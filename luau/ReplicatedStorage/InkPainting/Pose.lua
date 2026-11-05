-- InkPainting/Pose (ModuleScript) -> ReplicatedStorage.InkPainting.Pose
-- Caster body + held brush for the T ultimate. Runs on EVERY client for the caster, because joint Transforms do not
-- replicate. Pose rows follow InkSkillController: {t, pitch, yaw, roll, dx, dy, dz} in degrees / studs.
-- Arms: pitch lifts forward/up, yaw sweeps around the body (+ = left), roll = out to the side (+ right arm, - left arm).
-- Elbows/knees: pitch = bend amount (sign picked per rig). Waist/Neck: pitch + = lean back / look up, yaw + = turn left.
-- The real brush is hidden and a client-side copy is drawn in the hand so it can grow without touching the tool welds.
local Config = require(script.Parent:WaitForChild("Config"))

local Pose = {}

local function K(t, p, y, r, dx, dy, dz)
	return { t, p or 0, y or 0, r or 0, dx or 0, dy or 0, dz or 0 }
end

local REST = {
	RightShoulder = K(0, 16, 0, 12),
	LeftShoulder = K(0, 14, 0, -12),
	RightElbow = K(0, 28),
	LeftElbow = K(0, 22),
}

-- Keyframes per shot. Shot 1 brush before the face, 2 launch into the storm, 3 load overhead, 4 giant stroke,
-- 5 conduct the painting, 6-7 brush to the sky for the eye, 8 command the demons, land.
local KEYS = {
	RightShoulder = {
		REST.RightShoulder, K(0.35, 140, 26, 0), K(0.85, 146, 28, 0),
		K(1.0, -25, -10, 45), K(1.45, -18, -30, 72), K(1.85, -10, -32, 70),
		K(2.2, 150, 0, 22), K(2.58, 168, 0, 18),
		K(2.78, 110, 20, 10), K(2.96, 35, 38, 6), K(3.2, 45, 30, 10),
		K(3.5, 100, 10, 15), K(4.45, 104, 6, 14),
		K(4.8, 165, 0, 10), K(6.15, 170, 0, 8),
		K(6.36, 168, -5, 20), K(6.5, 40, 32, 6), K(6.9, 50, 25, 10), K(7.3, 30, 10, 14), K(7.5, 16, 0, 12),
	},
	RightElbow = {
		REST.RightElbow, K(0.35, 72), K(0.85, 76),
		K(1.0, 25), K(1.45, 10), K(1.85, 12),
		K(2.2, 18), K(2.58, 14),
		K(2.78, 8), K(2.96, 16), K(3.2, 20),
		K(3.5, 10), K(4.45, 12),
		K(4.8, 6), K(6.15, 5),
		K(6.36, 12), K(6.5, 14), K(6.9, 22), K(7.5, 28),
	},
	LeftShoulder = {
		REST.LeftShoulder, K(0.35, 18, 0, -16), K(0.85, 20, 0, -18),
		K(1.0, 40, 0, -60), K(1.45, 32, 0, -78), K(1.85, 30, 0, -80),
		K(2.2, 80, -12, -12), K(2.58, 88, -10, -8),
		K(2.78, 40, 0, -40), K(2.96, -30, 0, -50), K(3.2, -10, 0, -45),
		K(3.5, 62, 40, 0), K(4.45, 64, 42, 0),
		K(4.8, 40, 0, -80), K(6.15, 42, 0, -82),
		K(6.36, 80, -10, -15), K(6.5, -25, 0, -50), K(6.9, -5, 0, -40), K(7.5, 14, 0, -12),
	},
	LeftElbow = {
		REST.LeftElbow, K(0.35, 30), K(0.85, 34),
		K(1.0, 15), K(1.45, 22), K(1.85, 25),
		K(2.2, 8), K(2.58, 5),
		K(2.96, 35), K(3.2, 30),
		K(3.5, 118), K(4.45, 122),
		K(4.8, 15), K(6.15, 15),
		K(6.36, 8), K(6.5, 35), K(7.5, 22),
	},
	Waist = {
		K(0), K(0.35, 0, 8, 0), K(0.85, -4, 10, 0),
		K(1.0, -12, 0, 0), K(1.45, 6, -12, 4), K(1.85, 8, -14, 4),
		K(2.2, 10, -18, 0), K(2.58, 14, -22, 0),
		K(2.78, 0, 5, 0), K(2.96, -30, 35, 0), K(3.2, -20, 25, 0),
		K(3.5, 4, -8, 0), K(4.45, 5, -10, 0),
		K(4.8, 10, 0, 0), K(6.15, 12, 0, 0),
		K(6.36, 14, -20, 0), K(6.5, -28, 30, 0), K(6.9, -12, 12, 0), K(7.5),
	},
	Neck = {
		K(0), K(0.35, -6, -6, 0), K(0.85, -8, -8, 0),
		K(1.0, 6), K(1.45, 12, 8, 0), K(1.85, 10, 8, 0),
		K(2.2, -10, 12, 0), K(2.58, -14, 14, 0),
		K(2.96, -18, -20, 0), K(3.2, -12, -12, 0),
		K(3.5, 4, 4, 0), K(4.45, 4, 6, 0),
		K(4.8, 24, 0, 0), K(6.15, 28, 0, 0),
		K(6.5, -14, -18, 0), K(6.9, -6, -6, 0), K(7.5),
	},
	RightHip = {
		K(0), K(0.85, -4, 0, 4),
		K(1.0, 30, 0, 6), K(1.45, 38, 0, 6), K(1.85, 36, 0, 8),
		K(2.2, -20, 0, 6), K(2.58, -24, 0, 6),
		K(2.96, 40, 0, 6), K(3.2, 30, 0, 6),
		K(3.5, 25, 0, 10), K(4.45, 26, 0, 10),
		K(4.8, 15, 0, 8), K(6.15, 16, 0, 8),
		K(6.5, 38, 0, 6), K(6.9, 30, 0, 6), K(7.3, 32, 0, 4), K(7.5),
	},
	LeftHip = {
		K(0), K(0.85, 4, 0, -4),
		K(1.0, 30, 0, -6), K(1.45, -14, 0, -6), K(1.85, -12, 0, -8),
		K(2.2, 38, 0, -6), K(2.58, 42, 0, -6),
		K(2.96, -10, 0, -6), K(3.2, -4, 0, -6),
		K(3.5, 10, 0, -12), K(4.45, 12, 0, -12),
		K(4.8, -8, 0, -8), K(6.15, -8, 0, -8),
		K(6.5, -10, 0, -6), K(6.9, 10, 0, -6), K(7.3, 30, 0, -4), K(7.5),
	},
	RightKnee = {
		K(0), K(1.0, 62), K(1.45, 72), K(1.85, 70),
		K(2.2, 40), K(2.58, 44), K(2.96, 60), K(3.2, 50),
		K(3.5, 50), K(4.45, 52), K(4.8, 30), K(6.15, 30),
		K(6.5, 64), K(6.9, 50), K(7.3, 58), K(7.5),
	},
	LeftKnee = {
		K(0), K(1.0, 62), K(1.45, 16), K(1.85, 18),
		K(2.2, 50), K(2.58, 52), K(2.96, 20), K(3.2, 24),
		K(3.5, 60), K(4.45, 62), K(4.8, 20), K(6.15, 22),
		K(6.5, 20), K(6.9, 40), K(7.3, 58), K(7.5),
	},
	Root = {
		K(0), K(0.85, 0, 0, 0, 0, -0.15, 0),
		K(1.0, -14, 0, 0, 0, -0.6, 0), K(1.45, -6, 0, 0), K(1.85, -4, 0, 0),
		K(2.2, 6, 0, 0), K(2.58, 8, 0, 0),
		K(2.96, -16, 0, 0, 0, -0.4, 0), K(3.2, -8, 0, 0),
		K(3.5, 0), K(4.45, 0), K(6.15, 2, 0, 0),
		K(6.5, -14, 0, 0, 0, -0.3, 0), K(6.9, -4, 0, 0), K(7.3, 0, 0, 0, 0, -0.9, 0), K(7.5),
	},
}

