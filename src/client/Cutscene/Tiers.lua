--!strict
-- Cutscene/Tiers: the generic per-tier sequences. Used for every RARE aura and as the fallback for any
-- higher aura that has no themed scene of its own (e.g. auras added later).
--
--   1 RARE        edge flash, vignette pulse, FOV punch, small burst
--   2 EPIC        glitch overlay (RGB-split bars + block noise), shake, colour-correction pulse, burst
--   3 LEGENDARY   letterbox, orbit camera, dimmed world, hacker terminal trace, glitch spike, white-out
--   4 MYTHIC /    escalating glitch + error popups, full "system crash" screen (BSOD / corrupted),
--     CORRUPTED   counter to 100%, cracks, screen shatters into flying shards, low-angle hero shot
--   5 SINGULARITY fade to black + silence, a white point grows with rings, camera rises into the sky and
--                 dives back, the aura name is spelled out huge with RGB split, final white-out

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RNG = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RNG"))

local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local U = require(script.Parent.Util)
local Fx = require(script.Parent.Fx)

local P = Kit.P
local WHITE, BLACK = U.WHITE, U.BLACK
local clamp01, lerp, seg = U.clamp01, U.lerp, U.seg
local outCubic, inCubic, inOutCubic, outQuart, inQuart, inOutSine, outBack, bump =
	U.outCubic, U.inCubic, U.inOutCubic, U.outQuart, U.inQuart, U.inOutSine, U.outBack, U.bump
local hex, spaced, glowColor, brightness = U.hex, U.spaced, U.glowColor, U.brightness
local setT, setC = Fx.setT, Fx.setC

--------------------------------------------------------------------------------------------------------
-- LEVEL 1: RARE (~0.9s)
--------------------------------------------------------------------------------------------------------

local function level1(S: any)
	local tc = S.tier.color
	local edge = S:edges(tc:Lerp(S.aura.color, 0.35), 0.24, 10)
	local vig = S:edges(BLACK, 0.4, 9)
	setT(edge, 1)
	setT(vig, 1)
	-- A thin scanline that sweeps down the screen with the flash.
	local scan = S:frame({
		Name = "Scan",
		BackgroundColor3 = tc:Lerp(WHITE, 0.4),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 3),
		ZIndex = 12,
	})
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = scan,
	})
	S:sfx("Whoosh", 0.55, 1.15)
	S:sfx("Glitch", 0.25, 1.5)
	S:burst(1)
	S:phase(0.9, function(a: number)
		local flash = if a < 0.1 then outCubic(a / 0.1) else 1 - outCubic(seg(a, 0.1, 1))
		setT(edge, 1 - flash * 0.85)
		setT(vig, 1 - bump(a) * 0.6)
		scan.Position = UDim2.fromScale(0, outCubic(seg(a, 0, 0.6)))
		scan.BackgroundTransparency = 1 - bump(seg(a, 0, 0.6)) * 0.6
		-- Kick in, then spring back with a small overshoot.
		S.fovPunch = if a < 0.13 then -9 * outCubic(a / 0.13) else -9 * (1 - outBack(seg(a, 0.13, 1)))
	end)
	S.fovPunch = 0
end

--------------------------------------------------------------------------------------------------------
-- LEVEL 2: EPIC (~1.8s)
--------------------------------------------------------------------------------------------------------

