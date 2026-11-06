# Kernel (1 in 1,250,000, MYTHIC tier): "Ring zero. Absolute control."
# VFX (AurasHigh.lua A.Kernel): four concentric segment rings RING 0..3 (each with a beam circle and
# a floating "RING k" label wired to the core), a core orb before the chest, a sky pillar, a ground
# sigil, sparks and a magenta light.
#
# CONCEPT: the operator of ring zero. It LEVITATES (A.lift = 1.6 studs, legs dangle) and CONDUCTS the
# rings with its hands like a system administrator issuing commands: every gesture in this file is a
# command the rings obey in game.
#
# IDLE (6.0 s = 180 f; the core heartbeat is Sync.phase(bus, 1.5) = 4 beats per idle loop).
#   Markers -> what the VFX does:
#   0-18    calm hover, arms low and out (palms down-forward), legs dangling apart
#   20      anticipation: the right arm swings back/out, the torso counter-turns left
#   26      "cmd" "1"   EXPO: the right hand stabs forward-right, torso turns into it, head 1 f
#                       later, legs lag 4 f. VFX: a command beam fires from the right hand to the
#                       RING 1 label, ring 1 flashes white, kicks out wider and spins up.
#   48      anticipation on the left side
#   54      "cmd" "2"   the mirrored command with the LEFT hand -> RING 2 (beam from the left hand).
#   80-96   both arms float up overhead in a big arc, the body rises, the legs trail together
#   100     "lock"      BACK: the arms snap down into a T, chest out, head snaps level 2 f later.
#                       VFX: all four rings snap FLAT and FREEZE (spin + wobble stop), every ring
#                       and label flashes, labels read "LOCKED".
#   118     "charge"    the hands cup around the core before the chest, body curls, legs fold up.
#                       VFX: the rings contract toward the body, sparks stream INTO the core, the
#                       core shell compresses, all labels read "RING 0".
#   118-134 trembling build-up
#   136     "zero"      BACK: arms fling down and out, back arches, body surges up (head 2 f later,
#                       legs 4 f later). VFX: core nova (squares + glow), shock ring on the REAL
#                       floor, the rings blast out 35 % wider, sky pillar flares, light surge.
#   160     "unlock"    the arms float down: the rings resume their wobble and spin (eased).
#
# WALK (one stride): a commanding hover glide 1.45 studs up, pitched 16 deg, arms swept back and out
#   with palms down, legs trailing together in a slow scissor. Frame 2 "thrust": a small push of
#   both arms backward -> a small shock ring on the real floor + core spark puff.
#
# REACTIONS:
#   ascend    (trigger "jump", 0.8 s, add): both palms push down hard. marker 3 "push" -> floor
#             shock ring + core flash.
#   intrusion (trigger "intrusion", 1.0 s, add): the VFX fires "intrusion" every 10-16 s while
#             hovering in place: a red UNAUTHORIZED process appears on the outer ring at the
#             Kernel's front-right. The head snaps to it (f 2), the torso follows, the right hand
#             whips out at it. marker 9 "kill" -> a cyan kill beam from the right hand, the red
#             process bursts into red squares and is gone, ring 3 flashes.
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("Kernel")
LIFT = 1.6

# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames


def rest(sway=0.0, y=0.0):
    """Calm commanding hover. sway -1..1 rolls the weight a touch left .. right."""
    return dict(
        root=(3, 4 * sway, 1.5 * sway),
        root_pos=(0.04 * sway, LIFT + y, 0),
        neck=(2, -3 * sway, -1.5 * sway),
        rs=(-4, 0, 30 + 3 * sway),
        ls=(-4, 0, -30 + 3 * sway),
        rh=(-6, 0, 5),
        lh=(8, 0, -4),
    )


