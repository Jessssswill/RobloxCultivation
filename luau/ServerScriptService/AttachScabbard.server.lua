--[[
Sarung pedang di pinggang kiri (R15). Pedang kelihatan di dalam sarung waktu Tool nggak dipegang,
sarung kosong waktu Tool dipegang.
Cara pakai:
  1. Import IronDaoScabbard.fbx (unit: Stud). Hasilnya Model berisi MeshPart "Scabbard" dan "Mount".
     Isi Scabbard > SurfaceAppearance dengan 4 PNG IronDaoScabbard_* (Color/Normal/Roughness/Metalness).
     Sama untuk SpiritSwordScabbard.fbx (PNG SpiritSwordScabbard_*).
  2. Bikin folder ServerStorage > Scabbards, taruh Model tadi di situ, namai "IronDaoScabbard" / "SpiritSwordScabbard".
  3. Tool pedang ada di Backpack pemain (contoh: dari ServerStorage.Weapons), namanya harus sama dengan kunci di SCABBARDS.
  4. Taruh script ini sebagai Script di ServerScriptService.
Sarung kedua (misal Spirit Sword) cukup tambah 1 entri di SCABBARDS. Cuma sarung pedang terakhir yang dipegang yang muncul.
Kalau posisinya kurang pas, ubah angka di SCABBARDS lalu Play lagi.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- Kunci = nama Tool. Semua angka dalam stud / derajat, relatif ke LowerTorso (karakter menghadap -Z, kiri = -X)
local SCABBARDS = {
	["Iron Dao"] = {
		Template = "IronDaoScabbard",       -- nama Model di ServerStorage.Scabbards
		Part = "LowerTorso",                -- bagian badan tempat sarung dilas
		Pos = Vector3.new(-1.15, -0.3, -0.6), -- posisi mulut sarung: kiri, sedikit di bawah pinggang, agak ke depan
		Tilt = 35,     -- derajat ujung sarung turun dari horizontal (makin besar makin tegak)
		Yaw = -6,      -- putar kiri-kanan; negatif = ujung sarung keluar menjauhi kaki
		Roll = 0,      -- putar di sumbu sarung; 0 = mata pedang menghadap atas, 180 = bawah
		SwordDepth = 0.55, -- jarak mulut sarung -> posisi tangan (Handle) pedang waktu disarungkan
	},
	["Spirit Sword"] = {
		Template = "SpiritSwordScabbard", Part = "LowerTorso",
		Pos = Vector3.new(-1.15, -0.3, -0.6), Tilt = 35, Yaw = -6,
		Roll = 0,           -- jian: 0 = muka datar menghadap luar, mata pedang atas/bawah
		SwordDepth = 0.555, -- guard pas di atas mulut, lidah guard masuk takik mulut sarung
	},
}

local FOLDER = ServerStorage:WaitForChild("Scabbards")
local WeaponScale = require(game:GetService("ReplicatedStorage"):WaitForChild("WeaponScale"))

-- Arah dasar: sumbu sarung (Y mesh) ke belakang, punggung (X mesh) ke bawah, sisi depan mesh ke kiri luar
local BASE = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(0, 0, 1))

local function offset(cfg, k)
	return CFrame.new(cfg.Pos * k)
		* CFrame.Angles(0, math.rad(cfg.Yaw), 0)
		* CFrame.Angles(math.rad(cfg.Tilt), 0, 0)
		* BASE
		* CFrame.Angles(0, math.rad(cfg.Roll), 0)
end

local function find(root, name)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, name) then return d end
	end
end

local function weld(part0, part1, c0)
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = part0, part1, c0
	w.Parent = part1
	return w
end

local function loose(p)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
end

-- Pasang sarung ke karakter. Return model sarung dan part Mount (titik mulut sarung)
local function attach(character, scabbardTemplate, cfg, k)
	local body = character:WaitForChild(cfg.Part or "LowerTorso", 5)
	if not body then return end
	local model = scabbardTemplate:Clone()
	model:ScaleTo(k) -- sarung ikut ukuran pedangnya (tinggi avatar x BaseScale)
	local mount = find(model, "Mount")
	assert(mount, "Mount part not found in " .. scabbardTemplate.Name)
	mount.Transparency = 1
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			loose(p)
			if p ~= mount then weld(mount, p, mount.CFrame:ToObjectSpace(p.CFrame)) end -- posisi relatif dari hasil import
		end
	end
	weld(body, mount, offset(cfg, body.Size.X / 2)) -- ikut skala badan (LowerTorso standar lebarnya 2)
	model.Name = "Scabbard_" .. scabbardTemplate.Name
	model.Parent = character
	return model, mount
end

-- Salinan pedang di dalam sarung: muncul kalau Tool ada di Backpack, hilang kalau dipegang
local function sheath(player, model, mount, tool, cfg)
	local handle = tool:FindFirstChild("Handle")
	if not handle then return end
	local copy = Instance.new("Model")
	copy.Name = "SheathedSword"
	local k = WeaponScale.targetFor(model.Parent, tool)
	local r = k / (tool:GetAttribute("AppliedScale") or 1) -- Tool di Backpack bisa belum atau udah diskalain
	copy:SetAttribute("AppliedScale", k)
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") and p ~= handle and p.Transparency < 1 then
			local c = p:Clone()
			c.Size *= r
			for _, b in ipairs(c:GetDescendants()) do
				if b:IsA("Bone") then b.Position *= r end
			end
			for _, ch in ipairs(c:GetChildren()) do
				if not (ch:IsA("SurfaceAppearance") or ch:IsA("Bone")) then ch:Destroy() end -- buang Trail, Attachment, weld lama; tulang rumbai tetap
			end
			loose(c)
			local rel = handle.CFrame:ToObjectSpace(p.CFrame)
			weld(mount, c, CFrame.new(0, -cfg.SwordDepth * k, 0) * (rel - rel.Position + rel.Position * r))
			c.Parent = copy
		end
	end
	local function refresh()
		copy.Parent = (tool.Parent == player:FindFirstChild("Backpack")) and model or nil
	end
	tool:GetPropertyChangedSignal("Parent"):Connect(refresh)
	refresh()
end

-- Cuma satu sarung yang kelihatan: punya pedang yang terakhir dipegang (default: pedang pertama yang ketemu)
local function onCharacter(player, character)
	local backpack = player:WaitForChild("Backpack")
	local entries = {} -- toolName -> { model, tool }
	local active = nil

	local function show()
		for name, e in pairs(entries) do
			e.model.Parent = (name == active) and character or nil
		end
	end

	local function add(tool)
		local cfg = SCABBARDS[tool.Name]
		if not cfg or entries[tool.Name] then return end
		local template = FOLDER:FindFirstChild(cfg.Template)
		if not template then return end
		local model, mount = attach(character, template, cfg, WeaponScale.targetFor(character, tool))
		if not model then return end
		sheath(player, model, mount, tool, cfg)
		entries[tool.Name] = { model = model, tool = tool }
		tool.Equipped:Connect(function()
			active = tool.Name
			show()
		end)
		if not active then active = tool.Name end
		show()
	end

	for _, t in ipairs(backpack:GetChildren()) do
		if t:IsA("Tool") then task.spawn(add, t) end
	end
	backpack.ChildAdded:Connect(function(t)
		if t:IsA("Tool") then task.spawn(add, t) end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
	if player.Character then onCharacter(player, player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
