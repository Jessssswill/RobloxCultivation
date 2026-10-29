-- Disintegration.lua (ModuleScript)  |  灰飞烟灭  — Donghua rework
-- Put in: ReplicatedStorage/Skill/Disintegration  (replace the old one)
-- Usage is unchanged:  require(skills.Disintegration):Cast(player)
-- Extra API: module:IsCasting(player), module:Cancel(player)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

----------------------------------------------------------------------
-- ASSETS
----------------------------------------------------------------------
local assets = ReplicatedStorage:WaitForChild("Disintegration")
local animation = assets:WaitForChild("Animation"):WaitForChild("Animation")
local beamPart = assets:WaitForChild("Beam")
local chainPart = assets:WaitForChild("Chain")
local circlePart = assets:WaitForChild("Circle")
local barrierTemplate = assets:WaitForChild("Barrier")
local distortionSphere = assets:FindFirstChild("Distortion") -- optional
local castSound = assets:FindFirstChild("disintegration")     -- optional

----------------------------------------------------------------------
-- CONFIG (tweak here)
----------------------------------------------------------------------
local CONFIG = {
	DISTANCE = 50,          -- how far in front the formation spawns
	T_BARRIER = 2,          -- barrier beams start
	T_CHAIN = 6,            -- chain formation starts
	T_BEAM = 10.5,          -- the strike
	BEAM_LIFE = 8.5,
	BLEND = 0.45,           -- camera crossfade between shots
	LETTERBOX = 0.11,       -- cinematic bars (screen fraction each)
	RECOLOR = true,         -- re-tint particles/beams gold + jade (set false to keep your original colors)
	IMPACT_FRAMES = true,   -- black/white + white flash frames at the strike
	PLAY_SOUND = true,
	FX_LINGER = 3,          -- effects stay this many seconds AFTER the camera is released, then fade
	FLASH_STRENGTH = 0.45,  -- impact white-out opacity (0 = none, 1 = full white)
	TITLE = true,
	TITLE_TEXT = "灰飞烟灭",
	SEAL_TEXT = "灭",
	SUBTITLE = "— DISINTEGRATION —",
}

-- Palette: gold qi, jade lightning, ink black, vermilion seal
local GOLD = Color3.fromRGB(255, 200, 80)
local PALE = Color3.fromRGB(255, 244, 205)
local JADE = Color3.fromRGB(120, 235, 205)
local INK = Color3.fromRGB(10, 10, 12)
local VERMILION = Color3.fromRGB(196, 38, 38)
local WHITE = Color3.new(1, 1, 1)

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function ease(a) return a * a * (3 - 2 * a) end
local function lerp(a, b, t) return a + (b - a) * t end

local function scaleSeq(seq, k)
	local pts = {}
	for _, kp in ipairs(seq.Keypoints) do
		table.insert(pts, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
	end
	return NumberSequence.new(pts)
end

local function verticalText(str)
	local out = {}
	for _, cp in utf8.codes(str) do
		table.insert(out, utf8.char(cp))
	end
	return table.concat(out, "\n")
end

local function prepAnchored(inst)
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.CanCollide = false
		inst.CanQuery = false
		inst.CanTouch = false
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

local function tint(root, c0, c1)
	if not CONFIG.RECOLOR then return end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") then
			d.Color = ColorSequence.new(c0, c1)
		end
	end
end

----------------------------------------------------------------------
-- SESSION (owns everything one cast creates, so cleanup is always complete)
----------------------------------------------------------------------
local active = {}
local Session = {}
Session.__index = Session

local function newSession(player)
	return setmetatable({
		player = player,
		alive = true,
		items = {},
		conns = {},
		cleanups = {},
		shakes = {},
		t0 = os.clock(),
	}, Session)
end

function Session:Track(inst) table.insert(self.items, inst) return inst end
function Session:OnCleanup(fn) table.insert(self.cleanups, fn) end
function Session:Connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(self.conns, c)
	return c
end
function Session:Delay(t, fn)
	task.delay(t, function()
		if self.alive then fn() end
	end)
end
function Session:Tween(inst, info, goal)
	local tw = TweenService:Create(inst, info, goal)
	tw:Play()
	return tw
end
function Session:Loop(duration, fn, onDone)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not self.alive then conn:Disconnect() return end
		local a = math.clamp((os.clock() - start) / duration, 0, 1)
		fn(a, dt)
		if a >= 1 then
			conn:Disconnect()
			if onDone then onDone() end
		end
	end)
	table.insert(self.conns, conn)
