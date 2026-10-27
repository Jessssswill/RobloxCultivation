-- CombatCore: data pemain, realm, damage, VFX, skill, tribulasi.
-- Dipakai CombatServer, HitServer (pedang) dan ZoneSpawner (monster).
local Core = {}
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DSS = game:GetService("DataStoreService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunS = game:GetService("RunService")
local Remotes = RS:WaitForChild("QiRemotes")
local FX = workspace:WaitForChild("FX")
local Monsters = workspace:WaitForChild("Monsters")

local CYAN = Color3.fromRGB(110, 220, 255)
local GOLD = Color3.fromRGB(255, 210, 90)
local PURPLE = Color3.fromRGB(190, 170, 255)
Core.CYAN, Core.GOLD = CYAN, GOLD

-- ===== Realm & Dao =====
Core.REALMS = {"Iron Bone", "Soul Spring", "Inner Heaven"}
local STAGES = {"Early", "Mid", "Peak"}
function Core.realmOf(stage) return math.ceil(stage / 3) end
function Core.realmName(stage)
	return Core.REALMS[Core.realmOf(stage)] .. " " .. STAGES[(stage - 1) % 3 + 1]
end
function Core.qiNeed(stage) return 40 + stage * 30 end
function Core.daoLevel(xp)
	if xp >= 300 then return 3 elseif xp >= 120 then return 2 elseif xp >= 40 then return 1 end
	return 0
end

-- ===== Data (DataStore cuma jalan kalau place sudah di-publish + API access nyala) =====
Core.Data = {}
local store
pcall(function() store = DSS:GetDataStore("QiCultivation_v1") end)
local function defaults()
	return {Qi = 0, Stage = 1, Race = "", SwordDao = 0, PalmDao = 0, Mats = {}, Lore = {}}
end

function Core.sync(plr)
	local d = Core.Data[plr]
	if not d then return end
	plr:SetAttribute("Qi", math.floor(d.Qi))
	plr:SetAttribute("QiNeed", Core.qiNeed(d.Stage))
	plr:SetAttribute("Stage", d.Stage)
	plr:SetAttribute("Realm", Core.realmName(d.Stage))
	plr:SetAttribute("Race", d.Race)
	plr:SetAttribute("SwordDao", Core.daoLevel(d.SwordDao))
	plr:SetAttribute("PalmDao", Core.daoLevel(d.PalmDao))
	local n = 0
	for _, c in d.Mats do n += c end
	plr:SetAttribute("Mats", n)
	plr:SetAttribute("Lore", #d.Lore)
	local ls = plr:FindFirstChild("leaderstats")
	if ls then
		ls.Realm.Value = Core.realmName(d.Stage)
		ls.Qi.Value = math.floor(d.Qi)
	end
end

function Core.load(plr)
	local d
	if store then
		local ok, res = pcall(function() return store:GetAsync("u" .. plr.UserId) end)
		if ok and type(res) == "table" then d = res end
		if not ok then warn("[QiSword] DataStore not active (needs publish + API access):", res) end
	end
	local def = defaults()
	d = d or def
	for k, v in def do
		if d[k] == nil then d[k] = v end
	end
	Core.Data[plr] = d
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local r = Instance.new("StringValue")
	r.Name = "Realm"
	r.Parent = ls
	local q = Instance.new("IntValue")
	q.Name = "Qi"
	q.Parent = ls
	ls.Parent = plr
	Core.sync(plr)
	plr:SetAttribute("TribReady", d.Stage % 3 == 0 and d.Stage < 9 and d.Qi >= Core.qiNeed(d.Stage))
	plr:SetAttribute("DataLoaded", true)
end

function Core.save(plr)
	local d = Core.Data[plr]
	if store and d then
		pcall(function() store:SetAsync("u" .. plr.UserId, d) end)
	end
end

-- ===== Helper VFX =====
function Core.part(size, cf, color, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if props then
		for k, v in props do p[k] = v end
	end
	p.Parent = FX
	return p
end

function Core.fade(p, t, size, delayT)
	task.delay(delayT or 0, function()
		if not p.Parent then return end
		local goal = {Transparency = 1}
		if size then goal.Size = size end
		TS:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	end)
	Debris:AddItem(p, (delayT or 0) + t + 0.1)
end

local FLAT = CFrame.Angles(0, 0, math.rad(90))
function Core.disc(pos, radius, color, transp)
	return Core.part(Vector3.new(0.2, radius * 2, radius * 2), CFrame.new(pos) * FLAT, color, {Shape = Enum.PartType.Cylinder, Transparency = transp or 0.6})
end

function Core.ring(pos, radius, color, t, thick)
	t = t or 0.4
	local r = Core.part(Vector3.new(thick or 0.4, 1, 1), CFrame.new(pos) * FLAT, color, {Shape = Enum.PartType.Cylinder, Transparency = 0.15})
	TS:Create(r, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = Vector3.new(thick or 0.4, radius * 2, radius * 2)}):Play()
	Core.fade(r, t * 0.8, nil, t * 0.5)
	return r
end

function Core.sparks(pos, color, n, speed)
	local a = Core.part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), color, {Transparency = 1})
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0)})
	e.Lifetime = NumberRange.new(0.25, 0.55)
	e.Speed = NumberRange.new(speed or 20, (speed or 20) * 1.8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 5
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = (n or 15) * 8
	e.Parent = a
	task.delay(0.12, function() e.Enabled = false end)
	Debris:AddItem(a, 1)
end

-- angka damage digambar di client biar halus
function Core.popNumber(pos, text, color, big)
	Remotes.Fx:FireAllClients("Num", pos, text, color, big)
end

local function exclude()
	local list = {FX, Monsters}
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(list, p.Character) end
	end
	return list
end
function Core.ground(pos)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = exclude()
	local res = workspace:Raycast(pos + Vector3.new(0, 25, 0), Vector3.new(0, -120, 0), rp)
	return res and res.Position or pos
end
local ground = Core.ground

local function flatDir(from, to, fallback)
	local v = to and (to - from) or fallback
	v = Vector3.new(v.X, 0, v.Z)
	if v.Magnitude < 0.1 then v = Vector3.new(fallback.X, 0, fallback.Z) end
	return v.Unit
end

local function clampAim(root, aim, maxD, default)
	local c = aim or (root.Position + root.CFrame.LookVector * default)
	local off = c - root.Position
	if off.Magnitude > maxD then c = root.Position + off.Unit * maxD end
	return ground(c)
end

-- ===== Cari musuh =====
local function alive(m)
	local h = m:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 and m:FindFirstChild("HumanoidRootPart") then return h end
end
Core.alive = alive

function Core.enemiesInRadius(pos, r)
	local list = {}
	for _, m in Monsters:GetChildren() do
		if alive(m) then
			local root = m.HumanoidRootPart
			if (root.Position - pos).Magnitude <= r + root.Size.Magnitude / 3 then table.insert(list, m) end
		end
	end
	return list
end

local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Include
op.FilterDescendantsInstances = {Monsters}
function Core.enemiesInBox(cf, size)
	local list, seen = {}, {}
	for _, part in workspace:GetPartBoundsInBox(cf, size, op) do
		local m = part
		while m and m.Parent ~= Monsters do m = m.Parent end
		if m and not seen[m] and alive(m) then
			seen[m] = true
			table.insert(list, m)
		end
	end
	return list
end

-- ===== Karakter =====
local function weld(p, to, offset)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = to.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
	return p
end
Core.weld = weld

function Core.baseSpeed(plr)
	local d = Core.Data[plr]
	local s = 17
	if plr:GetAttribute("BeastForm") then s += 6 end
	if plr:GetAttribute("Sprinting") then s += 11 end -- lari
	if plr:GetAttribute("Mounted") then s += 40 end -- menunggang kuda langit
	if plr:GetAttribute("DemonForm") then s += 40 end
	if plr:GetAttribute("SwordRiding") then s += 40 end -- menunggang pedang terbang (sama dengan kuda) -- wujud iblis 梼杌
	return s
end

local AURA = {
	{Color3.fromRGB(255, 90, 60), 5, 0.8},
	{CYAN, 9, 1.1},
	{GOLD, 14, 1.5},
}
function Core.applyAura(plr)
	local d = Core.Data[plr]
	local char = plr.Character
	local torso = char and char:FindFirstChild("UpperTorso")
	if not d or not torso then return end
	local old = char:FindFirstChild("QiAura")
	if old then old:Destroy() end
	local realm = Core.realmOf(d.Stage)
	local cfg = AURA[realm]
	local f = Instance.new("Folder")
	f.Name = "QiAura"
	f.Parent = char
	local core = Instance.new("Part")
	core.Size = Vector3.new(0.2, 0.2, 0.2)
	core.Transparency = 1
	core.Parent = f
	weld(core, torso, CFrame.new(0, 0.2, 0.8))
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(cfg[1])
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = cfg[2] * (1 + ((d.Stage - 1) % 3) * 0.5)
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, 4, 0)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, cfg[3] * 0.4), NumberSequenceKeypoint.new(0.4, cfg[3]), NumberSequenceKeypoint.new(1, 0)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)})
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Parent = core
	local light = Instance.new("PointLight")
	light.Color = cfg[1]
	light.Range = 6 + realm * 2
	light.Brightness = 1
	light.Parent = core
	if realm >= 2 then
		local halo = Instance.new("Part")
		halo.Shape = Enum.PartType.Cylinder
		halo.Material = Enum.Material.Neon
		halo.Color = cfg[1]
		halo.Transparency = 0.8
		halo.Size = Vector3.new(0.1, 2.2, 2.2)
		halo.Parent = f
		weld(halo, torso, CFrame.new(0, 1.9, 0.7) * CFrame.Angles(0, math.rad(90), 0))
	end
	if realm >= 3 then
		local isle = Instance.new("Part")
		isle.Size = Vector3.new(1.6, 0.6, 1.6)
		isle.Color = Color3.fromRGB(110, 95, 80)
		isle.Material = Enum.Material.Rock
		isle.Parent = f
		weld(isle, torso, CFrame.new(1.9, 2.6, 1.2))
		local grass = Instance.new("Part")
		grass.Size = Vector3.new(1.6, 0.15, 1.6)
		grass.Color = Color3.fromRGB(100, 170, 90)
		grass.Material = Enum.Material.Grass
		grass.Parent = f
		weld(grass, torso, CFrame.new(1.9, 2.97, 1.2))
	end
end

