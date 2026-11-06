# Botnet (1 in 6,500, Rare): "Ten thousand machines say hi."
# Concept: the bot-herder who has become one of its own machines. The body moves like a
# servo rig - holds dead still, then SNAPS between angles (CONST keys) with a 2-frame
# servo overshoot, buzzes while it holds a command, and greets you with a stiff mechanical
# wave that the whole drone swarm copies.
#
# CLIPS
#   idle (4.0 s, 120 f, loop)
#     f0-28    stiff stance; the head scans in three servo snaps (left, right, centre), the
#              torso follows each snap two frames late with a smaller angle
#     f32-38   anticipation: knees "dip" (body drops), torso leans in, right arm cocks back
#     f42      COMMAND: right arm shoots straight up (BACK overshoot), chest back, head looks
#              up at the hand two frames later; the arm buzzes in CONST micro-jitters f44-54
#     f58-64   the arm swings out to the side, head turns to the viewer
#     f68-84   "HI": a robotic wave - the raised arm snaps between two angles 3x (CONST),
#              head tilts the other way on every snap, body bobs
#     f88-94   the arm drops back to the side with a servo overshoot
#     f100-114 two last head scans, then back into the loop
#   walk (lib.STRIDE): stop-motion march - 8 CONST poses per stride (the body is sampled at
#     ~11 fps), straight stiff legs and arms swinging in exact opposition, upright torso,
#     head locked forward with a quantized counter-turn.
#   reboot (0.8 s, add, trigger "jump"): on take-off the body glitches through three servo
#     offsets and resets (the swarm "drops the connection").
#
# MARKERS (AurasMid A.Botnet)
#   tick  f8, f18, f28, f100, f108   head servo snap  -> every drone eye blinks ON in unison,
#                                                         rotors flash white, square puff at the head
#   cmd   f42   arm points to the sky                -> drones break orbit and lock into a tight
#                                                         halo around the RIGHT HAND (they ride the
#                                                         hand through the wave), command cube +
#                                                         light surge, spark burst from the hand
#   wave  f68, f76, f84   each wave snap              -> the halo drones hop in a ripple, the floor
#                                                         ring pulses, square puff from the hand
#   drop  f88   the arm drops                         -> the drones release back into their orbit
#   reboot reboot f2 (on take-off)              -> the drones scatter outward and every eye
#                                                         goes dark for a beat, then reconnects
#   (free) step "R"/"L" -> a square puff and a laser spot snap under that foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Botnet")


def wobble(clip, joint, axis, amp, cycles, phase=0.0, loc=False):
    """Additive periodic sine drift (F-curve GENERATOR modifier): keeps CONST snaps intact."""
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


def plant(clip, passes=2):
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


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


def add(a, b, k=1.0):
    return tuple(x + y * k for x, y in zip(a, b))


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.0)  # 120 frames
K = idle.pose

BASE = dict(
    root=(0, 0, 0), root_pos=(0, 0, 0), neck=(-2, 0, 0),
    rs=(2, 0, 4), ls=(2, 0, -4), rh=(0, 0, 2), lh=(0, 0, -2),
)


def servo(f, pose, over, hold=2):
    """Snap to `pose` at frame f with a CONST servo overshoot (`over` = per-joint deltas)."""
    o = dict(pose)
    for j, d in over.items():
        o[j] = add(pose[j], d)
    K(f, o, ease="CONST")
    K(f + hold, pose, ease="CONST")


# --- three head scans; the torso follows each snap two frames late, smaller
K(0, BASE, ease="CONST")
SCAN_L = P(BASE, neck=(-2, 26, 0))
servo(8, SCAN_L, {"neck": (0, 5, 0)})
K(10, P(SCAN_L, root=(0, 6, 0), rs=(4, 0, 4), ls=(0, 0, -4)), ease="CONST")
idle.marker(8, "tick")
SCAN_R = P(BASE, neck=(-6, -24, 0), root=(0, 6, 0))
servo(18, SCAN_R, {"neck": (0, -5, 0)})
K(20, P(SCAN_R, root=(0, -5, 0), root_pos=(0.04, 0, 0), rh=(0, 0, 3), lh=(0, 0, -1), rs=(0, 0, 4), ls=(4, 0, -4)), ease="CONST")
idle.marker(18, "tick")
SCAN_C = P(BASE, neck=(-3, 0, 0), root=(0, -5, 0), root_pos=(0.04, 0, 0))
servo(28, SCAN_C, {"neck": (-3, 3, 0)})
K(30, P(SCAN_C, root=(0, 0, 0), root_pos=(0, 0, 0)))
idle.marker(28, "tick")
# --- anticipation: dip, lean in, right arm cocks back (smooth, mechanical ease)
ANT = P(BASE, root=(-6, 4, 1), root_pos=(0, -0.08, 0.04), neck=(-8, -4, 0),
        rs=(-24, 0, 10), ls=(8, 0, -6), rh=(5, 0, 3), lh=(5, 0, -3))
