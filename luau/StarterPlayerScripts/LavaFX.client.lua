-- Lava hidup (client, hanya di sekitar kamera supaya ringan): kerak lava retak mengapung & hanyut di atas magma menyala,
-- magma berdenyut, gelembung magma menggembung lalu meletup (cipratan, tetesan, asap, suara).
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer

local realm = workspace:WaitForChild("DemonRealm")
local lake = realm:WaitForChild("BloodLake")
local magma = {}
while true do      -- ubin lava baru ter-stream saat pemain mendekat: tunggu sampai ada
	table.clear(magma)
	for _, p in lake:GetChildren() do if p.Name == "LavaCrust" then table.insert(magma, p) end end
	if #magma > 0 then break end
	task.wait(1)
end
lake.ChildAdded:Connect(function(p) if p.Name == "LavaCrust" then table.insert(magma, p) end end)
local TOP = magma[1].Position.Y + magma[1].Size.Y / 2
local CENTER = Vector3.new(8000, TOP, 0)
local LIMIT = 1300          -- jangkauan lautan lava dari pusat
local RADIUS = 340          -- kerak & letupan hanya dibuat di sekitar kamera
local NRAFT = 110

local fx = Instance.new("Folder")
fx.Name = "LavaFXLocal"
fx.Parent = workspace

-- titik di lava terbuka? (sinar dari atas tidak mengenai pulau/jembatan sebelum mengenai lava)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = {fx}
local function openLava(x, z)
	local h = workspace:Raycast(Vector3.new(x, TOP + 300, z), Vector3.new(0, -320, 0), rp)
	return (not h) or h.Instance:IsDescendantOf(lake)   -- ubin lava tidak bisa di-raycast: tidak kena apa-apa = lava terbuka
end

-- ===== kerak mengapung
local rng = Random.new()
local rafts = {}
local function flow(x, z, t)   -- medan arus pelan berkelok
	local a = math.noise(x * 0.0021, z * 0.0021, t * 0.02) * 6.28
	return Vector3.new(math.cos(a), 0, math.sin(a)) * (2.2 + 1.6 * math.noise(z * 0.003, x * 0.003, 3.1))
end
local function newRaft(r, around)
	local a, d = rng:NextNumber(0, 6.283), rng:NextNumber(0.15, 1) ^ 0.5 * RADIUS
	r.x, r.z = around.X + math.cos(a) * d, around.Z + math.sin(a) * d
	r.rot = rng:NextNumber(0, 6.283)
	r.spin = rng:NextNumber(-0.05, 0.05)
	local s = rng:NextNumber(18, 62)
	r.part.Size = Vector3.new(s, rng:NextNumber(0.6, 1.4), s * rng:NextNumber(0.55, 1.1))
	r.part.Color = Color3.fromRGB(rng:NextInteger(70, 120), rng:NextInteger(26, 40), rng:NextInteger(14, 20))
	r.age, r.life = 0, rng:NextNumber(25, 60)
	r.part.Transparency = 1
end
for i = 1, NRAFT do
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.CrackedLava
	p.Parent = fx
	local r = {part = p}
	newRaft(r, CENTER)
	r.age = rng:NextNumber(0, r.life)
	rafts[i] = r
end

-- ===== suara letupan (pustaka APM berlisensi Roblox)
local popSnd = {}
for i = 1, 4 do
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://1837830050"
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance, s.RollOffMaxDistance = 20, 260
	popSnd[i] = s
end
local popIdx = 0

