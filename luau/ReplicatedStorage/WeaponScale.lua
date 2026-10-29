-- ModuleScript: ReplicatedStorage.WeaponScale
-- Skala senjata dan sarung ngikutin tinggi avatar pemain (keputusan Will 19 Okt 2026).
-- Ukuran dasar senjata (versi BESAR 20 Okt: jian/dao 7, Sky Sword 7,5, Dragon Jade 8 stud) dibikin buat avatar R15
-- standar setinggi REF_HEIGHT.
-- Draft Luau. Nanti dipindah ke roblox-ts di langkah susulan #3.
local WeaponScale = {}

WeaponScale.REF_HEIGHT = 5.2 -- tinggi avatar standar; kalibrasi di Studio pakai WeaponScale.avatarHeight() avatar default
WeaponScale.MIN, WeaponScale.MAX = 0.8, 1.6

-- Tinggi avatar dari telapak kaki sampai ubun-ubun, tanpa aksesoris (rambut/topi nggak dihitung)
function WeaponScale.avatarHeight(character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not (hum and root and head) then return WeaponScale.REF_HEIGHT end
	local ground = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
	local top = head.Position.Y + head.Size.Y / 2
	return math.max(top - ground, 1)
end

function WeaponScale.factorFor(character)
	return math.clamp(WeaponScale.avatarHeight(character) / WeaponScale.REF_HEIGHT, WeaponScale.MIN, WeaponScale.MAX)
end

-- Faktor akhir satu senjata: tinggi avatar x BaseScale senjata itu (attribute di Tool, default 1).
-- BaseScale ngecilin/gedein model hasil import ke ukuran dasarnya tanpa ngubah file 3D-nya.
function WeaponScale.targetFor(character, tool)
	return WeaponScale.factorFor(character) * (tool:GetAttribute("BaseScale") or 1)
end

local function scaleCFrame(cf, k)
	return cf - cf.Position + cf.Position * k
end

-- Skala Tool relatif ke Handle. Aman dipanggil berkali-kali: yang disimpan cuma faktor total.
-- Part yang nyambung lewat Weld/Motor cukup digeser lewat C0/C1 (jangan set CFrame: kalau Tool lagi dipegang, itu
-- ikut nyeret badan). Part yang pake WeldConstraint dilepas dulu, dipindah, terus disambung lagi.
function WeaponScale.scaleTool(tool, target)
	local current = tool:GetAttribute("AppliedScale") or 1
	local k = target / current
	if math.abs(k - 1) < 0.01 then return end
	local handle = tool:FindFirstChild("Handle")
	if not handle then return end
	local constraints = {}
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("WeldConstraint") and d.Enabled then
			local other = (d.Part0 == handle and d.Part1) or (d.Part1 == handle and d.Part0)
			if other then
				table.insert(constraints, { w = d, p = other, rel = handle.CFrame:ToObjectSpace(other.CFrame) })
				d.Enabled = false
			end
		end
	end
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Size *= k
		elseif d:IsA("Attachment") then -- termasuk Bone rumbai
			d.Position *= k
		elseif d:IsA("JointInstance") then
			d.C0 = scaleCFrame(d.C0, k)
			d.C1 = scaleCFrame(d.C1, k)
		elseif d:IsA("Beam") then
			d.Width0 *= k
			d.Width1 *= k
		elseif d:IsA("ParticleEmitter") then
			local kps = {}
			for _, p in ipairs(d.Size.Keypoints) do
				table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
			end
			d.Size = NumberSequence.new(kps)
		end
	end
	for _, c in ipairs(constraints) do
		c.p.CFrame = handle.CFrame * scaleCFrame(c.rel, k)
		c.w.Enabled = true
	end
	tool.Grip = scaleCFrame(tool.Grip, k)
	tool:SetAttribute("AppliedScale", target)
end

-- Sarung (Model) cukup pakai ScaleTo bawaan; offset pinggang di AttachScabbard juga harus dikali faktor yang sama
function WeaponScale.scaleModel(model, target)
	model:ScaleTo(target)
end

return WeaponScale
