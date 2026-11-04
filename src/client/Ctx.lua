--!strict
-- Shared client state: latest player data from the server, request helper, window registry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request") :: RemoteFunction

local Ctx = {}

-- Mirrors the server's view(): Rolls, Inv, Found, Aura, Rig, Rigs, Scripts, Active, Breach, Best,
-- Settings, Luck, Speed, NextBoot.
Ctx.Data = {} :: { [string]: any }
Ctx.Changed = Instance.new("BindableEvent") -- fires after Ctx.Data updates
Ctx.Windows = {} :: { [string]: any }
Ctx.Busy = false -- true while a roll or cutscene is playing

function Ctx.Request(action: string, args: any?): any
	local ok, res = pcall(Request.InvokeServer, Request, action, args)
	if not ok then
		warn("[Request]", action, res)
		return nil
	end
	return res
end

function Ctx.Set(data: { [string]: any })
	Ctx.Data = data
	Ctx.Changed:Fire(data)
end

function Ctx.Open(name: string)
	local w = Ctx.Windows[name]
	if w then
		w:Open()
	end
end

function Ctx.Toggle(name: string)
	local w = Ctx.Windows[name]
	if w then
		w:Toggle()
	end
end

-- Saves a setting locally and on the server.
function Ctx.Setting(k: string, v: any)
	if Ctx.Data.Settings then
		Ctx.Data.Settings[k] = v
	end
	Ctx.Request("Setting", { k = k, v = v })
	Ctx.Changed:Fire(Ctx.Data)
end

-- Toast is assigned by Hud at start: Ctx.Toast(text, color?)
Ctx.Toast = function(_text: string, _color: Color3?) end

return Ctx
