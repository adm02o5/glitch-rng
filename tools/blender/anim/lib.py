"""Glitch RNG aura animation toolkit for Blender (headless or GUI).

Every aura animation of the game is keyframed HERE, in Blender, on an exact Roblox R6 rig,
then baked into src/shared/AuraFX/Anims/<AuraId>.lua (played by AuraFX/Poses + AuraFX/Clips).

Run one aura:   tools/blender/anim/run.sh <AuraId>        (auras/<AuraId>.py)
Re-export a hand-edited .blend:  tools/blender/anim/run.sh --blend art/anims/<AuraId>.blend

------------------------------------------------------------------ the rig
Bones = Roblox R6 joints, every bone's rest axes == Roblox part axes, pivots == Motor6D pivots:
    root  (RootJoint, HumanoidRootPart -> Torso, pivot = torso centre, 3 studs above the floor)
    neck  (Neck, pivot = top of torso)          rs / ls (Right/Left Shoulder, pivot = torso top corners)
    rh / lh (Right/Left Hip, pivot = torso bottom corners)
Units are studs. Blender +Z = Roblox +Y (up); the character faces Blender +Y (Roblox -Z).

------------------------------------------------------------------ rotation convention
Rotations are given in DEGREES as (x, y, z) == Roblox CFrame.Angles(x, y, z) in the PARENT
part's axes (Roblox: +X right, +Y up, +Z back). Cheat-sheet:
    shoulders / hips   +x = limb swings FORWARD,  -x = backward
                       rs/rh +z = outward (away from the body), ls/lh -z = outward
                       rs +y = arm (when raised forward) swings toward the body centre / left
    root (torso)       -x = lean FORWARD, +x = lean back, +z = lean LEFT, -z = lean right,
                       +y = turn LEFT;  root_pos = (x, y, z) studs shift, +y up (crouch = -y)
    neck               +x = look UP, -x = look down, +y = look LEFT, +z = tilt head LEFT
    arms straight up = rs (180,0,0) or (0,0,180);  T-pose = rs (0,0,90), ls (0,0,-90)
There are no knees/elbows in R6: crouching = root_pos y down + hips forward (+x) with the
torso leaning forward (-x) so the feet stay on the floor (check() measures it).

------------------------------------------------------------------ clips
    A = lib.Anim("NeonPulse")                      # fresh scene + rig (30 fps)
    idle = A.clip("idle", seconds=3.0)             # looping, timed from equip (shared VFX beat)
    walk = A.clip("walk", seconds=lib.STRIDE)      # looping, ONE stride: frame 0 = right foot
                                                   # contact (right foot forward), half = left
    hit  = A.clip("flinch", seconds=0.7, trigger="pulse", mode="replace")   # one-shot reaction
    idle.key(0, root=(0, 0, 0), neck=(-4, 0, 0), rs=(5, 0, 6), ls=(5, 0, -6), ease="INOUT")
    idle.key(45, root_pos=(0, -0.05, 0), rs=(12, 0, 8))   # unspecified joints keep their curves
    idle.marker(45, "beat")                        # emitted on the aura's Sync bus at that frame
    idle.marker(60, "spark", "rhand")              # with an argument
    idle.loop()                                    # last frame = copy of frame 0 (seamless)
    A.lift = 0                                     # > 0 for levitating sets (root y = height)
    A.finish()                                     # check + save .blend + export .lua + preview

ease: "INOUT" (default, bezier), "IN", "OUT", "LINEAR", "CONST" (hard snap, glitch frames),
      "BACK" / "ELASTIC" / "BOUNCE" (Blender's dynamic easings, overshoot / springs).
Anything else Blender offers (F-curve noise modifiers, NLA, constraints, drivers...) is
welcome: export() samples the EVALUATED pose of every frame (but keep loops seamless:
use clip.noise() for organic drift, it is periodic; Blender's NOISE modifier is not).
"""

