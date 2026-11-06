# Blackout (1 in 66,666, Epic, Blackout biome): "When the grid dies, it wakes."
# Concept: something that lives in the dark between power cuts. While the grid is down it is
# DORMANT - hunched, arms wrapped around itself, shivering, breathing slow and heavy. Then the
# emergency strobe catches it: a head twitch, a deep coiled breath in, and it WAKES with a hard
# snap upright (chest out, arms flung down and wide, dead stare up), scans the dark like the
# rotating beacon on its head, gets hit by a power SURGE (three-frame convulsion) and finally
# drains back into the dormant hunch as the lights die. Grounded on purpose (Epic tier).
#
# CLIPS
#   idle  (4.8 s, 144 f, loop) = 4 strobe periods of 1.2 s (the VFX strobe runs on
#         Sync.phase(bus, 1.2), so every marker below lands on the strobe grid).
#         f0-40  dormant hunch, two heavy breaths, shiver (periodic noise)
#         f44    head twitch toward the light (CONST snap, 3 frames, EXPO recover)
#         f52-68 anticipation: sinks deeper, coils, hug tightens, head drops
#         f72    WAKE: explosive snap upright, arms thrown down/out, chin up (EXPO + BACK settle)
#         f80-100 scan: head tracks left (slow), holds, SNAPS right; torso follows 3 f late,
#                right hand twitches open after the head (overlap)
#         f106   SURGE: 3-frame convulsion (CONST A/B/A), EXPO recover
#         f116-140 drain: slumps back into the hug; the head drops last
#   walk  (lib.STRIDE) heavy predatory stalk: torso low and forward, head low and locked,
#         shoulders rolling with each step, limp arms swinging 3 frames late, every contact
#         lands like a stomp (EXPO into the contact, passing pose rises high).
#   short (0.5 s, add, trigger "short") electrocution jolt; the VFX fires "short" whenever a
#         random spark burst crackles out of the body.
#   slam  (0.8 s, replace, trigger "land") heavy three-point-ish landing: drops low, arms flung
#         back, head down, then the head snaps up.
#
# MARKERS (AurasMid A.Blackout)
#   twitch      idle f44   -> the dome blinks off, sparks crackle at the head, sign glitches
#   wake        idle f72   -> AWAKE state: strobes / pillars / beacon at full power, spark bursts
#                             from both hands, floor ring flashes, smoke burst, sign "IT WAKES"
#   scan        idle f96   -> the beacon spotlights lock onto the head's look direction for 1 s
#   surge       idle f106  -> chest spark explosion, every pillar + LED flares, light spike
#   dark        idle f118  -> DORMANT state: everything dims down to an ember, smoke puff
#   stomp R/L   walk f0/h  -> red shock ring + smoke puff under that foot
#   jolt        short f1   -> spark spray from both hands
#   impact      slam f3    -> big smoke burst + floor ring flash + sparks
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Blackout")


def plant(clip, passes=2):
    """Floor contact: at every root-height key, raise the body just enough that the lowest
    sole touches the floor (R6 has no knees). Never lowers a key."""
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
idle = A.clip("idle", seconds=4.8)  # 144 frames
K = idle.pose

# dormant hunch: torso folded forward, hips forward to keep the legs vertical, arms wrapped
HUG_OUT = dict(  # breath out (lowest)
    root=(-16, 4, 2), root_pos=(0, -0.12, 0), neck=(-20, -6, 4),
    rs=(72, 8, -50), ls=(58, -8, 47), rh=(16, -2, 3), lh=(15, 4, -4),
)
HUG_IN = P(HUG_OUT, root=(-11, 3, 1.5), root_pos=(0, -0.06, 0), neck=(-15, -4, 3),
           rs=(66, 6, -44), ls=(53, -6, 41))
