-- SwordFX: thick anime slash effects for the jian combo, coloured by the sword's Element attribute.
-- Reuses the Ink Brush slash pack (ReplicatedStorage.InkM1Assets: SlashMesh crescents + Slash flipbook emitters + GroundEffects)
-- so no new uploads are needed. Client-only; every client spawns it for every attacker (see SwordComboRelay).
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local SwordFX = {}

-- workspace attribute SwordFXSlow (debug only) stretches every effect so it can be inspected frame by frame
local function slow() return workspace:GetAttribute("SwordFXSlow") or 1 end
local function TI(t, ...) return TweenInfo.new(t * slow(), ...) end

SwordFX.PALETTE = {
	Thunder = { core = Color3.fromRGB(255, 252, 230), main = Color3.fromRGB(255, 205, 70), deep = Color3.fromRGB(255, 140, 30) },
	Ice = { core = Color3.fromRGB(240, 250, 255), main = Color3.fromRGB(120, 200, 255), deep = Color3.fromRGB(40, 110, 255) },
	Lotus = { core = Color3.fromRGB(255, 245, 250), main = Color3.fromRGB(255, 140, 190), deep = Color3.fromRGB(90, 220, 160) },
	Jade = { core = Color3.fromRGB(235, 255, 240), main = Color3.fromRGB(80, 235, 150), deep = Color3.fromRGB(20, 140, 90) },
	Fire = { core = Color3.fromRGB(255, 245, 220), main = Color3.fromRGB(255, 120, 40), deep = Color3.fromRGB(200, 30, 20) },
	None = { core = Color3.fromRGB(255, 255, 255), main = Color3.fromRGB(180, 215, 255), deep = Color3.fromRGB(90, 140, 255) },
}

local pack = RS:WaitForChild("InkM1Assets", 10)
local slashSrc = pack and ((pack:FindFirstChild("InkSlash") and pack.InkSlash:FindFirstChild("SlashMesh")) or pack:FindFirstChild("Smears"))
local refRoot = pack and pack:FindFirstChild("ReferenceRig") and pack.ReferenceRig:FindFirstChild("HumanoidRootPart")

local function palette(tool)
	return SwordFX.PALETTE[tool and tool:GetAttribute("Element") or "None"] or SwordFX.PALETTE.None
end

local function bare(p)
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	return p
end

local function folderFx()
	local f = Instance.new("Folder")
	f.Name = "SwordFX"
	f.Parent = workspace
	Debris:AddItem(f, 3 * slow())
	return f
end

-- crescent slash meshes from the pack, rolled into the swing plane, two layers (white core + element colour)
local function crescent(f, root, pal, roll, scale, dur)
	local src = slashSrc
	if not (src and refRoot) then return end
	local pivot = root.CFrame * CFrame.new(0, 0.6, -1.2)
	local spin = pivot * CFrame.Angles(0, 0, math.rad(roll)) * pivot:Inverse()
	local delta = root.CFrame * refRoot.CFrame:Inverse()
	for li, m in ipairs(src:GetChildren()) do
		local s, e = m:FindFirstChild("Start"), m:FindFirstChild("End")
		if s and e then
			for layer = 1, 2 do
				local p = bare(s:Clone())
				for _, d in ipairs(p:GetChildren()) do d:Destroy() end
				local k = scale * (layer == 1 and 0.92 or 1.06)
				p.Material = Enum.Material.Neon
				p.Color = layer == 1 and pal.core or (li == 2 and pal.deep or pal.main)
				p.Transparency = layer == 1 and 0.45 or 0.05
				p.Size = s.Size * k
				p.CFrame = spin * delta * s.CFrame
				p.Parent = f
				TweenService:Create(p, TI(dur * (layer == 1 and 0.8 or 1), Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = e.Size * k, CFrame = spin * delta * e.CFrame, Transparency = 1,
				}):Play()
			end
		end
	end
end

