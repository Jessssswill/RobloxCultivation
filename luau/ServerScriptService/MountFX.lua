-- MountFX: efek panggil tunggangan (kuda emas / pedang biru), setara efek berubah wujud iblis.
-- charge(hrp, theme, dur): lingkaran segel berputar di tanah, pusaran qi tersedot ke tubuh, bara, kilat, cahaya makin terang,
-- riser + dengung, sorot Highlight. impact(pos, theme): gelombang kejut, ledakan partikel, cahaya, dentuman.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local THEMES = {
	Steed = {main = Color3.fromRGB(255, 205, 110), hot = Color3.fromRGB(255, 240, 190), smoke = {Color3.fromRGB(255, 225, 160), Color3.fromRGB(255, 170, 70)},
		light = Color3.fromRGB(255, 210, 130), riser = "1837834536", drone = "9043355570", boom = "9048840285", spell = "108306323478967"},
	Sword = {main = Color3.fromRGB(110, 180, 255), hot = Color3.fromRGB(220, 240, 255), smoke = {Color3.fromRGB(170, 215, 255), Color3.fromRGB(70, 120, 255)},
		light = Color3.fromRGB(140, 200, 255), riser = "1837834536", drone = "9043355570", boom = "1837830182", spell = "108306323478967"},
}
local M = {}

local function anchorPart(pos, size)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one * size
	p.Position = pos
	p.Parent = workspace
	return p
end

local function sound(parent, id, vol, speed)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume, s.PlaybackSpeed = vol, speed or 1
	s.RollOffMaxDistance = 320
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 8)
end

local function neon(size, cf, color, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material, p.Color, p.Size, p.CFrame = Enum.Material.Neon, color, size, cf
	p.Parent = parent
	return p
end

local function bolt(center, r, color)
	local a = center + Vector3.new(math.random(-100, 100) / 100 * r, math.random(0, 140) / 100 * r, math.random(-100, 100) / 100 * r)
	for _ = 1, 4 do
		local b = a + Vector3.new(math.random(-60, 60) / 100 * r * 0.5, -math.random(20, 60) / 100 * r * 0.5, math.random(-60, 60) / 100 * r * 0.5)
		local seg = neon(Vector3.new(0.16, 0.16, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, workspace)
		Debris:AddItem(seg, 0.12)
		a = b
	end
end

-- lingkaran segel (dua cincin + jari-jari) di tanah, berputar & membesar
local function sigil(ground, radius, color, dur)
	local model = Instance.new("Model")
	model.Name = "MountSigil"
	local base = CFrame.new(ground + Vector3.new(0, 0.12, 0))
	for _, R in {radius, radius * 0.72} do
		local n = 28
		for k = 1, n do
			local a = k / n * math.pi * 2
			local len = 2 * math.pi * R / n * 1.05
			neon(Vector3.new(len, 0.08, 0.22), base * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, -R) , color, model)
		end
	end
	for k = 1, 8 do                                                  -- jari-jari & rune
		local a = k / 8 * math.pi * 2
		neon(Vector3.new(0.12, 0.08, radius * 0.28), base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius * 0.86), color, model)
		neon(Vector3.new(0.5, 0.08, 0.5), base * CFrame.Angles(0, a + 0.2, 0) * CFrame.new(0, 0, -radius * 0.58) * CFrame.Angles(0, math.rad(45), 0), color, model)
	end
	model.Parent = workspace
	for _, p in model:GetChildren() do
		p.Transparency = 1
		TweenService:Create(p, TweenInfo.new(0.35), {Transparency = 0.15}):Play()
	end
	task.spawn(function()
		local t0 = os.clock()
		local origin = {}
		for _, p in model:GetChildren() do origin[p] = base:ToObjectSpace(p.CFrame) end
		while model.Parent and os.clock() - t0 < dur do
			local t = os.clock() - t0
			local s = 0.6 + 0.4 * math.min(1, t / 0.5)
			local rot = base * CFrame.Angles(0, t * 1.6, 0)
			for p, o in origin do
				p.CFrame = rot * CFrame.new(o.Position * s) * o.Rotation
			end
			RunService.Heartbeat:Wait()
		end
		for _, p in model:GetChildren() do TweenService:Create(p, TweenInfo.new(0.3), {Transparency = 1}):Play() end
		Debris:AddItem(model, 0.35)
	end)
end

function M.flash(char, theme, t)
	local T = THEMES[theme]
	local h = Instance.new("Highlight")
	h.FillColor, h.OutlineColor = T.main, T.hot
	h.FillTransparency, h.OutlineTransparency = 1, 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = char
	TweenService:Create(h, TweenInfo.new(t * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FillTransparency = 0.35}):Play()
	task.delay(t, function() if h.Parent then TweenService:Create(h, TweenInfo.new(0.4), {FillTransparency = 1, OutlineTransparency = 1}):Play() end end)
	Debris:AddItem(h, t + 0.5)
