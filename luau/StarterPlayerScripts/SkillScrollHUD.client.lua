-- LocalScript: StarterPlayer.StarterPlayerScripts.SkillScrollHUD
-- Khusus PC/laptop: tombol skill dipindah ke gulungan (scroll) di pojok kanan bawah yang bisa dibuka-tutup,
-- biar layar gak numpuk. Klik gulungannya atau tekan K. Di HP/tablet tampilan lama tetap dipakai.
-- v2: tampilan gulungan dibuat sendiri (ubin pernis hitam-emas, cap merah, kertas tua). Slot asli dari
-- QiClient dan WeaponSkillClient tetap jalan tapi disembunyikan; tiap frame isinya (nama, cooldown, terkunci)
-- disalin ke ubin gulungan, jadi script aslinya tidak perlu diubah.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RunS = game:GetService("RunService")

if UIS.TouchEnabled and not UIS.KeyboardEnabled then return end

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local TOGGLE_KEY = Enum.KeyCode.K

local PAPER = Color3.fromRGB(240, 226, 188)
local PAPER_EDGE = Color3.fromRGB(176, 140, 88)
local INK = Color3.fromRGB(46, 28, 18)
local CINNABAR = Color3.fromRGB(170, 36, 28)
local WOOD = Color3.fromRGB(88, 48, 26)
local GOLD = Color3.fromRGB(212, 170, 80)
local GOLD_DIM = Color3.fromRGB(150, 116, 52)
local LACQUER = Color3.fromRGB(36, 22, 16)
local IVORY = Color3.fromRGB(246, 234, 204)

local F_TITLE = Font.new("rbxasset://fonts/families/Fondamento.json")
local F_BODY = Font.new("rbxasset://fonts/families/Merriweather.json")
local F_BODY_B = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)

local W = 320
local PAD = 16

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) make("UICorner", {CornerRadius = r or UDim.new(0, 6)}, o) end
local function grad(o, rot, ...)
	local cols = {...}
	local keys = {}
	for i, c in cols do keys[i] = ColorSequenceKeypoint.new((i - 1) / (#cols - 1), c) end
	return make("UIGradient", {Rotation = rot, Color = ColorSequence.new(keys)}, o)
end
local function text(props, parent)
	local t = make("TextLabel", {BackgroundTransparency = 1, FontFace = F_BODY, TextColor3 = INK, TextSize = 15, ZIndex = 4}, parent)
	for k, v in props do t[k] = v end
	return t
end

local gui = make("ScreenGui", {Name = "SkillScroll", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, pg)
-- tempat slot asli disembunyikan (tetap jalan, cuma tidak digambar)
local stash = make("Frame", {Name = "Stash", Visible = false, Size = UDim2.fromOffset(10, 10)}, gui)

-- wadah di pojok kanan bawah
local root = make("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -18), Size = UDim2.fromOffset(W + 30, 40), BackgroundTransparency = 1}, gui)

-- batang kayu dengan ujung emas
local function rod(parent, pos, anchor)
	local r = make("Frame", {AnchorPoint = anchor, Position = pos, Size = UDim2.new(1, 30, 0, 18), BackgroundColor3 = WOOD, ZIndex = 6}, parent)
	corner(r, UDim.new(1, 0))
	grad(r, 90, Color3.fromRGB(160, 100, 58), WOOD, Color3.fromRGB(40, 20, 10))
	make("UIStroke", {Color = Color3.fromRGB(30, 14, 6), Thickness = 1}, r)
	for _, x in {0, 1} do
		local k = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, 0.5, 0), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = GOLD, ZIndex = 7}, r)
		corner(k, UDim.new(1, 0))
		make("UIStroke", {Color = Color3.fromRGB(104, 72, 20), Thickness = 1.5}, k)
		grad(k, 90, Color3.fromRGB(255, 232, 150), GOLD, Color3.fromRGB(140, 98, 30))
		local ring = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 8}, k)
		corner(ring, UDim.new(1, 0))
		make("UIStroke", {Color = Color3.fromRGB(120, 84, 24), Thickness = 1.5}, ring)
	end
	return r
