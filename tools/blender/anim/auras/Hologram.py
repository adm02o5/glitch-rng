# Hologram (1 in 30,000, Epic): "A projection that learned to stand."
# Concept: a projected person that is still figuring out how to be a body. Everything it does
# runs at the projector's frame rate (the whole clip is re-sampled to 15 fps CONST steps, the
# walk to 10 fps), so it reads as a stop-motion broadcast, not a person. It raises its hand
# and studies it, turns it over (palm up -> palm down), brings the other hand in, compares
# them - then the SIGNAL DROPS: three wrong frames in different places, power sags, the head
# hangs, frozen. The projector re-syncs it into the calibration T-pose, the head scans left
# / right / centre like a boot routine, then it relaxes with a weight shift and glances at one
# of its own UI panels.
#
# CLIPS
#   idle (4.4 s, 132 f, loop, 15 fps steps)
#     f0-10    rest stance (slight contrapposto), tiny sway
#     f12-22   right hand rises to eye level, palm up; head tilts down at it, curious tilt
#     f28-32   the hand turns over (palm down), the head tilts the other way
#     f36-44   the left hand joins, both hands held side by side, head centred between them
#     f50-54   DROPOUT: three CONST wrong frames (body offset 0.35 studs, limbs scattered)
#     f56-60   power sag: head hangs, arms dangle, frozen
#     f62      CALIB: snap to the calibration T-pose
#     f68-80   head scans left, right, centre (CONST), arms re-seat by a degree
#     f86      release: arms drop with a BACK overshoot, weight shift to the left foot
#     f98-112  glance at a UI panel on the left (body follows), back
#   walk (lib.STRIDE, 10 fps steps): stiff, upright, perfectly regular projected stride with
#     small arm swing; one frame per stride the whole body jumps sideways (signal flick).
#   twitch (0.33 s, ADD, trigger "flicker"): when the VFX glitches the projection at random,
#     the head and shoulders jerk for two frames (VFX -> body).
#   rez (0.7 s, replace, trigger "land"): on landing the projection collapses into a crouch,
#     jitters sideways and re-materialises into the T-pose, then rest.
#
# MARKERS (AurasMid A.Hologram)
#   hand   f20   the hand reaches eye level  -> pixel sparkles off the right hand, panel #1
#                                               shows "HAND.OBJ"
#   turn   f30   the hand turns over          -> sparkles again, small skin flicker
#   drop   f50   signal lost                  -> skin offset + flicker for the whole dropout,
#                                               scan discs blink, panels nearly vanish, light
#                                               dips, lens sparks
#   calib  f62   T-pose snap                  -> all three scan discs sweep top -> bottom
#                                               together (0.7 s), panels read "CALIBRATING",
#                                               base ring flashes, light flash
#   scan   f68, f74, f80   head scan steps    -> the head emits a short pixel puff
#   glance f104  looks at the panel           -> the nearest panel flashes bright
#   flick  walk  the sideways jump             -> skin offset for 2 frames
#   rez    rez f6 re-materialise              -> discs sweep, sparkles from the whole body
#   (free) step -> a projector-blue pixel splash at the landing foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("Hologram")


def plant(clip, passes=3):
    """Raise root-height keys just enough that the lowest sole touches the floor (never lowers)."""
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


def quantize(clip, step):
    """Projector frame rate: re-sample every curve (modifiers included) every `step` frames and
    replace it with CONSTANT keys. Loops stay seamless (the end key = frame 0)."""
    n = clip.frames
    for fc in clip.all_curves():
        pts = [(f, fc.evaluate(f)) for f in range(0, n + 1, step)]
        if pts[-1][0] != n:
            pts.append((n, fc.evaluate(n)))
        if clip.looping:
            pts[-1] = (n, pts[0][1])
        for m in list(fc.modifiers):
            if m.type != "CYCLES":
                fc.modifiers.remove(m)
        fc.keyframe_points.clear()
        for f, v in pts:
            k = fc.keyframe_points.insert(f, v)
            k.interpolation = "CONSTANT"
        fc.update()


