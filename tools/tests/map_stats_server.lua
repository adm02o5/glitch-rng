local map = workspace:WaitForChild("Map", 30)
task.wait(2)
local n, shadow, anchoredNo, neon, glass = 0, 0, 0, 0, 0
local cls = {}
local byModel = {}
for _, d in map:GetDescendants() do
	cls[d.ClassName] = (cls[d.ClassName] or 0) + 1
	if d:IsA("BasePart") then
		n += 1
		if d.CastShadow then shadow += 1 end
		if not d.Anchored then anchoredNo += 1 end
		if d.Material == Enum.Material.Neon then neon += 1 end
		if d.Material == Enum.Material.Glass then glass += 1 end
		local top = d
		while top.Parent ~= map and top.Parent do top = top.Parent end
		byModel[top.Name] = (byModel[top.Name] or 0) + 1
	end
end
print("PARTS", n, "shadow", shadow, "unanchored", anchoredNo, "neon", neon, "glass", glass)
local t = {}
for k, v in cls do if v > 50 then table.insert(t, k .. "=" .. v) end end
print("CLASSES", table.concat(t, " "))
local m = {}
for k, v in byModel do table.insert(m, {k, v}) end
table.sort(m, function(a, b) return a[2] > b[2] end)
local s = {}
for i = 1, math.min(14, #m) do table.insert(s, m[i][1] .. "=" .. m[i][2]) end
print("TOP", table.concat(s, " "))
print("STREAMING", tostring(workspace.StreamingEnabled))
