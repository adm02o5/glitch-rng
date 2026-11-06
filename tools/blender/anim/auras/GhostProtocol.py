# Ghost Protocol (1 in 2,500,000, MYTHIC tier): "Disavowed. Invisible. Everywhere."
# VFX (AurasHigh.lua A.GhostProtocol): a semi-transparent body in a force-field skin, two delayed
# echoes of the body circling the player (they replay THIS animation 0.35 / 0.7 s late), a cloak
# of fading pixels on the back, smoke wisps, a "[ DISAVOWED ]" tag over the head, a ground sigil.
#
# CONCEPT: a disavowed field agent that is barely there. It hovers low (A.lift = 1 stud, legs
# hanging slack, head bowed), checks its six like a spy, tells YOU to keep quiet, then wraps
# itself in its cloak and VANISHES - and snaps back into existence half a stud away, turned,
# ready, before it drifts home. Ghost motion = slow, weightless drift between hard spy snaps.
#
# IDLE (6.0 s = 180 f; the echoes' breathing and the sigil pulse share this period through
#   Sync.phase(bus, 6)). Markers -> what the VFX does:
#   0-24    low hover, head bowed, arms slack and trailing, slow drift turn
#   28      anticipation: head dips
#   32      "scan" "L"   EXPO head snaps over the left shoulder, torso follows 4 f later
#                        VFX: the echo on that side flares solid for a moment, a wisp puff from
#                        the head, the DISAVOWED tag glitches.
#   46      listening tilt
#   52      "scan" "R"   the same over the right shoulder
#   66      looks straight at the camera
#   78      "shh"        BACK: right index to the lips, leaning in, left arm hidden behind the back
#                        VFX: the tag goes solid white, a small wisp from the right hand, then
#                        SILENCE: every emitter and the light dim for ~0.7 s.
#   100     anticipation: arms swing out and back, the body rises
#   108     "cloak"      EXPO: the arms sweep across the body (cape swirl), the body turns away
#                        and tucks.  VFX: the body goes fully invisible (parts -> 0.97, skin off),
#                        the pixel cloak bursts off the back, a smoke puff, the echoes fade out.
#   108-125 invisible drift (only the echoes replay it, late)
#   126     "decloak"    CONST: snaps back into existence 0.5 stud to the side, turned the other
#                        way, arms low and wide, head up = "ready".  VFX: white flash of the skin,
#                        a ring of wisps, the echoes snap to the body and come back.
#   130-180 overshoot, then a slow weightless drift back home and into the bowed hover
#
# WALK (one stride): a sneaky hover-dash 0.8 stud up: body pitched 30 deg, head low looking
#   ahead, arms swept far back (alternating a little), legs trailing in a slack scissor, banking.
#   0 / h  "shed" "R"/"L" -> pixels are shed backward from the cloak (one puff per half stride).
#   7      "blink"        CONST: the body skips 0.3 stud ahead for 2 frames (a dropped frame)
#                         VFX: the skin flickers off and the body flashes nearly invisible.
#
# REACTIONS (one-shots, mode "add"):
#   vault   (trigger "jump", 0.8 s): tuck and stretch. marker 2 "blink" -> skin flicker.
#   spotted (trigger "spotted", 1.3 s): the VFX fires "spotted" when the local camera comes
#           within 9 studs (cooldown 9 s): the head snaps up at the viewer, the body recoils,
#           the arms cross over the face, it blinks out and back.
#           marker 9 "cloak" -> vanish (as in the idle); marker 24 "decloak" -> reappear.
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy  # noqa: E402
import lib  # noqa: E402

A = lib.Anim("GhostProtocol")
LIFT = 1.0


def hold(clip, f):
    """Freeze every animated channel at frame f with a CONSTANT key (next key = hard snap)."""
    for fc in clip.all_curves():
        k = fc.keyframe_points.insert(f, fc.evaluate(f))
        k.interpolation = "CONSTANT"
        fc.update()


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames


def drift(sway=0.0, yaw=0.0, y=0.0):
    """Low ghost hover. sway -1..1 = weight drifting left .. right."""
    return dict(
        root=(-4, yaw, 2 * sway),
        root_pos=(0.04 * sway, LIFT + y, 0),
        neck=(-15, -3 * sway, -3 * sway),
        rs=(-12, 4, 8 + 2 * sway),
        ls=(-9, -4, -8 + 2 * sway),
        rh=(-13, 0, 3),
        lh=(-5, 0, -2),
    )


idle.pose(0, drift(-1, -4))
idle.key(16, root=(-3, 6, 1), root_pos=(0, LIFT + 0.12, 0), rs=(-14, 4, 10), ls=(-11, -4, -9),
         rh=(-10, 0, 3), lh=(-8, 0, -2))
