-- Teleport hub <-> Istana Surga, dan tangkap pemain yang jatuh ke lautan awan
local Players = game:GetService("Players")
local folder = workspace:WaitForChild("HeavenPortals")
local function send(plr, pos)
	local c = plr.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not r then return end
	pcall(function() plr:RequestStreamAroundAsync(pos) end)
	c:PivotTo(CFrame.new(pos))
	r.AssemblyLinearVelocity = Vector3.zero
end
local function hook(name, attr)
	local pad = folder:WaitForChild(name):WaitForChild("Pad")
	pad:WaitForChild("ProximityPrompt").Triggered:Connect(function(plr) send(plr, folder:GetAttribute(attr)) end)
end
hook("ToHeaven", "HeavenArrive")
hook("ToHub", "HubArrive")
while true do
	local lo, hi, cy = folder:GetAttribute("ZoneMin"), folder:GetAttribute("ZoneMax"), folder:GetAttribute("CloudY")
	for _, plr in Players:GetPlayers() do
		local c = plr.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r then
			local p = r.Position
			if p.X > lo.X and p.X < hi.X and p.Z > lo.Z and p.Z < hi.Z and p.Y < cy + 6 and p.Y > cy - 400 then
				send(plr, folder:GetAttribute("HeavenArrive"))
			end
		end
	end
	task.wait(0.3)
end
