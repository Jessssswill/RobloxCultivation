-- LocalScript: StarterPlayer.StarterPlayerScripts.WeaponSkillClient
-- Input Z/X/G saat pedang ber-Element dipegang, cut-in ultimate, bar cooldown kecil,
-- dan semua efek skill pedang (dikirim server lewat QiRemotes.WeaponFx).
-- Efek dibuat dari Part + ParticleEmitter bawaan, semua dihapus otomatis. Efek yang jauh dari kamera dilewati biar gak lag.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunS = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local KSP = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local mouse = player:GetMouse()
local R = RS:WaitForChild("QiRemotes")
local SkillRemote = R:WaitForChild("WeaponSkill")
local FxRemote = R:WaitForChild("WeaponFx")
local Anims = RS:FindFirstChild("QiAnims")

local KC = Enum.KeyCode
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local MAX_DIST = 320

local THEME = {
	Thunder = {a = Color3.fromRGB(235, 245, 255), b = Color3.fromRGB(90, 170, 255), c = Color3.fromRGB(45, 50, 80)},
	Ice = {a = Color3.fromRGB(240, 252, 255), b = Color3.fromRGB(130, 215, 255), c = Color3.fromRGB(70, 140, 230)},
	Lotus = {a = Color3.fromRGB(255, 238, 246), b = Color3.fromRGB(255, 135, 190), c = Color3.fromRGB(255, 215, 130)},
	Jade = {a = Color3.fromRGB(215, 255, 230), b = Color3.fromRGB(50, 215, 135), c = Color3.fromRGB(255, 205, 110)},
}
-- {nama, cooldown, animasi}
local SKILLS = {
	Thunder = {Z = {"Thunder Step", 4, "Crescent"}, X = {"Cloud Thunder", 9, "SwordRain"}, G = {"Nine Clouds Thunder", 28, "SwordRain"}},
	Ice = {Z = {"Frost Thrust", 4, "Crescent"}, X = {"Frozen Heaven", 9, "SwordRain"}, G = {"Frozen Heaven Severance", 28, "SwordRain"}},
	Lotus = {Z = {"Petal Dance", 4, "Crescent"}, X = {"Lotus Guard", 9, "SwordRain"}, G = {"Thousand Petal Bloom", 28, "SwordRain"}},
	Jade = {Z = {"Dragon Roar", 4, "Crescent"}, X = {"Jade Dragon Rush", 9, "SwordRain"}, G = {"Jade Dragon Descends", 28, "SwordRain"}},
}
local KEYS = {[KC.Z] = "Z", [KC.X] = "X", [KC.G] = "G"}
-- body motion for each skill (procedural, same system as the click combo; works live without uploaded animations)
local SwordCombo = require(RS:WaitForChild("SwordCombo"))
local SwordFX = require(RS:WaitForChild("SwordFX"))
local ComboRelay = RS:WaitForChild("SwordComboRelay")
local MOTION = {Z = "SkillZ", X = "SkillX", G = "Ult"}
-- calligraphy name shown in the ultimate cutscene
local ULT_HAN = {Thunder = "九霄雷劫", Ice = "冰封天斩", Lotus = "千瓣莲华", Jade = "玉龙降世"}

local folder = Instance.new("Folder")
folder.Name = "WeaponFxLocal"
folder.Parent = workspace

-- ===================== helper efek =====================
local function near(pos)
	return (cam.CFrame.Position - pos).Magnitude < MAX_DIST
end

local function part(size, cf, color, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if props then
		for k, v in props do p[k] = v end
	end
	p.Parent = folder
	return p
end

local function meshed(scale, cf, color, props)
	local p = part(Vector3.one, cf, color, props)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Scale = scale
	m.Parent = p
	return p, m
end

local function tween(o, t, goal, style, dir)
	local tw = TS:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function fade(p, t, delayT, extra)
	task.delay(delayT or 0, function()
		if not p.Parent then return end
		local goal = {Transparency = 1}
		if extra then
			for k, v in extra do goal[k] = v end
		end
		tween(p, t, goal)
	end)
	Debris:AddItem(p, (delayT or 0) + t + 0.1)
end

local function light(pos, color, brightness, range, t)
	local p = part(Vector3.one * 0.2, CFrame.new(pos), color, {Transparency = 1})
	local l = Instance.new("PointLight")
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = p
	tween(l, t, {Brightness = 0})
	Debris:AddItem(p, t + 0.05)
end

local function burst(pos, color, n, speed, size, tex, life)
	local p = part(Vector3.one * 0.2, CFrame.new(pos), color, {Transparency = 1})
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex or TEX_SPARK
	e.Color = ColorSequence.new(color)
	e.LightEmission, e.LightInfluence = 1, 0
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size or 0.6), NumberSequenceKeypoint.new(1, 0)})
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime = NumberRange.new((life or 0.5) * 0.5, life or 0.5)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.Parent = p
	e:Emit(n)
	Debris:AddItem(p, (life or 0.5) + 0.1)
end

-- cincin datar yang membesar
local FLAT = CFrame.Angles(0, 0, math.rad(90))
-- 2026-11-01: hollow ring of glowing blades instead of a solid disk (solid disks read as white blobs and hide the fight)
local function ring(pos, radius, color, t, thick, transp)
	local n = math.clamp(math.floor(radius * 2.2), 14, 40)
	local w = (thick or 0.3) * 1.4
	local first
	for i = 1, n do
		local base = CFrame.new(pos) * CFrame.Angles(0, (i / n) * math.pi * 2, 0)
		local seg = math.max(0.6, radius * 2 * math.pi / n * 0.8)
		local p = part(Vector3.new(0.6, w * 0.6, 0.25), base * CFrame.new(0, 0, -0.8), color, {Transparency = transp or 0.15})
		tween(p, t, {CFrame = base * CFrame.new(0, 0, -radius), Size = Vector3.new(seg, w * 0.4, 0.5)}, Enum.EasingStyle.Quint)
		fade(p, t * 0.8, t * 0.4)
		first = first or p
	end
	return first
end

local function ground(pos)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ex = {folder}
	local fxf = workspace:FindFirstChild("FX")
	local mon = workspace:FindFirstChild("Monsters")
	if fxf then table.insert(ex, fxf) end
	if mon then table.insert(ex, mon) end
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(ex, p.Character) end
	end
	rp.FilterDescendantsInstances = ex
	local res = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -120, 0), rp)
	return res and res.Position or pos
end

-- update per frame sampai dur habis, fn(k) dengan k 0..1
local function animate(dur, fn, done)
	local t0 = os.clock()
	local con
	con = RunS.RenderStepped:Connect(function()
		local k = math.min((os.clock() - t0) / dur, 1)
		local ok = pcall(fn, k)
		if k >= 1 or not ok then
			con:Disconnect()
			if done then done() end
		end
	end)
end

-- ===================== petir =====================
local function segment(a, b, width, color, life, transp)
	local len = (b - a).Magnitude
	local p = part(Vector3.new(width, width, len), CFrame.lookAt((a + b) / 2, b), color, {Transparency = transp or 0})
	fade(p, life * 0.6, life * 0.4)
	return p
end

local function bolt(a, b, jag, width, life, th, branches)
	local n = math.clamp(math.floor((b - a).Magnitude / 2.2), 3, 18)
	local dir = (b - a).Unit
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then side = dir:Cross(Vector3.xAxis) end
	side = side.Unit
	local up = dir:Cross(side).Unit
	local prev = a
	for i = 1, n do
		local pt = a:Lerp(b, i / n)
		if i < n then
			pt += side * (math.random() - 0.5) * jag + up * (math.random() - 0.5) * jag
		end
		segment(prev, pt, width, th.a, life)
		segment(prev, pt, width * 3, th.b, life * 0.8, 0.55)
		if branches and i < n and math.random() < 0.25 then
			local off = (side * (math.random() - 0.5) + up * (math.random() - 0.5) + dir * 0.4).Unit * jag * 2.5
			bolt(pt, pt + off, jag * 0.5, width * 0.5, life * 0.8, th, false)
		end
		prev = pt
	end
end

-- awan petir dari beberapa bola + asap
-- 2026-11-01: storm cloud made of thick churning smoke with lightning flickering inside (the old solid balls read as black marbles)
local function cloud(pos, size, th, life)
	local parts = {}
	for i = 1, 4 do
		local off = Vector3.new((math.random() - 0.5) * size * 1.2, (math.random() - 0.5) * size * 0.2, (math.random() - 0.5) * size * 1.2)
		local b = part(Vector3.new(size * 0.6, size * 0.3, size * 0.6), CFrame.new(pos + off), th.c, {Transparency = 1})
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = TEX_SMOKE
		smoke.Color = ColorSequence.new(Color3.fromRGB(40, 46, 70), Color3.fromRGB(85, 100, 140))
		smoke.LightEmission, smoke.LightInfluence = 0, 0.4
		smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size * 0.55), NumberSequenceKeypoint.new(1, size * 0.95)})
		smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(1, 1)})
		smoke.Lifetime = NumberRange.new(1.2, 1.8)
		smoke.Rate = 14
		smoke.Speed = NumberRange.new(0.5, 2)
		smoke.Rotation = NumberRange.new(0, 360)
		smoke.RotSpeed = NumberRange.new(-25, 25)
		smoke.SpreadAngle = Vector2.new(180, 25)
		smoke.Parent = b
		smoke:Emit(6)
		local glow = Instance.new("ParticleEmitter")
		glow.Texture = TEX_SPARK
		glow.Color = ColorSequence.new(th.a, th.b)
		glow.LightEmission, glow.LightInfluence = 1, 0
		glow.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, 0)})
		glow.Transparency = NumberSequence.new(0.2, 1)
		glow.Lifetime = NumberRange.new(0.08, 0.16)
		glow.Rate = 9
		glow.Speed = NumberRange.new(0, 0)
		glow.Parent = b
		task.delay(life, function() smoke.Enabled = false glow.Enabled = false end)
		Debris:AddItem(b, life + 2)
		table.insert(parts, b)
	end
	return parts
end
local function strike(pos, radius, big, th)
	th = th or THEME.Thunder
	local sky = pos + Vector3.new((math.random() - 0.5) * 4, big and 60 or 34, (math.random() - 0.5) * 4)
	bolt(sky, pos, big and 6 or 3.5, big and 0.9 or 0.35, big and 0.6 or 0.38, th, true)
	if big then
		task.delay(0.05, function() bolt(sky + Vector3.new(2, 0, -2), pos, 7, 0.5, 0.5, th, true) end)
	end
	ring(pos + Vector3.new(0, 0.2, 0), radius, th.b, 0.35, 0.3)
	burst(pos + Vector3.new(0, 0.5, 0), th.a, big and 40 or 14, big and 40 or 22, big and 1.2 or 0.6)
	light(pos + Vector3.new(0, 4, 0), th.b, big and 12 or 6, big and 40 or 20, 0.3)
end

-- ===================== es =====================
local function wedge(size, cf, color, props)
	local w = Instance.new("WedgePart")
	w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = true, false, false, false, false
	w.Material = Enum.Material.Glass
	w.Color = color
	w.Size = size
	w.CFrame = cf
	for k, v in props or {} do w[k] = v end
	w.Parent = folder
	return w
