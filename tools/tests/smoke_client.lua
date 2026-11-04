local plr = game.Players.LocalPlayer
local t0 = os.clock()
repeat task.wait(0.2) until plr:GetAttribute("Loaded") or os.clock() - t0 > 40
local C = plr.PlayerScripts:WaitForChild("Client")
local Ctx = require(C.Ctx)
local Config = require(game.ReplicatedStorage.Shared.Config)
local cam = workspace.CurrentCamera
local function mark(s) print("PHASE " .. s .. " @" .. string.format("%.1f", workspace.DistributedGameTime)) end
local function hrp() return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") end
mark("hud")
task.wait(4)
mark("rolls")
local Roller = require(C.Roller)
for i = 1, 3 do print("roll", i, Roller.Roll(), Ctx.Data.Rolls) end
local function wide()
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 40, 95), Vector3.new(0, 15, -40))
end
for _, b in { "DataStorm", "Blackout", "KernelPanic", "Overclock" } do
	Ctx.Request("DebugBiome", b)
	mark("biome " .. b)
	wide()
	task.wait(5)
end
Ctx.Request("DebugBiome", "Normal")
cam.CameraType = Enum.CameraType.Custom
mark("cutscene Kernel")
require(C.Cutscene).Play(Config.AuraById.Kernel, { first = true })
mark("cutscene done")
for _, id in { "Glitch", "CyberSeraph", "Singularity", "Redacted" } do
	Ctx.Request("DebugGive", { id = id, n = 1 })
	print("equip", id, Ctx.Request("Equip", id))
	task.wait(0.6)
	local r = hrp()
	if r then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(r.Position + r.CFrame.LookVector * 14 + Vector3.new(0, 3, 0), r.Position + Vector3.new(0, 1, 0))
	end
	mark("aura " .. id)
	task.wait(4)
end
cam.CameraType = Enum.CameraType.Custom
for _, w in { "Inventory", "Index", "Forge" } do
	Ctx.Open(w)
	mark("window " .. w)
	task.wait(3)
end
mark("end")
