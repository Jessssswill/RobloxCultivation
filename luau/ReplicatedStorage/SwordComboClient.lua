-- WeaponCombo v4 (jian/dao): attack while walking (slowed walk, legs keep walking, upper body swings; will 2026-11-04).
-- Each sword has its own combo style (SwordCombo.StyleOf: Thunder = Lightning 5 fast hits, Ice = Moon, Lotus = Lotus,
-- Jade = Dragon heavy, Fire = Blaze dao) and its own element effects (SwordFX).
-- v3: 4-hit combo, whole body driven by ReplicatedStorage.SwordCombo (no uploaded animation needed),
-- thick element slash effects from ReplicatedStorage.SwordFX, hit-stop, lunge. Other players see it via SwordComboRelay.
-- Damage stays on the server (ComboServer in this tool, remote "Hit").
-- Module: every sword Tool runs it through a one-line LocalScript stub (WeaponCombo), so a change here reaches
-- all swords at once (Rojo-synced: luau/ReplicatedStorage/SwordComboClient.lua).
return function(tool)
	local Players = game:GetService("Players")
	local RS = game:GetService("ReplicatedStorage")
	local Debris = game:GetService("Debris")
	local SwordCombo = require(RS:WaitForChild("SwordCombo"))
	local SwordFX = require(RS:WaitForChild("SwordFX"))
	local relay = RS:WaitForChild("SwordComboRelay")
	local player = Players.LocalPlayer
	local remote = tool:WaitForChild("Hit")

	local trails = {}
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("Trail") then table.insert(trails, d) end
	end
	local function setTrail(on)
		for _, t in ipairs(trails) do t.Enabled = on end
	end

	local function lunge(root, speed)
		local att = Instance.new("Attachment")
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
		lv.LineDirection = root.CFrame.LookVector
		lv.LineVelocity = speed
		lv.MaxForce = 60000
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = root
		Debris:AddItem(lv, 0.12)
		Debris:AddItem(att, 0.12)
	end

	local function blocked()
		return player:GetAttribute("Meditating") or player:GetAttribute("Flying") or player:GetAttribute("Casting")
	end

	local step, lastEnd, current, queued, chainAt = 0, 0, nil, false, 0
	local savedSpeed
	local ownChain = false -- true only while this script starts its own next hit (see onEnd)

	local function restoreSpeed(hum)
		if savedSpeed and hum and hum.Parent then hum.WalkSpeed = savedSpeed end
		savedSpeed = nil
	end

	local attack
	attack = function()
		local char = tool.Parent
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (hum and root) or hum.Health <= 0 or blocked() then return end
		if current and os.clock() < chainAt then
			queued = true
			return
		end
		queued = false
		if os.clock() - lastEnd > 0.6 and not current then step = 0 end
		local style = SwordCombo.StyleOf(tool)
		local count = SwordCombo.Count(style)
		step = step % count + 1
		local i = step
		local clip = SwordCombo.Get(i, style)
		relay:FireServer(tool, i)
		savedSpeed = savedSpeed or hum.WalkSpeed
		-- keep walking while swinging, just slower (light hits ~60 %, the finisher ~30 %), Ink Brush / Type Soul style
		hum.WalkSpeed = savedSpeed * (clip.move or 0.6) -- each style sets its own (Dragon heavy = slow, Lightning = fast)
		-- clicks before this hit has landed are queued; chainAt opens once its last contact has really happened (below),
		-- not at a fixed time: on a slow phone the clip runs behind the clock and a timer would cut the hit off before it lands
		chainAt = math.huge
		local mine
		ownChain = true
		mine = SwordCombo.Play(char, i, {
			onTrail = function(on)
				setTrail(on)
				if on then SwordFX.Spawn(char, tool, clip, "Swing") end
			end,
			onLunge = nil, -- no lunge: the attacker stays in place
			onContact = function(_, contactIndex)
				remote:FireServer(i, contactIndex)
				SwordFX.Spawn(char, tool, clip, "Contact")
				SwordCombo.HitStop(char, clip.heavy and 0.1 or 0.055)
				if contactIndex == #clip.contact and current == mine then
					-- next hit a little after this one lands, so the combo flows without cutting the follow-through short
					chainAt = os.clock() + 0.16
					task.delay(0.16, function()
						if queued and current == mine and tool.Parent == char then attack() end
					end)
				end
			end,
			onEnd = function(chained)
				if current == mine then current = nil end
				-- chained into our own next hit: that hit keeps the slow walk and the combo count going. Anything else
				-- (clip finished, unequip, a Z/X/G skill taking over the body) must give the walk speed back, or the
				-- player stays slowed after casting a skill in the middle of a combo.
				if chained and ownChain then return end
				restoreSpeed(hum)
				lastEnd = os.clock()
				if i == count then step = 0 end
			end,
		}, style)
		ownChain = false
		current = mine
	end

	tool.Activated:Connect(attack)
	tool.Unequipped:Connect(function()
		local char = player.Character
		if char then SwordCombo.Stop(char) end
		setTrail(false)
		restoreSpeed(char and char:FindFirstChildOfClass("Humanoid"))
		queued, current = false, nil
	end)
end
