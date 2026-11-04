local plr = game.Players.LocalPlayer
local t0 = os.clock()
repeat task.wait(0.2) until plr:GetAttribute("Loaded") or os.clock() - t0 > 40
local stall = workspace:WaitForChild("Map"):WaitForChild("ElliotStall", 30)
local elliot = stall:WaitForChild("Elliot", 30)
local head = elliot:WaitForChild("Head")
task.wait(3)
game:GetService("ProximityPromptService").Enabled = false
local cam = workspace.CurrentCamera
local f = head.CFrame
local pos = f.Position + f.LookVector * 11 + f.RightVector * 7 + Vector3.new(0, 1.5, 0)
local target = f.Position + f.RightVector * 2.5 + Vector3.new(0, -0.5, 0)
print("PHASE stall", head.Position)
local t = os.clock()
while os.clock() - t < 12 do
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(pos, target)
	task.wait()
end
