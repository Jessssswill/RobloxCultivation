-- QiClient: input skill, HUD, cut-in ultimate, hitstop, getar kamera, banner, dialog, pilih ras.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local KSP = game:GetService("KeyframeSequenceProvider")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local mouse = player:GetMouse()
local R = RS:WaitForChild("QiRemotes")
local Anims = RS:WaitForChild("QiAnims")
local FXF = workspace:WaitForChild("FX")
local Monsters = workspace:WaitForChild("Monsters")

local CYAN = Color3.fromRGB(110, 220, 255)
local GOLD = Color3.fromRGB(255, 210, 90)
local FONT = Enum.Font.FredokaOne
local KC = Enum.KeyCode

local SKILLS = {
	{key = KC.Z, name = "Crescent", label = "Crescent", cd = 3, sword = true},
	{key = KC.X, name = "SwordRain", label = "Sword Rain", cd = 8, sword = true},
	{key = KC.C, name = "QiPalm", label = "Qi Palm", cd = 5},
	{key = KC.V, name = "GroundShock", label = "Ground Shock", cd = 7},
	{key = KC.G, name = "SkySword", label = "Galaxy Blade", cd = 3, sword = true, ult = true, title = "GALAXY SEVERING BLADE"},
	{key = KC.H, name = "HeavenPalm", label = "Heaven Palm", cd = 25, ult = true, req = 7, title = "PALM OF THE NINE HEAVENS"},
	{key = KC.U, name = "DivineDragon", label = "Divine Dragon", cd = 3, ult = true, req = 1, title = "NINE HEAVENS DIVINE DRAGON"},
}
local LEN = {Crescent = 0.7, SwordRain = 0.85, SkySword = 4.3, QiPalm = 0.7, GroundShock = 0.85, HeavenPalm = 1.9, DivineDragon = 7.6}

local char, hum, root, animator
local tracks = {}
local cdEnd = {}
local casting, blocking, meditating, flying, cinematic = false, false, false, false, false
local dashReady, parryReady = 0, 0

-- ===================== GUI =====================
local gui = Instance.new("ScreenGui")
gui.Name = "QiHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) make("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
local function stroke(o, c, t) make("UIStroke", {Color = c or Color3.new(0, 0, 0), Thickness = t or 1.5, Transparency = 0.3}, o) end
local function label(props, parent)
	local t = make("TextLabel", {BackgroundTransparency = 1, Font = FONT, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, TextScaled = true}, parent)
	for k, v in props do t[k] = v end
	return t
end

-- panel kiri atas: realm, qi, hp
local panel = make("Frame", {Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(310, 118), BackgroundColor3 = Color3.fromRGB(15, 20, 30), BackgroundTransparency = 0.35}, gui)
corner(panel, 10)
stroke(panel, CYAN, 1)
local realmL = label({Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(286, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Text = "Iron Bone Early"}, panel)
local function bar(y, color, h)
	local bg = make("Frame", {Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(286, h or 16), BackgroundColor3 = Color3.fromRGB(35, 40, 55)}, panel)
	corner(bg, 6)
	local fill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = color}, bg)
	corner(fill, 6)
	local t = label({Size = UDim2.fromScale(1, 1), TextSize = 13, TextScaled = false, ZIndex = 2}, bg)
	return fill, t
end
local qiFill, qiText = bar(36, CYAN)
local hpFill, hpText = bar(58, Color3.fromRGB(90, 220, 120))
local infoL = label({Position = UDim2.fromOffset(12, 80), Size = UDim2.fromOffset(286, 16), TextScaled = false, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 210, 230)}, panel)
local tribL = label({Position = UDim2.fromOffset(12, 98), Size = UDim2.fromOffset(286, 16), TextScaled = false, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 170, 255), Text = ""}, panel)

-- slot skill
local slotsF = make("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -84), Size = UDim2.fromOffset(6 * 74, 70), BackgroundTransparency = 1}, gui)
make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center}, slotsF)
local slots = {}
for _, s in SKILLS do
	local f = make("Frame", {Size = UDim2.fromOffset(64, 64), BackgroundColor3 = s.ult and Color3.fromRGB(45, 35, 15) or Color3.fromRGB(20, 30, 45), BackgroundTransparency = 0.15, ClipsDescendants = true}, slotsF)
	corner(f, 10)
	stroke(f, s.ult and GOLD or CYAN, 2)
	label({Position = UDim2.fromOffset(5, 3), Size = UDim2.fromOffset(18, 18), Text = s.key.Name, TextColor3 = s.ult and GOLD or CYAN}, f)
	label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -6, 0, 26), Text = s.label}, f)
	local ov = make("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, ZIndex = 3}, f)
	local cdT = label({Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 4, TextSize = 22, TextScaled = false}, f)
	local lock = label({Size = UDim2.fromScale(1, 1), Text = "Inner\nHeaven", ZIndex = 5, TextSize = 13, TextScaled = false, BackgroundTransparency = 0.3, BackgroundColor3 = Color3.new(0, 0, 0), Visible = false}, f)
	slots[s.name] = {ov = ov, cdT = cdT, lock = lock}
end
label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -160), Size = UDim2.fromOffset(700, 20), TextScaled = false, TextSize = 14, TextColor3 = Color3.fromRGB(210, 220, 235),
	Text = "Click Combo  |  Q Dash  |  F Parry  |  Hold R Block  |  M Meditate  |  B Fly (Soul Spring)"}, gui)

-- banner tengah
local banner = label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromOffset(900, 54), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 20}, gui)
local zoneL = label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.fromOffset(600, 40), TextTransparency = 1, TextStrokeTransparency = 1, Font = Enum.Font.Fantasy, TextColor3 = Color3.fromRGB(255, 235, 190), ZIndex = 20}, gui)
local bannerToken = 0
local function showBanner(text, color, dur, lbl)
	lbl = lbl or banner
	bannerToken += 1
	local my = bannerToken
	lbl.Text = text
	lbl.TextColor3 = color or Color3.new(1, 1, 1)
	lbl.Size = UDim2.fromOffset(lbl.Size.X.Offset, lbl.Size.Y.Offset * 0.7)
	TS:Create(lbl, TweenInfo.new(0.25, Enum.EasingStyle.Back), {TextTransparency = 0, TextStrokeTransparency = 0.3, Size = UDim2.fromOffset(lbl.Size.X.Offset, lbl == banner and 54 or 40)}):Play()
	task.delay(dur or 2.5, function()
		if lbl ~= banner or my == bannerToken then
			TS:Create(lbl, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		end
	end)
end

-- boss bar
local bossF = make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(520, 44), BackgroundTransparency = 1, Visible = false}, gui)
local bossName = label({Size = UDim2.new(1, 0, 0, 20), Text = "", TextColor3 = Color3.fromRGB(255, 200, 160)}, bossF)
local bossBg = make("Frame", {Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Color3.fromRGB(40, 20, 20)}, bossF)
corner(bossBg, 6)
stroke(bossBg, Color3.fromRGB(255, 120, 80), 1.5)
local bossFill = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(230, 60, 50)}, bossBg)
corner(bossFill, 6)

