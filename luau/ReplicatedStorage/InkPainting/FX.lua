-- InkPainting/FX (ModuleScript) -> ReplicatedStorage.InkPainting.FX
-- World effects of the T ultimate, built on every client that sees the cast. The caster's own camera work, sky and
-- colour grade live in Cinema. ctx = {char, tool, origin (CFrame facing the painting), P (ground point), lift,
-- tier (1..3, phones = 1), screenSky (caster with cutscene on: sky cards drawn on screen so the grade cannot grey them)}
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(script.Parent:WaitForChild("Config"))
local Pose = require(script.Parent:WaitForChild("Pose"))

local T, Tex = Config.T, Config.Tex
local ease, outCubic = Config.ease, Config.outCubic
local UP = Vector3.yAxis
local BLACK = Color3.fromRGB(10, 9, 12)
local DARK_RED = Color3.fromRGB(70, 6, 8)
local HELL = Color3.fromRGB(255, 58, 34)
local FIRE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 140)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 92, 30)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 10, 6)),
})

local FX = {}

local function lin(a, b, x)
	return math.clamp((x - a) / (b - a), 0, 1)
end

local function window(t, a, fadeIn, b, fadeOut)
	return math.min(lin(a, a + fadeIn, t), 1 - lin(b - fadeOut, b, t))
end

local function part(parent, name, size, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = parent
	return p
end

local function seq(points)
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.LightInfluence = 0
	e.LightEmission = 0
	e.Enabled = true
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local function flip2x2(e)
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	pcall(function()
		e.FlipbookFramerate = NumberRange.new(0)
	end)
	pcall(function()
		e.FlipbookStartRandom = true
	end)
end

local function groundRay(pos, ignore)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + UP * 6, -UP * 40, rp)
	return hit and hit.Position or pos
end

-- Ground cards are flat, the forest floor is not, and terrain grass (decoration on) swallows flat decals. Lift a card
-- over the highest ground under it plus the grass. (Scripts cannot switch Terrain.Decoration off: plugin-only.)
local function cardLift(pos, ignore, r, f, spread)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore
	local ok, decorated = pcall(function() return workspace.Terrain.Decoration end)
	local rise, grassy = 0, false
	for _, off in { Vector3.zero, r * spread, -r * spread, f * spread, -f * spread } do
		local hit = workspace:Raycast(pos + off + UP * 6, -UP * 14, rp)
		if hit then
			rise = math.max(rise, hit.Position.Y - pos.Y)
			if hit.Instance:IsA("Terrain") and (hit.Material == Enum.Material.Grass or hit.Material == Enum.Material.LeafyGrass) then grassy = true end
		end
	end
	local grass = (grassy and (not ok or decorated)) and 2.1 or 0 -- the forest grass stands ~2.2 studs tall
	return math.min(math.min(rise, 1.5) + grass, 3.2)
end

-- flat decal on the ground that can grow / fade
local function groundCard(parent, name, tex, center, color, yaw)
	local p = part(parent, name, Vector3.new(1, 0.05, 1), CFrame.new(center + UP * 0.07) * CFrame.Angles(0, yaw or 0, 0))
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = tex
	d.Color3 = color
	d.Transparency = 1
	d.Parent = p
	local base = p.CFrame
	return {
		part = p,
		decal = d,
		set = function(size, alpha, col)
			if alpha >= 0.999 then
				d.Transparency = 1
				return
			end
			p.Size = Vector3.new(math.max(size, 0.1), 0.05, math.max(size, 0.1))
			p.CFrame = base
			d.Transparency = alpha
			if col then d.Color3 = col end
		end,
	}
end

