-- Kuda Langit: panggil + naik (toggle). Panggil: pemain mengangkat tangan (kilau emas), kuda muncul dari awan emas
-- di kejauhan lalu berlari mendatangi, berhenti di samping, pemain melompat ke pelana; kuda dilas ke HumanoidRootPart,
-- HipHeight dinaikkan supaya kuku menyentuh tanah.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local CS = game:GetService("CollectionService")
local Core = require(script.Parent:WaitForChild("CombatCore"))
local FX = require(script.Parent:WaitForChild("MountFX"))   -- efek panggil setara wujud iblis
local remote = RS:WaitForChild("QiRemotes"):WaitForChild("Steed")
local TEMPLATE = game:GetService("ServerStorage"):WaitForChild("Mounts"):WaitForChild("CelestialSteed")
local SIT = 1.4           -- pusat HumanoidRootPart di atas titik pelana (studs, skala penunggang 1)
local HORSE_K = 0.72      -- kuda diperkecil & penunggang diperbesar supaya proporsinya seperti kuda & orang sungguhan
local RIDER_K = 1.25      -- (gumba kuda setinggi bahu orang, kaki penunggang bisa mengapit badan kuda)
local COOLDOWN = 1.5
local CALL = 0.8          -- lama gerakan memanggil sebelum kuda muncul
local RUN = 42            -- kecepatan lari kuda saat menyongsong (studs/detik)
local LEAP = 0.55         -- lama lompatan ke pelana (sambil berputar menghadap arah lari kuda)
local active, last, calling = {}, {}, {}

local function puff(pos)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency, a.Size = true, false, false, false, 1, Vector3.one
	a.Position = pos
	a.Parent = workspace
	local c = Instance.new("ParticleEmitter")
	c.Texture = "rbxasset://textures/particles/smoke_main.dds"
	c.Color = ColorSequence.new(Color3.fromRGB(255, 250, 240))
	c.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 11)})
	c.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	c.Lifetime, c.Speed, c.SpreadAngle, c.Drag = NumberRange.new(0.8, 1.4), NumberRange.new(8, 16), Vector2.new(180, 180), 4
	c.Rate = 0
	c.Parent = a
	c:Emit(28)
	local s = Instance.new("ParticleEmitter")
	s.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	s.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140))
	s.LightEmission, s.Size = 1, NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
	s.Lifetime, s.Speed, s.SpreadAngle, s.Rate = NumberRange.new(0.6, 1), NumberRange.new(10, 20), Vector2.new(180, 180), 0
	s.Parent = a
	s:Emit(40)
	Debris:AddItem(a, 2.5)
end

local function sound(parent, id, vol, speed)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume, s.PlaybackSpeed = vol, speed or 1
	s.RollOffMaxDistance = 260
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 6)
	return s
end

local function dismount(plr)
	local a = active[plr]
	if not a then return end
	active[plr] = nil
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	plr:SetAttribute("Mounted", nil)
	if hum then
		-- ScaleTo dulu (ia ikut mengalikan HipHeight), baru HipHeight asli dipasang: kalau terbalik karakter tenggelam
		if a.scale and char and char.Parent then pcall(function() char:ScaleTo(a.scale) end) end
		hum.HipHeight = a.hip
		hum.WalkSpeed = Core.baseSpeed(plr)   -- ScaleTo ikut mengalikan WalkSpeed: setel ulang dari CombatCore
	end
	if a.model and a.model.Parent then
		puff(a.model.RootPart.Position)
		a.model:Destroy()
	end
end

-- tanah di bawah titik (abaikan karakter & kuda)
local groundRP = RaycastParams.new()
groundRP.FilterType = Enum.RaycastFilterType.Exclude
local function groundY(pos, ignore, fallback)
	groundRP.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 25, 0), Vector3.new(0, -80, 0), groundRP)
	return hit and hit.Position.Y or fallback
end

local function flat(v)
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 1e-3 and v.Unit or Vector3.zAxis
end