-- dialog
local dlg = make("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -190), Size = UDim2.fromOffset(620, 96), BackgroundColor3 = Color3.fromRGB(15, 18, 28), BackgroundTransparency = 0.15, Visible = false}, gui)
corner(dlg, 12)
stroke(dlg, GOLD, 1.5)
local dlgName = label({Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD}, dlg)
local dlgText = label({Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -32, 0, 54), TextScaled = false, TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham}, dlg)
local dlgToken = 0
local function showDialog(name, line)
	dlgToken += 1
	local my = dlgToken
	dlgName.Text = name
	dlgText.Text = ""
	dlg.Visible = true
	task.spawn(function()
		for i = 1, #line do
			if my ~= dlgToken then return end
			dlgText.Text = line:sub(1, i)
			task.wait(0.012)
		end
	end)
	task.delay(7, function() if my == dlgToken then dlg.Visible = false end end)
end

-- feed loot kanan
local feed = make("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(260, 200), BackgroundTransparency = 1}, gui)
make("UIListLayout", {VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4)}, feed)
local function feedLine(text, color)
	local l = label({Size = UDim2.fromOffset(260, 22), Text = text, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Right}, feed)
	task.delay(3, function()
		TS:Create(l, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		Debris:AddItem(l, 0.6)
	end)
end

-- letterbox + flash buat cut-in
local topBar = make("Frame", {Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 30}, gui)
local botBar = make("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 30}, gui)
local ultTitle = label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.fromOffset(800, 50), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 31, Font = Enum.Font.Fantasy}, gui)
local flash = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 40}, gui)
local function doFlash(color, a)
	flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	flash.BackgroundTransparency = a or 0.3
	TS:Create(flash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
end

-- ===================== feel: getar & hitstop =====================
local shakeMag, shakeEnd, shakeDur = 0, 0, 1
local function shake(mag, dur)
	if os.clock() < shakeEnd and mag < shakeMag then return end
	shakeMag, shakeDur, shakeEnd = mag, dur, os.clock() + dur
end
RunS:BindToRenderStep("QiShake", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeEnd - os.clock()
	if left > 0 then
		local k = left / shakeDur * shakeMag
		cam.CFrame *= CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * k * 0.02)
	end
end)

local function hitstop(dur)
	if not animator then return end
	local list = {}
	for _, t in animator:GetPlayingAnimationTracks() do
		if t.Priority == Enum.AnimationPriority.Action4 then
			t:AdjustSpeed(0)
			table.insert(list, t)
		end
	end
	task.delay(dur, function()
		for _, t in list do t:AdjustSpeed(1) end
	end)
end

local function popNumber(pos, text, color, big)
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.Transparency = 1
	a.Size = Vector3.new(0.2, 0.2, 0.2)
	a.Position = pos + Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2)
	a.Parent = FXF
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(big and 150 or 100, big and 56 or 36)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 140
	bb.Parent = a
	local t = label({Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color, TextStrokeTransparency = 0}, bb)
	bb.Size = UDim2.fromOffset(bb.Size.X.Offset * 1.6, bb.Size.Y.Offset * 1.6)
	TS:Create(bb, TweenInfo.new(0.15, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(big and 150 or 100, big and 56 or 36)}):Play()
	TS:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {StudsOffset = Vector3.new(0, 3.5, 0)}):Play()
	TS:Create(t, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.55), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(a, 1)
end

-- ===================== karakter & animasi =====================
local function loadTrack(name)
	local a = Instance.new("Animation")
	a.AnimationId = KSP:RegisterKeyframeSequence(Anims[name])
	local t = animator:LoadAnimation(a)
	t.Priority = Enum.AnimationPriority.Action4
	return t
end

local flyLV, flyAO, flyConn
local function stopFly(silent)
	if flyConn then flyConn:Disconnect() flyConn = nil end
	if flyLV then flyLV:Destroy() flyLV = nil end
	if flyAO then flyAO:Destroy() flyAO = nil end
	if hum then hum.PlatformStand = false end
	if tracks.Fly then tracks.Fly:Stop(0.3) end
	if flying and not silent then R.Fly:FireServer(false) end
	flying = false
	player:SetAttribute("Flying", nil)
end


-- ===================== Divine Dragon: custom cast animation (R15) =====================
local function dA(x, y, z) return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0)) end
local DRAGON_TREE = {n = "HumanoidRootPart", c = {
	{n = "LowerTorso", c = {
		{n = "UpperTorso", c = {
			{n = "Head"},
			{n = "RightUpperArm", c = {{n = "RightLowerArm", c = {{n = "RightHand"}}}}},
			{n = "LeftUpperArm", c = {{n = "LeftLowerArm", c = {{n = "LeftHand"}}}}},
		}},
		{n = "RightUpperLeg", c = {{n = "RightLowerLeg"}}},
		{n = "LeftUpperLeg", c = {{n = "LeftLowerLeg"}}},
	}},
}}
-- {time, joints, legs{thighR, kneeR, thighL, kneeL}}  (times match the server/camera timeline)
local DRAGON_FRAMES = {
	{0, {}},
	-- 0.6 gather qi: low stance, arms drawn back
	{0.6, {LowerTorso = CFrame.new(0, -0.6, 0) * dA(8), UpperTorso = dA(12), Head = dA(-10),
		RightUpperArm = dA(-25, 0, 18), RightLowerArm = dA(15), LeftUpperArm = dA(-25, 0, -18), LeftLowerArm = dA(15)}, {38, -70}},
	-- 1.3 rise: stand and sweep both arms up, chest open, eyes to the sky
	{1.3, {LowerTorso = CFrame.new(0, -0.1, 0), UpperTorso = dA(-14), Head = dA(-22),
		RightUpperArm = dA(150, 0, 35), RightLowerArm = dA(12), LeftUpperArm = dA(150, 0, -35), LeftLowerArm = dA(12)}, {8, -14}},
	-- 1.9 summon: right hand to heaven, left hand seals at the chest
	{1.9, {UpperTorso = dA(-18), Head = dA(-30),
		RightUpperArm = dA(172, 0, 8), RightLowerArm = dA(4), LeftUpperArm = dA(58, 0, -22), LeftLowerArm = dA(105)}, {6, -10}},
	-- 2.9 hold while the dragon arrives (slight drift so it never freezes)
	{2.9, {LowerTorso = CFrame.new(0, -0.15, 0), UpperTorso = dA(-22, 6, 0), Head = dA(-34, -6, 0),
		RightUpperArm = dA(165, 10, 14), RightLowerArm = dA(4), LeftUpperArm = dA(62, 0, -28), LeftLowerArm = dA(110)}, {10, -16}},
	-- 3.5 / 4.2 roar: arms flare wide, head thrown back
	{3.5, {LowerTorso = CFrame.new(0, -0.25, 0), UpperTorso = dA(-26), Head = dA(-42),
		RightUpperArm = dA(35, 0, 78), RightLowerArm = dA(25), LeftUpperArm = dA(35, 0, -78), LeftLowerArm = dA(25)}, {14, -24}},
	{4.2, {LowerTorso = CFrame.new(0, -0.28, 0), UpperTorso = dA(-28), Head = dA(-44),
		RightUpperArm = dA(38, 0, 82), RightLowerArm = dA(28), LeftUpperArm = dA(38, 0, -82), LeftLowerArm = dA(28)}, {14, -24}},
	-- 4.45 command: sword-finger points at the target, lunge stance, fire begins on the left
	{4.45, {LowerTorso = CFrame.new(0, -0.3, 0) * dA(4), UpperTorso = dA(12, 17, 0), Head = dA(8, -10, 0),
		RightUpperArm = dA(0, 34, 0) * dA(95), RightLowerArm = dA(0), LeftUpperArm = dA(35, 0, -25), LeftLowerArm = dA(100)}, {-14, -10, 26, -40}},
	-- 5.75 sweep ends on the right
	{5.75, {LowerTorso = CFrame.new(0, -0.3, 0) * dA(4), UpperTorso = dA(12, -17, 0), Head = dA(8, 10, 0),
		RightUpperArm = dA(0, -34, 0) * dA(95), RightLowerArm = dA(0), LeftUpperArm = dA(35, 0, -25), LeftLowerArm = dA(100)}, {-14, -10, 26, -40}},
	-- 6.3 release: exhale, arms fall open
	{6.3, {LowerTorso = CFrame.new(0, -0.15, 0), UpperTorso = dA(6), Head = dA(5),
		RightUpperArm = dA(10, 0, 22), RightLowerArm = dA(18), LeftUpperArm = dA(10, 0, -22), LeftLowerArm = dA(18)}, {10, -18}},
	{7.0, {}},
}
local function addPose(parent, node, joints)
	local p = Instance.new("Pose")
	p.Name = node.n
	p.CFrame = joints[node.n] or CFrame.new()
	p.Weight = node.n == "HumanoidRootPart" and 0 or 1
	p.EasingStyle = Enum.PoseEasingStyle.Cubic
	p.EasingDirection = Enum.PoseEasingDirection.InOut
	p.Parent = parent
	for _, ch in node.c or {} do addPose(p, ch, joints) end
