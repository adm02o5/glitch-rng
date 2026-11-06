# Cookie (1 in 20, Basic): "Tracks you across every server."  look: warm crumbs and small hex
# "tracker" icons orbiting at chest height, each tied to the head by a thin data beam.
# Concept: a browser cookie with a snack. The left hand holds a (VFX-less, imagined) cookie at
# the chest; the player bites it, chews contentedly... and then gets SUSPICIOUS - eyes dart over
# one shoulder, then the other, as if checking who is watching (the trackers light up the side
# being checked), a smug little shrug, and the right hand brushes the crumbs off the chest.
# Basic tier: subtle, but with a clear little story.
#
# CLIPS
#   idle (4.5 s, 135 f, loop)
#     f0-18    snack stance: weight on the left leg, right hip out, cookie held at the chest,
#              right arm hangs loose, head relaxed with a small tilt
#     f18-28   anticipation: head pulls back, the cookie rises to the mouth
#     f30      BITE: the head snaps forward-down onto the cookie (EXPO), chest folds a touch
#     f34-62   CHEW: three small nods (f40/f50/f60), the cookie lowers back to the chest, the
#              weight drifts to the right leg (the head lags 3 f behind the torso)
#     f66-80   TRACK R: eyes dart over the RIGHT shoulder (CONST snap), torso follows 3 f later
#     f84-96   TRACK L: snap over the LEFT shoulder, deeper lean, eyes narrowed (head down)
#     f100     back to front, a smug shrug (shoulders up, BACK overshoot)
#     f110-124 BRUSH: the right hand sweeps crumbs off the chest twice (f114, f122)
#     f124-135 settles back into the snack stance
#   walk (lib.STRIDE): a casual snacking stroll - the left hand keeps the cookie at the chest
#     (barely swinging), the right arm swings loose and wide, a relaxed hip sway, the head bobs
#     at double time (chewing) and the chin stays a little up.
#
# MARKERS (AurasLow A.Cookie)
#   bite   f30              -> crumb burst from THE MOUTH (head tip) and the cookie hand, the
#                              hex trackers jolt outward, warm light flare
#   chew   f40, f50, f60    -> a few crumbs drop from the mouth
#   track  f68 "R", f86 "L" -> the trackers' data beams flare and the hexes on that side swing
#                              toward the head (they are watching back), the orbit speeds up
#   brush  f114, f122       -> crumbs fall from the chest
#   crumb  walk f0 + half   -> a couple of crumbs fall from the cookie hand on each step
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Cookie")


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


def plant(clip, passes=2):
    """Raise root-height keys just enough that the lowest sole touches the floor (never lowers
    a key, so deliberate hops survive)."""
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


def legs(w, y=0.0):
    # w -1..1 = weight on the left .. right leg
    return dict(root_pos=(0.08 * w, y, 0), rh=(0, 0, 2.0 * w + 1.8), lh=(0, 0, 2.0 * w - 1.8))


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.5)  # 135 frames
K = idle.key

HOLD_L = (62, -28, -4)  # cookie at the chest
MOUTH_L = (112, -38, -2)  # cookie at the mouth
HANG_R = (2, 0, 7)

STAND = dict(root=(0, -3, 2.2), neck=(0, 4, -4), rs=HANG_R, ls=HOLD_L, **legs(-1))
idle.pose(0, STAND)
K(10, neck=(2, 6, -5), rs=(4, 0, 8))
# anticipation: head pulls back, cookie rises
K(22, ease="INOUT", neck=(9, 2, -2), root=(2, -2, 1.5))
K(26, ease="OUT", ls=MOUTH_L)
# BITE
K(30, ease="EXPO", neck=(-16, 0, 0), root=(-4, -1, 1.2), ls=(106, -36, -2),
  rs=(6, 0, 10), root_pos=(-0.06, -0.02, 0))
idle.marker(30, "bite")
K(33, ease="OUT", neck=(-11, 0, 1), root=(-2, -1, 1.2))
# CHEW: three nods; cookie lowers, weight drifts right (head lags the torso)
for i, f in enumerate((40, 50, 60)):
    K(f - 3, ease="OUT", neck=(-2 - i, 3 * i, 2 * i))
    K(f, ease="EXPO", neck=(-9 - i, 3 * i, 2 * i))
    idle.marker(f, "chew")