function Core.applyCharacter(plr, heal)
	local d = Core.Data[plr]
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not d or not hum then return end
	local maxhp = 100 + (d.Stage - 1) * 15 + (Core.RACE[d.Race] or Core.RACE.Mortal).hp
	hum.MaxHealth = maxhp
	if heal then hum.Health = maxhp end
	hum.WalkSpeed = Core.baseSpeed(plr)
	local old = char:FindFirstChild("RaceFX")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "RaceFX"
	f.Parent = char
	local head = char:FindFirstChild("Head")
	local function veins(col)
		for _, n in {"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "UpperTorso"} do
			local limb = char:FindFirstChild(n)
			if limb then
				local line = Instance.new("Part")
				line.Material = Enum.Material.Neon
				line.Color = col
				line.Size = n == "UpperTorso" and Vector3.new(0.12, 1.4, 0.05) or Vector3.new(0.08, limb.Size.Y * 0.8, limb.Size.Z + 0.02)
				line.Parent = f
				weld(line, limb, n == "UpperTorso" and CFrame.new(0, 0, -limb.Size.Z / 2) or CFrame.new())
			end
		end
	end
	if d.Race == "Celestial" and head then
		-- lingkaran cahaya di belakang kepala + urat emas
		local halo = Instance.new("Part")
		halo.Shape = Enum.PartType.Cylinder
		halo.Material = Enum.Material.Neon
		halo.Color = GOLD
		halo.Transparency = 0.35
		halo.Size = Vector3.new(0.08, 2.1, 2.1)
		halo.Parent = f
		weld(halo, head, CFrame.new(0, 0.45, 0.75) * CFrame.Angles(0, math.rad(90), 0))
		veins(GOLD)
	elseif d.Race == "Demon" and head then
		-- tanduk merah gelap + urat merah
		for _, s in {-1, 1} do
			local horn = Instance.new("WedgePart")
			horn.Size = Vector3.new(0.2, 0.75, 0.35)
			horn.Color = Color3.fromRGB(70, 10, 15)
			horn.Material = Enum.Material.SmoothPlastic
			horn.Parent = f
			weld(horn, head, CFrame.new(0.32 * s, 0.8, -0.05) * CFrame.Angles(math.rad(-15), 0, math.rad(-18 * s)))
		end
		veins(Color3.fromRGB(200, 20, 40))
	end
	Core.applyAura(plr)
end

-- ===== Ras =====
-- Mortal: Dao lebih cepat, stat awal paling rendah.
-- Celestial: stat & qi lebih tinggi, ranah awal cepat, tapi tribulasi lebih berat.
-- Demon: menyerap qi musuh yang dikalahkan, serangan ganas, tapi meditasi lambat.
Core.RACE = {
	Mortal = {hp = -10, qi = 1, dao = 1.5, dmg = 1, med = 1, trib = 1},
	Celestial = {hp = 15, qi = 1.2, dao = 1, dmg = 1, med = 1, trib = 1.4},
	Demon = {hp = 5, qi = 1, dao = 1, dmg = 1.12, med = 0.6, trib = 1},
}
function Core.race(plr)
	local d = Core.Data[plr]
	return Core.RACE[d and d.Race or ""] or Core.RACE.Mortal
end

-- ===== Progres =====
function Core.addDao(plr, key, amt)
	local d = Core.Data[plr]
	if not d then return end
	local before = Core.daoLevel(d[key])
	amt *= Core.race(plr).dao
	d[key] = math.min(d[key] + amt, 400)
	local after = Core.daoLevel(d[key])
	if after > before then
		local nm = key == "SwordDao" and "Sword Dao" or "Palm Dao"
		local col = key == "SwordDao" and CYAN or GOLD
		Remotes.Fx:FireClient(plr, "Banner", "Enlightenment! " .. nm .. " Level " .. after, col)
		local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if r then Core.ring(r.Position - Vector3.new(0, 2.6, 0), 14, col, 0.8) end
		Core.sync(plr)
	end
end

function Core.onBreakthrough(plr, major)
	local d = Core.Data[plr]
	Core.sync(plr)
	Remotes.Fx:FireAllClients("Breakthrough", plr.Name, Core.realmName(d.Stage), major)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local col = major and GOLD or CYAN
		local pillar = Core.part(Vector3.new(200, 5, 5), CFrame.new(root.Position + Vector3.new(0, 97, 0)) * FLAT, col, {Shape = Enum.PartType.Cylinder, Transparency = 0.3})
		TS:Create(pillar, TweenInfo.new(1.2), {Size = Vector3.new(200, 14, 14)}):Play()
		Core.fade(pillar, 1, nil, 0.7)
		Core.ring(root.Position - Vector3.new(0, 2.8, 0), major and 30 or 16, col, 0.7)
		Core.sparks(root.Position, col, 40, 35)
	end
	Core.applyCharacter(plr, true)
end

function Core.addQi(plr, amt)
	local d = Core.Data[plr]
	if not d then return end
	amt *= Core.race(plr).qi
	-- Celestial: ranah awal (Qi Condensation) melesat lebih cepat
	if d.Race == "Celestial" and d.Stage <= 3 then amt *= 1.25 end
	d.Qi += amt
	while d.Stage < 9 and d.Qi >= Core.qiNeed(d.Stage) do
		if d.Stage % 3 == 0 then
			-- Peak: harus lewat tribulasi petir dulu
			d.Qi = Core.qiNeed(d.Stage)
			if not plr:GetAttribute("TribReady") then
				plr:SetAttribute("TribReady", true)
				Remotes.Fx:FireClient(plr, "Banner", "Peak reached! Face the heavenly lightning at the Tribulation Arena", PURPLE)
			end
			break
		end
		d.Qi -= Core.qiNeed(d.Stage)
		d.Stage += 1
		Core.onBreakthrough(plr, false)
	end
	if d.Stage >= 9 then d.Qi = math.min(d.Qi, Core.qiNeed(9)) end
	Core.sync(plr)
end

-- ===== Damage =====
function Core.dealDamage(plr, m, base, src, kb)
	local hum = alive(m)
	if not hum then return end
	local d = Core.Data[plr]
	local stage = d and d.Stage or 1
	local dmg = base * (1 + (stage - 1) * 0.12)
	dmg *= Core.race(plr).dmg
	if plr:GetAttribute("BeastForm") then dmg *= 1.25 end
	local crit = math.random() < 0.1
	if crit then dmg *= 1.5 end
	if (m:GetAttribute("StunUntil") or 0) > os.clock() then dmg *= 1.3 end
	dmg = math.max(1, math.floor(dmg + 0.5))
	m:SetAttribute("LastHitBy", plr.UserId)
	hum:TakeDamage(dmg)
	if hum.Health <= 0 and d and d.Race == "Demon" and not m:GetAttribute("Devoured") then
		Core.devour(plr, m)
	end
	local root = m.HumanoidRootPart
	Core.popNumber(root.Position + Vector3.new(0, root.Size.Y / 2 + 2.5, 0), tostring(dmg) .. (crit and "!" or ""), crit and GOLD or Color3.new(1, 1, 1), crit)
	local hl = m:FindFirstChild("HitFlash") or Instance.new("Highlight")
	hl.Name = "HitFlash"
	hl.FillColor = Color3.new(1, 1, 1)
	hl.OutlineColor = CYAN
	hl.FillTransparency = 0.25
	hl.Enabled = true
	hl.Parent = m
	task.delay(0.09, function() if hl.Parent then hl.Enabled = false end end)
	Core.sparks(root.Position, src == "palm" and GOLD or CYAN, 10)
	local pr = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if kb and kb > 0 and pr then
		if m:GetAttribute("Heavy") then kb *= 0.12 end
		local dir = root.Position - pr.Position
		dir = Vector3.new(dir.X, 0, dir.Z)
		if dir.Magnitude > 0.01 then
			root.AssemblyLinearVelocity = dir.Unit * kb + Vector3.new(0, kb * 0.3, 0)
		end
	end
	Remotes.Fx:FireClient(plr, "HitConfirm", (src == "ult" or src == "palmult") and 0.12 or 0.05, crit)
	if src == "combo" or src == "sword" or src == "ult" then
		Core.addDao(plr, "SwordDao", src == "combo" and 0.5 or 2)
	elseif src == "palm" or src == "palmult" then
		Core.addDao(plr, "PalmDao", 2)
	end
	return dmg
end

-- Demon: serap sisa qi musuh yang mati (qi bonus + sedikit darah)
function Core.devour(plr, m)
	m:SetAttribute("Devoured", true)
	local root = m:FindFirstChild("HumanoidRootPart")
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	local qi = math.max(1, math.floor((m:GetAttribute("Qi") or 5) * 0.5))
	Core.addQi(plr, qi)
	if hum and hum.Health > 0 then hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.08) end
	if root and myRoot then
		local red = Color3.fromRGB(220, 30, 50)
		Core.popNumber(root.Position + Vector3.new(0, 7, 0), "Devour +" .. qi .. " qi", red)
		for i = 1, 5 do
			local orb = Core.part(Vector3.new(0.7, 0.7, 0.7), CFrame.new(root.Position + Vector3.new(math.random(-2, 2), math.random(0, 3), math.random(-2, 2))), red, {Shape = Enum.PartType.Ball})
			TS:Create(orb, TweenInfo.new(0.5 + i * 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = myRoot.CFrame, Size = Vector3.new(0.2, 0.2, 0.2)}):Play()
			Core.fade(orb, 0.6 + i * 0.08, nil, 0.1)
		end
	end
end

function Core.beastForm(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	plr:SetAttribute("BeastForm", true)
	plr:SetAttribute("BeastCD", os.clock() + 60)
	hum.WalkSpeed = Core.baseSpeed(plr)
	local torso = char:FindFirstChild("UpperTorso")
	local fire
	if torso then
		fire = Instance.new("Fire")
		fire.Color = Color3.fromRGB(255, 120, 60)
		fire.SecondaryColor = Color3.fromRGB(255, 40, 40)
		fire.Size = 6
		fire.Parent = torso
	end
	Remotes.Fx:FireClient(plr, "Banner", "Beast Form awakened!", Color3.fromRGB(255, 120, 60))
	task.delay(10, function()
		plr:SetAttribute("BeastForm", nil)
		if fire then fire:Destroy() end
		if hum.Parent and not char:GetAttribute("Blocking") and not plr:GetAttribute("Meditating") then
			hum.WalkSpeed = Core.baseSpeed(plr)
		end
	end)
end

-- monster -> pemain. src = model monster (buat parry), heavy = serangan berat
function Core.damagePlayer(char, dmg, src, heavy)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root then return "none" end
	local plr = Players:GetPlayerFromCharacter(char)
	local top = root.Position + Vector3.new(0, 3, 0)
	local now = os.clock()
	if (char:GetAttribute("IFrameUntil") or 0) > now then
		Core.popNumber(top, "DODGE", Color3.fromRGB(200, 230, 255))
		return "dodge"
	end
	if src and (char:GetAttribute("ParryUntil") or 0) > now then
		src:SetAttribute("StunUntil", now + (heavy and 1.0 or 1.6))
		Core.popNumber(top, "PARRY!", CYAN, true)
		Core.sparks(root.Position + root.CFrame.LookVector * 2, CYAN, 25, 30)
		if plr then Remotes.Fx:FireClient(plr, "Parry") end
		return "parry"
	end
	if char:GetAttribute("Blocking") then
		dmg *= 0.3
		Core.sparks(root.Position + root.CFrame.LookVector * 2, Color3.fromRGB(255, 240, 200), 8)
	end
	dmg = math.max(1, math.floor(dmg + 0.5))
	hum:TakeDamage(dmg)
	Core.popNumber(top, tostring(dmg), Color3.fromRGB(255, 90, 90))
	if plr then
		Remotes.Fx:FireClient(plr, "Shake", heavy and 0.7 or 0.3, 0.2)
		local d = Core.Data[plr]
	end
	return "hit"
end

-- ===== Loot =====
Core.RARITY = {Common = Color3.fromRGB(225, 225, 225), Rare = Color3.fromRGB(80, 160, 255), Epic = Color3.fromRGB(190, 90, 255), Legendary = GOLD}
Core.MAT_VALUE = {Common = 5, Rare = 15, Epic = 40, Legendary = 100}
Core.LOOT = {
	SpiritWolf = {{"Wolf Fang", "Common", 0.7}, {"Spirit Core", "Rare", 0.15}},
	StoneBoar = {{"Boar Hide", "Common", 0.7}, {"Stone Tusk", "Rare", 0.2}},
	ElderWolf = {{"Frostfang Pelt", "Epic", 1}, {"Spirit Core", "Rare", 0.6}},
	MistSerpent = {{"Mist Scale", "Rare", 0.6}, {"Spirit Core", "Rare", 0.2}},
	ThunderApe = {{"Thunder Fur", "Rare", 0.6}},
	StormApeKing = {{"Storm Heart", "Epic", 1}},
	DragonGuardian = {{"Sword Shard", "Legendary", 1}, {"Dragon Scale", "Epic", 1}},
}
Core.ITEM_RARITY = {}
for _, list in Core.LOOT do
	for _, it in list do Core.ITEM_RARITY[it[1]] = it[2] end
end

function Core.dropLoot(name, pos)
	local tbl = Core.LOOT[name]
	if not tbl then return end
	for _, it in tbl do
		if math.random() < it[3] then
			local col = Core.RARITY[it[2]]
			local at = ground(pos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
			local orb = Core.part(Vector3.new(1.2, 1.2, 1.2), CFrame.new(at + Vector3.new(0, 1.2, 0)), col, {Shape = Enum.PartType.Ball})
			local beam = Core.part(Vector3.new(16, 0.6, 0.6), CFrame.new(at + Vector3.new(0, 8, 0)) * FLAT, col, {Shape = Enum.PartType.Cylinder, Transparency = 0.55})
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(180, 28)
			bb.StudsOffset = Vector3.new(0, 2, 0)
			bb.MaxDistance = 80
			bb.Parent = orb
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Text = it[1] .. " [" .. it[2] .. "]"
			t.TextColor3 = col
			t.TextStrokeTransparency = 0.3
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.Parent = bb
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 45 and orb.Parent do
					for _, p in Players:GetPlayers() do
						local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
						local d = Core.Data[p]
						if r and d and (r.Position - at).Magnitude < 7 then
							d.Mats[it[1]] = (d.Mats[it[1]] or 0) + 1
							Remotes.Fx:FireClient(p, "Loot", it[1], it[2], col)
							Core.sync(p)
							orb:Destroy()
							beam:Destroy()
							return
						end
					end
					task.wait(0.2)
				end
				orb:Destroy()
				beam:Destroy()
			end)
		end
	end
end

-- ===== Model skill =====
local function makeSword(scale, color)
	local m = Instance.new("Model")
	local blade = Core.part(Vector3.new(0.5, 6, 0.18) * scale, CFrame.new(), color, {Transparency = 0.1})
	blade.Parent = m
	local edge = Core.part(Vector3.new(0.18, 6.1, 0.2) * scale, CFrame.new(), Color3.new(1, 1, 1), {})
	edge.Parent = m
	local guard = Core.part(Vector3.new(1.8, 0.3, 0.4) * scale, CFrame.new(0, 3 * scale, 0), GOLD, {Material = Enum.Material.Metal})
	guard.Parent = m
	local hilt = Core.part(Vector3.new(0.3, 1.6, 0.3) * scale, CFrame.new(0, 3.9 * scale, 0), Color3.fromRGB(40, 40, 60), {Material = Enum.Material.SmoothPlastic})
	hilt.Parent = m
	m.PrimaryPart = blade
	m.Parent = FX
	return m
end

local function makePalm(scale, color)
	local m = Instance.new("Model")
	local palm = Core.part(Vector3.new(3.2, 3.6, 0.8) * scale, CFrame.new(), color, {Transparency = 0.2})
	palm.Parent = m
	for i = 0, 3 do
		local len = (i == 0 or i == 3) and 2.1 or 2.7
		local f = Core.part(Vector3.new(0.7, len, 0.6) * scale, CFrame.new((-1.2 + i * 0.8) * scale, (1.8 + len / 2) * scale, 0), color, {Transparency = 0.2})
		f.Parent = m
	end
	local th = Core.part(Vector3.new(0.7, 2, 0.6) * scale, CFrame.new(2.1 * scale, 0.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(-40)), color, {Transparency = 0.2})
	th.Parent = m
	m.PrimaryPart = palm
	m.Parent = FX
	return m
end

local function fadeModel(m, t, delayT)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then Core.fade(p, t, nil, delayT) end
	end
	Debris:AddItem(m, (delayT or 0) + t + 0.2)
end

local function tweenFor(dur, fn)
	local t0 = os.clock()
	while true do
		RunS.Heartbeat:Wait()
		local k = math.min((os.clock() - t0) / dur, 1)
		fn(k)
		if k >= 1 then break end
	end
end

local function shakeNear(pos, mag, dur, range)
	for _, p in Players:GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - pos).Magnitude < (range or 120) then Remotes.Fx:FireClient(p, "Shake", mag, dur) end
	end
end
Core.shakeNear = shakeNear

-- ===== Skill =====
local Skills = {}
Core.Skills = Skills

