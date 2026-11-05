-- Blender clip + Sync bus check: wear each aura in LIST, idle 7 s then walk 4 s; log marker
-- events (Sync.stats) and how much the joints move.
local plr = game.Players.LocalPlayer
local t0 = os.clock()
repeat task.wait(0.2) until plr:GetAttribute("Loaded") or os.clock() - t0 > 40
local C = plr.PlayerScripts:WaitForChild("Client")
local Ctx = require(C.Ctx)
Ctx.Setting("Tut", true)
task.wait(2.5)
pcall(function() require(C.Tutorial).Skip() end)
local Sync = require(game.ReplicatedStorage.Shared.AuraFX.Sync)
local char
repeat
	char = plr.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	task.wait(0.3)
until h and (h.RigType == Enum.HumanoidRigType.R6 or not WANT_R6) or os.clock() - t0 > 60
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
for _ = 1, 3 do
	pcall(function() require(C.Tutorial).Skip() end)
	task.wait(0.4)
end
print("RIG", hum.RigType, "anch", hrp.Anchored, "owner?", hrp.ReceiveAge, "ps", hum.PlatformStand, "ws", hum.WalkSpeed, "same", plr.Character == char)
local cam = workspace.CurrentCamera
local LIST = LIST or { "NeonPulse" }
local function motor(n)
	return char:FindFirstChild(n, true) :: Motor6D
end
local rs, neck, root = motor("Right Shoulder") or motor("RightShoulder"), motor("Neck"), motor("RootJoint") or motor("Root")
local function deg(cf)
	local x, y, z = cf:ToOrientation()
	return string.format("%.0f,%.0f,%.0f", math.deg(x), math.deg(y), math.deg(z))
end
do -- baseline: can we walk at all (no aura)?
	Ctx.Request("AdminWear", "")
	task.wait(0.5)
	hrp.CFrame = CFrame.new(-20, 4, 40)
	task.wait(0.5)
	local p0 = hrp.Position
	local tt = os.clock()
	while os.clock() - tt < 2 do
		hum:Move(Vector3.new(1, 0, 0), false)
		task.wait()
	end
	hum:Move(Vector3.zero, false)
	print(string.format("BASELINE walked %.1f studs (aura attr=%s)", (hrp.Position - p0).Magnitude, tostring(plr:GetAttribute("Aura"))))
end
for _, id in LIST do
	hrp.CFrame = CFrame.new(-20, 4, 40)
	task.wait(0.3)
	Ctx.Request("AdminWear", id)
	table.clear(Sync.stats)
	local t = os.clock()
	local lastBeat = 0
	while os.clock() - t < 7 do
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(4, 1.5, -9), hrp.Position + Vector3.new(0, 0.3, 0))
		local b = Sync.stats.beat or 0
		if b ~= lastBeat then
			lastBeat = b
			print(string.format("%s t=%.2f beat#%d rs=%s neck=%s root=%s", id, os.clock() - t, b, deg(rs.Transform), deg(neck.Transform), deg(root.Transform)))
		end
		task.wait()
	end
	local idleStats = table.clone(Sync.stats)
	table.clear(Sync.stats)
	t = os.clock()
	local p0 = hrp.Position
	local stepsSeen = 0
	local dbg = false
	while os.clock() - t < 4 do
		hum:Move(Vector3.new(1, 0, 0), false)
		plr:Move(Vector3.new(1, 0, 0), false)
		hrp.AssemblyLinearVelocity = Vector3.new(16, 0, 0) -- physics does not step in this Studio test env
		if false then
			dbg = true
			local op = OverlapParams.new() op.FilterDescendantsInstances = { char } op.FilterType = Enum.RaycastFilterType.Exclude
			for _, bp in workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(4, 5, 4), op) do print("DBG touching", bp:GetFullName(), bp.Anchored, bp.CanCollide) end
			local an = {}
			for _, d in char:GetDescendants() do if d:IsA("BasePart") and d.Anchored then table.insert(an, d.Name) end end
			for _, d in char:GetDescendants() do if d:IsA("Constraint") or d:IsA("BodyMover") or d:IsA("AlignPosition") then table.insert(an, "C:" .. d.ClassName .. ":" .. d.Name) end end
			print("DBG anchored/constraints:", table.concat(an, ","), "seat", hum.SeatPart, "sit", hum.Sit, "auto", hum.AutoRotate, "state", hum:GetState())
			print("DBG movedir", hum.MoveDirection, "vel", hrp.AssemblyLinearVelocity, "pos", hrp.Position, "floor", hum.FloorMaterial, "mass", hrp.AssemblyMass, "rootpart", hrp.AssemblyRootPart and hrp.AssemblyRootPart:GetFullName())
		end
		cam.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(3, 2, -10), hrp.Position + Vector3.new(0, 0.3, 0))
		task.wait()
	end
	hum:Move(Vector3.zero, false)
	print(string.format("%s walked %.1f studs, ws=%.0f, MoveDir=%s, state=%s", id, (hrp.Position - p0).Magnitude, hum.WalkSpeed, tostring(hum.MoveDirection), tostring(hum:GetState())))
	local parts = {}
	for k, v in idleStats do table.insert(parts, k .. "=" .. v) end
	local wparts = {}
	for k, v in Sync.stats do table.insert(wparts, k .. "=" .. v) end
	print("AURA", id, "idle:", table.concat(parts, " "), "| walk:", table.concat(wparts, " "))
end
print("SYNC DONE")
