# Deepfake (1 in 1,200, Rare): "Your face. Not your face."
# Concept: an uncanny double. It stands in a too-perfect, symmetric "calibration" pose; the face
# mask peels off its head and floats beside it. The body turns, slowly and wrongly, to stare at
# its own face, the head glitches between two mirrored identities, the hand feels the (now bare)
# face, reaches out, grabs the mask and SLAPS it back on - re-lock - and the loop starts again.
# The idle length (5.0 s) IS the VFX peel cycle (Sync.phase(bus, 5) in AurasExtra A.Deepfake).
#
# CLIPS
#   idle (5.0 s, 150 f, loop)
#     f0       calibration pose: square, symmetric, arms a touch out (too perfect)
#     f6-12    anticipation dip, then the head jerks back as the mask lifts off (EXPO)
#     f20-50   slow uncanny turn: the head leads, looking up-right at the floating mask, the torso
#              follows 4-6 frames later, weight drifts onto the left foot, the head keeps tilting
#     f55-66   identity glitch: CONST snaps between the look and its mirror image (3 broken frames
#              each), torso and shoulders flip with it
#     f72-96   the right hand rises and touches the bare face; the head leans into the palm
#     f100-112 head turns back to the mask, the arm reaches out to it (BACK), grabs it
#     f114-126 pulls it in, cocking the arm wide (anticipation)
#     f132     SLAP: the hand drives the mask onto the face, the head recoils left, body jolts
#     f136-150 recoil overshoot, the arm drops, back into calibration
#   walk (lib.STRIDE): stabilised glide - stiff arms that barely swing, the torso yaws with the
#     legs but the neck counter-rotates so the face stays dead ahead (like a tracked face);
#     on the left contact the head drops two frames into its mirrored identity (CONST).
#   doubletake (0.8 s, add, trigger "mismatch"): when the face tracker randomly loses the match
#     (VFX), the head jerks round at the orbiting candidate masks and shakes "no".
#
# MARKERS (AurasExtra A.Deepfake)
#   peel  f8     the mask leaves the face -> scan brackets bloom, scan line sweeps fast, face-square
#                burst from the head
#   swap  f56,f62  mirror snaps -> MISMATCH (red) for a few frames, candidate masks jump half an
#                orbit, landmark dots jitter hard
#   touch f88    fingertips on the bare face -> skin/cyan square spray from the right hand, dots scatter
#   grab  f112   the hand closes on the mask -> the mask stops floating and rides the right hand
#                (until the slap), cyan sparks from the hand
#   lock  f132   SLAP -> mask snaps onto the face, MATCH 100.0% flashes white, brackets punch in,
#                light surge, big burst from the head, sigil glow kick
#   flick (walk, left contact)  mirror flicker -> short MISMATCH + dot jitter
#   (free) step "R"/"L" -> recognition squares puff from that foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Deepfake")


def wobble(clip, joint, axis, amp, cycles, phase=0.0, loc=False):
    """Additive periodic sine drift (F-curve GENERATOR modifier): keeps sharp keys intact."""
    path = f'pose.bones["{joint}"].' + ("location" if loc else "rotation_euler")
    for fc in clip._curves(path):
        if fc.array_index != axis:
            continue
        m = fc.modifiers.new("FNGENERATOR")
        m.function_type = "SIN"
        m.use_additive = True
        m.amplitude = amp if loc else math.radians(amp)
        m.phase_multiplier = 2 * math.pi * cycles / clip.frames
        m.phase_offset = phase
        fc.update()
        return
    raise ValueError(f"no keys on {path}[{axis}]")


def plant(clip, passes=2):
    """Raise root-height keys just enough that the lowest sole touches the floor (never lowers)."""
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
idle = A.clip("idle", seconds=5.0)  # 150 frames == the VFX peel cycle
K = idle.pose

CAL = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0),
           rs=(2, 0, 7), ls=(2, 0, -7), rh=(0, 0, 3), lh=(0, 0, -3))
K(0, CAL)
# anticipation, then the head jerks back as the mask peels away
K(5, P(CAL, root=(-2, 0, 0), neck=(-5, 0, 0), rs=(4, 0, 6), ls=(4, 0, -6)))
K(8, P(CAL, root=(3, 0, 0), root_pos=(0, 0.03, 0), neck=(10, 0, 0), rs=(-2, 0, 11), ls=(-2, 0, -11)), ease="EXPO")
idle.marker(8, "peel")
K(13, P(CAL, root=(1, 0, 0), neck=(4, 0, 0), rs=(0, 0, 8), ls=(0, 0, -8)))
# slow uncanny turn: the head leads...
K(22, P(CAL, root=(1, -2, 0), neck=(3, -16, -3)))
LOOK = dict(root=(1, -11, 3), root_pos=(-0.07, 0, 0), neck=(9, -32, -14),
            rs=(-3, 0, 9), ls=(5, 0, -4), rh=(0, 0, 6), lh=(0, 0, -1))
