# Hotfix (1 in 400, Enhanced): "Deployed on a Friday."  look: orange flames shaped like wrench
# icons, hot sparks, floor fire, a version label above the head.
# Concept: a frantic on-call dev pushing a fix to production at 17:59 on a Friday. Taps the
# foot, checks the watch (double take!), hammers the code into place with a wrench (3 hits,
# each one a new build), winds up and SLAMS deploy with both fists, then the prod servers
# catch fire - flinches back from the flames and wipes the sweat off the brow.
# One idle loop = one deploy (6 s), exactly the old VFX deploy rhythm (3 builds of 2 s).
#
# CLIPS
#   idle (6.0 s, 180 f, loop)
#     f0-20    NERVOUS WAIT: weight on the left leg, the right foot taps (f5/10/15/20), the
#              head glances left and right, fingers fidget
#     f24-36   CHECK WATCH: the left forearm comes up across the chest, the head drops to it
#     f38-42   DOUBLE TAKE: the head snaps up (EXPO) and back down - "17:59!"
#     f46-90   HAMMER: the right arm winds up (torso turns + leans back = anticipation) and
#              strikes down three times (f58/72/86, EXPO, each harder; torso and hips follow,
#              the head lags 1-2 f), the left hand braces in front
#     f96-110  DEPLOY WIND-UP: both arms high overhead, chest back, up on the toes
#     f114     SLAM: both fists crash down (EXPO), deep forward lean, held while the eyes
#              creep up anxiously (f124)
#     f134     FLARE: the servers ignite - flinch back, forearms up to shield the face,
#              head turned away (BACK overshoot)
#     f146-166 WIPE: the right hand sweeps across the brow, shoulders drop in a sigh, a shake
#              of the hot hand
#     f170-180 back to the nervous wait
#   walk (lib.STRIDE): a rushed forward-leaning power-walk (late for prod): big pumping arms,
#     bouncy passing, the head pushed forward and up.
#   burn (0.6 s, add, trigger "burn"): while walking a spark storm burns the right hand ->
#     it jerks away and shakes (VFX -> body).
#
# MARKERS (AurasExtra A.Hotfix)
#   tap    f5/10/15/20       foot taps     -> a puff of sparks at THE RIGHT FOOT
#   watch  f34               watch check   -> the label shows the clock "FRI 17:5x"
#   hit    "rhand" f58/72/86 wrench strikes -> build +1 ("HOTFIX v1.0.N"), a spark shower from
#                                             THE RIGHT HAND, the wrench flames flare
#   deploy f114              both-fist slam -> "DEPLOYED (FRI 17:59)", big floor spark burst,
#                                             floor fire surges, light flares
#   flare  f134              flinch        -> a fireball puff from the floor, light spike
#   (free) step -> sparks + a little flame at the landing foot; VFX "burn" -> burn reaction
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Hotfix")


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


def plant(clip, passes=2):
    """Raise root-height keys just enough that the lowest sole touches the floor (never lowers
    a key, so deliberate rises survive)."""
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


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames
K = idle.key


def legs(w, lean=0.0, y=0.0):
    # w -1..1 = weight on the left .. right leg; lean = forward torso lean the hips cancel
    return dict(root_pos=(0.07 * w, y, 0), rh=(lean, 0, 1.8 * w + 1.6), lh=(lean, 0, 1.8 * w - 1.6))


FID_R, FID_L = (10, 0, 7), (8, 0, -7)
BASE = dict(root=(-2, 3, 1.5), neck=(-4, 0, 0), rs=FID_R, ls=FID_L)

idle.pose(0, P(BASE, **legs(-1, 2)))


def tap(f):
    # the free right foot lifts (OUT) and strikes (EXPO)
    K(f - 2.5, ease="OUT", rh=(12, 0, -0.4))
    K(f, ease="EXPO", rh=(2, 0, -0.2))
    idle.marker(f, "tap")


for f in (5, 10, 15, 20):
    tap(f)
# nervous glances + fidgeting fingers (arms twitch)
K(4, ease="EXPO", neck=(-2, 16, 2))
K(7, rs=(14, 0, 9), ls=(5, 0, -6))
K(11, ease="EXPO", neck=(-3, -14, -2))
K(14, rs=(8, 0, 6), ls=(11, 0, -8))
K(18, ease="EXPO", neck=(-5, 6, 1))
# CHECK WATCH
K(24, ease="IN", ls=(30, 0, -12), root=(-2, 6, 1.5))
K(30, ease="BACK", ls=(88, -34, 0), root=(-5, 9, 1), rs=(6, 0, 8), rh=(2, 0, -0.2))
K(32, ease="OUT", neck=(-24, 14, 3))
idle.marker(34, "watch")
K(37, neck=(-25, 15, 3), ls=(89, -35, 0))
# DOUBLE TAKE
K(39, ease="EXPO", neck=(6, 10, -2), root=(1, 8, 1))
K(42, ease="EXPO", neck=(-24, 13, 3), root=(-5, 9, 1))
K(45, neck=(-20, 10, 2), ls=(84, -32, 0))
# HAMMER x3 (right hand), the left hand braces
BRACE = (44, -10, -8)


