# Null Pointer (1 in 77,777,777, CORRUPTED tier): "Points at nothing. Nothing points back."
# A pure black void silhouette with a white outline, inverted pixels and a giant cursor arrow.
# CONCEPT: a dangling reference. The body hovers like a puppet whose strings point at nothing
# (A.lift = 1.5 studs, legs hang limp), it POINTS at empty space, stares back at the viewer,
# then gets DEREFERENCED: a segfault - glitch snaps, a frozen null (T-) pose, a dead drop to the
# floor - and the runtime re-points it back up into the air.
#
# IDLE (4.8 s = 144 f; the VFX pointer / inversion rhythm follows these markers exactly):
#   0-16    hover limp, head bowed, weight drifting left; anticipation: head turns right, arm cocks back
#   24      "point" "R"  EXPO: right arm snaps out pointing forward-right, torso turns into it,
#                        head lags 4 f, left arm counters, legs trail.
#                        VFX: the cursor arrow glitch-jumps to the spot the right hand points at
#                        (4 studs along the arm), pixel burst at the hand.
#   28-34   overshoot + settle, 40 head tilts (nothing there), 46 head turns back to the camera
#   52      "deref"      CONST: segfault - broken pose #1 (head cranked, torso jack-knifed)
#                        VFX: the cursor slams into the head, the whole aura INVERTS (white body,
#                        black outline, pixels swap), SIGSEGV glyph flash, white shock at the chest.
#   54, 57  "glitch"     CONST broken poses #2/#3 - VFX: the silhouette jitters, glyphs flicker.
#   60      "null"       CONST: frozen in the rig's null pose (T-pose = "no animation") for 6 f
#                        VFX: inversion held, the pixels freeze, the light cuts out.
#   66      "drop"       gravity: the body falls (IN ease) from 1.5 studs to the floor
#   74      "thud"       impact: squash forward, arms fling forward by inertia, head lags to 80
#                        VFX: floor shock ring, square burst out of the floor, disc flash.
#   84      hanging dead, head on the chest
#   92      "repoint"    EXPO: re-referenced - snapped back up to 1.7 studs, head up, arms flare,
#                        legs trail behind and swing through (follow-through to 98)
#                        VFX: the inversion ends, the cursor flies back above the head, upward
#                        pixel stream from the floor, outline flash.
#   104-110 "point" "L"  mirror point with the left arm (smaller), 124-144 limp settle (BACK)
#
# WALK (one stride, lib.STRIDE): a rigid glide 1.4 studs up, torso pitched forward, the right arm
#   POINTS the way like a cursor, the left arm trails, the legs dangle and pendulum-swing.
#   Frame-skip stutter: on frames 3 and h+3 the whole body CONST-jumps 0.35 studs ahead for 2
#   frames (a dropped frame) and snaps back.
#   3 / h+3 "skip" "R"/"L" -> VFX: a black afterimage of the void silhouette is left behind and
#                             fades, a pixel puff from the pointing hand.
#
# REACTIONS (one-shots, mode "add" on top of idle / walk):
#   poke   (trigger "poke", 0.7 s): emitted by the VFX when the wandering cursor lands on the head
#          while gliding: head snaps back, shoulders flinch, then a dazed shake.
#          marker 1 "deref" -> the same segfault inversion flash as the idle (short).
#   crash  (trigger "land", 0.8 s): touching down after a jump makes the program crash for a
#          moment: CONST shudder poses, then recovery.
#          marker 1 "thud" -> floor shock + square burst;  marker 3 "glitch" -> silhouette jitter.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("NullPointer")
LIFT = 1.5

# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.8)  # 144 frames


def hold(clip, f):
    """Freeze every animated channel at frame f with a CONSTANT key, so the next key is a hard
    snap (lib ease names shape the segment LEAVING a key; this guarantees no in-between)."""
    for fc in clip.all_curves():
        k = fc.keyframe_points.insert(f, fc.evaluate(f))
        k.interpolation = "CONSTANT"
        fc.update()


