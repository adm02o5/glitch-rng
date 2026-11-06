# Glitch (1 in 1,000, Rare): "The signature of the game. Reality tears."
# Concept: a cool, slouched hacker whose body keeps DESYNCING - the animation drops frames,
# snaps to wrong poses for 2-3 frames (CONST keys), rewinds and catches up with an EXPO pop,
# exactly like a corrupted video stream. Between the glitches the motion is relaxed and
# organic (weight shifts, breathing, sine drift that does not smear the snaps).
#
# CLIPS
#   idle  (4.0 s, 120 f, loop)  slouch on the right leg -> head-snap glitch -> weight shift to
#         the left leg -> body "teleport" (double snap sideways) -> anticipation crunch -> the
#         big TEAR (body flips between two broken poses 4x, freezes, recovers with overshoot)
#         -> "reboot" slump (head drops, arms go limp) -> head pops back up -> hand flick.
#   walk  (lib.STRIDE)          loose hunched stride; mid second half the gait FREEZES for two
#         frames (a dropped packet), then skips ahead to catch up the left contact.
#   glitchland (0.5 s, add, trigger "land")  landing from a jump makes the whole body jolt
#         between three corrupted offsets before settling.
#
# MARKERS (AurasMid A.Glitch)
#   snap "head"   f20   head jerks sideways  -> RGB-split burst + error glyphs flash at the head
#   snap "body"   f54   torso teleports      -> RGB-split burst + ghosts jump + floor tiles reshuffle
#   tear          f76   the big tear         -> long burst: all scanline tears + dead pixels + white
#                                               light + a big pixel explosion + floor tiles flash
#   slump         f94   power drains        -> the light and the ghosts dim, pixels stop
#   reboot        f106  head pops back up    -> the light (dimmed during the slump) flashes back on,
#                                               halo glyph shows "BOOT"
#   snap "rhand"  f110  right hand flick     -> pixel spray from the right hand
#   skip          walk f7  dropped frames    -> short burst while walking
#   crash         glitchland f1              -> burst + tiles (also the free "land" event)
#   (free events) step "R"/"L" -> a corrupted floor tile flashes under that foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Glitch")


def wobble(clip, joint, axis, amp, cycles, phase=0.0, loc=False):
    """Additive periodic sine drift as a Blender F-curve GENERATOR modifier: unlike
    clip.noise() it keeps CONST snap keys intact (no resampling). Whole cycles per clip."""
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
    """Floor contact: at every root-height key, raise the body just enough that the lowest
    sole touches the floor (R6 has no knees, so splayed / turned legs would dig in).
    Never lowers a key, so deliberate hops survive."""
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
idle = A.clip("idle", seconds=4.0)  # 120 frames

REST_R = dict(  # weight on the right leg, slouched, hips turned a little
    root=(-2, 6, -2), root_pos=(0.08, -0.02, 0), neck=(-5, -8, 3),
    rs=(4, 0, 5), ls=(8, 0, -7), rh=(0, 0, 2), lh=(3, 4, -5),
)
REST_L = dict(  # weight on the left leg
    root=(-2, -4, 2), root_pos=(-0.08, -0.02, 0), neck=(-4, 6, -2),
    rs=(7, 0, 7), ls=(4, 0, -5), rh=(3, -4, 5), lh=(0, 0, -2),
)
TEAR_A = dict(  # broken pose 1: arm flung up, head thrown back
    root=(8, 22, -10), root_pos=(0.3, 0.1, 0), neck=(18, -30, 16),
    rs=(60, 0, 70), ls=(-35, 0, -50), rh=(-6, 0, 10), lh=(14, 0, -6),
)
TEAR_B = dict(  # broken pose 2 ("rewind"): mirrored, the other arm
    root=(-6, -16, 8), root_pos=(-0.25, 0.04, 0), neck=(-10, 24, -14),
    rs=(-20, 0, 30), ls=(50, 0, -65), rh=(10, 0, 4), lh=(-8, 0, -8),
)
TEAR_C = dict(  # freeze frame between the two
    root=(2, 4, -2), root_pos=(0.1, 0.05, 0), neck=(6, -8, 4),
    rs=(30, 0, 40), ls=(10, 0, -30), rh=(2, 0, 4), lh=(4, 0, -4),
)
SLUMP = P(REST_R, root=(-11, 3, -2), root_pos=(0.06, -0.04, 0), neck=(-32, -4, 9),
          rs=(8, 0, 1), ls=(7, 0, -1), rh=(6, 0, 2), lh=(8, 4, -4))

