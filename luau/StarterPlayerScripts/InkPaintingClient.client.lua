-- InkPaintingClient (LocalScript) -> StarterPlayer.StarterPlayerScripts.InkPaintingClient
-- Ink Brush ultimate on T, "Hundred Demons Scroll" (2026-11-05). Replaces InkDanceClient (old T Ink Dragon,
-- archived). Input + HUD slot for the local player; plays every caster's ultimate (pose, brush, world FX) and the
-- cutscene for the local caster. Keeps the old HUD names (InkDanceHUD / InkQiCastUltimate) so the scroll HUD still works.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local folder = RS:WaitForChild("InkPainting")
local Config = require(folder:WaitForChild("Config"))
local FX = require(folder:WaitForChild("FX"))
local Cinema = require(folder:WaitForChild("Cinema"))
local SwordFX = RS:FindFirstChild("SwordFX") and require(RS.SwordFX)
local assets = RS:WaitForChild("InkM1Assets")
local Rules = require(assets:WaitForChild("InkQiRules"))
local remote = RS:WaitForChild("InkPaintingRemote")

local active = {}
local pending, nextCast = false, 0
local TITLE = Font.new("rbxasset://fonts/families/Fondamento.json")

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function tool()
	local c = player.Character
	return c and c:FindFirstChild("Ink Brush")
end

local function clearFlags(t)
	t = t or tool()
	if t then
		t:SetAttribute("SkillActive", false)
		t:SetAttribute("Attacking", false)
		t:SetAttribute("InkDanceActive", false)
	end
end

local function finish(caster, id, notify)
	local s = active[caster]
	if not s or (id and s.id ~= id) then return end
	active[caster] = nil
	for _, c in s.connections do
		c:Disconnect()
	end
	if s.cinema then pcall(function() s.cinema:Destroy() end) end
	if s.fx then pcall(function() s.fx:Destroy() end) end
	if caster == player then
		pending = false
		clearFlags(s.tool)
		if notify then remote:FireServer("Cancel", s.id) end
	end
end

local function begin(caster, id, origin, P, lift, serverStart, cooldown)
	finish(caster, nil, false)
	local char = caster.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local t = char and char:FindFirstChild("Ink Brush")
	if not (char and hum and root and t) then
		if caster == player then
			pending = false
			clearFlags()
			remote:FireServer("Cancel", id)
		end
		return
	end
	local isMe = caster == player
	local tier = 3
	if SwordFX and SwordFX.TierFor then
		local ok, v = pcall(SwordFX.TierFor, char)
		if ok and typeof(v) == "number" then tier = v end
	end
	if tier <= 0 then return end -- too far away to draw
	local s = { id = id, char = char, tool = t, connections = {} }
	active[caster] = s
	local function elapsed()
		return workspace:GetServerTimeNow() - serverStart
	end
	local ok, err = pcall(function()
		local cutscene = isMe and player:GetAttribute("UltCutscene") ~= false
		local ctx = { char = char, tool = t, origin = origin, P = P, lift = lift, tier = tier, screenSky = cutscene }
		s.fx = FX.New(ctx)
		if cutscene then s.cinema = Cinema.New(ctx, s.fx) end
		table.insert(s.connections, Run.PreSimulation:Connect(function()
			if not char.Parent or hum.Health <= 0 or t.Parent ~= char then
				finish(caster, id, isMe)
				return
			end
			local time = elapsed()
			local rootCF = origin * Config.RootOffset(time, lift)
			root.CFrame = rootCF
			s.fx:Update(math.max(0, time), rootCF)
			if time > Config.Duration + 0.4 then finish(caster, id, false) end
		end))
		if s.cinema then
			table.insert(s.connections, Run.RenderStepped:Connect(function()
				if s.cinema and not s.cinema.dead then s.cinema:Update(math.max(0, elapsed())) end
			end))
		end
		if isMe then
			pending = false
			nextCast = os.clock() + (cooldown or Config.Cooldown)
			t:SetAttribute("InkCooldownT", workspace:GetServerTimeNow() + (cooldown or Config.Cooldown))
			t:SetAttribute("SkillActive", true)
			t:SetAttribute("Attacking", true)
			t:SetAttribute("InkDanceActive", true)
			table.insert(s.connections, t.Unequipped:Connect(function() finish(caster, id, true) end))
		end
	end)
	if not ok then
		warn("[InkPainting] " .. tostring(err))
		finish(caster, id, isMe)
	end