end

-- duri es: dua WedgePart kaca saling membelakangi + inti neon, tumbuh dari tanah
local function iceSpike(pos, dir, h, th, life)
	local tilt = CFrame.Angles(math.rad((math.random() - 0.5) * 30), 0, math.rad((math.random() - 0.5) * 30))
	local base = CFrame.lookAt(pos, pos + dir) * tilt
	local w1 = wedge(Vector3.new(h * 0.3, 0.1, h * 0.18), base, th.b, {Transparency = 0.2, Reflectance = 0.15})
	local w2 = wedge(Vector3.new(h * 0.3, 0.1, h * 0.18), base * CFrame.Angles(0, math.pi, 0), th.b, {Transparency = 0.2, Reflectance = 0.15})
	local core = part(Vector3.new(h * 0.07, 0.1, h * 0.07), base, th.a, {Transparency = 0.3})
	local goals = {
		{w1, base * CFrame.new(0, h / 2, -h * 0.09)},
		{w2, base * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, h / 2, -h * 0.09)},
		{core, base * CFrame.new(0, h * 0.4, 0)},
	}
	for _, g in goals do
		local w = g[1]
		local hh = w == core and h * 0.8 or h
		tween(w, 0.12, {Size = Vector3.new(w.Size.X, hh, w.Size.Z), CFrame = g[2]}, Enum.EasingStyle.Back)
		fade(w, 0.4, life)
	end
	burst(pos + Vector3.new(0, 0.5, 0), th.a, 6, 12, 0.4)
end

-- balok es menyelimuti musuh yang membeku
local function encase(m, t, th)
	local root = m:FindFirstChild("HumanoidRootPart")
	if not root or not near(root.Position) then return end
	local cf, size = m:GetBoundingBox()
	local b = part(size * 1.15, cf, th.b, {Material = Enum.Material.Glass, Transparency = 0.45, Reflectance = 0.25})
	local inner = part(size * 1.05, cf, th.a, {Material = Enum.Material.ForceField, Transparency = 0.3})
	for _, p in {b, inner} do
		local s = p.Size
		p.Size = s * 0.6
		tween(p, 0.15, {Size = s}, Enum.EasingStyle.Back)
		fade(p, 0.25, t)
	end
	task.delay(t, function()
		burst(cf.Position, th.a, 18, 25, 0.7)
	end)
end

local function frostTint(m, t)
	local hl = Instance.new("Highlight")
	hl.FillColor = THEME.Ice.b
	hl.OutlineColor = THEME.Ice.a
	hl.FillTransparency = 0.55
	hl.OutlineTransparency = 0.4
	hl.Parent = m
	Debris:AddItem(hl, t)
end

-- ===================== teratai =====================
local function petal(cf, len, color, transp)
	local p, m = meshed(Vector3.new(len * 0.45, len * 0.08, len), cf, color, {Transparency = transp or 0.05})
	return p, m
end

local function lotus(pos, radius, th, life, rise)
	local parts = {}
	for layer = 1, 2 do
		local count = layer == 1 and 10 or 8
		local len = radius * (layer == 1 and 0.75 or 0.5)
		local open = layer == 1 and 70 or 45
		for i = 1, count do
			local a = (i + (layer == 2 and 0.5 or 0)) / count * math.pi * 2
			local baseCF = CFrame.new(pos) * CFrame.Angles(0, a, 0)
			local closed = baseCF * CFrame.Angles(math.rad(-80), 0, 0) * CFrame.new(0, 0, -len * 0.45)
			local opened = baseCF * CFrame.Angles(math.rad(-90 + open), 0, 0) * CFrame.new(0, 0, -len * 0.45)
			local col = layer == 1 and th.b or th.a
			local p = petal(closed, len, col, 0.15)
			p.Material = Enum.Material.Neon
			tween(p, rise or 0.5, {CFrame = opened}, Enum.EasingStyle.Back)
			fade(p, 0.5, life)
			table.insert(parts, p)
		end
	end
	local heart = part(Vector3.one * radius * 0.25, CFrame.new(pos + Vector3.new(0, radius * 0.08, 0)), th.c, {Shape = Enum.PartType.Ball, Transparency = 0.1})
	fade(heart, 0.5, life)
	table.insert(parts, heart)
	return parts
end

-- kelopak yang berputar mengelilingi titik (atau Part yang diikuti)
local function petalStorm(target, radius, count, dur, th, height)
	local list = {}
	for i = 1, count do
		local p = petal(CFrame.new(), 1.1 + math.random() * 0.6, (i % 3 == 0) and th.c or ((i % 2 == 0) and th.a or th.b), 0.1)
		table.insert(list, {p = p, a = math.random() * math.pi * 2, r = radius * (0.3 + math.random() * 0.7), h = math.random() * (height or 6), s = 3 + math.random() * 3, spin = math.random() * 6})
	end
	local t0 = os.clock()
	animate(dur, function(k)
		local c = typeof(target) == "Instance" and target.Position or target
		local t = os.clock() - t0
		for _, e in list do
			local a = e.a + t * e.s
			local pos = c + Vector3.new(math.cos(a) * e.r, e.h + math.sin(t * 2 + e.a) * 0.8, math.sin(a) * e.r)
			e.p.CFrame = CFrame.new(pos) * CFrame.Angles(t * e.spin, a, t * e.spin * 0.5)
			if k > 0.8 then e.p.Transparency = 0.1 + (k - 0.8) * 4.5 end
		end
	end, function()
		for _, e in list do e.p:Destroy() end
	end)
end

-- ===================== naga giok =====================
local function makeDragon(scale, th)
	local segs = {}
	local n = 16
	for i = 1, n do
		local s = scale * (1.2 - (i / n) * 0.75)
		local body = part(Vector3.one * s, CFrame.new(0, -500, 0), th.b, {Shape = Enum.PartType.Ball, Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.1})
		local core = part(Vector3.one * s * 0.55, CFrame.new(0, -500, 0), th.a, {Shape = Enum.PartType.Ball, Transparency = 0.15})
		local fin
		if i % 2 == 0 then
			fin = Instance.new("WedgePart")
			fin.Anchored, fin.CanCollide, fin.CanQuery, fin.CanTouch, fin.CastShadow = true, false, false, false, false
			fin.Material = Enum.Material.Neon
			fin.Color = th.c
			fin.Size = Vector3.new(s * 0.12, s * 0.6, s * 0.7)
			fin.Parent = folder
		end
		table.insert(segs, {body = body, core = core, fin = fin, s = s})
	end
	-- kepala: moncong, tanduk emas, mata
	local hs = scale * 1.5
	local head = part(Vector3.new(hs, hs * 0.8, hs * 1.3), CFrame.new(0, -500, 0), th.b, {Material = Enum.Material.Glass, Transparency = 0.15})
	local snout = part(Vector3.new(hs * 0.7, hs * 0.45, hs * 0.9), CFrame.new(0, -500, 0), th.b, {Material = Enum.Material.Glass, Transparency = 0.15})
	local hornL = part(Vector3.new(hs * 0.12, hs * 0.12, hs * 1.1), CFrame.new(0, -500, 0), th.c)
	local hornR = hornL:Clone()
	hornR.Parent = folder
	local eyeL = part(Vector3.one * hs * 0.18, CFrame.new(0, -500, 0), Color3.fromRGB(255, 240, 160), {Shape = Enum.PartType.Ball})
	local eyeR = eyeL:Clone()
	eyeR.Parent = folder
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, hs * 0.4, 0)
	a0.Parent = head
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -hs * 0.4, 0)
	a1.Parent = head
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(th.a, th.b)
	tr.LightEmission = 1
	tr.Lifetime = 0.5
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.Parent = head
	local all = {head, snout, hornL, hornR, eyeL, eyeR}
	for _, sg in segs do
		table.insert(all, sg.body)
		table.insert(all, sg.core)
		if sg.fin then table.insert(all, sg.fin) end
	end
	local d = {segs = segs, all = all}
	-- taruh naga mengikuti fungsi path(t) -> posisi, kepala di t
	function d.place(path, t, spacing)
		local hp = path(t)
		local hp2 = path(t - spacing * 0.5)
		local look = (hp - hp2)
		if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
		local hcf = CFrame.lookAt(hp, hp + look.Unit)
		head.CFrame = hcf
		snout.CFrame = hcf * CFrame.new(0, -hs * 0.1, -hs * 0.85)
		hornL.CFrame = hcf * CFrame.new(-hs * 0.3, hs * 0.45, hs * 0.3) * CFrame.Angles(math.rad(25), math.rad(-15), 0)
		hornR.CFrame = hcf * CFrame.new(hs * 0.3, hs * 0.45, hs * 0.3) * CFrame.Angles(math.rad(25), math.rad(15), 0)
		eyeL.CFrame = hcf * CFrame.new(-hs * 0.32, hs * 0.15, -hs * 0.45)
		eyeR.CFrame = hcf * CFrame.new(hs * 0.32, hs * 0.15, -hs * 0.45)
		for i, sg in segs do
			local p = path(t - spacing * i)
			local p2 = path(t - spacing * i - spacing * 0.5)
			local lk = p - p2
			local cf = lk.Magnitude > 0.01 and CFrame.lookAt(p, p + lk.Unit) or CFrame.new(p)
			sg.body.CFrame = cf
			sg.core.CFrame = cf
			if sg.fin then sg.fin.CFrame = cf * CFrame.new(0, sg.s * 0.55, 0) end
		end
	end
	function d.fade(t)
		for _, p in all do fade(p, t) end
	end
	return d
end

-- ===================== cut-in ultimate =====================
local gui = Instance.new("ScreenGui")
gui.Name = "WeaponSkillHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(y)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0, y)
	f.Position = UDim2.fromScale(0, y)
	f.Size = UDim2.fromScale(1, 0)
	f.ZIndex = 20
	f.Parent = gui
	return f
end
local topBar, botBar = bar(0), bar(1)
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.82)
title.Size = UDim2.fromScale(0.9, 0.08)
title.Font = Enum.Font.Garamond
title.TextScaled = true
title.TextTransparency = 1
title.TextStrokeTransparency = 1
title.ZIndex = 21
title.Parent = gui
local flashF = Instance.new("Frame")
flashF.Size = UDim2.fromScale(1, 1)
flashF.BackgroundTransparency = 1
flashF.BorderSizePixel = 0
flashF.ZIndex = 19
flashF.Parent = gui

local function screenFlash(color, t)
	flashF.BackgroundColor3 = color
	flashF.BackgroundTransparency = 0.25
	tween(flashF, t, {BackgroundTransparency = 1})
end

local han = title:Clone()
han.Position = UDim2.fromScale(0.5, 0.5)
han.Size = UDim2.fromScale(0.8, 0.2)
han.Font = Enum.Font.Garamond
han.Parent = gui
local hanGrad = Instance.new("UIGradient")
hanGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.48, 0), NumberSequenceKeypoint.new(0.52, 1), NumberSequenceKeypoint.new(1, 1)})
hanGrad.Parent = han
local titleGrad = hanGrad:Clone()
titleGrad.Parent = title

