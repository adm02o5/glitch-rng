# Mainframe (1 in 125,000, LEGENDARY): "The machine that runs the machines."
# VFX (AurasHigh.lua A.Mainframe): five SRV server racks orbiting at chest height (blinking LED rows,
# status lights, LOAD readouts), cables from every rack into a hub on the back with data pulses
# riding them, data uplink columns above the racks, a MAINFRAME://ONLINE title, a ground sigil,
# floor squares, back sparks and a cyan light.
#
# CONCEPT: the body IS the operator-machine. GROUNDED (A.lift = 0: a mainframe is heavy iron bolted
# to the floor). Everything moves like servos: fast EXPO starts that stop dead with a tiny BACK
# overshoot, the torso following the head a few frames late, CONST micro-twitches when it "thinks".
#
# IDLE (5.0 s = 150 f; the cable data pulses run on Sync.phase(bus, 5.0) * 3 = 3 waves per loop).
#   Markers -> what the VFX does:
#   0-10    stand-by stance: feet wide, arms a little forward, fists down, chest proud
#   12      "scan" "L"   head servo snaps 38 deg left (EXPO), torso follows 4 f later with an
#                        overshoot. VFX: the racks on the LEFT half light every LED white-cyan,
#                        status lights blaze, a spark puff leaves the head.
#   32      "scan" "R"   the same to the right (racks on the right half flash).
#   50      head + torso snap back to centre (servo settle)
#   56-60   arms rise to a keyboard before the chest, head tilts down at it
#   62..86  "type" "R"/"L" every 3 f: alternate fist taps (EXPO). VFX: each tap rewrites the LED
#                        row of the next rack (round robin), its status light pops, the hub sparks.
#   88-96   anticipation: the right fist climbs overhead, torso leans back and twists left, the
#                        right knee... (R6: the whole right leg) lifts forward, head looks up at the fist
#   98      "exec"       EXPO: fist hammers down + the right foot STOMPS, torso pitches forward,
#                        head 2 f later. VFX: EXECUTE: all five data pulses fire down their cables at
#                        once, the racks kick outward, the uplink columns shoot to 3x height, a cyan
#                        shock ring rolls out of the right foot, sigil disc + light flash, title
#                        "MAINFRAME://EXECUTE".
#   100-108 CONST aftershock jitter (servo chatter)
#   112     "vent"       the shoulders drop, head bows, arms hang: an exhale. VFX: a burst of
#                        coolant steam + sparks from the back hub.
#   124     head servo comes back up (EXPO), arms return to stand-by by 140.
#
# WALK (one stride): a heavy robotic march. Straight stiff legs that clunk into contact (EXPO), arms
#   swing rigid and opposite with fists, the torso yaws with the step but the head is GYRO-
#   STABILISED (counter-rotates so the face keeps looking straight ahead), a tiny servo nod on
#   every contact. VFX: the free "step" events -> a small shock ring from that foot, the racks dip.
#
# REACTIONS:
#   overload (trigger "overload", 2.0 s, replace): the VFX fires "overload" every 15-22 s while
#            standing still (LEDs go red, title OVERLOAD). The body glitches: CONST twitches of head
#            and arms (f2-14), then powers down. marker 18 "down" -> every LED, status light,
#            uplink and the light go dark, the head slumps, arms hang limp. marker 36 "reboot" ->
#            the body snaps upright with the arms flung out a touch (EXPO), white flash, LEDs come
#            back green, title "REBOOT OK".
#   thud     (trigger "land", 0.6 s, add): the heavy iron lands: torso pitches forward, arms flare,
#            head bobs. (VFX handles "land" itself: big shock ring + rack dip.)
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("Mainframe")

# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=5.0)  # 150 frames


def stand(yaw=0.0, nod=0.0):
    """Stand-by stance: feet wide, arms a bit forward and out, chest proud."""
    return dict(
        root=(1, yaw, 0),
        root_pos=(0, 0, 0),
        neck=(-2 + nod, 0, 0),
        rs=(9, 0, 9),
        ls=(9, 0, -9),
        rh=(0, -yaw * 0.5, 4),
        lh=(0, -yaw * 0.5, -4),
    )


