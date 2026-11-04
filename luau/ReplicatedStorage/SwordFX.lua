-- SwordFX: thick anime slash effects for the jian combo, coloured by the sword's Element attribute.
-- Reuses the Ink Brush slash pack (ReplicatedStorage.InkM1Assets: SlashMesh crescents + Slash flipbook emitters + GroundEffects)
-- so no new uploads are needed. Client-only; every client spawns it for every attacker (see SwordComboRelay).
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local SwordFX = {}

-- PERFORMANCE (will 2026-11-04: must stay light, especially on phones)
-- Quality tier per client: 3 = full, 2 = medium, 1 = low. Phones and low graphics settings get 1. Other players' attacks
-- get one tier less, and nothing at all beyond FAR studs. Player attribute FXQuality (1..3) overrides it (settings menu).
-- On top of that a rolling budget caps how many effect parts this client may create per 0.25 s, whatever happens.
local FAR, MID = 140, 70
SwordFX.BUDGET = {
	[1] = { steps = 1, ghostEvery = 0, shards = 0.3, streaks = 0.5, ring = 10, bolts = 0.4, flip = 0.5, hz = 30, burst = 60, particles = 0.45 },
	[2] = { steps = 3, ghostEvery = 6, shards = 0.6, streaks = 0.75, ring = 18, bolts = 0.7, flip = 0.8, hz = 45, burst = 150, particles = 0.7 },
	[3] = { steps = 6, ghostEvery = 3, shards = 1, streaks = 1, ring = 28, bolts = 1, flip = 1, hz = 60, burst = 320, particles = 1 },
}
local tierCache, tierAt = 3, -math.huge
local function deviceTier()
	if os.clock() - tierAt < 5 then return tierCache end
	tierAt = os.clock()
	local lp = Players.LocalPlayer
	local o = lp and lp:GetAttribute("FXQuality")
	if typeof(o) == "number" then
		tierCache = math.clamp(math.floor(o), 1, 3)
		return tierCache
	end
	local mobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
	local ok, q = pcall(function() return UserSettings():GetService("UserGameSettings").SavedQualityLevel end)
	local lvl = (ok and q) and q.Value or 0 -- 0 = Automatic
	if lvl == 0 then
		tierCache = mobile and 1 or 3
	elseif lvl <= 3 then
		tierCache = 1
	elseif lvl <= 6 then
		tierCache = 2
	else
		tierCache = mobile and 2 or 3
	end
	return tierCache
end
-- 0 = draw nothing
function SwordFX.TierFor(char)
	local tier = deviceTier()
	if Players.LocalPlayer and Players.LocalPlayer.Character == char then return tier end
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not (root and cam) then return 0 end
	local d = (root.Position - cam.CFrame.Position).Magnitude
	if d > FAR then return 0 end
	if d > MID then return 1 end
	return math.max(1, tier - 1)
end
local spent, windowAt = 0, 0
local function allow(n, tier)
	local now = os.clock()
	if now - windowAt > 0.25 then windowAt, spent = now, 0 end
	if spent + n > SwordFX.BUDGET[tier].burst then return false end
	spent += n
	return true
end
local function scaled(n, k) return math.max(1, math.floor(n * k + 0.5)) end

-- workspace attribute SwordFXSlow (debug only) stretches every effect so it can be inspected frame by frame
local function slow() return workspace:GetAttribute("SwordFXSlow") or 1 end
local function TI(t, ...) return TweenInfo.new(t * slow(), ...) end

SwordFX.PALETTE = {
	Thunder = { core = Color3.fromRGB(255, 252, 230), main = Color3.fromRGB(255, 205, 70), deep = Color3.fromRGB(255, 140, 30) },
	Ice = { core = Color3.fromRGB(240, 250, 255), main = Color3.fromRGB(120, 200, 255), deep = Color3.fromRGB(40, 110, 255) },
	Lotus = { core = Color3.fromRGB(255, 245, 250), main = Color3.fromRGB(255, 140, 190), deep = Color3.fromRGB(90, 220, 160) },
	Jade = { core = Color3.fromRGB(235, 255, 240), main = Color3.fromRGB(80, 235, 150), deep = Color3.fromRGB(20, 140, 90) },
	Fire = { core = Color3.fromRGB(255, 245, 220), main = Color3.fromRGB(255, 120, 40), deep = Color3.fromRGB(200, 30, 20) },
	None = { core = Color3.fromRGB(255, 255, 255), main = Color3.fromRGB(180, 215, 255), deep = Color3.fromRGB(90, 140, 255) },
}

local pack = RS:WaitForChild("InkM1Assets", 10)
local slashSrc = pack and ((pack:FindFirstChild("InkSlash") and pack.InkSlash:FindFirstChild("SlashMesh")) or pack:FindFirstChild("Smears"))
local refRoot = pack and pack:FindFirstChild("ReferenceRig") and pack.ReferenceRig:FindFirstChild("HumanoidRootPart")

