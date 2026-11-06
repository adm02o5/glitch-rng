# Virus (1 in 3,300, Rare): "Spreads by looking at it."
# Concept: patient zero. A sick, slouched host clutching its stomach, head lolling with fever.
# The infection keeps taking the body over: it convulses (glitchy CONST twitches), doubles over
# in a two-stage cough that sprays spores, then - possessed - cups the virus in both hands,
# lets it pinch and wobble, and rips the hands apart like a cell dividing: the orbs around the
# body split on exactly that frame. A slow sickly recovery back into the slouch.
# The idle length (4.0 s) is the infection cycle the VFX reads with Sync.phase(bus, 4.0).
#
# CLIPS
#   idle (4.0 s, 120 f, loop)
#     f0-22    feverish slouch: left hand on the stomach, right arm limp, weight drifts left then
#              right, the head lolls after the torso (overlap, 4 f late)
#     f26, f31 TWITCH: the infection jerks the body (CONST): head snaps up-right / down-left,
#              shoulders hike asymmetrically, the hips kick
#     f38-44   anticipation: big inhale, chest up, right fist comes up to the mouth
#     f48, f54 COUGH x2 (EXPO): the torso doubles forward, head down, knees (hips) give; the second
#              cough is smaller; recoil between them
#     f64-80   possessed: both hands cup in front of the chest, the head bends down to stare at the
#              virus; f74/f77/f80 the "cell" pinches (CONST micro-snaps of the hands)
#     f84      SPLIT (BACK): hands torn apart wide, torso arches back, head thrown up - then a
#              trembling hold, the arms sink and the left hand finds the stomach again
#   walk (lib.STRIDE): a sick lurching limp - the right leg takes a full step, the infected left
#     leg only drags forward a short way; the torso lurches onto the bad leg, the head lolls the
#     other way a beat late, the right arm swings limp, the left hand stays on the stomach.
#   convulse (0.8 s, add, trigger "land"): landing shakes the host - three CONST jerks + settle.
#
# MARKERS (AurasExtra A.Virus)
#   twitch f26, f31 (walk f16)  INFECTED label glitches (pink/garbage text), every orb jitters,
#                               the floor sigil flickers, green specks fly off the head
#   cough  f48, f54             spore spray from the head (tip "head"), a fresh infection ring
#                               spreads from the feet, two of the four orb lineages divide
#   pinch  f72                  the other two lineages start to pinch (wobble before division)
#   split  f84                  those two lineages divide NOW (hands torn apart), spark bursts
#                               from both hands, the root light flares, host counter doubles
#   drag   walk f3              green spores scrape off the dragged left foot
#   (free) step "R"/"L"         infected footprint: pink/green specks from that foot + a
#                               spreading ring
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Virus")


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


def sick(lean=9.0, sway=0.0, sink=0.0, **over):
    """Slouched host. lean = forward lean (deg), sway -1..1 = weight on the left .. right foot.
    The hips counter-rotate the lean so the legs stay vertical."""
    d = dict(
        root=(-lean, 3 * sway, -3.5 * sway),
        root_pos=(0.08 * sway, -sink, 0.03 * lean / 10),
        neck=(lean * 0.8 - 8, -4 * sway, -10 - 5 * sway),
        rs=(4 + lean * 0.5, 0, 5 + 2 * sway),  # limp right arm
        ls=(32, 0, 30),  # left hand on the stomach
        rh=(lean, 0, 2 + 3.5 * sway),
        lh=(lean, 0, -2 + 3.5 * sway),
    )
    d.update(over)
    return d


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.0)  # 120 frames == the infection cycle in the VFX
K = idle.pose

K(0, sick(9, 0))
# feverish sway: weight left, the head follows late
K(10, sick(10, -1, 0.02, neck=(0, 2, -6)))
idle.key(14, neck=(-2, 6, 4))  # head lolls left after the torso
K(20, sick(9, 0.6, neck=(-4, -2, -8)))
idle.key(23, neck=(-6, -4, -16), ease="IN")  # head drops to the right shoulder
# TWITCH 1: head snaps up-right, right shoulder hikes, hips kick
T1 = sick(6, 0.4, root=(-6, -6, -6), neck=(14, -24, -22), rs=(14, 0, 26), ls=(38, 0, 26),
          rh=(10, 0, 4), lh=(4, 0, -3))
