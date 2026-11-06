# Deadlock (1 in 900, Enhanced): "Waiting for itself. Forever."  look: two padlocks orbiting
# and chained together with beams.
# Concept: the body is the two threads. The wrists are shackled together in front (the chain
# between the two padlocks); the left half tries to go left, the right half yanks it back,
# then the other way round; finally both pull apart at once and lock up in a trembling
# standoff - nobody wins, the body slumps and taps its foot, waiting. Forever.
#
# CLIPS
#   idle (5.0 s, 150 f, loop)
#     f0-26    WAITING: wrists together in front, head down; the eyes go from the left lock to
#              the right lock (neck leads, torso follows 3 frames later)
#     f28-48   TUG LEFT: anticipation lean right -> lunge left (weight onto the left leg, arms
#              dragged left) -> YANKED BACK by the right half (EXPO snap past centre, head lags
#              and whips, overshoot settle)
#     f52-74   TUG RIGHT: the mirror image, a bit harder
#     f78-104  STRAIN: both arms pull apart at once, the chain stops them dead (EXPO), the body
#              rises onto the toes and trembles (2-frame LINEAR jitter on torso + arms), head
#              down, gritting
#     f104-114 SLUMP: everything gives up at once (EXPO), torso drops forward, head hangs
#     f116-150 IMPATIENT TAP: straightens, head tilts, the right foot taps twice, a sigh, back
#              to waiting
#   walk (lib.STRIDE): a shackled SHUFFLE - short choppy steps, the torso rocks side to side,
#     the chained hands stay together in front and jerk forward on every contact (chain clink),
#     head low.
#   jolt (0.6 s, add, trigger "jolt"): when the VFX fires a strain on its own (walking / no
#     idle markers) it emits "jolt" -> arms yank apart, chest jerks (VFX -> body).
#
# MARKERS (AurasExtra A.Deadlock)
#   look "L" / "R"  f12, f24      eyes on a lock   -> that lock's "WAITING FOR #n" tag flashes
#                                                    bright, its keyhole blinks
#   tug "L" / "R"   f36, f62      lunge            -> both padlocks are dragged toward that side
#                                                    along the orbit, the chain goes taut
#   yank            f40, f66      snapped back     -> the locks recoil, chain clinks: sparks at the
#                                                    chain middle, light blip
#   strain          f84           the standoff     -> full strain for 0.8 s: chain taut + glowing,
#                                                    keyholes white, spark shower, red light surge,
#                                                    the floor ring halts
#   slump           f108          gives up         -> chain sags extra, light dims, smoke puff
#   tap             f124, f132    foot taps        -> a dust puff and floor ring tick AT THE RIGHT FOOT
#   clink           walk f0, half chained hands jerk -> chain clink sparks
#   (free) step -> dust at that foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Deadlock")


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


def plant(clip, passes=2):
    """Raise root-height keys just enough that the lowest sole touches the floor."""
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


def legs(w, lean=0.0):
    return dict(root_pos=(0.08 * w, 0, 0), rh=(lean, 0, 2.5 - 2.0 * w), lh=(lean, 0, -2.5 - 2.0 * w))


def cuffs(dx=0.0, fwd=48.0):
    """Wrists chained together in front. dx > 0 drags both hands to the character's LEFT
    (degrees of extra sideways swing), fwd = how far forward the arms reach. The arms swing
    inward with z FIRST (Roblox Angles order: z, then y, then x) and are then raised forward."""
    return dict(rs=(fwd, 0, -27 - 0.8 * dx), ls=(fwd, 0, 27 - 0.8 * dx))


# f0-26 waiting, eyes go lock to lock
K(0, root=(-3, 0, 0), neck=(-10, -14, -2), **cuffs(), **legs(0, 3))
K(9, neck=(-9, -14, -2))
K(12, ease="EXPO", neck=(-8, 22, 3))
idle.marker(12, "look", "L")
K(15, root=(-3, 5, 0.5))
K(20, neck=(-8, 21, 3))
K(24, ease="EXPO", neck=(-9, -20, -3))
idle.marker(24, "look", "R")
K(27, root=(-3, -4, -0.5))
# f28-48 TUG LEFT
K(31, ease="INOUT", root=(-2, -6, -4), **cuffs(-6, 44), **legs(0.8, 2))
K(32, neck=(-6, -10, -4))
K(36, ease="EXPO", root=(-6, 12, 7), **cuffs(22, 54), **legs(-1, 6))
K(36, root_pos=(-0.2, 0, 0))
idle.marker(36, "tug", "L")
K(37, ease="EXPO", neck=(-12, 20, 5))
K(40, ease="EXPO", root=(-2, -10, -6), **cuffs(-20, 42), root_pos=(0.1, 0, 0),
  rh=(2, 0, 0.5), lh=(2, 0, -4.5))
