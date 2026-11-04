local st = workspace.Map:WaitForChild("ElliotStall", 20)
local e = st and st:WaitForChild("Elliot", 20)
if not e then print("NO ELLIOT") return end
for _, d in e:GetDescendants() do
	if d:IsA("BasePart") then
		print("PART", d.Name, d.Transparency, string.format("%.1f %.1f %.1f", d.Position.X, d.Position.Y, d.Position.Z), tostring(d.Size), d.Color)
	elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("Accessory") or d:IsA("Decal") then
		print("ITEM", d.ClassName, d.Name, d:IsA("Shirt") and d.ShirtTemplate or d:IsA("Pants") and d.PantsTemplate or "")
	end
end
