# Corruption (1 in 12,000,000, CORRUPTED tier): "The save file is damaged. So are you."
# VFX (AurasHigh.lua, A.Corruption): black-red tearing shards orbiting, glowing ground cracks
# spreading from the feet, inverted ghosts (mirrored clone under the floor + lagging black
# clone), a corrupted block halo, a red pillar, the "SAVE FILE CORRUPTED" title.
#
# CONCEPT: a broken save-file puppet. The body is a damaged state: a twisted broken-doll stance
# (torso turned and leaning, head lolled far to one side, one arm limp, the other bent back),
# limbs that SNAP into wrong angles on CONST frames, a state ROLLBACK (the pose jumps back to
# older frames), a huge STOMP that cracks the ground, and a claw that RIPS the air open.
# Grounded on purpose (the ground cracks come from its feet) - no levitation.
#
# IDLE (6.0 s = 180 f, grounded). Markers -> what the VFX does:
#   0-22    broken-doll stance, heavy uneven breathing, head lolled, weight on the right hip
#   28      "snap" "head"   CONST: the head snaps over to the other shoulder (overshoot 29)
#                        VFX: square burst from the head, the nearest shards tear outward,
#                            red light flick, the title glitches
#   44      "snap" "rarm"   CONST: the right arm snaps out to a wrong angle, then drops limp
#                        VFX: square burst from the right hand, shards near it tear
#   60      "snap" "larm"   CONST: the left arm wrenches behind the back
#                        VFX: square burst from the left hand, shards tear
#   64-70   "rollback"      CONST: the pose jumps back to frame 0, forward to 60, back, forward
#                        VFX: the save "rolls back": every shard jumps back along its orbit,
#                            the halo flickers, title shows "LOADING BACKUP...", crack glow drops
#   76-88   anticipation: weight onto the left foot, the right knee rises high, arms raised
#           outward like claws, head down glaring
#   92      "stomp"         EXPO: the right foot SLAMS down into a crouch, arms flung down/out,
#                            the head whips up 3 f later
#                        VFX: the ground cracks flash and a glow wave runs out of them from the
#                            centre, floor shockwave + red debris + smoke, every shard tears,
#                            big light flash, sparks from the right foot
#   112-118 right arm rises overhead, the head follows it, torso coils back (anticipation)
#   121     "rip" "rhand"   EXPO: the claw rips diagonally down across the body, torso twists
#                        VFX: a red tear streak stays in the air along the hand's path,
#                            fire sparks + black squares spray from the hand, shards tear
#   136/143 "twitch" "head" CONST head twitches; 150 "twitch" "body" a whole-body shudder
#                        VFX: title corrupts, small square burst from the head / chest
#   156-180 slowly folds back into the broken-doll stance
#
# WALK (one stride): a broken limp. The RIGHT foot lands as a heavy stomp (torso slams down,
#   the head lags and bounces), the LEFT leg drags and lands with a CONST glitch twitch.
#   0   "stomp" "R"       VFX: crack glow pulse + small shockwave + sparks at the right foot
#   h+1 "glitch" "L"      VFX: square burst at the left foot, title glitch
#   (free "step": dark smoke puff at that foot)
#
# REACTIONS:
#   wrench (trigger "tear", 0.8 s, add): the VFX fires "tear" every 4-7 s (a big shard rips
#          loose and flies out): the spine jerks in CONST spasms. 1 "wrench" -> chest burst.
#   crash  (trigger "land", 0.7 s, add): a heavy landing crouch. 2 "stomp" "land" -> the same
#          ground-crack stomp as the idle.
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("Corruption")


# ------------------------------------------------------------------ local helpers
def hold(clip, f):
    """CONSTANT key on every animated channel at f (the next key becomes a hard snap)."""
    for fc in clip.all_curves():
        k = fc.keyframe_points.insert(f, fc.evaluate(f))
        k.interpolation = "CONSTANT"
        fc.update()


def plant(clip, extra=None, passes=3):
    """On every keyed frame, set the root height so the lowest sole touches the floor exactly
    (+ extra[frame] studs). Keeps each key's easing."""
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
    """Any whole frame whose sole still dips below the floor gets a lifting root key."""
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
idle = A.clip("idle", seconds=6.0)  # 180 frames


def doll(breath=0.0):
    """Broken-doll stance; breath 0..1 (chest rises, head lifts a little)."""
    return dict(
        root=(-9 + 4 * breath, 10, -5),
        root_pos=(0.08, -0.04, 0),
        neck=(-12 + 5 * breath, -18, 26 - 3 * breath),
        rs=(14 - 3 * breath, 0, 5 + 2 * breath),
        ls=(-12, 0, -14 - 2 * breath),
        rh=(4, 0, 7),
        lh=(-3, 0, -3),
    )


