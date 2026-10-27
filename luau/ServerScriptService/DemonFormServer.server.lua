-- Wujud iblis 梼杌: tombol P (QiRemotes.DemonForm). Karakter disembunyikan, model monster di-weld ke HumanoidRootPart.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Core = require(script.Parent:WaitForChild("CombatCore"))
local remotes = RS:WaitForChild("QiRemotes")
local ev = remotes:WaitForChild("DemonForm")
local TEMPLATE = game:GetService("ServerStorage"):WaitForChild("Forms"):WaitForChild("DemonBeast")
local SCALE = 0.8            -- relatif template (template ~20 studs tinggi sampai ujung tanduk)
local COOLDOWN = 3
local LIFT = 2.5             -- HipHeight tambahan saat wujud iblis (supaya naik tangga mesh tidak nyangkut)
local last = {}

local function banner(plr, text)
	local fxr = remotes:FindFirstChild("Fx")
	if fxr then pcall(function() fxr:FireClient(plr, "Banner", text, Color3.fromRGB(255, 60, 40)) end) end
end

local function setVisible(char, vis)
	local form = char:FindFirstChild("DemonForm")
	for _, d in char:GetDescendants() do
		if form and d:IsDescendantOf(form) then continue end
		if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
			if vis then
				local t = d:GetAttribute("FormT")
				if t then d.Transparency = t end
				d:SetAttribute("FormT", nil)
			else
				if d:GetAttribute("FormT") == nil then d:SetAttribute("FormT", d.Transparency) end
				d.Transparency = 1
			end
		end
	end
end

local function burst(pos, scale)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = workspace
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(40, 10, 20), Color3.fromRGB(10, 5, 10))
	smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4 * scale), NumberSequenceKeypoint.new(1, 14 * scale)})
	smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	smoke.Lifetime, smoke.Speed = NumberRange.new(1.2, 2.2), NumberRange.new(8 * scale, 20 * scale)
	smoke.SpreadAngle, smoke.Rate = Vector2.new(180, 180), 0
	smoke.Parent = p
	smoke:Emit(45)
	local ember = Instance.new("ParticleEmitter")
	ember.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	ember.Color = ColorSequence.new(Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 20, 10))
	ember.LightEmission, ember.Rate = 1, 0
	ember.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2 * scale), NumberSequenceKeypoint.new(1, 0)})
	ember.Lifetime, ember.Speed = NumberRange.new(0.8, 1.6), NumberRange.new(15 * scale, 35 * scale)
	ember.SpreadAngle = Vector2.new(180, 180)
	ember.Parent = p
	ember:Emit(70)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 30, 10), 40 * scale, 6
	light.Parent = p
	TweenService:Create(light, TweenInfo.new(1.4), {Brightness = 0}):Play()
	for _, id in {"131557850414701", "1845133529"} do      -- braam + gemuruh (APM)
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id
		s.Volume = 1.6
		s.RollOffMaxDistance = 300
		s.Parent = p
		s:Play()
	end
	Debris:AddItem(p, 6)
end

local busy = {}

local function anchorPart(pos, size)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one * size
	p.Position = pos
	p.Parent = workspace
	return p
end

local function sound(parent, id, vol, speed)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume, s.PlaybackSpeed = vol, speed or 1
	s.RollOffMaxDistance = 320
	s.Parent = parent
	s:Play()
	return s
end

-- kilat merah bercabang di sekitar titik (beberapa ruas neon, hilang cepat)
local function bolt(center, r)
	local a = center + Vector3.new(math.random(-100, 100) / 100 * r, math.random(0, 140) / 100 * r, math.random(-100, 100) / 100 * r)
	for _ = 1, 4 do
		local b = a + Vector3.new(math.random(-60, 60) / 100 * r * 0.5, -math.random(20, 60) / 100 * r * 0.5, math.random(-60, 60) / 100 * r * 0.5)
		local seg = Instance.new("Part")
		seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
		seg.Material, seg.Color = Enum.Material.Neon, Color3.fromRGB(255, math.random(20, 60), 20)
		seg.Size = Vector3.new(0.18, 0.18, (b - a).Magnitude)
		seg.CFrame = CFrame.lookAt((a + b) / 2, b)
		seg.Parent = workspace
		Debris:AddItem(seg, 0.12)
		a = b
	end
