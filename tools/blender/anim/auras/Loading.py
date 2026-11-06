# Loading (1 in 9, Basic): "Please wait..."  look: spinning loading-circle segments around the
# waist and a progress bar above the head.
# Concept: the player is STUCK WAITING for their own aura to load. The head idly traces a
# slow buffering circle, the foot taps the seconds away, the bar freezes at 99 % and the body
# freezes with it, impatience (hands on hips, head shake, big sigh), then DONE! - a little fist
# pump - and immediately the bar restarts at 0 % and the shoulders slump. Basic tier: small,
# readable, a bit funny.
#
# CLIPS
#   idle (4.0 s, 120 f, loop)  - one full "load" of the progress bar
#     f0-44    WAITING: weight on the right leg, the head circles like a spinner (one turn per
#              ~1.5 s, the torso counter-circles a little and lags), arms hang loose; the left
#              foot taps 4 times (f12/20/28/36: quick lift -> EXPO strike)
#     f44-56   the circle slows, the eyes drift up toward the bar overhead
#     f56-62   STALL: CONST freeze-frame - head up, chest back, everything held still like the
#              frozen bar (99 %)
#     f62-84   IMPATIENT: hands go to the hips (BACK overshoot), weight crosses to the left leg,
#              "tsk" head shake (3 snaps), a big sigh (shoulders rise f76, drop f82)
#     f86      DONE: snap perk-up - right fist pump (BACK overshoot), tiny hop, head up
#     f100     RESET: the bar restarts -> the fist drops, head and shoulders slump forward
#     f104-120 recovers into the waiting pose, the head starts circling again
#   walk (lib.STRIDE): a "buffering" stroll - each contact pose HOLDS for 3 frames (CONST
#     lag) then catches up fast through the passing pose, like a video that stutters; arms
#     swing loose and low, the head keeps a small lazy circle.
#
# MARKERS (AurasExtra A.Loading)
#   tap    f12, f20, f28, f36  foot strikes   -> the waist spinner ticks forward one segment,
#                                               a puff of squares at the LEFT FOOT, the bar
#                                               jumps a chunk
#   stall  f56                 freeze         -> the bar sticks at 99 %, label "ALMOST...", the
#                                               spinner races (frustration), light dims
#   done   f86                 fist pump      -> bar fills, "DONE!", spark burst above the head
#                                               + sparks from THE RIGHT HAND, spinner flashes
#                                               white and stops, light flares
#   reset  f100                slump          -> bar back to 0 %, a new label, the spinner
#                                               starts again from the top
#   lag    walk f1, f11.5      walk stutter   -> the bar/spinner hiccup for a moment
#   (free) step -> squares shed from the landing foot
# The bar itself follows the shared idle phase (Sync.phase(bus, 4.0)) while standing, so it
# always matches the body; while walking it runs on its own random loader.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Loading")


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


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.0)  # 120 frames
K = idle.key


def legs(w, y=0.0):
    # w -1..1 = weight on the left .. right leg
    return dict(root_pos=(0.07 * w, y, 0), rh=(0, 0, 1.8 * w + 1.6), lh=(0, 0, 1.8 * w - 1.6))


HANG_R, HANG_L = (3, 0, 6), (3, 0, -6)

# WAITING: the head traces a buffering circle (keys every 6 f), torso counter-circles 2 f late
K(0, rs=HANG_R, ls=HANG_L, **legs(1))
for i in range(9):  # f0..48, one and a half turns slowing down at the end
    f = i * 6
    phi = i * (2 * math.pi / 6.5)
    amp = 6 if i < 7 else 4
    K(f, neck=(-2 + amp * math.sin(phi), 2 * math.cos(phi), amp * math.cos(phi)))
    K(f + 2, root=(-1.2 * math.sin(phi), 3, -2 + 1.2 * math.cos(phi)))


def tap(f):
    # left toe lifts quickly (OUT) and strikes down (EXPO); the knee-less leg swings forward
    K(f - 3, ease="OUT", lh=(13, 0, 0.6))
    K(f, ease="EXPO", lh=(0, 0, 0.2))
    K(f, rs=(3 + 1.2, 0, 6), ls=(3 + 2, 0, -7))  # the loose arm bounces with the strike
    K(f + 3, rs=HANG_R, ls=HANG_L)
    idle.marker(f, "tap")


for f in (12, 20, 28, 36):
    tap(f)