end

-- kertas yang terbuka ke atas dari batang bawah
local paper = make("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(W, 0), BackgroundColor3 = PAPER, BorderSizePixel = 0, ZIndex = 2}, root)
make("UIStroke", {Color = PAPER_EDGE, Thickness = 1}, paper)
-- pinggir kiri-kanan kertas lebih gelap, kayak kertas tua
grad(paper, 0, Color3.fromRGB(200, 170, 120), Color3.new(1, 1, 1), Color3.new(1, 1, 1), Color3.new(1, 1, 1), Color3.fromRGB(200, 170, 120))
local clip = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2}, paper)
-- bayangan di atas dan bawah kertas (dekat batang)
local shade = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 80, 40), BorderSizePixel = 0, ZIndex = 2}, clip)
make("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.06, 1), NumberSequenceKeypoint.new(0.94, 1), NumberSequenceKeypoint.new(1, 0.55),
})}, shade)
local topRod = rod(paper, UDim2.new(0.5, 0, 0, 0), Vector2.new(0.5, 0.5))
topRod.Visible = false

-- bingkai ganda: merah di luar, emas di dalam, dengan siku merah dan titik emas di keempat pojok
local frameOuter = make("Frame", {Position = UDim2.fromOffset(7, 12), Size = UDim2.new(1, -14, 1, -24), BackgroundTransparency = 1, ZIndex = 3}, clip)
make("UIStroke", {Color = CINNABAR, Thickness = 1.5, Transparency = 0.15}, frameOuter)
local frameInner = make("Frame", {Position = UDim2.fromOffset(11, 16), Size = UDim2.new(1, -22, 1, -32), BackgroundTransparency = 1, ZIndex = 3}, clip)
make("UIStroke", {Color = GOLD_DIM, Thickness = 1, Transparency = 0.3}, frameInner)
for _, c in {{0, 0}, {1, 0}, {0, 1}, {1, 1}} do
	local a = Vector2.new(c[1], c[2])
	make("Frame", {AnchorPoint = a, Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(14, 3), BackgroundColor3 = CINNABAR, BorderSizePixel = 0, ZIndex = 4}, frameOuter)
	make("Frame", {AnchorPoint = a, Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(3, 14), BackgroundColor3 = CINNABAR, BorderSizePixel = 0, ZIndex = 4}, frameOuter)
	make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(c[1], c[1] == 0 and 8 or -8, c[2], c[2] == 0 and 8 or -8), Size = UDim2.fromOffset(5, 5), Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 4}, frameOuter)
end

-- isi gulungan, nempel di bawah supaya kebuka dari bawah ke atas
local content = make("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 3}, clip)
make("UIPadding", {PaddingTop = UDim.new(0, 24), PaddingBottom = UDim.new(0, 22), PaddingLeft = UDim.new(0, PAD), PaddingRight = UDim.new(0, PAD)}, content)
make("UIListLayout", {Padding = UDim.new(0, 7), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, content)

-- judul
local head = make("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 3}, content)
text({Size = UDim2.new(1, 0, 0, 14), Text = "武  學  秘  卷", TextSize = 13, TextColor3 = CINNABAR, FontFace = F_BODY_B}, head)
text({Position = UDim2.fromOffset(0, 13), Size = UDim2.new(1, 0, 0, 30), Text = "Martial Scroll", TextSize = 28, FontFace = F_TITLE}, head)
local seal = make("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 4), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = CINNABAR, Rotation = 8, ZIndex = 4}, head)
corner(seal, UDim.new(0, 3))
make("UIStroke", {Color = Color3.fromRGB(120, 18, 14), Thickness = 1.5}, seal)
local sealIn = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, ZIndex = 5}, seal)
make("UIStroke", {Color = Color3.fromRGB(255, 220, 200), Thickness = 1, Transparency = 0.4}, sealIn)
text({Size = UDim2.fromScale(1, 1), Text = "武", TextColor3 = Color3.fromRGB(255, 238, 222), TextSize = 21, FontFace = F_BODY_B, ZIndex = 6}, seal)

-- garis hias: garis memudar - belah ketupat merah - garis memudar
local function divider(order)
	local f = make("Frame", {Size = UDim2.new(1, 0, 0, 9), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 3}, content)
	for _, side in {0, 1} do
		local l = make("Frame", {AnchorPoint = Vector2.new(side, 0.5), Position = UDim2.fromScale(side, 0.5), Size = UDim2.new(0.5, -10, 0, 1), BackgroundColor3 = GOLD_DIM, BorderSizePixel = 0, ZIndex = 4}, f)
		make("UIGradient", {Rotation = side == 0 and 0 or 180, Transparency = NumberSequence.new(1, 0)}, l)
	end
	make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 7), Rotation = 45, BackgroundColor3 = CINNABAR, BorderSizePixel = 0, ZIndex = 4}, f)
	return f
