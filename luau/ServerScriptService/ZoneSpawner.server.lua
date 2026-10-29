-- Spawn monster di tiap titik World.SpawnPoints. Kasih qi + loot ke pemain yang terakhir mukul.
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Core = require(game:GetService("ServerScriptService"):WaitForChild("CombatCore"))
local templates = game:GetService("ServerStorage"):WaitForChild("Monsters")
local Monsters = workspace:WaitForChild("Monsters")
local points = workspace:WaitForChild("World"):WaitForChild("SpawnPoints")
local Fx = RS:WaitForChild("QiRemotes"):WaitForChild("Fx")

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = {Monsters, workspace:WaitForChild("FX")}

local function spawnOne(pt)
	local name = pt:GetAttribute("Monster")
	local t = templates:FindFirstChild(name)
	if not t then
		warn("[QiSword] monster template missing:", name)
		return
	end
	local m = t:Clone()
	local r = pt:GetAttribute("Radius") or 10
	local a, d = math.random() * math.pi * 2, math.random() * r
	local pos = pt.Position + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
	local res = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), rp)
	local gy = res and res.Position.Y or pos.Y
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart")
	local _, size = m:GetBoundingBox()
	m:PivotTo(CFrame.new(pos.X, gy + size.Y / 2 + 1, pos.Z) * CFrame.Angles(0, math.random() * 6.28, 0))
	m.Parent = Monsters
	Core.ring(Vector3.new(pos.X, gy + 0.3, pos.Z), 5, Color3.fromRGB(150, 120, 255), 0.6)
	hum.Died:Connect(function()
		local uid = m:GetAttribute("LastHitBy")
		local plr = uid and Players:GetPlayerByUserId(uid)
		local p = root.Position
		local qi = m:GetAttribute("Qi") or 5
		if plr then
			Core.addQi(plr, qi)
			Core.popNumber(p + Vector3.new(0, 5, 0), "+" .. qi .. " qi", Core.CYAN, true)
		end
		Core.dropLoot(name, p)
		if (m:GetAttribute("Boss") or m:GetAttribute("Elite")) and plr then
			Fx:FireAllClients("Banner", hum.DisplayName:gsub(" %(.*%)", "") .. " defeated by " .. plr.DisplayName .. "!", Core.GOLD)
		end
		Core.sparks(p, Color3.fromRGB(150, 220, 255), 40, 15)
		for _, part in m:GetDescendants() do
			if part:IsA("BasePart") then
				TS:Create(part, TweenInfo.new(1.2), {Transparency = 1}):Play()
			elseif part:IsA("Decal") or part:IsA("Fire") or part:IsA("ParticleEmitter") then
				part:Destroy()
			end
		end
		task.wait(1.3)
		m:Destroy()
		task.wait(pt:GetAttribute("Respawn") or 10)
		spawnOne(pt)
	end)
end

for _, pt in points:GetChildren() do
	for i = 1, pt:GetAttribute("Count") or 1 do
		task.spawn(spawnOne, pt)
	end
end
print("[QiSword] ZoneSpawner jalan")
