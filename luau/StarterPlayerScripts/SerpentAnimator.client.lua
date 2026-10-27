-- SerpentAnimator (LocalScript, StarterPlayerScripts)
-- Menggerakkan naga ular (rig tulang datar: S01..S24 ekor->leher, Head, Jaw) secara procedural:
-- kepala melayang mengikuti HumanoidRootPart boss + pose serangan (atribut "Pose" dari MonsterAI),
-- tubuh menyusul di jalur yang dilalui kepala seperti ular, dengan ayunan pelan. Tidak butuh upload animasi.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local HOVER = 13            -- tinggi kepala di atas tanah boss (studs)
local POSE = {              -- {maju, naik, pitch kepala, bukaan rahang (derajat), kecepatan}
	[""]      = {4, 0, -2, 6, 5},
	Windup    = {-7, 7, 10, 20, 7},
	Strike    = {11, -9, -14, 42, 16},
	Rear      = {-4, 16, 18, 25, 6},
	Slam      = {7, -12, -22, 32, 14},
	Low       = {3, -6, -8, 15, 8},
	Roar      = {-3, 9, 22, 48, 6},
	Stun      = {5, -12, -25, 12, 5},
}

local rigs = {}

local function setup(rootPart)
	if rigs[rootPart] then return end
	local visual = rootPart.Parent
	local boss = visual.Parent
	local hrp = boss and boss:FindFirstChild("HumanoidRootPart")
	local hum = boss and boss:FindFirstChildOfClass("Humanoid")
	local rootBone = rootPart:FindFirstChild("Root")
	if not (hrp and hum and rootBone) then return end
	local spine, head, jaw = {}, rootBone:FindFirstChild("Head"), rootBone:FindFirstChild("Jaw")
	for i = 1, 24 do
		local b = rootBone:FindFirstChild(string.format("S%02d", i))
		if b then table.insert(spine, b) end
	end
	-- pose istirahat relatif terhadap RootPart (Transform masih identitas saat ini)
	local pc = rootPart.CFrame
	local function rel(b) b.Transform = CFrame.identity return pc:ToObjectSpace(b.WorldCFrame) end
	local fwdL = pc:VectorToObjectSpace((head.WorldPosition - spine[1].WorldPosition).Unit)
	local upL = rootPart:GetAttribute("UpLocal") or Vector3.yAxis
	local function frame(posL)  -- frame "ular" lokal: maju = ke kepala, atas = punggung
		return CFrame.lookAt(posL, posL + fwdL, upL)
	end
	local R = {}
	local data = {spine = {}, root = rootPart, hrp = hrp, hum = hum, boss = boss}
	for i, b in spine do
		local r = rel(b)
		data.spine[i] = {bone = b, rest = r, off = frame(r.Position):Inverse() * r, d = 0}
	end
	local hr, jr = rel(head), rel(jaw)
	local hf = frame(hr.Position)
	data.head = {bone = head, rest = hr, off = hf:Inverse() * hr}
	data.jaw = {bone = jaw, rest = jr, off = hf:Inverse() * jr, pivot = hf:PointToObjectSpace(jr.Position)}
	-- jarak sepanjang tubuh dari kepala ke tiap tulang
	for i, s in data.spine do s.d = (hr.Position - s.rest.Position):Dot(fwdL) end
	data.len = data.spine[1].d + 6
	-- rantai titik tubuh: [0] = pangkal leher, [i] = tulang punggung ke-(25-i) dari ekor; panjang ruas tetap
	local hp = hrp.Position + Vector3.new(0, HOVER, 0)
	local back = -hrp.CFrame.LookVector
	table.sort(data.spine, function(a, b) return a.d < b.d end)   -- urut dari dekat kepala ke ekor
	data.chain, data.seg = {}, {}
	local prevD = 3
	for i, s in data.spine do
		data.seg[i] = math.max(s.d - prevD, 0.5)
		prevD = s.d
		data.chain[i] = hp + back * s.d - Vector3.new(0, math.min(s.d * 0.12, HOVER - 3), 0)
	end
	data.headPos, data.headDir, data.jawA, data.t = hp, hrp.CFrame.LookVector, 0, 0
	rigs[rootPart] = data
end

