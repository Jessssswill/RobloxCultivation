-- Sinematik "Break the Seal" di gerbang 镇魔台 (hanya di layar pemain yang membuka segel)
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local Run = game:GetService("RunService")
local Players = game:GetService("Players")
local ev = RS:WaitForChild("ArenaSeal")
local player = Players.LocalPlayer
local busy = false

local function collect(m, prefix)
	local t = {}
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Name:sub(1, #prefix) == prefix then table.insert(t, p) end
	end
	return t
end
local function emitter(parent, tex, c1, c2, size0, size1, life, speed, light)
	local e = Instance.new("ParticleEmitter")
	e.Texture, e.Rate = tex, 0
	e.Color = ColorSequence.new(c1, c2)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size0), NumberSequenceKeypoint.new(1, size1)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	e.Lifetime, e.Speed, e.SpreadAngle = life, speed, Vector2.new(180, 180)
	e.LightEmission, e.Drag = light, 2
	e.Parent = parent
	return e
end

ev.OnClientEvent:Connect(function()
	if busy then return end
	local m = workspace:FindFirstChild("BossArena")
	if not m then return end
	busy = true
	local cam = workspace.CurrentCamera
	local hingeL, hingeR = m:GetAttribute("HingeL"), m:GetAttribute("HingeR")
	local center, behind = m:GetAttribute("DoorCenter"), m:GetAttribute("DoorBehind")
	local doorL, doorR = collect(m, "ReliefDoorL"), collect(m, "ReliefDoorR")
	local seal, beam = collect(m, "DoorSeal"), collect(m, "DoorLight")
	local saved = {}
	for _, list in {doorL, doorR, seal, beam} do
		for _, p in list do saved[p] = {p.CFrame, p.Transparency, p.Color, p.Material} end
	end
	local trash = {}
	local function keep(x) table.insert(trash, x) return x end

	-- kamera sinematik + getaran
	cam.CameraType = Enum.CameraType.Scriptable
	local camFrom = CFrame.lookAt(m:GetAttribute("SealCam"), m:GetAttribute("SealLook"))
	local camTo = camFrom * CFrame.new(0, 2, -18)
	local t0, shake = os.clock(), 0
	keep(Run.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / 3.4, 0, 1)
		local o = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake
		cam.CFrame = camFrom:Lerp(camTo, a * a) * CFrame.new(o)
		shake *= 0.94
	end))

	local fx = keep(Instance.new("Part"))
	fx.Anchored, fx.CanCollide, fx.CanQuery, fx.CanTouch, fx.Transparency, fx.Size = true, false, false, false, 1, Vector3.one
	fx.Position = center
	fx.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 170, 90), 60, 0, false
	light.Parent = fx
	local sparks = emitter(fx, "rbxasset://textures/particles/sparkles_main.dds", Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 70, 20),
		1.2, 0, NumberRange.new(0.6, 1.6), NumberRange.new(25, 60), 1)
	local embers = emitter(fx, "rbxasset://textures/particles/fire_main.dds", Color3.fromRGB(255, 150, 40), Color3.fromRGB(120, 20, 10),
		4, 10, NumberRange.new(0.8, 1.6), NumberRange.new(6, 16), 1)
	local smoke = emitter(fx, "rbxasset://textures/particles/smoke_main.dds", Color3.fromRGB(60, 40, 40), Color3.fromRGB(20, 18, 20),
		14, 40, NumberRange.new(2, 3.5), NumberRange.new(8, 18), 0)

	-- 1) jimat menyala & rantai membara
	for _, p in seal do
		local n = p.Name
		if n:find("TalismanPaper") or n:find("CinnabarInk") then
			p.Material = Enum.Material.Neon
			TS:Create(p, TweenInfo.new(0.5), {Color = Color3.fromRGB(255, 150, 40)}):Play()
		elseif n:find("ArenaIron") or n:find("AgedBronze") then
			p.Material = Enum.Material.Neon
			TS:Create(p, TweenInfo.new(0.8), {Color = Color3.fromRGB(255, 70, 25)}):Play()
		end
	end
	TS:Create(light, TweenInfo.new(0.8), {Brightness = 5}):Play()
	sparks:Emit(90)
	embers:Emit(30)
	shake = 0.4
	task.wait(0.8)

	-- 2) segel pecah: gelombang kejut, jimat jadi abu, rantai & gembok runtuh
	shake = 2.2
	sparks:Emit(260)
	embers:Emit(60)
	smoke:Emit(45)
	for _, p in seal do
		TS:Create(p, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1,
			CFrame = p.CFrame * CFrame.new(math.random(-3, 3), -8, math.random(-2, 2)) * CFrame.Angles(math.rad(math.random(-50, 50)), 0, math.rad(math.random(-50, 50)))}):Play()
	end
	local ring = keep(Instance.new("Part"))
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material, ring.Color, ring.Transparency = Enum.Material.Neon, Color3.fromRGB(255, 230, 180), 0.1
	ring.Size = Vector3.new(0.6, 4, 4)
	ring.CFrame = CFrame.lookAt(center, center + (cam.CFrame.Position - center).Unit) * CFrame.Angles(0, math.rad(90), 0)
	ring.Parent = workspace
	TS:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = Vector3.new(0.3, 170, 170), Transparency = 1}):Play()
	for _, p in beam do
		p.Material = Enum.Material.Neon
		TS:Create(p, TweenInfo.new(0.4), {Color = Color3.new(1, 1, 1)}):Play()
	end
	task.wait(0.5)

	-- 3) pintu raksasa terbuka ke dalam, cahaya membanjir dari balik pintu
	local flood = keep(Instance.new("Part"))
	flood.Anchored, flood.CanCollide, flood.CanQuery, flood.CanTouch, flood.CastShadow = true, false, false, false, false
	flood.Material, flood.Color, flood.Transparency = Enum.Material.Neon, Color3.fromRGB(255, 245, 225), 0
	flood.Size = m:GetAttribute("DoorSize")
	flood.CFrame = CFrame.lookAt(behind, center)
	flood.Parent = workspace
	local relL, relR = {}, {}
	for _, p in doorL do relL[p] = hingeL:ToObjectSpace(p.CFrame) end
	for _, p in doorR do relR[p] = hingeR:ToObjectSpace(p.CFrame) end
	local s0 = os.clock()
	shake = 1.0
	keep(Run.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - s0) / 1.9, 0, 1)
		local e = 1 - (1 - a) ^ 3
		local ang = math.rad(100) * e
		for p, r in relL do p.CFrame = hingeL * CFrame.Angles(0, ang, 0) * r end
		for p, r in relR do p.CFrame = hingeR * CFrame.Angles(0, -ang, 0) * r end
		if a < 1 then shake = math.max(shake, 0.35) end
	end))
	TS:Create(light, TweenInfo.new(1.6), {Brightness = 10, Range = 60, Color = Color3.fromRGB(255, 240, 210)}):Play()
	smoke:Emit(25)
	task.wait(1.6)

	-- 4) kilat putih -> server memindahkan pemain ke balik pintu
	local gui = keep(Instance.new("ScreenGui"))
	gui.IgnoreGuiInset, gui.DisplayOrder, gui.ResetOnSpawn = true, 50, false
	local white = Instance.new("Frame")
	white.Size, white.BackgroundColor3, white.BackgroundTransparency, white.BorderSizePixel = UDim2.fromScale(1, 1), Color3.new(1, 1, 1), 1, 0
	white.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	TS:Create(white, TweenInfo.new(0.35), {BackgroundTransparency = 0}):Play()
	task.wait(0.9)

	-- pulihkan gerbang (tetap bersegel untuk kunjungan berikutnya) & kamera
	for _, c in trash do
		if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
	end
	for p, v in saved do
		if p.Parent then p.CFrame, p.Transparency, p.Color, p.Material = v[1], v[2], v[3], v[4] end
	end
	cam.CameraType = Enum.CameraType.Custom
	TS:Create(white, TweenInfo.new(0.7), {BackgroundTransparency = 1}):Play()
	task.wait(0.75)
	for _, c in trash do
		if typeof(c) == "Instance" then c:Destroy() end
	end
	busy = false
end)
