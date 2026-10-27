-- MonsterAI generik: perilaku diatur lewat attribute (Damage, Attacks, Cooldown, dll).
-- Semua serangan punya telegraph merah dulu, jadi pemain sempat dash / parry / block.
local m = script.Parent
local hum = m:WaitForChild("Humanoid")
local root = m:WaitForChild("HumanoidRootPart")
local Players = game:GetService("Players")
local RunS = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Core = require(game:GetService("ServerScriptService"):WaitForChild("CombatCore"))
local Fx = RS:WaitForChild("QiRemotes"):WaitForChild("Fx")
pcall(function() root:SetNetworkOwner(nil) end)
local function A(x, y, z) return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0)) end
local function at(n) return m:GetAttribute(n) end
local RED = Color3.fromRGB(255, 50, 50)
local home = root.Position
local kind = at("Kind")

-- ===== pose sendi (Motor6D buat beast, AnimationConstraint buat rig R15) =====
local NAMES = kind == "beast" and {"Neck", "Hip1", "Hip2", "Hip3", "Hip4", "Tail"} or {"RightShoulder", "LeftShoulder", "Waist"}
local joints, base, cur, goal = {}, {}, {}, {}
for _, d in m:GetDescendants() do
	if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and table.find(NAMES, d.Name) then joints[d.Name] = d end
end
local function getC(j) if j:IsA("Motor6D") then return j.C0 end return j.Attachment0.CFrame end
local function setC(j, cf) if j:IsA("Motor6D") then j.C0 = cf else j.Attachment0.CFrame = cf end end
for n, j in joints do
	base[n] = getC(j)
	cur[n] = CFrame.new()
	goal[n] = CFrame.new()
end
local POSES = kind == "beast" and {
	Windup = {Neck = A(25), Hip1 = A(45), Hip2 = A(45)},
	Strike = {Neck = A(-30), Hip1 = A(-20), Hip2 = A(-20)},
	Rear = {Neck = A(30), Hip1 = A(75), Hip2 = A(75), Hip3 = A(-15), Hip4 = A(-15)},
	Slam = {Neck = A(-25), Hip1 = A(-25), Hip2 = A(-25)},
	Low = {Neck = A(-25), Hip3 = A(25), Hip4 = A(25)},
	Stun = {Neck = A(-30, 0, 18)},
	Roar = {Neck = A(45)},
} or {
	Windup = {RightShoulder = A(150), Waist = A(0, 30)},
	Strike = {RightShoulder = A(-40), Waist = A(0, -30)},
	Rear = {RightShoulder = A(165), LeftShoulder = A(165), Waist = A(-10)},
	Slam = {RightShoulder = A(-30), LeftShoulder = A(-30), Waist = A(25)},
	Low = {RightShoulder = A(-20), LeftShoulder = A(-20), Waist = A(30)},
	Stun = {Waist = A(-15, 0, 10)},
	Roar = {RightShoulder = A(120, 0, -30), LeftShoulder = A(120, 0, 30), Waist = A(-20)},
}
local poseSpeed = 14
local function pose(name, speed)
	local p = POSES[name] or {}
	for n in joints do goal[n] = p[n] or CFrame.new() end
	poseSpeed = speed or 14
end

local cycle, frame = 0, 0
RunS.Heartbeat:Connect(function(dt)
	frame += 1
	if frame % 2 == 1 or not m.Parent then return end
	dt *= 2
	local v = root.AssemblyLinearVelocity
	local moving = Vector3.new(v.X, 0, v.Z).Magnitude > 1.5
	cycle += dt * (moving and 11 or 2)
	local a = math.min(1, dt * poseSpeed)
	for n, j in joints do
		cur[n] = cur[n]:Lerp(goal[n], a)
		local extra = CFrame.new()
		if kind == "beast" then
			local s = math.sin(cycle)
			if moving then
				if n == "Hip1" or n == "Hip4" then extra = A(s * 32) elseif n == "Hip2" or n == "Hip3" then extra = A(-s * 32) end
			end
			if n == "Neck" then extra = A(math.sin(cycle * 0.5) * (moving and 4 or 2)) end
			if n == "Tail" then extra = A(0, math.sin(cycle * 1.3) * 25) end
		end
		setC(j, base[n] * cur[n] * extra)
	end
end)