K = idle.pose
K(0, REST_R)
K(10, P(REST_R, root=(-0.5, 6, -2), root_pos=(0.08, 0.0, 0), rs=(5, 0, 6), ls=(9, 0, -8)))  # breathe in
K(17, P(REST_R, neck=(-9, -4, 1), rs=(2, 0, 4)), ease="CONST")  # anticipation: eyes down
# --- snap 1: head jerks left, right shoulder hitches (2 broken frames, then held, EXPO out)
K(20, P(REST_R, root=(-2, 9, -3.5), root_pos=(0.14, -0.02, 0), neck=(4, 32, -14), rs=(22, 0, 14)), ease="CONST")
K(22, P(REST_R, root=(-2, 7, -1), root_pos=(0.1, -0.02, 0), neck=(2, 26, 8), rs=(14, 0, 10)), ease="CONST")
K(23, P(REST_R, root=(-2, 9, -3.5), root_pos=(0.14, -0.02, 0), neck=(3, 30, -12), rs=(20, 0, 13)), ease="EXPO")
K(30, P(REST_R, neck=(-6, -12, 4), rs=(2, 0, 4)))  # overshoot past rest
K(36, REST_R)
idle.marker(20, "snap", "head")
# --- weight shift to the left leg (body rises a touch while passing over the centre)
K(43, P(REST_L, root=(-1, 1, 0), root_pos=(0, 0.0, 0), neck=(-4, -1, 0)))
K(50, REST_L, ease="CONST")
# --- snap 2: the body teleports sideways twice (dropped frame between)
BODY1 = P(REST_L, root=(-4, -18, 7), root_pos=(-0.35, 0, 0.1), neck=(0, 14, -10),
          rs=(10, 0, 20), ls=(-12, 0, -18), rh=(6, 0, 6), lh=(-4, 0, -8))
BODY2 = P(BODY1, root=(-3, -24, 9), root_pos=(-0.45, 0, 0.12), neck=(2, 20, -12))
K(54, BODY1, ease="CONST")
K(56, REST_L, ease="CONST")
K(57, BODY2, ease="CONST")
K(59, BODY2, ease="EXPO")
K(64, P(REST_L, root=(-2, 2, 0), neck=(-4, -4, 1)))  # overshoot back
K(69, REST_L, ease="IN")
idle.marker(54, "snap", "body")
# --- anticipation crunch before the tear
K(74, P(REST_L, root=(-10, 0, 0), root_pos=(0, -0.05, 0), neck=(-14, 0, 0),
        rs=(-10, 0, 18), ls=(-10, 0, -18), rh=(8, 0, 3), lh=(8, 0, -3)), ease="CONST")
# --- the TEAR: flips between two broken poses, freezes, recovers
K(76, TEAR_A, ease="CONST")
K(78, TEAR_B, ease="CONST")
K(80, TEAR_A, ease="CONST")
K(81, TEAR_B, ease="CONST")
K(82, TEAR_C, ease="CONST")
K(86, TEAR_C, ease="EXPO")
K(92, P(REST_R, root=(-3, 4, -1), root_pos=(0.06, -0.04, 0), neck=(-8, -6, 2), rs=(2, 0, 3), ls=(3, 0, -4)), ease="IN")
idle.marker(76, "tear")
# --- reboot: slump, hang, pop back
idle.marker(94, "slump")
K(100, SLUMP)
K(104, P(SLUMP, neck=(-35, -5, 10), root_pos=(0.06, -0.045, 0)), ease="BACK")
K(107, P(REST_R, root=(1, 5, -2), root_pos=(0.08, 0.0, 0), neck=(4, -10, 2), rs=(6, 0, 8), ls=(8, 0, -9)), ease="CONST")
idle.marker(106, "reboot")
# --- hand flick: right hand snaps forward, eyes follow it
K(110, P(REST_R, root=(-1, 8, -2), neck=(-10, -14, 0), rs=(38, 6, 12), ls=(8, 0, -9)), ease="CONST")
K(112, P(REST_R, root=(-1, 8, -2), neck=(-9, -13, 0), rs=(34, 4, 10), ls=(8, 0, -9)), ease="EXPO")
idle.marker(110, "snap", "rhand")
idle.loop()
# organic drift that keeps every snap crisp (generator modifiers, whole cycles per loop)
wobble(idle, "root", 1, 1.4, 2, 0.3)
wobble(idle, "root", 0, 0.8, 3, 1.1)
wobble(idle, "neck", 1, 2.0, 3, 2.0)
wobble(idle, "neck", 0, 1.2, 4, 0.5)
wobble(idle, "rs", 2, 1.2, 3, 0.9)
wobble(idle, "ls", 2, 1.2, 2, 2.4)
wobble(idle, "root", 1, 0.012, 5, 0.0, loc=True)  # breathing

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # ~21 frames
h = walk.frames / 2