from __future__ import annotations

import math
import os
import subprocess
import sys
import tempfile

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 30
STRIDE = 1 / 1.4  # seconds of one walk cycle at WalkSpeed 16 (AuraFX/Poses STRIDE_HZ)
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
ANIMS_DIR = os.path.join(REPO, "src", "shared", "AuraFX", "Anims")
BLEND_DIR = os.path.join(REPO, "art", "anims")
PREVIEW_DIR = os.path.join(REPO, "build", "anim_preview")

# Roblox R6 geometry (Roblox space, HumanoidRootPart centre = origin)
HRP_Z = 3.0  # HumanoidRootPart centre height above the floor (studs)
BONES = {
    # name: (pivot in Roblox root space, parent)
    "root": ((0.0, 0.0, 0.0), None),
    "neck": ((0.0, 1.0, 0.0), "root"),
    "rs": ((1.0, 0.5, 0.0), "root"),
    "ls": ((-1.0, 0.5, 0.0), "root"),
    "rh": ((1.0, -1.0, 0.0), "root"),
    "lh": ((-1.0, -1.0, 0.0), "root"),
}
JOINTS = ["root", "neck", "rs", "ls", "rh", "lh"]
# body blocks: (bone, centre in Roblox root space, size in Roblox axes, colour)
BLOCKS = [
    ("root", (0, 0, 0), (2, 2, 1), (0.05, 0.42, 0.85)),  # Torso
    ("neck", (0, 1.62, 0), (1.25, 1.25, 1.25), (0.96, 0.8, 0.25)),  # Head (R6 head mesh)
    ("rs", (1.5, 0, 0), (1, 2, 1), (0.96, 0.8, 0.25)),  # Right Arm
    ("ls", (-1.5, 0, 0), (1, 2, 1), (0.96, 0.8, 0.25)),  # Left Arm
    ("rh", (0.5, -2, 0), (1, 2, 1), (0.3, 0.6, 0.2)),  # Right Leg
    ("lh", (-0.5, -2, 0), (1, 2, 1), (0.3, 0.6, 0.2)),  # Left Leg
]
FACE = [  # small dark blocks on the head front so facing is obvious in previews
    ("neck", (0.25, 1.75, -0.63), (0.18, 0.28, 0.05), (0.05, 0.05, 0.05)),
    ("neck", (-0.25, 1.75, -0.63), (0.18, 0.28, 0.05), (0.05, 0.05, 0.05)),
    ("neck", (0, 1.42, -0.63), (0.5, 0.08, 0.05), (0.05, 0.05, 0.05)),
    ("rs", (1.5, -0.85, -0.52), (0.6, 0.3, 0.05), (0.9, 0.2, 0.2)),  # red "palm" marker = front
    ("ls", (-1.5, -0.85, -0.52), (0.6, 0.3, 0.05), (0.9, 0.2, 0.2)),
]

# Roblox (x, y, z) -> Blender (x, -z, y + HRP_Z)
def rb(v) -> Vector:
    return Vector((v[0], -v[2], v[1]))


def rb_point(v) -> Vector:
    return Vector((v[0], -v[2], v[1] + HRP_Z))


def angles(deg) -> Euler:
    """Roblox CFrame.Angles(x, y, z) in degrees == Blender Euler order ZYX in bone axes."""
    return Euler((math.radians(deg[0]), math.radians(deg[1]), math.radians(deg[2])), "ZYX")


EASE = {
    "INOUT": ("BEZIER", "AUTO_CLAMPED", None),
    "IN": ("SINE", None, "EASE_IN"),
    "OUT": ("SINE", None, "EASE_OUT"),
    "LINEAR": ("LINEAR", None, None),
    "CONST": ("CONSTANT", None, None),
    "BACK": ("BACK", None, "EASE_OUT"),
    "ELASTIC": ("ELASTIC", None, "EASE_OUT"),
    "BOUNCE": ("BOUNCE", None, "EASE_OUT"),
    "QUAD": ("QUAD", None, "EASE_IN_OUT"),
    "EXPO": ("EXPO", None, "EASE_OUT"),
}