local function level2(S: any)
	local tc, a = S.tier.color, S.aura
	local gl = S:glitchLayer(20)
	local edgeL = S:edges(P.Cyan, 0.16, 10)
	local edgeR = S:edges(P.Magenta, 0.16, 10)
	local edgeT = S:edges(tc:Lerp(a.color, 0.4), 0.26, 11)
	local vig = S:edges(BLACK, 0.42, 9)
	for _, l in { edgeL, edgeR, edgeT, vig } do
		setT(l, 1)
	end
	local cc = S:cc()
	local rng = S.rng
	local fired = false
	S:sfx("Glitch", 0.55, 1)
	S:sfx("Whoosh", 0.4, 0.8)
	S:phase(1.8, function(_: number, e: number)
		-- Envelope: fast attack, a spike at the burst, long decay.
		local env = if e < 0.25 then outCubic(e / 0.25) else 1 - inOutCubic(seg(e, 0.6, 1.8))
		local spike = if rng:NextNumber() < 0.12 then rng:NextNumber(0.2, 0.5) else 0
		gl.k = clamp01(env * 0.85 + spike * env)
		S.shake = env * 0.75
		S.fovPunch = -6 * bump(seg(e, 0.5, 1.2))
		-- Chromatic edges offset left/right.
		local flick = 0.6 + 0.4 * math.sin(e * 40)
		edgeL[3].BackgroundTransparency = 1 - env * 0.55 * flick
		edgeR[4].BackgroundTransparency = 1 - env * 0.55 * (1.6 - flick)
		setT(edgeT, 1 - bump(seg(e, 0.45, 1.3)) * 0.8)
		setT(vig, 1 - env * 0.7)
		cc.Contrast = 0.35 * env
		cc.Saturation = 0.35 * env
		cc.Brightness = 0.08 * bump(seg(e, 0.5, 0.8))
		cc.TintColor = WHITE:Lerp(a.color:Lerp(tc, 0.5), 0.25 * env)
		if not fired and e >= 0.55 then
			fired = true
			S:burst(1.4)
			S:sfx("Boom", 0.5, 1.1)
			S:sfx("Glitch", 0.45, 0.75)
		end
	end)
	S.shake = 0
	S.fovPunch = 0
end

--------------------------------------------------------------------------------------------------------
-- LEVEL 3: LEGENDARY (~4.5s)
--------------------------------------------------------------------------------------------------------