K(44, ls=(80, -32, -3))
K(54, ls=HOLD_L, root=(0.5, 2, -1.5), rs=HANG_R, **legs(0.2))
K(64, root=(0, 3, -2.2), **legs(1))
K(63, neck=(-4, 6, 4))
# TRACK R: eyes dart over the right shoulder (CONST), torso follows 3 f later
K(67, ease="CONST", neck=(-4, 6, 4))
K(68, ease="EXPO", neck=(-2, -46, -3))
idle.marker(68, "track", "R")
K(71, ease="OUT", root=(0, -14, -2.5), rs=(-6, 0, 9), ls=(58, -24, -6))
K(78, neck=(-3, -50, -4), root=(0, -16, -2.5))
# TRACK L: snap over the left shoulder, deeper, eyes narrowed
K(85, ease="CONST", neck=(-3, -50, -4))
K(86, ease="EXPO", neck=(-8, 52, 6))
idle.marker(86, "track", "L")
K(89, ease="OUT", root=(-2, 18, 2.5), rs=(4, 0, 12), ls=(60, -30, -2), **legs(-0.6))
K(96, neck=(-9, 55, 7), root=(-2, 19, 2.8))
# back to front + smug shrug
K(100, ease="EXPO", neck=(2, 0, -6), root=(1, 0, 1))
K(103, ease="BACK", root=(4, 0, 1), root_pos=(-0.05, 0.07, 0), neck=(6, -2, -8),
  rs=(-4, 0, 16), ls=(66, -28, -10))
K(108, ease="INOUT", root=(0, 0, 1), root_pos=(-0.05, 0, 0), neck=(0, -2, -6), ls=HOLD_L,
  rs=(10, 0, 6))
# BRUSH: right hand sweeps across the chest twice
SWEEP_IN = (38, 32, 4)
SWEEP_OUT = (30, -6, 14)
K(111, ease="OUT", rs=SWEEP_IN, neck=(-14, 4, -2))
K(114, ease="EXPO", rs=SWEEP_OUT)
idle.marker(114, "brush")
K(118, ease="OUT", rs=SWEEP_IN)
K(122, ease="EXPO", rs=SWEEP_OUT, neck=(-10, 2, -3))
idle.marker(122, "brush")
K(128, ease="INOUT", rs=(4, 0, 8), neck=(-1, 4, -4), root=(0, -3, 2.2), **legs(-1))
idle.loop()
idle.noise("root", 2, 0.6, cycles=(1, 2, 3), seed=41)  # breathing sway
idle.noise("rs", 0, 1.2, cycles=(2, 3, 5), seed=42)
idle.noise("ls", 0, 0.8, cycles=(1, 3, 4), seed=43)
plant(idle)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(f, s):
    # s = +1: right foot forward
    walk.key(f, ease="INOUT",
             root=(1, -7 * s, -2.5 * s), root_pos=(0.05 * s, 0, 0),
             neck=(3, 6 * s, 2.5 * s),
             rs=(-34 * s, 0, 8 + 4 * s), ls=(HOLD_L[0] + 5 * s, HOLD_L[1], HOLD_L[2]),
             rh=(23 * s, 0, 1.5), lh=(-23 * s, 0, -1.5))
    walk.marker(f, "crumb")


def passing(f, s):
    walk.key(f, root=(-1, 0, 2 * s), root_pos=(0, 0.08, 0),
             neck=(-2, 0, -1.5 * s),
             rs=(-2, 0, 7), ls=(HOLD_L[0] - 3, HOLD_L[1], HOLD_L[2]),
             rh=(-2 * s, 0, 1.5), lh=(2 * s, 0, -1.5))


contact(0, 1)
passing(h * 0.5, 1)
contact(h, -1)
passing(h * 1.5, -1)
walk.loop()
plant(walk)

A.lift = 0
A.finish()