idle.pose(0, stand())
idle.key(6, root=(1.5, 0, 0), rs=(10, 0, 10), ls=(10, 0, -10))  # a "breath" of the cooling fans
# SCAN LEFT: head servo first (EXPO, stops dead), torso 4 f later with overshoot
idle.key(10, ease="CONST", neck=(-2, 0, 0))
idle.key(12, ease="EXPO", neck=(-1, 38, 2))
idle.marker(12, "scan", "L")
idle.key(14, ease="BACK", neck=(-1, 41, 2))
idle.key(13, root=(1, 0, 0))
idle.key(17, ease="EXPO", root=(1, 12, 0), rh=(0, -6, 4), lh=(0, -6, -4), rs=(8, 0, 11), ls=(11, 0, -8))
idle.key(19, ease="BACK", root=(1, 14, 0.5))
idle.key(24, root=(1, 11, 0), neck=(-1, 27, 1))
# processing tick (CONST micro twitch)
idle.key(27, ease="CONST", neck=(-4, 27, 1))
idle.key(28, ease="CONST", neck=(-1, 27, 1))
# SCAN RIGHT: head swings across (EXPO), torso follows
idle.key(30, ease="CONST", neck=(-1, 27, 1), root=(1, 11, 0))
idle.key(32, ease="EXPO", neck=(-1, -50, -2))
idle.marker(32, "scan", "R")
idle.key(34, ease="BACK", neck=(-1, -53, -2))
idle.key(33, root=(1, 11, 0), rs=(8, 0, 11), ls=(11, 0, -8))
idle.key(37, ease="EXPO", root=(1, -12, 0), rh=(0, 6, 4), lh=(0, 6, -4), rs=(11, 0, 8), ls=(8, 0, -11))
idle.key(39, ease="BACK", root=(1, -14, -0.5))
idle.key(44, root=(1, -11, 0), neck=(-1, -27, -1))
# back to centre: head first, torso 3 f later
idle.key(48, ease="CONST", neck=(-1, -27, -1), root=(1, -11, 0))
idle.key(50, ease="EXPO", neck=(-3, 0, 0))
idle.key(51, root=(1, -11, 0))
idle.key(54, ease="EXPO", root=(0, 0, 0), rh=(0, 0, 4), lh=(0, 0, -4), rs=(9, 0, 9), ls=(9, 0, -9))
# TYPE: arms rise to a keyboard before the chest, head tilts down at it
idle.key(60, ease="BACK", rs=(52, 0, -2), ls=(52, 0, 2), neck=(-16, 0, 0), root=(-3, 0, 0))
taps = [62, 65, 68, 71, 74, 77, 80, 83, 86]
for i, f in enumerate(taps):
    right = i % 2 == 0
    up, down = 54, 44
    if right:
        idle.key(f, ease="EXPO", rs=(down, 0, -3), ls=(up, 0, 2))
    else:
        idle.key(f, ease="EXPO", rs=(up, 0, -2), ls=(down, 0, 3))
    idle.marker(f, "type", "R" if right else "L")
# head reads the screen: tiny servo ticks left/right while typing
idle.key(66, ease="CONST", neck=(-16, 6, 0))
idle.key(74, ease="CONST", neck=(-15, -5, 0))
idle.key(82, ease="CONST", neck=(-17, 2, 0))
idle.key(86, root=(-3, 0, 0))
# EXEC anticipation: the right fist climbs overhead, the right leg lifts, torso leans back + twists
idle.key(90, ease="OUT", rs=(120, 0, 12), ls=(30, 0, -14), neck=(4, -4, 0), root=(2, 5, 0), rh=(0, 0, 4))
idle.key(96, ease="IN", rs=(168, 0, 10), ls=(14, 0, -20), neck=(16, -6, 0), root=(6, 9, 1),
         rh=(32, 0, 5), lh=(0, 0, -5))
