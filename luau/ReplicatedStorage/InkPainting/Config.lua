-- InkPainting/Config (ModuleScript) -> ReplicatedStorage.InkPainting.Config
-- Ink Brush ultimate on G (moved from T on 2026-11-10, will): "Hundred Demons Scroll" (百魔图), an ink-painting cutscene. Replaces the old T Ink Dragon
-- (2026-11-05, will picked it on the decision card). Shot plan v1: project files assets/InkBrush/cutscene/Shot plan v1.png
-- v2 (2026-11-10, will: "kayak sailor piece", longer, wider, the caster's own moves on screen, every hit felt): about 15 s
-- in 5 acts. 1 rise + bind (v1), 2 the caster backflips down and dashes a giant Z of three ink strokes through the
-- monsters (each stroke erupts), 3 giant stroke + dragon + red hell (v1), 4 eye, claws, demons (v1, slower), 5 the caster
-- dives from the sky and plants the brush: every stroke explodes.
-- Shared by server + clients. Three clocks:
--   tau = real seconds since the cast started (server clock), what the server and clients measure;
--   s   = story time = tau minus the hit-stop freezes (Config.Story), what everything is authored in;
--   t1  = v1 time (Config.T, Pose.KEYS, the v1 FX and shots), re-timed from s through Config.V1.
local Config = {}

Config.Version = 2
Config.Name = "Hundred Demons Scroll"
Config.Short = "Hundred Demons"
Config.Title = "百  魔  图    ·    H U N D R E D   D E M O N S   S C R O L L"
Config.TitleCJK = "百魔图"
Config.TitleLatin = "HUNDRED DEMONS SCROLL"
Config.Key = Enum.KeyCode.G -- will 2026-11-10: same key as the sword ultimates (was T)
Config.Cooldown = 60
Config.StudioCooldown = 4 -- short in Studio so it is easy to watch again

Config.TargetRange = 42 -- nearest monster in front within this range becomes the painting's centre
Config.TargetDistance = 16 -- otherwise paint this far ahead
Config.Radius = 50 -- monsters inside this radius are bound by the ink (v1: 28)
Config.Lift = 15 -- how high the caster rises (lower under a ceiling)
Config.BindFrom = 1.95 -- story time
Config.BindUntil = 12.62

-- v1 shot boundaries in v1 time (see shot plan): 1 raise, 2 rise, 3 tendrils, 4 stroke, 5 painting, 6 flood, 7 eye,
-- 8 demons
Config.T = {
	Rise = 0.9,
	Sky = 0.95,
	Tendrils = 1.9,
	Stroke = 2.6,
	Slam = 2.86,
	Impact = 2.96,
	Painting = 3.2,
	Wide = 3.85,
	Flood = 4.55,
	Black = 4.82,
	Red = 4.95,
	Eye = 5.15,
	Claws = 5.75,
	Demons = 6.2,
	Dive = 6.42,
	Final = 6.55,
	Restore = 6.9,
	End = 7.5,
}

-- v2 acts in story time
Config.Act = {
	Dive = 2.6, -- act 2: off the storm, backflip down to the first stroke
	Leap = 7.1, -- third stroke done: backflip up into the storm again
	Resume = 7.6, -- act 3: the v1 giant stroke goes on from v1 time 2.6
	Fall = 12.1, -- act 5: dive from the sky
	Final = 12.6, -- brush planted in the painting's centre: everything explodes
	Restore = 13.8,
	End = 14.4,
}
-- the three dashes (story time); each stroke erupts right after the caster leaves it
Config.Strokes = {
	{ from = 3.1, to = 4.2, erupt = 4.3 },
	{ from = 4.55, to = 5.65, erupt = 5.75 },
	{ from = 6.0, to = 7.1, erupt = 7.2 },
}
-- the dash path, a giant Z around the painting centre: {right, forward} studs from P (forward = cast direction)
Config.Path = { { -34, -11 }, { 34, -11 }, { -34, 11 }, { 34, 11 } }
Config.PathSamples = 9 -- ground samples per stroke (the caster runs on the ink, over the grass)
Config.Landing = -2.5 -- the final plant, studs in front of P (towards the caster's start)

-- v1 time for each story time (piecewise linear)
local V1 = {
	{ 0, 0 }, { 2.6, 2.6 }, -- act 1 as v1
	{ 7.6, 2.6 }, -- act 2: the dashes, v1 waits (tendrils grown, monsters bound)
	{ 10.15, 5.15 }, -- act 3: giant stroke, dragon, flood, red hell
	{ 12.1, 6.42 }, -- act 4: eye, claws, demons, slower than v1
	{ 12.6, 6.55 }, -- the dive, slow motion into the final hit
	{ 13.8, 6.9 }, -- the painting burns
	{ 14.4, 7.5 }, -- back to the game
}
function Config.V1(s)
	if s <= 0 then return 0 end
	for i = 2, #V1 do
		local a, b = V1[i - 1], V1[i]
		if s <= b[1] then return a[2] + (b[2] - a[2]) * (s - a[1]) / (b[1] - a[1]) end
	end
	return V1[#V1][2]
end
-- story time when the v1 content reaches t1 (after the act-2 wait for t1 > 2.6)
function Config.SAtV1(t1)
	if t1 <= 2.6 then return t1 end
	for i = 4, #V1 do
		local a, b = V1[i - 1], V1[i]
		if t1 <= b[2] then return a[1] + (b[1] - a[1]) * (t1 - a[2]) / (b[2] - a[2]) end
	end
	return V1[#V1][1]
end

-- Hit-stops: the whole painting freezes for d seconds at story time s (the camera keeps shaking)
Config.HitStops = {
	{ s = 4.3, d = 0.07 }, -- stroke 1 erupts
	{ s = 5.75, d = 0.07 }, -- stroke 2
	{ s = 7.2, d = 0.07 }, -- stroke 3
	{ s = 7.96, d = 0.09 }, -- giant stroke slam (v1 2.96)
	{ s = 12.6, d = 0.16 }, -- the final
}
do
	local acc = 0
	for _, h in Config.HitStops do
		h.tau = h.s + acc
		acc += h.d
	end
	Config.Duration = Config.Act.End + acc -- real seconds
end
function Config.Story(tau)
	local s = tau
	for _, h in Config.HitStops do
		if tau <= h.tau then break end
		s -= math.min(tau - h.tau, h.d)
	end
	return s
end
function Config.Tau(s) -- real time of a story moment (a freeze start for a hit-stop moment)
	local tau = s
	for _, h in Config.HitStops do
		if s > h.s then tau += h.d end
	end
	return tau
end

-- Damage is a first guess; real numbers belong to the balancing thread. t = story time.
Config.Hits = {
	{ t = 7.96, damage = 40, radius = 30 }, -- giant stroke (v1 2.96)
	{ t = 8.85, damage = 12, radius = 22 }, -- ink vortex (v1 3.85)
	{ t = 9.2, damage = 12, radius = 22 },
	{ t = 12.6, damage = 110, radius = 50, knockback = 95 }, -- hundred demons + planted brush
}
-- dash strokes: a light hit when the brush passes a monster, a heavier one when the stroke erupts
Config.StrokeHit = { pass = 10, passWidth = 13, erupt = 14, eruptWidth = 15 }

-- Textures. Self-made (assets/InkBrush/vfx/make_ink_textures_v1.py + _v2.py), uploaded to will's account on
-- 2026-11-10 (ids also in assets/InkBrush/vfx/ASSET_IDS.txt).
Config.Tex = {
	stroke = "rbxassetid://104748411009739", -- beams
	strokeGround = "rbxassetid://88943818598670", -- v2: the giant stroke card on the ground (margin, no straight edges)
	splat = "rbxassetid://97531826507954", -- 2x2
	tendril = "rbxassetid://84803686198511",
	bleed = "rbxassetid://74604303133527",
	bleedWhite = "rbxassetid://70484678978796", -- v2: white pigment, for tinted floods (black ink times red stays black)
	cloud = "rbxassetid://104362448609541", -- 2x2
	paper = "rbxassetid://71061011564945",
	vignette = "rbxassetid://101177830203670",
	eye = "rbxassetid://81584309648879", -- 2x2, closed -> open, pre-coloured
	claw = "rbxassetid://137069074844889", -- v2: the v1 tears ran off the texture border (straight cut ends in shot 7)
	demon = "rbxassetid://89773600359935", -- 2x2
	skySide = { "rbxassetid://134284556896654", "rbxassetid://107888920229869", "rbxassetid://101525768316954", "rbxassetid://75157940830124" },
	skyUp = "rbxassetid://80706159856716",
	fire = "rbxassetid://125606840536264", -- already in the place (InkSlash Fire11, 4x4 flipbook)
	glow = "rbxassetid://243660373", -- already in the place
}

-- Sounds: Creator Store effects by ProSoundEffects (Roblox-licensed, free to use, nothing uploaded). Picked by title
-- on 2026-11-05, not listened to yet: swap any that sound wrong. Empty string = silent.
Config.Sfx = {
	raise = "rbxassetid://9114630316", -- Gong Hit Resonant Trail 1
	rise = "rbxassetid://9120286081", -- Tubular Whoosh Suck Explosive Rise Roar 1
	thunder = "rbxassetid://9120016037", -- Thunder Cracks Big Rumbling Blasts Booming 1
	slam = "rbxassetid://9120502978", -- Water Burst Boom Blast Hissing Spray 2 (wet ink slam)
	roar = "rbxassetid://94467976772299", -- DragonRoarPreload, already in the place
	flood = "rbxassetid://9120704346", -- Whoosh Deep Booming Blast Reversed A
	eye = "rbxassetid://9126100633", -- Thunder With Lion Roar Growl Low Rumble Roar
	claw = "rbxassetid://9116411685", -- Magic Swoosh Fast Zooming Pass Bys 18
	demons = "rbxassetid://9125909298", -- Screechy Screaming Suck Shrieks With Shimmer
	final = "rbxassetid://9126083958", -- Synth Thunder Cracks Individual Explosion
}

local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function outCubic(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end
Config.ease = ease
Config.outCubic = outCubic

-- Caster root relative to the cast origin (origin faces the painting centre). Server and every client use this.
function Config.RootOffset(t, lift)
	lift = lift or Config.Lift
	local up = outCubic((t - 0.92) / 0.75)
	local y = lift * up
	local z = -2.5 * up
	y += math.sin(t * 2.4) * 0.35 * ease((t - 1.6) / 0.3)
	local dip = math.sin(math.clamp((t - 2.6) / 0.6, 0, 1) * math.pi)
	y -= 2.2 * dip
	z -= 1.8 * ease((t - 2.6) / 0.35)
	local down = ease((t - 6.9) / 0.45)
	return CFrame.new(0, y * (1 - down), z * (1 - down))
end

-- Held brush: calligraphy size in the shot-1 close-up, grows 3x on the launch, back to the real size at the end
-- (the colossal phantom brush is separate, see FX).
function Config.BrushScale(t)
	local small = 1 - 0.78 * ease(t / 0.08) -- shot 1: hand-sized, held up before the face (hidden by the cut in)
	local grow = math.clamp((t - 0.95) / 0.45, 0, 1)
	grow = 1 + 2.70158 * (grow - 1) ^ 3 + 1.70158 * (grow - 1) ^ 2 -- ease out back
	local big = small + (1.6 - small) * grow
	return big + (1 - big) * ease((t - 6.9) / 0.4)
end

-- v2 ------------------------------------------------------------------------------------------------------------
local UP = Vector3.yAxis
local TAU = math.pi * 2

local function flat(v)
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 1e-4 and v.Unit or Vector3.new(0, 0, -1)
end
local function yawOf(d)
	return math.atan2(-d.X, -d.Z)
end
local function lerpAngle(a, b, u)
	return a + ((b - a + math.pi) % TAU - math.pi) * u
end
Config.flat, Config.yawOf = flat, yawOf

-- dash speed profile: a burst off the mark, steady, a short brake
function Config.DashEase(u)
	u = math.clamp(u, 0, 1)
	return 0.8 * u + 0.2 * ease(u)
end

-- The ink surface under a point: terrain first (trees and props have house-sized collision boxes), any collidable
-- floor when there is no terrain close by, plus the terrain grass (the cards sit on top of it, so does the caster).
function Config.Surface(pos, baseY, ignore)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore
	rp.RespectCanCollide = true
	local from = Vector3.new(pos.X, baseY + 12, pos.Z)
	local any = workspace:Raycast(from, -UP * 60, rp)
	local tp = RaycastParams.new()
	tp.FilterType = Enum.RaycastFilterType.Include
	tp.FilterDescendantsInstances = { workspace.Terrain }
	local terrain = workspace:Raycast(from, -UP * 60, tp)
	local hit = any
	if terrain and (not any or any.Position.Y - terrain.Position.Y > 3) then hit = terrain end
	if not hit or math.abs(hit.Position.Y - baseY) > 10 then return Vector3.new(pos.X, baseY, pos.Z) end
	local grass = 0
	if hit.Instance:IsA("Terrain") and (hit.Material == Enum.Material.Grass or hit.Material == Enum.Material.LeafyGrass) then
		local ok, decorated = pcall(function() return workspace.Terrain.Decoration end)
		if not ok or decorated then grass = 2.1 end -- the forest grass stands ~2.2 studs tall
	end
	return hit.Position + UP * (grass + 0.08)
end

-- Built on the server, sent to every client in "Begin": the ground under the three dash strokes + the landing.
function Config.MakePlan(origin, P, rootH, ignore)
	local f = flat(origin.LookVector)
	local r = f:Cross(UP).Unit
	local strokes = {}
	for i = 1, #Config.Path - 1 do
		local a, b = Config.Path[i], Config.Path[i + 1]
		local pts = {}
		for k = 0, Config.PathSamples - 1 do
			local u = k / (Config.PathSamples - 1)
			local x, z = a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u
			pts[k + 1] = Config.Surface(P + r * x + f * z, P.Y, ignore)
		end
		-- soften bumps (the ends stay put: strokes meet at the corners)
		local ys = {}
		for k = 1, #pts do ys[k] = pts[k].Y end
		for k = 2, #pts - 1 do
			pts[k] = Vector3.new(pts[k].X, (ys[k - 1] + 2 * ys[k] + ys[k + 1]) / 4, pts[k].Z)
		end
		strokes[i] = pts
	end
	-- the corners belong to two strokes: one height for both
	for i = 1, #strokes - 1 do
		local a, b = strokes[i][#strokes[i]], strokes[i + 1][1]
		local y = (a.Y + b.Y) / 2
		strokes[i][#strokes[i]] = Vector3.new(a.X, y, a.Z)
		strokes[i + 1][1] = Vector3.new(b.X, y, b.Z)
	end
	return { rootH = rootH, land = Config.Surface(P + f * Config.Landing, P.Y, ignore), strokes = strokes }
end

-- lengths + directions, on the server and on every client (not sent)
function Config.PreparePlan(plan)
	if not plan or plan.cum then return plan end
	plan.cum, plan.len, plan.dir = {}, {}, {}
	for i, pts in plan.strokes do
		local cum, d = { 0 }, 0
		for k = 2, #pts do
			local a, b = pts[k - 1], pts[k]
			d += Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
			cum[k] = d
		end
		plan.cum[i], plan.len[i] = cum, d
		plan.dir[i] = flat(pts[#pts] - pts[1])
	end
	return plan
end

-- point on stroke i at flat distance d from its start
function Config.StrokeAt(plan, i, d)
	local pts, cum = plan.strokes[i], plan.cum[i]
	if d <= 0 then return pts[1] end
	for k = 2, #pts do
		if d <= cum[k] then
			local u = (d - cum[k - 1]) / math.max(1e-4, cum[k] - cum[k - 1])
			return pts[k - 1]:Lerp(pts[k], u)
		end
	end
	return pts[#pts]
end

-- flat distance along stroke i (from its start) and sideways from it, for a world point
function Config.StrokeProject(plan, i, pos)
	local a, d = plan.strokes[i][1], plan.dir[i]
	local off = Vector3.new(pos.X - a.X, 0, pos.Z - a.Z)
	local along = off:Dot(d)
	return along, (off - d * along).Magnitude
end

-- how far the brush has painted stroke i at story time s
function Config.StrokeProgress(plan, i, s)
	local st = Config.Strokes[i]
	return Config.DashEase((s - st.from) / (st.to - st.from)) * plan.len[i]
end

-- Caster root in world space at story time s. Server and every client use this (the root is anchored).
function Config.RootCF(s, origin, lift, plan)
	local A, St = Config.Act, Config.Strokes
	if plan and s >= A.Dive and s < A.Resume then
		local air = origin * Config.RootOffset(A.Dive, lift) -- where act 2 starts and ends
		local h = plan.rootH
		local pos, yaw, pitch
		if s < St[1].from then -- backflip down to the start of stroke 1, turning to face the dash
			local u = (s - A.Dive) / (St[1].from - A.Dive)
			local land = plan.strokes[1][1] + UP * h
			pos = air.Position:Lerp(land, ease(u)) + UP * 7 * math.sin(math.pi * u)
			yaw = lerpAngle(yawOf(origin.LookVector), yawOf(plan.dir[1]), ease(u * 1.15))
			pitch = TAU * ease(u)
		elseif s >= St[#St].to then -- backflip up into the storm, facing the painting again
			local u = (s - St[#St].to) / (A.Resume - St[#St].to)
			local pts = plan.strokes[#St]
			pos = (pts[#pts] + UP * h):Lerp(air.Position, outCubic(u)) + UP * 6 * math.sin(math.pi * u)
			yaw = lerpAngle(yawOf(plan.dir[#St]), yawOf(origin.LookVector), ease(u))
			pitch = TAU * ease(u)
		else
			for i, st in St do
				local nextSt = St[i + 1]
				if s < st.to then -- dash
					pos = Config.StrokeAt(plan, i, Config.StrokeProgress(plan, i, s)) + UP * h
					yaw, pitch = yawOf(plan.dir[i]), 0
					break
				elseif nextSt and s < nextSt.from then -- pivot at the corner with a hop
					local u = (s - st.to) / (nextSt.from - st.to)
					local pts = plan.strokes[i]
					pos = pts[#pts] + UP * (h + 2.2 * math.sin(math.pi * u))
					yaw = lerpAngle(yawOf(plan.dir[i]), yawOf(plan.dir[i + 1]), ease(u))
					pitch = 0
					break
				end
			end
		end
		return CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	end
	if plan and s >= A.Fall then -- act 5: hang in the sky, then drop like a meteor onto the centre
		local from = origin * Config.RootOffset(Config.V1(A.Fall), lift)
		local land = plan.land + UP * plan.rootH
		local yaw = yawOf(origin.LookVector)
		if s >= A.Final then return CFrame.new(land) * CFrame.Angles(0, yaw, 0) end
		local u = (s - A.Fall) / (A.Final - A.Fall)
		local pos = from.Position:Lerp(land, u ^ 3) + UP * 2.5 * math.sin(math.pi * math.min(1, u / 0.5)) * (1 - u)
		local pitch = -0.75 * ease(u / 0.55) * (1 - ease((u - 0.8) / 0.2))
		return CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	end
	return origin * Config.RootOffset(Config.V1(s), lift)
end

-- held brush size in story time: v1 sizes, a little shorter for the dashes (the tip drags on the ground), huge for
-- the final plant
function Config.BrushScale2(s)
	local A = Config.Act
	if s < A.Dive then return Config.BrushScale(s) end
	if s < A.Resume then
		local k = math.min(ease((s - A.Dive) / 0.4), 1 - ease((s - (A.Resume - 0.35)) / 0.35))
		return 1.6 - 0.35 * k
	end
	if s < A.Fall then return Config.BrushScale(Config.V1(s)) end
	local big = 1.6 + 0.5 * ease((s - A.Fall) / 0.45)
	return big + (1 - big) * ease((s - A.Restore) / 0.5)
end

return Config