idle.marker(40, "yank")
K(42, ease="EXPO", neck=(-4, -14, 10))
K(46, ease="BACK", root=(-3, 3, 1.5), **cuffs(4, 48), **legs(0, 3))
K(48, ease="BACK", neck=(-9, 6, -2))
# f52-74 TUG RIGHT (mirror, harder)
K(57, ease="INOUT", root=(-2, 6, 4), **cuffs(6, 44), **legs(-0.8, 2))
K(58, neck=(-6, 10, 4))
K(62, ease="EXPO", root=(-7, -14, -8), **cuffs(-24, 56), **legs(1, 7))
K(62, root_pos=(0.22, 0, 0))
idle.marker(62, "tug", "R")
K(63, ease="EXPO", neck=(-13, -22, -6))
K(66, ease="EXPO", root=(-2, 11, 7), **cuffs(22, 42), root_pos=(-0.11, 0, 0),
  rh=(2, 0, 4.5), lh=(2, 0, -0.5))
idle.marker(66, "yank")
K(68, ease="EXPO", neck=(-4, 15, -11))
K(72, ease="BACK", root=(-3, -3, -1.5), **cuffs(-4, 48), **legs(0, 3))
K(74, ease="BACK", neck=(-9, -5, 2))
# f78-104 STRAIN: pull apart, the chain stops them, trembling standoff
K(80, ease="IN", root=(-5, 0, 0), rs=(44, 0, -34), ls=(44, 0, 34), neck=(-14, 0, 0),
  root_pos=(0, 0, 0), rh=(5, 0, 3), lh=(5, 0, -3))
K(84, ease="EXPO", root=(2, 0, 0), rs=(46, 0, 22), ls=(46, 0, -22), neck=(-18, 0, 0),
  root_pos=(0, 0.07, 0), rh=(0, 0, 4), lh=(0, 0, -4))
idle.marker(84, "strain")
for i, f in enumerate(range(86, 103, 2)):
    s = 1 if i % 2 == 0 else -1
    K(f, ease="LINEAR", root=(2 + 0.5 * s, 0.8 * s, 1.4 * s),
      rs=(46 + s, 0, 22 - 1.5 * s), ls=(46 - s, 0, -22 - 1.5 * s),
      neck=(-18 - s, 1.5 * s, -1.5 * s), root_pos=(0, 0.07 + 0.012 * s, 0))
# f104-114 SLUMP
K(108, ease="EXPO", root=(-12, 0, 2), **cuffs(0, 50), neck=(-26, 4, 6),
  root_pos=(0, 0, 0), rh=(12, 0, 2.5), lh=(12, 0, -2.5))
idle.marker(108, "slump")
K(114, root=(-10, 1, 2), neck=(-24, 5, 7))
# f116-150 impatient tap, sigh, back to waiting
K(119, ease="OUT", root=(-1, 3, 1), neck=(-3, 8, 9), **cuffs(0, 44), **legs(-0.8, 1))
K(121, rh=(14, 0, 3.5))
K(124, ease="EXPO", rh=(2, 0, 3.5))
idle.marker(124, "tap")
K(128, ease="OUT", rh=(14, 0, 3.5), neck=(-4, 9, 11))
K(132, ease="EXPO", rh=(2, 0, 3.5))
idle.marker(132, "tap")
K(138, root=(-5, 0, 0), neck=(-12, -4, 0), root_pos=(-0.03, 0, 0), rh=(3, 0, 3), lh=(3, 0, -1.5))
K(144, root=(-3, 0, 0), neck=(-10, -12, -2))
idle.loop()
idle.noise("neck", 1, 1.2, cycles=(2, 3, 5), seed=31)
idle.noise("root", 0, 0.8, cycles=(1, 2, 3), seed=32)  # breathing
idle.noise("rs", 2, 1.0, cycles=(3, 4, 6), seed=33)  # the cuffs never sit still
idle.noise("ls", 2, 1.0, cycles=(3, 4, 6), seed=33)  # (same seed: the wrists move together)

# ------------------------------------------------------------------ walk (shackled shuffle)
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(f, s):
    walk.key(f, ease="EXPO",
             root=(-6, -4 * s, -5 * s), root_pos=(0.06 * s, 0, 0),
             rs=(56, 0, -27 + 3 * s), ls=(56, 0, 27 + 3 * s),
             rh=(5 + 16 * s, 0, 2), lh=(5 - 16 * s, 0, -2))
    walk.key(f + 1, ease="OUT", neck=(-14, 4 * s, 4 * s))
    walk.key(f + 3, ease="INOUT", rs=(46, 0, -27 + 2 * s), ls=(46, 0, 27 + 2 * s))
    walk.marker(f, "clink")


def passing(f, s):
    walk.key(f, root=(-5, 0, 1.5 * s), root_pos=(0, 0.05, 0),
             rh=(5 - 2 * s, 0, 2), lh=(5 + 2 * s, 0, -2))
    walk.key(f + 1, neck=(-10, 0, 0))


contact(0, 1)
passing(h * 0.5, 1)
contact(h, -1)
passing(h * 1.5, -1)
walk.loop()

# ------------------------------------------------------------------ jolt (VFX -> body)
jo = A.clip("jolt", seconds=0.6, trigger="jolt", mode="add", blend_in=0.03, blend_out=0.18)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
jo.pose(0, Z)
jo.pose(3, P(Z, root=(4, 0, 0), neck=(-8, 0, 0), rs=(-4, 0, 16), ls=(-4, 0, -16)), ease="EXPO")
jo.pose(6, P(Z, root=(2, 0, 1.5), neck=(-6, 0, 2), rs=(-2, 0, 12), ls=(-2, 0, -12)))
jo.pose(18, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
