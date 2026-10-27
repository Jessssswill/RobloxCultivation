-- ModuleScript: ServerScriptService.SpiritRadianceGlow
-- Lights up a Spirit Sword's golden radiance for a while. Clients draw it (StarterPlayerScripts.SpiritRadianceVFX).
-- Glow.pulse(tool, level, duration): level 1 = basic attack, 2 = skill Z/X, 3 = ultimate G.
-- Sets Tool attributes GlowLevel and GlowUntil (workspace:GetServerTimeNow() time). Never lowers a higher active level;
-- a lower pulse that outlasts it takes over when the higher one ends.
--
-- Where to call it (these files are not edited here, check the lines before pasting):
--   local Glow = require(game:GetService("ServerScriptService"):WaitForChild("SpiritRadianceGlow"))
--
--   1) Basic attack: the ComboServer Script inside each Tool, in tool.Hit.OnServerEvent (the "Hit" remote that
--      shared/WeaponCombo.lua fires with remote:FireServer(i) at each swing's Hit marker), after its own checks:
--          if tool:GetAttribute("Element") == "Thunder" then Glow.pulse(tool, 1, 0.6) end
--      The swinging client already lights its own sword at once (SpiritRadianceVFX predicts on tool.Activated),
--      so this call is what other players see.
--      No-edit fallback: in WeaponSkills.server.lua the Core.dealDamage wrapper (src == "combo") also knows the
--      tool, but it only runs when a swing hits something.
--
--   2) Skills: server/WeaponSkills.server.lua, SkillRemote.OnServerEvent, right after
--          if not ready(plr, el .. key, CD[key] - 0.2) then return end
--      add
--          if el == "Thunder" then Glow.pulse(tool, key == "G" and 3 or 2, key == "G" and 4.5 or 1.5) end
--      Z/X: 1.5 s. G (SK.Thunder.G, Nine Clouds Thunder): 1.25 s wind-up + 0.7 s + 9 strikes x 0.14 s + 0.25 s
--      before the pillar, about 3.5 s, so 4.5 keeps the sword lit through the pillar. Use 3 for a shorter flare.
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
