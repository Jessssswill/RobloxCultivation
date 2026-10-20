-- Script: ServerScriptService.WeaponSkills
-- Skill Z/X dan ultimate G milik tiap pedang yang dibeli, plus pasif tebasan biasa.
-- Pedang dikenali dari attribute "Element" di Tool: Thunder (Spirit Sword), Ice (Sky Sword),
-- Lotus (Lotus Jade Jian), Jade (Dragon Jade Blade). Tanpa Element, Z/X/G tetap skill global lama.
-- Server cuma ngitung damage, status, dan timing. Efek yang gerak digambar tiap client lewat QiRemotes.WeaponFx
-- biar mulus dan gak bikin lag jaringan.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Core = require(game:GetService("ServerScriptService"):WaitForChild("CombatCore"))
local R = RS:WaitForChild("QiRemotes")
local SkillRemote = R:WaitForChild("WeaponSkill")
local FxRemote = R:WaitForChild("WeaponFx")

-- damage = pengali dari stat tabel di "Konsep efek senjata.md"
local STATS = {
	Thunder = {dmg = 0.95},
	Lotus = {dmg = 0.90},
	Ice = {dmg = 1.10},
	Jade = {dmg = 1.35},
}
local CD = {Z = 4, X = 9, G = 28}
-- jeda sebelum efek keluar, biar pas sama ayunan animasi
local DELAY = {Z = 0.15, X = 0.25, G = 0}

local function fx(kind, ...)
	FxRemote:FireAllClients(kind, ...)
end

local function charOf(plr)
	local c = plr.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if h and r and h.Health > 0 then return c, r, h end
end

local function weaponOf(char)
	local t = char and char:FindFirstChildOfClass("Tool")
	local el = t and t:GetAttribute("Element")
	if el and STATS[el] then return t, el end
end

local cds = {}
local function ready(plr, key, cd)
	cds[plr] = cds[plr] or {}
	if os.clock() < (cds[plr][key] or 0) then return false end
	cds[plr][key] = os.clock() + cd
	return true
end
Players.PlayerRemoving:Connect(function(p) cds[p] = nil end)

local function flatDir(from, to, fallback)
	local v = to and (to - from) or fallback
	v = Vector3.new(v.X, 0, v.Z)
	if v.Magnitude < 0.1 then v = Vector3.new(fallback.X, 0, fallback.Z) end
	return v.Unit
end

local function aimPoint(root, aim, maxD, default)
	local c = aim or (root.Position + root.CFrame.LookVector * default)
	local off = Vector3.new(c.X - root.Position.X, 0, c.Z - root.Position.Z)
	if off.Magnitude > maxD then c = root.Position + off.Unit * maxD end
	return Core.ground(c)
end

local function hitAll(plr, list, base, el, src, kb)
	for _, m in list do Core.dealDamage(plr, m, base * STATS[el].dmg, src, kb) end
end

local function stun(m, t)
	m:SetAttribute("StunUntil", math.max(m:GetAttribute("StunUntil") or 0, os.clock() + t))
end

-- lambat karena es: kecepatan dibagi dua, balik lagi kalau waktunya habis
local function slow(m, t)
	local h = Core.alive(m)
	if not h then return end
	local token = os.clock()
	if not m:GetAttribute("FrostSlow") then
		m:SetAttribute("FrostBase", h.WalkSpeed)
		h.WalkSpeed *= 0.5
	end
	m:SetAttribute("FrostSlow", token)
	fx("Frost", m, t)
	task.delay(t, function()
		if m.Parent and m:GetAttribute("FrostSlow") == token then
			m:SetAttribute("FrostSlow", nil)
			local h2 = m:FindFirstChildOfClass("Humanoid")
			if h2 then h2.WalkSpeed = m:GetAttribute("FrostBase") or h2.WalkSpeed end
		end
	end)
end

local function freeze(m, t)
	stun(m, t)
	slow(m, t)
	fx("Freeze", m, t)
end

local function heal(hum, root, frac)
	if hum.Health <= 0 or hum.Health >= hum.MaxHealth then return end
	local amt = math.floor(hum.MaxHealth * frac + 0.5)
	hum.Health = math.min(hum.MaxHealth, hum.Health + amt)
	Core.popNumber(root.Position + Vector3.new(0, 3.5, 0), "+" .. amt, Color3.fromRGB(140, 255, 170))
end

local function playersNear(pos, r)
	local list = {}
	for _, p in Players:GetPlayers() do
		local c, root, hum = charOf(p)
		if c and (root.Position - pos).Magnitude <= r then table.insert(list, {p, root, hum}) end
	end
	return list
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local function wallCheck(char, from, dir, dist)
	rp.FilterDescendantsInstances = {char, workspace:FindFirstChild("FX"), workspace:FindFirstChild("Monsters")}
	local res = workspace:Raycast(from, dir * dist, rp)
	return res and math.max(0, (res.Position - from).Magnitude - 2) or dist
