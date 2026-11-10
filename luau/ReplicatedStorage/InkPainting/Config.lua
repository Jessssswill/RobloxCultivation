-- InkPainting/Config (ModuleScript) -> ReplicatedStorage.InkPainting.Config
-- Ink Brush ultimate on T: "Hundred Demons Scroll" (百魔图), an ink-painting cutscene. Replaces the old T Ink Dragon
-- (2026-11-05, will picked it on the decision card). Shot plan v1: project files assets/InkBrush/cutscene/Shot plan v1.png
-- Shared by server + clients. All times are seconds since the cast started (server clock).
local Config = {}

Config.Name = "Hundred Demons Scroll"
Config.Short = "Hundred Demons"
Config.Title = "百  魔  图    ·    H U N D R E D   D E M O N S   S C R O L L"
Config.Key = Enum.KeyCode.T
Config.Duration = 7.5
Config.Cooldown = 60
Config.StudioCooldown = 4 -- short in Studio so it is easy to watch again

Config.TargetRange = 42 -- nearest monster in front within this range becomes the painting's centre
Config.TargetDistance = 16 -- otherwise paint this far ahead
Config.Radius = 28 -- monsters inside this radius are bound by the ink
Config.Lift = 15 -- how high the caster rises (lower under a ceiling)
Config.BindFrom = 1.95
Config.BindUntil = 6.58

-- Damage is a first guess; real numbers belong to the balancing thread.
Config.Hits = {
	{ t = 2.96, damage = 40, radius = 24 }, -- giant stroke
	{ t = 3.85, damage = 12, radius = 16 }, -- ink vortex
	{ t = 4.2, damage = 12, radius = 16 },
	{ t = 6.55, damage = 110, radius = 30, knockback = 85 }, -- hundred demons
}

-- Shot boundaries (see shot plan): 1 raise, 2 rise, 3 tendrils, 4 stroke, 5 painting, 6 flood, 7 eye, 8 demons
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

return Config
