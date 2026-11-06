# Phantom Ping (1 in 2,500, Rare): "Notification from nobody."
# Concept: someone who keeps hearing notifications that are not there. Calm, a little
# hunched and uneasy; a PING makes the head snap toward the sound with a startled shrug, the
# torso follows late, a long suspicious stare at the empty air, then an annoyed swipe to
# dismiss it and a tired sigh. The second ping comes from BEHIND-left: this time no snap,
# just a slow dreadful look over the shoulder at the phantom echo hovering back there.
#
# CLIPS
#   idle (6.0 s, 180 f, loop; = two 3 s ring cycles of the VFX)
#     f0-26    uneasy calm: slight hunch, breathing, arms loose, weight drifting
#     f28      PING (right) -> f31 head snaps right + shoulders shrug + small hop back (EXPO),
#              f36 the torso follows the head, f40-56 squinting stare with a curious tilt
#     f58-74   nothing there; head drifts back, eyes down
#     f78-86   SWIPE: right hand rises to the right and sweeps across (dismiss), f96 drops
#     f106     SIGH: shoulders and chest sink, head drops
#     f122     PING (left/behind) -> slow look over the left shoulder (no snap: dread),
#              f140 STARE at the phantom, f156-180 slowly turns back, settles into the loop
#   walk (lib.STRIDE): light tiptoe drift - short leg swing, high soft bounce, arms held
#     close and low, head slightly down and turned, uneasy.
#   glance (1.3 s, add, trigger "ghostping"): while walking the VFX now and then fires a
#     phantom notification; the head whips over the right shoulder and comes back (VFX -> body).
#
# MARKERS (AurasMid A.PhantomPing)
#   ping "R" f28 / ping "L" f122 -> a big notification badge pops on that side of the head,
#                                   a floor shock ring expands, head sparkles, light flash
#   swipe f84                     -> every visible badge is flicked away (fast fade + drift),
#                                   spark spray from the right hand
#   sigh  f106                    -> the light and the rings dim for a moment
#   stare f140                    -> the phantom echo behind the player flares bright
#   (free events) step -> a faint ping ripple at the landing foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("PhantomPing")


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
    """Floor contact: raise root-height keys just enough that the lowest sole touches the
    floor (never lowers a key, so deliberate rises survive)."""
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
idle = A.clip("idle", seconds=6.0)  # 180 frames

CALM = dict(
    root=(-3, 2, 1), root_pos=(0, 0, 0), neck=(-6, -3, 1),
    rs=(3, 0, 4), ls=(5, 0, -5), rh=(0, 0, 1.5), lh=(1, 3, -2.5),
)
K = idle.pose
K(0, CALM)
K(14, P(CALM, root=(-1.5, 1, 0.5), neck=(-4, -1, 0), rs=(4, 0, 5), ls=(6, 0, -6)))  # breathe in
K(25, P(CALM, root=(-3.5, 2, 1.2), neck=(-7, -4, 1)), ease="CONST")
# --- PING right: the sound, 3 frames later the startle
idle.marker(28, "ping", "R")
K(28, P(CALM, root=(-3.5, 2, 1.2), neck=(-7, -4, 1)), ease="EXPO")
STARTLE = P(CALM, root=(4, -4, -1), root_pos=(0, 0.06, 0.08), neck=(10, -46, -8),
            rs=(-4, 0, 17), ls=(-2, 0, -16), rh=(-2, 0, 2), lh=(-2, 0, -3))
K(31, STARTLE)
K(36, P(STARTLE, root=(1, -14, -2), root_pos=(0.04, 0.02, 0.04), neck=(6, -40, -10),
        rs=(2, 0, 10), ls=(2, 0, -10)))  # torso catches up with the head
STARE = P(CALM, root=(-5, -16, -3), root_pos=(0.06, 0, -0.04), neck=(-2, -34, -14),
          rs=(6, 0, 6), ls=(8, 0, -6), rh=(2, 0, 2), lh=(-1, -3, -2))
