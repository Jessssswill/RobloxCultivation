-- InkPaintingServer (Script) -> ServerScriptService.InkPaintingServer
-- Server side of the Ink Brush ultimate on T, "Hundred Demons Scroll" (2026-11-05). Replaces InkDanceServer (old T
-- Ink Dragon, archived in ServerStorage). Validates the cast, flies the caster (anchored root, same curve the
-- clients use), binds monsters around the painting centre and deals the hits. Clients draw everything.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local SSS = game:GetService("ServerScriptService")

local Config = require(RS:WaitForChild("InkPainting"):WaitForChild("Config"))
local Combat = require(SSS:WaitForChild("InkQiCombat"))
local Core = require(SSS:WaitForChild("CombatCore"))

local remote = RS:FindFirstChild("InkPaintingRemote") or Instance.new("RemoteEvent")
remote.Name = "InkPaintingRemote"
remote.Parent = RS

local COOLDOWN = Run:IsStudio() and Config.StudioCooldown or Config.Cooldown
local DURATION = Config.Duration
local sessions, cooldowns, serial = {}, {}, 0

local function rayParams(ignore)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore
	rp.RespectCanCollide = true
	return rp
end

local function groundAt(pos, ignore)
	local hit = workspace:Raycast(pos + Vector3.yAxis * 8, -Vector3.yAxis * 60, rayParams(ignore))
	return hit and hit.Position or pos
end

-- painting centre: nearest living monster in front, else a point ahead
local function pickTarget(char, root)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local best, bestScore
	for _, m in Core.enemiesInRadius(root.Position, Config.TargetRange) do
		local mr = m:FindFirstChild("HumanoidRootPart")
		if mr then
			local off = mr.Position - root.Position
			local flat = Vector3.new(off.X, 0, off.Z)
			local d = flat.Magnitude
			local dot = d > 0.1 and flat.Unit:Dot(look) or 1
			if dot > 0.15 then
				local score = d * (1.6 - dot)
				if not bestScore or score < bestScore then best, bestScore = mr, score end
			end
		end
	end
	local ignore = { char }
	local monsters = workspace:FindFirstChild("Monsters")
	if monsters then table.insert(ignore, monsters) end
	if best then
		local flat = Vector3.new(best.Position.X - root.Position.X, 0, best.Position.Z - root.Position.Z)
		if flat.Magnitude < 8 then
			return groundAt(root.Position + look * 8, ignore)
		end
		return groundAt(best.Position, ignore)
	end
	return groundAt(root.Position + look * Config.TargetDistance, ignore)
end

local function unbind(s)
	for m, saved in s.bound do
		local mr = m:FindFirstChild("HumanoidRootPart")
		if mr and mr.Parent then mr.Anchored = saved.anchored end
		if m.Parent then m:SetAttribute("InkBound", nil) end
	end
	s.bound = {}
end

local function finish(player, reason)
	local s = sessions[player]
	if not s then return end
	sessions[player] = nil
	unbind(s)
	Combat.Clear(player)
	if s.root.Parent then
		s.root.CFrame = s.origin
		s.root.Anchored = s.anchored
	end
	if s.hum.Parent then
		s.hum.WalkSpeed, s.hum.JumpPower, s.hum.JumpHeight, s.hum.AutoRotate = s.walk, s.jump, s.jumpHeight, s.rotate
	end
	if s.char.Parent then
		s.char:SetAttribute("InkDanceCasting", nil)
		s.char:SetAttribute("UltGuardUntil", nil)
	end
	remote:FireAllClients("End", player, s.id, reason)
end

local function victims(s, radius)
	local list = {}
	for _, m in Core.enemiesInRadius(s.P, radius) do
		if Combat.CanHit(s.player, m) then table.insert(list, m) end
	end
	return list
end

local function bind(s)
	local stun = os.clock() + (Config.BindUntil - Config.BindFrom) + 0.25
	for _, m in victims(s, Config.Radius) do
		local mr = m:FindFirstChild("HumanoidRootPart")
		if mr and not s.bound[m] then
			s.bound[m] = { anchored = mr.Anchored }
			mr.Anchored = true
			m:SetAttribute("InkBound", true)
			m:SetAttribute("StunUntil", math.max(m:GetAttribute("StunUntil") or 0, stun))
		end
	end
