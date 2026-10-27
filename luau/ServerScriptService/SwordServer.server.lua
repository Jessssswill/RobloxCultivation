-- Pedang Terbang (ras Celestial): tombol T (QiRemotes.FlyingSword). Panggil: pemain membentuk segel jari (kilau biru),
-- pedang melesat turun dari langit melengkung sambil berputar, melayang rata di depan kaki, pemain melompat ke atasnya,
-- pedang dilas di bawah kaki & HipHeight dinaikkan: pedang melayang di ketinggian tetap, pemain bergerak seperti naik kuda
-- (tidak bisa naik/turun, kecepatan +40 sama dengan kuda & wujud iblis). Turun: pedang melesat pergi ke langit.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Core = require(script.Parent:WaitForChild("CombatCore"))
local FX = require(script.Parent:WaitForChild("MountFX"))   -- efek panggil setara wujud iblis
local remotes = RS:WaitForChild("QiRemotes")
local remote = remotes:WaitForChild("FlyingSword")
local TEMPLATE = game:GetService("ServerStorage"):WaitForChild("Mounts"):WaitForChild("FlyingSword")
local CALL = 0.6           -- lama segel jari sebelum pedang muncul (total panggil 2,0 dtk = kuda = wujud iblis)
local ARRIVE = 0.95        -- lama pedang melesat datang
local BOARD = 0.45         -- lama lompatan ke atas pedang
local COOLDOWN = 1.5
local HOVER = 1.4          -- tinggi pedang melayang di atas tanah (studs)
local active, busy, last = {}, {}, {}

local function banner(plr, text)
	local fx = remotes:FindFirstChild("Fx")
	if fx then pcall(function() fx:FireClient(plr, "Banner", text, Color3.fromRGB(140, 200, 255)) end) end
end

local function sound(parent, id, vol, speed)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume, s.PlaybackSpeed = vol, speed or 1
	s.RollOffMaxDistance = 300
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 6)
end

local function sparkle(pos, n, size)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency, a.Size = true, false, false, false, 1, Vector3.one
	a.Position = pos
	a.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255), Color3.fromRGB(90, 160, 255))
	e.LightEmission, e.Rate = 1, 0
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size or 1), NumberSequenceKeypoint.new(1, 0)})
	e.Lifetime, e.Speed, e.SpreadAngle = NumberRange.new(0.5, 1.1), NumberRange.new(8, 20), Vector2.new(180, 180)
	e.Parent = a
	e:Emit(n)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = Color3.fromRGB(150, 200, 255), 20, 3
	l.Parent = a
	game:GetService("TweenService"):Create(l, TweenInfo.new(0.8), {Brightness = 0}):Play()
	Debris:AddItem(a, 2)
end

local function flat(v)
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 1e-3 and v.Unit or Vector3.zAxis
end

local groundRP = RaycastParams.new()
groundRP.FilterType = Enum.RaycastFilterType.Exclude
local function groundY(pos, ignore, fallback)
	groundRP.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), groundRP)
	return hit and hit.Position.Y or fallback
end

-- letakkan pedang supaya titik pijaknya (atribut StandRel) berada di cf
local function place(m, cf)
	local rp = m.PrimaryPart
	local target = cf * m:GetAttribute("StandRel"):Inverse()
	m:PivotTo(target * rp.CFrame:Inverse() * m:GetPivot())
end

local function bezier(a, b, c, t)
	return a:Lerp(b, t):Lerp(b:Lerp(c, t), t)
end