# ------------------------------------------------------------------ scene + rig


def _reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.render.fps_base = 1
    sc.unit_settings.system = "NONE"
    return sc


def _block_mesh(name, blocks, rig):
    """One mesh with a box per block, each weighted 100 % to its bone (armature-deformed)."""
    me = bpy.data.meshes.new(name)
    verts, faces, groups, cols = [], [], [], []
    for bone, c, s, col in blocks:
        cx, cy, cz = rb_point(c)
        sx, sy, sz = s[0] / 2, s[2] / 2, s[1] / 2
        base = len(verts)
        for dx in (-1, 1):
            for dy in (-1, 1):
                for dz in (-1, 1):
                    verts.append((cx + dx * sx, cy + dy * sy, cz + dz * sz))
        for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            faces.append(tuple(base + i for i in f))
            cols.append(col)
        groups.append((bone, range(base, base + 8)))
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for bone, idx in groups:
        vg = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
        vg.add(list(idx), 1.0, "REPLACE")
    # per-face colour via one material per colour (Workbench shows material colours)
    mats = {}
    for i, col in enumerate(cols):
        key = tuple(round(x, 3) for x in col)
        if key not in mats:
            m = bpy.data.materials.new(f"{name}_{len(mats)}")
            m.diffuse_color = (*col, 1)
            ob.data.materials.append(m)
            mats[key] = len(mats)
        me.polygons[i].material_index = mats[key]
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    ob.parent = rig
    return ob


def build_rig():
    sc = bpy.context.scene
    arm = bpy.data.armatures.new("R6")
    rig = bpy.data.objects.new("R6", arm)
    sc.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    ebs = {}
    for name, (piv, parent) in BONES.items():
        eb = arm.edit_bones.new(name)
        h = rb_point(piv)
        eb.head = h
        eb.tail = h + Vector((0, 0, 0.5))  # bone Y axis = Blender +Z = Roblox +Y
        eb.align_roll(Vector((0, -1, 0)))  # bone Z axis = Blender -Y = Roblox +Z
        eb.use_deform = True
        ebs[name] = eb
    for name, (_, parent) in BONES.items():
        if parent:
            ebs[name].parent = ebs[parent]
            ebs[name].use_connect = False
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        pb.rotation_mode = "ZYX"
    bpy.ops.object.mode_set(mode="OBJECT")
    # sanity: every bone's rest axes must equal Roblox axes in Blender coordinates
    want = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    for b in arm.bones:
        got = b.matrix_local.to_3x3()
        err = max(abs(got[i][j] - want[i][j]) for i in range(3) for j in range(3))
        assert err < 1e-4, f"bone {b.name} rest axes off by {err}"
    _block_mesh("Body", BLOCKS + FACE, rig)
    return rig


def _stage(sc):
    # floor with a 1-stud grid so sinking / floating feet are obvious in previews
    me = bpy.data.meshes.new("Floor")
    n, verts, faces = 8, [], []
    for i in range(-n, n):
        for j in range(-n, n):
            b = len(verts)
            verts += [(i, j, 0), (i + 1, j, 0), (i + 1, j + 1, 0), (i, j + 1, 0)]
            faces.append((b, b + 1, b + 2, b + 3))
    me.from_pydata(verts, [], faces)
    fl = bpy.data.objects.new("Floor", me)
    sc.collection.objects.link(fl)
    m1 = bpy.data.materials.new("FloorA")
    m1.diffuse_color = (0.16, 0.16, 0.2, 1)
    m2 = bpy.data.materials.new("FloorB")
    m2.diffuse_color = (0.24, 0.24, 0.3, 1)
    me.materials.append(m1)
    me.materials.append(m2)
    for k, p in enumerate(me.polygons):
        i, j = divmod(k, 2 * n)
        p.material_index = (i + j) % 2
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 9
    sc.camera = cam
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
        sh = sc.display.shading
        sh.light = "STUDIO"
        sh.color_type = "MATERIAL"
        sh.show_cavity = True
        sh.show_object_outline = True
        sh.show_shadows = True
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 300
    sc.render.resolution_y = 300
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("W")
    w.color = (0.05, 0.05, 0.07)
    sc.world = w
    return cam


