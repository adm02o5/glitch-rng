# Cryptic (1 in 8,888, Rare): "Encrypted with a key no one has."
# Concept: a cipher-cracker / safecracker. Both hands weave slow circles in front of the chest
# (spinning the cipher), then the right hand reaches for an invisible dial and turns it click
# by click, ear cocked to listen; the body coils, throws both arms open - DECRYPT! - for a
# moment the phrase reads in clear text... and then the hands slam shut together: re-LOCKED.
# The VFX cycle (scramble -> decrypt -> lock) is now driven by this clip instead of t % 4.
#
# CLIPS
#   idle (4.0 s, 120 f, loop)
#     f0-30    weave: one slow circle of both hands in front of the chest (the right hand
#              leads, the left follows half a turn behind), eyes on the hands, torso sways
#     f34-40   the right hand reaches forward to the "dial", the left pulls back to the chest,
#              the head cocks sideways to listen (lags the hand by 3 frames)
#     f44/52/60 three dial clicks: a sharp EXPO flick of the wrist outward, the head nods on
#              each click one frame later
#     f66-86   tension: leaning in, then a coil - both hands pulled to the chest, body sinks
#     f90      UNLOCK: both arms thrown open forward-up (BACK overshoot), chest opens, chin up
#     f96-108  floating in the reveal, arms drifting wider
#     f112     LOCK: the hands slam together in front of the chest (accelerating IN), the head
#              snaps down; recoil and back into the weave
#   walk (lib.STRIDE): scholarly glide - the hands stay up in front of the chest still weaving
#     a little circle per step, the torso barely bobs, legs swing smoothly from the hip.
#   jolt (0.6 s, add, trigger "land"): the cipher "slips" on landing - the hands jerk apart and
#     re-centre, head shakes.
#
# MARKERS (AurasMid A.Cryptic)
#   turn  f44, f52, f60   dial click   -> the golden key turns one notch (eased), both glyph rings
#                                         jump a notch, the floor wheel rescrambles, gold spark
#                                         puff from the right hand
#   unlock f90            arms open   -> decryption starts: the ring glyphs resolve into
#                                         ENCRYPTED!! / XOR-AES-256 one by one, label [ACCESS?],
#                                         light surge, spark burst from both hands, rings spin up
#   lock  f112            hands clap  -> instant re-scramble, [LOCKED] flashes white, the rings
#                                         shudder (radius kick), spark burst between the hands
#   slip  jolt f1 (on landing)        -> scramble burst + ring shudder
#   (free) step "R"/"L" -> gold cipher squares puff from that foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Cryptic")


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
idle = A.clip("idle", seconds=4.0)  # 120 frames
K = idle.pose

STAND = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(-14, 0, 0),
             rh=(0, 0, 2), lh=(0, 0, -2))


def weave(a, sway=1.0):
    """Both hands on a circle in front of the chest; a = angle of the right hand (deg).
    The left hand runs half a turn behind. The head and torso follow the right hand."""
    r = math.radians(a)
    l = r + math.pi
    return P(STAND,
             root=(0, 4 * math.cos(r) * sway, 1.5 * math.sin(r) * sway),
             root_pos=(0.04 * math.sin(r) * sway, 0, 0),
             neck=(-15 + 3 * math.sin(r), 6 * math.cos(r - 0.6), 2 * math.sin(r)),
             rs=(50 + 12 * math.sin(r), 30 + 8 * math.cos(r), 4),
             ls=(50 + 12 * math.sin(l), -30 - 8 * math.cos(l), -4),
             rh=(0, 0, 2 + 1.2 * math.sin(r)), lh=(0, 0, -2 + 1.2 * math.sin(r)))


# one slow circle (keys every 7.5 f, smooth)
for i, f in enumerate((0, 8, 15, 23, 30)):
    K(f, weave(90 * i))
# reach to the dial, the head listens 3 frames later
DIAL = P(STAND, root=(-5, 9, -1), root_pos=(0.06, -0.02, -0.04), neck=(-8, -6, 4),
         rs=(80, 26, 2), ls=(44, -18, -8), rh=(3, 0, 3), lh=(4, 0, -1))
