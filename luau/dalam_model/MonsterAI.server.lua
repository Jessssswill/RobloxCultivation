-- AI sederhana: kejar player terdekat, telegraph lalu pukul.
local m = script.Parent
local hum = m:WaitForChild("Humanoid")
local root = m:WaitForChild("HumanoidRootPart")
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")
pcall(function() root:SetNetworkOwner(nil) end)

local RunS = game:GetService("RunService")
local shoulder
for _, d in m:GetDescendants() do
	if d.Name == "RightShoulder" and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then shoulder = d end
end
local function getC(j)
	if j:IsA("Motor6D") then return j.C0 end
	return j.Attachment0.CFrame
end
local function setC(j, cf)
	if j:IsA("Motor6D") then j.C0 = cf else j.Attachment0.CFrame = cf end
end
local origC0 = shoulder and getC(shoulder)
local function arm(deg, t)
	if not shoulder then return end
	task.spawn(function()
		local start, goal, el = getC(shoulder), origC0 * CFrame.Angles(math.rad(deg), 0, 0), 0
		while el < t do
			el += RunS.Heartbeat:Wait()
			setC(shoulder, start:Lerp(goal, math.min(el / t, 1)))
		end
		setC(shoulder, goal)
	end)
end

-- Animasi jalan & idle default R15 punya Roblox
pcall(function()
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local walkA = Instance.new("Animation")
	walkA.AnimationId = "rbxassetid://507777826"
	local idleA = Instance.new("Animation")
	idleA.AnimationId = "rbxassetid://507766388"
	local walk = animator:LoadAnimation(walkA)
	local idle = animator:LoadAnimation(idleA)
	idle.Looped = true
	walk.Looped = true
	idle:Play()
	hum.Running:Connect(function(speed)
		if speed > 0.5 then
			if not walk.IsPlaying then walk:Play() end
		else
			walk:Stop()
		end
	end)
end)

local lastAtk = 0
while hum.Health > 0 do
	local target, best = nil, 60
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 then
			local d = (r.Position - root.Position).Magnitude
			if d < best then
				target, best = c, d
			end
		end
	end
	if target then
		local r = target.HumanoidRootPart
		if best > 5.5 then
			hum:MoveTo(r.Position)
		else
			hum:MoveTo(root.Position)
		end
		if best <= 7 and os.clock() - lastAtk > 2.5 then
			lastAtk = os.clock()
			arm(150, 0.35) -- telegraph, celah buat dash/parry
			task.wait(0.35)
			arm(-30, 0.1)
			if hum.Health > 0 and (r.Position - root.Position).Magnitude < 8 then
				target.Humanoid:TakeDamage(6)
			end
			task.wait(0.3)
			arm(0, 0.3)
		end
	end
	task.wait(0.1)
end