VIEWS = {
    # name: camera location (Blender), looks at the character's chest
    "front": (0, 14, 3.2),
    "side": (14, 0, 3.2),
    "3/4": (9, 10, 6),
}


def _aim(cam, loc, target=(0, 0, 2.6)):
    cam.location = Vector(loc)
    d = Vector(target) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


# ------------------------------------------------------------------ clips


class Clip:
    def __init__(self, anim: "Anim", name: str, frames: int, loop: bool, trigger, mode, blend_in, blend_out):
        self.anim = anim
        self.name = name
        self.frames = frames
        self.looping = loop
        act = bpy.data.actions.new(f"{anim.id}_{name}")
        act.use_fake_user = True
        act.use_frame_range = True
        act.frame_start = 0
        act.frame_end = frames
        act.use_cyclic = loop
        act["glitch_clip"] = name
        act["glitch_aura"] = anim.id
        act["glitch_loop"] = bool(loop)
        if trigger:
            act["glitch_trigger"] = trigger
        act["glitch_mode"] = mode
        act["glitch_blend_in"] = blend_in
        act["glitch_blend_out"] = blend_out
        self.action = act
        self._prev_q = {}

    def _bind(self):
        rig = self.anim.rig
        if rig.animation_data is None:
            rig.animation_data_create()
        rig.animation_data.action = self.action
        return rig

    def key(self, frame: float, ease: str = "INOUT", root=None, root_pos=None, neck=None, rs=None, ls=None, rh=None, lh=None):
        """Keyframe the given joints at `frame` (degrees, Roblox CFrame.Angles order)."""
        rig = self._bind()
        vals = {"root": root, "neck": neck, "rs": rs, "ls": ls, "rh": rh, "lh": lh}
        for j, v in vals.items():
            if v is None:
                continue
            pb = rig.pose.bones[j]
            pb.rotation_euler = angles(v)
            pb.keyframe_insert("rotation_euler", frame=frame)
            self._ease(f'pose.bones["{j}"].rotation_euler', frame, ease)
        if root_pos is not None:
            pb = rig.pose.bones["root"]
            pb.location = Vector(root_pos)
            pb.keyframe_insert("location", frame=frame)
            self._ease('pose.bones["root"].location', frame, ease)

    def pose(self, frame: float, p: dict, ease: str = "INOUT"):
        """key() with a dict: {"root": (..), "root_pos": (..), "rs": (..), ...}."""
        self.key(frame, ease=ease, **p)

    def _curves(self, path):
        act = self.action
        out = []
        try:  # Blender 4.4+ layered actions
            for layer in act.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        out += [fc for fc in bag.fcurves if fc.data_path == path]
        except AttributeError:
            pass
        if not out and hasattr(act, "fcurves"):
            out = [fc for fc in act.fcurves if fc.data_path == path]
        return out

    def all_curves(self):
        act = self.action
        out = []
        try:
            for layer in act.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        out += list(bag.fcurves)
        except AttributeError:
            pass
        if not out and hasattr(act, "fcurves"):
            out = list(act.fcurves)
        return out

    def _ease(self, path, frame, ease):
        interp, handle, easing = EASE.get(ease, EASE["INOUT"])
        for fc in self._curves(path):
            for kp in fc.keyframe_points:
                if abs(kp.co.x - frame) < 1e-3:
                    kp.interpolation = interp
                    if handle:
                        kp.handle_left_type = handle
                        kp.handle_right_type = handle
                    if easing:
                        kp.easing = easing
            fc.update()

    def marker(self, frame: float, event: str, arg: str | None = None):
        """Sync marker: emitted on the aura's Sync bus when playback crosses this frame."""
        name = f"fx:{event}" + (f":{arg}" if arg else "")
        m = self.action.pose_markers.new(name)
        m.frame = int(round(frame))

    def loop(self):
        """Make the cycle seamless: copy every curve's value at frame 0 to the last frame and
        give the curves cyclic extrapolation (so bezier handles flow across the loop point)."""
        end = self.frames
        for fc in self.all_curves():
            v0 = fc.evaluate(0)
            kp = None
            for k in fc.keyframe_points:
                if abs(k.co.x - end) < 1e-3:
                    kp = k
            if kp is None:
                kp = fc.keyframe_points.insert(end, v0)
            kp.co.y = v0
            first = fc.keyframe_points[0]
            kp.interpolation = first.interpolation
            kp.handle_left_type = first.handle_left_type
            kp.handle_right_type = first.handle_right_type
            if not any(m.type == "CYCLES" for m in fc.modifiers):
                fc.modifiers.new("CYCLES")
            fc.update()

    def noise(self, joint: str, axis: int, strength_deg: float, cycles=(2, 3, 5), seed: int = 0, loc=False, step=2):
        """Organic micro-motion baked ON TOP of the existing keys of one channel
        (axis 0/1/2 = Roblox x/y/z rotation, or root location in studs when loc=True).
        The noise is a sum of sines with whole cycles per clip, so looping clips stay seamless.
        Call it AFTER loop() and after all keys of that channel are set."""
        path = f'pose.bones["{joint}"].' + ("location" if loc else "rotation_euler")
        amp = strength_deg if loc else math.radians(strength_deg)
        n = self.frames
        rnd = [(math.sin(seed * 12.9898 + i * 78.233) * 43758.5453) % 1 for i in range(len(cycles))]
        for fc in self._curves(path):
            if fc.array_index != axis:
                continue
            pts = []
            for f in range(0, n + 1, step):
                w = sum(math.sin(2 * math.pi * (c * f / n + r)) / (k + 1) for k, (c, r) in enumerate(zip(cycles, rnd)))
                w /= sum(1 / (k + 1) for k in range(len(cycles)))
                pts.append((f, fc.evaluate(f) + amp * w))
            if n % step:
                pts.append((n, pts[0][1]))
            pts[-1] = (pts[-1][0], pts[0][1]) if self.looping else pts[-1]
            fc.keyframe_points.clear()
            for f, v in pts:
                k = fc.keyframe_points.insert(f, v)
                k.interpolation = "BEZIER"
                k.handle_left_type = k.handle_right_type = "AUTO_CLAMPED"
            fc.update()
            return
        raise ValueError(f"no keys on {path}[{axis}] yet: key the joint before adding noise")


