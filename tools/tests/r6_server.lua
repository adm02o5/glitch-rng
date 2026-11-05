--@start (playtest.py runs this as soon as play begins)
-- Swap every player's character for an R6 rig (the open Studio copy may still spawn R15).
local Players = game:GetService("Players")
local function r6(p)
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(1626125898)
	end)
	if not ok then
		desc = Instance.new("HumanoidDescription")
	end
	local old = p.Character
	local m = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	m.Name = p.Name
	m:PivotTo(CFrame.new(-20, 5, 40))
	p.Character = m
	if old then old:Destroy() end
	m.Parent = workspace
	task.wait(0.2)
	pcall(function() m.HumanoidRootPart:SetNetworkOwner(p) end)
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Anchored = false end end
	print("R6 swapped", p.Name, m:FindFirstChild("Animate") ~= nil)
end
for _, p in Players:GetPlayers() do
	task.spawn(r6, p)
end
Players.PlayerAdded:Connect(function(p)
	task.wait(1.5)
	r6(p)
end)