idle.pose(0, rest(-1, 0.0))
idle.key(12, root_pos=(-0.02, LIFT + 0.12, 0), rs=(-3, 0, 33), ls=(-3, 0, -33), neck=(3, 2, 0))
# CMD 1 - anticipation: right arm swings back and out, torso counter-turns left
idle.key(20, ease="IN", root=(2, 9, 0), rs=(-22, 0, 62), neck=(0, 6, 0), root_pos=(0, LIFT + 0.08, 0))
# stab: right hand forward-right, torso turns into it (head 1 f later, legs 4 f later)
idle.key(26, ease="EXPO", root=(-5, -13, -2), root_pos=(0.05, LIFT + 0.0, 0), rs=(84, 0, 22),
         ls=(-8, 0, -40))
idle.marker(26, "cmd", "1")
idle.key(27, ease="EXPO", neck=(1, -22, -3))
idle.key(30, ease="OUT", rh=(-16, 0, 7), lh=(2, 0, -5))
# overshoot hold, settle
idle.key(34, root=(-3, -11, -1), rs=(78, 0, 20), root_pos=(0.04, LIFT + 0.06, 0))
idle.key(42, root=(1, -4, 0), rs=(20, 0, 32), neck=(2, -8, 0), rh=(-6, 0, 5), lh=(8, 0, -4))
# CMD 2 - anticipation on the left
idle.key(48, ease="IN", root=(2, -9, 0), ls=(-22, 0, -62), rs=(-4, 0, 34), neck=(0, -6, 0),
         root_pos=(0, LIFT + 0.1, 0))
idle.key(54, ease="EXPO", root=(-5, 14, 2), root_pos=(-0.05, LIFT + 0.02, 0), ls=(84, 0, -22),
         rs=(-8, 0, 40))
idle.marker(54, "cmd", "2")
idle.key(55, ease="EXPO", neck=(1, 24, 3))
idle.key(58, ease="OUT", rh=(4, 0, 5), lh=(-14, 0, -7))
idle.key(62, root=(-3, 12, 1), ls=(78, 0, -20), root_pos=(-0.04, LIFT + 0.07, 0))
idle.key(70, root=(2, 4, 0), ls=(18, 0, -32), neck=(2, 8, 0), rh=(-6, 0, 5), lh=(8, 0, -4))
idle.pose(76, rest(0.3, 0.08))
# RISE: arms float up overhead in a big arc, the body rises, legs trail together
idle.key(90, root=(7, 0, 0), root_pos=(0, LIFT + 0.36, 0), neck=(12, 0, 0),
         rs=(-8, 0, 118), ls=(-8, 0, -118), rh=(-12, 0, 2), lh=(-7, 0, -2))
idle.key(96, ease="IN", rs=(-6, 0, 134), ls=(-6, 0, -134), root=(9, 0, 0), root_pos=(0, LIFT + 0.42, 0))
# LOCK: arms snap down into a T, chest out; head snaps level 2 f later
idle.key(100, ease="BACK", rs=(0, 0, 90), ls=(0, 0, -90), root=(-2, 0, 0), root_pos=(0, LIFT + 0.3, 0))
idle.marker(100, "lock")
idle.key(102, ease="BACK", neck=(-2, 0, 0))
idle.key(104, ease="OUT", rh=(-4, 0, 6), lh=(-1, 0, -6))
idle.key(110, rs=(1, 0, 88), ls=(1, 0, -89), root=(-1, 1, 0), root_pos=(0, LIFT + 0.26, 0), neck=(0, 2, 0))
# CHARGE: hands cup around the core, body curls, legs fold up (BACK settle)
idle.key(118, ease="BACK", root=(-12, 0, 0), root_pos=(0, LIFT - 0.06, 0), neck=(-17, 0, 0),
         rs=(64, 0, -22), ls=(64, 0, 22), rh=(28, 0, 3), lh=(34, 0, -3))
idle.marker(118, "charge")
# trembling build-up
idle.key(122, root=(-13, 1, 0), rs=(66, 0, -24), ls=(67, 0, 24), root_pos=(0, LIFT - 0.09, 0))
idle.key(126, root=(-11, -1, 0), rs=(63, 0, -21), ls=(63, 0, 21), neck=(-15, 0, 0), root_pos=(0, LIFT - 0.04, 0))
idle.key(130, root=(-14, 1, 0), rs=(67, 0, -25), ls=(66, 0, 25), root_pos=(0, LIFT - 0.1, 0))
idle.key(134, ease="IN", root=(-15, 0, 0), root_pos=(0, LIFT - 0.12, 0), neck=(-20, 0, 0),
         rs=(70, 0, -26), ls=(70, 0, 26), rh=(34, 0, 3), lh=(40, 0, -3))
