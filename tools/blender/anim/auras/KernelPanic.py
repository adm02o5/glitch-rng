# Kernel Panic (1 in 25,000,000, CORRUPTED tier, KernelPanic biome only): "Only during total
# system failure."  VFX: violent red glitch storm, warning triangles, alarm searchlights, sky
# lightning, a KERNEL PANIC title and error streams (AurasHigh.lua, A.KernelPanic).
#
# CONCEPT: the body IS the crashing machine. It never levitates (a crash is grounded): a wide,
# tense stance that never stops trembling (high-frequency periodic noise on every joint), the
# alarm goes off, it searches for the source, seizes in glitch snaps, clutches its head, screams
# at the sky, SLAMS the ground with both fists, blacks out and hard-reboots.
#
# IDLE (5.0 s = 150 f, grounded). Markers -> what the VFX does:
#   0-12    tense stance, weight on the left foot, breath in at 8
#   14      anticipation: head flicks right a little, shoulders hunch
#   18      "alarm" "L"  EXPO head whip to the LEFT, torso follows 4 f later, arms flinch up
#                        VFX: both searchlights snap onto the left side and hold, the left
#                        warning triangles flare, an alarm flash of the root light
#   30      "alarm" "R"  the same whip to the RIGHT (head first, torso at 34, arms lag to 36)
#   40/42/44 "spasm"     three CONST broken poses (seizure)
#                        VFX: every glitch block re-scatters at once, square + spark bursts out
#                        of the chest, the title tears (offset + flicker), light strobes white
#   46      EXPO recovery to the tense stance
#   52-58   both hands rise to the head; 58 "clutch" (hands on the temples)
#                        VFX: the error streams collapse into a tight ring around the head and
#                        scroll fast for the clutch window (58-82), head sparks
#   62-78   rocking + head shaking "no" inside the hands, torso folds forward
#   84      "scream"     BACK: torso arches back, head thrown up, arms flung down and out wide
#                        VFX: fire-spark sprays from both hands, the warning triangles are blown
#                        outward (radius 5 -> 8), title scales up, light surge
#   100-104 anticipation: both arms swing up overhead, the body rises onto the toes
#   108     "slam"       EXPO both fists slam down, sumo crouch (legs splayed, torso hunched)
#                        VFX: floor shock ring + smoke burst, the two sky lightning bolts strike
#                        at once, root light flash, the floor ring speeds up
#   118     "blackout"   IN: the body goes limp, head drops, arms hang dead
#                        VFX: LIGHTS OUT - emitters throttle, title and triangles hidden,
#                        searchlights off, light 0 (until "reboot")
#   132     "reboot"     CONST: rigid boot pose (stiff, arms at the sides, staring ahead),
#                        134 CONST overshoot glitch, 140 BACK back into the tense stance
#                        VFX: white flash, the title reads "REBOOTING..." for a moment, blocks
#                        reappear, everything comes back on
#
# WALK (one stride): a panicked stagger - torso pitched forward and twisted, the right arm
#   shields the head, the left flails behind, the head keeps glancing back over the shoulder.
#   On frames 2 and h+2 the body hitches: a CONST sideways stutter for 2 frames.
#   2 / h+2 "hitch" "R"/"L" -> VFX: sparks burst from that foot + blocks re-scatter.
#   (free "step" events: a small red spark puff at each footfall)
#
# REACTIONS (one-shots, mode "add"):
#   jolt  (trigger "strike", 0.8 s): the VFX fires "strike" every 3.5-6.5 s (a dedicated huge
#         bolt hits the ground next to the player) -> electrocution: CONST shudders.
#         marker 1 "zap" -> spark bursts from both hands + chest, white flash.
#   crash (trigger "land", 0.7 s): landing a jump buckles the body (squash + arms flail).
#         marker 1 "impact" -> floor shock + smoke puff.
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("KernelPanic")


def hold(clip, f):
    """Freeze every animated channel at frame f with a CONSTANT key so the next key is a hard
    snap (a lib ease shapes the segment LEAVING a key)."""
    for fc in clip.all_curves():
        k = fc.keyframe_points.insert(f, fc.evaluate(f))
        k.interpolation = "CONSTANT"
        fc.update()