-- Z: tebasan bulan sabit (skillshot)
function Skills.Crescent(plr, char, root, aim, small)
	local dir = flatDir(root.Position, aim, root.CFrame.LookVector)
	local pos = root.Position + dir * 3
	local w = small and 6 or 12
	local blade = Core.part(Vector3.new(w, 0.5, 2.6), CFrame.lookAt(pos, pos + dir), CYAN, {Transparency = 0.15})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = blade
	local inner = Core.part(Vector3.new(w * 0.8, 0.3, 1.1), blade.CFrame, Color3.new(1, 1, 1), {})
	mesh:Clone().Parent = inner
	local light = Instance.new("PointLight")
	light.Color = CYAN
	light.Range = 14
	light.Brightness = 3
	light.Parent = blade
	local hit = {}
	local dist, speed, range = 0, 120, small and 45 or 75
	while dist < range do
		dist += speed * RunS.Heartbeat:Wait()
		local cf = CFrame.lookAt(pos + dir * dist, pos + dir * (dist + 1))
		blade.CFrame = cf
		inner.CFrame = cf
		for _, m in Core.enemiesInBox(cf, Vector3.new(w, 5, 4)) do
			if not hit[m] then
				hit[m] = true
				Core.dealDamage(plr, m, small and 12 or 28, "sword", 30)
			end
		end
	end
	Core.fade(blade, 0.15, Vector3.new(w * 1.4, 0.5, 3))
	Core.fade(inner, 0.15)
end

-- X: hujan pedang di titik bidik
function Skills.SwordRain(plr, char, root, aim)
	local d = Core.Data[plr]
	local center = clampAim(root, aim, 45, 15)
	local count = Core.daoLevel(d.SwordDao) >= 3 and 18 or 12
	local tele = Core.disc(center + Vector3.new(0, 0.15, 0), 12, CYAN, 0.65)
	Core.fade(tele, 0.4, nil, count * 0.06 + 0.3)
	for i = 1, count do
		task.delay(i * 0.06, function()
			local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * 11
			local land = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local s = makeSword(1, CYAN)
			local tilt = CFrame.Angles(math.rad(math.random(-12, 12)), math.random() * 6, math.rad(math.random(-12, 12)))
			tweenFor(0.22, function(k)
				s:PivotTo(CFrame.new(land + Vector3.new(0, 45 * (1 - k * k) + 2.2, 0)) * tilt)
			end)
			Core.sparks(land, CYAN, 8)
			for _, m in Core.enemiesInRadius(land, 4.5) do Core.dealDamage(plr, m, 10, "sword", 8) end
			fadeModel(s, 0.4, 0.6)
		end)
	end
end

-- C: telapak qi raksasa
function Skills.QiPalm(plr, char, root, aim)
	local d = Core.Data[plr]
	local dir = flatDir(root.Position, aim, root.CFrame.LookVector)
	local start = root.Position + dir * 3 + Vector3.new(0, 0.5, 0)
	local palm = makePalm(1.6, GOLD)
	local hit = {}
	local range = 50
	tweenFor(0.42, function(k)
		local e = 1 - (1 - k) ^ 3
		local pos = start + dir * range * e
		local cf = CFrame.lookAt(pos, pos + dir)
		palm:PivotTo(cf)
		for _, m in Core.enemiesInBox(cf, Vector3.new(7, 8, 5)) do
			if not hit[m] then
				hit[m] = true
				Core.dealDamage(plr, m, 30, "palm", 70)
			end
		end
	end)
	local endPos = start + dir * range
	if Core.daoLevel(d.PalmDao) >= 1 then
		Core.ring(endPos, 10, GOLD, 0.4, 1)
		Core.sparks(endPos, GOLD, 25, 30)
		for _, m in Core.enemiesInRadius(endPos, 10) do Core.dealDamage(plr, m, 15, "palm", 30) end
	end
	fadeModel(palm, 0.25)
end

-- V: hentakan bumi di sekitar diri
function Skills.GroundShock(plr, char, root)
	local d = Core.Data[plr]
	local lvl2 = Core.daoLevel(d.PalmDao) >= 2
	local radius = lvl2 and 20 or 16
	local pos = ground(root.Position)
	Core.ring(pos + Vector3.new(0, 0.2, 0), radius, GOLD, 0.45, 0.6)
	Core.ring(pos + Vector3.new(0, 0.3, 0), radius * 0.6, Color3.new(1, 1, 1), 0.3, 0.4)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		task.delay(i * 0.015, function()
			local at = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.6
			local cf = CFrame.new(at - Vector3.new(0, 2, 0)) * CFrame.Angles(math.rad(math.random(-20, 20)), a, math.rad(math.random(-20, 20)))
			local rock = Core.part(Vector3.new(2, 4, 2), cf, Color3.fromRGB(120, 110, 100), {Material = Enum.Material.Slate})
			TS:Create(rock, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {CFrame = cf + Vector3.new(0, 3.5, 0)}):Play()
			Core.fade(rock, 0.5, Vector3.new(1, 1, 1), 0.6)
		end)
	end
	Core.sparks(pos + Vector3.new(0, 1, 0), Color3.fromRGB(230, 210, 170), 30, 25)
	for _, m in Core.enemiesInRadius(pos, radius) do
		Core.dealDamage(plr, m, lvl2 and 32 or 25, "palm", 20)
		m:SetAttribute("StunUntil", os.clock() + 0.7)
		if not m:GetAttribute("Heavy") then m.HumanoidRootPart.AssemblyLinearVelocity += Vector3.new(0, 45, 0) end
	end
	shakeNear(pos, 0.7, 0.3, 40)
end

-- G (ultimate): Galaxy Severing Blade. Avatar emas raksasa muncul di belakang,
-- semua tenaga dipadatkan jadi satu garis putih, tebasan emas membelah bola dunia.
-- Efeknya pakai Beam, Trail dan ParticleEmitter biar halus dan glowing (gaya donghua).
local WHITE = Color3.new(1, 1, 1)
local SKYBLUE = Color3.fromRGB(170, 215, 255)
local VIOLET = Color3.fromRGB(185, 150, 255)
local ORANGE = Color3.fromRGB(255, 150, 60)
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"
local Terrain = workspace.Terrain

local function nseq(pts)
	local k = {}
	for _, p in pts do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(k)
end
local function cseq(pts)
	local k = {}
	for _, p in pts do table.insert(k, ColorSequenceKeypoint.new(p[1], p[2])) end
	return ColorSequence.new(k)
end
local GOLD_SEQ = cseq({{0, WHITE}, {0.35, Color3.fromRGB(255, 235, 160)}, {0.75, GOLD}, {1, ORANGE}})

-- titik bebas di dunia (attachment di Terrain = koordinat dunia)
local function att(pos, life)
	local a = Instance.new("Attachment")
	a.Parent = Terrain
	a.WorldPosition = pos
	Debris:AddItem(a, life or 7)
	return a
end
local function beam(a0, a1, w0, w1, color, transp, props)
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = w0
	b.Width1 = w1
	b.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
	b.Transparency = transp or NumberSequence.new(0)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 12
	if props then for k, v in props do b[k] = v end end
	b.Parent = a0
	return b
end
local function trail(a0, a1, life, color, transp)
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = life
	t.MinLength = 0
	t.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
	t.Transparency = transp or nseq({{0, 0}, {0.4, 0.3}, {1, 1}})
	t.LightEmission = 1
	t.LightInfluence = 0
	t.Parent = a0
	return t
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Texture = TEX_SPARK
	e.Rate = 0
	for k, v in props do e[k] = v end
	e.Parent = parent
	return e
end
local function holder(cf, size, shape, life)
	local p = Core.part(size or Vector3.new(0.2, 0.2, 0.2), cf, WHITE, {Transparency = 1, Shape = shape or Enum.PartType.Block})
	Debris:AddItem(p, life or 6)
	return p
end
-- lebar beam dipudarkan (NumberSequence nggak bisa di-tween)
local function shrinkBeams(list, dur, delayT)
	task.delay(delayT or 0, function()
		local w = {}
		for i, b in list do w[i] = {b.Width0, b.Width1} end
		tweenFor(dur, function(k)
			for i, b in list do
				if b.Parent then
					b.Width0 = w[i][1] * (1 - k)
					b.Width1 = w[i][2] * (1 - k)
				end
			end
		end)
		for _, b in list do b:Destroy() end
	end)
end
local function energyRing(pos, radius, color, t, thick, flat)
	local r = Core.part(Vector3.new(thick or 0.4, 1, 1), CFrame.new(pos) * (flat or CFrame.Angles(0, 0, math.rad(90))), color, {Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Transparency = 0})
	TS:Create(r, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = Vector3.new(thick or 0.4, radius * 2, radius * 2)}):Play()
	Core.fade(r, t * 0.7, nil, t * 0.5)
	return r
end

-- salinan emas raksasa dari badan pemain, ngikutin pose animasi tiap frame
local function makeAvatar(char)
	local list = {}
	local m = Instance.new("Model")
	m.Name = "GoldenAvatar"
	local torso
	for _, src in char:GetDescendants() do
		if src:IsA("BasePart") and src.Name ~= "HumanoidRootPart" and src.Transparency < 1 and not src:FindFirstAncestorOfClass("Tool") and not src:FindFirstAncestor("QiAura") then
			local okc, c = pcall(function() return src:Clone() end)
			if okc and c then
				for _, ch in c:GetChildren() do
					if not ch:IsA("SpecialMesh") then ch:Destroy() end
				end
				c.Anchored = true
				c.CanCollide = false
				c.CanQuery = false
				c.CanTouch = false
				c.CastShadow = false
				c.Massless = true
				c.Material = Enum.Material.ForceField
				c.Color = Color3.fromRGB(255, 200, 80)
				c.Transparency = 1
				if c:IsA("MeshPart") then pcall(function() c.TextureID = "" end) end
				c.Parent = m
				local mesh = c:FindFirstChildOfClass("SpecialMesh")
				if mesh then mesh.TextureId = "" end
				if src.Name == "UpperTorso" then torso = c end
				table.insert(list, {src, c, src.Size, mesh and mesh.Scale})
			end
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = GOLD
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.fromRGB(255, 245, 210)
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = m
	m.Parent = FX
	return m, list, hl, torso
end

local function poseAvatar(list, root, anchor, s, transp)
	local inv = root.CFrame:Inverse()
	for _, pr in list do
		local src, c = pr[1], pr[2]
		if src.Parent and c.Parent then
			local rel = inv * src.CFrame
			c.Size = pr[3] * s
			if pr[4] then c:FindFirstChildOfClass("SpecialMesh").Scale = pr[4] * s end
			c.CFrame = anchor * CFrame.new(rel.Position * s) * rel.Rotation
			c.Transparency = transp
		end
	end
end

-- petir bercabang di permukaan bola: inti putih + glow ungu, berkedip
local function crackBolt(center, radius, color)
	local rnd = Random.new()
	local a = rnd:NextUnitVector()
	local b = (a + rnd:NextUnitVector() * 1.3).Unit
	local pts = {}
	for i = 0, 7 do
		local v = a:Lerp(b, i / 7)
		if v.Magnitude < 0.05 then v = a end
		v = v.Unit * radius * 1.01
		if i > 0 and i < 7 then v += rnd:NextUnitVector() * radius * 0.07 end
		table.insert(pts, att(center + v, 2))
	end
	local beams = {}
	for i = 1, #pts - 1 do
		table.insert(beams, beam(pts[i], pts[i + 1], 0.45, 0.45, WHITE, nil, {Segments = 1}))
		table.insert(beams, beam(pts[i], pts[i + 1], 2.2, 2.2, color, NumberSequence.new(0.45), {Segments = 1}))
		if i % 3 == 0 then
			local tip = att(pts[i].WorldPosition + rnd:NextUnitVector() * radius * 0.25, 2)
			table.insert(beams, beam(pts[i], tip, 0.3, 0, WHITE, nil, {Segments = 1}))
		end
	end
	task.spawn(function()
		for _ = 1, 4 do
			task.wait(0.05)
			for _, bm in beams do if bm.Parent then bm.Enabled = not bm.Enabled end end
		end
		for _, bm in beams do if bm.Parent then bm.Enabled = true end end
	end)
	shrinkBeams(beams, 0.25, 0.3)
end