# EXEC: hammer down + stomp (head 2 f later)
idle.key(98, ease="EXPO", rs=(46, 0, 6), ls=(-14, 0, -24), root=(-9, -4, 0), rh=(0, 0, 4), lh=(0, 0, -4))
idle.marker(98, "exec")
idle.key(100, ease="EXPO", neck=(-14, 2, 0))
# aftershock: servo chatter (CONST)
idle.key(101, ease="CONST", root=(-7, -3, 0), rs=(50, 0, 7))
idle.key(103, ease="CONST", root=(-8, -5, 0.6), rs=(44, 0, 5), neck=(-12, 3, 1))
idle.key(105, ease="CONST", root=(-7, -3, -0.6), rs=(48, 0, 7), neck=(-13, 1, -1))
idle.key(107, ease="CONST", root=(-7.5, -4, 0), rs=(46, 0, 6), neck=(-12, 2, 0))
idle.key(108, root=(-7.5, -4, 0), ls=(-10, 0, -20))
# VENT: exhale, shoulders drop, head bows, arms hang
idle.key(112, ease="OUT", root=(-5, -1, 0), neck=(-22, 0, 0), rs=(2, 0, 5), ls=(2, 0, -5))
idle.marker(112, "vent")
idle.key(120, root=(-4, 0, 0), neck=(-24, 0, 1), rs=(0, 0, 4), ls=(0, 0, -4))
# reactivate: head servo comes back up, then torso, then arms
idle.key(122, ease="CONST", neck=(-24, 0, 1))
idle.key(124, ease="EXPO", neck=(-1, 0, 0))
idle.key(126, ease="BACK", neck=(-3, 0, 0))
idle.key(128, ease="EXPO", root=(1.5, 0, 0))
idle.key(140, ease="INOUT", rs=(9, 0, 9), ls=(9, 0, -9))
idle.loop()
idle.noise("root", 1, 0.6, cycles=(1, 2, 3), seed=11)
idle.noise("rs", 2, 0.8, cycles=(2, 3, 5), seed=12)
idle.noise("ls", 2, 0.8, cycles=(2, 3, 5), seed=13)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2


def contact(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, ease="EXPO",
             root=(-2, -7 * s, 0), root_pos=(0, 0, 0),
             neck=(-5, 7 * s, 0),
             rs=(-24 * s, 0, 8), ls=(24 * s, 0, -8),
             rh=(22 * s, 7 * s, 3), lh=(-22 * s, 7 * s, -3))


def settle(f, side):
    s = 1 if side == "R" else -1
    # 2 f after contact: tiny servo nod and arm stop (BACK = mechanical overshoot)
    walk.key(f, ease="BACK", neck=(-2, 6 * s, 0), rs=(-21 * s, 0, 8), ls=(21 * s, 0, -8))


def passing(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, root=(-1, 0, -1.5 * s), root_pos=(0, 0.13, 0),
             neck=(-3, 0, 0), rs=(0, 0, 9), ls=(0, 0, -9),
             rh=(-4 * s, 0, 3), lh=(4 * s, 0, -3))


contact(0, "R")
settle(2, "R")
passing(h * 0.5, "R")
contact(h, "L")
settle(h + 2, "L")
passing(h * 1.5, "L")
walk.loop()

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))

