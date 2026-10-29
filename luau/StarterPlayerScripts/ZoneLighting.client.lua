-- Lighting per zona. Di luar zona mana pun = lighting bawaan place (senja hub).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
local INFO = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local MARGIN = 12

local atm = Lighting:FindFirstChildOfClass("Atmosphere")
local cc = Lighting:FindFirstChild("SectColor") or Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")

local function preset(t)
	local out = {}
	local map = {Lighting = Lighting, Atmosphere = atm, Color = cc, Bloom = bloom, Rays = rays}
	for k, props in t do
		local inst = map[k]
		if inst then out[inst] = props end
	end
	return out
end

local ZONES = {
	Forest = preset({
		Lighting = {ClockTime = 13.2, Brightness = 2.6, Ambient = Color3.fromRGB(70, 78, 90),
			OutdoorAmbient = Color3.fromRGB(128, 138, 150), ExposureCompensation = 0.15},
		Atmosphere = {Density = 0.3, Offset = 0.15, Haze = 1.2, Glare = 0.2,
			Color = Color3.fromRGB(200, 215, 235), Decay = Color3.fromRGB(110, 130, 160)},
		Color = {TintColor = Color3.fromRGB(245, 250, 255), Saturation = 0.1, Contrast = 0.12},
		Bloom = {Intensity = 0.25},
		Rays = {Intensity = 0.12},
	}),
	DragonLair = preset({
		Lighting = {ClockTime = 0.5, Brightness = 0.4, Ambient = Color3.fromRGB(34, 20, 18),
			OutdoorAmbient = Color3.fromRGB(40, 24, 22), ExposureCompensation = 0.2},
		Atmosphere = {Density = 0.38, Offset = 0.05, Haze = 2.2, Glare = 0,
			Color = Color3.fromRGB(70, 34, 28), Decay = Color3.fromRGB(30, 12, 10)},
		Color = {TintColor = Color3.fromRGB(255, 232, 222), Saturation = 0.05, Contrast = 0.2},
		Bloom = {Intensity = 0.6, Threshold = 1.4, Size = 32},
		Rays = {Intensity = 0},
	}),
	Heaven = preset({
		Lighting = {ClockTime = 15.6, Brightness = 3, Ambient = Color3.fromRGB(104, 96, 88),
			OutdoorAmbient = Color3.fromRGB(168, 158, 146), ExposureCompensation = 0.1},
		Atmosphere = {Density = 0.45, Offset = 0.3, Haze = 3, Glare = 0.6,
			Color = Color3.fromRGB(255, 240, 222), Decay = Color3.fromRGB(214, 186, 158)},
		Color = {TintColor = Color3.fromRGB(255, 248, 236), Saturation = 0.1, Contrast = 0.1},
		Bloom = {Intensity = 0.5, Threshold = 1.5, Size = 32},
		Rays = {Intensity = 0.22},
	}),
	TrialArena = preset({
		Lighting = {ClockTime = 15.5, Brightness = 0.9, Ambient = Color3.fromRGB(78, 80, 88),
			OutdoorAmbient = Color3.fromRGB(110, 112, 122), ExposureCompensation = 0.15},
		Atmosphere = {Density = 0.48, Offset = 0.25, Haze = 2.6, Glare = 0,
			Color = Color3.fromRGB(150, 154, 164), Decay = Color3.fromRGB(88, 92, 104)},
		Color = {TintColor = Color3.fromRGB(240, 242, 255), Saturation = -0.22, Contrast = 0.18},
		Bloom = {Intensity = 0.7, Threshold = 1.4, Size = 26},
		Rays = {Intensity = 0.06},
	}),
	Underworld = preset({
		Lighting = {ClockTime = 0, Brightness = 0.8, Ambient = Color3.fromRGB(70, 32, 22),
			OutdoorAmbient = Color3.fromRGB(96, 42, 26), ExposureCompensation = 0.35},
		Atmosphere = {Density = 0.42, Offset = 0.0, Haze = 3, Glare = 0,
			Color = Color3.fromRGB(38, 22, 44), Decay = Color3.fromRGB(18, 8, 22)},
		Color = {TintColor = Color3.fromRGB(242, 234, 248), Saturation = 0, Contrast = 0.18},
		Bloom = {Intensity = 0.3, Threshold = 1.8, Size = 24},
		Rays = {Intensity = 0},
	}),
	-- Desa Shiqiao: pagi berkabut di lembah (referensi #7)
	Shiqiao = preset({
		Lighting = {ClockTime = 9, Brightness = 1.8, Ambient = Color3.fromRGB(84, 88, 92),
			OutdoorAmbient = Color3.fromRGB(132, 138, 142), ExposureCompensation = 0.15},
		Atmosphere = {Density = 0.4, Offset = 0.22, Haze = 2.4, Glare = 0.1,
			Color = Color3.fromRGB(200, 208, 212), Decay = Color3.fromRGB(128, 138, 146)},
		Color = {TintColor = Color3.fromRGB(240, 243, 245), Saturation = -0.12, Contrast = 0.1},
		Bloom = {Intensity = 0.3},
		Rays = {Intensity = 0.04},
	}),
}

-- nilai bawaan dari semua properti yang dipakai zona mana pun
local DEFAULT = {}
for _, z in ZONES do
	for inst, props in z do
		DEFAULT[inst] = DEFAULT[inst] or {}
		for k in props do
			if DEFAULT[inst][k] == nil then DEFAULT[inst][k] = inst[k] end
		end
	end
end
-- tujuan tween: properti yang tidak diatur zona kembali ke bawaan
local function target(z)
	local out = {}
	for inst, props in DEFAULT do
		out[inst] = {}
		for k, v in props do out[inst][k] = (z and z[inst] and z[inst][k] ~= nil) and z[inst][k] or v end
	end
	return out
end

local active = {}
local function apply(t)
	for _, tw in active do tw:Cancel() end
	table.clear(active)
	for inst, goal in t do
		local tw = TweenService:Create(inst, INFO, goal)
		tw:Play()
		table.insert(active, tw)
	end
end

local zones = {}
local function scan()
	table.clear(zones)
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "LightingZone" then
			table.insert(zones, d)
		end
	end
end
scan()
workspace.DescendantAdded:Connect(function(d) if d.Name == "LightingZone" then task.defer(scan) end end)

local function inside(z, pos, margin)
	local lp = z.CFrame:PointToObjectSpace(pos)
	local h = z.Size / 2 + Vector3.new(margin, 0, margin)
	return math.abs(lp.X) <= h.X and math.abs(lp.Z) <= h.Z
end

local current = nil
while true do
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local found
		for _, z in zones do
			local name = z:GetAttribute("LightingZone") or "Forest"
			if inside(z, root.Position, (name == current) and MARGIN or 0) then found = name break end
		end
		if found ~= current then
			current = found
			apply(target(found and ZONES[found]))
		end
	end
	task.wait(0.25)
end