local function bladeTip(char)
	local tool = char:FindFirstChildOfClass("Tool")
	local h = tool and tool:FindFirstChild("Handle")
	if not h then return (char:FindFirstChild("Head") or char.PrimaryPart).Position end
	local best, bm
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") and d ~= h and d.Transparency < 1 and (not bm or d.Size.Magnitude > bm) then best, bm = d, d.Size.Magnitude end
	end
	best = best or h
	local sz = best.Size
	local ax = (sz.X >= sz.Y and sz.X >= sz.Z) and Vector3.xAxis or ((sz.Y >= sz.Z) and Vector3.yAxis or Vector3.zAxis)
	local half = math.max(sz.X, sz.Y, sz.Z) / 2
	local a, b = best.CFrame:PointToWorldSpace(ax * half), best.CFrame:PointToWorldSpace(-ax * half)
	return (a - h.Position).Magnitude > (b - h.Position).Magnitude and a or b
end

-- qi of the element streams in from all around and soaks into the blade
local function gather(char, th, dur)
	local t0 = os.clock()
	while os.clock() - t0 < dur and char.Parent do
		local tip = bladeTip(char)
		for _ = 1, 3 do
			local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 - 0.2, math.random() - 0.5)
			if dir.Magnitude > 0.01 then
				local from = tip + dir.Unit * (7 + math.random() * 5)
				local p = part(Vector3.new(0.12, 0.12, 1.6), CFrame.lookAt(from, tip), math.random() < 0.4 and th.a or th.b)
				tween(p, 0.32, {CFrame = CFrame.lookAt(tip, tip + (tip - from).Unit), Size = Vector3.new(0.05, 0.05, 0.4)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				fade(p, 0.08, 0.3)
			end
		end
		task.wait(0.03)
	end
end

-- ultimate cutscene (local player only, ~6.2 s), timed to the long Ult clip in SwordCombo:
-- 0-1.3 close-up on the face and the sword-finger seal -> 1.3-2.6 wide orbit while the set piece grows (avatar, dragon, throne...)
-- -> 2.6-3.55 low hero shot as the blade rises, calligraphy name -> 3.55 whip -> 3.7 impact frame on the cleave -> wide shot of the payoff
-- Player attribute UltCutscene = false (settings menu, later) skips all camera work.
local ORBIT = {Thunder = {26, 14}, Jade = {24, 12}, Lotus = {15, 5}, Ice = {13, 3}}
local function cutIn(text, th, el, aim)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if player:GetAttribute("UltCutscene") == false then
		task.wait(4.6)
		return
	end
	local head = char:FindFirstChild("Head") or root
	local base = root.CFrame
	local fov0 = cam.FieldOfView
	local target = aim and Vector3.new(aim.X, root.Position.Y, aim.Z) or (base * CFrame.new(0, 0, -16)).Position
	if (target - root.Position).Magnitude < 6 then target = (base * CFrame.new(0, 0, -16)).Position end
	local o = ORBIT[el] or ORBIT.Ice
	local big = el == "Thunder"
	tween(topBar, 0.25, {Size = UDim2.fromScale(1, 0.13)})
	tween(botBar, 0.25, {Size = UDim2.fromScale(1, 0.13)})
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "WeaponUltCut"
	cc.Parent = Lighting
	tween(cc, 0.4, {Saturation = -0.55, Contrast = 0.25, TintColor = th.b:Lerp(Color3.new(1, 1, 1), 0.65)})
	han.Text = ULT_HAN[el] or ""
	han.TextColor3, han.TextStrokeColor3 = th.a, th.c
	title.Text = text
	title.TextColor3, title.TextStrokeColor3 = th.a, th.b
	hanGrad.Offset, titleGrad.Offset = Vector2.new(-1, 0), Vector2.new(-1, 0)
	task.spawn(gather, char, th, 3.55)
	ring(root.Position - Vector3.new(0, 2.6, 0), 9, th.b, 0.7, 0.3)
	local t0 = os.clock()
	local shake, impact = 0, false
	cam.CameraType = Enum.CameraType.Scriptable
	RunS:BindToRenderStep("WeaponUltCam", Enum.RenderPriority.Camera.Value + 2, function()
		if not char.Parent then return end
		local t = os.clock() - t0
		local hp = head.Position
		local cf, fov
		if t < 1.3 then -- 1. close-up, slow push in on the face and seal
			local u = t / 1.3
			u = 1 - (1 - u) ^ 2
			cf = CFrame.lookAt((base * CFrame.new(1.4 - 0.5 * u, 0.8 + 0.2 * u, -5.6 + 1.8 * u)).Position, hp - Vector3.new(0, 0.35, 0))
			fov = 46 - 8 * u
		elseif t < 2.6 then -- 2. pull out into a wide orbit so the set piece behind/around the caster reads
			local u = (t - 1.3) / 1.3
			u = u * u * (3 - 2 * u)
			local ang = math.rad(-55 + 110 * u)
			local d = o[1] * (0.7 + 0.3 * u)
			cf = CFrame.lookAt((base * CFrame.Angles(0, ang, 0) * CFrame.new(0, 2 + o[2] * 0.3, -d)).Position, hp + Vector3.new(0, 1 + o[2] * 0.6 * u, 0))
			fov = 58 + 10 * u
		elseif t < 3.55 then -- 3. low hero shot looking up as the blade goes to the sky
			local u = (t - 2.6) / 0.95
			local tip = bladeTip(char)
			local d = big and 17 or 7.5
			local look = big and hp + Vector3.new(0, 13, 0) or hp:Lerp(tip, 0.55)
			cf = CFrame.lookAt((base * CFrame.Angles(0, math.rad(25 - 15 * u), 0) * CFrame.new(0, -1.9, -d + 1.2 * u)).Position, look)
			fov = 64
		elseif t < 3.7 then -- 4. whip in from the side
			local u = (t - 3.55) / 0.15
			cf = CFrame.lookAt((base * CFrame.new(4 - 1.5 * u, 1.4, -2.5)).Position, hp)
			fov = 62 + 18 * u
		else -- 5. wide shot of the payoff, slow dolly, shake
			local u = math.min(1, (t - 3.7) / 2.5)
			local back = (root.Position - target)
			back = Vector3.new(back.X, 0, back.Z)
			back = back.Magnitude > 0.01 and back.Unit or -base.LookVector
			local side = back:Cross(Vector3.yAxis)
			local pos, look
			if big then -- side-on so the avatar and the target are both in frame
				pos = root.Position + side * (26 + 4 * u) + back * 4 + Vector3.new(0, 8 + 3 * u, 0)
				look = root.Position:Lerp(target, 0.45) + Vector3.new(0, 7, 0)
			elseif el == "Jade" then
				pos = root.Position + back * (18 + 6 * u) + side * 10 + Vector3.new(0, 14 + 4 * u, 0)
				look = root.Position:Lerp(target, 0.65) + Vector3.new(0, 4 * (1 - u), 0)
			else
				pos = root.Position + back * (14 + 6 * u) + side * 7 + Vector3.new(0, 9 + 3 * u, 0)
				look = root.Position:Lerp(target, 0.65)
			end
			cf = CFrame.lookAt(pos, look)
			fov = 72
		end
		if shake > 0 then
			shake = math.max(0, shake - 1 / 60)
			local k = shake * 1.6
			cf = cf * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * k * 0.05)
		end
		cam.CFrame = cf
		cam.FieldOfView = fov
		if t >= 3.7 and not impact then
			impact = true
			shake = 0.55
		end
	end)
	task.wait(2.6)
	-- name reveal on the hero shot
	ring(root.Position - Vector3.new(0, 2.6, 0), 13, th.a, 0.6, 0.4, 0.2)
	tween(han, 0.01, {TextTransparency = 0, TextStrokeTransparency = 0.2})
	tween(title, 0.01, {TextTransparency = 0, TextStrokeTransparency = 0.2})
	tween(hanGrad, 0.45, {Offset = Vector2.new(1, 0)}, Enum.EasingStyle.Sine)
	task.delay(0.12, function() tween(titleGrad, 0.45, {Offset = Vector2.new(1, 0)}, Enum.EasingStyle.Sine) end)
	task.wait(1.1)
	-- impact frame: two frames of inverted black/white, then the colour comes back hot
	flashF.BackgroundColor3 = Color3.new(0, 0, 0)
	flashF.BackgroundTransparency = 0.05
	cc.Saturation, cc.Contrast, cc.Brightness = -1, 1, 0.15
	han.TextTransparency, title.TextTransparency = 1, 1
	han.TextStrokeTransparency, title.TextStrokeTransparency = 1, 1
	task.wait(0.05)
	flashF.BackgroundColor3 = th.a
	flashF.BackgroundTransparency = 0.1
	task.wait(0.05)
	tween(flashF, 0.4, {BackgroundTransparency = 1})
	tween(cc, 0.5, {Saturation = 0.2, Contrast = 0.1, Brightness = 0})
	task.wait(2.4)
	RunS:UnbindFromRenderStep("WeaponUltCam")
	cam.CameraType = Enum.CameraType.Custom
	tween(cam, 0.4, {FieldOfView = fov0})
	tween(topBar, 0.3, {Size = UDim2.fromScale(1, 0)})
	tween(botBar, 0.3, {Size = UDim2.fromScale(1, 0)})
	tween(cc, 0.6, {Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1)})
	Debris:AddItem(cc, 0.7)
end

-- langit gelap sebentar waktu ultimate (cuma kalau dekat)
local function darkSky(color, dur)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "WeaponUltSky"
	cc.Parent = Lighting
	tween(cc, 0.4, {Brightness = -0.12, Contrast = 0.15, Saturation = -0.25, TintColor = color})
	task.delay(dur, function()
		tween(cc, 0.8, {Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1)})
		Debris:AddItem(cc, 0.9)
	end)
end

-- ===================== bar cooldown =====================
local hud = Instance.new("Frame")
hud.Name = "WeaponSkills"
hud.AnchorPoint = Vector2.new(0.5, 1)
hud.Position = UDim2.new(0.5, 0, 1, -178)
hud.Size = UDim2.fromOffset(372, 40)
hud.BackgroundTransparency = 1
hud.Visible = false
hud.Parent = gui
local lay = Instance.new("UIListLayout")
lay.FillDirection = Enum.FillDirection.Horizontal
lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
lay.Padding = UDim.new(0, 6)
lay.Parent = hud
local slots = {}
for i, key in {"Z", "X", "G"} do
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(120, 40)
	f.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	f.BackgroundTransparency = 0.25
	f.LayoutOrder = i
	f.ClipsDescendants = true
	f.Parent = hud
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
	local st = Instance.new("UIStroke")
	st.Thickness = 1.5
	st.Parent = f
	local cd = Instance.new("Frame")
	cd.BackgroundColor3 = Color3.new(0, 0, 0)
	cd.BackgroundTransparency = 0.45
	cd.BorderSizePixel = 0
	cd.Size = UDim2.fromScale(0, 1)
	cd.ZIndex = 3
	cd.Parent = f
	local k = Instance.new("TextLabel")
	k.BackgroundTransparency = 1
	k.Size = UDim2.new(0, 22, 1, 0)
	k.Position = UDim2.fromOffset(4, 0)
	k.Font = Enum.Font.FredokaOne
	k.TextSize = 18
	k.Text = key
	k.ZIndex = 2
	k.Parent = f
	local n = Instance.new("TextLabel")
	n.BackgroundTransparency = 1
	n.Size = UDim2.new(1, -30, 1, 0)
	n.Position = UDim2.fromOffset(26, 0)
	n.Font = Enum.Font.GothamMedium
	n.TextSize = 12
	n.TextWrapped = true
	n.TextColor3 = Color3.new(1, 1, 1)
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.ZIndex = 2
	n.Parent = f
	slots[key] = {frame = f, stroke = st, cd = cd, key = k, name = n}