-- animasi jalan & idle default R15 punya Roblox
if kind ~= "beast" then
	pcall(function()
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local wa = Instance.new("Animation")
		wa.AnimationId = "rbxassetid://507777826"
		local ia = Instance.new("Animation")
		ia.AnimationId = "rbxassetid://507766388"
		local walk, idle = animator:LoadAnimation(wa), animator:LoadAnimation(ia)
		walk.Looped, idle.Looped = true, true
		idle:Play()
		hum.Running:Connect(function(sp)
			if sp > 0.5 then
				if not walk.IsPlaying then walk:Play() end
				walk:AdjustSpeed(sp / 14)
			else
				walk:Stop()
			end
		end)
	end)
end

-- ===== helper =====
local function stunned() return (m:GetAttribute("StunUntil") or 0) > os.clock() end
local function dmg() return (at("Damage") or 10) * (at("Phase") == 2 and 1.3 or 1) end
local function groundY() return Core.ground(root.Position).Y end
local function face(pos)
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(pos.X, root.Position.Y, pos.Z))
end
local function stop() hum:MoveTo(root.Position) end
local function charsIn(test)
	local list = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and test(r.Position) then table.insert(list, c) end
	end
	return list
end
local function inRadius(pos, r)
	return charsIn(function(p) return (Vector3.new(p.X, pos.Y, p.Z) - pos).Magnitude <= r and math.abs(p.Y - pos.Y) < 10 end)
end
local function inBox(cf, size)
	return charsIn(function(p)
		local l = cf:PointToObjectSpace(p)
		return math.abs(l.X) <= size.X / 2 and math.abs(l.Y) <= size.Y / 2 and math.abs(l.Z) <= size.Z / 2
	end)
end
local function okToHit() return hum.Health > 0 and not stunned() end
local function velocity(vec, t)
	local att = root:FindFirstChild("RootAttachment")
	if not att then return end
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e7
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.PlaneVelocity = Vector2.new(vec.X, vec.Z)
	lv.Parent = root
	task.delay(t, function() lv:Destroy() end)
	return lv
end

local function findTarget()
	local best, bestD = nil, at("Aggro") or 45
	local leash = at("Leash") or 70
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and (r.Position - home).Magnitude < leash then
			local d = (r.Position - root.Position).Magnitude
			if d < bestD then best, bestD = c, d end
		end
	end
	return best, bestD
end

-- ===== serangan =====
local ATK = {}

function ATK.Swipe(target)
	stop()
	face(target.HumanoidRootPart.Position)
	local reach = (at("AttackRange") or 6) + 3
	local w = root.Size.X + 4
	local gy = groundY()
	local cf = root.CFrame * CFrame.new(0, 0, -reach / 2)
	local tele = Core.part(Vector3.new(w, 0.2, reach), CFrame.new(cf.Position.X, gy + 0.15, cf.Position.Z) * (cf - cf.Position), RED, {Transparency = 0.6})
	pose("Windup", 10)
	task.wait(at("Windup") or 0.5)
	tele:Destroy()
	if not okToHit() then pose() return end
	pose("Strike", 30)
	velocity(root.CFrame.LookVector * 28, 0.12)
	for _, c in inBox(cf, Vector3.new(w, 12, reach)) do Core.damagePlayer(c, dmg(), m, at("Heavy")) end
	task.wait(0.35)
	pose()
end

function ATK.Charge(target)
	stop()
	face(target.HumanoidRootPart.Position)
	local dir = root.CFrame.LookVector
	local len = 36
	local gy = groundY()
	local startP = Vector3.new(root.Position.X, gy + 0.15, root.Position.Z)
	local tele = Core.part(Vector3.new(root.Size.X + 2, 0.2, len), CFrame.lookAt(startP, startP + dir) * CFrame.new(0, 0, -len / 2), RED, {Transparency = 0.6})
	pose("Low", 8)
	task.wait(0.8)
	tele:Destroy()
	if not okToHit() then pose() return end
	local hit = {}
	velocity(dir * 70, 0.5)
	local t0 = os.clock()
	while os.clock() - t0 < 0.5 and hum.Health > 0 do
		for _, c in inRadius(root.Position, root.Size.Z / 2 + 2.5) do
			if not hit[c] then
				hit[c] = true
				if Core.damagePlayer(c, dmg(), m, at("Heavy")) == "hit" then
					c.HumanoidRootPart.AssemblyLinearVelocity = dir * 50 + Vector3.new(0, 30, 0)
				end
			end
		end
		RunS.Heartbeat:Wait()
	end
	pose()
	task.wait(0.4)
