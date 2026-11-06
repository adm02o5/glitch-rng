# Cyber Seraph (1 in 4,444,444, MYTHIC tier): "An angel compiled from light."
# VFX (AurasHigh.lua A.CyberSeraph): six neon wings on the back, a halo of code over the head,
# a sun disc behind it, a light pillar into the sky, feather pixels falling, a ground sigil.
#
# CONCEPT: a seraph that LEVITATES (A.lift = 2 studs, legs dangle with pointed toes). Its arms ARE
# the wing muscles: the VFX reads the elevation / forward sweep of each arm every frame and the
# three wings on that side follow it (upper wing first, lower wings lag = overlapping action), so
# every flap in this file is a real wing beat in game. The 6 s idle is a little sermon:
# two wing beats, a gaze down at the mortals, then it gathers light in prayer and RADIATES it.
#
# IDLE (6.0 s = 180 f; the sigil / light breathing and the halo spin share this period through
#   Sync.phase(bus, 6)). Markers -> what the VFX does:
#   0-20    serene hover, chest proud, arms low and open (palms forward), legs dangling apart
#   26      upstroke anticipation: arms lift high, body dips, head dips (wings rise with them)
#   32      "flap"          EXPO downstroke: arms slam down, body surges up 0.4 studs, chest out,
#                           head lags 2 f, legs lag 4 f.  VFX: the wings beat down (arm-driven),
#                           a downdraft ring of light races over the REAL ground under the body,
#                           a puff of feather pixels is shed from the wings, the halo light pops.
#   44      follow-through: arms bounce back up a little, body peaks
#   70-75   "flap" "soft"   a smaller beat led by the left arm (asymmetric), smaller ring + puff
#   96      gaze: head turns right and down to look at the world below, torso follows f 100
#   112     "gather"        hands meet in prayer before the chest, head bows, legs fold up,
#                           body sinks (wings wrap FORWARD around the body - arm-driven).
#                           VFX: the halo's code glyphs are pulled in tight and the ring shrinks,
#                           light drains (dim), sparks stream INTO the chest while held.
#   118-130 trembling build-up while the light charges
#   132     "radiate"       BACK: arms fling up and out into a V, back arches, head thrown back
#                           (lags 2 f), legs trail apart (lag 4 f), body rises to +0.6.
#                           VFX: halo flash + ring pops wide, a nova of light feathers from the
#                           chest, the sky pillar flares wide, a big ground ring, root light surge,
#                           wings fully spread (arm-driven).
#   142-180 overshoot, then the arms float down and the body descends back to rest
#
# WALK (one stride): a forward glide 1.8 studs up, body pitched 22 deg, arms swept back like
#   folded wings with one beat per stride: arms lift outward at the start, downstroke at f 4.
#   4 "glide"  -> a small feather puff from the wings + soft ground ring under the body.
#   Legs trail together in a slow scissor (the right one leads at frame 0).
#
# REACTIONS (one-shots):
#   soar      (trigger "jump", 0.9 s, add): a huge wing beat. marker 3 "flap" "big" -> big ring + puff.
#   recompile (trigger "recompile", 1.0 s, add): the VFX fires "recompile" every 11-17 s while
#             idle: the angel's code glitches - the wings flicker out and the halo prints garbage.
#             The body CONST-snaps through broken poses (glitch frames), then shakes it off.
#             marker 2 "glitch" -> wing feathers flicker off at random, halo glyphs = garbage;
#             marker 22 "rebuild" -> the wings re-materialise with a sparkle burst + halo flash.
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("CyberSeraph")
LIFT = 2.0


def hold(clip, f):
    """Freeze every animated channel at frame f with a CONSTANT key (next key = hard snap)."""
    for fc in clip.all_curves():
        k = fc.keyframe_points.insert(f, fc.evaluate(f))
        k.interpolation = "CONSTANT"
        fc.update()


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames


