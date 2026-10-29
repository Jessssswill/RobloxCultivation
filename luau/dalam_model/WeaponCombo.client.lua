-- Combo 4 hit per gaya senjata. Attribute "AnimSet" di Tool memilih animasi (misal "Jian" -> QiAnims.Jian_Slash1..4).
-- Kalau set itu belum ada, pakai Slash1..4 biasa. RegisterKeyframeSequence cuma jalan di Studio; game asli pakai AnimationId hasil upload.
-- Efek (tebasan bercahaya, ledakan hit, getar kamera, hit-stop, dorongan maju) cuma dibuat di client pemain sendiri.
local tool = script.Parent
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local KSP = game:GetService("KeyframeSequenceProvider")
local player = Players.LocalPlayer
local remote = tool:WaitForChild("Hit")
local Anims = RS:WaitForChild("QiAnims")

local trails = {}
for _, d in ipairs(tool:GetDescendants()) do
	if d:IsA("Trail") then table.insert(trails, d) end
end
local function setTrail(on)
	for _, t in ipairs(trails) do t.Enabled = on end
end

-- warna efek ikut warna trail pedang
local colorA, colorB = Color3.new(1, 1, 1), Color3.fromRGB(120, 200, 255)
if trails[1] then
	local kp = trails[1].Color.Keypoints
	colorA, colorB = kp[1].Value, kp[#kp].Value
end

-- Bentuk tebasan per langkah combo, relatif ke HumanoidRootPart (stud): titik awal, titik akhir, arah lengkungan
local ARCS = {
	{ Vector3.new(0.8, 0.4, -1.5), Vector3.new(0.8, 0.4, -7.5), Vector3.new(0, 0, 0), 1.2 },
	{ Vector3.new(-2.5, -1.8, -2), Vector3.new(2.8, 3.2, -1.5), Vector3.new(0, 0, -3), 2.2 },
	{ Vector3.new(3.2, 0.3, -0.5), Vector3.new(-3.2, 0.5, -0.5), Vector3.new(0, 0, -4), 2.4 },
	{ Vector3.new(0.3, 4.5, -1), Vector3.new(0, -2.8, -3), Vector3.new(0, 0, -4.5), 3.2 },
}
local ARC3B = { Vector3.new(-3.2, 0.8, -0.5), Vector3.new(3.4, 0.2, -0.5), Vector3.new(0, 0, -4.2), 2.4 }
local LUNGE = { 26, 12, 14, 20 }

local function root()
	local char = tool.Parent
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function attachmentAt(parent, pos, axis)
	local up = math.abs(axis.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
	local a = Instance.new("Attachment")
	a.WorldCFrame = CFrame.fromMatrix(pos, axis, axis:Cross(up):Cross(axis).Unit)
	a.Parent = parent
	return a
end

local function slashArc(arc)
	local hrp = root()
	if not hrp then return end
	local cf = hrp.CFrame
	local p0, p1 = cf:PointToWorldSpace(arc[1]), cf:PointToWorldSpace(arc[2])
	local bulge = cf:VectorToWorldSpace(arc[3])
	local span = p1 - p0
	local c0 = p0 + bulge + span * 0.15
	local c1 = p1 + bulge - span * 0.15
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency, holder.Size, holder.CFrame = 1, Vector3.one * 0.2, CFrame.new(p0)
	holder.Parent = workspace
	local a0 = attachmentAt(holder, p0, (c0 - p0).Magnitude > 0.01 and (c0 - p0).Unit or span.Unit)
	local a1 = attachmentAt(holder, p1, (p1 - c1).Magnitude > 0.01 and (p1 - c1).Unit or span.Unit)
	local beams = {}
	for layer = 1, 2 do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.CurveSize0, b.CurveSize1 = (c0 - p0).Magnitude, (p1 - c1).Magnitude
		b.FaceCamera = true
		b.Segments = 24
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Width0 = layer == 1 and arc[4] * 0.25 or arc[4] * 0.08
		b.Width1 = layer == 1 and arc[4] or arc[4] * 0.35
		b.Color = layer == 1 and ColorSequence.new(colorB, colorA) or ColorSequence.new(Color3.new(1, 1, 1))
		b.Parent = holder
		beams[layer] = b
	end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) / 0.28
		if t >= 1 then
			conn:Disconnect()
			holder:Destroy()
			return
		end
		-- muncul cepat dari ujung awal, lalu memudar dari pangkal
		local head = math.min(t * 3, 1)
		local tail = math.clamp((t - 0.25) / 0.75, 0, 1)
		for layer, b in ipairs(beams) do
			local base = layer == 1 and 0.15 or 0
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, math.clamp(base + tail * 1.2, 0, 1)),
				NumberSequenceKeypoint.new(math.clamp(head - 0.01, 0.001, 0.996), math.clamp(base + tail, 0, 1)),
				NumberSequenceKeypoint.new(math.clamp(head - 0.01, 0.001, 0.996) + 0.002, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end)