# anticipation: head dips before the first scan
idle.key(28, ease="IN", neck=(-20, 2, 0), root=(-6, 4, 0))
# SCAN LEFT: the head snaps (EXPO), torso follows 4 f later, the right arm lags behind
idle.key(32, ease="EXPO", neck=(-2, 44, 5))
idle.marker(32, "scan", "L")
idle.key(36, ease="OUT", root=(-3, 16, 2), root_pos=(0, LIFT + 0.06, 0))
idle.key(38, rs=(-6, 4, 14), ls=(-16, -4, -6))
idle.key(46, neck=(0, 48, 12))  # listening tilt
idle.key(48, ease="IN", neck=(-4, 40, 6))
# SCAN RIGHT
idle.key(52, ease="EXPO", neck=(-4, -46, -6))
idle.marker(52, "scan", "R")
idle.key(56, ease="OUT", root=(-3, -14, -2), root_pos=(0, LIFT + 0.08, 0))
idle.key(58, rs=(-16, 4, 6), ls=(-6, -4, -14))
idle.key(62, neck=(-6, -50, -10))
# looks straight at the camera; the right arm starts to rise (anticipation of the gesture)
idle.key(68, ease="OUT", neck=(-6, 0, 0), root=(-4, 0, 0), rs=(30, 0, 6), root_pos=(0, LIFT + 0.1, 0))
# SHH: right index to the lips, leaning in, left arm hidden behind the back
idle.key(78, ease="BACK", root=(-9, 6, -2), neck=(-10, -8, 8), rs=(122, 0, -32), ls=(-36, 10, -6),
         rh=(-6, 0, 3), lh=(-14, 0, -2))
idle.marker(78, "shh")
idle.key(86, neck=(-12, -6, 10), rs=(124, 0, -33), root=(-10, 7, -2))
idle.key(94, ease="IN", neck=(-11, -10, 7), rs=(120, 0, -31), root_pos=(0, LIFT + 0.04, 0))
# CLOAK: anticipation - arms swing out and back, body rises
idle.key(100, ease="OUT", root=(4, 4, 0), root_pos=(0, LIFT + 0.22, 0), neck=(4, 10, 0),
         rs=(-30, 0, 62), ls=(-30, 0, -62), rh=(-18, 0, 5), lh=(-10, 0, -4))
# the cape swirl: arms sweep across the body, the body turns away and tucks
idle.key(108, ease="EXPO", root=(-16, 34, 4), root_pos=(0, LIFT + 0.3, 0), neck=(-26, 16, 0),
         rs=(78, 46, -8), ls=(40, 0, -30), rh=(24, 0, 4), lh=(32, 0, -4))
idle.marker(108, "cloak")
# invisible drift (slow, only the echoes show it)
idle.key(118, root=(-14, 40, 4), root_pos=(0.1, LIFT + 0.34, 0), neck=(-22, 14, 0), rs=(70, 40, -6), ls=(36, 0, -28))
idle.key(125, root=(-13, 42, 3), root_pos=(0.15, LIFT + 0.32, 0))
hold(idle, 125)
# DECLOAK: CONST snap - half a stud aside, turned the other way, arms low and wide, head up
idle.key(126, ease="CONST", root=(2, -24, -3), root_pos=(0.55, LIFT + 0.1, 0), neck=(6, 18, 4),
         rs=(12, -10, 42), ls=(12, 10, -40), rh=(-10, 0, 8), lh=(4, 0, -6))
idle.marker(126, "decloak")
idle.key(130, ease="OUT", root=(4, -27, -4), root_pos=(0.55, LIFT + 0.16, 0), neck=(9, 20, 5),
         rs=(16, -10, 48), ls=(16, 10, -46))
# slow weightless drift back home (arms first, the legs and head lag behind)
idle.key(146, root=(-2, -14, -2), root_pos=(0.32, LIFT + 0.1, 0), rs=(-4, 0, 22), ls=(-2, 0, -20))
idle.key(152, neck=(-6, 6, 1), rh=(-12, 0, 5), lh=(-2, 0, -4))
idle.key(164, root=(-4, -6, -2), root_pos=(0.08, LIFT + 0.04, 0), rs=(-11, 4, 9), ls=(-8, -4, -8))
idle.key(170, neck=(-14, 3, 3), rh=(-13, 0, 3), lh=(-5, 0, -2))
idle.loop()
idle.noise("root", 1, 2.0, cycles=(1, 2, 3), seed=51)
idle.noise("root", 2, 1.2, cycles=(1, 2, 5), seed=52)
idle.noise("root", 1, 0.05, cycles=(1, 2, 3), seed=53, loc=True)
idle.noise("neck", 2, 2, cycles=(1, 3, 4), seed=54)
idle.noise("rh", 0, 4, cycles=(1, 2, 3), seed=55)
idle.noise("lh", 0, 4, cycles=(1, 3, 4), seed=56)
idle.noise("rs", 0, 2.5, cycles=(1, 2, 3), seed=57)
idle.noise("ls", 0, 2.5, cycles=(1, 2, 5), seed=58)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
n = walk.frames
h = n / 2
WY = LIFT - 0.2


