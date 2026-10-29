-- GiantSwing (ModuleScript)  |  法天象地 — golden giant avatar mirrors your sword swing
-- Put in: ReplicatedStorage/Skill/GiantSwing
-- Usage:  require(RS.Skill.GiantSwing):Cast(Players.LocalPlayer)   (client only)
-- Needs: a Tool (sword) equipped. The giant is a golden clone of YOUR character that copies
-- your joints every frame, so when your combo swings, the giant swings too.
-- Visual only: damage still comes from your normal sword hit (HitServer/ComboServer).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
local CFG = {
	SCALE = 8,          -- giant size multiplier
	BACK = 16,          -- how far behind you the giant stands
	COOLDOWN = 15,
	SWINGS = 1,         -- combo hits (last one is the big one)
	SLOW_START = 0.5,   -- swing speed at the start of the wind-up (1 = normal)
	SLOW_MIN = 0.18,    -- swing speed right before impact (slower = more tension)
	BUILD_TIME = 2.7,   -- seconds for the build-up to reach full intensity
	SLAM_T = 0.8,       -- animation time where the downward slam begins
	SLAM_SPEED = 1.0,   -- speed of the slam itself (fast = snappy)
	CAM_LIFT = 5,       -- raise all low camera shots by this many studs (to clear grass/props on the ground)
	CUT_T = 0.62,       -- animation time where the camera cuts from the close-up to the wide shot
	IMPACT_DIST = 18,   -- studs in front of you where the blade lands
	SLASH_ANIM_ID = "", -- optional: your own uploaded overhead-slash animation id (rbxassetid://...)
	SWING_GAP = 0.75,
	LETTERBOX = 0.11,
	HITSTOP = 0.09,
	SHAKE = 1.0,
	TITLE = "法天象地",
	SUBTITLE = "— CELESTIAL GIANT —",
}

local T_AIM_END, T_RISE, T_RISE_LEN, T_SHOT_C = 1.7, 1.7, 1.8, 3.6
local T_FLASH, T_SWING = 3.4, 3.9

local GOLD = Color3.fromRGB(255, 200, 80)
local PALE = Color3.fromRGB(255, 244, 205)

local module = {}
local active, lastCast = {}, {}

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function ease(a) a = math.clamp(a, 0, 1) return a * a * (3 - 2 * a) end
local function lerp(a, b, t) return a + (b - a) * t end
local function tween(inst, t, goal, style)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function vertical(str)
	local out = {}
	for _, c in utf8.codes(str) do table.insert(out, utf8.char(c)) end
	return table.concat(out, "\n")
end

local function notify(player, msg)
	local g = Instance.new("ScreenGui")
	g.ResetOnSpawn = false
	g.Parent = player:WaitForChild("PlayerGui")
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.fromScale(0.5, 0.12)
	l.Size = UDim2.fromOffset(320, 36)
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0.4
	l.TextColor3 = GOLD
	l.Font = Enum.Font.GothamBold
	l.TextSize = 18
	l.Text = msg
	l.Parent = g
	Debris:AddItem(g, 2)
end

-- Overhead slash (top -> bottom) built in code. R15 joint rotations around X:
-- +angle swings the limb forward/up, so 170deg = sword overhead, 30deg = blade down in front.
-- NOTE: RegisterKeyframeSequence only works in Studio. For a published game, upload the
-- animation and put its id in CFG.SLASH_ANIM_ID.
local function pose(name, cf, w, parent)
	local p = Instance.new("Pose")
	p.Name, p.CFrame, p.Weight = name, cf, w
	p.Parent = parent
	return p
end

local function buildSlash()
	local seq = Instance.new("KeyframeSequence")
	seq.Name, seq.Loop, seq.Priority = "GiantSlash", false, Enum.AnimationPriority.Action4
	local function key(t, arm, elbow, lean, dir, marker)
		local k = Instance.new("Keyframe")
		k.Time = t
		local root = pose("HumanoidRootPart", CFrame.identity, 0, k)
		local lower = pose("LowerTorso", CFrame.identity, 0, root)
		local upper = pose("UpperTorso", CFrame.Angles(lean, 0, 0), 1, lower)
		for _, side in { "Right", "Left" } do
			local ua = pose(side .. "UpperArm", CFrame.Angles(math.rad(arm), 0, 0), 1, upper)
			pose(side .. "LowerArm", CFrame.Angles(elbow, 0, 0), 1, ua)
		end
		for _, d in k:GetDescendants() do
			if d:IsA("Pose") then
				d.EasingStyle = Enum.PoseEasingStyle.Cubic
				d.EasingDirection = dir
			end
		end
		if marker then
			local m = Instance.new("KeyframeMarker")
			m.Name = marker
			m.Parent = k
		end
		k.Parent = seq
	end
	key(0.0, 0, 0, 0, Enum.PoseEasingDirection.Out)
	key(0.5, 170, 0.6, 0.30, Enum.PoseEasingDirection.InOut) -- raise sword overhead (slow build-up)
	key(0.8, 178, 0.8, 0.42, Enum.PoseEasingDirection.InOut) -- cock back, hold the tension
	key(1.1, 30, 0.05, -0.45, Enum.PoseEasingDirection.In, "Hit") -- slam down
	key(1.8, 0, 0, 0, Enum.PoseEasingDirection.InOut) -- recover
	return seq
end

----------------------------------------------------------------------
-- WORLD FX (all take the session s)
----------------------------------------------------------------------
local function ring(s, pos, size, dur, thick)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material, p.Color, p.Transparency = Enum.Material.Neon, GOLD, 0.15
	p.Size = Vector3.new(thick, 4, 4)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = workspace
	s:track(p)
	tween(p, dur, { Size = Vector3.new(thick, size, size), Transparency = 1 })
	Debris:AddItem(p, dur + 0.2)
end

local function burst(s, pos, dustAmount, speed)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
	a.Size = Vector3.one
	a.Position = pos
	a.Parent = workspace
	s:track(a)

	local d = Instance.new("ParticleEmitter")
	d.Texture = "rbxasset://textures/particles/smoke_main.dds"
	d.Color = ColorSequence.new(Color3.fromRGB(214, 176, 110), Color3.fromRGB(120, 100, 70))
	d.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	d.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 22) })
	d.Lifetime = NumberRange.new(1.2, 2.2)
	d.Speed = NumberRange.new(speed * 0.5, speed)
	d.SpreadAngle = Vector2.new(75, 75)
	d.RotSpeed = NumberRange.new(-60, 60)
	d.Drag = 3
	d.LightEmission = 0.25
	d.Enabled = false
	d.Parent = a
	d:Emit(dustAmount)

	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(GOLD)
	sp.LightEmission = 1
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sp.Lifetime = NumberRange.new(0.6, 1.3)
	sp.Speed = NumberRange.new(30, 75)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.Acceleration = Vector3.new(0, -60, 0)
	sp.Enabled = false
	sp.Parent = a
	sp:Emit(math.floor(dustAmount * 1.2))

	Debris:AddItem(a, 3)
