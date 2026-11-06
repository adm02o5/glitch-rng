# Zero Day (1 in 50,000, Epic): "No patch. No warning."
# Concept: the one who already knows when it hits. Cold, impatient, in control: it rolls its
# neck, taps its foot to the countdown, checks the "watch" on its left wrist and taps it, puts
# its hands on its hips and looks up at the big T- counter overhead... then crouches, gathers,
# and at ZERO detonates - arms flung up and out in a V, chest thrown open, head back - exactly
# when the red lightning hits. The VFX countdown (plates, floor ring, big T- label) now runs on
# the idle's 6 s cycle, so the digits reach 00.0 on the detonation frame.
#
# CLIPS
#   idle (6.0 s, 180 f, loop)
#     f0-20    aftermath: arms come down from the V, shoulders roll, weight settles
#     f22-34   neck roll: head tilts hard left, rolls over to the right (slow, heavy)
#     f40-62   impatient foot taps x3 (right foot, toes slap down on f44/f52/f60), the body
#              bounces slightly with each tap, arms hang loose
#     f66-74   left wrist comes up in front of the chest, head snaps down to read it (EXPO)
#     f80/86   right index taps the "watch" twice (small BACK jabs)
#     f96-112  hands on hips, weight to the left leg, a slow look up at the counter overhead
#     f118     head back to level; small exhale
#     f134-158 ANTICIPATION: sinks into a crouch, arms pulled in low and back, head down,
#              trembling (charge)
#     f168     ZERO: explodes upward - arms in a wide V, chest open, head back (EXPO),
#              overshoot on f171, shudders with the lightning until f178
#   walk (lib.STRIDE): brisk, purposeful power walk - slight forward lean, fists pumping
#     (strong forward/back arm swing), shoulders counter-rotating, head locked forward.
#   impact (0.75 s, replace, trigger "land"): lands in a one-knee-style crouch, the right fist
#     punches the floor, a beat, rises.
#
# MARKERS (AurasMid A.ZeroDay)
#   tap    f44, f52, f60   toe slaps        -> the floor countdown ring ticks: white flash
#                                              chasing round, sparks pop at the right foot
#   watch  f70             wrist raised      -> a small countdown glyph lights up on the left
#                                              wrist (follows the hand), plates flicker
#   tick   f80, f86        index taps        -> wrist glyph jumps / flashes, tiny spark
#   look   f104            looks up          -> the big T- label flares and swells
#   charge f140            the crouch        -> ambient arcs speed up / brighten, light builds,
#                                              smoke thickens (envelope until zero)
#   zero   f168            DETONATION        -> lightning (strike window starts here), spark
#                                              burst from both hands, floor ring white,
#                                              ZERO DAY label, light 6-10
#   slam   impact f4       fist on the floor -> ring flash + spark burst at the fist
#   (free) step -> spark kick at that foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("ZeroDay")


def wobble(clip, joint, axis, amp, cycles, phase=0.0, loc=False):
    """Additive periodic sine drift (F-curve GENERATOR modifier): keeps sharp keys intact."""
    path = f'pose.bones["{joint}"].' + ("location" if loc else "rotation_euler")
    for fc in clip._curves(path):
        if fc.array_index != axis:
            continue
        m = fc.modifiers.new("FNGENERATOR")
        m.function_type = "SIN"
        m.use_additive = True
        m.amplitude = amp if loc else math.radians(amp)
        m.phase_multiplier = 2 * math.pi * cycles / clip.frames
        m.phase_offset = phase
        fc.update()
        return
    raise ValueError(f"no keys on {path}[{axis}]")


def plant(clip, passes=3, extra=0.0):
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
    if extra:
        for fc in clip._curves('pose.bones["root"].location'):
            if fc.array_index == 1:
                for kp in fc.keyframe_points:
                    kp.co.y += extra
                    kp.handle_left.y += extra
                    kp.handle_right.y += extra
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
idle = A.clip("idle", seconds=6.0)  # 180 frames
K = idle.pose

STAND = dict(
    root=(0, -6, 1), root_pos=(0.04, 0, 0), neck=(-3, 4, 0),
    rs=(2, 0, 5), ls=(3, 0, -5), rh=(0, 0, 3), lh=(0, 0, -2),
)
V = dict(  # the detonation pose
    root=(12, 0, 0), root_pos=(0, 0.1, 0), neck=(30, 0, 0),
    rs=(-2, 0, 126), ls=(-2, 0, -126), rh=(-6, 0, 10), lh=(-6, 0, -10),
)
# aftermath: arms come down from the V (f180 = f0 is the tail of the detonation)
K(0, P(V, root=(6, 0, 0), root_pos=(0, 0.03, 0), neck=(16, 0, 0), rs=(10, 0, 100), ls=(10, 0, -100)))
K(10, P(STAND, rs=(4, 0, 22), ls=(4, 0, -22), neck=(4, 2, 0)), ease="OUT")
K(18, STAND)
# neck roll: tilt left, roll over to the right
K(24, P(STAND, neck=(-6, 6, 22), root=(0, -6, 3)), ease="INOUT")
K(29, P(STAND, neck=(-16, 0, 0)))
K(35, P(STAND, neck=(-4, -6, -22), root=(0, -6, -2)))
K(40, P(STAND, neck=(-2, 3, -2)), ease="BACK")
# impatient foot taps: right foot lifts its toes, slaps down (the leg swings a little forward)
TAP = P(STAND, root=(0, -8, 2), root_pos=(-0.08, 0, 0), lh=(0, 0, -2.5))
for f in (44, 52, 60):
    K(f - 4, P(TAP, rh=(14, 0, 5), root_pos=(-0.08, 0.04, 0), neck=(-2, 3, 0)), ease="OUT")
    K(f, P(TAP, rh=(5, 0, 4), neck=(-5, 3, 0)), ease="EXPO")
    idle.marker(f, "tap")
