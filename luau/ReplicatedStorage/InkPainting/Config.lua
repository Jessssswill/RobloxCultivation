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

-- Textures. Self-made (assets/InkBrush/vfx/make_ink_textures_v1.py). Until will OKs the upload they load from the
-- Studio content folder on his laptop (content/textures/QiInk), so they ONLY show in his Studio. After the upload,
-- swap these to rbxassetid:// ids.
local LOCAL = "rbxasset://textures/QiInk/"
Config.Tex = {
	stroke = LOCAL .. "ink_stroke.png",
	splat = LOCAL .. "ink_splat_flip.png", -- 2x2
	tendril = LOCAL .. "ink_tendril.png",
	bleed = LOCAL .. "ink_bleed.png",
	cloud = LOCAL .. "ink_cloud_flip.png", -- 2x2
	paper = LOCAL .. "ink_paper.png",
	vignette = LOCAL .. "ink_vignette.png",
	eye = LOCAL .. "hell_eye_flip.png", -- 2x2, closed -> open, pre-coloured
	claw = LOCAL .. "claw_slash.png",
	demon = LOCAL .. "demon_face_flip.png", -- 2x2
	skySide = { LOCAL .. "ink_sky_side0.png", LOCAL .. "ink_sky_side1.png", LOCAL .. "ink_sky_side2.png", LOCAL .. "ink_sky_side3.png" },
	skyUp = LOCAL .. "ink_sky_up.png",
	fire = "rbxassetid://125606840536264", -- already in the place (InkSlash Fire11, 4x4 flipbook)
	glow = "rbxassetid://243660373", -- already in the place
}

-- Sounds: empty = silent. Filled after an audio search (no new uploads needed for Creator Store sounds).
Config.Sfx = {
	raise = "",
	rise = "",
	thunder = "",
	slam = "",
	roar = "rbxassetid://94467976772299", -- DragonRoarPreload, already in the place
	flood = "",
	eye = "",
	claw = "",
	demons = "",
	final = "",
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

-- Held brush grows during the ultimate (the colossal phantom brush is separate, see FX).
function Config.BrushScale(t)
	local grow = math.clamp((t - 0.95) / 0.45, 0, 1)
	grow = 1 + 2.70158 * (grow - 1) ^ 3 + 1.70158 * (grow - 1) ^ 2 -- ease out back
	local shrink = ease((t - 6.9) / 0.4)
	return 1 + 0.6 * grow * (1 - shrink)
end

return Config