-- image card in the sky: on the caster's screen (exact colours) or a BillboardGui for everyone else
local function skyCard(fx, tex, color, cell)
	local card = {}
	local rect = cell and Vector2.new((cell % 2) * 512, math.floor(cell / 2) * 512)
	local function image(parent)
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = tex
		img.ImageColor3 = color or Color3.new(1, 1, 1)
		img.ImageTransparency = 1
		if rect then
			img.ImageRectOffset = rect
			img.ImageRectSize = Vector2.new(512, 512)
		end
		img.Parent = parent
		return img
	end
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.ClipsDescendants = true
	holder.BorderSizePixel = 0
	local img = image(holder)
	if fx.screen then
		holder.AnchorPoint = Vector2.new(0, 0.5)
		holder.Visible = false
		holder.Parent = fx.screen
	else
		local p = part(fx.folder, "SkyCard", Vector3.one * 0.2, CFrame.new(fx.P + UP * 50))
		local bb = Instance.new("BillboardGui")
		bb.Adornee = p
		bb.LightInfluence = 0
		bb.AlwaysOnTop = false
		bb.MaxDistance = 1500
		bb.ResetOnSpawn = false
		bb.Enabled = false
		bb.Parent = p
		holder.Parent = bb
		card.part, card.bb = p, bb
	end
	-- pos world point, w/h studs, alpha 0..1 (1 = solid), reveal 0..1 (left to right wipe), cellIndex optional
	function card:Set(pos, w, h, alpha, reveal, newCell)
		reveal = math.clamp(reveal or 1, 0, 1)
		if newCell and newCell ~= card.cell then
			card.cell = newCell
			img.ImageRectOffset = Vector2.new((newCell % 2) * 512, math.floor(newCell / 2) * 512)
		end
		if alpha <= 0.001 or reveal <= 0.001 then
			if fx.screen then holder.Visible = false else card.bb.Enabled = false end
			return
		end
		img.ImageTransparency = 1 - alpha
		if fx.screen then
			local cam = workspace.CurrentCamera
			local v = cam:WorldToViewportPoint(pos)
			if v.Z < 1 then
				holder.Visible = false
				return
			end
			local px = cam.ViewportSize.Y / (2 * v.Z * math.tan(math.rad(cam.FieldOfView) / 2))
			holder.Visible = true
			holder.Position = UDim2.fromOffset(v.X - w * px / 2, v.Y)
			holder.Size = UDim2.fromOffset(w * px * reveal, h * px)
			img.Size = UDim2.fromOffset(w * px, h * px)
		else
			card.bb.Enabled = true
			card.part.CFrame = CFrame.new(pos)
			card.bb.Size = UDim2.fromScale(w, h)
			holder.Size = UDim2.fromScale(reveal, 1)
			img.Size = UDim2.fromScale(1 / math.max(reveal, 0.01), 1)
		end
	end
	return card
end

local function playSound(fx, key, where, volume)
	local id = Config.Sfx[key]
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 1
	if fx.screenGui then
		s.Parent = fx.screenGui -- caster watching the cutscene: no distance falloff
	else
		local p = part(fx.folder, "Sfx_" .. key, Vector3.one * 0.2, CFrame.new(where))
		s.RollOffMaxDistance = 600
		s.RollOffMinDistance = 30
		s.Parent = p
	end
	s:Play()
end

