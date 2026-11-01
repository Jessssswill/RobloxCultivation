-- SwordCombo: 4-hit jian combo driven straight onto the R15 joints (Motor6D.Transform), same idea as the Ink Brush.
-- Why: no animation upload needed (works in the live game), whole body moves, smooth curves, hit-stop.
-- Every client plays it for every character (the owner locally, others via SwordComboRelay), so all players see it.
-- Pose values per joint: {pitchX, yawY, rollZ (deg), x, y, z (studs)}; same conventions as assets/Animations/build_jian_v2.lua.
local RunService = game:GetService("RunService")

local SwordCombo = {}
-- preview/debug: workspace attribute SwordComboTimeScale (0 freezes every combo in place, 0.2 = slow motion)

local JOINT = { -- short name -> Motor6D name (R15)
	LT = "Root", UT = "Waist", H = "Neck",
	RUA = "RightShoulder", RLA = "RightElbow", RH = "RightWrist",
	LUA = "LeftShoulder", LLA = "LeftElbow", LH = "LeftWrist",
	RUL = "RightHip", RLL = "RightKnee", RF = "RightAnkle",
	LUL = "LeftHip", LLL = "LeftKnee", LF = "LeftAnkle",
}
-- overlapping action: hips lead, chest, shoulder, elbow, wrist follow a few ms later -> the arm whips instead of moving as one block
local LAG = { LT = 0, RUL = 0, LUL = 0, RLL = 0.01, LLL = 0.01, RF = 0.015, LF = 0.015, UT = 0.018, H = 0.05,
	RUA = 0.03, LUA = 0.04, RLA = 0.045, LLA = 0.055, RH = 0.055, LH = 0.06 }

local READY = { LT = { 0, 10, 0, 0, -0.1, 0 }, UT = { 0, 15, 0 }, RUA = { 45, 0, 10 }, RLA = { 35, 0, 0 }, RH = { 10, 0, 0 },
	LUA = { 15, 0, -15 }, LLA = { 25, 0, 0 }, RUL = { 10, 0, 0 }, RLL = { -10, 0, 0 }, LUL = { -8, 0, 0 }, LLL = { -6, 0, 0 } }

