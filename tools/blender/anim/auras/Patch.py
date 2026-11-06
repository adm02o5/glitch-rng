# Patch (1 in 150, Enhanced): "Fixed 3 bugs. Added 7."  look: bandage strips of code wrapping
# the body, green plus signs, a medic-cross floor sigil, heal rings rising every 2.4 s.
# Concept: a self-taught field medic for code. The player patches themself up - slaps a
# bandage on the forearm, admires the fix, then a fresh bug twitches the other arm ("added 7"),
# a sheepish head scratch, a big "redeploy" breath, a pat on the thigh and a test kick of the
# patched leg. Enhanced tier: subtle, but every beat tells the joke.
#
# CLIPS
#   idle (4.8 s, 144 f, loop) = two 2.4 s heal cycles (the heal ring leaves the floor at
#                               f0 and f72 through Sync.phase(bus, 2.4))
#     f0-14    INSPECT: the right forearm comes up in front, the head and torso turn to look at
#              it (head 2 f ahead), weight on the left leg
#     f18      anticipation: the left hand pulls out and back
#     f24      SLAP: the left palm smacks onto the right forearm (EXPO), head nods 1 f later
#     f27-33   rubs the bandage in (two small strokes)
#     f38-46   ADMIRE: the right arm swings out to the side and up (BACK overshoot), the head
#              follows 2 f late, satisfied nod
#     f50-55   BUG: CONST glitch frames - the left arm jerks out, the head snaps, the torso
#              jitters, then everything drops back
#     f58-70   sheepish HEAD SCRATCH (right hand at the head, 4 scratches, head tilts into it),
#              left hand on the hip
#     f72      HEAL: big redeploy breath - chest up and back, both arms open palms-out (BACK)
#     f82-90   settles, weight drifts to the right
#     f96      PAT: leans in and slaps the left thigh (EXPO)
#     f106-116 TEST KICK: the patched left leg kicks forward and returns, arms balance
#     f120-144 back to the inspect start, weight returns to the left leg
#   walk (lib.STRIDE): a patched-up LIMP - the right leg is stiff (short swing, hip hikes on
#     its passing pose), the left steps long; the left arm is held in a sling across the belly,
#     the right arm swings for balance; the head bobs harder on the stiff side.
#   zap (0.55 s, add, trigger "bugzap"): while walking the VFX sometimes sparks a fresh bug ->
#     the left arm and head twitch (VFX -> body).
#
# MARKERS (AurasExtra A.Patch)
#   apply "lhand" f24, f96   slaps     -> green heal burst + plus sparks FROM THE LEFT HAND, the
#                                         bandage strips flare, note "+3 FIXED" / "PATCHED"
#   bug   "lhand" f50        twitch    -> blue/red glitch squares from the left hand, the strips
#                                         flicker blue, note "+7 BUGS", the light stutters
#   heal          f72        breath    -> the floor cross flashes, big heal burst from the chest,
#                                         a version bump "v1.0.N"
#   (free) step -> a plus pops at the stiff right foot / tape squares at the left foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Patch")


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
idle = A.clip("idle", seconds=4.8)  # 144 frames
K = idle.key


def legs(w, lean=0.0, y=0.0):
    # w -1..1 = weight on the left .. right leg; lean = forward torso lean the hips cancel
    return dict(root_pos=(0.07 * w, y, 0), rh=(lean, 0, 1.8 * w + 1.6), lh=(lean, 0, 1.8 * w - 1.6))


LOOSE_R, LOOSE_L = (4, 0, 6), (4, 0, -6)
FORE = (68, 6, -2)  # right forearm raised in front (inspect)

