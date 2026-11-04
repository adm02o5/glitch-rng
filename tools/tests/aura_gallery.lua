-- Shows every aura in turn on the local character, front close-up, with its name on screen.
-- Optional global filter: set ONLY = { "Glitch", ... } at the top to shoot a subset.
local plr = game.Players.LocalPlayer
local t0 = os.clock()
repeat task.wait(0.2) until plr:GetAttribute("Loaded") or os.clock() - t0 > 40
local C = plr.PlayerScripts:WaitForChild("Client")
local Ctx = require(C.Ctx)
local Config = require(game.ReplicatedStorage.Shared.Config)
local cam = workspace.CurrentCamera
local hud = plr.PlayerGui:FindFirstChild("GlitchUI")
if hud then hud.Enabled = false end
local gui = Instance.new("ScreenGui")
gui.DisplayOrder = 100
gui.Parent = plr.PlayerGui
local tag = Instance.new("TextLabel")
tag.Size = UDim2.fromOffset(700, 60)
tag.Position = UDim2.fromOffset(30, 30)
tag.BackgroundTransparency = 1
tag.TextColor3 = Color3.new(1, 1, 0)
tag.TextSize = 40
tag.Font = Enum.Font.Code
tag.TextXAlignment = Enum.TextXAlignment.Left
tag.Parent = gui
local char = plr.Character or plr.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
-- Stand on an open spot facing +Z with the dark plaza behind.
hrp.CFrame = CFrame.new(0, 4, 30)
task.wait(1)
hrp.Anchored = true
local list = Config.Auras
local only = ONLY
for _, a in list do
	if not only or table.find(only, a.id) then
		Ctx.Request("DebugGive", { id = a.id, n = 1 })
		Ctx.Request("Equip", a.id)
		tag.Text = a.id .. "  1/" .. a.chance
		cam.CameraType = Enum.CameraType.Scriptable
		local p = hrp.Position
		cam.CFrame = CFrame.lookAt(p + hrp.CFrame.LookVector * 13 + Vector3.new(0, 2.5, 0), p + Vector3.new(0, 1.2, 0))
		print("AURA " .. a.id)
		task.wait(3)
	end
end
print("GALLERY DONE")
