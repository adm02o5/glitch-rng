# Rootkit (1 in 12,500, Epic): "Lives below the surface."
# Concept: something that crawled up out of ring zero. A low predatory hunch, knuckles almost
# dragging, claws scratching at the floor; then it rears up, hauls both arms overhead and
# SLAMS them down - the purple roots erupt from the floor on that impact - and slowly drags
# them up out of the ground with palms-up, straining arms. Between the big beats the head
# twitches around in hard snaps like a process hiding from a scan.
# The tendril growth cycle of the VFX (4.5 s) now starts on the slam, so idle = 4.5 s.
#
# CLIPS
#   idle (4.5 s, 135 f, loop)
#     f0-8     hunch: torso pitched forward, staggered wide stance, arms hanging in front,
#              head craned up to keep the eyes forward; breathing heaves the back
#     f10/18   right claw rakes the floor twice (fast EXPO downstroke, slow recovery), the
#              torso dips with every rake and the head follows a frame late
#     f28/36   left claw rakes twice, weight shifts onto the left leg
#     f42-54   REAR UP: the torso unfolds backward, both arms haul up overhead (slow, heavy),
#              chin up, a held tremble at the top (anticipation)
#     f60      SLAM: arms whip down to the floor, torso pitches deep (IN ease into impact),
#              overshoot at f62, recoil and settle by f70
#     f76-100  PULL: palms up, both arms slowly heave forward-up as if dragging the roots out
#              of the ground, torso straining back (trembling wobble)
#     f104/110/116  three hard head snaps (CONST): left, right, back to centre - hiding
#     f120-135 sinks back into the hunch
#   walk (lib.STRIDE): low prowl - torso pitched forward, arms hanging and swinging long in
#     front of the body, heavy contact dips, shoulders roll with the stride, head kept level.
#   crouch (0.7 s, replace, trigger "land"): lands into a deep three-point crouch with the
#     right hand slapping the floor, then rises back.
#
# MARKERS (AurasMid A.Rootkit)
#   scratch "rhand" f10, f18 / "lhand" f28, f36   -> purple sparks rake out of that hand, the
#                                                    nearest floor cracks flash
#   slam   f60    the double-arm impact           -> floor shock ring, every crack flashes from
#                                                    the centre outward, disc flare, smoke
#                                                    burst, sparks from both hands, light surge,
#                                                    the tendrils (re)erupt from the floor
#   pull   f78    the heave begins                -> tendrils pulse bright while they climb,
#                                                    sparks stream up from both palms
#   twitch f104, f110, f116   head snaps          -> the kernel glyphs (root#, sudo -s,
#                                                    /dev/kmem) flash on, chest square burst
#   touch  crouch f5 (the hand hits the floor)    -> a small shock ring + cracks flash
#   (free) step "R"/"L" -> purple sparks kick up from that foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Rootkit")


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


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.5)  # 135 frames
K = idle.pose

# torso pitched forward 24 deg; hips +x compensate so the legs stand (staggered: left fwd)
HUNCH = dict(
    root=(-28, 6, 2), root_pos=(0, -0.4, 0.15), neck=(26, -6, 0),
    rs=(40, 0, 8), ls=(34, 0, -10), rh=(22, 0, 9), lh=(36, 0, -9),
)
K(0, HUNCH)
K(6, P(HUNCH, root=(-26, 6, 2), neck=(20, -4, 1), rs=(38, 0, 8), ls=(32, 0, -10)))
# --- right claw rakes twice: fast downstroke, slow recovery; head follows a frame late
for f in (10, 18):
    K(f - 3, P(HUNCH, root=(-24, 8, 3), rs=(62, 0, 14), neck=(24, -10, 2)), ease="EXPO")
    K(f, P(HUNCH, root=(-29, 10, 4), rs=(16, 0, 10), neck=(24, -10, 2)))
    K(f + 1, P(HUNCH, root=(-29, 10, 4), rs=(14, 0, 10), neck=(18, -14, 4)), ease="OUT")
    idle.marker(f, "scratch", "rhand")
K(23, P(HUNCH, root=(-25, 2, 0), neck=(22, 0, 0)))
# --- left claw rakes twice, weight onto the left leg
LW = P(HUNCH, root=(-24, -6, -3), root_pos=(-0.08, -0.4, 0.15), neck=(22, 6, -2))
for f in (28, 36):
    K(f - 3, P(LW, ls=(60, 0, -15), neck=(24, 10, -2)), ease="EXPO")
    K(f, P(LW, root=(-29, -9, -4), ls=(14, 0, -11), neck=(24, 10, -2)))
    K(f + 1, P(LW, root=(-29, -9, -4), ls=(12, 0, -11), neck=(18, 14, -4)), ease="OUT")
    idle.marker(f, "scratch", "lhand")
K(40, P(LW, root=(-26, -3, -1), neck=(22, 4, 0)))
# --- REAR UP: unfold backward, haul both arms overhead (heavy, slow), tremble at the top
REAR = dict(
    root=(8, 0, 0), root_pos=(0, 0.06, 0.05), neck=(16, 0, 0),
    rs=(160, 0, 26), ls=(160, 0, -26), rh=(4, 0, 8), lh=(6, 0, -8),
)
K(46, P(HUNCH, root=(-10, 0, 0), root_pos=(0, -0.2, 0.1), neck=(14, 0, 0),
        rs=(90, 0, 18), ls=(90, 0, -18), rh=(10, 0, 9), lh=(14, 0, -9)))