K(0, root=(0, -2, 1.5), neck=(-4, -3, 0), rs=LOOSE_R, ls=LOOSE_L, **legs(-1))
# INSPECT: eyes first, then torso, then the arm
K(6, ease="OUT", neck=(-14, -16, -3))
K(8, root=(-1, -7, 1.5))
K(12, ease="BACK", rs=FORE, ls=(6, 0, -8))
# anticipation of the slap
K(18, ease="OUT", ls=(26, 0, -28), root=(0, -9, 1.5), neck=(-16, -18, -3))
# SLAP: left palm onto the right forearm
K(24, ease="EXPO", ls=(70, -38, -2), rs=(62, 6, -2), root=(-2, -4, 1))
idle.marker(24, "apply", "lhand")
K(25, ease="EXPO", neck=(-21, -12, -2))
# rub it in
K(28, ls=(72, -34, -2), neck=(-17, -12, -2))
K(31, ls=(67, -40, -2))
K(34, ls=(71, -35, -2), rs=(64, 6, -2))
# ADMIRE: arm out and up, head follows late, satisfied nod
K(38, ease="IN", ls=(10, 0, -10), rs=(50, 0, 30))
K(43, ease="BACK", rs=(28, 0, 88), root=(1.5, -8, 2), neck=(-2, -22, -6))
K(45, ease="BACK", neck=(-4, -30, -8))
K(47, neck=(-10, -28, -8))  # nod
K(49, neck=(-3, -27, -7), rs=(26, 0, 84))
# BUG: CONST glitch frames
K(50, ease="CONST", ls=(18, 0, -72), neck=(6, 12, 9), root=(1, -6, -2.5), rs=(24, 0, 82))
idle.marker(50, "bug", "lhand")
K(52, ease="CONST", ls=(-22, 0, -38), neck=(-4, -12, -5), root=(2, -10, 3))
K(54, ease="CONST", ls=(30, 0, -55), neck=(4, 6, 6), root=(1, -7, 0))
K(56, ease="EXPO", ls=(6, 0, -10), neck=(-2, 4, 2), root=(0, -3, 1), rs=(30, 0, 60))
# sheepish HEAD SCRATCH
SCR = (166, 0, -18)
K(61, ease="BACK", rs=SCR, ls=(-10, 0, -26), neck=(-8, 6, -9), root=(0, 2, 1.5))
for i, f in enumerate((63, 65, 67, 69)):
    z = -12 if i % 2 == 0 else -21
    K(f, ease="INOUT", rs=(SCR[0] - (2 if i % 2 else 0), 0, z))
K(64, neck=(-9, 7, -11))
K(70, neck=(-10, 5, -8))
# HEAL: big redeploy breath, arms open palms-out
K(68, ease="IN", root=(-3, 0, 0), root_pos=(-0.02, 0, 0))
K(72, ease="BACK", root=(6, 0, 0), root_pos=(0, 0.06, 0), neck=(10, 0, 0),
  rs=(16, 0, 62), ls=(16, 0, -62), rh=(0, 0, 2.2), lh=(0, 0, -2.2))
idle.marker(72, "heal")
K(78, root=(4, 1, 0), neck=(7, 2, 1), rs=(12, 0, 56), ls=(12, 0, -56), root_pos=(0, 0.04, 0))
# settle, weight to the right
K(86, ease="INOUT", root=(0, 3, -1.5), neck=(-3, 4, 1), rs=(6, 0, 10), ls=(6, 0, -10), **legs(1))
# PAT the left thigh
K(92, ease="OUT", ls=(30, 0, -22), root=(-3, 6, -1), neck=(-12, 10, 2), **legs(0.4, 3))
K(96, ease="EXPO", ls=(14, 0, 2), root=(-8, 7, 0), neck=(-20, 12, 3), **legs(0.4, 8))
idle.marker(96, "apply", "lhand")
K(100, ls=(18, 0, -2), root=(-6, 6, 0), neck=(-15, 10, 2), **legs(0.4, 6))
# TEST KICK of the patched leg
K(105, ease="INOUT", root=(1, 2, -2), ls=(4, 0, -16), rs=(4, 0, 14), neck=(-8, 4, 0),
  root_pos=(0.09, 0, 0), rh=(0, 0, 3.6), lh=(0, 0, 0))
