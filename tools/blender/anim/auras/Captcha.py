# Captcha (1 in 25, Basic): "Select all squares with auras."
# Concept: a person solving a captcha in the air. They study the floating 3x3 grid with a
# tilted head, poke tiles with the right index finger, hesitate and scratch their head over
# the last one, slam VERIFY - and then, for a second, move exactly like a robot (head snaps,
# stiff arms) before shaking it off. "I'm not a robot." Sure.
#
# The idle is 5.0 s = one captcha round of the VFX (select x4 -> verify -> reset).
#
# CLIPS
#   idle (5.0 s, 150 f, loop)
#     f0-12    studying: head tilted, chin up at the grid, weight on the right leg, left hand
#              on the hip, right hand hovering in front of the grid
#     f15-22   SELECT #1 (high right tile): pull back -> jab (EXPO) -> recoil (BACK);
#              the head nods into each jab 2 frames late
#     f33-40   SELECT #2 (centre-left), f51-58 SELECT #3 (top-left)
#     f60-80   hesitation: hand goes up to scratch the head (3 little scratches), head tilts
#              the other way, weight shifts to the left leg
#     f83-90   SELECT #4: a quick decisive jab, then a confident nod
#     f94-104  VERIFY: big wind-up (lean back, arm cocked), push forward with the whole body
#              (BACK overshoot), then a satisfied chest-up settle
#     f112-124 ROBOT: arms snap stiff to the sides, head snaps left / right / front on CONST
#              keys (pure machine moves)
#     f128-150 shakes it off (shoulder shimmy, head roll) and goes back to studying
#   walk (lib.STRIDE): a distracted phone-zombie shuffle: the grid is held in both hands like a
#     phone, head down, short steps, the thumb on the side of the landing foot taps it.
#   denied (1.0 s, add, trigger "denied"): when the VFX rejects the answer ("TRY AGAIN"), the
#     head drops and shakes "no", shoulders slump (VFX -> body).
#
# MARKERS (AurasExtra A.Captcha)
#   select  f19, f37, f55, f87   the finger jab     -> the next tile of the grid flips and
#                                                       lights up, sparks fly from the fingertip,
#                                                       its floor tile flashes
#   verify  f100                 the VERIFY push    -> the checkmark pops (or 1 in 5: tiles flash
#                                                       red, "TRY AGAIN" -> emits "denied"),
#                                                       spark burst, light surge
#   beep    f112, f116, f120     robot head snaps   -> the label glitches to BEEP / BOOP / ...,
#                                                       binary sparks from the head
#   (free) step -> while walking every footfall selects the next tile; after four, the next
#          footfall verifies
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Captcha")


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
idle = A.clip("idle", seconds=5.0)  # 150 frames
K = idle.key


def legs(w):
    # w = +1 weight on the right leg, -1 on the left
    return dict(root_pos=(0.07 * w, 0, 0), rh=(0, 0, 2.5 + 1.5 * w), lh=(0, 0, -2.5 + 1.5 * w))


HIP = (-8, 0, -24)  # left hand on the hip
STUDY = dict(root=(2, 4, -1.5), neck=(7, 6, 11), rs=(68, 4, 10), ls=HIP)


def select(f, el, az, marker=True):
    """A finger jab at the grid tile at elevation `el`, azimuth `az` (+ right)."""
    K(f - 4, ease="OUT", rs=(el - 12, 4, az), root=(3, 4 - az * 0.2, -1.5))
    K(f, ease="EXPO", rs=(el, 4, az), root=(-3, 4 - az * 0.25, -1.5))
    K(f + 2, ease="EXPO", neck=(2 + (el - 90) * 0.3, 6 - az * 0.5, 8))
    K(f + 6, ease="BACK", rs=(el - 6, 4, az), root=(0, 4 - az * 0.2, -1.5))
    K(f + 8, neck=(6 + (el - 90) * 0.3, 6 - az * 0.4, 10))
    if marker:
        idle.marker(f, "select")


K(0, **STUDY, **legs(1))
K(10, neck=(9, 8, 13), rs=(72, 4, 6))
select(19, 104, 16)
select(37, 84, -6)
select(55, 110, -12)
# hesitation: scratch the head, tilt the other way, weight moves left
K(63, rs=(120, 4, 2), neck=(4, 2, -4), root=(1, 2, 1), **legs(-0.2))
K(67, ease="OUT", rs=(158, 4, 6), neck=(2, 0, -12), root=(2, 0, 2), **legs(-1))
K(70, rs=(150, 4, 12))
K(73, rs=(160, 4, 4))
K(76, rs=(151, 4, 12))
K(79, rs=(158, 4, 5), neck=(5, 4, -10))
# SELECT #4 - decisive
K(83, ease="OUT", rs=(78, 4, 20), root=(4, 0, 0), neck=(6, -4, 2), **legs(0.2))
K(87, ease="EXPO", rs=(92, 4, 20), root=(-4, -2, 0), **legs(1))
idle.marker(87, "select")
K(89, ease="EXPO", neck=(-6, -6, 3))  # confident nod
K(93, rs=(84, 4, 18), neck=(4, -4, 2))
# VERIFY: wind-up, push with the whole body, settle chest-up
K(96, ease="OUT", rs=(52, 4, 14), root=(6, 3, 0), root_pos=(0.05, 0.02, 0.08),
  neck=(8, 0, 0), ls=(-12, 0, -26))