local function palette(tool)
	return SwordFX.PALETTE[tool and tool:GetAttribute("Element") or "None"] or SwordFX.PALETTE.None
end

local function bare(p)
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	return p
end

-- ---------------------------------------------------------------- element signatures (particles)
-- Self-made textures (assets/VFX/textures_v1), uploaded with will's OK on 2026-11-01; same ids as WeaponSkillClient.
local VTX = {
	lightning = "rbxassetid://85766794891773", glow = "rbxassetid://86794260657796", flare = "rbxassetid://74917717176224",
	shock = "rbxassetid://120638941464407", smoke = "rbxassetid://128189018436398", frost = "rbxassetid://106494765248742",
	snow = "rbxassetid://132476517971091", petal = "rbxassetid://115963999420447", lotus = "rbxassetid://125562162597738",
	aura = "rbxassetid://103751465846390", crescent = "rbxassetid://116325702137675", swirl = "rbxassetid://74831198929905",
	fire = "rbxasset://textures/particles/fire_main.dds", spark = "rbxasset://textures/particles/sparkles_main.dds",
}
local G4 = Enum.ParticleFlipbookLayout.Grid4x4
local FLAT = Enum.ParticleOrientation.VelocityPerpendicular -- with a tiny upward speed: lies flat on the ground
local function NSK(t)
	local ks = {}
	for _, p in ipairs(t) do table.insert(ks, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(ks)
end
local FADE = NSK({ { 0, 0 }, { 0.7, 0.35 }, { 1, 1 } })
local function NR(a, b) return NumberRange.new(a, b or a) end
local function CS(a, b) return ColorSequence.new(a, b or a) end

local function folderFx()
	local f = Instance.new("Folder")
	f.Name = "SwordFX"
	f.Parent = workspace
	Debris:AddItem(f, 3 * slow())
	return f
end

-- GPU particle burst from a hidden host part. One part per burst, whatever the particle count, so this is the
-- cheap way to make an effect thick (the old look used one part per streak/shard).
local function burst(f, cf, n, props)
	if n <= 0 then return end
	local host = bare(Instance.new("Part"))
	host.Transparency, host.Size, host.CFrame = 1, Vector3.new(0.2, 0.2, 0.2), cf
	host.Parent = f
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightInfluence = 0
	e.Speed = NR(0)
	e.Transparency = FADE
	for k, v in pairs(props) do e[k] = v end
	e.Parent = host
	e:Emit(n)
end

local function groundBelow(pos, ignore)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -9, 0), ray)
	return hit and hit.Position + Vector3.new(0, 0.12, 0)
end

-- impact signature per element. pos = impact point, k = particle tier factor
local SIG = {}
SIG.Thunder = function(f, pos, pal, heavy, k)
	burst(f, CFrame.new(pos), math.max(2, math.floor((heavy and 8 or 5) * k)), { Texture = VTX.lightning, FlipbookLayout = G4,
		FlipbookMode = Enum.ParticleFlipbookMode.Random, Color = CS(pal.core, pal.main), LightEmission = 1, Brightness = 3,
		Size = NumberSequence.new(heavy and 6 or 4), Lifetime = NR(0.1, 0.2), Rotation = NR(0, 360), Speed = NR(2, 6), SpreadAngle = Vector2.new(180, 180) })
	burst(f, CFrame.new(pos), 1, { Texture = VTX.shock, Color = CS(pal.main), LightEmission = 1, Brightness = 2,
		Size = NSK({ { 0, 0.5 }, { 1, heavy and 12 or 8 } }), Transparency = NSK({ { 0, 0.05 }, { 1, 1 } }), Lifetime = NR(0.22) })
	burst(f, CFrame.new(pos), 1, { Texture = VTX.flare, Color = CS(pal.core), LightEmission = 1, Brightness = 4,
		Size = NSK({ { 0, heavy and 9 or 6 }, { 1, 0 } }), Lifetime = NR(0.16) })
