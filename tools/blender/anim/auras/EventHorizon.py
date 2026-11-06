# Event Horizon (1 in 50,000,000, CORRUPTED tier): "Nothing escapes. Not even light."
# VFX: a black-hole orb hovering above the head with an accretion disc, polar jets, matter
# streams and debris spiralling in, a contracting gravity well on the floor (AurasHigh.lua).
#
# CONCEPT: the body is caught in the hole's gravity. It LEVITATES (A.lift = 2 studs) and moves
# in zero-g slow motion: limbs float, everything overlaps and lags. Each 6 s cycle it is
# reached for, stretched up toward the singularity (spaghettification), frozen by time dilation,
# CRUSHED into a ball by tidal force and then flares out like Hawking radiation before drifting
# back down.
#
# IDLE (6.0 s = 180 f; the gravity well, the debris spiral and the sigil pulse share this
#   period through Sync.phase(bus, 6)). Markers -> what the VFX does:
#   0-20    zero-g drift, slow turn, arms floating out, legs trailing asymmetrically
#   20      head lifts to look at the hole above
#   32      anticipation: dips down, arms tuck in, legs fold - coiling
#   44      "reach"   BACK: arms shoot up to the orb, body stretched long, head thrown back
#                     VFX: matter streams flare white-hot and spark spray is pulled from both
#                     hands up into the orb, the accretion disc spins faster while reaching
#   52-84   spaghettified: dragged slowly upward in a spiral (root yaw +45), legs trail apart
#   86      "dilate"  CONST hold: TIME DILATION - the body freezes for 14 frames
#                     VFX: every particle emitter slows to 8 % (TimeScale), debris and disc
#                     freeze, the photon ring flickers - then everything snaps back
#   100     "crush"   EXPO: crushed into a ball (legs to the chest, arms hug them, head down)
#                     VFX: the orb implodes (shrinks), the floor gravity circles collapse to
#                     the centre, a dark shock ring on the floor, the light dims
#   104-116 trembling compression
#   118     "flare"   BACK: starfish burst - arms and legs flung wide, head back
#                     VFX: Hawking flash - jets widen, a huge spark nova from the body, white
#                     shock ring on the floor, light surge, the orb overshoots big
#   124-180 follow-through, the body sinks back down, limbs drifting home with lags
#
# WALK (one stride): a slow zero-g swim. Body pitched forward, legs trailing behind in a lazy
#   scissor, the arms do an alternating breast-stroke, the body surges forward on each pull.
#   2 / h+2 "stroke" "R"/"L" -> VFX: a spark trail is torn from that hand toward the orb.
#
# REACTIONS (one-shots, mode "add"):
#   gulp   (trigger "swallow", 1.0 s): the VFX fires "swallow" when a big debris chunk falls
#          through the horizon (every second debris cycle) -> the body is yanked upward toward
#          the hole, arms flail, then floats back down.  marker 2 "gulp" -> orb flash + ring.
#   warp   (trigger "jump", 0.8 s): jumping stretches the body up toward the singularity.
#          marker 1 "warp" -> jets flare, sparks from the feet.
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("EventHorizon")
LIFT = 2.0


def hold(clip, f):
    """Freeze every animated channel at frame f with a CONSTANT key (next key = hard snap)."""
    for fc in clip.all_curves():
        k = fc.keyframe_points.insert(f, fc.evaluate(f))
        k.interpolation = "CONSTANT"
        fc.update()


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames


def drift(sway, yaw, y=0.0):
    """Zero-g float. sway -1..1 = slow roll left .. right."""
    return dict(
        root=(-4, yaw, 3 * sway),
        root_pos=(0.1 * sway, LIFT + y, 0),
        neck=(-6, -4 * sway, -2 * sway),
        rs=(16 + 4 * sway, 0, 34 + 4 * sway),
        ls=(12 - 4 * sway, 0, -30 + 4 * sway),
        rh=(-8 + 4 * sway, 0, 7),
        lh=(5 - 4 * sway, 0, -5),
    )


idle.pose(0, drift(-1, -10))
idle.key(10, root_pos=(-0.06, LIFT + 0.08, 0), rs=(20, 0, 40), ls=(16, 0, -38), rh=(-12, 0, 8), lh=(8, 0, -6))
# the head lifts first to look at the hole, the torso follows the turn
idle.key(20, neck=(22, 6, 0), root=(-2, 2, 1), rs=(26, 0, 46), ls=(24, 0, -44), root_pos=(0, LIFT + 0.12, 0))
idle.key(26, neck=(26, 4, 0), root=(-1, 8, 0))
# anticipation: coil (dip, tuck arms, fold legs)
idle.key(36, ease="IN", root=(-12, 10, 0), root_pos=(0, LIFT - 0.22, 0), neck=(-12, 0, 0),
         rs=(10, 0, 14), ls=(10, 0, -14), rh=(24, 0, 4), lh=(30, 0, -4))