local function level3(S: any)
	local tc, a = S.tier.color, S.aura
	local info = S.info

	local lines: { { text: string, color: Color3?, hold: number, dots: boolean?, progress: boolean?, sound: string? } } = {}
	table.insert(lines, { text = "> ANOMALY DETECTED", color = P.Red, hold = 0.22, sound = "Error" })
	if S.exclusive then
		table.insert(lines, {
			text = "> SECTOR LOCK: " .. S.biomeName .. "  // EXCLUSIVE SIGNAL",
			color = S.biomeColor:Lerp(WHITE, 0.2),
			hold = 0.15,
		})
	else
		table.insert(lines, { text = "> SECTOR: " .. S.biomeName, color = P.Dim, hold = 0.1 })
	end
	if info.breach then
		table.insert(lines, { text = "> BREACH PROTOCOL ENGAGED", color = P.Red, hold = 0.12 })
	elseif info.boot then
		table.insert(lines, { text = "> BOOT SEQUENCE OVERRIDE", color = P.Magenta, hold = 0.12 })
	end
	table.insert(lines, { text = "> TRACING SIGNATURE", color = P.Text, hold = 0.35, dots = true })
	table.insert(lines, { text = "", progress = true, hold = 0 })
	table.insert(lines, {
		text = "> CLASS: " .. S.tier.name .. "  //  " .. RNG.ChanceText(a.chance),
		color = tc,
		hold = 0.25,
	})
	if info.first then
		table.insert(lines, { text = "> NEW SIGNATURE DISCOVERED", color = P.Lime, hold = 0.45, sound = "Announce" })
	end

	local gl = S:glitchLayer(30)
	local vig = S:edges(BLACK, 0.46, 8)
	local edge = S:edges(tc, 0.2, 9)
	setT(vig, 1)
	setT(edge, 1)
	local lb = S:letterbox(
		40,
		"// SIGNAL INTERCEPT  ::  TRACE 0x" .. hex(S.rng, 4) .. "  ::  SECTOR " .. S.biomeName,
		spaced(S.tier.name) .. "     S I G N A T U R E",
		tc
	)
	local cc = S:cc()
	local white = S:frame({ Name = "White", BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 150 })

	-- Intro: glitch spike in, HUD away, bars in, world dims, orbit starts.
	S:sfx("Glitch", 0.6, 0.9)
	S:sfx("Riser", 0.45, 1)
	S:hideHud()
	S:orbitCamera(4.6)
	S:phase(0.5, function(k: number)
		gl.k = bump(k) * 0.9
		lb.k = outCubic(k)
		setT(vig, 1 - 0.75 * k)
		setT(edge, 1 - 0.55 * bump(k))
		cc.Brightness = -0.12 * k
		cc.Saturation = -0.45 * k
		cc.Contrast = 0.15 * k
		cc.TintColor = WHITE:Lerp(tc, 0.12 * k)
		S.shake = 0.5 * (1 - k)
	end)
	S.shake = 0

	local term = S:terminal(#lines, 50)
	local panel: Frame = term.panel
	local target = panel.Position
	panel.Position = target - UDim2.fromScale(0.08, 0)
	term.scale.Scale = S.vs * 0.6
	Kit.tween(panel, 0.35, { Position = target })
	Kit.tween(term.scale, 0.35, { Scale = S.vs * 0.92 }, Enum.EasingStyle.Back)
	S:phase(0.25, function(k: number)
		gl.k = 0.25 * (1 - k)
	end)

	-- Breathing edge glow while the trace runs.
	S:loop(function(now: number)
		setT(edge, 1 - (0.25 + 0.12 * math.sin(now * 5)))
		return false
	end)

	for _, ln in lines do
		if ln.sound then
			S:sfx(ln.sound, 0.5, 1)
		end
		if ln.progress then
			local l = term.add("", tc:Lerp(WHITE, 0.25))
			local lastTen = -1
			S:phase(0.9, function(k: number)
				local p = clamp01(inOutCubic(k) + math.sin(k * 29) * 0.025 * (1 - k))
				if k >= 1 then
					p = 1
				end
				local n = 20
				local filled = math.floor(p * n + 0.5)
				local pct = math.floor(p * 100)
				l.Text = "> DECRYPTING [" .. string.rep("#", filled) .. string.rep("-", n - filled) .. "] " .. pct .. "%"
				term.progress(p)
				local ten = math.floor(pct / 10)
				if ten ~= lastTen then
					lastTen = ten
					S:sfx("Tick", 0.35, 0.9 + p * 0.6)
				end
			end)
			l.TextColor3 = P.Lime
			Kit.glitch(l, 0.2)
		else
			local l = S:typeLine(term, ln.text, ln.color, 75, ln.hold, ln.dots)
			if ln.text:find("ANOMALY") or ln.text:find("NEW SIGNATURE") then
				Kit.glitch(l, 0.3)
			end
		end
	end

	-- Glitch spike, building to the white-out.
	S:sfx("Glitch", 0.75, 1.25)
	S:sfx("Riser", 0.35, 1.6)
	S:phase(0.45, function(k: number)
		gl.k = 0.3 + 0.9 * inCubic(k)
		S.shake = 0.9 * k
		white.BackgroundTransparency = 1 - 0.3 * inQuart(k)
		setC(edge, tc:Lerp(WHITE, k))
		setT(edge, 1 - 0.9 * k)
		cc.Brightness = lerp(-0.12, 0.25, inCubic(k))
	end)
	S:phase(0.12, function(k: number)
		white.BackgroundTransparency = 0.7 * (1 - k)
	end)
	S:sfx("Boom", 0.7, 1)
	S:peakCut(white)
	S:burst(1.7)
	S:raw(0.55, function(k: number)
		white.BackgroundTransparency = outCubic(k)
	end)
end

--------------------------------------------------------------------------------------------------------
-- LEVEL 4: MYTHIC / CORRUPTED (~7s)
--------------------------------------------------------------------------------------------------------

local MYTHIC_ERRORS = {
	"FATE.EXE is not responding.",
	"The memory at 0x0000DEAD could not be read.",
	"Probability overflow in luck.dll",
	"Reality buffer exceeded (4096/4096).",
	"Signature checksum mismatch.",
	"Unhandled exception in roll_core.sys",
	"Stack overflow in destiny.bin",
}
local CORRUPT_ERRORS = {
	"C0RRUPT10N SPR34D1NG",
	"Kernel heap overwritten by unknown entity.",
	"Integrity check: 0% (FAILED)",
	"SEGFAULT in fate_core.sys",
	"Do not turn off your reality.",
	"Unknown process is rewriting you.",
	"ERR 0xBADF00D :: memory is screaming",
}

local function level4(S: any)
	local corrupted = S.tier.id == "Corrupted"
	local tc, a = S.tier.color, S.aura
	local rng = S.rng
	local hue = if corrupted then P.Red else tc

	local gl = S:glitchLayer(30)
	local edge = S:edges(hue, 0.22, 9)
	local vig = S:edges(BLACK, 0.48, 8)
	setT(edge, 1)
	setT(vig, 1)
	local cc = S:cc()
	local white = S:frame({ Name = "White", BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 150 })

	local errs = if corrupted then CORRUPT_ERRORS else MYTHIC_ERRORS
	local biomeErr = "Unhandled anomaly in sector " .. S.biomeName
	local pops: { Frame } = {}
	local nextPop, nextGl = 0.35, 0

	-- 1) Escalation: the screen glitches harder and harder.
	S:sfx("Riser", 0.55, 0.85)
	S:sfx("Glitch", 0.5, 0.8)
	S:phase(2.3, function(k: number, e: number)
		local esc = k ^ 1.5
		local spike = if rng:NextNumber() < 0.1 then 0.45 else 0
		gl.k = 0.08 + 0.95 * esc + spike * esc
		S.shake = 0.12 + 0.95 * esc
		S.fovPunch = -8 * inOutCubic(k)
		setT(edge, 1 - (0.2 + 0.65 * esc) * (0.65 + 0.35 * math.sin(e * 32)))
		setT(vig, 1 - 0.85 * esc)
		cc.Saturation = -0.7 * esc + (if spike > 0 then 0.6 else 0)
		cc.Contrast = 0.45 * esc
		cc.Brightness = if spike > 0 then 0.12 else -0.05 * esc
		cc.TintColor = WHITE:Lerp(hue, 0.28 * esc)
		if e >= nextPop then
			local msg = if S.exclusive and #pops == 2 then biomeErr else errs[rng:NextInteger(1, #errs)]
			table.insert(pops, S:errorPopup(45, msg, corrupted))
			S:sfx("Error", 0.45, 0.9 + esc * 0.5)
			nextPop = e + lerp(0.5, 0.1, esc)
		end
		if e >= nextGl then
			S:sfx("Glitch", 0.3 + 0.4 * esc, 0.75 + esc * 0.9)
			nextGl = e + lerp(0.55, 0.16, esc)
		end
	end)

	-- 2) Crash screen. Behind it, the camera moves to a low angle on the character.
	S:hideHud()
	for _, p in pops do
		p:Destroy()
	end
	S.shake = 0
	S.fovPunch = 0
	setT(edge, 1)
	setT(vig, 1)
	cc.Saturation = 0.15
	cc.Contrast = 0.2
	cc.Brightness = 0
	cc.TintColor = WHITE:Lerp(a.color, 0.08)
	local crash = S:crashScreen(corrupted, 60)
	gl.holder.ZIndex = 62
	S:sfx("Error", 0.85, 0.7)
	S:sfx("Boom", 0.55, 0.55)
	S:lowAngleCamera()
	local crashDur = if S.info.first then 2.5 else 2.1
	local lastStep = -1
	S:phase(crashDur, function(k: number, e: number)
		-- Glitched cut-in for the first moments, then a subtle flicker.
		gl.k = if e < 0.18 then 1 - e / 0.18 else (if corrupted then 0.12 else 0.03)
		-- Counter races to 100 with little stalls.
		local q = seg(k, 0.06, 0.86)
		local stepped = math.floor((q ^ 1.7) * 100)
		if q > 0.4 and q < 0.48 then
			stepped = math.floor((0.4 ^ 1.7) * 100)
		end
		local pct = math.clamp(stepped, 0, 100)
		crash.update(os.clock(), e, pct)
		local step = math.floor(pct / 5)
		if step ~= lastStep then
			lastStep = step
			S:sfx("Tick", 0.3, 0.8 + pct / 100 * 0.8)
		end
	end)
	crash.update(os.clock(), crashDur, 100)

	-- 3) Cracks spread...
	gl.k = 0
	S:sfx("Glitch", 0.9, 0.55)
	local cr = S:cracks(70)
	S:phase(0.3, function(k: number)
		cr.set(k)
		S.shake = 0.35 * k
	end)

	-- 4) ...and the screen shatters into the hero shot.
	S:sfx("Boom", 0.95, 0.85)
	S:sfx("Whoosh", 0.75, 0.9)
	local lb = S:letterbox(
		40,
		"// SYSTEM FAILURE  ::  " .. (if corrupted then "CORRUPTION" else "ANOMALY") .. " CONTAINED  ::  SECTOR " .. S.biomeName,
		spaced(S.tier.name) .. "     S I G N A T U R E",
		hue
	)
	S:shatter(crash.root, 7, 4, 65, cr.cx, cr.cy)
	cr.holder:Destroy()
	S:burst(2.6)
	S:worldFlash(glowColor(a), 0.7)
	local edgeG = S:edges(glowColor(a), 0.25, 9)
	S:phase(1.5, function(k: number, e: number)
		white.BackgroundTransparency = 0.4 + 0.6 * outCubic(clamp01(e / 0.3))
		S.shake = 0.75 * (1 - k) ^ 2
		lb.k = outCubic(clamp01(e / 0.45))
		setT(edgeG, 0.2 + 0.8 * outCubic(k))
		cc.Brightness = 0.15 * (1 - outCubic(clamp01(e / 0.5)))
	end)

	-- 5) White-out and cut back.
	S:phase(0.22, function(k: number)
		white.BackgroundTransparency = 1 - inCubic(k)
	end)
	S:peakCut(white)
	S:raw(0.5, function(k: number)
		white.BackgroundTransparency = outCubic(k)
	end)