local function dismiss(plr)
	local a = active[plr]
	active[plr] = nil
	plr:SetAttribute("SwordRiding", nil)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and a and a.hip then hum.HipHeight = a.hip end
	if hum and hum.Health > 0 then hum.WalkSpeed = Core.baseSpeed(plr) end
	local m = a and a.model
	if not (m and m.Parent) then return end
	local w = m.PrimaryPart:FindFirstChild("RiderWeld")
	if w then w:Destroy() end
	m.PrimaryPart.Anchored = true
	m:SetAttribute("Rider", nil)
	sparkle(m.PrimaryPart.Position, 25, 0.8)
	sound(m.PrimaryPart, "107073250463751", 0.9, 1.3)
	-- melesat pergi ke langit sambil berputar
	local start = m.PrimaryPart.CFrame * m:GetAttribute("StandRel")     -- bingkai titik pijak (maju = arah ujung pedang)
	local fwd = flat(start.LookVector)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.9 and m.Parent do
			local t = (os.clock() - t0) / 0.9
			local p = start.Position + fwd * 60 * t * t + Vector3.new(0, 70 * t * t, 0)
			place(m, CFrame.lookAt(p, p + (fwd + Vector3.new(0, 1.2 * t, 0)).Unit) * CFrame.Angles(0, 0, t * 12))
			RunService.Heartbeat:Wait()
		end
		m:Destroy()
	end)
end

