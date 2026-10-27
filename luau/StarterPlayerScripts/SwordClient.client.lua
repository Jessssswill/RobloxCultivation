-- Pedang Terbang (client): tombol T / tombol layar (khusus Celestial), lompatan ke pedang, menunggang pedang yang melayang
-- di ketinggian tetap (bergerak seperti kuda: W/A/S/D, bisa lompat seperti kuda & monster), pose berdiri ala xianxia
-- (tangan kanan segel jari di dada, tangan kiri di punggung), jejak cahaya saat melaju.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local remote = RS:WaitForChild("QiRemotes"):WaitForChild("FlyingSword")
local SPEED = 57            -- untuk pose (condong saat melaju); kecepatan sebenarnya dari CombatCore (+40, sama dengan kuda)

local function toggle() remote:FireServer() end
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.T and (player:GetAttribute("Race") == "Celestial" or player:GetAttribute("SwordRiding")) then
		toggle()
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SwordGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local btn = Instance.new("TextButton")
btn.Size, btn.Position, btn.AnchorPoint = UDim2.fromOffset(130, 44), UDim2.new(1, -16, 1, -96), Vector2.new(1, 1)
btn.BackgroundColor3, btn.BackgroundTransparency = Color3.fromRGB(18, 40, 90), 0.1
btn.TextColor3, btn.Font, btn.TextSize = Color3.fromRGB(215, 235, 255), Enum.Font.GothamBold, 16
btn.Parent = gui
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", btn)
stroke.Color, stroke.Thickness = Color3.fromRGB(140, 200, 255), 1.5
btn.Activated:Connect(toggle)
local function refresh()
	local riding = player:GetAttribute("SwordRiding") == true
	btn.Visible = riding or player:GetAttribute("Race") == "Celestial"
	btn.Text = riding and "🗡 Dismount [T]" or "🗡 Sword [T]"
end
player:GetAttributeChangedSignal("Race"):Connect(refresh)
refresh()

-- ===== lompatan ke atas pedang (dikirim server)
remote.OnClientEvent:Connect(function(kind, target, dur)
	if kind ~= "board" then return end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local start = hrp.CFrame
	local t0 = os.clock()
	while os.clock() - t0 < dur do
		local a = (os.clock() - t0) / dur
		local e = a * a * (3 - 2 * a)
		local p = start.Position:Lerp(target.Position, e) + Vector3.new(0, 4.5 * math.sin(math.pi * a), 0)
		hrp.CFrame = CFrame.new(p) * start.Rotation:Lerp(target.Rotation, e)
		hrp.AssemblyLinearVelocity = Vector3.zero
		RunService.RenderStepped:Wait()
	end
	hrp.CFrame = target
end)

-- ===== menunggang (pemain sendiri): animasi bawaan dimatikan (pose prosedural di bawah), lompat tetap boleh
local riding = false
local function setRide(on)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or riding == on then return end
	riding = on
	local animate = char:FindFirstChild("Animate")
	if animate then animate.Disabled = on end
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	if on then
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then for _, tr in animator:GetPlayingAnimationTracks() do tr:Stop(0.15) end end
	else
		for _, d in char:GetDescendants() do
			if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then pcall(function() d.Transform = CFrame.identity end) end
		end
	end
end
player:GetAttributeChangedSignal("SwordRiding"):Connect(function()
	refresh()
	setRide(player:GetAttribute("SwordRiding") == true)
end)
player.CharacterAdded:Connect(function() riding = false refresh() end)

-- ===== jejak cahaya pedang (semua pedang yang sedang dikendarai)
RunService.Heartbeat:Connect(function()
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and m.Name:match("^Sword_") and m.PrimaryPart then
			local v = m.PrimaryPart.AssemblyLinearVelocity.Magnitude
			local riding = m:GetAttribute("Rider") ~= nil
			for _, d in m:GetDescendants() do
				if d:IsA("Trail") then d.Enabled = (not riding) or v > 12 end
				if d:IsA("ParticleEmitter") and d.Name == "TipSpark" then d.Rate = riding and (v > 12 and 40 or 6) or 30 end
			end
		end
	end
end)