end
divider(2)

-- judul bagian: "招式  Techniques" di tengah dengan garis di kiri-kanan
local function section(cn, name, order)
	local f = make("Frame", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 3}, content)
	text({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(150, 20), Text = cn .. "  " .. name, TextSize = 16, TextColor3 = CINNABAR, FontFace = F_TITLE}, f)
	for _, side in {0, 1} do
		make("Frame", {AnchorPoint = Vector2.new(side, 0.5), Position = UDim2.fromScale(side, 0.5), Size = UDim2.new(0.5, -78, 0, 1), BackgroundColor3 = CINNABAR, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 4}, f)
	end
	return f
end

-- ===================== ubin skill =====================
-- ubin pernis hitam dengan bingkai emas, cap merah berisi huruf tombol, garis warna elemen di bawah
local function makeTile(parent, w, h, wide)
	local t = make("Frame", {Size = UDim2.fromOffset(w, h), BackgroundColor3 = LACQUER, ZIndex = 4}, parent)
	corner(t, UDim.new(0, 5))
	grad(t, 90, Color3.fromRGB(86, 58, 40), Color3.fromRGB(46, 28, 18), Color3.fromRGB(22, 13, 8))
	local stroke = make("UIStroke", {Color = GOLD, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, t)
	local inner = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, ZIndex = 5}, t)
	corner(inner, UDim.new(0, 3))
	make("UIStroke", {Color = GOLD, Thickness = 1, Transparency = 0.7}, inner)
	local bar = make("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -16, 0, 2), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 6}, t)
	corner(bar, UDim.new(1, 0))
	local cd = make("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 8, Size = UDim2.fromScale(0, 0)}, t)
	corner(cd, UDim.new(0, 5))
	local cdText = text({Size = UDim2.fromScale(1, 1), Text = "", TextSize = 22, FontFace = F_TITLE, TextColor3 = IVORY, TextStrokeTransparency = 0.4, ZIndex = 9}, t)
	local sealF = make("Frame", {Size = UDim2.fromOffset(20, 20), Position = wide and UDim2.new(0, 5, 0.5, -10) or UDim2.fromOffset(-5, -5), Rotation = wide and 0 or -6, BackgroundColor3 = CINNABAR, ZIndex = 10}, t)
	corner(sealF, UDim.new(0, 3))
	make("UIStroke", {Color = Color3.fromRGB(110, 16, 12), Thickness = 1}, sealF)
	local key = text({Size = UDim2.fromScale(1, 1), Text = "", TextSize = 14, FontFace = F_BODY_B, TextColor3 = Color3.fromRGB(255, 240, 225), ZIndex = 11}, sealF)
	local name = text({
		AnchorPoint = wide and Vector2.new(0, 0.5) or Vector2.new(0.5, 0.5),
		Position = wide and UDim2.new(0, 30, 0.5, -1) or UDim2.new(0.5, 0, 0.5, 5),
		Size = wide and UDim2.new(1, -34, 1, -8) or UDim2.new(1, -8, 1, -22),
		Text = "", TextSize = 12, TextScaled = true, TextWrapped = true, FontFace = F_BODY_B, TextColor3 = IVORY,
		TextXAlignment = wide and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, LineHeight = 0.95, ZIndex = 7,
	}, t)
	make("UITextSizeConstraint", {MaxTextSize = 12, MinTextSize = 8}, name)
	local lock = text({Size = UDim2.fromScale(1, 1), Text = "封", TextSize = 34, FontFace = F_BODY_B, TextColor3 = CINNABAR, TextTransparency = 0.35, Rotation = -12, Visible = false, ZIndex = 9}, t)
	local req = text({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -6, 0, 13), BackgroundTransparency = 0, BackgroundColor3 = CINNABAR, Text = "", TextSize = 9, FontFace = F_BODY_B, TextColor3 = IVORY, Visible = false, ZIndex = 10}, t)
	corner(req, UDim.new(0, 2))
	return {frame = t, stroke = stroke, bar = bar, cd = cd, cdText = cdText, seal = sealF, key = key, name = name, lock = lock, req = req}
end

-- skill yang belum terbuka: ubin pucat dengan cap 封 (tersegel) dan pita merah berisi syarat realm
local function setLocked(tile, locked, reqText)
	tile.frame.BackgroundColor3 = locked and Color3.fromRGB(130, 110, 86) or LACQUER
	tile.stroke.Color = locked and GOLD_DIM or GOLD
	tile.name.TextTransparency = locked and 0.45 or 0
	tile.seal.BackgroundColor3 = locked and Color3.fromRGB(120, 90, 80) or CINNABAR
	tile.lock.Visible = locked
	tile.req.Visible = locked
	tile.req.Text = reqText
end

section("招式", "Techniques", 3)
local grid = make("Frame", {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 3}, content)
local gridLayout = make("UIGridLayout", {CellSize = UDim2.fromOffset(62, 64), CellPadding = UDim2.fromOffset(9, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, grid)
make("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5)}, grid)
-- AutomaticSize tidak menghitung UIGridLayout dengan benar, jadi tingginya diatur manual
gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	grid.Size = UDim2.new(1, 0, 0, gridLayout.AbsoluteContentSize.Y + 5)
end)

local weaponHead = section("兵法", "Weapon Arts", 5)
local weaponBox = make("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 6, ZIndex = 3}, content)
make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, weaponBox)
weaponHead.Visible = false
weaponBox.Visible = false

section("心法", "Controls", 7)
local controls = make("Frame", {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, LayoutOrder = 8, ZIndex = 3}, content)
local ctrlLayout = make("UIGridLayout", {CellSize = UDim2.new(0.5, -4, 0, 22), CellPadding = UDim2.fromOffset(8, 3), SortOrder = Enum.SortOrder.LayoutOrder}, controls)
ctrlLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	controls.Size = UDim2.new(1, 0, 0, ctrlLayout.AbsoluteContentSize.Y)
end)

-- "Hold R Block" -> tombol R, "Block (hold)"; "Click Combo" -> tombol M1
local function addControl(line, order)
	local keyName, label = line:match("^(%S+)%s+(.+)$")
	if not keyName then return end
	if keyName == "Hold" then
		local k2, rest = label:match("^(%S+)%s+(.+)$")
		if k2 then keyName, label = k2, rest .. " (hold)" end
	elseif keyName == "Click" then
		keyName = "M1"
	end
	local row = make("Frame", {BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 3}, controls)
	local capW = #keyName > 1 and 28 or 20
	local cap = make("Frame", {Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(capW, 18), BackgroundColor3 = IVORY, ZIndex = 4}, row)
	corner(cap, UDim.new(0, 3))
	make("UIStroke", {Color = CINNABAR, Thickness = 1.2}, cap)
	text({Size = UDim2.fromScale(1, 1), Text = keyName, TextSize = 11, FontFace = F_BODY_B, TextColor3 = CINNABAR, ZIndex = 5}, cap)
	text({Position = UDim2.fromOffset(capW + 6, 0), Size = UDim2.new(1, -(capW + 6), 1, 0), Text = label, TextSize = 12, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4}, row)
end

local function setControls(raw)
	for _, c in controls:GetChildren() do
		if c:IsA("Frame") then c:Destroy() end
	end
	local i = 0
	for part in (raw .. "|"):gmatch("%s*(.-)%s*|") do
		if part ~= "" then
			i += 1
			addControl(part, i)
		end
	end
end

-- batang bawah = tombol buka/tutup
local bottom = make("TextButton", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -30, 0, 26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 8}, root)
rod(bottom, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
local band = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(148, 26), BackgroundColor3 = CINNABAR, ZIndex = 9}, bottom)
corner(band, UDim.new(0, 3))
grad(band, 90, Color3.fromRGB(205, 60, 46), CINNABAR, Color3.fromRGB(120, 22, 16))
make("UIStroke", {Color = GOLD, Thickness = 1.5}, band)
local bandText = text({Size = UDim2.fromScale(1, 1), Text = "Skills", TextSize = 17, FontFace = F_TITLE, TextColor3 = IVORY, ZIndex = 10}, band)
local bandKey = make("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(18, 16), BackgroundColor3 = IVORY, ZIndex = 10}, band)
corner(bandKey, UDim.new(0, 3))
text({Size = UDim2.fromScale(1, 1), Text = "K", TextSize = 11, FontFace = F_BODY_B, TextColor3 = CINNABAR, ZIndex = 11}, bandKey)
-- rumbai merah di ujung kanan
local tassel = make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, 15, 0.5, 10), Size = UDim2.fromOffset(4, 20), BackgroundColor3 = CINNABAR, BorderSizePixel = 0, ZIndex = 7}, bottom)
local knot = make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = CINNABAR, Rotation = 45, ZIndex = 7}, tassel)
corner(knot, UDim.new(0, 2))

