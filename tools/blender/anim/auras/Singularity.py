# Singularity (1 in 150,000,000, SINGULARITY tier): "All data collapses into one point."
# White core star above the head, galaxy spiral round the waist, gravitational rings, sky beams.
# A cinematic showpiece: the body levitates (A.lift = 2.4 studs) and PERFORMS the collapse.
#
# IDLE (6.0 s = 180 f, the VFX collapse/burst rhythm follows these markers exactly):
#   0-36    OPEN      floating star-gazer: arms spread palms-up, chest open, head tilted to the
#           star, dangling legs drift out of phase; slow weight sway (torso leads, head lags 4 f).
#   36-48   anticipation dip (arms sink, body drops a little), then
#   48      "gather"  the right arm sweeps up in an arc (the left follows 5 f later)
#                     VFX: hand tips start streaming sparks up to the star, rings start to tighten.
#   62      "reach"   both hands up at the star, back arched, rising toward it
#                     VFX: thin light threads hand -> star flash on.
#   78      "pull"    the hands grab and DRAG the star's mass down: arms crash down to cross over
#                     the chest, torso curls, legs tuck, head bows (78 -> 106)
#                     VFX: galaxy arms, rings, star shells contract toward the core (collapse).
#   108     "collapse" fully curled, minimum size: star dims, implosion particles suck inward.
#   108-124 tremble   (CONST micro-snaps, escalating) - the compressed point vibrates.
#   124     "crack"   head snaps up one beat before the release (star flickers white).
#   128     "burst"   EXPO explosion: arms flung wide and up, back arched, legs splay, body pops
#                     up 0.5 studs. VFX: burst sparks from the star, chest shockwave, ground
#                     shock ring, beams/rings overshoot outward, light flare, hand bursts.
#   134     overshoot / follow-through (head lags to 138)
#   150     "echo"    secondary recoil flick of the arms (aftershock): small second ring pulse.
#   160-180 BACK-eased settle into OPEN (loop).
#
# WALK (one stride, lib.STRIDE): comet glide. Hovering 2.3 studs up, torso pitched forward and
#   banking into each half-stride, arms swept back as the comet tail (wave lagging the torso),
#   legs trail and flutter-kick (right leg forward on frame 0, left on half).
#   0  "kick" "L"  the trailing left leg snaps back = thrust: ripple + spark puff under that foot.
#   h  "kick" "R"  mirror.
#
# REACTIONS (one-shots, mode "add" so they ride on top of idle or walk):
#   launch  (trigger "jump", 0.8 s): legs tuck, arms whip down then flare, body rises.
#           marker 3 "launch" -> VFX: ground ring burst + star flare.
#   regrav  (trigger "land", 0.9 s): gravity re-grabs the body: knees up, dip, overshoot, settle.
#           marker 2 "impact" -> VFX: ground shock + sigil flash + floor sparks.
#   flare   (trigger "flare", emitted by the VFX every ~5 s while gliding, 1.3 s): the star
#           throws off a flare - head snaps up, the right hand reaches up and catches it, pulls
#           it in, and flings it back into the comet tail.
#           marker 13 "catch" -> VFX: light thread star -> right hand + hand spark burst.
#           marker 27 "fling" -> VFX: streak of sparks thrown backward from the right hand.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Singularity")
LIFT = 2.4

# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames


def body(f, ease="INOUT", **kw):
    idle.key(f, ease=ease, **kw)


# --- OPEN (star-gazer), sway to the left, drifting
body(0, root=(6, 7, 2.5), root_pos=(-0.05, LIFT + 0.02, 0),
     rs=(34, 0, 64), ls=(28, 0, -70), rh=(12, 0, 5), lh=(-8, 0, -3))
idle.key(0, neck=(15, -5, -3))
body(20, root=(4, -5, -2), root_pos=(0.05, LIFT + 0.16, 0),
     rs=(38, 0, 74), ls=(36, 0, -66), rh=(4, 0, 3), lh=(2, 0, -6))
idle.key(24, neck=(18, 4, 3))

# --- anticipation: everything sinks before the gather
body(36, ease="IN", root=(-3, 2, 0), root_pos=(0, LIFT - 0.06, 0),
     rs=(28, 0, 52), ls=(30, 0, -56), rh=(14, 0, 2), lh=(10, 0, -3))
idle.key(39, neck=(4, 0, 0))

# --- GATHER: the right arm sweeps up in an arc, the left lags behind
body(48, ease="EXPO", root=(4, 12, -3), root_pos=(0.04, LIFT + 0.12, 0),
     rs=(150, -6, 38), rh=(-4, 0, 4), lh=(4, 0, -4))
idle.key(53, ease="EXPO", ls=(118, 0, -52))
idle.key(51, neck=(22, 10, -4))
idle.marker(48, "gather")

