-- InkPaintingServer (Script) -> ServerScriptService.InkPaintingServer
-- Server side of the Ink Brush ultimate on G (T until 2026-11-10), "Hundred Demons Scroll" (2026-11-05). Replaces InkDanceServer (old T
-- Ink Dragon, archived in ServerStorage). Validates the cast, plans the v2 dash path on the ground (sent to every
-- client), moves the caster (anchored root, the same Config.RootCF the clients use), binds monsters around the
-- painting centre and deals the hits. Clients draw everything. Times: tau = real, story = minus the hit-stops.
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
local DURATION = Config.Duration -- real seconds, freezes included
local St, SH = Config.Strokes, Config.StrokeHit
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
			return groundAt(root.Position + look * 8, ignore), best.Parent
		end
		return groundAt(best.Position, ignore), best.Parent
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
		-- stay where the ultimate left the caster (the final plant is at the painting centre), standing upright
		local pos, look = s.root.Position, s.root.CFrame.LookVector
		look = math.abs(look.Y) < 0.9 and Config.flat(look) or Config.flat(s.origin.LookVector)
		s.root.CFrame = CFrame.lookAt(pos, pos + look)
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
	local stun = os.clock() + (Config.Tau(Config.BindUntil) - Config.Tau(Config.BindFrom)) + 0.25
	for _, m in victims(s, Config.Radius) do
		local mr = m:FindFirstChild("HumanoidRootPart")
		if mr and not s.bound[m] then
			s.bound[m] = { anchored = mr.Anchored }
			mr.Anchored = true
			m:SetAttribute("InkBound", true)
			m:SetAttribute("StunUntil", math.max(m:GetAttribute("StunUntil") or 0, stun))
		end
	end
	-- the last stroke (Config.MakeFinal) runs through the main target when it is bound (anchored from now to the
	-- burst, so it holds still under the stroke), else through the painting's centre
	if s.plan then
		local ignore = {}
		for _, other in Players:GetPlayers() do
			if other.Character then table.insert(ignore, other.Character) end
		end
		local monsters = workspace:FindFirstChild("Monsters")
		if monsters then table.insert(ignore, monsters) end
		local main = s.target and s.bound[s.target] and s.target or nil
		local ok, fin = pcall(Config.MakeFinal, s.plan, s.origin, s.P, main, ignore)
		if ok and fin then
			s.plan.final, s.main = fin, main
			remote:FireAllClients("Final", s.player, s.id, fin)
		elseif not ok then
			warn("[InkPainting] final: " .. tostring(fin))
		end
	end
end

-- Monsters stay alive (on a sliver of health) until the final burst, so every later shot still has them to hit:
-- the first live test killed 3 of 4 wolves during the dashes. A hit that would kill is owed and paid with the final.
local function deal(s, m, amount, final)
	local h = m:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return end
	if final then
		amount += s.owed[m] or 0
		s.owed[m] = nil
	elseif h.Health - amount * (s.mult or 1.5) < math.max(2, h.MaxHealth * 0.04) then
		s.owed[m] = (s.owed[m] or 0) + amount
		return
	end
	local before = h.Health
	Combat.Damage(s.player, m, amount, "ult", 0)
	if not final and h.Health > 0 and h.Health < before then
		-- the combat core scales damage (realm etc.): learn the factor from what a hit really took
		s.mult = math.max(s.mult or 0, (before - h.Health) / amount)
	end
end

local function hit(s, h)
	local list = victims(s, h.radius)
	if h.knockback then unbind(s) end
	for _, m in list do
		deal(s, m, h.damage, h.knockback ~= nil)
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

