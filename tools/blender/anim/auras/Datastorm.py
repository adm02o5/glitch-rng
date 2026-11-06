# Datastorm (1 in 20,000, Epic, DataStorm biome): "Born in the eye of the storm."
# Concept: the storm-caller standing in the eye of a green code tornado. Wide, rooted stance,
# both arms raised, STIRRING the vortex in big sweeping circles - the torso twists with every
# sweep, the head and arms trail a few frames behind like they are dragged by the wind. Then
# the dip-and-rise: it sinks, hauls both arms to the sky (charging, trembling), and DRIVES the
# right arm down - the lightning bolt hits the floor exactly where the hand points. A stagger
# of recoil, then a gust: arms fling wide, the code rain blasts outward, and it floats back
# into the stir.
#
# CLIPS
#   idle (4.8 s, 144 f, loop)
#     f0-44    three stir sweeps (right->left->right->left, BACK overshoot), torso twists
#              +-14 deg, weight rolls between the feet, arms stir high (the leading arm sweeps
#              forward-across, the trailing one back); neck keys land 3-4 frames after the
#              body (drag); the third sweep is the biggest
#     f56      dip: anticipation, knees "bend" (root down + hips forward), arms drop low/in,
#              head down
#     f66-84   RISE: both arms haul overhead (EXPO), back arches, chin up; held trembling
#              and pulled even further back on f84 (anticipation for the strike)
#     f88      STRIKE: the right arm whips down pointing at the floor out front-right, the
#              left arm flies back up for balance, deep lean into the strike (EXPO)
#     f90-102  overshoot + 3 CONST jolts (the shock running through the body), recoil
#     f108     GUST: arms fling out wide, palms forward, chest open, head back (BACK)
#     f120-144 arms float back up into the stir pose (slow, wind-carried)
#   walk (lib.STRIDE): leaning into the gale - torso pitched forward, head up to see through
#     the wind, arms streaming back and out (barely swinging, fluttering), heavy push-off.
#   touchdown (0.8 s, replace, trigger "land"): lands into a crouch and punches the right fist
#     into the floor - calls a bolt down onto the fist - then rises.
#
# MARKERS (AurasMid A.Datastorm)
#   swirl  f12, f28, f42   each sweep's whip  -> the tornado spins faster (envelope), glyph
#                                                columns flash, streaks brighten
#   charge f66             the haul to the sky -> the sky emitter bursts, code rain thickens,
#                                                light swells, both hands spark upward
#   strike f88             the downward drive  -> the lightning bolt fires from the sky to the
#                                                floor point under the right hand, ground glyph
#                                                burst + smoke, light 6, hand spark
#   gust   f108            arms fling wide     -> outward blast of ground pixels, rings swell
#   touchdown f4 "strike"  fist hits the floor -> the same bolt + burst, aimed at the fist
#   (free) step "R"/"L" -> a small code splash under that foot
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("Datastorm")


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


def plant(clip, passes=3, extra=0.0):
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
    if extra:
        for fc in clip._curves('pose.bones["root"].location'):
            if fc.array_index == 1:
                for kp in fc.keyframe_points:
                    kp.co.y += extra
                    kp.handle_left.y += extra
                    kp.handle_right.y += extra
                fc.update()


def keysheet(clip, frames, tag="keys"):
    """Extra contact sheet of hand-picked frames (front / side / 3-4) for reviewing key poses."""
    import subprocess
    import tempfile
    rig, sc, cam = A.rig, A.scene, A.cam
    rig.animation_data.action = clip.action
    tmp = tempfile.mkdtemp(prefix="glitchks_")
    cmd = ["montage"]
    for v in ("front", "side", "3/4"):
        lib._aim(cam, lib.VIEWS[v])
        for f in frames:
            sc.frame_set(f)
            fp = os.path.join(tmp, f"{v.replace('/', '')}_{f:04d}.png")
            sc.render.filepath = fp
            bpy.ops.render.render(write_still=True)
            cmd += ["-label", f"{v} f{f}", fp]
    dst = os.path.join(lib.PREVIEW_DIR, f"{A.id}_{clip.name}_{tag}.png")
    cmd += ["-tile", f"{len(frames)}x3", "-geometry", "+2+2", "-background", "#111", "-fill", "#ddd",
            "-pointsize", "13", dst]
    subprocess.run(cmd, check=False, capture_output=True)
    print("[preview]", dst)


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.8)  # 144 frames
K = idle.pose


