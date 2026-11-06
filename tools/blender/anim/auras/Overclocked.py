# Overclocked (1 in 400,000, LEGENDARY tier, Overclock biome): "Running at 300%. Smells like burning."
# VFX (AurasHigh.lua A.Overclocked): a big cooling fan spinning on the back, a fast fan halo above
# the head, lightning arcs out of the chest, back vents spitting fire, heat smoke, floor fire, a
# TEMP readout above the head and an orange root light.
#
# CONCEPT: a machine pushed past its limits, grounded (Legendary = big readable signature motion; an
# overheating rig stays on the ground). The whole body hums with a fine high-frequency vibration
# (periodic noise, 20-40 cycles per loop). One idle loop is one THERMAL CYCLE: rev up -> piston
# stomp -> coil -> SURGE (arms thrown up in a V, roaring) -> crackling hold -> overheat (hand to the
# forehead, slump) -> fanning the face -> head shake -> reboot stutter -> back to the power stance.
#
# IDLE (4.0 s = 120 f; the VFX's TEMP gauge, fan speed and sigil breathing follow
#   Sync.phase(bus, 4.0) plus the markers). Markers -> what the VFX does:
#   0-12    pumped power stance (fists clenched, wide legs, chest forward), weight on the right leg,
#           vibrating; head lags the torso by 2-3 frames on every move.
#   14      "rev"          crouch + fists pulled in to the chest (anticipation).
#                          VFX: the back fan and halo spin up (rev envelope), TEMP starts climbing.
#   22-26   left knee-less "piston" lift, then
#   26      "stomp" "L"    the left foot slams down (EXPO), body drops, arms jolt 2 f later.
#                          VFX: a fire shock ring bursts from the left foot, floor sparks.
#   34      coil: torso curled forward, fists dragged back by the hips, head down.
#   38      "surge"        EXPO explosion: torso back, arms thrown up and out in a V, head up (roar).
#                          VFX: every arc fires at once from both fists, white-hot flash of the
#                          blades, light surge, spark burst, TEMP jumps to the red.
#   44-50   CONST shake frames (the crackling hold); "crackle" on 44 and 48 -> extra arc bursts.
#   62      "throttle"     overheat: hunch, right hand slaps the forehead, left arm drops.
#                          VFX: TEMP shows THROTTLING!, the light browns out, the fan stalls.
#   68/76   "vent"         the right hand fans the face (two waves).
#                          VFX: the back vents blast a steam/fire puff each wave.
#   84-92   head shake (no/no/no), torso counters.
#   96      "reboot"       CONST: 2 frames of a stiff upright "boot" pose, then snap back.
#                          VFX: white flash of the TEMP glyph, fan and halo restart.
#   100-120 settle back into the power stance with a BACK overshoot, weight to the left and back.
#
# WALK (one stride): a hyper sprint - torso pitched forward, huge pumping arms with clenched fists
#   (forward bias), long legs, a hard drop on every contact and a pop up on the passing pose,
#   high-frequency vibration on top. VFX uses the runner's "step" events: sparks + a fire puff
#   from that foot, the arcs flicker with each footfall.
#
# REACTIONS:
#   zap  (trigger "zap", 0.6 s, add): the VFX shoots a white arc from the fan into the body every
#        6-10 s; the body gets electrocuted - CONST jitter, arms flare, head snaps. marker 2 "jolt"
#        -> sparks burst from both hands.
#   slam (trigger "land", 0.7 s, add): heavy landing - crouch, arms flung down/back, head bob.
#        marker 2 "quake" -> big fire shock ring + floor spark burst.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("Overclocked")

# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=4.0)  # 120 frames


def power(sway=0.0, br=0.0):
    """Pumped power stance. sway -1..1 = weight left .. right, br = breath 0..1."""
    return dict(
        root=(-5 + 1.5 * br, 3 * sway, -2.2 * sway),
        root_pos=(0.08 * sway, -0.12 + 0.03 * br, 0),
        neck=(3 - 1.5 * br, -4 * sway, 1.5 * sway),
        rs=(22 + 3 * br, 0, 16 + 2 * br),
        ls=(22 + 3 * br, 0, -16 - 2 * br),
        rh=(5, 0, 8 + 2 * sway),
        lh=(5, 0, -8 + 2 * sway),
    )


idle.pose(0, power(1, 0))
idle.pose(8, power(0.8, 1))
# --- rev: crouch, fists pulled in to the chest (head lags: keyed 2 f later)
idle.key(14, ease="QUAD", root=(-12, 6, -2), root_pos=(0.06, -0.28, 0),
         rs=(70, 0, 22), ls=(70, 0, -22), rh=(14, 0, 9), lh=(14, 0, -9))
