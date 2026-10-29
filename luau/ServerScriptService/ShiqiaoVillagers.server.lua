-- Warga Desa Shiqiao. Titik-titiknya di workspace.DesaShiqiao.TitikWarga (Part tak terlihat, atribut "Peran"),
-- dibuat oleh map/shiqiao/warga/buat_titik_warga.lua:
--   Jalan    = titik jalur desa; warga jalan-jalan di sekitar "rumah"-nya sendiri biar tersebar rata
--   Pedagang = pedagang di depan toko, menghadap LookVector titik (atribut "Toko" = jenis toko)
--   Duduk    = duduk di bangku (bukan Seat, biar pemain/warga lain tidak ikut kedudukan)
--   Ngobrol  = dua warga ngobrol berhadapan
--   Diam     = warga berdiri di satu tempat; atribut "Gaya" = Rumah (depan rumah) / Mancing (tepi sungai)
-- Semua bisa diajak bicara (QiRemotes.Dialog). Warga yang diam di-anchor, yang jalan punya anti-nyangkut.
local Players = game:GetService("Players")
local PFS = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local RS = game:GetService("ReplicatedStorage")

local desa = workspace:WaitForChild("DesaShiqiao")
local titik = desa:WaitForChild("TitikWarga")
local Dialog = RS:WaitForChild("QiRemotes"):WaitForChild("Dialog")

local JUMLAH_JALAN = 14
local JUMLAH_ANAK = 4
local RADIUS_JALAN = 90 -- warga jalan-jalan paling jauh segini dari titik rumahnya
local folderWarga = Instance.new("Folder")
folderWarga.Name = "Warga"
local ANIM = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	sit = "rbxassetid://2506281703",
}

-- warga tidak saling tabrak (dulu sering nyangkut karena dua warga saling dorong di jalan sempit)
local GRUP = "Warga"
pcall(function() PhysicsService:RegisterCollisionGroup(GRUP) end)
PhysicsService:CollisionGroupSetCollidable(GRUP, GRUP, false)

-- Penampilan warga = layered clothing katalog (NPC tidak perlu beli). Dipilih dari uji lineup 2026-10-29:
-- baju rakyat biasa warna kusam, bukan jubah naga/dewa yang cocoknya buat kultivator.
local A = Enum.AccessoryType
local KULIT = {Color3.fromRGB(234, 192, 160), Color3.fromRGB(214, 168, 132), Color3.fromRGB(196, 150, 112), Color3.fromRGB(226, 182, 148)}
local CELANA = {Color3.fromRGB(58, 48, 40), Color3.fromRGB(44, 46, 52), Color3.fromRGB(70, 60, 46)}
local BAJU_DALAM = Color3.fromRGB(226, 216, 192) -- warna badan wanita, biar celah ruqun kelihatan kayak baju dalam
local TUNIK, LUMPUR, PETANI = 91359280176800, 107155319275780, 111756851804219
local JUBAH_PUTIH, JUBAH_SARJANA = 79303524577143, 12388431541
local RUQUN_MERAH, RUQUN_HIJAU, RUQUN_UNGU = 18769796770, 18644142060, 18769803736
local LENGAN_BIRU, LENGAN_GADING = 121743765274589, 138557894176101
local RAMBUT_PRIA, RAMBUT_QIN = 12168270604, 94197433224962
local SANGGUL, SANGGUL_DUA = 123842549837356, 71532166378320
local CAPING_BAMBU, CAPING_PADI = 12283471793, 91662445445572
local LOOKS = {
	{tipe = "pria", baju = {{TUNIK, A.Jacket}}, rambut = RAMBUT_PRIA, topi = CAPING_BAMBU},
	{tipe = "pria", baju = {{TUNIK, A.Jacket}}, rambut = RAMBUT_QIN},
	{tipe = "pria", baju = {{LUMPUR, A.Jacket}}, rambut = RAMBUT_QIN, topi = CAPING_PADI},
	{tipe = "pria", baju = {{LUMPUR, A.Jacket}}, rambut = RAMBUT_PRIA},
	{tipe = "pria", baju = {{PETANI, A.Jacket}}, rambut = RAMBUT_PRIA, topi = CAPING_BAMBU},
	{tipe = "pria", baju = {{JUBAH_PUTIH, A.Shirt}}, rambut = RAMBUT_QIN},
	{tipe = "pria", baju = {{JUBAH_SARJANA, A.DressSkirt}}, rambut = RAMBUT_QIN},
	{tipe = "wanita", baju = {{RUQUN_MERAH, A.DressSkirt}, {LENGAN_BIRU, A.Jacket}}, rambut = SANGGUL_DUA},
	{tipe = "wanita", baju = {{RUQUN_HIJAU, A.DressSkirt}, {LENGAN_BIRU, A.Jacket}}, rambut = SANGGUL},
	{tipe = "wanita", baju = {{RUQUN_UNGU, A.DressSkirt}, {LENGAN_BIRU, A.Jacket}}, rambut = SANGGUL_DUA},
	{tipe = "wanita", baju = {{RUQUN_MERAH, A.DressSkirt}, {LENGAN_GADING, A.Jacket}}, rambut = SANGGUL},
	{tipe = "wanita", baju = {{TUNIK, A.Jacket}}, rambut = SANGGUL_DUA},
	{tipe = "wanita", baju = {{LUMPUR, A.Jacket}}, rambut = SANGGUL, topi = CAPING_PADI},
}