K(33, P(BASE, neck=(-4, 0, 0)), ease="EXPO")
K(38, ANT, ease="BACK")
# --- COMMAND: arm straight up, chest back, head follows two frames later
CMD = P(BASE, root=(5, 7, -2), root_pos=(0, 0.03, 0), neck=(6, 4, 0),
        rs=(172, 0, 6), ls=(-10, 0, -12), rh=(-2, 0, 3), lh=(-2, 0, -3))
K(42, CMD, ease="CONST")
idle.marker(42, "cmd")
K(44, P(CMD, neck=(20, 8, -3)), ease="CONST")
# buzz while holding the command (CONST micro-jitters)
for i, f in enumerate((46, 48, 50, 52, 54)):
    s = 1 if i % 2 == 0 else -1
    K(f, P(CMD, neck=(20 + 1.5 * s, 8, -3 + 2 * s), rs=(172 + 3 * s, 0, 6 - 2 * s),
           root=(5, 7 + 1.2 * s, -2), ls=(-10 - 2 * s, 0, -12)), ease="CONST")
K(56, P(CMD, neck=(19, 8, -3)), ease="EXPO")
# --- the arm swings out to the side, head turns to the viewer
SIDE = P(BASE, root=(1, -6, 2), root_pos=(-0.04, 0, 0), neck=(-2, 4, 6),
         rs=(4, 0, 140), ls=(4, 0, -8), rh=(0, 0, 1), lh=(0, 0, -3))
K(64, SIDE, ease="CONST")
# --- HI: robotic wave, the swarm copies it
for k, f in enumerate((68, 72, 76, 80, 84)):
    up = k % 2 == 0
    pose = P(SIDE, rs=(4, 0, 170 if up else 138),
             neck=(-2, 4, -7 if up else 7),
             root=(1, -6, 3 if up else 1),
             root_pos=(-0.04, 0.035 if up else 0, 0))
    servo(f, pose, {"rs": (0, 0, 7 if up else -7)})
    if up:
        idle.marker(f, "wave")
K(87, P(SIDE, rs=(4, 0, 160), neck=(-2, 2, -4)), ease="BACK")
# --- the arm drops with a servo overshoot (BACK), body settles
DROP = P(BASE, root=(0, -2, 0), neck=(-3, 2, 0), rs=(-4, 0, 3))
K(93, DROP, ease="BACK")
idle.marker(88, "drop")
K(97, P(BASE, rs=(3, 0, 4)), ease="CONST")
# --- two last scans, then home
SCAN2 = P(BASE, neck=(-8, -16, 0))
servo(100, SCAN2, {"neck": (0, -4, 0)})
K(102, P(SCAN2, root=(0, -4, 0)), ease="CONST")
idle.marker(100, "tick")
SCAN3 = P(BASE, neck=(0, 12, 0), root=(0, -4, 0))
servo(108, SCAN3, {"neck": (2, 4, 0)})
K(110, P(SCAN3, root=(0, 2, 0)), ease="CONST")
idle.marker(108, "tick")
K(114, P(BASE, neck=(-2, 3, 0)), ease="EXPO")
idle.loop()
# fans and servos never stop: tiny mechanical hum on the torso, slow breathing of the chassis
wobble(idle, "root", 2, 0.5, 6, 0.4)
wobble(idle, "root", 1, 0.008, 4, 0.0, loc=True)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames


def march(u):
    """u 0..1 over the stride -> pose (sampled into CONST keys = stop-motion)."""
    c = math.cos(2 * math.pi * u)  # +1 at right contact, -1 at left contact
    lift = abs(math.sin(2 * math.pi * u))  # passing poses rise
    q = lambda x, step: round(x / step) * step  # noqa: E731  servo quantization
    fw = lambda x, a, b: x * (a if x > 0 else b)  # noqa: E731  forward swing > back swing
    return dict(
        root=(2 + 2 * abs(c), q(-5 * c, 2.5), 0), root_pos=(0, 0.1 * lift, 0),
        neck=(-4, q(5 * c, 2.5), 0),
        rs=(fw(-c, 34, 20), 0, 5), ls=(fw(c, 34, 20), 0, -5),
        rh=(fw(c, 32, 20), 0, 2), lh=(fw(-c, 32, 20), 0, -2),
    )


STEPS = 8
for i in range(STEPS):
    walk.pose(i * n / STEPS, march(i / STEPS), ease="CONST")
walk.loop()

# ------------------------------------------------------------------ reboot (additive, on take-off)
reb = A.clip("reboot", seconds=0.8, trigger="jump", mode="add", blend_in=0.02, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
reb.pose(0, Z, ease="CONST")
reb.pose(2, P(Z, root=(0, 10, 3), neck=(8, -20, 6), rs=(20, 0, 10), ls=(-15, 0, -6)), ease="CONST")
reb.pose(5, P(Z, root=(0, -8, -3), neck=(-6, 18, -6), rs=(-12, 0, 4), ls=(22, 0, -12)), ease="CONST")
reb.pose(8, P(Z, root=(0, 4, 0), neck=(4, -8, 0), rs=(6, 0, 18), ls=(6, 0, -18)), ease="CONST")
reb.pose(12, Z)
reb.marker(2, "reboot")

plant(idle)
plant(walk)

A.lift = 0
A.finish()
