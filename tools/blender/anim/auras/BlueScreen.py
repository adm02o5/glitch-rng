# Blue Screen (1 in 7,000,000, MYTHIC): ":( Your PC ran into a problem."
# VFX (AurasHigh.lua, A.BlueScreen): six BSOD panels orbiting the chest, a giant BSOD monitor
# floating behind, Windows-style error popups, a loading spinner over the head, dead pixels.
#
# CONCEPT: the body IS the PC that crashes. A crash is grounded, so this Mythic set does NOT
# levitate. The comedy of a blue screen: busy typing -> the machine lags -> it freezes rigid in
# the infamous T-pose (frame drops, jitter) -> powers off -> reboots, confused, scratches its
# head and shrugs ":(" while error popups spawn from its hands.
#
# IDLE (6.0 s = 180 f, grounded). Markers -> what the VFX does:
#   0-22    typing on an invisible keyboard, head down, weight drifting from foot to foot
#   4/8/11/15/19 "key" R|L   a finger tap of that hand
#                        VFX: a tiny burst of blue/white pixels flies off that hand
#   21-24   right hand rises and SLAMS the enter key
#   24      "enter"          VFX: an error popup opens right in front of the player
#   28      "lag"            dropped frames: the pose freezes (CONST), 31 rewinds to an older
#                            pose, 33 jumps back (frame-skip stutter)
#                        VFX: the orbiting panels hitch backwards (rewind), pixels re-scatter
#   36-42   head rises from the keyboard, "uh oh" - shoulders hunch (anticipation)
#   46      "crash"          CONST snap into the frozen T-pose
#                        VFX: BLUE SCREEN flash (root light 7), every popup bursts open at once,
#                            the panels kick outward and STOP orbiting (frozen until "restart"),
#                            "% complete" races 0 -> 100 during the freeze, chest pixel burst
#   48-92   frozen T-pose with CONST frame jitter every 2-4 frames
#   70      "glitch"         the left arm and head drop out of the T-pose for 3 frames
#                        VFX: all dead pixels re-scatter, square burst from the chest, panels
#                            flicker
#   94      "restart"        power off: the body slumps forward (IN), head drops, arms hang
#                        VFX: lights out - root light dims, spinner/pixels/popups hidden, panels
#                            stand still until "boot"
#   114     "boot"           CONST: torso snaps upright, head pops up 2 f later (BACK)
#                        VFX: white flash, "0% complete", pixel burst, panels resume orbiting
#   120-132 confused head tilts left / right
#   136     "scratch"        right hand scratches the back of the head (fast wiggle)
#                        VFX: little pixel squares pop off the head
#   152     "shrug"          BACK: both arms out, palms forward/up, head tilts ":("
#                        VFX: an error popup spawns at EACH hand, a soft blue flash
#   170-180 back to the keyboard
#
# WALK (one stride): a stiff office-worker walk that LAGS: the left contact drops 3 frames
#   (CONST hold) and then catches up with a snap.
#   h+1 "lag"            VFX: panels hitch backwards, pixel re-scatter
#   (free "step": a puff of blue pixel squares at that foot)
#
# REACTIONS:
#   frozen (trigger "freeze", 1.1 s, replace): the VFX fires "freeze" every 6-10 s while walking:
#         the body snaps into the T-pose and SLIDES along frozen (legs locked together), jitters,
#         then thaws with a BACK settle.
#         0  "stall"   VFX: blue flash, popups burst, panels freeze
#         26 "unfreeze" VFX: panels resume, pixel puff
#   stumble (trigger "land", 0.6 s, add): landing a jump = a hard reset jolt.
#         1 "impact"   VFX: floor pixel burst + flash
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("BlueScreen")


# ------------------------------------------------------------------ local helpers
def hold(clip, f):
    """CONSTANT key on every animated channel at f (the next key becomes a hard snap)."""
    for fc in clip.all_curves():
        k = fc.keyframe_points.insert(f, fc.evaluate(f))
        k.interpolation = "CONSTANT"
        fc.update()