K(26, T1, ease="CONST")
idle.marker(26, "twitch")
K(28, sick(8, 0.2, neck=(4, -10, -12)), ease="CONST")
# TWITCH 2: the other way, deeper
T2 = sick(12, -0.5, root=(-12, 8, 6), neck=(-12, 22, 20), rs=(0, 0, 8), ls=(24, 0, 36),
          rh=(14, 0, 1), lh=(8, 0, -5))
K(31, T2, ease="CONST")
idle.marker(31, "twitch")
K(33, sick(10, -0.2, neck=(-4, 10, 6)), ease="CONST")
K(38, sick(9, 0, neck=(-4, 2, -6)))
# anticipation: inhale, chest up, fist to the mouth
INHALE = sick(-4, 0, 0, root=(5, 4, 0), neck=(-2, -4, -2), rs=(132, 0, -30), ls=(28, 0, 28),
              rh=(-4, 0, 2), lh=(-4, 0, -2))
K(42, P(INHALE, rs=(96, 0, -18)), ease="IN")
K(45, INHALE, ease="OUT")
# COUGH 1: double over
C1 = sick(26, 0, 0.12, root=(-26, -3, 0), neck=(-6, -6, -4), rs=(138, 0, -32), ls=(40, 0, 34),
          rh=(30, 0, 3), lh=(30, 0, -3))
K(48, C1, ease="EXPO")
idle.marker(48, "cough")
K(51, sick(10, 0, 0.04, root=(-10, -1, 0), neck=(4, -4, -2), rs=(126, 0, -28), ls=(32, 0, 30)), ease="OUT")
# COUGH 2: smaller echo
C2 = sick(19, 0, 0.08, root=(-19, 2, 1), neck=(-4, 4, 2), rs=(136, 0, -31), ls=(36, 0, 32),
          rh=(22, 0, 3), lh=(22, 0, -3))
K(54, C2, ease="EXPO")
idle.marker(54, "cough")
K(58, sick(11, 0, 0.03, neck=(-2, 0, -8), rs=(70, 0, -12)))
K(64, sick(9, 0.3, neck=(-6, -2, -12)))
# possessed: cup the virus in both hands, stare down at it
CUP = sick(12, 0, 0.02, root=(-12, 0, 0), neck=(-16, 0, 0), rs=(76, 0, -28), ls=(76, 0, 28))
K(70, P(CUP, rs=(64, 0, -18), ls=(66, 0, 20), neck=(-10, 4, -6)))
K(72, CUP, ease="EXPO")
idle.marker(72, "pinch")
# the cell pinches: micro-snaps of the hands, head twitches with them
K(74, P(CUP, rs=(80, 0, -31), ls=(72, 0, 25), neck=(-18, -3, 2)), ease="CONST")
K(77, P(CUP, rs=(72, 0, -25), ls=(80, 0, 31), neck=(-15, 3, -2)), ease="CONST")
K(80, P(CUP, rs=(78, 0, -32), ls=(78, 0, 32), neck=(-19, 0, 0)), ease="CONST")
K(81, P(CUP, rs=(74, 0, -29), ls=(74, 0, 29), root=(-14, 0, 0), root_pos=(0, -0.05, 0.04)), ease="IN")
# SPLIT: hands torn apart, torso arches back, head thrown up
SPLIT = sick(-6, 0, 0, root=(7, 0, 0), neck=(18, 0, 0), rs=(62, -16, 62), ls=(62, 16, -62),
             rh=(-6, 0, 4), lh=(-6, 0, -4))
