local plr = game.Players.LocalPlayer
local SS = game:GetService("SoundService")
local t0 = os.clock()
repeat task.wait(0.2) until plr:GetAttribute("Loaded") or os.clock() - t0 > 40
local C = plr.PlayerScripts:WaitForChild("Client")
local Ctx = require(C.Ctx)
local function playing(tag)
	task.wait(3)
	local t = {}
	for _, s in SS:GetChildren() do
		if s:IsA("Sound") and s.IsPlaying and s.Volume > 0.01 then
			table.insert(t, string.format("%s(%.2f,loaded=%s)", s.Name, s.Volume, tostring(s.IsLoaded)))
		end
	end
	print("AUDIO " .. tag .. ": " .. table.concat(t, " "))
end
playing("start")
Ctx.Request("AdminBiome", "DataStorm")
playing("datastorm")
Ctx.Request("AdminBiome", "Normal")
Ctx.Request("AdminWear", "Kernel")
playing("kernel aura")
Ctx.Request("AdminWear", "")
playing("aura off")
