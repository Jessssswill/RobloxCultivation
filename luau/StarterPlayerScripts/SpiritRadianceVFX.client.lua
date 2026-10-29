-- LocalScript: StarterPlayer.StarterPlayerScripts.SpiritRadianceVFX
-- Golden radiance on Spirit Sword (Tool attribute Element = "Thunder") while attacking or using skills. Off at rest.
-- The server sets Tool attributes GlowLevel (0 off, 1 attack, 2 skill, 3 ultimate) and GlowUntil (GetServerTimeNow time),
-- see ServerScriptService.SpiritRadianceGlow. The Tool needs MeshParts BladeGlow and LightWings (SpiritSword_v6_glow.fbx).
-- Effects are built on this client for every player's sword, so everyone sees everyone's glow.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local CORE = Color3.fromRGB(255, 246, 216) -- white-hot
local GOLD = Color3.fromRGB(255, 194, 61) -- warm rim
local GEM_HOT = Color3.fromRGB(190, 238, 255) -- blue gem at full flare
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local RISE = 0.35 -- seconds to reach the target level
local FADE = 0.5 -- seconds for a level 1 glow to fade out after GlowUntil
local PREDICT = 0.6 -- own swings light up at once, before the server attribute arrives
local WISP_CURVE = 1.0 -- studs, how far the wisps bulge off the blade

-- look per level, values in between are blended
local LEVELS = {
	[0] = { glowT = 1, wingT = 1, light = 0, range = 6, rate = 0, guardRate = 0, wisp = 1, trail = 1, life = 0.12, heat = 0, gem = 0 },
	{ glowT = 0.55, wingT = 1, light = 1.5, range = 9, rate = 4, guardRate = 0, wisp = 1, trail = 0.3, life = 0.16, heat = 0.25, gem = 0.15 },
	{ glowT = 0.3, wingT = 0.25, light = 3, range = 13, rate = 10, guardRate = 8, wisp = 0.4, trail = 0.12, life = 0.22, heat = 0.6, gem = 0.6 },
	{ glowT = 0.12, wingT = 0.05, light = 5, range = 17, rate = 18, guardRate = 16, wisp = 0.15, trail = 0, life = 0.3, heat = 1, gem = 1 },
}
local STEPS = 20 -- look steps per level
local MAX_STEP = 3 * STEPS

local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end

-- everything that changes while fading is built once here, so the frame loop allocates nothing
local LOOK = {}
for s = 0, MAX_STEP do
	local lv = s / STEPS
	local i = math.min(math.floor(lv), 2)
	local f = lv - i
	local a, b = LEVELS[i], LEVELS[i + 1]
	local v = {}
	for k, x in pairs(a) do v[k] = x + (b[k] - x) * f end
	v.wispSeq = NumberSequence.new({ kp(0, 1), kp(0.25, v.wisp), kp(0.75, v.wisp), kp(1, 1) })
	v.trailSeq = NumberSequence.new({ kp(0, v.trail), kp(1, 1) })
	v.glowColor = GOLD:Lerp(CORE, v.heat)
	v.wingColor = GOLD:Lerp(CORE, v.heat * 0.6)
	LOOK[s] = v
end

local rateScale = 1
local tracked = {} -- tool -> state
local active = {} -- tool -> state, only while glowing or fading
local heartbeat

local function newAttachment(parent, name, pos, xAxis, yAxis)
	local a = Instance.new("Attachment")
	a.Name = name
	if xAxis then
		a.CFrame = CFrame.fromMatrix(pos, xAxis, yAxis)
	else
		a.Position = pos
	end
	a.Parent = parent
	return a
end

local function sparkles(parent, speed, size)
	local e = Instance.new("ParticleEmitter")
	e.Name = "RadianceSparkles"
	e.Texture = SPARKLE
	e.Color = ColorSequence.new(CORE, GOLD)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ kp(0, 0), kp(0.15, size), kp(1, 0) })
	e.Transparency = NumberSequence.new({ kp(0, 0.1), kp(1, 1) })
	e.Lifetime = NumberRange.new(0.35, 0.8)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Rate = 0
	e.Enabled = false
	e.Parent = parent
	return e
end

-- blade line in the host part's space: BladeBase/BladeTip on Sword, else BladeGlow's long axis
local function bladeLine(st)
	local sword = st.sword
	local base = sword and sword:FindFirstChild("BladeBase")
	local tip = sword and sword:FindFirstChild("BladeTip")
	if base and tip and base:IsA("Attachment") and tip:IsA("Attachment") then
		return sword, base.Position, tip.Position
	end
	local s = st.glow.Size
	local axis = (s.X >= s.Y and s.X >= s.Z) and Vector3.xAxis or (s.Y >= s.Z and Vector3.yAxis or Vector3.zAxis)
	local half = axis * (axis:Dot(s) / 2)
	return st.glow, -half, half
