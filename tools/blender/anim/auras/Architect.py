# The Architect (1 in 404,000,000, SINGULARITY tier): "Wrote the world. Page not found."
# Giant wireframe grid sphere, floating code pages, green god-rays, voxels materialising.
# CONCEPT: the god-programmer at work. A calm, regal figure levitating 2.2 studs above its own
# floor grid (A.lift = 2.2) who WRITES the world: types it in the air, compiles it from the
# sky, throws it onto the floor, spreads the pages - then hits a 404 glitch and calmly patches it.
#
# IDLE (6.0 s = 180 f; the VFX rhythm follows these markers exactly):
#   0-30    COMPOSED: open chest, chin up, palms turned out, one leg forward, slow weight sway,
#           breathing rise (20).  32 anticipation: the hands drift together in front.
#   44..66  "key" "R"/"L" x6  typing in the air at chest height, alternating hands, head down
#                        VFX: each keystroke materialises a voxel in front of the body, the hand
#                        that typed sparks, the blinking cursor flashes.
#   68->72  "enter"      the right hand rises and SLAMS the enter key (EXPO)
#                        VFX: voxel burst, the code pages flash, title glitch-refresh.
#   80-96   head lifts to admire; anticipation: the torso coils right, the right arm drops back
#   100     "compile"    the right arm sweeps up over the head, palm to the sky, back arched, the
#                        body rises 0.35 studs. VFX: god-rays converge (width + brightness flare),
#                        the sky pillar flares, code rain doubles, the sphere glows.
#   112-122 "build"      the arm carves a huge arc down and out, throwing the world onto the floor
#                        (head follows, torso leans into it). VFX: floor shock ring, a wave of
#                        voxels erupts across the grid, the grid lines flash, floor squares.
#   134     "sweep"      the left arm spreads the pages horizontally while the torso turns left
#                        VFX: the code pages fly outward (radius kick) and spin faster.
#   144/146 "error"      CONST glitch: head jerk, arm twitch, body pops sideways (404)
#                        VFX: sphere / nodes flicker out, the title flashes "ERROR 404".
#   150-156 "fix"        a deliberate finger-tap at the bug (EXPO) - VFX: the sphere snaps back with
#                        a flash, cursor + hand spark, a voxel appears where the finger tapped.
#   164-180 BACK settle into COMPOSED (loop).
#
# WALK (one stride, lib.STRIDE): the overseer's air-walk. Upright regal glide 2 studs up, each leg
#   in turn reaches down and PLANTS on an invisible code tile (body dips into it), arms relaxed
#   back with a small counter-swing, head steady.
#   0 "tile" "R",  h "tile" "L" -> VFX: a glowing green tile is written under that foot (fades),
#                                  spark puff from the foot.
#
# REACTIONS (one-shots, mode "add"):
#   ascend     (trigger "jump", 0.8 s): palms up, chin up, body lifts.  marker 3 "ascend" -> sky
#              pillar flare + rain burst + floor shock.
#   touchdown  (trigger "land", 0.9 s): legs tuck, dip, arms balance out. marker 2 "impact" ->
#              floor shock ring + grid flash + floor squares.
#   pagefault  (trigger "pagefault", emitted by the VFX every 6-9 s while gliding, 1.4 s): a page
#              glitches, the head snaps to it, the right hand flicks out and patches it.
#              marker 18 "fix" -> same patch flash as the idle.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Architect")
LIFT = 2.2


def hold(clip, f):
    """CONSTANT key on every animated channel at frame f (the next key becomes a hard snap)."""
    for fc in clip.all_curves():
        k = fc.keyframe_points.insert(f, fc.evaluate(f))
        k.interpolation = "CONSTANT"
        fc.update()


# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=6.0)  # 180 frames


def composed(sway, y=0.0):
    """Regal float: chest open, chin up, palms out, right leg forward. sway -1..1."""
    return dict(
        root=(4, 5 * sway, -1.5 * sway),
        root_pos=(0.06 * sway, LIFT + y, 0),
        neck=(7, -4 * sway, 1.5 * sway),
        rs=(6, -24, 20 + 2 * sway),
        ls=(6, 24, -20 + 2 * sway),
        rh=(15, 0, 3),
        lh=(1, 0, -4),
    )


idle.pose(0, composed(-1))
# breath in: chest rises, arms float up a touch (left lags the right)
idle.key(20, root=(6, 1, 0), root_pos=(0, LIFT + 0.12, 0), neck=(9, 1, 0), rs=(8, -26, 25), rh=(17, 0, 3), lh=(3, 0, -4))
idle.key(24, ls=(8, 26, -25))
# anticipation: hands drift together, head starts to look down
idle.key(32, ease="BACK", root=(1, 0, 0), root_pos=(0, LIFT + 0.04, 0), neck=(-6, 0, 0),
         rs=(34, 12, 6), ls=(30, -12, -6), rh=(13, 0, 2), lh=(4, 0, -3))