end

-- gelombang kejut cincin neon di tanah
local function shockwave(pos, radius)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material, ring.Color = Enum.Material.Neon, Color3.fromRGB(255, 40, 15)
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = 0.15
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1}):Play()
	Debris:AddItem(ring, 0.8)
end

local function fade(model, show, t)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "RootPart" then
			if p:GetAttribute("T0") == nil then p:SetAttribute("T0", p.Transparency) end
			local goal = show and p:GetAttribute("T0") or 1
			if show then p.Transparency = 1 end
			TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Sine), {Transparency = goal}):Play()
		end
	end
end

local function flash(char, t)
	local h = Instance.new("Highlight")
	h.FillColor, h.OutlineColor = Color3.fromRGB(255, 30, 20), Color3.fromRGB(255, 120, 60)
	h.FillTransparency, h.OutlineTransparency = 1, 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = char
	TweenService:Create(h, TweenInfo.new(t * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FillTransparency = 0.15}):Play()
	Debris:AddItem(h, t + 0.3)
	return h
end

-- fase pengumpulan energi iblis: pusaran asap ungu-hitam tersedot ke tubuh, bara merah, kilat, cahaya makin terang
local CHARGE = 2.0          -- total berubah wujud 2,0 dtk (= kuda = pedang)
local function charge(plr, hrp)
	local pos = hrp.Position
	local p = anchorPart(pos, 16)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(60, 10, 40), Color3.fromRGB(8, 2, 8))
	smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 1.5)})
	smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 0.9)})
	smoke.Shape, smoke.ShapeInOut, smoke.ShapeStyle = Enum.ParticleEmitterShape.Sphere, Enum.ParticleEmitterShapeInOut.Inward, Enum.ParticleEmitterShapeStyle.Surface
	smoke.Lifetime, smoke.Speed, smoke.Rate = NumberRange.new(0.7, 1.0), NumberRange.new(10, 14), 90
	smoke.RotSpeed, smoke.Rotation = NumberRange.new(-200, 200), NumberRange.new(0, 360)
	smoke.Parent = p
	local ember = Instance.new("ParticleEmitter")
	ember.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	ember.Color = ColorSequence.new(Color3.fromRGB(255, 140, 60), Color3.fromRGB(255, 20, 10))
	ember.LightEmission = 1
	ember.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.1)})
	ember.Shape, ember.ShapeInOut, ember.ShapeStyle = Enum.ParticleEmitterShape.Sphere, Enum.ParticleEmitterShapeInOut.Inward, Enum.ParticleEmitterShapeStyle.Surface
	ember.Lifetime, ember.Speed, ember.Rate = NumberRange.new(0.5, 0.8), NumberRange.new(14, 22), 140
	ember.Parent = p
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 20, 10), 26, 0
	light.Parent = p
	TweenService:Create(light, TweenInfo.new(CHARGE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Brightness = 8, Range = 40}):Play()
	sound(p, "1837834536", 1.4, 1.25)                  -- riser
	sound(p, "9043355570", 1.0)                        -- dengung gelap
	flash(hrp.Parent, CHARGE)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < CHARGE do
			bolt(pos, 6)
			task.wait(0.07 + math.random() * 0.06)
		end
		smoke.Enabled, ember.Enabled = false, false
	end)
	Debris:AddItem(p, CHARGE + 1.5)
end

local function untransform(plr, quiet)
	local char = plr.Character
	local f = char and char:FindFirstChild("DemonForm")
	plr:SetAttribute("DemonForm", nil)
	if f then
		f.Name = "DemonFormLeaving"
		if not quiet then
			burst(f:GetPivot().Position, 0.6)
			fade(f, false, 0.45)
			Debris:AddItem(f, 0.5)
		else
			f:Destroy()
		end
	end
	if char then
		setVisible(char, true)
		if not quiet then flash(char, 0.4).FillTransparency = 0.3 end
	end
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then hum.WalkSpeed = Core.baseSpeed(plr) end
	local h0 = hum and hum:GetAttribute("DemonHip0")
	if h0 then hum.HipHeight = h0 hum:SetAttribute("DemonHip0", nil) end
