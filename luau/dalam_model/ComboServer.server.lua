-- Server: validasi hitbox combo pedang, damage lewat CombatCore.
local tool = script.Parent
local Core = require(game:GetService("ServerScriptService"):WaitForChild("CombatCore"))
local remote = tool:WaitForChild("Hit")
local last, count = 0, 0
remote.OnServerEvent:Connect(function(plr, step)
	local char = tool.Parent
	if typeof(step) ~= "number" or not char or plr.Character ~= char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or os.clock() - last < 0.12 then return end
	last = os.clock()
	local heavy = step == 4
	local size = heavy and Vector3.new(11, 7, 10) or Vector3.new(8, 6, 8)
	local cf = root.CFrame * CFrame.new(0, 0, -size.Z / 2 + 0.5)
	local hitAny = false
	for _, m in Core.enemiesInBox(cf, size) do
		hitAny = true
		Core.dealDamage(plr, m, heavy and 35 or 15, "combo", heavy and 55 or 6)
	end
	if hitAny then
		count += 1
		local d = Core.Data[plr]
		-- Sword Dao 1: tiap hit ke-5 keluar pedang bayangan
		if count % 5 == 0 and d and Core.daoLevel(d.SwordDao) >= 1 then
			task.spawn(Core.Skills.Crescent, plr, char, root, nil, true)
		end
	end
end)
