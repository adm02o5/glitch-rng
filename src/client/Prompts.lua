--!strict
-- Custom look for terminal ProximityPrompts (Style = Custom, attribute Kind) and opening their windows.

local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Kit = require(script.Parent.UI.Kit)
local Ctx = require(script.Parent.Ctx)

local P = Kit.P
local new = Kit.new

local Prompts = {}

local KIND_WINDOW = { Forge = "Forge", Lab = "Lab", Index = "Index" }
local KIND_COLOR = { Forge = P.Amber, Lab = P.Lime, Index = P.Magenta }

local function build(prompt: ProximityPrompt): BillboardGui
	local kind = prompt:GetAttribute("Kind")
	local color = (typeof(kind) == "string" and KIND_COLOR[kind]) or P.Cyan
	local bb = new("BillboardGui", {
		Name = "PromptUI",
		Size = UDim2.fromOffset(240, 74),
		StudsOffset = Vector3.new(0, 1.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	local panel = Kit.panel(bb, { Size = UDim2.fromScale(1, 1) }, color)
	local key = new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(14, 14),
		Parent = panel,
	})
	Kit.corner(key, 4)
	Kit.label(key, "E", 26, {
		FontFace = Kit.Title,
		TextColor3 = P.Bg,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local title = Kit.label(panel, prompt.ObjectText, 16, {
		FontFace = Kit.Title,
		TextColor3 = color,
		Position = UDim2.fromOffset(72, 14),
		Size = UDim2.new(1, -80, 0, 22),
	})
	Kit.label(panel, "> " .. string.lower(prompt.ActionText) .. " terminal_", 13, {
		TextColor3 = P.Dim,
		Position = UDim2.fromOffset(72, 40),
		Size = UDim2.new(1, -80, 0, 16),
	})
	local sc = new("UIScale", { Scale = 0.5, Parent = panel })
	Kit.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.glitch(title, 0.3)
	-- Blinking key cap.
	local conn = RunService.RenderStepped:Connect(function()
		key.BackgroundTransparency = 0.15 + math.abs(math.sin(os.clock() * 3)) * 0.25
	end)
	bb.Destroying:Connect(function()
		conn:Disconnect()
	end)
	return bb
end

function Prompts.Start()
	ProximityPromptService.PromptShown:Connect(function(prompt, input)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local bb = build(prompt)
		bb.Adornee = prompt.Parent :: any
		bb.Parent = Kit.Top
		prompt.PromptHidden:Once(function()
			bb:Destroy()
		end)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt:GetAttribute("Kind")
		local win = typeof(kind) == "string" and KIND_WINDOW[kind]
		if win then
			Ctx.Open(win)
		end
	end)
end

return Prompts
