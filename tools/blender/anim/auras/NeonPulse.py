# Neon Pulse (1 in 4,000, Rare): "The city's heartbeat."
# VFX sync: every "beat" marker launches the neon pulse up the spiral tubes + the floor shock
# ring (AurasMid NeonPulse listens on the bus); "dub" is the softer second heart sound.
#
# IDLE (3.2 s, two 1.6 s heartbeats): relaxed contrapposto that slowly sways weight from foot
#   to foot; on each LUB the chest pops (torso back + up, shoulders flare, head bobs), the DUB
#   is a smaller echo 0.27 s later, then everything settles with a soft overshoot.
# WALK (one stride): springy beat-walk, every footfall lands like a pulse (chest pop + arm
#   flare on contact, bouncy rise on the passing pose).
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lib  # noqa: E402

A = lib.Anim("NeonPulse")

# ------------------------------------------------------------------ idle
idle = A.clip("idle", seconds=3.2)  # 96 frames, beats on 0 and 48

def rest(sway):
    # sway -1..1: weight on the left .. right foot
    return dict(
        root=(0, 2 * sway, -1.6 * sway),
        root_pos=(0.06 * sway, 0, 0),
        neck=(-3, -3 * sway, 1.2 * sway),
        rs=(4, 0, 5 + 1.5 * sway),
        ls=(4, 0, -5 + 1.5 * sway),
        rh=(0, 0, 1.6 * sway + 1.5),
        lh=(0, 0, 1.6 * sway - 1.5),
    )

def beat(f, sway, big=1.0):
    r = rest(sway)
    # LUB: chest pops back and up, shoulders flare, head bobs back
    idle.key(f, ease="EXPO",
             root=(5 * big, 2 * sway, -1.6 * sway), root_pos=(0.06 * sway, 0.07 * big, 0),
             neck=(-9 * big, -3 * sway, 1.2 * sway),
             rs=(9 * big, 0, 11 * big), ls=(9 * big, 0, -11 * big),
             rh=r["rh"], lh=r["lh"])
    # recoil
    idle.key(f + 4, root=(-1.5 * big, 2 * sway, -1.6 * sway), root_pos=(0.06 * sway, -0.02, 0),
             neck=(-1, -3 * sway, 1.2 * sway), rs=(2, 0, 4), ls=(2, 0, -4))
    # DUB (smaller echo)
    idle.key(f + 8, ease="EXPO",
             root=(2.6 * big, 2 * sway, -1.6 * sway), root_pos=(0.06 * sway, 0.035 * big, 0),
             neck=(-6 * big, -3 * sway, 1.2 * sway), rs=(6, 0, 8), ls=(6, 0, -8))
    # settle with a soft overshoot
    idle.key(f + 14, root=(-0.8, 2 * sway, -1.6 * sway), root_pos=(0.06 * sway, -0.01, 0),
             neck=(-2.5, -3 * sway, 1.2 * sway), rs=(3.5, 0, 4.5), ls=(3.5, 0, -4.5))
    idle.marker(f, "beat")
    idle.marker(f + 8, "dub")

beat(0, -1)
idle.pose(30, rest(0))
beat(48, 1, 0.9)
idle.pose(78, rest(0))
idle.loop()
idle.noise("neck", 1, 1.5, seed=1)  # eyes drift a little
idle.noise("root", 1, 0.8, seed=2)

# ------------------------------------------------------------------ walk
walk = A.clip("walk", seconds=lib.STRIDE)  # ~21 frames, contacts on 0 and half
h = walk.frames / 2

def contact(f, side):
    s = 1 if side == "R" else -1  # +1: right foot forward
    walk.key(f, ease="EXPO",
             root=(4, -7 * s, -2 * s), root_pos=(0, 0, 0),
             neck=(-6, 6 * s, 1.5 * s),
             rs=(-26 * s, 0, 12), ls=(26 * s, 0, -12),
             rh=(24 * s, 0, 2), lh=(-24 * s, 0, -2))
    walk.marker(f, "beat")

def passing(f, side):
    s = 1 if side == "R" else -1  # the right leg is the one carrying weight when s = 1
    walk.key(f, root=(-3, 0, 1.5 * s), root_pos=(0, 0.09, 0),
             neck=(-1, 0, 0),
             rs=(0, 0, 6), ls=(0, 0, -6),
             rh=(-2 * s, 0, 2), lh=(2 * s, 0, -2))

contact(0, "R")
passing(h * 0.5, "R")
contact(h, "L")
passing(h * 1.5, "L")
walk.loop()

A.lift = 0
A.finish()