-- hover: pita sedikit membesar
bottom.MouseEnter:Connect(function() TS:Create(band, TweenInfo.new(0.12), {Size = UDim2.fromOffset(156, 28)}):Play() end)
bottom.MouseLeave:Connect(function() TS:Create(band, TweenInfo.new(0.12), {Size = UDim2.fromOffset(148, 26)}):Play() end)

-- ===================== buka / tutup =====================
local open = false
local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function openHeight()
	return content.AbsoluteSize.Y + 4
end

local function setOpen(v)
	open = v
	bandText.Text = v and "Close" or "Skills"
	if v then
		topRod.Visible = true
		TS:Create(paper, tweenInfo, {Size = UDim2.fromOffset(W, openHeight())}):Play()
	else
		local tw = TS:Create(paper, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.fromOffset(W, 0)})
		tw.Completed:Connect(function()
			if not open then topRod.Visible = false end
		end)
		tw:Play()
	end
end

bottom.MouseButton1Click:Connect(function() setOpen(not open) end)
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == TOGGLE_KEY then setOpen(not open) end
end)
-- tinggi ikut berubah kalau isi berubah (misalnya pedang ber-skill dilepas)
content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	-- pakai tween baru supaya tween buka yang masih jalan tidak menimpa tinggi yang baru
	if open then TS:Create(paper, TweenInfo.new(0.15), {Size = UDim2.fromOffset(W, openHeight())}):Play() end
