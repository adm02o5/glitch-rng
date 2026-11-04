--!strict
-- Elliot: quest giver + black-market stall in the south-east lounge.
-- R6 body from a HumanoidDescription (classic hoodie/jeans, hair and hood from the marketplace).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local NPC = {}

local P = Config.Palette
local E = Config.Elliot
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local R6_IDLE = "rbxassetid://180435571" -- Roblox's default R6 idle

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, tr: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = tr or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = size.Magnitude > 6
	p.Parent = parent
	return p
end

local function neon(parent: Instance, size: Vector3, cf: CFrame, color: Color3): Part
	local p = part(parent, size, cf, color, Enum.Material.Neon)
	p.CanCollide = false
	p.CastShadow = false
	return p
end

-- Scrolling green terminal text on a part face.
local function screen(p: BasePart, face: Enum.NormalId, lines: { string }, color: Color3)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.Parent = p
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(2, 6, 4)
	bg.Parent = g
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -8, 1, -8)
	t.Position = UDim2.fromOffset(4, 4)
	t.Text = table.concat(lines, "\n")
	t.TextColor3 = color
	t.FontFace = MONO
	t.TextSize = 13
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.Parent = bg
end

local function buildStall(root: Model, base: CFrame)
	local DARK = Color3.fromRGB(16, 17, 24)
	local METAL = Color3.fromRGB(46, 48, 60)
	-- Floor pad with neon edge.
	part(root, Vector3.new(16, 0.3, 11), base * CFrame.new(0, 0.15, -1), Color3.fromRGB(10, 10, 14), Enum.Material.DiamondPlate)
	for _, x in { -8, 8 } do
		neon(root, Vector3.new(0.15, 0.1, 11), base * CFrame.new(x, 0.32, -1), P.Lime)
	end
	neon(root, Vector3.new(16, 0.1, 0.15), base * CFrame.new(0, 0.32, 4.5), P.Lime)
	-- Back wall and side walls (corrugated look).
	part(root, Vector3.new(14, 9, 0.6), base * CFrame.new(0, 4.8, -5.6), DARK, Enum.Material.CorrodedMetal)
	for i = -6, 6, 1.2 do
		part(root, Vector3.new(0.25, 9, 0.2), base * CFrame.new(i, 4.8, -5.2), METAL, Enum.Material.Metal)
	end
	for _, x in { -7, 7 } do
		part(root, Vector3.new(0.6, 9, 6), base * CFrame.new(x, 4.8, -2.8), DARK, Enum.Material.CorrodedMetal)
		part(root, Vector3.new(0.5, 9.4, 0.5), base * CFrame.new(x, 4.9, 0.2), METAL, Enum.Material.Metal)
	end
	-- Counter with glowing strip and keyboard.
	part(root, Vector3.new(12, 3.2, 1.6), base * CFrame.new(0, 1.9, 1.2), DARK, Enum.Material.Metal)
	part(root, Vector3.new(12.4, 0.25, 2), base * CFrame.new(0, 3.6, 1.2), METAL, Enum.Material.Metal)
	neon(root, Vector3.new(11.6, 0.12, 0.12), base * CFrame.new(0, 3.3, 2.05), P.Lime)
	neon(root, Vector3.new(11.6, 0.12, 0.12), base * CFrame.new(0, 0.6, 2.05), P.Magenta)
	part(root, Vector3.new(2.2, 0.12, 0.8), base * CFrame.new(-3.2, 3.78, 1.0), Color3.fromRGB(10, 10, 12))
	for k = 0, 9 do
		neon(root, Vector3.new(0.14, 0.05, 0.14), base * CFrame.new(-4.1 + k * 0.2, 3.86, 0.9), P.Lime).Transparency = 0.4
	end
	-- Laptop on the counter.
	part(root, Vector3.new(2, 0.12, 1.4), base * CFrame.new(3, 3.8, 1.1), Color3.fromRGB(30, 30, 36), Enum.Material.Metal)
	local lid = part(root, Vector3.new(2, 1.35, 0.08), base * CFrame.new(3, 4.45, 0.45) * CFrame.Angles(math.rad(-12), math.pi, 0), Color3.fromRGB(30, 30, 36), Enum.Material.Metal)
	screen(lid, Enum.NormalId.Back, { "$ ./fsociety.sh", "> rooting ...", "> odds: patched", "> hello friend_" }, P.Lime)
	-- Shelves of glowing script disks behind the counter.
	for row = 0, 2 do
		local y = 4.4 + row * 1.6
		part(root, Vector3.new(12, 0.18, 1.4), base * CFrame.new(0, y, -4.5), METAL, Enum.Material.Metal)
		for k = 0, 8 do
			local col = ({ P.Lime, P.Amber, P.Red, P.Cyan })[(k + row) % 4 + 1]
			local d = part(root, Vector3.new(0.9, 0.9, 0.12), base * CFrame.new(-5 + k * 1.25, y + 0.55, -4.5) * CFrame.Angles(0, 0, math.rad(8 * ((k % 3) - 1))), Color3.fromRGB(14, 14, 18))
			d.CanCollide = false
			neon(root, Vector3.new(0.5, 0.5, 0.14), d.CFrame * CFrame.new(0, 0, 0.01), col).Transparency = 0.15
		end
	end
	-- Monitors on the back wall.
	for i, x in { -4.2, 4.2 } do
		local m = part(root, Vector3.new(3.4, 2.2, 0.3), base * CFrame.new(x, 8.6, -5.1), Color3.fromRGB(20, 20, 26), Enum.Material.Metal)
		screen(m, Enum.NormalId.Front, if i == 1
			then { "MARKET.EXE", "luck.exe ..... 200", "speed.exe .... 150", "breach.exe .. 3000" }
			else { "QUEUE", "> contract #0x1F", "> status: open", "> reward: BITS" }, if i == 1 then P.Amber else P.Cyan)
	end
	-- Awning with neon edge and hanging cables.
	part(root, Vector3.new(15.4, 0.3, 7.4), base * CFrame.new(0, 9.6, -1.6) * CFrame.Angles(math.rad(-7), 0, 0), DARK, Enum.Material.Metal)
	neon(root, Vector3.new(15.4, 0.14, 0.14), base * CFrame.new(0, 9.15, 2.2), P.Magenta)
	for i = -6, 6, 3 do
		local c = neon(root, Vector3.new(0.08, 1.2 + math.abs(i) * 0.08, 0.08), base * CFrame.new(i, 8.4, 1.6), P.Lime)
		c.Material = Enum.Material.Neon
		local bulb = neon(root, Vector3.new(0.35, 0.35, 0.35), base * CFrame.new(i, 7.7 - math.abs(i) * 0.04, 1.6), P.Lime)
		bulb.Shape = Enum.PartType.Ball
		local l = Instance.new("PointLight")
		l.Color = P.Lime
		l.Range = 8
		l.Brightness = 0.7
		l.Parent = bulb
	end
	-- Crates and a stool beside the stall.
	for i, off in { Vector3.new(9.5, 1.2, 1), Vector3.new(10, 3.3, 0.6), Vector3.new(-9.6, 1.2, 0) } do
		local cr = part(root, Vector3.new(2.4, 2.4, 2.4), base * CFrame.new(off) * CFrame.Angles(0, math.rad(i * 13), 0), Color3.fromRGB(34, 30, 26), Enum.Material.WoodPlanks)
		neon(root, Vector3.new(2.42, 0.1, 2.42), cr.CFrame * CFrame.new(0, 0.6, 0), P.Amber).Transparency = 0.3
	end