def stir(tw, hi=0.0):
    """Stir pose. tw -1..1: the torso turned right .. left (the right arm leads when tw > 0).
    hi 0..1 lifts the arms higher (the big sweep)."""
    return dict(
        root=(4, 14 * tw, -3 * tw),
        root_pos=(0.12 * tw, -0.06, 0),
        rs=(6 + 28 * tw + 6 * hi, 0, 100 - 14 * tw + 14 * hi),
        ls=(6 - 28 * tw + 6 * hi, 0, -100 - 14 * tw - 14 * hi),
        rh=(0, -9 * tw, 9 + 2 * tw),
        lh=(0, -9 * tw, -9 + 2 * tw),
    )


def head(tw, up=14):
    return (up, -6 * tw, 4 * tw)


# three sweeps: body on the beat (BACK overshoot), head 3-4 frames late (dragged by the wind)
K(0, P(stir(-0.8), neck=head(-1)))
for f, tw, hi in ((14, 1.0, 0.0), (30, -1.0, 0.2), (46, 0.9, 1.0)):
    idle.marker(f - 2, "swirl")
    K(f, stir(tw, hi), ease="BACK")
    idle.key(f + 4, neck=head(tw, 14 + 6 * hi), ease="BACK")
# dip (anticipation for the rise)
DIP = dict(
    root=(-12, 4, 0), root_pos=(0, -0.3, 0.05), neck=(-16, 2, 0),
    rs=(24, 0, 34), ls=(24, 0, -34), rh=(18, -2, 10), lh=(18, -2, -10),
)
K(58, DIP, ease="IN")
idle.key(61, neck=(-20, 0, 0))
idle.marker(66, "charge")
# RISE: haul both arms to the sky
RISE = dict(
    root=(9, 0, 0), root_pos=(0, 0.02, 0), neck=(30, 0, 0),
    rs=(172, -4, 14), ls=(172, 4, -14), rh=(-2, 0, 9), lh=(-2, 0, -9),
)
K(70, RISE, ease="EXPO")
idle.key(73, neck=(34, 0, 2), ease="BACK")
K(78, P(RISE, root=(10, -2, 1), rs=(176, -4, 12), ls=(170, 4, -16), neck=(32, 3, 2)))
# pull back further (wind-up)
K(85, P(RISE, root=(13, -4, 2), rs=(196, -6, 18), ls=(186, 6, -20), neck=(36, 4, 3),
        rh=(-5, 0, 9), lh=(-5, 0, -9)), ease="IN")
# STRIKE: right arm drives down at the floor out front-right, left arm flies up-back
STRIKE = dict(
    root=(-18, -12, -9), root_pos=(0.2, -0.3, 0.05), neck=(-24, -14, -6),
    rs=(42, 0, 24), ls=(-52, 0, -124), rh=(24, 10, 16), lh=(14, 10, -4),
)
K(88, STRIKE, ease="EXPO")
idle.marker(88, "strike")
K(91, P(STRIKE, root=(-21, -13, -10), rs=(36, 0, 26), ls=(-58, 0, -130), neck=(-28, -16, -8)))
# shock jolts (CONST, 2 frames each)
K(93, P(STRIKE, root=(-17, -10, -7), neck=(-18, -10, -10)), ease="CONST")
K(95, P(STRIKE, root=(-20, -14, -11), neck=(-27, -18, -3)), ease="CONST")
K(97, P(STRIKE, root=(-19, -12, -9), neck=(-23, -13, -7)))
K(102, P(STRIKE, root=(-11, -6, -4), root_pos=(0.12, -0.2, 0.04), rs=(34, 0, 36), ls=(-24, 0, -96),
         neck=(-10, -8, -3), rh=(16, 6, 13), lh=(8, 6, -6)))
