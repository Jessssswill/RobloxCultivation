-- CombatServer: nerima input dari client, validasi cooldown, lalu jalanin CombatCore.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunS = game:GetService("RunService")
local Core = require(script.Parent:WaitForChild("CombatCore"))
local R = RS:WaitForChild("QiRemotes")

local COOLDOWN = {Crescent = 3, SwordRain = 8, QiPalm = 5, GroundShock = 7, SkySword = 25, HeavenPalm = 25, DivineDragon = 1}
-- jeda biar efek pas sama marker "Cast" di animasi
local DELAY = {Crescent = 0.26, SwordRain = 0.3, QiPalm = 0.23, GroundShock = 0.32, SkySword = 0, HeavenPalm = 0, DivineDragon=0}
local REQ = {HeavenPalm = 7, DivineDragon = 1}
local cds = {}

local function ready(plr, key, cd)
	cds[plr] = cds[plr] or {}
	if os.clock() < (cds[plr][key] or 0) then return false end
	cds[plr][key] = os.clock() + cd
	return true
end
local function charOf(plr)
	local c = plr.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if h and r and h.Health > 0 then return c, r, h end
end

local function onPlayer(plr)
	Core.load(plr)
	plr.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid")
		char:WaitForChild("UpperTorso", 5)
		task.wait(0.2)
		plr:SetAttribute("BeastForm", nil)
		plr:SetAttribute("Meditating", nil)
		plr:SetAttribute("Flying", nil)
		Core.applyCharacter(plr, true)
	end)
	if plr.Character then Core.applyCharacter(plr, true) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end

R.Skill.OnServerEvent:Connect(function(plr, name, aim)
	if type(name) ~= "string" or not COOLDOWN[name] then return end
	if aim ~= nil and typeof(aim) ~= "Vector3" then return end
	local char = charOf(plr)
	local d = Core.Data[plr]
	if not char or not d or plr:GetAttribute("Meditating") then return end
	if REQ[name] and d.Stage < REQ[name] then return end
	if not ready(plr, name, COOLDOWN[name] - 0.2) then return end
	task.spawn(function()
		if DELAY[name] > 0 then task.wait(DELAY[name]) end
		local c2, r2 = charOf(plr)
		if c2 then Core.Skills[name](plr, c2, r2, aim) end
	end)
end)

R.Parry.OnServerEvent:Connect(function(plr)
	local char = charOf(plr)
	if char and ready(plr, "Parry", 0.6) then char:SetAttribute("ParryUntil", os.clock() + 0.35) end
end)

R.Dash.OnServerEvent:Connect(function(plr)
	if plr:GetAttribute("Mounted") or plr:GetAttribute("SteedCalling") or plr:GetAttribute("DemonForm") or plr:GetAttribute("DemonCharging") or plr:GetAttribute("SwordRiding") or plr:GetAttribute("SwordCalling") then return end   -- tidak bisa dash saat naik kuda / wujud iblis
	local char = charOf(plr)
	if char and ready(plr, "Dash", 0.6) then char:SetAttribute("IFrameUntil", os.clock() + 0.3) end
end)

R.Block.OnServerEvent:Connect(function(plr, on)
	local char, _, hum = charOf(plr)
	if not char then return end
	if on then
		char:SetAttribute("Blocking", true)
		hum.WalkSpeed = 8
		local token = os.clock()
		char:SetAttribute("BlockToken", token)
		task.delay(3, function()
			if char:GetAttribute("BlockToken") == token and char:GetAttribute("Blocking") then
				char:SetAttribute("Blocking", nil)
				hum.WalkSpeed = Core.baseSpeed(plr)
			end
		end)
	else
		char:SetAttribute("Blocking", nil)
		hum.WalkSpeed = Core.baseSpeed(plr)
	end
end)

local function inMedZone(pos)
	local z = workspace.World.AzureCloudSect:FindFirstChild("MeditationZone")
	if not z then return false end
	local lp = z.CFrame:PointToObjectSpace(pos)
	return math.abs(lp.X) <= z.Size.X / 2 and math.abs(lp.Z) <= z.Size.Z / 2 and math.abs(lp.Y) <= z.Size.Y / 2 + 3
end