def hammer(f_strike, k):
    up = f_strike - 6
    K(up, ease="OUT", rs=(158 + 4 * k, 0, 10), root=(3 + k, 14, 0), neck=(-6, 8, 0), ls=BRACE,
      **legs(0.3, 2))
    K(f_strike, ease="EXPO", rs=(48 - 3 * k, 0, -4), root=(-10 - 2 * k, 4, -1),
      **legs(0.3, 10 + 2 * k))
    K(f_strike + 1, ease="EXPO", neck=(-24 - 2 * k, 2, -2))
    K(f_strike + 3, ease="BACK", rs=(60, 0, 0), root=(-7 - k, 6, -0.5))
    idle.marker(f_strike, "hit", "rhand")


hammer(58, 0)
hammer(72, 1)
hammer(86, 2)
K(92, rs=(70, 0, 2), ls=(40, 0, -10), root=(-5, 3, 0), neck=(-12, 0, 0), **legs(0, 5))
# DEPLOY WIND-UP: arms overhead, chest back, up on the toes
K(100, ease="OUT", rs=(172, 0, -12), ls=(172, 0, 12), root=(7, 0, 0), neck=(12, 0, 0),
  root_pos=(0, 0.06, 0), rh=(0, 0, 1.4), lh=(0, 0, -1.4))
K(108, rs=(178, 0, -10), ls=(178, 0, 10), root=(9, 0, 0), neck=(14, 0, 0), root_pos=(0, 0.08, 0))
# SLAM
SLAM = dict(rs=(64, 0, -8), ls=(64, 0, 8), root=(-16, 0, 0), neck=(-14, 0, 0),
            root_pos=(0, 0, 0), rh=(16, 0, 1.6), lh=(16, 0, -1.6))
idle.pose(114, SLAM, ease="EXPO")
idle.marker(114, "deploy")
K(116, ease="EXPO", neck=(-20, 0, 0), rs=(58, 0, -8), ls=(58, 0, 8))
K(120, neck=(-16, 0, 0), rs=(62, 0, -8), ls=(62, 0, 8))
K(126, ease="INOUT", neck=(14, -3, 0), root=(-14, -2, 0))
K(131, neck=(12, 3, 1))
# FLARE: flinch back, shield the face
K(134, ease="BACK", root=(8, -10, 2), neck=(4, 26, 6), rs=(96, 0, 34), ls=(104, 0, -24),
  root_pos=(-0.08, 0.03, 0), rh=(0, 0, 0.4), lh=(0, 0, -3.2))
idle.marker(134, "flare")
K(140, root=(5, -8, 2), neck=(0, 22, 5), rs=(88, 0, 30), ls=(96, 0, -22), root_pos=(-0.08, 0.01, 0))
# WIPE the brow (right hand sweeps across the forehead), sigh, shake the hot hand
K(146, ease="INOUT", ls=(10, 0, -9), rs=(150, 18, -12), neck=(6, 6, 2), root=(2, -2, 1))
K(152, ease="INOUT", rs=(152, -16, -22), neck=(9, -6, -2))
K(156, ease="OUT", rs=(30, 0, 30), root=(-4, 0, 1), root_pos=(-0.05, -0.02, 0), neck=(-10, 0, 0))
K(159, ease="EXPO", rs=(26, 0, 42))  # shake shake
K(161, ease="EXPO", rs=(30, 0, 26))
K(163, ease="EXPO", rs=(24, 0, 40))
K(166, rs=(16, 0, 18), neck=(-6, 2, 0))
idle.pose(172, P(BASE, **legs(-1, 2)))
idle.loop()
idle.noise("root", 2, 0.6, cycles=(2, 3, 5), seed=51)  # jittery nerves
idle.noise("neck", 1, 1.6, cycles=(3, 5, 7), seed=52)
idle.noise("rs", 0, 1.2, cycles=(3, 5, 8), seed=53)

# ------------------------------------------------------------------ walk (rushed)
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2
LEAN = 11


def contact(f, s):
    walk.key(f, ease="EXPO", root=(-LEAN, -8 * s, -1.5 * s), root_pos=(0, 0, 0),
             neck=(4, 7 * s, 1.5 * s),
             rs=(-46 * s, 0, 10), ls=(46 * s, 0, -10),
             rh=(LEAN + 28 * s, 0, 1.6), lh=(LEAN - 28 * s, 0, -1.6))


def passing(f, s):
    walk.key(f, root=(-LEAN - 3, 0, 1.6 * s), root_pos=(0, 0.11, 0),
             neck=(7, 0, 0),
             rs=(-6 * s, 0, 8), ls=(6 * s, 0, -8),
             rh=(LEAN - 4 * s, 0, 1.6), lh=(LEAN + 4 * s, 0, -1.6))


contact(0, 1)
passing(h * 0.5, 1)
contact(h, -1)
passing(h * 1.5, -1)
walk.loop()

# ------------------------------------------------------------------ burn (VFX -> body)
burn = A.clip("burn", seconds=0.6, trigger="burn", mode="add", blend_in=0.02, blend_out=0.15)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
burn.pose(0, Z)
burn.pose(2, P(Z, rs=(30, 0, 34), neck=(4, -16, -4), root=(3, -5, 0)), ease="EXPO")
burn.pose(5, P(Z, rs=(24, 0, 46), neck=(3, -12, -3), root=(2, -4, 0)), ease="EXPO")
burn.pose(8, P(Z, rs=(30, 0, 28), neck=(2, -8, -2), root=(2, -3, 0)), ease="EXPO")
burn.pose(11, P(Z, rs=(22, 0, 40), neck=(1, -4, -1), root=(1, -2, 0)), ease="EXPO")
burn.pose(18, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