K(84, SPLIT, ease="BACK")
idle.marker(84, "split")
# trembling hold
K(88, P(SPLIT, rs=(58, -18, 66), ls=(66, 14, -58), neck=(15, 4, 3)), ease="CONST")
K(90, P(SPLIT, rs=(64, -14, 60), ls=(60, 18, -64), neck=(17, -3, -2)), ease="CONST")
K(93, P(SPLIT, root=(5, 0, 0), neck=(13, 0, 0)))
# arms sink, the left hand finds the stomach, fever returns
K(102, sick(6, -0.4, neck=(0, 4, -4), rs=(16, 0, 18), ls=(26, 0, 14)), ease="IN")
K(110, sick(10, 0.2, neck=(-4, -2, -12), rs=(2, 0, 4)))
idle.loop()
wobble(idle, "root", 1, 0.016, 4, 0.0, loc=True)  # laboured breathing
wobble(idle, "neck", 2, 2.5, 3, 0.4)  # feverish head drift
wobble(idle, "neck", 1, 2.0, 2, 1.1)
wobble(idle, "root", 2, 0.8, 1, 0.2)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2
LEAN = 11


def limp_contact_r():
    # the good right leg lands with a full step; the bad left leg is still trailing behind
    return sick(LEAN, 0.6, root=(-LEAN, -8, -4), neck=(-2, 6, 8),
                rs=(-22, 0, 6), ls=(32, 0, 30),
                rh=(LEAN + 26, 0, 3), lh=(LEAN - 20, 0, -2))


def limp_pass_r():
    # weight on the good leg: the body rises, the left leg drags forward
    return sick(LEAN - 2, 0.8, 0, root=(-LEAN + 2, -2, -5), neck=(0, 2, 10),
                rs=(0, 0, 6), ls=(30, 0, 31),
                rh=(LEAN + 2, 0, 4), lh=(LEAN - 2, 0, -1))


def limp_contact_l():
    # the infected left leg lands short; the torso lurches onto it, head lolls right (late)
    return sick(LEAN + 4, -1, 0.04, root=(-LEAN - 4, 8, 9), neck=(-6, -6, -6),
                rs=(26, 0, 9), ls=(40, 0, 27),
                rh=(LEAN + 4 - 18, 0, 5), lh=(LEAN + 4 + 12, 0, -1))


def limp_pass_l():
    # barely rises over the bad leg; the right leg swings through
    return sick(LEAN + 3, -0.9, 0.02, root=(-LEAN - 3, 4, 7), neck=(-8, -4, -16),
                rs=(10, 0, 7), ls=(36, 0, 29),
                rh=(LEAN + 3 + 2, 0, 4), lh=(LEAN + 3 - 2, 0, 0))


walk.pose(0, limp_contact_r(), ease="EXPO")
walk.marker(3, "drag")
walk.pose(h * 0.5, limp_pass_r())
walk.pose(h, limp_contact_l(), ease="EXPO")
walk.pose(h * 1.45, limp_pass_l())
walk.key(h * 1.5, neck=(8, -18, -20), ease="CONST")  # a feverish twitch mid-stride
walk.marker(h * 1.5, "twitch")
walk.key(h * 1.5 + 2, neck=(-6, -2, -10))
walk.loop()

# ------------------------------------------------------------------ convulse (additive, landing)
cv = A.clip("convulse", seconds=0.8, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
cv.pose(0, Z, ease="CONST")
cv.pose(2, P(Z, root=(-8, 4, 5), neck=(-16, 12, 14), rs=(12, 0, 16), ls=(6, 0, -6), rh=(8, 0, 0), lh=(8, 0, 0)), ease="CONST")
cv.pose(5, P(Z, root=(-4, -6, -6), neck=(10, -14, -16), rs=(-4, 0, 4), ls=(14, 0, -18), rh=(4, 0, 0), lh=(4, 0, 0)), ease="CONST")
cv.pose(8, P(Z, root=(-6, 3, 2), neck=(-8, 6, 10), rs=(8, 0, 10), ls=(4, 0, -8), rh=(6, 0, 0), lh=(6, 0, 0)), ease="CONST")
cv.pose(11, P(Z, root=(-3, 0, 0), neck=(-6, 0, -4), rh=(3, 0, 0), lh=(3, 0, 0)), ease="OUT")
cv.pose(24, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