COIL = dict(  # anticipation: deepest crouch, hug tight, head buried
    root=(-24, 0, 0), root_pos=(0, -0.22, 0), neck=(-28, 0, 0),
    rs=(82, 10, -56), ls=(68, -10, 53), rh=(24, 0, 3), lh=(24, 0, -3),
)
WAKE = dict(  # explosive snap upright
    root=(7, 0, 0), root_pos=(0, 0.06, 0), neck=(14, 0, 0),
    rs=(-14, 0, 34), ls=(-14, 0, -34), rh=(-4, 0, 6), lh=(-4, 0, -6),
)
WAKE_SETTLE = dict(
    root=(2, 0, 0), root_pos=(0, 0.02, 0), neck=(6, 0, 0),
    rs=(-6, 0, 18), ls=(-6, 0, -18), rh=(-1, 0, 4), lh=(-1, 0, -4),
)
LOOK_L = dict(root=(1, 10, 0), neck=(2, 38, 3), rs=(-4, 0, 16), ls=(-8, 0, -22))
LOOK_R = dict(root=(1, -14, 0), neck=(3, -46, -4), rs=(-10, 0, 24), ls=(-4, 0, -15))
SURGE_A = dict(
    root=(12, 8, -6), root_pos=(0, 0.1, 0), neck=(24, -14, 10),
    rs=(30, 0, 80), ls=(-20, 0, -64), rh=(-6, 0, 9), lh=(4, 0, -8),
)
SURGE_B = dict(
    root=(5, -9, 7), root_pos=(0, 0.05, 0), neck=(-6, 20, -12),
    rs=(-24, 0, 58), ls=(36, 0, -84), rh=(4, 0, 7), lh=(-6, 0, -10),
)

K(0, HUG_OUT)
K(20, HUG_IN)
K(38, HUG_OUT)
# twitch toward the light (CONST snap, hold 3 frames)
idle.key(43, neck=(-19, -4, 3))
idle.key(44, ease="CONST", neck=(4, 28, -10), root=(-14, 8, 0))
idle.marker(44, "twitch")
idle.key(47, ease="EXPO", neck=(-6, 18, -6), root=(-14, 6, 1))
idle.key(52, neck=(-18, 2, 2), root=(-15, 3, 1.5))
# anticipation: coil (slow in), head drops 3 frames after the torso
idle.key(56, ease="IN", root=(-20, 1, 1), root_pos=(0, -0.17, 0), rs=(76, 9, -53), ls=(62, -9, 50),
         rh=(20, -1, 3), lh=(20, 2, -3))
K(66, COIL, ease="IN")
idle.key(69, neck=(-32, 0, 0))
# WAKE (snap on 72, overshoot, settle) - arms trail the torso by a frame
K(72, WAKE, ease="EXPO")
idle.marker(72, "wake")
idle.key(73, ease="EXPO", rs=(-20, 0, 40), ls=(-20, 0, -40))
idle.key(77, ease="BACK", root=(-1, 0, 0), neck=(4, 0, 0), rs=(-4, 0, 14), ls=(-4, 0, -14))
K(82, WAKE_SETTLE)
# scan left (slow, torso first, head 3 f later), hold, snap right
idle.key(86, root=LOOK_L["root"], rs=LOOK_L["rs"], ls=LOOK_L["ls"])
idle.key(89, ease="OUT", neck=LOOK_L["neck"])
idle.key(94, neck=(4, 40, 4), root=(1, 11, 0))
idle.key(96, ease="EXPO", neck=LOOK_R["neck"])
idle.marker(96, "scan")
idle.key(99, ease="EXPO", root=LOOK_R["root"], ls=LOOK_R["ls"])
idle.key(101, ease="BACK", rs=(-14, -8, 30))  # right hand twitches open after the head
# surge: anticipation compress, convulse A/B/A, recover
idle.key(104, ease="IN", root=(-3, -12, 0), root_pos=(0, -0.02, 0), neck=(-2, -40, -3),
         rs=(-6, 0, 22), ls=(-4, 0, -16))
K(106, SURGE_A, ease="CONST")
idle.marker(106, "surge")
K(108, SURGE_B, ease="CONST")
K(110, SURGE_A, ease="CONST")
K(112, P(WAKE_SETTLE, root=(4, -4, 1), neck=(10, -10, 2)), ease="EXPO")
# drain: slump back into the hug; torso first, arms 3 f later, head last
idle.key(118, ease="IN", root=(-6, 2, 1), root_pos=(0, -0.02, 0), rh=(6, -1, 4), lh=(6, 2, -5))
idle.marker(118, "dark")
idle.key(121, rs=(24, 0, -4), ls=(20, 0, 4))
idle.key(124, neck=(-4, -4, 2))
idle.key(130, root=(-13, 3, 2), root_pos=(0, -0.09, 0), rs=(62, 6, -42), ls=(50, -6, 40),
         rh=(13, -2, 3), lh=(13, 4, -4))