def rest(sway=0.0, y=0.0):
    """Serene hover. sway -1..1 rolls the weight a touch left .. right."""
    return dict(
        root=(4, 3 * sway, 2 * sway),
        root_pos=(0.05 * sway, LIFT + y, 0),
        neck=(9, -3 * sway, -2 * sway),
        rs=(-9, -12, 30 + 3 * sway),
        ls=(-7, 12, -28 + 3 * sway),
        rh=(-7, 0, 4),
        lh=(5, 0, -3),
    )


idle.pose(0, rest(-1, 0.1))
idle.key(14, root_pos=(0, LIFT + 0.2, 0), rs=(-8, -12, 40), ls=(-6, 12, -38), neck=(11, 0, 0))
# FLAP 1 - upstroke anticipation: arms rise high, the body dips and hunches, head dips
idle.key(26, ease="IN", root=(-7, 0, 0), root_pos=(0, LIFT - 0.06, 0), neck=(-6, 0, 0),
         rs=(-14, 0, 128), ls=(-14, 0, -128), rh=(8, 0, 4), lh=(14, 0, -3))
# downstroke: arms slam down, the body surges up (EXPO), head lags 2 f, legs lag 4 f
idle.key(32, ease="EXPO", root=(9, 0, 0), root_pos=(0, LIFT + 0.38, 0),
         rs=(-26, -8, 14), ls=(-26, 8, -14))
idle.marker(32, "flap")
idle.key(34, ease="EXPO", neck=(15, 0, 0))
idle.key(36, ease="OUT", rh=(-16, 0, 6), lh=(-10, 0, -5))
# follow-through: arms bounce back up, body peaks, head settles
idle.key(44, root=(6, -2, -1), root_pos=(0, LIFT + 0.44, 0), rs=(-10, -10, 50), ls=(-10, 10, -46),
         neck=(10, 2, 0))
idle.key(48, rh=(-6, 0, 4), lh=(4, 0, -3))
idle.key(60, root=(4, 2, 1), root_pos=(0.03, LIFT + 0.26, 0), rs=(-9, -12, 36), ls=(-7, 12, -34),
         neck=(8, -2, -1))
# FLAP 2 (smaller, led by the LEFT arm: it rises 2 f earlier and higher)
idle.key(68, ease="IN", ls=(-10, 0, -100))
idle.key(70, ease="IN", root=(-3, 2, -1), root_pos=(0.03, LIFT + 0.14, 0), rs=(-10, 0, 88),
         neck=(1, 0, 0), rh=(4, 0, 4), lh=(9, 0, -3))
idle.key(75, ease="EXPO", root=(6, 0, 1), root_pos=(0.02, LIFT + 0.34, 0), rs=(-22, -8, 18),
         ls=(-22, 8, -16))
idle.marker(75, "flap", "soft")
idle.key(77, ease="EXPO", neck=(12, 0, 0))
idle.key(79, ease="OUT", rh=(-12, 0, 5), lh=(-6, 0, -4))
idle.key(88, root=(4, 0, 2), root_pos=(0.05, LIFT + 0.3, 0), rs=(-9, -12, 38), ls=(-8, 12, -36),
         neck=(9, 0, 0), rh=(-7, 0, 4), lh=(5, 0, -3))
# gaze: the head turns right and down to look at the world below; the torso follows 4 f later
idle.key(96, neck=(-16, -26, -6))
idle.key(100, root=(2, -9, -2), rs=(-6, -12, 34), ls=(-4, 12, -40))
idle.key(106, neck=(-19, -30, -7), root_pos=(0.05, LIFT + 0.22, 0))
# GATHER: hands meet in prayer before the chest, head bows, legs fold up, body sinks (BACK settle)
idle.key(112, ease="BACK", root=(-10, 0, 0), root_pos=(0, LIFT - 0.02, 0), neck=(-22, 0, 0),
         rs=(62, 34, 4), ls=(62, -34, -4), rh=(26, 0, 3), lh=(32, 0, -3))
