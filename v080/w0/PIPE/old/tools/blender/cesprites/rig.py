"""Scene rig: Cycles setup, sky + sun, shadow catcher, orthographic sprite camera, render passes.

Conventions: the model root sits at the sprite anchor (world origin) - for vehicles the rear-bumper
centre on the ground, for props the centre of the near face on the ground. The camera looks along +Y
(from behind / from the road), pitched down by the elevation angle. Angles rotate the model root
about Z: positive yaw = rotated to the RIGHT (nose to +X, right flank visible).
"""
import math
import os

import bpy
import numpy as np
from mathutils import Vector

from . import materials as M
from . import meshutil as MU

# direction TOWARDS the sun, fixed relative to the camera: upper left, slightly from the viewer's side
SUN_DIR = Vector((-0.55, -0.55, 0.92)).normalized()
SUN_STRENGTH = 2.4
SKY_STRENGTH = 0.85
SHADOW_SKY = 0.22      # weak sky in the shadow pass -> compact, sun-dominated ground shadow


class Rig:
    def __init__(self, quick=False):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        M.reset()
        sc = bpy.context.scene
        self.scene = sc
        self.quick = quick
        sc.render.engine = "CYCLES"
        cy = sc.cycles
        cy.device = "CPU"
        sc.render.threads_mode = "FIXED"
        sc.render.threads = int(os.environ.get("CE_THREADS", "3"))
        sc.render.film_transparent = True
        sc.render.use_persistent_data = True
        sc.render.resolution_percentage = 100
        sc.render.filter_size = 1.25
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
        sc.view_settings.exposure = 0.0
        sc.view_settings.gamma = 1.0
        im = sc.render.image_settings
        im.file_format = "PNG"
        im.color_mode = "RGBA"
        im.color_depth = "8"
        im.compression = 15
        cy.use_adaptive_sampling = True
        cy.adaptive_threshold = 0.02
        cy.denoiser = "OPENIMAGEDENOISE"
        try:
            cy.denoising_use_gpu = False
        except Exception:
            pass
        cy.caustics_reflective = False
        cy.caustics_refractive = False
        cy.sample_clamp_indirect = 4.0
        self.col = sc.collection
        MU.set_collection(self.col)
        self.world_sky = self._sky_world()
        self.world_black = self._black_world()
        sc.world = self.world_sky
        sun_data = bpy.data.lights.new("sun", "SUN")
        sun_data.energy = SUN_STRENGTH
        sun_data.angle = math.radians(4.0)
        sun_data.color = (1.0, 0.97, 0.92)
        self.sun = bpy.data.objects.new("sun", sun_data)
        self.sun.rotation_euler = SUN_DIR.to_track_quat("Z", "Y").to_euler()
        self.col.objects.link(self.sun)
        cam = bpy.data.cameras.new("cam")
        cam.type = "ORTHO"
        cam.sensor_fit = "HORIZONTAL"
        cam.clip_start = 0.05
        cam.clip_end = 5000.0
        self.cam = bpy.data.objects.new("cam", cam)
        self.col.objects.link(self.cam)
        sc.camera = self.cam
        self.root = MU.empty("ROOT")
        self.catchers = []
        self.samples_base = 8 if quick else 40
        self.samples_emit = 4 if quick else 12

    # --- worlds ---------------------------------------------------------------------------------

    def _sky_world(self):
        w = bpy.data.worlds.new("sky")
        nt = w.node_tree
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        nb = M.NB(nt)
        tc = nb.node("ShaderNodeTexCoord")
        sep = nb.node("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Generated"], sep.inputs[0])
        zf = nb.math("MULTIPLY_ADD", sep.outputs[2], 0.5, 0.5)
        col = nb.ramp(zf, [
            (0.0, M.srgb("#3a3631")),
            (0.47, M.srgb("#6d6a63")),
            (0.5, M.srgb("#e4e8ec")),
            (0.62, M.srgb("#b9cde3")),
            (1.0, M.srgb("#7fa3cf")),
        ])
        bg = nb.node("ShaderNodeBackground")
        nt.links.new(col, bg.inputs["Color"])
        bg.inputs["Strength"].default_value = SKY_STRENGTH
        self.sky_bg = bg
        out = nb.node("ShaderNodeOutputWorld")
        nt.links.new(bg.outputs[0], out.inputs["Surface"])
        return w

    def _black_world(self):
        w = bpy.data.worlds.new("black")
        nt = w.node_tree
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        bg = nt.nodes.new("ShaderNodeBackground")
        bg.inputs["Color"].default_value = (0, 0, 0, 1)
        bg.inputs["Strength"].default_value = 0.0
        out = nt.nodes.new("ShaderNodeOutputWorld")
        nt.links.new(bg.outputs[0], out.inputs["Surface"])
        return w

    # --- scene content --------------------------------------------------------------------------

    def add_catcher(self, sx, sy, center=(0.0, 0.0), z=0.0, parent=None, color="#5b5b58"):
        """Shadow catcher plane (base pass only). Parent defaults to the model root."""
        import bmesh
        bm = bmesh.new()
        res = bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
        for v in res["verts"]:
            v.co.x = v.co.x * sx + center[0]
            v.co.y = v.co.y * sy + center[1]
            v.co.z = z
        mat = M.basic("catcher", color, rough=0.9)
        ob = MU.make("catcher", bm, mat, parent=parent or self.root)
        ob.is_shadow_catcher = True
        self.catchers.append(ob)
        return ob

    def set_yaw(self, yaw_deg):
        self.root.rotation_euler = (0.0, 0.0, math.radians(-yaw_deg))

    # --- measuring ------------------------------------------------------------------------------

    def model_points(self, include_catchers=False):
        self.root.rotation_euler = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        out = []
        for ob in self.root.children_recursive:
            if ob.type not in ("MESH", "CURVE", "FONT") or ob.hide_render:
                continue
            if ob in self.catchers and not include_catchers:
                continue
            ev = ob.evaluated_get(deps)
            me = ev.to_mesh()
            n = len(me.vertices)
            if n:
                co = np.empty(n * 3, dtype=np.float64)
                me.vertices.foreach_get("co", co)
                co = co.reshape(-1, 3)
                mw = np.array(ob.matrix_world)
                out.append(co @ mw[:3, :3].T + mw[:3, 3])
            ev.to_mesh_clear()
        if not out:
            return np.zeros((1, 3))
        return np.concatenate(out)

    # --- camera ---------------------------------------------------------------------------------

    def frame_ortho(self, elevation_deg, image_width_m, cell, anchor, dist=400.0):
        th = math.radians(elevation_deg)
        sc = self.scene
        cam = self.cam
        cam.data.type = "ORTHO"
        cam.data.sensor_fit = "HORIZONTAL"
        cam.data.ortho_scale = image_width_m
        cam.data.shift_x = 0.0
        cam.data.shift_y = 0.0
        sc.render.resolution_x = int(cell[0])
        sc.render.resolution_y = int(cell[1])
        wm = image_width_m
        hm = wm * cell[1] / cell[0]
        r = Vector((1.0, 0.0, 0.0))
        u = Vector((0.0, math.sin(th), math.cos(th)))
        f = Vector((0.0, math.cos(th), -math.sin(th)))
        c = -(anchor[0] - 0.5) * wm * r - (0.5 - anchor[1]) * hm * u - dist * f
        cam.location = c
        cam.rotation_euler = (math.pi / 2 - th, 0.0, 0.0)

    def frame_persp(self, location, target, lens_mm, cell, shift=(0.0, 0.0)):
        sc = self.scene
        cam = self.cam
        cam.data.type = "PERSP"
        cam.data.sensor_fit = "HORIZONTAL"
        cam.data.sensor_width = 36.0
        cam.data.lens = lens_mm
        cam.data.shift_x, cam.data.shift_y = shift
        sc.render.resolution_x = int(cell[0])
        sc.render.resolution_y = int(cell[1])
        loc = Vector(location)
        cam.location = loc
        d = Vector(target) - loc
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

    def frame_game(self, cam, rect, supersample):
        """Perspective game camera (pivot = world origin = car centre on the ground): camera
        cam["distance_m"] behind and cam["height_m"] above the origin, looking horizontally along +Y,
        horizontal field of view cam["fov_deg"] over cam["screen"][0] px, horizon at
        cam["horizon_y_frac"]. rect = (x0, y0, x1, y1) in game screen px; the render shows exactly that
        screen region (lens shift), supersample times larger."""
        sc = self.scene
        c = self.cam
        sw, sh = cam["screen"]
        f = game_focal(cam)
        x0, y0, x1, y1 = rect
        res_x = int(round((x1 - x0) * supersample))
        res_y = int(round((y1 - y0) * supersample))
        c.data.type = "PERSP"
        c.data.sensor_fit = "HORIZONTAL"
        c.data.sensor_width = 36.0
        c.data.lens = f * supersample * 36.0 / res_x
        cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
        c.data.shift_x = (cx - sw * 0.5) / (x1 - x0)
        c.data.shift_y = -(cy - sh * cam["horizon_y_frac"]) / (x1 - x0)
        c.data.clip_start = 0.05
        c.data.clip_end = 500.0
        sc.render.resolution_x = res_x
        sc.render.resolution_y = res_y
        c.location = Vector((0.0, -cam["distance_m"], cam["height_m"]))
        c.rotation_euler = (math.pi / 2, 0.0, 0.0)

    def frame_face(self, loc, rot, ortho_w, res_x, res_y):
        """Orthographic face-on camera for box faces (render covers exactly ortho_w x res_y/res_x*ortho_w)."""
        sc = self.scene
        c = self.cam
        c.data.type = "ORTHO"
        c.data.sensor_fit = "HORIZONTAL"
        c.data.ortho_scale = ortho_w
        c.data.shift_x = 0.0
        c.data.shift_y = 0.0
        c.data.clip_start = 0.1
        c.data.clip_end = 300.0
        sc.render.resolution_x = int(res_x)
        sc.render.resolution_y = int(res_y)
        c.location = Vector(loc)
        c.rotation_euler = rot

    def box_lighting(self):
        """World-fixed light for box faces (same for every face): sky + sun from above, slightly behind."""
        d = Vector((0.0, -0.42, 0.91)).normalized()
        self.sun.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        self.sun.data.energy = 2.1

    # --- passes and rendering -------------------------------------------------------------------

    def _model_objects(self):
        return [o for o in self.root.children_recursive if o not in self.catchers]

    def set_pass(self, layer, samples=None):
        """layer: 'base' (object only, lit), 'shadow' (only the ground shadow, objects invisible to the
        camera) or an emission layer name."""
        sc = self.scene
        cy = sc.cycles
        shadow = layer == "shadow"
        M.set_pass("base" if shadow else layer)
        # dithering (+-1 LSB noise) only for the colour pass; it would leave faint noise in masks/emission
        sc.render.dither_intensity = 1.0 if layer == "base" else 0.0
        base = layer == "base" or shadow
        sc.world = self.world_sky if base else self.world_black
        self.sky_bg.inputs["Strength"].default_value = SHADOW_SKY if shadow else SKY_STRENGTH
        self.sun.hide_render = not base
        for c in self.catchers:
            c.hide_render = not shadow
        for o in self._model_objects():
            o.visible_camera = not shadow
        if shadow:
            cy.samples = samples or (6 if self.quick else 20)
            cy.use_denoising = True
            cy.max_bounces = 1
            cy.diffuse_bounces = 1
            cy.glossy_bounces = 0
            cy.transmission_bounces = 0
            cy.transparent_max_bounces = 2
            cy.volume_bounces = 0
        elif base:
            cy.samples = samples or self.samples_base
            cy.use_denoising = True
            cy.max_bounces = 4
            cy.diffuse_bounces = 2
            cy.glossy_bounces = 2
            cy.transmission_bounces = 2
            cy.transparent_max_bounces = 8
            cy.volume_bounces = 0
        else:
            cy.samples = samples or self.samples_emit
            cy.use_denoising = False
            cy.max_bounces = 0
            cy.diffuse_bounces = 0
            cy.glossy_bounces = 0
            cy.transmission_bounces = 0
            # lamp lenses (materials.lens) are transparent in the light passes
            cy.transparent_max_bounces = 8
            cy.volume_bounces = 0

    def render(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path


def game_focal(cam):
    """Focal length in game pixels for the horizontal field of view."""
    return cam["screen"][0] * 0.5 / math.tan(math.radians(cam["fov_deg"]) * 0.5)


def game_project(pts, cam, yaw_deg=0.0):
    """Screen positions (game px, y down) of model points (car centre at the origin) turned by yaw."""
    a = math.radians(-yaw_deg)
    ca, sa = math.cos(a), math.sin(a)
    x = pts[:, 0] * ca - pts[:, 1] * sa
    y = pts[:, 0] * sa + pts[:, 1] * ca
    z = pts[:, 2]
    f = game_focal(cam)
    d = np.maximum(y + cam["distance_m"], 0.2)
    sx = cam["screen"][0] * 0.5 + f * x / d
    sy = cam["screen"][1] * cam["horizon_y_frac"] + f * (cam["height_m"] - z) / d
    return sx, sy


def shadow_points(pts, sun_dir=None):
    """Ground projection of points along the sun direction (for framing the baked shadow)."""
    s = SUN_DIR if sun_dir is None else sun_dir
    k = pts[:, 2] / max(1e-3, s.z)
    out = pts.copy()
    out[:, 0] = pts[:, 0] - s.x * k
    out[:, 1] = pts[:, 1] - s.y * k
    out[:, 2] = 0.0
    return out


def extents(pts, yaws_deg, elevation_deg):
    """Image-space extents (metres, relative to the anchor) of points over several yaw angles.
    Returns x_min, x_max, y_min, y_max (y = up in the image)."""
    th = math.radians(elevation_deg)
    xs0, xs1, ys0, ys1 = [], [], [], []
    for yaw in yaws_deg:
        a = math.radians(-yaw)
        ca, sa = math.cos(a), math.sin(a)
        px = pts[:, 0] * ca - pts[:, 1] * sa
        py = pts[:, 0] * sa + pts[:, 1] * ca
        iy = py * math.sin(th) + pts[:, 2] * math.cos(th)
        xs0.append(px.min())
        xs1.append(px.max())
        ys0.append(iy.min())
        ys1.append(iy.max())
    return float(min(xs0)), float(max(xs1)), float(min(ys0)), float(max(ys1))


def plan_cell(ext, ppm, side=0.1, top=0.1, bottom=0.08, align=4, centered=True, min_cell=(16, 16)):
    """Cell size (px), image_width_m and anchor for the given extents and pixels per metre."""
    x0, x1, y0, y1 = ext
    if centered:
        half = max(-x0, x1) + side
        wm = 2.0 * half
        ax_m = half
    else:
        wm = (x1 - x0) + 2 * side
        ax_m = -x0 + side
    t = y1 + top
    b = max(0.0, -y0) + bottom
    hm = t + b
    cw = max(min_cell[0], int(math.ceil(wm * ppm / align)) * align)
    ch = max(min_cell[1], int(math.ceil(hm * ppm / align)) * align)
    wm2 = cw / ppm
    hm2 = ch / ppm
    ax = (ax_m + (wm2 - wm) * 0.5) / wm2 if not centered else 0.5
    ay = 1.0 - b / hm2
    return (int(cw), int(ch)), float(wm2), (round(float(ax), 4), round(float(ay), 4))
