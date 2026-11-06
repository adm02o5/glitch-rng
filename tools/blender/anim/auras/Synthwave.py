# Synthwave (1 in 7,500, Rare): "Forever 1986."
# Concept: the coolest guy at the arcade at sunset. Leaning back, hand on the hip, nodding to a
# 120 BPM synth track (the VFX runs on exactly this tempo). Once a bar he fires a finger gun at
# the camera, sweeps his hand across the horizon as if unveiling the sunset behind him, then
# pushes his (invisible) shades up his nose and slides back into the groove.
# The idle is ONE 8-beat phrase: 4.0 s = 8 beats x 0.5 s (15 f per beat); the VFX beat clock
# is Sync.phase(bus, 0.5) and the phrase clock Sync.phase(bus, 4.0), so both share the tempo.
#
# CLIPS
#   idle (4.0 s, 120 f, loop)
#     every beat (f0, 15, 30 ... 105): head nod (EXPO dip, 7 f recovery), left foot taps on the
#              beat, the torso rocks side to side on alternate beats; neck keys are on their own
#              schedule so the head overlaps the body
#     f0-30    cool lean: torso turned a little left, leaning back, right hand on the hip, left arm
#              loose and swinging with the groove
#     f37      anticipation: right arm cocks back, torso winds further left
#     f45      FINGER GUN (BACK) at the camera, torso snaps square; f48 recoil kick; the left hand
#              drops onto the hip
#     f56      wind-up to the left, head follows the hand
#     f60-75   SWEEP: the right hand glides across the horizon and finishes high out to the side
#              (BACK overshoot), the torso unwinds, eyes follow the hand
#     f90      SHADES: hand snaps to the face (EXPO), chin up, leaning back
#     f100-120 hand slides back to the hip, left arm loosens, back into the groove
#   walk (lib.STRIDE): grooving strut - bouncy rise on every passing pose, shoulders roll against
#     the hips, arms swing loose and wide, the head nods on every footfall (one beat per step).
#   flourish (0.8 s, add, trigger "land"): lands like a dance hit - arms flare, head nods, settles.
#
# MARKERS (AurasExtra A.Synthwave)
#   beat   idle f0,15,...,105; walk on both contacts
#          -> "1986" pops (scale + white flash), the sun halo throbs, grid lines flash, root light
#   tap    idle f0,30,60,90 (bar downbeats, the foot tap) -> neon ring ripples out from the left foot
#   point  f45   finger gun -> cyan spark burst from the right hand + a "PEW" streak, text kicks
#   sweep  f75   end of the horizon sweep -> the sun swells up and flares, palms sway, sparkles
#                trail from the hand, the horizon line brightens
#   shades f90   shades push -> a star glint flashes on the face, the "1986" chrome shimmers
#   (free) step "R"/"L" -> a small pink/cyan floor ripple under that foot while walking
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Synthwave")
BEAT = 15  # frames per beat at 120 BPM


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


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.0)  # 120 frames = 8 beats at 120 BPM

HIP_R = (-12, 0, 34)  # right hand on the hip (arm angled out and back)
HIP_L = (-12, 0, -34)
LOOSE_L = (8, 0, -7)

# --- torso / hips: the body layer (rocks on alternate beats, turns with the gestures)
def body(f, turn=10.0, rock=0.0, back=3.0, dip=0.0, ease="INOUT"):
    # turn: +y = torso turned left; the hips counter-turn so the feet keep pointing forward
    idle.key(f, ease=ease, root=(back, turn, -2 + rock), root_pos=(0.07, -dip, 0),
             rh=(-back, -turn * 0.6, 2 - rock), lh=None)


for b in range(8):
    f = b * BEAT
    rock = -2.5 if b % 2 == 0 else 1.5
    if f in (45, 60, 75, 90):
        continue  # gesture beats key the body below
    body(f, rock=rock, dip=0.05, ease="EXPO")
    body(f + 7, rock=rock * 0.4, dip=0.0)
# gesture body keys
body(37, turn=16, rock=1.0, back=4, ease="IN")  # wind-up
body(45, turn=-4, rock=-3.5, back=-1, dip=0.06, ease="BACK")  # finger gun: snap square
body(52, turn=-2, rock=-2, back=1)
body(56, turn=18, rock=1.5, back=3)  # wind-up to the left
body(66, turn=2, rock=-1, back=3, dip=0.03)
body(75, turn=-14, rock=-3, back=4, dip=0.05, ease="BACK")  # sweep finish
body(82, turn=-8, rock=-1.5, back=4)
body(90, turn=6, rock=0.5, back=7, dip=0.04, ease="EXPO")  # shades: lean back
body(97, turn=8, rock=0, back=6)

