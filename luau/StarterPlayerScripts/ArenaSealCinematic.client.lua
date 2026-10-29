-- Sinematik "Break the Seal" v2 (hanya di layar pemain yang memicu), ~8 detik, dengan suara (pustaka APM berlisensi Roblox):
-- 1) bidikan lebar rendah + bilah sinema, tanah bergetar, debu jatuh, riser & drone
-- 2) dekat: jimat menyala & terbakar beruntun (mantra whoosh)
-- 3) rantai membara lalu PECAH: serpihan mata rantai terlempar, kilat putih, gelombang kejut, gong + sub boom
-- 4) pintu batu raksasa terbuka berat: gemuruh & braam, cahaya membanjir, debu, judul 封印已破
-- 5) kamera menerobos gerbang -> layar putih -> server memindahkan pemain (8.0 dtk) -> pudar
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local Run = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ev = RS:WaitForChild("ArenaSealFx")
local player = Players.LocalPlayer
local playing = false

local SFX = {
	riser = {1837834536, 0.7}, drone = {9043355570, 0.8}, spell = {108306323478967, 0.75},
	metal = {9043356042, 0.9}, chains = {9046406229, 1.0}, boom = {1837830182, 1.0},
	gong = {9048840285, 0.85}, rumble = {1845133529, 1.0}, braam = {131557850414701, 0.85},
	whoosh = {107073250463751, 1.0},
}
local cache = {}
local function sfx(key, vol, pitch, t0)
	local d = SFX[key]
	local s = cache[key]
	if not s then
		s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. d[1]
		s.Parent = workspace.CurrentCamera
		local rv = Instance.new("ReverbSoundEffect")
		rv.DecayTime, rv.WetLevel, rv.DryLevel = 2.5, -8, 0
		rv.Parent = s
		cache[key] = s
	end
	s.Volume = (vol or 1) * d[2]
	s.PlaybackSpeed = pitch or 1
	s.TimePosition = t0 or 0
	s:Play()
	return s
end
local function fadeOut(s, t)
	if s then TS:Create(s, TweenInfo.new(t), {Volume = 0}):Play() task.delay(t, function() s:Stop() end) end
end
task.defer(function()   -- muat suara lebih awal supaya tidak telat saat dipicu
	for k in SFX do local s = sfx(k, 0) s:Stop() end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync((function() local t = {} for _, s in cache do table.insert(t, s) end return t end)()) end)
end)

local function nameOf(p) return (p.Name:gsub("%.%d+$", "")) end
local function collect(model)
	local g = {L = {}, R = {}, Paper = {}, Ink = {}, Chain = {}, Bronze = {}, Beam = {}}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local n = nameOf(p)
			if n:match("^ReliefDoorL__") then table.insert(g.L, p)
			elseif n:match("^ReliefDoorR__") then table.insert(g.R, p)
			elseif n == "DoorSeal__TalismanPaper" then table.insert(g.Paper, p)
			elseif n == "DoorSeal__CinnabarInk" then table.insert(g.Ink, p)
			elseif n == "DoorSeal__ArenaIron" then table.insert(g.Chain, p)
			elseif n == "DoorSeal__AgedBronze" then table.insert(g.Bronze, p)
			elseif n:match("^DoorLight__") then table.insert(g.Beam, p)
			end
		end
	end
	return g
end

local function emitter(pos, size, c1, c2, rate, life, speed, tex, dur, sz, accel, spread)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency, a.CastShadow = true, false, false, false, 1, false
	a.Size, a.Position = size, pos
	a.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(c1, c2)
	e.LightEmission, e.Rate = tex and 0.2 or 1, rate
	e.Lifetime, e.Speed = NumberRange.new(life * 0.6, life), NumberRange.new(speed * 0.5, speed)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, sz or 0.6), NumberSequenceKeypoint.new(1, tex and (sz or 0.6) * 3 or 0)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, tex and 0.4 or 0), NumberSequenceKeypoint.new(1, 1)})
	e.SpreadAngle, e.Acceleration = spread or Vector2.new(180, 180), accel or Vector3.new(0, 6, 0)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = a
	task.delay(dur, function() e.Enabled = false end)
	Debris:AddItem(a, dur + life + 0.5)
	return e
