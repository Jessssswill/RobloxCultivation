-- Server: validasi hitbox combo pedang, damage lewat CombatCore.
-- v4 (2026-11-04): tiap pedang punya gaya sendiri (ReplicatedStorage.SwordCombo.STYLES). Damage, hitbox dan finisher
-- dibaca dari clip gaya itu: cepat (Lightning) = per hit kecil, berat (Dragon) = per hit besar, spin/aoe = hitbox keliling.
-- Module: each sword Tool calls it from a one-line ComboServer stub. opts.onHit(tool) runs on every accepted hit
-- (Spirit Sword uses it for its glow pulse).
return function(tool, opts)
	opts = opts or {}
	local Core = require(game:GetService("ServerScriptService"):WaitForChild("CombatCore"))
	local SwordCombo = require(game:GetService("ReplicatedStorage"):WaitForChild("SwordCombo"))
	local remote = tool:WaitForChild("Hit")
	local last, count = 0, 0
	local lastStep, stepHits = 0, 0
	remote.OnServerEvent:Connect(function(plr, step)
		local char = tool.Parent
		if typeof(step) ~= "number" or step % 1 ~= 0 or not char or plr.Character ~= char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local clip = SwordCombo.Get(step, SwordCombo.StyleOf(tool))
		if not clip then return end
		-- anti-spam (exploiters firing the heavy finisher over and over): a hit must be the next contact of the same clip,
		-- a later step of the combo, or a restart at 1, and can't arrive faster than half the real gap the clip allows
		-- (half, so lag and jitter never eat a legit hit).
		local now = os.clock()
		local same = step == lastStep and stepHits < #clip.contact
		local minGap
		if same then
			minGap = (clip.contact[stepHits + 1] - clip.contact[stepHits]) * 0.5
		elseif step == 1 or step > lastStep then
			minGap = (0.16 + clip.contact[1]) * 0.5 -- the client chains 0.16 s after the previous contact at the earliest
		else
			return
		end
		if now - last < math.max(0.08, minGap) then return end
		last = now
		if same then
			stepHits += 1
		else
			lastStep, stepHits = step, 1
		end
		if opts.onHit then opts.onHit(tool) end
		local heavy = clip.heavy == true
		local size, cf
		if clip.aoe then
			size = Vector3.new(15, 7, 15) -- spins hit all around
			cf = root.CFrame
		else
			size = heavy and Vector3.new(11, 7, 10) or Vector3.new(8, 6, 8)
			cf = root.CFrame * CFrame.new(0, 0, -size.Z / 2 + 0.5)
		end
		local mult = clip.dmg or 1
		local dmg = math.floor((heavy and 35 or 15) * mult + 0.5)
		local hitAny = false
		for _, m in Core.enemiesInBox(cf, size) do
			hitAny = true
			Core.dealDamage(plr, m, dmg, "combo", heavy and 55 or 6)
		end
		if hitAny then
			count += 1
			local d = Core.Data[plr]
			-- Sword Dao 1: tiap hit ke-5 keluar pedang bayangan
			if count % 5 == 0 and d and Core.daoLevel(d.SwordDao) >= 1 then
				task.spawn(Core.Skills.Crescent, plr, char, root, nil, true)
			end
		end
	end)
end