# --- left leg: taps on every beat (lifts on the off-beat, slaps down on the beat)
for b in range(8):
    f = b * BEAT
    idle.key(f, lh=(2, -6, -7), ease="EXPO")
    idle.key(f + 8, lh=(13 if b % 2 == 0 else 9, -6, -8), ease="OUT")
    if b % 2 == 0:
        idle.marker(f, "tap")

# --- head: nods on every beat, looks with the gestures (a few frames behind the body)
NECK = {}
for b in range(8):
    f = b * BEAT
    NECK[f] = ((-11, -7, 4), "EXPO")  # nod down on the beat
    NECK[f + 7] = ((2, -7, 5), "INOUT")
NECK[39] = ((-2, -12, 2), "INOUT")
NECK[45] = ((-12, 2, -6), "EXPO")  # aim down the barrel, head tilt
NECK[52] = ((0, 0, -4), "INOUT")
NECK[59] = ((0, 16, 4), "INOUT")  # follows the hand to the left
NECK[69] = ((2, -2, 0), "INOUT")
NECK[78] = ((6, -16, -4), "BACK")  # eyes on the hand at the end of the sweep
NECK[82] = ((2, -14, -2), "INOUT")
NECK[90] = ((10, -4, 3), "EXPO")  # chin up, shades on
NECK[96] = ((8, -6, 4), "INOUT")
for f in sorted(NECK):
    v, e = NECK[f]
    idle.key(f, neck=v, ease=e)

# --- arms: the performance layer
idle.key(0, rs=HIP_R, ls=LOOSE_L)
idle.key(15, ls=(16, 0, -9))
idle.key(30, rs=HIP_R, ls=(4, 0, -6))
idle.key(37, rs=(-28, 0, 44), ls=(10, 0, -10), ease="IN")  # cock back
idle.key(45, rs=(88, 0, -6), ls=HIP_L, ease="BACK")  # FINGER GUN
idle.marker(45, "point")
idle.key(48, rs=(104, 0, -6), ease="EXPO")  # recoil
idle.key(52, rs=(90, 0, -6))
idle.key(56, rs=(78, 0, -46), ease="INOUT")  # wind to the left
idle.key(66, rs=(96, 0, 18), ease="LINEAR")
idle.key(75, rs=(22, 0, 128), ease="BACK")  # SWEEP finish, high out to the side
idle.marker(75, "sweep")
idle.key(82, rs=(24, 0, 96))
idle.key(87, rs=(110, 0, -20), ease="IN")
idle.key(90, rs=(152, 0, -28), ls=HIP_L, ease="EXPO")  # SHADES
idle.marker(90, "shades")
idle.key(95, rs=(146, 0, -27))
idle.key(106, rs=HIP_R, ls=(12, 0, -8))
for b in range(8):
    idle.marker(b * BEAT, "beat")
idle.loop()
wobble(idle, "root", 1, 0.012, 4, 0.3, loc=True)  # breathing
wobble(idle, "root", 1, 1.0, 1, 0.8)  # slow turn drift
wobble(idle, "neck", 2, 1.2, 2, 0.1)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def strut_contact(f, s):
    # s = +1: right foot forward. Shoulders roll against the hips, head nods on the beat
    walk.key(f, ease="EXPO",
             root=(2, -9 * s, -2.5 * s), root_pos=(0, 0, 0),
             neck=(-9, 8 * s, 3 * s),
             rs=(-28 * s, 0, 13), ls=(28 * s, 0, -13),
             rh=(24 * s, 5 * s, 2), lh=(-24 * s, 5 * s, -2))
    walk.marker(f, "beat")


def strut_pass(f, s):
    # bouncy rise over the standing leg, chin lifts, arms brush past wide
    walk.key(f, ease="OUT",
             root=(4, -2 * s, 2.5 * s), root_pos=(0.04 * s, 0.14, 0),
             neck=(4, 3 * s, -2 * s),
             rs=(4 * s, 0, 16), ls=(-4 * s, 0, -16),
             rh=(-2 * s, 0, 3), lh=(2 * s, 0, -3))


strut_contact(0, 1)
strut_pass(h * 0.5, 1)
strut_contact(h, -1)
strut_pass(h * 1.5, -1)
walk.loop()

# ------------------------------------------------------------------ flourish (additive, landing)
fl = A.clip("flourish", seconds=0.8, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
fl.pose(0, Z, ease="EXPO")
fl.pose(3, dict(Z, root=(-5, 0, 0), neck=(-14, 0, 0), rs=(0, 0, 38), ls=(0, 0, -38), rh=(5, 0, 0), lh=(5, 0, 0)), ease="BACK")
fl.pose(9, dict(Z, root=(2, 0, 0), neck=(6, 0, 0), rs=(0, 0, 22), ls=(0, 0, -22)))
fl.pose(15, dict(Z, neck=(-6, 0, 0)), ease="EXPO")
fl.pose(24, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