end

local cdEnd = {}
local busy = false
local animCache = {}

local function equipped()
	local c = player.Character
	local t = c and c:FindFirstChildOfClass("Tool")
	local el = t and t:GetAttribute("Element")
	if el and THEME[el] then return t, el end
end

RunS.RenderStepped:Connect(function()
	local _, el = equipped()
	hud.Visible = el ~= nil
	if not el then return end
	local th = THEME[el]
	local now = os.clock()
	for key, sl in slots do
		local s = SKILLS[el][key]
		sl.name.Text = s[1]
		sl.key.TextColor3 = th.b
		sl.stroke.Color = th.b
		local left = (cdEnd[el .. key] or 0) - now
		sl.cd.Size = UDim2.fromScale(left > 0 and left / s[2] or 0, 1)
	end
end)

local function track(hum, name)
	local animator = hum:FindFirstChildOfClass("Animator")
	if not (animator and Anims) then return end
	local key = hum:GetFullName() .. name
	if animCache[key] and animCache[key].Parent ~= nil then return animCache[key] end
	local src = Anims:FindFirstChild(name)
	if not src then return end
	local anim
	if src:IsA("Animation") then
		anim = src
	elseif src:IsA("KeyframeSequence") then
		local ok, id = pcall(function() return KSP:RegisterKeyframeSequence(src) end)
		if not ok then return end
		anim = Instance.new("Animation")
		anim.AnimationId = id
	else
		return
	end
	local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
	if ok then
		animCache[key] = tr
		return tr
	end
end

local function cast(key)
	local tool, el = equipped()
	if not tool or busy then return end
	local char = player.Character
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or hum.Health <= 0 then return end
	if player:GetAttribute("Casting") or player:GetAttribute("Meditating") or player:GetAttribute("Flying") then return end
	local s = SKILLS[el][key]
	local id = el .. key
	local now = os.clock()
	if (cdEnd[id] or 0) > now then return end
	cdEnd[id] = now + s[2]
	local aim = mouse.Hit and mouse.Hit.Position
	if aim then
		local flat = Vector3.new(aim.X, root.Position.Y, aim.Z)
		if (flat - root.Position).Magnitude > 1 then root.CFrame = CFrame.lookAt(root.Position, flat) end
	end
	busy = true
	player:SetAttribute("Casting", true)
	SkillRemote:FireServer(key, aim)
	local motion = MOTION[key]
	local clip = SwordCombo.Get(motion)
	local trails = {}
	for _, d in tool:GetDescendants() do
		if d:IsA("Trail") then table.insert(trails, d) end
	end
	ComboRelay:FireServer(tool, motion)
	SwordCombo.Play(char, motion, {
		onTrail = function(on)
			for _, t in trails do t.Enabled = on end
			if on then SwordFX.Spawn(char, tool, clip, "Swing") end
		end,
		onContact = function()
			SwordFX.Spawn(char, tool, clip, "Contact")
			SwordCombo.HitStop(char, clip.heavy and 0.12 or 0.06)
		end,
		onEnd = function(chained)
			if not chained then char:SetAttribute("SwordAttacking", false) end
		end,
	})
	local speed = hum.WalkSpeed
	if key == "G" then
		hum.WalkSpeed = 0
		cutIn(s[1]:upper(), THEME[el], el, aim)
	else
		task.wait(0.5)
	end
	busy = false
	player:SetAttribute("Casting", nil)
	if key == "G" and hum.WalkSpeed == 0 then hum.WalkSpeed = speed end
end

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	local key = KEYS[input.KeyCode]
	if key and equipped() then task.spawn(cast, key) end
end)

-- ===================== pedang roh raksasa =====================
-- 2026-11-01: every ultimate drops a giant spirit copy of the caster's OWN sword (its real meshes, scaled up, made of
-- glowing glass/forcefield in the element colour) point-first into the target, instead of a sword built from blocks
local ultCaster = {}
local function spiritBlade(el, center, height, th, fallDur, holdDur, onLand)
	local plr = ultCaster[el]
	local tool = plr and plr.Character and plr.Character:FindFirstChildOfClass("Tool")
	local h = tool and tool:FindFirstChild("Handle")
	if not h then return false end
	local tip = bladeTip(plr.Character)
	local tipLocal = h.CFrame:PointToObjectSpace(tip)
	if tipLocal.Magnitude < 0.5 then return false end
	local K = height / tipLocal.Magnitude
	local rot = CFrame.fromRotationBetweenVectors(tipLocal.Unit, -Vector3.yAxis)
	local pieces = {}
	for _, d in tool:GetDescendants() do
		if d:IsA("MeshPart") and d.Transparency < 0.6 and d.Size.Magnitude > 0.6 then
			local off = h.CFrame:ToObjectSpace(d.CFrame)
			for layer = 1, 2 do
				local g = d:Clone()
				for _, ch in g:GetChildren() do ch:Destroy() end
				g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
				g.Size = d.Size * K * (layer == 1 and 1 or 0.94)
				g.Material = layer == 1 and Enum.Material.Glass or Enum.Material.Neon
				g.Color = layer == 1 and th.b or th.a
				g.Transparency = layer == 1 and 0.25 or 0.55
				g.Reflectance = layer == 1 and 0.3 or 0
				g.Parent = folder
				table.insert(pieces, {g, CFrame.new(off.Position * K) * off.Rotation})
			end
		end
	end
	if #pieces == 0 then return false end
	-- handle frame: tip points straight down; lands with the tip buried a little in the ground
	local landH = CFrame.new(center + Vector3.new(0, height * 0.92, 0)) * rot
	local fromH = landH + Vector3.new(0, 90, 0)
	local spin = math.rad(math.random(0, 359))
	local function place(cf)
		local c = CFrame.new(cf.Position) * CFrame.Angles(0, spin, 0) * cf.Rotation
		for _, pc in pieces do pc[1].CFrame = c * pc[2] end
	end
	place(fromH)
	animate(fallDur, function(k)
		place(fromH:Lerp(landH, k * k * k))
	end, function()
		place(landH)
		if onLand then onLand() end
		for _, pc in pieces do fade(pc[1], 0.5, holdDur) end
	end)
	return true
end

-- ===================== ultimate set pieces (2026-11-01) =====================
-- Every sword's ultimate has its own donghua-style set piece, timed to the long cutscene:
-- 0-1.3 seal close-up, 1.3-2.6 the set piece grows, 2.6-3.55 blade raised to the sky, 3.7 cleave (server damage starts), payoff until ~6.2
-- Thunder = 法相 giant lightning avatar of the caster, Ice = 领域 frozen domain + sky-splitting cut, Lotus = 莲台 throne + 万剑 petal swords,
-- Jade = 龙魂 jade dragon coiling up the caster then spiralling down on the target.
local ULT = {LEAD = 3.7, recent = {}}
ULT.GLYPHS = {
	Thunder = {"雷", "霆", "震", "霄", "电", "鸣", "天", "罚"},
	Ice = {"冰", "霜", "寒", "封", "雪", "凝", "天", "斩"},
	Lotus = {"莲", "华", "净", "心", "花", "开", "千", "瓣"},
	Jade = {"龙", "玉", "吟", "渊", "鳞", "腾", "云", "降"},
}

-- formation array (阵法): counter-rotating rings, an eight-point star and glowing glyphs; y > 5 = hangs in the sky
function ULT.array(center, radius, th, el, life, y)
	local items = {}
	local sky = (y or 0) > 5
	local function add(p, rel, dir) table.insert(items, {p, rel, dir}) end
	local function ringOf(r, n, w, color, dir)
		local seg = 2 * math.pi * r / n * 1.03
		for i = 1, n do
			local p = part(Vector3.new(seg, 0.08, w), CFrame.new(center), color, {Transparency = 1})
			add(p, CFrame.Angles(0, (i / n) * math.pi * 2, 0) * CFrame.new(0, 0, -r), dir)
		end
	end
	ringOf(radius, 56, 0.35, th.b, 1)
	ringOf(radius * 0.86, 48, 0.16, th.a, 1)
	ringOf(radius * 0.55, 36, 0.25, th.b, -1)
	local rs = radius * 0.55
	for sq = 0, 1 do
		for i = 0, 3 do
			local a1, a2 = math.rad(sq * 45 + i * 90), math.rad(sq * 45 + (i + 1) * 90)
			local v1 = Vector3.new(math.cos(a1) * rs, 0, math.sin(a1) * rs)
			local v2 = Vector3.new(math.cos(a2) * rs, 0, math.sin(a2) * rs)
			local p = part(Vector3.new(0.2, 0.08, (v2 - v1).Magnitude), CFrame.new(center), th.a, {Transparency = 1})
			add(p, CFrame.lookAt((v1 + v2) / 2, v2), -1)
		end
	end
	local glyphs = ULT.GLYPHS[el] or ULT.GLYPHS.Thunder
	for i = 1, 8 do
		local sz = radius * 0.22
		local p = part(Vector3.new(sz, 0.05, sz), CFrame.new(center), th.b, {Transparency = 1})
		local sg = Instance.new("SurfaceGui")
		sg.Face = sky and Enum.NormalId.Bottom or Enum.NormalId.Top
		sg.LightInfluence = 0
		sg.Brightness = 2
		sg.Parent = p
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.TextScaled = true
		tl.Font = Enum.Font.Garamond
		tl.Text = glyphs[i]
		tl.TextColor3, tl.TextStrokeColor3 = th.a, th.b
		tl.TextTransparency, tl.TextStrokeTransparency = 1, 1
		tl.Parent = sg
		tween(tl, 0.6, {TextTransparency = 0, TextStrokeTransparency = 0.3})
		task.delay(life, function()
			if tl.Parent then tween(tl, 0.5, {TextTransparency = 1, TextStrokeTransparency = 1}) end
		end)
		add(p, CFrame.Angles(0, (i / 8) * math.pi * 2, 0) * CFrame.new(0, 0, -radius * 0.7) * CFrame.Angles(0, math.pi, 0), 1)
	end
	for _, it in items do
		if it[1].Size.Y > 0.06 then tween(it[1], 0.6, {Transparency = 0.12}) end
		fade(it[1], 0.5, life)
	end
	local t0 = os.clock()
	local con
	con = RunS.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > life + 0.6 then con:Disconnect() return end
		local base = CFrame.new(center + Vector3.new(0, y or 0.2, 0))
		local ang = t * 0.7
		for _, it in items do
			if it[1].Parent then it[1].CFrame = base * CFrame.Angles(0, ang * it[3], 0) * it[2] end
		end
	end)
