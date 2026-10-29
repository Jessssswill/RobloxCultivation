local lava = script.Parent
local hit = {}
lava.CanTouch = true
-- lava di bawah kerak; cek ketinggian pemain tiap 0.5 dtk (lebih andal dari Touched untuk part non-collide)
while true do
	for _, plr in game:GetService("Players"):GetPlayers() do
		local c = plr.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 then
			local lp = lava.CFrame:PointToObjectSpace(r.Position)
			if math.abs(lp.X) < lava.Size.X / 2 and math.abs(lp.Z) < lava.Size.Z / 2 and lp.Y < 3.5 then
				h:TakeDamage(12)
			end
		end
	end
	task.wait(0.5)
end