# REACH: arms shoot up to the orb, body stretched (legs lag 3 f, head lags 2 f)
idle.key(44, ease="BACK", root=(8, 12, 0), root_pos=(0, LIFT + 0.55, 0), rs=(176, -6, 12), ls=(176, 6, -12))
idle.marker(44, "reach")
idle.key(46, ease="BACK", neck=(38, 0, 0))
idle.key(47, ease="OUT", rh=(-6, 0, 3), lh=(-2, 0, -3))
idle.key(52, root=(5, 16, 2), rs=(170, -4, 16), ls=(172, 4, -10), neck=(32, 2, 0), root_pos=(0, LIFT + 0.48, 0))
# spaghettified: dragged up in a slow spiral, legs drift apart
idle.key(68, ease="LINEAR", root=(7, 32, -3), root_pos=(0.05, LIFT + 0.7, 0), neck=(36, -4, 4),
         rs=(174, -8, 8), ls=(170, 8, -18), rh=(-10, 0, 9), lh=(-4, 0, -10))
idle.key(84, ease="LINEAR", root=(9, 45, 2), root_pos=(-0.03, LIFT + 0.85, 0), neck=(40, 3, -3),
         rs=(178, -4, 14), ls=(176, 4, -12), rh=(-6, 0, 12), lh=(-12, 0, -7))
idle.key(86, ease="EXPO", root=(10, 47, 2), root_pos=(-0.03, LIFT + 0.88, 0), neck=(44, 3, -3))
hold(idle, 86)
idle.marker(86, "dilate")
# time dilation: almost nothing moves for 14 frames (a 2-degree creep)
idle.key(99, ease="LINEAR", root=(11, 48, 2), neck=(45, 3, -3), rs=(179, -4, 15))
hold(idle, 99)
# CRUSH: snap into a ball
idle.key(100, ease="CONST", root=(-34, 50, 0), root_pos=(0, LIFT + 0.4, 0), neck=(-36, 0, 0),
         rs=(58, -18, 8), ls=(58, 18, -8), rh=(98, 0, 10), lh=(98, 0, -10))
idle.marker(100, "crush")
idle.key(103, ease="EXPO", root=(-38, 51, 0), root_pos=(0, LIFT + 0.3, 0), neck=(-40, 0, 0),
         rs=(54, -22, 4), ls=(54, 22, -4), rh=(104, 0, 6), lh=(104, 0, -6))
idle.key(110, root=(-40, 52, 2), root_pos=(0, LIFT + 0.26, 0), neck=(-42, 2, 0),
         rs=(52, -24, 2), ls=(52, 24, -2), rh=(106, 0, 5), lh=(106, 0, -5))
idle.key(116, ease="IN", root=(-42, 52, 0), root_pos=(0, LIFT + 0.22, 0), neck=(-44, 0, 0),
         rs=(50, -26, 0), ls=(50, 26, 0), rh=(108, 0, 4), lh=(108, 0, -4))
# FLARE: starfish burst
idle.key(118, ease="BACK", root=(14, 54, 0), root_pos=(0, LIFT + 0.55, 0), neck=(24, 0, 0),
         rs=(14, 0, 100), ls=(14, 0, -100), rh=(-14, 0, 30), lh=(-14, 0, -30))
idle.marker(118, "flare")
idle.key(122, neck=(34, 0, 0), rs=(8, 0, 112), ls=(8, 0, -112), rh=(-18, 0, 34), lh=(-18, 0, -34))
idle.key(126, root=(10, 50, -2), root_pos=(0, LIFT + 0.5, 0), rh=(-10, 0, 26), lh=(-12, 0, -24))
# follow-through: sink back, limbs drift home with lags (arms first, then legs, head last)
idle.key(140, root=(-2, 30, 2), root_pos=(0.04, LIFT + 0.2, 0), rs=(30, 0, 70), ls=(26, 0, -62))
idle.key(146, rh=(-12, 0, 14), lh=(2, 0, -12), neck=(14, -2, 2))
idle.key(156, root=(-4, 8, 3), root_pos=(0.08, LIFT + 0.04, 0), rs=(20, 0, 44), ls=(14, 0, -36), neck=(-2, -4, -2))
idle.key(166, rh=(-9, 0, 8), lh=(6, 0, -5))
idle.loop()
idle.noise("root", 1, 2.5, cycles=(1, 2, 3), seed=31)
idle.noise("root", 2, 1.5, cycles=(1, 2, 5), seed=32)
idle.noise("root", 1, 0.05, cycles=(2, 3, 4), seed=33, loc=True)
idle.noise("rh", 0, 4, cycles=(2, 3, 5), seed=34)
idle.noise("lh", 0, 4, cycles=(2, 4, 5), seed=35)
idle.noise("rs", 2, 3, cycles=(2, 3, 4), seed=36)
idle.noise("ls", 2, 3, cycles=(2, 3, 5), seed=37)
idle.noise("neck", 1, 3, cycles=(1, 3, 4), seed=38)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2
WY = 1.8


def reach(f, side):
    s = 1 if side == "R" else -1  # +1: the right arm reaches forward, right leg trails back
    walk.key(f, root=(-20, -6 * s, 3 * s), root_pos=(0, WY + 0.05, 0.05),
             neck=(14, 5 * s, 0),
             rs=(80 + 50 * s, -10, 24), ls=(80 - 50 * s, 10, -24),
             rh=(-8 - 12 * s, 0, 6), lh=(-8 + 12 * s, 0, -6))