idle.pose(0, doll(0))
idle.pose(12, doll(1))
idle.key(15, neck=(-6, -16, 21))  # head lags the breath
idle.pose(22, doll(0.1))
idle.key(24, neck=(-14, -18, 29))
# SNAP head: slow roll toward centre (anticipation), then CONST to the other shoulder
idle.key(27, ease="IN", neck=(-8, -6, 10))
idle.key(28, ease="CONST", neck=(-4, 22, -42), root=(-10, 12, -7))
idle.marker(28, "snap", "head")
idle.key(29, ease="CONST", neck=(-2, 27, -49))
idle.key(31, ease="INOUT", neck=(-4, 20, -40), root=(-9, 10, -5))
idle.key(38, ease="INOUT", neck=(-9, 15, -33))
# SNAP right arm: tremble, then wrong angle, then dropped limp with a bounce
idle.key(42, ease="LINEAR", rs=(18, 0, 2))
idle.key(43, rs=(16, 0, 3))
idle.key(44, ease="CONST", rs=(30, -40, 102), root=(-6, 6, -9), neck=(-6, 18, -40))
idle.marker(44, "snap", "rarm")
idle.key(46, ease="LINEAR", rs=(27, -44, 106))
idle.key(53, ease="IN", rs=(22, -30, 96))
idle.key(56, ease="BOUNCE", rs=(6, 0, 22), root=(-9, 9, -5))
# SNAP left arm: wrenched behind the back, the head jolts with it
idle.key(58, ease="IN", ls=(-6, 0, -10))
idle.key(60, ease="CONST", ls=(-72, 30, -36), neck=(-4, 26, -52), root=(-12, 14, -3))
idle.marker(60, "snap", "larm")
idle.key(62, ease="CONST", neck=(-6, 22, -46))
POSE60 = dict(root=(-12, 14, -3), neck=(-6, 22, -46), rs=(6, 0, 22), ls=(-72, 30, -36))
# ROLLBACK: the save jumps back to frame 0, forward, back, forward
D0 = doll(0)
idle.pose(64, D0, ease="CONST")
idle.marker(64, "rollback")
idle.pose(66, POSE60, ease="CONST")
idle.pose(68, D0, ease="CONST")
idle.key(70, ease="CONST", root=(-6, -18, 6), neck=(-10, -30, 34), rs=(10, 0, 30), ls=(-40, 0, -30))
idle.key(72, ease="INOUT", root=(-8, 4, -2), neck=(-12, -10, 20), rs=(12, 0, 10), ls=(-20, 0, -16))
# STOMP: weight onto the left foot, the right knee rises, claws raised wide
idle.key(78, root=(-4, 2, 7), root_pos=(-0.12, 0, 0), neck=(-14, 0, 6), rs=(30, 0, 60), ls=(30, 0, -60),
         rh=(20, 0, 8), lh=(0, 0, -2))
idle.key(85, ease="OUT", root=(4, -4, 6), root_pos=(-0.12, 0, 0), neck=(-22, 0, 2), rs=(40, 0, 122), ls=(40, 0, -122),
         rh=(64, 0, 8), lh=(-2, 0, -2))
idle.key(89, ease="IN", root=(6, -5, 6), neck=(-24, 0, 0), rs=(44, 0, 130), ls=(44, 0, -130), rh=(68, 0, 9))
idle.key(92, ease="EXPO", root=(-24, 0, 0), root_pos=(0, -0.4, -0.06), neck=(-30, 0, 0),
         rs=(-8, 0, 52), ls=(-8, 0, -52), rh=(16, 0, 16), lh=(16, 0, -16))
idle.marker(92, "stomp", "R")
idle.key(95, ease="BACK", neck=(-2, 6, 8), root=(-20, 3, 2), rs=(-12, 0, 58), ls=(-6, 0, -48))  # head whips up
idle.key(101, root=(-15, 6, -2), root_pos=(0.04, -0.28, -0.04), rs=(2, 0, 34), ls=(-6, 0, -30), neck=(-6, 4, 12),
         rh=(12, 0, 12), lh=(10, 0, -12))
# RIP: the right claw rises overhead (head follows 3 f later), torso coils back
idle.key(110, root=(-2, -4, 2), root_pos=(0.04, -0.05, 0), rs=(150, 10, 20), ls=(-18, 0, -18), rh=(4, 0, 6), lh=(-2, 0, -4))
idle.key(113, neck=(16, -8, 4))
idle.key(118, ease="IN", root=(8, -14, 4), rs=(176, 0, 32), neck=(20, -12, 2), ls=(-26, 0, -24))
idle.key(121, ease="EXPO", root=(-18, 18, -4), rs=(44, 40, 14), neck=(-18, 14, -6), ls=(-34, 0, -30),
         root_pos=(0.02, -0.1, -0.04))
idle.marker(121, "rip", "rhand")
idle.key(124, rs=(28, 46, 18), root=(-20, 22, -5), neck=(-14, 20, -10))
idle.key(132, ease="INOUT", rs=(12, 0, 8), root=(-10, 12, -4), neck=(-12, 0, 14), ls=(-14, 0, -14),
         root_pos=(0.06, -0.04, 0))