idle.key(134, neck=(-22, -6, 4))
idle.loop()
plant(idle)
idle.noise("rs", 2, 1.4, cycles=(9, 13, 17), seed=3)  # shiver
idle.noise("ls", 2, 1.4, cycles=(11, 14, 19), seed=4)
idle.noise("neck", 1, 2.0, cycles=(2, 3, 7), seed=5)
idle.noise("root", 2, 0.8, cycles=(2, 5), seed=6)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
h = walk.frames / 2


def contact(f, side):
    s = 1 if side == "R" else -1  # +1: right leg forward
    walk.key(f, ease="EXPO",
             root=(-12, -9 * s, -4 * s), root_pos=(0, -0.04, 0),
             neck=(-12, 8 * s, 3 * s),
             rh=(30 * s + 12, 0, 2), lh=(-30 * s + 12, 0, -2))
    walk.marker(f, "stomp", side)


def recoil(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, root=(-15, -7 * s, -5 * s), root_pos=(0, -0.06, 0), neck=(-17, 6 * s, 2 * s))


def passing(f, side):
    s = 1 if side == "R" else -1  # weight on the right leg when s = 1
    walk.key(f, root=(-9, 0, 3 * s), root_pos=(0, 0.1, 0), neck=(-10, 0, 0),
             rh=(12 - 2 * s, 0, 2), lh=(12 + 2 * s, 0, -2))


def arms(f, side):  # limp arms swing ~3 frames late
    s = 1 if side == "R" else -1
    walk.key(f, ease="OUT", rs=(-16 * s + 8, 0, 9), ls=(16 * s + 8, 0, -9))


contact(0, "R")
recoil(2.5, "R")
arms(3, "R")
passing(h * 0.5, "R")
contact(h, "L")
recoil(h + 2.5, "L")
arms(h + 3, "L")
passing(h * 1.5, "L")
walk.loop()
plant(walk)

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))

sh = A.clip("short", seconds=0.5, trigger="short", mode="add", blend_in=0.01, blend_out=0.12)
sh.pose(0, Z)
sh.key(1, ease="CONST", root_pos=(0, 0.1, 0), root=(6, 6, -4), neck=(14, -16, 8), rs=(-10, 0, 30), ls=(-8, 0, -26))
sh.marker(1, "jolt")
sh.key(3, ease="CONST", root_pos=(0, 0.1, 0), root=(2, -6, 5), neck=(-8, 18, -10), rs=(14, 0, 14), ls=(16, 0, -32))
sh.key(5, ease="CONST", root_pos=(0, 0.05, 0), root=(4, 3, -2), neck=(8, -8, 4), rs=(-6, 0, 22), ls=(-4, 0, -18))
sh.key(8, ease="EXPO", root_pos=(0, 0.01, 0), root=(1, 0, 0), neck=(2, 0, 0), rs=(0, 0, 4), ls=(0, 0, -4))
sh.pose(15, Z)

sl = A.clip("slam", seconds=0.8, trigger="land", mode="replace", blend_in=0.02, blend_out=0.25)
STAND = dict(root=(-4, 0, 0), root_pos=(0, 0, 0), neck=(-4, 0, 0), rs=(4, 0, 8), ls=(4, 0, -8),
             rh=(4, 0, 2), lh=(4, 0, -2))
sl.pose(0, P(STAND, root=(2, 0, 0), rs=(30, 0, 30), ls=(30, 0, -30), rh=(10, 0, 3), lh=(-6, 0, -3)))
sl.pose(3, dict(root=(-26, 0, 0), root_pos=(0, -0.3, 0), neck=(-24, 0, 0),
                rs=(-40, 0, 26), ls=(-40, 0, -26), rh=(30, 0, 6), lh=(28, 0, -6)), ease="EXPO")
sl.marker(3, "impact")
sl.key(7, root=(-24, 0, 0), root_pos=(0, -0.26, 0), neck=(-14, 0, 0), rs=(-30, 0, 22), ls=(-30, 0, -22))
sl.key(10, ease="EXPO", neck=(10, 0, 0))  # head snaps up, eyes on you
sl.key(18, root=(-10, 0, 0), root_pos=(0, -0.08, 0), rs=(-4, 0, 12), ls=(-4, 0, -12), rh=(10, 0, 3), lh=(10, 0, -3))
sl.pose(24, STAND)
plant(sl)

A.lift = 0
A.finish()