-- ===== pedang miring mengikuti lereng/tangga (semua pengendara): tinggi tanah di depan & belakang titik pijak diukur,
-- pedang diputar pada titik pijak (kaki tetap di tempat) supaya ujung & gagang tidak menembus anak tangga
local tiltRP = RaycastParams.new()
tiltRP.FilterType = Enum.RaycastFilterType.Exclude
local tilt = {}
RunService.Heartbeat:Connect(function(dt)
	local ex = {}
	for _, pl in Players:GetPlayers() do if pl.Character then table.insert(ex, pl.Character) end end
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and m.Name:match("^Sword_") then table.insert(ex, m) end
	end
	tiltRP.FilterDescendantsInstances = ex
	for w, T in tilt do
		if not w.Parent then tilt[w] = nil end
	end
	for _, m in workspace:GetChildren() do
		local rp = m:IsA("Model") and m.Name:match("^Sword_") and m:GetAttribute("Rider") and m.PrimaryPart
		local w = rp and rp:FindFirstChild("RiderWeld")
		local rel = rp and m:GetAttribute("StandRel")
		if w and w:IsA("Weld") and rel then
			local T = tilt[w]
			if not T then
				T = {base = w.C0, pitch = 0}
				tilt[w] = T
			end
			local stand = rp.CFrame * rel                                  -- bingkai titik pijak (maju = ke ujung pedang)
			local fwd = Vector3.new(stand.LookVector.X, 0, stand.LookVector.Z)
			fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.zAxis
			local c = stand.Position
			local hf = workspace:Raycast(c + fwd * 6 + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), tiltRP)
			local hb = workspace:Raycast(c - fwd * 6 + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), tiltRP)
			local target = 0
			if hf and hb then target = math.clamp(math.atan2(hf.Position.Y - hb.Position.Y, 12), -0.6, 0.6) end
			-- lompat: pedang melambung, ujung terangkat saat naik & menukik saat turun
			local uid = m:GetAttribute("Rider")
			local pl = uid and Players:GetPlayerByUserId(uid)
			local hum = pl and pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
			local inAir = hum and hum.FloorMaterial == Enum.Material.Air
			T.air = (T.air or 0) + ((inAir and 1 or 0) - (T.air or 0)) * math.min(1, dt * (inAir and 12 or 5))
			local vy = rp.AssemblyLinearVelocity.Y
			T.jf = (T.jf or 0) + (math.clamp(0.5 - vy / 50, 0, 1) - (T.jf or 0)) * math.min(1, dt * 6)   -- 0 naik .. 1 turun
			target += T.air * (0.2 - 0.32 * T.jf)                          -- naik: ujung terangkat; turun: menukik pelan
			T.pitch += (target - T.pitch) * math.min(1, dt * 8)
			local P = T.base * rel                                         -- titik pijak dalam ruang HumanoidRootPart
			w.C0 = P * CFrame.Angles(T.pitch, 0, 0) * P:Inverse() * T.base
		end
	end
end)

-- ===== pose: segel jari saat memanggil, berdiri gagah di atas pedang saat terbang (semua pemain yang terlihat)
local JOINTS = {Waist = "UpperTorso", Neck = "Head", LeftHip = "LeftUpperLeg", RightHip = "RightUpperLeg", LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg", LeftAnkle = "LeftFoot", RightAnkle = "RightFoot", LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm", LeftElbow = "LeftLowerArm", RightElbow = "RightLowerArm", LeftWrist = "LeftHand", RightWrist = "RightHand"}
local function joint(ch, n)
	local part = ch:FindFirstChild(JOINTS[n])
	local j = part and part:FindFirstChild(n)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then return j end
end
local A_ = CFrame.Angles
local airJ = {}
RunService.PreSimulation:Connect(function()
	for _, pl in Players:GetPlayers() do
		local ch = pl.Character
		if ch and ch:FindFirstChild("UpperTorso") then
			local pose
			if pl:GetAttribute("SwordRiding") then
				local hrp = ch:FindFirstChild("HumanoidRootPart")
				local v = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
				local sp = math.clamp(v.Magnitude / SPEED, 0, 1)
				local tt = os.clock()
				local sway = 0.03 * math.sin(tt * 1.8)
				local hum = ch:FindFirstChildOfClass("Humanoid")
				local air = hum and hum.FloorMaterial == Enum.Material.Air
				local st = airJ[pl] or {a = 0, land = 0, t = os.clock(), was = false}
				airJ[pl] = st
				local now = os.clock()
				local dtp = math.min(0.1, now - st.t)
				st.t = now
				st.a += ((air and 1 or 0) - st.a) * math.min(1, dtp * (air and 12 or 6))
				if st.was and not air then st.land = 1 end
				st.was = air
				st.land = math.max(0, st.land - dtp * 3)
				local J = st.a * 0.7 + math.sin(st.land * math.pi) * 0.6     -- udara: lutut ditekuk; mendarat: meredam
				pose = {
					Waist = A_(-0.08 * sp + sway, 0.25, 0), Neck = A_(0.05, -0.25, 0),
					-- kuda-kuda: kaki kiri di depan, kanan di belakang, lutut sedikit ditekuk (menyerap goyangan pedang)
					LeftHip = A_(0.35 + 0.1 * sp + 0.45 * J, 0, -0.12), RightHip = A_(-0.3 + 0.35 * J, 0, 0.12),
					LeftKnee = A_(-0.35 - 0.7 * J, 0, 0), RightKnee = A_(-0.25 - 0.7 * J, 0, 0),
					LeftAnkle = A_(0.05, 0, 0), RightAnkle = A_(0.15, 0, 0),
					-- tangan kanan segel jari di depan dada, tangan kiri di punggung
					RightShoulder = A_(1.15, 0, -0.85), RightElbow = A_(1.5, 0, 0), RightWrist = A_(0.35, 0, 0),
					LeftShoulder = A_(-0.45, 0, 0.35), LeftElbow = A_(0.9, 0, 0), LeftWrist = A_(0.2, 0, 0),
				}
			elseif pl:GetAttribute("SwordCalling") then
				pose = {RightShoulder = A_(2.6, 0, -0.25), RightElbow = A_(0.35, 0, 0), RightWrist = A_(0.3, 0, 0),
					LeftShoulder = A_(-0.35, 0, 0.3), LeftElbow = A_(0.8, 0, 0)}
			end
			if pose then
				for n, cf in pose do
					local j = joint(ch, n)
					if j then j.Transform = cf end
				end
			end
		end
	end
end)