end

local SK = {Thunder = {}, Ice = {}, Lotus = {}, Jade = {}}

-- ================= Spirit Sword: awan petir =================
-- Z Thunder Step: melesat jadi kilat, nyetrum semua yang dilewati
function SK.Thunder.Z(plr, char, root, aim, el)
	local dir = flatDir(root.Position, aim, root.CFrame.LookVector)
	local from = root.Position
	local dist = wallCheck(char, from, dir, 22)
	local to = from + dir * dist
	char:SetAttribute("IFrameUntil", os.clock() + 0.3)
	root.CFrame = CFrame.lookAt(to, to + dir)
	local mid = (from + to) / 2
	local list = Core.enemiesInBox(CFrame.lookAt(mid, to), Vector3.new(8, 8, dist + 4))
	local hits = {}
	for _, m in list do table.insert(hits, m.HumanoidRootPart.Position) end
	fx("ThunderStep", from, to, hits)
	hitAll(plr, list, 30, el, "sword", 12)
	for _, m in list do stun(m, 0.5) end
end

-- X Cloud Thunder: awan hitam di titik bidik, petir nyambar berkali-kali
function SK.Thunder.X(plr, char, root, aim, el)
	local center = aimPoint(root, aim, 40, 18)
	fx("ThunderCloud", center, 11, 1.6)
	task.wait(0.55)
	for i = 1, 5 do
		local a = math.random() * math.pi * 2
		local pos = Core.ground(center + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * 8)
		fx("Strike", pos, 5, false)
		hitAll(plr, Core.enemiesInRadius(pos, 5), 14, el, "sword", 12)
		task.wait(0.16)
	end
	fx("Strike", center, 9, true)
	local list = Core.enemiesInRadius(center, 9)
	hitAll(plr, list, 26, el, "sword", 40)
	for _, m in list do stun(m, 0.6) end
	Core.shakeNear(center, 0.6, 0.25)
end

-- G Nine Clouds Thunder: sembilan awan melingkar, sambar satu-satu, lalu menyatu jadi pilar petir raksasa
function SK.Thunder.G(plr, char, root, aim, el)
	local center = aimPoint(root, aim, 30, 14)
	task.wait(1.25)
	fx("NineClouds", center, 15)
	task.wait(0.7)
	for i = 1, 9 do
		local a = (i / 9) * math.pi * 2
		local pos = Core.ground(center + Vector3.new(math.cos(a), 0, math.sin(a)) * 15)
		fx("Strike", pos, 7, false)
		hitAll(plr, Core.enemiesInRadius(pos, 7), 18, el, "sword", 10)
		task.wait(0.14)
	end
	task.wait(0.25)
	fx("ThunderPillar", center, 18)
	local list = Core.enemiesInRadius(center, 18)
	hitAll(plr, list, 120, el, "ult", 90)
	for _, m in list do stun(m, 1.5) end
	Core.shakeNear(center, 1.4, 0.6)
end

-- ================= Sky Sword: es =================
-- Z Frost Thrust: tusukan yang memunculkan barisan duri es
function SK.Ice.Z(plr, char, root, aim, el)
	local dir = flatDir(root.Position, aim, root.CFrame.LookVector)
	local from = root.Position
	local dist = wallCheck(char, from, dir, 24)
	fx("FrostThrust", Core.ground(from), dir, dist)
	task.wait(0.15)
	local mid = from + dir * (dist / 2)
	local list = Core.enemiesInBox(CFrame.lookAt(mid, mid + dir), Vector3.new(7, 8, dist + 2))
	hitAll(plr, list, 28, el, "sword", 15)
	for _, m in list do
		stun(m, 0.3)
		slow(m, 2.5)
	end
end

-- X Frozen Heaven: lingkaran es, musuh membeku, lalu pecah
function SK.Ice.X(plr, char, root, aim, el)
	local center = aimPoint(root, aim, 35, 16)
	fx("FrozenField", center, 12, 2.2)
	task.wait(0.5)
	local list = Core.enemiesInRadius(center, 12)
	hitAll(plr, list, 22, el, "sword", 0)
	for _, m in list do freeze(m, 1.6) end
	task.wait(1.6)
	fx("Shatter", center, 12)
	hitAll(plr, Core.enemiesInRadius(center, 13), 24, el, "sword", 30)
	Core.shakeNear(center, 0.5, 0.2)
end