end
function Session:Shake(duration, magnitude)
	table.insert(self.shakes, { start = os.clock(), duration = duration, mag = magnitude })
end
function Session:ShakeAmount()
	local now, amp = os.clock(), 0
	for i = #self.shakes, 1, -1 do
		local sh = self.shakes[i]
		local a = (now - sh.start) / sh.duration
		if a >= 1 then
			table.remove(self.shakes, i)
		else
			amp = math.max(amp, sh.mag * (1 - a))
		end
	end
	return amp
end
function Session:Cleanup()
	if not self.alive then return end
	self.alive = false
	for _, c in ipairs(self.conns) do c:Disconnect() end
	for _, fn in ipairs(self.cleanups) do pcall(fn) end
	for _, i in ipairs(self.items) do pcall(function() i:Destroy() end) end
	active[self.player] = nil
end

----------------------------------------------------------------------
-- FADE HELPERS
----------------------------------------------------------------------
local function fadeBeam(s, beam, duration)
	local keys = beam.Transparency.Keypoints
	s:Loop(duration, function(a)
		local pts = {}
		for _, k in ipairs(keys) do
			table.insert(pts, NumberSequenceKeypoint.new(k.Time, k.Value + (1 - k.Value) * a))
		end
		beam.Transparency = NumberSequence.new(pts)
	end)
end

local function fadeOut(s, root, duration)
	local info = TweenInfo.new(duration)
	local function handle(d)
		if d:IsA("BasePart") then
			s:Tween(d, info, { Transparency = 1 })
		elseif d:IsA("Beam") then
			fadeBeam(s, d, duration)
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		elseif d:IsA("Decal") or d:IsA("Texture") then
			s:Tween(d, info, { Transparency = 1 })
		end
	end
	handle(root)
	for _, d in ipairs(root:GetDescendants()) do handle(d) end
end

----------------------------------------------------------------------
-- GUI: letterbox, flash, title card with vermilion seal
----------------------------------------------------------------------
local function buildGui(s, player)
	local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
	local gui = s:Track(Instance.new("ScreenGui"))
	gui.Name = "DisintegrationCutscene"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = pg

	local function bar(anchorY)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = INK
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.fromScale(1, 0)
		f.ZIndex = 10
		f.Parent = gui
		return f
	end
	local top, bottom = bar(0), bar(1)
	local function setBars(scale, dur)
		for _, f in ipairs({ top, bottom }) do
			TweenService:Create(f, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Size = UDim2.fromScale(1, scale) }):Play()
		end
	end

	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 30
	flash.Parent = gui

	local fadeTitle = function() end
	if CONFIG.TITLE then
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.87, 0.46)
		label.Size = UDim2.fromScale(0.09, 0.5)
		label.Font = Enum.Font.GothamBlack
		label.Text = verticalText(CONFIG.TITLE_TEXT)
		label.TextScaled = true
		label.TextColor3 = GOLD
		label.TextTransparency = 1
		label.ZIndex = 20
		label.Parent = gui

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = INK
		stroke.Transparency = 1
		stroke.Parent = label

		local seal = Instance.new("Frame")
		seal.BackgroundColor3 = VERMILION
		seal.BackgroundTransparency = 1
		seal.BorderSizePixel = 0
		seal.AnchorPoint = Vector2.new(0.5, 0.5)
		seal.Position = UDim2.fromScale(0.87, 0.78)
		seal.Size = UDim2.fromOffset(46, 46)
		seal.Rotation = -5
		seal.ZIndex = 20
		seal.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = seal

		local sealText = Instance.new("TextLabel")
		sealText.BackgroundTransparency = 1
		sealText.Size = UDim2.fromScale(1, 1)
		sealText.Font = Enum.Font.GothamBlack
		sealText.Text = CONFIG.SEAL_TEXT
		sealText.TextScaled = true
		sealText.TextColor3 = PALE
		sealText.TextTransparency = 1
		sealText.ZIndex = 21
		sealText.Parent = seal
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 7)
		pad.PaddingBottom = UDim.new(0, 7)
		pad.PaddingLeft = UDim.new(0, 7)
		pad.PaddingRight = UDim.new(0, 7)
		pad.Parent = sealText

		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.AnchorPoint = Vector2.new(0.5, 1)
		sub.Position = UDim2.fromScale(0.5, 0.86)
		sub.Size = UDim2.fromScale(0.4, 0.035)
		sub.Font = Enum.Font.GothamMedium
		sub.Text = CONFIG.SUBTITLE
		sub.TextScaled = true
		sub.TextColor3 = PALE
		sub.TextTransparency = 1
		sub.ZIndex = 20
		sub.Parent = gui

		fadeTitle = function(visible, dur)
			local info = TweenInfo.new(dur, Enum.EasingStyle.Sine)
			local v = visible and 0 or 1
			TweenService:Create(label, info, { TextTransparency = v }):Play()
			TweenService:Create(stroke, info, { Transparency = v }):Play()
			TweenService:Create(seal, info, { BackgroundTransparency = visible and 0.05 or 1 }):Play()
			TweenService:Create(sealText, info, { TextTransparency = v }):Play()
			TweenService:Create(sub, info, { TextTransparency = v }):Play()
		end
	end

	return { setBars = setBars, flash = flash, fadeTitle = fadeTitle }