def plant(clip, extra=None, passes=3):
    """On every keyed frame, set the root height so the lowest sole touches the floor exactly
    (+ extra[frame] studs). Keeps each key's easing."""
    extra = extra or {}
    rig, sc = A.rig, A.scene
    rig.animation_data.action = clip.action
    frames = sorted({int(round(k.co.x)) for fc in clip.all_curves() for k in fc.keyframe_points})
    if clip.looping:
        frames = [f for f in frames if f < clip.frames]
    if not clip._curves('pose.bones["root"].location'):
        clip.key(0, root_pos=(0, 0, 0))
    ycurve = [fc for fc in clip._curves('pose.bones["root"].location') if fc.array_index == 1][0]
    for _ in range(passes):
        for f in frames:
            sc.frame_set(f)
            low = min(lib._lowest_sole(rig, "rh"), lib._lowest_sole(rig, "lh"))
            want = ycurve.evaluate(f) - low + extra.get(f, 0.0)
            kp = next((k for k in ycurve.keyframe_points if abs(k.co.x - f) < 1e-3), None)
            if kp is None:
                prev = [k for k in ycurve.keyframe_points if k.co.x < f]
                kp = ycurve.keyframe_points.insert(f, want)
                if prev:
                    kp.interpolation = prev[-1].interpolation
            dy = want - kp.co.y
            kp.co.y = want
            kp.handle_left.y += dy
            kp.handle_right.y += dy
            ycurve.update()
        if clip.looping:
            end = next((k for k in ycurve.keyframe_points if abs(k.co.x - clip.frames) < 1e-3), None)
            if end is not None:
                end.co.y = ycurve.keyframe_points[0].co.y
                ycurve.update()


def unsink(clip, tol=0.03, passes=3):
    """Any whole frame whose sole still dips below the floor gets a lifting root key."""
    rig, sc = A.rig, A.scene
    rig.animation_data.action = clip.action
    ycurve = [fc for fc in clip._curves('pose.bones["root"].location') if fc.array_index == 1][0]
    last = clip.frames if not clip.looping else clip.frames - 1
    for _ in range(passes):
        fixes = []
        for f in range(0, last + 1):
            sc.frame_set(f)
            low = min(lib._lowest_sole(rig, "rh"), lib._lowest_sole(rig, "lh"))
            if low < -tol:
                fixes.append((f, ycurve.evaluate(f) - low))
        if not fixes:
            return
        for f, v in fixes:
            prev = [k for k in ycurve.keyframe_points if k.co.x <= f]
            interp = prev[-1].interpolation if prev else "BEZIER"
            kp = ycurve.keyframe_points.insert(f, v)
            kp.interpolation = interp
        ycurve.update()


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames


def typing(sway, rh_tap=0.0, lh_tap=0.0):
    """Hunched over an invisible keyboard. sway -1..1 = weight left .. right foot.
    *_tap > 0 = that hand dips onto a key (degrees)."""
    return dict(
        root=(-6, 3 * sway, -1.5 * sway),
        root_pos=(0.05 * sway, 0, -0.02),
        neck=(-16, -2 * sway, 1.5 * sway),
        rs=(70 - rh_tap, 14, 3),
        ls=(70 - lh_tap, -14, -3),
        rh=(0, 0, 2 + 1.5 * sway),
        lh=(0, 0, -2 + 1.5 * sway),
    )


idle.pose(0, typing(-1))
# finger taps (EXPO dips, the other hand lifts a little; head bobs with them, lagging 1 f)
taps = [(4, "R", -0.8), (8, "L", -0.5), (11, "R", -0.2), (15, "R", 0.2), (19, "L", 0.6)]
for f, side, sw in taps:
    p = typing(sw, rh_tap=9 if side == "R" else -4, lh_tap=9 if side == "L" else -4)
    idle.pose(f, p, ease="EXPO")
    idle.key(f + 1, neck=(-18, -2 * sw + (3 if side == "R" else -3), 1.5 * sw))
    idle.marker(f, "key", side)
# enter: the right hand rises, then slams
idle.key(21, ease="IN", rs=(96, 8, 8), ls=(66, -14, -3), neck=(-12, 4, 2), root=(-4, 2, -1))
idle.key(24, ease="EXPO", rs=(58, 16, 2), ls=(68, -14, -3), neck=(-20, 0, 0), root=(-9, 3, -1),
         root_pos=(0.04, -0.04, -0.04))