-- G Frozen Heaven Severance: pedang es raksasa jatuh dari langit, area membeku, lalu tebasan langit memecahkan semuanya
function SK.Ice.G(plr, char, root, aim, el)
	local center = aimPoint(root, aim, 30, 16)
	task.wait(1.25)
	fx("IceSword", center, 22)
	task.wait(0.75)
	local list = Core.enemiesInRadius(center, 22)
	hitAll(plr, list, 50, el, "sword", 0)
	for _, m in list do freeze(m, 2.2) end
	Core.shakeNear(center, 1.0, 0.4)
	task.wait(1.1)
	local _, r2 = charOf(plr)
	fx("IceSever", center, 23, r2 and r2.Position or center)
	task.wait(0.2)
	local list2 = Core.enemiesInRadius(center, 23)
	hitAll(plr, list2, 110, el, "ult", 70)
	for _, m in list2 do slow(m, 4) end
	Core.shakeNear(center, 1.4, 0.5)
end

-- ================= Lotus Jade Jian: teratai =================
-- Z Petal Dance: berputar dalam pusaran kelopak, tiap putaran sedikit nyembuhin
function SK.Lotus.Z(plr, char, root, aim, el)
	fx("PetalDance", root, 10, 0.8)
	for i = 1, 3 do
		local c, r2, h2 = charOf(plr)
		if not c then return end
		local list = Core.enemiesInRadius(r2.Position, 10)
		hitAll(plr, list, 12, el, "sword", i == 3 and 30 or 6)
		if #list > 0 then heal(h2, r2, 0.04) end
		task.wait(0.22)
	end
end

-- X Lotus Guard: teratai pelindung, damage masuk dikurangi 60% selama 3 detik, kelopak meledak keluar
function SK.Lotus.X(plr, char, root, aim, el)
	char:SetAttribute("LotusGuardUntil", os.clock() + 3)
	fx("LotusGuard", root, 3)
	local _, r2, h2 = charOf(plr)
	if h2 then heal(h2, r2, 0.12) end
	task.wait(0.2)
	hitAll(plr, Core.enemiesInRadius(root.Position, 10), 18, el, "sword", 45)
end

-- G Thousand Petal Bloom: teratai raksasa mekar, badai seribu kelopak, nyembuhin kawan di dalamnya
function SK.Lotus.G(plr, char, root, aim, el)
	local center = Core.ground(root.Position)
	task.wait(1.25)
	fx("LotusBloom", center, 22, 3)
	task.wait(0.5)
	for i = 1, 6 do
		hitAll(plr, Core.enemiesInRadius(center, 22), 16, el, "sword", 6)
		for _, e in playersNear(center, 22) do heal(e[3], e[2], 0.04) end
		task.wait(0.4)
	end
	fx("LotusFinale", center, 22)
	hitAll(plr, Core.enemiesInRadius(center, 22), 85, el, "ult", 55)
	Core.shakeNear(center, 1.0, 0.4)
end

-- ================= Dragon Jade Blade: naga giok =================
-- Z Dragon Roar: auman naga, gelombang kejut berbentuk kerucut ke depan
function SK.Jade.Z(plr, char, root, aim, el)
	local dir = flatDir(root.Position, aim, root.CFrame.LookVector)
	fx("DragonRoar", root.Position, dir, 18)
	local list = {}
	for _, m in Core.enemiesInRadius(root.Position, 18) do
		local v = m.HumanoidRootPart.Position - root.Position
		v = Vector3.new(v.X, 0, v.Z)
		if v.Magnitude < 3 or v.Unit:Dot(dir) > 0.45 then table.insert(list, m) end
	end
	hitAll(plr, list, 32, el, "sword", 65)
	for _, m in list do stun(m, 0.5) end
	Core.shakeNear(root.Position, 0.5, 0.2)
end

-- X Jade Dragon Rush: naga giok menerjang lurus ke depan, nabrak semua di jalurnya
function SK.Jade.X(plr, char, root, aim, el)
	local dir = flatDir(root.Position, aim, root.CFrame.LookVector)
	local from = root.Position + Vector3.new(0, 1, 0)
	local dist, dur = 44, 0.75
	fx("DragonRush", from, dir, dist, dur)
	local hit = {}
	local t0 = os.clock()
	while os.clock() - t0 < dur do
		local k = (os.clock() - t0) / dur
		local head = from + dir * dist * k
		for _, m in Core.enemiesInRadius(head, 6) do
			if not hit[m] then
				hit[m] = true
				Core.dealDamage(plr, m, 44 * STATS[el].dmg, "sword", 55)
			end
		end
		task.wait(0.05)
	end
end