# ------------------------------------------------------------------ the set


class Anim:
    def __init__(self, aura_id: str):
        self.id = aura_id
        self.lift = 0.0
        self.air = None
        self.clips: list[Clip] = []
        sc = _reset_scene()
        self.scene = sc
        self.rig = build_rig()
        self.cam = _stage(sc)
        sc["glitch_aura"] = aura_id

    def clip(self, name, seconds=None, frames=None, trigger=None, mode="replace", blend_in=0.08, blend_out=0.18):
        if frames is None:
            frames = max(2, int(round((seconds or 2) * FPS)))
        loop = trigger is None and name in ("idle", "walk")
        c = Clip(self, name, frames, loop, trigger, mode, blend_in, blend_out)
        self.clips.append(c)
        return c

    # -------------------------------------------------- checks
    def check(self, quiet=False):
        """Measures feet vs floor and arm/leg penetration of the torso over every frame.
        Returns a list of problem strings (printed too)."""
        problems = []
        rig = self.rig
        sc = self.scene
        for c in self.clips:
            rig.animation_data.action = c.action
            lows, sinks, floats, hits = [], 0, 0, 0
            for f in range(0, c.frames + (0 if c.looping else 1)):
                sc.frame_set(f)
                low = min(_lowest_sole(rig, "rh"), _lowest_sole(rig, "lh"))
                lows.append(low)
                lift = rig.pose.bones["root"].location.y if self.lift > 0 else 0
                if low < -0.08:
                    sinks += 1
                if self.lift <= 0 and low > 0.35 and c.name in ("idle",):
                    floats += 1
                hits += _arm_in_torso(rig)
            if sinks:
                problems.append(f"{c.name}: feet sink below the floor on {sinks} frames (min {min(lows):.2f} studs) -> the game lifts the body there")
            if floats:
                problems.append(f"{c.name}: both feet off the floor on {floats} frames (grounded set)")
            if hits:
                problems.append(f"{c.name}: an arm passes deep through the torso on {hits} frames")
        if not quiet:
            for p in problems:
                print("[check]", self.id, p)
            if not problems:
                print("[check]", self.id, "OK")
        return problems

    # -------------------------------------------------- export
    def save(self):
        os.makedirs(BLEND_DIR, exist_ok=True)
        path = os.path.join(BLEND_DIR, f"{self.id}.blend")
        self.scene["glitch_lift"] = float(self.lift)
        if self.air is not None:
            self.scene["glitch_air"] = float(self.air)
        bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
        print("[save]", path)
        return path

    def export(self):
        return export_scene(self.id, self.rig, self.scene, self.lift, self.air)

    def preview(self, frames_per_clip=8):
        return preview_scene(self.id, self.rig, self.scene, self.cam, frames_per_clip)

    def finish(self, preview=True):
        problems = self.check()
        self.save()
        self.export()
        if preview:
            self.preview()
        return problems