local NAMA = {
	pria = {"Uncle Wang", "Old Zhou", "Brother Liu", "Farmer Sun", "Grandpa Ma", "Woodcutter He", "Fisher Gao", "Brother Tang",
		"Old Feng", "Ferryman Luo", "Carpenter Deng", "Young Pan", "Uncle Xu", "Herder Kong", "Potter Yuan", "Brother Shen",
		"Old Han", "Uncle Bai", "Butcher Niu", "Brother Qin", "Grandpa Tao", "Farmer Yang", "Mason Fu", "Young Jin",
		"Uncle Hou", "Old Shi", "Brother Ren", "Weaver Lu", "Hunter Mo", "Uncle Peng"},
	wanita = {"Auntie Li", "Sister Fang", "Granny Qian", "Little Mei", "Widow Zhao", "Sister Ning", "Auntie Hu",
		"Weaver Lan", "Auntie Song", "Little Yu", "Granny Lin", "Sister Cui", "Auntie Jiang", "Washer Wu",
		"Auntie Guo", "Sister Rong", "Granny Ye", "Auntie Xie", "Sister Hua", "Widow Tian", "Auntie Ma",
		"Sister Jing", "Granny Pei", "Auntie Lou", "Sister Ying", "Auntie Ding", "Granny Shao", "Sister Qiu"},
}

local OBROLAN = {
	"The Lanyun Sect tests spirit roots again this spring. My son can't sleep.",
	"Mind the stone bridge. The carvings are older than the village.",
	"Rice is cheap this year. Heaven is kind, for now.",
	"They say cultivators ride flying swords. I just want my back to stop aching.",
	"Have you seen the Xue clan carriages on the road? Nothing good follows them.",
	"The river ran warm last night. Grandmother calls it an omen.",
	"Don't walk the mountain paths after dark. The beasts there have qi.",
	"Shiqiao is small, but nobody here goes hungry.",
	"An immortal passed through once, before I was born. The old folks still talk about it.",
	"The willows by the river were planted by the first families of Shiqiao.",
}
local PEDAGANG = {
	Penginapan = {"Rooms by the river, warm rice wine. Rest a while, traveller.", "Stone Bridge Inn, best beds this side of the mountains."},
	Beras = {"Fresh rice from the terraces! Cheaper than in Hongcheng.", "Chen's rice, milled this morning."},
	Obat = {"Herbs for wounds, herbs for chills. Cultivators buy my spirit grass too.", "Spring Return Pharmacy. Don't train until you bleed, child."},
	Besi = {"Hoes, sickles, kitchen knives. A sword? Not for a village smith.", "Zhang's forge never cools."},
	Teh = {"Clear Wind tea, three coppers a cup!", "Sit, drink. The mountain mist tastes better with tea."},
	Toko = {"Rope, lamps, sandals, a bit of everything.", "Honest goods, honest price."},
}
local SAPA = {"Good day.", "Safe travels.", "Fine weather today.", "Hm? Oh, hello."}