end

----------------------------------------------------------------------
-- WORLD EFFECTS
----------------------------------------------------------------------
local function groundAt(pos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	local ray = workspace:Raycast(pos + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), params)
	return ray and ray.Position or pos
end

-- Rising gold qi around the caster
local function runQi(s, root)
	local att = s:Track(Instance.new("Attachment"))
	att.Parent = root
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dng"
	em.Rate = 0
	em.Lifetime = NumberRange.new(1.2, 2)
	em.Speed = NumberRange.new(1, 4)
	em.SpreadAngle = Vector2.new(360, 360)
	em.Acceleration = Vector3.new(0, 7, 0)
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	em.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	em.Color = ColorSequence.new(GOLD, PALE)
	em.LightEmission = 1
	em.LightInfluence = 0
	em.RotSpeed = NumberRange.new(-90, 90)
	em.Parent = att
	s:Tween(em, TweenInfo.new(CONFIG.T_BEAM, Enum.EasingStyle.Sine), { Rate = 60 })
	s:Delay(CONFIG.T_BEAM + 0.2, function()
		s:Tween(em, TweenInfo.new(1.5), { Rate = 0 })
	end)
end

local function shockwave(s, center, delayT, color, maxSize)
	s:Delay(delayT, function()
		local ring = s:Track(Instance.new("Part"))
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Transparency = 0.55
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Size = Vector3.new(1, 4, 4)
		ring.CFrame = CFrame.new(center + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = workspace
		s:Tween(ring, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.6, maxSize, maxSize), Transparency = 1 })
		Debris:AddItem(ring, 1.4)
	end)
end