# GUST: fling wide, chest open, head back
GUST = dict(
    root=(8, 2, 0), root_pos=(0, -0.04, 0), neck=(22, 4, 0),
    rs=(14, 0, 104), ls=(14, 0, -104), rh=(-2, 0, 11), lh=(-2, 0, -11),
)
idle.marker(108, "gust")
K(108, GUST, ease="BACK")
idle.key(112, neck=(26, 6, -3), ease="BACK")
K(124, P(stir(-0.4, 0.2), neck=head(-0.6, 18)))
idle.loop()
# the wind: arms flutter, breathing heaves, the head drifts
wobble(idle, "rs", 2, 2.2, 7, 0.3)
wobble(idle, "ls", 2, 2.2, 7, 2.1)
wobble(idle, "rs", 0, 1.5, 5, 1.0)
wobble(idle, "ls", 0, 1.5, 5, 3.0)
wobble(idle, "root", 0, 1.0, 3, 0.5)
idle.noise("neck", 1, 2.5, cycles=(2, 3, 5), seed=3)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)
h = walk.frames / 2
LEAN = 22


def contact(s):
    return dict(
        root=(-LEAN, -6 * s, -2 * s), root_pos=(0, -0.08, 0.1), neck=(14, 5 * s, 2 * s),
        rs=(-44 - 6 * s, 0, 30), ls=(-44 + 6 * s, 0, -30),
        rh=(LEAN + 26 * s, 0, 3), lh=(LEAN - 26 * s, 0, -3),
    )


def passing(s):
    return dict(
        root=(-LEAN + 3, 0, 2.5 * s), root_pos=(0, 0.1, 0.1), neck=(10, 0, -s),
        rs=(-38, 0, 36), ls=(-38, 0, -36),
        rh=(LEAN - 2 * s, 0, 3), lh=(LEAN + 2 * s, 0, -3),
    )


walk.pose(0, contact(1), ease="OUT")
walk.pose(h * 0.5, passing(1))
walk.pose(h, contact(-1), ease="OUT")
walk.pose(h * 1.5, passing(-1))
walk.loop()
wobble(walk, "rs", 2, 3, 3, 0.0)  # flutter in the wind
wobble(walk, "ls", 2, 3, 3, 1.7)
wobble(walk, "rs", 0, 3, 2, 0.9)
wobble(walk, "ls", 0, 3, 2, 2.6)

# ------------------------------------------------------------------ touchdown (on landing)
td = A.clip("touchdown", seconds=0.8, trigger="land", mode="replace", blend_in=0.03, blend_out=0.25)
td.pose(0, P(DIP, root=(-16, 0, 0), rs=(120, 0, 30), ls=(30, 0, -60)), ease="IN")
FIST = dict(
    root=(-38, 8, 4), root_pos=(0, -0.6, 0.25), neck=(30, -6, 0),
    rs=(74, 0, 12), ls=(-10, 0, -70), rh=(34, 0, 14), lh=(42, 0, -12),
)
td.pose(4, FIST, ease="EXPO")
td.marker(4, "strike")
td.pose(7, P(FIST, root=(-41, 8, 4), neck=(26, -8, -4)))
td.pose(10, P(FIST, root=(-39, 6, 3), neck=(32, -4, 2)))
td.pose(16, P(DIP, root=(-14, 2, 0), rs=(40, 0, 50), ls=(10, 0, -70), neck=(6, 0, 0)), ease="OUT")
td.pose(24, P(stir(0, 0), neck=head(0)))

plant(idle, extra=0.04)
plant(walk)
plant(td)

A.lift = 0
A.finish(preview=False)
A.preview(frames_per_clip=12)
keysheet(idle, [14, 30, 46, 58, 70, 85, 88, 91, 102, 108])
