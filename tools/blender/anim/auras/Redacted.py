# [REDACTED] (1 in 1,000,000,000, SINGULARITY tier - the rarest aura): "████ ██ ███████ ████."
# Black censor bars orbiting, red CLASSIFIED stamps, reality tearing. The body is the SUBJECT of
# a classified file: something that should not exist, held suspended above its own seal.
# A cinematic showpiece: the set levitates (A.lift = 2.0 studs); the floor seal, disc, ring,
# smoke and tears stay on the real ground (the builder subtracts c.lift for those).
#
# IDLE (6.0 s = 180 f; the VFX rhythm follows these markers exactly):
#   0-28    SUSPENDED  hangs upright like an exhibit: head bowed, arms stiff and slightly out,
#                      dangling legs drift out of phase, slow breathing rise (head lags 4 f).
#   30  "snap" "L"     CONST head snap to a wrong angle (looks left, tilted)  VFX: face bar
#   38  "snap" "R"     CONST snap (right, down)                               flash + widen,
#   44  "snap" "C"     CONST snap straight at the viewer, head cocked 32 deg   censor glyphs reshuffle
#   50-56  anticipation: shoulders sink, torso curls, legs tuck.
#   58-66  the right arm winds up overhead (BACK), the torso twists into it, then
#   66  "stamp" "R"    EXPO slam: arm down to horizontal = stamping the air in front of it.
#                      VFX: a CLASSIFIED stamp slams in at the right hand, hand spark burst,
#                      floor seal flashes, light flash.
#   76-82  the left arm winds up while the right one is still settling (overlap), then
#   82  "stamp" "L"    second, sharper stamp (left hand)  VFX: same at the left hand.
#   94/97/100/102 "cut" the body is censored: CONST frame cuts between three wrong poses
#                      (teleport offsets, flung limbs) and back. VFX: black body clones shoved
#                      sideways (frame-cut afterimage), sky bar jitter, glitch-square burst.
#   106-118 hands meet in front of the chest and dig into the air (escalating tremble)
#   112 "grab"         VFX: red seam beam between the hands lights up, tears start to glow.
#   122 "tear"         EXPO: the hands RIP reality apart, arms flung wide, back arched, body
#                      pops up 0.45 studs. VFX: every reality tear opens at once, chest
#                      shockwave, spark burst from both hands, vortex, light flare 9.
#   130-149 exposed: arms held wide with CONST tremble, the head slowly lowers to a stare.
#   150 "seal"         CONST snap back to rigid attention, head bowed. VFX: tears snap shut,
#                      every stamp slams [REDACTED] at once, floor seal flash, ground ring.
#   150-180 weighted drop + BACK settle into SUSPENDED (loop).
#
# WALK (one stride, lib.STRIDE): frame-dropped hover. Hovering 1.9 studs up, leaning into the
#   path, arms stiff and trailing, legs dangling back. Twice per stride the body BLINKS AHEAD
#   along the path (root z jumps forward on a CONST key, the head snaps to a wrong angle, an
#   arm jerks) and then drifts back into place while the character catches up.
#   3     "blink" "R"   big blink (0.9 studs ahead)   VFX: afterimage clones left behind + glitch
#   13.5  "blink" "L"   smaller blink (0.5 studs)          burst at the chest, face bar flash.
#
# REACTIONS (one-shots, mode "add"):
#   lurch   (trigger "jump", 0.7 s): CONST jerk up, legs tuck, arms snap out, then settle.
#           marker 2 "launch" -> VFX: floor seal flash + glitch burst.
#   slam    (trigger "land", 0.8 s): the gravity "stamp": body drops, arms snap down, head bows,
#           BACK recovery.  marker 2 "slam" -> VFX: ground shock ring + floor seal flash + stamp.
#   breach  (trigger "breach", 1.0 s, EMITTED BY THE VFX every 3.5-6 s while moving): the
#           containment breaks - violent CONST twitches of head/torso/arms.
#           markers 0, 5, 12 "twitch" -> VFX: clone shove + glitch burst + face flash each.
import math
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Redacted")
L = 2.0  # idle hover height (studs)


def wobble(clip, joint, axis, amp, cycles, phase=0.0, loc=False):
    """Periodic additive sine drift as an F-curve FNGENERATOR modifier. Unlike clip.noise()
    it does not resample the channel, so CONST snap keys stay hard. Whole cycles per clip."""
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


def P(base, **over):
    d = dict(base)
    d.update(over)
    return d


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames
K = idle.key
M = idle.marker