end

-- built the first time the sword lights up, destroyed on unequip
local function build(st)
	local host, p0, p1 = bladeLine(st)
	local axis = (p1 - p0).Unit
	local side = axis:Cross(math.abs(axis.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis).Unit
	local fwd = axis:Cross(side)
	local len = (p1 - p0).Magnitude
	local made = {}
	local function keep(x)
		table.insert(made, x)
		return x
	end

	local trail = Instance.new("Trail")
	trail.Name = "RadianceTrail"
	trail.Attachment0 = keep(newAttachment(host, "RadianceBase", p0))
	trail.Attachment1 = keep(newAttachment(host, "RadianceTip", p1))
	trail.Color = ColorSequence.new(GOLD, CORE)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.MinLength = 0.05
	trail.FaceCamera = false
	trail.Enabled = false
	trail.Parent = host
	st.trail = trail

	local mid = keep(newAttachment(host, "RadianceMid", p0:Lerp(p1, 0.5)))
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Shadows = false
	light.Enabled = false
	light.Parent = mid
	st.light = light

	st.emitters = {}
	for _, f in ipairs({ 0.2, 0.5, 0.8 }) do
		local a = keep(newAttachment(host, "RadianceSpark", p0:Lerp(p1, f)))
		table.insert(st.emitters, sparkles(a, 2, 0.25))
	end
	-- guard sits about one stud below BladeBase on v6
	local guard = keep(newAttachment(host, "RadianceGuard", p0 - axis * (len * 0.22)))
	st.guardEmitter = sparkles(guard, 4, 0.3)

	-- wisps: three beams in planes 120 deg apart; CurveSize0/1 sway out of phase so they twist around the blade
	st.wisps = {}
	for i = 1, 3 do
		local th = i * math.pi * 2 / 3
		local out = side * math.cos(th) + fwd * math.sin(th)
		local curl = axis:Cross(out)
		local a0 = keep(newAttachment(host, "RadianceWispA", p0 - axis * (len * 0.25) + out * 0.25, curl, axis))
		local a1 = keep(newAttachment(host, "RadianceWispB", p1 - axis * (len * 0.08) - out * 0.15, curl, axis))
		local b = Instance.new("Beam")
		b.Name = "RadianceWisp"
		b.Attachment0, b.Attachment1 = a0, a1
		b.Color = ColorSequence.new(GOLD, CORE)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Width0, b.Width1 = 0.06, 0.03
		b.Segments = 20
		b.FaceCamera = true
		b.Enabled = false
		b.Parent = host
		table.insert(st.wisps, b)
	end
	st.made = made
end

local function apply(st, s)
	local v = LOOK[s]
	local on = s > 0
	st.glow.Transparency = v.glowT
	st.glow.Color = v.glowColor
	if st.wings then
		st.wings.Transparency = v.wingT
		st.wings.Color = v.wingColor
	end
	if st.gem then st.gem.Color = st.gemColors[s] end
	st.light.Enabled = on
	st.light.Brightness = v.light
	st.light.Range = v.range
	st.trail.Enabled = on
	st.trail.Transparency = v.trailSeq
	st.trail.Lifetime = v.life
	for _, e in ipairs(st.emitters) do
		e.Rate = v.rate * rateScale
		e.Enabled = v.rate > 0.5
	end
	st.guardEmitter.Rate = v.guardRate * rateScale
	st.guardEmitter.Enabled = v.guardRate > 0.5
	local wispOn = v.wisp < 0.99
	for _, b in ipairs(st.wisps) do
		b.Enabled = wispOn
		b.Transparency = v.wispSeq
	end
end

local function frame(dt)
	local serverNow = workspace:GetServerTimeNow()
	local clock = os.clock()
	for tool, st in pairs(active) do
		local target = serverNow < st.untilT and st.level or 0
		if clock < st.predictUntil and target < 1 then target = 1 end
		local a = st.amount
		if target > a then
			a = math.min(target, a + dt * math.max(target, 1) / RISE)
		elseif target < a then
			a = math.max(target, a - dt * math.max(a, 1) / FADE)
		end
		st.amount = a
		local s = math.floor(a * STEPS + 0.5)
		if s ~= st.step then
			st.step = s
			apply(st, s)
		end
		if s > 0 and LOOK[s].wisp < 0.99 then
			local t = clock * 2.2
			for i, b in ipairs(st.wisps) do
				local ph = t + i * 2.1
				b.CurveSize0 = WISP_CURVE * math.sin(ph)
				b.CurveSize1 = WISP_CURVE * math.cos(ph * 1.3)
			end
		end
		if s == 0 and target == 0 then active[tool] = nil end
	end
	if next(active) == nil and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function wake(st)
	if not tracked[st.tool] then return end
	if not st.made then build(st) end
	active[st.tool] = st
	if not heartbeat then heartbeat = RunService.Heartbeat:Connect(frame) end
end

local function untrack(tool)
	local st = tracked[tool]
	if not st then return end
	tracked[tool] = nil
	active[tool] = nil
	for _, c in ipairs(st.conns) do c:Disconnect() end
	if st.made then
		for _, x in ipairs(st.made) do x:Destroy() end
		st.trail:Destroy()
		for _, b in ipairs(st.wisps) do b:Destroy() end
	end
	st.glow.Transparency = 1
	if st.wings then st.wings.Transparency = 1 end
	if st.gem then st.gem.Color = st.gemColors[0] end
end

local function prepPart(p)
	p.Material = Enum.Material.Neon
	p.CastShadow = false
	p.Transparency = 1
end

local function track(tool, char, owner)
	if tracked[tool] or tool.Parent ~= char or tool:GetAttribute("Element") ~= "Thunder" then return end
	local glow = tool:FindFirstChild("BladeGlow", true)
	if not (glow and glow:IsA("BasePart")) then return end
	local wings = tool:FindFirstChild("LightWings", true)
	if wings and not wings:IsA("BasePart") then wings = nil end
	local gem = tool:FindFirstChild("QiGlow", true)
	if gem and not gem:IsA("BasePart") then gem = nil end
	local st = {
		tool = tool, char = char, owner = owner, glow = glow, wings = wings, gem = gem,
		sword = tool:FindFirstChild("Sword", true),
		amount = 0, step = 0, level = 0, untilT = 0, predictUntil = 0, conns = {},
	}
	prepPart(glow)
	if wings then prepPart(wings) end
	if gem then
		st.gemColors = {}
		local base = gem.Color
		for s = 0, MAX_STEP do st.gemColors[s] = base:Lerp(GEM_HOT, LOOK[s].gem) end
	end
	tracked[tool] = st

	local function readAttrs()
		local lv, u = tool:GetAttribute("GlowLevel"), tool:GetAttribute("GlowUntil")
		st.level = typeof(lv) == "number" and math.clamp(math.floor(lv), 0, 3) or 0
		st.untilT = typeof(u) == "number" and u or 0
		if st.level > 0 and st.untilT > workspace:GetServerTimeNow() then wake(st) end
	end
	table.insert(st.conns, tool:GetAttributeChangedSignal("GlowLevel"):Connect(readAttrs))
	table.insert(st.conns, tool:GetAttributeChangedSignal("GlowUntil"):Connect(readAttrs))
	table.insert(st.conns, tool.AncestryChanged:Connect(function()
		if tool.Parent ~= char then untrack(tool) end
	end))
	if char == player.Character then
		table.insert(st.conns, tool.Activated:Connect(function()
			st.predictUntil = os.clock() + PREDICT
			wake(st)
		end))
	end
	readAttrs()
end

local charConns = {} -- player -> connections of the current character

local function dropCharacter(p)
	if charConns[p] then
		for _, c in ipairs(charConns[p]) do c:Disconnect() end
		charConns[p] = nil
	end
	for tool, st in pairs(tracked) do
		if st.owner == p then untrack(tool) end
	end
end

local function watchCharacter(p, char)
	dropCharacter(p)
	local conns = {}
	table.insert(conns, char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then task.defer(track, c, char, p) end
	end))
	charConns[p] = conns
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") then task.defer(track, c, char, p) end
	end
end

local function watchPlayer(p)
	p.CharacterAdded:Connect(function(char) watchCharacter(p, char) end)
	p.CharacterRemoving:Connect(function() dropCharacter(p) end)
	if p.Character then watchCharacter(p, p.Character) end
end

Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(dropCharacter)
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end

-- optional quality: LocalPlayer attribute VFXQuality = "Low" halves the particles
local function readQuality()
	rateScale = player:GetAttribute("VFXQuality") == "Low" and 0.5 or 1
	for _, st in pairs(active) do st.step = -1 end
end
player:GetAttributeChangedSignal("VFXQuality"):Connect(readQuality)
readQuality()