-- t = seconds. snap = the segment INTO this key is front-loaded (fast start, soft landing) -> sharp cut.
-- contact = hit times; trail = {on, off}; lunge = {time, speed}; fx = slash plane for SwordFX (roll deg, from-side)
SwordCombo.CLIPS = {
	{ -- 1. Diagonal cut: upper right -> lower left, step in
		name = "Diagonal", dur = 0.78, contact = { 0.29 }, trail = { 0.2, 0.42 }, lunge = { 0.22, 22 },
		fx = { roll = -40, dir = -1, reach = 6.5 },
		keys = {
			{ 0, READY },
			{ 0.16, { LT = { 0, -18, 0, 0, -0.15, 0.2 }, UT = { 8, -32, 6 }, RUA = { 150, 0, 42 }, RLA = { 70, 0, 0 }, RH = { 25, 0, 0 },
				LUA = { 55, 0, -25 }, LLA = { 70, 0, 0 }, LH = { 0, 0, 0 }, RUL = { -6, 0, 0 }, RLL = { -14, 0, 0 }, LUL = { 18, 0, 0 }, LLL = { -22, 0, 0 } } },
			{ 0.21, { LT = { 0, -20, 0, 0, -0.18, 0.22 }, UT = { 10, -36, 7 }, RUA = { 158, 0, 46 }, RLA = { 76, 0, 0 }, RH = { 30, 0, 0 },
				LUA = { 58, 0, -28 }, LLA = { 72, 0, 0 }, RUL = { -7, 0, 0 }, RLL = { -15, 0, 0 }, LUL = { 19, 0, 0 }, LLL = { -23, 0, 0 } } },
			{ 0.29, { LT = { -4, 22, 0, 0, -0.38, -0.55 }, UT = { -12, 30, -8 }, RUA = { 72, 0, -40 }, RLA = { 8, 0, 0 }, RH = { -12, 0, 0 },
				LUA = { -25, 0, -50 }, LLA = { 20, 0, 0 }, RUL = { 48, 0, 0 }, RLL = { -42, 0, 0 }, LUL = { -28, 0, 0 }, LLL = { -12, 0, 0 } }, snap = true },
			{ 0.38, { LT = { -6, 28, 0, 0, -0.42, -0.6 }, UT = { -16, 40, -10 }, RUA = { 48, 0, -62 }, RLA = { 18, 0, 0 }, RH = { -18, 0, -8 },
				LUA = { -32, 0, -56 }, LLA = { 18, 0, 0 }, RUL = { 52, 0, 0 }, RLL = { -46, 0, 0 }, LUL = { -30, 0, 0 }, LLL = { -12, 0, 0 } } },
			{ 0.52, { LT = { -2, 18, 0, 0, -0.3, -0.4 }, UT = { -6, 24, -4 }, RUA = { 60, 0, -35 }, RLA = { 30, 0, 0 }, RH = { 0, 0, 0 },
				LUA = { -5, 0, -35 }, LLA = { 30, 0, 0 }, RUL = { 34, 0, 0 }, RLL = { -30, 0, 0 }, LUL = { -20, 0, 0 }, LLL = { -10, 0, 0 } } },
			{ 0.78, READY },
		},
	},
	{ -- 2. Horizontal backhand: left -> right, low stance, body unwinds
		name = "Horizontal", dur = 0.74, contact = { 0.27 }, trail = { 0.18, 0.4 }, lunge = { 0.2, 14 },
		fx = { roll = 0, dir = 1, reach = 6.5 },
		keys = {
			{ 0, READY },
			{ 0.15, { LT = { 0, 28, 0, 0, -0.38, 0 }, UT = { -6, 40, 8 }, RUA = { 85, 0, -72 }, RLA = { 38, 0, 0 }, RH = { 0, 0, -18 },
				LUA = { 25, 0, -20 }, LLA = { 75, 0, 0 }, RUL = { 22, 0, 0 }, RLL = { -36, 0, 0 }, LUL = { 14, 0, 0 }, LLL = { -34, 0, 0 } } },
			{ 0.19, { LT = { 0, 30, 0, 0, -0.42, 0.02 }, UT = { -7, 44, 9 }, RUA = { 86, 0, -78 }, RLA = { 42, 0, 0 }, RH = { 0, 0, -20 },
				LUA = { 26, 0, -22 }, LLA = { 78, 0, 0 }, RUL = { 23, 0, 0 }, RLL = { -38, 0, 0 }, LUL = { 15, 0, 0 }, LLL = { -36, 0, 0 } } },
			{ 0.27, { LT = { 0, -24, 0, 0, -0.4, -0.35 }, UT = { -4, -38, -6 }, RUA = { 92, 0, 72 }, RLA = { 4, 0, 0 }, RH = { 0, 0, 16 },
				LUA = { 30, 0, -60 }, LLA = { 25, 0, 0 }, RUL = { 30, 0, 0 }, RLL = { -30, 0, 0 }, LUL = { -18, 0, 0 }, LLL = { -18, 0, 0 } }, snap = true },
			{ 0.36, { LT = { 0, -32, 0, 0, -0.42, -0.4 }, UT = { -4, -50, -8 }, RUA = { 90, 0, 88 }, RLA = { 10, 0, 0 }, RH = { 0, 0, 22 },
				LUA = { 34, 0, -66 }, LLA = { 22, 0, 0 }, RUL = { 32, 0, 0 }, RLL = { -32, 0, 0 }, LUL = { -20, 0, 0 }, LLL = { -18, 0, 0 } } },
			{ 0.5, { LT = { 0, -12, 0, 0, -0.26, -0.22 }, UT = { -2, -18, -3 }, RUA = { 70, 0, 45 }, RLA = { 28, 0, 0 }, RH = { 5, 0, 8 },
				LUA = { 20, 0, -35 }, LLA = { 30, 0, 0 }, RUL = { 20, 0, 0 }, RLL = { -20, 0, 0 }, LUL = { -12, 0, 0 }, LLL = { -10, 0, 0 } } },
			{ 0.74, READY },
		},
	},
	{ -- 3. Rising circle: drop low with the blade behind, rise and carve upward
		name = "Rising", dur = 0.84, contact = { 0.33 }, trail = { 0.22, 0.46 }, lunge = { 0.25, 12 },
		fx = { roll = 90, dir = 1, reach = 6 },
		keys = {
			{ 0, READY },
			{ 0.18, { LT = { 12, -15, 0, 0, -0.6, 0.15 }, UT = { 18, -25, 5 }, RUA = { -25, 0, 35 }, RLA = { 25, 0, 0 }, RH = { -20, 0, 0 },
				LUA = { 60, 0, -30 }, LLA = { 70, 0, 0 }, RUL = { 45, 0, 0 }, RLL = { -75, 0, 0 }, LUL = { 35, 0, 0 }, LLL = { -65, 0, 0 } } },
			{ 0.24, { LT = { 14, -16, 0, 0, -0.66, 0.16 }, UT = { 20, -28, 6 }, RUA = { -32, 0, 38 }, RLA = { 28, 0, 0 }, RH = { -24, 0, 0 },
				LUA = { 62, 0, -32 }, LLA = { 72, 0, 0 }, RUL = { 48, 0, 0 }, RLL = { -80, 0, 0 }, LUL = { 38, 0, 0 }, LLL = { -70, 0, 0 } } },
			{ 0.33, { LT = { -8, 8, 0, 0, 0.12, -0.3 }, UT = { -18, 10, -4 }, RUA = { 165, 0, 18 }, RLA = { 8, 0, 0 }, RH = { 25, 0, 0 },
				LUA = { -30, 0, -55 }, LLA = { 15, 0, 0 }, RUL = { 20, 0, 0 }, RLL = { -10, 0, 0 }, LUL = { -25, 0, 0 }, LLL = { -15, 0, 0 } }, snap = true },
			{ 0.42, { LT = { -10, 12, 0, 0, 0.28, -0.35 }, UT = { -22, 14, -6 }, RUA = { 178, 0, -8 }, RLA = { 14, 0, 0 }, RH = { 35, 0, 0 },
				LUA = { -36, 0, -60 }, LLA = { 15, 0, 0 }, RUL = { 18, 0, 0 }, RLL = { -20, 0, 0 }, LUL = { -20, 0, 0 }, LLL = { -30, 0, 0 } } },
			{ 0.58, { LT = { 0, 10, 0, 0, -0.18, -0.2 }, UT = { -4, 14, 0 }, RUA = { 100, 0, 15 }, RLA = { 30, 0, 0 }, RH = { 10, 0, 0 },
				LUA = { 5, 0, -30 }, LLA = { 30, 0, 0 }, RUL = { 18, 0, 0 }, RLL = { -22, 0, 0 }, LUL = { -12, 0, 0 }, LLL = { -10, 0, 0 } } },
			{ 0.84, READY },
		},
	},
	{ -- 4. Step thrust (finisher): coil back with sword-finger forward, explode into a deep lunge
		name = "Thrust", dur = 1.0, contact = { 0.38 }, trail = { 0.3, 0.52 }, lunge = { 0.3, 34 }, heavy = true,
		fx = { thrust = true, reach = 9 },
		keys = {
			{ 0, READY },
			{ 0.2, { LT = { 4, 35, 0, 0, -0.3, 0.35 }, UT = { 6, 30, 0 }, RUA = { 15, 0, 30 }, RLA = { 100, 0, 0 }, RH = { -15, 0, 0 },
				LUA = { 85, 0, -5 }, LLA = { 5, 0, 0 }, LH = { 0, 0, 0 }, RUL = { -10, 0, 0 }, RLL = { -30, 0, 0 }, LUL = { 25, 0, 0 }, LLL = { -35, 0, 0 } } },
			{ 0.3, { LT = { 6, 38, 0, 0, -0.36, 0.42 }, UT = { 8, 34, 0 }, RUA = { 8, 0, 32 }, RLA = { 108, 0, 0 }, RH = { -18, 0, 0 },
				LUA = { 88, 0, -4 }, LLA = { 3, 0, 0 }, RUL = { -12, 0, 0 }, RLL = { -34, 0, 0 }, LUL = { 28, 0, 0 }, LLL = { -40, 0, 0 } } },
			{ 0.38, { LT = { -8, -18, 0, 0, -0.55, -1.0 }, UT = { -14, -25, 0 }, RUA = { 94, 0, 4 }, RLA = { 0, 0, 0 }, RH = { -4, 0, 0 },
				LUA = { -35, 0, -60 }, LLA = { 10, 0, 0 }, RUL = { 62, 0, 0 }, RLL = { -50, 0, 0 }, LUL = { -38, 0, 0 }, LLL = { -8, 0, 0 } }, snap = true },
			{ 0.5, { LT = { -9, -20, 0, 0, -0.6, -1.08 }, UT = { -16, -28, 0 }, RUA = { 96, 0, 2 }, RLA = { 0, 0, 0 }, RH = { -4, 0, 0 },
				LUA = { -38, 0, -63 }, LLA = { 10, 0, 0 }, RUL = { 64, 0, 0 }, RLL = { -52, 0, 0 }, LUL = { -40, 0, 0 }, LLL = { -8, 0, 0 } } },
			{ 0.7, { LT = { 0, -5, 0, 0, -0.3, -0.5 }, UT = { -4, -6, 0 }, RUA = { 70, 0, 12 }, RLA = { 25, 0, 0 }, RH = { 5, 0, 0 },
				LUA = { 5, 0, -25 }, LLA = { 30, 0, 0 }, RUL = { 30, 0, 0 }, RLL = { -28, 0, 0 }, LUL = { -16, 0, 0 }, LLL = { -10, 0, 0 } } },
			{ 1.0, READY },
		},
	},
}