end

local function transform(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp and hum.Health > 0) then return end
	if plr:GetAttribute("Mounted") then
		banner(plr, "Dismount your horse first")
		return
	end
	busy[plr] = true
	hum:UnequipTools()
	-- 1) kumpulkan energi (pemain tertahan di tempat)
	plr:SetAttribute("DemonCharging", true)
	hum.WalkSpeed = 0
	charge(plr, hrp)
	task.wait(CHARGE)
	plr:SetAttribute("DemonCharging", nil)
	busy[plr] = nil
	if not (char.Parent and hum.Health > 0) then return end
	-- 2) monster muncul
	local f = TEMPLATE:Clone()
	f.Name = "DemonForm"
	f:ScaleTo(f:GetScale() * SCALE)
	f:PivotTo(CFrame.new())
	-- arah kepala (tulang Head) disejajarkan dengan arah hadap pemain
	local head, pelvis, chest = f:FindFirstChild("Head", true), f:FindFirstChild("Pelvis", true), f:FindFirstChild("Chest", true)
	local fwd = head.WorldPosition - pelvis.WorldPosition
	fwd = Vector3.new(fwd.X, 0, fwd.Z).Unit
	f:PivotTo(CFrame.lookAt(Vector3.zero, fwd):Inverse() * f:GetPivot())
	local cf, sz = f:GetBoundingBox()
	local bottom = cf.Y - sz.Y / 2
	local mid = (pelvis.WorldPosition + chest.WorldPosition) / 2
	local ground = hrp.CFrame * CFrame.new(0, -(hrp.Size.Y / 2 + hum.HipHeight), 0)
	f:PivotTo(ground * CFrame.new(-mid.X, -bottom - LIFT, -mid.Z) * f:GetPivot())   -- diturunkan LIFT, nanti naik lagi ikut HipHeight
	for _, p in f:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = hrp, p
			w.Parent = p
		end
	end
	f:SetAttribute("Owner", plr.UserId)
	f:SetAttribute("Born", workspace:GetServerTimeNow())
	CS:AddTag(f, "HairPhysics")
	CS:AddTag(f, "DemonFormModel")
	setVisible(char, false)
	fade(f, true, 0.35)
	f.Parent = char
	plr:SetAttribute("DemonForm", true)
	hum.WalkSpeed = Core.baseSpeed(plr)
	if hum:GetAttribute("DemonHip0") == nil then hum:SetAttribute("DemonHip0", hum.HipHeight) end
	hum.HipHeight = hum:GetAttribute("DemonHip0") + LIFT
	burst(hrp.Position, 1)
	shockwave(ground.Position + Vector3.new(0, 0.3, 0), 38)
	local sp = anchorPart(hrp.Position, 1)
	sound(sp, "1837830182", 2)                         -- dentuman
	sound(sp, "108306323478967", 1.2, 0.8)             -- gema mantra
	Debris:AddItem(sp, 6)
	banner(plr, "Taowu Demon Form Awakened!")
end

ev.OnServerEvent:Connect(function(plr)
	if busy[plr] or os.clock() - (last[plr] or 0) < COOLDOWN then return end
	last[plr] = os.clock()
	if plr:GetAttribute("DemonForm") then
		untransform(plr)
		return
	end
	if plr:GetAttribute("Race") ~= "Demon" then
		banner(plr, "Only the Demon race can transform")
		return
	end
	transform(plr)
end)

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		plr:SetAttribute("DemonForm", nil)
		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function() plr:SetAttribute("DemonForm", nil) end)
	end)
end)
Players.PlayerRemoving:Connect(function(plr) last[plr], busy[plr] = nil, nil end)