local function galaxyBlade(plr, char, root, aim)
	local hum = char:FindFirstChildOfClass("Humanoid")
	char:SetAttribute("IFrameUntil", os.clock() + 4.6)
	local origin = root.Position
	local dir = flatDir(origin, aim, root.CFrame.LookVector)
	local dist = 55
	if aim then dist = math.clamp((Vector3.new(aim.X, origin.Y, aim.Z) - origin).Magnitude, 35, 70) end
	local center = ground(origin + dir * dist) + Vector3.new(0, 10, 0)
	Remotes.Fx:FireAllClients("GalaxyUlt", plr, origin, center, dir)
	local up = Vector3.new(0, 1, 0)
	local face = CFrame.lookAt(origin, origin + dir)
	local floor = ground(origin)

	-- 1) melayang naik, qi berputar, batu-batu terangkat
	root.Anchored = true
	local avatar, aps, glow, avTorso = makeAvatar(char)
	local auraE
	if avTorso then
		auraE = emitter(avTorso, {Color = GOLD_SEQ, Size = nseq({{0, 1.5}, {0.5, 3}, {1, 0}}), Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, 10, 0), Transparency = nseq({{0, 0.3}, {1, 1}}), Texture = TEX_FIRE, Rate = 60, RotSpeed = NumberRange.new(-60, 60)})
	end
	local wings = {}
	for sgn = -1, 1, 2 do
		for i = 1, 6 do
			local len = 8 + i * 1.7
			local a0, a1 = att(origin, 6), att(origin, 6)
			local outer = beam(a0, a1, 0, 0, GOLD_SEQ, nseq({{0, 0.15}, {0.7, 0.35}, {1, 1}}))
			local inner = beam(a0, a1, 0, 0, WHITE, nseq({{0, 0}, {0.8, 0.4}, {1, 1}}))
			table.insert(wings, {a0, a1, outer, inner, sgn, i, len})
		end
	end
	local swirl = {}
	for i = 1, 12 do
		local a0, a1 = att(origin, 6), att(origin, 6)
		local col = i % 3 == 0 and VIOLET or (i % 3 == 1 and GOLD or WHITE)
		trail(a0, a1, 0.35, cseq({{0, WHITE}, {1, col}}), nseq({{0, 0}, {0.5, 0.35}, {1, 1}}))
		table.insert(swirl, {a0, a1, i * math.pi * 2 / 12, (i % 4) * 1.6})
	end
	local core = holder(face, nil, nil, 6)
	local streak = emitter(core, {Color = cseq({{0, WHITE}, {0.5, VIOLET}, {1, GOLD}}), Orientation = Enum.ParticleOrientation.VelocityParallel, Size = nseq({{0, 0.5}, {1, 0}}), Squash = NumberSequence.new(-2.5), Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(25, 55), SpreadAngle = Vector2.new(180, 180), Drag = 2})
	local rocks = {}
	for i = 1, 18 do
		local ang = math.random() * math.pi * 2
		local rad = 6 + math.random() * 12
		local sz = 0.5 + math.random() * 1.6
		local rock = Core.part(Vector3.new(sz, sz * 0.8, sz), CFrame.new(floor + Vector3.new(math.cos(ang) * rad, sz / 2, math.sin(ang) * rad)) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), Color3.fromRGB(90, 85, 80), {Material = Enum.Material.Slate})
		table.insert(rocks, {rock, rock.CFrame, 3 + math.random() * 7, math.random() * 2 - 1})
		Debris:AddItem(rock, 6)
	end
	local dustP = holder(CFrame.new(floor + up * 0.3), Vector3.new(34, 0.2, 34), nil, 6)
	local dust = emitter(dustP, {Texture = TEX_SMOKE, Color = ColorSequence.new(Color3.fromRGB(230, 200, 150)), Size = nseq({{0, 3}, {1, 9}}), Transparency = nseq({{0, 0.65}, {1, 1}}), Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(2, 6), Acceleration = Vector3.new(0, 2, 0), LightEmission = 0.2, RotSpeed = NumberRange.new(-30, 30), Rate = 25})
	dust:Emit(30)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 30
	light.Brightness = 0
	light.Parent = core
	TS:Create(light, TweenInfo.new(1.2), {Brightness = 4}):Play()

	local SCALE = 3.4
	local t0 = os.clock()
	local avS, avTr, wingK, wingVis, swirlR = 1, 1, 0, 0, 16
	local conn
	conn = RunS.Heartbeat:Connect(function()
		if not root.Parent or not avatar.Parent then conn:Disconnect() return end
		local t = os.clock() - t0
		local rc = root.CFrame
		local anchor = rc * CFrame.new(0, (avS - 1) * 2.6 - 1.5, 4 + avS * 1.4)
		poseAvatar(aps, root, anchor, avS, avTr)
		glow.FillTransparency = 0.6 + 0.4 * avTr
		glow.OutlineTransparency = avTr
		local back = anchor * CFrame.new(0, 1.2 * avS, 0.6 * avS)
		core.CFrame = back
		for _, w in wings do
			local a0, a1, outer, cw, sgn, i, len = w[1], w[2], w[3], w[4], w[5], w[6], w[7]
			local spread = math.rad(16 + i * 15) * wingK + math.sin(t * 3 + i) * 0.04
			local bcf = back * CFrame.Angles(0, 0, -sgn * spread) * CFrame.Angles(math.rad(-12 - i * 2), 0, 0)
			a0.WorldPosition = (bcf * CFrame.new(0, 1.5, 0)).Position
			a1.WorldPosition = (bcf * CFrame.new(0, len * (0.3 + 0.7 * wingK) + 1.5, 0)).Position
			outer.Width0 = 3.2 * wingVis
			cw.Width0 = 0.9 * wingVis
		end
		local c = rc.Position
		for _, s in swirl do
			local ang = s[3] + t * 5
			local p = c + Vector3.new(math.cos(ang) * swirlR, s[4] - 2 + math.sin(t * 4 + s[3]) * 1.2, math.sin(ang) * swirlR)
			s[1].WorldPosition = p
			s[2].WorldPosition = p + up * 0.6
		end
		for _, r in rocks do
			if r[1].Parent then
				local lift = math.min(t / 1.6, 1)
				lift = 1 - (1 - lift) ^ 2
				r[1].CFrame = r[2] + up * (r[3] * lift + math.sin(t * 2 + r[3]) * 0.3) * 1
				r[1].CFrame *= CFrame.Angles(r[4] * t * 0.6, r[4] * t * 0.4, 0)
			end
		end
	end)

	local base = root.CFrame
	task.spawn(function()
		tweenFor(0.5, function(k)
			if root.Parent then root.CFrame = base + up * 6 * (1 - (1 - k) ^ 3) end
		end)
	end)
	energyRing(floor + up * 0.3, 14, GOLD, 0.8, 0.4)

	-- 2) avatar emas tumbuh, sayap pedang terbuka
	tweenFor(0.9, function(k)
		local e = 1 - (1 - k) ^ 3
		avS = 1 + (SCALE - 1) * e
		avTr = 1 - 0.65 * math.min(k * 1.6, 1)
		wingVis = math.min(math.max(k - 0.2, 0) * 2, 1)
		wingK = math.max(k - 0.25, 0) / 0.75
		swirlR = 16 - 6 * e
	end)
	streak.Rate = 110
	energyRing(floor + up * 0.4, 26, Color3.fromRGB(255, 235, 170), 0.6, 0.6)
	shakeNear(origin, 0.5, 0.6, 120)
	task.wait(0.35)

	-- 3) semua dipadatkan ke pedang (partikel tersedot masuk)
	streak.Rate = 0
	dust.Rate = 0
	if auraE then auraE.Rate = 0 end
	local swordPos = root.Position + up * 3
	local implode = holder(CFrame.new(swordPos), Vector3.new(26, 26, 26), Enum.PartType.Ball, 2)
	local inE = emitter(implode, {Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NumberSequence.new(-2.5), Color = cseq({{0, WHITE}, {1, GOLD}}), Size = nseq({{0, 0.7}, {1, 0.1}}), Lifetime = NumberRange.new(0.35, 0.45), Speed = NumberRange.new(30, 38)})
	inE:Emit(160)
	tweenFor(0.4, function(k)
		local e = k * k
		avS = SCALE - (SCALE - 0.6) * e
		avTr = 0.35 + 0.65 * e
		wingK = 1 - e
		wingVis = 1 - e
		swirlR = 10 * (1 - e) + 0.5
	end)
	conn:Disconnect()
	avatar:Destroy()
	for _, w in wings do w[1]:Destroy() w[2]:Destroy() end
	for _, s in swirl do s[1]:Destroy() s[2]:Destroy() end
	local pop = holder(CFrame.new(swordPos), nil, nil, 2)
	emitter(pop, {Color = cseq({{0, WHITE}, {1, GOLD}}), Size = nseq({{0, 2.5}, {1, 0}}), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(10, 25), SpreadAngle = Vector2.new(180, 180)}):Emit(40)
	TS:Create(light, TweenInfo.new(0.15), {Brightness = 10, Range = 45}):Play()
	task.wait(0.15)

	-- 4) garis putih tipis membelah langit
	local la = att(swordPos - dir * 30, 2)
	local lb = att(swordPos + dir * 320, 2)
	local lineCore = beam(la, lb, 0.15, 0.15, WHITE, nil, {Segments = 1})
	local lineGlow = beam(la, lb, 0.5, 0.5, SKYBLUE, NumberSequence.new(0.7), {Segments = 1})
	task.spawn(function()
		tweenFor(0.12, function(k)
			lineCore.Width0, lineCore.Width1 = 0.15 + 2.2 * k, 0.15 + 2.2 * k
			lineGlow.Width0, lineGlow.Width1 = 0.5 + 9 * k, 0.5 + 9 * k
		end)
		shrinkBeams({lineCore, lineGlow}, 0.25)
	end)
	task.wait(0.1)

	-- 5) tebasan emas raksasa: busur dari trail (jejak gerak) + beam (tepi terang)
	for _, r in rocks do
		if r[1].Parent then
			TS:Create(r[1], TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = r[1].CFrame + dir * 25 + up * 4, Transparency = 1}):Play()
		end
	end
	local tilt = CFrame.Angles(0, 0, math.rad(-35))
	local start = root.Position + dir * 4
	local travel = (Vector3.new(center.X, start.Y, center.Z) - start).Magnitude + 20
	local N = 9
	local arc = {}
	local edge = {}
	for k = 0, N - 1 do
		local ai, ao = att(start, 3), att(start, 3)
		trail(ai, ao, 0.24, GOLD_SEQ, nseq({{0, 0}, {0.3, 0.25}, {1, 1}}))
		table.insert(arc, {ai, ao, math.rad(-70 + 140 * k / (N - 1)), 5 * math.sin(math.pi * k / (N - 1)) + 0.3})
	end
	for k = 1, N - 1 do
		table.insert(edge, beam(arc[k][2], arc[k + 1][2], 0.3, 0.3, WHITE, nil, {Segments = 2}))
		table.insert(edge, beam(arc[k][2], arc[k + 1][2], 1, 1, GOLD, NumberSequence.new(0.35), {Segments = 2}))
	end
	local sparkP = holder(CFrame.new(start), nil, nil, 3)
	local sparkE = emitter(sparkP, {Color = cseq({{0, WHITE}, {0.5, GOLD}, {1, ORANGE}}), Size = nseq({{0, 0.6}, {1, 0}}), Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(6, 18), SpreadAngle = Vector2.new(180, 180), Drag = 3, Rate = 260})
	local hitSet = {}
	tweenFor(0.42, function(k)
		local e = 1 - (1 - k) ^ 2
		local pos = start + dir * travel * e + up * (center.Y - start.Y) * e
		local cf = CFrame.lookAt(pos, pos + dir) * tilt
		local r = 16 + 10 * e
		for idx, a in arc do
			local ang, w = a[3], a[4] * (1 + e * 0.6)
			local n = Vector3.new(math.sin(ang), 0, -math.cos(ang) * 0.55).Unit
			local p = Vector3.new(math.sin(ang) * r, 0, -math.cos(ang) * r * 0.55)
			a[1].WorldPosition = (cf * CFrame.new(p - n * w / 2)).Position
			a[2].WorldPosition = (cf * CFrame.new(p + n * w / 2)).Position
			if idx < N then
				edge[idx * 2].Width0 = 1 + a[4] * 0.9
				edge[idx * 2].Width1 = 1 + arc[idx + 1][4] * 0.9
			end
		end
		sparkP.CFrame = cf
		for _, m in Core.enemiesInBox(CFrame.lookAt(pos, pos + dir), Vector3.new(34, 26, 14)) do
			if not hitSet[m] then
				hitSet[m] = true
				Core.dealDamage(plr, m, 70, "ult", 40)
				Core.sparks(m.HumanoidRootPart.Position, GOLD, 25, 40)
			end
		end
	end)
	sparkE.Rate = 0
	shrinkBeams(edge, 0.15)
	-- jejak tebasan panjang yang membelah langit
	local tiltDir = (CFrame.lookAt(center, center + dir) * tilt * CFrame.Angles(0, math.rad(10), 0)).LookVector
	local ba, bb = att(center - tiltDir * 130, 2), att(center + tiltDir * 130, 2)
	local bGlow = beam(ba, bb, 14, 14, GOLD_SEQ, nseq({{0, 1}, {0.15, 0.35}, {0.5, 0.15}, {0.85, 0.35}, {1, 1}}), {Segments = 1})
	local bCore = beam(ba, bb, 3.5, 3.5, WHITE, nseq({{0, 1}, {0.2, 0}, {0.8, 0}, {1, 1}}), {Segments = 1})
	shrinkBeams({bGlow, bCore}, 0.6, 0.2)
	shakeNear(center, 1.0, 0.4, 200)

	-- 6) bola dunia: kaca biru, isinya nebula + bintang
	local R0 = 22
	local sphere = Core.part(Vector3.new(2, 2, 2), CFrame.new(center), SKYBLUE, {Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Transparency = 0})
	local inner = Core.part(Vector3.new(2, 2, 2), CFrame.new(center), Color3.fromRGB(30, 50, 110), {Shape = Enum.PartType.Ball, Material = Enum.Material.Glass, Transparency = 0.8})
	local rim = Core.part(Vector3.new(0.6, 2, 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), SKYBLUE, {Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Transparency = 0})
	TS:Create(sphere, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = Vector3.one * R0 * 2}):Play()
	TS:Create(inner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = Vector3.one * R0 * 1.92}):Play()
	TS:Create(rim, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = Vector3.new(0.6, R0 * 2.9, R0 * 2.9)}):Play()
	local neb = holder(CFrame.new(center), Vector3.one * R0 * 1.5, Enum.PartType.Ball, 4)
	local nebE = emitter(neb, {Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Texture = TEX_SMOKE, Color = cseq({{0, VIOLET}, {0.5, Color3.fromRGB(90, 140, 255)}, {1, Color3.fromRGB(120, 255, 230)}}), Size = nseq({{0, 8}, {1, 18}}), Transparency = nseq({{0, 1}, {0.3, 0.3}, {1, 1}}), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.5, 2), RotSpeed = NumberRange.new(-40, 40), LightEmission = 1, Rate = 70})
	nebE:Emit(40)
	local starE = emitter(neb, {Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Color = ColorSequence.new(WHITE), Size = nseq({{0, 0.5}, {1, 0}}), Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0, 1), Rate = 80})
	for _, m in Core.enemiesInRadius(center, R0 + 4) do m:SetAttribute("StunUntil", os.clock() + 2.2) end
	task.wait(0.3)

	-- 7) petir retak menjalar di permukaan bola
	for i = 1, 12 do
		crackBolt(center, R0, i % 3 == 0 and GOLD or VIOLET)
		if i % 4 == 0 then shakeNear(center, 0.35, 0.15, 160) end
		task.wait(0.06)
	end
	TS:Create(inner, TweenInfo.new(0.2), {Color = Color3.fromRGB(255, 220, 150), Transparency = 0.25}):Play()
	task.wait(0.12)

	-- 8) satu garis tebasan membelah bola, bola pecah jadi kepingan
	local cutDir = (CFrame.lookAt(center, center + dir) * tilt).RightVector
	local ca, cb = att(center - cutDir * R0 * 1.7, 2), att(center + cutDir * R0 * 1.7, 2)
	local cutCore = beam(ca, cb, 1.6, 1.6, WHITE, nseq({{0, 1}, {0.15, 0}, {0.85, 0}, {1, 1}}), {Segments = 1})
	local cutGlow = beam(ca, cb, 8, 8, GOLD, nseq({{0, 1}, {0.2, 0.3}, {0.8, 0.3}, {1, 1}}), {Segments = 1})
	shrinkBeams({cutCore, cutGlow}, 0.25, 0.08)
	nebE.Rate = 0
	starE.Rate = 0
	sphere:Destroy()
	inner:Destroy()
	Core.fade(rim, 0.3)
	for i = 1, 30 do
		local v = Random.new():NextUnitVector()
		local sz = math.random(3, 7)
		local shard = Core.part(Vector3.new(sz, sz * 0.6, 0.4), CFrame.new(center + v * R0 * 0.9) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), i % 4 == 0 and GOLD or SKYBLUE, {Material = i % 2 == 0 and Enum.Material.Glass or Enum.Material.ForceField, Transparency = 0.1})
		if i % 3 == 0 then
			local s0 = Instance.new("Attachment")
			s0.Position = Vector3.new(0, 0.3, 0)
			s0.Parent = shard
			local s1 = Instance.new("Attachment")
			s1.Position = Vector3.new(0, -0.3, 0)
			s1.Parent = shard
			trail(s0, s1, 0.3, i % 4 == 0 and GOLD_SEQ or ColorSequence.new(SKYBLUE))
		end
		TS:Create(shard, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = shard.CFrame + v * math.random(25, 45) + up * math.random(-5, 10), Transparency = 1}):Play()
		Debris:AddItem(shard, 1.2)
	end
	local boom = holder(CFrame.new(center), Vector3.one * 4, Enum.PartType.Ball, 4)
	emitter(boom, {Color = cseq({{0, WHITE}, {0.4, GOLD}, {1, ORANGE}}), Size = nseq({{0, 1.4}, {1, 0}}), Lifetime = NumberRange.new(0.5, 1.2), Speed = NumberRange.new(40, 85), SpreadAngle = Vector2.new(180, 180), Drag = 2.5}):Emit(160)
	emitter(boom, {Texture = TEX_SMOKE, Color = cseq({{0, Color3.fromRGB(255, 230, 180)}, {0.5, VIOLET}, {1, Color3.fromRGB(70, 90, 160)}}), Size = nseq({{0, 8}, {1, 22}}), Transparency = nseq({{0, 0.35}, {1, 1}}), Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(12, 28), SpreadAngle = Vector2.new(180, 180), Drag = 3, RotSpeed = NumberRange.new(-50, 50), LightEmission = 0.6}):Emit(45)
	emitter(boom, {Texture = TEX_FIRE, Color = GOLD_SEQ, Size = nseq({{0, 6}, {1, 14}}), Transparency = nseq({{0, 0.2}, {1, 1}}), Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(180, 180), Drag = 3}):Emit(30)
	local bl = Instance.new("PointLight")
	bl.Color = GOLD
	bl.Range = 60
	bl.Brightness = 10
	bl.Parent = boom
	TS:Create(bl, TweenInfo.new(1.2), {Brightness = 0}):Play()
	energyRing(center, R0 * 2.2, GOLD, 0.7, 1.4)
	energyRing(center, R0 * 1.6, SKYBLUE, 0.6, 1, (CFrame.lookAt(center, center + dir) * tilt).Rotation * CFrame.Angles(0, math.rad(90), 0))
	energyRing(ground(center) + up * 0.3, R0 * 2, GOLD, 0.8, 0.8)
	for _, m in Core.enemiesInRadius(center, R0 + 6) do Core.dealDamage(plr, m, 130, "ult", 90) end
	shakeNear(center, 2.2, 0.8, 220)
	TS:Create(light, TweenInfo.new(0.6), {Brightness = 0}):Play()

	-- 9) mendarat, debu terhempas
	task.wait(0.5)
	if root.Parent then
		local landTo = ground(root.Position) + up * (hum and hum.HipHeight + root.Size.Y / 2 or 3)
		local from = root.CFrame
		tweenFor(0.25, function(k)
			if root.Parent then root.CFrame = from:Lerp(CFrame.new(landTo) * from.Rotation, k * k) end
		end)
		root.Anchored = false
		energyRing(ground(root.Position) + up * 0.3, 10, GOLD, 0.4, 0.3)
		local landP = holder(CFrame.new(ground(root.Position) + up * 0.5), Vector3.new(6, 0.2, 6), nil, 3)
		emitter(landP, {Texture = TEX_SMOKE, Color = ColorSequence.new(Color3.fromRGB(220, 200, 160)), Size = nseq({{0, 2}, {1, 6}}), Transparency = nseq({{0, 0.5}, {1, 1}}), Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(85, 85), Drag = 4, LightEmission = 0.2}):Emit(24)
	end
