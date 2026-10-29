-- Kuda Langit (client): tombol H / tombol layar, pose duduk penunggang, animasi lari kuda dari tulang
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local remote = RS:WaitForChild("QiRemotes"):WaitForChild("Steed")

local function toggle() remote:FireServer() end
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.T and (player:GetAttribute("Race") == "Mortal" or player:GetAttribute("Mounted")) then toggle() end
end)

-- tombol layar (HP & PC)
local gui = Instance.new("ScreenGui")
gui.Name = "SteedGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local btn = Instance.new("TextButton")
btn.Size, btn.Position, btn.AnchorPoint = UDim2.fromOffset(120, 44), UDim2.new(1, -16, 1, -96), Vector2.new(1, 1)
btn.BackgroundColor3, btn.BackgroundTransparency = Color3.fromRGB(110, 14, 18), 0.1
btn.TextColor3, btn.Font, btn.TextSize = Color3.fromRGB(255, 225, 160), Enum.Font.GothamBold, 16
btn.Text = "🐎 Horse [T]"
btn.Parent = gui
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", btn)
stroke.Color, stroke.Thickness = Color3.fromRGB(214, 168, 80), 1.5
btn.Activated:Connect(toggle)

-- pose duduk penunggang
local sitTrack
local function updateSit()
	local mounted = player:GetAttribute("Mounted") == true
	btn.Text = mounted and "🐎 Dismount [T]" or "🐎 Horse [T]"
	btn.Visible = mounted or player:GetAttribute("Race") == "Mortal"   -- kuda khusus ras Mortal
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	-- pose menunggang dibuat prosedural (lihat RIDE di bawah): animasi bawaan dimatikan selama naik kuda
	local animate = char and char:FindFirstChild("Animate")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if mounted and hum and not sitTrack then
		sitTrack = true
		if animate then animate.Disabled = true end
		if animator then for _, tr in animator:GetPlayingAnimationTracks() do tr:Stop(0.15) end end
	elseif not mounted and sitTrack then
		sitTrack = nil
		if animate then animate.Disabled = false end
		for _, d in (char and char:GetDescendants() or {}) do
			if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then pcall(function() d.Transform = CFrame.identity end) end
		end
	end
end
player:GetAttributeChangedSignal("Mounted"):Connect(updateSit)
player:GetAttributeChangedSignal("Race"):Connect(updateSit)
task.defer(updateSit)
player.CharacterAdded:Connect(function() sitTrack = nil task.wait(0.5) updateSit() end)

-- animasi lari kuda (semua kuda di workspace yang punya atribut Rider)
local LEGS = {"FL1", "FR1", "HL1", "HR1"}
local OFFS = {FL1 = 0, FR1 = 0.45, HL1 = math.pi, HR1 = math.pi + 0.45}
local rigs = {}
local function setup(m)
	if rigs[m] then return end
	local rp = m:FindFirstChild("RootPart")
	if not rp then return end
	local B = {}
	for _, n in {"Body", "Neck", "Head", "Tail", "FL1", "FL2", "FR1", "FR2", "HL1", "HL2", "HR1", "HR2"} do
		B[n] = rp:FindFirstChild(n, true)
		if not B[n] then return end
		B[n].Transform = CFrame.identity
	end
	for _, n in {"Mane1", "Mane2", "Mane3", "Mane4", "Tail2", "Tail3", "Fore", "ClothL", "ClothR"} do   -- tulang rambut & kain (opsional, v4+/v5)
		B[n] = rp:FindFirstChild(n, true)
		if B[n] then B[n].Transform = CFrame.identity end
	end
	local pc = rp.CFrame
	local fwd = B.Neck.WorldPosition - B.Body.WorldPosition
	fwd = Vector3.new(fwd.X, 0, fwd.Z).Unit
	local right = fwd:Cross(Vector3.yAxis).Unit
	local axis, up, fax = {}, {}, {}
	for n, b in B do
		local rel = pc:ToObjectSpace(b.WorldCFrame)
		axis[n] = rel:VectorToObjectSpace(pc:VectorToObjectSpace(right)).Unit
		fax[n] = rel:VectorToObjectSpace(pc:VectorToObjectSpace(fwd)).Unit
		up[n] = rel:VectorToObjectSpace(pc:VectorToObjectSpace(Vector3.yAxis)).Unit
	end
	-- arah putar: sudut positif = kaki mengayun ke depan
	local sgn = CFrame.fromAxisAngle(right, 0.3):VectorToWorldSpace(-Vector3.yAxis):Dot(fwd) > 0 and 1 or -1
	local tdir = (-fwd - Vector3.yAxis).Unit
	local tsg = CFrame.fromAxisAngle(right, 0.3):VectorToWorldSpace(tdir).Y > tdir.Y and 1 or -1
	local dust = rp:FindFirstChild("HoofDust") and rp.HoofDust:FindFirstChild("Dust")
	local root = rp:FindFirstChild("Root")
	local saddle = {}
	for _, p in m:GetDescendants() do
		if p:IsA("MeshPart") and (p.Name:match("^Tack") or p.Name:match("^Cloth")) then p.CanQuery = true table.insert(saddle, p) end
	end
	local seatRP = RaycastParams.new()
	seatRP.FilterType = Enum.RaycastFilterType.Include
	seatRP.FilterDescendantsInstances = saddle
	rigs[m] = {seatRP = seatRP, seat = 0,rp = rp, B = B, axis = axis, up = up, fax = fax, sgn = sgn, tsg = tsg, ph = 0, amp = 0, t = 0, dust = dust,
		root = root, raxis = root and root.WorldCFrame:VectorToObjectSpace(right).Unit, fwdL = pc:VectorToObjectSpace(fwd),
		half = (B.FL1.WorldPosition - B.HL1.WorldPosition).Magnitude / 2, pitch = 0}