# SUSPENDED (two breaths of the exhibit)
SUSP = dict(root=(-2, 4, 1.5), root_pos=(0.03, L, 0), rs=(4, 0, 13), ls=(6, 0, -15),
            rh=(8, 0, 3), lh=(3, 0, -4))
K(0, **SUSP)
K(0, neck=(-20, -4, 3))
K(16, root=(1, -3, -1), root_pos=(-0.02, L + 0.16, 0), rs=(8, 0, 17), ls=(9, 0, -18),
  rh=(3, 0, 4), lh=(8, 0, -3))
K(20, neck=(-13, 3, -2))
K(28, root=(0, -1, 0), root_pos=(0, L + 0.1, 0), rs=(6, 0, 15), ls=(7, 0, -16))
K(27, neck=(-17, 1, 0), ease="CONST")  # held, then the snaps

# --- three CONST head snaps to "redacted" angles, the torso answers 2 f later
K(30, neck=(8, 62, 18), ease="CONST")
M(30, "snap", "L")
K(32, root=(1, 6, -1), ease="EXPO")
K(38, neck=(-12, -58, -24), ease="CONST")
M(38, "snap", "R")
K(40, root=(-1, -7, 2), ease="EXPO")
K(44, neck=(4, 0, 32))  # straight at the viewer, cocked - it holds the stare
M(44, "snap", "C")
K(46, root=(0, 0, -2), root_pos=(0, L + 0.06, 0), ease="EXPO")
K(50, neck=(2, 0, 28))

# --- anticipation: shoulders sink, curl, legs tuck
K(52, ease="IN", root=(-7, 2, 0), root_pos=(0, L - 0.1, 0), rs=(-8, 0, 7), ls=(-8, 0, -8),
  rh=(14, 0, 2), lh=(12, 0, -2))
K(55, neck=(-8, 2, 10))

# --- STAMP R: wind-up overhead (BACK overshoot), torso twists into it, the left arm counters
K(60, ease="BACK", root=(6, -12, 3), root_pos=(0.05, L + 0.12, 0), rs=(165, 0, 12),
  ls=(12, 0, -24), rh=(2, 0, 4), lh=(6, 0, -3))
K(62, neck=(16, -10, 4))
K(64, ease="IN", root=(8, -14, 3), root_pos=(0.05, L + 0.16, 0), rs=(176, 0, 6))
K(66, ease="EXPO", root=(-11, 8, -2), root_pos=(0, L - 0.12, 0), rs=(78, 0, 4), ls=(16, 0, -30),
  rh=(16, 0, 3), lh=(20, 0, -3))
M(66, "stamp", "R")
K(68, neck=(-16, 2, 0), ease="EXPO")
K(72, root=(-6, 4, 0), root_pos=(0, L - 0.04, 0), rs=(88, 0, 7), ls=(10, 0, -22))

# --- STAMP L: the left arm winds up while the right arm is still settling (overlap)
K(77, ease="BACK", root=(5, 13, -3), root_pos=(-0.05, L + 0.12, 0), ls=(160, 0, -12),
  rh=(4, 0, 3), lh=(2, 0, -4))
K(78, rs=(34, 0, 16))
K(79, neck=(13, 11, -4))
K(80, ease="IN", root=(7, 15, -3), ls=(172, 0, -6))
K(82, ease="EXPO", root=(-12, -9, 2), root_pos=(0, L - 0.15, 0), ls=(80, 0, -4),
  rh=(18, 0, 3), lh=(16, 0, -3))
M(82, "stamp", "L")
K(84, neck=(-18, -2, 0), ease="EXPO")
K(88, root=(-6, -4, 0), root_pos=(0, L - 0.05, 0), ls=(90, 0, -7), rs=(20, 0, 14))
K(92, neck=(-12, 0, 0))

# --- CENSORED: frame cuts between wrong poses (hold at 93, snap on 94/97/100, back on 102)
ALL = ("root", "root_pos", "neck", "rs", "ls", "rh", "lh")
HOLD = dict(root=(-5, -3, 0), root_pos=(0, L - 0.03, 0), neck=(-12, 0, 0), rs=(19, 0, 14),
            ls=(88, 0, -8), rh=(12, 0, 3), lh=(10, 0, -3))
idle.pose(93, HOLD, ease="CONST")
idle.pose(94, dict(root=(4, 25, -6), root_pos=(0.7, L + 0.2, 0.2), neck=(0, -40, 10),
                   rs=(40, 0, 60), ls=(20, 0, -10), rh=(-10, 0, 8), lh=(20, 0, -3)), ease="CONST")
