# Hacktivist (1 in 5,000, Rare): "Expect us."
# Concept: the masked rally leader. Arms crossed, chin up, weight cocked on one hip - unbothered.
# Then it RAISES A FIST to the crowd (two pumps), levels an accusing finger straight at the camera
# ("WE SEE YOU"), cups both hands round the mouth and SHOUTS, snaps the arms back across the chest
# and gives one slow, knowing nod. Expect us.
# The idle length (5.2 s) sets the shout rhythm of the VFX: both slogan changes ride the markers
# (fist + shout) instead of the old 2.6 s timer.
#
# CLIPS
#   idle (5.2 s, 156 f, loop)
#     f0-14    arms crossed, chin up, weight on the right leg, slow breath, head drifts over the crowd
#     f18-26   anticipation: the arms uncross, the right fist drops low and back, the torso coils
#              right and sinks (the head lags 3 f)
#     f30      FIST: the right fist punches up overhead (EXPO), chest lifts, left fist to the hip
#     f30-52   overshoot + two pumps (f38, f46), the head bobs one frame after each pump
#     f56-62   the fist drops, the arm swings round (BACK) into a dead-level point at the camera,
#              the torso squares up, the head pushes forward
#     f62-74   holds the point; a tiny side-to-side "you" wag of the finger
#     f78-84   both hands rise to the mouth (megaphone), the body leans back to inhale
#     f86      SHOUT: lunge forward from the hips, head thrust, shoulders up (EXPO)
#     f90-104  shout recoil, follow-through
#     f110     CROSS: the arms snap across the chest (BACK overshoot), weight back to the right hip
#     f122-132 slow nod (chin down, hold, up) - "expect us"
#     f132-156 settle, breath, weight drift
#   walk (lib.STRIDE): protest march - chin up, chest out, the right fist held high and pumping once
#     per stride, the left arm swinging big, shoulders rolling with the step, a proud bounce.
#   brace (0.7 s, add, trigger "land"): lands, absorbs it, then squares up chin-high.
#
# MARKERS (AurasExtra A.Hacktivist)
#   fist  f30          new slogan on the shout glyph + both banners, banner RGB-glitch, banners jump,
#                      red/white spark burst from the right fist, light flashes white
#   pump  f38, f46     banners bob in time, short glitch, code columns flash bright
#   point f62          the three masks snap round to stare where the body points (forward) and hold,
#                      red code spray from the right hand
#   shout f86          second slogan change, shout glyph punches in (bigger), a megaphone ring blasts
#                      out from the head, banners jump, strong glitch, light flash
#   cross f110         the masks drift back into orbit, a white spark ring on the chest
#   nod   f126         the masks nod together, the sigil light pulses
#   march (walk, right contact)  banners bob with the march; every 3rd march changes the slogan
#   (free) step "R"/"L"  red squares kick up from that foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Hacktivist")


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
idle = A.clip("idle", seconds=5.2)  # 156 frames
K = idle.pose

CROSS_R = (96, 12, -66)  # forearm block across the chest (solved so it clears the torso)
CROSS_L = (82, -14, 60)  # tucked under it, a little lower


def stance(w=1.0, **over):
    """Arms crossed, chin up, weight cocked on the right hip (w = 1) / centred (w = 0)."""
    d = dict(root=(2, 4 * w, -3 * w), root_pos=(0.12 * w, 0, 0), neck=(7, -4 * w, 3 * w),
             rs=CROSS_R, ls=CROSS_L, rh=(0, 0, 3 * w + 1), lh=(4 * w, -8 * w, -4 * w - 3))
    d.update(over)
    return d


REST = stance()
K(0, REST)
K(8, stance(neck=(9, 6, 2), root=(3, 5, -3)))  # inhale, look over the crowd (left)
K(14, stance(neck=(8, -10, 4), root=(2, 3, -3)))  # drift right
# anticipation: uncross, the right fist drops low and back, the torso coils right and sinks
K(19, stance(0.6, neck=(4, -6, 2), rs=(30, 10, 10), ls=(40, -20, -8)), ease="IN")
COIL = dict(root=(-4, -12, 2), root_pos=(0.04, -0.12, 0), neck=(-2, 4, 0),
            rs=(-28, 0, 18), ls=(18, 0, -14), rh=(4, 6, 2), lh=(4, 6, -4))
K(24, COIL, ease="OUT")
K(26, P(COIL, neck=(-5, 6, 1)))  # head lags into the coil
# FIST: punch up overhead, chest lifts, the left fist to the hip
FIST = dict(root=(5, 8, -4), root_pos=(0.04, 0.06, 0), neck=(16, -8, 6),
            rs=(12, 0, 152), ls=(-14, 0, -32), rh=(-5, -4, 2), lh=(-5, -4, -4))
K(30, FIST, ease="EXPO")
idle.marker(30, "fist")
K(34, P(FIST, rs=(10, 0, 154), neck=(19, -8, 7), root=(6, 9, -5)))  # overshoot
K(36, P(FIST, rs=(18, 0, 130), neck=(15, -6, 5)), ease="IN")  # load the pump
for f in (38, 46):
    K(f, P(FIST, rs=(10, 0, 152), root=(6, 7, -5), root_pos=(0.04, 0.08, 0)), ease="EXPO")
    idle.marker(f, "pump")
    K(f + 1, P(FIST, rs=(10, 0, 150), neck=(20, -6, 7), root=(6, 7, -5), root_pos=(0.04, 0.07, 0)))
    K(f + 5, P(FIST, rs=(18, 0, 132), neck=(14, -7, 5)), ease="IN")
