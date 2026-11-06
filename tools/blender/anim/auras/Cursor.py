# Cursor (1 in 5, Basic): "Click here. No, here."
# Concept: the player IS the mouse pointer's owner. The right arm is a pointing hand that
# hovers, aims and clicks in the air; the eyes find the target a beat before the hand gets
# there; the target keeps running away ("No, here") and the body gets a little fed up.
#
# CLIPS
#   idle (4.8 s, 144 f, loop)
#     f0-20    hover A: the pointing arm drifts right, the head follows ~3 frames late,
#              weight on the left leg (contrapposto), the free arm hangs loose
#     f22-30   CLICK #1: tiny lift (anticipation) -> sharp tap down (EXPO) -> springy recover
#     f36-50   move to B (up-left): eyes lead, torso turns, arm arrives with a soft overshoot,
#              weight drifts to the right leg
#     f56-70   DOUBLE-CLICK: lift, tap, half-recover, tap again, recover
#     f80      "NO, HERE": the head snaps (CONST) to a target low on the right, the arm whips
#              after it 3 frames later (EXPO) with an overshoot, torso turns right
#     f100-108 CLICK #3 on the new target (a harder, annoyed tap)
#     f114-130 fed-up shrug: arms drop and flare, head tilts, chest leans back, sigh down
#     f134-144 the arm comes up again to hover A
#   walk (lib.STRIDE): a casual stroll with the right arm held out low and forward like a
#     pointer leading the way (small counter-sway), the left arm swings freely, head follows
#     the hand; one click tap per stride on the right contact.
#   glance (0.6 s, add, trigger "poke"): a random click of an orbiting cursor in the VFX makes
#     the head dart over the right shoulder and come back (VFX -> body).
#
# MARKERS (AurasExtra A.Cursor)
#   click     f25, f59, f103, walk f0  the hand taps     -> ripple ring + spark puff AT THE
#                                                          FINGERTIP, the nearest orbiting
#                                                          cursor presses in, light blips
#   click "2" f66                      the double click  -> bigger ripple + sparks, all four
#                                                          floor-selection handles flash
#   warp      f80                      "No, here" snap   -> every orbiting cursor teleports a
#                                                          step around the body (glitch jump),
#                                                          the tooltip pops "No, here."
#   (free) step -> a tiny ripple at the foot; VFX emits "poke" -> glance
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Cursor")


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


def plant(clip, passes=2):
    """Floor contact: raise root-height keys just enough that the lowest sole touches the
    floor (never lowers a key, so deliberate rises survive)."""
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
idle = A.clip("idle", seconds=4.8)  # 144 frames
K = idle.key

# legs: weight on the left leg (w = -1) .. right leg (w = +1)
def legs(w):
    return dict(root_pos=(0.07 * w, 0, 0), rh=(0, 0, 2.5 - 1.5 * w), lh=(0, 0, -2.5 - 1.5 * w))


def aim(f, el, az, ease="INOUT", lag=3, w=None, tilt=0.0, lean=0.0):
    """Right hand points at elevation `el` (90 = straight ahead) and azimuth `az` (+ = to the
    right). The eyes lead (keyed `lag` frames earlier), the torso turns a little with it."""
    K(f - lag, ease=ease, neck=((el - 90) * 0.45 - 3, -az * 0.55, tilt))
    K(f, ease=ease, rs=(el, 4, az), root=(lean, -az * 0.18, 0))
    if w is not None:
        K(f, ease="INOUT", **legs(w))