# eyes drift up toward the bar
K(52, ease="IN", neck=(8, 4, 2), root=(1, 3, -2), rs=(2, 0, 6), ls=(2, 0, -6), **legs(1))
# STALL: freeze-frame (CONST in, CONST hold)
STALL = dict(neck=(17, 3, 3), root=(3.5, 3, -2), rs=(0, 0, 9), ls=(0, 0, -9),
             root_pos=(0.07, 0.03, 0), rh=(0, 0, 3.4), lh=(0, 0, 0.2))
idle.pose(56, STALL, ease="CONST")
idle.marker(56, "stall")
idle.pose(61, P(STALL, neck=(17, 3, 3.5)), ease="EXPO")
# IMPATIENT: hands to the hips (overshoot), weight crosses to the left
AKIMBO_R, AKIMBO_L = (-12, 0, 30), (-12, 0, -30)
K(66, ease="BACK", rs=AKIMBO_R, ls=AKIMBO_L, root=(1, -2, 1.5), neck=(4, -6, -3), **legs(-1))
# "tsk" head shake: three snaps
K(69, ease="EXPO", neck=(2, 9, -2))
K(72, ease="EXPO", neck=(2, -8, -3))
K(75, ease="EXPO", neck=(1, 5, -2))
# big sigh: shoulders up, then drop
K(78, ease="INOUT", root=(4, -2, 1.5), root_pos=(-0.07, 0.06, 0), neck=(10, -2, -1),
  rs=(-14, 0, 33), ls=(-14, 0, -33))
K(83, ease="OUT", root=(-3, -2, 1.5), root_pos=(-0.07, -0.02, 0), neck=(-6, -2, -2),
  rs=(-8, 0, 26), ls=(-8, 0, -26), rh=(3, 0, -0.4), lh=(3, 0, -3.4))
# DONE: snap perk-up, right fist pump, tiny hop
K(86, ease="EXPO", root=(4, 4, -1), root_pos=(0, 0.14, 0), neck=(12, 6, 2),
  rs=(158, 0, 10), ls=(10, 0, -20), rh=(0, 0, 2.5), lh=(0, 0, -2.5))
idle.marker(86, "done")
K(90, ease="BACK", root=(1, 4, -1), root_pos=(0, 0.0, 0), neck=(8, 5, 2), rs=(146, 0, 6), ls=(6, 0, -12))
K(96, root=(1.5, 3, -1), rs=(150, 0, 8), neck=(9, 6, 2))
# RESET: the bar restarts -> slump
K(100, ease="EXPO", root=(-6, 1, 0), root_pos=(0, -0.04, 0), neck=(-17, 0, 0),
  rs=(10, 0, 3), ls=(10, 0, -3), rh=(6, 0, 1.6), lh=(6, 0, -1.6))
idle.marker(100, "reset")
K(104, ease="OUT", neck=(-14, 1, 2))
K(110, root=(-1.5, 3, -2), neck=(-3, 2, 5), rs=HANG_R, ls=HANG_L, **P(legs(1), rh=(1, 0, 3.4), lh=(1, 0, 0.2)))
idle.loop()
idle.noise("root", 2, 0.5, cycles=(1, 2, 3), seed=31)  # breathing sway
idle.noise("rs", 0, 1.0, cycles=(2, 3, 5), seed=32)
idle.noise("ls", 0, 1.0, cycles=(2, 3, 5), seed=33)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(f, s):
    # s = +1: right foot forward. The pose lands, then HOLDS (buffering), then catches up.
    pose = dict(root=(2, -5 * s, -1.5 * s), root_pos=(0, 0, 0),
                neck=(-3, 4 * s, 3 * s),
                rs=(-20 * s, 0, 6), ls=(20 * s, 0, -6),
                rh=(22 * s, 0, 1.5), lh=(-22 * s, 0, -1.5))
    walk.pose(f, pose, ease="EXPO")
    walk.pose(f + 3, P(pose, neck=(-2, 4.5 * s, 3.5 * s)), ease="EXPO")  # lag hold
    walk.marker(f + 1, "lag")


def passing(f, s):
    walk.key(f, root=(-2, 0, 1.4 * s), root_pos=(0, 0.08, 0),
             neck=(-1, -1 * s, -2 * s),
             rs=(-2, 0, 5), ls=(2, 0, -5),
             rh=(-3 * s, 0, 1.5), lh=(3 * s, 0, -1.5))


contact(0, 1)
passing(h * 0.5 + 1.5, 1)
contact(h, -1)
passing(h * 1.5 + 1.5, -1)
walk.loop()

plant(idle)
plant(walk)

A.lift = 0
A.finish()