-- Brush direction in root space (x right, y up, -z forward). Brush tip points along it.
local BRUSH = {
	{ 0, 0.2, -0.4, -1 }, { 0.35, -0.04, -1, -0.12 }, { 0.85, -0.04, -1, -0.1 },
	{ 1.0, 0.7, -0.3, 0.6 }, { 1.45, 0.88, -0.22, 0.42 }, { 1.85, 0.86, -0.2, 0.45 },
	{ 2.2, 0.1, 0.65, 0.75 }, { 2.58, 0.1, 0.55, 0.85 },
	{ 2.78, 0, 0.25, -1 }, { 2.96, -0.4, -0.75, -0.55 }, { 3.2, -0.3, -0.6, -0.7 },
	{ 3.5, 0, 0.35, -1 }, { 4.45, 0.05, 0.4, -1 },
	{ 4.8, 0, 1, -0.08 }, { 6.15, 0, 1, -0.05 },
	{ 6.36, 0.1, 0.6, 0.8 }, { 6.5, -0.35, -0.75, -0.6 }, { 6.9, -0.2, -0.6, -0.8 }, { 7.5, 0.2, -0.4, -1 },
}

-- Grip in the right hand (same numbers InkDanceMotion used).
local GRIP_C0 = CFrame.new(0, -0.10804, 0) * CFrame.Angles(0, math.pi, 0)
local GRIP_Z = -0.8
local TIP_Z = 5.5