def plant(clip, extra=None, passes=3):
    """Grounding pass (R6 has no knees, and a splayed block leg dips its inner sole corner):
    on every keyed frame of the clip, set the root height so the lowest sole corner touches the
    floor exactly (+ extra[frame] studs, e.g. up on the toes). Keeps each key's easing."""
    extra = extra or {}
    rig, sc = A.rig, A.scene
    rig.animation_data.action = clip.action
    frames = sorted({int(round(k.co.x)) for fc in clip.all_curves() for k in fc.keyframe_points})
    if clip.looping:
        frames = [f for f in frames if f < clip.frames]
    if not clip._curves('pose.bones["root"].location'):
        clip.key(0, root_pos=(0, 0, 0))
    ycurve = [fc for fc in clip._curves('pose.bones["root"].location') if fc.array_index == 1][0]
    for _ in range(passes):
        for f in frames:
            sc.frame_set(f)
            low = min(lib._lowest_sole(rig, "rh"), lib._lowest_sole(rig, "lh"))
            want = ycurve.evaluate(f) - low + extra.get(f, 0.0)
            kp = next((k for k in ycurve.keyframe_points if abs(k.co.x - f) < 1e-3), None)
            if kp is None:
                prev = [k for k in ycurve.keyframe_points if k.co.x < f]
                kp = ycurve.keyframe_points.insert(f, want)
                if prev:
                    kp.interpolation = prev[-1].interpolation
            dy = want - kp.co.y
            kp.co.y = want
            kp.handle_left.y += dy
            kp.handle_right.y += dy
            ycurve.update()
        if clip.looping:
            end = next((k for k in ycurve.keyframe_points if abs(k.co.x - clip.frames) < 1e-3), None)
            if end is not None:
                end.co.y = ycurve.keyframe_points[0].co.y
                ycurve.update()


def unsink(clip, tol=0.03, passes=3):
    """Residual pass after plant() / noise(): any whole frame whose sole still dips below the
    floor gets a root-height key that lifts it back (frames are what the game samples)."""
    rig, sc = A.rig, A.scene
    rig.animation_data.action = clip.action
    ycurve = [fc for fc in clip._curves('pose.bones["root"].location') if fc.array_index == 1][0]
    last = clip.frames if not clip.looping else clip.frames - 1
    for _ in range(passes):
        fixes = []
        for f in range(0, last + 1):
            sc.frame_set(f)
            low = min(lib._lowest_sole(rig, "rh"), lib._lowest_sole(rig, "lh"))
            if low < -tol:
                fixes.append((f, ycurve.evaluate(f) - low))
        if not fixes:
            return
        for f, v in fixes:
            prev = [k for k in ycurve.keyframe_points if k.co.x <= f]
            interp = prev[-1].interpolation if prev else "BEZIER"
            kp = ycurve.keyframe_points.insert(f, v)
            kp.interpolation = interp
        ycurve.update()


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=5.0)  # 150 frames


def tense(sway, rise=0.0):
    """Wide braced stance. sway -1..1 = weight on the left .. right foot."""
    return dict(
        root=(-5, 3 * sway, -2 * sway),
        root_pos=(0.06 * sway, -0.04 + rise, 0),
        neck=(-6, -4 * sway, 2 * sway),
        rs=(10, 0, 16 + 2 * sway),
        ls=(10, 0, -16 + 2 * sway),
        rh=(5, 0, 11 + 2 * sway),
        lh=(5, 0, -11 + 2 * sway),
    )


idle.pose(0, tense(-1))
idle.key(8, root=(-3, -2, 1.5), root_pos=(-0.05, -0.02, 0), neck=(-3, 2, -1.5), rs=(12, 0, 18), ls=(12, 0, -18))
# anticipation: a flick to the right before the whip left
idle.key(14, ease="EXPO", neck=(-8, -12, -3), root=(-5, -4, 1), rs=(14, 0, 20), ls=(14, 0, -20))
# ALARM LEFT: head first, torso lags 4 f, arms flinch up and lag 6 f
idle.key(18, ease="EXPO", neck=(2, 48, 8), root=(-4, 2, 1))
idle.marker(18, "alarm", "L")
idle.key(22, root=(-2, 18, 3), root_pos=(-0.08, -0.02, 0), rs=(26, 0, 30), ls=(30, 0, -26),
         rh=(5, 0, 13), lh=(5, 0, -9))