K(34, P(LOOK, root=(1, -6, 2), neck=(9, -34, -10)), ease="OUT")
# ...the torso arrives later, the head keeps tilting (too far: uncanny)
K(42, LOOK)
K(52, P(LOOK, neck=(8, -33, -19), root=(1, -12, 3.5)))
# identity glitch: CONST flips to the mirror image and back
MIR = P(LOOK, root=(1, 11, -3), root_pos=(0.07, 0, 0), neck=(9, 32, 19),
        rs=(5, 0, 4), ls=(-3, 0, -9), rh=(0, 0, 1), lh=(0, 0, -6))
HOLD = P(LOOK, neck=(8, -33, -19), root=(1, -12, 3.5))
K(55, HOLD, ease="CONST")
K(56, MIR, ease="CONST")
idle.marker(56, "swap")
K(59, HOLD, ease="CONST")
K(62, MIR, ease="CONST")
idle.marker(62, "swap")
K(64, P(HOLD, neck=(6, -30, -12)), ease="CONST")
K(66, P(HOLD, neck=(6, -30, -12)))
# the hand rises to feel the bare face, the head turns back into it
K(76, P(CAL, root=(-1, -5, 1), root_pos=(-0.04, 0, 0), neck=(-2, -12, -6),
        rs=(55, 14, 14), ls=(4, 0, -5), rh=(0, 0, 5), lh=(0, 0, -2)))
TOUCH = P(CAL, root=(-2, -3, 1), root_pos=(-0.03, 0, 0), neck=(-6, 10, -12),
          rs=(140, 0, -28), ls=(5, 0, -5), rh=(0, 0, 5), lh=(0, 0, -2))
K(86, P(TOUCH, rs=(146, 0, -24), neck=(-2, 4, -6)), ease="OUT")
K(88, TOUCH)
idle.marker(88, "touch")
K(94, P(TOUCH, rs=(136, 0, -30), neck=(-8, 12, -14)))
# looks back at the mask, reaches for it
K(100, P(TOUCH, neck=(6, -26, -8), rs=(130, 0, -10)))
REACH = dict(root=(-3, -14, -3), root_pos=(0.04, 0, 0), neck=(8, -30, -6),
             rs=(104, -16, 46), ls=(-8, 0, -10), rh=(0, 0, 2), lh=(0, 0, -5))
K(110, P(REACH, rs=(108, -20, 52)), ease="BACK")
K(112, REACH, ease="EXPO")
idle.marker(112, "grab")
# pull it in, cocking the arm wide
K(118, P(REACH, root=(-1, -10, -2), rs=(112, -24, 58), neck=(6, -20, -4)))
K(126, P(REACH, root=(1, -16, -1), rs=(118, -28, 66), neck=(4, -10, -2), ls=(-10, 0, -12)), ease="IN")
# SLAP onto the face, head recoils left
SLAP = dict(root=(3, 8, 2), root_pos=(-0.02, -0.03, 0), neck=(5, 18, 12),
            rs=(140, 0, -27), ls=(-4, 0, -12), rh=(0, 0, 4), lh=(0, 0, -4))
K(132, SLAP, ease="BACK")
idle.marker(132, "lock")
K(136, P(SLAP, neck=(-3, 6, 3), root=(-1, 3, 0), root_pos=(0, 0, 0)))
K(142, P(CAL, rs=(30, 8, 9), neck=(-1, 2, 1), root=(0, 1, 0)), ease="OUT")
idle.loop()
wobble(idle, "neck", 2, 1.2, 3, 0.4)
wobble(idle, "root", 1, 0.008, 5, 0.0, loc=True)  # breathing
wobble(idle, "rs", 2, 1.0, 2, 1.1)
wobble(idle, "ls", 2, 1.0, 2, 2.3)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(s):
    return dict(root=(-2, -7 * s, -1 * s), root_pos=(0, 0, 0), neck=(1, 7 * s, 1 * s),
                rs=(-9 * s, 0, 6), ls=(9 * s, 0, -6), rh=(25 * s, 0, 2), lh=(-25 * s, 0, -2))


def glide(s):
    return dict(root=(-3, 0, 0.8 * s), root_pos=(0, 0.05, 0), neck=(2, 0, 0),
                rs=(0, 0, 7), ls=(0, 0, -7), rh=(-2 * s, 0, 2), lh=(2 * s, 0, -2))


walk.pose(0, contact(1))
walk.pose(h * 0.5, glide(1))
walk.key(h - 1, neck=(1, -5, -1), ease="CONST")
walk.pose(h, P(contact(-1), neck=(4, 24, 16)), ease="CONST")  # mirrored identity flicker
walk.marker(h, "flick")
walk.key(h + 2, neck=(1, -7, -1))
walk.pose(h * 1.5, glide(-1))
walk.loop()

# ------------------------------------------------------------------ doubletake (additive)
dt = A.clip("doubletake", seconds=0.8, trigger="mismatch", mode="add", blend_in=0.02, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
dt.pose(0, Z, ease="EXPO")
dt.pose(3, P(Z, neck=(5, 26, 8), root=(1, 6, 0), rs=(4, 0, 6), ls=(4, 0, -6)))
dt.pose(8, P(Z, neck=(2, -16, -6), root=(0, -3, 0)), ease="EXPO")
dt.pose(12, P(Z, neck=(1, 10, 3)), ease="EXPO")
dt.pose(16, P(Z, neck=(0, -4, -1)))
dt.pose(24, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
