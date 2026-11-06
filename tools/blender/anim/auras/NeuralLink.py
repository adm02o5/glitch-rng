# Neural Link (1 in 600,000, LEGENDARY tier): "Mind, meet machine."
# VFX (AurasHigh.lua A.NeuralLink): a glowing neuron web (16 nodes + links) around the head,
# synapse sparks racing along the links, dendrites reaching out of the web, spine beams from the
# web into the back, a head ring, a ground sigil, sparks and a pink root light.
#
# CONCEPT: a grounded "receiver" (Legendary = big readable signature motion, no levitation): two
# fingers pressed to the right temple, head tilted into the hand, listening to the network. One
# idle loop is one THOUGHT: listen -> the signal arrives (head snap + aftershock twitches) -> the
# head reads the data, the left hand lifts and a thought forms on the palm -> both arms throw the
# signal out (transmit) -> the fingers return to the temple and re-link. The head always leads,
# the torso follows 2-3 frames later and the free arm lags another 2-4 (overlapping action).
#
# IDLE (5.0 s = 150 f; the web's breathing radius and the sigil follow Sync.phase(bus, 5.0)).
#   Markers -> what the VFX does:
#   0-26    listen: fingers on the temple, head tilted into the hand, slow breathing, weight on
#           the right leg (contrapposto), eyes drifting (periodic noise).
#   28      anticipation: the head bows, fingers press harder.
#   34      "receive"      EXPO: head snaps up and back, chest jolts, the free hand splays.
#                          VFX: a synapse storm: every node flashes white, sparks burst from the
#                          head, all spine beams surge, the web radius kicks out.
#   38, 41  "twitch"       CONST aftershocks of the head.
#                          VFX: a few random nodes flash + small spark puffs.
#   58-76   process: the head turns left and scans back, the left hand rises palm up in front.
#   80      "thought" "lhand"  a small BACK flick of the palm.
#                          VFX: a thought orb forms over the left palm (pink core + cyan sparks),
#                          two dendrites snap onto the palm and stay linked until "transmit".
#   96      anticipation: both arms pull in, torso curls, head drops.
#   102     "transmit"     EXPO: both arms fling open and forward, chest opens, head up.
#                          VFX: the orb shoots out, a shock ring of cyan sparks rolls outward from
#                          the chest, the web expands, all dendrites stretch out, light surge.
#   128     "link" "rhand" BACK: the fingers land back on the temple.
#                          VFX: a link beam flashes from the fingertips into the web, the head
#                          ring flares, the web contracts to its resting radius.
#
# WALK (one stride): the fingers stay on the temple (tiny bob), the free arm swings, a smooth
#   gliding gait with a soft rise on the passing pose; the head counter-rotates against the
#   torso so the gaze stays steady ("processing while walking"). VFX: the runner's "step"
#   events flash the node nearest each foot and puff cyan sparks from that foot.
#
# REACTIONS:
#   overload (trigger "overload", 0.9 s, add): the VFX fires "overload" every 7-12 s (a wave of
#     synapses rushes into the head); the head bows, then snaps back with CONST twitches, the free
#     arm flares. marker 7 "spike" -> every node flashes, a big spark burst from the head.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("NeuralLink")

TEMPLE = (155, -15, -30)  # right hand fingers on the right temple (solved for the R6 arm)


def temple(dx=0.0, dz=0.0):
    return (TEMPLE[0] + dx, TEMPLE[1], TEMPLE[2] + dz)


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=5.0)  # 150 frames


def listen(br=0.0, sway=1.0):
    """Receiving pose. br = breath 0..1, sway -1..1 = weight left .. right."""
    return dict(
        root=(-2 + 2 * br, -5 + sway, -1.5 * sway),
        root_pos=(0.05 * sway, 0.015 * br, 0),
        neck=(-9 + 2 * br, -4, -11 - br),
        rs=temple(2 * br, 0),
        ls=(7 + 2 * br, 0, -8 - 2 * br),
        rh=(2, 0, 3 + 1.5 * sway),
        lh=(5, 0, -4 + 1.5 * sway),
    )


idle.pose(0, listen(0))
idle.pose(16, listen(1), ease="QUAD")
# --- anticipation: head bows, fingers press
idle.key(28, ease="IN", root=(-5, -5, -1.5), neck=(-16, -3, -13), rs=temple(4, -3), ls=(4, 0, -6))
# --- the signal arrives: head leads, chest 2 f later, free hand 4 f later
idle.key(34, ease="EXPO", neck=(12, 4, -3))
idle.marker(34, "receive")
idle.key(36, ease="EXPO", root=(6, -3, 1), root_pos=(0.03, 0.04, 0), rs=temple(-8, 6))
idle.key(38, ease="EXPO", ls=(14, 0, -30))
idle.key(38, ease="CONST", neck=(2, -7, -12))
idle.marker(38, "twitch")
idle.key(41, ease="CONST", neck=(9, 6, -2))
idle.marker(41, "twitch")
idle.key(44, ease="EXPO", neck=(-1, 0, -8), root=(2, -4, 0))
idle.key(48, ls=(8, 0, -14), rs=temple(-2, 2))
# --- process: head turns left reading the data, torso follows, left hand rises palm up
idle.key(58, ease="QUAD", neck=(-4, 24, -4))
idle.key(61, ease="QUAD", rs=temple(1, 0), root=(-1, 6, 1), root_pos=(-0.04, 0, 0), rh=(1, 0, 4), lh=(4, 0, -3))
idle.key(64, ease="QUAD", ls=(70, 0, 12))
idle.key(72, ease="QUAD", neck=(-10, 6, -6))
idle.key(75, ease="QUAD", root=(-3, 2, 0), ls=(78, 0, 8))
# --- a thought forms on the palm
idle.key(80, ease="BACK", ls=(92, 0, 6), neck=(-14, 10, -4))
idle.marker(80, "thought", "lhand")
idle.key(88, ls=(86, 0, 9), neck=(-12, 8, -5), rs=temple(3, -2))
# --- anticipation: arms pull in, torso curls, head drops
idle.key(96, ease="IN", root=(-7, 0, 0), root_pos=(0, 0, 0), neck=(-18, 0, 0),
         rs=(55, 0, 12), ls=(55, 0, -12), rh=(6, 0, 3), lh=(6, 0, -3))
