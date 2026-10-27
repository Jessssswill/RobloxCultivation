-- LocalScript: StarterPlayer.StarterPlayerScripts.WeaponLife
-- Makes held swords feel alive instead of statue-stiff. Runs on this client for every character, so everyone sees it.
--  1. Tassel physics: a Tool with a skinned MeshPart "Tassel" (bones T0, T1, ... from the cord down, see
--     assets/Tassel/tassel_rig.py) gets a verlet chain: it lags behind swings, swings when you run, settles slowly,
--     and stays outside the sword body. Same maths as assets/Tassel/tassel_sim.py (the preview video); keep in step.
--  2. Grip sway: the sword lags a little when you turn or accelerate, overshoots and settles, and breathes at rest.
--  3. Stances: while only the default tool-hold animation plays, the sword arm and the sword's angle in the fist follow
--     springs between idle (relaxed, blade up-forward, breathing and small wrist fidgets), walk (arm swings with the
--     stride), run (blade trailing behind) and air. Fades out whenever an attack/skill animation plays.
-- Nothing here replicates; the server never sees these offsets (hitboxes are unaffected).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local camera = workspace.CurrentCamera

local TASSEL = {
	gravity = 40, -- studs/s^2. Roblox's 196 makes cloth look snappy; ~40 reads as real weight at avatar scale
	damp = 0.985, -- per 1/60 s step
	stiff = 0.004, -- pull towards hanging straight down
	iters = 6,
	step = 1 / 60,
	maxSteps = 4, -- per frame, so a hitch doesn't explode the chain
	wind = 2.5, -- studs/s^2 of slow noise so it is never perfectly still
	range = 140, -- studs from the camera; farther tassels freeze
	bodyLength = 6.3, -- sword body capsule (studs at scale 1), from the pommel up
	bodyRadius = 0.16,
}

local SWAY = {
	yawPerTurn = 0.055, -- radians of lag per radian/s of turning
	pitchPerAccel = 0.004, -- radians per stud/s^2 of forward acceleration
	rollPerSide = 0.003,
	limit = math.rad(14),
	spring = 70, -- stiffness
	damping = 9,
	breathe = math.rad(1.3), -- idle wobble
	breatheHz = 0.28,
}

-- Stances, additive on top of the default "toolnone" hold (arm straight forward, ~79 deg at the shoulder). Degrees,
-- R15 Motor6D axes; X positive swings forward/up. grip = extra turn of the sword in the fist (RightGrip.C0), X positive
-- tips the blade up from the forearm line. Each joint follows its target on a spring, so changes overshoot a little and
-- settle like a real arm carrying weight. All of it fades out while an attack/skill animation plays.
local STANCE = {
	-- blade up-forward at ~40 deg, hand in front of the belly, turned a little outward so it stays off the face
	idle = { shoulder = Vector3.new(-60, 0, 0), elbow = Vector3.new(50, 0, 0), grip = Vector3.new(55, -15, 0) },
	-- same carry while walking (the stride swing is added on top); lower would put the tip into the ground
	walk = { shoulder = Vector3.new(-60, 0, 0), elbow = Vector3.new(52, 0, 0), grip = Vector3.new(58, -15, 0) },
	-- running: arm hangs back, blade turned behind and ~15 deg up. grip Y twists the sword around the forearm; going
	-- negative swings the blade out to the side on the way, so it never sweeps through the legs or the ground
	run = { shoulder = Vector3.new(-95, 0, 0), elbow = Vector3.new(15, 0, 0), grip = Vector3.new(60, -170, 0) },
	-- in the air: arm a little up, blade out and back
	air = { shoulder = Vector3.new(-72, 0, 0), elbow = Vector3.new(30, 0, 0), grip = Vector3.new(55, -120, 0) },
}
local MOTION = {
	spring = 55, -- joint spring stiffness
	damping = 10, -- < 2*sqrt(spring) so it overshoots slightly
	fade = 8, -- per second, hold weight in/out around attacks
	walkFrom = 2, -- studs/s: below this the idle stance
	runFrom = 19, -- studs/s: sprint (walk is 17, sprint 28)
	runFull = 25,
	strideRate = 0.75, -- radians of stride phase per stud moved
	walkSwing = 11, -- degrees of shoulder swing per stride
	runSwing = 6,
	breatheHz = 0.26,
	breathe = Vector3.new(2, 3, 3), -- shoulder, elbow, grip degrees
	wander = 5, -- slow wrist drift, degrees
	fidgetEvery = { 6, 11 }, -- seconds between small wrist turns while idle
	fidget = 18,
}