end

-- 法相: a giant energy copy of the caster rises behind them and mirrors every move, sword included
function ULT.Thunder(plr, th, center)
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local g = ground(root.Position)
	ULT.array(g, 15, th, "Thunder", 5.6)
	local was = char.Archivable
	char.Archivable = true
	local ok, av = pcall(function() return char:Clone() end)
	char.Archivable = was
	if not ok or not av then return end
	for _, d in av:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Clothing") or d:IsA("Decal") or d:IsA("SurfaceAppearance")
			or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light") or d:IsA("Sound")
			or d:IsA("BillboardGui") or d:IsA("ForceField") or d:IsA("BodyColors") or d:IsA("ShirtGraphic") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	local avRoot = av:FindFirstChild("HumanoidRootPart")
	if not avRoot then av:Destroy() return end
	local parts = {}
	for _, d in av:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow, d.Massless, d.Anchored = false, false, false, false, true, false
			d.Material = Enum.Material.Neon
			d.Color = th.b:Lerp(th.a, 0.25)
			d.Transparency = 1
			if d:IsA("MeshPart") then pcall(function() d.TextureID = "" end) end
			table.insert(parts, d)
		end
	end
	avRoot.Anchored = true
	av.PrimaryPart = avRoot
	av.Name = "UltAvatar"
	av.Parent = folder
	local S = 5
	pcall(function() av:ScaleTo(S) end)
	local hl = Instance.new("Highlight")
	hl.FillColor, hl.OutlineColor = th.b, th.a
	hl.FillTransparency, hl.OutlineTransparency = 1, 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = av
	tween(hl, 0.9, {FillTransparency = 0.7, OutlineTransparency = 0})
	for _, p in parts do
		if p ~= avRoot then tween(p, 0.9, {Transparency = 0.5}) end
	end
	-- joints to mirror (player's Transform -> avatar, translations scaled up)
	local pairs_ = {}
	for _, j in char:GetDescendants() do
		if (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and j.Parent then
			local holder = av:FindFirstChild(j.Parent.Name, true)
			local twin = holder and holder:FindFirstChild(j.Name)
			if twin and (twin:IsA("Motor6D") or twin:IsA("AnimationConstraint")) then table.insert(pairs_, {j, twin}) end
		end
	end
	local h0 = root.Position.Y - g.Y
	local back = -root.CFrame.LookVector
	local rot = root.CFrame - root.Position
	local finalPos = g + back * 9 + Vector3.new(0, h0 * S - S * 1.6, 0)
	local startPos = finalPos - Vector3.new(0, h0 * S * 1.5, 0)
	local t0 = os.clock()
	local con
	local nextBolt = 0
	con = RunS.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if not av.Parent or t > 6.4 then con:Disconnect() return end
		local u = math.clamp(t / 1.3, 0, 1)
		u = 1 - (1 - u) ^ 3
		local bob = math.sin(t * 2.2) * 0.4
		avRoot.CFrame = rot + startPos:Lerp(finalPos, u) + Vector3.new(0, bob, 0)
		for _, pr in pairs_ do
			if pr[1].Parent and pr[2].Parent then
				local tr = pr[1].Transform
				pr[2].Transform = CFrame.new(tr.Position * S) * tr.Rotation
			end
		end
		-- lightning crawling over the avatar
		if t > 0.6 and t < 5.6 and os.clock() > nextBolt then
			nextBolt = os.clock() + 0.12
			local a, b = parts[math.random(1, #parts)], parts[math.random(1, #parts)]
			if a.Parent and b.Parent and (a.Position - b.Position).Magnitude > 2 then bolt(a.Position, b.Position, 2.5, 0.25, 0.15, th, false) end
		end
	end)
	-- the avatar's cleave throws a giant bolt from its blade into the target
	task.delay(ULT.LEAD, function()
		if not av.Parent then return end
		local tip = bladeTip(av)
		bolt(tip, center, 7, 1.4, 0.7, th, true)
		task.delay(0.08, function() bolt(tip + Vector3.new(3, 0, 0), center, 9, 0.8, 0.6, th, true) end)
		burst(center + Vector3.new(0, 2, 0), th.a, 60, 55, 1.4, nil, 0.8)
		ring(center + Vector3.new(0, 0.4, 0), 16, th.b, 0.6, 0.6, 0.1)
		light(center + Vector3.new(0, 8, 0), th.b, 18, 80, 0.7)
	end)
	task.delay(5.5, function()
		if not av.Parent then return end
		tween(hl, 0.7, {FillTransparency = 1, OutlineTransparency = 1})
		for _, p in parts do if p.Parent then tween(p, 0.7, {Transparency = 1}) end end
		Debris:AddItem(av, 0.8)
	end)
end

-- 领域: the world drains of colour and stops, snow hangs frozen in the air, then one cut splits the sky
function ULT.Ice(plr, th, center)
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local g = ground(root.Position)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "UltDomain"
	cc.Parent = Lighting
	tween(cc, 0.8, {Saturation = -0.85, Contrast = 0.15, TintColor = Color3.fromRGB(205, 228, 255)})
	task.delay(5.6, function()
		tween(cc, 0.8, {Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1)})
		Debris:AddItem(cc, 0.9)
	end)
	ULT.array(g, 16, th, "Ice", 5.5)
	for _ = 1, 80 do
		local p0 = root.Position + Vector3.new((math.random() - 0.5) * 56, math.random() * 24 - 2, (math.random() - 0.5) * 56)
		local s = 0.15 + math.random() * 0.3
		local p = part(Vector3.one * s, CFrame.new(p0 + Vector3.new(0, 4, 0)), th.a, {Shape = Enum.PartType.Ball, Transparency = 1})
		tween(p, 1.1, {CFrame = CFrame.new(p0), Transparency = 0.05}, Enum.EasingStyle.Quart)
		fade(p, 0.6, 5.2)
	end
	-- frost creeping out over the ground
	for i = 1, 14 do
		task.delay(0.6 + i * 0.08, function()
			local a = math.random() * math.pi * 2
			local p = ground(g + Vector3.new(math.cos(a), 0, math.sin(a)) * (4 + math.random() * 12))
			iceSpike(p, Vector3.new(math.cos(a), 0, math.sin(a)), 1.5 + math.random() * 2.5, th, 4.4)
		end)
	end
	-- an ice formation opens in the sky over the target; the giant blade falls through it
	task.delay(2.3, function() ULT.array(center, 12, th, "Ice", 2.6, 58) end)
	task.delay(ULT.LEAD, function()
		local flat = center - root.Position
		flat = Vector3.new(flat.X, 0, flat.Z)
		local dir = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector
		local cf = CFrame.lookAt(g, g + dir)
		-- the sky splits: a hair-thin line of light from the clouds to the ground that tears open
		local crack = part(Vector3.new(0.2, 1, 0.2), cf * CFrame.new(0, 60, -36), th.a, {Transparency = 0})
		local halo = part(Vector3.new(0.2, 1, 0.2), crack.CFrame, th.b, {Transparency = 0.5})
		tween(crack, 0.12, {Size = Vector3.new(0.5, 200, 0.5)})
		tween(halo, 0.12, {Size = Vector3.new(2, 200, 2)})
		task.delay(0.15, function()
			tween(crack, 0.5, {Size = Vector3.new(5, 200, 0.6), Transparency = 0.2})
			tween(halo, 0.5, {Size = Vector3.new(18, 200, 2), Transparency = 0.85})
			fade(crack, 0.6, 0.6)
			fade(halo, 0.6, 0.5)
		end)
		-- a wall of cutting light races from the caster to the target
		local wave = part(Vector3.new(26, 18, 0.3), cf * CFrame.new(0, 9, -2), th.a, {Transparency = 0.2})
		local waveGlow = part(Vector3.new(34, 24, 0.3), wave.CFrame, th.b, {Transparency = 0.6})
		local dist = math.max(8, flat.Magnitude)
		tween(wave, 0.3, {CFrame = cf * CFrame.new(0, 9, -dist), Size = Vector3.new(40, 2, 0.1), Transparency = 0.6})
		tween(waveGlow, 0.3, {CFrame = cf * CFrame.new(0, 9, -dist), Size = Vector3.new(50, 4, 0.1)})
		fade(wave, 0.2, 0.3)
		fade(waveGlow, 0.2, 0.3)
		screenFlash(th.a, 0.35)
	end)
end

-- 莲台 + 万剑: a giant lotus throne blooms under the caster, petal-swords gather in three halos, then rain onto the target
function ULT.Lotus(plr, th, center)
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local tool = char and char:FindFirstChildOfClass("Tool")
	local h = tool and tool:FindFirstChild("Handle")
	if not (root and h) then return end
	local g = ground(root.Position)
	lotus(g + Vector3.new(0, 0.4, 0), 9, th, 5.6, 0.9)
	ULT.array(g, 14, th, "Lotus", 5.6)
	petalStorm(g, 8, 30, 5, th, 9)
	-- the blade piece of the caster's sword is the template for every flying sword
	local best, bm
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") and d ~= h and d.Transparency < 1 and (not bm or d.Size.Magnitude > bm) then best, bm = d, d.Size.Magnitude end
	end
	if not best then return end
	local tipAxis = best.CFrame:PointToObjectSpace(bladeTip(char))
	tipAxis = tipAxis.Magnitude > 0.01 and tipAxis.Unit or Vector3.yAxis
	local align = CFrame.fromRotationBetweenVectors(tipAxis, -Vector3.zAxis)
	local swords = {}
	for ringI = 1, 3 do
		local n = 6 + ringI * 3
		for i = 1, n do
			local s = best:Clone()
			for _, ch in s:GetChildren() do ch:Destroy() end
			s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = true, false, false, false, false
			s.Material = Enum.Material.Neon
			s.Color = (i % 3 == 0) and th.c or th.b
			s.Size = best.Size * 0.75
			s.Transparency = 1
			s.Parent = folder
			local at = Instance.new("Attachment") at.Position = Vector3.new(0, 0, 0) at.Parent = s
			local a2 = Instance.new("Attachment") a2.Position = tipAxis * 0.4 a2.Parent = s
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = at, a2
			tr.Color = ColorSequence.new(th.a, th.b)
			tr.LightEmission = 1
			tr.Lifetime = 0.25
			tr.Transparency = NumberSequence.new(0.3, 1)
			tr.WidthScale = NumberSequence.new(1, 0)
			tr.Parent = s
			tween(s, 0.4, {Transparency = 0.1})
			local ra, rr = math.random() * math.pi * 2, 4 + math.random() * 15
			local hit = ground(center + Vector3.new(math.cos(ra) * rr, 0, math.sin(ra) * rr))
			table.insert(swords, {s = s, ring = ringI, a = (i / n) * math.pi * 2, delay = math.random() * 0.25, hit = hit})
		end
	end
	local t0 = os.clock()
	local con
	con = RunS.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > ULT.LEAD + 1 then con:Disconnect() return end
		for _, w in swords do
			if w.s.Parent and not w.fired then
				local r = 3.5 + w.ring * 2.4
				local hgt = 2 + w.ring * 2.6 + math.min(t, 1.5) * 2
				local a = w.a + t * (w.ring % 2 == 0 and -1.4 or 1.1)
				local pos = g + Vector3.new(math.cos(a) * r, hgt, math.sin(a) * r)
				local aimW = math.clamp((t - 3.0) / 0.5, 0, 1)
				local tangent = Vector3.new(-math.sin(a), 0.35, math.cos(a))
				local toTarget = (w.hit - pos)
				local dir = tangent.Unit:Lerp(toTarget.Unit, aimW)
				w.s.CFrame = CFrame.lookAt(pos, pos + dir) * align
				w.pos, w.dir = pos, dir
			end
		end
	end)
	task.delay(ULT.LEAD, function()
		for i, w in swords do
			task.delay(w.delay + (i % 6) * 0.03, function()
				if not w.s.Parent or not w.pos then return end
				w.fired = true
				local hit = w.hit
				local from = w.pos
				local look = (hit - from).Unit
				tween(w.s, 0.22, {CFrame = CFrame.lookAt(hit - look * 1.5, hit) * align}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.22, function()
					burst(hit + Vector3.new(0, 0.5, 0), th.a, 8, 18, 0.5, nil, 0.4)
					local p = petal(CFrame.new(hit + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.random() * 6.28, 0), 2.4, th.b, 0.1)
					p.Material = Enum.Material.Neon
					fade(p, 0.5, 0.3)
					fade(w.s, 0.4, 0.5)
				end)
			end)
		end
	end)
end

-- 龙魂: a jade dragon spirit with overlapping scales, gold fins, mane and an opening jaw
function ULT.dragon(scale, th)
	local segs = {}
	local n = 26
	for i = 1, n do
		local s = scale * (1.15 - (i / n) * 0.8)
		local body = meshed(Vector3.new(s * 0.95, s * 0.85, s * 1.7), CFrame.new(0, -500, 0), th.b, {Material = Enum.Material.Glass, Transparency = 0.3, Reflectance = 0.15})
		local core = meshed(Vector3.new(s * 0.45, s * 0.4, s * 1.4), CFrame.new(0, -500, 0), th.a, {Transparency = 0.2})
		local fin = Instance.new("WedgePart")
		fin.Anchored, fin.CanCollide, fin.CanQuery, fin.CanTouch, fin.CastShadow = true, false, false, false, false
		fin.Material = Enum.Material.Neon
		fin.Color = th.c
		fin.Size = Vector3.new(s * 0.1, s * 0.55, s * 0.9)
		fin.Parent = folder
		local belly = meshed(Vector3.new(s * 0.6, s * 0.3, s * 1.5), CFrame.new(0, -500, 0), th.c, {Transparency = 0.25})
		table.insert(segs, {body = body, core = core, fin = fin, belly = belly, s = s})
	end
	local hs = scale * 1.45
	local head = meshed(Vector3.new(hs, hs * 0.75, hs * 1.4), CFrame.new(0, -500, 0), th.b, {Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.15})
	local snout = meshed(Vector3.new(hs * 0.7, hs * 0.4, hs * 1.1), CFrame.new(0, -500, 0), th.b, {Material = Enum.Material.Glass, Transparency = 0.15})
	local jaw = meshed(Vector3.new(hs * 0.6, hs * 0.22, hs * 1.0), CFrame.new(0, -500, 0), th.b, {Material = Enum.Material.Glass, Transparency = 0.2})
	local glowMouth = meshed(Vector3.new(hs * 0.45, hs * 0.2, hs * 0.8), CFrame.new(0, -500, 0), th.a, {Transparency = 0.1})
	local horns, whiskers, mane = {}, {}, {}
	for k = 1, 2 do
		table.insert(horns, part(Vector3.new(hs * 0.12, hs * 0.12, hs * 1.3), CFrame.new(0, -500, 0), th.c))
		table.insert(whiskers, part(Vector3.new(hs * 0.05, hs * 0.05, hs * 1.8), CFrame.new(0, -500, 0), th.a, {Transparency = 0.2}))
	end
	for k = 1, 7 do
		table.insert(mane, part(Vector3.new(hs * 0.08, hs * 0.08, hs * (0.9 + (k % 3) * 0.3)), CFrame.new(0, -500, 0), k % 2 == 0 and th.a or th.c, {Transparency = 0.15}))
	end
	local eyes = {}
	for k = 1, 2 do
		table.insert(eyes, part(Vector3.one * hs * 0.17, CFrame.new(0, -500, 0), Color3.fromRGB(255, 240, 160), {Shape = Enum.PartType.Ball}))
	end
	local all = {head, snout, jaw, glowMouth}
	for _, list in {horns, whiskers, mane, eyes} do for _, p in list do table.insert(all, p) end end
	for _, sg in segs do
		for _, p in {sg.body, sg.core, sg.fin, sg.belly} do table.insert(all, p) end
	end
	-- qi mist trailing from the body
	for i = 3, n, 6 do
		local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, segs[i].s * 0.4, 0) a0.Parent = segs[i].body
		local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -segs[i].s * 0.4, 0) a1.Parent = segs[i].body
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(th.a, th.b)
		tr.LightEmission = 1
		tr.Lifetime = 0.45
		tr.Transparency = NumberSequence.new(0.5, 1)
		tr.Parent = segs[i].body
	end
	local d = {all = all, open = 0}
	function d.place(path, t, spacing)
		local hp = path(t)
		local look = hp - path(t - spacing * 0.5)
		if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
		local hcf = CFrame.lookAt(hp, hp + look.Unit)
		local open = math.rad(35 * d.open)
		head.CFrame = hcf
		snout.CFrame = hcf * CFrame.new(0, hs * 0.02, -hs * 0.95) * CFrame.Angles(open * -0.3, 0, 0)
		jaw.CFrame = hcf * CFrame.new(0, -hs * 0.28, -hs * 0.3) * CFrame.Angles(-open, 0, 0) * CFrame.new(0, 0, -hs * 0.55)
		glowMouth.CFrame = hcf * CFrame.new(0, -hs * 0.12, -hs * 0.75)
		glowMouth.Transparency = 0.1 + 0.8 * (1 - d.open)
		for k, sgn in {-1, 1} do
			horns[k].CFrame = hcf * CFrame.new(sgn * hs * 0.28, hs * 0.42, hs * 0.45) * CFrame.Angles(math.rad(28), math.rad(sgn * 18), 0) * CFrame.new(0, 0, hs * 0.4)
			whiskers[k].CFrame = hcf * CFrame.new(sgn * hs * 0.32, -hs * 0.05, -hs * 1.2) * CFrame.Angles(math.rad(-10 + math.sin(os.clock() * 4 + k) * 12), math.rad(sgn * 35), 0) * CFrame.new(0, 0, hs * 0.85)
			eyes[k].CFrame = hcf * CFrame.new(sgn * hs * 0.3, hs * 0.16, -hs * 0.45)
		end
		for k, m in mane do
			local side = (k - 4) / 3
			m.CFrame = hcf * CFrame.new(side * hs * 0.45, hs * 0.3, hs * 0.55) * CFrame.Angles(math.rad(35 + math.sin(os.clock() * 5 + k) * 10), math.rad(side * 40), 0) * CFrame.new(0, 0, hs * 0.5)
		end
		for i, sg in segs do
			local p = path(t - spacing * i)
			local lk = p - path(t - spacing * i - spacing * 0.5)
			local cf = lk.Magnitude > 0.01 and CFrame.lookAt(p, p + lk.Unit) or CFrame.new(p)
			sg.body.CFrame = cf
			sg.core.CFrame = cf
			sg.belly.CFrame = cf * CFrame.new(0, -sg.s * 0.3, 0)
			sg.fin.CFrame = cf * CFrame.new(0, sg.s * 0.62, 0)
		end
	end
	function d.fade(t)
		for _, p in all do fade(p, t) end
	end
	return d