FREE = (4, 0, -6)  # the loose left arm
# f0 hover A
K(0, ls=FREE, **legs(-1))
aim(3, 82, 6)
aim(17, 88, 18, tilt=3)
K(16, ls=(6, 0, -7))
# CLICK #1
aim(22, 95, 19, ease="OUT", lag=1)
aim(25, 79, 18, ease="EXPO", lag=0, lean=-2)
idle.marker(25, "click")
aim(30, 87, 18, ease="BACK", lag=0)
# move to B (up-left) - eyes first, weight drifts right
aim(42, 114, -11, w=1, tilt=-3, lag=4)
K(42, ls=(2, 0, -5))
aim(48, 110, -9, tilt=-2)
# DOUBLE CLICK
aim(56, 117, -9, ease="OUT", lag=1)
aim(59, 101, -9, ease="EXPO", lag=0, lean=-2)
idle.marker(59, "click")
aim(63, 111, -9, ease="OUT", lag=0)
aim(66, 99, -9, ease="EXPO", lag=0, lean=-3)
idle.marker(66, "click", "2")
aim(71, 109, -9, ease="BACK", lag=0)
K(74, neck=(1, 7, -2))
# "NO, HERE" - the head snaps first, the arm whips after it
K(79, neck=(1, 6, -2))
K(80, ease="CONST", neck=(-14, -24, 6))
idle.marker(80, "warp")
K(81, ease="EXPO", neck=(-13, -22, 5))
K(80, rs=(107, 4, -9), root=(-3, 2, 0))
K(84, ease="EXPO", rs=(58, 4, 36), root=(-4, -10, -2), ls=(-6, 0, -12), **legs(1))
K(89, ease="BACK", rs=(61, 4, 33), root=(-3, -8, -1.5))
K(94, rs=(63, 4, 31), neck=(-12, -20, 4))
# CLICK #3 - harder, annoyed
K(99, ease="OUT", rs=(73, 4, 31), root=(-2, -8, -1))
K(103, ease="EXPO", rs=(52, 4, 31), root=(-6, -9, -2), neck=(-16, -21, 5))
idle.marker(103, "click")
K(108, ease="BACK", rs=(62, 4, 31), root=(-3, -8, -1))
# fed-up shrug (arms flare, chest back, head tilts), then a sigh
K(116, ease="BACK", rs=(18, -6, 16), ls=(16, 6, -18), root=(4, -2, 1.5),
  neck=(5, -4, 10), root_pos=(0, 0.03, 0))
K(124, rs=(10, 0, 9), ls=(8, 0, -10), root=(1, 0, 0.5), neck=(-8, 2, 5), root_pos=(0, -0.04, 0))
K(132, rs=(40, 4, 4), ls=(5, 0, -7), root=(0, 1, 0), neck=(-6, -2, 1), **legs(-0.6))
K(144, ls=FREE)
idle.loop()
idle.noise("rs", 2, 2.2, cycles=(3, 5, 8), seed=3)  # hover jitter of the pointing hand
idle.noise("neck", 1, 1.6, seed=4)
idle.noise("root", 2, 0.7, cycles=(1, 2, 3), seed=5)  # breathing sway

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(f, s, tap=False):
    walk.key(f, ease="OUT",
             root=(-2, -6 * s, -1.5 * s), root_pos=(0, -0.12, 0),
             neck=(-9, 5 * s, 1.5 * s),
             rs=(56 if tap else 66, 4, 8 - 3 * s), ls=(24 * s, 0, -7),
             rh=(24 * s, 0, 2), lh=(-24 * s, 0, -2))


def passing(f, s):
    walk.key(f, root=(-4, 0, 1.2 * s), root_pos=(0, 0.05, 0),
             neck=(-6, 0, 0),
             rs=(70, 4, 7), ls=(0, 0, -6),
             rh=(-2 * s, 0, 2), lh=(2 * s, 0, -2))


contact(0, 1, tap=True)
walk.marker(0, "click")
walk.key(3, ease="BACK", rs=(69, 4, 5))
passing(h * 0.5, 1)
contact(h, -1)
passing(h * 1.5, -1)
walk.loop()

# ------------------------------------------------------------------ glance (VFX -> body)
gl = A.clip("glance", seconds=0.6, trigger="poke", mode="add", blend_in=0.04, blend_out=0.15)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
gl.pose(0, Z)
gl.pose(3, P(Z, neck=(5, -30, -5)), ease="EXPO")
gl.pose(5, P(Z, neck=(6, -34, -6), root=(0, -5, 0)))
gl.pose(10, P(Z, neck=(4, -30, -4), root=(0, -5, 0)))
gl.pose(18, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
