# Sentinel (1 in 888,888, LEGENDARY tier): "The firewall's last guardian."
# VFX (AurasHigh.lua A.Sentinel): six hexagon shield plates orbiting the body, a golden eye
# floating above the head with beams down to the plates and the ground, an eye ring, a ground
# sigil, sparks and a golden root light.
#
# CONCEPT: a grounded guardian (Legendary = big readable signature motion, no levitation). It
# holds a wide guard stance with the LEFT forearm up as a shield and the right fist cocked, scans
# the perimeter, then plants a stomp and crosses both arms in a block - the six plates slam into a
# hexagon WALL in front of it - holds the wall, and finally SHOVES it outward.
#
# IDLE (6.0 s = 180 f; the VFX cycle is driven by the markers, the sigil breathes with
#   Sync.phase(bus, 6)). Markers -> what the VFX does:
#   0-24    guard stance, weight on the right leg, slow breathing, plates orbit
#   30      "scan" "L"   head snaps over the LEFT shoulder (torso follows 4 f later, arms lag 6 f)
#                        VFX: the golden eye stops staring at the camera and looks where the head
#                        looks, a searchlight beam sweeps the ground on that side.
#   58      "scan" "R"   same to the RIGHT (the head whips through the centre).
#   88      anticipation: the body rises and leans back, the right leg lifts forward, the arms
#                        draw down and back (wound up).
#   96      "stomp"      the right foot slams down (EXPO), body drops, torso pitches forward.
#                        VFX: a hex shock ring races over the floor from the right foot, golden
#                        floor sparks burst there, the plates jolt upward.
#   98      "raise"      both arms snap up crossed before the face (2 f after the foot = overlap).
#                        VFX: the plates leave their orbit and lock into a hexagon wall in front.
#   98-138  hold the block: trembling, the head peeks over the arms at 118, the weight settles.
#   140     anticipation: arms pull in tight, torso coils (the wall is compressed toward the body)
#   146     "push"       BACK: both arms thrust forward and apart, palms out, torso drives in.
#                        VFX: the wall is shoved 3 studs outward and dissolves back into orbit,
#                        sparks burst from both palms, the eye flashes white.
#   156-180 overshoot, then the arms come back down into the guard stance.
#
# WALK (one stride): a shielded advance - the shield forearm stays up in front, the right fist
#   stays cocked, torso turned shield-side forward, heavy deliberate steps (the body sinks onto
#   each contact and rises on the passing pose, the shield arm jolts 1-2 f after each footfall).
#   VFX uses the runner's free "step" events: a small hex ripple under that foot and a plate jolt.
#
# REACTIONS:
#   brace (trigger "land", 0.8 s, add): superhero landing - the body absorbs the landing, the arms
#         cross into the block. marker 3 "slam" -> big hex shock ring + floor sparks + plates slam
#         down, the eye flashes.
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("Sentinel")

# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames


def guard(br=0.0, sway=0.0):
    """Wide guard stance. br = breath 0..1, sway -1..1 = weight left .. right."""
    return dict(
        root=(-3 + 1.5 * br, -11 + 2 * sway, -1.5 * sway),
        root_pos=(0.05 * sway, 0.14 + 0.03 * br, 0),
        neck=(1 - 2 * br, 11 - 2 * sway, 1.2 * sway),
        rs=(52 + 3 * br, 8, -8),  # right fist cocked
        ls=(78 + 3 * br, -8, 18),  # shield forearm up in front
        rh=(5, -6, 7 + 1.2 * sway),
        lh=(-6, -6, -7 + 1.2 * sway),
    )


idle.pose(0, guard(0, 0.6))
idle.pose(14, guard(1, 0.7))
idle.pose(24, guard(0.3, 0.5))
# SCAN LEFT: head snaps over the left shoulder, torso follows, arms lag
idle.key(30, ease="EXPO", neck=(2, 46, 3))
idle.marker(30, "scan", "L")
idle.key(34, ease="OUT", root=(-3, 4, 1), root_pos=(-0.03, 0.15, 0))
idle.key(36, ease="OUT", rs=(50, 8, -4), ls=(80, -8, 12))
idle.key(46, neck=(-2, 50, 2), root=(-2, 6, 1))
# whip through the centre to the RIGHT
idle.key(54, ease="IN", neck=(0, 12, 0))
idle.key(58, ease="EXPO", neck=(0, -42, -3))
idle.marker(58, "scan", "R")
idle.key(62, ease="OUT", root=(-3, -24, -2), root_pos=(0.05, 0.15, 0))
idle.key(64, ease="OUT", rs=(56, 8, -12), ls=(76, -8, 24))
idle.key(74, neck=(-3, -47, -2), root=(-3, -26, -2))
# back to the front, settle
idle.pose(82, guard(0.5, 0.2))
# ANTICIPATION: rise, lean back, right leg lifts forward, arms wind down and back
idle.key(90, ease="OUT", root=(5, -6, 2), root_pos=(-0.1, 0.14, 0), neck=(-4, 6, 0),
         rs=(-14, 0, 26), ls=(-10, 0, -26), rh=(30, 0, 5), lh=(-4, 0, -7))
