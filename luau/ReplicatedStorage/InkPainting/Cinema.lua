-- InkPainting/Cinema (ModuleScript) -> ReplicatedStorage.InkPainting.Cinema
-- Caster-only part of the G ultimate: camera shots, ink-storm skybox, grade (grey ink world -> red hell), screen
-- overlays (rice paper, ink frame, ink flood), letterbox, title card and a skip button. Everything is local and
-- restored in Destroy. Player attribute UltCutscene = false skips it (same switch as the sword ultimates).
-- v2: Update(s, tau) takes story time + real time. Rule (will 2026-11-10): every shot shows the caster's own moves,
-- the technique and the monsters getting hit; hits are felt (shake, flash, lens punch; the freezes are in Config).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local CAS = game:GetService("ContextActionService")
local Config = require(script.Parent:WaitForChild("Config"))

local T, Tex = Config.T, Config.Tex
local ease = Config.ease
local UP = Vector3.yAxis
local TITLE = Font.new("rbxasset://fonts/families/Fondamento.json")
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)

local Cinema = {}

local function lin(a, b, x)
	return math.clamp((x - a) / (b - a), 0, 1)
end
local outCubicLocal = Config.outCubic

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

-- Map scan, spread over frames, done when the brush comes out (Cinema.Prepare). It collects what the per-frame camera
-- code cannot reach on its own: parts with CanQuery off (the forest trees are like that, so raycasts and overlap queries
-- miss them) and see-through foliage (SurfaceAppearance in Transparency mode), which the colour grade does not grey.
local LEAF_INK = Color3.fromRGB(50, 40, 52) -- multiplies any leaf colour down to near-black ink
local SKIP_ROOTS = { Terrain = true, Camera = true, Monsters = true, TownNPCs = true }
local scan = { list = nil, at = -1e9, busy = false }

function Cinema.Prepare()
	if scan.busy or os.clock() - scan.at < 90 then return end
	scan.busy = true
	task.spawn(function()
		local found, stack, n = {}, {}, 0
		for _, c in workspace:GetChildren() do
			if not (SKIP_ROOTS[c.Name] or c:IsA("Terrain") or c.Name:sub(1, 11) == "InkPainting" or (c:IsA("Model") and Players:GetPlayerFromCharacter(c))) then
				table.insert(stack, c)
			end
		end
		while #stack > 0 do
			local inst = table.remove(stack)
			if inst:IsA("BasePart") then
				local sa = inst:FindFirstChildOfClass("SurfaceAppearance")
				local leafy = sa ~= nil and sa.AlphaMode == Enum.AlphaMode.Transparency
				local ghost = not inst.CanQuery and inst.Transparency < 1 and inst.Size.Magnitude < 140
				if ghost or leafy then table.insert(found, { part = inst, sa = leafy and sa or nil, ghost = ghost }) end
			end
			for _, c in inst:GetChildren() do
				table.insert(stack, c)
			end
			n += 1
			if n % 1500 == 0 then task.wait() end
		end
		scan.list, scan.at, scan.busy = found, os.clock(), false
	end)
end

-- segment a -> b against a part's box (half size * shrink), in the box's own space
local function slab(o, d, h, t0, t1)
	if math.abs(d) < 1e-6 then
		if o < -h or o > h then return nil end
		return t0, t1
	end
	local ta, tb = (-h - o) / d, (h - o) / d
	if ta > tb then ta, tb = tb, ta end
	t0, t1 = math.max(t0, ta), math.min(t1, tb)
	if t0 > t1 then return nil end
	return t0, t1
end

local function segmentHitsBox(cf, half, a, b)
	local la = cf:PointToObjectSpace(a)
	local d = cf:PointToObjectSpace(b) - la
	local t0, t1 = slab(la.X, d.X, half.X, 0, 1)
	if not t0 then return false end
	t0, t1 = slab(la.Y, d.Y, half.Y, t0, t1)
	if not t0 then return false end
	return slab(la.Z, d.Z, half.Z, t0, t1) ~= nil
end

-- {t, saturation, contrast, brightness, tint}
local PAPER_TINT = Color3.new(1, 0.965, 0.9)
local RED_TINT = Color3.new(1, 0.3, 0.26)
local GRADE = {
	{ 0, 0, 0, 0, Color3.new(1, 1, 1) },
	{ T.Rise, -0.45, 0.1, 0, Color3.new(1, 1, 1) },
	{ T.Sky, -0.97, 0.22, 0, Color3.new(1, 0.985, 0.95) },
	{ T.Painting - 0.01, -0.97, 0.22, 0, Color3.new(1, 0.985, 0.95) },
	{ T.Painting, -1, 0.36, 0.03, PAPER_TINT },
	{ T.Red - 0.01, -1, 0.36, 0.03, PAPER_TINT },
	{ T.Red, -1, 0.42, -0.03, RED_TINT },
	{ T.Restore, -1, 0.42, -0.03, RED_TINT },
	{ T.End, 0, 0, 0, Color3.new(1, 1, 1) },
}

local function grade(t)
	local n = #GRADE
	if t >= GRADE[n][1] then return GRADE[n] end
	for i = 1, n - 1 do
		local a, b = GRADE[i], GRADE[i + 1]
		if t < b[1] then
			local u = (t - a[1]) / math.max(1e-4, b[1] - a[1])
			if i == 1 or a[1] == T.Rise then u = ease(u) end
			return { t, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u, a[4] + (b[4] - a[4]) * u, a[5]:Lerp(b[5], u) }
		end
	end
	return GRADE[n]
