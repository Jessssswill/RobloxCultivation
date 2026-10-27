-- MountCamFX: kamera bergetar saat memanggil kuda / pedang (makin kuat) & saat naik (hentakan), setara wujud iblis.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer
local function shake(dur, amp, rising)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if not hum then break end
			local a = (os.clock() - t0) / dur
			local k = rising and a or (1 - a)
			hum.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * amp * k
			RunService.RenderStepped:Wait()
		end
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum and not plr:GetAttribute("DemonForm") then hum.CameraOffset = Vector3.zero end
	end)
end
for _, a in {"SteedCalling", "SwordCalling"} do
	plr:GetAttributeChangedSignal(a):Connect(function()
		if plr:GetAttribute(a) then shake(1.6, 0.7, true) end
	end)
end
for _, a in {"Mounted", "SwordRiding"} do
	plr:GetAttributeChangedSignal(a):Connect(function()
		if plr:GetAttribute(a) then shake(0.6, 1.8, false) end
	end)
end