end

function ULT.Jade(plr, th, center)
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local g = ground(root.Position)
	ULT.recent.Jade = os.clock()
	ULT.array(g, 15, th, "Jade", 5.6)
	local d = ULT.dragon(3.2, th)
	local top = g + Vector3.new(0, 26, 0)
	local landing = center + Vector3.new(0, 2, 0)
	-- one continuous path over time: hidden under the caster -> coils up around them -> rears at the top -> spirals down on the target
	local function path(t)
		if t < 1.2 then
			return g + Vector3.new(0, -20 + t * 10, 0)
		elseif t < 3.5 then
			local u = (t - 1.2) / 2.3
			local a = u * 2.3 * math.pi * 2
			local r = 6 - u * 1.5
			return g + Vector3.new(math.cos(a) * r, -8 + u * 34, math.sin(a) * r)
		elseif t < ULT.LEAD then
			local u = (t - 3.5) / (ULT.LEAD - 3.5)
			local a = 2.3 * math.pi * 2
			local r = 4.5
			return g + Vector3.new(math.cos(a) * r, 26 + u * 2, math.sin(a) * r)
		else
			local u = math.min(1, (t - ULT.LEAD) / 1.8)
			local a0 = 2.3 * math.pi * 2
			local startP = g + Vector3.new(math.cos(a0) * 4.5, 28, math.sin(a0) * 4.5)
			local base = startP:Lerp(landing, u ^ 1.4)
			local r = 12 * math.sin(u * math.pi) * (1 - u * 0.5)
			local a = a0 + u * 3 * math.pi * 2
			return base + Vector3.new(math.cos(a) * r, math.sin(u * math.pi) * 6, math.sin(a) * r)
		end
	end
	local t0 = os.clock()
	local roared = false
	animate(ULT.LEAD + 1.9, function()
		local t = os.clock() - t0
		d.open = (t > 3.2 and t < 3.9) and math.sin((t - 3.2) / 0.7 * math.pi) or 0
		if t > 3.3 and not roared then
			roared = true
			local hp = path(t)
			ring(hp, 14, th.a, 0.6, 0.4, 0.2)
			burst(hp, th.a, 40, 40, 1, nil, 0.6)
			light(hp, th.b, 12, 60, 0.6)
		end
		d.place(path, t, 0.035)
	end, function()
		burst(landing, th.a, 70, 60, 1.5, nil, 0.9)
		ring(center + Vector3.new(0, 0.4, 0), 20, th.b, 0.7, 0.6, 0.1)
		light(center + Vector3.new(0, 6, 0), th.b, 18, 80, 0.7)
		screenFlash(th.a, 0.3)
		d.fade(0.4)
	end)
end

-- ===================== efek dari server =====================
local FX = {}

function FX.UltStart(plr, el, center)
	ultCaster[el] = plr
	local c = plr.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root or not near(root.Position) then return end
	local th = THEME[el]
	darkSky(th.c:Lerp(Color3.new(1, 1, 1), 0.55), 6)
	if typeof(center) == "Vector3" and ULT[el] then task.spawn(ULT[el], plr, th, center) end
	-- aura naik di sekitar pemain
	ring(root.Position - Vector3.new(0, 2.8, 0), 10, th.b, 0.8, 0.25)
	local col = part(Vector3.new(60, 6, 6), CFrame.new(root.Position + Vector3.new(0, 28, 0)) * CFrame.Angles(0, 0, math.rad(90)), th.a, {Shape = Enum.PartType.Cylinder, Transparency = 0.6})
	tween(col, 0.5, {Size = Vector3.new(60, 0.4, 0.4)})
	fade(col, 0.4, 0.4)
	light(root.Position, th.b, 6, 24, 1.2)