end

local function rocks(s, pos, n, power)
	for _ = 1, n do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Slate
		p.Color = Color3.fromRGB(100 + math.random(0, 30), 85 + math.random(0, 25), 65 + math.random(0, 15))
		local sz = lerp(0.8, 3.2, math.random() ^ 2)
		p.Size = Vector3.new(sz, sz * lerp(0.6, 1, math.random()), sz * lerp(0.6, 1, math.random()))
		p.CFrame = CFrame.new(pos + Vector3.new(math.random(-6, 6), 1, math.random(-6, 6)))
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.Parent = workspace
		s:track(p)
		local ang, r = math.random() * math.pi * 2, math.random() * power
		table.insert(s.rocks, {
			part = p,
			vel = Vector3.new(math.cos(ang) * r * 0.6, power * lerp(0.5, 1.3, math.random()), math.sin(ang) * r * 0.6),
			spin = Vector3.new(math.random(-4, 4), math.random(-4, 4), math.random(-4, 4)),
			age = 0,
			life = lerp(1.6, 2.8, math.random()),
		})
	end
end

local function pillar(s, pos, width, hold)
	width, hold = width or 16, hold or 1.4
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = Enum.PartType.Cylinder
	p.Material, p.Color, p.Transparency = Enum.Material.Neon, GOLD, 0.3
	p.Size = Vector3.new(300, 2, 2)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = workspace
	s:track(p)
	tween(p, 0.4, { Size = Vector3.new(300, width, width) }, Enum.EasingStyle.Back)
	task.delay(hold, function()
		if s.alive then tween(p, 0.9, { Size = Vector3.new(300, 0.5, 0.5), Transparency = 1 }) end
	end)
	Debris:AddItem(p, hold + 1.5)
end

local PURPLE = Color3.fromRGB(170, 120, 255)

-- purple lightning bolts striking around a point (Jing Yuan style)
local function lightning(s, pos, count)
	for _ = 1, count do
		task.delay(math.random() * 0.5, function()
			if not s.alive then return end
			local ang, r = math.random() * math.pi * 2, lerp(8, 42, math.random())
			local bottom = pos + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
			local top = bottom + Vector3.new(math.random(-8, 8), 90, math.random(-8, 8))
			local prev = top
			for k = 1, 6 do
				local nxt = top:Lerp(bottom, k / 6)
				if k < 6 then nxt += Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)) end
				local seg = Instance.new("Part")
				seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
				seg.Material, seg.Color, seg.Transparency = Enum.Material.Neon, (math.random() < 0.3) and PALE or PURPLE, 0
				local dist = (nxt - prev).Magnitude
				seg.Size = Vector3.new(0.7, 0.7, dist)
				seg.CFrame = CFrame.lookAt((prev + nxt) / 2, nxt)
				seg.Parent = workspace
				s:track(seg)
				tween(seg, 0.35, { Transparency = 1 })
				Debris:AddItem(seg, 0.5)
				prev = nxt
			end
			ring(s, bottom, 18, 0.35, 0.3)
		end)
	end
end

local function bolt(s, a, b, segs, jitter, color, thick, life)
	local prev = a
	for k = 1, segs do
		local nxt = a:Lerp(b, k / segs)
		if k < segs then nxt += Vector3.new((math.random() - 0.5) * jitter * 2, 0, (math.random() - 0.5) * jitter * 2) end
		local seg = Instance.new("Part")
		seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
		seg.Material, seg.Color, seg.Transparency = Enum.Material.Neon, color, 0
		seg.Size = Vector3.new(thick, thick, math.max((nxt - prev).Magnitude, 0.1))
		seg.CFrame = CFrame.lookAt((prev + nxt) / 2, nxt)
		seg.Parent = workspace
		s:track(seg)
		tween(seg, life, { Transparency = 1 })
		Debris:AddItem(seg, life + 0.15)
		prev = nxt
	end
