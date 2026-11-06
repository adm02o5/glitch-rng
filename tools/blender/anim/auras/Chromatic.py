# Chromatic (1 in 85,000, Epic): "Every colour at once."
# Concept: a vogue / light-show dancer who IS the prism. The aura's colour-split ghosts are
# delayed copies of the body (0.08 s and 0.17 s behind), so every big sweep of the body
# fans out into an RGB smear - the choreography is built from sharp hits (where the ghosts
# snap back onto the body) and long flowing arcs (where they separate into a rainbow).
# One idle loop = one full hue cycle of the VFX (4.0 s), so each move always lands on the
# same colour.
#
# CLIPS
#   idle  (4.0 s, 120 f, loop)
#         f0     hip-popped contrapposto, weight on the left leg, arms floating low
#         f8     coil: torso winds to the right, right arm drops low and back (anticipation)
#         f12-20 the right arm sweeps a huge arc forward and up (rainbow trail from the hand)
#         f20    STRIKE: right arm straight up, left arm snaps out to the side 2 f later,
#                chest arched, head whips toward the left hand (BACK overshoot)
#         f30-62 release: arms pour down in waves (left leads, right trails), figure-eight hips,
#                head rolls 3 f behind the torso
#         f66    SPLIT: the body jumps left / right / left on CONST keys (a chromatic aberration
#                "glitch"), EXPO back to centre
#         f78    anticipation: folds forward, arms cross in front of the chest
#         f88    SPECTRUM: arms burst open wide, chest up, chin up (EXPO + BACK settle)
#         f96-104 slow showcase turn with the arms held wide, head counter-turning
#         f106-120 arms float down (left first) back into the contrapposto
#   walk  (lib.STRIDE) catwalk strut: crossing steps, big hip roll, shoulders counter-twist,
#         head held level (neck counters the torso), arms flow 3 frames behind the legs.
#   vogue (0.9 s, replace, trigger "land") lands in a dip with both arms snapped up in a V.
#
# MARKERS (AurasMid A.Chromatic)
#   arc "rhand"  idle f12  -> rainbow trail on the right hand for the sweep
#   strike       idle f20  -> prism flashes white and spins fast, rings punch outward, rainbow
#                             burst from the raised right hand, light spike
#   split        idle f66  -> the colour ghosts tear far apart and the hue jumps half a cycle
#   spectrum     idle f88  -> rainbow bursts from both hands, prism rays flare wide, rings pulse,
#                             trails on both hands
#   pop R/L      walk f0/h -> rainbow pixel splash from that foot + floor ring flash
#   flare        vogue f3  -> big rainbow burst from the chest + every ring punches out
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Chromatic")


def plant(clip, passes=2):
    """Floor contact: at every root-height key, raise the body just enough that the lowest
    sole touches the floor (R6 has no knees). Never lowers a key."""
    rig, sc = A.rig, A.scene
    rig.animation_data.action = clip.action
    for _ in range(passes):
        for fc in clip._curves('pose.bones["root"].location'):
            if fc.array_index != 1:
                continue
            for kp in fc.keyframe_points:
                f = kp.co.x
                sc.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
                low = min(lib._lowest_sole(rig, "rh"), lib._lowest_sole(rig, "lh"))
                if low < -0.005:
                    kp.co.y -= low
                    kp.handle_left.y -= low
                    kp.handle_right.y -= low
            fc.update()


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.0)  # 120 frames = one hue cycle
K = idle.pose

POSE_A = dict(  # contrapposto, weight on the left leg, right hip popped
    root=(0, 7, 4), root_pos=(-0.12, 0, 0), neck=(-3, -9, -7),
    rs=(10, 0, 16), ls=(18, 0, -20), rh=(2, -6, 2), lh=(-1, 0, -5),
)
COIL = dict(
    root=(-6, -18, -2), root_pos=(0.04, -0.06, 0), neck=(-8, 6, 2),
    rs=(-34, 0, 26), ls=(42, 0, 10), rh=(8, 4, 3), lh=(6, 4, -3),
)
STRIKE = dict(
    root=(6, 12, -5), root_pos=(0.08, 0.05, 0), neck=(8, 26, -8),
    rs=(174, 0, 6), ls=(-2, 0, -84), rh=(-4, -6, 7), lh=(-6, 6, -3),
)
SPECTRUM = dict(
    root=(7, 0, 0), root_pos=(0, 0.06, 0), neck=(12, 0, 0),
    rs=(22, 0, 116), ls=(22, 0, -116), rh=(-5, 0, 6), lh=(-5, 0, -6),
)

