local plr = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local t0 = os.clock()
repeat task.wait(0.2) until plr:GetAttribute("Loaded") or os.clock() - t0 > 40
task.wait(3)
local cam = workspace.CurrentCamera
local v = cam.ViewportSize
local c = v / 2
print("viewport", v, "mouseBehavior", UIS.MouseBehavior, "iconEnabled", UIS.MouseIconEnabled)
local objs = plr.PlayerGui:GetGuiObjectsAtPosition(c.X, c.Y - 36)
for _, o in objs do
	print("AT CENTER:", o:GetFullName(), o.ClassName, o.AbsoluteSize, o.Visible)
end
for _, g in plr.PlayerGui:GetChildren() do
	print("gui", g.Name, g.ClassName)
end