# --- REACH: both hands up at the star, arched, rising
body(62, root=(11, -2, 0), root_pos=(0, LIFT + 0.42, 0),
     rs=(170, 0, -10), ls=(168, 0, 12), rh=(-10, 0, 1.5), lh=(-13, 0, -1.5))
idle.key(66, neck=(30, -2, 0))
idle.marker(62, "reach")
body(72, root=(13, 1, 1), root_pos=(0, LIFT + 0.5, 0),  # held, still stretching (overshoot)
     rs=(176, 0, -16), ls=(176, 0, 17), rh=(-12, 0, 1), lh=(-15, 0, -1))
idle.key(75, neck=(32, 1, 1))

# --- PULL: grab and drag the mass down (EXPO = the snap of the grab)
idle.marker(78, "pull")
body(84, ease="EXPO", root=(2, 0, 0), root_pos=(0, LIFT + 0.36, 0),
     rs=(132, -4, 18), ls=(128, 4, -18), rh=(4, 0, 2), lh=(2, 0, -2))
idle.key(87, neck=(18, 0, 0))
body(96, root=(-14, -3, 1), root_pos=(0, LIFT + 0.1, 0),
     rs=(86, 22, 30), ls=(84, -22, -30), rh=(30, 0, 3), lh=(36, 0, -3))
idle.key(99, neck=(-10, 0, 0))

# --- COLLAPSE: curled into a ball, arms crossed over the chest
body(106, ease="OUT", root=(-30, 0, 0), root_pos=(0, LIFT - 0.08, 0.1),
     rs=(70, 0, -62), ls=(76, 0, 60), rh=(64, 0, 6), lh=(70, 0, -6))
idle.key(110, neck=(-30, 0, 0))
idle.marker(108, "collapse")

# --- tremble: escalating CONST micro-snaps (the compressed point vibrates)
for i, f in enumerate(range(110, 124, 2)):
    k = (i + 1) / 7
    s = 1 if i % 2 == 0 else -1
    body(f, ease="CONST",
         root=(-30 + 1.2 * k * s, 1.5 * k * s, -2.2 * k * s),
         root_pos=(0.04 * k * s, LIFT - 0.1 - 0.04 * k, 0.1),
         rs=(70 + 3 * k * s, 0, -62 - 3 * k), ls=(76 - 3 * k * s, 0, 60 + 3 * k))

# --- CRACK: the head snaps up one beat before the release
body(124, ease="CONST", root=(-26, 0, 0), root_pos=(0, LIFT - 0.16, 0.1),
     rs=(68, 0, -66), ls=(74, 0, 64), rh=(70, 0, 6), lh=(76, 0, -6))
idle.key(124, ease="CONST", neck=(18, 0, 0))
idle.marker(124, "crack")

# --- BURST: explosion open
idle.marker(128, "burst")
body(129, ease="EXPO", root=(22, 0, 0), root_pos=(0, LIFT + 0.5, -0.05),
     rs=(18, 0, 142), ls=(14, 0, -146), rh=(-24, 0, 20), lh=(-30, 0, -22))
idle.key(131, ease="EXPO", neck=(30, 0, 0))
body(135, root=(26, -3, 1), root_pos=(0, LIFT + 0.6, -0.05),  # follow-through
     rs=(22, 0, 152), ls=(18, 0, -156), rh=(-28, 0, 24), lh=(-34, 0, -26))
idle.key(139, neck=(36, -3, 2))

# --- ECHO: aftershock recoil and secondary flick
body(146, root=(3, -2, 0), root_pos=(0, LIFT + 0.24, 0),
     rs=(34, 0, 84), ls=(30, 0, -88), rh=(0, 0, 6), lh=(-4, 0, -7))
idle.key(149, neck=(10, -2, 0))
body(151, ease="EXPO", root=(9, 1, 0), root_pos=(0, LIFT + 0.3, 0),
     rs=(40, 0, 108), ls=(36, 0, -112))
idle.marker(150, "echo")

# --- settle into OPEN (the loop key at 180 = frame 0)
body(162, ease="BACK", root=(5, 5, 1.5), root_pos=(-0.03, LIFT + 0.06, 0),
     rs=(32, 0, 68), ls=(28, 0, -72), rh=(10, 0, 5), lh=(-6, 0, -4))
idle.key(165, ease="BACK", neck=(14, -3, -2))

idle.loop()
# organic drift on top (periodic -> seamless)
idle.noise("root", 1, 1.6, cycles=(1, 2, 3), seed=3)
idle.noise("root", 2, 1.0, cycles=(2, 3), seed=4)
idle.noise("neck", 1, 2.5, cycles=(1, 3, 4), seed=5)
idle.noise("rh", 0, 3.0, cycles=(2, 3), seed=6)
idle.noise("lh", 0, 3.0, cycles=(2, 5), seed=7)
idle.noise("rs", 2, 2.0, cycles=(2, 3), seed=8)
idle.noise("ls", 2, 2.0, cycles=(3, 4), seed=9)
idle.noise("root", 1, 0.06, cycles=(1, 2), seed=10, loc=True)  # breathing float bob

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # ~21 frames
h = walk.frames / 2
WY = 2.3