idle.key(24, neck=(4, 52, 10), rs=(30, 0, 33), ls=(34, 0, -28))  # overshoot
idle.key(27, neck=(0, 44, 6), root=(-3, 16, 2))
# ALARM RIGHT (bigger, the source must be there)
idle.key(30, ease="EXPO", neck=(0, -56, -10), root=(-4, 10, 0))
idle.marker(30, "alarm", "R")
idle.key(34, root=(-3, -20, -4), root_pos=(0.1, -0.03, 0), rh=(5, 0, 9), lh=(5, 0, -13))
idle.key(36, neck=(3, -60, -12), rs=(34, 0, 26), ls=(24, 0, -34))
idle.key(39, ease="LINEAR", neck=(1, -54, -9), root=(-4, -18, -3), rs=(32, 0, 25), ls=(22, 0, -32))
hold(idle, 39)
# SPASM: three CONST broken poses (seizure)
idle.key(40, ease="CONST", root=(-14, 14, 9), root_pos=(0.15, -0.02, 0.05), neck=(-26, 30, -32),
         rs=(110, 0, 48), ls=(-24, 0, -64), rh=(10, 0, 4), lh=(14, 0, -20))
idle.marker(40, "spasm")
idle.key(42, ease="CONST", root=(10, -18, -10), root_pos=(-0.18, 0.04, -0.05), neck=(30, -24, 28),
         rs=(-30, 0, 70), ls=(130, 0, -30), rh=(-4, 0, 18), lh=(-6, 0, -6))
idle.marker(42, "spasm")
idle.key(44, ease="CONST", root=(-20, 6, -4), root_pos=(0.06, -0.08, 0.08), neck=(-34, -10, 14),
         rs=(60, 0, 80), ls=(70, 0, -80), rh=(22, 0, 14), lh=(22, 0, -14))
idle.marker(44, "spasm")
# EXPO recovery
idle.pose(46, tense(0.4), ease="INOUT")
idle.key(46, neck=(-10, -6, 4))
idle.key(50, ease="INOUT", rs=(30, 0, 14), ls=(30, 0, -14), neck=(-12, 0, 0))
# CLUTCH: hands to the temples (arms rise; head ducks into them, lagging 2 f)
idle.key(55, rs=(120, -10, -6), ls=(120, 10, 6), root=(-8, 2, 0), root_pos=(0.02, -0.06, 0))
idle.key(58, ease="BACK", rs=(150, 0, -32), ls=(150, 0, 32), neck=(-16, 0, 0), root=(-10, 0, 0))
idle.marker(58, "clutch")
# rocking + shaking "no" inside the hands, folding forward
for i, f in enumerate((62, 66, 70, 74)):
    s = 1 if i % 2 == 0 else -1
    idle.key(f, neck=(-18 - i * 2, 16 * s, 4 * s), root=(-12 - i * 2.5, -4 * s, 3 * s),
             root_pos=(0.04 * s, -0.07 - i * 0.012, 0),
             rs=(150 - i * 3, 0, -32), ls=(150 - i * 3, 0, 32),
             rh=(12 + i * 2.5, 0, 11 - 2 * s), lh=(12 + i * 2.5, 0, -11 - 2 * s))
idle.key(79, ease="IN", neck=(-30, 0, 0), root=(-24, 0, 0), root_pos=(0, -0.13, 0),
         rs=(140, 0, -30), ls=(140, 0, 30), rh=(24, 0, 12), lh=(24, 0, -12))
# SCREAM: arch back, head up, arms flung down and out wide
idle.key(84, ease="BACK", root=(16, 0, 0), root_pos=(0, 0.02, 0.05), neck=(44, 0, 0),
         rs=(-22, 0, 58), ls=(-22, 0, -58), rh=(-12, 0, 13), lh=(-12, 0, -13))
idle.marker(84, "scream")
idle.key(88, neck=(50, 4, 3), rs=(-26, 0, 64), ls=(-26, 0, -64), root=(18, 2, 0))  # head lags further
idle.key(96, ease="LINEAR", neck=(46, -3, -2), root=(15, -2, 0), rs=(-24, 0, 60), ls=(-24, 0, -60))
# anticipation for the slam: arms swing up overhead, up onto the toes
idle.key(100, root=(4, 0, 0), root_pos=(0, 0.04, 0), neck=(12, 0, 0), rs=(110, 0, 20), ls=(110, 0, -20),
         rh=(-4, 0, 9), lh=(-4, 0, -9))