local function scan()
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("SerpentRig") then setup(d) end
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") and d:GetAttribute("SerpentRig") then task.defer(setup, d) end
end)
scan()

-- titik di jalur pada jarak d di belakang kepala (jalur[1] = posisi kepala terbaru)
local function sample(trail, d)
	local acc = 0
	for i = 1, #trail - 1 do
		local a, b = trail[i], trail[i + 1]
		local L = (b - a).Magnitude
		if acc + L >= d then return a:Lerp(b, (d - acc) / math.max(L, 1e-3)) end
		acc += L
	end
	local n = #trail
	local dir = n > 1 and (trail[n] - trail[n - 1]).Unit or Vector3.zAxis
	return trail[n] + dir * (d - acc)
end

RunService.RenderStepped:Connect(function(dt)
	for rootPart, R in rigs do
		if not rootPart.Parent or not R.boss.Parent then rigs[rootPart] = nil continue end
		R.t += dt
		local hrp = R.hrp
		local fwd = hrp.CFrame.LookVector
		fwd = Vector3.new(fwd.X, 0, fwd.Z).Unit
		local up = Vector3.yAxis
		local pose = R.boss:GetAttribute("Pose") or ""
		if R.hum.Health <= 0 then pose = "Stun" end
		local P = POSE[pose] or POSE[""]
		local groundY = hrp.Position.Y - hrp.Size.Y / 2 - R.hum.HipHeight
		local target = Vector3.new(hrp.Position.X, groundY + HOVER, hrp.Position.Z) + fwd * P[1] + up * P[2]
		target += up * math.sin(R.t * 1.4) * 1.2
		local k = 1 - math.exp(-dt * P[5])
		R.headPos = R.headPos:Lerp(target, k)
		local wantDir = (fwd * 10 + up * P[3] * 0.4).Unit
		R.headDir = R.headDir:Lerp(wantDir, k).Unit
		R.jawA += (math.rad(P[4] + math.sin(R.t * 2.1) * 3) - R.jawA) * math.min(1, dt * 10)

		-- rantai: tiap ruas ditarik ruas di depannya dengan panjang tetap (tubuh selalu terentang, terseret di belakang)
		local neck = R.headPos - R.headDir * 3
		local chain = R.chain
		local backDir = -R.headDir
		for i = 1, #chain do
			local prev = i == 1 and neck or chain[i - 1]
			local v = chain[i] - prev
			v = v.Magnitude > 1e-3 and v.Unit or backDir
			v = (v + backDir * 0.02 * dt * 60).Unit                       -- pelan-pelan meluruskan ke belakang
			local p = prev + v * R.seg[i]
			local floorY = groundY + 3 + (1 - i / #chain) * 2
			local sagY = groundY + 3.5 + (HOVER - 4) * (1 - i / #chain) ^ 1.6  -- leher tinggi, ekor di lantai
			p = Vector3.new(p.X, math.max(floorY, p.Y + (sagY - p.Y) * math.min(1, dt * 1.5)), p.Z)
			chain[i] = p
		end

		local pc = rootPart.CFrame
		-- tulang punggung (+ ayunan ular, tidak disimpan ke rantai)
		for i, s in R.spine do
			local p = chain[i]
			local pa = i == 1 and neck or chain[i - 1]
			local pb = chain[math.min(i + 1, #chain)]
			local f = (pa - pb)
			f = f.Magnitude > 1e-3 and f.Unit or R.headDir
			local side = f:Cross(up)
			side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
			local amp = 2.4 * math.clamp(s.d / 25, 0, 1)
			p += side * math.sin(R.t * 2.0 - s.d * 0.075) * amp
			local W = CFrame.lookAt(p, p + f, up) * s.off
			s.bone.Transform = (pc * s.rest):Inverse() * W
		end
		-- kepala & rahang
		local H = CFrame.lookAt(R.headPos, R.headPos + R.headDir, up)
		R.head.bone.Transform = (pc * R.head.rest):Inverse() * (H * R.head.off)
		local J = R.jaw
		local hinge = CFrame.new(J.pivot) * CFrame.Angles(-R.jawA, 0, 0) * CFrame.new(-J.pivot)
		J.bone.Transform = (pc * J.rest):Inverse() * (H * hinge * J.off)
	end
end)