end
SIG.Ice = function(f, pos, pal, heavy, k, ground)
	burst(f, CFrame.new(pos), math.max(3, math.floor((heavy and 18 or 10) * k)), { Texture = VTX.snow, Color = CS(pal.core, pal.main),
		LightEmission = 0.8, Size = NSK({ { 0, 0.55 }, { 1, 0.15 } }), Speed = NR(6, 14), SpreadAngle = Vector2.new(180, 180),
		Drag = 3, Acceleration = Vector3.new(0, -6, 0), Rotation = NR(0, 360), RotSpeed = NR(-220, 220), Lifetime = NR(0.5, 0.9) })
	burst(f, CFrame.new(pos), 1, { Texture = VTX.crescent, Color = CS(pal.core, pal.main), LightEmission = 1, Brightness = 2,
		Size = NSK({ { 0, heavy and 7 or 5 }, { 1, heavy and 10 or 7 } }), Rotation = NR(math.random(0, 360)), Lifetime = NR(0.2) })
	if ground then
		burst(f, CFrame.new(ground), 1, { Texture = VTX.frost, Color = CS(pal.core, pal.main), LightEmission = 0.6, Orientation = FLAT,
			Speed = NR(0.01), Size = NSK({ { 0, 1 }, { 0.25, heavy and 11 or 7 }, { 1, heavy and 12 or 8 } }),
			Transparency = NSK({ { 0, 0.15 }, { 0.6, 0.35 }, { 1, 1 } }), Rotation = NR(0, 360), Lifetime = NR(0.7) })
	end
end
SIG.Lotus = function(f, pos, pal, heavy, k)
	burst(f, CFrame.new(pos), math.max(4, math.floor((heavy and 20 or 11) * k)), { Texture = VTX.petal,
		Color = CS(Color3.fromRGB(255, 236, 246), pal.main), LightEmission = 0.35, Size = NSK({ { 0, 0.7 }, { 1, 0.35 } }),
		Speed = NR(5, 12), SpreadAngle = Vector2.new(180, 180), Drag = 2.5, Acceleration = Vector3.new(0, -2, 0),
		Rotation = NR(0, 360), RotSpeed = NR(-180, 180), Lifetime = NR(0.8, 1.4) })
	burst(f, CFrame.new(pos), 1, { Texture = VTX.lotus, Color = CS(Color3.new(1, 1, 1)), LightEmission = 0.4,
		Size = NSK({ { 0, 0.5 }, { 0.35, heavy and 7 or 5 }, { 1, heavy and 8 or 5.5 } }),
		Transparency = NSK({ { 0, 0.1 }, { 0.6, 0.2 }, { 1, 1 } }), RotSpeed = NR(40), Lifetime = NR(0.45) })
end
SIG.Jade = function(f, pos, pal, heavy, k)
	burst(f, CFrame.new(pos), 1, { Texture = VTX.swirl, Color = CS(pal.core, pal.main), LightEmission = 1, Brightness = 2,
		Size = NSK({ { 0, 1 }, { 1, heavy and 11 or 7 } }), RotSpeed = NR(-320), Lifetime = NR(0.35) })
	burst(f, CFrame.new(pos), 1, { Texture = VTX.shock, Color = CS(pal.main), LightEmission = 1,
		Size = NSK({ { 0, 0.5 }, { 1, heavy and 13 or 8 } }), Transparency = NSK({ { 0, 0.05 }, { 1, 1 } }), Lifetime = NR(0.25) })
	burst(f, CFrame.new(pos), math.max(3, math.floor((heavy and 16 or 9) * k)), { Texture = VTX.glow, Color = CS(pal.core, pal.main),
		LightEmission = 1, Size = NSK({ { 0, 0.8 }, { 1, 0 } }), Speed = NR(5, 12), SpreadAngle = Vector2.new(180, 180), Drag = 2,
		Lifetime = NR(0.3, 0.6) })
end
SIG.Fire = function(f, pos, pal, heavy, k, ground)
	burst(f, CFrame.new(pos), math.max(2, math.floor((heavy and 9 or 5) * k)), { Texture = VTX.aura, FlipbookLayout = G4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = CS(Color3.fromRGB(255, 225, 130), Color3.fromRGB(255, 70, 20)),
		LightEmission = 1, Brightness = 2, Size = NSK({ { 0, heavy and 4 or 3 }, { 1, heavy and 7 or 5 } }), Speed = NR(2, 6),
		SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, 6, 0), Rotation = NR(-25, 25), Lifetime = NR(0.35, 0.5) })
	burst(f, CFrame.new(pos), math.max(4, math.floor((heavy and 20 or 11) * k)), { Texture = VTX.fire,
		Color = CS(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 60, 10)), LightEmission = 1, Size = NSK({ { 0, 0.4 }, { 1, 0 } }),
		Speed = NR(8, 16), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 10, 0), Drag = 2, Lifetime = NR(0.4, 0.8) })
	if k >= 0.7 then
		burst(f, CFrame.new(ground or pos), heavy and 3 or 2, { Texture = VTX.smoke, FlipbookLayout = G4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = CS(Color3.fromRGB(60, 50, 45)), LightEmission = 0,
			Size = NSK({ { 0, 2.5 }, { 1, 5.5 } }), Transparency = NSK({ { 0, 0.45 }, { 1, 1 } }), Speed = NR(1, 2.5),
			SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, 2, 0), Lifetime = NR(0.6, 0.8) })
	end