def glide(f, side):
    s = 1 if side == "R" else -1  # +1: right leg forward (left trails and kicks)
    walk.key(f, ease="EXPO",
             root=(-24, -6 * s, 4 * s), root_pos=(0, WY - 0.04, 0),
             neck=(20, 6 * s, -3 * s),
             rs=(-46 - 7 * s, 0, 22 + 4 * s), ls=(-46 + 7 * s, 0, -22 + 4 * s),
             rh=(12 * s - 20, 0, 3), lh=(-12 * s - 20, 0, -3))
    walk.marker(f, "kick", "L" if s > 0 else "R")


def drift(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, root=(-21, 0, 1 * s), root_pos=(0, WY + 0.1, 0),
             neck=(17, 0, 0),
             rs=(-58 + 5 * s, 0, 28), ls=(-58 - 5 * s, 0, -28),  # the tail ripples (lags)
             rh=(-24, 0, 4), lh=(-24, 0, -4))


glide(0, "R")
drift(h * 0.55, "R")
glide(h, "L")
drift(h * 1.55, "L")
walk.loop()

# ------------------------------------------------------------------ reactions (additive)
launch = A.clip("launch", seconds=0.8, trigger="jump", mode="add", blend_in=0.04, blend_out=0.2)
launch.key(0, root=(0, 0, 0), root_pos=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0), neck=(0, 0, 0))
launch.key(3, ease="EXPO", root=(-8, 0, 0), root_pos=(0, 0.1, 0), rs=(-25, 0, -22), ls=(-25, 0, 22),
           rh=(40, 0, 0), lh=(46, 0, 0), neck=(-8, 0, 0))
launch.marker(3, "launch")
launch.key(10, ease="BACK", root=(8, 0, 0), root_pos=(0, 0.35, 0), rs=(10, 0, 30), ls=(10, 0, -30),
           rh=(-10, 0, 6), lh=(-12, 0, -6), neck=(12, 0, 0))
launch.key(24, root=(0, 0, 0), root_pos=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0), neck=(0, 0, 0))

regrav = A.clip("regrav", seconds=0.9, trigger="land", mode="add", blend_in=0.03, blend_out=0.2)
regrav.key(0, root=(0, 0, 0), root_pos=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0), neck=(0, 0, 0))
regrav.key(1, ease="LINEAR", root_pos=(0, 0.04, 0))  # legs start tucking before the dip
regrav.key(3, ease="EXPO", root=(-12, 0, 0), root_pos=(0, -0.13, 0), rs=(18, 0, -18), ls=(18, 0, 18),
           rh=(74, 0, 4), lh=(78, 0, -4), neck=(-14, 0, 0))
regrav.marker(2, "impact")
regrav.key(11, ease="BACK", root=(5, 0, 0), root_pos=(0, 0.12, 0), rs=(-6, 0, 16), ls=(-6, 0, -16),
           rh=(-6, 0, 2), lh=(-8, 0, -2), neck=(6, 0, 0))
regrav.key(27, root=(0, 0, 0), root_pos=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0), neck=(0, 0, 0))

flare = A.clip("flare", seconds=1.3, trigger="flare", mode="add", blend_in=0.06, blend_out=0.25)
flare.key(0, root=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), neck=(0, 0, 0))
flare.key(4, ease="EXPO", neck=(26, 6, 0), root=(6, 4, 0))  # head snaps up to the star
flare.key(6, ease="IN", rs=(-12, 0, -6))  # anticipation: the hand dips first
flare.key(13, ease="BACK", rs=(150, 0, -8), ls=(10, 0, -10), root=(9, 6, -2), neck=(30, 10, 0))
flare.marker(13, "catch")
flare.key(20, rs=(95, 0, -2), neck=(10, 4, 0), root=(3, 2, 0))  # pulls it in to the chest
flare.key(27, ease="EXPO", rs=(-38, 0, 14), ls=(-6, 0, -4), root=(-4, -6, 2), neck=(4, -8, 0))  # fling back
flare.marker(27, "fling")
flare.key(39, rs=(0, 0, 0), ls=(0, 0, 0), root=(0, 0, 0), neck=(0, 0, 0))

A.lift = LIFT

# Preview framing for a levitating set (local helper, lib.py untouched): aim the contact-sheet
# camera 2.4 studs higher and widen it so the raised head and arms stay in frame.
_aim0 = lib._aim
lib._aim = lambda cam, loc, target=(0, 0, 2.6): _aim0(cam, (loc[0], loc[1], loc[2] + LIFT), (target[0], target[1], target[2] + LIFT))
A.cam.data.ortho_scale = 10.5
A.finish(preview=False)
A.preview(frames_per_clip=int(os.environ.get("SING_FRAMES", "10")))