end

function Skills.SkySword(plr, char, root, aim)
	local okRun, err = pcall(galaxyBlade, plr, char, root, aim)
	if not okRun then warn("[QiSword] Galaxy Blade error:", err) end
	if root.Parent then root.Anchored = false end
	local av = FX:FindFirstChild("GoldenAvatar")
	if av and not okRun then av:Destroy() end
end

-- H (ultimate, Inner Heaven): telapak langit menekan dari atas
function Skills.HeavenPalm(plr, char, root, aim)
	char:SetAttribute("IFrameUntil", os.clock() + 1.6)
	local d = Core.Data[plr]
	local twin = Core.daoLevel(d.PalmDao) >= 3
	local center = clampAim(root, aim, 50, 20)
	Core.ring(ground(root.Position) + Vector3.new(0, 0.2, 0), 9, GOLD, 1.0, 0.3)
	local tele = Core.disc(center + Vector3.new(0, 0.15, 0), 22, GOLD, 0.7)
	Core.fade(tele, 0.3, nil, 1.3)
	task.wait(0.8)
	local palms = {}
	for _, o in (twin and {Vector3.new(-9, 0, 0), Vector3.new(9, 0, 0)} or {Vector3.zero}) do
		table.insert(palms, {makePalm(7, GOLD), o})
	end
	tweenFor(0.5, function(k)
		local e = k ^ 3
		for _, pr in palms do
			pr[1]:PivotTo(CFrame.new(center + pr[2] + Vector3.new(0, 90 - 87 * e, 0)) * CFrame.Angles(math.rad(-90), 0, 0))
		end
	end)
	Core.ring(center + Vector3.new(0, 0.3, 0), 28, GOLD, 0.6, 1.2)
	Core.ring(center + Vector3.new(0, 0.5, 0), 18, Color3.new(1, 1, 1), 0.35, 0.8)
	Core.sparks(center + Vector3.new(0, 2, 0), GOLD, 60, 55)
	for _, m in Core.enemiesInRadius(center, 22) do
		Core.dealDamage(plr, m, twin and 95 * 1.3 or 95, "palmult", 40)
		m:SetAttribute("StunUntil", os.clock() + 1.2)
	end
	shakeNear(center, 1.8, 0.6, 150)
	for _, pr in palms do fadeModel(pr[1], 0.6, 0.9) end
