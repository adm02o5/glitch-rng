-- Runs the tutorial end to end; MOBILE global (set before this script) forces the phone layout.
local plr = game.Players.LocalPlayer
if MOBILE then plr:SetAttribute("ForceMobile", true) end
local t0 = os.clock()
repeat task.wait(0.2) until plr:GetAttribute("Loaded") or os.clock() - t0 > 40
local C = plr.PlayerScripts:WaitForChild("Client")
local Tutorial = require(C.Tutorial)
local Roller = require(C.Roller)
local Ctx = require(C.Ctx)
task.wait(3)
if not Tutorial.Running then task.spawn(Tutorial.Start) end
local last, since = -1, os.clock()
local rolls0 = Ctx.Data.Rolls or 0
while Tutorial.Running and os.clock() - t0 < 140 do
	if Tutorial.Step ~= last then
		print("STEP", Tutorial.Step)
		last, since = Tutorial.Step, os.clock()
	end
	if os.clock() - since > 3.2 then
		if (Ctx.Data.Rolls or 0) == rolls0 then
			task.spawn(Roller.Roll)
		end
		Tutorial.Next()
		since = os.clock()
	end
	task.wait(0.2)
end
local cam = workspace.CurrentCamera
print("DONE running", Tutorial.Running, "cam", cam.CameraType, "tut", Ctx.Data.Settings and Ctx.Data.Settings.Tut, "busy", Ctx.Busy)