# ZERO: arms fling down and out, back arches, body surges (head 2 f, legs 4 f later)
idle.key(136, ease="BACK", root=(13, 0, 0), root_pos=(0, LIFT + 0.55, 0), rs=(-24, 0, 58), ls=(-24, 0, -58))
idle.marker(136, "zero")
idle.key(138, ease="BACK", neck=(22, 0, 0))
idle.key(140, ease="OUT", rh=(-20, 0, 11), lh=(-14, 0, -11))
idle.key(146, root=(10, 0, 0), root_pos=(0, LIFT + 0.6, 0), rs=(-20, 0, 54), ls=(-20, 0, -55))
idle.key(152, neck=(14, 2, 0), rh=(-12, 0, 7), lh=(-6, 0, -7))
# UNLOCK: arms float down, the body descends (arms first, legs, head last)
idle.key(160, root=(6, -2, 0), root_pos=(0, LIFT + 0.36, 0), rs=(-8, 0, 40), ls=(-8, 0, -40))
idle.marker(160, "unlock")
idle.key(166, neck=(6, 3, 1), rh=(-8, 0, 5), lh=(5, 0, -4))
idle.key(172, root=(4, -3, -1), root_pos=(-0.03, LIFT + 0.08, 0), rs=(-5, 0, 32), ls=(-5, 0, -32))
idle.loop()
idle.noise("root", 1, 2.0, cycles=(1, 2, 3), seed=71)
idle.noise("root", 2, 1.0, cycles=(1, 2, 5), seed=72)
idle.noise("root", 1, 0.04, cycles=(2, 3, 4), seed=73, loc=True)
idle.noise("neck", 1, 2.0, cycles=(1, 3, 4), seed=74)
idle.noise("rh", 0, 3, cycles=(2, 3, 5), seed=75)
idle.noise("lh", 0, 3, cycles=(2, 4, 5), seed=76)
idle.noise("rs", 2, 1.5, cycles=(2, 3, 4), seed=77)
idle.noise("ls", 2, 1.5, cycles=(2, 3, 5), seed=78)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2
WY = LIFT - 0.15

walk.key(0, ease="IN", root=(-15, -3, 1), root_pos=(0, WY, 0), neck=(13, 3, 0),
         rs=(-18, 0, 42), ls=(-18, 0, -42), rh=(-10, 0, 4), lh=(-24, 0, -4))
# thrust: both arms push backward (EXPO), the body surges a hair
walk.key(3, ease="EXPO", root=(-18, 0, 0), root_pos=(0, WY + 0.1, 0), rs=(-40, 0, 30), ls=(-40, 0, -30))
walk.marker(2, "thrust")
walk.key(5, ease="EXPO", neck=(16, 0, 0))
walk.key(6, ease="OUT", rh=(-22, 0, 5), lh=(-14, 0, -4))
walk.key(h, root=(-16, 3, -1), root_pos=(0, WY + 0.06, 0), neck=(14, -3, 0),
         rs=(-32, 0, 34), ls=(-32, 0, -34), rh=(-24, 0, 4), lh=(-10, 0, -4))
walk.key(h + 5, root=(-15, 0, 0), root_pos=(0, WY - 0.02, 0), rs=(-22, 0, 40), ls=(-22, 0, -40),
         neck=(13, 0, 0), rh=(-17, 0, 4), lh=(-17, 0, -4))
walk.loop()

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))