K(100, ease="BACK", rs=(94, 4, 2), root=(-9, -2, 0), root_pos=(0.07, -0.05, -0.12),
  neck=(-4, 0, 0), ls=(-16, 0, -22))
idle.marker(100, "verify")
K(104, rs=(86, 4, 4), root=(-6, -2, 0))
K(109, rs=(20, 2, 8), root=(5, 0, 0), root_pos=(0.05, 0.02, 0), neck=(10, 0, 2), ls=(-4, 0, -12))
# ROBOT: stiff arms, mechanical head snaps
ROBOT = dict(rs=(0, 0, 3), ls=(0, 0, -3), root=(0, 0, 0), root_pos=(0, 0, 0),
             rh=(0, 0, 1), lh=(0, 0, -1))
K(111, ease="CONST", neck=(0, 0, 0), **ROBOT)
K(112, ease="CONST", neck=(0, 32, 0))
idle.marker(112, "beep")
K(116, ease="CONST", neck=(0, -32, 0))
idle.marker(116, "beep")
K(120, ease="CONST", neck=(0, 0, 0))
idle.marker(120, "beep")
K(124, ease="CONST", rs=(0, 0, 3), ls=(0, 0, -3), root=(0, 0, 0))
# shake it off
K(128, ease="OUT", root=(0, 3, 4), neck=(-4, -8, -9), rs=(10, 0, 14), ls=(6, 0, -14))
K(132, root=(0, -3, -4), neck=(-2, 8, 9), rs=(4, 0, 6), ls=(10, 0, -20))
K(137, root=(1, 2, 1), neck=(4, 4, 6), rs=(40, 4, 10), ls=(-6, 0, -22), **legs(0.6))
K(150, **STUDY)
idle.loop()
idle.noise("neck", 2, 1.5, cycles=(2, 3), seed=7)
idle.noise("root", 0, 0.8, cycles=(2, 3, 5), seed=8)  # breathing
idle.noise("ls", 0, 1.2, cycles=(1, 2), seed=9)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(f, s):
    # the grid is held like a phone in both hands; the thumb on the side of the landing
    # foot taps it
    walk.key(f, ease="OUT",
             root=(-5, -4 * s, -1.2 * s), root_pos=(0, -0.08, 0),
             neck=(-20, 3 * s, 6 * s),
             rs=(58 if s > 0 else 62, 4, -13), ls=(58 if s < 0 else 62, -4, 13),
             rh=(18 * s, 0, 2), lh=(-18 * s, 0, -2))
    tap_r = s > 0
    walk.key(f + 2, ease="EXPO", rs=(70 if tap_r else 62, 4, -13), ls=(62 if tap_r else 70, -4, 13))


def passing(f, s):
    walk.key(f, root=(-6, 0, 1.0 * s), root_pos=(0, 0.04, 0),
             neck=(-17, 0, 0), rs=(64, 4, -13), ls=(64, -4, 13),
             rh=(-2 * s, 0, 2), lh=(2 * s, 0, -2))


contact(0, 1)
passing(h * 0.5, 1)
contact(h, -1)
passing(h * 1.5, -1)
walk.loop()

# ------------------------------------------------------------------ denied (VFX -> body)
dn = A.clip("denied", seconds=1.0, trigger="denied", mode="add", blend_in=0.05, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
dn.pose(0, Z)
dn.pose(4, P(Z, neck=(-18, 0, 0), root=(-5, 0, 0), rs=(-8, 0, -3), ls=(-8, 0, 3)), ease="EXPO")
dn.pose(9, P(Z, neck=(-16, 14, 0), root=(-5, 0, 0), rs=(-8, 0, -3), ls=(-8, 0, 3)))
dn.pose(14, P(Z, neck=(-16, -14, 0), root=(-5, 0, 0), rs=(-8, 0, -3), ls=(-8, 0, 3)))
dn.pose(19, P(Z, neck=(-16, 10, 0), root=(-4, 0, 0)))
dn.pose(30, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
