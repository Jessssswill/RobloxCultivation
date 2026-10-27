-- Rak senjata: dekati pedang di rak, tekan E untuk ambil. Satu pemain cuma dapat satu salinan tiap pedang.
local ServerStorage = game:GetService("ServerStorage")
local Weapons = ServerStorage:WaitForChild("Weapons")
local rack = workspace:WaitForChild("WeaponRack")

local function biggestPart(model)
	local best, size = nil, 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Size.Magnitude > size then best, size = p, p.Size.Magnitude end
	end
	return best
end

local function has(player, name)
	local char = player.Character
	return player.Backpack:FindFirstChild(name) or (char and char:FindFirstChild(name))
end

for _, model in ipairs(rack:GetChildren()) do
	local template = Weapons:FindFirstChild(model.Name)
	local part = template and biggestPart(model)
	if part then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take"
		prompt.ObjectText = model.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.Triggered:Connect(function(player)
			if not has(player, model.Name) then
				template:Clone().Parent = player.Backpack
			end
		end)
	end
end
