# Trojan (1 in 1,500, Rare): "A gift you should not have opened."
# Concept: the innocent gift-giver. Hands clasped behind the back, rocking on the heels,
# humming - then a shifty look around, a too-friendly OFFER of the gift with the right hand,
# a slow creepy head tilt while the gift is held out (the trojan shows its face), and the
# hand snaps back behind the back as if nothing happened.
#
# CLIPS
#   idle (5.0 s, 150 f, loop)
#     f0-40    hands behind the back, rocking heel -> toe -> heel, head hums side to side
#     f44-68   shifty look-around: glance left (hold), whip right (hold), back to centre
#     f70      anticipation: lean in, shoulders forward, eyes down at the "victim"
#     f78      OFFER: right arm swings forward palm up (BACK overshoot), friendly head tilt,
#              two little "go on, take it" pushes (f86, f93)
#     f100     CREEP: head tilts hard and drops, torso leans in - the trojan reveals itself
#     f110     HIDE: the hand whips back behind the back (EXPO), body straightens, innocent
#     f118-150 rocking again into the loop
#   walk (lib.STRIDE): innocent stroll - hands stay clasped behind the back (small counter
#     swing), chest out, exaggerated hip sway and a side-to-side head bob on every step.
#   peek (0.9 s, add, trigger "giftpop"): whenever a gift box in the VFX pops its lid, the
#     head darts toward it and back (VFX -> body).
#
# MARKERS (AurasMid A.Trojan)
#   tap   f24, f132  rocks onto the toes        -> red sparks puff from both feet
#   offer f78        the gift is held out        -> a gift box flies into the right hand, lid
#                                                   pops, spark burst from the hand
#   push  f86, f93   "take it" nudges            -> the box in the hand bounces, small sparks
#   creep f100       the creepy head tilt        -> the knight hologram blazes (no flicker,
#                                                   bright), label flips to TROJAN.EXE, light
#                                                   surges, spark rain from the knight
#   hide  f110       hand snaps back             -> the box flies back to its orbit, label
#                                                   returns to GIFT.EXE
#   (free events) step -> sparks drip from the landing foot; VFX emits "giftpop" -> peek
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Trojan")


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


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=5.0)  # 150 frames

# hands clasped behind the back: arms swung back and a little inward
BACK_R, BACK_L = (-30, 0, -9), (-30, 0, 9)
INNO = dict(  # innocent, chest out, chin up
    root=(3, 0, 0), root_pos=(0, 0, 0), neck=(4, 0, 0),
    rs=BACK_R, ls=BACK_L, rh=(0, 0, 1.5), lh=(0, 0, -1.5),
)
HEEL = P(INNO, root=(6, 0, 0), root_pos=(0, 0, 0.06), neck=(6, 0, 7),
         rs=(-34, 0, -9), ls=(-34, 0, 9), rh=(-3, 0, 1.5), lh=(-3, 0, -1.5))
TOE = P(INNO, root=(-2, 0, 0), root_pos=(0, 0.07, -0.05), neck=(1, 0, -7),
        rs=(-26, 0, -9), ls=(-26, 0, 9), rh=(3, 0, 1.5), lh=(3, 0, -1.5))

K = idle.pose
K(0, INNO)
K(12, HEEL)
K(24, TOE, ease="BACK")
idle.marker(24, "tap")
K(36, HEEL)
# --- shifty look-around (the head leads, the torso follows a few frames late)
K(44, P(INNO, neck=(0, 34, 4)), ease="EXPO")
K(48, P(INNO, root=(2, 8, 0), neck=(-2, 38, 4)))
K(56, P(INNO, root=(2, 6, 0), neck=(-3, 36, 3)), ease="EXPO")
K(59, P(INNO, root=(2, 2, 0), neck=(-4, -40, -4)))
K(63, P(INNO, root=(2, -9, 0), neck=(-5, -42, -5)))
K(68, P(INNO, root=(1, -4, 0), neck=(-2, -10, 0)), ease="IN")
# --- anticipation: lean in toward the "victim", eyes down
K(73, P(INNO, root=(-9, 4, 1), root_pos=(0, 0, -0.08), neck=(-12, -4, 4),
        rs=(-40, 0, -10), ls=(-32, 0, 9), rh=(7, 0, 1.5), lh=(7, 0, -1.5)), ease="BACK")
