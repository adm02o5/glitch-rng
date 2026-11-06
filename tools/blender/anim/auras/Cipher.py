# Cipher (1 in 600, Enhanced): "Rot13 of something important."
# Concept: a safecracker working the cryptex of letter wheels around their body. Each wheel
# is turned by a hand at its height in little click-stops (EXPO snaps), the head tilts to
# LISTEN for the tumblers, the last click lands, the code is cracked and the arms burst open -
# then a cocky flick of the wrist scrambles everything again.
#
# The cryptex has three wheels: 1 = shin height, 2 = waist, 3 = head height.
#
# CLIPS
#   idle (4.4 s, 132 f, loop)
#     f0-8     ready: leaning in, both hands hovering at the waist, head cocked
#     f8-26    WHEEL 1: bends down over it (torso forward, hips compensate), the LEFT hand sweeps
#              the low wheel in three click-stops; the head lags each click by 2 frames
#     f30-50   WHEEL 2: rises, the RIGHT hand turns the waist wheel (three clicks), the torso
#              twists with the hand
#     f54-68   LISTEN: freezes, ear tilted right toward the wheels, left palm up ("wait..."),
#              weight shifts onto the right leg
#     f70-80   WHEEL 3: the right hand reaches up to head height, two clicks, the second one
#              harder (the last tumbler)
#     f84-96   anticipation (everything pulls in) -> CRACKED: arms fly open (BACK overshoot),
#              chest and chin up, a proud nod
#     f108-116 SCRAMBLE: right hand wind-up across the body -> a cocky flick outward (EXPO)
#     f118-132 back to ready
#   walk (lib.STRIDE): a brisk secretive agent walk, slightly hunched, both hands in front of
#     the belly twisting an imaginary cryptex (the hands counter-twist on each footfall), the
#     head scans left and right once per stride.
#   cracked (0.8 s, add, trigger "cracked"): when the VFX cracks the code on its own (while
#     walking), a quick fist pump and a nod (VFX -> body).
#
# MARKERS (AurasExtra A.Cipher)
#   turn "1"/"2"/"3"  f12 f17 f22 / f38 f43 f48 / f74 f79   each click-stop of a hand
#                       -> that wheel advances one notch with a mechanical snap, glyph flips,
#                          purple click-sparks from the turning hand, the read bar blinks
#   solve      f88      arms burst open -> every wheel reads K-E-Y on the bar, DECRYPTED,
#                          light surge, sparks burst from both hands and the floor disc flashes
#   scramble   f113     the wrist flick  -> all wheels spin away several notches, every glyph
#                          re-randomizes, spark spray from the right hand, the solve ends
#   (free) step -> while walking each footfall turns the next wheel; after six turns the VFX
#          cracks the code itself and emits "cracked"
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Cipher")


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
idle = A.clip("idle", seconds=4.4)  # 132 frames
K = idle.key


def stance(lean, w=0.0, drop=0.0):
    """Torso lean (deg, negative = forward) with the hips compensating so the legs stay
    vertical; w = weight shift (+ right leg)."""
    return dict(root_pos=(0.07 * w, -drop, 0),
                rh=(-lean, 0, 2.5 + 1.5 * w), lh=(-lean, 0, -2.5 + 1.5 * w))


READY = dict(root=(-6, 0, 0), neck=(-6, 4, 8), rs=(48, 0, 12), ls=(48, 0, -12))
K(0, **READY, **stance(-6))
# --- WHEEL 1 (low): bend over it, the left hand sweeps in three click-stops
K(8, ease="OUT", root=(-20, -4, 2), neck=(-12, 6, 10), ls=(22, 0, -26), rs=(30, 0, 14),
  **stance(-20, w=-0.4, drop=0.08))
for i, f in enumerate((12, 17, 22)):
    z = -18 + i * 9
    K(f, ease="EXPO", ls=(22 + i * 2, 0, z), root=(-20, -4 + i * 2, 2))
    K(f + 2, ease="EXPO", neck=(-14, 6 - i * 3, 10 - i))
    idle.marker(f, "turn", "1")
K(26, ls=(26, 0, 4))
# --- WHEEL 2 (waist): rise, right hand turns, torso twists along
K(32, root=(-7, 6, 0), neck=(-8, -6, 6), rs=(66, 0, 34), ls=(30, 0, -10), **stance(-7, w=0.2))
for i, f in enumerate((38, 43, 48)):
    z = 26 - i * 11
    K(f, ease="EXPO", rs=(68, 0, z), root=(-7, 6 - i * 5, 0))
    K(f + 2, ease="EXPO", neck=(-8, -6 + i * 5, 6))
    idle.marker(f, "turn", "2")