def keysheet(clip, frames, tag="keys"):
    """Extra contact sheet of hand-picked frames (front / side / 3-4) for reviewing key poses."""
    import subprocess
    import tempfile
    rig, sc, cam = A.rig, A.scene, A.cam
    rig.animation_data.action = clip.action
    tmp = tempfile.mkdtemp(prefix="glitchks_")
    cmd = ["montage"]
    for v in ("front", "side", "3/4"):
        lib._aim(cam, lib.VIEWS[v])
        for f in frames:
            sc.frame_set(f)
            fp = os.path.join(tmp, f"{v.replace('/', '')}_{f:04d}.png")
            sc.render.filepath = fp
            bpy.ops.render.render(write_still=True)
            cmd += ["-label", f"{v} f{f}", fp]
    dst = os.path.join(lib.PREVIEW_DIR, f"{A.id}_{clip.name}_{tag}.png")
    cmd += ["-tile", f"{len(frames)}x3", "-geometry", "+2+2", "-background", "#111", "-fill", "#ddd",
            "-pointsize", "13", dst]
    subprocess.run(cmd, check=False, capture_output=True)
    print("[preview]", dst)


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.4)  # 132 frames
K = idle.pose

REST = dict(
    root=(0, 3, 1.5), root_pos=(0.05, 0, 0), neck=(-2, -2, 0),
    rs=(3, 0, 5), ls=(2, 0, -6), rh=(0, 0, 3), lh=(0, 0, -1.5),
)
K(0, REST)
K(8, P(REST, root=(0, 2, 2), neck=(-1, -4, 1)))
# --- studies its right hand: rises to eye level palm up, head tilts down at it
K(12, P(REST, rs=(40, 0, 2), neck=(-6, -6, 2)), ease="IN")
HAND = P(REST, root=(1, -4, 1), rs=(104, 0, -14), neck=(-14, -16, 12), ls=(4, 0, -8))
K(20, HAND, ease="BACK")
idle.marker(20, "hand")
idle.key(24, neck=(-16, -18, 16))
# --- turns it over: palm down, curious tilt the other way
TURN = P(HAND, rs=(98, 170, -14), neck=(-12, -14, -10))
K(30, TURN, ease="EXPO")
idle.marker(30, "turn")
# --- the left hand joins: both side by side, head centred between them
BOTH = P(TURN, root=(2, 0, 0), root_pos=(0, 0, 0), rs=(96, 170, -10), ls=(96, 0, 10), neck=(-14, 0, 0))
K(38, BOTH, ease="BACK")
K(44, P(BOTH, rs=(100, 170, -12), ls=(100, 0, 12), neck=(-18, 0, 4)))
# --- DROPOUT: three wrong frames in different places, then the power sag
K(48, P(BOTH, neck=(-17, 2, 3)))
idle.marker(50, "drop")
K(50, dict(root=(0, 8, -6), root_pos=(0.35, 0, 0), neck=(10, 25, 15), rs=(30, 0, 40), ls=(-20, 0, -14),
           rh=(4, 0, 6), lh=(-4, 0, -2)), ease="CONST")
K(52, dict(root=(3, -10, 5), root_pos=(-0.28, 0.06, 0), neck=(-15, -22, -10), rs=(140, 0, 10), ls=(40, 0, -50),
           rh=(-4, 0, 1), lh=(6, 0, -6)), ease="CONST")
K(54, dict(root=(0, 0, 0), root_pos=(0.12, 0, 0), neck=(4, 10, 0), rs=(96, 170, -10), ls=(96, 0, 10),
           rh=(0, 0, 3), lh=(0, 0, -3)), ease="CONST")
SAG = dict(root=(-9, 0, 3), root_pos=(0, -0.12, 0.02), neck=(-34, 0, 6), rs=(-4, 0, 3), ls=(-4, 0, -3),
           rh=(10, 0, 3), lh=(10, 0, -3))
K(56, SAG, ease="CONST")
K(60, P(SAG, neck=(-36, 0, 8)), ease="CONST")
# --- CALIB: snap to the calibration T-pose, head scans left / right / centre
TP = dict(root=(0, 0, 0), root_pos=(0, 0.03, 0), neck=(0, 0, 0), rs=(0, 0, 90), ls=(0, 0, -90),
          rh=(0, 0, 5), lh=(0, 0, -5))
K(62, TP, ease="CONST")
idle.marker(62, "calib")
K(66, P(TP, rs=(0, 0, 88), ls=(0, 0, -91)), ease="CONST")
for f, ny in ((68, 34), (74, -34), (80, 0)):
    K(f, P(TP, rs=(0, 0, 88), ls=(0, 0, -91), neck=(0, ny, 0)), ease="CONST")
    idle.marker(f, "scan")
K(84, P(TP, rs=(0, 0, 89), ls=(0, 0, -89)), ease="IN")
# --- release with an overshoot, weight to the left foot
K(90, P(REST, root=(0, -2, -2.5), root_pos=(-0.06, 0, 0), rs=(4, 0, 2), ls=(6, 0, -3), neck=(2, 2, -2)),
  ease="BACK")