local function runCircle(s, center)
	local clone = s:Track(circlePart:Clone())
	prepAnchored(clone)
	clone.CFrame = CFrame.new(center + Vector3.new(0, 1, 0))
	tint(clone, GOLD, PALE)
	clone.Parent = workspace

	local groups = {}
	for _, att in ipairs(clone:GetDescendants()) do
		if att:IsA("Attachment") and att.Name:match("^Circle%d+$") then
			local list = {}
			for _, em in ipairs(att:GetChildren()) do
				if em:IsA("ParticleEmitter") then
					table.insert(list, { em = em, size = em.Size, bright = em.Brightness, rate = em.Rate })
					em.Size = scaleSeq(em.Size, 0)
					em.Brightness = 0
					em.Rate = 0
					em.Enabled = true
				end
			end
			if #list > 0 then
				table.insert(groups, { index = tonumber(att.Name:match("%d+")) or 0, list = list })
			end
		end
	end
	table.sort(groups, function(a, b) return a.index < b.index end)

	local N = #groups
	local STAG, APPEAR = 0.25, 2
	local appearTotal = math.max(N - 1, 0) * STAG + APPEAR
	local T_BEAM = CONFIG.T_BEAM

	-- 1) staggered build-up
	for i, g in ipairs(groups) do
		s:Delay((i - 1) * STAG, function()
			for _, e in ipairs(g.list) do
				s:Loop(APPEAR, function(a) e.em.Size = scaleSeq(e.size, ease(a)) end)
				s:Tween(e.em, TweenInfo.new(APPEAR, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{ Brightness = e.bright, Rate = e.rate })
			end
		end)
	end
	-- 2) slow charge until the strike
	s:Delay(appearTotal, function()
		local dur = math.max(T_BEAM - 0.3 - appearTotal, 0.5)
		for _, g in ipairs(groups) do
			for _, e in ipairs(g.list) do
				s:Tween(e.em, TweenInfo.new(dur, Enum.EasingStyle.Linear),
					{ Brightness = e.bright * 1.3, Rate = e.rate * 2 })
			end
		end
	end)
	-- 3) shine right before impact
	s:Delay(T_BEAM - 0.3, function()
		for _, g in ipairs(groups) do
			for _, e in ipairs(g.list) do
				s:Tween(e.em, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Brightness = e.bright * 1.8, Rate = e.rate * 3 })
			end
		end
	end)
	-- 4) settle under the beam
	s:Delay(T_BEAM + 0.1, function()
		for _, g in ipairs(groups) do
			for _, e in ipairs(g.list) do
				s:Tween(e.em, TweenInfo.new(1.2), { Brightness = e.bright * 1.1, Rate = e.rate * 1.3 })
			end
		end
	end)
	-- 5) dissolve, outermost first
	local T_END = T_BEAM + CONFIG.BEAM_LIFE + CONFIG.FX_LINGER
	local fadeAt = T_END - 0.5 - (math.max(N - 1, 0) * 0.12 + 0.6) -- dissolves right at the end
	for i = N, 1, -1 do
		local g = groups[i]
		s:Delay(fadeAt + (N - i) * 0.12, function()
			for _, e in ipairs(g.list) do
				s:Loop(0.5, function(a) e.em.Size = scaleSeq(e.size, 1 - ease(a)) end)
				s:Tween(e.em, TweenInfo.new(0.5), { Rate = 0 })
				s:Delay(0.5, function() e.em.Enabled = false end)
			end
		end)
	end
	s:Delay(fadeAt + math.max(N - 1, 0) * 0.12 + 0.6, function() fadeOut(s, clone, 0.5) end)

	return clone
end

local function runBarrier(s, circleClone)
	local temp = barrierTemplate:Clone()
	tint(temp, JADE, PALE)
	local map = {}
	for _, ch in ipairs(temp:GetChildren()) do
		if ch:IsA("Attachment") then
			ch.Parent = circleClone
			local beams = {}
			for _, d in ipairs(ch:GetChildren()) do
				if d:IsA("Beam") then
					d.Enabled = false
					if not d.Attachment0 then d.Attachment0 = ch end
					table.insert(beams, d)
				end
			end
			map[ch.Name] = beams
		end
	end
	temp:Destroy()

	local order = { "right1", "left1", "right2", "left2", "right3", "left3" }
	for i, name in ipairs(order) do
		local beams = map[name]
		if beams then
			s:Delay(CONFIG.T_BARRIER + (i - 1) * 0.9, function()
				for _, b in ipairs(beams) do b.Enabled = true end
			end)
		end
	end
	s:Delay(CONFIG.T_BEAM + CONFIG.BEAM_LIFE + CONFIG.FX_LINGER - 1.2, function()
		for _, beams in pairs(map) do
			for _, b in ipairs(beams) do
				fadeBeam(s, b, 0.6)
				s:Delay(0.6, function() b.Enabled = false end)
			end
		end
	end)
end