end
SIG.None = function(f, pos, pal, heavy, k)
	burst(f, CFrame.new(pos), 1, { Texture = VTX.flare, Color = CS(pal.core), LightEmission = 1, Brightness = 3,
		Size = NSK({ { 0, heavy and 7 or 5 }, { 1, 0 } }), Lifetime = NR(0.16) })
end

-- particles that stream off the blade tip while it swings (rate per second at full quality)
local TIP = {
	Thunder = { Texture = VTX.lightning, FlipbookLayout = G4, FlipbookMode = Enum.ParticleFlipbookMode.Random, LightEmission = 1,
		Brightness = 2, Size = NumberSequence.new(1.3), Lifetime = NR(0.08, 0.14), Rotation = NR(0, 360), Rate = 28 },
	Ice = { Texture = VTX.snow, LightEmission = 0.8, Size = NSK({ { 0, 0.4 }, { 1, 0.1 } }), Lifetime = NR(0.4, 0.7), Speed = NR(0.5, 2),
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -4, 0), Rotation = NR(0, 360), RotSpeed = NR(-200, 200), Rate = 30 },
	Lotus = { Texture = VTX.petal, LightEmission = 0.35, Size = NSK({ { 0, 0.5 }, { 1, 0.3 } }), Lifetime = NR(0.6, 1), Speed = NR(0.5, 2),
		SpreadAngle = Vector2.new(180, 180), Drag = 1, Acceleration = Vector3.new(0, -1.5, 0), Rotation = NR(0, 360), RotSpeed = NR(-160, 160), Rate = 22 },
	Jade = { Texture = VTX.glow, LightEmission = 1, Size = NSK({ { 0, 0.6 }, { 1, 0 } }), Lifetime = NR(0.25, 0.4), Rate = 35 },
	Fire = { Texture = VTX.fire, LightEmission = 1, Size = NSK({ { 0, 0.9 }, { 1, 0.2 } }), Lifetime = NR(0.25, 0.45), Speed = NR(1, 3),
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 8, 0), Rate = 45 },
	None = { Texture = VTX.spark, LightEmission = 1, Size = NumberSequence.new(0.4), Lifetime = NR(0.2, 0.3), Rate = 20 },
}

-- crescent slash meshes from the pack, rolled into the swing plane, two layers (white core + element colour)
local function crescent(f, root, pal, roll, scale, dur)
	local src = slashSrc
	if not (src and refRoot) then return end
	local pivot = root.CFrame * CFrame.new(0, 0.6, -1.2)
	local spin = pivot * CFrame.Angles(0, 0, math.rad(roll)) * pivot:Inverse()
	local delta = root.CFrame * refRoot.CFrame:Inverse()
	for li, m in ipairs(src:GetChildren()) do
		local s, e = m:FindFirstChild("Start"), m:FindFirstChild("End")
		if s and e then
			for layer = 1, 2 do
				local p = bare(s:Clone())
				for _, d in ipairs(p:GetChildren()) do d:Destroy() end
				local k = scale * (layer == 1 and 0.92 or 1.06)
				p.Material = Enum.Material.Neon
				p.Color = layer == 1 and pal.core or (li == 2 and pal.deep or pal.main)
				p.Transparency = layer == 1 and 0.45 or 0.05
				p.Size = s.Size * k
				p.CFrame = spin * delta * s.CFrame
				p.Parent = f
				TweenService:Create(p, TI(dur * (layer == 1 and 0.8 or 1), Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = e.Size * k, CFrame = spin * delta * e.CFrame, Transparency = 1,
				}):Play()
			end
		end
	end
end

-- flipbook slash / impact emitters from the pack, recoloured
local SKIP_WORDS = { "glow", "filler", "fog", "smoke", "ink", "dark", "plume", "billow", "water", "splash", "shaded" }
local function SKIP(name)
	name = string.lower(name)
	for _, w in ipairs(SKIP_WORDS) do
		if string.find(name, w, 1, true) then return true end
	end
	return false
end

local function flipbooks(f, cf, pal, mult, groundToo)
	local sizeK = groundToo and 0.75 or 0.6
	if not pack then return end
	local host = bare(Instance.new("Part"))
	host.Transparency, host.Size, host.CFrame = 1, Vector3.one, cf
	host.Parent = f
	local function from(container)
		for _, e in ipairs(container:GetDescendants()) do
			-- the ink pack's soft glows / smoke / ink blots turn into flat white blobs once recoloured, so only the sharp shapes are kept
			if e:IsA("ParticleEmitter") and not SKIP(e.Name) then
				local c = e:Clone()
				c.Enabled = false
				c.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, pal.core), ColorSequenceKeypoint.new(0.12, pal.main), ColorSequenceKeypoint.new(1, pal.deep) })
				c.LightEmission = 1 -- additive: the pack's black ink outlines vanish, only the light stays
				c.LightInfluence = 0
				c.Brightness = 1.2
				local ks = {}
				for _, k in ipairs(c.Size.Keypoints) do table.insert(ks, NumberSequenceKeypoint.new(k.Time, k.Value * sizeK, k.Envelope * sizeK)) end
				c.Size = NumberSequence.new(ks)
				c.TimeScale = c.TimeScale / slow()
				c.Parent = host
				c:Emit(math.ceil((e:GetAttribute("EmitCount") or 1) * mult))
			end
		end
	end
	local ink = pack:FindFirstChild("InkSlash")
	local slash = ink and ink:FindFirstChild("Slash")
	if slash then from(slash) end
	if groundToo and ink then -- (pack.InkSlash would throw if the pack was moved/renamed)
		local g = ink:FindFirstChild("GroundEffects")
		if g then from(g) end
	end