K(44, STARE)
K(56, P(STARE, neck=(-4, -36, -17), root=(-6, -17, -3)))  # leaning in, squinting
# --- nothing there
K(66, P(CALM, root=(-4, -6, 0), neck=(-12, -10, -2)))
K(74, P(CALM, root=(-4, 0, 1), neck=(-11, -2, 1)), ease="BACK")
# --- SWIPE to dismiss: raise to the right, sweep across, drop
K(80, P(CALM, root=(-2, -6, 0), neck=(-4, -10, 0), rs=(48, 0, 34), ls=(4, 0, -6)), ease="EXPO")
K(86, P(CALM, root=(-4, 10, 2), neck=(-6, 8, 2), rs=(72, 52, 2), ls=(2, 0, -8)))
idle.marker(84, "swipe")
K(90, P(CALM, root=(-4, 11, 2), neck=(-7, 9, 2), rs=(64, 48, 4)), ease="IN")
K(98, P(CALM, root=(-3, 4, 1), neck=(-6, 2, 1), rs=(0, 0, 3)), ease="BACK")
# --- SIGH
K(104, P(CALM, root=(0, 2, 0.5), root_pos=(0, 0.03, 0), neck=(2, 0, 0), rs=(5, 0, 7), ls=(6, 0, -8)))
K(110, P(CALM, root=(-8, 2, 1), root_pos=(0, -0.02, 0), neck=(-18, -2, 3), rs=(6, 0, 2), ls=(7, 0, -2)))
idle.marker(106, "sigh")
K(118, P(CALM, root=(-6, 2, 1), neck=(-14, -2, 2)))
# --- PING left / behind: slow, dreadful look over the shoulder
idle.marker(122, "ping", "L")
K(123, P(CALM, root=(-6, 2, 1), neck=(-13, -2, 2)), ease="IN")
K(126, P(CALM, root=(-5, 3, 0), neck=(-6, 8, 3), rs=(4, 0, 5), ls=(3, 0, -9)))  # freeze, eyes widen
LOOKBACK = P(CALM, root=(-1, 26, -4), root_pos=(-0.05, 0, 0.04), neck=(0, 58, 6),
             rs=(10, 0, 6), ls=(-6, 0, -12), rh=(2, 8, 2), lh=(-3, 6, -3))
K(140, LOOKBACK)
idle.marker(140, "stare")
K(150, P(LOOKBACK, neck=(2, 60, 9), root=(-1, 27, -4.5)))
K(162, P(CALM, root=(-3, 8, 0), neck=(-8, 18, 2)), ease="OUT")
K(172, P(CALM, neck=(-7, 0, 1)))
idle.loop()
wobble(idle, "neck", 0, 1.2, 3, 0.4)
wobble(idle, "neck", 2, 1.0, 4, 1.9)
wobble(idle, "root", 2, 0.7, 2, 0.7)
wobble(idle, "root", 0, 0.8, 6, 0.0)  # breathing
wobble(idle, "rs", 2, 0.8, 3, 1.0)
wobble(idle, "ls", 2, 0.8, 3, 2.6)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(s):
    return dict(
        root=(-6, -5 * s, -1.5 * s), root_pos=(0, 0, 0), neck=(-8, 4 * s - 6, 1 * s),
        rs=(-14 * s, 0, 5), ls=(14 * s, 0, -5),
        rh=(19 * s, 0, 1.5), lh=(-19 * s, 0, -1.5),
    )


def passing(s):
    return dict(
        root=(-4, 0, 1.5 * s), root_pos=(0, 0.18, 0), neck=(-6, -6, -1 * s),
        rs=(2 * s, 0, 4), ls=(-2 * s, 0, -4),
        rh=(-6 * s, 0, 1.5), lh=(6 * s, 0, -1.5),  # trailing toe lifts softly
    )


W = walk.pose
W(0, contact(1), ease="OUT")
W(h * 0.5, passing(1), ease="IN")
W(h, contact(-1), ease="OUT")
W(h * 1.5, passing(-1), ease="IN")
walk.loop()

# ------------------------------------------------------------------ glance (additive, VFX -> body)
gl = A.clip("glance", seconds=1.3, trigger="ghostping", mode="add", blend_in=0.05, blend_out=0.25)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
gl.pose(0, Z, ease="EXPO")
gl.pose(4, P(Z, neck=(8, -55, -6), root=(2, -10, 0), rs=(-3, 0, 8), ls=(-3, 0, -8)))
gl.pose(9, P(Z, neck=(5, -62, -9), root=(1, -16, 0), rs=(0, 0, 4), ls=(0, 0, -4)))
gl.pose(22, P(Z, neck=(2, -58, -8), root=(0, -14, 0)), ease="OUT")
gl.pose(34, P(Z, neck=(-3, 6, 1), root=(0, 2, 0)))
gl.pose(39, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