-- flipbook slash / impact emitters from the pack, recoloured
local SKIP_WORDS = { "glow", "filler", "fog", "smoke", "ink", "dark", "plume", "billow", "water", "splash", "shaded" }
local function SKIP(name)
	name = string.lower(name)
	for _, w in ipairs(SKIP_WORDS) do
		if string.find(name, w, 1, true) then return true end
	end
	return false
end

local function flipbooks(f, cf, pal, mult, groundToo)
	local sizeK = groundToo and 0.75 or 0.6
	if not pack then return end
	local host = bare(Instance.new("Part"))
	host.Transparency, host.Size, host.CFrame = 1, Vector3.one, cf
	host.Parent = f
	local function from(container)
		for _, e in ipairs(container:GetDescendants()) do
			-- the ink pack's soft glows / smoke / ink blots turn into flat white blobs once recoloured, so only the sharp shapes are kept
			if e:IsA("ParticleEmitter") and not SKIP(e.Name) then
				local c = e:Clone()
				c.Enabled = false
				c.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, pal.core), ColorSequenceKeypoint.new(0.12, pal.main), ColorSequenceKeypoint.new(1, pal.deep) })
				c.LightEmission = 1 -- additive: the pack's black ink outlines vanish, only the light stays
				c.LightInfluence = 0
				c.Brightness = 1.2
				local ks = {}
				for _, k in ipairs(c.Size.Keypoints) do table.insert(ks, NumberSequenceKeypoint.new(k.Time, k.Value * sizeK, k.Envelope * sizeK)) end
				c.Size = NumberSequence.new(ks)
				c.TimeScale = c.TimeScale / slow()
				c.Parent = host
				c:Emit(math.ceil((e:GetAttribute("EmitCount") or 1) * mult))
			end
		end
	end
	local slash = pack:FindFirstChild("InkSlash") and pack.InkSlash:FindFirstChild("Slash")
	if slash then from(slash) end
	if groundToo then
		local g = pack.InkSlash:FindFirstChild("GroundEffects")
		if g then from(g) end
	end
end

local function shards(f, pos, dir, pal, n, speed)
	for _ = 1, n do
		local p = bare(Instance.new("Part"))
		p.Material = Enum.Material.Neon
		p.Color = math.random() < 0.4 and pal.core or pal.main
		p.Size = Vector3.new(0.12, 0.12, math.random() * 1.4 + 0.6)
		local d = (dir + Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5) * 1.6).Unit
		p.CFrame = CFrame.lookAt(pos, pos + d)
		p.Parent = f
		local t = 0.22 + math.random() * 0.15
		TweenService:Create(p, TI(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(pos + d * speed * t, pos + d * (speed * t + 1)), Size = Vector3.new(0.02, 0.02, 0.2), Transparency = 1,
		}):Play()
	end
end

local function bolts(f, pos, pal, n)
	for _ = 1, n do
		local a = pos
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.6 - 0.2, math.random() - 0.5).Unit
		for _ = 1, 5 do
			local b = a + (dir + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.9).Unit * (0.6 + math.random() * 0.8)
			local p = bare(Instance.new("Part"))
			p.Material = Enum.Material.Neon
			p.Color = pal.main
			p.Size = Vector3.new(0.14, 0.14, (b - a).Magnitude)
			p.CFrame = CFrame.lookAt((a + b) / 2, b)
			p.Parent = f
			TweenService:Create(p, TI(0.18), { Transparency = 1, Size = p.Size * Vector3.new(0.2, 0.2, 1) }):Play()
			a = b
		end
	end
end