end

local function cast()
	local t = tool()
	if not Rules.CanUse(player) or not t or pending or active[player] or os.clock() < nextCast or not t:GetAttribute("M1Ready")
		or t:GetAttribute("Attacking") or t:GetAttribute("SkillActive") then
		return
	end
	local h = player.Character:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 or h.RigType ~= Enum.HumanoidRigType.R15 then return end
	pending = true
	t:SetAttribute("SkillActive", true)
	t:SetAttribute("Attacking", true)
	remote:FireServer("Cast")
	task.delay(3, function()
		if pending and not active[player] then
			pending = false
			clearFlags()
		end
	end)
end

remote.OnClientEvent:Connect(function(action, ...)
	if action == "Begin" then
		begin(...)
	elseif action == "End" then
		local caster, id = ...
		finish(caster, id, false)
	elseif action == "Denied" then
		pending = false
		if not active[player] then clearFlags() end
	end
end)

-- T is bound only while the brush is out, so T keeps working for the steed / sword riding / demon form otherwise
-- (a CAS binding marks the key as game-processed for every UserInputService listener). Touch uses the scroll HUD.
local bound = false
local function bindKey(on)
	if on == bound then return end
	bound = on
	if on then
		Cinema.Prepare() -- background map scan for the cutscene camera (trees the queries cannot see)
		CAS:BindAction("InkPaintingUltimate", function(_, state)
			if state == Enum.UserInputState.Begin then cast() end
			return Enum.ContextActionResult.Sink
		end, false, Config.Key)
	else
		CAS:UnbindAction("InkPaintingUltimate")
	end
end
local function watch(char)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and c.Name == "Ink Brush" then bindKey(true) end
	end)
	char.ChildRemoved:Connect(function(c)
		if c.Name == "Ink Brush" and not char:FindFirstChild("Ink Brush") then bindKey(false) end
	end)
	bindKey(char:FindFirstChild("Ink Brush") ~= nil)
end
player.CharacterAdded:Connect(watch)
if player.Character then watch(player.Character) end
player.CharacterRemoving:Connect(function()
	finish(player, nil, true)
	pending = false
	bindKey(false)
end)

-- HUD slot (hidden when the Martial Scroll shows the skills)
local hud = make("ScreenGui", { Name = "InkDanceHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4 }, player:WaitForChild("PlayerGui"))
hud.Enabled = not Rules.UseScroll()
local uiCast = Instance.new("BindableEvent")
uiCast.Name = "InkQiCastUltimate"
uiCast.Parent = hud
uiCast.Event:Connect(cast)
local slot = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 127, 0.81, 0), Size = UDim2.fromOffset(70, 70), BackgroundColor3 = Color3.fromRGB(27, 22, 25), Visible = false }, hud)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, slot)
make("UIStroke", { Color = Color3.fromRGB(176, 60, 52), Thickness = 2 }, slot)
make("TextLabel", { Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(24, 23), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "T", TextSize = 20, TextColor3 = Color3.fromRGB(245, 236, 221) }, slot)
make("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.96), Size = UDim2.new(1, -4, 0, 26), BackgroundTransparency = 1, FontFace = TITLE, Text = Config.Short, TextScaled = true, TextColor3 = Color3.fromRGB(224, 216, 205) }, slot)
local timer = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "", TextSize = 23, TextColor3 = Color3.new(1, 1, 1) }, slot)
Run.Heartbeat:Connect(function()
	slot.Visible = tool() ~= nil
	timer.Text = os.clock() < nextCast and tostring(math.ceil(nextCast - os.clock())) or ""
end)

-- Studio-only: fire the full ultimate through the normal cast path
if Run:IsStudio() then
	local event = Instance.new("BindableEvent")
	event.Name = "PreviewInkPainting"
	event.Parent = hud
	event.Event:Connect(cast)
end