end
local function buildDragonKS()
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "DivineDragonCast"
	ks.Loop = false
	ks.Priority = Enum.AnimationPriority.Action4
	for _, f in DRAGON_FRAMES do
		local j, lg = f[2], f[3]
		if lg then
			j.RightUpperLeg, j.RightLowerLeg = dA(lg[1]), dA(lg[2])
			j.LeftUpperLeg, j.LeftLowerLeg = dA(lg[3] or lg[1]), dA(lg[4] or lg[2])
		end
		local kf = Instance.new("Keyframe")
		kf.Time = f[1]
		kf.Parent = ks
		addPose(kf, DRAGON_TREE, j)
	end
	return ks
end
local DRAGON_KS = buildDragonKS()
local function loadSeq(ks)
	local a = Instance.new("Animation")
	a.AnimationId = KSP:RegisterKeyframeSequence(ks)
	local t = animator:LoadAnimation(a)
	t.Priority = Enum.AnimationPriority.Action4
	t.Looped = false
	return t
end

local function onChar(c)
	char = c
	hum = c:WaitForChild("Humanoid")
	root = c:WaitForChild("HumanoidRootPart")
	animator = hum:WaitForChild("Animator")
	mouse.TargetFilter = c
	tracks = {}
	for _, n in {"Crescent", "SwordRain", "SkySword", "QiPalm", "GroundShock", "HeavenPalm", "Parry", "Block", "Dash", "Meditate", "Fly"} do
		tracks[n] = loadTrack(n)
	end
	tracks.DivineDragon = loadSeq(DRAGON_KS)
	casting, blocking, meditating = false, false, false
	player:SetAttribute("Casting", nil)
	stopFly(true)
end
player.CharacterAdded:Connect(onChar)
if player.Character then task.spawn(onChar, player.Character) end

local function alive() return char and hum and hum.Health > 0 and root end

local function cancelActions()
	for _, t in animator:GetPlayingAnimationTracks() do
		if t.Priority == Enum.AnimationPriority.Action4 and t ~= tracks.Dash then t:Stop(0.05) end
	end
	local tool = char:FindFirstChildOfClass("Tool")
	local blade = tool and tool:FindFirstChild("Blade")
	local trail = blade and blade:FindFirstChild("QiTrail")
	if trail then trail.Enabled = false end
end