# ------------------------------------------------------------------ geometry helpers


def _bone_world(rig, name):
    return rig.matrix_world @ rig.pose.bones[name].matrix


def _part_corners(rig, bone, centre, size):
    """World corners of a body block riding `bone`."""
    pb = rig.pose.bones[bone]
    rest = rig.data.bones[bone].matrix_local
    m = rig.matrix_world @ pb.matrix @ rest.inverted()
    c = rb_point(centre)
    s = (size[0] / 2, size[2] / 2, size[1] / 2)
    out = []
    for dx in (-1, 1):
        for dy in (-1, 1):
            for dz in (-1, 1):
                out.append(m @ Vector((c.x + dx * s[0], c.y + dy * s[1], c.z + dz * s[2])))
    return out


def _lowest_sole(rig, leg):
    centre = (0.5, -2, 0) if leg == "rh" else (-0.5, -2, 0)
    return min(p.z for p in _part_corners(rig, leg, centre, (1, 2, 1)))


def _arm_in_torso(rig):
    """1 if a hand-end point of an arm is deep inside the torso box this frame."""
    pb = rig.pose.bones["root"]
    rest = rig.data.bones["root"].matrix_local
    torso_inv = (rig.matrix_world @ pb.matrix @ rest.inverted()).inverted()
    hit = 0
    for arm, x in (("rs", 1.5), ("ls", -1.5)):
        for p in _part_corners(rig, arm, (x, -0.5, 0), (0.4, 1.0, 0.4)):
            q = torso_inv @ p  # torso-rest blender space
            c = rb_point((0, 0, 0))
            d = q - c
            if abs(d.x) < 0.7 and abs(d.y) < 0.3 and abs(d.z) < 0.8:
                hit = 1
                break
    return hit


# ------------------------------------------------------------------ export (scene -> Luau)