end

function M.charge(hrp, theme, dur, ground)
	local T = THEMES[theme]
	local pos = hrp.Position
	ground = ground or (pos - Vector3.new(0, 3, 0))
	local p = anchorPart(pos, 16)
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/smoke_main.dds"
	swirl.Color = ColorSequence.new(T.smoke[1], T.smoke[2])
	swirl.LightEmission = 0.6
	swirl.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4.5), NumberSequenceKeypoint.new(1, 1)})
	swirl.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0.95)})
	swirl.Shape, swirl.ShapeInOut, swirl.ShapeStyle = Enum.ParticleEmitterShape.Sphere, Enum.ParticleEmitterShapeInOut.Inward, Enum.ParticleEmitterShapeStyle.Surface
	swirl.Lifetime, swirl.Speed, swirl.Rate = NumberRange.new(0.6, 0.9), NumberRange.new(10, 14), 80
	swirl.RotSpeed, swirl.Rotation = NumberRange.new(-220, 220), NumberRange.new(0, 360)
	swirl.Parent = p
	local spark = Instance.new("ParticleEmitter")
	spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spark.Color = ColorSequence.new(T.hot, T.main)
	spark.LightEmission = 1
	spark.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.1)})
	spark.Shape, spark.ShapeInOut, spark.ShapeStyle = Enum.ParticleEmitterShape.Sphere, Enum.ParticleEmitterShapeInOut.Inward, Enum.ParticleEmitterShapeStyle.Surface
	spark.Lifetime, spark.Speed, spark.Rate = NumberRange.new(0.5, 0.8), NumberRange.new(14, 22), 130
	spark.Parent = p
	local up = Instance.new("ParticleEmitter")                       -- tiang cahaya naik dari segel
	up.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	up.Color = ColorSequence.new(T.hot, T.main)
	up.LightEmission = 1
	up.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
	up.Shape, up.ShapeStyle = Enum.ParticleEmitterShape.Disc, Enum.ParticleEmitterShapeStyle.Surface
	up.Lifetime, up.Speed, up.Rate = NumberRange.new(0.8, 1.3), NumberRange.new(12, 22), 90
	up.EmissionDirection = Enum.NormalId.Top
	local disc = anchorPart(ground + Vector3.new(0, 0.2, 0), 1)
	disc.Size = Vector3.new(9, 0.2, 9)
	up.Parent = disc
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = T.light, 24, 0
	light.Parent = p
	TweenService:Create(light, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Brightness = 7, Range = 40}):Play()
	sound(p, T.riser, 1.3, 2.2 / math.max(0.6, dur) * 0.6)
	sound(p, T.drone, 0.9)
	sound(p, T.spell, 1.0, 1.3)
	sigil(ground, 6, T.main, dur + 0.4)
	M.flash(hrp.Parent, theme, dur)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			bolt(pos, 5, T.main)
			task.wait(0.08 + math.random() * 0.07)
		end
		swirl.Enabled, spark.Enabled, up.Enabled = false, false, false
		TweenService:Create(light, TweenInfo.new(0.5), {Brightness = 0}):Play()
	end)
	Debris:AddItem(p, dur + 1.6)
	Debris:AddItem(disc, dur + 1.6)
end

function M.impact(pos, theme, radius, ground)
	local T = THEMES[theme]
	radius = radius or 30
	local p = anchorPart(pos, 1)
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(T.hot, T.main)
	burst.LightEmission, burst.Rate = 1, 0
	burst.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0)})
	burst.Lifetime, burst.Speed, burst.SpreadAngle = NumberRange.new(0.6, 1.2), NumberRange.new(20, 40), Vector2.new(180, 180)
	burst.Parent = p
	burst:Emit(80)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(T.smoke[1], T.smoke[2])
	smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 12)})
	smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
	smoke.Lifetime, smoke.Speed, smoke.SpreadAngle, smoke.Rate = NumberRange.new(1, 1.8), NumberRange.new(10, 24), Vector2.new(180, 30), 0
	smoke.Parent = p
	smoke:Emit(30)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = T.light, 50, 8
	light.Parent = p
	TweenService:Create(light, TweenInfo.new(1.2), {Brightness = 0}):Play()
	local g = ground or (pos - Vector3.new(0, 3, 0))
	for k, rr in {radius, radius * 0.6} do
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
		ring.Material, ring.Color = Enum.Material.Neon, k == 1 and T.main or T.hot
		ring.Size = Vector3.new(0.3, 2, 2)
		ring.CFrame = CFrame.new(g + Vector3.new(0, 0.25 + 0.1 * k, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.2
		ring.Parent = workspace
		TweenService:Create(ring, TweenInfo.new(0.6 + 0.15 * k, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(0.3, rr * 2, rr * 2), Transparency = 1}):Play()
		Debris:AddItem(ring, 1)
	end
	sound(p, T.boom, 1.6)
	Debris:AddItem(p, 4)
end

return M
