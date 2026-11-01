-- Plays other players' jian combo steps (sent by SwordComboRelay) on their characters: body motion, trail, slash FX.
local RS = game:GetService("ReplicatedStorage")
local SwordCombo = require(RS:WaitForChild("SwordCombo"))
local SwordFX = require(RS:WaitForChild("SwordFX"))
local relay = RS:WaitForChild("SwordComboRelay")

relay.OnClientEvent:Connect(function(char, tool, step)
	if typeof(char) ~= "Instance" or typeof(tool) ~= "Instance" or not char.Parent then return end
	local clip = SwordCombo.Get(step)
	if not clip then return end
	local trails = {}
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("Trail") then table.insert(trails, d) end
	end
	SwordCombo.Play(char, step, {
		onTrail = function(on)
			for _, t in ipairs(trails) do t.Enabled = on end
			if on then SwordFX.Spawn(char, tool, clip, "Swing") end
		end,
		onContact = function()
			SwordFX.Spawn(char, tool, clip, "Contact")
			SwordCombo.HitStop(char, clip.heavy and 0.1 or 0.055)
		end,
		onEnd = function(chained)
			if not chained then char:SetAttribute("SwordAttacking", false) end
		end,
	})
end)