function FX.New(ctx)
	local origin, P = ctx.origin, ctx.P
	local f = Vector3.new(origin.LookVector.X, 0, origin.LookVector.Z)
	f = f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, -1)
	local r = f:Cross(UP).Unit
	local tier = ctx.tier or 3
	local k = tier == 1 and 0.45 or (tier == 2 and 0.7 or 1)
	local folder = Instance.new("Folder")
	folder.Name = "InkPaintingFX"
	folder.Parent = workspace
	local fx = { folder = folder, P = P, cues = {}, victims = {}, beams = {} }
	if ctx.screenSky then
		local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
		local gui = Instance.new("ScreenGui")
		gui.Name = "InkPaintingSky"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 99
		gui.Parent = pg
		fx.screen, fx.screenGui = gui, gui
	end
	local ignore = { ctx.char, folder }
	local ground0 = groundRay(origin.Position, ignore)
	local groundIgnore = { ctx.char, folder }
	if workspace:FindFirstChild("Monsters") then table.insert(groundIgnore, workspace.Monsters) end
	local lift0, liftP = cardLift(ground0, groundIgnore, r, f, 8), cardLift(P, groundIgnore, r, f, 14)
	local A, B = P - r * 28, P + r * 28
	local E = P + UP * 58 - f * 6

	-- held brush (on every client) + colossal phantom brush
	local pose = Pose.Bind(ctx.char, ctx.tool)
	pose:Parent(folder)
	fx.pose = pose
	local phantom = Pose.Phantom(ctx.tool, 8)
	phantom.model.Parent = folder
	phantom:Place(A + UP * 300, -UP, f, 1)
	local phantomInk = Instance.new("Highlight") -- black ink spear with a red-violet rim (ref 0:05.5)
	phantomInk.FillColor = BLACK
	phantomInk.OutlineColor = Color3.fromRGB(255, 80, 150)
	phantomInk.FillTransparency = 1
	phantomInk.OutlineTransparency = 1
	phantomInk.DepthMode = Enum.HighlightDepthMode.Occluded
	phantomInk.Adornee = phantom.model
	phantomInk.Parent = phantom.model

	-- 1. brush tip: red-purple glow, ink drips
	local tipPart = part(folder, "BrushTip", Vector3.one * 0.2, origin)
	local tipAtt = Instance.new("Attachment")
	tipAtt.Parent = tipPart
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 70, 140)
	light.Range = 10
	light.Brightness = 0
	light.Shadows = false
	light.Parent = tipPart
	local tipGlow = emitter(tipAtt, {
		Texture = Tex.glow, Color = ColorSequence.new(Color3.fromRGB(255, 80, 150)), LightEmission = 1,
		Size = seq({ { 0, 0.25 }, { 0.3, 0.6 }, { 1, 0 } }), Transparency = seq({ { 0, 0.5 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(0.3, 1.2), SpreadAngle = Vector2.new(180, 180),
	})
	-- shot 1 holds the brush a stud from the face: small glow there, the full one from the launch on
	local GLOW_SMALL, GLOW_SMALL_T = tipGlow.Size, tipGlow.Transparency
	local GLOW_BIG, GLOW_BIG_T = seq({ { 0, 0.6 }, { 0.3, 1.4 }, { 1, 0 } }), seq({ { 0, 0.3 }, { 1, 1 } })
	local glowBig = false
	local drips = emitter(tipAtt, {
		Texture = Tex.splat, Color = ColorSequence.new(BLACK), Size = seq({ { 0, 0.5 }, { 0.2, 1.1 }, { 1, 0.3 } }),
		Transparency = seq({ { 0, 0.05 }, { 0.8, 0.2 }, { 1, 1 } }), Lifetime = NumberRange.new(0.6, 1.0),
		Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -38, 0),
		Rotation = NumberRange.new(-180, 180), RotSpeed = NumberRange.new(-90, 90),
	})
	flip2x2(drips)

	-- 2. launch: ink blooms under the caster
	local launchBleed = groundCard(folder, "LaunchBleed", Tex.bleed, ground0 + UP * lift0, BLACK)
	local launchAtt = Instance.new("Attachment")
	-- emitters start above the lifted ground cards, or the opaque cards hide their first frames
	launchAtt.Parent = part(folder, "LaunchSplash", Vector3.one * 0.2, CFrame.new(ground0 + UP * (lift0 + 0.5)))
	local splashProps = {
		Texture = Tex.splat, Color = ColorSequence.new(BLACK), Size = seq({ { 0, 1.2 }, { 0.15, 3.4 }, { 1, 1.6 } }),
		Transparency = seq({ { 0, 0 }, { 0.7, 0.15 }, { 1, 1 } }), Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(25, 48), SpreadAngle = Vector2.new(75, 75), Acceleration = Vector3.new(0, -55, 0),
		Rotation = NumberRange.new(-180, 180), RotSpeed = NumberRange.new(-120, 120), Drag = 1.5,
		EmissionDirection = Enum.NormalId.Top,
	}
	local launchSplash = emitter(launchAtt, splashProps)
	flip2x2(launchSplash)

	-- 3. storm clouds around the caster (locked to a slowly turning part = swirling storm)
	local cloudCenter = ground0 + UP * (ctx.lift * 0.85)
	local cloudLife = 7.35 - T.Sky
	local function cloudRing(size, n, shade, sizeMin, sizeMax)
		local p = part(folder, "StormClouds", size, CFrame.new(cloudCenter))
		local e = emitter(p, {
			Texture = Tex.cloud, Color = ColorSequence.new(Color3.new(shade, shade, shade)),
			Size = seq({ { 0, sizeMin * 0.7 }, { 0.1, sizeMin }, { 1, sizeMax } }),
			Transparency = seq({ { 0, 1 }, { 0.06, 0.08 }, { 0.92, 0.12 }, { 1, 1 } }),
			Lifetime = NumberRange.new(cloudLife), Speed = NumberRange.new(0.5, 2), Shape = Enum.ParticleEmitterShape.Cylinder,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Rotation = NumberRange.new(-180, 180), RotSpeed = NumberRange.new(-8, 8), LockedToPart = true,
			Orientation = Enum.ParticleOrientation.FacingCamera,
		})
		flip2x2(e)
		return { part = p, e = e, n = math.max(4, math.floor(n * k)) }
	end
	local rings = {
		cloudRing(Vector3.new(140, 50, 140), 26, 1, 40, 62),
		cloudRing(Vector3.new(70, 34, 70), 12, 0.62, 26, 38),
	}
	if tier == 1 then table.remove(rings, 2) end

	-- 4. creeping tendrils at the painting centre + ink climbing every bound monster
	local tendrils = groundCard(folder, "Tendrils", Tex.tendril, P + UP * liftP, BLACK, math.random() * math.pi * 2)
	local tendrilGlow = groundCard(folder, "TendrilsGlow", Tex.tendril, P + UP * (liftP + 0.02), HELL)
	tendrilGlow.part.CFrame = tendrils.part.CFrame + UP * 0.02
	local glowSg = nil
	local function addVictims()
		local monsters = workspace:FindFirstChild("Monsters")
		if not monsters then return end
		local list = {}
		for _, m in monsters:GetChildren() do
			local h = m:FindFirstChildOfClass("Humanoid")
			local rp = m:FindFirstChild("HumanoidRootPart")
			if h and rp and h.Health > 0 and (rp.Position - P).Magnitude <= Config.Radius then
				table.insert(list, { m = m, root = rp, d = (rp.Position - P).Magnitude })
			end
		end
		table.sort(list, function(a, b) return a.d < b.d end)
		local maxN = tier == 1 and 4 or 8
		for i = 1, math.min(#list, maxN) do
			local v = list[i]
			local hl = Instance.new("Highlight")
			hl.Adornee = v.m
			hl.FillColor = BLACK
			hl.FillTransparency = 1
			hl.OutlineColor = BLACK
			hl.OutlineTransparency = 1
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = folder
			local feet = groundRay(v.root.Position, { v.m, ctx.char, folder })
			local entry = { m = v.m, root = v.root, hl = hl, beams = {}, feet = feet }
			for b = 1, (tier == 1 and 1 or 2) do
				local ang = math.random() * math.pi * 2
				local a0p = part(folder, "TendrilFoot", Vector3.one * 0.2, CFrame.new(feet + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 1.8))
				local a1p = part(folder, "TendrilTop", Vector3.one * 0.2, CFrame.new(feet))
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Parent, a1.Parent = a0p, a1p
				local beam = Instance.new("Beam")
				beam.Attachment0, beam.Attachment1 = a0, a1
				beam.Texture = Tex.stroke
				beam.TextureMode = Enum.TextureMode.Stretch
				beam.Color = ColorSequence.new(BLACK)
				beam.LightInfluence = 0
				beam.Width0, beam.Width1 = 1.4, 0.2
				beam.CurveSize0, beam.CurveSize1 = (b == 1 and 2.5 or -2.5), (b == 1 and -1.5 or 1.5)
				beam.Segments = 12
				beam.FaceCamera = true
				beam.Transparency = NumberSequence.new(1)
				beam.Parent = a0p
				table.insert(entry.beams, { beam = beam, top = a1p, height = 1.6 + b * 0.9 })
			end
			table.insert(fx.victims, entry)
		end
	end

	-- 5-6. giant stroke on the ground, revealed left to right under the phantom brush as it drags across
	-- A Top-face SurfaceGui runs canvas X along the part's -Z and canvas Y along its +X. So the part's X axis is -f
	-- (stroke width, towards the shot-4 camera) and its -Z is r: canvas left = A, the brush press; reveal A -> B.
	local STROKE_W, STROKE_D = 64, 40
	local strokePart = part(folder, "GiantStroke", Vector3.new(STROKE_D, 0.05, STROKE_W), CFrame.fromMatrix(P + UP * (liftP + 0.12), -f, UP))
	local function strokeGui(color, glow)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Top
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(1024, 512)
		sg.LightInfluence = glow and 0 or 1
		sg.Brightness = glow and 2.5 or 1
		sg.AlwaysOnTop = false
		sg.Adornee = strokePart
		sg.Parent = strokePart
		local clip = Instance.new("Frame")
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(0, 1)
		clip.Parent = sg
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = Tex.strokeGround or Tex.stroke
		img.ImageColor3 = color
		img.Size = UDim2.fromOffset(1024, 512)
		img.ImageTransparency = glow and 1 or 0.02
		img.Parent = clip
		return clip, img
	end
	local strokeClip, strokeImg = strokeGui(BLACK, false)
	local glowClip, glowImg = strokeGui(HELL, true)
	glowSg = glowImg
	local dragAtt = Instance.new("Attachment")
	local dragPart = part(folder, "StrokeSpray", Vector3.one * 0.2, CFrame.new(A))
	dragAtt.Parent = dragPart
	local dragSpray = emitter(dragAtt, {
		Texture = Tex.splat, Color = ColorSequence.new(BLACK), Size = seq({ { 0, 1 }, { 0.2, 2.6 }, { 1, 0.8 } }),
		Transparency = seq({ { 0, 0 }, { 0.75, 0.2 }, { 1, 1 } }), Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(14, 30), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -50, 0),
		Rotation = NumberRange.new(-180, 180), RotSpeed = NumberRange.new(-120, 120), EmissionDirection = Enum.NormalId.Top,
	})
	flip2x2(dragSpray)

	-- 7. impact at the painting centre
	local impactAtt = Instance.new("Attachment")
	impactAtt.Parent = part(folder, "Impact", Vector3.one * 0.2, CFrame.new(P + UP * (liftP + 0.8)))
	local impactSplash = emitter(impactAtt, splashProps)
	flip2x2(impactSplash)
	local impactBleed = groundCard(folder, "ImpactBleed", Tex.bleed, P + UP * (liftP + 0.03), BLACK, 1.3)
	local finalBleed = groundCard(folder, "FinalBleed", Tex.bleed, P + UP * (liftP + 0.05), DARK_RED, 2.4)

	-- 9. ink vortex pouring from the sky onto the centre
	local V = P + UP * 72
	local vortex = {}
	for i = 1, (tier == 1 and 2 or 3) do
		local top = part(folder, "VortexTop", Vector3.one * 0.2, CFrame.new(V))
		local bottom = part(folder, "VortexBottom", Vector3.one * 0.2, CFrame.new(P + UP * (liftP + 0.5)))
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = top, bottom
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Texture = Tex.stroke
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 26
		beam.TextureSpeed = 1.8
		beam.Color = ColorSequence.new(Color3.fromRGB(28, 27, 30))
		beam.LightInfluence = 0
		beam.Segments = 24
		beam.FaceCamera = true
		beam.CurveSize0, beam.CurveSize1 = 22, -14
		beam.Transparency = NumberSequence.new(1)
		beam.Parent = top
		table.insert(vortex, { beam = beam, a0 = a0, a1 = a1, phase = (i - 1) * math.pi * 2 / 3 })
	end
	local vortexFall
	if tier >= 2 then
		local colPart = part(folder, "VortexColumn", Vector3.new(14, 60, 14), CFrame.new(P + UP * 34))
		vortexFall = emitter(colPart, {
			Texture = Tex.cloud, Color = ColorSequence.new(Color3.fromRGB(60, 58, 62)),
			Size = seq({ { 0, 8 }, { 1, 16 } }), Transparency = seq({ { 0, 1 }, { 0.15, 0.2 }, { 0.8, 0.3 }, { 1, 1 } }),
			Lifetime = NumberRange.new(1.1, 1.5), Speed = NumberRange.new(18, 32), EmissionDirection = Enum.NormalId.Bottom,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Rotation = NumberRange.new(-180, 180), RotSpeed = NumberRange.new(-90, 90),
		})
		flip2x2(vortexFall)
	end

	-- 8. ink dragon from the old T, reused and pointed at the centre
	local dragonModule
	do
		local assets = RS:FindFirstChild("InkM1Assets")
		local m = assets and assets:FindFirstChild("InkDanceVFX")
		if m then
			local ok, mod = pcall(require, m)
			if ok then dragonModule = mod end
		end
	end
	local dragonOrigin = CFrame.lookAt(P - f * 12.8 + UP * 2.65, P - f * 11.8 + UP * 2.65)

	-- 10. viewers without the screen flood still see the world swallowed by ink
	local floodBleed = groundCard(folder, "FloodBleed", Tex.bleed, P + UP * (liftP + 0.09), BLACK, 0.4)

	-- 11-13. sky: hell eye, claw tears, hundred demons
	local eye = skyCard(fx, Tex.eye, nil, 0)
	local claws = {
		{ card = skyCard(fx, Tex.claw, HELL), at = E - r * 6 - UP * 4 + f * 2, w = 74, h = 37, t0 = T.Claws },
		{ card = skyCard(fx, Tex.claw, HELL), at = E + r * 9 + UP * 7 + f * 2, w = 64, h = 32, t0 = T.Claws + 0.14 },
	}
	local demonSpots = { { -34, 4, 24 }, { -23, 17, 28 }, { -9, 26, 30 }, { 9, 26, 30 }, { 23, 17, 28 }, { 34, 4, 24 }, { 0, -12, 34 } }
	local demons = {}
	for i, d in demonSpots do
		if tier > 1 or i % 2 == 1 then
			table.insert(demons, {
				card = skyCard(fx, Tex.demon, Color3.fromRGB(255, 70, 45), (i - 1) % 4),
				at = E + r * d[1] + UP * d[2] + f * 4,
				size = d[3],
				t0 = T.Demons + (i - 1) * 0.03,
			})
		end
	end

	-- 14. hell fire along the stroke
	local firePart = part(folder, "StrokeFire", Vector3.new(50, 1, 5), CFrame.fromMatrix(P + UP * (liftP + 0.6), r, UP))
	local fire = emitter(firePart, {
		Texture = Tex.fire, Color = FIRE, LightEmission = 1, Size = seq({ { 0, 3 }, { 0.4, 7 }, { 1, 2 } }),
		Transparency = seq({ { 0, 0.2 }, { 0.7, 0.35 }, { 1, 1 } }), Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(8, 18), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rotation = NumberRange.new(-20, 20), Acceleration = Vector3.new(0, 6, 0),
	})
	fire.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	fire.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 90, 40)
	fireLight.Range = 40
	fireLight.Brightness = 0
	fireLight.Shadows = false
	fireLight.Parent = firePart

	-- cues that fire once
	local function cue(name, at, fn)
		table.insert(fx.cues, { name = name, t = at, fn = fn })
	end
	cue("raise", 0.05, function() playSound(fx, "raise", origin.Position, 0.8) end)
	cue("launch", T.Rise + 0.03, function()
		launchSplash:Emit(math.floor(16 * k))
		playSound(fx, "rise", ground0, 1)
	end)
	cue("sky", T.Sky, function()
		for _, ring in rings do ring.e:Emit(ring.n) end
		playSound(fx, "thunder", cloudCenter, 1)
	end)
	cue("bind", Config.BindFrom, addVictims)
	cue("impact", T.Impact, function()
		impactSplash:Emit(math.floor(34 * k))
		playSound(fx, "slam", P, 1.2)
	end)
	cue("roar", T.Painting + 0.25, function() playSound(fx, "roar", P, 0.7) end)
	cue("vortexHit1", Config.Hits[2].t, function() impactSplash:Emit(math.floor(10 * k)) end)
	cue("vortexHit2", Config.Hits[3].t, function() impactSplash:Emit(math.floor(10 * k)) end)
	cue("flood", T.Flood, function() playSound(fx, "flood", P, 1) end)
	cue("eye", T.Eye, function() playSound(fx, "eye", E, 1) end)
	cue("claw", T.Claws, function() playSound(fx, "claw", E, 1) end)
	cue("demons", T.Demons, function() playSound(fx, "demons", E, 1) end)
	cue("final", T.Final, function()
		impactSplash.Color = ColorSequence.new(DARK_RED)
		impactSplash:Emit(math.floor(40 * k))
		fire:Emit(math.floor(60 * k))
		playSound(fx, "final", P, 1.3)
	end)

	local dragon
	function fx:Update(t, rootCF)
		local info = pose:Update(t, rootCF)
		fx.tip = info.tip
		for _, c in fx.cues do
			if not c.done and t >= c.t then
				c.done = true
				local ok, err = pcall(c.fn)
				if not ok then warn("[InkPainting] cue " .. c.name .. ": " .. tostring(err)) end
			end
		end

		-- brush tip
		tipPart.CFrame = CFrame.new(info.tip)
		light.Brightness = 3 * window(t, 0.1, 0.3, 7.3, 0.4) * (t < T.Rise and 0.4 or 0.55) -- shot 1: a stud from the face
		tipGlow.Rate = t < T.Rise + 0.1 and 30 or (t < T.Restore and 6 or 0)
		if glowBig ~= (t >= T.Rise) then
			glowBig = t >= T.Rise
			tipGlow.Size = glowBig and GLOW_BIG or GLOW_SMALL
			tipGlow.Transparency = glowBig and GLOW_BIG_T or GLOW_SMALL_T
		end
		drips.Rate = (t > T.Rise and t < T.Stroke) and 18 * k or 0

		-- launch bloom
		local lb = lin(T.Rise, T.Rise + 0.45, t)
		launchBleed.set(3 + 21 * outCubic(lb), lb <= 0 and 1 or (0.12 + 0.88 * lin(1.9, 2.4, t)))

		-- swirl
		for i, ring in rings do
			ring.part.CFrame = CFrame.new(cloudCenter) * CFrame.Angles(0, t * (i == 1 and 0.3 or -0.45), 0)
		end

		-- tendrils
		local tg = lin(T.Tendrils, T.Tendrils + 0.6, t)
		local tendrilAlpha = tg <= 0 and 1 or lin(T.Restore, T.End - 0.1, t)
		tendrils.set(2 + 44 * outCubic(tg), tendrilAlpha, t > T.Red and DARK_RED or BLACK)
		local glowA = window(t, T.Demons + 0.05, 0.3, T.End - 0.2, 0.5)
		tendrilGlow.set(46, glowA > 0 and 1 - 0.75 * glowA * (0.85 + 0.15 * math.sin(t * 30)) or 1)
		for _, v in fx.victims do
			local alive = v.m.Parent and v.root.Parent
			-- the look outlives the server bind: monsters stay ink through the final hit (bare, they read as pink boxes)
			local bind = alive and window(t, Config.BindFrom, 0.25, T.Restore + 0.15, 0.3) or 0
			v.hl.FillTransparency = 1 - 0.85 * bind -- solid ink: at 0.45 the light monster skin showed through as pink
			v.hl.OutlineTransparency = 1 - 0.8 * bind
			v.hl.OutlineColor = t > T.Red and HELL or BLACK
			local climb = outCubic(lin(Config.BindFrom, Config.BindFrom + 0.45, t))
			for _, b in v.beams do
				b.top.CFrame = CFrame.new(v.feet + UP * (0.2 + b.height * climb))
				b.beam.Transparency = NumberSequence.new(1 - bind * 0.95)
			end
		end

		-- phantom brush slam + drag (the tip rides on the stroke card, which sits over the grass)
		local wipe = t < T.Slam and 0 or 1
		fx.phantomTip, fx.phantomMid = nil, nil
		if t >= T.Stroke and t <= T.Painting + 0.2 then
			local tip, dir, alpha
			local down = -UP
			local ink = UP * (liftP + 0.35)
			if t < T.Slam then
				local u = ease(lin(T.Stroke + 0.06, T.Slam, t))
				tip = (A + UP * 42 - r * 6):Lerp(A + ink, u * u)
				dir = (down + r * 0.32 + f * 0.18).Unit
				alpha = lin(T.Stroke + 0.06, T.Stroke + 0.16, t)
			elseif t < 3.06 then
				local u = ease(lin(T.Slam, 3.06, t))
				tip = (A + ink):Lerp(B + ink, u)
				dir = ((down + r * 0.32 + f * 0.18):Lerp(down - r * 0.28 + f * 0.18, u)).Unit
				alpha = 1
				wipe = math.clamp(((tip - P):Dot(r) + STROKE_W * 0.5 + 5) / STROKE_W, 0, 1) -- the bristles lead by a few studs
			else
				local u = ease(lin(3.06, T.Painting + 0.15, t))
				tip = (B + ink):Lerp(B + UP * 34 + r * 10, u)
				dir = (down - r * 0.28 + f * 0.18).Unit
				alpha = 1 - u
			end
			phantom:Place(tip, dir, f, 1 - alpha)
			if alpha > 0.05 then fx.phantomTip, fx.phantomMid = tip, tip - dir * 22 end -- Cinema fades trees in front of it
			phantomInk.FillTransparency = 1 - 0.9 * alpha
			phantomInk.OutlineTransparency = 1 - 0.8 * alpha
			dragPart.CFrame = CFrame.new(tip)
			dragSpray.Rate = (t >= T.Slam and t < 3.06) and 220 * k or 0
		else
			dragSpray.Rate = 0
			if t > T.Painting + 0.2 and not fx.phantomGone then
				fx.phantomGone = true
				phantom:Destroy()
			end
		end
		strokeClip.Size = UDim2.fromScale(wipe, 1)
		strokeImg.ImageTransparency = 0.02 + 0.98 * lin(T.Restore, T.End - 0.1, t)
		strokeImg.ImageColor3 = t > T.Red and DARK_RED or BLACK
		glowClip.Size = UDim2.fromScale(wipe, 1)
		glowSg.ImageTransparency = 1 - 0.85 * glowA * (0.8 + 0.2 * math.sin(t * 23))

		-- impact + final blooms
		local ib = lin(T.Impact, T.Impact + 0.22, t)
		impactBleed.set(4 + 32 * outCubic(ib), ib <= 0 and 1 or (0.1 + 0.9 * lin(T.Impact + 0.6, T.Painting + 1.0, t)))
		local fb = lin(T.Final, T.Final + 0.25, t)
		finalBleed.set(6 + 38 * outCubic(fb), fb <= 0 and 1 or (0.05 + 0.95 * lin(T.Restore, T.End - 0.05, t)))

		-- dragon (created behind the cut into shot 5, removed under the black flood)
		if dragonModule and not dragon and t >= T.Painting - 0.1 and t < T.Black then
			local ok, res = pcall(dragonModule.New, folder, dragonOrigin, false, P)
			if ok then dragon = res else warn("[InkPainting] dragon: " .. tostring(res)) dragonModule = nil end
		end
		if dragon then
			if t >= T.Black + 0.05 then
				pcall(function() dragon:Destroy() end)
				dragon = false
				dragonModule = nil
			else
				local clip = 3.1 + math.clamp((t - T.Painting) / 1.3, 0, 1) * 1.9
				local ok, err = pcall(dragon.Update, dragon, clip, info.tip)
				if not ok then
					warn("[InkPainting] dragon update: " .. tostring(err))
					pcall(function() dragon:Destroy() end)
					dragon = false
					dragonModule = nil
				end
			end
		end
		fx.dragon = dragon or nil

		-- vortex
		local vg = window(t, T.Painting + 0.1, 0.25, T.Flood + 0.05, 0.25)
		for _, v in vortex do
			local spin = CFrame.Angles(0, t * 5 + v.phase, 0)
			v.a0.CFrame = spin * CFrame.Angles(0, 0, math.pi / 2)
			v.a1.CFrame = spin * CFrame.Angles(0, 0, math.pi / 2)
			v.beam.Width0, v.beam.Width1 = 30 * vg, 7 * vg
			v.beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 1 - 0.85 * vg),
				NumberSequenceKeypoint.new(1, 1 - 0.9 * vg),
			})
		end
		if vortexFall then vortexFall.Rate = vg > 0.5 and 34 or 0 end

		-- flood for viewers in the world
		if not fx.screen then
			local fl = lin(T.Flood, T.Black, t)
			floodBleed.set(8 + 70 * outCubic(fl), fl <= 0 and 1 or (0.05 + 0.95 * lin(T.Red + 0.1, T.Eye + 0.3, t)), t > T.Red and DARK_RED or BLACK)
		end

		-- eye
		local eyeA = window(t, T.Eye, 0.15, T.Final + 0.12, 0.12)
		local frame = math.clamp(math.floor(lin(T.Eye + 0.1, T.Eye + 0.5, t) * 4), 0, 3)
		local pulse = 1 + 0.03 * math.sin(t * 9)
		eye:Set(E, 46 * pulse, 46 * pulse, eyeA, 1, frame)

		-- claws
		for _, c in claws do
			local a = window(t, c.t0, 0.02, c.t0 + 0.6, 0.25)
			c.card:Set(c.at, c.w, c.h, a, outCubic(lin(c.t0, c.t0 + 0.12, t)))
		end

		-- demons appear, then dive onto the centre
		for _, d in demons do
			local appear = lin(d.t0, d.t0 + 0.14, t)
			local dive = ease(lin(T.Dive, T.Final, t))
			local a = appear * (1 - lin(T.Final - 0.03, T.Final + 0.05, t))
			local s = (0.6 + 0.4 * outCubic(appear)) * (1 + 0.6 * dive)
			d.card:Set(d.at:Lerp(P + UP * 4, dive), d.size * s, d.size * s, a, 1)
		end

		-- fire
		local fireOn = t > T.Demons + 0.05 and t < T.Restore + 0.25
		fire.Rate = fireOn and (t >= T.Final and 90 or 25) * k or 0
		fireLight.Brightness = 4 * window(t, T.Demons + 0.05, 0.2, T.End, 0.5)
		return info
	end

	function fx:Destroy()
		pcall(function() pose:Destroy() end)
		if dragon then pcall(function() dragon:Destroy() end) end
		if not fx.phantomGone then pcall(function() phantom:Destroy() end) end
		folder:Destroy()
		if fx.screenGui then fx.screenGui:Destroy() end
	end

	return fx
end

return FX
