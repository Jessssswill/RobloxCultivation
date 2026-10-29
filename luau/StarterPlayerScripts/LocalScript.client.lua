local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local skills = game.ReplicatedStorage:WaitForChild("Skill")
local disintegration = require(skills:WaitForChild("Disintegration"))
local giantSwing = require(skills:WaitForChild("GiantSwing"))

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Zero then
		disintegration:Cast(Players.LocalPlayer)
	elseif input.KeyCode == Enum.KeyCode.Y then
		giantSwing:Cast(Players.LocalPlayer)
	end
end)