# --- TRANSMIT: arms fling open and forward, chest opens
idle.key(102, ease="EXPO", root=(8, 0, 0), root_pos=(0, 0.05, 0),
         rs=(84, 0, 60), ls=(84, 0, -60), rh=(-7, 0, 4), lh=(-7, 0, -4))
idle.key(104, ease="EXPO", neck=(16, 0, 0))
idle.marker(102, "transmit")
idle.key(108, rs=(92, 0, 70), ls=(92, 0, -70), root=(9, 0, 0))
idle.key(110, neck=(19, 2, 1))
# --- arms drift down, right hand heads back to the temple
idle.key(118, ease="QUAD", root=(1, -2, 0), root_pos=(0, 0, 0), neck=(2, -2, -4),
         rs=(60, 0, 40), ls=(22, 0, -26), rh=(1, 0, 3), lh=(3, 0, -4))
idle.key(128, ease="BACK", rs=temple(0, 0))
idle.marker(128, "link", "rhand")
idle.key(130, ease="BACK", neck=(-10, -4, -12), root=(-2, -4, -1))
idle.key(134, ls=(6, 0, -10))
idle.pose(142, listen(0.3, 0.9))
idle.loop()
idle.noise("neck", 1, 2.2, cycles=(2, 3, 7), seed=11)  # eyes drift while listening
idle.noise("neck", 0, 1.2, cycles=(3, 5, 8), seed=12)
idle.noise("root", 2, 0.8, cycles=(1, 2, 3), seed=13)
idle.noise("ls", 2, 1.5, cycles=(2, 4, 5), seed=14)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # ~21 frames, contacts on 0 and half
h = walk.frames / 2


def contact(f, side):
    s = 1 if side == "R" else -1  # +1: right foot forward
    walk.key(f, ease="INOUT",
             root=(-3, -8 * s, -1.5 * s), root_pos=(0, 0, 0),
             neck=(-7, 8 * s - 3, -10),  # counter-rotates: the gaze stays steady
             rs=temple(-3, 0), ls=(30 * s + 4, 0, -7),
             rh=(27 * s + 3, 0, 2), lh=(-27 * s + 3, 0, -2))


def passing(f, side):
    s = 1 if side == "R" else -1  # the right leg carries the weight when s = 1
    walk.key(f, ease="INOUT",
             root=(-1, 0, 1.5 * s), root_pos=(0, 0.07, 0),
             neck=(-9, -3, -11),
             rs=temple(3, 0), ls=(4, 0, -9),
             rh=(3 - 4 * s, 0, 3), lh=(3 + 4 * s, 0, -3))


contact(0, "R")
passing(h * 0.5, "R")
contact(h, "L")
passing(h * 1.5, "L")
walk.loop()

# ------------------------------------------------------------------ reactions
ov = A.clip("overload", seconds=0.9, trigger="overload", mode="add", blend_in=0.05, blend_out=0.25)
Z = (0, 0, 0)
ov.key(0, root=Z, root_pos=Z, neck=Z, rs=Z, ls=Z)
ov.key(4, ease="IN", root=(-4, 0, 0), neck=(-8, 0, 2), ls=(4, 0, 4))
ov.key(7, ease="EXPO", root=(7, 0, 1), neck=(20, 0, 8), rs=(-6, 0, 4), ls=(-12, 0, -26))
ov.marker(7, "spike")
ov.key(10, ease="CONST", neck=(9, -9, -2))
ov.key(13, ease="CONST", neck=(15, 7, 5))
ov.key(16, ease="CONST", neck=(7, -4, 0))
ov.key(19, ease="EXPO", root=(2, 0, 0), neck=(3, 0, 0), ls=(-4, 0, -8))
ov.key(27, root=Z, root_pos=Z, neck=Z, rs=Z, ls=Z)


# ------------------------------------------------------------------ floor contact
# R6 has no knees: bake a per-frame correction into root_pos y wherever the lowest sole would
# dip below the floor (the authored weight shifts still read through the torso, head and arms).
def floor_fix(clip, margin=0.0):
    rig, sc = A.rig, A.scene
    rig.animation_data.action = clip.action
    lift = {}
    for f in range(clip.frames + 1):
        sc.frame_set(f)
        low = min(lib._lowest_sole(rig, "rh"), lib._lowest_sole(rig, "lh"))
        lift[f] = max(0.0, margin - low)
    if not any(v > 1e-4 for v in lift.values()):
        return
    if clip.looping:
        lift[clip.frames] = lift[0]
    for fc in clip._curves('pose.bones["root"].location'):
        if fc.array_index != 1:
            continue
        vals = [(f, fc.evaluate(f) + lift[f]) for f in range(clip.frames + 1)]
        fc.keyframe_points.clear()
        for f, v in vals:
            k = fc.keyframe_points.insert(f, v)
            k.interpolation = "LINEAR"
        fc.update()


for c in A.clips:
    floor_fix(c)

A.lift = 0
A.finish()