end

function FX.ThunderStep(from, to, hits)
	if not near(from) then return end
	local th = THEME.Thunder
	bolt(from, to, 2.2, 0.35, 0.45, th, true)
	bolt(from + Vector3.new(0, 0.6, 0), to + Vector3.new(0, 0.6, 0), 1.6, 0.15, 0.4, th, false)
	burst(from, th.a, 20, 20, 0.6)
	burst(to, th.a, 25, 24, 0.7)
	light(to, th.b, 8, 20, 0.25)
	for _, p in hits do
		bolt(to + Vector3.new(0, 1, 0), p, 1.2, 0.12, 0.18, th, false)
		burst(p, th.a, 10, 18, 0.5)
	end
end

function FX.ThunderCloud(center, radius, life)
	if not near(center) then return end
	local th = THEME.Thunder
	local sky = center + Vector3.new(0, 30, 0)
	local parts = cloud(sky, radius * 1.1, th, life)
	-- kilatan di dalam awan
	for i = 1, 6 do
		task.delay(0.1 + i * 0.2, function()
			local p = parts[math.random(1, #parts)]
			if p.Parent then light(p.Position, th.b, 10, 30, 0.12) end
		end)
	end
	local warn = part(Vector3.new(0.12, radius * 2, radius * 2), CFrame.new(center + Vector3.new(0, 0.15, 0)) * FLAT, th.b, {Shape = Enum.PartType.Cylinder, Transparency = 0.75})
	fade(warn, 0.4, life)
end

function FX.Strike(pos, radius, big)
	if near(pos) then strike(pos, radius, big) end
end

function FX.NineClouds(center, radius)
	if not near(center) then return end
	local th = THEME.Thunder
	for i = 1, 9 do
		local a = (i / 9) * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * radius, 32, math.sin(a) * radius)
		task.delay(i * 0.04, function() cloud(p, 6, th, 2.6) end)
	end
	-- lingkaran rune di tanah
	local r1 = part(Vector3.new(0.12, radius * 2.2, radius * 2.2), CFrame.new(center + Vector3.new(0, 0.15, 0)) * FLAT, th.b, {Shape = Enum.PartType.Cylinder, Transparency = 0.7})
	local r2 = part(Vector3.new(0.14, radius * 1.6, radius * 1.6), CFrame.new(center + Vector3.new(0, 0.18, 0)) * FLAT, th.c, {Shape = Enum.PartType.Cylinder, Transparency = 0.5})
	fade(r1, 0.5, 2.6)
	fade(r2, 0.5, 2.6)
end

function FX.ThunderPillar(center, radius)
	if not near(center) then return end
	local th = THEME.Thunder
	local h = 90
	local pillar = part(Vector3.new(h, radius * 0.6, radius * 0.6), CFrame.new(center + Vector3.new(0, h / 2, 0)) * FLAT, th.a, {Shape = Enum.PartType.Cylinder, Transparency = 0.05})
	local glow = part(Vector3.new(h, radius * 1.3, radius * 1.3), CFrame.new(center + Vector3.new(0, h / 2, 0)) * FLAT, th.b, {Shape = Enum.PartType.Cylinder, Transparency = 0.55})
	tween(pillar, 1.1, {Size = Vector3.new(h, 0.5, 0.5)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	fade(pillar, 0.35, 0.9)
	fade(glow, 1.1, 0.3, {Size = Vector3.new(h, radius * 2.2, radius * 2.2)})
	for i = 1, 5 do
		local a = math.random() * math.pi * 2
		bolt(center + Vector3.new(0, 70, 0), center + Vector3.new(math.cos(a) * radius * 0.8, 0, math.sin(a) * radius * 0.8), 6, 0.4, 0.6, th, true)
	end
	ring(center + Vector3.new(0, 0.3, 0), radius * 1.2, th.a, 0.5, 0.6, 0.1)
	ring(center + Vector3.new(0, 0.5, 0), radius * 1.6, th.b, 0.8, 0.4, 0.4)
	burst(center + Vector3.new(0, 2, 0), th.a, 60, 55, 1.4, nil, 0.8)
	light(center + Vector3.new(0, 8, 0), th.b, 18, 60, 0.6)
	screenFlash(th.a, 0.35)
end

function FX.Chain(from, targets)
	if not near(from) then return end
	for _, p in targets do
		bolt(from, p, 1.2, 0.12, 0.18, THEME.Thunder, false)
		burst(p, THEME.Thunder.a, 8, 15, 0.4)
	end
end

function FX.FrostThrust(origin, dir, dist)
	if not near(origin) then return end
	local th = THEME.Ice
	local n = math.max(3, math.floor(dist / 3))
	for i = 1, n do
		task.delay(i * 0.035, function()
			local p = ground(origin + dir * (i * dist / n) + Vector3.new(0, 2, 0))
			iceSpike(p + dir:Cross(Vector3.yAxis) * (math.random() - 0.5) * 1.5, dir, 2.5 + i * 0.35, th, 0.9)
			if i % 2 == 0 then iceSpike(p, dir, 1.6 + i * 0.2, th, 0.8) end
		end)
	end
	burst(origin + dir * 3 + Vector3.new(0, 2, 0), th.a, 20, 25, 0.5)
end

function FX.FrozenField(center, radius, life)
	if not near(center) then return end
	local th = THEME.Ice
	local floor = part(Vector3.new(0.2, 1, 1), CFrame.new(center + Vector3.new(0, 0.12, 0)) * FLAT, th.b, {Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.3})
	tween(floor, 0.4, {Size = Vector3.new(0.2, radius * 2, radius * 2)}, Enum.EasingStyle.Quint)
	fade(floor, 0.5, life)
	local mist = part(Vector3.one * 0.2, CFrame.new(center + Vector3.new(0, 1, 0)), th.a, {Transparency = 1})
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX_SMOKE
	e.Color = ColorSequence.new(th.a, th.b)
	e.Size = NumberSequence.new(3, 6)
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1)})
	e.Lifetime = NumberRange.new(1, 1.6)
	e.Rate = 18
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Shape = Enum.ParticleEmitterShape.Cylinder
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = mist
	mist.Size = Vector3.new(radius * 2, 0.5, radius * 2)
	task.delay(life * 0.8, function() e.Enabled = false end)
	Debris:AddItem(mist, life + 1.8)
	for i = 1, 10 do
		task.delay(0.3 + i * 0.03, function()
			local a = math.random() * math.pi * 2
			local p = ground(center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * (0.3 + math.random() * 0.7))
			iceSpike(p, Vector3.new(math.cos(a), 0, math.sin(a)), 2 + math.random() * 2.5, th, life - 0.3)
		end)
	end
	ring(center + Vector3.new(0, 0.3, 0), radius, th.a, 0.45, 0.4, 0.15)
end

function FX.Shatter(center, radius)
	if not near(center) then return end
	local th = THEME.Ice
	burst(center + Vector3.new(0, 2, 0), th.a, 50, 40, 1, nil, 0.7)
	for i = 1, 14 do
		local a = math.random() * math.pi * 2
		local shard = part(Vector3.new(0.4, 0.4, 1.4), CFrame.new(center + Vector3.new(math.cos(a) * radius * 0.5, 1.5, math.sin(a) * radius * 0.5)), th.b, {Material = Enum.Material.Glass, Transparency = 0.2})
		local out = shard.Position + Vector3.new(math.cos(a), 0.6 + math.random(), math.sin(a)) * radius * 0.6
		tween(shard, 0.45, {CFrame = CFrame.lookAt(out, out + Vector3.new(math.cos(a), 0, math.sin(a))) * CFrame.Angles(math.random() * 3, 0, 0)})
		fade(shard, 0.3, 0.3)
	end
	ring(center + Vector3.new(0, 0.5, 0), radius * 1.2, th.a, 0.4, 0.5, 0.1)
	light(center + Vector3.new(0, 4, 0), th.b, 10, 35, 0.3)
end