end)

-- ===================== salin isi slot asli ke ubin =====================
local mirrors = {}
local weaponBar = nil

local function isSlot(f)
	return f:IsA("Frame") and f.Size.X.Offset == 64 and f.Size.Y.Offset == 64
end

-- bagian-bagian slot QiClient: huruf tombol (lebar 18), nama (tinggi 26), tirai cooldown (Frame), angka cooldown,
-- dan tirai terkunci (label berlatar) yang tampil kalau realm belum cukup
local function qiParts(s)
	local p = {cdTexts = {}}
	for _, c in s:GetChildren() do
		if c:IsA("UIStroke") then p.stroke = c
		elseif c:IsA("Frame") then p.cd = p.cd or c
		elseif c:IsA("TextLabel") then
			if c.Size.X.Offset == 18 then p.key = c
			elseif c.Size.Y.Offset == 26 then p.name = c
			elseif c.BackgroundTransparency < 1 then p.lockLabel = c -- tirai "terkunci" berisi syarat realm
			else table.insert(p.cdTexts, c) end
		end
	end
	return p
end

local function adoptQiHUD(hud)
	local found = {}
	for _, d in hud:GetDescendants() do
		if d:IsA("TextLabel") and d.Text:find("Click Combo", 1, true) then
			setControls(d.Text)
			d.Visible = false
		end
	end
	for _, f in hud:GetChildren() do
		if f:IsA("Frame") and f:FindFirstChildOfClass("UIListLayout") then
			local slots = {}
			for _, c in f:GetChildren() do
				if isSlot(c) then table.insert(slots, c) end
			end
			if #slots >= 4 then
				table.sort(slots, function(a, b) return a.AbsolutePosition.X < b.AbsolutePosition.X end)
				for _, s in slots do table.insert(found, s) end
				f.Visible = false
			end
		end
	end
	for i, s in found do
		local tile = makeTile(grid, 62, 64, false)
		tile.frame.LayoutOrder = i
		table.insert(mirrors, {kind = "qi", src = s, parts = qiParts(s), tile = tile})
	end
	return #found > 0