end

function ATK.Slam(target)
	stop()
	face(target.HumanoidRootPart.Position)
	local r = at("SlamRadius") or 12
	local gy = groundY()
	local c0 = Vector3.new(root.Position.X, gy + 0.15, root.Position.Z)
	local tele = Core.disc(c0, r, RED, 0.65)
	local fill = Core.part(Vector3.new(0.25, 1, 1), tele.CFrame, RED, {Shape = Enum.PartType.Cylinder, Transparency = 0.35})
	game:GetService("TweenService"):Create(fill, TweenInfo.new(0.95, Enum.EasingStyle.Linear), {Size = Vector3.new(0.25, r * 2, r * 2)}):Play()
	pose("Rear", 8)
	root.AssemblyLinearVelocity += Vector3.new(0, 25, 0)
	task.wait(0.95)
	tele:Destroy()
	fill:Destroy()
	if not okToHit() then pose() return end
	pose("Slam", 35)
	Core.ring(c0, r + 2, Color3.fromRGB(255, 140, 90), 0.4, 0.8)
	Core.sparks(c0 + Vector3.new(0, 1, 0), Color3.fromRGB(255, 200, 150), 30, 30)
	Core.shakeNear(c0, 0.9, 0.3, 60)
	for _, c in inRadius(c0, r) do
		if Core.damagePlayer(c, dmg() * 1.3, m, true) == "hit" then
			local away = c.HumanoidRootPart.Position - c0
			away = Vector3.new(away.X, 0, away.Z)
			if away.Magnitude > 0.1 then c.HumanoidRootPart.AssemblyLinearVelocity = away.Unit * 45 + Vector3.new(0, 35, 0) end
		end
	end
	task.wait(0.5)
	pose()
end

function ATK.Thunder(target)
	stop()
	face(target.HumanoidRootPart.Position)
	pose("Rear", 8)
	local n = at("Boss") and 3 or (at("Elite") and 2 or 1)
	for i = 1, n do
		local r = target:FindFirstChild("HumanoidRootPart")
		if r then
			local lead = r.AssemblyLinearVelocity * 0.4
			task.spawn(Core.lightning, r.Position + Vector3.new(lead.X, 0, lead.Z), 6, dmg(), 0.9, Color3.fromRGB(255, 240, 120))
		end
		task.wait(0.35)
	end
	task.wait(0.6)
	pose()
end

local function eruption(pos, r, d, warnT)
	local g = Core.ground(pos)
	local tele = Core.disc(g + Vector3.new(0, 0.2, 0), r, RED, 0.6)
	local fill = Core.part(Vector3.new(0.25, 1, 1), tele.CFrame, Color3.fromRGB(255, 120, 40), {Shape = Enum.PartType.Cylinder, Transparency = 0.3})
	game:GetService("TweenService"):Create(fill, TweenInfo.new(warnT, Enum.EasingStyle.Linear), {Size = Vector3.new(0.25, r * 2, r * 2)}):Play()
	task.wait(warnT)
	tele:Destroy()
	fill:Destroy()
	local pillar = Core.part(Vector3.new(26, r * 1.6, r * 1.6), CFrame.new(g + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 120, 40), {Shape = Enum.PartType.Cylinder, Transparency = 0.25})
	Core.fade(pillar, 0.5, Vector3.new(30, r * 0.4, r * 0.4), 0.1)
	Core.sparks(g + Vector3.new(0, 2, 0), Color3.fromRGB(255, 150, 60), 30, 40)
	Core.shakeNear(g, 0.6, 0.25, 50)
	for _, c in inRadius(g, r) do Core.damagePlayer(c, d, nil, true) end
end