# typing in the air: hands at chest height, alternating keystrokes
TYPE_R = (76, 16, 0)
TYPE_L = (76, -16, 0)
idle.key(40, root=(-5, 0, 0), root_pos=(0, LIFT, 0), neck=(-20, 0, 0), rs=TYPE_R, ls=TYPE_L)
for i, f in enumerate(range(44, 68, 4)):
    side = "R" if i % 2 == 0 else "L"
    down = 64 + (i % 3) * 2
    if side == "R":
        idle.key(f - 1, ease="EXPO", rs=(TYPE_R[0] + 5, TYPE_R[1] - 3, 0))  # lift
        idle.key(f, rs=(down, TYPE_R[1] + 2, 0), root=(-6, -2, 0), neck=(-22, -3, 0))
        idle.key(f + 2, rs=TYPE_R)
    else:
        idle.key(f - 1, ease="EXPO", ls=(TYPE_L[0] + 5, TYPE_L[1] + 3, 0))
        idle.key(f, ls=(down, TYPE_L[1] - 2, 0), root=(-6, 2, 0), neck=(-22, 3, 0))
        idle.key(f + 2, ls=TYPE_L)
    idle.marker(f, "key", side)
# ENTER: the right hand rises... and slams
idle.key(68, ease="EXPO", rs=(112, 8, 6), root=(-2, 3, 0), neck=(-14, -4, 0), root_pos=(0, LIFT + 0.06, 0))
idle.key(72, rs=(58, 14, 0), root=(-9, -2, 0), neck=(-26, -2, 0), root_pos=(0, LIFT - 0.08, 0), ls=(70, -14, 0))
idle.marker(72, "enter")
# head lifts to admire the work (head leads, torso follows)
idle.key(80, neck=(10, 4, 0), root=(-1, 0, 0), rs=(40, 6, 8), ls=(38, -6, -8), root_pos=(0, LIFT + 0.02, 0))
idle.key(86, root=(3, 0, 0), rs=(22, -6, 16), ls=(20, 6, -16))
# anticipation: torso coils right, the right arm swings down and back
idle.key(94, ease="EXPO", root=(-4, -16, -4), root_pos=(0.04, LIFT - 0.05, 0), neck=(-6, -10, 0),
         rs=(-22, 0, 24), ls=(12, 0, -30), rh=(18, 0, 4), lh=(2, 0, -6))
# COMPILE: the arm sweeps up to the sky, back arched, body rises
idle.key(100, root=(11, 8, 2), root_pos=(0, LIFT + 0.35, 0), neck=(24, 4, 0),
         rs=(168, 0, 14), ls=(18, 0, -44), rh=(6, 0, 4), lh=(-6, 0, -6))
idle.marker(100, "compile")
idle.key(106, root=(12, 9, 2), root_pos=(0, LIFT + 0.4, 0), neck=(28, 5, 0), rs=(172, 0, 18), ls=(20, 0, -48))
# BUILD: a huge arc down and out to the right - the world is thrown onto the floor
idle.key(112, ease="IN", rs=(130, 0, 70), root=(6, -2, -2), neck=(14, -10, 0))
idle.key(117, ease="LINEAR", rs=(75, -10, 86), root=(-3, -10, -5), neck=(-4, -16, -2), root_pos=(0.08, LIFT + 0.15, 0))
idle.key(122, ease="BACK", rs=(40, -20, 52), root=(-12, -14, -7), neck=(-22, -18, -4), root_pos=(0.12, LIFT - 0.05, 0),
         ls=(10, 0, -34), rh=(24, 0, 5), lh=(-4, 0, -6))
idle.marker(122, "build")
# follow-through, then SWEEP: the left arm spreads the pages while the torso turns left
idle.key(127, rs=(30, -14, 40), root=(-8, -8, -4), neck=(-14, -10, -2), ls=(62, -24, -12))
idle.key(134, ease="EXPO", root=(-2, 16, 3), root_pos=(-0.06, LIFT + 0.08, 0), neck=(4, 20, 2),
         ls=(84, 6, -74), rs=(16, 0, 24), rh=(10, 0, 3), lh=(8, 0, -4))
idle.marker(134, "sweep")
idle.key(140, ls=(80, 10, -84), neck=(5, 22, 3), root=(0, 18, 3))
hold(idle, 143)
# ERROR: two CONST glitch frames
idle.key(144, ease="CONST", root=(-6, 4, 12), root_pos=(0.35, LIFT + 0.1, 0.1), neck=(-12, 34, 30),
         rs=(70, 0, 100), ls=(30, 0, -20))
idle.marker(144, "error")
idle.key(146, ease="CONST", root=(4, 26, -9), root_pos=(-0.2, LIFT - 0.06, -0.1), neck=(14, 4, -24),
         rs=(4, 0, 50), ls=(96, 20, -60))
idle.key(148, ease="EXPO", root=(0, 18, 3), root_pos=(-0.04, LIFT + 0.04, 0), neck=(4, 22, 3),
         rs=(14, 0, 22), ls=(76, 8, -70))