# STOMP: the foot slams down, body drops, torso pitches forward
idle.key(96, ease="EXPO", rh=(4, -6, 9), lh=(-5, -6, -8), root=(-9, -4, 0), root_pos=(0, 0.17, 0))
idle.marker(96, "stomp")
# ...the arms snap up into the crossed block 2 f later, the head dips behind them
idle.key(98, ease="BACK", rs=(112, 6, -26), ls=(118, -6, 28), neck=(-9, 4, 0))
idle.marker(98, "raise")
idle.key(104, root=(-5, -4, 0), root_pos=(0, 0.16, 0), neck=(-6, 3, 0))
# hold the block: trembling, peek over the arms, weight settles
idle.key(110, rs=(110, 6, -27), ls=(115, -6, 29), root=(-6, -3, 1))
idle.key(118, neck=(6, 2, 0), rs=(104, 6, -24), ls=(110, -6, 26), root=(-4, -5, -1))
idle.key(126, rs=(111, 6, -28), ls=(117, -6, 30), root=(-6, -4, 1), root_pos=(0.02, 0.16, 0))
idle.key(134, neck=(-4, 3, 0), root=(-5, -4, 0))
# ANTICIPATION: pull in tight, coil
idle.key(141, ease="IN", rs=(84, 0, -38), ls=(88, 0, 40), root=(4, -2, 0), root_pos=(0, 0.18, 0),
         neck=(-10, 2, 0))
# PUSH: arms thrust forward and apart, torso drives in, head follows 2 f later
idle.key(146, ease="BACK", rs=(88, 0, 24), ls=(90, 0, -24), root=(-12, -2, 0), root_pos=(0, 0.18, 0))
idle.marker(146, "push")
idle.key(148, ease="BACK", neck=(8, 0, 0))
idle.key(150, ease="OUT", rh=(2, -6, 8), lh=(-9, -6, -8))
# overshoot hold, then back into the guard
idle.key(156, rs=(84, 0, 20), ls=(86, 0, -20), root=(-9, -4, 0), neck=(4, 3, 0))
idle.key(166, rs=(60, 6, -2), ls=(80, -6, 8), root=(-4, -9, -1), neck=(1, 8, 1))
idle.pose(172, guard(0.2, 0.5))
idle.loop()
idle.noise("neck", 1, 2.0, cycles=(1, 3, 4), seed=11)
idle.noise("neck", 0, 1.2, cycles=(2, 3, 5), seed=12)
idle.noise("root", 1, 1.0, cycles=(1, 2, 3), seed=13)
idle.noise("rs", 0, 1.5, cycles=(2, 3, 5), seed=14)
idle.noise("ls", 0, 1.5, cycles=(2, 4, 5), seed=15)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2


def contact(f, side):
    s = 1 if side == "R" else -1  # +1: right foot forward
    walk.key(f, ease="EXPO",
             root=(-6, -12 - 4 * s, -1.5 * s), root_pos=(0, 0.14, 0),
             neck=(2, 12 + 4 * s, 1.5 * s),
             rh=(21 * s, -4, 4), lh=(-21 * s, -4, -4))
    # the shield arm and the fist jolt 1-2 f after the footfall (weight)
    walk.key(f + 1.5, ease="OUT", ls=(72, -8, 16), rs=(46 + 3 * s, 8, -6))


def passing(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, root=(-9, -12, 1.5 * s), root_pos=(0, 0.2, 0), neck=(4, 12, 0),
             rh=(-2 * s, -4, 5), lh=(2 * s, -4, -5))
    walk.key(f + 1, ls=(80, -8, 18), rs=(52 - 3 * s, 8, -8))


contact(0, "R")
passing(h * 0.5, "R")
contact(h, "L")
passing(h * 1.5, "L")
walk.loop()

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
brace = A.clip("brace", seconds=0.8, trigger="land", mode="add", blend_in=0.02, blend_out=0.22)
brace.pose(0, Z)
brace.key(3, ease="EXPO", root=(-14, 0, 0), root_pos=(0, 0.0, 0), neck=(-10, 0, 0),
          rs=(40, 0, -12), ls=(26, 0, 12), rh=(12, 0, 3), lh=(10, 0, -3))
brace.marker(3, "slam")
brace.key(6, ease="OUT", neck=(6, 0, 0))
brace.key(10, root=(-10, 0, 0), root_pos=(0, 0.01, 0), rs=(42, 0, -12), ls=(28, 0, 12))
brace.key(16, ease="BACK", root=(-2, 0, 0), root_pos=(0, 0.02, 0), neck=(2, 0, 0), rs=(10, 0, -2),
          ls=(8, 0, 2), rh=(2, 0, 0), lh=(2, 0, 0))
brace.pose(24, Z)

A.lift = 0


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
    keysheet(idle, [0, 30, 46, 58, 74, 90, 96, 98, 118, 141, 146, 156])
if os.environ.get("LOWS"):
    for c in A.clips:
        A.rig.animation_data.action = c.action
        out = []
        for f in range(0, c.frames + 1, 2):
            A.scene.frame_set(f)
            out.append(f"{f}:{min(lib._lowest_sole(A.rig, 'rh'), lib._lowest_sole(A.rig, 'lh')):.2f}")
        print("[lows]", c.name, " ".join(out))