idle.key(93, neck=(-4, 2, -3))
# --- glance at a UI panel on the left; body follows a little
GL = P(REST, root=(0, 12, -1), root_pos=(-0.06, 0, 0), neck=(6, 34, 6), rs=(6, 0, 8), ls=(10, 0, -12))
K(100, GL, ease="EXPO")
idle.marker(104, "glance")
K(108, P(GL, neck=(8, 38, 4)))
K(116, P(REST, root=(0, 1, 0), neck=(-3, -4, 0)))
idle.loop()
idle.noise("root", 2, 1.2, cycles=(2, 3), seed=5)  # broadcast sway
idle.noise("neck", 0, 1.5, cycles=(3, 5), seed=6)
quantize(idle, 2)  # 15 fps projector steps

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(s):
    return dict(
        root=(-2, -5 * s, 0), root_pos=(0, 0, 0), neck=(1, 4 * s, 0),
        rs=(-24 * s, 0, 5), ls=(24 * s, 0, -5),
        rh=(26 * s, 0, 1.5), lh=(-26 * s, 0, -1.5),
    )


def passing(s):
    return dict(
        root=(-1, 0, 1.2 * s), root_pos=(0, 0.06, 0), neck=(0, 0, 0),
        rs=(0, 0, 5), ls=(0, 0, -5),
        rh=(-2 * s, 0, 1.5), lh=(2 * s, 0, -1.5),
    )


walk.pose(0, contact(1), ease="LINEAR")
walk.pose(h * 0.5, passing(1), ease="LINEAR")
walk.pose(h, contact(-1), ease="LINEAR")
walk.pose(h * 1.5, passing(-1), ease="LINEAR")
walk.loop()
quantize(walk, 3)  # 10 fps
plant(walk)
# the signal flick: one CONST frame where the whole body jumps sideways
rig = A.rig
walk._bind()
A.scene.frame_set(15)
pos15 = rig.pose.bones["root"].location.copy()
walk.key(15, ease="CONST", root_pos=(pos15.x + 0.32, pos15.y, pos15.z), neck=(0, -14, -8))
walk.key(16, ease="CONST", root_pos=tuple(pos15), neck=(0, -1, 0))
walk.marker(15, "flick")

# ------------------------------------------------------------------ twitch (ADD, VFX -> body)
tw = A.clip("twitch", seconds=0.33, trigger="flicker", mode="add", blend_in=0.01, blend_out=0.05)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0))
tw.pose(0, Z, ease="CONST")
tw.pose(1, dict(root=(0, 4, 3), neck=(6, 20, 12), rs=(0, 0, 10), ls=(-6, 0, 0)), ease="CONST")
tw.pose(3, dict(root=(0, -3, -2), neck=(-8, -12, -6), rs=(4, 0, -2), ls=(0, 0, -9)), ease="CONST")
tw.pose(5, Z, ease="CONST")
tw.pose(10, Z, ease="CONST")

# ------------------------------------------------------------------ rez (on landing)
rz = A.clip("rez", seconds=0.7, trigger="land", mode="replace", blend_in=0.02, blend_out=0.2)
CR = dict(root=(-16, 0, 0), root_pos=(0, -0.45, 0.15), neck=(-24, 0, 0), rs=(18, 0, 14), ls=(18, 0, -14),
          rh=(22, 0, 5), lh=(22, 0, -5))
rz.pose(0, CR, ease="CONST")
rz.pose(2, P(CR, root_pos=(0.3, -0.45, 0.15), neck=(-10, 20, 10)), ease="CONST")
rz.pose(4, P(CR, root_pos=(-0.25, -0.45, 0.15), neck=(-30, -14, -6), rs=(40, 0, 30)), ease="CONST")
rz.pose(6, TP, ease="CONST")
rz.marker(6, "rez")
rz.pose(10, P(TP, rs=(0, 0, 87), ls=(0, 0, -87)), ease="CONST")
rz.pose(14, P(REST, rs=(10, 0, 20), ls=(10, 0, -20)), ease="CONST")
rz.pose(16, REST, ease="CONST")
rz.pose(21, REST, ease="CONST")

plant(idle)
plant(rz)

A.lift = 0
A.finish(preview=False)
A.preview(frames_per_clip=12)
keysheet(idle, [0, 20, 30, 40, 50, 52, 56, 62, 74, 90, 104])