end

local function shards(f, pos, dir, pal, n, speed)
	for _ = 1, n do
		local p = bare(Instance.new("Part"))
		p.Material = Enum.Material.Neon
		p.Color = math.random() < 0.4 and pal.core or pal.main
		p.Size = Vector3.new(0.12, 0.12, math.random() * 1.4 + 0.6)
		local d = (dir + Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5) * 1.6).Unit
		p.CFrame = CFrame.lookAt(pos, pos + d)
		p.Parent = f
		local t = 0.22 + math.random() * 0.15
		TweenService:Create(p, TI(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(pos + d * speed * t, pos + d * (speed * t + 1)), Size = Vector3.new(0.02, 0.02, 0.2), Transparency = 1,
		}):Play()
	end
end

local function bolts(f, pos, pal, n)
	for _ = 1, n do
		local a = pos
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.6 - 0.2, math.random() - 0.5).Unit
		for _ = 1, 5 do
			local b = a + (dir + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.9).Unit * (0.6 + math.random() * 0.8)
			local p = bare(Instance.new("Part"))
			p.Material = Enum.Material.Neon
			p.Color = pal.main
			p.Size = Vector3.new(0.14, 0.14, (b - a).Magnitude)
			p.CFrame = CFrame.lookAt((a + b) / 2, b)
			p.Parent = f
			TweenService:Create(p, TI(0.18), { Transparency = 1, Size = p.Size * Vector3.new(0.2, 0.2, 1) }):Play()
			a = b
		end
	end
end

-- impact: small hot core + a starburst of thin light streaks facing the camera (no solid disks blocking the view)
local function flash(f, pos, pal, size, streakK)
	local ball = bare(Instance.new("Part"))
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = pal.main
	ball.Transparency = 0.25
	ball.Size = Vector3.one * 0.6
	ball.CFrame = CFrame.new(pos)
	ball.Parent = f
	TweenService:Create(ball, TI(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size * 0.35, Transparency = 1 }):Play()
	local cam = workspace.CurrentCamera
	local face = CFrame.lookAt(pos, cam.CFrame.Position)
	local n = scaled(6 + size, streakK or 1)
	for i = 1, n do
		local ang = (i / n) * math.pi * 2 + math.random() * 0.3
		local len = size * (0.35 + math.random() * 0.45)
		local dirCF = face * CFrame.Angles(0, 0, ang)
		local p = bare(Instance.new("Part"))
		p.Material = Enum.Material.Neon
		p.Color = i % 3 == 0 and pal.core or (i % 3 == 1 and pal.main or pal.deep)
		p.Size = Vector3.new(0.16, 0.6, 0.05)
		p.CFrame = dirCF * CFrame.new(0, 0.6, 0)
		p.Parent = f
		TweenService:Create(p, TI(0.16 + math.random() * 0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.03, len, 0.03), CFrame = dirCF * CFrame.new(0, len * 0.75, 0), Transparency = 1,
		}):Play()
	end
end

-- ground shockwave: a ring of glowing blades racing outward along the floor (hollow, so the player still sees the fight)
local function groundRing(f, root, pal, size, n)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { root.Parent, f }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), ray)
	if not hit then return end
	local c = hit.Position + Vector3.new(0, 0.1, 0)
	n = n or 28
	for i = 1, n do
		local ang = (i / n) * math.pi * 2
		local base = CFrame.new(c) * CFrame.Angles(0, ang, 0)
		local p = bare(Instance.new("Part"))
		p.Material = Enum.Material.Neon
		p.Color = i % 2 == 0 and pal.main or pal.deep
		p.Transparency = 0.1
		p.Size = Vector3.new(0.9, 0.12, 0.35)
		p.CFrame = base * CFrame.new(0, 0, -1.2)
		p.Parent = f
		TweenService:Create(p, TI(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			CFrame = base * CFrame.new(0, 0, -size * 0.5), Size = Vector3.new(size * 0.12, 0.04, 0.12), Transparency = 1,
		}):Play()
	end
end

