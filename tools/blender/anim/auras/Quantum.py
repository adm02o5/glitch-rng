# Quantum (1 in 250,000, LEGENDARY): "Both rolled and not rolled."
# VFX (AurasHigh.lua A.Quantum): three tilted electron orbit rings with electrons (quantum jumps =
# a flash at the old AND the new spot), two superposition ghosts of the body (a ForceField one and a
# neon one) standing 2.6 studs to either side and swapping sides every half loop, a nucleus atom over
# the head, a probability wave ring at the feet, a sigil, sparks and a violet light.
#
# CONCEPT: a body that is in two states at once. It hovers LOW (A.lift = 0.8 studs: legs hang
# loose), calm and weightless between the events, then breaks physics in CONST snaps: it TUNNELS
# (the whole body is in one spot, then another, then home within 6 frames, arms in a different pose
# in every state), it flicks electrons out of their orbits, and it LOOKS at its ghosts: observing a
# superposition collapses it.
#
# IDLE (6.0 s = 180 f; the ghosts swap sides on Sync.phase(bus, 6.0) = at 0 and 90).
#   Markers -> what the VFX does:
#   0-20    calm hover, arms out and forward cradling the orbits, legs dangling apart
#   22      anticipation: the right hand curls in, the torso winds up to the left
#   28      "flick" "R"   EXPO: the right hand flings out to the side, torso follows, head 2 f late.
#                         VFX: an electron quantum-jumps (flash at both spots), sparks spray from
#                         the right hand.
#   40      "tunnel" "L"  CONST: the body is suddenly 0.6 studs LEFT, turned, other arm pose
#   43      "tunnel" "R"  CONST: ... now 0.6 studs RIGHT, mirrored pose.
#                         VFX on both: a flash where the body is now, the ghost on that side blazes.
#   46      "collapse"    CONST: back home. VFX: both ghosts snap fully visible then fade, the
#                         probability wave pulses outward, a spark burst from the chest.
#   60-82   the head slowly turns to the ghost on the RIGHT, the torso leans to it
#   84      "observe" "R" EXPO: the head darts in, the right hand points at it. VFX: that ghost
#                         flashes solid white-violet and COLLAPSES (vanishes ~0.6 s, then fades back).
#   90      (ghosts swap sides)
#   100-112 arms float up and wide, the body rises 0.45 studs, legs trail together
#   114     "split"       BACK: arms snap open into a wide T, chest out, head 2 f and legs 4 f later.
#                         VFX: SUPERPOSITION: both ghosts at full strength, all three electrons
#                         jump at once, the electron rings swell, a white flash, light surge.
#   126-132 floats back down
#   134/140 "flick" "L"   the mirrored flick with the LEFT hand
#   150/153 "tunnel" "R"/"L", 156 "collapse"   the mirrored tunnel triplet
#   166     "observe" "L" the head darts to the LEFT ghost
#
# WALK (one stride): a forward-leaning hover glide 0.65 studs up, arms swept back and out, legs
#   trailing in a slow scissor. Frame 7 "tunnel" "w": CONST, the body jumps 0.45 studs ahead
#   for 3 frames (it tunnels along its path). VFX: a small flash + spark puff at the chest.
#
# REACTIONS:
#   blink (trigger "jump", 0.7 s, add): the body tucks (f2) and snaps open (f5). marker 5 "blink":
#         a flash + an electron jump.
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("Quantum")
LIFT = 0.8

# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames


def rest(sway=0.0, y=0.0):
    """Calm weightless hover. sway -1..1 drifts a touch left .. right."""
    return dict(
        root=(4, 3 * sway, 1.5 * sway),
        root_pos=(0.05 * sway, LIFT + y, 0),
        neck=(3, -4 * sway, -2 * sway),
        rs=(22, 0, 28 + 3 * sway),
        ls=(22, 0, -28 + 3 * sway),
        rh=(10, 0, 4),
        lh=(-5, 0, -3),
    )


def tunnel(f0, first):
    """CONST triplet: home -> first side -> other side -> home (f0, f0+3, f0+6)."""
    s = 1 if first == "R" else -1
    idle.key(f0 - 1, ease="CONST", root_pos=(0, LIFT + 0.06, 0), root=(4, 0, 0), rs=(22, 0, 28), ls=(22, 0, -28),
             neck=(3, 0, 0))
    # state A: displaced to `first`, turned toward it, arms in a different superposed pose
    idle.key(f0, ease="CONST", root_pos=(0.6 * s, LIFT + 0.14, 0.1), root=(2, -16 * s, -5 * s),
             rs=(70, 0, 12) if s > 0 else (-10, 0, 60), ls=(-10, 0, -60) if s > 0 else (70, 0, -12),
             neck=(-6, 12 * s, 6 * s))
    idle.marker(f0, "tunnel", first)
    # state B: the mirrored state on the other side
    idle.key(f0 + 3, ease="CONST", root_pos=(-0.6 * s, LIFT + 0.02, -0.1), root=(6, 16 * s, 5 * s),
             rs=(-10, 0, 60) if s > 0 else (70, 0, 12), ls=(70, 0, -12) if s > 0 else (-10, 0, -60),
             neck=(8, -12 * s, -6 * s))
    idle.marker(f0 + 3, "tunnel", "L" if first == "R" else "R")
    # collapse: home (eases out from here)
    idle.key(f0 + 6, ease="BACK", root_pos=(0, LIFT + 0.06, 0), root=(3, 0, 0), rs=(26, 0, 34), ls=(26, 0, -34),
             neck=(1, 0, 0))
    idle.marker(f0 + 6, "collapse")


