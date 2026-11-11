-- InkPainting/FX (ModuleScript) -> ReplicatedStorage.InkPainting.FX
-- World effects of the G ultimate, built on every client that sees the cast. The caster's own camera work, sky and
-- colour grade live in Cinema. ctx = {char, tool, origin (CFrame facing the painting), P (ground point), lift,
-- tier (1..3, phones = 1), screenSky (caster with cutscene on: sky cards drawn on screen so the grade cannot grey them),
-- plan (v2 dash path from the server, Config.MakePlan)}.
-- fx:Update(s, rootCF, tau) takes story time; the v1 effects below run on v1 time t = Config.V1(s).
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(script.Parent:WaitForChild("Config"))
local Pose = require(script.Parent:WaitForChild("Pose"))

local T, Tex = Config.T, Config.Tex
local ease, outCubic = Config.ease, Config.outCubic
local UP = Vector3.yAxis
local BLACK = Color3.fromRGB(10, 9, 12)
local DARK_RED = Color3.fromRGB(70, 6, 8)
local PAPER = Color3.fromRGB(236, 230, 216) -- the main target under the last stroke: blank paper with the ink across it
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
	local cloudLife = Config.Tau(Config.SAtV1(7.35)) - Config.Tau(Config.SAtV1(T.Sky)) -- the storm lasts the whole cast
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
		local maxN = tier == 1 and 5 or 10
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

	-- v2 act 2: the three dash strokes of the Z, painted on the ground under the caster's brush, each erupting when
	-- the caster leaves it; v2 act 5: every stroke explodes around the planted brush
	local plan = ctx.plan
	local dashes = {}
	local hitPart, hitSplash, hitFlash, demonRise, dashPart, dashSpray, trail, trailPart, ringAtt, ring, finalGlow, ringPart
	if plan then
		local W, PX = 22, 12 -- card width (the ink band is about half of it), canvas pixels per stud
		for i, pts in plan.strokes do
			local cum, L = plan.cum[i], plan.len[i]
			local d = { cards = {}, len = L, revealed = 0, passed = {}, erupted = false }
			local step = tier == 1 and 2 or 1
			local j = 1
			while j < #pts do
				local j2 = math.min(j + step, #pts)
				local a, b = pts[j], pts[j2]
				local seg = b - a
				local d3 = seg.Magnitude > 0.01 and seg.Unit or plan.dir[i]
				local side = d3:Cross(UP)
				side = side.Magnitude > 0.01 and side.Unit or r
				local n = side:Cross(d3).Unit
				local segLen = cum[j2] - cum[j]
				-- a Top-face SurfaceGui runs canvas X along the part's -Z: -Z = the stroke direction, canvas left = start
				local card = part(folder, "DashStroke", Vector3.new(W, 0.05, seg.Magnitude + 0.15), CFrame.fromMatrix((a + b) / 2 + n * 0.04, d3:Cross(n), n))
				local sg = Instance.new("SurfaceGui")
				sg.Face = Enum.NormalId.Top
				sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
				sg.CanvasSize = Vector2.new(math.max(8, math.floor(segLen * PX)), W * PX)
				sg.LightInfluence = 1
				sg.AlwaysOnTop = false
				sg.Adornee = card
				sg.Parent = card
				local clip = Instance.new("Frame")
				clip.BackgroundTransparency = 1
				clip.ClipsDescendants = true
				clip.Size = UDim2.fromScale(0, 1)
				clip.Parent = sg
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.Image = Tex.strokeGround or Tex.stroke
				img.ImageColor3 = BLACK
				img.ImageTransparency = 0.02
				img.Size = UDim2.fromOffset(math.floor(L * PX), W * PX) -- one texture over the whole stroke, each card shows its slice
				img.Position = UDim2.fromOffset(-math.floor(cum[j] * PX), 0)
				img.Parent = clip
				table.insert(d.cards, { from = cum[j], len = math.max(segLen, 0.01), clip = clip, img = img, shown = -1 })
				j = j2
			end
			-- eruption (ink geyser along the whole stroke) + fire for the final
			local a, b = pts[1], pts[#pts]
			local mid = (a + b) / 2 + UP * 0.8
			local ePart = part(folder, "DashErupt", Vector3.new(3.5, 1, L), CFrame.lookAt(mid, mid + plan.dir[i]))
			d.erupt = emitter(ePart, {
				Texture = Tex.splat, Color = ColorSequence.new(BLACK), Size = seq({ { 0, 1.4 }, { 0.15, 3.4 }, { 1, 1 } }),
				Squash = seq({ { 0, 1.4 }, { 0.5, 0.8 }, { 1, 0 } }), Orientation = Enum.ParticleOrientation.VelocityParallel,
				Transparency = seq({ { 0, 0 }, { 0.8, 0.15 }, { 1, 1 } }), Lifetime = NumberRange.new(0.55, 0.95),
				Speed = NumberRange.new(30, 62), SpreadAngle = Vector2.new(14, 14), Acceleration = Vector3.new(0, -95, 0),
				EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			})
			flip2x2(d.erupt)
			d.fire = emitter(ePart, {
				Texture = Tex.fire, Color = FIRE, LightEmission = 1, Size = seq({ { 0, 3 }, { 0.4, 6.5 }, { 1, 2 } }),
				Transparency = seq({ { 0, 0.2 }, { 0.7, 0.35 }, { 1, 1 } }), Lifetime = NumberRange.new(0.5, 0.9),
				Speed = NumberRange.new(8, 18), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
				Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				Rotation = NumberRange.new(-20, 20), Acceleration = Vector3.new(0, 6, 0),
			})
			d.fire.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			d.fire.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
			if tier >= 2 then
				d.light = Instance.new("PointLight")
				d.light.Color = Color3.fromRGB(255, 90, 40)
				d.light.Range = 34
				d.light.Brightness = 0
				d.light.Shadows = false
				d.light.Parent = ePart
			end
			dashes[i] = d
		end
		-- one set of hit effects, moved onto each monster as it gets hit
		hitPart = part(folder, "DashHit", Vector3.one * 0.2, CFrame.new(P))
		local hitAtt = Instance.new("Attachment")
		hitAtt.Parent = hitPart
		hitSplash = emitter(hitAtt, {
			Texture = Tex.splat, Color = ColorSequence.new(BLACK), Size = seq({ { 0, 0.8 }, { 0.15, 2.4 }, { 1, 1 } }),
			Transparency = seq({ { 0, 0 }, { 0.7, 0.15 }, { 1, 1 } }), Lifetime = NumberRange.new(0.35, 0.6),
			Speed = NumberRange.new(18, 36), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -60, 0),
			Rotation = NumberRange.new(-180, 180), RotSpeed = NumberRange.new(-160, 160), Drag = 1.5,
		})
		flip2x2(hitSplash)
		hitFlash = emitter(hitAtt, { -- white star burst: stays white under the grey grade
			Texture = Tex.glow, Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 1,
			Size = seq({ { 0, 2 }, { 0.3, 9 }, { 1, 11 } }), Transparency = seq({ { 0, 0 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.12, 0.16), Speed = NumberRange.new(0),
		})
		demonRise = emitter(dashes[#dashes].erupt.Parent, { -- stroke 3 lets the first demons out of the ground
			Texture = Tex.demon, Color = ColorSequence.new(Color3.fromRGB(36, 33, 38)), Size = seq({ { 0, 3 }, { 0.3, 7 }, { 1, 9 } }),
			Transparency = seq({ { 0, 1 }, { 0.1, 0.05 }, { 0.75, 0.2 }, { 1, 1 } }), Lifetime = NumberRange.new(0.9, 1.2),
			Speed = NumberRange.new(10, 20), SpreadAngle = Vector2.new(12, 12), EmissionDirection = Enum.NormalId.Top,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Rotation = NumberRange.new(-12, 12),
		})
		flip2x2(demonRise)
		-- brush spray where the ink is being laid
		dashPart = part(folder, "DashSpray", Vector3.one * 0.2, CFrame.new(P))
		local sprayAtt = Instance.new("Attachment")
		sprayAtt.Parent = dashPart
		dashSpray = emitter(sprayAtt, {
			Texture = Tex.splat, Color = ColorSequence.new(BLACK), Size = seq({ { 0, 0.8 }, { 0.2, 2 }, { 1, 0.6 } }),
			Transparency = seq({ { 0, 0 }, { 0.75, 0.2 }, { 1, 1 } }), Lifetime = NumberRange.new(0.35, 0.7),
			Speed = NumberRange.new(10, 24), SpreadAngle = Vector2.new(55, 55), Acceleration = Vector3.new(0, -55, 0),
			Rotation = NumberRange.new(-180, 180), RotSpeed = NumberRange.new(-120, 120), EmissionDirection = Enum.NormalId.Top,
		})
		flip2x2(dashSpray)
		-- speed streak behind the caster
		trailPart = part(folder, "DashTrail", Vector3.one * 0.2, ctx.origin)
		local t0, t1a = Instance.new("Attachment"), Instance.new("Attachment")
		t0.Position, t1a.Position = Vector3.new(0, 1.6, 0), Vector3.new(0, -1.9, 0)
		t0.Parent, t1a.Parent = trailPart, trailPart
		trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = t0, t1a
		trail.Texture = Tex.stroke
		trail.Color = ColorSequence.new(BLACK)
		trail.LightInfluence = 0
		trail.Lifetime = 0.22
		trail.MinLength = 0.05
		trail.FaceCamera = true
		trail.Transparency = seq({ { 0, 0.15 }, { 1, 1 } })
		trail.WidthScale = seq({ { 0, 1 }, { 1, 0.35 } })
		trail.Enabled = false
		trail.Parent = trailPart
		-- the final: an ink shockwave ring round the planted brush + a red flash on the ground
		ringPart = part(folder, "FinalRing", Vector3.one * 0.2, CFrame.new(plan.land + UP * 1.4))
		ringAtt = Instance.new("Attachment")
		ringAtt.Parent = ringPart
		ring = emitter(ringAtt, {
			Texture = Tex.splat, Color = ColorSequence.new(DARK_RED, BLACK), Size = seq({ { 0, 4 }, { 0.3, 9 }, { 1, 12 } }),
			Transparency = seq({ { 0, 0.05 }, { 0.75, 0.25 }, { 1, 1 } }), Lifetime = NumberRange.new(0.9, 1.25),
			Speed = NumberRange.new(85, 120), Drag = 2.6, SpreadAngle = Vector2.new(6, 4),
			EmissionDirection = Enum.NormalId.Front, Rotation = NumberRange.new(-180, 180), RotSpeed = NumberRange.new(-60, 60),
		})
		flip2x2(ring)
		finalGlow = groundCard(folder, "FinalGlow", Tex.glow, plan.land + UP * 0.25, HELL)
	end

	-- v2 act 5: the last stroke (Config.MakeFinal), built when the server sends it. A camera-facing ink beam along the
	-- Bezier, painted from in front of the caster up through the target, a red-hot aura that gathers in the beat, and
	-- the burst.
	local finalStroke
	local function revealSeq(p, alpha)
		if p <= 0 then return NumberSequence.new(1) end
		if p >= 1 then return NumberSequence.new(alpha) end
		local pa = math.clamp(p - 0.035, 0.001, 0.996)
		local pb = math.clamp(p, pa + 0.002, 0.999)
		return NumberSequence.new({
			NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(pa, alpha),
			NumberSequenceKeypoint.new(pb, 1), NumberSequenceKeypoint.new(1, 1),
		})
	end
	local function buildFinal(fin)
		local holder = part(folder, "FinalStroke", Vector3.one * 0.2, CFrame.new(fin.point))
		-- beam curve: P1 = P0 + axis0 * CurveSize0, P2 = P3 - axis1 * CurveSize1
		local c0 = (fin.b - fin.a) / 3 + fin.w
		local c1 = (fin.b - fin.a) / 3 - fin.w
		local P0, P1, P2, P3 = fin.a, fin.a + c0, fin.b - c1, fin.b
		local function att(pos, axis)
			local x = axis.Magnitude > 1e-3 and axis.Unit or Vector3.xAxis
			local z = x:Cross(UP)
			z = z.Magnitude > 0.01 and z.Unit or Vector3.xAxis
			local a = Instance.new("Attachment")
			a.CFrame = CFrame.fromMatrix(pos - fin.point, x, z:Cross(x))
			a.Parent = holder
			return a
		end
		local a0, a1 = att(P0, c0), att(P3, c1)
		-- the same curve split in two at the target (de Casteljau at t = 0.5, which is fin.point), for the aura
		local L1, L2 = (P0 + P1) / 2, (P0 + 2 * P1 + P2) / 4
		local R1, R2 = (P1 + 2 * P2 + P3) / 4, (P2 + P3) / 2
		local M = (L2 + R1) / 2
		local am = att(M, R1 - L2)
		local function beam(tex, color, width, emission, z, from, to, size0, size1)
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = from or a0, to or a1
			b.CurveSize0, b.CurveSize1 = size0 or c0.Magnitude, size1 or c1.Magnitude
			b.Texture = tex
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureLength = 1
			b.TextureSpeed = 0 -- the default (1) slides the texture along the beam
			b.Color = ColorSequence.new(color)
			b.LightInfluence = 0
			b.LightEmission = emission
			b.Width0, b.Width1 = width, width
			b.FaceCamera = true
			b.Segments = tier == 1 and 16 or 30
			b.ZOffset = z
			b.Transparency = NumberSequence.new(1)
			b.Parent = holder
			return b
		end
		local F = { fin = fin, spots = {}, cards = {} }
		-- the ink. A Beam lays its texture sideways (texture X across the width, Y along the length) and slides it,
		-- so the stroke picture came out as a flat-ended black slab (Studio test 2026-11-11). It goes on flat cards
		-- along the curve instead, like the dash strokes: one picture over the whole stroke, each card shows its slice.
		-- A SurfaceGui is one-sided, so every slice has a card facing each side of the stroke plane, and they are drawn
		-- over everything: the ink crosses the paper-white target instead of hiding behind its Highlight.
		local PX = 24
		local segs = tier == 1 and 4 or 6
		local cardH = fin.width * 1.4 -- room for the swell as it bursts
		local n0 = fin.root.RightVector -- normal of the stroke plane (the strike direction and up)
		local pts, cum = { fin.a }, { 0 }
		for k = 1, segs do
			pts[k + 1] = Config.FinalAt(fin, k / segs)
			cum[k + 1] = cum[k] + (pts[k + 1] - pts[k]).Magnitude
		end
		local L = cum[segs + 1]
		F.length, F.px, F.cardH = L, PX, cardH
		for k = 1, segs do
			local a, b = pts[k], pts[k + 1]
			local d3 = (b - a).Unit
			local from, len = cum[k] - 0.15, (b - a).Magnitude + 0.3 -- slices overlap a little: no gaps at the bends
			for _, n in { n0, -n0 } do
				-- a Top-face SurfaceGui runs canvas X along the part's -Z (= d3: canvas left = the start of the slice)
				local card = part(folder, "FinalCard", Vector3.new(cardH, 0.05, len), CFrame.fromMatrix((a + b) / 2 + n * 0.05, d3:Cross(n), n))
				local sg = Instance.new("SurfaceGui")
				sg.Face = Enum.NormalId.Top
				sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
				sg.CanvasSize = Vector2.new(math.max(8, math.floor(len * PX)), math.floor(cardH * PX))
				sg.LightInfluence = 0
				sg.AlwaysOnTop = true
				sg.Adornee = card
				sg.Parent = card
				local clip = Instance.new("Frame")
				clip.BackgroundTransparency = 1
				clip.ClipsDescendants = true
				clip.Size = UDim2.fromScale(0, 1)
				clip.Parent = sg
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.Image = Tex.strokeGround or Tex.stroke
				img.ImageColor3 = BLACK
				img.ImageTransparency = 0.02
				img.Size = UDim2.fromOffset(math.floor(L * PX), math.floor(fin.width * PX))
				img.Position = UDim2.fromOffset(-math.floor(from * PX), math.floor((cardH - fin.width) * PX / 2))
				img.Parent = clip
				table.insert(F.cards, { from = from, len = len, clip = clip, img = img, x = -math.floor(from * PX) })
			end
		end
		-- a red-hot aura behind the ink: black ink alone vanished against the dark red world (Studio test 2026-11-11).
		-- One soft glow per half, so it is brightest where the stroke shows either side of the target
		F.halo = {
			beam(Tex.glow, HELL, fin.width * 1.8, 1, -0.5, a0, am, (L1 - P0).Magnitude, (M - L2).Magnitude),
			beam(Tex.glow, HELL, fin.width * 1.8, 1, -0.5, am, a1, (R1 - M).Magnitude, (P3 - R2).Magnitude),
		}
		for _, tt in { 0.2, 0.5, 0.8 } do
			local sp = part(folder, "FinalBurst", Vector3.one * (fin.width * 0.35), CFrame.new(Config.FinalAt(fin, tt)))
			local burst = emitter(sp, {
				Texture = Tex.splat, Color = ColorSequence.new(BLACK), Size = seq({ { 0, 1.6 }, { 0.15, 4 }, { 1, 1.2 } }),
				Transparency = seq({ { 0, 0 }, { 0.75, 0.15 }, { 1, 1 } }), Lifetime = NumberRange.new(0.5, 0.9),
				Speed = NumberRange.new(26, 58), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -70, 0),
				Drag = 1.2, Rotation = NumberRange.new(-180, 180), RotSpeed = NumberRange.new(-140, 140),
				Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			})
			flip2x2(burst)
			local drip = emitter(sp, { -- wet ink running off the stroke during the beat
				Texture = Tex.splat, Color = ColorSequence.new(BLACK), Size = seq({ { 0, 0.5 }, { 0.3, 1 }, { 1, 0.4 } }),
				Squash = seq({ { 0, 0.8 }, { 1, 1.6 } }), Transparency = seq({ { 0, 0.05 }, { 1, 0.6 } }),
				Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(0, 2), Acceleration = Vector3.new(0, -45, 0),
				Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			})
			flip2x2(drip)
			local hot = emitter(sp, {
				Texture = Tex.fire, Color = FIRE, LightEmission = 1, Size = seq({ { 0, 3 }, { 0.4, 7 }, { 1, 2 } }),
				Transparency = seq({ { 0, 0.15 }, { 0.7, 0.35 }, { 1, 1 } }), Lifetime = NumberRange.new(0.45, 0.8),
				Speed = NumberRange.new(10, 24), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(-20, 20),
				Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			})
			hot.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			hot.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
			table.insert(F.spots, { part = sp, burst = burst, drip = drip, hot = hot })
		end
		-- the shockwave and the red ground flash move under the target
		local under = Vector3.new(fin.point.X, fin.floor or fin.groundY, fin.point.Z)
		ringPart.CFrame = CFrame.new(fin.point)
		if finalGlow then finalGlow.part:Destroy() end
		finalGlow = groundCard(folder, "FinalGlow", Tex.glow, under + UP * 0.25, HELL)
		finalStroke = F
	end

	local FA = Config.Act -- (ACT is declared further down)
	local function updateFinal(s)
		local F = finalStroke
		if not F then return end
		local fin = F.fin
		-- the wet front runs from above the caster, through the target and out beyond it, ahead of the brush
		local p = outCubic(lin(FA.Stroke + 0.03, FA.Mark, s))
		local gone = lin(FA.Final, FA.Final + 0.2, s) -- it bursts: thrown apart in a fifth of a second
		local swell = 1 + 0.4 * outCubic(gone)
		local front = p * (F.length + 0.15)
		local w, h = math.floor(F.length * F.px), math.floor(fin.width * swell * F.px)
		local y = math.floor((F.cardH * F.px - h) / 2)
		for _, c in F.cards do
			c.clip.Size = UDim2.fromScale(p > 0 and math.clamp((front - c.from) / c.len, 0, 1) or 0, 1)
			c.img.ImageTransparency = 0.02 + 0.98 * gone
			c.img.Size = UDim2.fromOffset(w, h)
			c.img.Position = UDim2.fromOffset(c.x, y)
		end
		-- the aura comes in with the wet front, gathers heat through the beat (flickering) and flares out as it bursts
		local heat = window(s, FA.Mark + 0.03, 0.22, FA.Final + 0.2, 0.2)
		local flicker = 0.85 + 0.15 * math.sin(s * 53)
		local aura = math.clamp((0.45 + 0.45 * heat) * flicker * (1 - gone), 0, 1)
		local hw = fin.width * (1.6 + 0.4 * heat + 1.2 * outCubic(gone))
		for i, h in F.halo do
			h.Transparency = revealSeq(math.clamp(p * 2 - (i - 1), 0, 1), 1 - aura) -- each half follows the wet front
			h.Width0, h.Width1 = hw, hw
		end
		local dripping = s >= FA.Mark and s < FA.Final
		for _, sp in F.spots do
			sp.drip.Rate = dripping and 22 * k or 0
		end
	end

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
	cue("vortexHit1", T.Wide, function() impactSplash:Emit(math.floor(10 * k)) end)
	cue("vortexHit2", T.Wide + 0.35, function() impactSplash:Emit(math.floor(10 * k)) end)
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

	-- v2 cues run on story time
	local cuesS = {}
	local function cueS(name, at, fn)
		table.insert(cuesS, { name = name, t = at, fn = fn })
	end
	local ACT, St = Config.Act, Config.Strokes -- (A is the giant stroke's start point)
	if plan then
		cueS("dive", ACT.Dive, function() playSound(fx, "rise", origin.Position, 0.55) end)
		for i, st in St do
			cueS("dash" .. i, st.from, function() playSound(fx, "claw", plan.strokes[i][1], 1) end)
		end
		cueS("leap", ACT.Leap, function() playSound(fx, "rise", origin.Position, 0.5) end)
		cueS("stroke", ACT.Stroke, function()
			if plan.final then playSound(fx, "claw", plan.final.point, 1.3) end
		end)
		cueS("mark", ACT.Mark, function() -- the stroke is through: the target flashes and turns to blank paper
			local fin = plan.final
			if not fin then return end
			hitPart.CFrame = CFrame.new(fin.point)
			hitSplash:Emit(math.floor(36 * k))
			hitFlash:Emit(2)
			for _, v in fx.victims do
				if fin.model and v.m == fin.model then
					v.paper = true
					v.flash = fx.s
				end
			end
			playSound(fx, "slam", fin.point, 0.8)
		end)
		cueS("plant", ACT.Final, function() -- the last stroke bursts (or the brush is planted): every stroke explodes
			for _, d in dashes do
				d.erupt:Emit(math.floor(45 * k))
				d.fire:Emit(math.floor(30 * k))
			end
			local fin = plan.final
			if finalStroke then
				for _, sp in finalStroke.spots do
					sp.burst:Emit(math.floor(34 * k))
					sp.hot:Emit(math.floor(10 * k))
				end
				hitPart.CFrame = CFrame.new(fin.point)
				hitSplash:Emit(math.floor(45 * k))
				hitFlash:Emit(2)
			end
			for _, v in fx.victims do
				if v.paper then -- back to ink with a white flash as it is blown away
					v.paper = false
					v.flash = fx.s
				end
			end
			local n = tier == 1 and 16 or 28
			for i = 1, n do
				ringAtt.CFrame = CFrame.Angles(0, (i + math.random()) * math.pi * 2 / n, 0)
				ring:Emit(tier == 1 and 2 or 3)
			end
			local at = fin and fin.point or plan.land
			playSound(fx, "slam", at, 1.3)
			playSound(fx, "thunder", at, 0.8)
		end)
	end

	-- monster hits: a white flash + a jolt (pass), or thrown up (eruption). Bound monsters are anchored by the server,
	-- so the jolt is a local CFrame offset that ends exactly where it started.
	local function kick(v, s, kind, dir)
		v.kicks = v.kicks or {}
		table.insert(v.kicks, { s = s, kind = kind, dir = dir })
		v.flash = s
		hitPart.CFrame = CFrame.new(v.root.Position + UP)
		hitSplash:Emit(math.floor((kind == "pass" and 10 or 16) * k))
		hitFlash:Emit(1)
	end

	local function updateDashes(s, t, info)
		for i, d in dashes do
			local st = St[i]
			if s >= st.from then
				local prog = math.min(Config.StrokeProgress(plan, i, s), d.len) -- where the caster is
				if s >= st.to then
					d.revealed = d.len
				else
					local tipAlong = Config.StrokeProject(plan, i, info.tip) -- the ink follows the brush tip
					d.revealed = math.clamp(math.max(d.revealed, math.min(prog, tipAlong + 1.5)), 0, d.len)
				end
				local col = t > T.Red and DARK_RED or BLACK
				local fade = 0.02 + 0.98 * lin(T.Restore, T.End - 0.1, t)
				for _, c in d.cards do
					local w = math.clamp((d.revealed - c.from) / c.len, 0, 1)
					if math.abs(w - c.shown) > 1e-3 then
						c.shown = w
						c.clip.Size = UDim2.fromScale(w, 1)
					end
					c.img.ImageColor3 = col
					c.img.ImageTransparency = fade
				end
				if s < st.to then
					dashPart.CFrame = CFrame.new(Config.StrokeAt(plan, i, d.revealed) + UP * 0.4)
					for _, v in fx.victims do
						if not d.passed[v] and v.root.Parent then
							local along, side = Config.StrokeProject(plan, i, v.root.Position)
							if side <= Config.StrokeHit.passWidth and along >= -3 and along <= prog + 1 then
								d.passed[v] = true
								kick(v, s, "pass", plan.dir[i])
								fx.hitPulse = s
							end
						end
					end
				end
				if s >= st.erupt and not d.erupted then
					d.erupted = true
					d.erupt:Emit(math.floor(70 * k))
					d.fire:Emit(math.floor(26 * k)) -- particles keep their colour in the grey world: a hot accent on the ink
					if i == #dashes then demonRise:Emit(math.floor(12 * k)) end
					playSound(fx, "slam", Config.StrokeAt(plan, i, d.len * 0.5), 1.1)
					for _, v in fx.victims do
						if v.root.Parent then
							local along, side = Config.StrokeProject(plan, i, v.root.Position)
							if side <= Config.StrokeHit.eruptWidth and along >= -4 and along <= d.len + 4 then kick(v, s, "erupt") end
						end
					end
				end
				if d.light then
					local burst = s >= st.erupt and 4.5 * math.exp(-(s - st.erupt) * 4) or 0 -- lights the dark forest floor
					d.light.Brightness = math.max(burst, 3.2 * window(t, T.Final, 0.08, T.End, 0.5))
				end
				d.fire.Rate = (t >= T.Final and t < T.Restore + 0.25) and 14 * k or 0
			end
		end
		local dashing = false
		for _, st in St do
			if s >= st.from and s < st.to then dashing = true end
		end
		dashSpray.Rate = dashing and 170 * k or 0
		trailPart.CFrame = fx.rootCF
		trail.Enabled = s >= ACT.Dive and s < ACT.Resume
		-- the final flash on the ground
		local fg = lin(ACT.Final, ACT.Final + 0.4, s)
		finalGlow.set(10 + 100 * outCubic(fg), fg <= 0 and 1 or (0.15 + 0.85 * fg), HELL)
	end

	local function updateVictims(s)
		for _, v in fx.victims do
			if v.kicks and #v.kicks > 0 then
				if v.root.Parent and v.root.Anchored and s < ACT.Final - 0.1 then
					if not v.base then v.base = v.root.CFrame end
					local off, live = Vector3.zero, false
					for _, kk in v.kicks do
						local age = s - kk.s
						if kk.kind == "pass" then
							local u = age / 0.3
							if u < 1 then
								live = true
								off += (UP * 1.2 + kk.dir * 1.6) * math.sin(math.pi * u)
							end
						else
							local u = age / 0.62
							if u < 1 then
								live = true
								off += UP * 5.5 * (4 * u * (1 - u))
							end
						end
					end
					if live then
						v.root.CFrame = v.base + off
					else
						v.root.CFrame = v.base
						v.base, v.kicks = nil, {}
					end
				else
					if v.base and v.root.Parent and v.root.Anchored then v.root.CFrame = v.base end
					v.base, v.kicks = nil, {}
				end
			end
			if v.flash then
				local fa = math.clamp((s - v.flash) / 0.14, 0, 1)
				v.hl.FillColor = Color3.new(1, 1, 1):Lerp(v.paper and PAPER or BLACK, fa)
				if fa >= 1 then v.flash = nil end
			end
		end
	end

	local dragon
	function fx:Update(s, rootCF, tau)
		local t = Config.V1(s)
		fx.s, fx.rootCF = s, rootCF
		-- the last stroke arrives from the server once the target is bound
		if plan and plan.final and finalStroke == nil then
			local ok, err = pcall(buildFinal, plan.final)
			if not ok then
				warn("[InkPainting] final stroke: " .. tostring(err))
				finalStroke = false
			end
		end
		pose.final = plan and plan.final
		local info = pose:Update(s, rootCF)
		fx.tip = info.tip
		for _, c in fx.cues do
			if not c.done and t >= c.t then
				c.done = true
				local ok, err = pcall(c.fn)
				if not ok then warn("[InkPainting] cue " .. c.name .. ": " .. tostring(err)) end
			end
		end
		for _, c in cuesS do
			if not c.done and s >= c.t then
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
			ring.part.CFrame = CFrame.new(cloudCenter) * CFrame.Angles(0, s * (i == 1 and 0.3 or -0.45), 0)
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
			v.hl.FillTransparency = v.paper and 0.04 or (1 - 0.85 * bind) -- solid ink: at 0.45 the light monster skin showed through as pink
			v.hl.OutlineTransparency = v.paper and 0 or (1 - 0.8 * bind)
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
			local at = d.at:Lerp(P + UP * 4, dive)
			if plan then
				-- the v2 finale camera waits at the landing: a demon diving past the lens filled the whole screen
				local cam = workspace.CurrentCamera
				local view = 2 * (cam.CFrame.Position - at).Magnitude * math.tan(math.rad(cam.FieldOfView) / 2)
				a *= math.clamp(1 - (d.size * s / math.max(view, 1) - 0.4) / 0.3, 0, 1)
			end
			d.card:Set(at, d.size * s, d.size * s, a, 1)
		end

		-- fire
		local fireOn = t > T.Demons + 0.05 and t < T.Restore + 0.25
		fire.Rate = fireOn and (t >= T.Final and 90 or 25) * k or 0
		fireLight.Brightness = 4 * window(t, T.Demons + 0.05, 0.2, T.End, 0.5)

		if plan then
			local ok, err = pcall(updateDashes, s, t, info)
			if ok then ok, err = pcall(updateFinal, s) end
			if not ok and not fx.warned then
				fx.warned = true
				warn("[InkPainting] dashes: " .. tostring(err))
			end
		end
		updateVictims(s)
		return info
	end

	function fx:Destroy()
		for _, v in fx.victims do -- a monster still mid-jolt goes back where the server holds it
			if v.base and v.root.Parent and v.root.Anchored then v.root.CFrame = v.base end
		end
		pcall(function() pose:Destroy() end)
		if dragon then pcall(function() dragon:Destroy() end) end
		if not fx.phantomGone then pcall(function() phantom:Destroy() end) end
		folder:Destroy()
		if fx.screenGui then fx.screenGui:Destroy() end
	end

	return fx
end

return FX