# the Architect regards the bug (head tilt), lowers the left hand, readies the finger
idle.key(152, ease="BACK", neck=(-4, 4, -12), root=(-2, 4, 0), ls=(30, 0, -26), rs=(108, 14, 2))
# FIX: a deliberate tap
idle.key(156, rs=(84, 16, 0), neck=(-10, 2, -8), root=(-5, 2, 0))
idle.marker(156, "fix")
idle.key(160, rs=(92, 14, 4), neck=(-6, 2, -6))
idle.key(166, ease="BACK", root=(2, 0, 0), rs=(30, -12, 18), ls=(14, 12, -18), neck=(5, 0, 0),
         root_pos=(0, LIFT + 0.02, 0), rh=(14, 0, 3), lh=(2, 0, -4))
idle.loop()
idle.noise("root", 1, 1.2, seed=11, step=1)
idle.noise("root", 1, 0.05, cycles=(2, 3), seed=12, loc=True, step=1)
idle.noise("neck", 1, 1.4, seed=13, step=1)
idle.noise("rh", 0, 3, cycles=(2, 3, 5), seed=14, step=1)
idle.noise("lh", 0, 3, cycles=(2, 4, 5), seed=15, step=1)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # 21 frames
h = walk.frames / 2
WY = 2.0


def plant(f, side):
    s = 1 if side == "R" else -1  # +1: right leg reaches forward and plants
    walk.key(f, ease="OUT", root=(-5, -5 * s, -1.5 * s), root_pos=(0, WY - 0.08, 0),
             neck=(3, 4 * s, 0),
             rs=(-16 - 6 * s, -10, 14), ls=(-16 + 6 * s, 10, -14),
             rh=(28 * s - 2, 0, 3), lh=(-28 * s - 2, 0, -3))
    walk.marker(f, "tile", side)


def pass_(f, side):
    s = 1 if side == "R" else -1
    walk.key(f, root=(-3, 0, 1 * s), root_pos=(0, WY + 0.08, 0), neck=(2, 0, 0),
             rs=(-14, -10, 12), ls=(-14, 10, -12),
             rh=(-8 * s + 2, 0, 3), lh=(8 * s + 2, 0, -3))


plant(0, "R")
pass_(h * 0.5, "R")
plant(h, "L")
pass_(h * 1.5, "L")
walk.loop()

# ------------------------------------------------------------------ reactions (additive)
Z = dict(root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0), rh=(0, 0, 0), lh=(0, 0, 0))

ascend = A.clip("ascend", seconds=0.8, trigger="jump", mode="add", blend_in=0.04, blend_out=0.2)
ascend.pose(0, Z)
ascend.key(3, ease="EXPO", root=(8, 0, 0), root_pos=(0, 0.25, 0), neck=(16, 0, 0),
           rs=(20, 0, 30), ls=(20, 0, -30), rh=(-8, 0, 2), lh=(-10, 0, -2))
ascend.marker(3, "ascend")
ascend.key(10, root=(5, 0, 0), root_pos=(0, 0.3, 0), neck=(10, 0, 0), rs=(12, 0, 20), ls=(12, 0, -20))
ascend.pose(24, Z)

touch = A.clip("touchdown", seconds=0.9, trigger="land", mode="add", blend_in=0.03, blend_out=0.2)
touch.pose(0, Z)
touch.key(2, ease="EXPO", root=(-10, 0, 0), root_pos=(0, 0.05, 0), neck=(-10, 0, 0),
          rs=(10, 0, 26), ls=(10, 0, -26), rh=(40, 0, 2), lh=(44, 0, -2))
touch.marker(2, "impact")
touch.key(10, ease="BACK", root=(4, 0, 0), root_pos=(0, 0.12, 0), neck=(5, 0, 0), rs=(-4, 0, 8), ls=(-4, 0, -8),
          rh=(-4, 0, 0), lh=(-6, 0, 0))
touch.pose(27, Z)

pf = A.clip("pagefault", seconds=1.4, trigger="pagefault", mode="add", blend_in=0.06, blend_out=0.25)
pf.pose(0, Z)
pf.key(3, ease="EXPO", neck=(6, -34, -4), root=(0, -6, 0))  # head snaps to the glitching page
pf.key(9, ease="IN", rs=(-10, 0, 10), root=(0, -10, -2))  # anticipation
pf.key(15, rs=(84, -40, 10), neck=(4, -40, -6), root=(2, -16, -3))  # reach out
pf.key(18, ease="BACK", rs=(74, -36, 8), neck=(0, -36, -4))  # tap
pf.marker(18, "fix")
pf.key(28, rs=(20, -10, 6), neck=(2, -12, 0), root=(0, -6, 0))
pf.pose(42, Z)

A.lift = LIFT

# preview framing for a levitating set (local helper, lib.py untouched)
_aim0 = lib._aim
lib._aim = lambda cam, loc, target=(0, 0, 2.6): _aim0(cam, (loc[0], loc[1], loc[2] + 1.6), (target[0], target[1], target[2] + 1.6))
A.cam.data.ortho_scale = 11
A.finish(preview=False)
A.preview(frames_per_clip=int(os.environ.get("ARCH_FRAMES", "12")))