-- ===================== cut-in ultimate =====================
local function cutIn(title, color)
	cinematic = true
	TS:Create(topBar, TweenInfo.new(0.25), {Size = UDim2.fromScale(1, 0.12)}):Play()
	TS:Create(botBar, TweenInfo.new(0.25), {Size = UDim2.fromScale(1, 0.12)}):Play()
	ultTitle.Text = title
	ultTitle.TextColor3 = color
	TS:Create(ultTitle, TweenInfo.new(0.3), {TextTransparency = 0, TextStrokeTransparency = 0.2}):Play()
	local head = char:FindFirstChild("Head") or root
	cam.CameraType = Enum.CameraType.Scriptable
	local face = (root.CFrame * CFrame.new(1.6, 1.8, -6)).Position
	cam.CFrame = CFrame.lookAt(face, head.Position)
	TS:Create(cam, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {CFrame = CFrame.lookAt((root.CFrame * CFrame.new(1.1, 1.7, -4.2)).Position, head.Position)}):Play()
	task.wait(0.75)
	doFlash(color, 0.5)
	local sky = (root.CFrame * CFrame.new(6, 26, 30)).Position
	TS:Create(cam, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.lookAt(sky, root.Position + root.CFrame.LookVector * 22)}):Play()
	task.wait(1.0)
	cam.CameraType = Enum.CameraType.Custom
	TS:Create(topBar, TweenInfo.new(0.3), {Size = UDim2.fromScale(1, 0)}):Play()
	TS:Create(botBar, TweenInfo.new(0.3), {Size = UDim2.fromScale(1, 0)}):Play()
	TS:Create(ultTitle, TweenInfo.new(0.4), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	cinematic = false
end

-- ===================== aksi =====================
-- ===== kendaraan: aksi bertarung -> otomatis turun dulu, lalu aksi dijalankan
local function mountBusy()
	return player:GetAttribute("Mounted") or player:GetAttribute("SwordRiding") or player:GetAttribute("DemonForm")
		or player:GetAttribute("SteedCalling") or player:GetAttribute("SwordCalling") or player:GetAttribute("DemonCharging")
end
local function autoDismount()        -- true = sudah turun, aksi boleh jalan
	if not mountBusy() then return true end
	if player:GetAttribute("SteedCalling") or player:GetAttribute("SwordCalling") or player:GetAttribute("DemonCharging") then
		return false                     -- sedang memanggil / berubah wujud: abaikan
	end
	local rem = player:GetAttribute("Mounted") and R:FindFirstChild("Steed")
		or player:GetAttribute("SwordRiding") and R:FindFirstChild("FlyingSword")
		or player:GetAttribute("DemonForm") and R:FindFirstChild("DemonForm")
	if rem then rem:FireServer() end
	local t0 = os.clock()
	while mountBusy() and os.clock() - t0 < 1.6 do task.wait() end
	if mountBusy() then return false end
	task.wait(0.05)                      -- satu frame supaya pose & skala karakter kembali normal
	return true
end
local function watchTool(t)
	if not t:IsA("Tool") or t:GetAttribute("MountHook") then return end
	t:SetAttribute("MountHook", true)
	t.Activated:Connect(function()
		if mountBusy() then task.spawn(autoDismount) end
	end)
end
local function hookChar(c)
	for _, t in c:GetChildren() do watchTool(t) end
	c.ChildAdded:Connect(function(t)
		if not t:IsA("Tool") then return end
		watchTool(t)
		if player:GetAttribute("DemonForm") then task.spawn(autoDismount) end   -- monster tidak memegang senjata
	end)
end
if player.Character then hookChar(player.Character) end
player.CharacterAdded:Connect(hookChar)
local bp = player:FindFirstChildOfClass("Backpack")
if bp then bp.ChildAdded:Connect(watchTool) for _, t in bp:GetChildren() do watchTool(t) end end
player.ChildAdded:Connect(function(b) if b:IsA("Backpack") then b.ChildAdded:Connect(watchTool) end end)

local function cast(s)
	if mountBusy() and not autoDismount() then return end
	if not alive() or casting or meditating or flying or cinematic then return end
	local now = os.clock()
	if (cdEnd[s.name] or 0) > now then return end
	if s.req and (player:GetAttribute("Stage") or 1) < s.req then
		showBanner(s.label .. " unlocks at Inner Heaven", GOLD, 1.8)
		return
	end
	if s.sword and not char:FindFirstChild("QiSword") then
		local tool = player.Backpack:FindFirstChild("QiSword")
		if tool then hum:EquipTool(tool) end
	end
	cdEnd[s.name] = now + s.cd
	local aim = mouse.Hit and mouse.Hit.Position
	if aim then
		local flat = Vector3.new(aim.X, root.Position.Y, aim.Z)
		if (flat - root.Position).Magnitude > 1 then root.CFrame = CFrame.lookAt(root.Position, flat) end
	end
	casting = true
	player:SetAttribute("Casting", true)
	R.Skill:FireServer(s.name, aim)
	local tr = tracks[s.name]
	tr:Play(0.08)
	local speed = hum.WalkSpeed
	if s.ult then
		hum.WalkSpeed = 0
		if s.name ~= "SkySword" and s.name ~= "DivineDragon" then task.spawn(cutIn, s.title, s.sword and CYAN or GOLD) end
	end
	task.wait((LEN[s.name] or 0.7) * (s.ult and 0.95 or 0.75))
	casting = false
	player:SetAttribute("Casting", nil)
	if s.ult and hum.WalkSpeed == 0 then hum.WalkSpeed = speed end
end

local function ghost()
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local g = p:Clone()
			g:ClearAllChildren()
			g.Anchored = true
			g.CanCollide = false
			g.CanQuery = false
			g.CanTouch = false
			g.Material = Enum.Material.Neon
			g.Color = CYAN
			g.Transparency = 0.55
			g.Parent = FXF
			TS:Create(g, TweenInfo.new(0.35), {Transparency = 1}):Play()
			Debris:AddItem(g, 0.4)
		end
	end
end

local function dash()
	if player:GetAttribute("Mounted") or player:GetAttribute("SteedCalling") or player:GetAttribute("DemonForm") or player:GetAttribute("DemonCharging") or player:GetAttribute("SwordRiding") or player:GetAttribute("SwordCalling") then return end   -- tidak bisa dash saat naik kuda / wujud iblis
	if not alive() or meditating or flying or cinematic or os.clock() < dashReady then return end
	dashReady = os.clock() + 0.7
	cancelActions()
	casting = false
	player:SetAttribute("Casting", nil)
	R.Dash:FireServer()
	tracks.Dash:Play(0.03)
	local dir = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection or root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = root:FindFirstChild("RootAttachment")
	lv.MaxForce = 1e6
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * 85
	lv.Parent = root
	ghost()
	task.delay(0.08, ghost)
	task.delay(0.18, function() lv:Destroy() end)
end

local function parry()
	if mountBusy() then task.spawn(function() if autoDismount() then parry() end end) return end
	if not alive() or meditating or flying or cinematic or os.clock() < parryReady then return end
	parryReady = os.clock() + 0.6
	cancelActions()
	tracks.Parry:Play(0.03)
	R.Parry:FireServer()
end

local function setBlock(on)
	if on and mountBusy() then task.spawn(autoDismount) return end
	if on then
		if not alive() or meditating or flying or casting or cinematic then return end
		blocking = true
		tracks.Block:Play(0.1)
		R.Block:FireServer(true)
		task.delay(3, function()
			if blocking then
				blocking = false
				tracks.Block:Stop(0.15)
			end
		end)
	elseif blocking then
		blocking = false
		tracks.Block:Stop(0.15)
		R.Block:FireServer(false)
	end
end

local function setMeditate(on)
	if on then
		if not alive() or flying or casting then return end
		meditating = true
		player:SetAttribute("Meditating", true)
		hum:UnequipTools()
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		tracks.Meditate:Play(0.4)
		R.Meditate:FireServer(true)
		showBanner("Meditating... (M to stand)", CYAN, 1.5)
	elseif meditating then
		meditating = false
		player:SetAttribute("Meditating", nil)
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		tracks.Meditate:Stop(0.3)
		R.Meditate:FireServer(false)
	end
end

local function startFly()
	if mountBusy() then task.spawn(function() if autoDismount() then startFly() end end) return end
	if not alive() or meditating or casting then return end
	if (player:GetAttribute("Stage") or 1) < 4 then
		showBanner("Reach Soul Spring to ride your sword", CYAN, 1.8)
		return
	end
	local att = root:FindFirstChild("RootAttachment")
	if not att then return end
	flying = true
	player:SetAttribute("Flying", true)
	hum:UnequipTools()
	R.Fly:FireServer(true)
	tracks.Fly:Play(0.3)
	hum.PlatformStand = true
	root.CFrame += Vector3.new(0, 4, 0)
	flyLV = Instance.new("LinearVelocity")
	flyLV.Attachment0 = att
	flyLV.MaxForce = 1e6
	flyLV.VectorVelocity = Vector3.zero
	flyLV.Parent = root
	flyAO = Instance.new("AlignOrientation")
	flyAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
	flyAO.Attachment0 = att
	flyAO.MaxTorque = 1e6
	flyAO.Responsiveness = 20
	flyAO.CFrame = root.CFrame.Rotation
	flyAO.Parent = root
	local vel = Vector3.zero
	flyConn = RunS.RenderStepped:Connect(function(dt)
		local cf = cam.CFrame
		local dir = Vector3.zero
		if UIS:IsKeyDown(KC.W) then dir += cf.LookVector end
		if UIS:IsKeyDown(KC.S) then dir -= cf.LookVector end
		if UIS:IsKeyDown(KC.D) then dir += cf.RightVector end
		if UIS:IsKeyDown(KC.A) then dir -= cf.RightVector end
		if UIS:IsKeyDown(KC.Space) then dir += Vector3.yAxis end
		if UIS:IsKeyDown(KC.LeftControl) then dir -= Vector3.yAxis end
		local want = dir.Magnitude > 0 and dir.Unit * 65 or Vector3.zero
		vel = vel:Lerp(want, math.min(1, dt * 4))
		flyLV.VectorVelocity = vel
		local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		if look.Magnitude > 0.01 then
			local tilt = math.clamp(vel.Magnitude / 65, 0, 1) * 18
			flyAO.CFrame = CFrame.lookAt(Vector3.zero, look.Unit) * CFrame.Angles(math.rad(-tilt), 0, 0)
		end
	end)
	showBanner("Sword Flight! W/A/S/D, Space up, Ctrl down", CYAN, 2)
end

-- ===================== input =====================
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == KC.R then
		setBlock(true)
		return
	end
	local k = input.KeyCode
	-- [WeaponSkills] skip
	do
		local wt = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if wt and wt:GetAttribute("Element") and (k == KC.Z or k == KC.X or k == KC.G) and mountBusy() then task.spawn(autoDismount) end   -- skill senjata: turun dulu
		if wt and wt:GetAttribute("Element") and (k == KC.Z or k == KC.X or k == KC.G) then return end
	end
	if meditating and (k == KC.M or k == KC.Space) then
		setMeditate(false)
		return
	end
	for _, s in SKILLS do
		if k == s.key then
			task.spawn(cast, s)
			return
		end
	end
	if k == KC.Q then dash()
	elseif k == KC.F then parry()
	elseif k == KC.M then setMeditate(true)
	elseif k == KC.B then
		if flying then stopFly() else startFly() end
	elseif k == KC.F7 then R.DevQi:FireServer()   -- tombol uji qi (P dipakai wujud iblis)
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.KeyCode == KC.R then setBlock(false) end
end)

