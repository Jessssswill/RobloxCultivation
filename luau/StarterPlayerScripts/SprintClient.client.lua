-- Lari: tahan Shift (PC), L3 (gamepad), atau tombol Run (HP)
local Players = game:GetService("Players")
local CAS = game:GetService("ContextActionService")
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Sprint = RS:WaitForChild("QiRemotes"):WaitForChild("Sprint")
local FOV_BOOST = 8
local running = false
local baseFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70

local function fov(on)
	local cam = workspace.CurrentCamera
	if cam then
		TS:Create(cam, TweenInfo.new(0.25), { FieldOfView = on and baseFov + FOV_BOOST or baseFov }):Play()
	end
end

local function set(on)
	if on == running then return end
	running = on
	Sprint:FireServer(on)
	fov(on)
end

CAS:BindAction("QiSprint", function(_, state)
	if state == Enum.UserInputState.Begin then
		set(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		set(false)
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
CAS:SetTitle("QiSprint", "Run")

player.CharacterAdded:Connect(function()
	running = false
	fov(false)
end)
