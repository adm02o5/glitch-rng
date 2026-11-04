--!strict
-- Cutscene/Util: easing, colour and string helpers shared by every scene.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local U = {}

U.WHITE = Color3.new(1, 1, 1)
U.BLACK = Color3.new(0, 0, 0)

function U.clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
function U.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
-- 0..1 progress of x inside [a, b].
function U.seg(x: number, a: number, b: number): number
	return math.clamp((x - a) / (b - a), 0, 1)
end
function U.outCubic(t: number): number
	return 1 - (1 - t) ^ 3
end
function U.inCubic(t: number): number
	return t ^ 3
end
function U.inOutCubic(t: number): number
	return if t < 0.5 then 4 * t ^ 3 else 1 - (-2 * t + 2) ^ 3 / 2
end
function U.outQuart(t: number): number
	return 1 - (1 - t) ^ 4
end
function U.inQuart(t: number): number
	return t ^ 4
end
function U.inOutSine(t: number): number
	return -(math.cos(math.pi * t) - 1) / 2
end
function U.outBack(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
function U.outExpo(t: number): number
	return if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
end
function U.inExpo(t: number): number
	return if t <= 0 then 0 else 2 ^ (10 * t - 10)
end
function U.outElastic(t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
end
-- 0 -> 1 -> 0 hump.
function U.bump(t: number): number
	return math.sin(math.pi * math.clamp(t, 0, 1))
end
-- Square-ish blink: 1 for `duty` of every period.
function U.blink(now: number, rate: number, duty: number?): number
	return if (now * rate) % 1 < (duty or 0.5) then 1 else 0
end

function U.flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return f.Unit
end

function U.brightness(c: Color3): number
	return c.R + c.G + c.B
end

-- A colour that reads as light on black (dark auras fall back to their second colour or white).
function U.glowColor(a: Config.Aura): Color3
	if U.brightness(a.color) > 0.7 then
		return a.color
	elseif U.brightness(a.color2) > 0.7 then
		return a.color2
	end
	return U.WHITE
end

function U.hsv(h: number, s: number, v: number): Color3
	return Color3.fromHSV(h % 1, s, v)
end

function U.spaced(s: string): string
	local out = {}
	for _, cp in utf8.codes(s) do
		table.insert(out, utf8.char(cp))
	end
	return table.concat(out, " ")
end

U.GARBAGE = {
	"#", "$", "%", "&", "@", "!", "?", "/", "\\", "|", "<", ">", "{", "}", "[", "]",
	"=", "+", "*", "^", "~", "0", "1", "X", "Z", "_", ";", ":",
}

function U.corrupt(rng: Random, s: string, amount: number): string
	if amount <= 0 then
		return s
	end
	local out = {}
	for _, cp in utf8.codes(s) do
		local ch = utf8.char(cp)
		if ch ~= " " and ch ~= "\n" and rng:NextNumber() < amount then
			table.insert(out, U.GARBAGE[rng:NextInteger(1, #U.GARBAGE)])
		else
			table.insert(out, ch)
		end
	end
	return table.concat(out)
end

function U.hex(rng: Random, digits: number): string
	local t = {}
	for i = 1, digits do
		t[i] = string.format("%X", rng:NextInteger(0, 15))
	end
	return table.concat(t)
end

function U.bits(rng: Random, n: number): string
	local t = {}
	for i = 1, n do
		t[i] = if rng:NextNumber() < 0.5 then "0" else "1"
	end
	return table.concat(t)
end

-- 1234567 -> "1,234,567"
function U.commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

local CODE_WORDS = {
	"0x7F", "NULL", "ret", "jmp", "mov", "push", "pop", "call", "fate()", "luck++", "roll", "seed", "xor",
	"0xFF", "int3", "nop", "sys", "~/", "sudo", "&&", "||", "::", "->", "{}", "[]", "0b1", "eax", "rsp",
	"hash", "sig", "key", "init", "exec", "fork", "kill", "ping", "void", "*ptr", "//", "<>", "!=", "==",
}

function U.codeWord(rng: Random): string
	return CODE_WORDS[rng:NextInteger(1, #CODE_WORDS)]
end

return U