idle.key(16, neck=(-12, -5, 2))
idle.marker(14, "rev")
# --- piston: weight onto the right leg, left leg lifts
idle.key(22, ease="OUT", root=(-8, 10, -6), root_pos=(0.22, -0.18, 0),
         rs=(62, 0, 26), ls=(55, 0, -30), rh=(10, 0, 6), lh=(40, 0, -10))
idle.key(24, neck=(-6, -10, 5))
# --- stomp: the left foot slams down, arms jolt 2 frames later
idle.key(26, ease="EXPO", root=(-14, 4, 2), root_pos=(0.05, -0.32, 0), rh=(16, 0, 9), lh=(14, 0, -9))
idle.key(28, ease="EXPO", rs=(80, 0, 20), ls=(84, 0, -18), neck=(-16, -3, 0))
idle.marker(26, "stomp", "L")
idle.key(30, root=(-12, 3, 1), root_pos=(0.04, -0.29, 0))
# --- coil: curl forward, fists dragged back by the hips
idle.key(34, ease="IN", root=(-17, 0, 0), root_pos=(0, -0.34, 0),
         rs=(-24, 0, 14), ls=(-24, 0, -14), rh=(18, 0, 9), lh=(18, 0, -9))
idle.key(35, neck=(-22, 0, 0))
# --- SURGE: arms flung up in a V, chest back, roar
idle.key(38, ease="EXPO", root=(12, 0, 0), root_pos=(0, 0.02, 0),
         rs=(20, 0, 126), ls=(20, 0, -126), rh=(-11, 0, 9), lh=(-11, 0, -9))
idle.key(40, ease="EXPO", neck=(24, 0, 0))
idle.marker(38, "surge")
idle.key(42, root=(14, -2, 1), rs=(16, 0, 136), ls=(16, 0, -136), rh=(-13, 0, 10), lh=(-13, 0, -8))
idle.key(43, neck=(28, 3, -2))
# --- crackling hold: CONST shake frames
for f, s in ((44, 1), (46, -1), (48, 1), (50, -1)):
    idle.key(f, ease="CONST", root=(12 + s, 2 * s, -2.5 * s),
             rs=(18 + 4 * s, 0, 132 - 5 * s), ls=(18 - 4 * s, 0, -132 - 5 * s),
             neck=(25 - 2 * s, 5 * s, 3 * s), rh=(-11 - s, 0, 9), lh=(-11 - s, 0, -9))
idle.marker(44, "crackle")
idle.marker(48, "crackle")
# --- arms sink, heat building
idle.key(56, ease="INOUT", root=(4, -2, 1), root_pos=(0, -0.06, 0),
         rs=(20, 0, 95), ls=(20, 0, -100), neck=(8, 2, 0), rh=(-3, 0, 8), lh=(-3, 0, -8))
# --- throttle: hunch, right hand slaps the forehead, left arm drops
idle.key(62, ease="EXPO", root=(-12, -6, 5), root_pos=(-0.08, -0.16, 0),
         rs=(170, 40, -45), ls=(4, 0, -10), rh=(12, 0, 7), lh=(12, 0, -9))
idle.key(64, ease="BACK", neck=(-14, 6, 9))
idle.marker(62, "throttle")
# --- fanning the face (two waves)
idle.key(68, ease="QUAD", rs=(120, 10, 50), root=(-8, -8, 4), neck=(10, 14, 6), rh=(8, 0, 7), lh=(8, 0, -9))
idle.marker(68, "vent")
idle.key(72, ease="QUAD", rs=(150, -20, -18), neck=(4, 10, 4))
idle.key(76, ease="QUAD", rs=(118, 12, 54), neck=(12, 16, 5))
idle.marker(76, "vent")
idle.key(80, ease="QUAD", rs=(70, 0, 30), ls=(10, 0, -14), root=(-6, -4, 2), neck=(-2, 6, 2), rh=(6, 0, 8), lh=(6, 0, -8))
# --- head shake, torso counters a little
idle.key(84, ease="QUAD", neck=(-6, 18, 0), root=(-6, -6, 1))
idle.key(88, ease="QUAD", neck=(-6, -18, 0), root=(-6, 4, 1))
idle.key(92, ease="QUAD", neck=(-5, 12, 0), root=(-6, -2, 0))
idle.key(94, rs=(40, 0, 20), ls=(24, 0, -16), root_pos=(0, -0.12, 0))
# --- reboot stutter: 2 frames of a stiff boot pose, then snap back
idle.key(96, ease="CONST", root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0),
         rs=(0, 0, 2), ls=(0, 0, -2), rh=(0, 0, 2), lh=(0, 0, -2))
idle.marker(96, "reboot")
idle.key(98, ease="CONST", root=(-9, -10, 3), root_pos=(-0.04, -0.2, 0), neck=(-10, 12, -4),
         rs=(34, 0, 26), ls=(40, 0, -26), rh=(9, 0, 9), lh=(9, 0, -7))