end
do
	local Lighting = game:GetService("Lighting")

	-- ===== settings =====
	local DRAGON_LENGTH = 75 -- overall size. 75 = default (about 100 studs head to tail). Raise or lower to scale the whole dragon.
	local MOUTH = Vector3.new(0, -0.05, -0.5) -- root-local fraction of root size; -Z = front. Where the breath starts.
	local SFX = { -- placeholders from Roblox's built-in sounds; swap for marketplace ids
		thunder = "rbxasset://sounds/impact_explosion_03.mp3",
		roar = "rbxasset://sounds/uuhhh.mp3",
		whoosh = "rbxasset://sounds/Rocket whoosh 01.wav",
		beam = "rbxasset://sounds/Rocket shot.wav",
		boom = "rbxasset://sounds/impact_explosion_03.mp3",
	}

	-- dragon look and motion (all tweakable)
	local SEGS = 34 -- body segments
	local WAVE_SPEED = 3.4 -- how fast the body ripples (radians per second)
	local WAVE_LEN = 44 -- length of one wave along the body, in studs (at default scale)
	local WAVE_AMP = 4.5 -- how far the body swings side to side, in studs (at default scale)
	local FIN_FLIP = false -- if the mane and back fins point FORWARD instead of back, set this to true
	local BODY = Color3.fromRGB(176, 38, 38)
	local BELLY = Color3.fromRGB(214, 150, 70)
	local DGOLD = Color3.fromRGB(235, 185, 75)
	local BONE = Color3.fromRGB(238, 228, 205)
	local EYE = Color3.fromRGB(255, 225, 90)

	local FIRE = Color3.fromRGB(255, 140, 50)
	local DARK = Color3.fromRGB(35, 32, 38)
	local BLUE = Color3.fromRGB(150, 190, 255)
	local FLAT2 = CFrame.Angles(0, 0, math.rad(90))
	local TEX_SMOKE2 = "rbxasset://textures/particles/smoke_main.dds"
	local TEX_FIRE2 = "rbxasset://textures/particles/fire_main.dds"

	local function sfx(id, pos, vol, speed)
		if not id or id == "" then return end
		local a = Core.part(Vector3.one, CFrame.new(pos), WHITE, {Transparency = 1})
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = vol or 1
		s.PlaybackSpeed = speed or 1
		s.RollOffMinDistance = 60
		s.RollOffMaxDistance = 450
		s.Parent = a
		s:Play()
		Debris:AddItem(a, 6)
	end

	-- ===== REAL DRAGON ROAR (the Skyrim mp3) =====
	-- 1) Upload the mp3 to Roblox: Studio > View > Asset Manager > Audio > Import (or create.roblox.com > Creations > Audio).
	-- 2) When it is approved, copy its asset id and paste it below, e.g. "rbxassetid://123456789".
	-- Leave it "" and the old built-in layered roar is used instead (nothing breaks).
	local ROAR_ID = "rbxassetid://94467976772299"

	-- Everything below follows the loudness of the mp3, so jaw, head shudder and camera shake stay in sync with the sound.
	local ROAR = {
		volume = 6.2, -- loudness of the recording (the mp3 is fairly quiet)
		shake = 1.6, -- camera shake at the loudest part of the roar (0 = off)
		tremor = 1, -- how hard the dragon's head and body shudder while roaring (0 = off)
		step = 0.05, -- seconds between envelope samples
		env = { -- loudness of the mp3 every 0.05 s (0..1), measured from the file
			0.41, 0.37, 0.32, 0.34, 0.48, 0.71, 0.91, 0.96, 0.92, 0.88, 0.87, 0.90,
			0.90, 0.87, 0.82, 0.76, 0.73, 0.74, 0.76, 0.76, 0.74, 0.72, 0.73, 0.75,
			0.75, 0.75, 0.77, 0.78, 0.77, 0.75, 0.71, 0.70, 0.74, 0.80, 0.83, 0.83,
			0.85, 0.86, 0.84, 0.84, 0.83, 0.79, 0.78, 0.78, 0.73, 0.70, 0.72, 0.71,
			0.70, 0.74, 0.77, 0.75, 0.72, 0.70, 0.69, 0.71, 0.79, 0.83, 0.79, 0.76,
			0.75, 0.78, 0.83, 0.85, 0.83, 0.79, 0.79, 0.80, 0.80, 0.83, 0.83, 0.76,
			0.76, 0.84, 0.88, 0.80, 0.69, 0.60, 0.52, 0.47, 0.43, 0.40, 0.43, 0.49,
			0.48, 0.42, 0.37, 0.32, 0.28, 0.26, 0.24, 0.23, 0.23, 0.24, 0.25, 0.26,
			0.24, 0.22, 0.21, 0.22, 0.21, 0.19, 0.20, 0.26, 0.32, 0.36, 0.36, 0.30,
			0.25, 0.25, 0.25, 0.24, 0.25, 0.28, 0.29, 0.27, 0.24, 0.25, 0.28, 0.26,
			0.19, 0.16, 0.18, 0.20, 0.19, 0.15, 0.12, 0.11, 0.11, 0.11, 0.10, 0.10,
			0.10, 0.10, 0.10, 0.10, 0.09, 0.09, 0.10, 0.10, 0.10
		},
	}
	function ROAR.at(t) -- loudness 0..1 at t seconds after the sound started
		local i = t / ROAR.step
		local a = math.floor(i)
		local v0 = ROAR.env[a + 1]
		if not v0 then return 0 end
		local v1 = ROAR.env[a + 2] or v0
		return v0 + (v1 - v0) * (i - a)
	end
	function ROAR.shakeNear(caster, pos, strength, range, maxLen)
		if strength <= 0 then return end
		for _, p in Players:GetPlayers() do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local k = 1
				if p ~= caster then k = 1 - math.clamp((r.Position - pos).Magnitude / range, 0, 1) end
				if k > 0.02 then Remotes.Fx:FireClient(p, "RoarShake", ROAR.env, ROAR.step, strength * k, maxLen) end
			end
		end
	end
	if ROAR_ID ~= "" then -- lets every client download the roar ahead of time so the first cast is not late
		local pre = Instance.new("Sound")
		pre.Name = "DragonRoarPreload"
		pre.SoundId = ROAR_ID
		pre.Volume = 0
		pre.Parent = RS
	end

	-- Dragon roar: several slowed-down, distorted layers plus reverb so it sounds huge and growly.
	local function roar(pos, vol, pitch)
		vol, pitch = vol or 1, pitch or 1
		local anchor = Core.part(Vector3.one, CFrame.new(pos), WHITE, {Transparency = 1})
		local function fx(level, wet, bass)
			return function(s)
				local d = Instance.new("DistortionSoundEffect")
				d.Level = level
				d.Parent = s
				local eq = Instance.new("EqualizerSoundEffect")
				eq.LowGain = bass or 4
				eq.MidGain = -2
				eq.HighGain = -8
				eq.Parent = s
				local rv = Instance.new("ReverbSoundEffect")
				rv.DecayTime = 3.2
				rv.Density = 1
				rv.Diffusion = 1
				rv.DryLevel = 0
				rv.WetLevel = wet
				rv.Parent = s
			end
		end
		local function layer(id, speed, v, delayT, setup)
			task.delay(delayT, function()
				if not anchor.Parent then return end
				local s = Instance.new("Sound")
				s.SoundId = id
				s.Volume = v * vol
				s.PlaybackSpeed = speed * pitch
				s.RollOffMinDistance = 120
				s.RollOffMaxDistance = 700
				if setup then setup(s) end
				s.Parent = anchor
				s:Play()
			end)
		end
		local VOICE = "rbxasset://sounds/uuhhh.mp3"
		local RUMBLE = "rbxasset://sounds/impact_explosion_03.mp3"
		if ROAR_ID ~= "" then
			layer(ROAR_ID, 1, 1.6, 0, fx(0.25, -6, 2))
		else
			layer(VOICE, 0.30, 1.9, 0, fx(0.75, -5, 6))
			layer(VOICE, 0.43, 1.2, 0.12, fx(0.6, -8, 4))
			layer(VOICE, 0.21, 1.5, 0.05, fx(0.5, -4, 10))
		end
		layer(RUMBLE, 0.35, 1.5, 0, fx(0.2, -10, 8))
		layer(SFX.whoosh, 0.55, 0.8, 0.35, nil)
		Debris:AddItem(anchor, 9)
	end

	-- ===== procedural Eastern dragon =====
	-- No mesh and no bones. A long chain of cylinders and balls follows the head along its
	-- path, a travelling sine wave makes the body slither, and the mane, whiskers, legs and
	-- jaw all move every frame. Returns a small handle:
	--   rig.root      invisible part, move THIS to move the dragon (-Z is the front)
	--   rig.Size      size of root (the breath mouth is placed from it)
	--   rig.step(dt)  call once per frame after moving root
	--   rig.place(cf) teleport the whole dragon to cf, body straight behind the head
	--   rig.setAlpha(0..1)  0 = invisible, 1 = fully visible
	--   rig.jaw       0 = closed, 1 = wide open (smoothed automatically)
	--   rig.destroy()
	local function buildDragon()
		local S = DRAGON_LENGTH / 75
		local SPACING = 2.7 * S
		local ANCHOR = Vector3.new(0, 0, 3.0 * S) -- where the neck joins the back of the head
		local HINGE = Vector3.new(0, -1.3 * S, -0.8 * S) -- jaw pivot
		local CYL = CFrame.Angles(0, math.pi / 2, 0) -- cylinders run along X; this lines them up with lookAt
		local function V(x, y, z) return Vector3.new(x * S, y * S, z * S) end

		local model = Instance.new("Model")
		model.Name = "DivineDragon"
		local parts, cfs = {}, {}

		local function add(kind, size, color, mat)
			local p
			if kind == "wedge" then
				p = Instance.new("WedgePart")
			else
				p = Instance.new("Part")
			end
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = true
			if kind == "cyl" then
				p.Shape = Enum.PartType.Cylinder
			elseif kind == "ball" then
				local m = Instance.new("SpecialMesh")
				m.MeshType = Enum.MeshType.Sphere
				m.Parent = p
			end
			p.Size = size
			p.Color = color
			p.Material = mat or Enum.Material.SmoothPlastic
			p.Transparency = 1
			p.Parent = model
			local n = #parts + 1
			parts[n] = p
			cfs[n] = CFrame.new()
			return n
		end

		local function cylBetween(i, a, b, d)
			local dv = b - a
			local len = dv.Magnitude
			if len < 1e-3 then
				b = a + Vector3.new(0, 0, 1e-2)
				len = 1e-2
			end
			parts[i].Size = Vector3.new(len + 0.15 * S, math.max(d, 0.1), math.max(d, 0.1))
			cfs[i] = CFrame.lookAt((a + b) / 2, b) * CYL
		end

		-- invisible root: the motion driver moves this, everything else follows it
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.CanTouch = false
		root.CastShadow = false
		root.Transparency = 1
		root.Size = V(10, 6, 15)
		root.Parent = model
		-- soft dark cloud trail (no glow)
		local e = Instance.new("ParticleEmitter")
		e.Texture = TEX_SMOKE2
		e.Color = ColorSequence.new(Color3.fromRGB(70, 70, 85), Color3.fromRGB(30, 30, 38))
		e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 12 * S), NumberSequenceKeypoint.new(1, 30 * S)})
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Rate = 22
		e.Speed = NumberRange.new(2, 6)
		e.LightInfluence = 1
		e.Parent = root

		-- ----- body: joints 0..SEGS, ball at each joint, cylinder between joints, fin on top -----
		local bp, vp, fr, up = {}, {}, {}, {} -- base path, wavy visual path, forward dir, up dir
		local radius, ballI, cylI, finI, finH = {}, {}, {}, {}, {}
		for i = 0, SEGS do
			local u = i / SEGS
			radius[i] = S * (0.35 + 2.3 * (1 - u) ^ 0.7)
			ballI[i] = add("ball", Vector3.one * radius[i] * 2, BODY)
			if i > 0 then
				cylI[i] = add("cyl", Vector3.one, (i % 2 == 0) and BODY or BELLY)
				local h
				if i <= 14 then
					h = S * (1.2 + 3.0 * (1 - i / 15)) -- mane along the neck
				else
					h = S * (1.1 * (1 - u) + 0.3)
				end
				if i >= SEGS - 6 then
					h = S * (0.8 + (i - (SEGS - 6)) * 0.7) -- flame-like tuft at the tail tip
				end
				finH[i] = h
				finI[i] = add("wedge", Vector3.new(0.32 * S, h, SPACING * 1.6), DGOLD)
			end
		end
		-- cylinders alternate body/belly colour only in a subtle way; make belly slightly darker so it reads as scales
		for i = 1, SEGS do
			if i % 2 == 1 then parts[cylI[i]].Color = BODY:Lerp(BELLY, 0.28) end
		end

		-- ----- legs (4, tucked, paddle gently) -----
		local legs = {}
		for _, def in {{5, 1}, {5, -1}, {9, 1}, {9, -1}, {21, 1}, {21, -1}, {24, 1}, {24, -1}} do
			local L = {joint = def[1], side = def[2], phase = def[1] * 0.7 + (def[2] > 0 and 0 or 1.4)}
			L.upper = add("cyl", Vector3.one, BODY)
			L.lower = add("cyl", Vector3.one, BODY)
			L.paw = add("ball", Vector3.one * 1.1 * S, BODY)
			L.claws = {add("cyl", Vector3.one, BONE), add("cyl", Vector3.one, BONE), add("cyl", Vector3.one, BONE)}
			table.insert(legs, L)
		end

		-- ----- head (static parts in head-local space; jaw parts rotate about HINGE) -----
		local head = {}
		local function hpart(kind, size, lcf, color, isJaw, mat)
			table.insert(head, {i = add(kind, size, color, mat), cf = lcf, jaw = isJaw})
		end
		local function stick(a, b, d, color, isJaw) -- thin cylinder between two head-local points
			local len = (b - a).Magnitude
			hpart("cyl", Vector3.new(len, d, d), CFrame.lookAt((a + b) / 2, b) * CYL, color, isJaw)
		end
		hpart("ball", V(5.6, 5, 7.5), CFrame.new(V(0, 0, 0.2)), BODY) -- skull
		hpart("ball", V(3.7, 2.9, 6.6), CFrame.new(V(0, -0.3, -4.1)), BODY) -- snout
		hpart("ball", V(3.0, 1.4, 6.4), CFrame.new(V(0, -1.9, -3.7)), BELLY, true) -- lower jaw
		for _, sd in {-1, 1} do
			hpart("ball", Vector3.one * 1.15 * S, CFrame.new(V(sd * 2.05, 0.9, -2.5)), EYE, false, Enum.Material.Neon) -- eye
			hpart("ball", V(1.7, 0.8, 2.6), CFrame.new(V(sd * 2.0, 1.7, -2.4)) * CFrame.Angles(0, sd * 0.25, 0), BODY) -- brow ridge
			hpart("ball", Vector3.one * 0.55 * S, CFrame.new(V(sd * 0.75, 0.55, -7.2)), DARK) -- nostril
			stick(V(sd * 0.85, -1.4, -6.4), V(sd * 0.85, -2.9, -6.2), 0.4 * S, BONE, false) -- upper fang
			stick(V(sd * 0.7, -1.7, -5.9), V(sd * 0.7, -0.6, -5.8), 0.3 * S, BONE, true) -- lower fang
			-- antler horns, three segments sweeping back and up
			stick(V(sd * 1.2, 2.0, 0.2), V(sd * 1.7, 3.4, 2.4), 0.85 * S, BONE, false)
			stick(V(sd * 1.7, 3.4, 2.4), V(sd * 2.0, 4.0, 5.2), 0.55 * S, BONE, false)
			stick(V(sd * 2.0, 4.0, 5.2), V(sd * 1.8, 3.9, 6.6), 0.25 * S, BONE, false)
			-- side horn branch
			stick(V(sd * 1.65, 3.3, 2.2), V(sd * 3.1, 3.7, 3.0), 0.3 * S, BONE, false)
		end

		-- ----- whiskers: chains of thin cylinders that flutter and trail behind the head -----
		local whiskers = {}
		local function whisker(start, dir, step, n, phase)
			local W = {start = start, dir = dir.Unit, step = step * S, n = n, phase = phase, idx = {}}
			for j = 1, n do W.idx[j] = add("cyl", Vector3.one, DGOLD) end
			table.insert(whiskers, W)
		end
		for _, sd in {-1, 1} do
			whisker(V(sd * 1.4, -0.1, -6.3), Vector3.new(sd * 0.45, 0.1, 0.9), 2.4, 6, sd * 0.8)
			whisker(V(sd * 0.95, -1.8, -5.0), Vector3.new(sd * 0.3, -0.25, 0.9), 1.6, 4, sd * 1.7 + 1)
		end

		-- ----- the per-frame update -----
		local rig = {root = root, Size = root.Size, jaw = 0}
		local jawS, lastPos = 0, nil

		local function frameOf(i) -- forward (toward head) and up directions at joint i, from the visual path
			local a = vp[math.max(i - 1, 0)]
			local b = vp[math.min(i + 1, SEGS)]
			local f = a - b
			if f.Magnitude < 1e-3 then f = -root.CFrame.LookVector else f = f.Unit end
			local side = f:Cross(Vector3.yAxis)
			if side.Magnitude < 1e-3 then side = Vector3.xAxis else side = side.Unit end
			return f, side:Cross(f)
		end

		function rig.step(dt)
			local t = os.clock()
			local hcf = root.CFrame
			local vel = Vector3.zero
			if lastPos and dt > 0 then vel = (hcf.Position - lastPos) / dt end
			lastPos = hcf.Position
			jawS += (rig.jaw - jawS) * (1 - math.exp(-9 * math.max(dt, 1 / 60)))

			-- 1) base path: every joint follows the one in front at a fixed distance
			bp[0] = hcf:PointToWorldSpace(ANCHOR)
			for i = 1, SEGS do
				local d = bp[i - 1] - bp[i]
				local m = d.Magnitude
				if m < 1e-3 then d, m = -hcf.LookVector, 1 end
				bp[i] = bp[i - 1] - d / m * SPACING
			end

			-- 2) wavy visual path: a wave travels from head to tail, growing toward the tail
			local k = 2 * math.pi / (WAVE_LEN * S)
			for i = 0, SEGS do
				local a = bp[math.max(i - 1, 0)]
				local b = bp[math.min(i + 1, SEGS)]
				local f = a - b
				if f.Magnitude < 1e-3 then f = -hcf.LookVector else f = f.Unit end
				local side = f:Cross(Vector3.yAxis)
				if side.Magnitude < 1e-3 then side = Vector3.xAxis else side = side.Unit end
				local upv = side:Cross(f)
				local u = i / SEGS
				local env = math.clamp(u / 0.28, 0, 1)
				env = env * env * (3 - 2 * env) * (0.55 + 0.45 * u) * (1 + 0.7 * math.max(0, (u - 0.8) / 0.2))
				local amp = WAVE_AMP * S * env
				local ph = t * WAVE_SPEED - i * SPACING * k
				vp[i] = bp[i] + side * (math.sin(ph) * amp) + upv * (math.sin(ph * 0.9 + 1.3) * amp * 0.4)
			end

			-- 3) place the body parts
			for i = 0, SEGS do
				cfs[ballI[i]] = CFrame.new(vp[i])
				if i > 0 then
					cylBetween(cylI[i], vp[i - 1], vp[i], radius[i - 1] + radius[i])
					local f, upv = frameOf(i)
					local fz = FIN_FLIP and -f or f
					local sway = 0.5 + 0.3 * math.sin(t * WAVE_SPEED - i * SPACING * k + 0.8)
					local tilt = FIN_FLIP and sway or -sway
					local base = vp[i] + upv * (radius[i] * 0.75)
					cfs[finI[i]] = CFrame.fromMatrix(base, upv:Cross(fz), upv, fz)
						* CFrame.Angles(tilt, 0, 0) * CFrame.new(0, finH[i] / 2, 0)
				end
			end

			-- 4) legs
			for _, L in legs do
				local i = L.joint
				local f, upv = frameOf(i)
				local jcf = CFrame.fromMatrix(vp[i], f:Cross(upv), upv, -f)
				local sw = math.sin(t * 3.2 + L.phase)
				local r = radius[i]
				local sh = Vector3.new(L.side * r * 0.75, -r * 0.55, 0)
				local kn = sh + V(L.side * 1.5, -0.9, 1.4 + sw * 0.8)
				local paw = kn + V(L.side * 0.7, -1.7, -0.6 + sw * 1.0)
				local shW, knW, pawW = jcf:PointToWorldSpace(sh), jcf:PointToWorldSpace(kn), jcf:PointToWorldSpace(paw)
				cylBetween(L.upper, shW, knW, 0.9 * S)
				cylBetween(L.lower, knW, pawW, 0.7 * S)
				cfs[L.paw] = CFrame.new(pawW)
				for c = 1, 3 do
					local tip = paw + V(L.side * 0.3 + (c - 2) * 0.55, -0.7, -1.1)
					cylBetween(L.claws[c], pawW, jcf:PointToWorldSpace(tip), 0.28 * S)
				end
			end

			-- 5) head, with a small sway and a smooth jaw
			local hf = hcf * CFrame.Angles(math.sin(t * WAVE_SPEED * 0.9 + 0.6) * 0.04, math.sin(t * WAVE_SPEED) * 0.09, 0)
			local jawCF = hf * CFrame.new(HINGE) * CFrame.Angles(-jawS * 0.55, 0, 0) * CFrame.new(-HINGE)
			for _, h in head do
				cfs[h.i] = (h.jaw and jawCF or hf) * h.cf
			end

			-- 6) whiskers flutter, and trail opposite to the direction of travel
			local lv = hcf:VectorToObjectSpace(vel)
			for _, W in whiskers do
				local prev
				for j = 0, W.n do
					local s = j * W.step
					local off = Vector3.new(
						math.sin(t * 2.4 - j * 0.85 + W.phase) * 0.35 * j * S,
						math.sin(t * 1.9 - j * 0.7 + W.phase * 1.7) * 0.3 * j * S,
						0
					)
					local lag = -lv * (0.0035 * j ^ 1.6)
					if lag.Magnitude > 8 * S then lag = lag.Unit * 8 * S end
					local p = hf:PointToWorldSpace(W.start + W.dir * s + off + lag)
					if prev then
						cylBetween(W.idx[j], prev, p, S * (0.32 * (1 - j / (W.n + 1)) + 0.08))
					end
					prev = p
				end
			end

			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end

		function rig.place(cf)
			root.CFrame = cf
			lastPos = nil
			local b0 = cf:PointToWorldSpace(ANCHOR)
			for i = 0, SEGS do
				bp[i] = b0 - cf.LookVector * (i * SPACING)
				vp[i] = bp[i]
			end
			rig.step(0)
		end

		function rig.setAlpha(a)
			local tr = 1 - math.clamp(a, 0, 1)
			for _, p in parts do p.Transparency = tr end
		end

		function rig.points() -- current world positions of the body joints, head to tail
			return vp
		end

		function rig.destroy()
			model:Destroy()
		end

		model.Parent = FX
		return rig
	end

	local function getDragon()
		local ok, res = pcall(buildDragon)
		if not ok then
			warn("[DivineDragon] could not build the dragon: " .. tostring(res))
			return nil
		end
		return res
	end

	local function bolt(top, bottom)
		local prev = top
		for i = 1, 8 do
			local p = top:Lerp(bottom, i / 8) + (i < 8 and Vector3.new(math.random(-7, 7), 0, math.random(-7, 7)) or Vector3.zero)
			local len = (p - prev).Magnitude
			local cf = CFrame.lookAt((prev + p) / 2, p)
			Core.fade(Core.part(Vector3.new(0.6, 0.6, len), cf, WHITE, {}), 0.35, nil, 0.1)
			Core.fade(Core.part(Vector3.new(1.8, 1.8, len), cf, BLUE, {Transparency = 0.7}), 0.4, nil, 0.05)
			prev = p
		end
	end

	local function debris(pos)
		for _ = 1, 16 do
			local s = 1 + math.random() * 2.5
			local r = Instance.new("Part")
			r.Size = Vector3.new(s, s * 0.8, s * 1.2)
			r.Material = Enum.Material.Slate
			r.Color = Color3.fromRGB(70, 64, 60)
			r.CFrame = CFrame.new(pos + Vector3.new(math.random(-8, 8), 1, math.random(-8, 8))) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
			r.CanQuery = false
			r.CanTouch = false
			r.Parent = FX
			r.AssemblyLinearVelocity = Vector3.new(math.random(-40, 40), 50 + math.random(30), math.random(-40, 40))
			r.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
			Debris:AddItem(r, 3)
		end
		local sc = Core.part(Vector3.new(0.15, 56, 56), CFrame.new(pos + Vector3.new(0, 0.12, 0)) * FLAT2, DARK, {Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate, Transparency = 0.2})
		Core.fade(sc, 2.5, nil, 3)
	end

	-- big billow of dust thrown up by the crash
	local function dust(pos)
		local h = Core.part(Vector3.one, CFrame.new(pos + Vector3.new(0, 3, 0)), DARK, {Transparency = 1})
		local d = Instance.new("ParticleEmitter")
		d.Texture = TEX_SMOKE2
		d.Color = ColorSequence.new(Color3.fromRGB(125, 108, 90), Color3.fromRGB(70, 62, 55))
		d.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
		d.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 44)})
		d.Lifetime = NumberRange.new(2, 3.4)
		d.Speed = NumberRange.new(30, 75)
		d.SpreadAngle = Vector2.new(80, 80)
		d.Rate = 0
		d.LightInfluence = 1
		d.Parent = h
		d:Emit(70)
		Debris:AddItem(h, 6)
	end

	-- glowing cracks spreading out from the crash site
	local function cracks(pos)
		for i = 1, 14 do
			local a = (i / 14) * math.pi * 2 + math.random() * 0.35
			local len = 24 + math.random() * 34
			local dv = Vector3.new(math.cos(a), 0, math.sin(a))
			local mid = pos + dv * (len / 2) + Vector3.new(0, 0.18, 0)
			local tip = pos + dv * len + Vector3.new(0, 0.18, 0)
			local dark = Core.part(Vector3.new(2.6, 0.2, len), CFrame.lookAt(mid, tip), DARK, {Material = Enum.Material.Slate})
			Core.fade(dark, 4, nil, 3)
			local glow = Core.part(Vector3.new(0.9, 0.25, len * 0.92), CFrame.lookAt(mid + Vector3.new(0, 0.05, 0), tip), FIRE, {Material = Enum.Material.Neon})
			Core.fade(glow, 3, nil, 1.8)
		end
	end

	function Skills.DivineDragon(plr, char, root, aim)
		char:SetAttribute("IFrameUntil", os.clock() + 7)
		local dir = flatDir(root.Position, aim or (root.Position + root.CFrame.LookVector * 40), root.CFrame.LookVector)
		local target = ground(clampAim(root, aim, 70, 32))
		local right = dir:Cross(Vector3.yAxis).Unit

		-- ===== 1) the sky darkens and tears open =====
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Parent = Lighting
		local function grade(t, props) TS:Create(cc, TweenInfo.new(t), props):Play() end
		grade(0.8, {Brightness = -0.12, Contrast = 0.2, Saturation = -0.3, TintColor = Color3.fromRGB(190, 205, 255)})
		Remotes.Fx:FireClient(plr, "DragonUlt", root.Position, target, dir)

		local cloudPart = Core.part(Vector3.new(90, 2, 90), CFrame.new(target + Vector3.new(0, 110, 0)), DARK, {Transparency = 1})
		local clouds = Instance.new("ParticleEmitter")
		clouds.Texture = TEX_SMOKE2
		clouds.Color = ColorSequence.new(DARK)
		clouds.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.5), NumberSequenceKeypoint.new(0.8, 0.6), NumberSequenceKeypoint.new(1, 1)})
		clouds.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 50), NumberSequenceKeypoint.new(1, 95)})
		clouds.Lifetime = NumberRange.new(5, 7)
		clouds.Rate = 14
		clouds.Speed = NumberRange.new(1, 3)
		clouds.Rotation = NumberRange.new(0, 360)
		clouds.RotSpeed = NumberRange.new(-8, 8)
		clouds.LightInfluence = 0.6
		clouds.Parent = cloudPart
		clouds:Emit(30)
		sfx(SFX.thunder, target + Vector3.new(0, 80, 0), 1.2, 0.55)
		shakeNear(target, 0.4, 1.2, 200)
		task.wait(0.8)

		for i = 1, 3 do
			local a = i / 3 * math.pi * 2 + math.random()
			local gp = ground(target + Vector3.new(math.cos(a) * 38, 0, math.sin(a) * 38))
			bolt(gp + Vector3.new(0, 110, 0), gp)
			sfx(SFX.thunder, gp, 0.9, 0.8 + math.random() * 0.3)
			Core.sparks(gp + Vector3.new(0, 1, 0), BLUE, 12, 25)
			shakeNear(gp, 0.5, 0.25, 150)
			task.wait(0.28)
		end

		-- ===== 2) the dragon bursts out of the clouds =====
		local dragon = getDragon()
		local sizeV = dragon and dragon.Size or Vector3.new(10, 6, 15)
		local hover = target + Vector3.new(0, 55, 0) - dir * 18
		local startP = root.Position - dir * 70 + Vector3.new(0, 135, 0)
		-- smooth motion driver: spring toward goalPos, eased turning, banking,
		-- pitch from climb/dive speed, plus gentle wing-beat bob. All phases only
		-- change the goals, so there are no hard hand-offs between moves.
		local pos, vel = startP, Vector3.zero
		local look = (hover - startP).Unit
		local goalPos, goalLook, follow = startP, dir, true
		local manual, lookRate = false, 3.5 -- manual = skip the spring (used for the dive)
		local rollS, pitchS, rear = 0, 0, 0
		local tremor, roarLive = 0, false -- roar shudder (0..1) and "the mp3 roar owns the jaw right now"
		local t0 = os.clock()
		local K = 6
		local driver
		local function mouth()
			if dragon then return (dragon.root.CFrame * CFrame.new(sizeV * MOUTH)).Position end
			return hover
		end
		if dragon then
			dragon.place(CFrame.lookAt(startP, startP + look))
			task.spawn(tweenFor, 0.5, function(k) dragon.setAlpha(k) end)
			driver = RunS.Heartbeat:Connect(function(dt)
				dt = math.min(dt, 0.05)
				if not manual then
					vel += ((goalPos - pos) * K - vel * (2 * math.sqrt(K))) * dt
					pos += vel * dt
				end
				if follow and vel.Magnitude > 6 then goalLook = vel.Unit end
				look = look:Lerp(goalLook, 1 - math.exp(-lookRate * dt)).Unit
				local side = look:Cross(Vector3.yAxis)
				side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
				rollS += (math.clamp(-vel:Dot(side) * 0.012, -0.5, 0.5) - rollS) * (1 - math.exp(-4 * dt))
				pitchS += (math.clamp(vel.Y * 0.008, -0.35, 0.35) - pitchS) * (1 - math.exp(-4 * dt))
				local t = os.clock() - t0
				local p2 = pos + Vector3.new(0, math.sin(t * 2.2) * 1.4, 0)
				local tr = tremor
				if tr > 0.01 then -- roaring: the whole body shudders
					p2 += Vector3.new(math.noise(t * 17, 1.3, 0), math.noise(t * 19, 2.7, 0), math.noise(t * 15, 4.1, 0)) * (tr * 2.4)
				end
				dragon.root.CFrame = CFrame.lookAt(p2, p2 + look) * CFrame.Angles(pitchS + rear + math.noise(t * 23, 5.5, 0) * tr * 0.09, math.noise(t * 21, 7.7, 0) * tr * 0.06, rollS + math.sin(t * 3.4) * 0.05 + math.noise(t * 25, 9.1, 0) * tr * 0.08)
				dragon.step(dt)
			end)
		end

		-- ===== roar playback: jaw, shudder and camera shake all follow the mp3's loudness =====
		local roarConn, roarSnd, roarAnchor
		local function endRoar(fade)
			if roarConn then roarConn:Disconnect() roarConn = nil end
			tremor, roarLive = 0, false
			if dragon then dragon.jaw = 0 end
			if roarSnd and roarSnd.Parent then
				TS:Create(roarSnd, TweenInfo.new(fade or 0.4), {Volume = 0}):Play()
				Debris:AddItem(roarAnchor, (fade or 0.4) + 0.2)
			end
			roarSnd, roarAnchor = nil, nil
		end
		local function beginRoar(vol, atPos, maxLen)
			if ROAR_ID == "" then
				roar(atPos or hover, vol, 1) -- built-in layered roar
				return
			end
			if roarConn then endRoar(0.1) end
			local anchor = Core.part(Vector3.one, CFrame.new(atPos or hover), WHITE, {Transparency = 1})
			Debris:AddItem(anchor, 12)
			local s = Instance.new("Sound")
			s.SoundId = ROAR_ID
			s.Volume = ROAR.volume * vol
			s.RollOffMinDistance = 150
			s.RollOffMaxDistance = 800
			local eq = Instance.new("EqualizerSoundEffect") -- a little chest weight
			eq.LowGain = 3
			eq.MidGain = 0
			eq.HighGain = -2
			eq.Parent = s
			local rv = Instance.new("ReverbSoundEffect") -- big open-sky tail
			rv.DecayTime = 2.6
			rv.Density = 1
			rv.Diffusion = 1
			rv.DryLevel = 0
			rv.WetLevel = -9
			rv.Parent = s
			s.Parent = anchor
			s:Play()
			roarSnd, roarAnchor, roarLive = s, anchor, true
			local t0 = os.clock()
			ROAR.shakeNear(plr, target, ROAR.shake * vol, 320, maxLen)
			sfx(SFX.boom, atPos or hover, 0.9 * vol, 0.35) -- deep thump under the roar
			local conn
			conn = RunS.Heartbeat:Connect(function()
				local e = ROAR.at(os.clock() - t0)
				tremor = e * ROAR.tremor
				if dragon then
					dragon.jaw = math.clamp(0.12 + e, 0, 1) -- mouth opens with the sound
					if roarAnchor then roarAnchor.CFrame = CFrame.new(mouth()) end -- sound comes from the mouth
				end
			end)
			roarConn = conn
			task.delay(9, function() if roarConn == conn then endRoar(0.3) end end) -- safety net
		end

		-- entry: wide curving swoop out of the clouds, then settle at the hover point
		sfx(SFX.whoosh, startP, 1.2, 0.8)
		goalPos = startP + (hover - startP) * 0.5 + right * 50
		task.wait(0.8)
		goalPos = hover
		task.wait(0.4)
		follow, goalLook = false, dir
		task.wait(0.5)

		-- ===== 3) the roar =====
		beginRoar(1)
		Core.ring(hover - Vector3.new(0, 6, 0), 70, Color3.fromRGB(220, 230, 255), 0.8, 0.5)
		if not roarLive then shakeNear(target, 1.3, 1.1, 250) end
		grade(0.6, {Brightness = -0.2})
		tweenFor(1.0, function(k)
			rear = math.sin(k * math.pi) * 0.35 -- head lifts back while roaring
			if dragon and not roarLive then dragon.jaw = math.sin(k * math.pi) end -- mouth opens and closes
		end)

		-- ===== 4) it rears back and gathers golden energy in its mouth =====
		local impact = target + Vector3.new(0, 4, 0)
		Core.fade(Core.disc(target + Vector3.new(0, 0.25, 0), 34, Color3.fromRGB(255, 70, 50), 0.7), 2.2, nil, 0.1) -- red warning circle
		if dragon and not roarLive then dragon.jaw = 0.7 end
		follow = false
		goalPos = hover + Vector3.new(0, 14, 0) - dir * 10
		goalLook = (dir * 0.6 + Vector3.yAxis * 0.5).Unit
		local orb = Core.part(Vector3.one * 2, CFrame.new(mouth()), GOLD, {Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Transparency = 0.15})
		local nextSpark = 0
		tweenFor(0.6, function(k)
			rear = 0.35 + k * 0.3 -- head tilts up
			orb.Size = Vector3.one * (2 + 12 * k)
			orb.CFrame = CFrame.new(mouth())
			if k >= nextSpark then
				nextSpark += 0.25
				Core.sparks(mouth(), GOLD, 10, 30)
			end
		end)
		if not roarLive then roar(hover, 0.8, 1.25) end -- with the mp3 the first roar keeps going through the gather and the spiral
		Core.fade(orb, 0.25)

		-- ===== 5) it spirals down around the target, then plunges =====
		manual, lookRate = true, 9
		sfx(SFX.whoosh, hover, 1.6, 0.5)
		local rel = pos - target
		local r0 = math.max(Vector3.new(rel.X, 0, rel.Z).Magnitude, 8)
		local th0 = math.atan2(rel.Z, rel.X)
		local y0 = pos.Y
		local yEnd = impact.Y + 28
		local spiralT = 1.2
		tweenFor(spiralT, function(k)
			local e = k * k * (3 - 2 * k)
			local th = th0 + e * math.pi * 2.2
			local r = r0 + (24 - r0) * e
			local np = Vector3.new(target.X + math.cos(th) * r, y0 + (yEnd - y0) * e, target.Z + math.sin(th) * r)
			local step = np - pos
			if step.Magnitude > 0.01 then goalLook = step.Unit end
			vel = step / math.max(1 / 60, 0.016)
			pos = np
			rear = 0.3 * (1 - e)
		end)
		if dragon and not roarLive then dragon.jaw = 1 end
		local diveA = pos
		local diveV = impact - diveA
		local diveT = 0.35
		goalLook = diveV.Unit
		lookRate = 14
		tweenFor(diveT, function(k)
			pos = diveA + diveV * (k * k)
			vel = diveV * (2 * k / diveT)
		end)
		vel = Vector3.zero
		endRoar(0.5) -- the impact cuts the roar off
		if dragon then dragon.jaw = 0 end

		-- ===== 6) the crash =====
		grade(0.1, {Brightness = 0.4, Contrast = 0, Saturation = 0, TintColor = Color3.fromRGB(255, 235, 200)})
		task.delay(0.15, function()
			grade(1.6, {Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE})
		end)
		sfx(SFX.boom, target, 2, 0.45)
		sfx(SFX.boom, target, 1.6, 0.7)
		for i = 1, 4 do
			task.delay(i * 0.07, function()
				Core.ring(target + Vector3.new(0, 0.4, 0), 18 + i * 14, i == 1 and WHITE or FIRE, 0.7, 1.4)
			end)
		end
		Core.sparks(target + Vector3.new(0, 2, 0), FIRE, 90, 80)
		debris(target)
		task.delay(0.12, function() debris(target) end)
		dust(target)
		cracks(target)
		shakeNear(target, 3.2, 1.3, 300)
		for _, m in Core.enemiesInRadius(target, 34) do
			Core.dealDamage(plr, m, 260, "dragonult", 90)
			m:SetAttribute("StunUntil", os.clock() + 2)
		end
		-- aftershock as the long body slams down behind the head
		task.delay(0.45, function()
			sfx(SFX.boom, target, 1.2, 0.55)
			Core.ring(target + Vector3.new(0, 0.4, 0), 70, FIRE, 0.8, 1.2)
			shakeNear(target, 1.6, 0.6, 250)
			for _, m in Core.enemiesInRadius(target, 48) do
				Core.dealDamage(plr, m, 90, "dragonult", 40)
				m:SetAttribute("StunUntil", os.clock() + 1.2)
			end
		end)
		task.wait(0.8)

		-- ===== 7) the dragon bursts into golden light and rises to the heavens =====
		if dragon then
			local pts = dragon.points()
			local nextBurst = 0
			tweenFor(1.5, function(k)
				dragon.setAlpha(1 - k)
				if k >= nextBurst then
					nextBurst += 0.17
					for i = 0, 34, 3 do
						if pts[i] then Core.sparks(pts[i], GOLD, 7, 40) end
					end
				end
			end)
			driver:Disconnect()
			dragon.destroy()
		else
			task.wait(1)
		end
		clouds.Enabled = false
		Debris:AddItem(cloudPart, 8)
		Debris:AddItem(cc, 2.5)
	end