def pull(f, side):
    s = 1 if side == "R" else -1  # the reaching arm sweeps down and out: the body surges
    walk.key(f, ease="EXPO", root=(-24, -2 * s, 1 * s), root_pos=(0, WY + 0.12, -0.15),
             neck=(18, 2 * s, 0),
             rs=(52 + 40 * s, 0, 44 + 10 * s), ls=(52 - 40 * s, 0, -44 + 10 * s),
             rh=(-12 - 8 * s, 0, 5), lh=(-12 + 8 * s, 0, -5))
    walk.marker(f, "stroke", side)


def glide(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, root=(-18, 3 * s, -2 * s), root_pos=(0, WY - 0.03, 0),
             neck=(12, -2 * s, 0),
             rs=(40 + 6 * s, 0, 36), ls=(40 - 6 * s, 0, -36),
             rh=(-10 + 6 * s, 0, 5), lh=(-10 - 6 * s, 0, -5))


reach(0, "R")
pull(2, "R")
glide(h * 0.6, "R")
reach(h, "L")
pull(h + 2, "L")
glide(h * 1.6, "L")
walk.loop()

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))

gulp = A.clip("gulp", seconds=1.0, trigger="swallow", mode="add", blend_in=0.03, blend_out=0.25)
gulp.pose(0, Z)
gulp.key(2, ease="EXPO", root=(10, 0, 0), root_pos=(0, 0.45, 0), neck=(30, 0, 0),
         rs=(60, 0, 30), ls=(50, 0, -36), rh=(-10, 0, 6), lh=(-6, 0, -6))
gulp.marker(2, "gulp")
gulp.key(7, root=(6, 6, 2), root_pos=(0, 0.55, 0), neck=(22, 8, 0), rs=(40, 0, 40), ls=(60, 0, -24))
gulp.key(15, root=(-4, -2, -1), root_pos=(0, 0.12, 0), neck=(-6, -4, 0), rs=(8, 0, 10), ls=(10, 0, -8),
         rh=(6, 0, 2), lh=(8, 0, -2))
gulp.pose(30, Z)

warp = A.clip("warp", seconds=0.8, trigger="jump", mode="add", blend_in=0.02, blend_out=0.25)
warp.pose(0, Z)
warp.key(1, ease="BACK", root=(6, 0, 0), root_pos=(0, 0.3, 0), neck=(26, 0, 0),
         rs=(130, 0, -8), ls=(130, 0, 8), rh=(-6, 0, -4), lh=(-6, 0, 4))
warp.marker(1, "warp")
warp.key(8, root=(4, 0, 0), root_pos=(0, 0.25, 0), neck=(18, 0, 0), rs=(100, 0, 6), ls=(104, 0, -6))
warp.key(15, root=(-2, 0, 0), root_pos=(0, 0.05, 0), neck=(-4, 0, 0), rs=(20, 0, 8), ls=(20, 0, -8))
warp.pose(24, Z)

A.lift = LIFT

# preview framing for a levitating set (local helper, lib.py untouched)
_aim0 = lib._aim
lib._aim = lambda cam, loc, target=(0, 0, 2.6): _aim0(cam, (loc[0], loc[1], loc[2] + 1.6), (target[0], target[1], target[2] + 1.6))
A.cam.data.ortho_scale = 11


def keysheet(clip, frames, views=("front", "side", "3/4")):
    """Local helper (lib.py untouched): renders the exact frames given (markers / key poses)."""
    rig, sc, cam = A.rig, A.scene, A.cam
    rig.animation_data.action = clip.action
    marks = {}
    for m in clip.action.pose_markers:
        marks.setdefault(m.frame, []).append(m.name[3:])
    tmp = tempfile.mkdtemp(prefix="glitchkeys_")
    tiles = []
    for v in views:
        lib._aim(cam, lib.VIEWS[v])
        for f in frames:
            sc.frame_set(int(f))
            fp = os.path.join(tmp, f"{v.replace('/', '')}_{int(f):04d}.png")
            sc.render.filepath = fp
            bpy.ops.render.render(write_still=True)
            mk = marks.get(int(f))
            tiles.append((fp, f"{v} f{int(f)}" + (f" [{','.join(mk)}]" if mk else "")))
    dst = os.path.join(lib.PREVIEW_DIR, f"{A.id}_{clip.name}_keys.png")
    cmd = ["montage"]
    for fp, label in tiles:
        cmd += ["-label", label, fp]
    cmd += ["-tile", f"{len(frames)}x{len(views)}", "-geometry", "+2+2", "-background", "#111",
            "-fill", "#ddd", "-pointsize", "13", "-title", f"{A.id} / {clip.name} key poses", dst]
    subprocess.run(cmd, check=True, capture_output=True)
    print("[preview]", dst)


A.finish()
if os.environ.get("KEYS", "1") == "1":
    keysheet(idle, [0, 20, 36, 44, 52, 84, 92, 100, 110, 118, 122, 140, 156])