asc = A.clip("ascend", seconds=0.8, trigger="jump", mode="add", blend_in=0.03, blend_out=0.25)
asc.pose(0, Z)
asc.key(1, ease="IN", root=(-5, 0, 0), neck=(-6, 0, 0), rs=(0, 0, 25), ls=(0, 0, -25), rh=(8, 0, 0), lh=(8, 0, 0))
asc.key(3, ease="EXPO", root=(8, 0, 0), root_pos=(0, 0.35, 0), rs=(-10, 0, -20), ls=(-10, 0, 20))
asc.marker(3, "push")
asc.key(5, ease="EXPO", neck=(12, 0, 0))
asc.key(7, ease="OUT", rh=(-14, 0, 4), lh=(-14, 0, -4))
asc.key(13, root=(4, 0, 0), root_pos=(0, 0.25, 0), neck=(6, 0, 0), rs=(-4, 0, -6), ls=(-4, 0, 6))
asc.pose(24, Z)

intr = A.clip("intrusion", seconds=1.0, trigger="intrusion", mode="add", blend_in=0.02, blend_out=0.25)
intr.pose(0, Z)
# the head snaps to the intruder at the front-right first...
intr.key(2, ease="EXPO", neck=(-6, -38, -4))
# ...the torso follows, the right arm winds up
intr.key(5, ease="OUT", root=(-2, -12, -2), rs=(-12, 0, 30), root_pos=(0, 0.08, 0))
# whip: the right hand stabs at it (kill)
intr.key(9, ease="EXPO", root=(-6, -16, -3), rs=(72, 0, 18), root_pos=(0.04, 0.13, 0))
intr.marker(9, "kill")
intr.key(11, ease="OUT", rh=(-10, 0, 3), lh=(6, 0, -2))
intr.key(16, root=(-4, -14, -2), rs=(64, 0, 14), neck=(-4, -34, -3), root_pos=(0.02, 0.11, 0))
# satisfied: the head turns back first, then the arm and torso
intr.key(21, neck=(2, -8, 0))
intr.key(26, root=(-1, -4, 0), rs=(14, 0, 4), rh=(0, 0, 0), lh=(0, 0, 0), root_pos=(0, 0, 0))
intr.pose(30, Z)

A.lift = LIFT

# preview framing for a levitating set (local helper, lib.py untouched)
_aim0 = lib._aim
lib._aim = lambda cam, loc, target=(0, 0, 2.6): _aim0(cam, (loc[0], loc[1], loc[2] + 1.3), (target[0], target[1], target[2] + 1.3))
A.cam.data.ortho_scale = 11


def keysheet(clip, frames, views=("front", "side", "3/4")):
    """Local helper (lib.py untouched): renders the exact frames given (markers / key poses)."""
    rig, sc, cam = A.rig, A.scene, A.cam
    rig.animation_data.action = clip.action
    marks = {}
    for m in clip.action.pose_markers:
        marks.setdefault(m.frame, []).append(m.name[3:])
    tmp = tempfile.mkdtemp(prefix="glitchkeys_")
    tiles = []
    for v in views:
        lib._aim(cam, lib.VIEWS[v])
        for f in frames:
            sc.frame_set(int(f))
            fp = os.path.join(tmp, f"{v.replace('/', '')}_{int(f):04d}.png")
            sc.render.filepath = fp
            bpy.ops.render.render(write_still=True)
            mk = marks.get(int(f))
            tiles.append((fp, f"{v} f{int(f)}" + (f" [{','.join(mk)}]" if mk else "")))
    dst = os.path.join(lib.PREVIEW_DIR, f"{A.id}_{clip.name}_keys.png")
    cmd = ["montage"]
    for fp, label in tiles:
        cmd += ["-label", label, fp]
    cmd += ["-tile", f"{len(frames)}x{len(views)}", "-geometry", "+2+2", "-background", "#111",
            "-fill", "#ddd", "-pointsize", "13", "-title", f"{A.id} / {clip.name} key poses", dst]
    subprocess.run(cmd, check=True, capture_output=True)
    print("[preview]", dst)


A.finish()
if os.environ.get("KEYS", "1") == "1":
    keysheet(idle, [0, 20, 26, 34, 54, 90, 100, 118, 134, 136, 146, 160])
    keysheet(intr, [0, 2, 5, 9, 16, 26])