local WANTED = {
	Waist = true, Neck = true, RightShoulder = true, LeftShoulder = true, RightElbow = true, LeftElbow = true,
	RightHip = true, LeftHip = true, RightKnee = true, LeftKnee = true, Root = true, RightWrist = true,
}
local CHAIN = { "Root", "Waist", "RightShoulder", "RightElbow", "RightWrist" }

local function hermite(keys, t, c)
	local n = #keys
	if t <= keys[1][1] then return keys[1][c] end
	if t >= keys[n][1] then return keys[n][c] end
	local i = 1
	while keys[i + 1][1] < t do i += 1 end
	local a, b = keys[i], keys[i + 1]
	local p0, p3 = keys[math.max(1, i - 1)], keys[math.min(n, i + 2)]
	local span = b[1] - a[1]
	local u = (t - a[1]) / span
	local m0 = i == 1 and 0 or (b[c] - p0[c]) / math.max(1e-4, b[1] - p0[1]) * span
	local m1 = i + 1 == n and 0 or (p3[c] - a[c]) / math.max(1e-4, p3[1] - a[1]) * span
	return (2 * u ^ 3 - 3 * u ^ 2 + 1) * a[c] + (u ^ 3 - 2 * u ^ 2 + u) * m0 + (-2 * u ^ 3 + 3 * u ^ 2) * b[c] + (u ^ 3 - u ^ 2) * m1
end

local function sample(keys, t)
	return { t, hermite(keys, t, 2), hermite(keys, t, 3), hermite(keys, t, 4), hermite(keys, t, 5), hermite(keys, t, 6), hermite(keys, t, 7) }
end

local function brushDir(t)
	local v = Vector3.new(hermite(BRUSH, t, 2), hermite(BRUSH, t, 3), hermite(BRUSH, t, 4))
	return v.Magnitude > 1e-3 and v.Unit or Vector3.new(0, -1, 0)
end

local function jointWorld(j, w0, transform)
	if j:IsA("Motor6D") then
		return w0 * j.C0 * transform * j.C1:Inverse()
	end
	return w0 * j.Attachment0.CFrame * transform * j.Attachment1.CFrame:Inverse()
end

