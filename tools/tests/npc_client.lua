local plr = game.Players.LocalPlayer
local t0 = os.clock()
repeat task.wait(0.2) until plr:GetAttribute("Loaded") or os.clock() - t0 > 40
local C = plr.PlayerScripts:WaitForChild("Client")
local Ctx = require(C.Ctx)
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
print("rig", hum.RigType, "tag", char:FindFirstChild("AuraTag") ~= nil, "plist", plr.PlayerGui.GlitchUI:FindFirstChild("PlayerList") ~= nil)
local stall = workspace:WaitForChild("Map"):WaitForChild("ElliotStall", 20)
local elliot = stall and stall:WaitForChild("Elliot", 20)
print("elliot", elliot ~= nil, elliot and elliot:FindFirstChildOfClass("Humanoid") and elliot:FindFirstChildOfClass("Humanoid").RigType)
local cam = workspace.CurrentCamera
-- look at the stall
if elliot then
	local hrp = elliot:FindFirstChild("HumanoidRootPart")
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(hrp.Position + hrp.CFrame.LookVector * 16 + Vector3.new(0, 4, 0), hrp.Position + Vector3.new(0, 1, 0))
	print("PHASE stall")
	task.wait(4)
	char:PivotTo(hrp.CFrame * CFrame.new(0, 0, -7) * CFrame.Angles(0, math.pi, 0))
end
Ctx.Open("Elliot")
print("PHASE elliot window")
task.wait(4)
print("quest", Ctx.Data.Quest and Ctx.Data.Quest.i, Ctx.Data.Quest and Ctx.Data.Quest.n, "bits", Ctx.Data.Bits)
Ctx.Windows.Elliot:Close()
-- bench sit test: find a seat and drop onto it
local seat
for _, d in workspace.Map:GetDescendants() do
	if d:IsA("Seat") then seat = d break end
end
if seat then
	char:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	task.wait(1.5)
	print("sitting", hum.Sit, hum.SeatPart and hum.SeatPart.Name)
	cam.CFrame = CFrame.lookAt(seat.Position + seat.CFrame.LookVector * 12 + Vector3.new(0, 4, 0), seat.Position)
	print("PHASE bench")
	task.wait(3)
	hum.Jump = true
end
cam.CameraType = Enum.CameraType.Custom
local Roller = require(C.Roller)
for i = 1, 2 do Roller.Roll() end
print("after rolls bits", Ctx.Data.Bits, "quest n", Ctx.Data.Quest.n)
print("PHASE tab")
task.wait(3)
