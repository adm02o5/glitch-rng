--!strict
-- Custom look for terminal ProximityPrompts (Style = Custom, attribute Kind) and opening their windows.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent.UI.Kit)
local Ctx = require(script.Parent.Ctx)

local P = Kit.P
local new = Kit.new

local Prompts = {}

local KIND_WINDOW = { Forge = "Forge", Lab = "Lab", Index = "Index", Elliot = "Elliot" }
local KIND_COLOR = { Forge = P.Amber, Lab = P.Lime, Index = P.Magenta, Elliot = P.Lime }

-- Fires the prompt as if its key was pressed (custom prompts get no built-in tap handling).
local function trigger(prompt: ProximityPrompt)
	if not prompt.Enabled or not prompt.Parent then
		return
	end
	prompt:InputHoldBegin()
	if prompt.HoldDuration > 0 then
		task.wait(prompt.HoldDuration + 0.05)
	end
	prompt:InputHoldEnd()
end

-- Key label: the prompt's own keyboard key, the gamepad button, or TAP on touch screens.
local function keyText(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType?): string
	if input == Enum.ProximityPromptInputType.Touch or (input == nil and Kit.IsMobile()) then
		return "TAP"
	elseif input == Enum.ProximityPromptInputType.Gamepad then
		local s = UserInputService:GetStringForKeyCode(prompt.GamepadKeyCode)
		return if s ~= "" then s else "X"
	end
	local s = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return if s ~= "" then s else prompt.KeyboardKeyCode.Name
end

local function build(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType?): BillboardGui
	local kind = prompt:GetAttribute("Kind")
	local color = (typeof(kind) == "string" and KIND_COLOR[kind]) or P.Cyan
	local touch = input == Enum.ProximityPromptInputType.Touch or Kit.IsMobile()
	local bb = new("BillboardGui", {
		Name = "PromptUI",
		-- A bit larger on phones so it is an easy target for a thumb.
		Size = if touch then UDim2.fromOffset(270, 84) else UDim2.fromOffset(240, 74),
		StudsOffset = Vector3.new(0, 1.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Active = true, -- receives clicks / taps
	})
	local panel = Kit.panel(bb, { Size = UDim2.fromScale(1, 1) }, color)
	local key = new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(14, 14),
		Parent = panel,
	})
	Kit.corner(key, 4)
	local kt = keyText(prompt, input)
	Kit.label(key, kt, if #kt >= 3 then 13 elseif #kt == 2 then 18 else 26, {
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
	Kit.label(panel, (if touch then "> tap to " else "> ") .. string.lower(prompt.ActionText) .. " terminal_", 13, {
		TextColor3 = P.Dim,
		Position = UDim2.fromOffset(72, 40),
		Size = UDim2.new(1, -80, 0, 16),
	})
	local sc = new("UIScale", { Scale = 0.5, Parent = panel })
	Kit.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	-- Whole prompt is a button: click or tap opens the terminal (keyboard E still works as before).
	local hit = new("TextButton", {
		Name = "Hit",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = bb,
	})
	local busy = false
	Kit.feedback(hit, {
		hover = function()
			Kit.tween(sc, 0.12, { Scale = 1.05 })
		end,
		idle = function()
			Kit.tween(sc, 0.2, { Scale = 1 })
		end,
		press = function()
			Kit.tween(sc, 0.06, { Scale = 0.92 })
			key.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
		end,
		release = function()
			Kit.tween(sc, 0.2, { Scale = 1.05 })
		end,
	})
	hit.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		key.BackgroundColor3 = color
		task.spawn(trigger, prompt)
		task.delay(0.4, function()
			busy = false
		end)
	end)
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
		local bb = build(prompt, input)
		bb.Adornee = prompt.Parent :: any
		-- Directly under PlayerGui (not inside a ScreenGui), so the billboard receives taps and clicks.
		bb.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
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