def contact(s):
    # s = +1: right foot forward
    return dict(
        root=(-7, -8 * s, -2 * s), root_pos=(0, 0, 0), neck=(-2, 7 * s, 1.5 * s),
        rs=(-28 * s, 0, 8), ls=(24 * s, 0, -9),  # left arm swings a bit less (asymmetry)
        rh=(26 * s, 0, 2), lh=(-24 * s, 0, -2),
    )


def passing(s):
    # s = +1: the right leg carries the weight
    return dict(
        root=(-5, 0, 2 * s), root_pos=(0, 0.14, 0), neck=(-4, 0, -1 * s),
        rs=(-4 * s, 0, 6), ls=(4 * s, 0, -7),
        rh=(-3 * s, 0, 2), lh=(3 * s, 0, -2),
    )


def mix(a, b, f):
    out = {}
    for k in a:
        out[k] = tuple(x + (y - x) * f for x, y in zip(a[k], b[k]))
    return out


W = walk.pose
W(0, contact(1), ease="EXPO")
W(h * 0.25, P(contact(1), root_pos=(0, 0.0, 0), root=(-8, -6, -1.5)))  # settle into the step
W(h * 0.5, passing(1))
W(h * 1.5, passing(-1))
W(h, contact(-1), ease="EXPO")
# the dropped packet: frames 7-8 freeze on a corrupted mid-pose, then skip ahead
frz = mix(passing(1), contact(-1), 0.35)
frz = P(frz, neck=(6, -18, 10), root_pos=(0.12, 0.06, 0), rs=(frz["rs"][0], 0, 18))
W(7, frz, ease="CONST")
W(9, mix(passing(1), contact(-1), 0.8), ease="EXPO")
walk.marker(7, "skip")
walk.loop()
wobble(walk, "neck", 1, 2.5, 1, 0.7)

# ------------------------------------------------------------------ landing glitch (additive)
land = A.clip("glitchland", seconds=0.5, trigger="land", mode="add", blend_in=0.02, blend_out=0.12)
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
L = land.pose
L(0, Z, ease="CONST")
L(1, dict(root=(-8, 10, 6), root_pos=(0.2, 0.12, 0), neck=(-15, -20, 10), rs=(25, 0, 20), ls=(-15, 0, -20)), ease="CONST")
L(3, dict(root=(4, -8, -4), root_pos=(-0.15, 0.1, 0), neck=(8, 15, -8), rs=(-10, 0, 8), ls=(20, 0, -25)), ease="CONST")
L(5, dict(root=(-3, 4, 2), root_pos=(0.06, 0.05, 0), neck=(-5, -8, 4), rs=(8, 0, 6), ls=(-5, 0, -6)), ease="CONST")
L(6, dict(root=(-3, 4, 2), root_pos=(0.06, 0.05, 0), neck=(-5, -8, 4), rs=(8, 0, 6), ls=(-5, 0, -6)), ease="EXPO")
L(12, Z)
L(15, Z)
land.marker(1, "crash")

plant(idle)
plant(walk)

A.lift = 0
A.finish()