-- skill clips (not part of the click chain): Z = dash thrust, X = sky raise then cut down, Ult = the G cutscene motion
-- (charge with the sword-finger seal, raise the blade to the sky, giant cleave at 1.32 s right when the ultimate lands)
local SEAL = { 80, 0, -45 }
SwordCombo.SKILLS = {
	SkillZ = {
		name = "SkillZ", dur = 0.7, contact = { 0.24 }, trail = { 0.17, 0.34 }, lunge = { 99, 0 },
		fx = { thrust = true, reach = 9 },
		keys = {
			{ 0, READY },
			{ 0.14, { LT = { 6, 38, 0, 0, -0.36, 0.42 }, UT = { 8, 34, 0 }, RUA = { 8, 0, 32 }, RLA = { 108, 0, 0 }, RH = { -18, 0, 0 },
				LUA = { 88, 0, -4 }, LLA = { 3, 0, 0 }, RUL = { -12, 0, 0 }, RLL = { -34, 0, 0 }, LUL = { 28, 0, 0 }, LLL = { -40, 0, 0 } } },
			{ 0.24, { LT = { -8, -18, 0, 0, -0.55, -1.0 }, UT = { -14, -25, 0 }, RUA = { 94, 0, 4 }, RLA = { 0, 0, 0 }, RH = { -4, 0, 0 },
				LUA = { -35, 0, -60 }, LLA = { 10, 0, 0 }, RUL = { 62, 0, 0 }, RLL = { -50, 0, 0 }, LUL = { -38, 0, 0 }, LLL = { -8, 0, 0 } }, snap = true },
			{ 0.38, { LT = { -9, -20, 0, 0, -0.6, -1.08 }, UT = { -16, -28, 0 }, RUA = { 96, 0, 2 }, RLA = { 0, 0, 0 }, RH = { -4, 0, 0 },
				LUA = { -38, 0, -63 }, LLA = { 10, 0, 0 }, RUL = { 64, 0, 0 }, RLL = { -52, 0, 0 }, LUL = { -40, 0, 0 }, LLL = { -8, 0, 0 } } },
			{ 0.7, READY },
		},
	},
	SkillX = {
		name = "SkillX", dur = 0.95, contact = { 0.52 }, trail = { 0.43, 0.64 }, lunge = { 99, 0 },
		fx = { roll = 90, dir = -1, reach = 7.5 },
		keys = {
			{ 0, READY },
			{ 0.22, { LT = { -6, 0, 0, 0, 0.05, 0 }, UT = { -15, 0, 0 }, RUA = { 172, 0, 8 }, RLA = { 6, 0, 0 }, RH = { 30, 0, 0 },
				LUA = SEAL, LLA = { 100, 0, 0 }, RUL = { 4, 0, 0 }, RLL = { -4, 0, 0 }, LUL = { -4, 0, 0 }, LLL = { -4, 0, 0 } } },
			{ 0.42, { LT = { -8, 0, 0, 0, 0.12, 0 }, UT = { -18, 0, 0 }, RUA = { 178, 0, 6 }, RLA = { 4, 0, 0 }, RH = { 36, 0, 0 },
				LUA = SEAL, LLA = { 104, 0, 0 }, RUL = { 4, 0, 0 }, RLL = { -4, 0, 0 }, LUL = { -4, 0, 0 }, LLL = { -4, 0, 0 } } },
			{ 0.52, { LT = { -10, 0, 0, 0, -0.55, -0.45 }, UT = { -22, 0, 0 }, RUA = { 70, 0, 0 }, RLA = { 0, 0, 0 }, RH = { -12, 0, 0 },
				LUA = { -30, 0, -50 }, LLA = { 15, 0, 0 }, RUL = { 60, 0, 0 }, RLL = { -52, 0, 0 }, LUL = { -36, 0, 0 }, LLL = { -10, 0, 0 } }, snap = true },
			{ 0.68, { LT = { -11, 0, 0, 0, -0.6, -0.5 }, UT = { -24, 0, 0 }, RUA = { 64, 0, 0 }, RLA = { 0, 0, 0 }, RH = { -14, 0, 0 },
				LUA = { -32, 0, -52 }, LLA = { 15, 0, 0 }, RUL = { 62, 0, 0 }, RLL = { -54, 0, 0 }, LUL = { -38, 0, 0 }, LLL = { -10, 0, 0 } } },
			{ 0.95, READY },
		},
	},
	Ult = { -- long cutscene version (will 2026-11-01): seal + gather qi, raise the blade to the sky, cleave at 3.7 s
		name = "Ult", dur = 4.6, contact = { 3.7 }, trail = { 3.58, 3.86 }, lunge = { 99, 0 }, heavy = true,
		fx = { roll = 90, dir = -1, reach = 10 },
		keys = {
			{ 0, READY },
			{ 0.35, { LT = { 6, 30, 0, 0, -0.5, 0.3 }, UT = { 10, 25, 0 }, RUA = { 20, 0, 35 }, RLA = { 40, 0, 0 }, RH = { -10, 0, 0 },
				LUA = SEAL, LLA = { 100, 0, 0 }, H = { -8, -20, 0 }, RUL = { -10, 0, 0 }, RLL = { -40, 0, 0 }, LUL = { 30, 0, 0 }, LLL = { -45, 0, 0 } } },
			{ 1.3, { LT = { 7, 32, 0, 0, -0.58, 0.32 }, UT = { 12, 27, 0 }, RUA = { 16, 0, 38 }, RLA = { 44, 0, 0 }, RH = { -12, 0, 0 },
				LUA = SEAL, LLA = { 104, 0, 0 }, H = { -10, -22, 0 }, RUL = { -12, 0, 0 }, RLL = { -44, 0, 0 }, LUL = { 32, 0, 0 }, LLL = { -48, 0, 0 } } },
			{ 2.1, { LT = { 5, 20, 0, 0, -0.45, 0.2 }, UT = { 6, 16, 0 }, RUA = { 60, 0, 40 }, RLA = { 30, 0, 0 }, RH = { 0, 0, 0 },
				LUA = SEAL, LLA = { 100, 0, 0 }, RUL = { -6, 0, 0 }, RLL = { -30, 0, 0 }, LUL = { 22, 0, 0 }, LLL = { -32, 0, 0 } } },
			{ 2.6, { LT = { -6, 0, 0, 0, 0.05, 0 }, UT = { -15, 0, 0 }, RUA = { 175, 0, 8 }, RLA = { 5, 0, 0 }, RH = { 35, 0, 0 },
				LUA = SEAL, LLA = { 100, 0, 0 }, H = { -20, 0, 0 }, RUL = { 5, 0, 0 }, RLL = { -5, 0, 0 }, LUL = { -5, 0, 0 }, LLL = { -5, 0, 0 } } },
			{ 3.55, { LT = { -8, 0, 0, 0, 0.14, 0 }, UT = { -20, 0, 0 }, RUA = { 179, 0, 6 }, RLA = { 3, 0, 0 }, RH = { 40, 0, 0 },
				LUA = SEAL, LLA = { 104, 0, 0 }, H = { -24, 0, 0 }, RUL = { 4, 0, 0 }, RLL = { -4, 0, 0 }, LUL = { -4, 0, 0 }, LLL = { -4, 0, 0 } } },
			{ 3.7, { LT = { -10, 0, 0, 0, -0.72, -0.6 }, UT = { -26, 0, 0 }, RUA = { 60, 0, 0 }, RLA = { 0, 0, 0 }, RH = { -15, 0, 0 },
				LUA = { -30, 0, -50 }, LLA = { 15, 0, 0 }, RUL = { 66, 0, 0 }, RLL = { -56, 0, 0 }, LUL = { -40, 0, 0 }, LLL = { -10, 0, 0 } }, snap = true },
			{ 4.05, { LT = { -11, 0, 0, 0, -0.76, -0.64 }, UT = { -28, 0, 0 }, RUA = { 56, 0, 0 }, RLA = { 0, 0, 0 }, RH = { -16, 0, 0 },
				LUA = { -32, 0, -52 }, LLA = { 15, 0, 0 }, RUL = { 68, 0, 0 }, RLL = { -58, 0, 0 }, LUL = { -42, 0, 0 }, LLL = { -10, 0, 0 } } },
			{ 4.6, READY },
		},
	},
}

