-- Wujud iblis 梼杌 (client): tombol P / tombol layar, kamera mundur, animasi jalan procedural semua monster yang terlihat.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local plr = Players.LocalPlayer
local ev = RS:WaitForChild("QiRemotes"):WaitForChild("DemonForm")

-- ===== input
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.T and (plr:GetAttribute("Race") == "Demon" or plr:GetAttribute("DemonForm")) then ev:FireServer() end
end)
local gui = Instance.new("ScreenGui")
gui.Name = "DemonFormGui"
gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")
local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(104, 34)
btn.AnchorPoint = Vector2.new(1, 1)
btn.Position = UDim2.new(1, -14, 1, -168)
btn.BackgroundColor3 = Color3.fromRGB(70, 8, 16)
btn.BackgroundTransparency = 0.1
btn.TextColor3 = Color3.fromRGB(255, 200, 170)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 15
btn.Text = "Demon [T]"
btn.Parent = gui
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
local stroke = Instance.new("UIStroke", btn)
stroke.Color, stroke.Thickness = Color3.fromRGB(255, 60, 40), 1.5
btn.Activated:Connect(function() ev:FireServer() end)
local function refresh()
	btn.Visible = plr:GetAttribute("Race") == "Demon"
	btn.Text = plr:GetAttribute("DemonForm") and "Human [T]" or "Demon [T]"
end
plr:GetAttributeChangedSignal("Race"):Connect(refresh)
refresh()

-- ===== kamera: mundur & lebih tinggi saat jadi monster, bergetar saat berubah wujud
local saved
local camBase = Vector3.zero
local function shake(dur, amp)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if not hum then break end
			local k = 1 - (os.clock() - t0) / dur
			hum.CameraOffset = camBase + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * amp * k
			RunService.RenderStepped:Wait()
		end
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.CameraOffset = camBase end
	end)
end
plr:GetAttributeChangedSignal("DemonCharging"):Connect(function()
	if plr:GetAttribute("DemonCharging") then shake(1.4, 0.6) end
end)
plr:GetAttributeChangedSignal("DemonForm"):Connect(function()
	refresh()
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if plr:GetAttribute("DemonForm") then
		saved = saved or {plr.CameraMaxZoomDistance, plr.CameraMinZoomDistance}
		plr.CameraMaxZoomDistance = math.max(saved[1], 90)
		plr.CameraMinZoomDistance = 26
		task.delay(0.2, function() plr.CameraMinZoomDistance = saved and saved[2] or 0.5 end)
		camBase = Vector3.new(0, 7, 0)
		if hum then hum.CameraOffset = camBase end
		shake(0.8, 2.2)
	else
		if saved then plr.CameraMaxZoomDistance, plr.CameraMinZoomDistance = saved[1], saved[2] end
		saved = nil
		camBase = Vector3.zero
		if hum then hum.CameraOffset = camBase end
		shake(0.4, 1)
	end
end)

-- ===== animasi procedural: putar tulang terhadap sumbu dunia (sumbu kanan / atas monster)
local function parentWorld(b)
	local p = b.Parent
	return p:IsA("Bone") and p.TransformedWorldCFrame or p.CFrame
end
local function rot(b, axis, ang)
	if not b then return end
	local base = parentWorld(b) * b.CFrame
	b.Transform = CFrame.fromAxisAngle(base:VectorToObjectSpace(axis).Unit, ang)
end
local LEGS = {   -- {atas, tengah, bawah, fase}: trot -> diagonal sefase
	{"UpperArm_L", "Forearm_L", "Hand_L", 0, -1}, {"UpperArm_R", "Forearm_R", "Hand_R", math.pi, -1},
	{"Thigh_L", "Shin_L", "Foot_L", math.pi, 1}, {"Thigh_R", "Shin_R", "Foot_R", 0, 1},
}
local rigs = {}
local function track(m)
	task.spawn(function()
		local B = {}
		for _ = 1, 60 do
			for _, d in m:GetDescendants() do
				if d:IsA("Bone") then B[d.Name] = d end
			end
			if B.Head and B.Thigh_R then break end
			task.wait(0.5)
		end
		rigs[m] = {B = B, phase = 0, born = m:GetAttribute("Born") or workspace:GetServerTimeNow()}
	end)
end
for _, m in CS:GetTagged("DemonFormModel") do track(m) end
CS:GetInstanceAddedSignal("DemonFormModel"):Connect(track)
CS:GetInstanceRemovedSignal("DemonFormModel"):Connect(function(m) rigs[m] = nil end)

