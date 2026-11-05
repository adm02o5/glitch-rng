-- Idle 2.5 s then walk 3.5 s for each aura in LIST; side camera; label on screen.
local plr = game.Players.LocalPlayer
local t0 = os.clock()
repeat task.wait(0.2) until plr:GetAttribute("Loaded") or os.clock() - t0 > 40
local C = plr.PlayerScripts:WaitForChild("Client")
local Ctx = require(C.Ctx)
-- The tutorial auto-starts (Studio doesn't save Settings.Tut); mark it done and stop it.
Ctx.Setting("Tut", true)
task.wait(2.5)
pcall(function() require(C.Tutorial).Skip() end)
task.wait(0.3)
pcall(function() require(C.Tutorial).Skip() end)
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
print("RIG", hum.RigType)
local gui = Instance.new("ScreenGui") gui.DisplayOrder = 100 gui.Parent = plr.PlayerGui
local tag = Instance.new("TextLabel") tag.Size = UDim2.fromOffset(700, 60) tag.Position = UDim2.fromOffset(30, 30)
tag.BackgroundTransparency = 1 tag.TextColor3 = Color3.new(1, 1, 0) tag.TextSize = 40 tag.Font = Enum.Font.Code
tag.TextXAlignment = Enum.TextXAlignment.Left tag.Parent = gui
local cam = workspace.CurrentCamera
local LIST = LIST or { "Pixel", "WiFi", "Captcha", "Debug", "Glitch", "Synthwave", "Mainframe", "CyberSeraph", "KernelPanic" }
for _, id in LIST do
	hrp.CFrame = CFrame.new(-20, 4, 40)
	task.wait(0.3)
	Ctx.Request("AdminWear", id)
	tag.Text = id .. " idle"
	local t = os.clock()
	while os.clock() - t < 2.5 do
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(9, 2, 4), hrp.Position + Vector3.new(0, 0.5, 0))
		task.wait()
	end
	tag.Text = id .. " walk"
	t = os.clock()
	while os.clock() - t < 3.5 do
		hum:Move(Vector3.new(1, 0, 0), false)
		cam.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(4, 2, 10), hrp.Position + Vector3.new(0, 0.5, 0))
		task.wait()
	end
	hum:Move(Vector3.zero, false)
	print("AURA", id)
end
print("ANIM DONE")
