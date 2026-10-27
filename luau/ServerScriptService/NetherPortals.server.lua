-- Teleport hub <-> Kerajaan Iblis; jatuh ke danau darah = kembali ke gerbang Huangquan
local Players = game:GetService("Players")
local folder = workspace:WaitForChild("NetherPortals")
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
hook("ToNether", "NetherArrive")
hook("ToHub", "HubArrive")
while true do
	local lo, hi, ly = folder:GetAttribute("ZoneMin"), folder:GetAttribute("ZoneMax"), folder:GetAttribute("LakeY")
	for _, plr in Players:GetPlayers() do
		local c = plr.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if r and h then
			local p = r.Position
			if p.X > lo.X and p.X < hi.X and p.Z > lo.Z and p.Z < hi.Z and p.Y < ly + 2 and p.Y > ly - 600 then
				h:TakeDamage(15)
				send(plr, folder:GetAttribute("NetherArrive"))
			end
		end
	end
	task.wait(0.3)
end