-- v2 dash strokes: a hit when the brush passes a bound monster, another when the stroke erupts
local function strokeHits(s, story)
	for i, st in St do
		if story >= st.from and not s.passDone[i] then
			local prog = Config.StrokeProgress(s.plan, i, story)
			for m in s.bound do
				local mr = m.Parent and m:FindFirstChild("HumanoidRootPart")
				if mr and not s.passed[i][m] then
					local along, side = Config.StrokeProject(s.plan, i, mr.Position)
					if side <= SH.passWidth and along >= -3 and along <= prog + 1 then
						s.passed[i][m] = true
						if Combat.CanHit(s.player, m) then deal(s, m, SH.pass) end
					end
				end
			end
			if story >= st.to then s.passDone[i] = true end
		end
		if story >= st.erupt and not s.erupted[i] then
			s.erupted[i] = true
			for _, m in victims(s, Config.Radius + 6) do
				local mr = m:FindFirstChild("HumanoidRootPart")
				if mr then
					local along, side = Config.StrokeProject(s.plan, i, mr.Position)
					if side <= SH.eruptWidth and along >= -4 and along <= s.plan.len[i] + 4 then
						deal(s, m, SH.erupt)
					end
				end
			end
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
	local P, target = pickTarget(char, root)
	local flat = Vector3.new(P.X - root.Position.X, 0, P.Z - root.Position.Z)
	local origin = flat.Magnitude > 1 and CFrame.lookAt(root.Position, root.Position + flat.Unit) or root.CFrame
	-- lower the flight under a ceiling
	local lift = Config.Lift
	local ceiling = workspace:Raycast(root.Position, Vector3.yAxis * (Config.Lift + 8), rayParams({ char }))
	if ceiling then lift = math.max(3, ceiling.Distance - 6) end
	-- the ground under the dash path (players and monsters are not ground)
	local ignore = {}
	for _, other in Players:GetPlayers() do
		if other.Character then table.insert(ignore, other.Character) end
	end
	local monsters = workspace:FindFirstChild("Monsters")
	if monsters then table.insert(ignore, monsters) end
	local okPlan, plan = pcall(Config.MakePlan, origin, P, hum.HipHeight + root.Size.Y * 0.5, ignore)
	if not okPlan then
		warn("[InkPainting] plan: " .. tostring(plan))
		plan = nil
	end
	local wire = plan and { rootH = plan.rootH, land = plan.land, strokes = plan.strokes } or nil
	Config.PreparePlan(plan)
	local s = {
		id = serial, player = player, char = char, hum = hum, root = root, tool = tool, origin = origin, P = P, lift = lift,
		serverStart = workspace:GetServerTimeNow(), walk = hum.WalkSpeed, jump = hum.JumpPower, jumpHeight = hum.JumpHeight,
		rotate = hum.AutoRotate, anchored = root.Anchored, bound = {}, hits = {}, plan = plan,
		passed = { {}, {}, {} }, passDone = {}, erupted = {}, owed = {}, target = target,
	}
	sessions[player] = s
	cooldowns[player] = now + COOLDOWN
	Combat.Busy(player, DURATION + 0.05)
	char:SetAttribute("InkDanceCasting", true) -- InkSkillServer blocks Z/X while this is set
	char:SetAttribute("UltGuardUntil", now + DURATION)
	hum.WalkSpeed, hum.JumpPower, hum.JumpHeight, hum.AutoRotate = 0, 0, 0, false
	root.Anchored = true
	root.CFrame = origin
	remote:FireAllClients("Begin", player, s.id, origin, P, lift, s.serverStart, COOLDOWN, wire)
end)

Run.Heartbeat:Connect(function()
	for player, s in sessions do
		if player.Character ~= s.char or not s.root.Parent or s.hum.Health <= 0 or s.tool.Parent ~= s.char then
			finish(player, "Interrupted")
		else
			local tau = workspace:GetServerTimeNow() - s.serverStart
			local story = Config.Story(math.max(0, tau))
			s.root.CFrame = Config.RootCF(story, s.origin, s.lift, s.plan)
			if story >= Config.BindFrom and not s.didBind then
				s.didBind = true
				bind(s)
			end
			if s.plan then strokeHits(s, story) end
			if s.main and story >= Config.Act.Mark and not s.markHit then -- the last stroke goes through the main target
				s.markHit = true
				if s.main.Parent and Combat.CanHit(s.player, s.main) then deal(s, s.main, Config.FinalDamage) end
			end
			for i, h in Config.Hits do
				if story >= h.t and not s.hits[i] then
					s.hits[i] = true
					hit(s, h)
				end
			end
			if story >= Config.BindUntil and next(s.bound) then unbind(s) end
			if tau >= DURATION then finish(player, "Complete") end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	finish(player, "Left")
	cooldowns[player] = nil
end)