idle.marker(112, "gather")
# trembling build-up while the light charges (head lifts a hair, body rises slowly)
idle.key(118, root=(-12, 1, 0), root_pos=(0, LIFT - 0.06, 0), neck=(-25, 0, 0), rs=(66, 35, 4),
         ls=(66, -35, -4), rh=(30, 0, 3), lh=(36, 0, -3))
idle.key(124, root=(-11, -1, 0), root_pos=(0, LIFT + 0.02, 0), neck=(-20, 0, 0), rs=(64, 36, 4),
         ls=(64, -36, -4))
idle.key(130, ease="IN", root=(-14, 0, 0), root_pos=(0, LIFT - 0.08, 0), neck=(-27, 0, 0),
         rs=(70, 36, 4), ls=(70, -36, -4), rh=(34, 0, 3), lh=(40, 0, -3))
# RADIATE: arms fling up into a V, back arches; head lags 2 f, legs lag 4 f
idle.key(132, ease="BACK", root=(13, 0, 0), root_pos=(0, LIFT + 0.6, 0), rs=(-12, 0, 150),
         ls=(-12, 0, -150))
idle.marker(132, "radiate")
idle.key(134, ease="BACK", neck=(30, 0, 0))
idle.key(136, ease="OUT", rh=(-20, 0, 11), lh=(-15, 0, -11))
# overshoot hold, then the light ebbs: arms float down, body descends (arms first, legs, head last)
idle.key(142, root=(11, 0, 0), rs=(-10, 0, 140), ls=(-10, 0, -142), root_pos=(0, LIFT + 0.66, 0))
idle.key(148, neck=(26, 2, 0), rh=(-14, 0, 8), lh=(-10, 0, -8))
idle.key(156, root=(7, -2, 1), root_pos=(0, LIFT + 0.45, 0), rs=(-12, -6, 80), ls=(-10, 6, -76))
idle.key(162, neck=(14, 3, 1), rh=(-9, 0, 5), lh=(3, 0, -4))
idle.key(170, root=(5, 3, 2), root_pos=(-0.03, LIFT + 0.2, 0), rs=(-9, -12, 38), ls=(-7, 12, -34))
idle.loop()
idle.noise("root", 1, 2.5, cycles=(1, 2, 3), seed=41)
idle.noise("root", 2, 1.2, cycles=(1, 2, 5), seed=42)
idle.noise("root", 1, 0.04, cycles=(2, 3, 4), seed=43, loc=True)
idle.noise("neck", 1, 2.5, cycles=(1, 3, 4), seed=44)
idle.noise("rh", 0, 3, cycles=(2, 3, 5), seed=45)
idle.noise("lh", 0, 3, cycles=(2, 4, 5), seed=46)
idle.noise("rs", 2, 2, cycles=(2, 3, 4), seed=47)
idle.noise("ls", 2, 2, cycles=(2, 3, 5), seed=48)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2
WY = LIFT - 0.2

# one wing beat per stride: up at 0, downstroke 4, glide through the rest
walk.key(0, ease="IN", root=(-20, -3, 1), root_pos=(0, WY - 0.05, 0), neck=(16, 3, 0),
         rs=(-30, 0, 70), ls=(-30, 0, -70), rh=(-14, 0, 4), lh=(-26, 0, -4))
walk.key(4, ease="EXPO", root=(-24, 0, 0), root_pos=(0, WY + 0.14, 0), rs=(-52, 0, 30), ls=(-52, 0, -30))
walk.marker(4, "glide")
walk.key(6, ease="EXPO", neck=(20, 0, 0))
walk.key(7, ease="OUT", rh=(-24, 0, 5), lh=(-16, 0, -4))
walk.key(h, root=(-22, 3, -1), root_pos=(0, WY + 0.08, 0), neck=(18, -3, 0),
         rs=(-50, 0, 40), ls=(-50, 0, -40), rh=(-26, 0, 4), lh=(-14, 0, -4))