idle.pose(97, dict(root=(-8, -30, 8), root_pos=(-0.6, L - 0.1, -0.3), neck=(-20, 50, -15),
                   rs=(10, 0, 8), ls=(60, 0, -70), rh=(25, 0, 2), lh=(-12, 0, -9)), ease="CONST")
idle.pose(100, dict(root=(12, 5, 0), root_pos=(0.2, L + 0.35, 0), neck=(25, 0, 0),
                    rs=(150, 0, 30), ls=(150, 0, -30), rh=(-5, 0, 6), lh=(-5, 0, -6)), ease="CONST")
idle.pose(102, dict(root=(0, 0, 0), root_pos=(0, L, 0), neck=(-10, 0, 0), rs=(10, 0, 12),
                    ls=(10, 0, -12), rh=(6, 0, 2), lh=(4, 0, -2)))
for f in (94, 97, 100, 102):
    M(f, "cut")

# --- TEAR: hands meet in front of the chest, dig in, tremble, RIP
K(107, root=(-6, 0, 0), root_pos=(0, L - 0.04, 0), rs=(78, 0, -30), ls=(78, 0, 30),
  rh=(14, 0, 2), lh=(12, 0, -2))
K(109, neck=(-12, 0, 0))
K(112, ease="BACK", root=(-9, 0, 0), root_pos=(0, L - 0.08, 0), rs=(70, 0, -36), ls=(70, 0, 36),
  rh=(22, 0, 3), lh=(24, 0, -3))
M(112, "grab")
K(114, neck=(-18, 0, 0))
for i, f in enumerate(range(114, 121, 2)):  # escalating strain tremble (CONST micro-snaps)
    k = (i + 1) / 4
    s = 1 if i % 2 == 0 else -1
    K(f, ease="CONST", root=(-10 - 2 * k, 1.5 * k * s, -2 * k * s),
      root_pos=(0.04 * k * s, L - 0.09 - 0.03 * k, 0),
      rs=(72 + 2 * k * s, 0, -34 + 3 * k), ls=(72 - 2 * k * s, 0, 34 - 3 * k))
K(121, ease="IN", root=(-13, 0, 0), root_pos=(0, L - 0.14, 0), rs=(72, 0, -28), ls=(72, 0, 28))
M(122, "tear")
K(123, ease="EXPO", root=(16, 0, 0), root_pos=(0, L + 0.35, -0.05), rs=(40, 0, 105),
  ls=(40, 0, -105), rh=(-18, 0, 14), lh=(-20, 0, -14))
K(125, neck=(28, 0, 0), ease="EXPO")
K(130, root=(20, -2, 1), root_pos=(0, L + 0.45, -0.05), rs=(36, 0, 118), ls=(36, 0, -120),
  rh=(-22, 0, 16), lh=(-24, 0, -17))
K(133, neck=(34, -3, 2))
# exposed: held wide, CONST tremble, the head slowly comes down to a stare
for i, f in enumerate(range(134, 149, 2)):
    s = 1 if i % 2 == 0 else -1
    K(f, ease="CONST", root=(18 - i * 0.6, -2 + 1.4 * s, 1 - 1.2 * s),
      root_pos=(0.03 * s, L + 0.42 - i * 0.012, -0.05),
      rs=(36 + 2 * s, 0, 116 - i), ls=(36 - 2 * s, 0, -118 + i))
K(140, neck=(20, 2, 4))
K(146, neck=(4, 0, 6))
K(149, ease="CONST", neck=(2, 0, 6), rh=(-22, 0, 16), lh=(-24, 0, -17))

# --- SEAL: snap to rigid attention, head bowed; weighted drop, BACK settle
SEAL = dict(root=(0, 0, 0), root_pos=(0, L + 0.08, 0), neck=(-26, 0, 0), rs=(-6, 0, 6),
            ls=(-6, 0, -6), rh=(2, 0, 1), lh=(2, 0, -1))
idle.pose(150, SEAL, ease="OUT")
M(150, "seal")
K(158, root=(-3, 0, 0), root_pos=(0, L - 0.1, 0), rs=(-2, 0, 9), ls=(-2, 0, -9),
  rh=(10, 0, 3), lh=(8, 0, -3))