def dash(f, side):
    s = 1 if side == "R" else -1  # +1: the right leg leads (forward)
    walk.key(f, ease="OUT", root=(-30, -5 * s, -4 * s), root_pos=(0, WY, 0), neck=(16, 5 * s, 2 * s),
             rs=(-58 + 8 * s, 0, 14), ls=(-58 - 8 * s, 0, -14),
             rh=(-14 + 10 * s, 0, 3), lh=(-14 - 10 * s, 0, -3))
    walk.marker(f, "shed", side)


def float_(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, root=(-27, 2 * s, 1 * s), root_pos=(0, WY + 0.1, 0), neck=(14, -2 * s, 0),
             rs=(-52, 0, 18), ls=(-52, 0, -18), rh=(-16, 0, 3), lh=(-16, 0, -3))


dash(0, "R")
# dropped frame: CONST skip ahead for 2 frames, then back
walk.key(6, ease="CONST", root_pos=(0, WY + 0.06, 0))
walk.key(7, ease="CONST", root_pos=(0, WY + 0.08, -0.3))
walk.marker(7, "blink")
walk.key(9, ease="INOUT", root_pos=(0, WY + 0.1, 0))
float_(5, "R")
dash(h, "L")
float_(h + 5, "L")
walk.loop()

# ------------------------------------------------------------------ reactions
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))

vault = A.clip("vault", seconds=0.8, trigger="jump", mode="add", blend_in=0.03, blend_out=0.25)
vault.pose(0, Z)
vault.key(2, ease="EXPO", root=(-26, 0, 0), root_pos=(0, 0.2, 0), neck=(-16, 0, 0), rs=(30, 0, 10),
          ls=(30, 0, -10), rh=(40, 0, 0), lh=(46, 0, 0))
vault.marker(2, "blink")
vault.key(9, ease="BACK", root=(10, 0, 0), root_pos=(0, 0.35, 0), neck=(12, 0, 0), rs=(-30, 0, 24),
          ls=(-30, 0, -24), rh=(-16, 0, 4), lh=(-10, 0, -4))
vault.key(16, root=(-2, 0, 0), root_pos=(0, 0.06, 0), neck=(-2, 0, 0), rs=(-4, 0, 4), ls=(-4, 0, -4),
          rh=(2, 0, 0), lh=(2, 0, 0))
vault.pose(24, Z)

sp = A.clip("spotted", seconds=1.3, trigger="spotted", mode="add", blend_in=0.02, blend_out=0.3)
sp.pose(0, Z)
# the head snaps up at the viewer first, the body recoils 2 f later
sp.key(2, ease="EXPO", neck=(24, 0, 0))
sp.key(4, ease="EXPO", root=(10, 0, 0), root_pos=(0, 0.15, 0.2), rs=(20, 0, 14), ls=(20, 0, -14),
       rh=(10, 0, 0), lh=(14, 0, 0))
# arms cross over the face, it turns away and blinks out
sp.key(9, ease="EXPO", root=(-10, 24, 0), root_pos=(0, 0.25, 0.1), neck=(-14, 10, 0), rs=(110, 40, -10),
       ls=(100, -40, 10), rh=(24, 0, 0), lh=(30, 0, 0))
sp.marker(9, "cloak")
sp.key(23, root=(-8, 30, 0), root_pos=(0.1, 0.25, 0.1), neck=(-12, 14, 0))
hold(sp, 23)
# blinks back in, turned the other way, then settles
sp.key(24, ease="CONST", root=(4, -18, 0), root_pos=(-0.35, 0.1, 0), neck=(10, 14, 0), rs=(10, 0, 24),
       ls=(10, 0, -24), rh=(-6, 0, 0), lh=(0, 0, 0))
sp.marker(24, "decloak")
sp.key(30, ease="OUT", root=(2, -12, 0), root_pos=(-0.25, 0.08, 0), neck=(6, 8, 0), rs=(6, 0, 14), ls=(6, 0, -14))
sp.pose(39, Z)

A.lift = LIFT

# preview framing for a levitating set (local helper, lib.py untouched)
_aim0 = lib._aim
lib._aim = lambda cam, loc, target=(0, 0, 2.6): _aim0(cam, (loc[0], loc[1], loc[2] + 0.8), (target[0], target[1], target[2] + 0.8))
A.cam.data.ortho_scale = 10


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
    keysheet(idle, [0, 28, 32, 46, 52, 68, 78, 100, 108, 125, 126, 146])