end

-- ===== Petir (tribulasi, uji Dao, serangan monster) =====
function Core.lightning(pos, radius, dmg, warnT, color)
	color = color or PURPLE
	local g = ground(pos)
	local tele = Core.disc(g + Vector3.new(0, 0.2, 0), radius, Color3.fromRGB(255, 60, 60), 0.6)
	local inner = Core.part(Vector3.new(0.25, 0.5, 0.5), tele.CFrame, Color3.fromRGB(255, 60, 60), {Shape = Enum.PartType.Cylinder, Transparency = 0.3})
	TS:Create(inner, TweenInfo.new(warnT, Enum.EasingStyle.Linear), {Size = Vector3.new(0.25, radius * 2, radius * 2)}):Play()
	task.wait(warnT)
	tele:Destroy()
	inner:Destroy()
	local top = g + Vector3.new(math.random(-6, 6), 90, math.random(-6, 6))
	local prev = top
	for i = 1, 8 do
		local nextP = top:Lerp(g, i / 8) + (i < 8 and Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)) or Vector3.zero)
		local len = (nextP - prev).Magnitude
		local cf = CFrame.lookAt((prev + nextP) / 2, nextP)
		Core.fade(Core.part(Vector3.new(0.8, 0.8, len), cf, Color3.new(1, 1, 1), {}), 0.25, nil, 0.08)
		Core.fade(Core.part(Vector3.new(2.2, 2.2, len), cf, color, {Transparency = 0.5}), 0.3, nil, 0.05)
		prev = nextP
	end
	Core.ring(g + Vector3.new(0, 0.3, 0), radius + 2, color, 0.3, 0.5)
	Core.sparks(g + Vector3.new(0, 1, 0), color, 25, 35)
	shakeNear(g, 0.5, 0.2, 40)
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and (Vector3.new(r.Position.X, g.Y, r.Position.Z) - g).Magnitude <= radius + 1 and math.abs(r.Position.Y - g.Y) < 12 then
			Core.damagePlayer(c, dmg, nil, true)
		end
	end
