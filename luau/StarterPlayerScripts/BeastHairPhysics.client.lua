-- Fisika rambut & ekor (spring bone, client) untuk monster Demon & Kuda Langit. Taruh di StarterPlayerScripts.
-- Model yang diberi tag CollectionService "HairPhysics" akan disimulasikan: tulang rambut ("HairNN_k", "ManeN", "Fore")
-- dan ekor ("Tail", "TailN") punya titik ujung yang tertinggal (inersia), ditarik pegas ke pose diam, kena gravitasi,
-- angin & hambatan udara (tersibak ke belakang saat berlari), lalu tulang diputar ke arah titik itu.
-- Atribut model "PhysProfile" memilih setelan (default: monster; "Steed": kuda). Hanya model dekat kamera yang dihitung.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local PROFILES = {
	Default = {
		Hair = {stiff = 55, damp = 0.86, gravity = 18, wind = 2.5, drag = 0.35, maxAngle = math.rad(70)},
		Tail = {stiff = 90, damp = 0.9, gravity = 6, wind = 0.6, drag = 0.15, maxAngle = math.rad(35)},
	},
	Sword = {   -- rumbai pedang terbang: lemas, menjuntai karena gravitasi, berkibar kuat saat terbang
		Hair = {stiff = 14, damp = 0.85, gravity = 30, wind = 1.5, drag = 1.2, maxAngle = math.rad(85)},
		Tassel = {stiff = 14, damp = 0.85, gravity = 30, wind = 1.5, drag = 1.2, maxAngle = math.rad(85)},
	},
	Steed = {   -- surai & ekor kuda: lebih lentur, tersibak kuat saat gallop
		Hair = {stiff = 38, damp = 0.88, gravity = 5, wind = 1.6, drag = 0.8, maxAngle = math.rad(60)},
		Tail = {stiff = 32, damp = 0.9, gravity = 4, wind = 1.0, drag = 1.2, maxAngle = math.rad(55)},
		Tassel = {stiff = 45, damp = 0.82, gravity = 14, wind = 0.8, drag = 0.3, maxAngle = math.rad(45)},   -- rumbai ban dada
	},
}
local MAX_DIST = 180
local rigs = {}
local lastPos = {}

local function kindOf(name)
	if name:match("^Hair") or name:match("^Mane") or name == "Fore" then return "Hair" end
	if name:match("^Tail") then return "Tail" end
	if name:match("^Tassel") then return "Tassel" end
end

local function parentWorld(b)
	local p = b.Parent
	if p:IsA("Bone") then
		return p.TransformedWorldCFrame
	end
	return p.CFrame
end

local function build(model)
	local chains = {}
	local s0 = model:GetScale()
	for _, b in model:GetDescendants() do
		if b:IsA("Bone") then
			local kind = kindOf(b.Name)
			if kind then
				-- vektor ujung dalam ruang lokal tulang: ke anak tulang sejenis, atau lanjutan ruas sebelumnya (ruas terakhir)
				local child
				for _, c in b:GetChildren() do
					if c:IsA("Bone") and kindOf(c.Name) == kind then
						child = c
					end
				end
				local w = b.TransformedWorldCFrame
				local tip
				if child then
					tip = child.CFrame.Position
				else
					local prev = b.Parent:IsA("Bone") and kindOf(b.Parent.Name) == kind and b.Parent.TransformedWorldCFrame.Position
					if prev and (w.Position - prev).Magnitude > 0.3 then
						tip = w:VectorToObjectSpace(w.Position - prev)
					else
						-- tulang tunggal (rumbai / jambul): menjuntai ke bawah dari pangkalnya
						tip = w:VectorToObjectSpace(Vector3.new(0, kind == "Tassel" and -0.9 or -1.6, 0))
					end
				end
				if tip.Magnitude > 1e-3 then
					table.insert(chains, {bone = b, kind = kind, tip = tip, len = tip.Magnitude,
						p = w * tip, v = Vector3.zero, depth = #b:GetFullName(), s0 = s0})
				end
			end
		end
	end
	table.sort(chains, function(a, c) return a.depth < c.depth end)   -- induk dulu, baru anak
	return chains
end

local function track(model)
	task.spawn(function()             -- StreamingEnabled: tunggu tulang ter-stream ke client
		for _ = 1, 60 do
			if not model.Parent then return end
			local ch = build(model)
			if #ch > 0 then
				task.wait(0.5)
				rigs[model] = build(model)
				return
			end
			task.wait(1)
		end
	end)
end
for _, m in CollectionService:GetTagged("HairPhysics") do
	track(m)
end
CollectionService:GetInstanceAddedSignal("HairPhysics"):Connect(track)
CollectionService:GetInstanceRemovedSignal("HairPhysics"):Connect(function(m) rigs[m] = nil end)

local t = 0
RunService:BindToRenderStep("BeastHairPhysics", Enum.RenderPriority.Camera.Value + 1, function(dt)
	dt = math.min(dt, 1 / 30)
	t += dt
	local cam = workspace.CurrentCamera.CFrame.Position
	for model, chains in rigs do
		if not model.Parent then
			rigs[model], lastPos[model] = nil, nil
			continue
		end
		local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if not pp or (pp.Position - cam).Magnitude > MAX_DIST then
			continue
		end
		local P = PROFILES[model:GetAttribute("PhysProfile") or "Default"] or PROFILES.Default
		local scale = model:GetScale()
		-- kecepatan model dari perpindahan (juga benar untuk kuda anchored yang digeser server saat datang)
		local last = lastPos[model]
		local vel = last and (pp.Position - last) / dt or Vector3.zero
		lastPos[model] = pp.Position
		if vel.Magnitude > 400 then vel = Vector3.zero end            -- teleport
		local windDir = Vector3.new(math.sin(t * 0.7), 0, math.cos(t * 0.5)).Unit
		for _, c in chains do
			local S = P[c.kind] or P.Hair
			local b = c.bone
			local rest = parentWorld(b) * b.CFrame                         -- tulang tanpa putaran fisika
			local head = rest.Position
			local k = scale / c.s0                                        -- model di-ScaleTo setelah dibangun
			local target = rest * (c.tip * k)
			local gust = (0.6 + 0.4 * math.noise(t * 0.8, c.depth * 0.13)) * S.wind
			local acc = (target - c.p) * S.stiff + (Vector3.new(0, -S.gravity, 0) + windDir * gust) * c.len * k   -- relatif panjang ruas
				- vel * S.drag * S.stiff * 0.02                                -- hambatan udara: tersibak berlawanan arah gerak
			-- peredam relatif terhadap gerak model: diam relatif saat lari konstan, tersentak saat mulai/berhenti/belok
			c.v = vel + (c.v - vel) * S.damp + acc * dt
			c.p += c.v * dt
			local d = c.p - head                                           -- jaga panjang ruas tetap
			if d.Magnitude < 1e-4 then
				d = target - head
			end
			c.p = head + d.Unit * c.len * k
			local want = rest:VectorToObjectSpace(c.p - head).Unit
			local base = c.tip.Unit
			local ang = math.acos(math.clamp(base:Dot(want), -1, 1))
			if ang > S.maxAngle then                                       -- batasi tekukan supaya tidak menembus tubuh
				local axis = base:Cross(want)
				if axis.Magnitude > 1e-4 then
					want = CFrame.fromAxisAngle(axis.Unit, S.maxAngle) * base
				end
				c.p = head + rest:VectorToWorldSpace(want) * c.len * k
			end
			b.Transform = CFrame.fromRotationBetweenVectors(base, want)
		end
	end
end)