-- ===================== sinematik ultimate pedang (Galaxy Severing Blade) =====================
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local ultFx = {}
local function galaxyWorld(on, center)
	local cc = Lighting:FindFirstChild("QiColor")
	local bloom = Lighting:FindFirstChild("QiUltBloom")
	local dof = Lighting:FindFirstChild("QiUltDof")
	if on then
		if not bloom then
			bloom = Instance.new("BloomEffect")
			bloom.Name = "QiUltBloom"
			bloom.Intensity = 0
			bloom.Size = 40
			bloom.Threshold = 1.2
			bloom.Parent = Lighting
		end
		if not dof then
			dof = Instance.new("DepthOfFieldEffect")
			dof.Name = "QiUltDof"
			dof.FarIntensity = 0
			dof.NearIntensity = 0
			dof.FocusDistance = 25
			dof.InFocusRadius = 45
			dof.Parent = Lighting
		end
		TS:Create(bloom, TweenInfo.new(0.6), {Intensity = 0.6}):Play()
		TS:Create(dof, TweenInfo.new(0.6), {FarIntensity = 0.35}):Play()
		TS:Create(Lighting, TweenInfo.new(0.6), {Brightness = 0.2, ClockTime = 0.2, ExposureCompensation = -0.25}):Play()
		if cc then TS:Create(cc, TweenInfo.new(0.6), {TintColor = Color3.fromRGB(180, 175, 255), Contrast = 0.3, Saturation = 0.35}):Play() end
		-- langit galaksi: awan nebula warna-warni + bintang di sekitar titik tebasan
		local cols = {Color3.fromRGB(170, 120, 255), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 140, 90), Color3.fromRGB(120, 255, 210), Color3.fromRGB(255, 110, 190), Color3.fromRGB(150, 160, 255)}
		for i, col in cols do
			local ang = i / #cols * math.pi * 2
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Transparency = 1
			p.Size = Vector3.new(30, 12, 30)
			p.Position = center + Vector3.new(math.cos(ang) * 80, 35 + (i % 3) * 14, math.sin(ang) * 80)
			p.Parent = FXF
			local e = Instance.new("ParticleEmitter")
			e.Texture = TEX_SMOKE
			e.Color = ColorSequence.new(col, Color3.new(1, 1, 1):Lerp(col, 0.6))
			e.LightEmission = 1
			e.LightInfluence = 0
			e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 25), NumberSequenceKeypoint.new(1, 50)})
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.78), NumberSequenceKeypoint.new(1, 1)})
			e.Lifetime = NumberRange.new(3, 4)
			e.Speed = NumberRange.new(0.5, 2)
			e.RotSpeed = NumberRange.new(-8, 8)
			e.Rotation = NumberRange.new(0, 360)
			e.Rate = 3
			e.Parent = p
			e:Emit(4)
			table.insert(ultFx, p)
		end
		local sky = Instance.new("Part")
		sky.Anchored = true
		sky.CanCollide = false
		sky.CanQuery = false
		sky.CanTouch = false
		sky.Transparency = 1
		sky.Size = Vector3.new(260, 2, 260)
		sky.Position = center + Vector3.new(0, 70, 0)
		sky.Parent = FXF
		local st = Instance.new("ParticleEmitter")
		st.Texture = TEX_SPARK
		st.LightEmission = 1
		st.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1.2), NumberSequenceKeypoint.new(1, 0)})
		st.Lifetime = NumberRange.new(1.5, 3)
		st.Speed = NumberRange.new(0, 0.5)
		st.Rate = 120
		st.Parent = sky
		st:Emit(150)
		table.insert(ultFx, sky)
	else
		if bloom then
			TS:Create(bloom, TweenInfo.new(1.2), {Intensity = 0}):Play()
			Debris:AddItem(bloom, 1.3)
		end
		if dof then
			TS:Create(dof, TweenInfo.new(1.2), {FarIntensity = 0}):Play()
			Debris:AddItem(dof, 1.3)
		end
		TS:Create(Lighting, TweenInfo.new(1.2), {Brightness = 2.2, ClockTime = 16.2, ExposureCompensation = 0}):Play()
		if cc then TS:Create(cc, TweenInfo.new(1.2), {TintColor = Color3.new(1, 1, 1), Contrast = 0.08, Saturation = 0.15, Brightness = 0}):Play() end
		for _, p in ultFx do
			for _, e in p:GetChildren() do if e:IsA("ParticleEmitter") then e.Enabled = false end end
			Debris:AddItem(p, 4)
		end
		table.clear(ultFx)
	end
end

-- garis-garis kecepatan anime di pinggir layar
local speedLines = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 25, Visible = false}, gui)
local lines = {}
for i = 1, 36 do
	local ang = (i / 36) * 360 + math.random(-4, 4)
	local f = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(math.random(250, 520), math.random(1, 3)), Rotation = ang, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 25}, speedLines)
	table.insert(lines, {f, math.rad(ang)})
end
local function showSpeedLines(dur)
	speedLines.Visible = true
	local t0 = os.clock()
	while os.clock() - t0 < dur do
		for _, l in lines do
			local r = math.random(300, 480) + l[1].Size.X.Offset / 2
			l[1].Position = UDim2.new(0.5, math.cos(l[2]) * r, 0.5, math.sin(l[2]) * r)
			l[1].BackgroundTransparency = 0.15 + math.random() * 0.6
		end
		task.wait(0.04)
	end
	speedLines.Visible = false