end

Core.InTrial = {}
function Core.runTrial(plr, center, radius, waves, dmg, onSuccess, onFail)
	if Core.InTrial[plr] then return end
	Core.InTrial[plr] = true
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local failed = false
	local function check()
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health <= 0 or not char.Parent then return "You fell to the lightning..." end
		if not r or (Vector3.new(r.Position.X, center.Y, r.Position.Z) - center).Magnitude > radius + 10 then return "You fled the tribulation..." end
	end
	Remotes.Fx:FireClient(plr, "Storm", true)
	Remotes.Fx:FireClient(plr, "Banner", "The heavens are angered...", PURPLE)
	task.wait(2)
	for w, count in waves do
		Remotes.Fx:FireClient(plr, "Banner", "Lightning Wave " .. w .. " / " .. #waves, PURPLE)
		task.wait(1.2)
		for i = 1, count do
			failed = check() or false
			if failed then break end
			local r = char.HumanoidRootPart
			local target
			if i % 2 == 1 then
				target = r.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
			else
				target = center + Vector3.new(math.random(-radius, radius) * 0.8, 0, math.random(-radius, radius) * 0.8)
			end
			task.spawn(Core.lightning, target, 5, dmg, 1.1 - w * 0.1)
			task.wait(0.6 - w * 0.08)
		end
		if failed then break end
		task.wait(1.8)
		failed = check() or false
		if failed then break end
	end
	Remotes.Fx:FireClient(plr, "Storm", false)
	Core.InTrial[plr] = nil
	if failed then onFail(failed) else onSuccess() end
end

function Core.startTribulation(plr)
	local d = Core.Data[plr]
	if not d or not plr:GetAttribute("TribReady") then
		Remotes.Dialog:FireClient(plr, "Tribulation Arena", "Your qi has not reached its Peak. Cultivate until your realm reaches the Peak stage.")
		return
	end
	if d.Stage == 6 and Core.daoLevel(d.SwordDao) < 1 and Core.daoLevel(d.PalmDao) < 1 then
		Remotes.Dialog:FireClient(plr, "Tribulation Arena", "Inner Heaven demands insight. Reach Sword Dao or Palm Dao Level 1 first.")
		return
	end
	local center = workspace.World.AzureCloudSect.TribulationCenter.Position
	local waves = d.Stage == 3 and {5, 7, 10} or {7, 9, 12}
	local tdmg = 6 + d.Stage * 2
	if d.Race == "Celestial" then
		-- langit cemburu: tiap gelombang lebih banyak petir dan lebih sakit
		for i, n in waves do waves[i] = n + 3 end
		tdmg = math.floor(tdmg * Core.race(plr).trib + 0.5)
		Remotes.Fx:FireClient(plr, "Banner", "The heavens envy the Celestial-born...", GOLD)
	end
	Core.runTrial(plr, center, 18, waves, tdmg, function()
		d.Stage += 1
		d.Qi = 0
		plr:SetAttribute("TribReady", false)
		Core.onBreakthrough(plr, true)
	end, function(why)
		d.Qi = math.floor(d.Qi * 0.7)
		plr:SetAttribute("TribReady", false)
		Core.sync(plr)
		Remotes.Fx:FireClient(plr, "Banner", why .. " 30% qi lost", Color3.fromRGB(255, 120, 120))
	end)
end

function Core.startDaoTrial(plr)
	local d = Core.Data[plr]
	if not d then return end
	if d.Stage < 4 then
		Remotes.Dialog:FireClient(plr, "Storm Peak", "The storm would tear you apart. Reach Soul Spring first.")
		return
	end
	if os.clock() < (plr:GetAttribute("DaoTrialCD") or 0) then
		Remotes.Dialog:FireClient(plr, "Storm Peak", "The storm is resting. Return a little later.")
		return
	end
	plr:SetAttribute("DaoTrialCD", os.clock() + 180)
	local center = workspace.World.MistyValley.DaoTrialSite.Position - Vector3.new(0, 2, 0)
	Core.runTrial(plr, center, 7, {4, 6, 8}, 18, function()
		local key = d.SwordDao >= d.PalmDao and "SwordDao" or "PalmDao"
		Core.addDao(plr, key, 100)
		Remotes.Fx:FireClient(plr, "Banner", "Storm Peak conquered! Your Dao deepens.", GOLD)
	end, function(why)
		Remotes.Fx:FireClient(plr, "Banner", why, Color3.fromRGB(255, 120, 120))
	end)
end

-- ===== NPC =====
function Core.barter(plr)
	local d = Core.Data[plr]
	local total, count = 0, 0
	for name, n in d.Mats do
		local rar = Core.ITEM_RARITY[name]
		if rar and rar ~= "Legendary" then
			total += Core.MAT_VALUE[rar] * n
			count += n
			d.Mats[name] = nil
		end
	end
	if count == 0 then
		Remotes.Dialog:FireClient(plr, "Merchant Lin", "Bring me beast materials from the forest and valley. I pay in Qi Pills.")
		return
	end
	Core.addQi(plr, total)
	Remotes.Dialog:FireClient(plr, "Merchant Lin", ("Fine goods! %d materials for Qi Pills worth %d qi."):format(count, total))
end

function Core.elderLine(plr, default)
	local d = Core.Data[plr]
	if d and d.Race == "Demon" and math.random() < 0.5 then
		return "Hmph. I smell demonic qi on you, disciple. Walk carefully in this sect. " .. (default or "")
	end
	if plr:GetAttribute("TribReady") then
		return "Your qi has peaked. Enter the Tribulation Arena east of the hall and endure the heavenly lightning!"
	elseif d and (d.Mats["Sword Shard"] or 0) > 0 then
		return "The Sword Shard! The legend is true. Keep growing, disciple. More pieces sleep in lands not yet opened."
	elseif d and d.Stage >= 7 then
		return "Inner Heaven! Now face the Dragon Guardian in the Old Dragon Cave, south beyond the forest."
	elseif d and d.Stage >= 4 then
		return "Soul Spring! You can ride your sword now (press B). Fly east to the Misty Valley and seek the Storm Peak trial."
	end
	return default
end

return Core