-- blade sweep: every frame while the sword's trail is on, a glowing sheet is laid between the previous and the current
-- position of the blade (tip bright, toward the guard faint), so the slash is literally the path the sword cut
local RunService = game:GetService("RunService")
local function bladeOf(tool)
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle then return end
	local best, bestMag
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") and d ~= handle and d.Transparency < 1 then
			local m = d.Size.Magnitude
			if not bestMag or m > bestMag then best, bestMag = d, m end
		end
	end
	best = best or handle
	local sz = best.Size
	local axis = (sz.X >= sz.Y and sz.X >= sz.Z) and Vector3.xAxis or ((sz.Y >= sz.Z) and Vector3.yAxis or Vector3.zAxis)
	local half = math.max(sz.X, sz.Y, sz.Z) / 2
	local a, b = best.CFrame:PointToWorldSpace(axis * half), best.CFrame:PointToWorldSpace(-axis * half)
	if (a - handle.Position).Magnitude < (b - handle.Position).Magnitude then axis = -axis end
	return best, axis, half
end

local function sheet(f, p0, p1, q0, q1, color, transp, life)
	-- quad p0-p1 (old edge) to q0-q1 (new edge) approximated by one thin plate
	local mid = (p0 + p1 + q0 + q1) / 4
	local along = ((p1 - p0) + (q1 - q0)) / 2
	local across = ((q0 - p0) + (q1 - p1)) / 2
	if along.Magnitude < 0.05 or across.Magnitude < 0.02 then return end
	local n = along:Cross(across)
	if n.Magnitude < 1e-4 then return end
	local cf = CFrame.fromMatrix(mid, along.Unit, n.Unit)
	local p = bare(Instance.new("Part"))
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transp
	p.Size = Vector3.new(along.Magnitude, 0.04, across.Magnitude + 0.18)
	p.CFrame = cf
	p.Parent = f
	TweenService:Create(p, TI(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1, Size = Vector3.new(along.Magnitude * 1.02, 0.01, across.Magnitude + 0.18),
	}):Play()
end

-- four-point anime glint (luxury sparkle) facing the camera
local function glint(f, pos, pal, size)
	local cam = workspace.CurrentCamera
	local face = CFrame.lookAt(pos, cam.CFrame.Position)
	for i = 0, 3 do
		local p = bare(Instance.new("Part"))
		p.Material = Enum.Material.Neon
		p.Color = i % 2 == 0 and pal.core or pal.main
		p.Size = Vector3.new(0.12, 0.1, 0.02)
		p.CFrame = face * CFrame.Angles(0, 0, math.rad(i * 45))
		p.Parent = f
		local len = (i % 2 == 0) and size or size * 0.55
		TweenService:Create(p, TI(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, len, 0.02) }):Play()
		task.delay(0.09 * slow(), function()
			if p.Parent then
				TweenService:Create(p, TI(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.02, len * 1.2, 0.02), Transparency = 1 }):Play()
			end
		end)
	end
end