local t = 0
RunService:BindToRenderStep("DemonFormAnim", Enum.RenderPriority.Camera.Value, function(dt)
	t += dt
	local cam = workspace.CurrentCamera.CFrame.Position
	for m, r in rigs do
		if not m.Parent then rigs[m] = nil continue end
		local hrp = m.Parent:FindFirstChild("HumanoidRootPart")
		if not hrp or (hrp.Position - cam).Magnitude > 260 then continue end
		local B = r.B
		local v = hrp.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local k = math.clamp(speed / 22, 0, 1)
		r.phase += dt * (1.5 + speed * 0.32)
		local right, up = hrp.CFrame.RightVector, Vector3.yAxis
		local ph = r.phase
		local hum_ = m.Parent:FindFirstChildOfClass("Humanoid")
		local inAir = hum_ and hum_.FloorMaterial == Enum.Material.Air
		r.air = (r.air or 0) + ((inAir and 1 or 0) - (r.air or 0)) * math.min(1, dt * (inAir and 12 or 7))
		r.jf = (r.jf or 0) + (math.clamp(0.5 - v.Y / 50, 0, 1) - (r.jf or 0)) * math.min(1, dt * 6)
		if r.wasAir and not inAir then r.land = 1 end
		r.wasAir = inAir
		r.land = math.max(0, (r.land or 0) - dt * 3)
		local J = r.air                                               -- lompat: menerkam
		local rise = 1 - 2 * r.jf                                     -- +1 naik .. -1 turun (halus)
		local Ld = math.sin(r.land * math.pi)                         -- mendarat: meredam
		-- kemiringan badan ikut tanah (tangga / lereng): kaki depan & belakang menapak
		if not r.roots then
			r.roots = {}
			for _, d in m:GetDescendants() do
				if d:IsA("Bone") and not d.Parent:IsA("Bone") then table.insert(r.roots, d) end
			end
			local fl0 = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
			local hands = B.Hand_L and B.Hand_R and (B.Hand_L.WorldPosition + B.Hand_R.WorldPosition) / 2
			local feet = B.Foot_L and B.Foot_R and (B.Foot_L.WorldPosition + B.Foot_R.WorldPosition) / 2
			r.Lf = hands and math.max(1, (hands - hrp.Position):Dot(fl0)) or 5
			r.Lb = feet and math.max(1, -(feet - hrp.Position):Dot(fl0)) or 5
			r.rp = RaycastParams.new()
			r.rp.FilterDescendantsInstances = {m.Parent}
			r.pitch, r.dy = 0, 0
		end
		local look = hrp.CFrame.LookVector
		local fl = Vector3.new(look.X, 0, look.Z)
		fl = fl.Magnitude > 1e-3 and fl.Unit or Vector3.zAxis
		local y0 = hrp.Position.Y - hrp.Size.Y / 2 - (hum_ and hum_.HipHeight or 0)   -- tinggi telapak kalau datar
		local tp, tdy = 0, 0
		if not inAir then
			local function g(off)
				local h = workspace:Raycast(hrp.Position + fl * off + Vector3.new(0, 4, 0), Vector3.new(0, -16, 0), r.rp)
				return h and (h.Position.Y - y0) or 0
			end
			local df, db = g(r.Lf), g(-r.Lb)
			local tn = math.clamp((df - db) / (r.Lf + r.Lb), -0.75, 0.75)
			tp, tdy = math.atan(tn), math.clamp(df - r.Lf * tn, -4, 4)
		end
		local a = math.min(1, dt * 10)
		r.pitch += (tp - r.pitch) * a
		r.dy += (tdy - r.dy) * a
		local P = Vector3.new(hrp.Position.X, y0, hrp.Position.Z)
		local Rp = CFrame.new(0, r.dy, 0) * CFrame.new(P) * CFrame.fromAxisAngle(hrp.CFrame.RightVector, r.pitch) * CFrame.new(-P)
		for _, rb in r.roots do
			local base = parentWorld(rb) * rb.CFrame
			rb.Transform = base:Inverse() * Rp * base
		end
		-- napas & langkah: dada naik turun, tulang belakang bergelombang
		rot(B.Spine1, right, math.rad(1.5) * math.sin(ph * 2) * k)
		rot(B.Chest, right, math.rad(1.2) * math.sin(t * 1.6) + math.rad(2.5) * math.sin(ph * 2 + 0.6) * k + J * math.rad(12) * rise - math.rad(5) * Ld)
		rot(B.Neck1, right, math.rad(-1.5) * math.sin(t * 1.6 + 0.4) - math.rad(3) * math.sin(ph * 2 + 1.2) * k - J * math.rad(6) * rise)
		rot(B.Head, up, math.rad(6) * math.sin(t * 0.35) * (1 - k))
		-- rahang: auman saat baru berubah, lalu menggeram pelan
		local age = workspace:GetServerTimeNow() - r.born
		local roar = age < 1.6 and math.sin(math.min(1, age / 1.6) * math.pi) or 0
		rot(B.Jaw, right, math.rad(3 + 2 * math.sin(t * 0.9) + 24 * roar + 20 * J))
		for _, L in LEGS do
			local p = ph + L[4]
			local swing = math.sin(p)
			local lift = math.max(0, math.cos(p))
			local front = L[5] < 0
			local u_, m_, l_
			local f = r.jf * r.jf * (3 - 2 * r.jf)
			u_ = (front and 45 or -40) + ((front and 25 or 20) - (front and 45 or -40)) * f
			m_ = (front and 30 or 20) + ((front and 0 or 45) - (front and 30 or 20)) * f
			l_ = (front and 10 or 0) * f
			rot(B[L[1]], right, math.rad(26) * swing * k * (1 - J) + math.rad(u_) * J)
			rot(B[L[2]], right, L[5] * math.rad(38) * lift * k * (1 - J) + L[5] * math.rad(m_) * J + L[5] * math.rad(30) * Ld)
			rot(B[L[3]], right, -L[5] * math.rad(22) * lift * k * (1 - J) - L[5] * math.rad(l_) * J)
		end
	end
end)