def _clip_actions(aura_id):
    acts = [a for a in bpy.data.actions if a.get("glitch_aura") == aura_id and a.get("glitch_clip")]
    order = {"idle": 0, "walk": 1}
    acts.sort(key=lambda a: (order.get(a["glitch_clip"], 2), a["glitch_clip"]))
    return acts


def _fmt(nums, per_line=12, indent="\t\t\t\t"):
    lines = []
    for i in range(0, len(nums), per_line):
        lines.append(indent + ", ".join(nums[i : i + per_line]) + ",")
    return "\n".join(lines)


def _num(x, nd):
    s = f"{x:.{nd}f}".rstrip("0").rstrip(".")
    if s in ("-0", ""):
        s = "0"
    return s


def export_scene(aura_id, rig, sc, lift=0.0, air=None):
    acts = _clip_actions(aura_id)
    assert acts, f"no clips for {aura_id}"
    if rig.animation_data is None:
        rig.animation_data_create()
    out = []
    out.append(f"-- AUTO-GENERATED from art/anims/{aura_id}.blend by tools/blender/anim/lib.py.")
    out.append("-- The animation is authored in Blender: edit tools/blender/anim/auras/" + aura_id + ".py (or the")
    out.append("-- .blend) and re-run tools/blender/anim/run.sh, never edit this file by hand.")
    out.append("return {")
    out.append(f"\tlift = {_num(lift, 3)},")
    if air is not None:
        out.append(f"\tair = {_num(air, 3)},")
    out.append("\tclips = {")
    summary = []
    for act in acts:
        name = act["glitch_clip"]
        loop = bool(act.get("glitch_loop", False))
        frames = int(round(act.frame_end - act.frame_start))
        start = int(round(act.frame_start))
        n = frames if loop else frames + 1
        rig.animation_data.action = act
        q = {j: [] for j in JOINTS}
        p = []
        prev = {}
        moving = {j: False for j in JOINTS}
        for i in range(n):
            sc.frame_set(start + i)
            for j in JOINTS:
                mb = rig.pose.bones[j].matrix_basis
                qq = mb.to_quaternion().normalized()
                if j in prev and prev[j].dot(qq) < 0:
                    qq = -qq
                prev[j] = qq
                if abs(qq.w) < 0.99999:
                    moving[j] = True
                q[j] += [qq.x, qq.y, qq.z, qq.w]
                if j == "root":
                    t = mb.translation
                    p += [t.x, t.y, t.z]
        has_p = any(abs(v) > 1e-4 for v in p)
        out.append(f"\t\t{name} = {{")
        out.append(f"\t\t\tfps = {FPS},")
        out.append(f"\t\t\tn = {n},")
        out.append(f"\t\t\tlen = {_num(frames / FPS, 5)},")
        out.append(f"\t\t\tloop = {'true' if loop else 'false'},")
        if act.get("glitch_trigger"):
            out.append(f"\t\t\ttrigger = \"{act['glitch_trigger']}\",")
        out.append(f"\t\t\tmode = \"{act.get('glitch_mode', 'replace')}\",")
        out.append(f"\t\t\tblendIn = {_num(float(act.get('glitch_blend_in', 0.08)), 3)},")
        out.append(f"\t\t\tblendOut = {_num(float(act.get('glitch_blend_out', 0.18)), 3)},")
        for j in JOINTS:
            if not moving[j] and not (j == "root" and has_p):
                continue
            out.append(f"\t\t\t{j} = {{")
            out.append("\t\t\t\tq = {")
            out.append(_fmt([_num(v, 4) for v in q[j]], 12, "\t\t\t\t\t"))
            out.append("\t\t\t\t},")
            if j == "root" and has_p:
                out.append("\t\t\t\tp = {")
                out.append(_fmt([_num(v, 3) for v in p], 12, "\t\t\t\t\t"))
                out.append("\t\t\t\t},")
            out.append("\t\t\t},")
        evs = []
        for m in sorted(act.pose_markers, key=lambda m: m.frame):
            if not m.name.startswith("fx:"):
                continue
            parts = m.name[3:].split(":", 1)
            t = (m.frame - start) / FPS
            if len(parts) > 1 and parts[1]:
                evs.append(f"{{ {_num(t, 4)}, \"{parts[0]}\", \"{parts[1]}\" }}")
            else:
                evs.append(f"{{ {_num(t, 4)}, \"{parts[0]}\" }}")
        out.append("\t\t\tev = {" + (" " + ", ".join(evs) + " " if evs else "") + "},")
        out.append("\t\t},")
        summary.append(f"{name}({frames}f{' loop' if loop else ''}{', ' + str(len(evs)) + ' markers' if evs else ''}{', trigger=' + act['glitch_trigger'] if act.get('glitch_trigger') else ''})")
    out.append("\t},")
    out.append("}")
    os.makedirs(ANIMS_DIR, exist_ok=True)
    path = os.path.join(ANIMS_DIR, f"{aura_id}.lua")
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")
    print("[export]", path, " ".join(summary))
    return path