local RUMAH = {
	"Mind your step, the stones are slick after rain.",
	"My husband is out in the paddies until dusk.",
	"Come back at supper, there'll be congee.",
	"This house has stood since my grandfather's day.",
	"The roof leaks every spring. Every spring!",
}
local MANCING = {
	"Shh. You'll scare the carp.",
	"The river gives, if you're patient.",
	"Caught a fish with golden scales once. Nobody believes me.",
	"Best spot in Shiqiao, right here.",
}
local NAMA_ANAK = {"Little Bao", "Little Hu", "Little Lan", "Little Shun"}
local ANAK = {
	"Catch me if you can!",
	"Are you a real cultivator? Can you fly?",
	"Mother says I can't go past the bridge.",
	"I'm going to join the Lanyun Sect one day!",
}

-- ===== pembuatan model =====
local function buatDesc(look)
	local d = Instance.new("HumanoidDescription")
	local kulit = KULIT[math.random(#KULIT)]
	d.HeadColor = kulit
	d.TorsoColor = look.tipe == "wanita" and BAJU_DALAM or kulit
	d.LeftArmColor, d.RightArmColor = kulit, kulit
	local celana = CELANA[math.random(#CELANA)]
	d.LeftLegColor, d.RightLegColor = celana, celana
	local acc = {}
	for i, b in look.baju do
		table.insert(acc, {AssetId = b[1], AccessoryType = b[2], IsLayered = true, Order = i})
	end
	d:SetAccessories(acc, true)
	if look.rambut then d.HairAccessory = tostring(look.rambut) end
	if look.topi then d.HatAccessory = tostring(look.topi) end
	d.HeightScale = look.tipe == "wanita" and 0.95 + math.random() * 0.05 or 1 + math.random() * 0.06
	d.WidthScale = look.tipe == "wanita" and 0.9 or 1
	return d
end

-- ambil nama yang belum dipakai, biar tidak ada lima "Widow Zhao" di satu desa
local namaSisa = {pria = table.clone(NAMA.pria), wanita = table.clone(NAMA.wanita)}
local function namaBaru(tipe)
	local sisa = namaSisa[tipe]
	if #sisa == 0 then return NAMA[tipe][math.random(#NAMA[tipe])] end
	return table.remove(sisa, math.random(#sisa))
end

local function buatWarga(look, nama)
	local ok, m = pcall(function()
		return Players:CreateHumanoidModelFromDescription(buatDesc(look), Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Warga] gagal bikin model:", m)
		return nil
	end
	m.Name = nama or namaBaru(look.tipe)
	local hum = m:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = 6 + math.random() * 2
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	local animate = m:FindFirstChild("Animate")
	if animate then animate:Destroy() end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then p.CollisionGroup = GRUP end
	end
	m:SetAttribute("Warga", true)
	return m
end

local function animasi(m, jalanPakaiLari)
	local hum = m:FindFirstChildOfClass("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local t = {}
	for k, id in ANIM do
		local a = Instance.new("Animation")
		a.AnimationId = id
		t[k] = animator:LoadAnimation(a)
	end
	t.idle.Looped = true
	t.walk.Looped = true
	t.run.Looped = true
	t.sit.Looped = true
	t.sit.Priority = Enum.AnimationPriority.Action
	t.idle:Play()
	local gerak = jalanPakaiLari and t.run or t.walk
	hum.Running:Connect(function(speed)
		if speed > 0.5 then
			if not gerak.IsPlaying then gerak:Play(0.2) end
			gerak:AdjustSpeed(jalanPakaiLari and speed / 16 or speed / 8)
		elseif gerak.IsPlaying then
			gerak:Stop(0.25)
		end
	end)
	return t
end

-- ===== gelembung omongan =====
local function bilang(m, teks, lama)
	local head = m:FindFirstChild("Head")
	if not head then return end
	local old = head:FindFirstChild("Omongan")
	if old then old:Destroy() end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Omongan"
	bb.Size = UDim2.fromOffset(240, 60)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 45
	bb.LightInfluence = 0
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(245, 236, 214)
	lbl.BackgroundTransparency = 0.08
	lbl.TextColor3 = Color3.fromRGB(46, 32, 22)
	lbl.Font = Enum.Font.Merriweather
	lbl.TextScaled = true
	lbl.TextWrapped = true
	lbl.Text = teks
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 10)
	local pad = Instance.new("UIPadding", lbl)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	local tc = Instance.new("UITextSizeConstraint", lbl)
	tc.MaxTextSize = 18
	lbl.Parent = bb
	bb.Parent = head
	task.delay(lama or 4, function()
		if bb.Parent then bb:Destroy() end
	end)
end

local function hadap(m, pos)
	local root = m:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local p = root.Position
	local tgt = Vector3.new(pos.X, p.Y, pos.Z)
	if (tgt - p).Magnitude > 0.1 then root.CFrame = CFrame.lookAt(p, tgt) end
end

local function pemainDekat(pos, jarak)
	for _, plr in Players:GetPlayers() do
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - pos).Magnitude < jarak then return hrp end
	end
	return nil
end

local function pasangObrolan(m, lines, sibuk)
	local root = m:FindFirstChild("HumanoidRootPart")
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Talk"
	pp.ObjectText = m.Name
	pp.MaxActivationDistance = 9
	pp.HoldDuration = 0
	pp.RequiresLineOfSight = false
	pp.Parent = root
	pp.Triggered:Connect(function(plr)
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if sibuk then sibuk.sampai = os.clock() + 5 end
		local hum = m:FindFirstChildOfClass("Humanoid")
		-- yang di-anchor (duduk / diam) cukup noleh kalau tidak sedang duduk
		if hrp and hum and not m:GetAttribute("Duduk") then
			if not root.Anchored then hum:MoveTo(root.Position) end
			hadap(m, hrp.Position)
		end
		Dialog:FireClient(plr, m.Name, lines[math.random(#lines)])
	end)
	-- sapa pemain yang lewat dekat
	task.spawn(function()
		local terakhir = 0
		while m.Parent do
			task.wait(2 + math.random() * 2)
			if os.clock() - terakhir > 25 and root.Parent and pemainDekat(root.Position, 16) then
				bilang(m, math.random() < 0.5 and SAPA[math.random(#SAPA)] or lines[math.random(#lines)], 4)
				terakhir = os.clock()
			end
		end
	end)
end

-- cf = titik di tanah (kaki), menghadap arah LookVector-nya
local function letakkan(m, cf, anchor)
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart")
	m:PivotTo(cf + Vector3.new(0, hum.HipHeight + root.Size.Y / 2 + 0.05, 0))
	-- Atomic: model dikirim utuh ke client (kalau tidak, badannya bisa belum ke-stream)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	root.Anchored = anchor == true
	m.Parent = folderWarga
	if not root.Anchored then root:SetNetworkOwner(nil) end
end

-- ===== peran =====
local semuaJalan = {}
for _, p in titik:GetChildren() do
	if p:GetAttribute("Peran") == "Jalan" then table.insert(semuaJalan, p) end
end

local function tanah(p)
	return p.CFrame - Vector3.new(0, p.Size.Y / 2, 0)
end

-- titik rumah tersebar rata: pilih titik yang paling jauh dari yang sudah dipilih
local function sebarRata(jumlah)
	local hasil = {}
	if #semuaJalan == 0 then return hasil end
	table.insert(hasil, semuaJalan[math.random(#semuaJalan)])
	while #hasil < jumlah do
		local terbaik, jarakTerbaik = nil, -1
		for _, p in semuaJalan do
			local dMin = math.huge
			for _, q in hasil do dMin = math.min(dMin, (p.Position - q.Position).Magnitude) end
			if dMin > jarakTerbaik then terbaik, jarakTerbaik = p, dMin end
		end
		if jarakTerbaik <= 0 then
			table.insert(hasil, semuaJalan[math.random(#semuaJalan)])
		else
			table.insert(hasil, terbaik)
		end
	end
	return hasil
end

local function tujuanAcak(dari, rumah, radius)
	local cocok = {}
	for _, p in semuaJalan do
		local d = (p.Position - dari).Magnitude
		if d > 20 and (p.Position - rumah.Position).Magnitude < radius then table.insert(cocok, p) end
	end
	if #cocok >= 2 then return cocok[math.random(#cocok)] end
	-- rumahnya di pinggir desa dan sepi titik: pakai beberapa titik terdekat dari rumah
	-- (dulu balik ke titik rumah sendiri, jadi warganya diam di tempat terus)
	local urut = table.clone(semuaJalan)
	table.sort(urut, function(a, b)
		return (a.Position - rumah.Position).Magnitude < (b.Position - rumah.Position).Magnitude
	end)
	local pilih = {}
	for _, p in urut do
		if (p.Position - dari).Magnitude > 10 then table.insert(pilih, p) end
		if #pilih >= 4 then break end
	end
	return pilih[math.random(#pilih)] or rumah
end

-- jalan ke satu waypoint; false kalau tidak maju-maju (nyangkut)
local function jalanKe(hum, root, pos)
	hum:MoveTo(pos)
	local mulai = os.clock()
	local cek, posCek = os.clock(), root.Position
	while true do
		task.wait(0.25)
		if not root.Parent then return false end
		local flat = (root.Position - pos) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 2.5 then return true end
		if os.clock() - cek > 1.5 then
			if (root.Position - posCek).Magnitude < 0.8 then return false end
			cek, posCek = os.clock(), root.Position
			hum:MoveTo(pos) -- MoveTo habis setelah 8 detik, diulang biar tidak berhenti di tengah jalan
		end
		if os.clock() - mulai > 20 then return false end
	end
end

local function jalanJalan(m, rumah, radius, lines)
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart")
	local sibuk = {sampai = 0}
	pasangObrolan(m, lines, sibuk)
	local path = PFS:CreatePath({AgentRadius = 1.5, AgentHeight = 5.5, AgentCanJump = false, WaypointSpacing = 5,
		Costs = {Water = math.huge}})
	local gagal = 0
	while m.Parent do
		local tujuan = tujuanAcak(root.Position, rumah, radius)
		-- titik awal harus dekat tanah, kalau dari tinggi pinggang jalurnya sering gagal
		local kaki = root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2 - 1, 0)
		local ok = pcall(function() path:ComputeAsync(kaki, tujuan.Position + Vector3.new(0, 0.5, 0)) end)
		local sampai = false
		if ok and path.Status == Enum.PathStatus.Success then
			sampai = true
			for _, wp in path:GetWaypoints() do
				while os.clock() < sibuk.sampai do task.wait(0.5) end
				if not m.Parent then return end
				if not jalanKe(hum, root, wp.Position) then
					sampai = false
					break
				end
			end
		end
		if sampai then
			gagal = 0
			task.wait(3 + math.random() * 7)
		else
			gagal += 1
			hum:MoveTo(root.Position)
			-- nyangkut terus: pindah diam-diam ke titik jalan dekat rumah (kalau tidak ada pemain yang lihat)
			if gagal >= 3 and not pemainDekat(root.Position, 70) then
				local ke = tujuanAcak(rumah.Position, rumah, radius)
				if not pemainDekat(ke.Position, 70) then
					root.CFrame = CFrame.new(tanah(ke).Position + Vector3.new(0, hum.HipHeight + root.Size.Y / 2 + 0.05, 0))
					gagal = 0
				end
			end
			task.wait(1 + math.random())
		end
	end
end

local function lookAcak(tipe)
	local pilih = {}
	for _, l in LOOKS do
		if not tipe or l.tipe == tipe then table.insert(pilih, l) end
	end
	return pilih[math.random(#pilih)]
end

local function diam(p, lines, look)
	local m = buatWarga(look or lookAcak())
	if not m then return end
	letakkan(m, tanah(p), true)
	-- animasi dimuat setelah model masuk workspace; kalau sebelumnya, ada yang ke-replikasi T-pose
	animasi(m)
	pasangObrolan(m, lines)
end

local function duduk(p)
	local m = buatWarga(lookAcak())
	if not m then return end
	-- pinggul di permukaan bangku: root turun dari posisi berdiri
	local root = m.HumanoidRootPart
	m:PivotTo(p.CFrame + Vector3.new(0, p.Size.Y / 2 + root.Size.Y / 2 + 0.35, 0))
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	root.Anchored = true
	m:SetAttribute("Duduk", true)
	m.Parent = folderWarga
	local t = animasi(m)
	t.idle:Stop()
	t.sit:Play()
	pasangObrolan(m, OBROLAN)
end

local function ngobrol(p)
	local a, b = buatWarga(lookAcak("pria")), buatWarga(lookAcak("wanita"))
	if not (a and b) then return end
	local c = tanah(p)
	local kanan = c.RightVector * 1.9
	letakkan(a, CFrame.lookAt(c.Position - kanan, c.Position + kanan), true)
	letakkan(b, CFrame.lookAt(c.Position + kanan, c.Position - kanan), true)
	animasi(a)
	animasi(b)
	pasangObrolan(a, OBROLAN)
	pasangObrolan(b, OBROLAN)
	while a.Parent and b.Parent do
		task.wait(6 + math.random() * 6)
		local w = math.random() < 0.5 and a or b
		bilang(w, OBROLAN[math.random(#OBROLAN)], 5)
	end
end

-- ===== mulai =====
folderWarga.Parent = desa

for _, p in titik:GetChildren() do
	local peran = p:GetAttribute("Peran")
	if peran == "Pedagang" then
		task.spawn(diam, p, PEDAGANG[p:GetAttribute("Toko")] or PEDAGANG.Toko)
	elseif peran == "Duduk" then
		task.spawn(duduk, p)
	elseif peran == "Ngobrol" then
		task.spawn(ngobrol, p)
	elseif peran == "Diam" then
		local gaya = p:GetAttribute("Gaya")
		if gaya == "Mancing" then
			task.spawn(diam, p, MANCING, lookAcak("pria"))
		else
			task.spawn(diam, p, RUMAH)
		end
	end
end

if #semuaJalan >= 2 then
	local rumah = sebarRata(JUMLAH_JALAN + JUMLAH_ANAK)
	-- diacak biar anak-anak tidak selalu dapat titik paling pinggir
	for i = #rumah, 2, -1 do local j = math.random(i) rumah[i], rumah[j] = rumah[j], rumah[i] end
	for i = 1, JUMLAH_JALAN + JUMLAH_ANAK do
		task.spawn(function()
			task.wait(i * 0.3)
			local anak = i > JUMLAH_JALAN
			local namaAnak = anak and (NAMA_ANAK[i - JUMLAH_JALAN] or "Little Tao") or nil
			local m = buatWarga(lookAcak(), namaAnak)
			if not m then return end
			if anak then
				m:ScaleTo(0.72)
				m.Humanoid.WalkSpeed = 11 + math.random() * 3
			end
			letakkan(m, CFrame.new(tanah(rumah[i]).Position) * CFrame.Angles(0, math.random() * 6.28, 0))
			animasi(m, anak)
			jalanJalan(m, rumah[i], anak and 60 or RADIUS_JALAN, anak and ANAK or OBROLAN)
		end)
	end
end
