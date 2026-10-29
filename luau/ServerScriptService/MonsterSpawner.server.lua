-- Spawn monster dari template, respawn 4 detik setelah mati.
local template = game:GetService("ServerStorage"):WaitForChild("MonsterTemplate")
local SPAWN = CFrame.new(0, 8, -35)
local function spawnMonster()
	local m = template:Clone()
	m.Name = "Monster"
	m:PivotTo(SPAWN)
	m.Parent = workspace
	m:FindFirstChildOfClass("Humanoid").Died:Connect(function()
		task.wait(4)
		m:Destroy()
		spawnMonster()
	end)
end
spawnMonster()