idle.key(104, ease="IN", root=(8, 0, 0), root_pos=(0, 0.1, 0), neck=(16, 0, 0),
         rs=(172, 0, 10), ls=(172, 0, -10), rh=(-8, 0, 6), lh=(-8, 0, -6))
# SLAM: fists down, sumo crouch
idle.key(108, ease="EXPO", root=(-30, 0, 0), root_pos=(0, -0.42, -0.1), neck=(-14, 0, 0),
         rs=(62, -18, 14), ls=(62, 18, -14), rh=(30, 0, 34), lh=(30, 0, -34))
idle.marker(108, "slam")
idle.key(112, root=(-24, 2, 1), root_pos=(0, -0.32, -0.06), neck=(-4, 3, 2), rs=(56, -14, 16), ls=(52, 14, -18),
         rh=(25, 0, 30), lh=(25, 0, -30))
idle.key(116, ease="LINEAR", root=(-25, 0, 0), root_pos=(0, -0.34, -0.06), neck=(-6, 0, 0))
# BLACKOUT: limp collapse (gravity)
idle.key(118, ease="IN", neck=(-8, 0, 0))
idle.marker(118, "blackout")
idle.key(124, ease="OUT", root=(-20, 3, 4), root_pos=(0, -0.3, -0.05), neck=(-46, 6, 10),
         rs=(4, 0, 6), ls=(6, 0, -4), rh=(22, 0, 28), lh=(22, 0, -28))
idle.key(131, ease="LINEAR", root=(-21, 3, 5), root_pos=(0, -0.31, -0.05), neck=(-48, 7, 12),
         rs=(2, 0, 4), ls=(4, 0, -3))
hold(idle, 131)
# REBOOT: rigid boot pose, CONST
BOOT = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 3), ls=(0, 0, -3), rh=(0, 0, 3), lh=(0, 0, -3))
idle.pose(132, BOOT, ease="CONST")
idle.marker(132, "reboot")
idle.key(134, ease="CONST", root=(3, -6, 2), root_pos=(0.05, 0.03, 0), neck=(6, 14, -6), rs=(-6, 0, 10), ls=(8, 0, -8))
idle.pose(136, BOOT, ease="CONST")
idle.key(137, ease="INOUT", neck=(0, 0, 0))
idle.pose(142, tense(-1, 0.02), ease="BACK")
idle.loop()
plant(idle, {104: 0.08, 100: 0.03, 84: 0.04})
# never-ending tremor (fast, small) + slower organic drift; step=1 keeps the CONST snaps exact
idle.noise("root", 0, 1.0, cycles=(29, 41, 53), seed=11, step=1)
idle.noise("root", 2, 0.8, cycles=(31, 43, 59), seed=12, step=1)
idle.noise("neck", 1, 2.2, cycles=(23, 37, 47), seed=13, step=1)
idle.noise("neck", 0, 1.4, cycles=(3, 27, 41), seed=14, step=1)
idle.noise("rs", 2, 2.4, cycles=(19, 33, 49), seed=15, step=1)
idle.noise("ls", 2, 2.4, cycles=(21, 35, 51), seed=16, step=1)
idle.noise("rs", 0, 2.0, cycles=(2, 25, 45), seed=17, step=1)
idle.noise("ls", 0, 2.0, cycles=(3, 27, 43), seed=18, step=1)
unsink(idle)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2


def contact(f, side):
    s = 1 if side == "R" else -1  # +1: right foot forward
    walk.key(f, ease="EXPO",
             root=(-14, -8 * s, -3 * s), root_pos=(0, -0.08, 0),
             neck=(-2, 22 * s + 6, 6 * s),  # glancing back over the trailing shoulder
             rs=(146 - 8 * s, -26, -12), ls=(-40 - 14 * s, 0, -30 - 6 * s),
             rh=(14 + 30 * s, 0, 4), lh=(14 - 30 * s, 0, -4))


def hitch(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, ease="CONST", root=(-20, -14 * s, 8 * s), root_pos=(0.22 * s, -0.04, -0.12),
             neck=(-18, -20 * s, -18 * s), rs=(166, -14, 8), ls=(-70, 0, -50),
             rh=(20 + 24 * s, 0, 10), lh=(20 - 24 * s, 0, -10))
    walk.marker(f, "hitch", side)


