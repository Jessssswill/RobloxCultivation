-- ModuleScript: ServerScriptService.SpiritRadianceGlow
-- Lights up a Spirit Sword's golden radiance for a while. Clients draw it (StarterPlayerScripts.SpiritRadianceVFX).
-- Glow.pulse(tool, level, duration): level 1 = basic attack, 2 = skill Z/X, 3 = ultimate G.
-- Sets Tool attributes GlowLevel and GlowUntil (workspace:GetServerTimeNow() time). Never lowers a higher active level;
-- a lower pulse that outlasts it takes over when the higher one ends.
-- Called from the Spirit Sword ComboServer (level 1) and ServerScriptService.WeaponSkills (Z/X level 2, G level 3).
local Glow = {}

local follow = setmetatable({}, { __mode = "k" }) -- tool -> token of a pending lower-level continuation

local function read(tool)
	local lv, u = tool:GetAttribute("GlowLevel"), tool:GetAttribute("GlowUntil")
	return typeof(lv) == "number" and lv or 0, typeof(u) == "number" and u or 0
end

-- run `level` again from `at` until `endsAt`, unless a newer continuation replaces it
local function continueLater(tool, level, at, endsAt)
	local token = {}
	follow[tool] = token
	task.delay(math.max(at - workspace:GetServerTimeNow(), 0), function()
		if follow[tool] ~= token or not tool.Parent then return end
		follow[tool] = nil
		local left = endsAt - workspace:GetServerTimeNow()
		if left > 0.05 then Glow.pulse(tool, level, left) end
	end)
end

function Glow.pulse(tool, level, duration)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then return end
	level = math.clamp(math.floor(tonumber(level) or 0), 0, 3)
	duration = math.clamp(tonumber(duration) or 0, 0, 10)
	if level == 0 or duration <= 0 then return end
	local now = workspace:GetServerTimeNow()
	local endsAt = now + duration
	local curLevel, curUntil = read(tool)
	local live = curUntil > now
	if live and curLevel > level then
		if endsAt > curUntil then continueLater(tool, level, curUntil, endsAt) end
		return
	end
	if live and curLevel == level then
		endsAt = math.max(endsAt, curUntil)
	elseif live and curUntil > endsAt then
		continueLater(tool, curLevel, endsAt, curUntil) -- the weaker glow resumes after this one
	end
	tool:SetAttribute("GlowLevel", level)
	tool:SetAttribute("GlowUntil", endsAt)
end

-- turn it off now (e.g. on death or when the sword is dropped)
function Glow.clear(tool)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then return end
	follow[tool] = nil
	tool:SetAttribute("GlowLevel", 0)
	tool:SetAttribute("GlowUntil", 0)
end

return Glow