K(161, neck=(-24, -2, 2))
K(168, ease="BACK", root=(-3, 5, 1.8), root_pos=(0.03, L + 0.04, 0), rs=(4, 0, 13),
  ls=(6, 0, -15), rh=(7, 0, 3), lh=(4, 0, -4))
K(172, neck=(-21, -4, 3), ease="BACK")
idle.loop()
# organic drift on top (FNGENERATOR sines: periodic, CONST keys untouched)
wobble(idle, "root", 1, 1.6, 1, 0.3)
wobble(idle, "root", 2, 1.0, 2, 1.1)
wobble(idle, "neck", 1, 2.0, 3, 0.5)
wobble(idle, "rh", 0, 4.0, 2, 0.0)  # dangling legs out of phase
wobble(idle, "lh", 0, 4.0, 2, 2.2)
wobble(idle, "rh", 2, 1.5, 3, 0.9)
wobble(idle, "lh", 2, 1.5, 3, 2.6)
wobble(idle, "rs", 2, 1.5, 4, 0.4)
wobble(idle, "ls", 2, 1.5, 5, 1.7)
wobble(idle, "root", 1, 0.05, 2, 0.0, loc=True)  # breathing float bob

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
h = walk.frames / 2
WY = 1.9
W = walk.pose


def glide(s):
    # s = +1: right leg forward (frame 0), -1: left leg forward (half stride)
    return dict(root=(-14, -4 * s, 3 * s), root_pos=(0, WY, 0), neck=(9, 4 * s, -2 * s),
                rs=(-28 - 6 * s, 0, 11), ls=(-28 + 6 * s, 0, -11),
                rh=(-12 + 7 * s, 0, 3), lh=(-12 - 7 * s, 0, -3))


def drift(s, back):
    # after a blink: the body sits `back` studs ahead and floats back into place
    g = glide(s)
    return P(g, root_pos=(0, WY + 0.04, -back), root=(-15, -2 * s, 1.5 * s))


W(0, glide(1))
W(2, P(glide(1), root_pos=(0, WY - 0.03, 0)), ease="CONST")  # the frame before the blink
W(3, dict(root=(-21, 9, -3), root_pos=(0.15, WY + 0.12, -0.9), neck=(2, -26, 9),
          rs=(-52, 0, 32), ls=(-12, 0, -5), rh=(-2, 0, 6), lh=(-26, 0, -2)), ease="OUT")
walk.marker(3, "blink", "R")
W(7, drift(1, 0.35))
W(h, glide(-1))
W(h + 2, P(glide(-1), root_pos=(0, WY - 0.03, 0)), ease="CONST")
W(h + 3, dict(root=(-17, -6, 2), root_pos=(-0.12, WY + 0.07, -0.5), neck=(6, 19, -7),
              rs=(-20, 0, 6), ls=(-46, 0, -27), rh=(-24, 0, 2), lh=(-4, 0, -5)), ease="OUT")
walk.marker(h + 3, "blink", "L")
W(h + 7, drift(-1, 0.18))
walk.loop()
wobble(walk, "neck", 1, 2.0, 1, 0.7)

# ------------------------------------------------------------------ reactions (additive)
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0),
         rh=(0, 0, 0), lh=(0, 0, 0))

lurch = A.clip("lurch", seconds=0.7, trigger="jump", mode="add", blend_in=0.02, blend_out=0.2)
lurch.pose(0, Z, ease="CONST")
lurch.pose(2, dict(root=(-10, 6, 0), root_pos=(0, 0.3, 0), neck=(-14, -18, 8), rs=(10, 0, 40),
                   ls=(10, 0, -40), rh=(40, 0, 4), lh=(46, 0, -4)), ease="CONST")
lurch.marker(2, "launch")
lurch.pose(5, dict(root=(6, -3, 0), root_pos=(0, 0.4, 0), neck=(10, 6, -4), rs=(-6, 0, 26),
                   ls=(-6, 0, -26), rh=(10, 0, 6), lh=(14, 0, -6)), ease="BACK")
lurch.pose(21, Z)

slam = A.clip("slam", seconds=0.8, trigger="land", mode="add", blend_in=0.02, blend_out=0.2)
slam.pose(0, Z)
slam.key(1, ease="LINEAR", root_pos=(0, 0.06, 0))
slam.pose(3, dict(root=(-16, 0, 0), root_pos=(0, -0.08, 0), neck=(-22, 0, 0), rs=(-16, 0, 16),
                  ls=(-16, 0, -16), rh=(66, 0, 4), lh=(72, 0, -4)), ease="EXPO")
