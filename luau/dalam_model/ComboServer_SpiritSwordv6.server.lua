-- Stub (Spirit Sword): same as ComboServer, plus the white-gold glow pulse on every hit.
local SSS = game:GetService("ServerScriptService")
local Glow = require(SSS:WaitForChild("SpiritRadianceGlow"))
require(SSS:WaitForChild("SwordComboServer"))(script.Parent, {
	onHit = function(tool) Glow.pulse(tool, 1, 0.6) end,
})
