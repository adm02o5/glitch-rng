# Byte (1 in 7, Basic): "Eight bits of pure ambition."  look: 8 tiny cyan cubes orbiting the
# waist (each cube = one bit, lit = 1), a floor bit-register and a "01011010 5A" readout.
# Concept: a tiny 8-bit hero with BIG ambitions. The body moves like a chiptune sprite: chunky
# snaps on a 0.4 s beat (8 beats per loop = 8 bits), the right fist climbs one notch per beat
# (each notch switches one more bit ON), tops out at 0xFF with a proud fist pump... and then the
# byte OVERFLOWS: everything snaps back to 0 and the little guy slumps, shakes it off and starts
# counting again. Basic tier: small, readable, a little funny.
#
# CLIPS
#   idle (3.2 s, 96 f, loop) - beats every 12 f
#     f0-24    READY: chest out, fists at the sides, a chiptune heel-bounce on every beat (EXPO
#              dip, soft rise), the head snaps left / right in hard 8-bit steps (CONST)
#     f24-60   CLIMB: the right fist rises one notch per beat (f24/36/48/60, EXPO snap + tiny
#              settle), the head and chest follow it up 2-3 frames late, the left arm swings back
#              to counterbalance, weight drifts onto the left leg
#     f62      anticipation: crouch, fist dips, torso folds forward
#     f66      MAX (0xFF): pop up onto the toes (BACK overshoot), right fist fully up, left fist
#              punched out to the side, chest proud, head up
#     f78      OVERFLOW: CONST snap into a slump - arm drops, head droops, chest caves
#     f80-84   head shake ("nope"), f86-96 recovers into READY with a small shrug (BACK)
#   walk (lib.STRIDE): an 8-bit SPRITE MARCH - 8 hard-held poses per stride (CONST, ~11 fps
#     like an NES walk cycle): stiff straight-arm swings with fists, chest proud, head steady,
#     the body pops up on the passing poses.
#
# MARKERS (AurasLow A.Byte)
#   bit    idle f0, f12, f84; walk f0 + half   -> one random bit flips (cube spins, floor
#                                                 segment toggles, squares puff)
#   up     f24, f36, f48, f60   fist notch     -> the next OFF bit switches ON (the register
#                                                 visibly counts up with the arm), spark from
#                                                 THE RIGHT FIST, readout flashes
#   max    f66                  fist pump      -> all bits ON (11111111 FF), cubes flash white
#                                                 and swing out wide, spark burst from the fist,
#                                                 light flares
#   reset  f78                  overflow slump -> all bits OFF (00000000 00), cubes sag and dim,
#                                                 the light dips, "OVERFLOW" in the readout
#   (free) step -> squares kick up from the landing foot, a bit flips on the floor register
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Byte")


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
idle = A.clip("idle", seconds=3.2)  # 96 frames, 8 beats of 12 f
K = idle.key

READY = dict(
    root=(3, 0, 0), root_pos=(0, 0, 0),
    neck=(3, 8, 0),
    rs=(4, 0, 9), ls=(4, 0, -9),
    rh=(0, 0, 3.5), lh=(0, 0, -3.5),
)

# READY: two chiptune bounces, head snapping in 8-bit steps
idle.pose(0, READY, ease="EXPO")
K(0, ease="EXPO", root_pos=(0, -0.05, 0))
K(5, root_pos=(0, 0.015, 0), rs=(6, 0, 11), ls=(6, 0, -11))
K(0, ease="CONST", neck=(3, 8, 0))
K(12, ease="CONST", neck=(4, -8, -2))
K(12, ease="EXPO", root=(3, -2, -0.8), root_pos=(0, -0.05, 0), rs=(4, 0, 9), ls=(4, 0, -9))
K(17, root_pos=(0, 0.015, 0), rs=(6, 0, 11), ls=(6, 0, -11))
K(20, ease="CONST", neck=(5, 0, 0))
idle.marker(0, "bit")
idle.marker(12, "bit")