# TWITCHES
hold(idle, 135)
idle.key(136, ease="CONST", neck=(-4, -24, 36))
idle.marker(136, "twitch", "head")
idle.key(138, ease="INOUT", neck=(-12, -6, 18))
hold(idle, 142)
idle.key(143, ease="CONST", neck=(-18, 14, -12))
idle.marker(143, "twitch", "head")
idle.key(145, ease="INOUT", neck=(-12, -10, 20))
hold(idle, 149)
idle.key(150, ease="CONST", root=(-12, 16, 4), rs=(24, 0, 16), ls=(-24, 0, -6))
idle.marker(150, "twitch", "body")
idle.key(152, ease="CONST", root=(-8, 6, -10), rs=(6, 0, 4), ls=(-6, 0, -22))
idle.key(154, ease="INOUT", root=(-10, 10, -5), rs=(14, 0, 6), ls=(-12, 0, -14))
idle.key(163, neck=(-10, -14, 22))
idle.pose(172, doll(0.4))
idle.loop()
plant(idle, {85: 0.0})
idle.noise("neck", 2, 2.5, cycles=(1, 3, 4), seed=5, step=1)
idle.noise("neck", 1, 1.8, cycles=(2, 3, 7), seed=6, step=1)
idle.noise("root", 1, 1.2, cycles=(1, 2, 5), seed=7, step=1)
idle.noise("rs", 0, 2.0, cycles=(2, 3, 5), seed=8, step=1)
idle.noise("ls", 2, 1.5, cycles=(3, 5, 7), seed=9, step=1)
unsink(idle)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2

# R contact: heavy stomp
walk.key(0, ease="EXPO", root=(-14, 12, -7), root_pos=(0, -0.08, -0.03), neck=(-10, -16, 24),
         rs=(-18, 0, 12), ls=(-30, 0, -16), rh=(28, 0, 4), lh=(-24, 0, -4))
walk.marker(0, "stomp", "R")
walk.key(2, neck=(-22, -16, 32), root=(-16, 12, -8))  # head bounces after the impact
walk.key(h * 0.5, root=(-8, 8, -2), root_pos=(0, 0.08, 0), neck=(-10, -14, 22),
         rs=(4, 0, 9), ls=(-26, 0, -16), rh=(0, 0, 4), lh=(4, 0, -2))
# L contact: the dragged leg, lighter
walk.key(h, ease="OUT", root=(-9, 6, -2), root_pos=(0, -0.02, 0), neck=(-12, -18, 26),
         rs=(20, 0, 8), ls=(-38, 0, -18), rh=(-24, 0, 4), lh=(20, 0, -6))
walk.key(h + 1, ease="CONST", root=(-12, 20, -9), neck=(-4, -32, 42), ls=(-56, 20, -32))
walk.marker(h + 1, "glitch", "L")
walk.key(h + 3, ease="INOUT", root=(-10, 8, -3), neck=(-12, -16, 26), ls=(-34, 0, -18))
walk.key(h * 1.5, root=(-10, 10, -5), root_pos=(0, 0.06, 0), neck=(-12, -18, 24),
         rs=(4, 0, 7), ls=(-28, 0, -16), rh=(2, 0, 4), lh=(-2, 0, -3))
walk.loop()
plant(walk, {round(h * 0.5): 0.06, round(h * 1.5): 0.04})
unsink(walk)

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
wrench = A.clip("wrench", seconds=0.8, trigger="tear", mode="add", blend_in=0.02, blend_out=0.2)
wrench.pose(0, Z)
jerks = [
    dict(root=(8, 18, -8), neck=(12, -24, 30), rs=(-20, 0, 40), ls=(20, 0, -10)),
    dict(root=(-6, -12, 6), neck=(-10, 18, -20), rs=(10, 0, 10), ls=(-24, 0, -34)),
    dict(root=(5, 10, -4), neck=(8, -14, 18), rs=(-12, 0, 26), ls=(10, 0, -8)),
]
for i, p in enumerate(jerks):
    wrench.pose(1 + i * 2, p, ease="CONST")
wrench.marker(1, "wrench")
wrench.key(7, ease="INOUT", root=(2, 4, -2), neck=(4, -6, 8), rs=(-4, 0, 8), ls=(2, 0, -4))
wrench.pose(24, Z)

crash = A.clip("crash", seconds=0.7, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
crash.pose(0, Z)
crash.key(2, ease="EXPO", root=(-20, 4, -3), root_pos=(0, -0.34, -0.06), neck=(-16, 0, 10),
          rs=(-10, 0, 40), ls=(-10, 0, -40), rh=(18, 0, 14), lh=(18, 0, -14))
crash.marker(2, "stomp", "land")
crash.key(5, ease="BACK", neck=(4, -4, 14), root=(-16, 4, -2), root_pos=(0, -0.26, -0.05))
crash.key(11, root=(-6, 2, 0), root_pos=(0, -0.08, 0), neck=(-4, 0, 6), rs=(-2, 0, 12), ls=(-2, 0, -12),
          rh=(6, 0, 5), lh=(6, 0, -5))
crash.pose(21, Z)
plant(crash)

A.lift = 0
A.air = 0.25


# ------------------------------------------------------------------ key-pose sheet
def keysheet(clip, frames, views=("front", "side", "3/4")):
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
    keysheet(idle, [0, 12, 28, 44, 46, 60, 64, 70, 85, 92, 95, 118, 121, 136, 150])