local function runChain(s, center)
	local clone = s:Track(chainPart:Clone())
	prepAnchored(clone)
	clone.CFrame = CFrame.new(center + Vector3.new(0, 1, 0))
	tint(clone, GOLD, PALE)
	clone.Parent = workspace

	local beams = {}
	for _, att in ipairs(clone:GetDescendants()) do
		if att:IsA("Attachment") and att.Name:match("^Chain%d+$") then
			local index = tonumber(att.Name:match("%d+")) or 0
			for _, obj in ipairs(att:GetChildren()) do
				if obj:IsA("Beam") then
					obj.Enabled = true
					obj.Transparency = NumberSequence.new(1)
					table.insert(beams, { index = index, beam = obj })
				end
			end
		end
	end
	table.sort(beams, function(a, b) return a.index < b.index end)

	for i, data in ipairs(beams) do
		s:Delay((i - 1) * 0.4, function()
			s:Loop(0.6, function(a) data.beam.Transparency = NumberSequence.new(1 - ease(a)) end)
		end)
	end

	-- spins faster as the strike approaches
	local lifetime = CONFIG.T_BEAM + CONFIG.BEAM_LIFE + CONFIG.FX_LINGER - 0.4 - CONFIG.T_CHAIN
	local ramp = CONFIG.T_BEAM - CONFIG.T_CHAIN
	local t0 = os.clock()
	s:Loop(lifetime, function(_, dt)
		local k = math.clamp((os.clock() - t0) / ramp, 0, 1)
		clone.CFrame *= CFrame.Angles(0, math.rad(lerp(60, 150, ease(k))) * dt, 0)
	end)
	s:Delay(lifetime - 0.6, function() fadeOut(s, clone, 0.6) end)
end

local function runBeamPart(s, center, template, yOff, lifetime)
	if not template then return end
	local clone = s:Track(template:Clone())
	-- Spark/GroundWind are spawned separately; strip them from the main beam so they don't double up
	if template == beamPart then
		for _, c in ipairs(clone:GetChildren()) do
			if c:IsA("BasePart") then c:Destroy() end
		end
	end
	prepAnchored(clone)
	clone.CFrame = CFrame.new(center + Vector3.new(0, yOff, 0))
	tint(clone, PALE, GOLD)
	clone.Parent = workspace
	s:Loop(lifetime, function(_, dt)
		clone.CFrame *= CFrame.Angles(0, math.rad(30) * dt, 0)
	end)
	s:Delay(lifetime - 0.6, function() fadeOut(s, clone, 0.6) end)
end

-- Screen-filling distortion after the strike (fixed: fills in, goes ink-black, then clears)
local function runDistortion(s, cam, delayT)
	if not distortionSphere then return end
	local bindName = "DisintegrationDistortion"
	s:Delay(delayT, function()
		local sphere = s:Track(distortionSphere:Clone())
		sphere.Anchored = true
		sphere.CanCollide = false
		sphere.CanQuery = false
		sphere.CanTouch = false
		sphere.Parent = cam
		RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 2, function()
			if sphere.Parent then sphere.CFrame = cam.CFrame end
		end)
		s:OnCleanup(function() RunService:UnbindFromRenderStep(bindName) end)

		local hl = sphere:FindFirstChildOfClass("Highlight")
		if not hl then
			hl = Instance.new("Highlight")
			hl.Parent = sphere
		end
		hl.Enabled = true
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = 1

		s:Tween(hl, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FillTransparency = 0.45 })
		s:Delay(1.4, function()
			s:Tween(hl, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ FillColor = INK, OutlineColor = INK })
		end)
		s:Delay(3.4, function()
			s:Tween(hl, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ FillTransparency = 1, OutlineTransparency = 1 })
		end)
		s:Delay(5.1, function()
			RunService:UnbindFromRenderStep(bindName)
			sphere:Destroy()
		end)
	end)
end

----------------------------------------------------------------------
-- MODULE API
----------------------------------------------------------------------
local module = {}

function module:IsCasting(player)
	return active[player] ~= nil
end

function module:Cancel(player)
	local s = active[player]
	if s then s:Cleanup() end
end