def limp(sway, y=0.0):
    """Hovering puppet at rest. sway -1..1 = weight drifting left .. right."""
    return dict(
        root=(-2, 4 * sway, -2 * sway),
        root_pos=(0.05 * sway, LIFT + y, 0),
        neck=(-10, -5 * sway, 3 * sway),
        rs=(7, 0, 6 + 2 * sway),
        ls=(6, 0, -6 + 2 * sway),
        rh=(9 + 2 * sway, 0, 3),
        lh=(4 - 2 * sway, 0, -3),
    )


idle.pose(0, limp(-1))
idle.key(8, root_pos=(-0.05, LIFT - 0.07, 0), neck=(-12, 4, -3), rs=(8, 0, 5), ls=(7, 0, -5))  # breath out
# anticipation: something to the right - head turns first, the arm cocks back, torso coils left
idle.key(16, ease="EXPO", root=(0, 5, 2), root_pos=(-0.04, LIFT - 0.05, 0),
         neck=(-4, -20, -6), rs=(-12, 0, 12), ls=(2, 0, -8), rh=(12, 0, 4), lh=(5, 0, -3))
# POINT (right): EXPO snap, torso turns into it, the head is still on the way (lags 4 f)
idle.key(24, root=(2, -14, -4), root_pos=(0.06, LIFT + 0.05, 0),
         neck=(-4, -12, -2), rs=(98, -50, 0), ls=(-8, 0, -12), rh=(4, 0, 5), lh=(12, 0, -2))
idle.marker(24, "point", "R")
idle.key(28, neck=(2, -26, -6), rs=(103, -55, 0), root=(3, -17, -5), lh=(8, 0, -3), rh=(2, 0, 4))
idle.key(34, rs=(96, -47, 0), root=(2, -13, -4), neck=(0, -22, -4), ls=(-3, 0, -9), rh=(6, 0, 4), lh=(10, 0, -3))
# ... nothing there: the head tilts, puzzled (arm holds the point)
idle.key(40, neck=(-2, -18, 22), root=(1, -12, -2), rs=(97, -48, 0))
# ... and slowly turns back to stare at the viewer: nothing points back
idle.key(46, neck=(-7, 0, 15), root=(0, -10, -2), rs=(95, -46, 2), root_pos=(0.04, LIFT + 0.03, 0))
idle.key(50, ease="LINEAR", neck=(-8, 1, 13), rs=(95, -45, 2))  # held breath before the segfault
hold(idle, 51)
# DEREF: segfault, three CONST broken poses
idle.key(52, ease="CONST", root=(-14, 22, 11), root_pos=(0.3, LIFT + 0.15, 0.1),
         neck=(-22, 28, -34), rs=(150, 0, 42), ls=(40, 0, -72), rh=(-22, 0, 16), lh=(26, 0, -12))
idle.marker(52, "deref")
idle.key(54, ease="CONST", root=(9, -16, -12), root_pos=(-0.35, LIFT - 0.1, -0.2),
         neck=(16, -32, 26), rs=(18, 0, 86), ls=(158, 0, -18), rh=(20, 0, 2), lh=(-18, 0, -14))
idle.marker(54, "glitch")
idle.key(57, ease="CONST", root=(-8, 30, 6), root_pos=(0.18, LIFT + 0.06, 0.12),
         neck=(-30, 12, -18), rs=(120, 0, 30), ls=(60, 0, -95), rh=(-10, 0, 10), lh=(14, 0, -6))