end

----------------------------------------------------------------------
-- MAIN
----------------------------------------------------------------------
function module:IsCasting(player) return active[player] ~= nil end
function module:Cancel(player)
	local s = active[player]
	if s then s:cleanup() end
end

function module:Cast(player: Player)
	if player ~= Players.LocalPlayer or active[player] then return false end
	if lastCast[player] and os.clock() - lastCast[player] < CFG.COOLDOWN then
		notify(player, "Skill on cooldown")
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not (hum and hrp and cam) or hum.Health <= 0 then return false end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then notify(player, "Equip your sword first") return false end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return false end
	lastCast[player] = os.clock()

	local S = CFG.SCALE
	local baseScale = char:GetScale()
	local h = hum.HipHeight + hrp.Size.Y / 2

	-- session ---------------------------------------------------------
	local s = { alive = true, items = {}, conns = {}, rocks = {}, tracks = {}, build = 0, beamK = 0, t0 = os.clock(), m = 1, alpha = -1, shake = 0, fovPunch = 0 }
	active[player] = s
	function s:track(i) table.insert(self.items, i) return i end
	function s:connect(sig, fn) local c = sig:Connect(fn) table.insert(self.conns, c) return c end

	local oldSpeed = hum.WalkSpeed
	local camCF0, fov0, camType0 = cam.CFrame, cam.FieldOfView, cam.CameraType

	function s:cleanup()
		if not self.alive then return end
		self.alive = false
		active[player] = nil
		pcall(function() RunService:UnbindFromRenderStep("GiantSwingStep") end)
		for _, tr in self.tracks do pcall(function() tr:Stop() end) end
		for _, c in self.conns do c:Disconnect() end
		for _, i in self.items do if i and i.Parent then i:Destroy() end end
		if cam then cam.CameraType = Enum.CameraType.Custom cam.FieldOfView = fov0 end
		if hum and hum.Parent then
			hum.WalkSpeed = oldSpeed
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
	end

	hum.WalkSpeed = 0
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	s:connect(hum.Died, function() s:cleanup() end)

	-- lighting fx -----------------------------------------------------
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Parent = Lighting
	s:track(cc)
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.4, 30, 1
	bloom.Parent = Lighting
	s:track(bloom)
	tween(cc, 1, { Contrast = 0.15, Saturation = 0.15, TintColor = Color3.fromRGB(255, 238, 205) })

	-- gui: letterbox, flash, title -----------------------------------
	local gui = Instance.new("ScreenGui")
	gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = true, false, 50
	gui.Parent = player:WaitForChild("PlayerGui")
	s:track(gui)
	local function bar(top)
		local f = Instance.new("Frame")
		f.BackgroundColor3, f.BorderSizePixel, f.ZIndex = Color3.new(0, 0, 0), 0, 10
		f.AnchorPoint = Vector2.new(0, top and 0 or 1)
		f.Position = UDim2.fromScale(0, top and 0 or 1)
		f.Size = UDim2.fromScale(1, 0)
		f.Parent = gui
		return f
	end
	local barT, barB = bar(true), bar(false)
	local function setBars(v, t)
		tween(barT, t, { Size = UDim2.fromScale(1, v) })
		tween(barB, t, { Size = UDim2.fromScale(1, v) })
	end
	local flashF = Instance.new("Frame")
	flashF.Size, flashF.BorderSizePixel, flashF.ZIndex = UDim2.fromScale(1, 1), 0, 20
	flashF.BackgroundColor3, flashF.BackgroundTransparency = PALE, 1
	flashF.Parent = gui
	local function flash(strength, dur)
		flashF.BackgroundTransparency = 1 - strength
		tween(flashF, dur, { BackgroundTransparency = 1 })
	end
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency, title.TextTransparency = 1, 1
	title.AnchorPoint, title.Position = Vector2.new(0, 0.5), UDim2.fromScale(0.08, 0.5)
	title.Size = UDim2.fromOffset(110, 360)
	title.Font, title.TextSize, title.TextColor3 = Enum.Font.GothamBold, 72, GOLD
	title.Text = vertical(CFG.TITLE)
	title.ZIndex = 12
	title.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Transparency = Color3.fromRGB(120, 60, 0), 2, 1
	stroke.Parent = title
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency, sub.TextTransparency = 1, 1
	sub.AnchorPoint, sub.Position = Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.86)
	sub.Size = UDim2.fromOffset(400, 24)
	sub.Font, sub.TextSize, sub.TextColor3 = Enum.Font.GothamMedium, 16, PALE
	sub.Text = CFG.SUBTITLE
	sub.ZIndex = 12
	sub.Parent = gui
	local function titleFade(show, t)
		local v = show and 0 or 1
		tween(title, t, { TextTransparency = v })
		tween(stroke, t, { Transparency = v })
		tween(sub, t, { TextTransparency = v })
	end
	local function inkFrame() -- ink-wash style impact frame: black with white brush strokes
		local f = Instance.new("Frame")
		f.Size, f.BorderSizePixel, f.ZIndex = UDim2.fromScale(1, 1), 0, 18
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.Parent = gui
		for _ = 1, 7 do
			local b = Instance.new("Frame")
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Position = UDim2.fromScale(0.2 + math.random() * 0.6, 0.2 + math.random() * 0.6)
			b.Rotation = math.random(-60, 60)
			b.Size = UDim2.new(1.6, 0, 0, math.random(14, 60))
			b.BackgroundColor3, b.BorderSizePixel = Color3.new(1, 1, 1), 0
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
			})
			g.Parent = b
			b.Parent = f
		end
		Debris:AddItem(f, 0.09)
	end
	local function screenSlashes(n)
		for i = 1, n do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.5, 0.5 + (math.random() - 0.5) * 0.5)
			f.Rotation = math.random(-40, 40)
			f.BackgroundColor3 = (i % 3 == 0) and PURPLE or ((i % 2 == 0) and PALE or GOLD)
			f.BorderSizePixel, f.ZIndex = 0, 14
			f.Size = UDim2.new(0, 0, 0, math.random(4, 10))
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
			})
			g.Parent = f
			f.Parent = gui
			task.delay(i * 0.02, function()
				tween(f, 0.12, { Size = UDim2.new(1.3, 0, 0, f.Size.Y.Offset) }, Enum.EasingStyle.Exponential)
				task.delay(0.1, function() tween(f, 0.25, { BackgroundTransparency = 1 }) end)
			end)
			Debris:AddItem(f, 0.6)
		end
	end
	local function lightCross()
		for _, vert in { false, true } do
			local f = Instance.new("Frame")
			f.AnchorPoint, f.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
			f.BackgroundColor3, f.BorderSizePixel, f.ZIndex = PALE, 0, 15
			f.Size = vert and UDim2.new(0, 3, 0, 0) or UDim2.new(0, 0, 0, 3)
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
			})
			g.Rotation = vert and 90 or 0
			g.Parent = f
			f.Parent = gui
			tween(f, 0.35, { Size = vert and UDim2.new(0, 12, 1.6, 0) or UDim2.new(1.6, 0, 0, 12) }, Enum.EasingStyle.Exponential)
			task.delay(0.2, function() tween(f, 0.9, { BackgroundTransparency = 1 }) end)
			Debris:AddItem(f, 1.3)
		end
	end

	-- giant -----------------------------------------------------------
	local prevArch = char.Archivable
	char.Archivable = true
	local giant = char:Clone()
	char.Archivable = prevArch
	giant.Name = "GiantSpirit"
	for _, d in giant:GetDescendants() do
		if d:IsA("Humanoid") or d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui")
			or d:IsA("ForceField") or d:IsA("Clothing") or d:IsA("Decal") or d:IsA("SurfaceAppearance")
			or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	local gParts = {}
	for _, p in giant:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow, p.Massless = false, false, false, false, true
			p.Material, p.Color, p.Transparency = Enum.Material.Neon, GOLD, 1
			if p:IsA("MeshPart") then p.TextureID = "" end
			if p.Name ~= "HumanoidRootPart" then table.insert(gParts, p) end
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillColor, hl.OutlineColor = GOLD, PALE
	hl.FillTransparency, hl.OutlineTransparency = 1, 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = giant
	giant.Parent = workspace
	s:track(giant)

	local emitter
	local hand = giant:FindFirstChild("RightHand")
	if hand then
		local att = Instance.new("Attachment")
		att.Parent = hand
		emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(GOLD)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Speed = NumberRange.new(8, 25)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, 14, 0)
		emitter.Rate = 0
		emitter.Parent = att
	end

	-- joint map (forward kinematics): supports Motor6D, AnimationConstraint rigs and welds.
	-- The giant is fully anchored; every frame we rebuild its pose from YOUR joint Transforms.
	local src = {}
	for _, m in char:GetDescendants() do
		if m:IsA("Motor6D") and m.Part1 then
			src[m.Part1.Name .. "|" .. m.Name] = m
		elseif m:IsA("AnimationConstraint") and m.Attachment1 and m.Attachment1.Parent then
			src[m.Attachment1.Parent.Name .. "|" .. m.Name] = m
		end
	end
	local joints = {}
	for _, m in giant:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			table.insert(joints, { kind = "m", dst = m, src = src[m.Part1.Name .. "|" .. m.Name], p0 = m.Part0, p1 = m.Part1 })
		elseif m:IsA("AnimationConstraint") and m.Attachment0 and m.Attachment1 and m.Attachment0.Parent and m.Attachment1.Parent then
			local p1 = m.Attachment1.Parent
			table.insert(joints, { kind = "a", dst = m, src = src[p1.Name .. "|" .. m.Name], p0 = m.Attachment0.Parent, p1 = p1 })
		elseif m:IsA("Weld") and m.Part0 and m.Part1 then
			table.insert(joints, { kind = "w", dst = m, p0 = m.Part0, p1 = m.Part1 })
		elseif m:IsA("WeldConstraint") and m.Part0 and m.Part1 then
			table.insert(joints, { kind = "c", rel = m.Part0.CFrame:ToObjectSpace(m.Part1.CFrame), p0 = m.Part0, p1 = m.Part1 })
		end
	end
	local root = giant:FindFirstChild("HumanoidRootPart")
	local known, order = { [root] = true }, {}
	local progress = true
	while progress do
		progress = false
		for i = #joints, 1, -1 do
			local j = joints[i]
			if known[j.p0] and not known[j.p1] then
				j.fwd = true known[j.p1] = true
				table.insert(order, j) table.remove(joints, i) progress = true
			elseif known[j.p1] and not known[j.p0] then
				j.fwd = false known[j.p0] = true
				table.insert(order, j) table.remove(joints, i) progress = true
			elseif known[j.p0] and known[j.p1] then
				table.remove(joints, i)
			end
		end
	end
	local function jointRel(j, m) -- CFrame of p1 relative to p0
		if j.kind == "c" then return CFrame.new(j.rel.Position * m) * j.rel.Rotation end
		local c0, c1
		if j.kind == "a" then
			c0, c1 = j.dst.Attachment0.CFrame, j.dst.Attachment1.CFrame
		else
			c0, c1 = j.dst.C0, j.dst.C1
		end
		local tf = CFrame.identity
		if j.src then
			local t = j.src.Transform
			tf = CFrame.new(t.Position * m) * t.Rotation
		end
		return c0 * tf * c1:Inverse()
	end
	if #order == 0 then warn("GiantSwing: no joints mapped, giant cannot move") end

	-- charge VFX objects (follow the giant's sword) ---------------------
	local gTool = giant:FindFirstChildOfClass("Tool")
	local gHandle = gTool and gTool:FindFirstChild("Handle")
	local function swordTip() -- returns blade tip position and the direction hand -> tip
		local base = hand and hand.Position or giant:GetPivot().Position
		if gHandle and gHandle:IsA("BasePart") then
			local sz = gHandle.Size
			local axis, longest = Vector3.xAxis, sz.X
			if sz.Y > longest then axis, longest = Vector3.yAxis, sz.Y end
			if sz.Z > longest then axis, longest = Vector3.zAxis, sz.Z end
			local dir = gHandle.CFrame:VectorToWorldSpace(axis)
			local e1, e2 = gHandle.Position + dir * longest / 2, gHandle.Position - dir * longest / 2
			local tipP = ((e1 - base).Magnitude > (e2 - base).Magnitude) and e1 or e2
			local d = tipP - base
			return tipP, d.Magnitude > 0.01 and d.Unit or Vector3.yAxis
		end
		return base + Vector3.yAxis * S * 2, Vector3.yAxis
	end
	local function newPart(shape)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material, p.Color, p.Transparency = Enum.Material.Neon, GOLD, 1
		if shape then p.Shape = shape end
		p.Size = Vector3.one
		p.Parent = workspace
		s:track(p)
		return p
	end
	local beam = newPart(Enum.PartType.Cylinder) -- thin beam from the sword up through the clouds
	local blade = newPart() -- light blade that grows from the sword and swings with it
	blade.Color = PALE
	local bAtt0, bAtt1 = Instance.new("Attachment"), Instance.new("Attachment")
	bAtt0.Parent, bAtt1.Parent = blade, blade
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = bAtt0, bAtt1
	trail.Color = ColorSequence.new(PALE, GOLD)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime, trail.LightEmission, trail.MinLength, trail.FaceCamera = 0.5, 1, 0.1, true
	trail.Enabled = false
	trail.Parent = blade
	local cloudPart = newPart()
	cloudPart.Transparency = 1
	local cloudEm = Instance.new("ParticleEmitter")
	cloudEm.Texture = "rbxasset://textures/particles/smoke_main.dds"
	cloudEm.Color = ColorSequence.new(Color3.fromRGB(255, 240, 210), Color3.fromRGB(190, 170, 140))
	cloudEm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 40), NumberSequenceKeypoint.new(1, 130) })
	cloudEm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	cloudEm.Lifetime, cloudEm.Speed = NumberRange.new(2, 3), NumberRange.new(30, 60)
	cloudEm.SpreadAngle, cloudEm.LightEmission, cloudEm.Rate = Vector2.new(180, 180), 0.4, 0
	cloudEm.Parent = cloudPart

	-- camera + sync loop ----------------------------------------------
	cam.CameraType = Enum.CameraType.Scriptable
	local idx, lastCF, lastFov, blendT0 = 0, camCF0, fov0, 0
	local blendFrom, blendFov, blendLen = camCF0, fov0, 0.6

	RunService:BindToRenderStep("GiantSwingStep", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not s.alive then return end
		local t = os.clock() - s.t0
		local rcf = hrp.CFrame
		local pos, look, right, up = rcf.Position, rcf.LookVector, rcf.RightVector, Vector3.yAxis

		-- giant size / position / alpha
		local rp = math.clamp((t - T_RISE) / T_RISE_LEN, 0, 1)
		local m = lerp(1, S, 1 - (1 - rp) ^ 3)
		if math.abs(m - s.m) > 0.001 then s.m = m giant:ScaleTo(baseScale * m) end
		local gcf = rcf * CFrame.new(0, h * (m - 1), lerp(3, CFG.BACK, 1 - (1 - rp) ^ 3))
		giant:PivotTo(gcf)
		for _, j in order do
			local R = jointRel(j, m)
			if j.fwd then j.p1.CFrame = j.p0.CFrame * R else j.p0.CFrame = j.p1.CFrame * R:Inverse() end
		end
		local a = math.clamp((t - T_RISE) / 0.9, 0, 1)
		if s.fadeT0 then a = math.min(a, 1 - math.clamp((t - s.fadeT0) / 1.0, 0, 1)) end
		if math.abs(a - s.alpha) > 0.004 then
			s.alpha = a
			for _, p in gParts do p.Transparency = 1 - a * 0.6 end
			hl.FillTransparency, hl.OutlineTransparency = 1 - a * 0.45, 1 - a * 0.9
		end

		-- build-up: slow-motion wind-up that gets slower and more intense
		s.groundG = Vector3.new(gcf.Position.X, pos.Y - h, gcf.Position.Z)
		if s.swingT0 then
			local e = os.clock() - s.swingT0
			s.build = math.clamp(e / CFG.BUILD_TIME, 0, 1)
			if s.swingTrack and s.swingTrack.IsPlaying and not s.cutT and s.swingTrack.TimePosition >= CFG.CUT_T then
				s.cutT = t
			end
			if s.swingTrack and s.swingTrack.IsPlaying and not s.slamT and s.swingTrack.TimePosition >= CFG.SLAM_T then
				s.slamT, s.slamBurst = t, true
			end
			if s.slow and s.swingTrack and s.swingTrack.IsPlaying then
				local sp
				if s.swingTrack.TimePosition < CFG.SLAM_T then
					sp = lerp(CFG.SLOW_START, CFG.SLOW_MIN, ease(e / CFG.BUILD_TIME))
				else
					sp = CFG.SLAM_SPEED
				end
				s.swingTrack:AdjustSpeed(sp)
			end
			s.shake = math.max(s.shake, 0.08 + 0.45 * s.build)
			bloom.Intensity = lerp(0.4, 1.4, s.build)
		else
			s.build *= math.exp(-dt * 3)
		end
		if emitter then emitter.Rate = 90 * s.build end
		if s.freezeUntil then
			if os.clock() < s.freezeUntil then
				for _, tr in animator:GetPlayingAnimationTracks() do tr:AdjustSpeed(0) end
			else
				s.freezeUntil = nil
				for _, tr in animator:GetPlayingAnimationTracks() do tr:AdjustSpeed(1) end
			end
		end

		-- giant's charge VFX: sky lightning piercing the clouds, light blade, slash trail
		local tip, bdir = swordTip()
		local charging = s.swingT0 ~= nil and not s.slamT
		s.beamK = charging and s.build or math.max(0, s.beamK - dt * 5)
		local bk = 0
		if charging then bk = s.build
		elseif s.hitT then bk = 1 - math.clamp((t - s.hitT) / 0.7, 0, 1)
		elseif s.slamT then bk = 1 end
		if s.beamK > 0.01 then
			local w = lerp(0.6, S * 1.1, s.beamK)
			beam.Size = Vector3.new(500, w, w)
			beam.CFrame = CFrame.new(tip + Vector3.new(0, 250, 0)) * CFrame.Angles(0, 0, math.rad(90))
			beam.Transparency = lerp(0.5, 0.15, s.beamK)
		else
			beam.Transparency = 1
		end
		if bk > 0.01 then
			local len, w = S * 9 * ease(bk), S * 0.28
			blade.Size = Vector3.new(w, w, len)
			blade.CFrame = CFrame.lookAt(tip + bdir * len / 2, tip + bdir * len)
			bAtt0.Position, bAtt1.Position = Vector3.new(-S * 1.1, 0, -len / 2), Vector3.new(S * 1.1, 0, -len / 2)
			blade.Transparency = 0.15
		else
			blade.Transparency = 1
		end
		trail.Enabled = s.slamT ~= nil and (s.hitT == nil or t < s.hitT + 0.5)
		if charging and s.build > 0.05 then
			s.boltAcc = (s.boltAcc or 0) + dt
			if s.boltAcc > lerp(0.25, 0.06, s.build) then
				s.boltAcc = 0
				bolt(s, tip, tip + Vector3.new((math.random() - 0.5) * 40, 220, (math.random() - 0.5) * 40), 10, 7,
					math.random() < 0.35 and PALE or PURPLE, 0.8 + 1.2 * s.build, 0.25)
			end
			s.cloudAcc = (s.cloudAcc or 0) + dt
			if s.cloudAcc > 1.0 then
				s.cloudAcc = 0
				local cp = Vector3.new(tip.X, tip.Y + 110, tip.Z)
				ring(s, cp, 150 + 150 * s.build, 1.6, 1.0)
				cloudPart.Position = cp
				cloudEm:Emit(14)
			end
		end
		if s.slamBurst then -- the charge bursts through the clouds as the swing begins
			s.slamBurst = false
			for _ = 1, 7 do
				bolt(s, tip, tip + Vector3.new((math.random() - 0.5) * 60, 240, (math.random() - 0.5) * 60), 10, 9, PALE, 2.5, 0.4)
			end
			local cp = Vector3.new(tip.X, tip.Y + 110, tip.Z)
			ring(s, cp, 420, 1.2, 1.5)
			cloudPart.Position = cp
			cloudEm:Emit(50)
			s.shake = math.max(s.shake, 1.5)
			flash(0.35, 0.4)
		end

		-- rocks
		for i = #s.rocks, 1, -1 do
			local r = s.rocks[i]
			r.age += dt
			r.vel += Vector3.new(0, -45 * dt, 0)
			r.part.CFrame = CFrame.new(r.part.Position + r.vel * dt)
				* (r.part.CFrame.Rotation * CFrame.Angles(r.spin.X * dt, r.spin.Y * dt, r.spin.Z * dt))
			if r.age > r.life - 0.4 then r.part.Transparency = math.clamp((r.age - (r.life - 0.4)) / 0.4, 0, 1) end
			if r.age >= r.life then r.part:Destroy() table.remove(s.rocks, i) end
		end

		-- shots
		local gpos = gcf.Position
		local function shotA(u) -- starts as an extreme close-up on the eyes, then pulls back
			local k = ease(u / T_AIM_END)
			local head = pos + up * 1.9
			local cp = head + look * lerp(2.4, 7, k) + right * lerp(0.3, 1.2, k) + up * lerp(0.1, -1.2, k)
			return CFrame.lookAt(cp, head + up * lerp(0, -0.4, k)), lerp(26, 48, k)
		end
		-- framing helpers: keep the WHOLE giant (feet to raised sword), you, and the impact point in frame
		local gy = pos.Y - h -- ground level under you
		local aspect = cam.ViewportSize.X / math.max(cam.ViewportSize.Y, 1)
		local wide = aspect < 1.5 and 1.3 or 1 -- back off more on narrow/mobile screens
		local impactPos = (rcf * CFrame.new(0, 0, -CFG.IMPACT_DIST)).Position
		local function shotB(u) -- you tiny in the foreground, the giant's face looming behind
			local p = ease(u / 1.9)
			local cp = pos + look * (lerp(8, S * 2.9, p) * wide) + right * lerp(0.8, 3, p)
			cp = Vector3.new(cp.X, gy + CFG.CAM_LIFT + lerp(2, 3, p), cp.Z)
			local tg = Vector3.new(gpos.X, gy + lerp(3, S * 4.6, p), gpos.Z)
			return CFrame.lookAt(cp, tg), lerp(55, 64, p)
		end
		local function shotClose() -- close low angle on you raising the sword
			local k = ease(s.build)
			local phi = lerp(0.2, 0.9, k)
			local d = lerp(7, 5.5, k)
			local cp = pos + (look * math.cos(phi) + right * math.sin(phi)) * d
			cp = Vector3.new(cp.X, gy + CFG.CAM_LIFT + 0.8, cp.Z)
			return CFrame.lookAt(cp, pos + up * lerp(2.4, 4.4, k)), lerp(54, 44, k)
		end
		local function shotWide(u) -- giant + raised sword + you + impact point, all in frame
			local th = lerp(0.15, -0.45, ease(u / 4))
			local dir = right * math.cos(th) + look * math.sin(th)
			local mid = (gpos + impactPos) / 2
			local tg = Vector3.new(mid.X, gy + S * 3.6, mid.Z)
			local cp = tg + dir * (S * 8.2 * wide)
			cp = Vector3.new(cp.X, gy + CFG.CAM_LIFT + S * 1.8, cp.Z)
			return CFrame.lookAt(cp, tg), 58
		end
		local function shotGround(u) -- low shot along the ground: shockwave, rocks, dust
			local k = ease(u / 2)
			local dir = (look * 0.9 + right * 0.45).Unit
			local cp = impactPos + dir * (lerp(28, 36, k) * wide)
			cp = Vector3.new(cp.X, gy + CFG.CAM_LIFT + 2, cp.Z)
			return CFrame.lookAt(cp, impactPos + up * 5), lerp(72, 62, k)
		end
		local ni
		if s.tD and t >= s.tD then ni = 6
		elseif s.hitT then ni = 5
		elseif s.cutT then ni = 4
		elseif t >= T_SHOT_C then ni = 3
		elseif t >= T_AIM_END then ni = 2
		else ni = 1 end
		if ni ~= idx then
			idx = ni
			blendFrom, blendFov, blendT0 = lastCF, lastFov, t
			blendLen = ({ 0.6, 0.55, 0.45, 0.25, 0.08, 0.8 })[ni]
		end
		local cf, fov
		if idx == 1 then cf, fov = shotA(t)
		elseif idx == 2 then cf, fov = shotB(t - T_AIM_END)
		elseif idx == 3 then cf, fov = shotClose()
		elseif idx == 4 then cf, fov = shotWide(t - s.cutT)
		elseif idx == 5 then cf, fov = shotGround(t - s.hitT)
		else cf, fov = camCF0, fov0 end
		local w = ease((t - blendT0) / blendLen)
		if w < 1 then cf, fov = blendFrom:Lerp(cf, w), lerp(blendFov, fov, w) end
		lastCF, lastFov = cf, fov

		s.shake *= math.exp(-dt * 5)
		s.fovPunch *= math.exp(-dt * 6)
		local sh = s.shake
		if sh > 0.01 then
			cf = cf * CFrame.new((math.random() - 0.5) * sh, (math.random() - 0.5) * sh, 0)
				* CFrame.Angles(0, 0, math.rad((math.random() - 0.5) * sh * 1.5))
		end
		cam.CFrame = cf
		cam.FieldOfView = fov + s.fovPunch
	end)

	-- impact ----------------------------------------------------------
	local hit = Instance.new("BindableEvent")
	s:track(hit)
	local hooked = {}
	s:connect(animator.AnimationPlayed, function(track)
		if s.swinging and not s.swingTrack then s.swingTrack = track end
		if hooked[track] then return end
		hooked[track] = true
		s:connect(track:GetMarkerReachedSignal("Hit"), function() s.slow = false hit:Fire() end)
	end)

	local rayP = RaycastParams.new()
	rayP.FilterDescendantsInstances = { char, giant }
	local function groundPoint()
		local base = (hrp.CFrame * CFrame.new(0, 0, -CFG.IMPACT_DIST)).Position
		local r = workspace:Raycast(base + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), rayP)
		return r and r.Position or (base - Vector3.new(0, h, 0))
	end

	local function impact(big)
		s.hitT = os.clock() - s.t0
		local pos = groundPoint()
		-- hit-stop: long freeze on the big hit (freezes you AND the giant)
		s.freezeUntil = os.clock() + (big and 0.32 or CFG.HITSTOP)
		s.shake = math.max(s.shake, (big and 3.5 or 1.3) * CFG.SHAKE)
		s.fovPunch = big and 10 or 5
		flash(big and 0.8 or 0.25, 0.5)
		bloom.Intensity = big and 3 or 1.5
		tween(bloom, 0.8, { Intensity = 0.4 })
		if big then
			-- impact frames: ink (B/W) -> white-out -> dark -> back to normal
			cc.Saturation, cc.Contrast, cc.Brightness = -1, 1.6, 0.15
			task.delay(0.05, function() if s.alive then cc.Brightness = 0.95 end end)
			task.delay(0.10, function() if s.alive then cc.Brightness, cc.Contrast = -0.5, 2 inkFrame() end end)
			task.delay(0.16, function()
				if s.alive then
					cc.Brightness = 0
					tween(cc, 0.4, { Contrast = 0.15, Saturation = 0.15 })
				end
			end)
		end
		if big then -- "Lightbringer" finisher: sky beam + purple lightning
			pillar(s, pos, 60, 1.4)
			lightning(s, pos, 9)
			task.delay(0.3, function()
				if s.alive then tween(cc, 0.6, { TintColor = Color3.fromRGB(255, 238, 205), Brightness = 0 }) end
			end)
		end
		ring(s, pos, big and 90 or 50, 0.7, 0.8)
		if big then task.delay(0.12, function() if s.alive then ring(s, pos, 60, 0.6, 0.4) end end) end
		burst(s, pos, big and 60 or 30, big and 70 or 45)
		rocks(s, pos, big and 26 or 12, big and 70 or 45)
	end

	local function playSlash()
		local id = CFG.SLASH_ANIM_ID ~= "" and CFG.SLASH_ANIM_ID or nil
		if not id then
			local ok, res = pcall(function()
				return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(buildSlash())
			end)
			if not ok then
				warn("GiantSwing: set CFG.SLASH_ANIM_ID (RegisterKeyframeSequence is Studio-only): " .. tostring(res))
				return nil
			end
			id = res
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local tr = animator:LoadAnimation(anim)
		tr.Priority = Enum.AnimationPriority.Action4
		table.insert(s.tracks, tr)
		tr:Play(0.2)
		return tr
	end

	local function swing(big)
		local got = false
		local c = hit.Event:Once(function() got = true end)
		s.swinging, s.swingTrack, s.slow, s.swingT0 = true, nil, true, os.clock()
		local tr = playSlash()
		if tr then s.swingTrack = tr end
		local t1, lastPulse = os.clock(), os.clock()
		while s.alive and not got do
			local e = os.clock() - t1
			if not tr or e > 12 then break end
			if e > 0.6 and not tr.IsPlaying then break end
			if os.clock() - lastPulse > 0.7 and s.groundG then -- charge pulses
				lastPulse = os.clock()
				ring(s, s.groundG, 24 + 30 * s.build, 0.9, 0.3)
			end
			task.wait()
		end
		c:Disconnect()
		s.swinging, s.slow, s.swingT0 = false, false, nil
		if s.alive then impact(big) end
	end

	-- timeline --------------------------------------------------------
	local function now() return os.clock() - s.t0 end
	local function waitUntil(t) local d = t - now() if d > 0 then task.wait(d) end return s.alive end
	local function at(t, fn) task.delay(t, function() if s.alive then fn() end end) end

	at(0.0, function()
		setBars(CFG.LETTERBOX, 0.6)
		ring(s, hrp.Position - Vector3.new(0, h, 0), 30, 1.0, 0.4)
	end)
	at(0.55, function() -- eye flash
		flash(0.35, 0.35)
		bloom.Intensity = 1.8
		tween(bloom, 0.8, { Intensity = 0.4 })
		s.shake = 0.5
	end)
	at(T_RISE - 0.2, function() -- dim the world so the golden giant glows
		tween(cc, 0.8, { Brightness = -0.2, Contrast = 0.3, Saturation = 0, TintColor = Color3.fromRGB(215, 210, 240) })
	end)
	at(1.0, function() titleFade(true, 0.6) end)
	at(0.8, function()
		local gp = (hrp.CFrame * CFrame.new(0, -h, 6)).Position
		pillar(s, gp)
		ring(s, gp, 40, 1.2, 0.6)
		s.shake = 0.6
	end)
	at(T_RISE, function()
		local gp = (hrp.CFrame * CFrame.new(0, -h, 6)).Position
		ring(s, gp, 110, 1.6, 0.8)
		burst(s, gp, 30, 40)
		s.shake = 1.2
	end)
	at(T_FLASH, function()
		lightCross()
		flash(0.5, 0.5)
		bloom.Intensity = 2.5
		tween(bloom, 1, { Intensity = 0.4 })
		titleFade(false, 0.5)
		s.shake = 1.6
	end)

	task.spawn(function()
		local ok, err = pcall(function()
			if not waitUntil(T_SWING) then return end
			for i = 1, CFG.SWINGS do
				if not s.alive or tool.Parent ~= char then break end
				swing(i == CFG.SWINGS)
				if i < CFG.SWINGS then task.wait(CFG.SWING_GAP) end
			end
			task.wait(2.4)
			if not s.alive then return end
			s.fadeT0 = now()
			s.tD = now() + 0.3
			setBars(0, 0.8)
			task.wait(1.3)
		end)
		if not ok then warn("GiantSwing: " .. tostring(err)) end
		s:cleanup()
	end)

	return true
end

return module