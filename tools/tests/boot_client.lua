-- Boot screen check: warning card, countdown, loading stages, enter transition.
local plr = game.Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")
local g = pg:WaitForChild("GlitchBoot", 10)
print("BOOT gui", g ~= nil, "Booting", plr:GetAttribute("Booting"))
if not g then return end
local function find(name) return g:FindFirstChild(name, true) end
task.wait(1)
local ok = find("Understand")
print("WARN visible", find("Warning") ~= nil, "btn:", ok and ok:FindFirstChildWhichIsA("TextLabel").Text)
task.wait(3)
print("WARN after 4s btn:", ok and ok.Parent and ok:FindFirstChildWhichIsA("TextLabel").Text)
plr:SetAttribute("BootAck", true)
task.wait(1)
print("WARN gone", find("Warning") == nil)
local t0 = os.clock()
local last = ""
while os.clock() - t0 < 40 do
	local prog = find("Progress")
	local labels = {}
	if prog and prog.Visible then
		for _, d in prog:GetDescendants() do if d:IsA("TextLabel") and d.Text ~= "" then table.insert(labels, d.Text) end end
	end
	local s = table.concat(labels, " | ")
	if s ~= last and math.floor((os.clock() - t0) * 2) % 3 == 0 then print("PROG", s) last = s end
	if find("Enter") and find("Enter").Visible then break end
	task.wait(0.5)
end
print("ENTER visible", find("Enter") and find("Enter").Visible, string.format("after %.1fs", os.clock() - t0))
local term = find("Terminal")
if term then
	for _, d in term:GetDescendants() do if d:IsA("TextLabel") and d.Text ~= "" then print("TERM", (d.Text:gsub("<[^>]+>", ""))) end end
end
local bt = game:GetService("SoundService"):FindFirstChild("BootTheme")
print("MUSIC boot theme", bt ~= nil, bt and bt.IsPlaying, bt and bt.Volume)
task.wait(2)
plr:SetAttribute("BootEnter", true)
task.wait(2.5)
print("AFTER ENTER gui", pg:FindFirstChild("GlitchBoot") ~= nil, "Booting", plr:GetAttribute("Booting"))
task.wait(3)
local mus = {}
for _, s in game:GetService("SoundService"):GetChildren() do if s:IsA("Sound") and s.IsPlaying then table.insert(mus, s.Name .. string.format("@%.2f", s.Volume)) end end
print("MUSIC now", table.concat(mus, ", "))
print("BOOT DONE")