# CLIMB: the right fist rises one notch per beat; head + chest follow 2-3 frames late
notches = [
    # frame, rs, ls, neck, root, root_pos x (weight drifts left)
    (24, (40, -14, 20), (0, 0, -10), (8, -2, -2), (4, -1, 0.5), -0.02),
    (36, (80, -32, 10), (-8, 0, -12), (12, -4, -3), (5, -2, 1.2), -0.04),
    (48, (118, -34, 8), (-14, 0, -14), (17, -5, -4), (6, -3, 1.8), -0.06),
    (60, (156, -20, 8), (-18, 0, -16), (22, -6, -5), (7, -4, 2.4), -0.07),
]
for f, rs, ls, neck, root, wx in notches:
    K(f - 1, ease="CONST", rs=(rs[0] - 34, rs[1] * 0.6, rs[2]))  # hold the old notch until the snap
    K(f, ease="EXPO", rs=(rs[0] + 6, rs[1], rs[2] + 2))  # snap past the notch
    K(f + 3, ease="INOUT", rs=rs)  # settle onto it
    K(f + 2, ease="OUT", neck=neck)  # head follows late
    K(f + 3, ease="INOUT", root=root, ls=ls, root_pos=(wx, 0, 0),
      rh=(0, 0, 3.5 + 2 * wx), lh=(0, 0, -3.5 + 2 * wx))
    idle.marker(f, "up")
K(58, neck=(19, -5, -4))

# anticipation crouch
K(63, ease="IN", root=(-6, -2, 1), root_pos=(-0.05, -0.12, 0),
  neck=(4, -2, -2), rs=(140, 0, 16), ls=(8, 0, -16),
  rh=(26, 0, 3), lh=(26, 0, -3))
# MAX: pop onto the toes, fist pump, left fist punched out
MAX = dict(root=(7, 3, -1), root_pos=(0, 0.16, 0),
           neck=(20, 4, 2),
           rs=(176, 0, 4), ls=(30, 0, -60),
           rh=(-3, 0, 5), lh=(-3, 0, -5))
idle.pose(66, MAX, ease="BACK")
idle.marker(66, "max")
K(70, ease="BOUNCE", root_pos=(0, 0, 0), rh=(0, 0, 4), lh=(0, 0, -4))
K(71, root=(5, 3, -1), rs=(168, 0, 7), ls=(24, 0, -52), neck=(16, 5, 2))
K(77, root=(5.5, 2, -1), rs=(170, 0, 6), ls=(26, 0, -55), neck=(17, 3, 2))

# OVERFLOW: hard snap into a slump
SLUMP = dict(root=(-7, 0, 2), root_pos=(0, -0.04, 0),
             neck=(-18, 0, 7),
             rs=(6, 0, 4), ls=(6, 0, -4),
             rh=(3, 0, 2.5), lh=(3, 0, -2.5))
idle.pose(78, SLUMP, ease="CONST")
idle.marker(78, "reset")
K(79, ease="EXPO", neck=(-17, 0, 7))
# "nope" head shake
K(81, ease="EXPO", neck=(-14, 10, 4))
K(83, ease="EXPO", neck=(-12, -9, 3))
K(84, ease="EXPO", root_pos=(0, -0.05, 0))
idle.marker(84, "bit")
K(85, ease="EXPO", neck=(-9, 4, 2))
# shrug + recover (BACK overshoot)
K(88, ease="BACK", root=(4, 0, 0), root_pos=(0, 0.04, 0), neck=(4, 2, 0),
  rs=(2, 0, 13), ls=(2, 0, -13), rh=(0, 0, 3.5), lh=(0, 0, -3.5))
K(92, root=(2.5, 0, 0), root_pos=(0, -0.01, 0), neck=(3, 6, 0), rs=(5, 0, 8), ls=(5, 0, -8))
idle.loop()
idle.noise("root", 2, 0.6, cycles=(1, 2, 3), seed=71)  # breathing sway
idle.noise("ls", 0, 1.2, cycles=(2, 3, 5), seed=72)
plant(idle)

# ------------------------------------------------------------------ walk: 8-bit sprite march
walk = A.clip("walk", seconds=lib.STRIDE)
n = walk.frames
for k in range(8):
    f = k * n / 8
    p = k / 8 * 2 * math.pi
    s = math.cos(p)  # +1: right foot forward (contact), -1: left
    up = abs(math.sin(p))  # passing poses pop up
    walk.key(f, ease="CONST",
             root=(4 - 2 * up, -6 * s, -1.5 * s),
             root_pos=(0, 0.11 * up, 0),
             neck=(3, 5 * s, 1.2 * s),
             rs=(-30 * s, 0, 8), ls=(30 * s, 0, -8),
             rh=(24 * s, 0, 2), lh=(-24 * s, 0, -2))
walk.marker(0, "bit")
walk.marker(n / 2, "bit")
walk.loop()
plant(walk)

A.lift = 0
A.finish()