idle.marker(57, "glitch")
# NULL: the rig's reference pose, frozen
NULL = dict(root=(0, 0, 0), root_pos=(0, LIFT, 0), neck=(0, 0, 0), rs=(0, 0, 90), ls=(0, 0, -90), rh=(0, 0, 0), lh=(0, 0, 0))
idle.pose(60, NULL, ease="CONST")
idle.marker(60, "null")
idle.pose(66, NULL, ease="IN")  # hold, then gravity takes it
idle.marker(66, "drop")
# the fall: torso first, arms flop up a little (air drag), head still frozen
idle.key(71, ease="LINEAR", root_pos=(0, 0.75, 0), rs=(4, 0, 104), ls=(4, 0, -104), neck=(4, 0, 0))
# THUD: squash forward, arms whip forward by inertia
idle.key(74, ease="EXPO", root=(-12, 0, 0), root_pos=(0, 0.06, 0), rs=(30, 0, 30), ls=(26, 0, -34),
         neck=(-12, 0, 0), rh=(-4, 0, 2), lh=(-4, 0, -2))
idle.marker(74, "thud")
idle.key(78, root=(-4, 0, 1), root_pos=(0, 0.24, 0), rs=(8, 0, 10), ls=(4, 0, -12), neck=(-30, 0, 4))
idle.key(84, root=(-6, 2, 2), root_pos=(0, 0.16, 0), rs=(1, 0, 4), ls=(2, 0, -4), neck=(-38, 3, 7),
         rh=(2, 0, 2), lh=(0, 0, -2))
idle.key(89, ease="EXPO", root_pos=(0, 0.14, 0), neck=(-40, 3, 8))  # dead still...
# REPOINT: yanked back up by the runtime, head up, arms flare, legs trail behind
idle.key(92, ease="BACK", root=(5, 0, 0), root_pos=(0, LIFT + 0.22, 0), neck=(8, 0, 0),
         rs=(14, 0, 26), ls=(14, 0, -26), rh=(-14, 0, 5), lh=(-10, 0, -5))
idle.marker(92, "repoint")
idle.key(98, root=(-3, 0, 0), root_pos=(0, LIFT - 0.06, 0), neck=(-8, 0, 0),
         rs=(6, 0, 8), ls=(6, 0, -8), rh=(13, 0, 3), lh=(9, 0, -3))
# anticipation for the left point
idle.key(104, ease="EXPO", root=(-1, -4, -1), root_pos=(0.03, LIFT - 0.02, 0), neck=(-4, 16, 4), rs=(6, 0, 7),
         ls=(-10, 0, -11), rh=(8, 0, 3), lh=(9, 0, -3))
idle.key(110, root=(1, 11, 3), root_pos=(-0.04, LIFT + 0.04, 0), neck=(-3, 9, 1),
         ls=(94, 46, 0), rs=(-4, 0, 10), rh=(11, 0, 2), lh=(3, 0, -4))
idle.marker(110, "point", "L")
idle.key(114, neck=(-1, 23, 5), ls=(99, 50, 0), root=(1, 13, 3))
idle.key(120, ls=(93, 44, 0), neck=(-3, 20, 4))
# the arm lowers while the head keeps looking (overlap), then everything goes limp
idle.key(126, ease="BACK", ls=(40, 14, -4), neck=(-5, 16, 3), root=(0, 6, 1), rs=(5, 0, 8))
idle.key(134, ls=(6, 0, -7), neck=(-9, 6, -2), root=(-1, 0, 0), root_pos=(-0.02, LIFT + 0.02, 0))
idle.loop()
# organic hover drift (step=1 keeps the CONST snaps intact: export samples whole frames)
idle.noise("root", 1, 1.5, seed=3, step=1)
idle.noise("root", 1, 0.035, seed=4, loc=True, step=1)
idle.noise("neck", 1, 1.6, seed=5, step=1)
idle.noise("rh", 0, 2.5, cycles=(3, 4, 7), seed=6, step=1)
idle.noise("lh", 0, 2.5, cycles=(3, 5, 7), seed=7, step=1)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2
WY = 1.4


def glide(f, side):
    s = 1 if side == "R" else -1  # +1: right leg forward
    walk.key(f, ease="INOUT", root=(-12, -4 * s, 2 * s), root_pos=(0, WY, 0),
             neck=(6, 4 * s, 0),
             rs=(84, -4, 0), ls=(-24 - 6 * s, 0, -10),
             rh=(9 * s - 11, 0, 3), lh=(-9 * s - 11, 0, -3))