local function summon(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) or hum.Health <= 0 then return end
	if plr:GetAttribute("Race") ~= "Celestial" then
		banner(plr, "Only the Celestial race can ride the sword")
		return
	end
	if plr:GetAttribute("Meditating") or plr:GetAttribute("Mounted") or plr:GetAttribute("DemonForm") then return end
	busy[plr] = true
	local function abort(m)
		busy[plr] = nil
		plr:SetAttribute("SwordCalling", nil)
		if m then m:Destroy() end
		if hum.Parent and hum.Health > 0 then hum.WalkSpeed = Core.baseSpeed(plr) end
	end
	-- 1) segel jari: berhenti, tangan terangkat, kilau biru & denting
	hum:UnequipTools()
	plr:SetAttribute("SwordCalling", true)
	hum.WalkSpeed = 0
	local hand = char:FindFirstChild("RightHand") or hrp
	local at = Instance.new("Attachment")
	at.Parent = hand
	local glint = Instance.new("ParticleEmitter")
	glint.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glint.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255), Color3.fromRGB(100, 170, 255))
	glint.LightEmission, glint.Rate = 1, 70
	glint.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
	glint.Lifetime, glint.Speed, glint.SpreadAngle = NumberRange.new(0.4, 0.8), NumberRange.new(2, 5), Vector2.new(180, 180)
	glint.Parent = at
	local gl = Instance.new("PointLight")
	gl.Color, gl.Range, gl.Brightness = Color3.fromRGB(150, 200, 255), 14, 2.5
	gl.Parent = at
	Debris:AddItem(at, CALL + ARRIVE)
	sound(hrp, "108306323478967", 1.1, 1.6)
	FX.charge(hrp, "Sword", CALL + ARRIVE * 0.9, hrp.Position - Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight, 0))
	task.wait(CALL)
	if not (char.Parent and hum.Health > 0) then return abort() end
	-- 2) pedang melesat turun dari langit (belakang-atas), melengkung, berputar, lalu melayang rata di depan kaki
	local m = TEMPLATE:Clone()
	m.Name = "Sword_" .. plr.Name
	local rp = m.PrimaryPart
	rp.Anchored = true
	local ignore = {m}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
	local look, right = flat(hrp.CFrame.LookVector), flat(hrp.CFrame.RightVector)
	local feet = hrp.Position.Y - hrp.Size.Y / 2 - hum.HipHeight
	local hoverXZ = hrp.Position + look * 3.5
	local H = Vector3.new(hoverXZ.X, math.max(feet, groundY(hoverXZ, ignore, feet)) + HOVER, hoverXZ.Z)
	local S = hrp.Position - look * 25 + right * 18 + Vector3.new(0, 55, 0)
	local C = H - look * 14 + Vector3.new(0, 22, 0)
	local endCF = CFrame.lookAt(H, H + look)
	m:SetAttribute("Summoner", plr.UserId)
	place(m, CFrame.lookAt(S, C))
	m.Parent = workspace
	sparkle(S, 30, 1.2)
	sound(rp, "107073250463751", 1.2, 0.8)
	local t0 = os.clock()
	while true do
		local dt = RunService.Heartbeat:Wait()
		if not (char.Parent and hum.Health > 0 and m.Parent) then return abort(m) end
		local t = math.min(1, (os.clock() - t0) / ARRIVE)
		local e = 1 - (1 - t) ^ 3
		local p = bezier(S, C, H, e)
		local tg = (bezier(S, C, H, math.min(1, e + 0.02)) - p)
		local travel = CFrame.lookAt(p, p + (tg.Magnitude > 1e-3 and tg.Unit or look)) * CFrame.Angles(0, 0, (1 - e) * 14)
		local k = math.clamp((e - 0.7) / 0.3, 0, 1)                       -- akhir lintasan: rata menghadap arah pemain
		place(m, travel:Lerp(CFrame.new(p) * endCF.Rotation, k * k * (3 - 2 * k)))
		if t >= 1 then break end
	end
	place(m, endCF)
	sparkle(H, 35, 1)
	FX.impact(H, "Sword", 20, H - Vector3.new(0, HOVER, 0))
	sound(rp, "9048840285", 0.7, 1.4)
	if not (char.Parent and hum.Health > 0) then return abort(m) end
	-- 3) melompat ke atas pedang
	local hip0 = hum.HipHeight
	local target = endCF * CFrame.new(0, hrp.Size.Y / 2 + hip0, 0)
	remote:FireClient(plr, "board", target, BOARD)
	sound(hrp, "107073250463751", 0.8, 1.2)
	task.wait(BOARD)
	busy[plr] = nil
	plr:SetAttribute("SwordCalling", nil)
	if not (char.Parent and hum.Health > 0 and m.Parent) then return abort(m) end
	hrp.CFrame = target
	hrp.AssemblyLinearVelocity = Vector3.zero
	place(m, hrp.CFrame * CFrame.new(0, -(hrp.Size.Y / 2 + hip0), 0))
	hum.HipHeight = hip0 + HOVER                                        -- melayang: kaki tetap di atas pedang
	local w = Instance.new("Weld")                                       -- Weld (bukan WeldConstraint): client memiringkan pedang di tangga lewat C0
	w.Name = "RiderWeld"
	w.Part0, w.Part1 = hrp, rp
	w.C0 = hrp.CFrame:ToObjectSpace(rp.CFrame)
	w.Parent = rp
	rp.Anchored = false
	m:SetAttribute("Rider", plr.UserId)
	m:SetAttribute("Summoner", nil)
	plr:SetAttribute("SwordRiding", true)
	hum.WalkSpeed = Core.baseSpeed(plr)                                  -- +40 (CombatCore), sama dengan kuda & wujud iblis
	active[plr] = {model = m, hip = hip0}
	sparkle(H, 20, 0.8)
	FX.impact(hrp.Position, "Sword", 28, H - Vector3.new(0, HOVER, 0))
end

remote.OnServerEvent:Connect(function(plr)
	if busy[plr] then return end
	if last[plr] and os.clock() - last[plr] < COOLDOWN then return end
	last[plr] = os.clock()
	if active[plr] then dismiss(plr) else summon(plr) end
end)

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterRemoving:Connect(function()
		local a = active[plr]
		active[plr], busy[plr] = nil, nil
		plr:SetAttribute("SwordRiding", nil)
		plr:SetAttribute("SwordCalling", nil)
		if a and a.model then a.model:Destroy() end
	end)
end)
Players.PlayerRemoving:Connect(function(plr)
	local a = active[plr]
	if a and a.model then a.model:Destroy() end
	active[plr], busy[plr], last[plr] = nil, nil, nil
end)
-- turun otomatis saat meditasi
while true do
	for plr in active do
		if plr:GetAttribute("Meditating") then dismiss(plr) end
	end
	task.wait(0.5)
end
