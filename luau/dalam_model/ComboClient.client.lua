-- Combo 4 hit. Animasi dari KeyframeSequence di ReplicatedStorage.QiAnims.
-- RegisterKeyframeSequence cuma jalan di Studio. Buat game asli, animasinya di-upload dulu lalu pakai AnimationId.
local tool = script.Parent
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local KSP = game:GetService("KeyframeSequenceProvider")
local player = Players.LocalPlayer
local remote = tool:WaitForChild("Hit")
local trail = tool:WaitForChild("Blade"):WaitForChild("QiTrail")

local tracks, loadedFor = {}, nil
local busy, queued, step, lastEnd = false, false, 0, 0

local function loadTracks(char)
	if loadedFor == char then return end
	loadedFor = char
	local animator = char:WaitForChild("Humanoid"):WaitForChild("Animator")
	for i = 1, 4 do
		local anim = Instance.new("Animation")
		anim.AnimationId = KSP:RegisterKeyframeSequence(RS:WaitForChild("QiAnims")["Slash" .. i])
		local tr = animator:LoadAnimation(anim)
		tr.Priority = Enum.AnimationPriority.Action4
		tr:GetMarkerReachedSignal("TrailOn"):Connect(function() trail.Enabled = true end)
		tr:GetMarkerReachedSignal("Hit"):Connect(function() remote:FireServer(i) end)
		tr:GetMarkerReachedSignal("TrailOff"):Connect(function() trail.Enabled = false end)
		tr.Stopped:Connect(function() trail.Enabled = false end)
		tracks[i] = tr
	end
end

tool.Equipped:Connect(function() loadTracks(tool.Parent) end)
tool.Unequipped:Connect(function()
	for _, tr in tracks do tr:Stop() end
	trail.Enabled = false
	queued = false
end)

local function blocked()
	return player:GetAttribute("Meditating") or player:GetAttribute("Flying") or player:GetAttribute("Casting")
end

local function attack()
	if not tracks[1] or blocked() then return end
	busy = true
	if os.clock() - lastEnd > 0.9 then step = 0 end
	step = step % 4 + 1
	local tr = tracks[step]
	tr:Play(0.05)
	-- boleh lanjut combo sedikit sebelum animasi selesai biar terasa responsif
	task.wait(math.max(tr.Length - (step == 4 and 0.2 or 0.17), 0.2))
	lastEnd = os.clock()
	busy = false
	if queued then
		queued = false
		attack()
	end
end

tool.Activated:Connect(function()
	if busy then
		queued = true
		return
	end
	attack()
end)