end

local A, St = Config.Act, Config.Strokes
local function tauV1(t1)
	return Config.Tau(Config.SAtV1(t1))
end
-- {real time, amplitude, decay}
local SHAKES = {
	{ tauV1(T.Impact), 1.0, 9 },
	{ tauV1(T.Wide), 0.35, 12 },
	{ tauV1(T.Wide + 0.35), 0.35, 12 },
	{ tauV1(T.Claws), 0.6, 10 },
	{ tauV1(T.Claws + 0.14), 0.45, 10 },
	{ tauV1(T.Dive), 0.4, 6 },
	{ Config.Tau(A.Mark), 1.1, 7 }, -- the last stroke goes through the target
	{ Config.Tau(A.Final), 1.7, 5 },
}
-- {real time, flash strength, decay, colour} and {real time, lens punch in degrees}
local WHITE, WARM = Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 205)
local FLASHES = { { tauV1(T.Impact), 0.75, 22, WHITE }, { Config.Tau(A.Mark), 0.5, 20, WHITE }, { Config.Tau(A.Final), 0.8, 14, WARM } }
local PUNCHES = { { tauV1(T.Impact), -5 }, { Config.Tau(A.Mark), -5 }, { Config.Tau(A.Final), -10 } }
for _, st in St do
	table.insert(SHAKES, { Config.Tau(st.from), 0.3, 12 }) -- push off
	table.insert(SHAKES, { Config.Tau(st.erupt), 0.95, 8 })
	table.insert(FLASHES, { Config.Tau(st.erupt), 0.5, 26, WHITE })
	table.insert(PUNCHES, { Config.Tau(st.erupt), -6 })
end
local GOLD = Color3.fromRGB(236, 196, 120)