function module:Cast(player: Player)
	if active[player] then return end -- no overlapping casts (fixes the stuck-WalkSpeed bug)

	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not humanoid or not root or not cam or humanoid.Health <= 0 then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local T_BARRIER, T_CHAIN = CONFIG.T_BARRIER, CONFIG.T_CHAIN
	local T_BEAM, BEAM_LIFE = CONFIG.T_BEAM, CONFIG.BEAM_LIFE
	local T_END = T_BEAM + BEAM_LIFE

	local s = newSession(player)
	active[player] = s
	s:Connect(humanoid.Died, function() s:Cleanup() end)
	s:Connect(player.CharacterRemoving, function() s:Cleanup() end)

	-- Freeze the caster (always restored in cleanup)
	local saved = {
		ws = humanoid.WalkSpeed, jp = humanoid.JumpPower,
		jh = humanoid.JumpHeight, ar = humanoid.AutoRotate,
	}
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	local released = false
	local function restoreHumanoid()
		humanoid.WalkSpeed = saved.ws
		humanoid.JumpPower = saved.jp
		humanoid.JumpHeight = saved.jh
		humanoid.AutoRotate = saved.ar
	end
	s:OnCleanup(function()
		if not released then restoreHumanoid() end
	end)

	local track = animator:LoadAnimation(animation)
	track:Play()
	s:OnCleanup(function() track:Stop(0.25) end)

	if CONFIG.PLAY_SOUND and castSound and castSound:IsA("Sound") then
		local snd = s:Track(castSound:Clone())
		snd.Parent = root
		snd:Play()
	end

	-- Geometry
	local P = root.Position
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
	local L = flat.Unit
	local Y = Vector3.yAxis
	local Rt = L:Cross(Y)
	local head = P + Vector3.new(0, 1.5, 0)
	local center = groundAt(P + L * CONFIG.DISTANCE, char)

	-- Lighting grade (all created at runtime, nothing needed in Lighting)
	local cc = s:Track(Instance.new("ColorCorrectionEffect"))
	cc.Parent = Lighting
	local bloom = s:Track(Instance.new("BloomEffect"))
	bloom.Intensity = 0
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local blur = s:Track(Instance.new("BlurEffect"))
	blur.Size = 0
	blur.Parent = Lighting

	local warm = { TintColor = Color3.fromRGB(255, 240, 215), Contrast = 0.1, Saturation = 0.05, Brightness = 0 }
	local neutral = { TintColor = WHITE, Contrast = 0, Saturation = 0, Brightness = 0 }
	s:Tween(cc, TweenInfo.new(1.5), warm)
	s:Tween(bloom, TweenInfo.new(T_BEAM, Enum.EasingStyle.Sine), { Intensity = 0.25 })
	s:Delay(T_END - 1.4, function()
		s:Tween(cc, TweenInfo.new(1.4), neutral)
		s:Tween(bloom, TweenInfo.new(1.4), { Intensity = 0 })
	end)

	-- Eye / head glow for the close-up
	local glow = s:Track(Instance.new("PointLight"))
	glow.Color = GOLD
	glow.Brightness = 0
	glow.Range = 14
	glow.Parent = char:FindFirstChild("Head") or root
	s:Delay(T_BEAM - 1.6, function()
		s:Tween(glow, TweenInfo.new(1.4, Enum.EasingStyle.Sine), { Brightness = 2 })
	end)
	s:Delay(T_BEAM + 2, function()
		s:Tween(glow, TweenInfo.new(1.5), { Brightness = 0 })
	end)

	-- GUI
	local ui = buildGui(s, player)
	ui.setBars(CONFIG.LETTERBOX, 0.8)
	s:Delay(0.8, function() ui.fadeTitle(true, 0.7) end)
	s:Delay(5.2, function() ui.fadeTitle(false, 0.8) end)
	s:Delay(T_END - 0.8, function() ui.setBars(0, 0.8) end)

	----------------------------------------------------------------
	-- CUTSCENE CAMERA: 7 shots, crossfaded (impact shot is a hard cut)
	----------------------------------------------------------------
	local savedFov = cam.FieldOfView
	local CLOSEUP = T_BEAM - 1.2
	local shots = {
		-- 1. low-angle push-in on the caster
		{ 0, 2.4, function(a)
			local d = lerp(8, 4.5, ease(a))
			local pos = head + L * d + Rt * lerp(-1.5, 0.5, a) + Vector3.new(0, -2.4, 0)
			return CFrame.lookAt(pos, head + Vector3.new(0, 0.8, 0)), lerp(62, 48, a)
		end },
		-- 2. orbit between caster and formation
		{ 2.4, 6.0, function(a)
			local pivot = P + L * (CONFIG.DISTANCE * 0.5) + Vector3.new(0, 5, 0)
			local dir = CFrame.Angles(0, lerp(-1.2, 0.9, ease(a)), 0):VectorToWorldSpace(-L)
			local pos = pivot + dir * lerp(46, 38, a) + Vector3.new(0, lerp(7, 14, a), 0)
			return CFrame.lookAt(pos, pivot), 68
		end },
		-- 3. top-down formation reveal, slowly rotating
		{ 6.0, CLOSEUP, function(a)
			local h = lerp(95, 55, ease(a))
			local ang = lerp(0, 0.8, a)
			local up = Vector3.new(math.sin(ang), 0, -math.cos(ang))
			return CFrame.lookAt(center + Vector3.new(0, h, 0), center, up), lerp(70, 58, a)
		end },
		-- 4. face close-up, zoom punch
		{ CLOSEUP, T_BEAM, function(a)
			local pos = head + L * lerp(3.6, 2.4, a) + Rt * 1.1 + Vector3.new(0, 0.2, 0)
			return CFrame.lookAt(pos, head + Vector3.new(0, 0.1, 0)), lerp(34, 18, ease(a))
		end },
		-- 5. strike: behind the caster, wide, looking along the beam (hard cut)
		{ T_BEAM, T_BEAM + 2.2, function(a)
			local pos = P - L * lerp(7, 12, ease(a)) + Rt * lerp(-3, 2, a) + Vector3.new(0, lerp(2.5, 5, a), 0)
			return CFrame.lookAt(pos, center + Vector3.new(0, lerp(18, 40, a), 0)), lerp(105, 78, ease(a))
		end, 0 },
		-- 6. low ground angle, tilting up the beam
		{ T_BEAM + 2.2, T_BEAM + 5.5, function(a)
			local pos = center + Rt * lerp(34, 26, a) - L * 10 + Vector3.new(0, 2, 0)
			return CFrame.lookAt(pos, center + Vector3.new(0, lerp(10, 70, ease(a)), 0)), lerp(75, 88, a)
		end },
		-- 7. pull back to the standard over-the-shoulder view
		{ T_BEAM + 5.5, T_END, function(a)
			local e = ease(a)
			local posA = center + Rt * 30 + Vector3.new(0, 20, 0)
			local posB = P - L * 12 + Vector3.new(0, 4, 0)
			local tgtA = center + Vector3.new(0, 25, 0)
			local tgtB = head
			return CFrame.lookAt(posA:Lerp(posB, e), tgtA:Lerp(tgtB, e)), lerp(85, 70, e)
		end },
	}

	local bindName = "DisintegrationCutscene"
	cam.CameraType = Enum.CameraType.Scriptable
	local lastCF, lastFov = cam.CFrame, cam.FieldOfView
	local activeIdx, blendFrom, blendFromFov, blendStart, blendDur = 0, lastCF, lastFov, os.clock(), CONFIG.BLEND

	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - s.t0
		local idx = #shots
		for i, sh in ipairs(shots) do
			if t < sh[2] then idx = i break end
		end
		local sh = shots[idx]
		local a = math.clamp((t - sh[1]) / (sh[2] - sh[1]), 0, 1)
		local cf, fov = sh[3](a)

		if idx ~= activeIdx then
			activeIdx = idx
			blendFrom, blendFromFov = lastCF, lastFov
			blendStart = os.clock()
			blendDur = sh[4] or CONFIG.BLEND
		end
		local b = blendDur <= 0 and 1 or math.clamp((os.clock() - blendStart) / blendDur, 0, 1)
		cf = blendFrom:Lerp(cf, ease(b))
		fov = lerp(blendFromFov, fov, ease(b))
		lastCF, lastFov = cf, fov

		local amp = s:ShakeAmount()
		if amp > 0 then
			cf = cf * CFrame.new((math.random() - 0.5) * 2 * amp, (math.random() - 0.5) * 2 * amp, 0)
				* CFrame.Angles(0, 0, (math.random() - 0.5) * amp * 0.03)
		end
		cam.CFrame = cf
		cam.FieldOfView = fov
	end)
	-- Control (camera, movement) returns at T_END; the effects keep playing for FX_LINGER more seconds
	local function release()
		if released then return end
		released = true
		RunService:UnbindFromRenderStep(bindName)
		cam.FieldOfView = savedFov
		if humanoid.Parent then cam.CameraSubject = humanoid end
		cam.CameraType = Enum.CameraType.Custom
		restoreHumanoid()
		track:Stop(0.25)
	end
	s:OnCleanup(release)
	s:Delay(T_END, release)

	----------------------------------------------------------------
	-- TIMELINE
	----------------------------------------------------------------
	runQi(s, root)
	local circleClone = runCircle(s, center)
	s:Delay(T_BARRIER, function() runBarrier(s, circleClone) end)
	s:Delay(T_CHAIN, function() runChain(s, center) end)

	s:Delay(T_BEAM, function()
		-- the strike (spawned once; impact frames fire once, not 3x)
		runBeamPart(s, center, beamPart, 0, BEAM_LIFE + CONFIG.FX_LINGER)
		runBeamPart(s, center, beamPart:FindFirstChild("Spark"), 99, BEAM_LIFE + CONFIG.FX_LINGER)
		runBeamPart(s, center, beamPart:FindFirstChild("GroundWind"), 0, BEAM_LIFE + CONFIG.FX_LINGER)

		-- hit-stop on the caster's animation
		track:AdjustSpeed(0)
		s:Delay(0.12, function() track:AdjustSpeed(1) end)

		shockwave(s, center, 0, GOLD, 170)
		shockwave(s, center, 0.15, PALE, 240)
		shockwave(s, center, 0.3, JADE, 320)

		s:Tween(bloom, TweenInfo.new(0.1), { Intensity = 0.8 })
		s:Delay(0.4, function() s:Tween(bloom, TweenInfo.new(1.5), { Intensity = 0.35 }) end)
		s:Tween(glow, TweenInfo.new(0.1), { Brightness = 3 })
		blur.Size = 28
		s:Tween(blur, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 0 })

		s:Shake(0.45, 1.6)
		s:Shake(BEAM_LIFE - 0.5, 0.18)

		if CONFIG.IMPACT_FRAMES then
			-- Frame A: ink-wash black & white
			cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness = WHITE, -1, 1.4, -0.15
			local hl1 = s:Track(Instance.new("Highlight"))
			hl1.FillColor, hl1.OutlineColor = INK, WHITE
			hl1.FillTransparency, hl1.OutlineTransparency = 0, 0
			hl1.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl1.Parent = char

			s:Delay(0.09, function()
				hl1:Destroy()
				-- Frame B: white-out with gold outline, then fades
				cc.Saturation, cc.Contrast, cc.Brightness = 0, 0.15, 0
				cc.TintColor = warm.TintColor
				ui.flash.BackgroundColor3 = PALE
				ui.flash.BackgroundTransparency = 1 - CONFIG.FLASH_STRENGTH
				s:Tween(ui.flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundTransparency = 1 })
				local hl2 = s:Track(Instance.new("Highlight"))
				hl2.FillColor, hl2.OutlineColor = WHITE, Color3.fromRGB(255, 241, 46)
				hl2.FillTransparency, hl2.OutlineTransparency = 0.4, 0
				hl2.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl2.Parent = char
				s:Tween(hl2, TweenInfo.new(0.3), { FillTransparency = 1, OutlineTransparency = 1 })
				Debris:AddItem(hl2, 0.4)
			end)
		else
			ui.flash.BackgroundTransparency = 1 - CONFIG.FLASH_STRENGTH * 0.6
			s:Tween(ui.flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		end
	end)

	runDistortion(s, cam, T_BEAM + 3)

	s:Delay(T_END + CONFIG.FX_LINGER + 0.2, function() s:Cleanup() end)
end

return module