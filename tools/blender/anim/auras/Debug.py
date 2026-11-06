# Debug (1 in 250, Enhanced): "Breakpoint hit."  look: red breakpoint dots and yellow step
# arrows tracing around the body (a helix of 24 code "lines").
# Concept: the player is the debugger. A slightly hunched dev who drives the execution
# arrows with the body: taps "step over" in the air, flicks "continue", freezes like a
# paused program when a breakpoint hits, leans in with a magnifier hand to inspect the
# variables, then gets the "aha!" and points up. Enhanced tier: subtle but full of character.
#
# CLIPS
#   idle (4.4 s, 132 f, loop)
#     f0-26    STEP OVER x3: the right hand floats forward at keyboard height and taps the air
#              (lift 2 f -> EXPO tap -> BACK recover); the head nods one frame later each time,
#              weight sits on the left leg, the left hand hangs loose
#     f28-44   CONTINUE: the hand pulls back (anticipation) and flicks forward; the eyes chase
#              the running arrow around the body (head sweeps right -> left -> right, torso
#              turns a little after it)
#     f46-50   BREAK: a CONST freeze-frame jolt - chest pops back, head snaps up, arms flare,
#              held motionless for 4 frames like a paused process
#     f52-96   INSPECT: leans in, hips forward to keep the feet planted, the right hand rises in
#              front of the face (magnifier), the left hand goes to the hip; then the head and
#              hand jump in held STEPS (EXPO move, hold) across three watched variables
#     f98-112  AHA: straightens up, the right index shoots up (BACK overshoot), chest lifts
#     f112-132 back to the keyboard with an overshoot, weight drifts back to the left leg
#   walk (lib.STRIDE): a careful, hunched "search" walk - short steps that hold for a beat
#     on each contact (step-over stutter), the magnifier hand swept low across the floor in
#     front, the head following it 2 frames late, the left arm swinging little.
#   startle (0.5 s, add, trigger "bphit"): when a step arrow hits a breakpoint on its own
#     (auto mode while walking) the VFX emits "bphit" -> head snaps up, chest twitches back.
#
# MARKERS (AurasExtra A.Debug)
#   stepover f8, f16, f24  air taps          -> both step arrows advance one line, a white
#                                              spark from THE RIGHT HAND, the line counter blips
#   run      f34           continue flick    -> the arrows race along the helix (fast steps,
#                                              trails flare) until "break"
#   break    f46           freeze jolt       -> arrow #1 lands on the next breakpoint: the
#                                              breakpoint swells, red hit burst, "BREAK @ line",
#                                              the light turns red, the floor ring stops
#   watch    f66, f78, f90 inspect holds     -> a watch value ("x = nil", ...) pops next to the
#                                              magnifier hand, the nearest dash lights up
#   fix      f100          aha point-up      -> breakpoint flashes white, sparks from the hand,
#                                              status "RESUMED", pause ends
#   (free) step -> one step-over per footfall while walking (+ a dash flash at that foot)
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Debug")


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


def plant(clip, passes=2):
    """Raise root-height keys just enough that the lowest sole touches the floor."""
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


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.4)  # 132 frames
K = idle.key


def legs(w, lean=0.0):
    # w -1..1 = weight on the left .. right leg; lean = torso forward lean the hips cancel
    return dict(root_pos=(0.07 * w, 0, 0), rh=(lean, 0, 2.5 - 1.5 * w), lh=(lean, 0, -2.5 - 1.5 * w))


HUNCH = 5  # dev posture: torso slightly forward, hips forward by the same amount
TYPE = (58, 0, -3)  # right hand at "keyboard" height
LOOSE = (6, 0, -6)

K(0, root=(-HUNCH, 2, 0), neck=(-8, 4, 1), rs=TYPE, ls=LOOSE, **legs(-0.8, HUNCH))


def tap(f, k):
    K(f - 2, ease="OUT", rs=(TYPE[0] + 7, TYPE[1], TYPE[2]))
    K(f, ease="EXPO", rs=(TYPE[0] - 9, TYPE[1], TYPE[2]), root=(-HUNCH - 1, 2 + k, 0))
    K(f + 1, ease="EXPO", neck=(-12, 4 + k * 2, 1))
    K(f + 4, ease="BACK", rs=TYPE, root=(-HUNCH, 2 + k, 0))
    K(f + 5, neck=(-8, 4 + k * 2, 1))
    idle.marker(f, "stepover")


tap(8, 0)
tap(16, 1)
tap(24, 2)
# CONTINUE: pull back, flick forward; the eyes chase the running arrow
K(30, ease="OUT", rs=(38, 0, 6), root=(-HUNCH + 2, 4, 0), ls=(2, 0, -8))
K(31, neck=(-6, 6, 0))
K(34, ease="EXPO", rs=(86, 0, -6), root=(-HUNCH - 3, 0, 0), ls=(10, 0, -9))
idle.marker(34, "run")
K(36, ease="OUT", neck=(-4, -24, -3))
K(38, root=(-HUNCH - 1, -8, 0), rs=(74, 0, 8))
K(40, neck=(0, 26, 4))
K(42, root=(-HUNCH, 7, 0))
K(43, neck=(-2, -12, -2))
K(45, root=(-HUNCH, -3, 0), rs=(70, 0, -2), **legs(-0.2, HUNCH))
K(45, ls=(8, 0, -8))
# BREAK: freeze-frame jolt (CONST in, CONST hold)
K(46, ease="CONST", root=(3, 0, 0), neck=(7, 0, 0), rs=(64, 0, 16), ls=(4, 0, -16),
  root_pos=(-0.014, 0.05, 0), rh=(0, 0, 2.8), lh=(0, 0, -2.2))