idle.pose(0, rest(-1))
idle.key(14, root_pos=(-0.02, LIFT + 0.1, 0), rs=(24, 0, 31), ls=(24, 0, -30), neck=(5, 2, 0))
# FLICK R: wind-up (hand curls in, torso to the left) -> fling out (EXPO), head 2 f late, legs 4 f late
idle.key(22, ease="IN", root=(3, 9, 2), rs=(48, 0, 4), neck=(1, 6, 1), root_pos=(0, LIFT + 0.06, 0))
idle.key(28, ease="EXPO", root=(1, -10, -3), rs=(40, 0, 82), ls=(16, 0, -34), root_pos=(0.06, LIFT + 0.1, 0))
idle.marker(28, "flick", "R")
idle.key(30, ease="EXPO", neck=(4, -16, -4))
idle.key(32, ease="OUT", rh=(-4, 0, 7), lh=(-14, 0, -2))
idle.key(34, root=(2, -8, -2), rs=(36, 0, 76))
tunnel(40, "L")
idle.key(50, rh=(12, 0, 5), lh=(-2, 0, -4))
# OBSERVE R: slow turn of the head to the right ghost, torso leans to it
idle.key(60, root=(4, -2, 0), neck=(2, -12, -2), rs=(22, 0, 30), ls=(20, 0, -28), root_pos=(0, LIFT + 0.04, 0))
idle.key(80, ease="IN", root=(3, -10, -4), neck=(0, -34, -6), rs=(30, 0, 36), root_pos=(0.08, LIFT + 0.0, 0))
idle.key(84, ease="EXPO", root=(-2, -16, -6), neck=(-6, -46, -8), rs=(82, 0, 30), root_pos=(0.14, LIFT + 0.03, 0))
idle.marker(84, "observe", "R")
idle.key(86, ease="OUT", rh=(4, 0, 8), lh=(-12, 0, -2))
idle.key(90, root=(0, -13, -5), neck=(-4, -42, -7), rs=(76, 0, 30))
idle.pose(98, rest(0.2, 0.0))
# RISE -> SPLIT: arms float up and wide, body rises, legs trail together
idle.key(110, ease="IN", root=(8, 0, 0), root_pos=(0, LIFT + 0.45, 0), neck=(12, 0, 0),
         rs=(-6, 0, 122), ls=(-6, 0, -122), rh=(-10, 0, 2), lh=(-8, 0, -2))
idle.key(114, ease="BACK", root=(-3, 0, 0), root_pos=(0, LIFT + 0.36, 0), rs=(-16, 0, 92), ls=(-16, 0, -92))
idle.marker(114, "split")
idle.key(116, ease="BACK", neck=(-4, 0, 0))
idle.key(118, ease="OUT", rh=(14, 0, 12), lh=(-16, 0, -12))
idle.key(124, root=(-1, 0, 0), rs=(-10, 0, 86), ls=(-10, 0, -86), root_pos=(0, LIFT + 0.3, 0), neck=(0, 2, 0))
idle.key(132, root=(4, 2, 1), root_pos=(0, LIFT + 0.08, 0), rs=(18, 0, 34), ls=(18, 0, -32), neck=(3, -2, 0),
         rh=(9, 0, 4), lh=(-4, 0, -3))
# FLICK L
idle.key(134, ease="IN", root=(3, -9, -2), ls=(48, 0, -4), neck=(1, -6, -1))
idle.key(140, ease="EXPO", root=(1, 10, 3), ls=(40, 0, -82), rs=(16, 0, 34), root_pos=(-0.06, LIFT + 0.1, 0))
idle.marker(140, "flick", "L")
idle.key(142, ease="EXPO", neck=(4, 16, 4))
idle.key(144, ease="OUT", rh=(14, 0, 2), lh=(4, 0, -7))
tunnel(150, "R")
# OBSERVE L (quick)
idle.key(162, ease="IN", root=(3, 6, 2), neck=(1, 24, 3), root_pos=(0, LIFT + 0.04, 0))
idle.key(166, ease="EXPO", root=(-1, 12, 4), neck=(-5, 42, 7), ls=(70, 0, -28), root_pos=(-0.1, LIFT + 0.05, 0))
idle.marker(166, "observe", "L")
idle.key(168, ease="OUT", rh=(16, 0, 3), lh=(-6, 0, -7))
idle.key(174, root=(3, 2, 0), neck=(2, 8, 0), ls=(30, 0, -30))
idle.loop()
idle.noise("root", 1, 2.0, cycles=(1, 2, 3), seed=31)
idle.noise("root", 1, 0.05, cycles=(2, 3, 4), seed=32, loc=True)
idle.noise("neck", 1, 2.0, cycles=(1, 3, 4), seed=33)
idle.noise("rh", 0, 4, cycles=(2, 3, 5), seed=34)
idle.noise("lh", 0, 4, cycles=(2, 4, 5), seed=35)
idle.noise("rs", 2, 2, cycles=(2, 3, 4), seed=36)
idle.noise("ls", 2, 2, cycles=(2, 3, 5), seed=37)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2
WY = LIFT - 0.15