walk.key(h + 4, root=(-21, 0, 0), root_pos=(0, WY - 0.02, 0), rs=(-40, 0, 56), ls=(-40, 0, -56),
         neck=(16, 0, 0), rh=(-20, 0, 4), lh=(-20, 0, -4))
walk.loop()

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))

soar = A.clip("soar", seconds=0.9, trigger="jump", mode="add", blend_in=0.03, blend_out=0.25)
soar.pose(0, Z)
soar.key(2, ease="IN", root=(-6, 0, 0), root_pos=(0, 0.02, 0), neck=(-8, 0, 0), rs=(0, 0, 80), ls=(0, 0, -80),
         rh=(10, 0, 0), lh=(10, 0, 0))
soar.key(5, ease="EXPO", root=(10, 0, 0), root_pos=(0, 0.45, 0), neck=(14, 0, 0), rs=(-14, 0, -10),
         ls=(-14, 0, 10), rh=(-14, 0, 4), lh=(-14, 0, -4))
soar.marker(5, "flap", "big")
soar.key(12, root=(6, 0, 0), root_pos=(0, 0.35, 0), neck=(10, 0, 0), rs=(-4, 0, 14), ls=(-4, 0, -14))
soar.key(18, root=(-2, 0, 0), root_pos=(0, 0.08, 0), neck=(-2, 0, 0), rs=(0, 0, 4), ls=(0, 0, -4),
         rh=(4, 0, 0), lh=(4, 0, 0))
soar.pose(27, Z)

rec = A.clip("recompile", seconds=1.0, trigger="recompile", mode="add", blend_in=0.02, blend_out=0.2)
rec.pose(0, Z)
hold(rec, 0)
# glitch frames: hard CONST snaps through broken poses
rec.key(2, ease="CONST", root=(-8, 14, 6), root_pos=(0.25, 0.1, 0), neck=(-20, 30, 18),
        rs=(-30, 0, -24), ls=(40, 0, 10), rh=(16, 0, -6), lh=(-10, 0, 8))
rec.marker(2, "glitch")
rec.key(4, ease="CONST", root=(6, -18, -8), root_pos=(-0.3, 0.16, 0), neck=(18, -34, -14),
        rs=(50, 0, -18), ls=(-36, 0, 22), rh=(-14, 0, 8), lh=(18, 0, -6))
rec.key(6, ease="CONST", root=(-4, 8, -2), root_pos=(0.12, 0.04, 0), neck=(-28, 12, 6),
        rs=(-8, 0, -30), ls=(-8, 0, 30), rh=(22, 0, 0), lh=(22, 0, 0))
rec.key(9, ease="CONST", root=(4, -6, 4), root_pos=(-0.08, 0.1, 0), neck=(10, -18, -10),
        rs=(30, 0, -12), ls=(26, 0, 12), rh=(-6, 0, 4), lh=(4, 0, -4))
# shakes it off: a slow head shake, shoulders settle (BACK), the wings rebuild at 22
rec.key(13, ease="OUT", root=(-3, 0, 0), root_pos=(0, 0.04, 0), neck=(-10, 14, 0), rs=(4, 0, -8),
        ls=(4, 0, 8), rh=(6, 0, 0), lh=(6, 0, 0))
rec.key(17, neck=(-6, -12, 0))
rec.key(22, ease="BACK", root=(5, 0, 0), root_pos=(0, 0.12, 0), neck=(8, 2, 0), rs=(-6, 0, 18), ls=(-6, 0, -18),
        rh=(-6, 0, 0), lh=(-6, 0, 0))
rec.marker(22, "rebuild")
rec.pose(30, Z)

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
    keysheet(idle, [0, 26, 32, 44, 75, 100, 112, 130, 132, 142, 160])