# --- LISTEN: freeze, ear down toward the wheels, left palm up "wait..."
K(54, ease="OUT", root=(-9, -6, -5), neck=(-6, -10, -22), rs=(60, 0, 4), ls=(82, 0, -10),
  **stance(-9, w=1))
K(66, root=(-10, -7, -6), neck=(-8, -12, -25), ls=(86, 0, -12))
# --- WHEEL 3 (head height): reach up, two clicks, the second one harder
K(70, ease="OUT", root=(-2, 4, 0), neck=(6, -8, 4), rs=(128, 0, 28), ls=(30, 0, -10),
  **stance(-2, w=0.4))
K(74, ease="EXPO", rs=(130, 0, 16), root=(-2, 1, 0))
K(76, ease="EXPO", neck=(8, -4, 4))
idle.marker(74, "turn", "3")
K(79, ease="EXPO", rs=(134, 0, 0), root=(-3, -3, 0))
K(81, ease="EXPO", neck=(10, 2, 2))
idle.marker(79, "turn", "3")
# --- anticipation -> CRACKED
K(85, ease="IN", root=(-8, 0, 0), neck=(-10, 0, 0), rs=(40, 0, -6), ls=(40, 0, 6),
  **stance(-8, drop=0.06))
K(88, ease="BACK", root=(7, 0, 0), neck=(14, 0, 0), rs=(38, 0, 78), ls=(38, 0, -78),
  **stance(7, w=0))
idle.marker(88, "solve")
K(94, root=(5, 0, 0), neck=(10, 0, 3), rs=(34, 0, 70), ls=(34, 0, -70))
K(99, ease="EXPO", neck=(-2, 0, 3))  # proud nod
K(104, root=(3, 2, 0), neck=(6, 0, 4), rs=(20, 0, 40), ls=(18, 0, -36), **stance(3, w=-0.5))
# --- SCRAMBLE: wind-up across the body, cocky flick out
K(109, ease="OUT", root=(-2, 10, 0), neck=(-4, 8, 6), rs=(66, 0, -24))
K(113, ease="EXPO", root=(-4, -10, -2), neck=(-2, -14, 4), rs=(84, 0, 52))
idle.marker(113, "scramble")
K(118, ease="BACK", rs=(70, 0, 42), root=(-4, -8, -1))
K(124, rs=(52, 0, 18), neck=(-5, 0, 6), root=(-5, -2, 0), ls=(44, 0, -14), **stance(-5, w=0))
idle.loop()
idle.noise("neck", 1, 1.5, seed=11)
idle.noise("root", 2, 0.8, cycles=(1, 2, 3), seed=12)
idle.noise("ls", 2, 1.5, cycles=(2, 3, 5), seed=13)  # restless fingers
idle.noise("rs", 2, 1.5, cycles=(2, 3, 5), seed=14)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(f, s):
    # hands counter-twist the imaginary cryptex on each footfall
    walk.key(f, ease="EXPO",
             root=(-13, -7 * s, -2 * s), root_pos=(0, -0.12, 0),
             neck=(4, 0, 4 * s),
             rs=(34 + 9 * s, 0, -17 + 5 * s), ls=(34 - 9 * s, 0, 17 + 5 * s),
             rh=(20 * s + 13, 0, 2), lh=(-20 * s + 13, 0, -2))


def passing(f, s):
    walk.key(f, root=(-14, 0, 1.2 * s), root_pos=(0, 0.03, 0),
             neck=(6, 20 * s, -3 * s),  # shifty scan left / right
             rs=(36, 0, -15), ls=(36, 0, 15),
             rh=(13 - 2 * s, 0, 2), lh=(13 + 2 * s, 0, -2))


contact(0, 1)
passing(h * 0.5, 1)
contact(h, -1)
passing(h * 1.5, -1)
walk.loop()

# ------------------------------------------------------------------ cracked (VFX -> body)
ck = A.clip("cracked", seconds=0.8, trigger="cracked", mode="add", blend_in=0.04, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
ck.pose(0, Z)
ck.pose(3, P(Z, rs=(-14, 0, 6), root=(-3, 0, 0)), ease="OUT")
ck.pose(7, P(Z, rs=(62, 0, 10), root=(4, -4, 0), neck=(8, 0, 0)), ease="BACK")
ck.pose(11, P(Z, rs=(40, 0, 8), root=(2, -3, 0), neck=(-8, 0, 0)), ease="EXPO")
ck.pose(15, P(Z, rs=(48, 0, 8), root=(2, -3, 0), neck=(2, 0, 0)))
ck.pose(24, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