---------------------------------------------------------------------------------------------------------------------
-- tassel chains
---------------------------------------------------------------------------------------------------------------------
local chains = {} -- [MeshPart] = state
local original = setmetatable({}, { __mode = "k" }) -- [Bone] = { cf, scale } as imported; we overwrite bone CFrames

local function rotationBetween(a, b)
	local axis = a:Cross(b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	if axis.Magnitude < 1e-6 then
		return dot > 0 and CFrame.identity or CFrame.fromAxisAngle(Vector3.xAxis, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

local function buildChain(tassel, handle)
	local bones, i = {}, 0
	while true do
		local b = tassel:FindFirstChild("T" .. i, true)
		if not (b and b:IsA("Bone")) then
			break
		end
		bones[#bones + 1] = b
		i += 1
	end
	if #bones < 2 then
		return nil
	end
	local scale = (tassel.Parent and tassel.Parent:GetAttribute("AppliedScale")) or 1
	for _, b in ipairs(bones) do -- back to the imported pose (scaled to the current weapon size) before reading it
		local o = original[b]
		if not o then
			o = { cf = b.CFrame, scale = scale }
			original[b] = o
		end
		local k = scale / o.scale
		b.CFrame = o.cf - o.cf.Position + o.cf.Position * k
	end
	local hcf = handle.CFrame
	local rest, restRot, len = {}, {}, {}
	for k, b in ipairs(bones) do
		rest[k] = hcf:PointToObjectSpace(b.WorldPosition)
		restRot[k] = (hcf:ToObjectSpace(b.WorldCFrame)).Rotation
	end
	local n = #bones
	local tipAttr = tassel:GetAttribute("TipLength") -- studs at scale 1
	local tipLen = tipAttr and tipAttr * scale or (rest[n] - rest[n - 1]).Magnitude
	rest[n + 1] = rest[n] + (rest[n] - rest[n - 1]).Unit * tipLen
	for k = 1, n do
		len[k] = (rest[k + 1] - rest[k]).Magnitude
	end
	local axis = (rest[1] - rest[n + 1]).Unit -- the tassel hangs along the sword axis in the rest pose
	local p, q = {}, {}
	for k = 1, n + 1 do
		p[k] = hcf:PointToWorldSpace(rest[k])
		q[k] = p[k]
	end
	return {
		tassel = tassel,
		handle = handle,
		bones = bones,
		rest = rest,
		restRot = restRot,
		len = len,
		axis = axis,
		z0 = rest[1]:Dot(axis) + 0.02,
		z1 = rest[1]:Dot(axis) + TASSEL.bodyLength * scale,
		radius = TASSEL.bodyRadius * scale,
		p = p,
		q = q,
		acc = 0,
		lastHandle = hcf,
		scale = scale,
		seed = math.random() * 100,
	}
end

local function stepChain(c, hcf, wind)
	local p, q, len = c.p, c.q, c.len
	local dt = TASSEL.step
	p[1] = hcf:PointToWorldSpace(c.rest[1])
	q[1] = p[1]
	local g = Vector3.new(0, -TASSEL.gravity, 0) + wind
	for k = 2, #p do
		local v = (p[k] - q[k]) * TASSEL.damp
		q[k] = p[k]
		local np = p[k] + v + g * dt * dt
		local target = p[k - 1] - Vector3.new(0, len[k - 1], 0)
		p[k] = np:Lerp(target, TASSEL.stiff)
	end
	local axis, z0, z1, r = c.axis, c.z0, c.z1, c.radius
	for _ = 1, TASSEL.iters do
		for k = 1, #p - 1 do
			local d = p[k + 1] - p[k]
			local L = math.max(d.Magnitude, 1e-6)
			local corr = d * ((L - len[k]) / L)
			if k == 1 then
				p[k + 1] -= corr
			else
				p[k] += corr * 0.5
				p[k + 1] -= corr * 0.5
			end
		end
		for k = 2, #p do -- keep out of the sword body (capsule along the axis through the grip origin)
			local lp = hcf:PointToObjectSpace(p[k])
			local z = math.clamp(lp:Dot(axis), z0, z1)
			local off = lp - axis * z
			local m = off.Magnitude
			if m < r then
				off = m > 1e-5 and off * (r / m) or axis:Cross(Vector3.yAxis).Unit * r
				p[k] = hcf:PointToWorldSpace(axis * z + off)
			end
		end
	end
end

local function writeBones(c, hcf)
	local p = c.p
	for k, b in ipairs(c.bones) do
		local restA = hcf:VectorToWorldSpace(c.rest[k + 1] - c.rest[k]).Unit
		local d = p[k + 1] - p[k]
		if d.Magnitude > 1e-5 then
			local rot = rotationBetween(restA, d.Unit) * (hcf.Rotation * c.restRot[k])
			b.WorldCFrame = CFrame.new(p[k]) * rot
		end
	end
end

local function resetChain(c, hcf)
	for k = 1, #c.p do
		c.p[k] = hcf:PointToWorldSpace(c.rest[k])
		c.q[k] = c.p[k]
	end
	for _ = 1, 90 do
		stepChain(c, hcf, Vector3.zero)
	end
end

local track
local function updateTassels(dt, now)
	local camPos = camera.CFrame.Position
	for tassel, c in pairs(chains) do
		local handle = c.handle
		if not (tassel.Parent and handle.Parent and tassel:IsDescendantOf(workspace)) then
			continue
		end
		local hcf = handle.CFrame
		local scale = (tassel.Parent:GetAttribute("AppliedScale")) or 1
		if scale ~= c.scale then -- weapon rescaled for this avatar: rebuild from the new rest pose
			chains[tassel] = nil
			task.defer(track, tassel)
			continue
		end
		if (hcf.Position - camPos).Magnitude > TASSEL.range then
			c.lastHandle = hcf
			continue
		end
		if (hcf.Position - c.lastHandle.Position).Magnitude > 25 then -- teleport/respawn
			resetChain(c, hcf)
		end
		local wind = Vector3.new(
			math.noise(now * 0.35, c.seed, 0),
			0,
			math.noise(0, c.seed, now * 0.35)
		) * TASSEL.wind
		c.acc += dt
		local n = math.min(math.floor(c.acc / TASSEL.step), TASSEL.maxSteps)
		c.acc = math.min(c.acc - n * TASSEL.step, TASSEL.step)
		for s = 1, n do
			stepChain(c, c.lastHandle:Lerp(hcf, s / n), wind)
		end
		c.lastHandle = hcf
		writeBones(c, hcf)
	end
end

function track(tassel)
	if chains[tassel] or not tassel:IsA("BasePart") then
		return
	end
	local tool = tassel:FindFirstAncestorWhichIsA("Tool") or tassel.Parent
	-- sheathed copies (AttachScabbard) have no Handle; the Sword part shares the grip's axes and sits on the blade axis
	local handle = tool and (tool:FindFirstChild("Handle") or tool:FindFirstChild("Sword"))
	if not handle then
		return
	end
	local c = buildChain(tassel, handle)
	if c then
		chains[tassel] = c
		resetChain(c, handle.CFrame)
	end
end

---------------------------------------------------------------------------------------------------------------------
-- grip sway + relaxed hold, per character
---------------------------------------------------------------------------------------------------------------------
local rigs = {} -- [Model] = state

local function heldTool(char)
	local t = char:FindFirstChildWhichIsA("Tool")
	return t and t:FindFirstChild("Handle") and t
end

local function actionPlaying(animator)
	for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
		local pri = tr.Priority -- Core is the lowest priority but has the highest enum value (1000), so skip it
		if pri ~= Enum.AnimationPriority.Core and pri.Value >= Enum.AnimationPriority.Action.Value and tr.WeightCurrent > 0.1 then
			local name = tr.Animation and tr.Animation.Name or ""
			if name ~= "ToolNoneAnim" then
				return true
			end
		end
	end
	return false
end

local function rigState(char)
	local s = rigs[char]
	if s then
		return s
	end
	s = {
		ang = Vector3.zero, -- pitch, yaw, roll offsets
		vel = Vector3.zero,
		lastLook = nil,
		lastVel = Vector3.zero,
		hold = 0,
		pose = nil, -- { shoulder, elbow, grip } current spring values (degrees)
		poseVel = nil,
		air = 0,
		stride = 0,
		nextFidget = 0,
		fidgetT = -1,
		gripPose = CFrame.identity, -- written by updateHold, applied by updateSway
		phase = math.random() * 10,
		weld = nil,
		baseC0 = nil,
		written = nil,
	}
	rigs[char] = s
	return s
end

local function updateSway(char, s, dt, now)
	local root = char:FindFirstChild("HumanoidRootPart")
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local weld = hand and hand:FindFirstChild("RightGrip")
	if not (root and weld) then
		s.weld, s.lastLook = nil, nil
		return
	end
	if weld ~= s.weld or weld.C0 ~= s.written then -- new grip, or someone else changed it: take it as the base
		s.weld, s.baseC0 = weld, weld.C0
	end
	local look = root.CFrame.LookVector
	local vel = root.AssemblyLinearVelocity
	local target = Vector3.zero
	if s.lastLook and dt > 0 then
		local yawRate = math.atan2(s.lastLook:Cross(look).Y, s.lastLook:Dot(look)) / dt
		local accel = (vel - s.lastVel) / dt
		local fwd = accel:Dot(look)
		local side = accel:Dot(root.CFrame.RightVector)
		target = Vector3.new(-fwd * SWAY.pitchPerAccel, -yawRate * SWAY.yawPerTurn, -side * SWAY.rollPerSide)
		local L = SWAY.limit
		target = Vector3.new(math.clamp(target.X, -L, L), math.clamp(target.Y, -L, L), math.clamp(target.Z, -L, L))
	end
	s.lastLook, s.lastVel = look, vel
	-- damped spring towards the target lag
	local a = (target - s.ang) * SWAY.spring - s.vel * SWAY.damping
	s.vel += a * dt
	s.ang += s.vel * dt
	local b = math.sin((now + s.phase) * math.pi * 2 * SWAY.breatheHz) * SWAY.breathe
	local off = CFrame.Angles(s.ang.X + b, s.ang.Y, s.ang.Z + b * 0.4)
	local c0 = s.baseC0 * s.gripPose * off
	weld.C0 = c0
	s.written = c0
end

local function rad(v)
	return CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
end

local function blend(a, b, t)
	return {
		shoulder = a.shoulder:Lerp(b.shoulder, t),
		elbow = a.elbow:Lerp(b.elbow, t),
		grip = a.grip:Lerp(b.grip, t),
	}
end

local function updateHold(char, s, dt, now)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local upper = char:FindFirstChild("RightUpperArm")
	local lower = char:FindFirstChild("RightLowerArm")
	if not (animator and upper and lower) then
		return
	end
	local want = actionPlaying(animator) and 0 or 1
	s.hold += (want - s.hold) * math.min(1, dt * MOTION.fade)
	local v = char.PrimaryPart.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local state = hum:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
	s.air += ((airborne and 1 or 0) - s.air) * math.min(1, dt * 6)

	-- target stance from speed and air time
	local walkT = math.clamp((speed - MOTION.walkFrom) / 6, 0, 1)
	local runT = math.clamp((speed - MOTION.runFrom) / (MOTION.runFull - MOTION.runFrom), 0, 1)
	local target = blend(blend(blend(STANCE.idle, STANCE.walk, walkT), STANCE.run, runT), STANCE.air, s.air)

	-- stride swing, breathing, slow wrist drift, and the odd idle fidget
	s.stride += speed * dt * MOTION.strideRate
	local swing = math.sin(s.stride) * (MOTION.walkSwing * walkT * (1 - runT) + MOTION.runSwing * runT) * (1 - s.air)
	local idleT = (1 - walkT) * (1 - s.air)
	local br = math.sin((now + s.phase) * math.pi * 2 * MOTION.breatheHz)
	local b2 = math.sin((now + s.phase) * math.pi * 2 * MOTION.breatheHz + 1.1)
	local wx = math.noise(now * 0.18, s.phase, 1) * MOTION.wander * idleT
	local wy = math.noise(now * 0.13, s.phase, 2) * MOTION.wander * idleT
	local fid = 0
	if idleT > 0.9 then
		if s.fidgetT < 0 and now > s.nextFidget then
			s.fidgetT = 0
		end
	else
		s.nextFidget = now + MOTION.fidgetEvery[1]
	end
	if s.fidgetT >= 0 then
		s.fidgetT += dt
		local t = s.fidgetT / 1.4
		if t >= 1 then
			s.fidgetT = -1
			s.nextFidget = now + MOTION.fidgetEvery[1] + math.random() * (MOTION.fidgetEvery[2] - MOTION.fidgetEvery[1])
		else
			fid = math.sin(t * math.pi) * MOTION.fidget
		end
	end
	target.shoulder += Vector3.new(swing + br * MOTION.breathe.X * idleT, 0, 0)
	target.elbow += Vector3.new(-swing * 0.6 + b2 * MOTION.breathe.Y * idleT, 0, 0)
	target.grip += Vector3.new(swing * 0.8 + br * MOTION.breathe.Z * idleT + wx, wy + fid, fid * 0.5)

	-- springs
	if not s.pose then
		s.pose = { shoulder = target.shoulder, elbow = target.elbow, grip = target.grip }
		s.poseVel = { shoulder = Vector3.zero, elbow = Vector3.zero, grip = Vector3.zero }
	end
	local h = math.min(dt, 1 / 30)
	for _, k in ipairs({ "shoulder", "elbow", "grip" }) do
		local a = (target[k] - s.pose[k]) * MOTION.spring - s.poseVel[k] * MOTION.damping
		s.poseVel[k] += a * h
		s.pose[k] += s.poseVel[k] * h
	end

	local w = s.hold
	s.gripPose = CFrame.identity:Lerp(rad(s.pose.grip), w)
	if w < 0.01 then
		return
	end
	local sh = upper:FindFirstChild("RightShoulder")
	local el = lower:FindFirstChild("RightElbow")
	if sh then
		sh.Transform = sh.Transform * CFrame.identity:Lerp(rad(s.pose.shoulder), w)
	end
	if el then
		el.Transform = el.Transform * CFrame.identity:Lerp(rad(s.pose.elbow), w)
	end
end

---------------------------------------------------------------------------------------------------------------------
-- discovery + loops
---------------------------------------------------------------------------------------------------------------------
local function scan(inst)
	if inst.Name == "Tassel" and inst:IsA("BasePart") then
		task.defer(track, inst)
	end
end
for _, d in ipairs(workspace:GetDescendants()) do
	scan(d)
end
workspace.DescendantAdded:Connect(scan)
workspace.DescendantRemoving:Connect(function(d)
	chains[d] = nil
	rigs[d] = nil
end)

-- arm pose has to be applied after the Animator writes Transform, which happens before Stepped
RunService.Stepped:Connect(function(_, dt)
	local now = os.clock()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and char.PrimaryPart and heldTool(char) then
			updateHold(char, rigState(char), dt, now)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and heldTool(char) then
			updateSway(char, rigState(char), dt, now)
		end
	end
	updateTassels(dt, now)
end)