idle.marker(46, "break")
K(50, ease="EXPO", root=(3, 0, 0), neck=(7, 0, 0), rs=(64, 0, 16), ls=(4, 0, -16),
  root_pos=(-0.014, 0.05, 0), rh=(0, 0, 2.8), lh=(0, 0, -2.2))
# INSPECT: lean in, magnifier hand to the eye, other hand on the hip
LEAN = 13
K(56, ease="INOUT", root=(-LEAN, -4, 0), root_pos=(0.05, 0, 0), rh=(LEAN, 0, 1.5), lh=(LEAN, 0, -4.5),
  rs=(118, 0, -16), ls=(-14, 0, -30))
K(58, ease="OUT", neck=(-14, -10, -3))


def watch(f, look, mark=True):
    # jump the head + magnifier to a new variable (EXPO move), then hold
    K(f - 3, root=(-LEAN, look * 0.3, 0), rs=(118, 0, -16 - look * 0.6), neck=(-14, look * 0.6, -3))
    K(f, ease="EXPO", root=(-LEAN - 1, look * 0.45, 0), rs=(122, 0, -17 - look * 0.85), neck=(-16, look, -4))
    K(f + 7, root=(-LEAN - 1, look * 0.45, 0), rs=(121, 0, -17 - look * 0.85), neck=(-15, look * 1.04, -4))
    if mark:
        idle.marker(f, "watch")


watch(66, -16)
watch(78, 4)
watch(90, 20)
# AHA: straighten up, point up
K(97, ease="IN", root=(-6, 4, 0), rs=(108, 0, -12), neck=(-10, 12, 0),
  rh=(6, 0, 1.5), lh=(6, 0, -4.5), root_pos=(0.04, 0, 0))
K(100, ease="BACK", root=(4, 0, -1), rs=(168, 0, 6), ls=(-4, 0, -14), neck=(9, 0, -3),
  rh=(0, 0, 2.5), lh=(0, 0, -3.5), root_pos=(0.04, 0.05, 0))
idle.marker(100, "fix")
K(102, ease="BACK", neck=(12, -4, -6))
K(108, root=(3, 0, -0.5), rs=(160, 0, 8), neck=(8, -3, -4), root_pos=(0.04, 0.03, 0))
# back to the keyboard
K(114, ease="OUT", rs=(48, 0, 2), root=(-HUNCH - 1, 1, 0), ls=(4, 0, -8), root_pos=(-0.02, 0, 0),
  rh=(HUNCH, 0, 3.0), lh=(HUNCH, 0, -2.0))
K(117, ease="BACK", neck=(-10, 3, 1))
K(120, rs=(62, 0, -2))
K(126, rs=TYPE, root=(-HUNCH, 2, 0), **legs(-0.8, HUNCH))
idle.loop()
idle.noise("neck", 1, 1.2, cycles=(2, 3, 5), seed=21)
idle.noise("rs", 1, 1.5, cycles=(3, 5, 7), seed=22)  # restless hand
idle.noise("root", 2, 0.6, cycles=(1, 2, 3), seed=23)  # breathing sway

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(f, s):
    # s = +1: right foot forward. The magnifier sweeps toward the side of the forward foot.
    pose = dict(root=(-8, -5 * s, -1.5 * s), root_pos=(0, 0, 0),
                rs=(48, 0, -6 + 18 * s), ls=(16 * s, 0, -7),
                rh=(8 + 20 * s, 0, 2), lh=(8 - 20 * s, 0, -2))
    walk.key(f, ease="OUT", **pose)
    walk.key(f + 2, ease="LINEAR", **pose)  # step-over hold
    walk.key(f + 2, ease="OUT", neck=(-14, -16 * s, -2 * s))


def passing(f, s):
    walk.key(f, root=(-9, 0, 1.2 * s), root_pos=(0, 0.06, 0),
             rs=(46, 0, -6), ls=(0, 0, -6),
             rh=(8 - 3 * s, 0, 2), lh=(8 + 3 * s, 0, -2))
    walk.key(f + 1.5, neck=(-15, 0, 0))


contact(0, 1)
passing(h * 0.5 + 1, 1)
contact(h, -1)
passing(h * 1.5 + 1, -1)
walk.loop()

# ------------------------------------------------------------------ startle (VFX -> body)
st = A.clip("startle", seconds=0.5, trigger="bphit", mode="add", blend_in=0.03, blend_out=0.15)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
st.pose(0, Z)
st.pose(2, P(Z, neck=(12, 0, 0), root=(4, 0, 0), rs=(-6, 0, 8), ls=(0, 0, -8)), ease="CONST")
st.pose(5, P(Z, neck=(11, 0, 0), root=(4, 0, 0), rs=(-6, 0, 8), ls=(0, 0, -8)), ease="EXPO")
st.pose(15, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