walk.key(0, root=(-14, -4, 1), root_pos=(0, WY, 0), neck=(12, 4, 0),
         rs=(-50, 0, 30), ls=(-54, 0, -32), rh=(-8, 0, 4), lh=(-26, 0, -4))
walk.key(6, ease="CONST", root_pos=(0, WY + 0.05, 0), root=(-15, -1, 0))
walk.key(7, ease="CONST", root_pos=(0.08, WY + 0.1, -0.45), root=(-18, 6, -2), rs=(-72, 0, 22), ls=(-66, 0, -20))
walk.marker(7, "tunnel", "w")
walk.key(10, ease="EXPO", root_pos=(0, WY + 0.06, 0), root=(-15, 4, -1), rs=(-54, 0, 32), ls=(-50, 0, -30))
walk.key(h, neck=(13, -4, 0), rh=(-26, 0, 4), lh=(-8, 0, -4))
walk.key(h + 5, root=(-14, -3, 1), root_pos=(0, WY - 0.03, 0), neck=(12, 1, 0))
walk.loop()

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
bl = A.clip("blink", seconds=0.7, trigger="jump", mode="add", blend_in=0.03, blend_out=0.2)
bl.pose(0, Z)
bl.key(2, ease="IN", root=(-10, 0, 0), neck=(-10, 0, 0), rs=(30, 0, -18), ls=(30, 0, 18), rh=(24, 0, 0), lh=(28, 0, 0))
bl.key(5, ease="EXPO", root=(8, 0, 0), root_pos=(0, 0.3, 0), rs=(-14, 0, 40), ls=(-14, 0, -40))
bl.marker(5, "blink")
bl.key(7, ease="EXPO", neck=(10, 0, 0))
bl.key(9, ease="OUT", rh=(-12, 0, 6), lh=(-10, 0, -6))
bl.key(14, root=(3, 0, 0), root_pos=(0, 0.15, 0), rs=(-4, 0, 12), ls=(-4, 0, -12), neck=(4, 0, 0))
bl.pose(21, Z)

A.lift = LIFT

# preview framing for a levitating set (local helper, lib.py untouched)
_aim0 = lib._aim
lib._aim = lambda cam, loc, target=(0, 0, 2.6): _aim0(cam, (loc[0], loc[1], loc[2] + 0.6), (target[0], target[1], target[2] + 0.6))
A.cam.data.ortho_scale = 10


def keysheet(clip, frames, views=("front", "side", "3/4")):
    """Local helper (lib.py untouched): renders the exact frames given (markers / key poses)."""
    rig, sc, cam = A.rig, A.scene, A.cam
    rig.animation_data.action = clip.action
    marks = {}
    for m in clip.action.pose_markers:
        marks.setdefault(m.frame, []).append(m.name[3:])
    tmp = tempfile.mkdtemp(prefix="glitchkeys_")
    tiles = []
    for v in views:
        lib._aim(cam, lib.VIEWS[v])
        for f in frames:
            sc.frame_set(int(f))
            fp = os.path.join(tmp, f"{v.replace('/', '')}_{int(f):04d}.png")
            sc.render.filepath = fp
            bpy.ops.render.render(write_still=True)
            mk = marks.get(int(f))
            tiles.append((fp, f"{v} f{int(f)}" + (f" [{','.join(mk)}]" if mk else "")))
    dst = os.path.join(lib.PREVIEW_DIR, f"{A.id}_{clip.name}_keys.png")
    cmd = ["montage"]
    for fp, label in tiles:
        cmd += ["-label", label, fp]
    cmd += ["-tile", f"{len(frames)}x{len(views)}", "-geometry", "+2+2", "-background", "#111",
            "-fill", "#ddd", "-pointsize", "13", "-title", f"{A.id} / {clip.name} key poses", dst]
    subprocess.run(cmd, check=True, capture_output=True)
    print("[preview]", dst)


A.finish()
if os.environ.get("KEYS", "1") == "1":
    keysheet(idle, [0, 22, 28, 40, 43, 46, 80, 84, 110, 114, 140, 166])