def passing(f, side):
    s = 1 if side == "R" else -1  # the right leg carries the weight when s = 1
    walk.key(f, root=(-12, 0, 3 * s), root_pos=(0, 0.06, 0),
             neck=(-6, -6 * s, -2 * s),
             rs=(140, -22, -10), ls=(-34, 0, -24),
             rh=(12 - 4 * s, 0, 4), lh=(12 + 4 * s, 0, -4))


contact(0, "R")
hold(walk, 1)
hitch(2, "R")
walk.key(4, ease="INOUT", root=(-14, -6, -2), root_pos=(0, -0.06, 0), neck=(-4, 24, 5))
passing(h * 0.55, "R")
contact(h, "L")
hold(walk, h + 1)
hitch(h + 2, "L")
walk.key(h + 4, ease="INOUT", root=(-14, 6, 2), root_pos=(0, -0.06, 0), neck=(-4, -12, -5))
passing(h * 1.55, "L")
walk.loop()
plant(walk, {round(h * 0.55): 0.05, round(h * 1.55): 0.05})
walk.noise("rs", 0, 3, cycles=(5, 7, 11), seed=21, step=1)
walk.noise("ls", 2, 4, cycles=(4, 9, 13), seed=22, step=1)
unsink(walk)

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))

jolt = A.clip("jolt", seconds=0.8, trigger="strike", mode="add", blend_in=0.02, blend_out=0.2)
jolt.pose(0, Z)
shudders = [
    dict(root=(10, 4, -4), root_pos=(0, 0.12, 0), neck=(26, -10, 12), rs=(-14, 0, 40), ls=(-14, 0, -40), rh=(-3, 0, 4), lh=(-3, 0, -4)),
    dict(root=(4, -6, 5), root_pos=(0.06, 0.08, 0), neck=(14, 14, -14), rs=(-6, 0, 28), ls=(-20, 0, -48)),
    dict(root=(12, 5, -3), root_pos=(-0.06, 0.12, 0), neck=(30, -6, 8), rs=(-22, 0, 50), ls=(-8, 0, -30)),
    dict(root=(5, -3, 4), root_pos=(0.04, 0.07, 0), neck=(16, 8, -8), rs=(-8, 0, 30), ls=(-16, 0, -38)),
    dict(root=(8, 2, -2), root_pos=(0, 0.09, 0), neck=(22, -3, 4), rs=(-14, 0, 38), ls=(-12, 0, -36)),
]
for i, p in enumerate(shudders):
    jolt.pose(1 + i * 2, p, ease="CONST")
jolt.marker(1, "zap")
jolt.key(11, ease="INOUT", root=(5, 0, 0), root_pos=(0, 0.04, 0), neck=(10, 0, 0), rs=(-6, 0, 16), ls=(-6, 0, -16))
jolt.pose(24, Z)
plant(jolt, {1: 0.12, 3: 0.06, 5: 0.12, 7: 0.05, 9: 0.08, 11: 0.03})
unsink(jolt)

crash = A.clip("crash", seconds=0.7, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
crash.pose(0, Z)
crash.key(2, ease="EXPO", root=(-16, 0, 0), root_pos=(0, -0.3, -0.06), neck=(-12, 0, 0),
          rs=(30, 0, 24), ls=(30, 0, -24), rh=(16, 0, 18), lh=(16, 0, -18))
crash.marker(2, "impact")
crash.key(6, root=(-10, 5, 3), root_pos=(0, -0.18, -0.04), neck=(6, -10, 6), rs=(10, 0, 34), ls=(40, 0, -10),
          rh=(10, 0, 12), lh=(10, 0, -12))
crash.key(11, root=(-4, -3, -1), root_pos=(0, -0.05, 0), neck=(-4, 6, -3), rs=(8, 0, 8), ls=(6, 0, -10),
          rh=(4, 0, 4), lh=(4, 0, -4))
crash.pose(21, Z)
plant(crash)

A.lift = 0
A.air = 0.25


# ------------------------------------------------------------------ preview of the key poses
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
    keysheet(idle, [0, 18, 24, 30, 40, 42, 44, 58, 70, 84, 104, 108, 124, 132])
