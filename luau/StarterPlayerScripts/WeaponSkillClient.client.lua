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
local function ring(pos, radius, color, t, thick, transp)
	local r = part(Vector3.new(thick or 0.3, 1, 1), CFrame.new(pos) * FLAT, color, {Shape = Enum.PartType.Cylinder, Transparency = transp or 0.2})
	tween(r, t, {Size = Vector3.new(thick or 0.3, radius * 2, radius * 2)}, Enum.EasingStyle.Quint)
	fade(r, t * 0.8, t * 0.4)
	return r
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
local function cloud(pos, size, th, life)
	local parts = {}
	for i = 1, 6 do
		local off = Vector3.new((math.random() - 0.5) * size * 1.4, (math.random() - 0.5) * size * 0.25, (math.random() - 0.5) * size * 1.4)
		local s = size * (0.45 + math.random() * 0.35)
		local b = part(Vector3.new(s, s * 0.55, s), CFrame.new(pos + off), th.c, {Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Transparency = 1})
		tween(b, 0.4, {Transparency = 0.18})
		fade(b, 0.6, life)
		table.insert(parts, b)
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX_SMOKE
	e.Color = ColorSequence.new(Color3.fromRGB(70, 80, 110))
	e.Size = NumberSequence.new(size * 0.5, size * 0.9)
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1)})
	e.Lifetime = NumberRange.new(1, 1.6)
	e.Rate = 6
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 20)
	e.Parent = parts[1]
	task.delay(life, function() e.Enabled = false end)
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
	local scorch = part(Vector3.new(0.15, radius * 1.4, radius * 1.4), CFrame.new(pos + Vector3.new(0, 0.1, 0)) * FLAT, th.a, {Shape = Enum.PartType.Cylinder, Transparency = 0.3})
	fade(scorch, 0.4, 0.05)
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

local function cutIn(text, th)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	tween(topBar, 0.25, {Size = UDim2.fromScale(1, 0.12)})
	tween(botBar, 0.25, {Size = UDim2.fromScale(1, 0.12)})
	title.Text = text
	title.TextColor3 = th.a
	title.TextStrokeColor3 = th.b
	tween(title, 0.3, {TextTransparency = 0, TextStrokeTransparency = 0.1})
	local head = char:FindFirstChild("Head") or root
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt((root.CFrame * CFrame.new(1.8, 1.6, -6.5)).Position, head.Position)
	tween(cam, 0.8, {CFrame = CFrame.lookAt((root.CFrame * CFrame.new(1.1, 1.7, -4.3)).Position, head.Position)}, Enum.EasingStyle.Sine)
	burst(root.Position, th.a, 30, 14, 0.8)
	ring(root.Position - Vector3.new(0, 2.5, 0), 8, th.b, 0.6, 0.25)
	task.wait(0.85)
	screenFlash(th.a, 0.45)
	tween(cam, 0.45, {CFrame = CFrame.lookAt((root.CFrame * CFrame.new(0, 14, 26)).Position, root.Position + root.CFrame.LookVector * 14)}, Enum.EasingStyle.Quad)
	task.wait(0.45)
	cam.CameraType = Enum.CameraType.Custom
	tween(topBar, 0.3, {Size = UDim2.fromScale(1, 0)})
	tween(botBar, 0.3, {Size = UDim2.fromScale(1, 0)})
	task.delay(1.2, function() tween(title, 0.5, {TextTransparency = 1, TextStrokeTransparency = 1}) end)
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
	local tr = track(hum, s[3])
	if tr then tr:Play(0.08) end
	local speed = hum.WalkSpeed
	if key == "G" then
		hum.WalkSpeed = 0
		cutIn(s[1]:upper(), THEME[el])
		task.wait(0.4)
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

-- ===================== efek dari server =====================
local FX = {}

function FX.UltStart(plr, el)
	local c = plr.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root or not near(root.Position) then return end
	local th = THEME[el]
	darkSky(th.c:Lerp(Color3.new(1, 1, 1), 0.55), 5)
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
	-- pedang es raksasa
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
	local r1 = part(Vector3.new(0.12, radius * 2.2, radius * 2.2), CFrame.new(center + Vector3.new(0, 0.15, 0)) * FLAT, th.b, {Shape = Enum.PartType.Cylinder, Transparency = 0.7})
	fade(r1, 0.4, dur)
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