end

-- impact frame donghua: hitam-putih kontras tinggi beberapa frame
local function impactFrames()
	local cc = Lighting:FindFirstChild("QiColor")
	if cc then
		cc.Saturation = -1
		cc.Contrast = 1.2
	end
	flash.BackgroundColor3 = Color3.new(0, 0, 0)
	flash.BackgroundTransparency = 0.05
	task.wait(0.05)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	task.wait(0.04)
	flash.BackgroundTransparency = 1
	task.wait(0.06)
	flash.BackgroundColor3 = Color3.new(0, 0, 0)
	flash.BackgroundTransparency = 0.3
	task.wait(0.04)
	flash.BackgroundTransparency = 1
	if cc then
		cc.Saturation = 0.35
		cc.Contrast = 0.3
	end
	doFlash(GOLD, 0.4)
end

local function galaxyCinematic(caster, origin, center, dir)
	local near = root and (root.Position - origin).Magnitude < 300
	if near then
		galaxyWorld(true, center)
		task.delay(4.1, galaxyWorld, false)
	end
	if caster ~= player then return end
	cinematic = true
	local up = Vector3.new(0, 1, 0)
	local side = dir:Cross(up).Unit
	local P = origin + up * 6
	TS:Create(topBar, TweenInfo.new(0.25), {Size = UDim2.fromScale(1, 0.1)}):Play()
	TS:Create(botBar, TweenInfo.new(0.25), {Size = UDim2.fromScale(1, 0.1)}):Play()
	ultTitle.Text = "GALAXY SEVERING BLADE"
	ultTitle.TextColor3 = GOLD
	TS:Create(ultTitle, TweenInfo.new(0.4), {TextTransparency = 0, TextStrokeTransparency = 0.2}):Play()
	cam.CameraType = Enum.CameraType.Scriptable
	local fov = cam.FieldOfView
	-- shot 1: dari depan bawah, mundur pelan sampai avatar emas kelihatan
	cam.FieldOfView = 55
	cam.CFrame = CFrame.lookAt(origin + dir * 7 + up * 1.5 + side * 1.5, origin + up * 3)
	TS:Create(cam, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = CFrame.lookAt(P + dir * 30 + up * 4 + side * 9, P + up * 7 - dir * 4), FieldOfView = 70}):Play()
	task.wait(1.4)
	-- shot 2: close-up pas tenaga dipadatkan, dolly-zoom pelan
	TS:Create(ultTitle, TweenInfo.new(0.3), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	cam.CFrame = CFrame.lookAt(P + dir * 6 + side * 3.5 + up * 1.5, P + up * 2.5)
	TS:Create(cam, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = CFrame.lookAt(P + dir * 4.5 + side * 2.5 + up * 2, P + up * 3), FieldOfView = 45}):Play()
	task.wait(0.4)
	doFlash(Color3.new(1, 1, 1), 0)
	-- shot 3: dari belakang, ngikutin tebasan, speed lines
	cam.FieldOfView = 85
	cam.CFrame = CFrame.lookAt(P - dir * 12 + up * 5 + side * 3, center)
	TS:Create(cam, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.lookAt(P + dir * 14 + up * 9 + side * 5, center), FieldOfView = 70}):Play()
	task.spawn(showSpeedLines, 0.5)
	task.wait(0.6)
	-- shot 4: lebar ke bola dunia, retak, terbelah
	local wide = center + side * 48 + up * 12 - dir * 18
	cam.CFrame = CFrame.lookAt(wide, center)
	TS:Create(cam, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {CFrame = CFrame.lookAt(center + (wide - center) * 0.8, center)}):Play()
	task.wait(1.0)
	task.spawn(impactFrames)
	hitstop(0.12)
	task.wait(0.5)
	cam.FieldOfView = fov
	cam.CameraType = Enum.CameraType.Custom
	TS:Create(topBar, TweenInfo.new(0.3), {Size = UDim2.fromScale(1, 0)}):Play()
	TS:Create(botBar, TweenInfo.new(0.3), {Size = UDim2.fromScale(1, 0)}):Play()
	cinematic = false
end


-- ===================== Divine Dragon: cinematic (spline camera + donghua title) =====================
local function crv(p0, p1, p2, p3, u)
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
end
local function rigAt(keys, t)
	local n = #keys
	if t <= keys[1][1] then return keys[1][2], keys[1][3], keys[1][4] end
	if t >= keys[n][1] then return keys[n][2], keys[n][3], keys[n][4] end
	local i = 1
	while keys[i + 1][1] < t do i += 1 end
	local k0, k1, k2, k3 = keys[math.max(i - 1, 1)], keys[i], keys[i + 1], keys[math.min(i + 2, n)]
	local u = (t - k1[1]) / (k2[1] - k1[1])
	local e = u * u * (3 - 2 * u)
	return crv(k0[2], k1[2], k2[2], k3[2], u), crv(k0[3], k1[3], k2[3], k3[3], u), k1[4] + (k2[4] - k1[4]) * e
end