end

--------------------------------------------------------------------------------------------------------
-- LEVEL 5: SINGULARITY (~10.5s)
--------------------------------------------------------------------------------------------------------

local function level5(S: any)
	local a = S.aura
	local acol = glowColor(a)
	local info = S.info

	local black = S:frame({ Name = "Black", BackgroundTransparency = 1, ZIndex = 20 })
	local vig = S:edges(BLACK, 0.45, 15)
	setT(vig, 1)
	local cc = S:cc()
	local blur = S:blur()
	local white = S:frame({ Name = "White", BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 150 })

	-- 1) Fade to black, music dies.
	S:sfx("Glitch", 0.3, 0.45)
	S:phase(1.0, function(k: number)
		local q = inOutCubic(k)
		black.BackgroundTransparency = 1 - q
		S:duck(1 - q)
		cc.Saturation = -q
		S.fovPunch = -5 * q
	end)
	S:hideHud()
	S.fovPunch = 0

	-- Camera timeline (one closure, mode switched by the phases below).
	local lv = S:focusLook()
	local rv = lv:Cross(Vector3.yAxis)
	local mode = "front"
	local m0 = os.clock()
	local riseTop = 380
	local function frontCF(c: Vector3, dist: number, side: number): CFrame
		local look = c + Vector3.new(0, 1.5, 0)
		local pos = S:safe(look, c + lv * dist + rv * side + Vector3.new(0, 1.2, 0))
		return CFrame.lookAt(pos, look)
	end
	local function skyCF(c: Vector3, h: number, spin: number, k: number): CFrame
		local dir = (CFrame.fromAxisAngle(Vector3.yAxis, spin) * CFrame.new(lv)).Position
		local horiz = lerp(10, 3, k)
		local pos = c + dir * horiz + Vector3.new(0, h, 0)
		local up = Vector3.yAxis:Lerp(-dir, clamp01(k * 1.4))
		if up.Magnitude < 0.01 then
			up = -dir
		end
		return CFrame.lookAt(pos, c, up.Unit)
	end
	S:takeCamera(function(now: number)
		local c = S:focusPos()
		local e = now - m0
		if mode == "front" then
			return frontCF(c, 10, 0), 60
		elseif mode == "rise" then
			local k = clamp01(e / 2.3)
			local h = lerp(2, riseTop, outQuart(k))
			return skyCF(c, h, math.rad(120) * outCubic(k), outCubic(k)), lerp(60, 70, k)
		elseif mode == "dive" then
			local k = clamp01(e / 1.1)
			local h = lerp(riseTop, 9, inCubic(k))
			local spin = math.rad(120) + math.rad(200) * inCubic(k)
			return skyCF(c, h, spin, 1), lerp(70, 112, inQuart(k))
		else -- "hero"
			local k = clamp01(e / 3)
			return frontCF(c, lerp(8.5, 6.2, outCubic(k)), lerp(1.6, -0.8, inOutSine(k)))
				* CFrame.Angles(0, 0, math.rad(lerp(3, 0, outCubic(k)))),
				lerp(48, 44, k)
		end
	end)

	-- 2) Silence.
	S:phase(0.5)

	-- 3) A single white point appears and grows; rings ripple out; light is sucked in.
	local point = S:frame({
		Name = "Point",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.fromScale(0, 0),
		ZIndex = 30,
	})
	local glows: { Frame } = {}
	for i, spec in { { 8, 0.95 }, { 4, 0.88 }, { 2.2, 0.65 }, { 1, 0 } } do
		local g = Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = if i == 4 then WHITE else acol:Lerp(WHITE, (i - 1) * 0.25),
			BackgroundTransparency = spec[2],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(spec[1], spec[1]),
			ZIndex = i,
			Parent = point,
		})
		Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = g })
		glows[i] = g
	end
	local flare = Kit.new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = acol:Lerp(WHITE, 0.5),
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(40, 0.07),
		ZIndex = 5,
		Parent = point,
	})
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = flare,
	})
	local streaks = S:streaks(25, 44, acol)
	S:sfx("Riser", 0.75, 0.75)
	local nextRing = 0.15
	S:phase(2.0, function(k: number, e: number)
		local appear = outBack(clamp01(e / 0.3))
		local flicker = 1 + math.noise(e * 14, 2.2) * 0.25
		local s = (0.006 + 0.05 * inCubic(k)) * appear * flicker
		point.Size = UDim2.fromScale(s, s)
		flare.BackgroundTransparency = 0.6 - 0.45 * k
		streaks.k = 0.2 + 0.8 * k
		streaks.mode = "in"
		if e >= nextRing then
			S:ring(28, if math.floor(e * 10) % 2 == 0 then acol else WHITE, 1.4, 1.6, 2)
			S:sfx("Tick", 0.25, 0.5 + k)
			nextRing = e + lerp(0.6, 0.2, k)
		end
	end)
	-- Ring burst.
	S:ring(28, WHITE, 0.9, 2.4, 6)
	S:ring(28, acol, 1.3, 2.0, 3)
	S:sfx("Boom", 0.55, 0.6)
	S:sfx("Whoosh", 0.8, 0.8)

	-- 4) The world returns; the camera pulls far up into the sky.
	mode = "rise"
	m0 = os.clock()
	streaks.k = 0
	S:phase(2.3, function(_: number, e: number)
		black.BackgroundTransparency = outCubic(clamp01(e / 0.6))
		local s = lerp(0.056, 0.008, outCubic(clamp01(e / 0.5)))
		point.Size = UDim2.fromScale(s, s)
		local fade = seg(e, 1.2, 2.1)
		for i, g in glows do
			g.BackgroundTransparency = lerp(({ 0.95, 0.88, 0.65, 0 })[i], 1, fade)
		end
		flare.BackgroundTransparency = lerp(0.15, 1, fade)
		setT(vig, 1 - 0.65 * clamp01(e / 0.6))
		cc.Saturation = lerp(-1, -0.25, clamp01(e / 0.6))
		cc.Contrast = 0.18
		cc.TintColor = WHITE:Lerp(acol, 0.12)
	end)
	point:Destroy()

	-- 5) Dive back down with speed lines.
	mode = "dive"
	m0 = os.clock()
	streaks.mode = "out"
	S:sfx("Whoosh", 0.9, 1.2)
	S:sfx("Riser", 0.5, 1.4)
	S:phase(1.1, function(k: number)
		streaks.k = inCubic(k)
		S.shake = 0.5 * inCubic(k)
		cc.Contrast = 0.18 + 0.2 * k
		setT(vig, 1 - (0.65 + 0.25 * k))
	end)

	-- Impact: flash, cut to the hero shot.
	mode = "hero"
	m0 = os.clock()
	streaks.k = 0
	S.shake = 0
	S:sfx("Boom", 0.85, 0.7)
	S:burst(1.5)
	S:phase(0.25, function(k: number)
		white.BackgroundTransparency = 0.05 + 0.95 * outCubic(k)
		blur.Size = 14 * outCubic(k)
		cc.Brightness = -0.12 * k
		cc.Saturation = lerp(-0.25, -0.5, k)
	end)

	-- 6) The name, letter by letter, huge, with RGB split.
	local band = S:frame({
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.42),
		BackgroundTransparency = 0,
		ZIndex = 40,
	})
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
		Parent = band,
	})
	local name = string.upper(a.name)
	local n = utf8.len(name) or #name
	local maxText = math.floor(150 * S.vs + 0.5)
	local function nameLabel(color: Color3, tr: number, z: number): TextLabel
		local l = S:text({
			Text = name,
			FontFace = Kit.Title,
			TextScaled = true,
			TextColor3 = color,
			TextTransparency = tr,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.2),
			MaxVisibleGraphemes = 0,
			ZIndex = z,
		})
		Kit.new("UITextSizeConstraint", { MaxTextSize = maxText, Parent = l })
		Kit.new("UIScale", { Parent = l })
		return l
	end
	local cyanL = nameLabel(P.Cyan, 0.35, 44)
	local magL = nameLabel(P.Magenta, 0.35, 44)
	local mainL = nameLabel(WHITE, 0, 46)
	Kit.new("UIGradient", {
		Color = ColorSequence.new(a.color:Lerp(WHITE, 0.45), a.color2:Lerp(WHITE, 0.2)),
		Rotation = 90,
		Parent = mainL,
	})
	Kit.new("UIStroke", {
		Thickness = 3,
		Color = if brightness(a.color) < 0.4 then WHITE else BLACK,
		Transparency = 0.25,
		Parent = mainL,
	})
	local sub = S:text({
		Text = "",
		FontFace = Kit.MonoBold,
		TextSize = math.floor(20 * S.vs + 0.5),
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.615),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 46,
	})
	local newL = S:text({
		Text = "",
		FontFace = Kit.MonoBold,
		TextSize = math.floor(18 * S.vs + 0.5),
		TextColor3 = P.Lime,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.385),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 46,
	})
	for _, l in { sub, newL } do
		Kit.new("UIStroke", { Thickness = 2, Color = BLACK, Transparency = 0.3, Parent = l })
	end

	local labels = { mainL, cyanL, magL }
	local popAt = -10
	local jitter = 1
	S:loop(function(now: number)
		local pop = 1 + 0.22 * math.exp(-11 * (now - popAt))
		local j = 6 * S.vs * jitter
		for i, l in labels do
			local sc = l:FindFirstChildOfClass("UIScale")
			if sc then
				sc.Scale = pop
			end
			if i == 2 then
				l.Position = UDim2.new(0.5, -j - S.rng:NextNumber(0, 6) * jitter, 0.5, S.rng:NextNumber(-2, 2) * jitter)
			elseif i == 3 then
				l.Position = UDim2.new(0.5, j + S.rng:NextNumber(0, 6) * jitter, 0.5, S.rng:NextNumber(-2, 2) * jitter)
			end
		end
		return false
	end)

	if info.first then
		local txt = "> NEW SIGNATURE DISCOVERED <"
		local last = 0
		S:sfx("Announce", 0.6, 1)
		S:phase(0.7, function(_: number, e: number)
			local c = math.min(#txt, math.floor(e * 55))
			newL.Text = txt:sub(1, c)
			if c ~= last and c % 2 == 0 then
				S:sfx("Type", 0.3, 1.1)
			end
			last = c
		end)
		newL.Text = txt
	end

	local per = math.clamp(1.5 / n, 0.08, 0.17)
	local shown = 0
	S:phase(per * n + 0.08, function(_: number, e: number)
		local c = math.min(n, math.floor(e / per) + 1)
		if c ~= shown then
			shown = c
			for _, l in labels do
				l.MaxVisibleGraphemes = c
			end
			popAt = os.clock()
			S:sfx("Type", 0.6, 0.8 + (c / n) * 0.6)
			S:sfx("Glitch", 0.2, 1.4)
		end
	end)
	for _, l in labels do
		l.MaxVisibleGraphemes = -1
	end

	-- Name complete: the big hit.
	popAt = os.clock()
	S:sfx("Boom", 1, 0.8)
	S:sfx("Reveal5", 0.6, 1)
	S:burst(3.2)
	S:worldFlash(acol, 0.9)
	S:ring(42, WHITE, 1.1, 2.2, 5)
	S:ring(42, acol, 1.5, 1.8, 3)
	local subText = "[ "
		.. S.tier.name
		.. " ]   "
		.. RNG.ChanceText(a.chance)
		.. (if S.exclusive then "   //   " .. S.biomeName .. " EXCLUSIVE" else "")
	local lastC = 0
	S:phase(1.3, function(_: number, e: number)
		white.BackgroundTransparency = 0.55 + 0.45 * outCubic(clamp01(e / 0.3))
		jitter = lerp(1, 0.25, clamp01(e / 0.8))
		local c = math.min(#subText, math.floor(seg(e, 0.25, 0.9) * #subText))
		sub.Text = subText:sub(1, c)
		if c ~= lastC and c % 3 == 0 then
			S:sfx("Type", 0.25, 1.2)
		end
		lastC = c
	end)
	sub.Text = subText

	-- 7) Final white-out into the reveal.
	S:sfx("Riser", 0.4, 1.8)
	S:phase(0.5, function(k: number)
		white.BackgroundTransparency = 1 - inCubic(k)
		jitter = 0.25 + 1.5 * k
		for _, l in labels do
			local sc = l:FindFirstChildOfClass("UIScale")
			if sc then
				sc.Scale = 1 + 0.15 * k
			end
		end
	end)
	S:peakCut(white)
	S:raw(0.7, function(k: number)
		white.BackgroundTransparency = outCubic(k)
		S:duck(k)
	end)
end

return { level1, level2, level3, level4, level5 } :: { (any) -> () }