def skip(f, side):
    # dropped frame: the whole body jumps ahead, then snaps back (CONST both ways)
    s = 1 if side == "R" else -1
    walk.key(f, ease="CONST", root=(-16, -9 * s, 5 * s), root_pos=(0.08 * s, WY + 0.08, -0.35),
             neck=(-4, -10 * s, 8 * s), rs=(92, -8, 0), ls=(-34, 0, -16),
             rh=(-16, 0, 6), lh=(-20, 0, -6))
    walk.marker(f, "skip", side)


def back(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, ease="INOUT", root=(-11, -2 * s, 1 * s), root_pos=(0, WY + 0.04, 0),
             neck=(5, 2 * s, 0), rs=(83, -3, 0), ls=(-26, 0, -11),
             rh=(1 * s - 12, 0, 3), lh=(-1 * s - 12, 0, -3))


def float_(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, root=(-10, 2 * s, -1 * s), root_pos=(0, WY + 0.07, 0), neck=(4, 0, 0),
             rs=(85, -2, 0), ls=(-20 + 4 * s, 0, -9),
             rh=(-7 * s - 10, 0, 3), lh=(7 * s - 10, 0, -3))


glide(0, "R")
hold(walk, 2)
skip(3, "R")
back(5, "R")
float_(h * 0.75, "R")
glide(h, "L")
hold(walk, h + 2)
skip(h + 3, "L")
back(h + 5, "L")
float_(h * 1.75, "L")
walk.loop()

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))

poke = A.clip("poke", seconds=0.7, trigger="poke", mode="add", blend_in=0.02, blend_out=0.2)
poke.pose(0, Z)
poke.key(1, ease="EXPO", neck=(26, 0, -10), root=(8, 0, 0), root_pos=(0, 0.1, 0.12),
         rs=(-10, 0, 14), ls=(-12, 0, -14), rh=(-8, 0, 0), lh=(-6, 0, 0))
poke.marker(1, "deref")
poke.key(6, neck=(10, 10, 8), root=(3, 4, 0))
poke.key(10, neck=(8, -10, -6), root=(2, -3, 0))  # dazed shake
poke.key(14, neck=(4, 6, 3), root=(1, 1, 0), rs=(-3, 0, 4), ls=(-3, 0, -4))
poke.pose(21, Z)

crash = A.clip("crash", seconds=0.8, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
crash.pose(0, Z)
crash.key(1, ease="CONST", root=(-10, 10, 6), root_pos=(0, 0.2, 0), neck=(-20, 18, -16),
          rs=(30, 0, 30), ls=(16, 0, -46))
crash.marker(1, "thud")
crash.key(3, ease="CONST", root=(6, -12, -8), root_pos=(0.2, 0.22, 0), neck=(14, -20, 18),
          rs=(-10, 0, 50), ls=(40, 0, -10))
crash.marker(3, "glitch")
crash.key(5, ease="CONST", root=(-4, 6, 0), root_pos=(-0.1, 0.1, 0), neck=(-8, 6, -6), rs=(10, 0, 10), ls=(8, 0, -14))
crash.key(7, ease="INOUT", root=(-3, 0, 0), root_pos=(0, 0.04, 0), neck=(-12, 0, 0), rs=(4, 0, 4), ls=(4, 0, -4))
crash.pose(24, Z)

A.lift = LIFT

# preview framing for a levitating set (local helper, lib.py untouched)
_aim0 = lib._aim
lib._aim = lambda cam, loc, target=(0, 0, 2.6): _aim0(cam, (loc[0], loc[1], loc[2] + 1.0), (target[0], target[1], target[2] + 1.0))
A.cam.data.ortho_scale = 10.5
A.finish(preview=False)
A.preview(frames_per_clip=int(os.environ.get("NP_FRAMES", "10")))