-- impact: small hot core + a starburst of thin light streaks facing the camera (no solid disks blocking the view)
local function flash(f, pos, pal, size)
	local ball = bare(Instance.new("Part"))
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = pal.main
	ball.Transparency = 0.25
	ball.Size = Vector3.one * 0.6
	ball.CFrame = CFrame.new(pos)
	ball.Parent = f
	TweenService:Create(ball, TI(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size * 0.35, Transparency = 1 }):Play()
	local cam = workspace.CurrentCamera
	local face = CFrame.lookAt(pos, cam.CFrame.Position)
	local n = math.floor(6 + size)
	for i = 1, n do
		local ang = (i / n) * math.pi * 2 + math.random() * 0.3
		local len = size * (0.35 + math.random() * 0.45)
		local dirCF = face * CFrame.Angles(0, 0, ang)
		local p = bare(Instance.new("Part"))
		p.Material = Enum.Material.Neon
		p.Color = i % 3 == 0 and pal.core or (i % 3 == 1 and pal.main or pal.deep)
		p.Size = Vector3.new(0.16, 0.6, 0.05)
		p.CFrame = dirCF * CFrame.new(0, 0.6, 0)
		p.Parent = f
		TweenService:Create(p, TI(0.16 + math.random() * 0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.03, len, 0.03), CFrame = dirCF * CFrame.new(0, len * 0.75, 0), Transparency = 1,
		}):Play()
	end
end

-- ground shockwave: a ring of glowing blades racing outward along the floor (hollow, so the player still sees the fight)
local function groundRing(f, root, pal, size)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { root.Parent, f }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), ray)
	if not hit then return end
	local c = hit.Position + Vector3.new(0, 0.1, 0)
	local n = 28
	for i = 1, n do
		local ang = (i / n) * math.pi * 2
		local base = CFrame.new(c) * CFrame.Angles(0, ang, 0)
		local p = bare(Instance.new("Part"))
		p.Material = Enum.Material.Neon
		p.Color = i % 2 == 0 and pal.main or pal.deep
		p.Transparency = 0.1
		p.Size = Vector3.new(0.9, 0.12, 0.35)
		p.CFrame = base * CFrame.new(0, 0, -1.2)
		p.Parent = f
		TweenService:Create(p, TI(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			CFrame = base * CFrame.new(0, 0, -size * 0.5), Size = Vector3.new(size * 0.12, 0.04, 0.12), Transparency = 1,
		}):Play()
	end
end

-- blade sweep: every frame while the sword's trail is on, a glowing sheet is laid between the previous and the current
-- position of the blade (tip bright, toward the guard faint), so the slash is literally the path the sword cut
local RunService = game:GetService("RunService")
local function bladeOf(tool)
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle then return end
	local best, bestMag
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") and d ~= handle and d.Transparency < 1 then
			local m = d.Size.Magnitude
			if not bestMag or m > bestMag then best, bestMag = d, m end
		end
	end
	best = best or handle
	local sz = best.Size
	local axis = (sz.X >= sz.Y and sz.X >= sz.Z) and Vector3.xAxis or ((sz.Y >= sz.Z) and Vector3.yAxis or Vector3.zAxis)
	local half = math.max(sz.X, sz.Y, sz.Z) / 2
	local a, b = best.CFrame:PointToWorldSpace(axis * half), best.CFrame:PointToWorldSpace(-axis * half)
	if (a - handle.Position).Magnitude < (b - handle.Position).Magnitude then axis = -axis end
	return best, axis, half
end

local function sheet(f, p0, p1, q0, q1, color, transp, life)
	-- quad p0-p1 (old edge) to q0-q1 (new edge) approximated by one thin plate
	local mid = (p0 + p1 + q0 + q1) / 4
	local along = ((p1 - p0) + (q1 - q0)) / 2
	local across = ((q0 - p0) + (q1 - p1)) / 2
	if along.Magnitude < 0.05 or across.Magnitude < 0.02 then return end
	local n = along:Cross(across)
	if n.Magnitude < 1e-4 then return end
	local cf = CFrame.fromMatrix(mid, along.Unit, n.Unit)
	local p = bare(Instance.new("Part"))
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transp
	p.Size = Vector3.new(along.Magnitude, 0.04, across.Magnitude + 0.18)
	p.CFrame = cf
	p.Parent = f
	TweenService:Create(p, TI(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1, Size = Vector3.new(along.Magnitude * 1.02, 0.01, across.Magnitude + 0.18),
	}):Play()