-- a click step (1..4) or a skill name ("SkillZ", "SkillX", "Ult")
function SwordCombo.Get(id)
	return SwordCombo.CLIPS[id] or SwordCombo.SKILLS[id]
end

-- head keeps looking forward (counter the hips + chest) unless a key sets H
local function headFor(v)
	local lt, ut = v.LT or { 0, 0, 0 }, v.UT or { 0, 0, 0 }
	return { -(lt[1] + ut[1]) * 0.55, -(lt[2] + ut[2]) * 0.75, -(lt[3] + ut[3]) * 0.6 }
end
local allClips = table.clone(SwordCombo.CLIPS)
for _, c in pairs(SwordCombo.SKILLS) do table.insert(allClips, c) end
for _, clip in ipairs(allClips) do
	for _, k in ipairs(clip.keys) do
		if not k[2].H then
			local v = table.clone(k[2]); v.H = headFor(v); k[2] = v
		end
	end
end

local function chan(v, i) return v and v[i] or 0 end
local function snapEase(t) return 1 - (1 - t) ^ 3 end

-- Catmull-Rom through the keys of one joint/channel (velocity carries through each pose = no robotic stops)
local function sample(clip, j, i, t)
	local keys = clip.keys
	local n = #keys
	if t <= keys[1][1] then return chan(keys[1][2][j], i) end
	if t >= keys[n][1] then return chan(keys[n][2][j], i) end
	local k = 1
	while k < n - 1 and t > keys[k + 1][1] do k += 1 end
	local a, b = keys[k], keys[k + 1]
	local u = (t - a[1]) / math.max(1e-4, b[1] - a[1])
	if b.snap then u = snapEase(u) end
	local p0 = chan((keys[k - 1] or a)[2][j], i)
	local p1, p2 = chan(a[2][j], i), chan(b[2][j], i)
	local p3 = chan((keys[k + 2] or b)[2][j], i)
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
end

