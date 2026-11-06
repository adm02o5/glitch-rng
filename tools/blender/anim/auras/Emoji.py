# Emoji (1 in 60, Basic): ":)"  look: yellow smiley faces floating up and fading.
# Concept: the player is a walking emoji keyboard - every gesture is a reaction emoji
# acted out with the whole body: :wave: -> :tada: -> :shrug: -> :joy:. Light, bouncy, a bit
# goofy; Basic tier, so the motion stays small in amplitude but full of personality.
#
# CLIPS
#   idle (4.0 s, 120 f, loop)
#     f0-20    happy bob: two springy rises onto the toes, the head rocks side to side and
#              lands ~2 frames after the torso (overlap), arms flop a little outward
#     f20-48   :wave: - the right arm dips (anticipation), whips up and out (BACK overshoot,
#              kept under ~125 deg: an R6 arm raised higher would clip into the head)
#              and waves twice; torso leans away to balance, weight on the left leg, the
#              head tilts toward the hand with a grin, left arm drifts out in sympathy
#     f48-80   :tada: - arm drops with an overshoot, a crouch (torso forward, hips forward so
#              the feet stay planted, arms swung back), then a little STAR JUMP (arms + legs
#              spread, EXPO pop), land with a squash and a springy recovery
#     f82-100  :shrug: - palms turned up and out, head tilted, chest rises: "idk ¯\_(ツ)_/¯"
#     f102-120 :joy: - hunched giggle: quick shoulder shakes (LINEAR jitter), then it settles
#              back into the bob pose
#   walk (lib.STRIDE): a SKIP - a little hop on every stride with the free knee driven up
#     (leg swung forward), big outward arm swings, head bobbing ~2 frames behind the body.
#   aww (0.9 s, add, trigger "love"): when a floating face in the VFX turns heart-eyed it
#     emits "love" -> the head tilts and the chest lifts in a melted "awww" (VFX -> body).
#
# MARKERS (AurasExtra A.Emoji)
#   wave    f30, f38       the waving hand sweeps -> a smiley pops out OF THE RIGHT HAND and
#                                                    floats up (extra face pool), sparkle puff
#   pop     f70            star-jump landing      -> floor rings flash, spark ring burst, every
#                                                    floating face does a "boing" scale bounce
#   shrug   f88            palms up               -> "¯\_(ツ)_/¯" tag pops above the head,
#                                                    the faces flip to a flat ":/" mouth
#   giggle  f103           the giggle starts      -> warm glow puffs from the head, the waist
#                                                    bubbles flash and jiggle
#   skip    walk apex x2   top of each skip hop   -> a small spark puff off the head
#   (free) step -> a little sparkle at that foot; (free) land -> faces boing
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Emoji")


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


def plant(clip, passes=2):
    """Raise root-height keys just enough that the lowest sole touches the floor
    (never lowers a key, so deliberate hops survive)."""
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


def legs(w, spread=0.0):
    # w -1..1 = weight on the left .. right leg; spread = extra outward splay (degrees)
    return dict(root_pos=(0.06 * w, 0, 0), rh=(0, 0, 2.5 + spread - 1.5 * w), lh=(0, 0, -2.5 - spread - 1.5 * w))


ARMS = dict(rs=(4, 0, 9), ls=(4, 0, -9))

# f0-20 happy bob (rise onto the toes = root up; R6 has no knees)
K(0, root=(1, 0, 1.5), neck=(3, 0, 7), root_pos=(-0.03, 0, 0), **ARMS,
  rh=(0, 0, 3.2), lh=(0, 0, -1.8))
K(5, ease="OUT", root=(2, 0, 0), root_pos=(-0.03, 0.08, 0), rs=(6, 0, 14), ls=(6, 0, -14))
K(7, ease="OUT", neck=(5, 0, 1))
K(10, ease="IN", root=(0.5, 0, -1.5), root_pos=(0.02, 0, 0), rs=(3, 0, 8), ls=(3, 0, -8))
K(12, neck=(2, 0, -7))
K(15, ease="OUT", root=(2, 0, 0), root_pos=(0.02, 0.08, 0), rs=(6, 0, 14), ls=(6, 0, -14))
K(17, ease="OUT", neck=(5, 0, -1))
# f20-48 :wave:
K(20, ease="IN", root=(0.5, 0, 1), root_pos=(-0.05, 0, 0), rs=(-6, 0, 13), ls=(3, 0, -8),
  rh=(0, 0, 3.5), lh=(0, 0, -1))
K(22, neck=(1, 0, 4))
K(26, ease="BACK", rs=(14, 0, 124), root=(1, 3, 4), root_pos=(-0.07, 0.02, 0))
K(28, ease="OUT", neck=(7, -5, 6), ls=(6, 0, -15))
K(30, rs=(18, 0, 94))
idle.marker(30, "wave")
K(34, rs=(14, 0, 121), root=(1, 4, 4.5))
K(36, neck=(8, -7, 8))
K(38, rs=(18, 0, 92))
idle.marker(38, "wave")
K(42, rs=(14, 0, 116), ls=(5, 0, -13))
K(44, neck=(6, -5, 5))
# f48-80 :tada: star jump
K(48, ease="BACK", rs=(-12, 0, 11), root=(0.5, 0, 1.5), root_pos=(-0.03, 0, 0))
K(50, neck=(2, 0, -2))
K(56, ease="INOUT", root=(-9, 0, 0), rh=(9, 0, 3), lh=(9, 0, -3), root_pos=(0, 0, 0),
  rs=(-28, 0, 12), ls=(-28, 0, -12))