K(52, REAR, ease="LINEAR")
K(55, P(REAR, root=(10, 0, 0), rs=(168, 0, 24), ls=(168, 0, -24), neck=(20, 0, 0)), ease="IN")
# --- SLAM: arms whip down, torso pitches deep (accelerating into the impact)
SLAM = dict(
    root=(-40, 0, 0), root_pos=(0, -0.6, 0.25), neck=(34, 0, 0),
    rs=(64, 0, 16), ls=(64, 0, -16), rh=(30, 0, 18), lh=(38, 0, -18),
)
K(60, SLAM, ease="EXPO")
idle.marker(60, "slam")
K(62, P(SLAM, root=(-43, 0, 0), rs=(58, 0, 18), ls=(58, 0, -18), neck=(30, 0, 0)))
K(68, P(SLAM, root=(-37, 0, 0), neck=(36, 0, 0), rs=(56, 0, 14), ls=(56, 0, -14)))
# --- PULL: palms up, heave the roots out of the ground; torso straining back
K(76, P(SLAM, root=(-34, 0, 0), rs=(52, 0, 12), ls=(52, 0, -12), neck=(30, 0, 0)), ease="IN")
idle.marker(78, "pull")
PULL = dict(
    root=(-6, 0, 0), root_pos=(0, -0.15, 0.05), neck=(10, 0, 0),
    rs=(96, -6, 20), ls=(96, 6, -20), rh=(12, 0, 9), lh=(18, 0, -9),
)
K(98, PULL, ease="BACK")
K(102, P(PULL, root=(-9, 0, 0), rs=(90, -4, 20), ls=(90, 4, -20)))
# --- head snaps (CONST), the body flinches with each
TW = P(PULL, root=(-14, 0, 0), rs=(66, 0, 14), ls=(66, 0, -14), neck=(14, 0, 0))
K(103, TW, ease="CONST")
K(104, P(TW, neck=(16, 40, 10), root=(-14, 4, 1)), ease="CONST")
idle.marker(104, "twitch")
K(110, P(TW, neck=(12, -38, -12), root=(-15, -4, -1)), ease="CONST")
idle.marker(110, "twitch")
K(116, P(TW, neck=(22, 4, 0), root=(-16, 0, 0)), ease="CONST")
idle.marker(116, "twitch")
K(119, P(TW, neck=(22, 2, 0), root=(-17, 1, 0)))
# --- sink back into the hunch
K(128, P(HUNCH, root=(-25, 5, 1), neck=(21, -5, 0)))
idle.loop()
# breathing heaves the back, the hanging claws sway, the tremble of the strain
wobble(idle, "root", 0, 1.4, 3, 0.2)
wobble(idle, "root", 1, 0.015, 3, 0.2, loc=True)
wobble(idle, "rs", 0, 2.0, 5, 0.5)
wobble(idle, "ls", 0, 2.0, 5, 2.3)
wobble(idle, "neck", 1, 2.5, 2, 1.1)
wobble(idle, "rs", 2, 1.2, 9, 0.0)  # fine tremble (strain)
wobble(idle, "ls", 2, 1.2, 9, 1.6)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(s):
    # s = +1: right foot forward. Arms swing long in front of the body, opposite to the legs.
    return dict(
        root=(-30, -9 * s, -3 * s), root_pos=(0, -0.3, 0.12), neck=(28, 8 * s, 2 * s),
        rs=(32 - 28 * s, 0, 10), ls=(32 + 28 * s, 0, -10),
        rh=(30 + 26 * s, 0, 6), lh=(30 - 26 * s, 0, -6),
    )


def passing(s):
    return dict(
        root=(-26, 0, 3 * s), root_pos=(0, -0.05, 0.12), neck=(25, 0, -1 * s),
        rs=(34, 0, 12), ls=(34, 0, -12),
        rh=(26 - 3 * s, 0, 6), lh=(26 + 3 * s, 0, -6),
    )


walk.pose(0, contact(1), ease="OUT")
walk.pose(h * 0.5, passing(1))
walk.pose(h, contact(-1), ease="OUT")
walk.pose(h * 1.5, passing(-1))
walk.loop()
wobble(walk, "root", 1, 0.03, 2, 1.0, loc=True)  # heavy double-bob

# ------------------------------------------------------------------ crouch (on landing)
cr = A.clip("crouch", seconds=0.7, trigger="land", mode="replace", blend_in=0.03, blend_out=0.25)
cr.pose(0, P(HUNCH, root=(-18, 0, 0), rs=(20, 0, 10), ls=(20, 0, -10)), ease="IN")
TOUCH = dict(
    root=(-42, 6, 4), root_pos=(0, -0.7, 0.3), neck=(36, -6, 0),
    rs=(72, 0, 14), ls=(14, 0, -30), rh=(34, 0, 14), lh=(42, 0, -12),
)
cr.pose(5, TOUCH, ease="EXPO")
cr.marker(5, "touch")
cr.pose(8, P(TOUCH, root=(-44, 6, 4), neck=(32, -8, 0)))
cr.pose(21, P(HUNCH, root=(-24, 2, 1)))

plant(idle)
plant(walk)
plant(cr)
# the wobbles ride between the keys: a hair of extra clearance keeps every frame out of the floor
for clip in (idle,):
    for fc in clip._curves('pose.bones["root"].location'):
        if fc.array_index == 1:
            for kp in fc.keyframe_points:
                kp.co.y += 0.04
                kp.handle_left.y += 0.04
                kp.handle_right.y += 0.04
            fc.update()

A.lift = 0
A.finish()