K(0, POSE_A)
K(8, COIL, ease="IN")
idle.marker(12, "arc", "rhand")
idle.key(14, root=(-2, -4, -2), rs=(70, 0, 46), ls=(30, 0, -6), neck=(-2, 4, 0))  # mid-sweep
K(20, STRIKE, ease="BACK")
idle.marker(20, "strike")
idle.key(22, ease="EXPO", ls=(4, 0, -92))  # left arm snaps out 2 f behind the hit
idle.key(24, ls=(0, 0, -86))
idle.key(32, root=(4, 14, -4), neck=(6, 30, -5), rs=(166, 0, 16), ls=(4, 0, -80))
# release: left leads, right trails, head 3 f behind the hips
idle.key(38, ls=(46, 0, -42))
idle.key(42, rs=(110, 0, 52), root=(0, 0, 0), root_pos=(0, 0, 0))
idle.key(45, neck=(-2, 8, 2))
idle.key(48, ls=(56, 0, -18), root=(0, -9, -5), root_pos=(0.12, -0.02, 0), rh=(-1, 0, 5), lh=(2, 6, -2))
idle.key(51, rs=(44, 0, 32), neck=(-4, -10, 6))
idle.key(57, ls=(24, 0, -38), root=(0, 9, 5), root_pos=(-0.12, -0.02, 0), rh=(2, -6, 2), lh=(-1, 0, -5))
idle.key(60, rs=(72, 0, 18), neck=(-3, 10, -6))
# SPLIT: chromatic aberration jumps (CONST), EXPO back
K(66, dict(root=(0, 12, 9), root_pos=(-0.38, 0.03, 0), neck=(4, 22, 12), rs=(30, 0, 52), ls=(34, 0, -58)), ease="CONST")
idle.marker(66, "split")
K(68, dict(root=(0, -12, -9), root_pos=(0.38, 0.03, 0), neck=(4, -22, -12), rs=(38, 0, 60), ls=(26, 0, -48)), ease="CONST")
K(70, dict(root=(0, 5, 4), root_pos=(-0.16, 0.01, 0), neck=(2, 10, 5), rs=(30, 0, 40), ls=(30, 0, -44)), ease="CONST")
K(73, dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(20, 0, 24), ls=(20, 0, -24),
           rh=(0, 0, 3), lh=(0, 0, -3)), ease="EXPO")
# anticipation: fold, cross the arms in front
K(82, dict(root=(-12, 0, 0), root_pos=(0, -0.14, 0), neck=(-18, 0, 0),
           rs=(78, 0, -42), ls=(62, 0, 40), rh=(13, 0, 3), lh=(13, 0, -3)), ease="IN")
# SPECTRUM: burst open
K(88, SPECTRUM, ease="EXPO")
idle.marker(88, "spectrum")
idle.key(91, ease="BACK", rs=(16, 0, 108), ls=(16, 0, -108), neck=(8, 0, 0))
# showcase turn, head counter-turning
idle.key(98, root=(3, 14, 2), neck=(5, -8, -2), rs=(12, 0, 102), ls=(26, 0, -104))
idle.key(103, root=(2, 10, 3), neck=(2, -6, -4))
# float down, left first
idle.key(106, ls=(36, 0, -46))
idle.key(110, rs=(34, 0, 38))
K(116, P(POSE_A, rs=(12, 0, 18), ls=(20, 0, -22)))
idle.loop()
plant(idle)
idle.noise("root", 1, 1.6, cycles=(1, 2, 3), seed=11)
idle.noise("neck", 2, 2.0, cycles=(2, 3, 5), seed=12)
idle.noise("rs", 2, 2.5, cycles=(2, 3), seed=13)
idle.noise("ls", 2, 2.5, cycles=(2, 3), seed=14)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
h = walk.frames / 2


def contact(f, side):
    s = 1 if side == "R" else -1  # +1: right leg forward
    walk.key(f, ease="EXPO",
             root=(-3, -11 * s, -5 * s), root_pos=(0.06 * s, 0, 0),
             neck=(-3, 10 * s, 5 * s),
             rh=(27 * s + 3, 0, -3), lh=(-27 * s + 3, 0, 3))
    walk.marker(f, "pop", side)


def passing(f, side):
    s = 1 if side == "R" else -1  # weight on the right leg when s = 1
    walk.key(f, root=(-1, -2 * s, 7 * s), root_pos=(0.12 * s, 0.12, 0),
             neck=(-1, 2 * s, -6 * s),
             rh=(1, 0, -2), lh=(1, 0, 2))


def arms(f, side):  # flowing arms, 3 frames behind the legs, palms swept out
    s = 1 if side == "R" else -1
    walk.key(f, ease="OUT", rs=(-26 * s + 6, 0, 14 + 6 * s), ls=(26 * s + 6, 0, -14 + 6 * s))


def float_arms(f):
    walk.key(f, rs=(4, 0, 24), ls=(4, 0, -24))


contact(0, "R")
arms(3, "R")
passing(h * 0.5, "R")
float_arms(h * 0.5 + 3)
contact(h, "L")
arms(h + 3, "L")
passing(h * 1.5, "L")
float_arms(h * 1.5 + 3)
walk.loop()
plant(walk)

# ------------------------------------------------------------------ reaction
vg = A.clip("vogue", seconds=0.9, trigger="land", mode="replace", blend_in=0.02, blend_out=0.25)
NEUTRAL = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(-2, 0, 0), rs=(8, 0, 14), ls=(8, 0, -14),
               rh=(0, 0, 3), lh=(0, 0, -3))
vg.pose(0, dict(root=(4, 0, 0), root_pos=(0, 0.05, 0), neck=(6, 0, 0), rs=(70, 0, 50), ls=(70, 0, -50),
                rh=(16, 0, 4), lh=(-8, 0, -4)))
vg.pose(3, dict(root=(-14, 8, 0), root_pos=(0, -0.2, 0), neck=(16, -6, 6), rs=(150, 0, 42), ls=(150, 0, -42),
                rh=(26, 0, 6), lh=(10, 0, -6)), ease="EXPO")
vg.marker(3, "flare")
vg.key(8, ease="BACK", root=(-10, 6, 0), root_pos=(0, -0.14, 0), neck=(18, -4, 4), rs=(158, 0, 34), ls=(158, 0, -34))
vg.key(15, root=(-4, 3, 0), root_pos=(0, -0.04, 0), neck=(6, 0, 0), rs=(70, 0, 46), ls=(84, 0, -50),
       rh=(6, 0, 4), lh=(4, 0, -4))
vg.pose(27, NEUTRAL)
plant(vg)

A.lift = 0
A.finish()