end

-- bagian-bagian slot WeaponSkillClient: huruf tombol (lebar 22), nama, tirai cooldown (Frame)
local function adoptWeaponHUD(hud)
	local bar = hud:FindFirstChild("WeaponSkills")
	if not bar then return false end
	bar.Parent = stash
	weaponBar = bar
	local i = 0
	for _, c in bar:GetChildren() do
		if c:IsA("Frame") then
			i += 1
			local p = {cdTexts = {}}
			for _, d in c:GetChildren() do
				if d:IsA("UIStroke") then p.stroke = d
				elseif d:IsA("Frame") then p.cd = d
				elseif d:IsA("TextLabel") then
					if d.Size.X.Offset == 22 then p.key = d else p.name = d end
				end
			end
			local tile = makeTile(weaponBox, 92, 42, true)
			tile.frame.LayoutOrder = c.LayoutOrder
			table.insert(mirrors, {kind = "weapon", src = c, parts = p, tile = tile})
		end
	end
	return i > 0
end

RunS.RenderStepped:Connect(function()
	if weaponBar then
		local v = weaponBar.Visible
		weaponHead.Visible = v
		weaponBox.Visible = v
	end
	if not open then return end
	for _, m in mirrors do
		local p, t = m.parts, m.tile
		if p.key then t.key.Text = p.key.Text end
		if p.name then
			t.name.RichText = p.name.RichText
			t.name.Text = p.name.Text
		end
		t.bar.BackgroundColor3 = p.stroke and p.stroke.Color or GOLD
		if p.cd then
			t.cd.AnchorPoint = p.cd.AnchorPoint
			t.cd.Position = p.cd.Position
			t.cd.Size = p.cd.Size
			t.cd.Visible = p.cd.Visible
		end
		local num = ""
		for _, l in p.cdTexts do
			if l.Visible and l.Text:match("^%s*%d") then num = l.Text break end
		end
		t.cdText.Text = num
		if m.kind == "qi" then
			local L = p.lockLabel
			setLocked(t, L ~= nil and L.Visible, L and (L.Text:gsub("\n", " ")) or "")
		end
	end
end)

task.spawn(function()
	local qi = pg:WaitForChild("QiHUD", 30)
	if qi then
		for _ = 1, 20 do
			if adoptQiHUD(qi) then break end
			task.wait(0.25)
		end
	end
end)
task.spawn(function()
	local w = pg:WaitForChild("WeaponSkillHUD", 30)
	if w then
		for _ = 1, 20 do
			if adoptWeaponHUD(w) then break end
			task.wait(0.25)
		end
	end
end)