function FX.IceSword(center, radius)
	if not near(center) then return end
	local th = THEME.Ice
	-- salju turun
	local snow = part(Vector3.new(radius * 3, 1, radius * 3), CFrame.new(center + Vector3.new(0, 40, 0)), th.a, {Transparency = 1})
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX_SPARK
	e.Color = ColorSequence.new(th.a)
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(0.35, 0.2)
	e.Lifetime = NumberRange.new(3, 4)
	e.Rate = 70
	e.Speed = NumberRange.new(10, 14)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(15, 15)
	e.Parent = snow
	task.delay(3.5, function() e.Enabled = false end)
	Debris:AddItem(snow, 8)
	-- pedang es raksasa: salinan roh dari pedang si pemakai
	local function landed()
		burst(center + Vector3.new(0, 1, 0), th.a, 60, 50, 1.3, nil, 0.8)
		ring(center + Vector3.new(0, 0.4, 0), radius, th.a, 0.5, 0.6, 0.1)
		ring(center + Vector3.new(0, 0.6, 0), radius * 1.3, th.b, 0.8, 0.4, 0.4)
		light(center + Vector3.new(0, 6, 0), th.b, 16, 60, 0.6)
		screenFlash(th.a, 0.3)
		-- kristal es tumbuh di area
		for i = 1, 18 do
			task.delay(i * 0.02, function()
				local a = math.random() * math.pi * 2
				local p = ground(center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * (0.25 + math.random() * 0.75))
				iceSpike(p, Vector3.new(math.cos(a), 0, math.sin(a)), 3 + math.random() * 5, th, 1.4)
			end)
		end
	end
	if spiritBlade("Ice", center, 34, th, 0.75, 1.4, landed) then return end
	local L = 34
	local top = center + Vector3.new(0, 80, 0)
	local blade = part(Vector3.new(L, 1.2, 6), CFrame.new(top) * CFrame.Angles(0, 0, math.rad(90)), th.b, {Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.3})
	local core = part(Vector3.new(L * 0.95, 0.5, 1.6), blade.CFrame, th.a, {Transparency = 0.05})
	local guard = part(Vector3.new(1.5, 2.5, 12), blade.CFrame * CFrame.new(L / 2, 0, 0), th.c, {Material = Enum.Material.Glass, Transparency = 0.1})
	local hilt = part(Vector3.new(7, 1.4, 1.4), blade.CFrame * CFrame.new(L / 2 + 4, 0, 0), th.a, {Transparency = 0.1})
	local parts = {blade, core, guard, hilt}
	local offs = {}
	for i, p in parts do offs[i] = blade.CFrame:ToObjectSpace(p.CFrame) end
	local fromCF = blade.CFrame
	local toCF = CFrame.new(center + Vector3.new(0, L / 2 - 6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	animate(0.75, function(k)
		local e2 = k * k * k
		local cf = fromCF:Lerp(toCF, e2)
		for i, p in parts do p.CFrame = cf * offs[i] end
	end, function()
		burst(center + Vector3.new(0, 1, 0), th.a, 60, 50, 1.3, nil, 0.8)
		ring(center + Vector3.new(0, 0.4, 0), radius, th.a, 0.5, 0.6, 0.1)
		ring(center + Vector3.new(0, 0.6, 0), radius * 1.3, th.b, 0.8, 0.4, 0.4)
		light(center + Vector3.new(0, 6, 0), th.b, 16, 60, 0.6)
		screenFlash(th.a, 0.3)
		for _, p in parts do fade(p, 0.4, 1.4) end
		-- kristal es tumbuh di area
		for i = 1, 18 do
			task.delay(i * 0.02, function()
				local a = math.random() * math.pi * 2
				local p = ground(center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * (0.25 + math.random() * 0.75))
				iceSpike(p, Vector3.new(math.cos(a), 0, math.sin(a)), 3 + math.random() * 5, th, 1.4)
			end)
		end
	end)
end

function FX.IceSever(center, radius, from)
	if not near(center) then return end
	local th = THEME.Ice
	-- tebasan langit: bulan sabit raksasa melintang lalu meledak jadi pecahan
	local dir = Vector3.new(center.X - from.X, 0, center.Z - from.Z)
	if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, -1) end
	dir = dir.Unit
	local start = center - dir * radius + Vector3.new(0, 3, 0)
	local slash, m = meshed(Vector3.new(radius * 2.4, 0.6, 5), CFrame.lookAt(start, start + dir), th.a, {Transparency = 0.05})
	local glow, m2 = meshed(Vector3.new(radius * 2.8, 0.3, 9), slash.CFrame, th.b, {Transparency = 0.5})
	animate(0.3, function(k)
		local p = start + dir * radius * 2 * k
		slash.CFrame = CFrame.lookAt(p, p + dir)
		glow.CFrame = slash.CFrame
	end, function()
		fade(slash, 0.25)
		fade(glow, 0.3)
	end)
	task.delay(0.2, function()
		FX.Shatter(center, radius)
		ring(center + Vector3.new(0, 0.6, 0), radius * 1.4, th.b, 0.7, 0.5, 0.3)
		screenFlash(th.a, 0.3)
	end)
end

function FX.Frost(m, t)
	if m and m.Parent then frostTint(m, t) end
end

function FX.Freeze(m, t)
	if m and m.Parent then encase(m, t, THEME.Ice) end
end

function FX.PetalDance(root, radius, dur)
	if not (root and root.Parent and near(root.Position)) then return end
	local th = THEME.Lotus
	petalStorm(root, radius, 26, dur, th, 4)
	for i = 0, 2 do
		task.delay(i * 0.22, function()
			if root.Parent then
				local s, m = meshed(Vector3.new(radius * 2, 0.4, radius * 2), CFrame.new(root.Position) * CFrame.Angles(0, i * 1.2, 0), th.b, {Transparency = 0.55})
				tween(m, 0.25, {Scale = Vector3.new(radius * 2.4, 0.2, radius * 2.4)})
				fade(s, 0.25)
			end
		end)
	end
end

function FX.LotusGuard(root, dur)
	if not (root and root.Parent and near(root.Position)) then return end
	local th = THEME.Lotus
	local pos = root.Position - Vector3.new(0, 2.8, 0)
	lotus(pos, 7, th, dur, 0.4)
	local bubble = part(Vector3.one * 2, root.CFrame, th.b, {Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Transparency = 0.2})
	tween(bubble, 0.3, {Size = Vector3.one * 9}, Enum.EasingStyle.Back)
	animate(dur, function()
		if root.Parent then bubble.CFrame = root.CFrame end
	end, function() fade(bubble, 0.3) end)
	task.delay(0.2, function()
		for i = 1, 16 do
			local a = i / 16 * math.pi * 2
			local p = petal(CFrame.new(root.Position) * CFrame.Angles(0, a, 0), 1.6, i % 2 == 0 and th.a or th.b)
			local out = root.Position + Vector3.new(math.cos(a), 0.2, math.sin(a)) * 10
			tween(p, 0.4, {CFrame = CFrame.lookAt(out, out + Vector3.new(math.cos(a), 0, math.sin(a)))})
			fade(p, 0.25, 0.25)
		end
		ring(root.Position - Vector3.new(0, 2.5, 0), 10, th.a, 0.4, 0.3)
	end)
end

function FX.LotusBloom(center, radius, dur)
	if not near(center) then return end
	local th = THEME.Lotus
	lotus(center + Vector3.new(0, 0.3, 0), radius, th, dur + 0.6, 0.8)
	petalStorm(center, radius, 60, dur + 0.5, th, 10)
	light(center + Vector3.new(0, 6, 0), th.b, 6, radius * 2, dur)
	for i = 0, 5 do
		task.delay(0.5 + i * 0.4, function()
			ring(center + Vector3.new(0, 0.4, 0), radius, i % 2 == 0 and th.b or th.c, 0.4, 0.3, 0.35)
		end)
	end
end

function FX.LotusFinale(center, radius)
	if not near(center) then return end
	local th = THEME.Lotus
	local col = part(Vector3.new(70, radius * 0.5, radius * 0.5), CFrame.new(center + Vector3.new(0, 35, 0)) * FLAT, th.c, {Shape = Enum.PartType.Cylinder, Transparency = 0.1})
	fade(col, 0.6, 0.1, {Size = Vector3.new(70, radius * 1.5, radius * 1.5)})
	for i = 1, 30 do
		local a = i / 30 * math.pi * 2
		local p = petal(CFrame.new(center + Vector3.new(0, 2, 0)) * CFrame.Angles(0, a, 0), 2.2, i % 3 == 0 and th.c or th.b)
		local out = center + Vector3.new(math.cos(a) * radius, 4 + math.random() * 6, math.sin(a) * radius)
		tween(p, 0.6, {CFrame = CFrame.lookAt(out, out + Vector3.new(math.cos(a), 0.3, math.sin(a)))})
		fade(p, 0.4, 0.4)
	end
	ring(center + Vector3.new(0, 0.4, 0), radius * 1.3, th.a, 0.6, 0.5, 0.1)
	burst(center + Vector3.new(0, 3, 0), th.c, 50, 45, 1.2, nil, 0.8)
	light(center + Vector3.new(0, 6, 0), th.c, 14, 60, 0.6)
	screenFlash(th.a, 0.35)
end

function FX.DragonRoar(pos, dir, range)
	if not near(pos) then return end
	local th = THEME.Jade
	for i = 0, 2 do
		task.delay(i * 0.07, function()
			local p0 = pos + dir * (2 + i * 2)
			local s, m = meshed(Vector3.new(4, 4, 1), CFrame.lookAt(p0, p0 + dir), i == 1 and th.c or th.b, {Transparency = 0.3, Material = i == 1 and Enum.Material.Neon or Enum.Material.ForceField})
			local p1 = pos + dir * range
			tween(s, 0.35, {CFrame = CFrame.lookAt(p1, p1 + dir)})
			tween(m, 0.35, {Scale = Vector3.new(range * 1.2, range * 0.7, 2)})
			fade(s, 0.2, 0.2)
		end)
	end
	-- kepala naga bayangan
	local head = part(Vector3.new(4, 3, 5), CFrame.lookAt(pos + dir * 2 + Vector3.new(0, 1, 0), pos + dir * 10), th.b, {Material = Enum.Material.Glass, Transparency = 0.3})
	tween(head, 0.35, {Size = Vector3.new(8, 6, 10), CFrame = head.CFrame * CFrame.new(0, 0, -6)})
	fade(head, 0.3, 0.1)
	burst(pos + dir * 4, th.a, 25, 30, 0.8)
	light(pos + dir * 4, th.b, 8, 25, 0.3)
end

function FX.DragonRush(from, dir, dist, dur)
	if not near(from) then return end
	local th = THEME.Jade
	local d = makeDragon(2.2, th)
	local side = dir:Cross(Vector3.yAxis).Unit
	local path = function(t)
		local s = t * dist
		return from + dir * s + side * math.sin(s * 0.35) * 1.5 + Vector3.new(0, math.sin(s * 0.25) * 1 + 1, 0)
	end
	local spacing = 1.6 / dist
	animate(dur + 0.25, function(k)
		local t = k * (dur + 0.25) / dur
		d.place(path, t, spacing)
		if math.random() < 0.3 then burst(path(t), th.a, 3, 6, 0.5) end
	end, function() d.fade(0.3) end)
end

function FX.DragonDescend(center, radius, dur)
	if not near(center) then return end
	local th = THEME.Jade
	local r1 = part(Vector3.new(0.12, radius * 2.2, radius * 2.2), CFrame.new(center + Vector3.new(0, 0.15, 0)) * FLAT, th.b, {Shape = Enum.PartType.Cylinder, Transparency = 0.7})
	fade(r1, 0.4, dur)
	if os.clock() - (ULT.recent.Jade or -99) < 8 then return end -- the jade dragon set piece already dives in
	local d = makeDragon(4, th)
	local laps = 1.6
	local path = function(t)
		t = math.max(t, 0)
		local a = t * laps * math.pi * 2
		local r = radius * (1 - t * 0.85)
		local h = 70 * (1 - t) + 3
		return center + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)
	end
	local spacing = 0.03
	animate(dur, function(k)
		d.place(path, k, spacing)
	end, function() d.fade(0.4) end)
end

function FX.JadeImpact(center, radius)
	if not near(center) then return end
	local th = THEME.Jade
	ring(center + Vector3.new(0, 0.3, 0), radius, th.a, 0.45, 0.8, 0.05)
	ring(center + Vector3.new(0, 0.5, 0), radius * 1.4, th.c, 0.8, 0.5, 0.3)
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local rock = part(Vector3.new(2.5, 2.5, 2.5), CFrame.new(center + Vector3.new(math.cos(a) * 3, 0, math.sin(a) * 3)), th.b, {Material = Enum.Material.Glass, Transparency = 0.2})
		local out = center + Vector3.new(math.cos(a) * radius * 0.8, 3 + math.random() * 5, math.sin(a) * radius * 0.8)
		tween(rock, 0.5, {CFrame = CFrame.new(out) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), Size = Vector3.one * 1.2})
		fade(rock, 0.3, 0.4)
	end
	local col = part(Vector3.new(50, radius * 0.6, radius * 0.6), CFrame.new(center + Vector3.new(0, 25, 0)) * FLAT, th.a, {Shape = Enum.PartType.Cylinder, Transparency = 0.1})
	fade(col, 0.5, 0.05, {Size = Vector3.new(50, radius * 1.4, radius * 1.4)})
	burst(center + Vector3.new(0, 2, 0), th.c, 50, 50, 1.2, nil, 0.8)
	light(center + Vector3.new(0, 6, 0), th.b, 16, 60, 0.6)
	screenFlash(th.a, 0.35)
end

function FX.JadeBurst(pos)
	if not near(pos) then return end
	ring(pos, 5, THEME.Jade.b, 0.3, 0.3)
	burst(pos, THEME.Jade.a, 14, 22, 0.6)
end

FxRemote.OnClientEvent:Connect(function(kind, ...)
	local f = FX[kind]
	if f then task.spawn(f, ...) end
end)