local sweeping = {}
-- low tier: two bands instead of three (one third fewer parts, same read)
local BANDS_LOW = {
	{ 0.0, 0.75, "main", 0.35, 0.8 },
	{ 0.75, 1.0, "core", 0.05, 0.85 },
}
-- blade bands from guard (0) to tip (1): {from, to, colour, transparency, life multiplier}
local BANDS = {
	{ 0.0, 0.4, "deep", 0.65, 0.6 },
	{ 0.4, 0.8, "main", 0.2, 1 },
	{ 0.8, 1.0, "core", 0.05, 0.85 },
}
local function sweep(char, tool, pal, heavy, element, tier, window)
	if sweeping[tool] then return end
	local B = SwordFX.BUDGET[tier]
	local bands = tier == 1 and BANDS_LOW or BANDS
	local lastLay = 0
	local part, axis, half = bladeOf(tool)
	if not part then return end
	local trails = {}
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("Trail") then table.insert(trails, d) end
	end
	-- the sweep follows the sword's Trail on/off; a sword without a Trail falls back to the clip's trail window
	local hasTrail = #trails > 0
	window = (window or 0.25) / math.max(0.05, workspace:GetAttribute("SwordComboTimeScale") or 1)
	local f = folderFx()
	local function edge()
		local tip = part.CFrame:PointToWorldSpace(axis * half * 1.08)
		local base = part.CFrame:PointToWorldSpace(-axis * half * 0.25)
		return base, tip
	end
	local b0, t0 = edge()
	local started = os.clock()
	local frame = 0
	local ghostParts = {}
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("MeshPart") and d.Transparency < 0.5 and d.Size.Magnitude > 1 then table.insert(ghostParts, d) end
	end
	-- element particles streaming off the tip while the blade moves (one emitter, rate scaled by the quality tier)
	local tipAtt = Instance.new("Attachment")
	tipAtt.Name = "SwordFXTip"
	tipAtt.Position = axis * half * 0.92
	tipAtt.Parent = part
	local tipEm = Instance.new("ParticleEmitter")
	tipEm.LightInfluence = 0
	tipEm.Speed = NR(0)
	tipEm.Transparency = FADE
	local tipStyle = TIP[element or "None"] or TIP.None
	for k, v in pairs(tipStyle) do tipEm[k] = v end
	tipEm.Rate = tipStyle.Rate * B.particles
	tipEm.Color = CS(pal.core, pal.main)
	if element == "Fire" then tipEm.Color = CS(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 60, 10)) end
	if element == "Lotus" then tipEm.Color = CS(Color3.fromRGB(255, 236, 246), pal.main) end
	tipEm.Parent = tipAtt
	local conn
	sweeping[tool] = true
	conn = RunService.RenderStepped:Connect(function()
		local on = false
		for _, t in ipairs(trails) do if t.Enabled then on = true break end end
		local age = os.clock() - started
		local over = if hasTrail then (age > 0.05 and not on) else age > window
		if not part.Parent or not char.Parent or over or age > 1.2 then
			conn:Disconnect()
			sweeping[tool] = nil
			tipEm.Enabled = false
			Debris:AddItem(tipAtt, 1.5)
			return
		end
		-- lay sheets at most B.hz times a second (a 144 Hz screen must not make 2.4x more parts than a 60 Hz one)
		local now = os.clock()
		if now - lastLay < 1 / B.hz then return end
		lastLay = now
		local b1, t1 = edge()
		local life = heavy and 0.3 or 0.22
		-- fast swings move the tip a long way per frame: cut the gap into thin slices and the blade into bands,
		-- so the sheet follows the real curved path instead of showing big flat rectangles
		local steps = math.clamp(math.ceil((t1 - t0).Magnitude / 0.6), 1, B.steps)
		if not allow(steps * #bands, tier) then b0, t0 = b1, t1 return end
		for k = 1, steps do
			local u0, u1 = (k - 1) / steps, k / steps
			local pb0, pt0 = b0:Lerp(b1, u0), t0:Lerp(t1, u0)
			local pb1, pt1 = b0:Lerp(b1, u1), t0:Lerp(t1, u1)
			for _, band in ipairs(bands) do
				sheet(f, pb0:Lerp(pt0, band[1]), pb0:Lerp(pt0, band[2]), pb1:Lerp(pt1, band[1]), pb1:Lerp(pt1, band[2]),
					pal[band[3]], band[4], life * band[5] * (0.75 + 0.25 * u1))
			end
		end
		if tier >= 2 then
			if element == "Thunder" and math.random() < 0.35 and allow(5, tier) then bolts(f, t1, pal, 1) end
			if (element == "Ice" or element == "Jade" or element == "Lotus") and (t1 - t0).Magnitude > 0.01 and math.random() < 0.5 then
				shards(f, t1, (t1 - t0).Unit, pal, 1, 10)
			end
			if element == "Fire" and math.random() < 0.6 then shards(f, t1, Vector3.yAxis, pal, 2, 6) end
		end
		-- ghost blades: shimmering copies of the sword left along the cut (afterimages)
		frame += 1
		if B.ghostEvery > 0 and frame % B.ghostEvery == 1 and allow(#ghostParts, tier) then
			for _, src in ipairs(ghostParts) do
				local g = src:Clone()
				for _, ch in ipairs(g:GetChildren()) do ch:Destroy() end
				bare(g)
				g.Material = Enum.Material.ForceField
				g.Color = pal.main
				g.Transparency = 0
				g.CFrame = src.CFrame
				g.Parent = f
				TweenService:Create(g, TI(life * 1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
			end
		end
		b0, t0 = b1, t1
	end)
end

-- local player only: camera shake, FOV punch, a one-frame colour "impact frame" on the finisher
local fovBase, fovUntil = nil, 0
local function feel(char, strength, heavy)
	if Players.LocalPlayer.Character ~= char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local cam = workspace.CurrentCamera
	if hum then
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 0.18 and hum.Parent do
				local k = strength * (1 - (os.clock() - t0) / 0.18)
				hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
				task.wait()
			end
			if hum.Parent then hum.CameraOffset = Vector3.zero end
		end)
	end
	-- FOV punch. Fast combos land the next hit before the last punch has settled: always return to the FOV from before
	-- the first punch of the burst, otherwise every hit would ratchet the camera FOV up a little more for good.
	local now = os.clock()
	if not fovBase or now > fovUntil then fovBase = cam.FieldOfView end
	fovUntil = now + 0.25 * slow() + 0.03
	cam.FieldOfView = fovBase + (heavy and 6 or 2.5)
	TweenService:Create(cam, TI(0.25, Enum.EasingStyle.Quad), { FieldOfView = fovBase }):Play()
	if heavy then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Contrast, cc.Saturation, cc.Brightness = 0.6, -0.6, 0.15
		cc.Parent = Lighting
		TweenService:Create(cc, TI(0.2), { Contrast = 0, Saturation = 0, Brightness = 0 }):Play()
		Debris:AddItem(cc, 0.25)
	end
end

-- phase "Swing" at the start of the cut, "Contact" on each hit time
function SwordFX.Spawn(char, tool, clip, phase)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local tier = SwordFX.TierFor(char)
	if tier == 0 then return end
	local B = SwordFX.BUDGET[tier]
	local pal = palette(tool)
	local el = tool and tool:GetAttribute("Element")
	local fx = clip.fx
	local cf = root.CFrame
	if phase == "Swing" then
		if fx.thrust then
			-- spiral spear of light straight ahead
			if not allow(3, tier) then return end
			local f = folderFx()
			for i = 1, 3 do
				local p = bare(Instance.new("Part"))
				p.Material = Enum.Material.Neon
				p.Color = i == 1 and pal.core or (i == 2 and pal.main or pal.deep)
				p.Size = Vector3.new(0.5 + i * 0.35, 0.5 + i * 0.35, 1)
				p.Transparency = 0.1 * i
				p.CFrame = cf * CFrame.new(0.4, 0.3, -1.5)
				p.Parent = f
				TweenService:Create(p, TI(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = Vector3.new(0.05, 0.05, fx.reach * 1.6), CFrame = cf * CFrame.new(0.4, 0.3, -1.5 - fx.reach * 0.8), Transparency = 1,
				}):Play()
			end
		else
			sweep(char, tool, pal, clip.heavy, el, tier, clip.trail[2] - clip.trail[1])
		end
	elseif phase == "Contact" then
		local f = folderFx()
		local heavy = clip.heavy
		local pos = cf:PointToWorldSpace(Vector3.new(0, 0.4, -(fx.reach * 0.62)))
		-- the impact is what sells the hit, so it always shows; only its part counts shrink with the tier
		local nStreak = scaled(6 + (heavy and 8 or 5), B.streaks)
		local nShard = scaled(heavy and 26 or 14, B.shards)
		if allow(1 + nStreak, tier) then flash(f, pos, pal, heavy and 8 or 5, B.streaks) end
		local part, axis, half = bladeOf(tool)
		if part and allow(4, tier) then glint(f, part.CFrame:PointToWorldSpace(axis * half), pal, heavy and 5 or 3.2) end
		flipbooks(f, CFrame.lookAt(pos, pos + cf.LookVector) * CFrame.Angles(0, 0, math.rad(fx.roll or 0)), pal,
			(heavy and 2 or 1.3) * B.flip, heavy and tier >= 2)
		if allow(nShard, tier) then shards(f, pos, cf.LookVector, pal, nShard, heavy and 46 or 32) end
		if el == "Thunder" and tier >= 3 then
			local nb = scaled(heavy and 6 or 3, B.bolts)
			if allow(nb * 5, tier) then bolts(f, pos, pal, nb) end
		end
		-- element signature (particles: thick but cheap) + ground marks for spins and slams
		local ground = groundBelow(pos, { char, f })
		if allow(3, tier) then (SIG[el or "None"] or SIG.None)(f, pos, pal, heavy, B.particles, ground) end
		local groundRoot = (fx.spin or fx.slam) and groundBelow(root.Position, { char, f })
		if groundRoot and allow(2, tier) then
			burst(f, CFrame.new(groundRoot), 1, { Texture = VTX.shock, Color = CS(pal.core, pal.main), LightEmission = 1, Orientation = FLAT,
				Speed = NR(0.01), Size = NSK({ { 0, 1 }, { 1, fx.spin and 16 or 13 } }), Transparency = NSK({ { 0, 0.05 }, { 1, 1 } }),
				Lifetime = NR(fx.spin and 0.35 or 0.3) })
			if fx.slam then
				burst(f, CFrame.new(groundRoot + root.CFrame.LookVector * 4), scaled(5, B.particles), { Texture = VTX.smoke,
					FlipbookLayout = G4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = CS(Color3.fromRGB(120, 110, 100)),
					LightEmission = 0, Size = NSK({ { 0, 2 }, { 1, 5 } }), Transparency = NSK({ { 0, 0.4 }, { 1, 1 } }), Speed = NR(5, 9),
					SpreadAngle = Vector2.new(80, 80), Drag = 3, Lifetime = NR(0.5, 0.7) })
			end
		end
		if heavy and allow(B.ring, tier) then
			groundRing(f, root, pal, 22, B.ring)
		end
		feel(char, heavy and 1.1 or 0.4, heavy)
	end
end

return SwordFX