local INK_GOLD = Color3.fromRGB(235, 200, 120)
local function dragonTitle()
	local cn = label({AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.09, -24, 0.5, 0), Size = UDim2.fromOffset(130, 440),
		Text = "九\n天\n神\n龙", Font = Enum.Font.Fondamento, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1,
		TextStrokeColor3 = Color3.fromRGB(60, 35, 10), TextStrokeTransparency = 1, ZIndex = 31}, gui)
	make("UIGradient", {Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 225)),
		ColorSequenceKeypoint.new(0.55, INK_GOLD),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 120, 50))})}, cn)
	local en = label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.835), Size = UDim2.fromOffset(760, 30),
		Text = "N I N E    H E A V E N S    D I V I N E    D R A G O N", Font = Enum.Font.Fondamento, TextColor3 = INK_GOLD,
		TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 31}, gui)
	local line = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.805), Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = INK_GOLD, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 31}, gui)
	TS:Create(cn, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {TextTransparency = 0, TextStrokeTransparency = 0.55, Position = UDim2.new(0.09, 0, 0.5, 0)}):Play()
	TS:Create(line, TweenInfo.new(1.2, Enum.EasingStyle.Quart), {Size = UDim2.fromOffset(520, 2)}):Play()
	task.wait(0.5)
	TS:Create(en, TweenInfo.new(1.0), {TextTransparency = 0, TextStrokeTransparency = 0.6}):Play()
	task.wait(2.2)
	local out = TweenInfo.new(0.7)
	TS:Create(cn, out, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	TS:Create(en, out, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	TS:Create(line, out, {BackgroundTransparency = 1}):Play()
	task.wait(0.8)
	cn:Destroy()
	en:Destroy()
	line:Destroy()
end

local function dragonCinematic(o, target, dir)
	if cinematic or not root then return end
	cinematic = true
	-- hide the HUD and Roblox's own player list / hotbar / chat so the shot is clean
	local hiddenUi, hiddenCore = {}, {}
	for _, o in gui:GetChildren() do
		if o:IsA("GuiObject") and o ~= topBar and o ~= botBar and o ~= flash and o.Visible then
			o.Visible = false
			table.insert(hiddenUi, o)
		end
	end
	local SG = game:GetService("StarterGui")
	for _, ct in {Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Chat} do
		local okc, on = pcall(function() return SG:GetCoreGuiEnabled(ct) end)
		if okc and on then
			pcall(function() SG:SetCoreGuiEnabled(ct, false) end)
			table.insert(hiddenCore, ct)
		end
	end
	local up = Vector3.yAxis
	local side = dir:Cross(up).Unit
	local hover = target + up * 55 - dir * 18
	local keys = {
		{0.0, o + dir * 7 + up * 1.2 + side * 1.8, o + up * 3.2, 52},
		{0.9, o + dir * 4.2 + up * 2.3 + side * 1.1, o + up * 3.8, 40},
		{1.7, o - dir * 14 + up * 3 + side * 7, o + up * 30 + dir * 25, 68},
		{2.6, target + side * 105 - dir * 5 + up * 45, hover + up * 5 - dir * 28, 58}, -- wide side view: whole dragon swooping in
		{3.5, hover + dir * 42 + side * 30 - up * 4, hover + up * 1, 55}, -- roar close-up, head facing the camera
		{4.5, target + side * 92 + up * 30 + dir * 4, hover + up * 20, 60}, -- dragon rears back, energy gathers
		{5.5, target + side * 100 + up * 38 - dir * 10, target + up * 34, 62}, -- the spiral down, whole dragon in frame
		{6.3, target + side * 70 + up * 10 + dir * 14, target + up * 14, 66}, -- impact
		{7.2, target + side * 85 + up * 24, target + up * 26, 60}, -- cracks and dust, dragon half buried
		{8.2, target + side * 100 + up * 50, target + up * 60 - dir * 10, 60}, -- dragon dissolves into light
		{8.8, o - dir * 14 + up * 7, o + up * 3, 70},
	}
	local DUR = 8.8
	local fov0 = cam.FieldOfView
	local ok, err = pcall(function()
		TS:Create(topBar, TweenInfo.new(0.4), {Size = UDim2.fromScale(1, 0.1)}):Play()
		TS:Create(botBar, TweenInfo.new(0.4), {Size = UDim2.fromScale(1, 0.1)}):Play()
		cam.CameraType = Enum.CameraType.Scriptable
		local t0 = os.clock()
		RunS:BindToRenderStep("QiDragonCam", Enum.RenderPriority.Camera.Value, function()
			local t = os.clock() - t0
			local pos, look, fov = rigAt(keys, t)
			local sway = Vector3.new(math.noise(t * 0.7, 1, 0), math.noise(t * 0.7, 2, 0), math.noise(t * 0.7, 3, 0)) * 0.12
			cam.CFrame = CFrame.lookAt(pos + sway, look)
			cam.FieldOfView = fov
		end)
		task.delay(0.2, function() task.spawn(dragonTitle) end)
		local bolt = Color3.fromRGB(190, 215, 255)
		task.delay(0.85, doFlash, bolt, 0.75)
		task.delay(1.13, doFlash, bolt, 0.8)
		task.delay(1.41, doFlash, bolt, 0.7)
		task.delay(1.64, showSpeedLines, 0.8)
		task.delay(5.0, showSpeedLines, 0.9)
		task.delay(6.3, function()
			doFlash(Color3.new(1, 1, 1), 0.05)
			task.spawn(impactFrames)
			hitstop(0.16)
		end)
		while os.clock() - t0 < DUR do
			task.wait()
			if not alive() then break end
		end
	end)
	pcall(function() RunS:UnbindFromRenderStep("QiDragonCam") end)
	cam.FieldOfView = fov0
	cam.CameraType = Enum.CameraType.Custom
	TS:Create(topBar, TweenInfo.new(0.4), {Size = UDim2.fromScale(1, 0)}):Play()
	TS:Create(botBar, TweenInfo.new(0.4), {Size = UDim2.fromScale(1, 0)}):Play()
	for _, o in hiddenUi do
		if o.Parent then o.Visible = true end
	end
	for _, ct in hiddenCore do
		pcall(function() SG:SetCoreGuiEnabled(ct, true) end)
	end
	cinematic = false
	if not ok then warn("[DivineDragon cinematic]", err) end
end

-- ===================== dragon roar: camera shake that follows the roar's loudness =====================
do
	local roarShake
	R.Fx.OnClientEvent:Connect(function(kind, env, step, str, maxLen)
		if kind ~= "RoarShake" or type(env) ~= "table" or type(step) ~= "number" or type(str) ~= "number" then return end
		local len = #env * step
		if type(maxLen) == "number" then len = math.min(len, maxLen) end
		roarShake = {t0 = os.clock(), env = env, step = step, str = str, len = len}
	end)
	RunS:BindToRenderStep("QiRoarShake", Enum.RenderPriority.Camera.Value + 2, function()
		local rs = roarShake
		if not rs then return end
		local t = os.clock() - rs.t0
		if t > rs.len then roarShake = nil return end
		local i = t / rs.step
		local a = math.floor(i)
		local v0 = rs.env[a + 1] or 0
		local v1 = rs.env[a + 2] or v0
		local e = v0 + (v1 - v0) * (i - a)
		e *= math.clamp(t / 0.12, 0, 1) * math.clamp((rs.len - t) / 0.25, 0, 1) -- swell in, die out
		local k = e * rs.str
		local nx = math.noise(t * 31, 1.3, 0) + 0.6 * math.noise(t * 11, 7.7, 0) -- fast growl + slow heave
		local ny = math.noise(t * 29, 2.9, 0) + 0.6 * math.noise(t * 13, 9.1, 0)
		local nr = math.noise(t * 23, 4.4, 0)
		cam.CFrame *= CFrame.new(nx * k, ny * k, 0) * CFrame.Angles(0, 0, nr * k * 0.03)
	end)
	task.spawn(function() -- preload the roar so the first cast is not late
		local pre = game:GetService("ReplicatedStorage"):WaitForChild("DragonRoarPreload", 30)
		if pre then pcall(function() game:GetService("ContentProvider"):PreloadAsync({pre}) end) end
	end)
end

-- ===================== event dari server =====================
R.Fx.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "Num" then
		popNumber(a, b, c, d)
	elseif kind == "HitConfirm" then
		hitstop(a)
		shake(b and 0.5 or 0.25, 0.12)
	elseif kind == "Shake" then
		shake(a, b)
	elseif kind == "Banner" then
		showBanner(a, b, 2.8)
	elseif kind == "Parry" then
		hitstop(0.12)
		doFlash(CYAN, 0.6)
		shake(0.4, 0.15)
	elseif kind == "Loot" then
		feedLine("+1 " .. a .. " [" .. b .. "]", c)
	elseif kind == "Breakthrough" then
		if a == player.Name then
			doFlash(c and GOLD or Color3.new(1, 1, 1), 0.1)
			shake(c and 1.2 or 0.6, 0.6)
			showBanner("BREAKTHROUGH!  " .. b, c and GOLD or CYAN, 3.5)
		else
			feedLine(a .. " reached " .. b, GOLD)
		end
	elseif kind == "GalaxyUlt" then
		task.spawn(galaxyCinematic, a, b, c, d)
	elseif kind == "DragonUlt" then
		task.spawn(dragonCinematic, a, b, c)
	elseif kind == "Storm" then
		local cc = Lighting:FindFirstChild("QiColor")
		if a then
			TS:Create(Lighting, TweenInfo.new(1.5), {Brightness = 0.5, ClockTime = 19}):Play()
			if cc then TS:Create(cc, TweenInfo.new(1.5), {TintColor = Color3.fromRGB(190, 180, 255)}):Play() end
		else
			TS:Create(Lighting, TweenInfo.new(2), {Brightness = 2.2, ClockTime = 16.2}):Play()
			if cc then TS:Create(cc, TweenInfo.new(2), {TintColor = Color3.new(1, 1, 1)}):Play() end
		end
	end
end)
R.Dialog.OnClientEvent:Connect(showDialog)

-- ===================== pilih ras =====================
local function racePicker()
	local dim = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, ZIndex = 50}, gui)
	label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.12), Size = UDim2.fromOffset(700, 50), Text = "Choose Your Origin", TextColor3 = GOLD, ZIndex = 51, Font = Enum.Font.Fantasy}, dim)
	local row = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(780, 300), BackgroundTransparency = 1, ZIndex = 51}, dim)
	make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 20), HorizontalAlignment = Enum.HorizontalAlignment.Center}, row)
	local RACES = {
		{"Mortal", "Defy the heavens", "+50% Dao insight.\nExtra manual slot (soon).\n\nCost: lowest starting stats.", Color3.fromRGB(225, 225, 235)},
		{"Celestial", "Gifted by heaven", "+15 HP, +20% qi.\nEarly realms come fast.\n\nCost: harsher tribulations.", Color3.fromRGB(255, 210, 90)},
		{"Demon", "Walk the crooked path", "Devour qi from slain foes.\n+12% damage.\n\nCost: slow meditation, righteous NPCs distrust you.", Color3.fromRGB(230, 50, 70)},
	}
	for _, r in RACES do
		local b = make("TextButton", {Size = UDim2.fromOffset(240, 300), BackgroundColor3 = Color3.fromRGB(20, 25, 38), Text = "", AutoButtonColor = true, ZIndex = 52}, row)
		corner(b, 14)
		stroke(b, r[4], 2.5)
		label({Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 40), Text = r[1], TextColor3 = r[4], ZIndex = 53}, b)
		label({Position = UDim2.fromOffset(10, 70), Size = UDim2.new(1, -20, 0, 20), Text = r[2], TextColor3 = Color3.fromRGB(200, 200, 210), ZIndex = 53}, b)
		label({Position = UDim2.fromOffset(16, 120), Size = UDim2.new(1, -32, 0, 120), Text = r[3], TextScaled = false, TextSize = 17, TextWrapped = true, Font = Enum.Font.Gotham, ZIndex = 53}, b)
		b.MouseButton1Click:Connect(function()
			R.ChooseRace:FireServer(r[1])
			dim:Destroy()
			showBanner("Welcome, " .. r[1] .. " disciple of the Azure Cloud Sect", GOLD, 3)
		end)
	end