# --- settle into the power stance (BACK overshoot), weight to the left, head lags
idle.key(104, ease="BACK", **{k: v for k, v in power(-1, 0.5).items() if k != "neck"})
idle.key(107, ease="BACK", neck=power(-1, 0.5)["neck"])
idle.pose(114, power(0.2, 0.8))
idle.loop()
# the machine hums: fine high-frequency vibration (whole cycles per loop -> seamless)
idle.noise("root", 2, 0.7, cycles=(23, 31, 41), seed=3, step=1)
idle.noise("root", 0, 0.5, cycles=(19, 29, 37), seed=4, step=1)
idle.noise("neck", 1, 1.4, cycles=(17, 27, 43), seed=5, step=1)
idle.noise("rs", 0, 1.6, cycles=(21, 33, 47), seed=6, step=1)
idle.noise("ls", 0, 1.6, cycles=(22, 35, 45), seed=7, step=1)
idle.noise("root", 1, 0.012, cycles=(25, 39, 53), seed=8, loc=True, step=1)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # ~21 frames, contacts on 0 and half
h = walk.frames / 2


def contact(f, side):
    s = 1 if side == "R" else -1  # +1: right foot forward
    walk.key(f, ease="EXPO",
             root=(-19, -9 * s, -2.5 * s), root_pos=(0, -0.16, 0),
             neck=(13, 7 * s, 2 * s),
             rs=(-62 * s + 22, 0, 12), ls=(62 * s + 22, 0, -12),
             rh=(44 * s + 17, 0, 3), lh=(-44 * s + 17, 0, -3))


def passing(f, side):
    s = 1 if side == "R" else -1  # the right leg carries the weight when s = 1
    walk.key(f, ease="OUT",
             root=(-23, 0, 2.5 * s), root_pos=(0, 0.1, 0),
             neck=(17, 0, 0),
             rs=(-6 * s + 28, 0, 15), ls=(6 * s + 28, 0, -15),
             rh=(18 - 8 * s, 0, 4), lh=(18 + 8 * s, 0, -4))


contact(0, "R")
passing(h * 0.5, "R")
contact(h, "L")
passing(h * 1.5, "L")
walk.loop()
walk.noise("root", 2, 1.2, cycles=(7, 11, 13), seed=9, step=1)
walk.noise("neck", 1, 2.0, cycles=(5, 9, 13), seed=10, step=1)

# ------------------------------------------------------------------ reactions
zap = A.clip("zap", seconds=0.6, trigger="zap", mode="add", blend_in=0.03, blend_out=0.2)
zap.key(0, root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0))
zap.key(18, root_pos=(0, 0, 0))
zap.key(2, ease="CONST", root=(6, 4, -3), neck=(12, -10, 6), rs=(-10, 0, 28), ls=(-10, 0, -28))
zap.marker(2, "jolt")
zap.key(4, ease="CONST", root=(3, -5, 4), neck=(-6, 12, -8), rs=(6, 0, 12), ls=(6, 0, -34))
zap.key(6, ease="CONST", root=(7, 3, -2), neck=(10, -6, 5), rs=(-14, 0, 32), ls=(-6, 0, -18))
zap.key(8, ease="CONST", root=(2, -2, 3), neck=(-3, 8, -4), rs=(4, 0, 18), ls=(2, 0, -24))
zap.key(10, ease="EXPO", root=(4, 0, 0), neck=(4, 0, 0), rs=(-4, 0, 14), ls=(-4, 0, -14))
zap.key(18, root=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0))

slam = A.clip("slam", seconds=0.7, trigger="land", mode="add", blend_in=0.02, blend_out=0.25)
slam.key(0, root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0),
         rh=(0, 0, 0), lh=(0, 0, 0))
slam.key(2, ease="EXPO", root=(-12, 0, 0), root_pos=(0, -0.3, 0), neck=(-10, 0, 0),
         rs=(-30, 0, 22), ls=(-30, 0, -22), rh=(14, 0, 4), lh=(14, 0, -4))
slam.marker(2, "quake")
slam.key(5, neck=(4, 0, 0))
slam.key(9, root=(-6, 0, 0), root_pos=(0, -0.14, 0), rs=(-12, 0, 12), ls=(-12, 0, -12),
         rh=(7, 0, 2), lh=(7, 0, -2))
slam.key(21, root=(0, 0, 0), root_pos=(0, 0, 0), neck=(0, 0, 0), rs=(0, 0, 0), ls=(0, 0, 0),
         rh=(0, 0, 0), lh=(0, 0, 0))

# ------------------------------------------------------------------ floor contact
# R6 has no knees: a body drop the leg angles cannot absorb would push the soles into the floor.
# Bake a per-frame correction into root_pos y wherever the lowest sole dips below the floor
# (the authored drops still read through the torso pitch, arms and head).
def floor_fix(clip, margin=0.0):
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


for c in A.clips:
    floor_fix(c)

A.lift = 0
A.finish()
