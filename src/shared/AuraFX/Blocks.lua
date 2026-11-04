--!strict
-- AuraFX/Blocks: reusable composite building blocks (segment rings, beam circles,
-- body clones / afterimages, lightning, hex plates, polylines). All anchors are root-local.

local Core = require(script.Parent.Core)

type Ctx = Core.Ctx

local TAU = Core.TAU
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local Blocks = {}

---------------------------------------------------------------- math helpers

function Blocks.bez(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, s: number): Vector3
	local u = 1 - s
	return p0 * (u * u * u) + p1 * (3 * u * u * s) + p2 * (3 * u * s * s) + p3 * (s * s * s)
end

-- Reflect a root-local CFrame across the root's YZ plane.
function Blocks.mirrorX(l: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = l:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- Reflect a root-local CFrame across the horizontal plane y = plane.
function Blocks.mirrorY(l: CFrame, plane: number): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = l:GetComponents()
	return CFrame.new(x, 2 * plane - y, z, r00, -r01, r02, -r10, r11, -r12, r20, -r21, r22)
end

-- Point on a horizontal circle (root-local).
function Blocks.onCircle(r: number, a: number, y: number): Vector3
	return V(math.cos(a) * r, y, math.sin(a) * r)
end

---------------------------------------------------------------- segment ring

export type RingOpts = {
	n: number,
	radius: number,
	seg: Vector3, -- X radial thickness, Y height, Z tangential length (0 = auto)
	color: Color3,
	color2: Color3?, -- alternating colour
	mat: Enum.Material?,
	tr: number?,
	shape: Enum.PartType?,
	anchor: (t: number) -> CFrame, -- ring lies in the anchor's XZ plane
	spin: number?, -- rad/s
	gap: number?, -- every gap-th segment is omitted
	wave: number?, -- vertical wave amplitude
	waveFreq: number?,
	waveSpeed: number?,
	radiusFn: ((t: number) -> number)?,
	paint: ((k: number, t: number, p: BasePart, a: number) -> ())?,
}

function Blocks.ring(c: Ctx, o: RingOpts): { BasePart }
	local parts: { BasePart } = {}
	local angles: { number } = {}
	local tang = if o.seg.Z > 0 then o.seg.Z else TAU * o.radius / o.n * 0.72
	for i = 1, o.n do
		if o.gap and i % o.gap == 0 then
			continue
		end
		local col = if o.color2 and i % 2 == 0 then o.color2 else o.color
		local p = Core.part(c, V(o.seg.X, o.seg.Y, tang), col, o.mat, o.tr, o.shape)
		table.insert(parts, p)
		table.insert(angles, (i - 1) / o.n * TAU)
	end
	local spin = o.spin or 0
	local wave = o.wave or 0
	local wf = o.waveFreq or 3
	local ws = o.waveSpeed or 2
	local paint = o.paint
	Core.on(c, function(t, _, root)
		local base = root * o.anchor(t)
		local r = if o.radiusFn then o.radiusFn(t) else o.radius
		local rot = t * spin
		for k, p in parts do
			local a = angles[k] + rot
			local y = if wave ~= 0 then math.sin(a * wf + t * ws) * wave else 0
			Core.put(p, base * ANG(0, -a, 0) * CF(r, y, 0))
			if paint then
				paint(k, t, p, a)
			end
		end
	end)
	return parts
end

---------------------------------------------------------------- beam circle

export type CircleOpts = {
	radius: number,
	color: Color3,
	width: number,
	anchor: ((t: number) -> CFrame)?, -- dynamic; omit for a static circle at `at`
	at: CFrame?,
	n: number?,
	color2: Color3?,
	tr: number?,
	radiusFn: ((t: number) -> number)?,
	parent: BasePart?,
	bright: number?,
}

export type Circle = { beams: { Beam }, atts: { Attachment } }

-- Smooth circle from n cubic-bezier beams (tangent-aligned attachments).
function Blocks.circle(c: Ctx, o: CircleOpts): Circle
	local n = o.n or 6
	local k = 4 / 3 * math.tan(math.pi / (2 * n))
	local atts: { Attachment } = {}
	local beams: { Beam } = {}
	for i = 1, n do
		atts[i] = Core.att(c, o.parent)
	end
	local tr = Core.ns(o.tr or 0)
	for i = 1, n do
		beams[i] = Core.beam(c, atts[i], atts[i % n + 1], o.color, o.width, {
			color2 = o.color2,
			tr = tr,
			segs = 8,
			bright = o.bright,
		})
	end
	local lastR = -1
	local function place(t: number)
		local r = if o.radiusFn then o.radiusFn(t) else o.radius
		local base = if o.anchor then o.anchor(t) else (o.at or CFrame.identity)
		for i, a in atts do
			local ang = (i - 1) / n * TAU
			local cs, sn = math.cos(ang), math.sin(ang)
			a.CFrame = base * CFrame.fromMatrix(V(cs * r, 0, sn * r), V(-sn, 0, cs), Vector3.yAxis)
		end
		if r ~= lastR then
			lastR = r
			for _, b in beams do
				b.CurveSize0 = k * r
				b.CurveSize1 = k * r
			end
		end
	end
	place(os.clock())
	if o.anchor or o.radiusFn then
		Core.on(c, function(t)
			place(t)
		end)
	end
	return { beams = beams, atts = atts }
end

function Blocks.setBeamsTransparency(beams: { Beam }, tr: number)
	local s = NumberSequence.new(math.clamp(tr, 0, 1))
	for _, b in beams do
		b.Transparency = s
	end
end

function Blocks.setBeamsColor(beams: { Beam }, col: Color3)
	local s = ColorSequence.new(col)
	for _, b in beams do
		b.Color = s
	end
end

---------------------------------------------------------------- polyline

export type Poly = { beams: { Beam }, atts: { Attachment } }

-- Polyline of beams through root-local points (attachments can be moved later).
function Blocks.poly(
	c: Ctx,
	pts: { Vector3 },
	color: Color3,
	width: number,
	opts: Core.BeamOpts?,
	parent: BasePart?
): Poly
	local atts: { Attachment } = {}
	local beams: { Beam } = {}
	for i, p in pts do
		atts[i] = Core.att(c, parent, CF(p))
	end
	for i = 1, #pts - 1 do
		beams[i] = Core.beam(c, atts[i], atts[i + 1], color, width, opts)
	end
	return { beams = beams, atts = atts }
end

---------------------------------------------------------------- body clones

export type CloneOpts = {
	set: string?, -- "full" | "lite" | "core"
	color: Color3,
	mat: Enum.Material?,
	tr: number?,
	scale: number?,
	delay: number?, -- seconds behind the live pose
	fps: number?, -- quantise sampled time (stutter)
	map: ((cf: CFrame, root: CFrame, t: number) -> CFrame)?,
}

function Blocks.clones(c: Ctx, o: CloneOpts): { BasePart }
	local names = Core.SETS[o.set or "lite"] or Core.SETS.lite
	local parts: { BasePart } = {}
	local idx: { number } = {}
	for i, src in c.body do
		if names[src.Name] then
			table.insert(parts, Core.cloneShape(c, src, o.color, o.mat, o.tr, o.scale))
			table.insert(idx, i)
		end
	end
	local delay = o.delay or 0
	local fps = o.fps
	if delay > 0 then
		Core.useHistory(c)
	end
	local map = o.map
	Core.on(c, function(t, _, root)
		local pose: { CFrame }? = nil
		if delay > 0 then
			local at = t - delay
			if fps then
				at = math.floor(at * fps) / fps
			end
			pose = Core.sample(c, at)
		end
		for k, p in parts do
			local i = idx[k]
			local cf = if pose and pose[i] then pose[i] else c.body[i].CFrame
			if map then
				cf = map(cf, root, t)
			end
			Core.put(p, cf)
		end
	end)
	return parts
end

-- map helper: shift a clone by a root-local offset
function Blocks.offsetMap(offset: (t: number) -> CFrame): (cf: CFrame, root: CFrame, t: number) -> CFrame
	return function(cf: CFrame, root: CFrame, t: number): CFrame
		return root * offset(t) * root:ToObjectSpace(cf)
	end
end

---------------------------------------------------------------- lightning

export type BoltOpts = {
	segs: number,
	color: Color3,
	color2: Color3?,
	width: number,
	jitter: number,
	interval: number,
	ends: (t: number) -> (Vector3, Vector3), -- root-local start / end
	flicker: number?, -- chance a regeneration hides the bolt
	active: ((t: number) -> boolean)?,
	parent: BasePart?,
}

function Blocks.bolt(c: Ctx, o: BoltOpts): { Beam }
	local atts: { Attachment } = {}
	local beams: { Beam } = {}
	for i = 1, o.segs + 1 do
		atts[i] = Core.att(c, o.parent)
	end
	for i = 1, o.segs do
		local f = (i - 1) / o.segs
		beams[i] = Core.beam(c, atts[i], atts[i + 1], o.color, o.width * (1 - f * 0.6), {
			color2 = o.color2,
			w1 = o.width * (1 - (f + 1 / o.segs) * 0.6),
			segs = 1,
			bright = 3,
		})
	end
	local rng = c.rng
	local nextT = 0
	local shown = true
	Core.on(c, function(t)
		local act = if o.active then o.active(t) else true
		if not act then
			if shown then
				shown = false
				for _, b in beams do
					b.Enabled = false
				end
			end
			return
		end
		if t < nextT then
			return
		end
		nextT = t + o.interval * (0.6 + rng:NextNumber() * 0.8)
		local a, b = o.ends(t)
		local dir = b - a
		local len = dir.Magnitude
		local fwd = if len > 1e-3 then dir / len else Vector3.yAxis
		local ref = if math.abs(fwd.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis
		local side = fwd:Cross(ref).Unit
		local up = side:Cross(fwd)
		local show = not (o.flicker and rng:NextNumber() < o.flicker)
		for i = 0, o.segs do
			local f = i / o.segs
			local env = math.sin(f * math.pi)
			local off = (side * (rng:NextNumber() - 0.5) + up * (rng:NextNumber() - 0.5)) * (2 * o.jitter * env)
			atts[i + 1].Position = a + dir * f + off
		end
		shown = show
		for _, bm in beams do
			bm.Enabled = show
		end
	end)
	return beams
end

---------------------------------------------------------------- hex plates / triangles

-- Regular hexagon from three overlapping rectangles, lying in the local XZ plane.
function Blocks.hex(c: Ctx, R: number, thick: number, color: Color3, mat: Enum.Material?, tr: number?): { BasePart }
	local out: { BasePart } = {}
	for i = 1, 3 do
		out[i] = Core.part(c, V(R, thick * (1 - (i - 1) * 0.04), math.sqrt(3) * R), color, mat, tr)
	end
	return out
end

function Blocks.putHex(parts: { BasePart }, cf: CFrame)
	for i, p in parts do
		Core.put(p, cf * ANG(0, (i - 1) * math.pi / 3, 0))
	end
end

-- Equilateral triangle outline from three bars, in the local XY plane.
function Blocks.tri(c: Ctx, side: number, bar: number, color: Color3): { BasePart }
	local out: { BasePart } = {}
	for i = 1, 3 do
		out[i] = Core.part(c, V(side + bar, bar, bar * 0.6), color)
	end
	return out
end

function Blocks.putTri(parts: { BasePart }, cf: CFrame, side: number)
	local inr = side / (2 * math.sqrt(3))
	for i, p in parts do
		Core.put(p, cf * ANG(0, 0, (i - 1) * TAU / 3) * CF(0, -inr, 0))
	end
end

---------------------------------------------------------------- glyph helpers

-- Floating glyph on its own root attachment; returns attachment + label.
function Blocks.glyph(
	c: Ctx,
	text: string,
	color: Color3,
	size: Vector2,
	font: Font?,
	at: CFrame?,
	stroke: Color3?
): (Attachment, TextLabel, BillboardGui)
	local a = Core.att(c, nil, at)
	local g, l = Core.glyph(c, a, text, color, size, font, stroke)
	return a, l, g
end

return Blocks