-- ===== letupan gelembung magma
local function burst(pos)
	local size = rng:NextNumber(4, 11)
	local dome = Instance.new("Part")
	dome.Shape = Enum.PartType.Ball
	dome.Anchored, dome.CanCollide, dome.CanQuery, dome.CanTouch, dome.CastShadow = true, false, false, false, false
	dome.Material, dome.Color = Enum.Material.Neon, Color3.fromRGB(255, 120, 30)
	dome.Size = Vector3.one * 0.5
	dome.CFrame = CFrame.new(pos)
	dome.Parent = fx
	local skin = dome:Clone()            -- kulit kerak gelap di atas gelembung
	skin.Material, skin.Color, skin.Transparency = Enum.Material.CrackedLava, Color3.fromRGB(90, 30, 14), 0.25
	skin.Parent = fx
	local grow = rng:NextNumber(0.5, 1.1)
	TS:Create(dome, TweenInfo.new(grow, Enum.EasingStyle.Sine), {Size = Vector3.one * size, CFrame = CFrame.new(pos + Vector3.new(0, size * 0.18, 0))}):Play()
	TS:Create(skin, TweenInfo.new(grow, Enum.EasingStyle.Sine), {Size = Vector3.one * size * 1.02, CFrame = CFrame.new(pos + Vector3.new(0, size * 0.2, 0)), Transparency = 0.7}):Play()
	task.delay(grow, function()
		skin:Destroy()
		TS:Create(dome, TweenInfo.new(0.18), {Size = Vector3.new(size * 1.6, 0.4, size * 1.6), Transparency = 1}):Play()
		Debris:AddItem(dome, 0.25)
		local at = Instance.new("Attachment")
		at.WorldPosition = pos + Vector3.new(0, 1, 0)
		at.Parent = workspace.Terrain
		local splash = Instance.new("ParticleEmitter")
		splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		splash.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 60, 10))
		splash.LightEmission = 1
		splash.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size * 0.18), NumberSequenceKeypoint.new(1, 0)})
		splash.Lifetime, splash.Speed = NumberRange.new(0.6, 1.4), NumberRange.new(size * 2, size * 4)
		splash.SpreadAngle, splash.Acceleration = Vector2.new(35, 35), Vector3.new(0, -60, 0)
		splash.EmissionDirection = Enum.NormalId.Top
		splash.Parent = at
		splash:Emit(math.floor(18 + size * 3))
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(90, 50, 40), Color3.fromRGB(30, 24, 22))
		smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size * 2.4)})
		smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
		smoke.Lifetime, smoke.Speed = NumberRange.new(2, 3.5), NumberRange.new(4, 9)
		smoke.SpreadAngle, smoke.EmissionDirection = Vector2.new(20, 20), Enum.NormalId.Top
		smoke.Parent = at
		smoke:Emit(5)
		for _ = 1, math.floor(3 + size / 3) do      -- tetesan magma melompat lalu jatuh
			local drop = Instance.new("Part")
			drop.Shape = Enum.PartType.Ball
			drop.Size = Vector3.one * rng:NextNumber(0.6, 1.6)
			drop.Material, drop.Color = Enum.Material.Neon, Color3.fromRGB(255, rng:NextInteger(90, 160), 30)
			drop.CanCollide, drop.CanQuery, drop.CanTouch, drop.CastShadow, drop.Massless = false, false, false, false, true
			drop.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
			drop.Parent = fx
			drop.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-1, 1) * size * 2.4, rng:NextNumber(1.2, 2.4) * size * 2.2, rng:NextNumber(-1, 1) * size * 2.4)
			Debris:AddItem(drop, 2.2)
		end
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 120, 40), size * 4, 3, false
		light.Parent = at
		TS:Create(light, TweenInfo.new(0.8), {Brightness = 0}):Play()
		popIdx = popIdx % #popSnd + 1
		local s = popSnd[popIdx]
		s.Parent = at
		s.PlaybackSpeed = rng:NextNumber(1.5, 2.3) - size * 0.05
		s.Volume = 0.25 + size * 0.04
		s.TimePosition = 0
		s:Play()
		task.delay(3.6, function() s.Parent = nil at:Destroy() end)
	end)
end

-- ===== loop
local t, nextPop, pulse = 0, 0, 0
Run.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	local cp = cam.CFrame.Position
	local inside = (Vector3.new(cp.X, 0, cp.Z) - Vector3.new(CENTER.X, 0, CENTER.Z)).Magnitude < LIMIT + 200 and math.abs(cp.Y - TOP) < 900
	fx.Parent = inside and workspace or nil
	if not inside then return end
	t += dt
	-- magma berdenyut pelan
	pulse += dt
	if pulse > 0.1 then
		pulse = 0
		local k = 0.5 + 0.5 * math.sin(t * 0.9)
		local c = Color3.fromRGB(math.floor(185 + 35 * k), math.floor(68 + 28 * k), math.floor(6 + 6 * k))
		for _, m in magma do m.Color = c end
	end
	-- kerak hanyut, berputar, muncul & tenggelam perlahan; yang jauh dari kamera dipindah ke dekat kamera
	local around = Vector3.new(cp.X, TOP, cp.Z)
	for _, r in rafts do
		local v = flow(r.x, r.z, t)
		r.x += v.X * dt
		r.z += v.Z * dt
		r.rot += r.spin * dt
		r.age += dt
		local far = (Vector3.new(r.x, TOP, r.z) - around).Magnitude > RADIUS * 1.1
		if r.age > r.life or far then newRaft(r, around) end
		local fade = math.min(1, r.age / 4, (r.life - r.age) / 4)
		r.part.Transparency = 1 - fade
		local bob = 0.15 * math.sin(t * 0.8 + r.x * 0.05)
		r.part.CFrame = CFrame.new(r.x, TOP + 0.1 + r.part.Size.Y * 0.3 + bob, r.z) * CFrame.Angles(0.01 * math.sin(t + r.z), r.rot, 0.01 * math.cos(t + r.x))
	end
	-- letupan acak di lava terbuka dekat kamera
	if t > nextPop then
		nextPop = t + rng:NextNumber(0.25, 0.9)
		for _ = 1, 4 do
			local a, d = rng:NextNumber(0, 6.283), rng:NextNumber(30, RADIUS * 0.8)
			local x, z = cp.X + math.cos(a) * d, cp.Z + math.sin(a) * d
			if (Vector3.new(x, 0, z) - Vector3.new(CENTER.X, 0, CENTER.Z)).Magnitude < LIMIT and openLava(x, z) then
				burst(Vector3.new(x, TOP, z))
				break
			end
		end
	end
end)