# the fist drops, the arm swings round into a dead-level point at the camera
K(56, P(FIST, rs=(40, 0, 70), neck=(6, -4, 0), root=(0, 2, 0), ls=(-8, 0, -24)), ease="IN")
POINT = dict(root=(-6, 6, 0), root_pos=(0, 0, -0.06), neck=(-4, -6, 0),
             rs=(92, 12, 0), ls=(-10, 0, -22), rh=(6, -6, 2), lh=(6, -6, -4))
K(62, POINT, ease="BACK")
idle.marker(62, "point")
K(64, P(POINT, neck=(-7, -6, 0)))  # head pushes forward a beat later
K(67, P(POINT, rs=(92, 18, 0), neck=(-6, -8, 1)))  # "you" wag
K(70, P(POINT, rs=(92, 6, 0), neck=(-6, -4, -1)))
K(74, P(POINT, rs=(90, 12, 0), neck=(-5, -6, 0)))
# megaphone: both hands rise to the mouth, the body leans back to inhale
MEGA = dict(root=(6, 0, 0), root_pos=(0, 0.04, 0.04), neck=(8, 0, 0),
            rs=(150, 35, -54), ls=(150, -35, 54), rh=(-6, 0, 2), lh=(-6, 0, -2))
K(78, P(MEGA, rs=(120, 20, -30), ls=(120, -20, 30), root=(3, 2, 0)), ease="IN")
K(84, MEGA, ease="OUT")
# SHOUT: lunge forward from the hips, head thrust, shoulders up
SHOUT = dict(root=(-12, 0, 0), root_pos=(0, -0.05, -0.12), neck=(14, 0, 0),
             rs=(156, 32, -52), ls=(156, -32, 52), rh=(12, 0, 2), lh=(12, 0, -2))
K(86, SHOUT, ease="EXPO")
idle.marker(86, "shout")
K(90, P(SHOUT, root=(-14, 0, 0), neck=(18, 0, 0)))
K(98, P(SHOUT, root=(-9, 0, 0), neck=(11, 2, 0), rs=(146, 34, -50), ls=(146, -34, 50)))
K(104, P(MEGA, root=(-2, 0, 0), rs=(110, 20, -40), ls=(110, -20, 40)), ease="IN")
# CROSS: the arms snap across the chest, weight back on the right hip
K(110, stance(0.8, neck=(10, -2, 2)), ease="BACK")
idle.marker(110, "cross")
K(116, stance(1.0, neck=(8, 2, 3)))
# slow knowing nod
K(122, stance(1.0, neck=(9, 0, 3)), ease="IN")
K(126, stance(1.0, neck=(-14, 0, 2), root=(0, 4, -3)), ease="OUT")
idle.marker(126, "nod")
K(132, stance(1.0, neck=(-12, 1, 2), root=(0, 4, -3)))
K(140, stance(1.0, neck=(9, -2, 3)), ease="BACK")
K(148, stance(0.9, neck=(7, -5, 3)))
idle.loop()
wobble(idle, "root", 1, 0.014, 4, 0.0, loc=True)  # breathing
wobble(idle, "root", 0, 0.8, 2, 0.4)
idle.noise("neck", 1, 1.6, seed=3)
idle.noise("neck", 2, 1.0, seed=4)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2


def contact(f, s):
    """s = +1: right foot forward (right contact), -1: left contact."""
    walk.key(f, ease="EXPO",
             root=(3, -9 * s, -3 * s - 2), root_pos=(0, 0, 0),
             neck=(10, 8 * s, 2 * s),
             rs=(14, 0, 146 if s > 0 else 132),
             ls=(-34 * s, 0, -9),
             rh=(26 * s, 0, 2), lh=(-26 * s, 0, -2))


def passing(f, s):
    walk.key(f, root=(4, 0, 2 * s - 2), root_pos=(0, 0.12, 0),
             neck=(9, 0, 0),
             rs=(16, 0, 136),
             ls=(4 * s, 0, -12),
             rh=(-3 * s, 0, 2), lh=(3 * s, 0, -2))


contact(0, 1)
walk.marker(0, "march")
passing(h * 0.5, 1)
contact(h, -1)
passing(h * 1.5, -1)
walk.loop()

# ------------------------------------------------------------------ brace (additive, landing)
brace = A.clip("brace", seconds=0.7, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
Z = dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
brace.pose(0, Z, ease="EXPO")
brace.pose(3, P(Z, root=(-7, 0, 0), neck=(-8, 0, 0), rs=(-6, 0, 12), ls=(-6, 0, -12), rh=(7, 0, 0), lh=(7, 0, 0)))
brace.pose(10, P(Z, root=(3, 0, 0), neck=(10, 0, 0)), ease="BACK")
brace.pose(21, Z)

plant(idle)
plant(walk)

A.lift = 0
A.finish()