idle.marker(24, "enter")
idle.key(27, rs=(66, 14, 3), neck=(-15, 0, 0), root=(-6, 3, -1.5), root_pos=(0.04, 0, -0.02))
# LAG: dropped frames, a rewind, a skip
hold(idle, 28)
idle.marker(28, "lag")
idle.key(31, ease="CONST", rs=(96, 8, 8), neck=(-12, 4, 2), root=(-4, 2, -1))  # rewound to frame 21
idle.key(33, ease="CONST", rs=(66, 14, 3), neck=(-15, 0, 0), root=(-6, 3, -1.5))  # skip back
# head rises: "uh oh" (head first, hands lag 3 f), anticipation hunch
idle.key(36, ease="INOUT", neck=(2, 6, 10))
idle.key(39, rs=(56, 12, 4), ls=(56, -12, -4), root=(-3, 0, 0), root_pos=(0, 0, 0))
idle.key(42, ease="IN", neck=(-6, 0, 4), root=(-8, 0, 0), root_pos=(0, -0.05, 0),
         rs=(30, 6, 6), ls=(30, -6, -6), rh=(0, 0, 3), lh=(0, 0, -3))
hold(idle, 45)
# CRASH: frozen T-pose
TPOSE = dict(root=(0, 0, 0), root_pos=(0, 0.02, 0), neck=(0, 0, 0), rs=(0, 0, 90), ls=(0, 0, -90),
             rh=(0, 0, 1.5), lh=(0, 0, -1.5))
idle.pose(46, TPOSE, ease="CONST")
idle.marker(46, "crash")
# frame jitter: small CONST offsets every 2-4 frames (dropped / repeated frames)
jit = [
    (48, dict(root=(0, 1.5, 1.2), root_pos=(0.04, 0.02, 0), neck=(0, 3, 0), rs=(0, 0, 93))),
    (50, dict(root=(0, 0, 0), root_pos=(0, 0.02, 0), neck=(0, 0, 0), rs=(0, 0, 90))),
    (54, dict(root=(0, -1.2, -1), root_pos=(-0.05, 0.02, 0), ls=(0, 0, -86), neck=(2, -2, 0))),
    (56, dict(root=(0, 0, 0), root_pos=(0, 0.02, 0), ls=(0, 0, -90), neck=(0, 0, 0))),
    (61, dict(root_pos=(0.06, 0.02, 0.03), rs=(2, 0, 88), ls=(-2, 0, -92))),
    (63, dict(root_pos=(0, 0.02, 0), rs=(0, 0, 90), ls=(0, 0, -90))),
    (66, dict(root=(0.8, 0, -1.5), neck=(0, -4, 2))),
    (68, dict(root=(0, 0, 0), neck=(0, 0, 0))),
    # GLITCH: left arm and head drop out of the T-pose
    (70, dict(ls=(-8, 0, -34), neck=(-14, 10, 22), root=(0, 3, -2), root_pos=(-0.03, 0.02, 0))),
    (73, dict(ls=(0, 0, -90), neck=(0, 0, 0), root=(0, 0, 0), root_pos=(0, 0.02, 0))),
    (77, dict(root=(0, -1.5, 0), rs=(0, 0, 94), neck=(0, 3, 0))),
    (79, dict(root=(0, 0, 0), rs=(0, 0, 90), neck=(0, 0, 0))),
    (84, dict(root_pos=(-0.05, 0.02, 0), root=(0, 0, 1.2), ls=(0, 0, -93))),
    (86, dict(root_pos=(0, 0.02, 0), root=(0, 0, 0), ls=(0, 0, -90))),
    (90, dict(neck=(1, 2, -2), rs=(-2, 0, 91))),
    (92, dict(neck=(0, 0, 0), rs=(0, 0, 90))),
]
for f, p in jit:
    idle.pose(f, p, ease="CONST")
