-- Teleport hub <-> Arena Bos, prompt pintu gerbang, jatuh dari peta = kembali ke jalan suci
local Players = game:GetService("Players")
local folder = workspace:WaitForChild("ArenaPortals")
local function send(plr, pos)
	local c = plr.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not r then return end
	pcall(function() plr:RequestStreamAroundAsync(pos) end)
	c:PivotTo(CFrame.new(pos))
	r.AssemblyLinearVelocity = Vector3.zero
end
local function hook(path, attr)
	local part = folder:WaitForChild(path[1])
	if path[2] then part = part:WaitForChild(path[2]) end
	part:WaitForChild("ProximityPrompt").Triggered:Connect(function(plr) send(plr, folder:GetAttribute(attr)) end)
end
hook({"ToArena", "Pad"}, "ArenaArrive")
hook({"ToHub", "Pad"}, "HubArrive")
local sealFx = game:GetService("ReplicatedStorage"):WaitForChild("ArenaSealFx")
local busy = {}
folder:WaitForChild("DoorEnter"):WaitForChild("ProximityPrompt").Triggered:Connect(function(plr)
	if busy[plr] then return end
	busy[plr] = true
	sealFx:FireClient(plr)       -- jimat terbakar, rantai hancur, pintu terbuka (di layar pemain)
	task.wait(8.3)
	send(plr, folder:GetAttribute("DoorIn"))
	task.wait(1.5)
	busy[plr] = nil
end)
hook({"DoorExit"}, "DoorOut")
while true do
	local lo, hi, fy = folder:GetAttribute("ZoneMin"), folder:GetAttribute("ZoneMax"), folder:GetAttribute("FallY")
	for _, plr in Players:GetPlayers() do
		local c = plr.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r then
			local p = r.Position
			if p.X > lo.X and p.X < hi.X and p.Z > lo.Z and p.Z < hi.Z and p.Y < fy and p.Y > fy - 800 then
				send(plr, folder:GetAttribute("ArenaArrive"))
			end
		end
	end
	task.wait(0.4)
end
