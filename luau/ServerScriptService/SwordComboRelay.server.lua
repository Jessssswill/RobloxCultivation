-- Relays a player's jian combo step to every other client so they play the same body motion + FX on that character.
-- (SwordCombo writes Motor6D.Transform locally, which does not replicate by itself.)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local relay = RS:FindFirstChild("SwordComboRelay") or Instance.new("RemoteEvent")
relay.Name = "SwordComboRelay"
relay.Parent = RS

local last = {}
relay.OnServerEvent:Connect(function(plr, tool, step)
	local char = plr.Character
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") or tool.Parent ~= char then return end
	local isStep = typeof(step) == "number" and step % 1 == 0 and step >= 1 and step <= 4
	local isSkill = step == "SkillZ" or step == "SkillX" or step == "Ult"
	if not (isStep or isSkill) then return end
	local now = os.clock()
	if last[plr] and now - last[plr] < 0.2 then return end
	last[plr] = now
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= plr then relay:FireClient(other, char, tool, step) end
	end
end)
Players.PlayerRemoving:Connect(function(plr) last[plr] = nil end)