K(57, neck=(-6, 0, 0))
K(62, ease="EXPO", root=(4, 0, 0), root_pos=(0, 0.3, 0), rs=(10, 0, 126), ls=(10, 0, -126),
  rh=(0, 0, 13), lh=(0, 0, -13))
K(64, ease="OUT", neck=(10, 0, 3))
K(66, root_pos=(0, 0.34, 0), rs=(10, 0, 132), ls=(10, 0, -132), root=(5, 0, 0))
K(70, ease="IN", root_pos=(0, 0, 0), root=(-1, 0, 0), rs=(4, 0, 60), ls=(4, 0, -60),
  rh=(1, 0, 3), lh=(1, 0, -3))
idle.marker(70, "pop")
K(71, ease="IN", neck=(3, 0, 0))
K(73, ease="OUT", root=(-6, 0, 0), rh=(6, 0, 3), lh=(6, 0, -3), rs=(0, 0, 18), ls=(0, 0, -18))
K(75, neck=(-5, 0, 2))
K(79, ease="BACK", root=(1.5, 0, 0), rh=(0, 0, 3), lh=(0, 0, -3), rs=(4, 0, 10), ls=(4, 0, -10))
K(80, neck=(3, 0, 1))
# f82-100 :shrug:
K(84, ease="IN", root=(0, 0, 0), rs=(2, 0, 7), ls=(2, 0, -7), root_pos=(0, -0.0, 0))
K(85, neck=(-2, 0, 0))
K(88, ease="BACK", rs=(42, 0, 36), ls=(42, 0, -36), root=(3, 0, -1), root_pos=(0, 0.06, 0))
idle.marker(88, "shrug")
K(90, ease="BACK", neck=(-3, 3, 15))
K(96, rs=(38, 0, 33), ls=(38, 0, -33), root=(2, 0, -1.5), root_pos=(0, 0.045, 0))
K(98, neck=(-1, 2, 13))
# f102-120 :joy: giggle (shoulder shakes)
K(102, ease="OUT", root=(-6, 0, 0), rh=(6, 0, 3), lh=(6, 0, -3), rs=(18, 0, 5), ls=(18, 0, -5),
  root_pos=(0, 0, 0))
K(103, neck=(-8, 0, 6))
idle.marker(103, "giggle")
for i, f in enumerate(range(104, 113, 2)):
    s = 1 if i % 2 == 0 else -1
    K(f, ease="LINEAR", root=(-6 + s, 0, 2.2 * s), root_pos=(0, 0.035 if s > 0 else 0, 0))
K(113, ease="OUT", rs=(10, 0, 8), ls=(10, 0, -8))
K(114, root=(-2, 0, 0.5), rh=(2, 0, 3), lh=(2, 0, -3), root_pos=(-0.02, 0, 0))
K(115, neck=(-1, 0, 6), rh=(0, 0, 3.2), lh=(0, 0, -1.8))
idle.loop()
idle.noise("neck", 1, 1.5, seed=11)
idle.noise("root", 1, 0.8, cycles=(1, 2, 3), seed=12)
idle.noise("ls", 2, 1.5, cycles=(2, 3, 5), seed=13)

# ------------------------------------------------------------------ walk (a skip)
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(f, s):
    # s = +1: right foot forward / landing
    walk.key(f, ease="IN",
             root=(1, -6 * s, -2 * s), root_pos=(0, 0, 0),
             rs=(-34 * s, 0, 16), ls=(34 * s, 0, -16),
             rh=(24 * s, 0, 3), lh=(-22 * s, 0, -3))
    walk.key(f + 2, ease="OUT", neck=(0, 6 * s, 3 * s))


def hop(f, s):
    # s = +1: standing on the right leg, the left knee drives up
    walk.key(f, ease="OUT",
             root=(3, 2 * s, 2 * s), root_pos=(0, 0.3, 0),
             rs=(22 * s, 0, 22), ls=(-22 * s, 0, -22),
             rh=(-14 if s > 0 else 36, 0, 3), lh=(36 if s > 0 else -14, 0, -3))
    walk.key(f + 2, ease="OUT", neck=(6, -2 * s, -4 * s))
    walk.marker(f, "skip")


contact(0, 1)
hop(h * 0.5, 1)
contact(h, -1)
hop(h * 1.5, -1)
walk.loop()

# ------------------------------------------------------------------ aww (VFX -> body)
aw = A.clip("aww", seconds=0.9, trigger="love", mode="add", blend_in=0.05, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
aw.pose(0, Z)
aw.pose(4, P(Z, neck=(8, 0, 16), root=(3, 0, 3), rs=(14, 0, -4), ls=(14, 0, 4)), ease="EXPO")
aw.pose(12, P(Z, neck=(9, 0, 13), root=(3, 0, 2.5), rs=(16, 0, -4), ls=(16, 0, 4)))
aw.pose(18, P(Z, neck=(4, 0, -3), root=(1, 0, -1)))
aw.pose(27, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