end
local function tweenAll(parts, info, goal) for _, p in parts do TS:Create(p, info, goal):Play() end end

local function play()
	if playing then return end
	local model = workspace:FindFirstChild("BossArena")
	if not model then return end
	playing = true
	local portals = workspace:FindFirstChild("ArenaPortals")
	local pp = portals and portals:FindFirstChild("DoorEnter") and portals.DoorEnter:FindFirstChildOfClass("ProximityPrompt")
	if pp then pp.Enabled = false end   -- prompt disembunyikan selama sinematik (lokal)
	local g = collect(model)
	local S = model:GetAttribute("StudsPerMeter") or 3.57
	local function W(x, y, z) return Vector3.new(-6000 + x * S, 1000 + z * S, -y * S) end
	local hingeL, hingeR = model:GetAttribute("HingeL"), model:GetAttribute("HingeR")
	local center = model:GetAttribute("DoorCenter")
	local saved = {}
	for _, list in g do for _, p in list do saved[p] = {p.CFrame, p.Transparency, p.Color, p.Material, p.Size} end end

	-- pemain diam, HUD disembunyikan, bilah sinema
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local ws, jp = hum and hum.WalkSpeed, hum and hum.JumpPower
	if hum then hum.WalkSpeed, hum.JumpPower = 0, 0 end
	local hidden = {}
	for _, gui in player.PlayerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled then gui.Enabled = false table.insert(hidden, gui) end
	end
	local sg = Instance.new("ScreenGui")
	sg.Name, sg.IgnoreGuiInset, sg.DisplayOrder, sg.ResetOnSpawn = "SealCinema", true, 50, false
	sg.Parent = player.PlayerGui
	local function bar(top)
		local f = Instance.new("Frame")
		f.BackgroundColor3, f.BorderSizePixel = Color3.new(0, 0, 0), 0
		f.Size = UDim2.fromScale(1, 0)
		f.AnchorPoint = Vector2.new(0, top and 0 or 1)
		f.Position = UDim2.fromScale(0, top and 0 or 1)
		f.Parent = sg
		TS:Create(f, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(1, 0.12)}):Play()
		return f
	end
	local bt, bb = bar(true), bar(false)
	local white = Instance.new("Frame")
	white.BackgroundColor3, white.BorderSizePixel, white.BackgroundTransparency = Color3.new(1, 1, 1), 0, 1
	white.Size = UDim2.fromScale(1, 1)
	white.ZIndex = 5
	white.Parent = sg
	local function flash(a, t) white.BackgroundTransparency = a TS:Create(white, TweenInfo.new(t), {BackgroundTransparency = 1}):Play() end
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency, title.Size, title.Position = 1, UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0.36)
	title.Font, title.Text, title.TextScaled = Enum.Font.Antique, "封 印 已 破", true
	title.TextColor3, title.TextStrokeColor3, title.TextTransparency, title.TextStrokeTransparency = Color3.fromRGB(255, 214, 120), Color3.fromRGB(80, 10, 0), 1, 1
	title.ZIndex = 4
	title.Parent = sg
	local sub = title:Clone()
	sub.Text, sub.Font = "THE DEMON-SEALING GATE IS BROKEN", Enum.Font.GothamBold
	sub.Size, sub.Position = UDim2.fromScale(1, 0.04), UDim2.fromScale(0, 0.55)
	sub.Parent = sg
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SealGrade"
	cc.Parent = Lighting
	TS:Create(cc, TweenInfo.new(1.5), {Contrast = 0.25, Saturation = -0.25, TintColor = Color3.fromRGB(255, 232, 214)}):Play()
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.4, 30, 1.1
	bloom.Parent = Lighting

	-- kamera: nilai dasar ditween, guncangan & FOV ditambahkan tiap frame
	local cam = workspace.CurrentCamera
	local oldType, oldFov = cam.CameraType, cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local base = Instance.new("CFrameValue")
	base.Value = cam.CFrame
	local fov = Instance.new("NumberValue")
	fov.Value = cam.FieldOfView
	local shake = 0
	local conn = Run.RenderStepped:Connect(function()
		local tt = os.clock() * 32
		cam.FieldOfView = fov.Value
		cam.CFrame = base.Value * CFrame.new(math.noise(tt, 0.3) * shake, math.noise(0.7, tt) * shake, 0)
			* CFrame.Angles(math.noise(tt, 2.1) * shake * 0.01, 0, math.noise(tt, tt) * shake * 0.025)
	end)
	local function shot(cf, t, style, fv)
		TS:Create(base, TweenInfo.new(t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Value = cf}):Play()
		if fv then TS:Create(fov, TweenInfo.new(t, Enum.EasingStyle.Sine), {Value = fv}):Play() end
	end
	local wideFrom = CFrame.lookAt(W(-14, -48, 2.5), W(0, 0, 22))
	local wideTo = CFrame.lookAt(W(-6, -34, 4), W(0, 0, 19))

	-- ===== 1. bidikan lebar: tanah bergetar, debu jatuh dari gerbang, riser
	local riser = sfx("riser", 1, 1, 0)
	local drone = sfx("drone", 1, 0.8, 0)
	shot(wideFrom, 1.0, Enum.EasingStyle.Quad, 55)
	task.delay(1.0, function() shot(wideTo, 1.3, Enum.EasingStyle.Sine, 50) end)
	for i = 1, 3 do
		task.delay(0.3 * i, function() shake = 0.06 * i end)
	end
	emitter(W(0, -2.5, 34), Vector3.new(14 * S, 1, 2 * S), Color3.fromRGB(160, 150, 140), Color3.fromRGB(110, 104, 98), 60, 3, 2,
		"rbxasset://textures/particles/smoke_main.dds", 2.2, 1.2, Vector3.new(0, -18, 0), Vector2.new(15, 15))
	for _, p in g.Paper do p.Material = Enum.Material.Neon end
	tweenAll(g.Paper, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true), {Color = Color3.fromRGB(255, 200, 110)})
	task.wait(2.2)

	-- ===== 2. dekat ke pintu: jimat terbakar beruntun
	shot(CFrame.lookAt(W(3, -16, 10), W(0, -1, 14)), 0.5, Enum.EasingStyle.Quad, 48)
	shake = 0.12
	for i = 1, 6 do
		task.delay((i - 1) * 0.18, function()
			if i % 2 == 1 then sfx("spell", 0.7, 0.85 + i * 0.05) end
			for _ = 1, 3 do
				local p = W(math.random(-60, 60) / 10, -1.4, math.random(52, 280) / 10)
				emitter(p, Vector3.new(1.4, 3.6, 0.4), Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 70, 10), 140, 1.3, 7, nil, 0.35, 0.7)
				emitter(p, Vector3.new(1.2, 3, 0.4), Color3.fromRGB(70, 60, 55), Color3.fromRGB(25, 22, 20), 18, 2.2, 3,
					"rbxasset://textures/particles/smoke_main.dds", 0.4, 1.0)
			end
		end)
	end
	task.wait(0.5)
	tweenAll(g.Paper, TweenInfo.new(0.7), {Transparency = 1})
	tweenAll(g.Ink, TweenInfo.new(0.5), {Transparency = 1})
	task.wait(0.8)

	-- ===== 3. rantai membara lalu pecah
	shot(CFrame.lookAt(W(-5, -20, 6), W(0, -1, 15)), 0.4, Enum.EasingStyle.Quad, 52)
	sfx("metal", 1, 0.9)
	for _, p in g.Chain do p.Material = Enum.Material.Neon end
	tweenAll(g.Chain, TweenInfo.new(0.55), {Color = Color3.fromRGB(255, 80, 20)})
	shake = 0.25
	task.wait(0.6)
	sfx("chains", 1)
	sfx("boom", 1, 0.9)
	fadeOut(riser, 0.4)
	tweenAll(g.Chain, TweenInfo.new(0.12), {Transparency = 1})
	tweenAll(g.Bronze, TweenInfo.new(0.12), {Transparency = 1})
	flash(0.15, 0.6)
	fov.Value = 40
	TS:Create(fov, TweenInfo.new(0.7, Enum.EasingStyle.Back), {Value = 58}):Play()
	shake = 1.1
	-- serpihan mata rantai terlempar di sepanjang dua rantai menyilang
	local GW, GZ, GH = 15, 3.2, 27
	for _, sgn in {-1, 1} do
		for k = 0, 14 do
			local t = k / 14
			local pos = W(sgn * (GW / 2 - 1.2) * (1 - 2 * t), -1.7, (GZ + GH - 2.2) + ((GZ + 2.2) - (GZ + GH - 2.2)) * t)
			local link = Instance.new("Part")
			link.Size = Vector3.new(0.55, 0.35, 1.0) * S * 0.6
			link.Material, link.Color = Enum.Material.CorrodedMetal, Color3.fromRGB(200, 70, 30)
			link.CanCollide, link.CanQuery, link.CanTouch, link.Massless = true, false, false, true
			link.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			link.Parent = workspace
			link.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.random(10, 45), math.random(18, 55))
			link.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
			TS:Create(link, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.4), {Color = Color3.fromRGB(70, 50, 40)}):Play()
			Debris:AddItem(link, 4)
		end
	end
	emitter(center, Vector3.new(14 * S, 22 * S, 1), Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 50, 10), 1200, 1.6, 40, nil, 0.25, 0.9)
	-- gelombang kejut di tanah
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material, ring.Color, ring.Transparency = Enum.Material.Neon, Color3.fromRGB(255, 220, 160), 0.2
	ring.Size = Vector3.new(0.4, 4, 4)
	ring.CFrame = CFrame.new(W(0, -6, GZ + 0.15)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TS:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0.2, 70 * S, 70 * S), Transparency = 1}):Play()
	Debris:AddItem(ring, 1.2)
	task.wait(0.55)

	-- ===== 4. pintu terbuka berat: gemuruh, braam, cahaya membanjir, judul
	shot(CFrame.lookAt(W(0, -30, 5), W(0, 0, 15)), 2.6, Enum.EasingStyle.Sine, 62)
	sfx("rumble", 1, 0.85)
	sfx("braam", 1)
	shake = 0.45
	for _, b in g.Beam do
		b.Material = Enum.Material.Neon
		TS:Create(b, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Size = b.Size * Vector3.new(60, 1, 1), Transparency = 0}):Play()
	end
	-- dinding cahaya di balik pintu: mengisi seluruh bukaan sehingga isi lorong tidak terlihat sampai menerobos
	local glow = Instance.new("Part")
	glow.Name = "GateGlow"
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = true, false, false, false, false
	glow.Material, glow.Color, glow.Transparency = Enum.Material.Neon, Color3.fromRGB(255, 250, 238), 1
	glow.Size = Vector3.new((GW + 1) * S, (GH + 1) * S, 0.6 * S)
	glow.CFrame = CFrame.new(W(0, 2.6, GZ + GH / 2))
	glow.Parent = workspace
	TS:Create(glow, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {Transparency = 0}):Play()
	local halo = glow:Clone()      -- lapisan pendar lebih lebar di depan bukaan
	halo.Size = Vector3.new((GW + 6) * S, (GH + 5) * S, 0.2)
	halo.CFrame = CFrame.new(W(0, 0.3, GZ + GH / 2))
	halo.Transparency = 1
	halo.Parent = workspace
	TS:Create(halo, TweenInfo.new(2.2, Enum.EasingStyle.Sine), {Transparency = 0.55}):Play()
	local pl = Instance.new("SurfaceLight")
	pl.Face, pl.Brightness, pl.Range, pl.Angle, pl.Color = Enum.NormalId.Back, 6, 60, 120, Color3.fromRGB(255, 244, 220)
	pl.Parent = glow
	TS:Create(bloom, TweenInfo.new(2.4), {Intensity = 1.6, Threshold = 0.85}):Play()
	emitter(W(0, -4, GZ + 0.5), Vector3.new(16 * S, 1, 3 * S), Color3.fromRGB(170, 160, 150), Color3.fromRGB(100, 96, 92), 160, 3.5, 6,
		"rbxasset://textures/particles/smoke_main.dds", 2.2, 3, Vector3.new(0, 2, -4), Vector2.new(70, 20))
	emitter(W(0, -2.5, GZ + GH + 3), Vector3.new(16 * S, 1, 1 * S), Color3.fromRGB(150, 145, 140), Color3.fromRGB(110, 105, 100), 50, 2.5, 1,
		"rbxasset://textures/particles/smoke_main.dds", 2.0, 0.8, Vector3.new(0, -25, 0), Vector2.new(10, 10))
	local ang = Instance.new("NumberValue")
	ang.Changed:Connect(function()
		local a = math.rad(ang.Value)
		for _, p in g.L do p.CFrame = CFrame.new(hingeL) * CFrame.Angles(0, a, 0) * CFrame.new(hingeL):ToObjectSpace(saved[p][1]) end
		for _, p in g.R do p.CFrame = CFrame.new(hingeR) * CFrame.Angles(0, -a, 0) * CFrame.new(hingeR):ToObjectSpace(saved[p][1]) end
	end)
	TS:Create(ang, TweenInfo.new(2.6, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {Value = 86}):Play()
	task.delay(0.6, function()
		TS:Create(title, TweenInfo.new(0.8), {TextTransparency = 0, TextStrokeTransparency = 0.2}):Play()
		TS:Create(sub, TweenInfo.new(1.0), {TextTransparency = 0.1, TextStrokeTransparency = 0.4}):Play()
	end)
	task.wait(1.4)
	shake = 0.3
	task.wait(1.0)
	sfx("gong", 1, 0.95)
	shake = 0.7
	task.wait(0.35)
	TS:Create(title, TweenInfo.new(0.6), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	TS:Create(sub, TweenInfo.new(0.6), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()

	-- ===== 5. menerobos gerbang -> putih -> pindah
	sfx("whoosh", 1, 0.9)
	shot(CFrame.lookAt(W(0, 6, 15), W(0, 40, 12)), 1.0, Enum.EasingStyle.Quad, 85)
	shake = 0.2
	task.delay(0.55, function() TS:Create(white, TweenInfo.new(0.4), {BackgroundTransparency = 0}):Play() end)
	fadeOut(drone, 1.5)
	task.wait(1.1)   -- total ~8.0 dtk: server memindahkan pemain ke balik pintu

	glow:Destroy()
	halo:Destroy()
	-- ===== selesai: kamera kembali normal, layar putih memudar, gerbang dikembalikan
	shake = 0
	conn:Disconnect()
	cam.CameraType = oldType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or oldType
	cam.FieldOfView = oldFov
	if hum then hum.WalkSpeed, hum.JumpPower = ws, jp end
	task.wait(0.35)
	TS:Create(white, TweenInfo.new(1.0), {BackgroundTransparency = 1}):Play()
	TS:Create(bt, TweenInfo.new(0.8), {Size = UDim2.fromScale(1, 0)}):Play()
	TS:Create(bb, TweenInfo.new(0.8), {Size = UDim2.fromScale(1, 0)}):Play()
	TS:Create(cc, TweenInfo.new(1.0), {Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1)}):Play()
	TS:Create(bloom, TweenInfo.new(1.0), {Intensity = 0}):Play()
	task.wait(1.05)
	for _, gui in hidden do gui.Enabled = true end
	sg:Destroy()
	cc:Destroy()
	bloom:Destroy()
	ang:Destroy()
	base:Destroy()
	fov:Destroy()
	for p, st in saved do p.CFrame, p.Transparency, p.Color, p.Material, p.Size = st[1], st[2], st[3], st[4], st[5] end
	if pp then pp.Enabled = true end
	playing = false
end

ev.OnClientEvent:Connect(play)
