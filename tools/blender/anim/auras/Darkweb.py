# Darkweb (1 in 2,000, Rare): "Not indexed. Not safe."
# Concept: a hooded lurker. Hunched, hands buried in the hoodie pocket, eyes up from under the
# hood. It checks over both shoulders (paranoid snaps), slips one hand out to tap something on an
# invisible hidden terminal, then crouches and throws both arms out low and wide like a spider's
# legs - the web behind it flares, the spider sprints home - and it twitches, then tucks back in.
# The idle length (4.8 s) is the spider's crawl cycle in the VFX (Sync.phase(bus, 4.8)).
#
# CLIPS
#   idle (4.8 s, 144 f, loop)
#     f0-16    hunched lurk, slow breath, hands in the pocket, eyes up
#     f18-22   head dips (anticipation), then SNAPS left (EXPO), the torso follows 4 f later
#     f36-40   snaps over the right shoulder, deeper, the shoulders follow
#     f54      back to centre with a suspicious tilt
#     f62-82   the right hand slips out to chest height, head down to "the screen", three EXPO
#              finger taps (the head nods a frame after each), the left hand stays tucked
#     f86-92   coil: the hand goes back, the body sinks into a crouch (anticipation)
#     f96      SPREAD: both arms flung out low and wide like spider legs (BACK), chin up
#     f100-110 creepy leg-twitches (CONST snaps of each arm, asymmetric)
#     f118-144 tucks the hands back in, rises with an overshoot, settles into the lurk
#   walk (lib.STRIDE): sneaking - deeper hunch, short quick steps with a low bob, hands stay
#     in the pocket, the head checks left on the right step and right on the left step.
#   duck (0.7 s, add, trigger "land"): lands and cowers - shoulders up, head down, then peeks.
#
# MARKERS (AurasExtra A.Darkweb)
#   glance f22 "L", f40 "R"   head snaps -> the .onion label switches to a new address + flickers,
#                             the web shudders, onion rings flash
#   tap   f70, f76, f82       finger taps -> the web strands pluck (ring radius ripple), the spider
#                             freezes for a beat, purple data squares spark from the right hand
#   spread f96                arms out -> the web flares (bigger, brighter), the spider sprints back
#                             to the hub, floor strands pulse, spark bursts from both hands, smoke
#                             puff, the label reads "403 // GO BACK"
#   (free) step "R"/"L"       dark smoke + purple specks puff from that foot, the floor strands twitch
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Darkweb")


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


def hunch(lean, sink=0.0, **over):
    """Torso leaned forward by `lean` deg; the hips counter-rotate so the legs stay vertical."""
    d = dict(root=(-lean, 0, 0), root_pos=(0, -sink, 0.04 * lean / 12), neck=(lean * 0.8, 0, 0),
             rs=(40, 22, -6), ls=(40, -22, 6), rh=(lean, 0, 3), lh=(lean, 0, -3))
    d.update(over)
    return d


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.8)  # 144 frames == the spider's crawl cycle
K = idle.pose

LURK = hunch(14)
K(0, LURK)
K(10, hunch(16, 0.03, neck=(10, 3, 2)))  # exhale, sink
K(18, hunch(15, 0.02, neck=(6, 2, 0)), ease="IN")  # head dips (anticipation)
# glance LEFT: head snaps, torso follows
GL = hunch(14, neck=(12, 42, 6), root=(-14, 4, 1))
K(22, GL, ease="EXPO")
idle.marker(22, "glance", "L")
K(26, P(GL, root=(-13, 12, 2), neck=(11, 36, 5), rh=(14, -4, 3), lh=(14, -4, -3)))
K(34, P(GL, root=(-13, 11, 2), neck=(9, 38, 8), rh=(14, -4, 3), lh=(14, -4, -3)))
# glance RIGHT over the shoulder, deeper
K(37, P(GL, root=(-13, 10, 2), neck=(8, 30, 4), rh=(14, -4, 3), lh=(14, -4, -3)), ease="IN")
GR = hunch(15, neck=(10, -58, -6), root=(-15, -6, -2), rh=(15, 6, 3), lh=(15, 6, -3))
K(40, GR, ease="EXPO")
idle.marker(40, "glance", "R")
K(44, P(GR, root=(-15, -16, -3), neck=(9, -52, -4), rs=(36, 20, -4), ls=(44, -16, 10),
        rh=(15, 16, 3), lh=(15, 16, -3)))