end

local function impact(big)
	local hrp = root()
	if not hrp then return end
	local pos = hrp.CFrame:PointToWorldSpace(Vector3.new(0, 0.3, big and -4 or -3.5))
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = colorA
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.Size = Vector3.one * 0.6
	ball.CFrame = CFrame.new(pos)
	ball.Transparency = 0.1
	ball.Parent = workspace
	local size = big and 7 or 4
	TweenService:Create(ball, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size, Transparency = 1 }):Play()
	local ring = Instance.new("Part")
	ring.Material = Enum.Material.Neon
	ring.Color = colorB
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Size = Vector3.new(0.1, 1, 1)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.lookAt(pos, workspace.CurrentCamera.CFrame.Position) * CFrame.Angles(0, math.rad(90), 0)
	ring.Transparency = 0.2
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, size * 1.6, size * 1.6), Transparency = 1 }):Play()
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), colorA)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.Speed = NumberRange.new(18, 34)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.15, 0.3)
	sparks.Drag = 6
	sparks.Enabled = false
	sparks.Parent = ball
	sparks:Emit(big and 28 or 14)
	Debris:AddItem(ball, 0.5)
	Debris:AddItem(ring, 0.5)
end

local function shake(strength)
	local _, hum = root()
	if not hum then return end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > 0.16 or not hum.Parent then
			hum.CameraOffset = Vector3.zero
			conn:Disconnect()
			return
		end
		local k = strength * (1 - t / 0.16)
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
end

local function lunge(speed)
	local hrp = root()
	if not hrp then return end
	local att = Instance.new("Attachment")
	att.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	lv.LineDirection = hrp.CFrame.LookVector
	lv.LineVelocity = speed
	lv.MaxForce = 60000
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = hrp
	Debris:AddItem(lv, 0.12)
	Debris:AddItem(att, 0.12)
end

local function sequence(i)
	local set = tool:GetAttribute("AnimSet")
	return (set and Anims:FindFirstChild(set .. "_Slash" .. i)) or Anims:WaitForChild("Slash" .. i)
end

local tracks, loadedFor = {}, nil
local busy, queued, step, lastEnd = false, false, 0, 0

local function loadTracks(char)
	if loadedFor == char then return end
	loadedFor = char
	local animator = char:WaitForChild("Humanoid"):WaitForChild("Animator")
	for i = 1, 4 do
		local anim = Instance.new("Animation")
		anim.AnimationId = KSP:RegisterKeyframeSequence(sequence(i))
		local tr = animator:LoadAnimation(anim)
		tr.Priority = Enum.AnimationPriority.Action4
		local hits = 0
		tr:GetMarkerReachedSignal("TrailOn"):Connect(function()
			setTrail(true)
			hits = 0
			slashArc(ARCS[i])
			lunge(LUNGE[i])
		end)
		tr:GetMarkerReachedSignal("Hit"):Connect(function()
			remote:FireServer(i)
			hits += 1
			if i == 3 and hits == 2 then slashArc(ARC3B) lunge(10) end
			impact(i == 4)
			shake(i == 4 and 0.9 or 0.35)
			-- hit-stop: animasi berhenti sekejap biar tebasan terasa berat
			tr:AdjustSpeed(0.05)
			task.delay(i == 4 and 0.08 or 0.045, function() tr:AdjustSpeed(1) end)
		end)
		tr:GetMarkerReachedSignal("TrailOff"):Connect(function() setTrail(false) end)
		tr.Stopped:Connect(function() setTrail(false) end)
		tracks[i] = tr
	end
end

tool.Equipped:Connect(function() loadTracks(tool.Parent) end)
tool.Unequipped:Connect(function()
	for _, tr in pairs(tracks) do tr:Stop() end
	setTrail(false)
	busy, queued = false, false
end)

local function blocked()
	return player:GetAttribute("Meditating") or player:GetAttribute("Flying") or player:GetAttribute("Casting")
end

local function attack()
	if not tracks[1] or blocked() then return end
	busy = true
	if os.clock() - lastEnd > 0.9 then step = 0 end
	step = step % 4 + 1
	local tr = tracks[step]
	tr:Play(0.08)
	-- boleh lanjut combo sedikit sebelum animasi selesai biar terasa responsif
	task.wait(math.max(tr.Length - (step == 4 and 0.22 or 0.2), 0.2))
	lastEnd = os.clock()
	busy = false
	if queued then
		queued = false
		attack()
	end
end

tool.Activated:Connect(function()
	if busy then
		queued = true
		return
	end
	attack()
end)
