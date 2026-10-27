-- Script: ServerScriptService.WeaponScaleServer
-- Tiap kali pemain megang senjata, senjata diskalain sesuai tinggi avatarnya.
local Players = game:GetService("Players")
local WeaponScale = require(game:GetService("ReplicatedStorage"):WaitForChild("WeaponScale"))

local function onCharacter(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:FindFirstChild("Handle") then
			WeaponScale.scaleTool(child, WeaponScale.targetFor(character, child))
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then onCharacter(player.Character) end
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then onCharacter(player.Character) end
end