end

-- four-point anime glint (luxury sparkle) facing the camera
local function glint(f, pos, pal, size)
	local cam = workspace.CurrentCamera
	local face = CFrame.lookAt(pos, cam.CFrame.Position)
	for i = 0, 3 do
		local p = bare(Instance.new("Part"))
		p.Material = Enum.Material.Neon
		p.Color = i % 2 == 0 and pal.core or pal.main
		p.Size = Vector3.new(0.12, 0.1, 0.02)
		p.CFrame = face * CFrame.Angles(0, 0, math.rad(i * 45))
		p.Parent = f
		local len = (i % 2 == 0) and size or size * 0.55
		TweenService:Create(p, TI(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, len, 0.02) }):Play()
		task.delay(0.09 * slow(), function()
			if p.Parent then
				TweenService:Create(p, TI(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.02, len * 1.2, 0.02), Transparency = 1 }):Play()
			end
		end)
	end
end

local sweeping = {}
-- blade bands from guard (0) to tip (1): {from, to, colour, transparency, life multiplier}
local BANDS = {
	{ 0.0, 0.4, "deep", 0.65, 0.6 },
	{ 0.4, 0.8, "main", 0.2, 1 },
	{ 0.8, 1.0, "core", 0.05, 0.85 },
}
local function sweep(char, tool, pal, heavy, element)
	if sweeping[tool] then return end
	local part, axis, half = bladeOf(tool)
	if not part then return end
	local trails = {}
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("Trail") then table.insert(trails, d) end
	end
	local f = folderFx()
	local function edge()
		local tip = part.CFrame:PointToWorldSpace(axis * half * 1.08)
		local base = part.CFrame:PointToWorldSpace(-axis * half * 0.25)
		return base, tip
	end
	local b0, t0 = edge()
	local started = os.clock()
	local frame = 0
	local ghostParts = {}
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("MeshPart") and d.Transparency < 0.5 and d.Size.Magnitude > 1 then table.insert(ghostParts, d) end
	end
	local conn
	sweeping[tool] = true
	conn = RunService.RenderStepped:Connect(function()
		local on = false
		for _, t in ipairs(trails) do if t.Enabled then on = true break end end
		if not part.Parent or not char.Parent or (os.clock() - started > 0.05 and not on) or os.clock() - started > 1.2 then
			conn:Disconnect()
			sweeping[tool] = nil
			return
		end
		local b1, t1 = edge()
		local life = heavy and 0.3 or 0.22
		-- fast swings move the tip a long way per frame: cut the gap into thin slices and the blade into bands,
		-- so the sheet follows the real curved path instead of showing big flat rectangles
		local steps = math.clamp(math.ceil((t1 - t0).Magnitude / 0.6), 1, 6)
		for k = 1, steps do
			local u0, u1 = (k - 1) / steps, k / steps
			local pb0, pt0 = b0:Lerp(b1, u0), t0:Lerp(t1, u0)
			local pb1, pt1 = b0:Lerp(b1, u1), t0:Lerp(t1, u1)
			for _, band in ipairs(BANDS) do
				sheet(f, pb0:Lerp(pt0, band[1]), pb0:Lerp(pt0, band[2]), pb1:Lerp(pt1, band[1]), pb1:Lerp(pt1, band[2]),
					pal[band[3]], band[4], life * band[5] * (0.75 + 0.25 * u1))
			end
		end
		if element == "Thunder" and math.random() < 0.35 then bolts(f, t1, pal, 1) end
		if (element == "Ice" or element == "Jade" or element == "Lotus") and (t1 - t0).Magnitude > 0.01 and math.random() < 0.5 then
			shards(f, t1, (t1 - t0).Unit, pal, 1, 10)
		end
		if element == "Fire" and math.random() < 0.6 then shards(f, t1, Vector3.yAxis, pal, 2, 6) end
		-- ghost blades: shimmering copies of the sword left along the cut (afterimages)
		frame += 1
		if frame % 3 == 1 then
			for _, src in ipairs(ghostParts) do
				local g = src:Clone()
				for _, ch in ipairs(g:GetChildren()) do ch:Destroy() end
				bare(g)
				g.Material = Enum.Material.ForceField
				g.Color = pal.main
				g.Transparency = 0
				g.CFrame = src.CFrame
				g.Parent = f
				TweenService:Create(g, TI(life * 1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
			end
		end
		b0, t0 = b1, t1
	end)
end

-- local player only: camera shake, FOV punch, a one-frame colour "impact frame" on the finisher
local function feel(char, strength, heavy)
	if Players.LocalPlayer.Character ~= char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local cam = workspace.CurrentCamera
	if hum then
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 0.18 and hum.Parent do
				local k = strength * (1 - (os.clock() - t0) / 0.18)
				hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
				task.wait()
			end
			if hum.Parent then hum.CameraOffset = Vector3.zero end
		end)
	end
	local fov = cam.FieldOfView
	cam.FieldOfView = fov + (heavy and 6 or 2.5)
	TweenService:Create(cam, TI(0.25, Enum.EasingStyle.Quad), { FieldOfView = fov }):Play()
	if heavy then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Contrast, cc.Saturation, cc.Brightness = 0.6, -0.6, 0.15
		cc.Parent = Lighting
		TweenService:Create(cc, TI(0.2), { Contrast = 0, Saturation = 0, Brightness = 0 }):Play()
		Debris:AddItem(cc, 0.25)
	end
end

-- phase "Swing" at the start of the cut, "Contact" on each hit time
function SwordFX.Spawn(char, tool, clip, phase)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local pal = palette(tool)
	local el = tool and tool:GetAttribute("Element")
	local f = folderFx()
	local fx = clip.fx
	local cf = root.CFrame
	if phase == "Swing" then
		if fx.thrust then
			-- spiral spear of light straight ahead
			for i = 1, 3 do
				local p = bare(Instance.new("Part"))
				p.Material = Enum.Material.Neon
				p.Color = i == 1 and pal.core or (i == 2 and pal.main or pal.deep)
				p.Size = Vector3.new(0.5 + i * 0.35, 0.5 + i * 0.35, 1)
				p.Transparency = 0.1 * i
				p.CFrame = cf * CFrame.new(0.4, 0.3, -1.5)
				p.Parent = f
				TweenService:Create(p, TI(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = Vector3.new(0.05, 0.05, fx.reach * 1.6), CFrame = cf * CFrame.new(0.4, 0.3, -1.5 - fx.reach * 0.8), Transparency = 1,
				}):Play()
			end
		else
			sweep(char, tool, pal, clip.heavy, el)
		end
	elseif phase == "Contact" then
		local heavy = clip.heavy
		local pos = cf:PointToWorldSpace(Vector3.new(0, 0.4, -(fx.reach * 0.62)))
		flash(f, pos, pal, heavy and 8 or 5)
		local part, axis, half = bladeOf(tool)
		if part then glint(f, part.CFrame:PointToWorldSpace(axis * half), pal, heavy and 5 or 3.2) end
		flipbooks(f, CFrame.lookAt(pos, pos + cf.LookVector) * CFrame.Angles(0, 0, math.rad(fx.roll or 0)), pal, heavy and 2 or 1.3, heavy)
		shards(f, pos, cf.LookVector, pal, heavy and 26 or 14, heavy and 46 or 32)
		if el == "Thunder" then bolts(f, pos, pal, heavy and 6 or 3) end
		if heavy then
			groundRing(f, root, pal, 22)
		end
		feel(char, heavy and 1.1 or 0.4, heavy)
	end
end

return SwordFX