-- G Jade Dragon Descends: naga giok raksasa turun memutar dari langit lalu menghantam tanah
function SK.Jade.G(plr, char, root, aim, el)
	local center = aimPoint(root, aim, 30, 16)
	task.wait(1.25)
	fx("DragonDescend", center, 16, 2.2)
	for i = 1, 3 do
		task.wait(0.55)
		hitAll(plr, Core.enemiesInRadius(center, 17), 22, el, "sword", 15)
	end
	task.wait(0.55)
	fx("JadeImpact", center, 19)
	local list = Core.enemiesInRadius(center, 19)
	hitAll(plr, list, 140, el, "ult", 100)
	for _, m in list do stun(m, 1.5) end
	Core.shakeNear(center, 1.6, 0.6)
end

SkillRemote.OnServerEvent:Connect(function(plr, key, aim)
	if key ~= "Z" and key ~= "X" and key ~= "G" then return end
	if aim ~= nil and typeof(aim) ~= "Vector3" then return end
	local char, root = charOf(plr)
	if not char or plr:GetAttribute("Meditating") or plr:GetAttribute("Flying") then return end
	local tool, el = weaponOf(char)
	if not tool then return end
	if not ready(plr, el .. key, CD[key] - 0.2) then return end
	if key == "G" then fx("UltStart", plr, el) end
	task.spawn(function()
		if DELAY[key] > 0 then task.wait(DELAY[key]) end
		local c2, r2 = charOf(plr)
		if c2 then SK[el][key](plr, c2, r2, aim, el) end
	end)
end)

-- ================= Pasif tebasan biasa (klik) =================
-- Dibungkus di Core.dealDamage supaya ComboServer di tiap Tool gak perlu diubah.
local rawDeal = Core.dealDamage
local hitCount = {}
Players.PlayerRemoving:Connect(function(p) hitCount[p] = nil end)

local PASSIVE = {}
-- Spirit Sword: 30% peluang petir merambat ke 2 musuh terdekat
function PASSIVE.Thunder(plr, m, base)
	if math.random() > 0.3 then return end
	local from = m.HumanoidRootPart.Position
	local list, targets = {}, {}
	for _, e in Core.enemiesInRadius(from, 12) do
		if e ~= m then table.insert(list, e) end
	end
	table.sort(list, function(a, b)
		return (a.HumanoidRootPart.Position - from).Magnitude < (b.HumanoidRootPart.Position - from).Magnitude
	end)
	for i = 1, math.min(2, #list) do
		table.insert(targets, list[i].HumanoidRootPart.Position)
		rawDeal(plr, list[i], base * 0.4, "passive", 0)
	end
	fx("Chain", from, targets)
end
-- Sky Sword: tiap hit ke-4 bikin musuh melambat
function PASSIVE.Ice(plr, m, base, n)
	if n % 4 == 0 then slow(m, 2) end
end
-- Lotus Jade Jian: tiap hit nyembuhin 2% darah
function PASSIVE.Lotus(plr, m)
	local _, root, hum = charOf(plr)
	if hum then heal(hum, root, 0.02) end
end
-- Dragon Jade Blade: tiap hit ke-4 mental jauh
function PASSIVE.Jade(plr, m, base, n)
	if n % 4 ~= 0 then return end
	local _, root = charOf(plr)
	local mr = m:FindFirstChild("HumanoidRootPart")
	if not (root and mr) or m:GetAttribute("Heavy") then return end
	local v = mr.Position - root.Position
	v = Vector3.new(v.X, 0, v.Z)
	if v.Magnitude > 0.01 then mr.AssemblyLinearVelocity = v.Unit * 70 + Vector3.new(0, 25, 0) end
	fx("JadeBurst", mr.Position)
end

Core.dealDamage = function(plr, m, base, src, kb, ...)
	if src == "combo" and plr then
		local _, el = weaponOf(plr.Character)
		if el then
			hitCount[plr] = (hitCount[plr] or 0) + 1
			local dmg = rawDeal(plr, m, base * STATS[el].dmg, src, kb, ...)
			if dmg and m.Parent and m:FindFirstChild("HumanoidRootPart") then
				task.spawn(PASSIVE[el], plr, m, base * STATS[el].dmg, hitCount[plr])
			end
			return dmg
		end
	end
	return rawDeal(plr, m, base, src, kb, ...)
end

-- Lotus Guard: kurangi damage yang masuk
local rawHurt = Core.damagePlayer
Core.damagePlayer = function(char, dmg, src, heavy)
	if char and (char:GetAttribute("LotusGuardUntil") or 0) > os.clock() then dmg *= 0.4 end
	return rawHurt(char, dmg, src, heavy)
end