local function mount(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) or hum.Health <= 0 or plr:GetAttribute("Meditating") then return end
	if plr:GetAttribute("DemonForm") or plr:GetAttribute("DemonCharging") then return end
	if plr:GetAttribute("Race") ~= "Mortal" then return end   -- kuda khusus ras Mortal
	calling[plr] = true
	hum.Sit = false
	-- 1) memanggil: berhenti, angkat tangan, kilau emas & denting
	plr:SetAttribute("SteedCalling", true)
	hum.WalkSpeed = 0
	local hand = char:FindFirstChild("RightHand") or hrp
	local at = Instance.new("Attachment")
	at.Parent = hand
	local glint = Instance.new("ParticleEmitter")
	glint.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glint.Color = ColorSequence.new(Color3.fromRGB(255, 235, 170), Color3.fromRGB(255, 190, 90))
	glint.LightEmission, glint.Rate = 1, 60
	glint.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
	glint.Lifetime, glint.Speed, glint.SpreadAngle = NumberRange.new(0.4, 0.8), NumberRange.new(2, 5), Vector2.new(180, 180)
	glint.Parent = at
	local gl = Instance.new("PointLight")
	gl.Color, gl.Range, gl.Brightness = Color3.fromRGB(255, 220, 150), 14, 2
	gl.Parent = at
	Debris:AddItem(at, CALL + 0.6)
	task.delay(CALL, function() glint.Enabled = false end)
	sound(hrp, "108306323478967", 1.1, 1.4)            -- denting panggilan
	FX.charge(hrp, "Steed", CALL + 0.9, hrp.Position - Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight, 0))
	task.wait(CALL)
	local function abort(m)
		calling[plr] = nil
		plr:SetAttribute("SteedCalling", nil)
		if m then m:Destroy() end
		if hum.Parent and hum.Health > 0 then hum.WalkSpeed = Core.baseSpeed(plr) end
	end
	if not (char.Parent and hum.Health > 0) then return abort() end
	-- 2) kuda muncul di depan dari awan emas lalu menyongsong lurus ke arah pemain
	local m = TEMPLATE:Clone()
	m:ScaleTo(m:GetScale() * HORSE_K)
	local rp = m.RootPart
	local rootBone = rp:FindFirstChild("Root")
	local body, neck = rp:FindFirstChild("Body", true), rp:FindFirstChild("Neck", true)
	local footOff = rp.Position.Y - (rootBone and rootBone.WorldPosition.Y or rp.Position.Y)
	local rot0 = rp.CFrame.Rotation
	local fwd0 = flat(neck.WorldPosition - body.WorldPosition)
	local function facing(d)   -- putaran RootPart supaya kepala kuda menghadap arah d
		return CFrame.lookAt(Vector3.zero, flat(d)) * CFrame.lookAt(Vector3.zero, fwd0):Inverse() * rot0
	end
	local look = flat(hrp.CFrame.LookVector)
	local dir = -look                                   -- arah lari kuda: menuju (lalu melewati) pemain
	local ignore = {m}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
	local rel, drop = m:GetAttribute("SeatRel"), m:GetAttribute("Drop") * HORSE_K
	rel = CFrame.new(rel.Position * HORSE_K) * rel.Rotation
	-- jarak datar titik pelana di depan pusat RootPart (sepanjang arah lari)
	local seatAhead = facing(dir):VectorToWorldSpace(rel.Position):Dot(dir)
	local meet = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)          -- titik pertemuan: tempat pemain berdiri
	local startXZ = meet - dir * (50.4 + seatAhead)   -- total panggil 2,0 dtk (= pedang = wujud iblis)
	local y0 = groundY(startXZ, ignore, hrp.Position.Y - 3)
	rp.Anchored = true
	rp.CFrame = CFrame.new(startXZ.X, y0 + footOff, startXZ.Z) * facing(dir)
	m.Name = "Steed_" .. plr.Name
	m:SetAttribute("Summoner", plr.UserId)
	m:SetAttribute("AnimSpeed", RUN)
	m:SetAttribute("PhysProfile", "Steed")               -- surai & ekor pakai fisika pegas (BeastHairPhysics)
	CS:AddTag(m, "HairPhysics")
	m.Parent = workspace
	puff(rp.Position)
	FX.impact(rp.Position, "Steed", 16, Vector3.new(rp.Position.X, y0, rp.Position.Z))
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 230, 160))
	trail.LightEmission, trail.Rate = 1, 40
	trail.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0)})
	trail.Lifetime, trail.Speed, trail.SpreadAngle = NumberRange.new(0.5, 1), NumberRange.new(1, 3), Vector2.new(60, 60)
	trail.Parent = rp
	sound(rp, "1845133529", 0.7, 1.6)                  -- derap gemuruh
	local pos = startXZ
	local function place()
		local gy = groundY(pos, ignore, y0)
		rp.CFrame = CFrame.new(pos.X, gy + footOff, pos.Z) * facing(dir)
	end
	-- lari sampai pelana tinggal RUN*LEAP dari pemain, lalu pemain melompat; kuda terus berlari selama lompatan
	local scale0, hip = char:GetScale(), hum.HipHeight
	local leapt = false
	local t0 = os.clock()
	local tLeap
	while true do
		local dt = RunService.Heartbeat:Wait()
		if not (char.Parent and hum.Health > 0 and m.Parent) then
			if leapt then
				pcall(function() char:ScaleTo(scale0) end)
				hum.HipHeight = hip
			end
			return abort(m)
		end
		pos += dir * RUN * dt
		place()
		local seatXZ = pos + dir * seatAhead
		local togo = (meet - seatXZ):Dot(dir)
		if not leapt and (togo <= RUN * LEAP or os.clock() - t0 > 3) then
			leapt = true
			tLeap = os.clock()
			-- 3) lompat: karakter diperbesar, HipHeight menunggang, terbang melengkung ke titik pelana yang akan dicapai kuda
			pcall(function() char:ScaleTo(scale0 * RIDER_K) end)
			hum.HipHeight = drop + SIT * RIDER_K - hrp.Size.Y / 2
			local futureXZ = pos + dir * math.max(0, togo)
			local gy = groundY(futureXZ + dir * seatAhead, ignore, y0)
			local futureRP = CFrame.new(futureXZ.X, gy + footOff, futureXZ.Z) * facing(dir)
			remote:FireClient(plr, "leap", futureRP * rel * CFrame.new(0, SIT * RIDER_K, 0), LEAP)
			sound(hrp, "107073250463751", 0.9, 1.1)            -- desir lompatan
		end
		if leapt and os.clock() - tLeap >= LEAP then break end
	end
	calling[plr] = nil
	plr:SetAttribute("SteedCalling", nil)
	trail.Enabled = false
	-- 4) mendarat di pelana sambil kuda masih berlari: las, lepas anchor, bawa momentum lari
	hrp.CFrame = rp.CFrame * rel * CFrame.new(0, SIT * RIDER_K, 0)
	rp.Anchored = false
	local w = Instance.new("WeldConstraint")
	w.Name = "RiderWeld"
	w.Part0, w.Part1 = hrp, rp
	w.Parent = rp
	hrp.AssemblyLinearVelocity = dir * RUN * 0.8
	m:SetAttribute("Rider", plr.UserId)          -- Rider dulu, baru Summoner dihapus (client tidak kehilangan rig animasi)
	m:SetAttribute("AnimSpeed", nil)
	m:SetAttribute("Summoner", nil)
	plr:SetAttribute("Mounted", true)
	hum.WalkSpeed = Core.baseSpeed(plr)       -- ScaleTo penunggang ikut mengalikan WalkSpeed: setel langsung
	active[plr] = {model = m, hip = hip, scale = scale0}
	puff(rp.Position)
	FX.impact(hrp.Position, "Steed", 28, Vector3.new(rp.Position.X, groundY(rp.Position, ignore, y0), rp.Position.Z))
end

remote.OnServerEvent:Connect(function(plr)
	if calling[plr] then return end
	if last[plr] and os.clock() - last[plr] < COOLDOWN then return end
	last[plr] = os.clock()
	if active[plr] then dismount(plr) else mount(plr) end
end)

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterRemoving:Connect(function()
		local a = active[plr]
		active[plr], calling[plr] = nil, nil
		plr:SetAttribute("Mounted", nil)
		plr:SetAttribute("SteedCalling", nil)
		if a and a.model then a.model:Destroy() end
	end)
end)
Players.PlayerRemoving:Connect(function(plr)
	local a = active[plr]
	if a and a.model then a.model:Destroy() end
	active[plr], last[plr], calling[plr] = nil, nil, nil
end)
-- turun otomatis saat meditasi
while true do
	for plr in active do
		if plr:GetAttribute("Meditating") then dismount(plr) end
	end
	task.wait(0.5)
end