# wrist check: left forearm in front of the chest, head snaps down to read it
WATCH = P(STAND, root=(-2, 4, 0), ls=(80, -28, -6), rs=(8, 0, 8), neck=(-30, -8, 0))
K(66, P(STAND, ls=(40, -10, -8), neck=(-6, 0, 0)), ease="IN")
K(70, WATCH, ease="EXPO")
idle.marker(70, "watch")
idle.key(73, neck=(-32, -10, 3), ease="BACK")
# right index taps the watch twice
TAPW = P(WATCH, rs=(66, 32, -6), neck=(-32, -10, 3))
for f in (80, 86):
    K(f - 3, P(TAPW, rs=(72, 28, -2)), ease="OUT")
    K(f, TAPW, ease="EXPO")
    idle.marker(f, "tick")
K(90, P(WATCH, rs=(30, 10, 8), neck=(-24, -6, 0)))
# hands on hips, weight on the left leg, slow look up at the counter overhead
HIPS = dict(
    root=(1, 10, -2.5), root_pos=(-0.1, 0, 0), neck=(-2, -6, 2),
    rs=(-14, 0, 30), ls=(-14, 0, -30), rh=(0, 0, 4), lh=(0, 0, -1),
)
K(98, HIPS, ease="BACK")
K(104, P(HIPS, neck=(34, -4, -3), root=(4, 8, -2.5)))
idle.marker(104, "look")
K(114, P(HIPS, neck=(36, -2, -2), root=(4, 8, -2.5)))
K(122, P(HIPS, neck=(0, -4, 0), root=(-1, 6, -1)), ease="INOUT")
K(130, P(STAND, rs=(-6, 0, 12), ls=(-6, 0, -12)))
# anticipation: sink into a crouch, arms pulled in low and back, head down, trembling
CROUCH = dict(
    root=(-22, 0, 0), root_pos=(0, -0.45, 0.15), neck=(-12, 0, 0),
    rs=(-40, 0, 14), ls=(-40, 0, -14), rh=(30, 0, 9), lh=(30, 0, -9),
)
K(142, CROUCH, ease="INOUT")
idle.marker(140, "charge")
K(152, P(CROUCH, root=(-25, 0, 0), root_pos=(0, -0.52, 0.17), neck=(-16, 0, 0), rs=(-46, 0, 12),
         ls=(-46, 0, -12)))
K(162, P(CROUCH, root=(-27, 0, 0), root_pos=(0, -0.56, 0.18), neck=(-18, 0, 0), rs=(-50, 0, 10),
         ls=(-50, 0, -10)), ease="IN")
# ZERO
K(168, V, ease="EXPO")
idle.marker(168, "zero")
K(171, P(V, root=(15, 0, 0), neck=(36, 0, 0), rs=(-6, 0, 132), ls=(-6, 0, -132)))
K(174, P(V, root=(11, 3, 2), neck=(28, 4, 4)), ease="CONST")
K(176, P(V, root=(13, -3, -2), neck=(32, -4, -4)), ease="CONST")
idle.loop()
wobble(idle, "root", 0, 0.8, 4, 0.3)  # breathing
wobble(idle, "rs", 2, 2.0, 30, 0.0)  # fine tremble (shows in the crouch / V)
wobble(idle, "ls", 2, 2.0, 30, 1.5)
idle.noise("neck", 1, 1.5, cycles=(2, 3, 5), seed=11)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(s):
    return dict(
        root=(-8, -9 * s, -1.5 * s), root_pos=(0, -0.04, 0), neck=(4, 9 * s, 1 * s),
        rs=(-40 * s, 0, 7), ls=(40 * s, 0, -7),
        rh=(8 + 28 * s, 0, 2), lh=(8 - 28 * s, 0, -2),
    )


def passing(s):
    return dict(
        root=(-6, 0, 2 * s), root_pos=(0, 0.1, 0), neck=(2, 0, -1 * s),
        rs=(0, 0, 8), ls=(0, 0, -8),
        rh=(8 - 3 * s, 0, 2), lh=(8 + 3 * s, 0, -2),
    )


walk.pose(0, contact(1), ease="OUT")
walk.pose(h * 0.5, passing(1))
walk.pose(h, contact(-1), ease="OUT")
walk.pose(h * 1.5, passing(-1))
walk.loop()

# ------------------------------------------------------------------ impact (on landing)
im = A.clip("impact", seconds=0.75, trigger="land", mode="replace", blend_in=0.03, blend_out=0.25)
im.pose(0, P(CROUCH, root=(-12, 0, 0), rs=(90, 0, 20), ls=(-20, 0, -40)), ease="IN")
FIST = dict(
    root=(-40, 8, 4), root_pos=(0, -0.65, 0.28), neck=(30, -6, 0),
    rs=(74, 0, 12), ls=(-24, 0, -60), rh=(36, 0, 14), lh=(44, 0, -12),
)
im.pose(4, FIST, ease="EXPO")
im.marker(4, "slam")
im.pose(7, P(FIST, root=(-43, 8, 4), neck=(26, -8, -4)))
im.pose(13, P(FIST, root=(-38, 6, 3), neck=(34, 0, 0)))
im.pose(22, P(STAND, root=(-4, -4, 0), rs=(6, 0, 12), ls=(6, 0, -12)), ease="OUT")

plant(idle, extra=0.03)
plant(walk)
plant(im)

A.lift = 0
A.finish(preview=False)
A.preview(frames_per_clip=12)
keysheet(idle, [0, 24, 35, 56, 60, 70, 80, 98, 104, 152, 168, 171])