R.Meditate.OnServerEvent:Connect(function(plr, on)
	local char, root, hum = charOf(plr)
	if not char then return end
	if on and not plr:GetAttribute("Meditating") then
		plr:SetAttribute("Meditating", true)
		hum.WalkSpeed = 0
		task.spawn(function()
			while plr:GetAttribute("Meditating") and hum.Health > 0 and char.Parent do
				task.wait(3)
				if not plr:GetAttribute("Meditating") then break end
				local gain = inMedZone(root.Position) and 4 or 1
				gain = math.max(1, math.floor(gain * Core.race(plr).med + 0.5))
				Core.addQi(plr, gain)
				Core.popNumber(root.Position + Vector3.new(0, 3, 0), "+" .. gain .. " qi", Core.CYAN)
			end
		end)
	elseif not on then
		plr:SetAttribute("Meditating", nil)
		hum.WalkSpeed = Core.baseSpeed(plr)
	end
end)

R.Fly.OnServerEvent:Connect(function(plr, on)
	local char, root = charOf(plr)
	local d = Core.Data[plr]
	if not char or not d then return end
	local old = char:FindFirstChild("FlyingSword")
	if old then old:Destroy() end
	if on and d.Stage >= 4 then
		plr:SetAttribute("Flying", true)
		local s = Instance.new("Part")
		s.Name = "FlyingSword"
		s.Material = Enum.Material.Neon
		s.Color = Core.CYAN
		s.Size = Vector3.new(1.3, 0.3, 7.5)
		s.Parent = char
		Core.weld(s, root, CFrame.new(0, -3.1, -0.5))
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-0.6, 0, 3.5)
		a0.Parent = s
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0.6, 0, 3.5)
		a1.Parent = s
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = ColorSequence.new(Core.CYAN)
		tr.LightEmission = 1
		tr.Lifetime = 0.4
		tr.Transparency = NumberSequence.new(0.3, 1)
		tr.Parent = s
	else
		plr:SetAttribute("Flying", nil)
	end
end)

R.DevQi.OnServerEvent:Connect(function(plr)
	if RunS:IsStudio() then Core.addQi(plr, 150) end
end)

R.ChooseRace.OnServerEvent:Connect(function(plr, race)
	local d = Core.Data[plr]
	if d and d.Race == "" and Core.RACE[race] then
		d.Race = race
		Core.sync(plr)
		Core.applyCharacter(plr, true)
	end
end)

-- ===== Prompt di world =====
local world = workspace:WaitForChild("World")
for _, npc in world:WaitForChild("NPCs"):GetChildren() do
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	local pp = hrp and hrp:FindFirstChildOfClass("ProximityPrompt")
	if pp then
		pp.Triggered:Connect(function(plr)
			if npc.Name == "Merchant Lin" then
				Core.barter(plr)
			elseif npc.Name == "Elder Yun" then
				R.Dialog:FireClient(plr, npc.Name, Core.elderLine(plr, npc:GetAttribute("Line")))
			else
				R.Dialog:FireClient(plr, npc.Name, npc:GetAttribute("Line"))
			end
		end)
	end
end

local stele = world:FindFirstChild("AncientStele", true)
if stele then
	stele:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(plr)
		local d = Core.Data[plr]
		if d and not table.find(d.Lore, "Stele1") then
			table.insert(d.Lore, "Stele1")
			Core.sync(plr)
			R.Fx:FireClient(plr, "Banner", "Lore discovered (" .. #d.Lore .. ")", Core.GOLD)
		end
		R.Dialog:FireClient(plr, "Ancient Stele", stele:GetAttribute("Line"))
	end)
end

local function prompt(part, text, dist, fn)
	if not part then return end
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = text
	pp.ObjectText = ""
	pp.HoldDuration = 0.8
	pp.RequiresLineOfSight = false
	pp.MaxActivationDistance = dist
	pp.Parent = part
	pp.Triggered:Connect(fn)
end
prompt(world:FindFirstChild("TribulationCenter", true), "Begin Tribulation", 22, Core.startTribulation)
prompt(world:FindFirstChild("DaoTrialSite", true), "Begin Dao Trial", 14, Core.startDaoTrial)

-- ===== Simpan data =====
Players.PlayerRemoving:Connect(function(plr)
	Core.save(plr)
	Core.Data[plr] = nil
	cds[plr] = nil
end)
game:BindToClose(function()
	for _, p in Players:GetPlayers() do Core.save(p) end
end)
task.spawn(function()
	while true do
		task.wait(120)
		for _, p in Players:GetPlayers() do Core.save(p) end
	end
end)
print("[QiSword] CombatServer jalan")