slam.marker(2, "slam")
slam.pose(12, dict(root=(5, 0, 0), root_pos=(0, 0.1, 0), neck=(6, 0, 0), rs=(4, 0, -4),
                   ls=(4, 0, 4), rh=(-6, 0, 2), lh=(-8, 0, -2)), ease="BACK")
slam.pose(24, Z)

breach = A.clip("breach", seconds=1.0, trigger="breach", mode="add", blend_in=0.02, blend_out=0.25)
B = breach.pose
B(0, dict(root=(8, -20, 6), root_pos=(0.35, 0.2, 0), neck=(10, 55, 20), rs=(60, 0, 50),
          ls=(-10, 0, -10), rh=(-14, 0, 6), lh=(10, 0, -2)), ease="CONST")
B(3, dict(root=(-10, 16, -8), root_pos=(-0.3, 0.18, 0.15), neck=(-24, -44, -16), rs=(-20, 0, 6),
          ls=(70, 0, -60), rh=(16, 0, 2), lh=(-12, 0, -8)), ease="CONST")
B(5, dict(root=(14, 4, 0), root_pos=(0.1, 0.35, 0), neck=(30, 10, 34), rs=(110, 0, 20),
          ls=(110, 0, -20), rh=(-20, 0, 8), lh=(-20, 0, -8)), ease="CONST")
B(8, dict(root=(-4, -8, 3), root_pos=(-0.08, 0.14, 0), neck=(-8, -20, -6), rs=(10, 0, 14),
          ls=(14, 0, -18), rh=(6, 0, 2), lh=(4, 0, -2)), ease="CONST")
B(12, dict(root=(6, 12, -4), root_pos=(0.2, 0.18, -0.1), neck=(-16, 36, 12), rs=(30, 0, 70),
           ls=(-12, 0, -4), rh=(-8, 0, 4), lh=(12, 0, -3)), ease="CONST")
B(14, dict(root=(2, 4, -1), root_pos=(0.05, 0.13, 0), neck=(-6, 12, 4), rs=(10, 0, 22),
           ls=(-4, 0, -2), rh=(-2, 0, 1), lh=(4, 0, -1)), ease="BACK")
B(30, Z)
for f in (0, 5, 12):
    breach.marker(f, "twitch")

A.lift = L

# Preview framing for a levitating set (local, lib.py untouched): aim the contact-sheet camera
# higher and widen it so the raised arms stay in frame.
_aim0 = lib._aim
lib._aim = lambda cam, loc, target=(0, 0, 2.6): _aim0(cam, (loc[0], loc[1], loc[2] + L), (target[0], target[1], target[2] + L))
A.cam.data.ortho_scale = 10.5
A.finish(preview=False)
A.preview(frames_per_clip=int(os.environ.get("RED_FRAMES", "10")))


def key_sheet(clip, frames, views=("front", "3/4")):
    """Extra contact sheet at hand-picked frames (the key poses), build/anim_preview/Redacted_<clip>_keys.png."""
    rig, sc, cam = A.rig, A.scene, A.cam
    rig.animation_data.action = clip.action
    tmp = tempfile.mkdtemp(prefix="redkeys_")
    marks = {m.frame: m.name[3:] for m in clip.action.pose_markers}
    tiles = []
    for v in views:
        lib._aim(cam, lib.VIEWS[v])
        for f in frames:
            sc.frame_set(f)
            fp = os.path.join(tmp, f"{v.replace('/', '')}_{f:04d}.png")
            sc.render.filepath = fp
            bpy_render()
            tiles.append((fp, f"{v} f{f}" + (f" [{marks[f]}]" if f in marks else "")))
    dst = os.path.join(lib.PREVIEW_DIR, f"Redacted_{clip.name}_keys.png")
    cmd = ["montage"]
    for fp, lab in tiles:
        cmd += ["-label", lab, fp]
    cmd += ["-tile", f"{len(frames)}x{len(views)}", "-geometry", "+2+2", "-background", "#111",
            "-fill", "#ddd", "-pointsize", "13", dst]
    subprocess.run(cmd, check=True, capture_output=True)
    shutil.rmtree(tmp, ignore_errors=True)
    print("[preview]", dst)


def bpy_render():
    import bpy
    bpy.ops.render.render(write_still=True)


if os.environ.get("RED_KEYS"):
    key_sheet(idle, [0, 30, 44, 52, 64, 66, 77, 82, 94, 97, 100, 112, 122, 130, 150, 160])
