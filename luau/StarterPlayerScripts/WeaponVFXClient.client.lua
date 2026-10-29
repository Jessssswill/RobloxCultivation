-- Efek elemen senjata di layar tiap pemain (petir acak, kilatan pas dicabut). Elemen dari attribute "Element" di Tool.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local THUNDER = {
	core = Color3.fromRGB(235, 245, 255),
	glow = Color3.fromRGB(110, 180, 255),
}

local function boltSegment(a, b, width, color, life)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	local len = (b - a).Magnitude
	p.Size = Vector3.new(width, width, len)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = workspace
	Debris:AddItem(p, life)
	return p
end

local function bolt(a, b, jag, width, life)
	local n = math.max(3, math.floor((b - a).Magnitude / 0.5))
	local dir = (b - a).Unit
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then side = dir:Cross(Vector3.xAxis) end
	side = side.Unit
	local up = dir:Cross(side).Unit
	local prev = a
	for i = 1, n do
		local t = i / n
		local pt = a:Lerp(b, t)
		if i < n then
			pt += side * (math.random() - 0.5) * jag + up * (math.random() - 0.5) * jag
		end
		boltSegment(prev, pt, width, THUNDER.core, life)
		boltSegment(prev, pt, width * 3, THUNDER.glow, life * 0.9).Transparency = 0.4
		prev = pt
	end
end

local function bladePoints(tool)
	local sword = tool:FindFirstChild("Sword")
	if not sword then return end
	local base, tip = sword:FindFirstChild("BladeBase"), sword:FindFirstChild("BladeTip")
	if not (base and tip) then return end
	return sword, base.WorldPosition, tip.WorldPosition
end

local function flashLight(sword, brightness, dur)
	local l = Instance.new("PointLight")
	l.Color = THUNDER.glow
	l.Range = 14
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = sword
	Debris:AddItem(l, dur)
end

local function onEquip(tool)
	local sword, base, tip = bladePoints(tool)
	if not sword then return end
	local sky = tip + Vector3.new(math.random(-3, 3), 14, math.random(-3, 3))
	bolt(sky, tip, 1.6, 0.08, 0.14)
	task.delay(0.06, function() bolt(sky + Vector3.new(1, 0, -1), tip, 1.8, 0.05, 0.1) end)
	flashLight(sword, 8, 0.18)
	local burst = sword:FindFirstChild("VFX_Sparks")
	if burst then burst:Emit(30) end
end

local active = {}
local function track(tool)
	if active[tool] or tool:GetAttribute("Element") ~= "Thunder" then return end
	active[tool] = { nextArc = os.clock() + 0.3 }
	onEquip(tool)
end

local function watchCharacter(char)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then task.defer(track, c) end
	end)
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") then task.defer(track, c) end
	end
end

local function watchPlayer(p)
	p.CharacterAdded:Connect(watchCharacter)
	if p.Character then watchCharacter(p.Character) end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for tool, st in pairs(active) do
		local char = tool.Parent
		if not (char and char:FindFirstChildOfClass("Humanoid")) then
			active[tool] = nil
		elseif now >= st.nextArc then
			st.nextArc = now + 0.15 + math.random() * 0.35
			local sword, base, tip = bladePoints(tool)
			if sword then
				local a = base:Lerp(tip, math.random() * 0.6)
				local b = a:Lerp(tip, 0.35 + math.random() * 0.5)
				bolt(a, b, 0.5, 0.045, 0.11) if math.random() < 0.4 then bolt(a, b, 0.6, 0.03, 0.09) end
				if math.random() < 0.35 then flashLight(sword, 2.5, 0.07) end
			end
		end
	end
end)