K(50, P(GR, root=(-15, -15, -3), neck=(8, -50, -8), rh=(15, 15, 3), lh=(15, 15, -3)))
# back to centre, suspicious tilt
K(56, hunch(14, neck=(13, 4, 9)))
# the right hand slips out to an invisible terminal, head down to it
TERM = hunch(16, 0.02, neck=(-2, 8, 4), root=(-16, 6, 0), rs=(66, 0, -12), ls=(40, -22, 6),
             rh=(16, -6, 3), lh=(16, -6, -3))
K(64, P(TERM, rs=(54, 0, -4)))
K(68, TERM, ease="OUT")
for k, f in enumerate((70, 76, 82)):
    down = P(TERM, rs=(60, 0, -14 - 2 * k), neck=(-6, 8 - 3 * k, 4))
    K(f, down, ease="EXPO")
    idle.marker(f, "tap")
    K(f + 1, P(down, neck=(-9, 8 - 3 * k, 5)))
    K(f + 3, P(TERM, rs=(68, 0, -12 - 2 * k), neck=(-3, 7 - 3 * k, 4)))
# coil: the hand pulls back in, the body sinks
COIL = hunch(24, 0.18, neck=(18, 0, 0), rs=(34, 26, -4), ls=(34, -26, 4))
K(88, P(COIL, rs=(44, 14, -8)), ease="IN")
K(92, COIL, ease="IN")
# SPREAD: arms out low and wide like spider legs, chin up
SPREAD = hunch(20, 0.14, neck=(22, 0, 0), rs=(28, 0, 74), ls=(28, 0, -74),
               rh=(20, 0, 9), lh=(20, 0, -9))
K(96, SPREAD, ease="BACK")
idle.marker(96, "spread")
# leg twitches (asymmetric CONST snaps)
K(100, P(SPREAD, rs=(36, 0, 66), neck=(20, 6, 3)), ease="CONST")
K(102, P(SPREAD, rs=(36, 0, 66), ls=(18, 0, -80), neck=(20, -4, -2)), ease="CONST")
K(105, P(SPREAD, rs=(22, 0, 80), ls=(18, 0, -80), neck=(21, 3, 0)), ease="CONST")
K(108, P(SPREAD, rs=(30, 0, 70), ls=(34, 0, -68), neck=(20, 0, 0)), ease="CONST")
K(110, P(SPREAD, rs=(30, 0, 70), ls=(34, 0, -68), neck=(20, 0, 0)))
# tuck back in, rise with an overshoot
K(120, hunch(18, 0.06, neck=(10, -4, -2), rs=(44, 20, -6), ls=(42, -20, 6)), ease="IN")
K(128, hunch(11, 0, neck=(6, -2, -2), rs=(38, 22, -5), ls=(38, -22, 5)), ease="BACK")
K(136, hunch(15, 0.01, neck=(11, 0, 1)))
idle.loop()
wobble(idle, "root", 1, 0.012, 3, 0.0, loc=True)  # breathing under the hood
wobble(idle, "neck", 2, 1.5, 2, 0.6)
wobble(idle, "root", 1, 1.2, 1, 1.3)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2
LEAN = 18


def sneak_contact(s):
    return hunch(LEAN, 0.06, root=(-LEAN, -6 * s, -2 * s), neck=(14, 14 * s, 4 * s),
                 rs=(42, 22, -6), ls=(42, -22, 6),
                 rh=(LEAN + 18 * s, 0, 3), lh=(LEAN - 18 * s, 0, -3))


def sneak_pass(s):
    return hunch(LEAN + 2, 0.0, root=(-LEAN - 2, 0, 1.5 * s), neck=(16, 4 * s, 1 * s),
                 rs=(38, 20, -6), ls=(38, -20, 6),
                 rh=(LEAN - 2 * s, 0, 3), lh=(LEAN + 2 * s, 0, -3))


walk.pose(0, sneak_contact(1), ease="EXPO")
walk.pose(h * 0.5, sneak_pass(1))
walk.pose(h, sneak_contact(-1), ease="EXPO")
walk.pose(h * 1.5, sneak_pass(-1))
walk.loop()

# ------------------------------------------------------------------ duck (additive, landing)
duck = A.clip("duck", seconds=0.7, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
duck.pose(0, Z, ease="EXPO")
duck.pose(3, P(Z, root=(-6, 0, 0), neck=(-14, 0, 0), rs=(-6, 0, 10), ls=(-6, 0, -10), rh=(6, 0, 0), lh=(6, 0, 0)))
duck.pose(10, P(Z, root=(-4, 4, 0), neck=(4, 18, 2), rh=(4, 0, 0), lh=(4, 0, 0)))
duck.pose(15, P(Z, neck=(2, -10, 0)))
duck.pose(21, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