ov = A.clip("overload", seconds=2.0, trigger="overload", mode="replace", blend_in=0.05, blend_out=0.3)
ov.pose(0, stand())
# glitch twitches (CONST): head, then the right arm, then both
ov.key(2, ease="CONST", neck=(6, -24, 9))
ov.key(4, ease="CONST", neck=(-10, 14, -6), rs=(40, 0, 30))
ov.key(6, ease="CONST", neck=(2, -6, 4), rs=(6, 0, 12), root=(2, -6, 2))
ov.key(8, ease="CONST", ls=(46, 0, -34), root=(-2, 5, -2), neck=(-8, 20, -3))
ov.key(10, ease="CONST", rs=(30, 0, 24), ls=(4, 0, -10), neck=(8, -16, 6))
ov.key(12, ease="CONST", rs=(10, 0, 9), root=(3, -3, 1), neck=(-4, 6, -2))
ov.key(14, ease="CONST", neck=(4, -10, 3), ls=(10, 0, -9), root=(1, 0, 0))
# power down: head slumps, arms go limp, torso folds a little
ov.key(18, ease="OUT", neck=(-34, 4, 6), rs=(-2, 0, 3), ls=(-2, 0, -3), root=(-8, 0, -2))
ov.marker(18, "down")
ov.key(30, neck=(-38, 5, 8), root=(-9, 0, -2.5), rs=(-3, 0, 2), ls=(-3, 0, -2))
ov.key(34, ease="CONST", neck=(-38, 5, 8), root=(-9, 0, -2.5), rs=(-3, 0, 2), ls=(-3, 0, -2))
# reboot: snap upright, arms flung out a touch
ov.key(36, ease="EXPO", root=(4, 0, 0), neck=(6, 0, 0), rs=(14, 0, 26), ls=(14, 0, -26))
ov.marker(36, "reboot")
ov.key(39, ease="BACK", neck=(-3, 0, 0))
ov.key(44, root=(1, 0, 0), rs=(10, 0, 12), ls=(10, 0, -12))
ov.pose(60, stand())

thud = A.clip("thud", seconds=0.6, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
thud.pose(0, Z)
thud.key(2, ease="EXPO", root=(-9, 0, 0), neck=(-8, 0, 0), rs=(-6, 0, 16), ls=(-6, 0, -16))
thud.key(5, ease="BACK", neck=(4, 0, 0))
thud.key(8, root=(-3, 0, 0), rs=(-2, 0, 5), ls=(-2, 0, -5))
thud.pose(18, Z)


# ------------------------------------------------------------------ floor contact
def floor_fix(clip, margin=0.0):
    """R6 has no knees: bake a per-frame root_pos y correction wherever a sole dips into the floor."""
    rig, sc = A.rig, A.scene
    rig.animation_data.action = clip.action
    lift = {}
    for f in range(clip.frames + 1):
        sc.frame_set(f)
        low = min(lib._lowest_sole(rig, "rh"), lib._lowest_sole(rig, "lh"))
        lift[f] = max(0.0, margin - low)
    if not any(v > 1e-4 for v in lift.values()):
        return
    if clip.looping:
        lift[clip.frames] = lift[0]
    for fc in clip._curves('pose.bones["root"].location'):
        if fc.array_index != 1:
            continue
        vals = [(f, fc.evaluate(f) + lift[f]) for f in range(clip.frames + 1)]
        fc.keyframe_points.clear()
        for f, v in vals:
            k = fc.keyframe_points.insert(f, v)
            k.interpolation = "LINEAR"
        fc.update()


def plant(clip):
    """Keep the legs vertical under a pitching torso (servo stance): bake hip x = authored - root x
    per frame, so the authored leg moves (the stomp) read on top of a planted stance."""
    rx = [fc for fc in clip._curves('pose.bones["root"].rotation_euler') if fc.array_index == 0][0]
    for j in ("rh", "lh"):
        for fc in clip._curves(f'pose.bones["{j}"].rotation_euler'):
            if fc.array_index != 0:
                continue
            vals = [(f, fc.evaluate(f) - rx.evaluate(f)) for f in range(clip.frames + 1)]
            fc.keyframe_points.clear()
            for f, v in vals:
                k = fc.keyframe_points.insert(f, v)
                k.interpolation = "LINEAR"
            fc.update()


for c in (idle, ov):
    plant(c)
for c in (idle, walk, ov):
    floor_fix(c)


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


A.lift = 0
A.finish()
if os.environ.get("KEYS", "1") == "1":
    keysheet(idle, [0, 12, 19, 34, 39, 60, 74, 96, 98, 103, 116, 126])
    keysheet(ov, [0, 4, 8, 12, 24, 36, 44])