function ATK.Formation(target)
	stop()
	pose("Roar", 8)
	for _, p in Players:GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - root.Position).Magnitude < 80 then Fx:FireClient(p, "Banner", "Dragon Formation!", Color3.fromRGB(255, 120, 60)) end
	end
	local spots = {}
	for _, c in inRadius(root.Position, 70) do table.insert(spots, c.HumanoidRootPart.Position) end
	for i = 1, 5 do
		local a, d = math.random() * math.pi * 2, math.random(8, 30)
		table.insert(spots, root.Position + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
	end
	for i, s in spots do
		task.delay(i * 0.12, eruption, s, 7, dmg() * 1.2, 1.4)
	end
	task.wait(2.2)
	pose()
end

local attacks = string.split(at("Attacks") or "Swipe", ",")
local function choose(dist)
	local opts = {}
	local range = at("AttackRange") or 6
	for _, a in attacks do
		if a == "Swipe" and dist <= range + 1 then
			table.insert(opts, a)
		elseif a == "Charge" and dist > 9 and dist < 30 then
			table.insert(opts, a)
		elseif a == "Slam" and dist <= (at("SlamRadius") or 12) - 2 then
			table.insert(opts, a)
		elseif a == "Thunder" and dist > 8 and dist < 45 then
			table.insert(opts, a)
		elseif a == "Formation" and at("Phase") == 2 and dist < 60 then
			table.insert(opts, a)
			table.insert(opts, a)
		end
	end
	return opts[math.random(math.max(#opts, 1))]
end

-- ===== fase 2 boss =====
hum.HealthChanged:Connect(function(h)
	if at("Boss") and at("Phase") ~= 2 and h > 0 and h < hum.MaxHealth * 0.5 then
		m:SetAttribute("Phase", 2)
		hum.WalkSpeed += 4
		for _, n in {"Head", "UpperTorso", "HumanoidRootPart"} do
			local p = m:FindFirstChild(n)
			if p then
				local f = Instance.new("Fire")
				f.Color = Color3.fromRGB(255, 120, 40)
				f.SecondaryColor = Color3.fromRGB(255, 40, 20)
				f.Size = 8
				f.Parent = p
			end
		end
		for _, d in m:GetDescendants() do
			if d.Name == "Eye" then d.Color = Color3.fromRGB(255, 40, 20) end
		end
		pose("Roar", 8)
		Core.ring(Core.ground(root.Position) + Vector3.new(0, 0.3, 0), 30, Color3.fromRGB(255, 120, 40), 0.8, 1)
		Core.shakeNear(root.Position, 1.2, 0.8, 100)
		for _, p in Players:GetPlayers() do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - root.Position).Magnitude < 100 then
				Fx:FireClient(p, "Banner", hum.DisplayName .. " is enraged! Phase 2", Color3.fromRGB(255, 90, 60))
			end
		end
		m:SetAttribute("StunUntil", 0)
	end
end)

-- label pusing saat kena stun
local dizzy = Instance.new("BillboardGui")
dizzy.Size = UDim2.fromOffset(90, 26)
dizzy.StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y + 4, 0)
dizzy.AlwaysOnTop = true
dizzy.Enabled = false
dizzy.Adornee = root
dizzy.Parent = root
local dl = Instance.new("TextLabel")
dl.Size = UDim2.fromScale(1, 1)
dl.BackgroundTransparency = 1
dl.Text = "STUNNED"
dl.TextColor3 = Color3.fromRGB(255, 230, 90)
dl.TextStrokeTransparency = 0.2
dl.Font = Enum.Font.FredokaOne
dl.TextScaled = true
dl.Parent = dizzy

hum.Died:Connect(function()
	dizzy.Enabled = false
	pose("Stun", 6)
end)

-- ===== loop utama =====
local lastAtk = os.clock()
while hum.Health > 0 and m.Parent do
	task.wait(0.1)
	if stunned() then
		dizzy.Enabled = true
		stop()
		pose("Stun", 8)
		continue
	end
	if dizzy.Enabled then
		dizzy.Enabled = false
		pose()
	end
	local target, dist = findTarget()
	if target then
		local opt = os.clock() - lastAtk > (at("Cooldown") or 2) and choose(dist)
		if opt then
			ATK[opt](target)
			lastAtk = os.clock()
		elseif dist > (at("AttackRange") or 6) * 0.8 then
			hum:MoveTo(target.HumanoidRootPart.Position)
		else
			stop()
			face(target.HumanoidRootPart.Position)
		end
	else
		if (root.Position - home).Magnitude > 6 then hum:MoveTo(home) else stop() end
		if hum.Health < hum.MaxHealth then hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.02) end
	end
end