idle.marker(70, "glitch")
hold(idle, 94)
idle.marker(94, "restart")
# power off: the body slumps (gravity, IN), small bounce on the arms (OUT)
idle.key(103, ease="OUT", root=(-16, 2, 2), root_pos=(0, -0.12, -0.04), neck=(-44, 4, 8),
         rs=(10, 0, 8), ls=(12, 0, -6), rh=(8, 0, 4), lh=(8, 0, -4))
idle.key(107, ease="INOUT", root=(-15, 2, 2), neck=(-46, 5, 10), rs=(16, 0, 4), ls=(17, 0, -3))
idle.key(112, ease="LINEAR", root=(-16, 2, 2), neck=(-45, 5, 10), rs=(14, 0, 4), ls=(15, 0, -4))
hold(idle, 113)
# BOOT: torso snaps upright, the head pops up 2 f later
idle.key(114, ease="CONST", root=(1, 0, 0), root_pos=(0, 0, 0), rs=(0, 0, 4), ls=(0, 0, -4),
         rh=(0, 0, 2), lh=(0, 0, -2))
idle.marker(114, "boot")
idle.key(116, ease="BACK", neck=(10, 0, 0))
idle.key(120, ease="INOUT", root=(-1, 0, 0), neck=(2, 0, 0))
# confused head tilts (head leads, torso echoes 3 f later)
idle.key(124, neck=(-2, 12, 18))
idle.key(127, root=(0, 4, 2), root_pos=(-0.04, 0, 0), ls=(4, 0, -7))
idle.key(131, ease="BACK", neck=(-3, -14, -20))
idle.key(134, root=(-2, -3, -1.5), root_pos=(0.04, 0, 0), rs=(70, -6, 10))
# SCRATCH: the right hand to the back of the head, quick wiggle
idle.key(136, ease="BACK", rs=(156, 0, -26), neck=(-10, 10, 14), root=(-3, -4, -2))
idle.marker(136, "scratch")
for i, f in enumerate((138, 140, 142, 144, 146)):
    s = 1 if i % 2 == 0 else -1
    idle.key(f, ease="INOUT", rs=(156 + 4 * s, 0, -26 + 7 * s), neck=(-10 + s, 10 - 2 * s, 14))
# SHRUG: anticipation (arms drop, head tucks), then BACK shrug
idle.key(149, ease="IN", rs=(4, 0, 6), ls=(4, 0, -6), neck=(-8, 0, 4), root=(-3, 0, 0), root_pos=(0, -0.04, 0))
idle.key(152, ease="BACK", rs=(18, -30, 40), ls=(18, 30, -40), neck=(-10, -6, -16), root=(2, 0, 0),
         root_pos=(0, 0.02, 0), rh=(0, 0, 4), lh=(0, 0, -4))
idle.marker(152, "shrug")
idle.key(156, rs=(20, -32, 44), ls=(20, 32, -44), neck=(-8, -8, -20))  # arms keep floating out
idle.key(163, ease="INOUT", rs=(16, -28, 38), ls=(16, 28, -38), neck=(-12, 6, 14))
# back to the keyboard (arms lead, head follows)
idle.key(169, rs=(60, 14, 4), ls=(58, -14, -4), root=(-4, 2, 1))
idle.pose(176, typing(-1))
idle.loop()
plant(idle)
idle.noise("neck", 1, 1.6, cycles=(2, 3, 5), seed=1, step=1)
idle.noise("root", 1, 0.8, cycles=(1, 2, 3), seed=2, step=1)
idle.noise("rs", 2, 1.2, cycles=(2, 5, 7), seed=3, step=1)
idle.noise("ls", 2, 1.2, cycles=(3, 4, 7), seed=4, step=1)
unsink(idle)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2


def contact(f, side):
    s = 1 if side == "R" else -1  # +1: right foot forward
    walk.key(f, ease="OUT",
             root=(-3, -5 * s, -1.5 * s), root_pos=(0, 0, 0),
             neck=(-4, 4 * s, 0),
             rs=(-20 * s, 0, 5), ls=(20 * s, 0, -5),
             rh=(26 * s, 0, 1.5), lh=(-26 * s, 0, -1.5))