function Pose.Bind(char, tool)
	local root = char:FindFirstChild("HumanoidRootPart")
	local brush = tool and tool:FindFirstChild("Brush")
	assert(root and brush and brush:FindFirstChild("Handle"), "Ink Brush ultimate needs a root and an equipped brush")
	local self = { joints = {}, saved = {}, kinematic = {}, bend = {}, hidden = {} }

	for _, d in char:GetDescendants() do
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and WANTED[d.Name] and d.Part0 and d.Part1 then
			self.joints[d.Name] = d
		end
	end
	local look = root.CFrame.LookVector
	for _, n in { "RightElbow", "LeftElbow", "RightKnee", "LeftKnee" } do
		local j = self.joints[n]
		if j then
			local frame, c1
			if j:IsA("Motor6D") then
				frame, c1 = j.Part0.CFrame * j.C0, j.C1
			else
				frame, c1 = j.Attachment0.WorldCFrame, j.Attachment1.CFrame
			end
			local want = frame:VectorToObjectSpace(n:find("Knee") and -look or look)
			local offset = c1:Inverse().Position
			local moved = CFrame.Angles(0.3, 0, 0) * offset - offset
			self.bend[n] = moved:Dot(want) >= 0 and 1 or -1
		end
	end
	for _, j in self.joints do
		self.saved[j] = j.Transform
		if j:IsA("AnimationConstraint") then
			self.kinematic[j] = j.IsKinematic
			j.IsKinematic = true
		end
	end

	-- client-side brush copy: anchored parts placed from the handle every frame
	local copy = brush:Clone()
	local handle = copy:FindFirstChild("Handle")
	local parts = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
			d.LocalTransparencyModifier = 0
			table.insert(parts, { p = d, off = handle.CFrame:ToObjectSpace(d.CFrame), size = d.Size })
		end
	end
	copy.Name = "InkUltBrush"
	self.copy, self.copyParts, self.copyHandle = copy, parts, handle
	for _, d in brush:GetDescendants() do
		if d:IsA("BasePart") then
			self.hidden[d] = d.LocalTransparencyModifier
			d.LocalTransparencyModifier = 1
		end
	end
	self.lastScale = 1

	function self:Parent(folder)
		copy.Parent = folder
	end

	-- Returns brush info for the FX: tip, grip point, handle CFrame, direction, scale
	function self:Update(t, rootCF)
		local w = math.min(math.clamp(t / 0.15, 0, 1), math.clamp((Config.Duration - t) / 0.25, 0, 1))
		w = w * w * (3 - 2 * w)
		local transforms = {}
		for name, keys in KEYS do
			local j = self.joints[name]
			if j and j.Parent then
				local v = sample(keys, t)
				local cf
				if name:find("Elbow") or name:find("Knee") then
					cf = CFrame.Angles((self.bend[name] or 1) * math.rad(v[2]), 0, 0)
				else
					cf = CFrame.Angles(0, math.rad(v[3]), 0) * CFrame.Angles(math.rad(v[2]), 0, math.rad(v[4]))
					if name == "Root" then cf = CFrame.new(v[5], v[6], v[7]) * cf end
				end
				local tr = (self.saved[j] or CFrame.identity):Lerp(cf, w)
				j.Transform = tr
				transforms[name] = tr
			end
		end
		-- forward kinematics to the right hand (parts have not moved yet this frame)
		local world = rootCF
		for _, name in CHAIN do
			local j = self.joints[name]
			if not j then
				world = nil
				break
			end
			world = jointWorld(j, world, transforms[name] or j.Transform)
		end
		local hand = world or (char:FindFirstChild("RightHand") and char.RightHand.CFrame) or rootCF
		local s = Config.BrushScale(t)
		local dir = rootCF:VectorToWorldSpace(brushDir(t))
		local up = math.abs(dir:Dot(rootCF.UpVector)) > 0.95 and rootCF.LookVector or rootCF.UpVector
		local grip = (hand * GRIP_C0).Position
		local rot = CFrame.lookAt(Vector3.zero, -dir, up)
		local handleCF = CFrame.new(grip) * rot * CFrame.new(0, 0, -GRIP_Z * s)
		if math.abs(s - self.lastScale) > 1e-3 then
			for _, e in parts do
				e.p.Size = e.size * s
			end
			self.lastScale = s
		end
		local list, cfs = table.create(#parts), table.create(#parts)
		for i, e in parts do
			list[i] = e.p
			cfs[i] = handleCF * (CFrame.new(e.off.Position * s) * e.off.Rotation)
		end
		workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		return {
			tip = handleCF:PointToWorldSpace(Vector3.new(0, 0, TIP_Z * s)),
			grip = grip,
			handle = handleCF,
			dir = dir,
			scale = s,
		}
	end

	function self:Destroy()
		for j, cf in self.saved do
			if j.Parent then j.Transform = cf end
		end
		for j, was in self.kinematic do
			if j.Parent then j.IsKinematic = was end
		end
		for p, m in self.hidden do
			if p.Parent then p.LocalTransparencyModifier = m end
		end
		copy:Destroy()
	end

	return self
end

-- A second, colossal brush for the shot-4 slam (no hand, placed by the FX).
function Pose.Phantom(tool, scale)
	local brush = tool:FindFirstChild("Brush")
	local copy = brush:Clone()
	local handle = copy:FindFirstChild("Handle")
	local parts = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d:Destroy()
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
			d.LocalTransparencyModifier = 0
			local off = handle.CFrame:ToObjectSpace(d.CFrame)
			table.insert(parts, { p = d, off = CFrame.new(off.Position * scale) * off.Rotation, alpha = d.Transparency })
			d.Size *= scale
		end
	end
	copy.Name = "InkPhantomBrush"
	local self = { model = copy }
	-- place so the tip sits at `tip` and the brush points along `dir` (tip direction)
	function self:Place(tip, dir, up, alpha)
		local rot = CFrame.lookAt(Vector3.zero, -dir, up or Vector3.yAxis)
		local handleCF = CFrame.new(tip) * rot * CFrame.new(0, 0, -TIP_Z * scale)
		local list, cfs = table.create(#parts), table.create(#parts)
		for i, e in parts do
			list[i] = e.p
			cfs[i] = handleCF * e.off
			e.p.Transparency = 1 - (1 - e.alpha) * (1 - alpha)
		end
		workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	function self:Destroy()
		copy:Destroy()
	end
	return self
end

return Pose