end

local function buildElliot(root: Model, cf: CFrame): Model?
	local desc = Instance.new("HumanoidDescription")
	desc.Shirt = E.Shirt
	desc.Pants = E.Pants
	desc.HairAccessory = tostring(E.Hair)
	desc.HatAccessory = tostring(E.Hood)
	for _, k in { "HeadColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor", "TorsoColor" } do
		(desc :: any)[k] = E.Skin
	end
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R6)
	if not ok or not model then
		warn("[NPC] could not build Elliot:", model)
		return nil
	end
	local m = model :: Model
	m.Name = "Elliot"
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart
	m:PivotTo(cf)
	hrp.Anchored = true
	m.Parent = root
	-- Idle animation.
	task.spawn(function()
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local anim = Instance.new("Animation")
		anim.AnimationId = R6_IDLE
		local ok2, track = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		if ok2 and track then
			track.Looped = true
			track:Play()
		end
	end)
	-- Talk prompt.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "Talk"
	prompt.ObjectText = "ELLIOT"
	prompt:SetAttribute("Kind", "Elliot")
	prompt.Parent = hrp
	-- Name plate.
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(6, 1.4)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.MaxDistance = 80
	bb.LightInfluence = 0
	bb.Adornee = m:FindFirstChild("Head") :: BasePart
	bb.Parent = m
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.6)
	name.Text = "ELLIOT"
	name.TextScaled = true
	name.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	name.TextColor3 = P.Lime
	name.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = name
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Text = "QUESTS  ·  MARKET"
	sub.TextScaled = true
	sub.FontFace = MONO
	sub.TextColor3 = P.Dim
	sub.Parent = bb
	local st2 = Instance.new("UIStroke")
	st2.Thickness = 1.5
	st2.Parent = sub
	return m
end

function NPC.Build()
	local map = workspace:FindFirstChild("Map") or workspace
	local root = Instance.new("Model")
	root.Name = "ElliotStall"
	-- Face the plaza centre.
	local pos = E.Position
	local base = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	-- lookAt points -Z at the target; the stall's front (counter side) is +Z, so turn it around.
	base = base * CFrame.Angles(0, math.pi, 0)
	buildStall(root, base)
	root.Parent = map
	buildElliot(root, base * CFrame.new(0, 3.3, -1.8) * CFrame.Angles(0, math.pi, 0))
end

return NPC