K(37, P(DIAL, neck=(-14, 2, 0)), ease="BACK")
K(40, DIAL)
# three clicks: flick outward (EXPO), the head nods a frame later
for k, f in enumerate((44, 52, 60)):
    z = 2 + 9 * (k + 1)
    base = P(DIAL, rs=(80, 26, z - 9), neck=(-8, -6 - 2 * k, 6 + 2 * k), root=(-5 - k, 9, -1))
    K(f - 2, base, ease="EXPO")
    K(f, P(base, rs=(82, 26, z), root=(-6 - k, 10, -1.5)))
    K(f + 1, P(base, rs=(82, 26, z), neck=(-12, -6 - 2 * k, 9 + 2 * k), root=(-6 - k, 10, -1.5)), ease="OUT")
    idle.marker(f, "turn")
# tension: lean in and listen
K(68, P(DIAL, rs=(82, 26, 28), root=(-9, 11, -2), root_pos=(0.06, -0.04, -0.08), neck=(-10, -12, 14)))
# coil: hands pulled to the chest, sink
COIL = P(STAND, root=(5, 0, 0), root_pos=(0, -0.08, 0.05), neck=(-20, 0, 0),
         rs=(34, 30, 12), ls=(34, -30, -12), rh=(4, 0, 3), lh=(4, 0, -3))
K(78, COIL, ease="IN")
K(85, P(COIL, root=(7, 0, 0), neck=(-24, 0, 0), rs=(30, 32, 10), ls=(30, -32, -10)), ease="BACK")
# UNLOCK: arms thrown open forward-up, chin up
OPEN = P(STAND, root=(8, 0, 0), root_pos=(0, 0.06, 0), neck=(14, 0, 0),
         rs=(112, -8, 34), ls=(112, 8, -34), rh=(-2, 0, 3), lh=(-2, 0, -3))
K(90, OPEN)
idle.marker(90, "unlock")
K(93, P(OPEN, neck=(18, 0, 0), rs=(118, -10, 38), ls=(116, 10, -36)))
K(104, P(OPEN, root=(5, -4, 1), neck=(10, -6, 3), rs=(102, -14, 44), ls=(104, 14, -46)))
# anticipation for the lock: the arms open wider
K(108, P(OPEN, root=(3, 0, 0), neck=(4, 0, 0), rs=(92, -18, 54), ls=(92, 18, -54)), ease="IN")
# LOCK: hands slam together in front of the chest, head snaps down
LOCK = P(STAND, root=(-6, 0, 0), root_pos=(0, -0.03, -0.04), neck=(-24, 0, 0),
         rs=(66, 27, 4), ls=(66, -27, -4))
K(112, LOCK, ease="BACK")
idle.marker(112, "lock")
K(116, P(LOCK, root=(-3, 1, 0), neck=(-18, 0, 0), rs=(62, 25, 6), ls=(62, -25, -6)))
idle.loop()
wobble(idle, "neck", 1, 1.6, 3, 0.7)
wobble(idle, "root", 2, 0.6, 2, 1.9)
wobble(idle, "root", 1, 0.01, 4, 0.0, loc=True)  # breathing

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def stride(s, u):
    """s = +1 right contact, -1 left contact; u = weave angle (deg) of the hands."""
    w = weave(u, 0.0)
    return P(w, root=(-3, -5 * s, -1.5 * s), root_pos=(0, 0, 0), neck=(-12, 4 * s, 1.5 * s),
             rh=(22 * s, 0, 2), lh=(-22 * s, 0, -2))


def glide(s, u):
    w = weave(u, 0.0)
    return P(w, root=(-4, 0, 1 * s), root_pos=(0, 0.06, 0), neck=(-13, 0, 0),
             rh=(-2 * s, 0, 2), lh=(2 * s, 0, -2))


walk.pose(0, stride(1, 0))
walk.pose(h * 0.5, glide(1, 90))
walk.pose(h, stride(-1, 180))
walk.pose(h * 1.5, glide(-1, 270))
walk.loop()

# ------------------------------------------------------------------ jolt (additive, landing)
jolt = A.clip("jolt", seconds=0.6, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
jolt.pose(0, Z, ease="EXPO")
jolt.pose(3, P(Z, root=(-5, 0, 0), neck=(-10, 8, 0), rs=(-10, -8, 22), ls=(-10, 8, -22)))
jolt.pose(7, P(Z, root=(2, 0, 0), neck=(2, -8, 0), rs=(4, 4, -4), ls=(4, -4, 4)))
jolt.pose(11, P(Z, neck=(0, 4, 0)))
jolt.pose(18, Z)
jolt.marker(1, "slip")

plant(idle)
plant(walk)

A.lift = 0
A.finish()
