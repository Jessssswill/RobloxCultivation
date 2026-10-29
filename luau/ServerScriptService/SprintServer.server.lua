-- Lari (sprint): client kirim nyala/mati, server yang ngatur WalkSpeed lewat Core.baseSpeed
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Core = require(script.Parent:WaitForChild("CombatCore"))
local Sprint = RS:WaitForChild("QiRemotes"):WaitForChild("Sprint")

Sprint.OnServerEvent:Connect(function(plr, on)
	if typeof(on) ~= "boolean" then return end
	if (plr:GetAttribute("Sprinting") == true) == on then return end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local before = Core.baseSpeed(plr)
	plr:SetAttribute("Sprinting", on)
	-- cuma ubah kalau lagi jalan normal (bukan block, stun, atau lagi cast)
	if hum and math.abs(hum.WalkSpeed - before) < 0.05 then
		hum.WalkSpeed = Core.baseSpeed(plr)
	end
end)

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function() plr:SetAttribute("Sprinting", false) end)
end)