function Cinema.New(ctx, fx)
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local origin, P = ctx.origin, ctx.P
	local f = Vector3.new(origin.LookVector.X, 0, origin.LookVector.Z).Unit
	local r = f:Cross(UP).Unit
	local E = P + UP * 58 - f * 6
	local char = ctx.char
	local self = { connections = {}, hidden = {}, core = {}, transparency = {} }

	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { char, fx.folder }
	local monsters = workspace:FindFirstChild("Monsters")
	if monsters then table.insert(ignore, monsters) end
	rp.FilterDescendantsInstances = ignore
	local g0 = workspace:Raycast(origin.Position + UP * 4, -UP * 40, rp)
	-- only terrain pushes the camera in: trees, props and buildings are faded instead (big tree meshes have
	-- collision boxes the size of a house and used to shove the camera into the caster's back)
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
	local ground0 = g0 and g0.Position or origin.Position - UP * 3

	-- save + take over
	self.cam = { type = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView, cframe = camera.CFrame, focus = camera.Focus }
	camera.CameraType = Enum.CameraType.Scriptable
	for _, g in pg:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "InkPaintingSky" then
			self.hidden[g] = true
			g.Enabled = false
		end
	end
	for _, core in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Chat, Enum.CoreGuiType.Health } do
		local ok, on = pcall(function() return StarterGui:GetCoreGuiEnabled(core) end)
		if ok then
			self.core[core] = on
			pcall(function() StarterGui:SetCoreGuiEnabled(core, false) end)
		end
	end
	-- first person hides the body; the held brush stays hidden (Pose draws its own copy)
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") and p.LocalTransparencyModifier ~= 0 and not (ctx.tool and p:IsDescendantOf(ctx.tool)) then
			self.transparency[p] = p.LocalTransparencyModifier
			p.LocalTransparencyModifier = 0
		end
	end
	-- no name tags, health bars or prompts in the painting
	self.tags = {}
	local tagRoots = { workspace:FindFirstChild("Monsters"), workspace:FindFirstChild("TownNPCs") }
	for _, other in Players:GetPlayers() do
		if other.Character then table.insert(tagRoots, other.Character) end
	end
	for _, tagRoot in tagRoots do
		for _, d in tagRoot:GetDescendants() do
			if d:IsA("BillboardGui") and d.Enabled then
				self.tags[d] = true
				d.Enabled = false
			end
		end
	end
	local prompts = game:GetService("ProximityPromptService")
	self.prompts = prompts.Enabled
	prompts.Enabled = false
	self.faded = {}
	CAS:BindActionAtPriority("InkPaintingSink", function() return Enum.ContextActionResult.Sink end, false, 3000,
		Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.Z, Enum.KeyCode.X)

	local cc = make("ColorCorrectionEffect", { Name = "InkPaintingGrade" }, camera)
	self.cc = cc
	-- terrain grass blades are drawn after the colour grade (like see-through leaves), so they stayed green in the
	-- grey ink world: grey their material colour along with the grade (this client only) and put it back at the end
	local terrain = workspace.Terrain
	self.grass = {}
	for _, m in { Enum.Material.Grass, Enum.Material.LeafyGrass } do
		local ok, c0 = pcall(terrain.GetMaterialColor, terrain, m)
		if ok then self.grass[m] = { c0 = c0 } end
	end
	local GRASS_INK = Color3.new(0.345, 0.36, 0.32) -- a touch green: the map's lilac ambient tints the blades
	local function gradeGrass(k, tint)
		for m, g in self.grass do
			local c = g.c0:Lerp(GRASS_INK, k)
			c = Color3.new(c.R * tint.R, c.G * tint.G, c.B * tint.B)
			local cur = g.cur
			if not cur or math.abs(cur.R - c.R) + math.abs(cur.G - c.G) + math.abs(cur.B - c.B) > 0.015 then
				g.cur = c
				pcall(terrain.SetMaterialColor, terrain, m, c)
			end
		end
	end
	self.expo0 = Lighting.ExposureCompensation -- the ink world is pale paper, not the dark forest floor
	-- soft key light that follows the caster on the camera side (forest shade would hide the face otherwise)
	local world = make("Folder", { Name = "InkPaintingCinemaWorld" }, workspace)
	local keyPart = make("Part", { Name = "KeyLight", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1, Size = Vector3.one * 0.2 }, world)
	local key = make("PointLight", { Color = Color3.fromRGB(255, 238, 220), Range = 16, Brightness = 0, Shadows = false }, keyPart)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { char, fx.folder, world }
	-- trees and leaves around the painting from the map scan (anchored scenery, so their boxes are cached here)
	local ghosts, leaves = {}, {}
	self.tinted, self.leafInk = {}, 0
	for _, e in scan.list or {} do
		local p = e.part
		if p.Parent then
			local d = (p.Position - P).Magnitude
			if e.ghost and p.Anchored and d - p.Size.Magnitude * 0.5 < 90 then
				local half = p.Size * (p.Size.Magnitude < 25 and 0.46 or 0.35) -- bushes fill their box, fir crowns do not
				table.insert(ghosts, {
					part = p, cf = p.CFrame, center = p.Position, size = p.Size, half = half, radius = half.Magnitude,
					lens = p.Size.Magnitude < 125, reach = p.Size.Magnitude * 0.5 + 4.5,
				})
			end
			if e.sa and e.sa.Parent == p and d < 260 then table.insert(leaves, e.sa) end
		end
	end
	Cinema.Prepare() -- fresh scan for the next cast

	-- sky + atmosphere (swapped at the shot-2 cut)
	local sky = Instance.new("Sky")
	sky.Name = "InkPaintingSky"
	sky.SkyboxBk, sky.SkyboxLf, sky.SkyboxFt, sky.SkyboxRt = Tex.skySide[1], Tex.skySide[2], Tex.skySide[3], Tex.skySide[4]
	sky.SkyboxUp, sky.SkyboxDn = Tex.skyUp, Tex.skyUp
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	self.sky = sky
	self.oldSkies = {}
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		self.atm = atm
		self.atmSaved = { Density = atm.Density, Offset = atm.Offset, Color = atm.Color, Decay = atm.Decay, Glare = atm.Glare, Haze = atm.Haze }
	end

	-- overlays
	local gui = make("ScreenGui", { Name = "InkPaintingCinema", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, pg)
	self.gui = gui
	local paper = make("ImageLabel", { Name = "Paper", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Tex.paper, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(512, 512), ImageTransparency = 1, ZIndex = 2 }, gui)
	local vignette = make("ImageLabel", { Name = "InkFrame", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Tex.vignette, ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 1, ZIndex = 3 }, gui)
	local flood = make("ImageLabel", { Name = "InkFlood", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Image = Tex.bleed, ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 1, ZIndex = 5 }, gui)
	local black = make("Frame", { Name = "Black", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5 }, gui)
	local redFlood = make("ImageLabel", { Name = "RedFlood", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Image = Tex.bleedWhite or Tex.bleed, ImageColor3 = Color3.fromRGB(205, 18, 14), ImageTransparency = 1, ZIndex = 6 }, gui)
	local flash = make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 7 }, gui)
	local bars = {}
	for _, top in { true, false } do
		table.insert(bars, make("Frame", { AnchorPoint = Vector2.new(0, top and 1 or 0), Position = UDim2.fromScale(0, top and 0 or 1), Size = UDim2.fromScale(1, 0.075), BackgroundColor3 = Color3.fromRGB(8, 7, 9), BorderSizePixel = 0, ZIndex = 8 }, gui))
	end
	-- title card while the caster rises: black ink swipe, gold name, red seal (v2, replaces the small bar title)
	local card = make("Frame", { Name = "TitleCard", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.05, 0.6), Size = UDim2.fromScale(0.4, 0.2), BackgroundTransparency = 1, ZIndex = 9 }, gui)
	make("UIAspectRatioConstraint", { AspectRatio = 3.2 }, card)
	local swipeClip = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 9 }, card)
	local swipe = make("ImageLabel", { Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Image = Tex.stroke, ImageColor3 = Color3.fromRGB(8, 7, 9), ImageTransparency = 0.04, ZIndex = 9 }, swipeClip)
	local cjk = make("TextLabel", { Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.58, 0.62), BackgroundTransparency = 1, Text = Config.TitleCJK, Font = Enum.Font.Antique, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, TextTransparency = 1, ZIndex = 10 }, card)
	local cjkStroke = make("UIStroke", { Color = Color3.fromRGB(26, 8, 6), Thickness = 2, Transparency = 1 }, cjk)
	local cjkScale = make("UIScale", { Scale = 1 }, cjk)
	local latin = make("TextLabel", { Position = UDim2.fromScale(0.06, 0.68), Size = UDim2.fromScale(0.82, 0.2), BackgroundTransparency = 1, Text = Config.TitleLatin, FontFace = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(242, 230, 204), TextTransparency = 1, ZIndex = 10 }, card)
	local seal = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.74, 0.36), Size = UDim2.fromScale(0.2, 0.55), BackgroundColor3 = Color3.fromRGB(178, 28, 22), BackgroundTransparency = 1, Rotation = -7, ZIndex = 11 }, card)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, seal)
	make("UICorner", { CornerRadius = UDim.new(0.1, 0) }, seal)
	local sealScale = make("UIScale", { Scale = 1 }, seal)
	local sealText = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "墨", Font = Enum.Font.Antique, TextScaled = true, TextColor3 = Color3.fromRGB(255, 238, 222), TextTransparency = 1, ZIndex = 12 }, seal)
	local skip = make("TextButton", { Name = "Skip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.962, 0), Size = UDim2.fromOffset(112, 30), BackgroundColor3 = Color3.fromRGB(20, 18, 20), BackgroundTransparency = 0.35, Text = "LEWATI  >>", FontFace = BODY, TextSize = 14, TextColor3 = Color3.fromRGB(230, 222, 210), AutoButtonColor = true, ZIndex = 10 }, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, skip)
	make("UIStroke", { Color = Color3.fromRGB(150, 140, 130), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, skip)
	skip.Activated:Connect(function()
		self.skipped = true
		self:Destroy()
	end)
	CAS:BindActionAtPriority("InkPaintingSkip", function(_, state)
		if state == Enum.UserInputState.Begin then
			self.skipped = true
			task.defer(function() self:Destroy() end)
		end
		return Enum.ContextActionResult.Sink
	end, false, 3001, Enum.KeyCode.ButtonB)

	local function casterPos()
		local root = char:FindFirstChild("HumanoidRootPart")
		return root and root.Position or origin.Position
	end
	local function headPos()
		local head = char:FindFirstChild("Head")
		return head and head.Position or casterPos() + UP * 1.5
	end
	local function dragonFocus()
		local d = fx.dragon
		if d and d.DragonFocus then
			local ok, cf = pcall(d.DragonFocus, d)
			if ok and typeof(cf) == "CFrame" then return cf.Position end
		end
		return nil
	end

	-- v2 shots. The camera works each stroke from the side away from the painting centre, so the bound monsters are
	-- behind the caster as he passes them (stroke 2 runs through the centre: the caster's start side).
	local plan = ctx.plan
	local camSide = {}
	if plan then
		for i, pts in plan.strokes do
			local d = plan.dir[i]
			local n = d:Cross(UP).Unit
			local mid = (pts[1] + pts[#pts]) / 2
			local toP = Vector3.new(P.X - mid.X, 0, P.Z - mid.Z)
			local away = toP.Magnitude > 4 and -toP.Unit or -f
			if n:Dot(away) < 0 then n = -n end
			camSide[i] = n
		end
	end

	local function act2Shot(s)
		local c = casterPos()
		if s < St[1].from then -- backflip down to stroke 1, seen from beside its start
			local a, d, n = plan.strokes[1][1], plan.dir[1], camSide[1]
			local u = ease(lin(A.Dive, St[1].from, s))
			return a - d * 11 + n * 14 + UP * (3.5 + 1.5 * (1 - u)), c:Lerp(a + UP * 2, 0.35), 70
		end
		for i, st in St do
			local nextSt = St[i + 1]
			local d, n = plan.dir[i], camSide[i]
			if s < st.to then -- dash: tracking beside him and above, so the wet stroke trails out behind the brush
				local u = lin(st.from, st.to, s)
				return c + d * (2.5 - 1.5 * u) + n * 12 + UP * 7, c + d * 3.5 - UP * 0.6, 70
			elseif (nextSt and s < nextSt.from) or (not nextSt and s < A.Resume) then
				-- corner: just past the caster, looking back along the stroke as it erupts (the last one: follow him up)
				local pts = plan.strokes[i]
				local b, mid = pts[#pts], (pts[1] + pts[#pts]) / 2
				local u = ease(lin(st.to, nextSt and nextSt.from or A.Resume, s))
				local look = mid + UP * 1.5
				if not nextSt then
					look = look:Lerp(c, ease(lin(st.to + 0.18, A.Resume, s)))
					return b + d * 8 + n * 5 + UP * (7 + u), look, 74
				end
				-- pull back on his side of the stroke, looking across it towards the clearing: the stroke erupts between
				-- him and the monsters (beyond the corner the camera stood in the forest and the trees filled the frame)
				return b - d * (5 + 2 * u) + n * 14 + UP * (9 + u), b:Lerp(mid, 0.3) + UP, 74
			end
		end
		return c - f * 13 + UP * 5, c, 70
	end

	local function finaleShot(s, t)
		local c = casterPos()
		local land = plan.land
		local fin = plan.final
		if fin then -- the last stroke, side on: the caster on one side, the target on the other, the whole stroke across
			local sp, pt = fin.root.Position, fin.point
			local d = Config.flat(pt - sp)
			local side = d:Cross(UP).Unit
			if side:Dot(r) < 0 then side = -side end
			local lo = math.min(fin.groundY, sp.Y - 3)
			local hi = math.max(fin.b.Y + fin.width * 0.3, sp.Y + 17) -- the stroke's tail, the brush held high (2.1x)
			-- behind him: room for the brush as it whips up from behind his back
			local x0, x1 = math.min((fin.a - pt):Dot(d), (sp - pt):Dot(d)) - 7, (fin.b - pt):Dot(d) + 2
			local center = Vector3.new(pt.X, (lo + hi) / 2, pt.Z) + d * ((x0 + x1) / 2)
			local vp = camera.ViewportSize
			local aspect = math.max(vp.X / math.max(vp.Y, 1), 1)
			local fov = 58
			local tv = math.tan(math.rad(fov / 2))
			local dist = math.max((x1 - x0) / 2 / (tv * aspect), (hi - lo) / 2 / (tv * 0.85)) + 2 -- 0.85: the letterbox bars
			if s < A.Stroke then -- the dive: low beside the spot, he drops out of the sky onto the target, and the
				-- frame settles into the stroke shot as he lands (it used to jump at the landing)
				local u = lin(A.Fall, A.Stroke, s)
				local k = ease(lin(0.55, 1, u))
				local pos = (center + side * dist * 0.95 - UP * ((hi - lo) * 0.2)):Lerp(center + side * dist - UP, k)
				return pos, pt:Lerp(c, 0.45):Lerp(center + UP * 0.5, k), 64 - 6 * ease(u)
			end
			-- the stroke and the beat: still, then a slow push-in while the heat gathers; the lens dips to the target
			-- with the punch as it bursts (aimed at the middle of the stroke, the punch pushed him and the target under
			-- the bottom bar); after it the crane straight up over the clearing until the whole burning painting is in frame
			local push = ease(lin(A.Mark, A.Final, s))
			local dip = ease(lin(A.Final - 0.06, A.Final, s)) * (1 - ease(lin(A.Final + 0.05, A.Final + 0.35, s)))
			local hold = center + side * dist * (1 - 0.1 * push) - d * (1.5 * push) - UP
			local aim = (center + UP * 0.5 - d * (1.5 * push)):Lerp(pt + UP * 1.5, 0.8 * dip)
			local e = outCubicLocal(lin(A.Final + 0.2, A.Restore + 0.25, s))
			return hold:Lerp(P - f * 8 + r * 3 + UP * 48, e), aim:Lerp(P + f, e), (fov - 3 * push) + (72 - fov + 3 * push) * e
		end
		if s < A.Final then -- the dive, from the ground at the landing: he comes down at the lens with the demons
			local u = lin(A.Fall, A.Final, s)
			return land + r * 15 + f * 6 + UP * 1.8, c:Lerp(land + UP * 2, 0.25 * u), 66 - 8 * ease(u)
		end
		-- the plant, then a crane straight up over the clearing until the whole burning Z of strokes is in frame
		-- (craning back put the lens inside the forest crowns and the frame went black)
		local e = outCubicLocal(lin(A.Final + 0.05, A.Restore, s))
		return (land + f * 12 + r * 9 + UP * 2.5):Lerp(P - f * 8 + r * 3 + UP * 48, e), (land + UP * 1.5):Lerp(P + f, e), 60 + 12 * e
	end

	local function shot(t, s)
		if plan and s >= A.Dive and s < A.Resume then return act2Shot(s) end
		if plan and s >= A.Fall then return finaleShot(s, t) end
		if t >= T.Black and t < T.Demons then -- 7 (v2) up past the caster at the eye: brush raised to the sky, eye behind
			local u = ease(lin(T.Black, T.Demons, t))
			local c = casterPos()
			return c - f * (11 + 2 * u) + r * 8 - UP * 4, c:Lerp(E, 0.27), 76 + 6 * u
		elseif t >= T.Demons and t < T.Final then -- 8a (v2) low behind the bound monsters: monsters, caster, demons, eye
			local u = ease(lin(T.Demons, T.Final, t))
			return P + f * 22 + r * 6 + UP * 1.6, (P + UP * 2):Lerp(E, 0.3) + UP * 2 * u, 82
		end
		if t < T.Rise then -- 1 close-up at eye level, the brush hangs tip-down across the right cheek (ref 0:03.5)
			local head = headPos()
			local u = ease(t / T.Rise)
			return (head + f * 4.5 + r * 0.45):Lerp(head + f * 3.7 + r * 0.32, u), head + r * 0.2 - UP * 0.1, 40 - 4 * u
		elseif t < T.Tendrils then -- 2 low wide angle into the storm
			local u = ease(lin(T.Rise, T.Tendrils, t))
			return ground0 + UP * 4 - f * 14 + r * 11 + (r * 2 - f * 2) * u, casterPos() + UP * 1.5, 74 - 6 * u
		elseif t < T.Stroke then -- 3 the painter over his canvas: high behind the right shoulder, caster on the left third,
			-- the bound monsters in the middle (the old framing put the head under the letterbox bar)
			local u = ease(lin(T.Tendrils, T.Stroke, t))
			local c = casterPos()
			return c - f * (2.6 - 0.6 * u) + r * 4 + UP * (6.5 - 0.5 * u), P + UP * 1.5 + r * 2 + (c - P) * 0.2, 64
		elseif t < T.Painting then -- 4 high frontal wide: the phantom brush drops in from the top, stroke across the frame
			local u = ease(lin(T.Stroke, T.Painting, t))
			return P + f * (34 - 3 * u) + UP * (24 - 2 * u), P + UP * 3 - f * 4, 70 - 4 * u
		elseif t < T.Wide then -- 5a low near the stroke, the dragon rises
			local u = ease(lin(T.Painting, T.Wide, t))
			return P + f * 16 + r * 12 + UP * (5 + 2 * u), dragonFocus() or (P + UP * 10), 58
		elseif t < T.Black then -- 5b low under the canopy, up at the caster against the vortex + dragon, ink floods in
			-- (at the caster's height the lens sat inside the tree crowns). Aim between caster and centre so neither
			-- leaves the frame, whatever the cast distance.
			local u = ease(lin(T.Wide, T.Black, t))
			local c = casterPos()
			return ground0 + UP * (3.6 + u) - f * 9 - r * 12, (c + UP) * 0.45 + (P + UP * 9) * 0.55 + r * 2, 68 - 3 * u
		elseif t < T.Demons then -- 7 up at the sky, the eye opens
			local u = ease(lin(T.Black, T.Demons, t))
			return P + f * (30 - 2 * u) - r * 3 + UP * 2.5, E, 72 - 8 * u
		elseif t < T.Final then -- 8a demons around the eye, then they dive
			local u = ease(lin(T.Demons, T.Final, t))
			return P + f * 26 - r * 4 + UP * 4, E:Lerp(P + UP * 4, ease(lin(T.Dive, T.Final, t))), 76 - 2 * u
		elseif t < T.Restore then -- 8b the hit, high and frontal so the whole painted stroke reads over the grass; pulls back
			local u = ease(lin(T.Final, T.Restore, t))
			return P + f * (22 + 3 * u) - r * (3 + u) + UP * (15 + 2.5 * u), P + UP - f * 2, 66 + 4 * u
		end
		local c = casterPos()
		return c - f * 13 + UP * 5, c, 70
	end

	local function clearTerrain(pos, minUp)
		local down = workspace:Raycast(pos + UP * 6, -UP * 12, terrainOnly)
		if down and pos.Y < down.Position.Y + minUp then return Vector3.new(pos.X, down.Position.Y + minUp, pos.Z) end
		return pos
	end

	local function shake(t)
		local a = 0
		for _, s in SHAKES do
			local age = t - s[1]
			if age >= 0 then a += s[2] * math.exp(-age * s[3]) end
		end
		return a
	end

	function self:Update(s, tau)
		if self.dead then return end
		tau = tau or Config.Tau(s)
		local t = Config.V1(s)
		-- other scripts (skill endings, freecam) may hand the camera back mid-shot
		if camera.CameraType ~= Enum.CameraType.Scriptable then camera.CameraType = Enum.CameraType.Scriptable end
		-- HUD scripts re-enable their screens mid-cutscene (the elite banner showed over the painting): keep them off
		for _, g in pg:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled and g ~= gui and g.Name ~= "InkPaintingSky" and g.Name ~= "InkPaintingCinema" then
				self.hidden[g] = true
				g.Enabled = false
			end
		end
		-- grade + sky
		local g = grade(t)
		local hit = math.exp(-math.max(0, t - T.Impact) * 14) * (t >= T.Impact and 1 or 0)
		local fin = math.exp(-math.max(0, t - T.Final) * 10) * (t >= T.Final and 1 or 0)
		cc.Saturation = g[2]
		cc.Contrast = g[3] + 0.3 * hit + 0.45 * fin
		cc.Brightness = g[4] + 0.35 * hit + 0.12 * fin -- more lift washed the red hit out to salmon
		cc.TintColor = g[5]
		gradeGrass(math.clamp(-g[2], 0, 1), g[5])
		local inkLight = lin(T.Sky, T.Sky + 0.3, t) * (1 - lin(T.Red - 0.02, T.Red, t))
		local hellLight = (t >= T.Red and 1 or 0) * (1 - lin(T.Restore, T.End - 0.1, t))
		Lighting.ExposureCompensation = self.expo0 + 0.7 * inkLight + 0.2 * hellLight
		if t >= T.Sky and t < T.Restore + 0.2 and not self.skyOn then
			self.skyOn = true
			for _, s in Lighting:GetChildren() do
				if s:IsA("Sky") then
					table.insert(self.oldSkies, s)
					s.Parent = nil
				end
			end
			sky.Parent = Lighting
			if self.atm then
				self.atm.Density, self.atm.Offset, self.atm.Glare, self.atm.Haze = 0.42, 0.15, 0, 1.5
				self.atm.Color, self.atm.Decay = Color3.fromRGB(205, 203, 198), Color3.fromRGB(120, 118, 115)
			end
		elseif t >= T.Restore + 0.2 and self.skyOn then
			self.skyOn = false
			self:RestoreSky()
		end
		-- see-through leaves skip the grade and would stay green: ink them by hand, then fade them back
		local leafInk = (t >= T.Sky and t < T.End) and (1 - lin(T.Restore, T.End - 0.05, t)) or 0
		if math.abs(leafInk - self.leafInk) > 0.02 or (leafInk ~= self.leafInk and (leafInk == 0 or leafInk == 1)) then
			self.leafInk = leafInk
			for _, sa in leaves do
				if sa.Parent then
					local c0 = self.tinted[sa]
					if c0 == nil then
						c0 = sa.Color
						self.tinted[sa] = c0
					end
					sa.Color = c0:Lerp(LEAF_INK, leafInk)
				end
			end
		end

		-- overlays
		local inkWorld = lin(T.Sky, T.Sky + 0.25, t) * (1 - lin(T.Restore, T.End - 0.2, t))
		vignette.ImageTransparency = 1 - 0.85 * inkWorld
		vignette.ImageColor3 = t > T.Red and Color3.fromRGB(40, 0, 0) or Color3.new(0, 0, 0)
		local paperA = t >= T.Painting and (t < T.Red and 0.75 or 0.45) * (1 - lin(T.Restore, T.End - 0.2, t)) or 0
		paper.ImageTransparency = 1 - paperA
		local vp = camera.ViewportSize
		local big = math.max(vp.X, vp.Y) * 3
		local fl = lin(T.Flood, T.Black, t)
		flood.ImageTransparency = (fl > 0 and t < T.Red + 0.05) and 0 or 1
		local fs = big * fl ^ 1.6
		flood.Size = UDim2.fromOffset(fs, fs)
		black.BackgroundTransparency = 1 - math.min(lin(T.Black - 0.04, T.Black, t), 1 - lin(T.Red + 0.02, T.Eye - 0.02, t))
		local rf = lin(T.Red - 0.04, T.Red + 0.16, t)
		local rs = big * rf ^ 1.4
		redFlood.Size = UDim2.fromOffset(rs, rs)
		redFlood.ImageTransparency = (rf > 0) and lin(T.Red + 0.1, T.Eye + 0.25, t) or 1
		local fh, fcol = 0, WHITE
		for _, e in FLASHES do
			if tau >= e[1] then
				local v = e[2] * math.exp(-(tau - e[1]) * e[3])
				if v > fh then fh, fcol = v, e[4] end
			end
		end
		flash.BackgroundTransparency = 1 - fh
		flash.BackgroundColor3 = fcol
		local barsIn = ease(lin(0, 0.3, t)) * (1 - ease(lin(T.Restore + 0.15, T.End, t)))
		bars[1].Position = UDim2.fromScale(0, 0.075 * barsIn)
		bars[2].Position = UDim2.fromScale(0, 1 - 0.075 * barsIn)
		-- title card (real time; act 1 has no freezes)
		local out = lin(2.3, 2.6, tau)
		swipeClip.Size = UDim2.fromScale(outCubicLocal(lin(1.0, 1.28, tau)), 1)
		swipe.Size = UDim2.fromOffset(card.AbsoluteSize.X, card.AbsoluteSize.Y)
		swipe.ImageTransparency = 0.04 + 0.96 * out
		local ca = lin(1.12, 1.38, tau)
		cjk.TextTransparency = 1 - ca * (1 - out)
		cjkStroke.Transparency = cjk.TextTransparency
		cjkScale.Scale = 1 + 0.35 * (1 - outCubicLocal(ca))
		latin.TextTransparency = 1 - lin(1.3, 1.55, tau) * (1 - out)
		local sa = lin(1.5, 1.6, tau)
		seal.BackgroundTransparency = 1 - sa * (1 - out)
		sealText.TextTransparency = seal.BackgroundTransparency
		sealScale.Scale = 1 + 0.8 * (1 - outCubicLocal(sa))
		card.Visible = tau < 2.65
		skip.Visible = t < T.Restore

		-- camera
		local pos, look, fov = shot(t, s)
		local leave = ease(lin(T.Restore, T.End, t))
		-- keep the lens over the terrain grass, terrain pushes the camera in, everything else in the way gets faded below
		pos = clearTerrain(pos, 3.6)
		local hitR = workspace:Raycast(look, pos - look, terrainOnly)
		if hitR and hitR.Distance > 2 then pos = clearTerrain(hitR.Position + hitR.Normal * 0.7, 2.4) end
		local a = shake(tau)
		if fx.hitPulse then a += 0.28 * math.exp(-math.max(0, s - fx.hitPulse) * 16) end -- each monster the brush passes
		for _, p in PUNCHES do
			if tau >= p[1] then fov += p[2] * math.exp(-(tau - p[1]) * 9) end
		end
		local cf = CFrame.lookAt(pos, look)
		cf = cf * CFrame.new(math.sin(tau * 97) * 0.35 * a, math.sin(tau * 131) * 0.22 * a, 0) * CFrame.Angles(0, 0, math.rad(0.8) * math.sin(tau * 89) * a)
		if leave > 0 then
			local root = char:FindFirstChild("HumanoidRootPart")
			local delta = root and (root.Position - origin.Position) or Vector3.zero
			cf = cf:Lerp(self.cam.cframe + delta, leave)
			fov = fov + (self.cam.fov - fov) * leave
		end
		camera.CFrame = cf
		camera.Focus = CFrame.new(look)
		camera.FieldOfView = fov

		-- fade whatever stands between the camera and the subject (like Roblox Invisicam)
		local c = casterPos()
		local seen = {}
		local targets = { look }
		if t < T.Painting or (t >= T.Wide and t < T.Demons) or t >= T.Restore or (plan and ((s >= A.Dive and s < A.Resume) or s >= A.Fall or (t >= T.Black and t < T.Final))) then
			table.insert(targets, c + UP * 1.5)
		end
		if plan and ((s >= A.Dive and s < A.Resume) or s >= A.Fall) then
			-- his whole body in the v2 action shots: bushes hid everything below the chest
			table.insert(targets, c)
			table.insert(targets, c - UP * 1.8)
		end
		local last = plan and plan.final
		if last and s >= A.Stroke and s < A.Final + 0.3 then -- and the whole last stroke
			table.insert(targets, Config.FinalAt(last, 0.2))
			table.insert(targets, last.point)
			table.insert(targets, Config.FinalAt(last, 0.8))
		end
		if fx.phantomTip then
			table.insert(targets, fx.phantomTip)
			table.insert(targets, fx.phantomMid)
		end
		local okParts, parts = pcall(camera.GetPartsObscuringTarget, camera, targets, ignore)
		if okParts then
			for _, p in parts do
				if not p:IsA("Terrain") and p.Size.Magnitude < 120 then
					seen[p] = true
					if self.faded[p] == nil then
						self.faded[p] = p.LocalTransparencyModifier
						p.LocalTransparencyModifier = 0.94 -- 0.85 left grey ghost planes of the leaf cards
					end
				end
			end
		end
		-- grass, branches and monsters right at the lens disappear completely
		for _, p in workspace:GetPartBoundsInRadius(cf.Position, 8.5, overlap) do
			if not p:IsA("Terrain") and p.Size.Magnitude < 150 then
				seen[p] = true
				if self.faded[p] == nil then self.faded[p] = p.LocalTransparencyModifier end
				p.LocalTransparencyModifier = 1
			end
		end
		-- the same for scenery the queries cannot see (CanQuery off): box tests against the cached boxes
		local cp = cf.Position
		local upward = cf.LookVector.Y > 0.4 -- shots 7 + 8a look up at the eye: crowns overhead would fill the frame
		local segs = {}
		for _, target in targets do
			local span = target - cp
			if span.Magnitude > 3 then table.insert(segs, target - span.Unit * 2) end
		end
		for _, g in ghosts do
			local p = g.part
			if p.Parent then
				local mode = 0
				if g.lens and (cp - g.center).Magnitude < g.reach then
					local l = g.cf:PointToObjectSpace(cp)
					local s = g.size
					if math.abs(l.X) < s.X * 0.5 + 2.5 and math.abs(l.Y) < s.Y * 0.5 + 2.5 and math.abs(l.Z) < s.Z * 0.5 + 2.5 then mode = 1 end
				end
				if mode == 0 and upward and g.lens then
					local l = g.cf:PointToObjectSpace(cp)
					local s = g.size
					if math.abs(l.X) < s.X * 0.5 + 4 and math.abs(l.Z) < s.Z * 0.5 + 4 and l.Y < s.Y * 0.5 then mode = 1 end
				end
				if mode == 0 then
					for _, b in segs do
						local ab = b - cp
						local u = math.clamp((g.center - cp):Dot(ab) / ab:Dot(ab), 0, 1)
						if (cp + ab * u - g.center).Magnitude < g.radius and segmentHitsBox(g.cf, g.half, cp, b) then
							mode = 0.94
							break
						end
					end
				end
				if mode > 0 then
					seen[p] = true
					if self.faded[p] == nil then self.faded[p] = p.LocalTransparencyModifier end
					if p.LocalTransparencyModifier ~= mode then p.LocalTransparencyModifier = mode end
				end
			end
		end
		for p, m in self.faded do
			if not seen[p] then
				self.faded[p] = nil
				if p.Parent then p.LocalTransparencyModifier = m end
			end
		end
		local toCam = cf.Position - c
		toCam = toCam.Magnitude > 0.1 and toCam.Unit or f
		keyPart.CFrame = CFrame.new(c + toCam * 6 + UP * 2.5)
		-- dim in close-ups (white hair and pale skin blow out), full only in the wide shots
		local near = math.clamp(((cf.Position - c).Magnitude - 5) / 12, 0.15, 1)
		key.Brightness = 0.7 * near * (1 - lin(T.Restore, T.End, t))
	end

	function self:RestoreSky()
		sky.Parent = nil
		for _, s in self.oldSkies do
			if s then s.Parent = Lighting end
		end
		self.oldSkies = {}
		if self.atm and self.atm.Parent then
			for k, v in self.atmSaved do
				self.atm[k] = v
			end
		end
	end

	function self:Destroy()
		if self.dead then return end
		self.dead = true
		CAS:UnbindAction("InkPaintingSink")
		CAS:UnbindAction("InkPaintingSkip")
		self:RestoreSky()
		Lighting.ExposureCompensation = self.expo0
		sky:Destroy()
		cc:Destroy()
		gui:Destroy()
		for g in self.hidden do
			if g.Parent then g.Enabled = true end
		end
		for core, on in self.core do
			pcall(function() StarterGui:SetCoreGuiEnabled(core, on) end)
		end
		for p, m in self.transparency do
			if p.Parent then p.LocalTransparencyModifier = m end
		end
		for p, m in self.faded do
			if p.Parent then p.LocalTransparencyModifier = m end
		end
		self.faded = {}
		for sa, c0 in self.tinted do
			if sa.Parent then sa.Color = c0 end
		end
		self.tinted = {}
		for m, g in self.grass do
			pcall(workspace.Terrain.SetMaterialColor, workspace.Terrain, m, g.c0)
		end
		self.grass = {}
		for d in self.tags do
			if d.Parent then d.Enabled = true end
		end
		prompts.Enabled = self.prompts
		world:Destroy()
		local root = char:FindFirstChild("HumanoidRootPart")
		local delta = root and (root.Position - origin.Position) or Vector3.zero
		if camera and camera.Parent then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			camera.CameraSubject = (self.cam.subject and self.cam.subject.Parent) and self.cam.subject or hum
			camera.FieldOfView = self.cam.fov
			camera.CFrame = self.cam.cframe + delta
			camera.Focus = self.cam.focus + delta
			camera.CameraType = self.cam.type
		end
	end

	return self
end

return Cinema
