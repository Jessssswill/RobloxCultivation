local f = workspace:WaitForChild("HeavenPalace", 60)
f = f and f:WaitForChild("CloudSea", 30)
f = f and f:WaitForChild("CloudEmitters", 30)
if not f then return end
task.wait(2)
for _, a in f:GetChildren() do
	local pe = a:FindFirstChildOfClass("ParticleEmitter")
	if pe then pe:Emit(6) end
end
