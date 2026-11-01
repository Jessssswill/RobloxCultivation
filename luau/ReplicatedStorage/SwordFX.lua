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
local SKIP_WORDS = { "glow", "filler", "fog", "smoke", "ink", "dark", "plume", "billow", "water", "splash" }
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
				c.LightEmission = 0.45
				c.LightInfluence = 0
				c.Brightness = math.min(c.Brightness, 2)
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
			crescent(f, root, pal, fx.roll, 0.42 * fx.reach / 6, 0.3)
		end
	elseif phase == "Contact" then
		local heavy = clip.heavy
		local pos = cf:PointToWorldSpace(Vector3.new(0, 0.4, -(fx.reach * 0.62)))
		flash(f, pos, pal, heavy and 8 or 5)
		flipbooks(f, CFrame.lookAt(pos, pos + cf.LookVector) * CFrame.Angles(0, 0, math.rad(fx.roll or 0)), pal, heavy and 2 or 1.3, heavy)
		shards(f, pos, cf.LookVector, pal, heavy and 26 or 14, heavy and 46 or 32)
		if el == "Thunder" then bolts(f, pos, pal, heavy and 6 or 3) end
		if heavy then
			groundRing(f, root, pal, 22)
			crescent(f, root, pal, 0, 0.7, 0.4)
		end
		feel(char, heavy and 1.1 or 0.4, heavy)
	end
end

return SwordFX