end
local function scan()
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and (m:GetAttribute("Rider") or m:GetAttribute("Summoner")) then task.spawn(setup, m) end
	end
end
workspace.ChildAdded:Connect(function(c)
	if c:IsA("Model") then task.delay(0.3, function() if c:GetAttribute("Rider") or c:GetAttribute("Summoner") then setup(c) end end) end
end)
scan()

local pitchRP = RaycastParams.new()
pitchRP.FilterType = Enum.RaycastFilterType.Exclude
RunService.RenderStepped:Connect(function(dt)
	local chars = {}
	for _, pl in Players:GetPlayers() do if pl.Character then table.insert(chars, pl.Character) end end
	for m, R in rigs do
		if not m.Parent or not (m:GetAttribute("Rider") or m:GetAttribute("Summoner")) then
			if R.motor and R.c0 then R.motor.set(R.c0) end   -- turun kuda: pose penunggang dikembalikan
			rigs[m] = nil
			continue
		end
		local v = R.rp.AssemblyLinearVelocity
		local speed = m:GetAttribute("AnimSpeed") or Vector3.new(v.X, 0, v.Z).Magnitude   -- kuda datang (anchored): kecepatan dari server
		R.t += dt
		R.amp += (math.clamp(speed / 36, 0, 1) - R.amp) * math.min(1, dt * 6)
		local A, s = R.amp, R.sgn
			do   -- lompat: penunggang di udara -> pose lompat kuda (kaki depan terlipat, belakang menendang; turun: kaki depan menjulur)
				local uid_ = m:GetAttribute("Rider")
				local pl_ = uid_ and Players:GetPlayerByUserId(uid_)
				local hum_ = pl_ and pl_.Character and pl_.Character:FindFirstChildOfClass("Humanoid")
				local inAir = hum_ and hum_.FloorMaterial == Enum.Material.Air
				R.air = (R.air or 0) + ((inAir and 1 or 0) - (R.air or 0)) * math.min(1, dt * (inAir and 12 or 7))
				R.vy = R.rp.AssemblyLinearVelocity.Y
				R.jf = (R.jf or 0) + (math.clamp(0.5 - R.vy / 50, 0, 1) - (R.jf or 0)) * math.min(1, dt * 6)   -- 0 naik .. 1 turun
				if R.wasAir and not inAir then R.land = 1 end
				R.wasAir = inAir
				R.land = math.max(0, (R.land or 0) - dt * 3)
			end
		local ph = R.ph
		local function rot(n, ang) R.B[n].Transform = CFrame.fromAxisAngle(R.axis[n], ang) end
		-- surai & ekor ikut bergerak: ditiup ke belakang saat lari + gelombang mengikuti langkah + angin pelan saat diam
		local function rot2(n, a1, a2)
			if R.B[n] and R.axis[n] and R.fax[n] then
				R.B[n].Transform = CFrame.fromAxisAngle(R.axis[n], a1) * CFrame.fromAxisAngle(R.fax[n], a2)
			end
		end
-- [fisika] 		for k = 1, 4 do
-- [fisika] 			local n = "Mane" .. k
-- [fisika] 			local wave = math.sin(R.t * (2.2 + 6 * A) + k * 0.9) * (0.06 + 0.22 * A)
-- [fisika] 			local flap = math.sin(2 * ph + k * 0.7) * 0.12 * A
-- [fisika] 			rot2(n, -s * (0.55 * A + 0.04) + s * (wave + flap), 0.05 * math.sin(R.t * 1.7 + k) + 0.18 * A * math.sin(R.t * 3 + k))
-- [fisika] 		end
-- [fisika] 		rot2("Fore", -s * (0.4 * A) + s * 0.08 * math.sin(R.t * 2.5), 0.06 * math.sin(R.t * 1.9))
-- [fisika] 		for k, n in {"Tail2", "Tail3"} do
-- [fisika] 			rot2(n, R.tsg * (0.25 * A * k + 0.06 * math.sin(R.t * 2.2 - k * 0.8)) + 0.18 * A * math.sin(2 * ph - k * 0.9),
-- [fisika] 				(0.08 + 0.2 * A) * math.sin(R.t * 2.6 - k * 1.1))
-- [fisika] 		end
		-- gaya jalan: jalan (4 ketukan) -> derap (diagonal) -> gallop (FR memimpin), dicampur halus menurut kecepatan
		local G = math.clamp((speed - 26) / 10, 0, 1)
		local T = math.clamp((speed - 9) / 8, 0, 1) * (1 - G)
		local Wk = (1 - G - T) * math.clamp(speed / 3, 0, 1)
		R.ph += dt * 2 * math.pi * (Wk * 0.95 + T * 1.45 + G * 2.05)
		ph = R.ph
		local GAITS = {
			{Wk, 0.3, 0.7, {HL1 = 0, FL1 = 0.25, HR1 = 0.5, FR1 = 0.75}},
			{T, 0.48, 1.05, {FL1 = 0, HR1 = 0, FR1 = 0.5, HL1 = 0.5}},
			{G, 0.8, 1.35, {HL1 = 0, HR1 = 0.1, FL1 = 0.42, FR1 = 0.55}},
		}
		for _, n in LEGS do
			local up_, low_ = 0, 0
			for _, gt in GAITS do
				if gt[1] > 0 then
					local p = ph + gt[4][n] * 2 * math.pi
					up_ += gt[1] * gt[2] * math.sin(p)
					low_ += gt[1] * gt[3] * math.max(0, math.sin(p + 1.3)) ^ 1.5
				end
			end
			local front = n:sub(1, 1) == "F"
				local J = R.air or 0
				local ju, jl
				local f = R.jf or 0
				f = f * f * (3 - 2 * f)                                       -- naik -> turun berbaur halus
				ju = front and (0.75 - 0.4 * f) or (-0.55 + 0.9 * f)
				jl = front and (1.35 - 1.15 * f) or (0.45 + 0.35 * f)
				local Ld = math.sin((R.land or 0) * math.pi)                  -- mendarat: kaki menekuk meredam
				rot(n, s * (up_ * (1 - J) + ju * J))
			rot(n:sub(1, 2) .. "2", -s * ((front and 1 or 0.75) * low_ * (1 - J) + jl * J + Ld * (front and 0.35 or 0.5)))
		end
		-- badan: napas saat diam, ayun naik-turun saat derap, mengayun (rocking) saat gallop
		local breathe = 0.04 * math.sin(R.t * 1.4)
		local bob = Wk * 0.08 * math.abs(math.sin(2 * ph)) + T * 0.28 * math.abs(math.sin(2 * ph)) + G * 0.45 * (0.5 + 0.5 * math.sin(ph - 0.6)) + breathe
		local rock = G * 0.1 * math.sin(ph + 0.3) + T * 0.025 * math.sin(2 * ph)
		R.B.Body.Transform = CFrame.new(R.up.Body * (bob - math.sin((R.land or 0) * math.pi) * 0.35)) * CFrame.fromAxisAngle(R.axis.Body, rock)
		R.bob, R.rock, R.Wk, R.T, R.G, R.ph2 = bob, rock, Wk, T, G, ph
		-- kain pelana berayun keluar-masuk mengikuti langkah, sedikit maju-mundur, tiupan pelan saat diam
		local sway = 0.05 + 0.2 * T * math.abs(math.sin(2 * ph)) + 0.26 * G * (0.5 + 0.5 * math.sin(ph + 0.8)) + 0.025 * math.sin(R.t * 1.6)
		local fa = 0.06 * A * math.sin(ph + 1.0)
		rot2("ClothL", fa, sway)
		rot2("ClothR", fa, -sway)
		rot("Neck", s * (-(R.air or 0) * 0.22 * (1 - 2 * (R.jf or 0)) + math.sin((R.land or 0) * math.pi) * 0.12 - rock * 1.4 + Wk * 0.07 * math.sin(2 * ph + 0.5) + T * 0.05 * math.sin(2 * ph) + 0.03 * math.sin(R.t * 0.9)))
		rot("Head", s * (Wk * 0.05 * math.sin(2 * ph + 1.2) + G * 0.08 * math.sin(ph + 1.4) + 0.02 * math.sin(R.t * 0.7)))
-- [fisika] 		rot("Tail", R.tsg * ((0.25 * T + 0.55 * G) + 0.08 * math.sin(R.t * 2.2)) + 0.12 * A * math.sin(2 * ph))
		if R.dust then R.dust.Rate = speed > 18 and 30 or 0 end
		-- badan kuda miring mengikuti lereng/tangga (kuku depan & belakang sama-sama menapak)
		if R.root and R.raxis then
			local ex = table.clone(chars)
			table.insert(ex, m)
			pitchRP.FilterDescendantsInstances = ex
			local f = R.rp.CFrame:VectorToWorldSpace(R.fwdL)
			local c = R.root.WorldPosition
			local hf = workspace:Raycast(c + f * R.half + Vector3.new(0, 7, 0), Vector3.new(0, -26, 0), pitchRP)
			local hb = workspace:Raycast(c - f * R.half + Vector3.new(0, 7, 0), Vector3.new(0, -26, 0), pitchRP)
			local tgt = 0
			if hf and hb then tgt = math.clamp(math.atan2(hb.Position.Y - hf.Position.Y, 2 * R.half), -0.55, 0.55) end
			R.pitch += (tgt - R.pitch) * math.min(1, dt * 7)
			R.root.Transform = CFrame.fromAxisAngle(R.raxis, -R.pitch)
		end
		-- penunggang ikut miring (lereng/tangga) & ikut ayunan badan kuda: geser C0 sendi akar karakter (lokal, visual)
		local uid = m:GetAttribute("Rider")
		local rpl = uid and Players:GetPlayerByUserId(uid)
		local rc = rpl and rpl.Character
		local hrp = rc and rc:FindFirstChild("HumanoidRootPart")
		-- sendi akar: Motor6D (C0) atau AnimationConstraint baru (attachment di HumanoidRootPart, setara C0)
		local joint = rc and ((rc:FindFirstChild("LowerTorso") and rc.LowerTorso:FindFirstChild("Root")) or (hrp and hrp:FindFirstChild("RootJoint")))
		local motor
		if joint and joint:IsA("Motor6D") then
			motor = {get = function() return joint.C0 end, set = function(cf) joint.C0 = cf end, id = joint}
		elseif joint and joint:IsA("AnimationConstraint") then
			local att = (joint.Attachment0 and joint.Attachment0.Parent == hrp) and joint.Attachment0 or joint.Attachment1
			if att and att.Parent == hrp then
				motor = {get = function() return att.CFrame end, set = function(cf) att.CFrame = cf end, id = att}
			end
		end
		if motor and hrp and R.root then
			if not R.motor or R.motor.id ~= motor.id then
				if R.motor and R.c0 then R.motor.set(R.c0) end
				R.motor, R.c0 = motor, motor.get()
			end
			local f = R.rp.CFrame:VectorToWorldSpace(R.fwdL)
			local right = f:Cross(Vector3.yAxis).Unit
			local pg = R.root.WorldPosition
			local pb = R.B.Body.WorldPosition
			local Xw = CFrame.new(pg) * CFrame.fromAxisAngle(right, -(R.pitch or 0)) * CFrame.new(-pg)
				* CFrame.new(pb) * CFrame.fromAxisAngle(right, R.rock or 0) * CFrame.new(-pb) * CFrame.new(0, R.bob or 0, 0)
			local hc = hrp.CFrame
			-- tinggi duduk: panggul menempel permukaan pelana (raycast lokal ke pelana kuda)
			local lt = rc:FindFirstChild("LowerTorso")
			-- sinar dimulai dari panggul (bukan dari atas kepala) supaya tidak mengenai tali kendali / ujung pelana
			-- saat kuda menunduk; hanya permukaan yang menghadap ke atas yang dianggap dudukan
			if lt then
				local bottom = lt.Position - Vector3.new(0, lt.Size.Y * 0.5, 0)
				local hit = workspace:Raycast(bottom + Vector3.new(0, 1.2, 0), Vector3.new(0, -9, 0), R.seatRP)
				if hit and hit.Normal.Y > 0.55 then
					local err = (hit.Position.Y + 0.1) - bottom.Y
					R.seat = math.clamp(R.seat + err * 0.35, -4, 3)
				end
			end
			R.motor.set((hc:Inverse() * Xw * hc) * CFrame.new(0, R.seat, 0) * R.c0)
		end
	end
end)