# --- OFFER: right arm swings forward, palm up, friendly tilt
OFFER = P(INNO, root=(-6, 10, -2), root_pos=(0.05, 0, -0.1), neck=(-3, -6, 12),
          rs=(78, 14, 6), ls=(-34, 0, 11), rh=(5, 0, 2), lh=(6, 0, -3))
K(78, OFFER)
idle.marker(78, "offer")
K(83, P(OFFER, rs=(72, 12, 6), neck=(-2, -6, 10)))
K(86, P(OFFER, rs=(84, 14, 6), root=(-8, 11, -2), neck=(-5, -6, 14)), ease="EXPO")
idle.marker(86, "push")
K(90, P(OFFER, rs=(74, 12, 6)))
K(93, P(OFFER, rs=(86, 14, 6), root=(-8, 11, -2), neck=(-5, -6, 15)), ease="EXPO")
idle.marker(93, "push")
# --- CREEP: slow, wrong head tilt; the smile drops
CREEP = P(OFFER, root=(-12, 12, -4), root_pos=(0.05, -0.02, -0.14), neck=(-16, -10, 28),
          rs=(82, 18, 4), ls=(-38, 0, 12))
K(98, P(OFFER, rs=(80, 14, 6), neck=(-6, -6, 14)), ease="IN")
K(104, CREEP)
idle.marker(100, "creep")
K(108, P(CREEP, neck=(-18, -12, 31)), ease="EXPO")
# --- HIDE: the hand whips back, body pops upright and innocent again
K(111, P(INNO, root=(5, 2, 0), root_pos=(0, 0.03, 0.02), neck=(8, 4, -4),
         rs=(-36, 0, -9), ls=(-32, 0, 9)), ease="BACK")
idle.marker(110, "hide")
K(118, P(INNO, neck=(4, 3, -2)))
K(126, HEEL)
K(132, TOE, ease="BACK")
idle.marker(132, "tap")
K(142, P(HEEL, neck=(5, 0, 3)))
idle.loop()
wobble(idle, "neck", 1, 1.5, 3, 0.4)
wobble(idle, "neck", 2, 1.2, 4, 1.7)
wobble(idle, "root", 1, 1.0, 2, 2.1)
wobble(idle, "rs", 2, 0.8, 3, 0.2)
wobble(idle, "ls", 2, 0.8, 3, 1.4)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(s):
    return dict(
        root=(3, -6 * s, -4 * s), root_pos=(0, 0, 0), neck=(4, 5 * s, 7 * s),
        rs=(-30 + 5 * s, 0, -8), ls=(-30 - 5 * s, 0, 8),
        rh=(25 * s, 0, 1.5), lh=(-25 * s, 0, -1.5),
    )


def passing(s):
    return dict(
        root=(4, 0, 3 * s), root_pos=(0, 0.13, 0), neck=(5, 0, -3 * s),
        rs=(-31, 0, -9), ls=(-31, 0, 9),
        rh=(-3 * s, 0, 1.5), lh=(3 * s, 0, -1.5),
    )


W = walk.pose
W(0, contact(1), ease="OUT")
W(h * 0.5, passing(1))
W(h, contact(-1), ease="OUT")
W(h * 1.5, passing(-1))
walk.loop()
wobble(walk, "neck", 1, 4, 1, 0.0)  # slow innocent glance across the stride

# ------------------------------------------------------------------ peek (additive, VFX -> body)
peek = A.clip("peek", seconds=0.9, trigger="giftpop", mode="add", blend_in=0.05, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
peek.pose(0, Z, ease="EXPO")
peek.pose(4, P(Z, neck=(-8, 42, 8), root=(0, 6, 0), rs=(-4, 0, 0), ls=(-4, 0, 0)))
peek.pose(8, P(Z, neck=(-10, 40, 10), root=(0, 9, 0)), ease="EXPO")
peek.pose(15, P(Z, neck=(2, -6, -2), root=(0, -1, 0)))
peek.pose(27, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