K(110, ease="EXPO", lh=(30, 0, -2), root=(4, 2, -2.5), ls=(-6, 0, -26), rs=(-4, 0, 22), neck=(-14, 2, 0))
K(116, ease="BACK", lh=(0, 0, -0.4), root=(0, 1, -2), ls=(4, 0, -12), rs=(4, 0, 10), neck=(-6, 0, 0))
# back to the start, weight to the left
K(124, root=(0, -1, 1), neck=(-4, -2, 0), rs=LOOSE_R, ls=LOOSE_L, **legs(-0.6))
# loosen the patched shoulder: a little roll (right shoulder up-back, then down) and a head tilt
K(128, ease="OUT", rs=(-8, 0, 12), root=(1.5, -1, -2.5), neck=(-2, -4, 4), root_pos=(-0.04, 0.03, 0))
K(132, ease="BACK", rs=(10, 0, 4), root=(-1, -2, 2), neck=(-6, -3, -2), root_pos=(-0.06, 0, 0))
K(138, root=(0, -2, 1.5), rs=LOOSE_R, **legs(-1))
idle.loop()
idle.noise("root", 2, 0.5, cycles=(1, 2, 3), seed=41)  # breathing sway
idle.noise("neck", 1, 1.2, cycles=(2, 3, 5), seed=42)
idle.noise("ls", 0, 1.0, cycles=(2, 3, 5), seed=43)

# ------------------------------------------------------------------ walk (limp)
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2
SLING = (52, -14, -2)  # left forearm held across the belly


def contact(f, s):
    # s = +1: right (stiff) foot forward -> short stride, body lists right onto it
    if s > 0:
        walk.key(f, ease="EXPO", root=(-1, -4, -4), root_pos=(0, 0, 0), neck=(-8, 3, -5),
                 rs=(-14, 0, 9), ls=SLING, rh=(14, 0, 1.5), lh=(-24, 0, -1.5))
    else:
        walk.key(f, ease="OUT", root=(-3, 6, 1.5), root_pos=(0, 0, 0), neck=(-4, -3, 2),
                 rs=(22, 0, 8), ls=(SLING[0] + 3, SLING[1], SLING[2]), rh=(-24, 0, 1.5), lh=(28, 0, -1.5))


def passing(f, s):
    if s > 0:  # standing on the stiff leg: hip hikes, quick
        walk.key(f, root=(1, 0, 3), root_pos=(0, 0.13, 0), neck=(-2, 0, 3),
                 rs=(4, 0, 8), ls=(SLING[0] - 2, SLING[1], SLING[2]), rh=(-4, 0, 1.5), lh=(4, 0, -1.5))
    else:
        walk.key(f, root=(-2, 0, -1.5), root_pos=(0, 0.05, 0), neck=(-6, 0, -1),
                 rs=(2, 0, 8), ls=SLING, rh=(4, 0, 1.5), lh=(-4, 0, -1.5))


contact(0, 1)
passing(h * 0.42, 1)  # quick off the stiff leg
contact(h, -1)
passing(h * 1.55, -1)
walk.loop()

# ------------------------------------------------------------------ zap (VFX -> body)
zap = A.clip("zap", seconds=0.55, trigger="bugzap", mode="add", blend_in=0.02, blend_out=0.15)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
zap.pose(0, Z)
zap.pose(1, P(Z, ls=(-10, 0, -34), neck=(5, 10, 7), root=(1, -3, -2)), ease="CONST")
zap.pose(3, P(Z, ls=(12, 0, -20), neck=(-3, -6, -4), root=(0, 2, 1.5)), ease="CONST")
zap.pose(5, P(Z, ls=(-4, 0, -12), neck=(2, 3, 2)), ease="EXPO")
zap.pose(16, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