local function poseAt(clip, j, t)
	local rx, ry, rz = sample(clip, j, 1, t), sample(clip, j, 2, t), sample(clip, j, 3, t)
	local x, y, z = sample(clip, j, 4, t), sample(clip, j, 5, t), sample(clip, j, 6, t)
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

local active = {} -- [character] = player state

local function findJoints(char)
	local out = {}
	for short, name in pairs(JOINT) do
		local m = char:FindFirstChild(name, true)
		if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then out[short] = m end
	end
	return out
end

-- Play hit `index` on `char`. hooks: onContact(i, contactIndex), onTrail(on), onLunge(speed), onEnd()
function SwordCombo.Play(char, index, hooks)
	hooks = hooks or {}
	local clip = SwordCombo.Get(index)
	if not clip then return end
	local prev = active[char]
	if prev then prev.stop(true) end
	local joints = findJoints(char)
	local st = { t = 0, freeze = 0, done = false }
	active[char] = st
	char:SetAttribute("SwordAttacking", true)
	local fired, trailOn, lunged = {}, false, false
	local conn
	function st.stop(chained)
		if st.done then return end
		st.done = true
		if conn then conn:Disconnect() end
		if active[char] == st then active[char] = nil end
		if not chained then char:SetAttribute("SwordAttacking", false) end
		if trailOn and hooks.onTrail then hooks.onTrail(false) end
		if hooks.onEnd then hooks.onEnd(chained) end
	end
	function st.hitStop(sec) st.freeze = math.max(st.freeze, sec) end
	conn = RunService.PreSimulation:Connect(function(dt)
		if not char.Parent then st.stop() return end
		dt = math.min(dt, 1 / 20) * (workspace:GetAttribute("SwordComboTimeScale") or 1)
		if st.freeze > 0 then
			st.freeze -= dt
			dt *= 0.06 -- hit-stop: nearly frozen, not dead still
		end
		st.t += dt
		local t = st.t
		for ci, ct in ipairs(clip.contact) do
			if not fired[ci] and t >= ct then
				fired[ci] = true
				if hooks.onContact then hooks.onContact(index, ci) end
			end
		end
		if hooks.onTrail then
			local want = t >= clip.trail[1] and t < clip.trail[2]
			if want ~= trailOn then trailOn = want; hooks.onTrail(want) end
		end
		if not lunged and t >= clip.lunge[1] then
			lunged = true
			if hooks.onLunge then hooks.onLunge(clip.lunge[2]) end
		end
		-- blend in fast, blend out over the last 0.18 s back into whatever the Animator is playing
		local w = math.min(1, t / 0.06, (clip.dur - t) / 0.18)
		w = math.clamp(w, 0, 1)
		w = w * w * (3 - 2 * w)
		for short, m in pairs(joints) do
			local lag = LAG[short] or 0.03
			local pose = poseAt(clip, short, math.max(0, t - lag))
			m.Transform = w >= 0.999 and pose or m.Transform:Lerp(pose, w)
		end
		if t >= clip.dur then st.stop() end
	end)
	return st
end

function SwordCombo.Stop(char)
	local st = active[char]
	if st then st.stop() end
end

function SwordCombo.HitStop(char, sec)
	local st = active[char]
	if st then st.hitStop(sec) end
end

return SwordCombo