# ------------------------------------------------------------------ preview (contact sheets)


def preview_scene(aura_id, rig, sc, cam, frames_per_clip=8, views=("front", "side", "3/4")):
    """Renders every clip from several views into build/anim_preview/<Aura>_<clip>.png
    (rows = views, columns = frames, labels = frame number and any marker on it)."""
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    acts = _clip_actions(aura_id)
    outs = []
    for act in acts:
        name = act["glitch_clip"]
        rig.animation_data.action = act
        frames = int(round(act.frame_end - act.frame_start))
        loop = bool(act.get("glitch_loop", False))
        k = frames_per_clip
        picks = sorted({int(round(i * frames / (k if loop else max(1, k - 1)))) for i in range(k)})
        markers = {m.frame: m.name[3:] for m in act.pose_markers}
        tmp = tempfile.mkdtemp(prefix="glitchanim_")
        tiles = []
        for v in views:
            _aim(cam, VIEWS[v])
            for f in picks:
                sc.frame_set(int(act.frame_start) + f)
                fp = os.path.join(tmp, f"{v.replace('/', '')}_{f:04d}.png")
                sc.render.filepath = fp
                bpy.ops.render.render(write_still=True)
                near = [mk for mf, mk in markers.items() if abs(mf - f) <= max(1, frames // (2 * k))]
                label = f"{v} f{f}" + (f" [{','.join(near)}]" if near else "")
                tiles.append((fp, label))
        dst = os.path.join(PREVIEW_DIR, f"{aura_id}_{name}.png")
        cmd = ["montage"]
        for fp, label in tiles:
            cmd += ["-label", label, fp]
        cmd += [
            "-tile", f"{len(picks)}x{len(views)}", "-geometry", "+2+2", "-background", "#111",
            "-fill", "#ddd", "-pointsize", "13", "-title", f"{aura_id} / {name}  ({frames} f @ {FPS} fps)", dst,
        ]
        try:
            subprocess.run(cmd, check=True, capture_output=True)
            outs.append(dst)
            print("[preview]", dst)
        except Exception as e:  # noqa: BLE001
            print("[preview] montage failed:", e)
    return outs


# ------------------------------------------------------------------ re-export a saved .blend


def export_blend(path):
    bpy.ops.wm.open_mainfile(filepath=path)
    sc = bpy.context.scene
    aura = sc.get("glitch_aura")
    rig = bpy.data.objects.get("R6")
    assert aura and rig, "not a Glitch RNG animation file"
    lift = float(sc.get("glitch_lift", 0))
    air = sc.get("glitch_air")
    export_scene(aura, rig, sc, lift, float(air) if air is not None else None)
    cam = bpy.data.objects.get("Cam")
    if cam:
        preview_scene(aura, rig, sc, cam)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if argv and argv[0] == "--blend":
        export_blend(argv[1])