end

local function hit(s, h)
	local list = victims(s, h.radius)
	if h.knockback then unbind(s) end
	for _, m in list do
		Combat.Damage(s.player, m, h.damage, "ult", 0)
		local mr = m:FindFirstChild("HumanoidRootPart")
		if h.knockback and mr and not mr.Anchored then
			local away = mr.Position - s.P
			away = Vector3.new(away.X, 0, away.Z)
			if away.Magnitude < 0.1 then away = s.origin.LookVector end
			local power = (m:GetAttribute("Heavy") and 0.15 or 1) * h.knockback
			mr:ApplyImpulse((away.Unit + Vector3.yAxis * 0.6).Unit * power * mr.AssemblyMass)
		end
	end
end

remote.OnServerEvent:Connect(function(player, action, id)
	if action == "Cancel" then
		local s = sessions[player]
		if s and s.id == id then finish(player, "Cancelled") end
		return
	end
	if action ~= "Cast" then return end
	if not Combat.CanBegin(player) then
		remote:FireClient(player, "Denied")
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local tool = char and char:FindFirstChild("Ink Brush")
	local now = os.clock()
	if not hum or hum.Health <= 0 or hum.RigType ~= Enum.HumanoidRigType.R15 or not root or not tool or sessions[player]
		or now < (cooldowns[player] or 0) or now < (char:GetAttribute("InkSkillBusyUntil") or 0) then
		remote:FireClient(player, "Denied")
		return
	end
	serial += 1
	local P = pickTarget(char, root)
	local flat = Vector3.new(P.X - root.Position.X, 0, P.Z - root.Position.Z)
	local origin = flat.Magnitude > 1 and CFrame.lookAt(root.Position, root.Position + flat.Unit) or root.CFrame
	-- lower the flight under a ceiling
	local lift = Config.Lift
	local ceiling = workspace:Raycast(root.Position, Vector3.yAxis * (Config.Lift + 8), rayParams({ char }))
	if ceiling then lift = math.max(3, ceiling.Distance - 6) end
	local s = {
		id = serial, player = player, char = char, hum = hum, root = root, tool = tool, origin = origin, P = P, lift = lift,
		serverStart = workspace:GetServerTimeNow(), walk = hum.WalkSpeed, jump = hum.JumpPower, jumpHeight = hum.JumpHeight,
		rotate = hum.AutoRotate, anchored = root.Anchored, bound = {}, hits = {},
	}
	sessions[player] = s
	cooldowns[player] = now + COOLDOWN
	Combat.Busy(player, DURATION + 0.05)
	char:SetAttribute("InkDanceCasting", true) -- InkSkillServer blocks Z/X while this is set
	char:SetAttribute("UltGuardUntil", now + DURATION)
	hum.WalkSpeed, hum.JumpPower, hum.JumpHeight, hum.AutoRotate = 0, 0, 0, false
	root.Anchored = true
	root.CFrame = origin
	remote:FireAllClients("Begin", player, s.id, origin, P, lift, s.serverStart, COOLDOWN)
end)

Run.Heartbeat:Connect(function()
	for player, s in sessions do
		if player.Character ~= s.char or not s.root.Parent or s.hum.Health <= 0 or s.tool.Parent ~= s.char then
			finish(player, "Interrupted")
		else
			local t = workspace:GetServerTimeNow() - s.serverStart
			s.root.CFrame = s.origin * Config.RootOffset(t, s.lift)
			if t >= Config.BindFrom and not s.didBind then
				s.didBind = true
				bind(s)
			end
			for i, h in Config.Hits do
				if t >= h.t and not s.hits[i] then
					s.hits[i] = true
					hit(s, h)
				end
			end
			if t >= Config.BindUntil and next(s.bound) then unbind(s) end
			if t >= DURATION then finish(player, "Complete") end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	finish(player, "Left")
	cooldowns[player] = nil
end)