-- ===== RIDE: pose penunggang (duduk mengapit pelana, tangan memegang kendali & mengarahkan kuda)
-- ditulis di PreSimulation (setelah animator) supaya menimpa animasi bawaan, untuk semua penunggang yang terlihat
local JOINTS = {Waist = "UpperTorso", Neck = "Head", LeftHip = "LeftUpperLeg", RightHip = "RightUpperLeg", LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg", LeftAnkle = "LeftFoot", RightAnkle = "RightFoot", LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm", LeftElbow = "LeftLowerArm", RightElbow = "RightLowerArm", LeftWrist = "LeftHand", RightWrist = "RightHand"}
local function joint(ch, n)
	local part = ch:FindFirstChild(JOINTS[n])
	local j = part and part:FindFirstChild(n)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then return j end
end
local A_ = CFrame.Angles
RunService.PreSimulation:Connect(function()
	for m, R in rigs do
		local uid = m.Parent and m:GetAttribute("Rider")
		local rpl = uid and Players:GetPlayerByUserId(uid)
		local ch = rpl and rpl.Character
		if ch and ch:FindFirstChild("UpperTorso") then
			local Wk, T, G, ph = R.Wk or 0, R.T or 0, R.G or 0, R.ph2 or 0
			local yaw = R.rp.AssemblyAngularVelocity.Y
			R.steer = (R.steer or 0) + (math.clamp(yaw / 2.2, -1, 1) - (R.steer or 0)) * 0.15
			local st = R.steer
			local lean = -(0.1 + 0.05 * T + 0.16 * G) + (R.rock or 0) * 0.9
			local hands = 0.06 * Wk * math.sin(2 * ph + 0.4) + 0.08 * T * math.sin(2 * ph) + 0.16 * G * math.sin(ph + 1.2)
			local pose = {
				Waist = A_(lean, 0.12 * st, 0), Neck = A_(-lean * 0.6, 0.15 * st, 0),
				-- kaki mengangkang di atas pelana, betis menggantung memeluk sisi badan kuda (diukur: telapak di +-1.77 stud)
				LeftHip = A_(0.4, 0, -1.6), RightHip = A_(0.4, 0, 1.6),
				LeftKnee = A_(-0.5 - 0.15 * G * math.sin(ph), 0, 1.25), RightKnee = A_(-0.5 - 0.15 * G * math.sin(ph), 0, -1.25),
				LeftAnkle = A_(0.3, 0, 0.15), RightAnkle = A_(0.3, 0, -0.15),
				-- kedua tangan di depan perut memegang tali kendali (+-0.64 stud dari tengah); ikut ritme kepala kuda;
				-- belok: tali sisi itu ditarik ke belakang (bahu turun, siku menekuk), tangan lain mengendur ke depan
				LeftShoulder = A_(0.8 + hands - 0.5 * math.max(0, -st) + 0.2 * math.max(0, st), 0, 0.9),
				RightShoulder = A_(0.8 + hands - 0.5 * math.max(0, st) + 0.2 * math.max(0, -st), 0, -0.9),
				LeftElbow = A_(0.55 + 0.6 * math.max(0, -st), 0, 0), RightElbow = A_(0.55 + 0.6 * math.max(0, st), 0, 0),
				LeftWrist = A_(0.2, 0, 0), RightWrist = A_(0.2, 0, 0),
			}
			-- memegang senjata: tangan kiri sendiri memegang kendali di tengah, tangan kanan pose menyerbu
			-- (pedang menunjuk ke depan-atas, ikut ayunan gallop); saat menyerang, animasi tebasan tidak ditimpa
			if ch:FindFirstChildOfClass("Tool") then
				pose.LeftShoulder = A_(0.8 + hands - 0.4 * math.max(0, -st) + 0.15 * math.max(0, st), 0, 1.25)
				pose.LeftElbow = A_(0.55 + 0.5 * math.max(0, -st), 0, 0)
				local hum_ = ch:FindFirstChildOfClass("Humanoid")
				local anim_ = hum_ and hum_:FindFirstChildOfClass("Animator")
				local attacking = false
				if anim_ then
					for _, tr in anim_:GetPlayingAnimationTracks() do
						if not tr.Looped and tr.Priority.Value >= Enum.AnimationPriority.Action.Value then attacking = true break end
					end
				end
				if attacking then
					pose.RightShoulder, pose.RightElbow, pose.RightWrist = nil, nil, nil
				else
					local bob = 0.05 * T * math.sin(2 * ph) + 0.1 * G * math.sin(ph + 0.9) + 0.03 * math.sin((R.t or 0) * 1.3)
					pose.RightShoulder = A_(0.55 + 0.15 * G + bob, 0, 0.55 + 0.1 * math.max(0, -st))
					pose.RightElbow = A_(0.45 - 0.1 * G, 0, 0)
					pose.RightWrist = A_(1.3 - 0.5 * bob, 0, 0)
				end
			end
			local tune = workspace:GetAttribute("RideTune")   -- uji: "Joint=x,y,z;..." menimpa pose
			if tune then
				for n, x, y, z in tune:gmatch("(%a+)=([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do pose[n] = A_(tonumber(x), tonumber(y), tonumber(z)) end
			end
			for n, cf in pose do
				local j = joint(ch, n)
				if j then j.Transform = cf end
			end
		end
	end
end)
-- ===== panggil kuda: lompatan ke pelana (dikirim server) & pose tangan terangkat saat memanggil
remote.OnClientEvent:Connect(function(kind, target, dur)
	if kind ~= "leap" then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local start = hrp.CFrame
	local t0 = os.clock()
	while os.clock() - t0 < dur do
		local a = (os.clock() - t0) / dur
		local e = a * a * (3 - 2 * a)
		local p = start.Position:Lerp(target.Position, e) + Vector3.new(0, 5 * math.sin(math.pi * a), 0)
		hrp.CFrame = CFrame.new(p) * start.Rotation:Lerp(target.Rotation, e)
		hrp.AssemblyLinearVelocity = Vector3.zero
		RunService.RenderStepped:Wait()
	end
	hrp.CFrame = target
end)
RunService.PreSimulation:Connect(function()
	for _, pl in Players:GetPlayers() do
		local ch = pl.Character
		if ch and pl:GetAttribute("SteedCalling") and not pl:GetAttribute("Mounted") then
			local s = joint(ch, "RightShoulder")
			if s then s.Transform = A_(2.7, 0, -0.2) end
			local e = joint(ch, "RightElbow")
			if e then e.Transform = A_(0.35, 0, 0) end
		end
	end
end)