def passing(f, side):
    s = 1 if side == "R" else -1  # the right leg carries the weight when s = 1
    walk.key(f, root=(-2, 0, 1.2 * s), root_pos=(0, 0.07, 0),
             neck=(-2, 0, 0),
             rs=(2, 0, 4), ls=(-2, 0, -4),
             rh=(-3 * s, 0, 1.5), lh=(3 * s, 0, -1.5))


contact(0, "R")
passing(h * 0.5, "R")
contact(h, "L")
# LAG: three dropped frames after the left contact, then a snap to catch up
hold(walk, h + 1)
walk.marker(h + 1, "lag")
walk.key(h + 4, ease="CONST", root=(-2, 3, -1), root_pos=(0, 0.05, 0), neck=(-6, -8, 4),
         rs=(10, 0, 9), ls=(-14, 0, -9), rh=(-14, 0, 1.5), lh=(10, 0, -1.5))
walk.key(h + 5, ease="INOUT", neck=(-3, -2, 1))
passing(h * 1.5 + 1, "L")
walk.loop()
plant(walk, {round(h * 0.5): 0.05, round(h * 1.5 + 1): 0.05})
unsink(walk)

# ------------------------------------------------------------------ reactions
frozen = A.clip("frozen", seconds=1.1, trigger="freeze", mode="replace", blend_in=0.02, blend_out=0.15)
TP = dict(TPOSE)
TP["rh"], TP["lh"] = (0, 0, 0.5), (0, 0, -0.5)
frozen.pose(0, TP, ease="CONST")
frozen.marker(0, "stall")
fj = [
    (3, dict(root=(0, 2, 1), neck=(0, 3, 0), rs=(0, 0, 93))),
    (5, dict(root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 90))),
    (9, dict(root_pos=(0.05, 0.02, 0), ls=(0, 0, -86))),
    (11, dict(root_pos=(0, 0.02, 0), ls=(0, 0, -90))),
    (15, dict(root=(0, -2, -1), neck=(2, -4, 3))),
    (17, dict(root=(0, 0, 0), neck=(0, 0, 0))),
    (21, dict(rs=(2, 0, 87), ls=(-2, 0, -93), root_pos=(-0.04, 0.02, 0))),
    (23, dict(rs=(0, 0, 90), ls=(0, 0, -90), root_pos=(0, 0.02, 0))),
]
for f, p in fj:
    frozen.pose(f, p, ease="CONST")
hold(frozen, 25)
# thaw: arms drop with a springy settle, a confused look
frozen.key(26, ease="BACK", rs=(4, 0, 8), ls=(4, 0, -8), neck=(-4, 10, 8), root=(-3, 0, 0), root_pos=(0, 0, 0),
           rh=(0, 0, 2), lh=(0, 0, -2))
frozen.marker(26, "unfreeze")
frozen.key(33, rs=(0, 0, 5), ls=(0, 0, -5), neck=(-3, -4, -3), root=(-2, 0, 0))
plant(frozen)

Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))
stumble = A.clip("stumble", seconds=0.6, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
stumble.pose(0, Z)
stumble.key(1, ease="CONST", root=(-12, 4, 3), root_pos=(0, -0.22, -0.04), neck=(-14, -6, 8),
            rs=(-10, 0, 30), ls=(-10, 0, -30), rh=(12, 0, 8), lh=(12, 0, -8))
stumble.marker(1, "impact")
stumble.key(3, ease="CONST", root=(-8, -3, -2), root_pos=(0, -0.16, -0.03), neck=(-6, 8, -6), rs=(-6, 0, 22), ls=(-6, 0, -22))
stumble.key(6, ease="INOUT", root=(-6, 0, 0), root_pos=(0, -0.1, -0.02), neck=(-4, 0, 0), rs=(-4, 0, 10), ls=(-4, 0, -10),
            rh=(8, 0, 5), lh=(8, 0, -5))
stumble.pose(18, Z)
plant(stumble)

A.lift = 0
A.air = 0.25


# ------------------------------------------------------------------ key-pose sheet
def keysheet(clip, frames, views=("front", "side", "3/4")):
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
    keysheet(idle, [0, 4, 21, 24, 31, 42, 46, 70, 103, 116, 124, 131, 140, 152, 163])