end
task.spawn(function()
	while not player:GetAttribute("DataLoaded") do task.wait(0.2) end
	if (player:GetAttribute("Race") or "") == "" then racePicker() end
end)

-- ===================== loop HUD =====================
local function zoneOf(p)
	if p.X < -5000 then return "Demon-Sealing Arena" end
	if p.X > 7000 then return "Netherworld Demon Kingdom" end
	if p.Y > 1700 and p.Z > 4000 then return "Celestial Palace" end
	if p.X > 1500 and p.X < 2700 and p.Y < 600 then return "Azure Cloud Sect" end
	if p.X > 250 then return "Misty Valley" end
	if p.Z > -72 then return "Azure Cloud Sect" end
	if p.Z > -470 then return "Spirit Beast Forest" end
	return "Old Dragon Cave"
end
local curZone, nextScan, bossModel = nil, 0, nil
RunS.RenderStepped:Connect(function()
	local qi, need = player:GetAttribute("Qi") or 0, player:GetAttribute("QiNeed") or 70
	realmL.Text = player:GetAttribute("Realm") or "Iron Bone Early"
	qiFill.Size = UDim2.fromScale(math.clamp(qi / need, 0, 1), 1)
	qiText.Text = ("Qi  %d / %d"):format(qi, need)
	local race = player:GetAttribute("Race")
	infoL.Text = ("%s  |  Sword Dao %d  |  Palm Dao %d  |  Mats %d"):format((race and race ~= "") and race or "No origin", player:GetAttribute("SwordDao") or 0, player:GetAttribute("PalmDao") or 0, player:GetAttribute("Mats") or 0)
	tribL.Text = player:GetAttribute("TribReady") and "Peak reached! Go to the Tribulation Arena" or ""
	if hum then
		hpFill.Size = UDim2.fromScale(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 1)
		hpText.Text = ("HP  %d / %d"):format(hum.Health, hum.MaxHealth)
	end
	local now = os.clock()
	local stage = player:GetAttribute("Stage") or 1
	for _, s in SKILLS do
		local sl = slots[s.name]
		local left = (cdEnd[s.name] or 0) - now
		if left > 0 then
			sl.ov.Size = UDim2.fromScale(1, left / s.cd)
			sl.cdT.Text = left >= 1 and tostring(math.ceil(left)) or ("%.1f"):format(left)
		else
			sl.ov.Size = UDim2.fromScale(1, 0)
			sl.cdT.Text = ""
		end
		sl.lock.Visible = s.req ~= nil and stage < s.req
	end
	if now > nextScan and root then
		nextScan = now + 0.4
		local z = zoneOf(root.Position)
		if z ~= curZone then
			if curZone then showBanner(z, nil, 2.5, zoneL) end
			curZone = z
		end
		bossModel = nil
		local best = 100
		for _, m in Monsters:GetChildren() do
			local h = m:FindFirstChildOfClass("Humanoid")
			local r = m:FindFirstChild("HumanoidRootPart")
			if h and r and h.Health > 0 and (m:GetAttribute("Boss") or m:GetAttribute("Elite")) then
				local d = (r.Position - root.Position).Magnitude
				if d < best then best, bossModel = d, m end
			end
		end
	end
	local bh = bossModel and bossModel:FindFirstChildOfClass("Humanoid")
	if bh and bh.Health > 0 then
		bossF.Visible = true
		bossName.Text = bh.DisplayName .. (bossModel:GetAttribute("Phase") == 2 and "  - ENRAGED" or "")
		bossFill.Size = UDim2.fromScale(math.clamp(bh.Health / bh.MaxHealth, 0, 1), 1)
	else
		bossF.Visible = false
	end
end)
print("[QiSword] client siap")