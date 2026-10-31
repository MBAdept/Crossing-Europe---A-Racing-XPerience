#!/usr/bin/env python3
"""Steam key art for Crossing Europe: a 3D synthwave scene with the game's red Sportwagen.

Renders the background images (no text, no logo) for the Steam library formats with Cycles (CPU,
adaptive sampling, OpenImageDenoise) to linear EXR, then adds bloom, a soft highlight shoulder and the
sRGB display transform ("Standard" look, saturated neon) in numpy and writes 8-bit PNGs.

Usage (from the repository root, Blender 5.2 as Python module):
  CE_THREADS=3 /home/user/tools/bpyenv/bin/python tools/steam/keyart_scene.py \
      [--shots portrait,landscape,hero,icon_bg,portrait_b] [--scale 0.25] [--samples N] [--out DIR]

  --shots     comma separated shot names (default: all)
  --scale     render size factor; != 1 writes <shot>_pv.png previews (e.g. 0.25, few samples)
  --samples   max. Cycles samples (default: per shot; previews 16)
  --out       output directory (default: $STEAM_SCENE_OUT, else /tmp/crossing-europe-steam/scene)
  --keep-exr  keep the linear EXR renders (_<shot>.exr)
  --exr-dir   directory for the EXR renders (default: --out)
  --post-only re-run only the post (bloom, tone, dither) on kept EXRs
  --crop      x0,y0,x1,y1 fractions (y from the top): render only that region (detail checks)

Output (exact sizes, 8-bit RGB PNG, no text / logo):
  portrait.png 1200x1800, landscape.png 1840x860, hero.png 3840x1240, icon_bg.png 1024x1024,
  portrait_b.png 1200x1800 (alternative portrait: oncoming car, low front 3/4)
Every format has its own camera (no crops); the lens shift puts the road's vanishing point exactly at
SHOTS[..]["cam"]["vanish"], so horizon / sun / free logo areas are placed precisely.

Scene (metres; the road runs along +Y straight into the sun):
  world   sky gradient (navy -> purple -> magenta horizon), warm glow + halo rings around the sun, the
          striped retro sun (world shader: always on the horizon behind everything), screen-sized stars
  ridges  three layered low-poly mountain ridges on arcs around the origin (1.5 / 2.3 / 3.2 km), dark
          purple with emissive pink / violet / cyan crest lines (+ soft glow ribbons); height per shot
  floor   endless dark glossy plane with a footprint-filtered (alias-free) glowing magenta grid and
          horizon haze that matches the sky
  road    straight two-lane road (2 x 3.75 m) with cyan edge lines and a yellow dashed centre line
          (off in icon_bg: it would show between the C and the E); deep indigo-violet asphalt, only
          slightly glossy at a constant roughness, so the warm sun is not mirrored as brown smears
  car     the game's player car: cesprites.player_cars.build(rig, params of "player/sportwagen"),
          rendered in its base pass with the tail-light layer added as emission (the lamp internals
          glow through the red lenses); portrait_b additionally lights the headlights. The door
          mirrors are seated on the body (their arms float ~11 cm above it in the sprite model).
  lights  warm sun lamp from the sun's direction (diffuse only: reflections show the painted world
          sun), pink + cyan strip lights along the flanks, a pink kicker on the rear quarter and a
          dim violet fill from the camera side (car-frame rigs in LIGHT_RIGS)
  speed   Cycles motion blur: camera, car and its lights ride on a keyframed mover (1.1 m during the
          shutter, 0.5 m in landscape / hero so the grid keeps its lines), so road dashes and grid
          streak while the car stays sharp; tyres / rims spin
Post (numpy): multi-scale bloom with a soft threshold, vignette, optional darkening of the logo side
(landscape, hero), per-channel soft shoulder (keeps neon saturated like Blender's "Standard" view
transform; AgX / Filmic wash the pink and cyan out), sRGB, +-1 LSB dither against banding.
"""
import argparse
import math
import os
import random
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))

import bpy  # noqa: E402  (must come first: registers bmesh / mathutils)
import bmesh  # noqa: E402
from bpy_extras.object_utils import world_to_camera_view  # noqa: E402
from mathutils import Vector  # noqa: E402

from cesprites import catalog, player_cars  # noqa: E402
from cesprites import materials as M  # noqa: E402
from cesprites import rig as R  # noqa: E402

DEFAULT_OUT = os.environ.get("STEAM_SCENE_OUT", "/tmp/crossing-europe-steam/scene")

# brand colours (title screen)
PINK = "#ff2e88"
CYAN = "#29d8f5"
INK = "#1a0533"
SUN_TOP = "#ffe066"      # title-screen sun (the logo's paler #fff59e would compete with the logo)
SUN_MID = "#ff8f29"
SUN_BOT = "#ff2e87"
DASH_YELLOW = "#ffc928"
SUN_GAIN = 0.94         # sun disc emission; after the post the top reads ~(252,219,126), the centre
                        # ~(253,142,107) (title-screen sun: (255,224,102) -> (255,132,65))
ASPHALT = ("#0e0a26", "#1a1240")   # deep indigo-violet asphalt (grain mix), like the title-screen road

LANE_W = 3.75           # config/game_config.json road.lane_width_m (Landstrasse: 2 lanes)
EDGE_X = 2 * LANE_W + 0.12
ROAD_HALF = EDGE_X + 0.55
ROAD_SPEC = 0.12        # asphalt "Specular IOR Level" (per shot: road_spec)
ROAD_ROUGH = 0.75       # asphalt roughness, constant (per shot: road_rough); 0.5 still mirrored the
                        # sun as a warm sheen at the grazing angles of the low cameras


def lin(hexcol, k=1.0):
    c = M.srgb(hexcol)
    return (c[0] * k, c[1] * k, c[2] * k, 1.0)


def smoothstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------------------------------------
# node helpers and per-shot controls
# ------------------------------------------------------------------------------------------------

CTRL = {}   # name -> list of (socket) default values that are set per shot


class G(M.NB):
    """cesprites.materials.NB plus vector maths, smoothstep and registered control values."""

    def ctrl(self, name, value=0.0):
        n = self.node("ShaderNodeValue")
        n.label = name
        n.outputs[0].default_value = value
        CTRL.setdefault(name, []).append(n.outputs[0])
        return n.outputs[0]

    def ctrl_vec(self, name, value=(0.0, 0.0, 0.0)):
        n = self.node("ShaderNodeCombineXYZ")
        n.label = name
        for i in range(3):
            n.inputs[i].default_value = value[i]
        CTRL.setdefault(name, []).append(n)
        return n.outputs[0]

    def vm(self, op, a, b=None, s=None):
        n = self.node("ShaderNodeVectorMath", operation=op)
        self.feed(n.inputs[0], a)
        if b is not None:
            self.feed(n.inputs[1], b)
        if s is not None:
            self.feed(n.inputs["Scale"], s)
        return n

    def dot(self, a, b):
        return self.vm("DOT_PRODUCT", a, b).outputs["Value"]

    def norm(self, a):
        return self.vm("NORMALIZE", a).outputs[0]

    def vsub(self, a, b):
        return self.vm("SUBTRACT", a, b).outputs[0]

    def sep(self, v):
        n = self.node("ShaderNodeSeparateXYZ")
        self.feed(n.inputs[0], v)
        return n.outputs[0], n.outputs[1], n.outputs[2]

    def comb(self, x, y, z):
        n = self.node("ShaderNodeCombineXYZ")
        self.feed(n.inputs[0], x)
        self.feed(n.inputs[1], y)
        self.feed(n.inputs[2], z)
        return n.outputs[0]

    def mapr(self, x, a, b, c=0.0, d=1.0, interp="LINEAR"):
        n = self.node("ShaderNodeMapRange", interpolation_type=interp, clamp=True)
        self.feed(n.inputs["Value"], x)
        self.feed(n.inputs["From Min"], a)
        self.feed(n.inputs["From Max"], b)
        self.feed(n.inputs["To Min"], c)
        self.feed(n.inputs["To Max"], d)
        return n.outputs["Result"]

    def smooth(self, e0, e1, x):
        return self.mapr(x, e0, e1, 0.0, 1.0, "SMOOTHSTEP")

    def mn(self, a, b):
        return self.math("MINIMUM", a, b)

    def mx(self, a, b):
        return self.math("MAXIMUM", a, b)

    def div(self, a, b):
        return self.math("DIVIDE", a, b)

    def exp(self, a):
        return self.math("EXPONENT", a)

    def sq(self, a):
        return self.mul(a, a)

    def colk(self, col, k):
        """colour (rgba tuple or socket) times scalar (number or socket) -> vector socket"""
        return self.color_scale(col, k)

    def cadd(self, *cols):
        acc = cols[0]
        for c in cols[1:]:
            acc = self.vadd(acc, c)
        return acc

    def periodic_dist(self, x, period, offset=0.0):
        """distance of x to the nearest multiple of period (+offset), in [0, period/2]"""
        q = self.add(self.div(self.sub(x, offset), period), 0.5)
        return self.mul(self.absf(self.sub(self.math("FRACT", q), 0.5)), period)

    def line_cov(self, t, a0, w, spacing, min_px=1.0, dim=0.5):
        """Box-filtered coverage of a line of half width a0 at distance t, pixel footprint w (m), lines
        every `spacing` m. The half width grows to min_px/2 pixels (lines stay visible, merge into a band
        near the horizon) and the intensity drops by (a0/a)^dim when it grows."""
        a = self.mx(a0, self.mul(w, 0.5 * min_px)) if min_px > 0 else a0
        wc = self.mn(self.mx(w, 1e-4), spacing)
        hi = self.mn(self.add(t, self.mul(wc, 0.5)), a)
        lo = self.mx(self.sub(t, self.mul(wc, 0.5)), self.mul(a, -1.0))
        c = self.div(self.mx(self.sub(hi, lo), 0.0), wc)
        avg = self.mn(self.div(self.mul(a, 2.0), spacing), 1.0)
        f = self.smooth(0.25 * spacing, spacing, w)
        c = self.mixf(f, c, avg)
        if min_px > 0 and dim > 0:
            c = self.mul(c, self.math("POWER", self.div(a0, a), dim))
        return c

    def glow_cov(self, t, g, w, spacing):
        """exp(-t/g) halo around lines, faded to its period average where the footprint gets coarse."""
        e = self.exp(self.mul(self.div(t, g), -1.0))
        f = self.smooth(0.3 * g, 1.5 * g, w)
        return self.mixf(f, e, min(1.0, 2.0 * g / spacing))


def set_ctrl(name, value):
    for s in CTRL.get(name, []):
        if isinstance(s, bpy.types.Node):           # CombineXYZ vector control
            for i in range(3):
                s.inputs[i].default_value = float(value[i])
        else:
            s.default_value = float(value)


def new_mat(name):
    m = bpy.data.materials.new(name)
    try:
        if not m.node_tree:
            m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    return m, G(nt)


def out_surface(nb, shader):
    out = nb.node("ShaderNodeOutputMaterial")
    nb.links.new(shader, out.inputs["Surface"])


def emission(nb, col, strength=1.0):
    e = nb.node("ShaderNodeEmission")
    nb.feed(e.inputs["Color"], col)
    e.inputs["Strength"].default_value = strength
    return e.outputs[0]


def add_shader(nb, a, b):
    n = nb.node("ShaderNodeAddShader")
    nb.links.new(a, n.inputs[0])
    nb.links.new(b, n.inputs[1])
    return n.outputs[0]


def mix_shader(nb, fac, a, b):
    n = nb.node("ShaderNodeMixShader")
    nb.feed(n.inputs[0], fac)
    nb.links.new(a, n.inputs[1])
    nb.links.new(b, n.inputs[2])
    return n.outputs[0]


# ------------------------------------------------------------------------------------------------
# sky (node group shared by the world and the haze of floor, road and ridges)
# ------------------------------------------------------------------------------------------------

SKY_STOPS = [   # u = sqrt(max(z, 0)) of the view direction -> colour
    (0.00, "#5c1a6c"),
    (0.07, "#46145f"),
    (0.15, "#2f0f53"),
    (0.27, "#1c0a41"),
    (0.43, "#10072f"),
    (0.63, "#090520"),
    (1.00, "#050316"),
]


def sky_group():
    g = bpy.data.node_groups.new("KA_SKY", "ShaderNodeTree")
    g.interface.new_socket(name="Dir", in_out="INPUT", socket_type="NodeSocketVector")
    g.interface.new_socket(name="Color", in_out="OUTPUT", socket_type="NodeSocketColor")
    nb = G(g)
    gi = nb.node("NodeGroupInput")
    go = nb.node("NodeGroupOutput")
    d = nb.norm(gi.outputs["Dir"])
    _x, _y, z = nb.sep(d)
    zc = nb.mx(z, 0.0)
    u = nb.math("SQRT", zc)
    base = nb.ramp(u, [(p, lin(c)) for p, c in SKY_STOPS])
    base = nb.colk(base, nb.ctrl("sky_gain", 1.0))
    sd = nb.ctrl_vec("sun_dir", (0.0, 1.0, 0.05))
    cosa = nb.dot(d, sd)
    a = nb.math("ARCCOSINE", nb.mn(nb.mx(cosa, -1.0), 1.0))
    rho = nb.ctrl("sun_rho", 0.2)
    ga = nb.mx(nb.sub(a, rho), 0.0)
    # tight warm halo hugging the disc
    halo = nb.exp(nb.mul(nb.div(ga, nb.mul(rho, 0.22)), -1.0))
    # broad sunset glow along the horizon around the sun
    broad = nb.mul(nb.exp(nb.mul(nb.div(a, 0.6), -1.0)), nb.exp(nb.mul(nb.div(zc, 0.07), -1.0)))
    # two soft stepped halo rings (title screen look)
    r1 = nb.NOT(nb.smooth(nb.mul(rho, 1.36), nb.mul(rho, 1.40), a))
    r2 = nb.NOT(nb.smooth(nb.mul(rho, 1.80), nb.mul(rho, 1.86), a))
    rings = nb.add(nb.mul(r1, 0.55), nb.mul(r2, 0.45))
    col = nb.cadd(base,
                  nb.colk(lin("#ff4f8a"), nb.mul(halo, nb.ctrl("halo_gain", 0.26))),
                  nb.colk(lin("#ff3d7a"), nb.mul(broad, nb.ctrl("broad_gain", 0.10))),
                  nb.colk(lin("#4a1a66"), nb.mul(rings, nb.ctrl("ring_gain", 0.045))))
    nb.links.new(col, go.inputs["Color"])
    return g


def sky_node(nb, group, direction):
    n = nb.node("ShaderNodeGroup")
    n.node_tree = group
    nb.feed(n.inputs["Dir"], direction)
    return n.outputs["Color"]


def build_world(sky):
    w = bpy.data.worlds.new("keyart_sky")
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    nb = G(nt)
    tc = nb.node("ShaderNodeTexCoord")
    d = nb.norm(tc.outputs["Generated"])
    _x, _y, z = nb.sep(d)
    col = sky_node(nb, sky, d)
    lp = nb.node("ShaderNodeLightPath")
    cam_ray = lp.outputs["Is Camera Ray"]

    # --- retro sun: gradient disc, horizontal cut-outs in the lower half
    sd = nb.ctrl_vec("sun_dir", (0.0, 1.0, 0.05))
    su = nb.ctrl_vec("sun_up", (0.0, 0.0, 1.0))
    rho = nb.ctrl("sun_rho", 0.2)
    a = nb.math("ARCCOSINE", nb.mn(nb.mx(nb.dot(d, sd), -1.0), 1.0))
    inside = nb.lt(a, rho)
    t = nb.div(nb.dot(d, su), nb.math("SINE", rho))          # -1 bottom .. +1 top
    sun_col = nb.ramp(nb.madd(t, 0.5, 0.5), [
        (0.00, lin(SUN_BOT)), (0.30, lin("#ff4a62")), (0.52, lin(SUN_MID)), (0.74, lin("#ffc04d")),
        (1.00, lin(SUN_TOP))])
    # cut-outs: below t0 the period shrinks a little and the gaps grow towards the bottom
    s = nb.mx(nb.sub(nb.ctrl("stripe_t0", 0.30), t), 0.0)    # 0 at the first gap .. ~1.3
    per = nb.ctrl("stripe_period", 0.18)
    q = nb.div(s, per)
    gap_frac = nb.madd(s, nb.ctrl("stripe_grow", 0.36), nb.ctrl("stripe_min", 0.09))
    gap = nb.AND(nb.gt(nb.math("FRACT", q), nb.sub(1.0, gap_frac)), nb.gt(s, 0.0))
    sun_on = nb.mul(inside, nb.NOT(gap))
    sun = nb.colk(sun_col, nb.mul(sun_on, nb.ctrl("sun_gain", SUN_GAIN)))

    # --- stars: 2-D Voronoi in screen pixels (gnomonic projection with the shot camera)
    cf = nb.ctrl_vec("cam_f", (0.0, 1.0, 0.0))
    cr = nb.ctrl_vec("cam_r", (1.0, 0.0, 0.0))
    cu = nb.ctrl_vec("cam_u", (0.0, 0.0, 1.0))
    fpx = nb.ctrl("f_px", 1000.0)
    zf = nb.dot(d, cf)
    sx = nb.mul(nb.div(nb.dot(d, cr), nb.mx(zf, 1e-3)), fpx)
    sy = nb.mul(nb.div(nb.dot(d, cu), nb.mx(zf, 1e-3)), fpx)
    sp = nb.comb(sx, sy, 0.0)
    fade = nb.AND(nb.smooth(0.035, 0.20, z), nb.gt(zf, 0.05), cam_ray,
                  nb.smooth(nb.mul(rho, 1.25), nb.mul(rho, 2.1), a))
    stars = None
    for (cell, dens, r0, r1_, b0, b1, seed) in ((nb.ctrl("star_cell_s", 30.0), 0.62, 0.55, 0.95, 0.10, 0.55, 0.0),
                                                 (nb.ctrl("star_cell_b", 130.0), 0.55, 0.85, 1.55, 0.45, 1.9, 7.3)):
        v = nb.node("ShaderNodeTexVoronoi", voronoi_dimensions="2D", feature="F1")
        nb.feed(v.inputs["Vector"], nb.vadd(sp, (seed * 101.0, seed * 37.0, 0.0)))
        nb.feed(v.inputs["Scale"], nb.div(1.0, cell))
        v.inputs["Randomness"].default_value = 1.0
        dist = nb.mul(v.outputs["Distance"], cell)
        rx, ry, rz = nb.sep(v.outputs["Color"])
        present = nb.gt(rx, 1.0 - dens)
        k = nb.ctrl("star_px", 1.0)
        rad = nb.mul(nb.madd(ry, r1_ - r0, r0), k)
        bri = nb.madd(nb.mul(ry, nb.sq(ry)), b1 - b0, b0)
        prof = nb.exp(nb.mul(nb.sq(nb.div(dist, rad)), -1.0))
        tint = nb.mix(rz, lin("#c9d4ff"), lin("#ffd3ef"))
        st = nb.colk(tint, nb.AND(present, bri, prof))
        stars = st if stars is None else nb.vadd(stars, st)
    stars = nb.colk(stars, nb.mul(fade, nb.ctrl("star_gain", 1.0)))
    final = nb.cadd(col, sun, stars)
    bg = nb.node("ShaderNodeBackground")
    nb.feed(bg.inputs["Color"], final)
    bg.inputs["Strength"].default_value = 1.0
    out = nb.node("ShaderNodeOutputWorld")
    nb.links.new(bg.outputs[0], out.inputs["Surface"])
    try:
        w.cycles.sampling_method = "MANUAL"
        w.cycles.sample_map_resolution = 2048
    except Exception:
        pass
    return w


# ------------------------------------------------------------------------------------------------
# floor grid, road
# ------------------------------------------------------------------------------------------------

def haze_terms(nb, sky):
    """(view distance, horizontal sky colour seen through the point, pixel footprints)"""
    geo = nb.node("ShaderNodeNewGeometry")
    px, py, _pz = nb.sep(geo.outputs["Position"])
    camd = nb.node("ShaderNodeCameraData")
    d = camd.outputs["View Distance"]
    cx, cy, ch = nb.ctrl("cam_x", 0.0), nb.ctrl("cam_y", 0.0), nb.ctrl("cam_h", 2.0)
    hdir = nb.comb(nb.sub(px, cx), nb.sub(py, cy), 0.0)
    haze = sky_node(nb, sky, hdir)
    fp = nb.div(d, nb.ctrl("f_px", 1000.0))
    fp_x = nb.mul(fp, nb.add(1.0, nb.div(nb.absf(nb.sub(px, cx)), ch)))
    fp_y = nb.mul(fp, nb.mx(1.0, nb.div(d, ch)))
    return px, py, d, haze, fp_x, fp_y


def floor_material(sky):
    m, nb = new_mat("ka_floor")
    px, py, d, haze, fp_x, fp_y = haze_terms(nb, sky)
    S = nb.ctrl("grid_spacing", 6.0)
    S_avg = 6.0
    tx = nb.periodic_dist(px, S, nb.ctrl("grid_x0", 0.0))
    ty = nb.periodic_dist(py, S, 0.0)
    a0 = nb.ctrl("grid_halfw", 0.06)
    mpx = 1.15
    cx = nb.line_cov(tx, a0, fp_x, S_avg, mpx, 0.45)
    cy = nb.line_cov(ty, a0, fp_y, S_avg, mpx, 0.45)
    lines = nb.mx(cx, cy)
    g = 0.45
    glow = nb.mx(nb.glow_cov(tx, g, fp_x, S_avg), nb.glow_cov(ty, g, fp_y, S_avg))
    em = nb.cadd(nb.colk(lin(PINK), nb.mul(lines, nb.ctrl("grid_gain", 3.2))),
                 nb.colk(lin("#d0208a"), nb.mul(glow, nb.ctrl("grid_glow", 0.16))))
    fog = nb.NOT(nb.exp(nb.mul(nb.div(d, nb.ctrl("fog_dist", 1400.0)), -1.0)))
    bsdf = M.principled(nb, lin("#080519"), rough=0.42, spec=0.35)
    surf = add_shader(nb, bsdf, emission(nb, em))
    out_surface(nb, mix_shader(nb, fog, surf, emission(nb, haze)))
    return m


def road_material(sky):
    m, nb = new_mat("ka_road")
    px, py, d, haze, fp_x, fp_y = haze_terms(nb, sky)
    ax = nb.absf(px)
    # edge lines (solid, cyan) and centre dashes (yellow)
    te = nb.absf(nb.sub(ax, EDGE_X))
    ce = nb.line_cov(te, 0.09, fp_x, 2 * EDGE_X, 1.1, 0.4)
    tc = ax
    cc = nb.line_cov(tc, 0.075, fp_x, EDGE_X, 1.0, 0.4)
    dash_p, dash_l = 9.0, 3.0
    td = nb.periodic_dist(py, dash_p, nb.ctrl("dash_y0", 0.0))
    cd = nb.line_cov(td, dash_l * 0.5, fp_y, dash_p, 0.0, 0.0)
    centre = nb.mul(nb.mul(cc, cd), nb.ctrl("dash_on", 1.0))
    em = nb.cadd(nb.colk(lin(CYAN), nb.mul(ce, nb.ctrl("edge_gain", 3.0))),
                 nb.colk(lin(DASH_YELLOW), nb.mul(centre, nb.ctrl("dash_gain", 2.2))),
                 nb.colk(lin(CYAN), nb.mul(nb.glow_cov(te, 0.25, fp_x, 2 * EDGE_X), 0.08)))
    # asphalt: deep violet, fine grain, only slightly glossy (road_spec) at a constant roughness: a
    # glossier road with patchy roughness mirrored the warm sun / sunset as muddy brown smears
    grain = nb.noise(260.0, detail=3.0, rough=0.6, vec=nb.node("ShaderNodeNewGeometry").outputs["Position"])
    col = nb.mix(grain, lin(ASPHALT[0]), lin(ASPHALT[1]))
    normal = nb.bump(grain, strength=0.12, distance=0.004)
    bsdf = M.principled(nb, col, rough=nb.ctrl("road_rough", ROAD_ROUGH), spec=nb.ctrl("road_spec", ROAD_SPEC),
                        normal=normal)
    lines_mask = nb.mx(ce, centre)
    paint = M.principled(nb, lin("#cfd6dc"), rough=0.5, spec=0.4)
    base = mix_shader(nb, nb.mn(lines_mask, 1.0), bsdf, paint)
    surf = add_shader(nb, base, emission(nb, em))
    fog = nb.NOT(nb.exp(nb.mul(nb.div(d, nb.ctrl("fog_dist", 1400.0)), -1.0)))
    out_surface(nb, mix_shader(nb, fog, surf, emission(nb, haze)))
    return m


def quad(name, x0, x1, y0, y1, z, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], [], [(0, 1, 2, 3)])
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ------------------------------------------------------------------------------------------------
# mountain ridges
# ------------------------------------------------------------------------------------------------

RIDGES = [
    dict(name="far", dist=3200.0, seed=11, e_min=1.7, e_max=8.6, v0=4.0, v1=26.0, spacing=(5.0, 11.0),
         color="#2c1252", haze=0.30, rim=PINK, rim_gain=2.4, rim_px=2.0),
    dict(name="mid", dist=2300.0, seed=23, e_min=1.0, e_max=5.8, v0=6.0, v1=30.0, spacing=(4.0, 9.0),
         color="#1d0b40", haze=0.18, rim="#b04cff", rim_gain=1.3, rim_px=1.4),
    dict(name="near", dist=1500.0, seed=41, e_min=0.45, e_max=3.4, v0=8.0, v1=34.0, spacing=(3.5, 8.0),
         color="#120830", haze=0.08, rim=CYAN, rim_gain=2.2, rim_px=1.8),
]


def ridge_profile(rd):
    """Crest polyline [(azimuth deg, elevation deg)]: alternating peaks and saddles under an envelope
    that is low around the road / sun (azimuth 0) and rises to the sides, plus small secondary bumps."""
    rng = random.Random(rd["seed"])
    pts = []
    a = -100.0
    peak = rng.random() < 0.5
    while a <= 100.0:
        env = rd["e_min"] + (rd["e_max"] - rd["e_min"]) * smoothstep(rd["v0"], rd["v1"], abs(a))
        e = env * (rng.uniform(0.62, 1.0) if peak else rng.uniform(0.22, 0.52))
        pts.append((a, e))
        a += rng.uniform(*rd["spacing"]) * 0.5
        peak = not peak
    out = []
    for (a0, e0), (a1, e1) in zip(pts, pts[1:]):
        out.append((a0, e0))
        for k in (1, 2):
            t = k / 3.0
            am = a0 + (a1 - a0) * (t + rng.uniform(-0.06, 0.06))
            em = e0 + (e1 - e0) * t + rng.uniform(-0.09, 0.09) * abs(a1 - a0) * 0.35
            out.append((am, max(0.04, em)))
    out.append(pts[-1])
    return out


def ridge_point(dist, a_deg, e_deg, back=0.0):
    a = math.radians(a_deg)
    r = dist + back
    return Vector((r * math.sin(a), r * math.cos(a), dist * math.tan(math.radians(e_deg))))


def ridge_material(rd, sky):
    m, nb = new_mat("ka_ridge_" + rd["name"])
    geo = nb.node("ShaderNodeNewGeometry")
    n = geo.outputs["Normal"]
    L = Vector((-0.45, -0.75, 0.55)).normalized()
    shade = nb.madd(nb.mx(nb.dot(n, tuple(L)), 0.0), 0.55, 0.62)
    attr = nb.node("ShaderNodeAttribute", attribute_name="crest")
    crest = attr.outputs["Fac"]
    col = nb.colk(lin(rd["color"]), shade)
    rimglow = nb.colk(lin(rd["rim"]), nb.mul(nb.math("POWER", crest, 10.0), 0.10))
    px, py, _pz = nb.sep(geo.outputs["Position"])
    hdir = nb.comb(nb.sub(px, nb.ctrl("cam_x", 0.0)), nb.sub(py, nb.ctrl("cam_y", 0.0)), 0.0)
    haze = sky_node(nb, sky, hdir)
    hz = rd["haze"]
    # a little more haze towards the base (ground fog)
    hfac = nb.mapr(crest, 0.0, 1.0, min(0.92, hz + 0.32), hz)
    em = nb.mix(hfac, nb.cadd(col, rimglow), haze)
    out_surface(nb, emission(nb, em))
    return m


def rim_material(rd, kind):
    m, nb = new_mat("ka_rim_%s_%s" % (rd["name"], kind))
    if kind == "core":
        out_surface(nb, emission(nb, lin(rd["rim"], rd["rim_gain"] * (1.0 - 0.45 * rd["haze"]))))
        return m
    # soft glow ribbon: transparent + emission falling off from the centre line
    tc = nb.node("ShaderNodeTexCoord")
    _u, v, _w = nb.sep(tc.outputs["UV"])
    f = nb.sq(nb.NOT(nb.absf(nb.madd(v, 2.0, -1.0))))
    em = emission(nb, nb.colk(lin(rd["rim"]), nb.mul(f, 0.22 * rd["rim_gain"])))
    tr = nb.node("ShaderNodeBsdfTransparent")
    out_surface(nb, add_shader(nb, tr.outputs[0], em))
    return m


def ribbon(name, pts, normals_to_cam, width, mat, toward_cam):
    """Strip of constant width along a 3-D polyline, in the plane facing the camera (UV v across)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    left, right = [], []
    n = len(pts)
    for i in range(n):
        p = pts[i]
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        nc = normals_to_cam[i]
        b = nc.cross(t).normalized()
        if b.z < 0:
            b = -b
        c = p + nc * toward_cam
        left.append(bm.verts.new(c + b * (width * 0.5)))
        right.append(bm.verts.new(c - b * (width * 0.5)))
    for i in range(n - 1):
        f = bm.faces.new((right[i], right[i + 1], left[i + 1], left[i]))
        for lp, vv in zip(f.loops, (0.0, 0.0, 1.0, 1.0)):
            lp[uvl].uv = (0.0, vv)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.visible_shadow = False
    return ob


class Ridges:
    def __init__(self, sky):
        self.sky = sky
        self.base_profiles = [ridge_profile(rd) for rd in RIDGES]
        self.profiles = self.base_profiles
        self.objs = []
        self.mats = {}
        for rd in RIDGES:
            self.mats[rd["name"]] = (ridge_material(rd, sky), rim_material(rd, "core"), rim_material(rd, "glow"))

    def build(self, f_px, cam_pos, scale=1.0, tilt=0.0):
        """(Re)builds bodies and crest lines: elevations times scale * (1 + tilt * azimuth / 60 deg)
        (tilt > 0: lower on the left), crest lines rim_px wide."""
        for ob in self.objs:
            me = ob.data
            bpy.data.objects.remove(ob)
            bpy.data.meshes.remove(me)
        self.objs = []
        self.profiles = [[(a, e * scale * max(0.25, 1.0 + tilt * max(-1.0, min(1.0, a / 60.0))))
                          for (a, e) in prof] for prof in self.base_profiles]
        for rd, prof in zip(RIDGES, self.profiles):
            self.objs.append(self._body(rd, prof))
        self.build_rims(f_px, cam_pos)

    def _body(self, rd, prof):
        D = rd["dist"]
        rng = random.Random(rd["seed"] + 5)
        bm = bmesh.new()
        cl = bm.verts.layers.float.new("crest")
        rows = []
        depth = 0.16 * D
        for (fr, back) in ((1.0, 0.0), (0.55, -0.45), (0.0, -1.0)):
            row = []
            for (a, e) in prof:
                if fr == 1.0:
                    p = ridge_point(D, a, e)
                elif fr == 0.0:
                    p = ridge_point(D, a, 0.0, back * depth)
                    p.z = -8.0
                else:
                    jit_a = a + rng.uniform(-0.6, 0.6)
                    p = ridge_point(D, jit_a, e * (fr + rng.uniform(-0.12, 0.12)), back * depth * rng.uniform(0.7, 1.2))
                v = bm.verts.new(p)
                v[cl] = fr
                row.append(v)
            rows.append(row)
        for r0, r1 in zip(rows, rows[1:]):
            for i in range(len(r0) - 1):
                if (i + len(rows)) % 2:
                    bm.faces.new((r1[i], r1[i + 1], r0[i + 1]))
                    bm.faces.new((r1[i], r0[i + 1], r0[i]))
                else:
                    bm.faces.new((r1[i], r1[i + 1], r0[i]))
                    bm.faces.new((r1[i + 1], r0[i + 1], r0[i]))
        me = bpy.data.meshes.new("ridge_" + rd["name"])
        bm.to_mesh(me)
        bm.free()
        me.materials.append(self.mats[rd["name"]][0])
        ob = bpy.data.objects.new("ridge_" + rd["name"], me)
        bpy.context.scene.collection.objects.link(ob)
        ob.visible_shadow = False
        return ob

    def build_rims(self, f_px, cam_pos):
        for rd, prof in zip(RIDGES, self.profiles):
            D = rd["dist"]
            pts = [ridge_point(D, a, e) for (a, e) in prof]
            ncs = [(Vector((cam_pos[0], cam_pos[1], p.z)) - p).normalized() for p in pts]
            w = rd["rim_px"] * D / f_px
            _body, core, glow = self.mats[rd["name"]]
            self.objs.append(ribbon("rim_" + rd["name"], pts, ncs, w, core, 0.012 * D))
            self.objs.append(ribbon("rimglow_" + rd["name"], pts, ncs, w * 7.0, glow, 0.0115 * D))


# ------------------------------------------------------------------------------------------------
# car
# ------------------------------------------------------------------------------------------------

def build_car(rig):
    spec = [s for s in catalog.player_sets() if s["id"] == "player/sportwagen"][0]
    info = player_cars.build(rig, dict(spec["params"]))
    # the door mirrors' arms end ~11 cm above the body shoulder (invisible in the small game sprites,
    # but they float in close-ups): seat the mirror assemblies on the shoulder for the key art
    for ob in rig.root.children_recursive:
        if ob.type == "MESH" and "_mirror" in ob.name:
            xs = [v.co.x for v in ob.data.vertices]
            side = 1.0 if sum(xs) > 0 else -1.0
            ob.location.x += -0.07 * side
            ob.location.z += -0.075
    bpy.context.view_layer.update()
    return info


def car_lights_rewire():
    """Base pass + light layers at once: the CE_PASS switch (BSDF or layer emission) of every car
    material becomes BSDF + emission; the layer values (car_lights) scale the emission. Lens materials
    stay in their base look (tinted, transparent) so the glowing internals shine through them.
    Returns the emission nodes of the headlight internals (no light layer in the sprite pipeline)."""
    heads = []
    for m in bpy.data.materials:
        if not m.name.startswith("sportwagen") or not m.node_tree:
            continue
        nt = m.node_tree
        outs = [n for n in nt.nodes if n.bl_idname == "ShaderNodeOutputMaterial"]
        if not outs or not outs[0].inputs["Surface"].links:
            continue
        out = outs[0]
        src = out.inputs["Surface"].links[0].from_node
        if src.bl_idname != "ShaderNodeMixShader" or not src.inputs[2].links or not src.inputs[1].links:
            continue
        em_node = src.inputs[2].links[0].from_node
        if em_node.bl_idname != "ShaderNodeEmission":
            continue
        add = nt.nodes.new("ShaderNodeAddShader")
        nt.links.new(src.inputs[1].links[0].from_socket, add.inputs[0])
        nt.links.new(src.inputs[2].links[0].from_socket, add.inputs[1])
        nt.links.new(add.outputs[0], out.inputs["Surface"])
        if m.name.endswith("_reflector"):
            em_node.inputs["Strength"].default_value = 0.12      # reflectors only catch light
        if "_plate" in m.name and not m.name.endswith(("_text", "_bandtext", "_recess", "_band")):
            em_node.inputs["Strength"].default_value = 0.3       # dim plate lamp
        if m.name.endswith("_lampwhite") or m.name.endswith("_lampdark"):
            if em_node.inputs["Color"].links:
                nt.links.remove(em_node.inputs["Color"].links[0])
            em_node.inputs["Color"].default_value = lin("#eaf2ff")
            heads.append((em_node, 1.0 if m.name.endswith("_lampwhite") else 0.35))
    return heads


def car_lights(heads, tail=6.0, brake=0.0, head=0.0):
    g = M.pass_group()
    for name in ("base",) + M.LAYERS:
        g.nodes["v_" + name].outputs[0].default_value = 0.0
    g.nodes["v_base"].outputs[0].default_value = 1.0
    g.nodes["v_tail"].outputs[0].default_value = tail
    g.nodes["v_brake"].outputs[0].default_value = brake
    for node, k in heads:
        node.inputs["Strength"].default_value = head * k


# ------------------------------------------------------------------------------------------------
# lights
# ------------------------------------------------------------------------------------------------

LIGHTS = {}


# car-frame light rigs (x right, y forward, z up): position, aim point, size, size_y, power W, spread deg
LIGHT_RIGS = {
    "rear": dict(       # camera behind the car
        pink=((-3.4, 1.0, 1.7), (0.0, 0.2, 0.6), 4.6, 0.22, 140.0, 75.0),
        cyan=((3.3, 0.4, 1.6), (0.0, 0.0, 0.6), 4.6, 0.22, 115.0, 75.0),
        kick=((-3.0, -3.9, 1.6), (0.1, -1.6, 0.6), 1.8, 0.5, 45.0, 70.0),
        top=((0.0, 4.6, 3.0), (0.0, -0.4, 1.0), 3.2, 0.5, 0.0, 100.0)),      # off: bar on the rear window
    "front": dict(      # car coming towards the camera (car frame: +y = towards the camera)
        pink=((3.6, 1.2, 2.2), (0.0, 1.4, 0.75), 4.0, 0.25, 95.0, 45.0),
        cyan=((-3.6, 0.8, 2.1), (0.0, 1.4, 0.75), 4.0, 0.25, 80.0, 45.0),
        kick=((0.0, -4.5, 2.4), (0.0, -0.5, 1.0), 3.0, 0.4, 120.0, 90.0),
        top=((0.0, 5.0, 3.2), (0.0, 0.8, 0.8), 3.0, 0.5, 50.0, 100.0)),
}


def area_light(name, size, size_y, color, shape="RECTANGLE"):
    ld = bpy.data.lights.new(name, "AREA")
    ld.shape = shape
    ld.size = size
    ld.size_y = size_y
    ld.color = lin(color)[:3]
    ob = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(ob)
    ob.visible_camera = False
    LIGHTS[name] = ob
    return ob


def aim(ob, loc, target):
    ob.location = Vector(loc)
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


# ------------------------------------------------------------------------------------------------
# shots
# ------------------------------------------------------------------------------------------------
# cam: location, yaw (deg, + = look left), pitch (deg, - = down), lens (mm, 36 mm sensor width), vanish =
#      screen position (x, y from the top, fractions) of the road's vanishing point, reached by lens shift
# car: (x, y, yaw deg, + = nose left; > 90 = coming towards the camera -> "front" light rig, headlights)
# sun: elevation of the centre and angular radius (deg), optional gain (default SUN_GAIN) and stripe
#      controls
# optional: ridge_scale / ridge_tilt (mountain height, lower on the left), road_spec (asphalt
#      specular, default ROAD_SPEC), road_rough (default ROAD_ROUGH), dashes (centre line on/off),
#      dash_gain (centre-line emission, default 2.2),
#      grid (spacing, halfw, gain), stars (cell sizes px), post (left_dark), motion (m per shutter,
#      default 1.1), car_visible, headlights, light_gain, lights (per-light power factors)

SHOTS = {
    "portrait": dict(
        res=(1200, 1800), samples=128,
        cam=dict(loc=(1.55, -6.1, 1.85), yaw=0.0, pitch=-3.0, lens=38.0, vanish=(0.5, 0.57)),
        car=(1.875, 0.0, 8.0), sun=dict(elev=7.0, rho=13.5, az=0.0),
        dash_gain=1.7,      # the near dashes are big here: less bloom, no yellow-over-violet haze
        stars=dict(cell_s=34.0, cell_b=150.0)),
    "landscape": dict(
        res=(1840, 860), samples=128,
        cam=dict(loc=(1.05, -8.5, 1.25), yaw=3.0, pitch=-1.0, lens=34.0, vanish=(0.65, 0.53)),
        car=(1.875, 0.0, 5.0), sun=dict(elev=5.0, rho=7.0, az=0.0), ridge_scale=0.6, ridge_tilt=0.8,
        motion=0.5, post=dict(left_dark=(0.18, 0.5)),
        stars=dict(cell_s=30.0, cell_b=140.0)),
    "hero": dict(
        res=(3840, 1240), samples=96,
        cam=dict(loc=(0.3, -10.5, 0.9), yaw=3.0, pitch=0.0, lens=30.0, vanish=(0.60, 0.50)),
        car=(1.875, 0.0, 4.0), sun=dict(elev=3.0, rho=5.3, az=0.0), ridge_scale=0.62, ridge_tilt=0.45,
        motion=0.5, post=dict(left_dark=(0.32, 0.5)),
        stars=dict(cell_s=34.0, cell_b=160.0)),
    "icon_bg": dict(
        res=(1024, 1024), samples=64, car_visible=False,
        cam=dict(loc=(0.0, -12.0, 3.2), yaw=0.0, pitch=-4.0, lens=27.0, vanish=(0.5, 0.58)),
        car=(1.875, 0.0, 0.0), ridge_scale=0.8, road_spec=0.0, dashes=False,
        sun=dict(elev=6.5, rho=17.0, az=0.0,
                 stripes=dict(stripe_t0=0.32, stripe_period=0.21, stripe_min=0.24, stripe_grow=0.45)),
        grid=dict(spacing=9.0, halfw=0.12, gain=4.0), stars=dict(cell_s=60.0, cell_b=170.0)),
    "portrait_b": dict(
        res=(1200, 1800), samples=128, headlights=True, road_spec=0.1,
        cam=dict(loc=(2.4, -4.0, 0.55), yaw=0.0, pitch=1.0, lens=22.0, vanish=(0.5, 0.63)),
        car=(1.875, 0.0, 208.0), sun=dict(elev=14.0, rho=21.0, az=0.0),
        stars=dict(cell_s=34.0, cell_b=150.0)),
}


class Scene:
    def __init__(self, quick=False):
        t0 = time.time()
        self.rig = R.Rig(quick=quick)
        self.info = build_car(self.rig)
        print("car built in %.1fs" % (time.time() - t0), flush=True)
        sc = self.rig.scene
        self.scene = sc
        sc.render.film_transparent = False
        sc.render.dither_intensity = 0.0
        sc.render.filter_size = 1.2
        self.sky = sky_group()
        sc.world = build_world(self.sky)
        self.floor = quad("floor", -16000.0, 16000.0, -200.0, 16000.0, 0.0, floor_material(self.sky))
        self.road = quad("road", -ROAD_HALF, ROAD_HALF, -200.0, 16000.0, 0.004, road_material(self.sky))
        self.ridges = Ridges(self.sky)
        # lights: the rig's sun lamp becomes the low warm sun in front of the car
        self.sun = self.rig.sun
        self.sun.data.color = lin("#ff9d5c")[:3]
        self.sun.data.angle = math.radians(4.0)
        # reflections show the painted world sun (radiance ~1.2); a 4 deg lamp would be ~1000x brighter
        self.sun.visible_glossy = False
        self.sun.visible_transmission = False
        self.car_lights = dict(pink=area_light("neon_pink", 4.0, 0.2, PINK),
                               cyan=area_light("neon_cyan", 4.0, 0.2, CYAN),
                               kick=area_light("kick_pink", 2.0, 0.5, "#ff4a9a"),
                               top=area_light("top_warm", 3.0, 0.5, "#ff9a6a"))
        self.fill = area_light("fill", 2.4, 1.2, "#5a4cff")
        self.cam = self.rig.cam
        self.car_objs = [o for o in self.rig.root.children_recursive]
        self.heads = car_lights_rewire()
        # speed: camera, car and its lights ride on a keyframed mover -> Cycles motion blur streaks the
        # road and grid while the car stays sharp; the tyres / rims spin (brake disc + caliper do not)
        self.mover = bpy.data.objects.new("mover", None)
        sc.collection.objects.link(self.mover)
        self.rig.root.parent = self.mover
        self.cam.parent = self.mover
        for o in list(self.car_lights.values()) + [self.fill]:
            o.parent = self.mover
        self.spinners = [o for o in self.car_objs if o.type == "MESH" and "_wheel_" in o.data.name
                         and (o.data.name.endswith("_tyre") or o.data.name.endswith("_rim"))]
        for o in self.spinners:
            o.cycles.motion_steps = 4

    def car_xy(self, shot):
        x, y, yaw = shot["car"]
        return Vector((x, y, 0.0)), yaw

    def setup(self, name, scale, samples):
        shot = SHOTS[name]
        sc = self.scene
        rx, ry = shot["res"]
        sc.render.resolution_x = max(8, int(round(rx * scale)))
        sc.render.resolution_y = max(8, int(round(ry * scale)))
        sc.render.resolution_percentage = 100
        # --- car
        cpos, cyaw = self.car_xy(shot)
        root = self.rig.root
        root.location = cpos
        root.rotation_euler = (0.0, 0.0, math.radians(cyaw))
        vis = shot.get("car_visible", True)
        for o in self.car_objs:
            o.hide_render = not vis
        car_lights(self.heads, tail=12.0, brake=0.3, head=7.0 if shot.get("headlights") else 0.0)
        # --- camera
        c = shot["cam"]
        cam = self.cam
        cd = cam.data
        cd.type = "PERSP"
        cd.sensor_fit = "HORIZONTAL"
        cd.sensor_width = 36.0
        cd.lens = c["lens"]
        cd.shift_x, cd.shift_y = 0.0, 0.0
        cd.clip_start = 0.05
        cd.clip_end = 40000.0
        cam.location = Vector(c["loc"])
        cam.rotation_euler = (math.radians(90.0 + c["pitch"]), 0.0, math.radians(c["yaw"]))
        bpy.context.view_layer.update()
        # lens shift so that the road's vanishing point lands at c["vanish"] (fractions, y from the top)
        W, H = sc.render.resolution_x, sc.render.resolution_y
        far = cam.location + Vector((0.0, 30000.0, 0.0))
        v = world_to_camera_view(sc, cam, far)
        vx, vy = c.get("vanish", (v.x, 1.0 - v.y))
        cd.shift_x = (v.x - vx) * 1.0
        cd.shift_y = ((1.0 - vy) - v.y) * -1.0 * H / W
        bpy.context.view_layer.update()
        mw = cam.matrix_world
        f_px = cd.lens / 36.0 * sc.render.resolution_x
        set_ctrl("f_px", f_px)
        set_ctrl("cam_x", cam.location.x)
        set_ctrl("cam_y", cam.location.y)
        set_ctrl("cam_h", max(0.3, cam.location.z))
        set_ctrl("cam_r", mw.col[0].xyz.normalized())
        set_ctrl("cam_u", mw.col[1].xyz.normalized())
        set_ctrl("cam_f", (-mw.col[2].xyz).normalized())
        # --- sun
        s = shot["sun"]
        el, az = math.radians(s["elev"]), math.radians(s["az"])
        sd = Vector((-math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
        right = sd.cross(Vector((0, 0, 1))).normalized()
        up = right.cross(sd).normalized()
        set_ctrl("sun_dir", sd)
        set_ctrl("sun_up", up)
        set_ctrl("sun_rho", math.radians(s["rho"]))
        set_ctrl("sun_gain", s.get("gain", SUN_GAIN))
        ld = Vector((sd.x, sd.y, max(sd.z, math.radians(3.0)))).normalized()
        self.sun.rotation_euler = ld.to_track_quat("Z", "Y").to_euler()
        self.sun.data.energy = 3.2
        # --- stars (screen-pixel sized: scaled with the render scale)
        st = shot.get("stars", {})
        set_ctrl("star_cell_s", st.get("cell_s", 32.0) * scale)
        set_ctrl("star_cell_b", st.get("cell_b", 140.0) * scale)
        set_ctrl("star_px", max(scale, 0.35))
        # --- grid
        gr = shot.get("grid", {})
        set_ctrl("grid_spacing", gr.get("spacing", 6.0))
        set_ctrl("grid_halfw", gr.get("halfw", 0.06))
        set_ctrl("grid_gain", gr.get("gain", 3.2))
        set_ctrl("grid_x0", gr.get("x0", 0.0))
        set_ctrl("road_spec", shot.get("road_spec", ROAD_SPEC))
        set_ctrl("road_rough", shot.get("road_rough", ROAD_ROUGH))
        set_ctrl("dash_on", 1.0 if shot.get("dashes", True) else 0.0)
        set_ctrl("dash_gain", shot.get("dash_gain", 2.2))
        sun_stripes = dict(stripe_t0=0.30, stripe_period=0.18, stripe_min=0.09, stripe_grow=0.36)
        sun_stripes.update(s.get("stripes", {}))
        for k, v in sun_stripes.items():
            set_ctrl(k, v)
        # --- ridges: crest lines a constant number of pixels wide
        self.ridges.build(f_px / max(scale, 1e-3), cam.matrix_world.translation,
                          shot.get("ridge_scale", 1.0), shot.get("ridge_tilt", 0.0))
        # --- lights around the car (car frame: x right, y forward)
        cyaw_r = math.radians(cyaw)

        def cw(p):
            ca, sa = math.cos(cyaw_r), math.sin(cyaw_r)
            return Vector((cpos.x + p[0] * ca - p[1] * sa, cpos.y + p[0] * sa + p[1] * ca, p[2]))
        front = abs(((cyaw + 180.0) % 360.0) - 180.0) > 90.0      # car faces the camera
        rigdef = LIGHT_RIGS["front" if front else "rear"]
        gain = shot.get("light_gain", 1.0)
        for key, ob in self.car_lights.items():
            pos, tgt, size, size_y, power, spread = rigdef[key]
            aim(ob, cw(pos), cw(tgt))
            ob.data.size, ob.data.size_y = size, size_y
            ob.data.energy = power * gain * shot.get("lights", {}).get(key, 1.0)
            ob.data.spread = math.radians(spread)
            ob.hide_render = not vis
        camp = cam.location
        aim(self.fill, camp + Vector((0.3, -1.0, 1.6)), cw((0.0, 0.0, 0.6)))
        self.fill.data.energy = 16.0 * gain
        self.fill.data.spread = math.radians(100.0)
        self.setup_motion(shot, -1.0 if front else 1.0)
        # --- cycles
        cy = sc.cycles
        cy.samples = samples
        cy.use_adaptive_sampling = True
        cy.adaptive_threshold = 0.015 if samples > 40 else 0.04
        cy.adaptive_min_samples = min(32, samples)
        cy.use_denoising = True
        cy.denoiser = "OPENIMAGEDENOISE"
        try:
            cy.denoising_prefilter = "ACCURATE"
            cy.denoising_quality = "HIGH"
        except Exception:
            pass
        cy.max_bounces = 8
        cy.diffuse_bounces = 3
        cy.glossy_bounces = 4
        cy.transmission_bounces = 4
        cy.transparent_max_bounces = 16
        cy.volume_bounces = 0
        cy.sample_clamp_direct = 0.0
        cy.sample_clamp_indirect = 3.0
        cy.blur_glossy = 0.7
        cy.caustics_reflective = False
        cy.caustics_refractive = False
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
        return self.diagnose(name)

    def setup_motion(self, shot, direction=1.0):
        """Motion blur: the mover travels shot['motion'] metres along the road (+Y, or -Y for an
        oncoming car) during the shutter; the wheels roll accordingly."""
        sc = self.scene
        mb = shot.get("motion", 1.1)
        bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
        for ob in [self.mover] + self.spinners:
            ob.animation_data_clear()
        sc.frame_start, sc.frame_end = 1, 20
        sc.render.use_motion_blur = mb > 0
        sc.render.motion_blur_shutter = 1.0
        sc.render.motion_blur_position = "CENTER"
        if mb > 0:
            R_wheel = player_cars.DESIGNS["sportwagen"]["R"]
            for f, k in ((9, -1.0), (11, 1.0)):
                self.mover.location = (0.0, k * mb * direction, 0.0)
                self.mover.keyframe_insert("location", frame=f)
                for o in self.spinners:
                    o.rotation_euler = (-k * mb / R_wheel, 0.0, 0.0)
                    o.keyframe_insert("rotation_euler", index=0, frame=f)
        self.mover.location = (0.0, 0.0, 0.0)
        sc.frame_set(10)
        bpy.context.view_layer.update()

    def diagnose(self, name):
        sc = self.scene
        cam = self.cam
        W, H = sc.render.resolution_x, sc.render.resolution_y

        def scr(p):
            v = world_to_camera_view(sc, cam, Vector(p))
            return (v.x * W, (1.0 - v.y) * H, v.z)
        vp = scr(cam.location + Vector((0.0, 20000.0, 0.0)))
        rep = {"vanish": (round(vp[0] / W, 3), round(vp[1] / H, 3))}
        xs, ys = [], []
        for o in self.car_objs:
            if o.type != "MESH" or o.hide_render:
                continue
            for corner in o.bound_box:
                p = o.matrix_world @ Vector(corner)
                x, y, _z = scr(p)
                xs.append(x)
                ys.append(y)
        if xs:
            rep["car_x"] = (round(min(xs) / W, 3), round(max(xs) / W, 3))
            rep["car_y"] = (round(min(ys) / H, 3), round(max(ys) / H, 3))
        s = SHOTS[name]["sun"]
        el, rho = math.radians(s["elev"]), math.radians(s["rho"])
        for tag, e in (("sun_top", el + rho), ("sun_c", el), ("sun_bot", el - rho)):
            p = cam.location + Vector((0.0, math.cos(e), math.sin(e))) * 20000.0
            q = scr(p)
            rep[tag] = (round(q[0] / W, 3), round(q[1] / H, 3))
        print("[%s] %s" % (name, rep), flush=True)
        return rep

    def render(self, path):
        sc = self.scene
        im = sc.render.image_settings
        try:
            im.media_type = "IMAGE"
        except Exception:
            pass
        im.file_format = "OPEN_EXR"
        im.color_mode = "RGB"
        im.color_depth = "32"
        im.exr_codec = "ZIP"
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path


# ------------------------------------------------------------------------------------------------
# post: bloom, highlight shoulder, sRGB, dither (numpy)
# ------------------------------------------------------------------------------------------------

def load_exr(path):
    img = bpy.data.images.load(path, check_existing=False)
    n = len(img.pixels)
    w, h = img.size
    assert n == w * h * 4, (n, w, h)
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)[::-1, :, :3].copy()


def _box(a, r, axis):
    if r < 1:
        return a
    n = a.shape[axis]
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    p = np.pad(a, pad, mode="edge")
    c = np.cumsum(p, axis=axis, dtype=np.float64)
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return ((hi - lo) / (2 * r + 1)).astype(np.float32)


def _resize(a, w, h):
    from PIL import Image
    chans = [np.asarray(Image.fromarray(np.ascontiguousarray(a[:, :, i], dtype=np.float32)).resize((w, h), Image.BILINEAR))
             for i in range(a.shape[2])]
    return np.stack(chans, axis=2)


def gauss(a, sigma):
    """Gaussian blur (3 box passes), on a downsampled copy for large sigmas."""
    H, W = a.shape[:2]
    k = 1
    while sigma / k > 6.0 and min(H, W) / (k * 2) > 16:
        k *= 2
    small = a if k == 1 else _resize(a, max(1, W // k), max(1, H // k))
    s = sigma / k
    r = max(1, int(round((math.sqrt(12.0 * s * s / 3.0 + 1.0) - 1.0) / 2.0)))
    for _ in range(3):
        small = _box(small, r, 0)
        small = _box(small, r, 1)
    return small if k == 1 else _resize(small, W, H)


def post(lin_rgb, bloom=0.16, threshold=0.95, vignette=0.22, left_dark=None, out_size=None):
    """Bloom (multi-scale, soft threshold), vignette, optional darkening towards the left edge
    (left_dark=(strength, width fraction): calmer logo area), soft highlight shoulder, sRGB, dither."""
    a = lin_rgb.astype(np.float32)
    H, W = a.shape[:2]
    diag = math.hypot(W, H)
    lum = a.max(axis=2, keepdims=True)
    k = np.clip((lum - threshold) / (threshold * 1.5), 0.0, 1.0)
    bright = a * k
    acc = np.zeros_like(a)
    for frac, wgt in ((0.0022, 0.46), (0.007, 0.32), (0.022, 0.17), (0.06, 0.05)):
        acc += wgt * gauss(bright, frac * diag)
    a = a + bloom * acc
    if vignette > 0:
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2)) / math.sqrt(2.0)
        a *= (1.0 - vignette * np.clip(r, 0, 1) ** 2.2)[:, :, None]
    if left_dark:
        k, wf = left_dark
        t = np.clip(1.0 - np.arange(W, dtype=np.float32) / (wf * W), 0.0, 1.0)
        a *= (1.0 - k * t * t * (3 - 2 * t))[None, :, None]
    # soft shoulder per channel (keeps neon hues saturated, avoids hard clipping edges)
    kn = 0.82
    hi = a > kn
    a = np.where(hi, kn + (1 - kn) * (1 - np.exp(-(a - kn) / (1 - kn))), a)
    a = np.clip(a, 0.0, 1.0)
    srgb = np.where(a <= 0.0031308, a * 12.92, 1.055 * np.power(a, 1 / 2.4) - 0.055)
    rng = np.random.default_rng(7)
    srgb = srgb * 255.0 + (rng.random(srgb.shape, dtype=np.float32) - rng.random(srgb.shape, dtype=np.float32))
    out = np.clip(np.round(srgb), 0, 255).astype(np.uint8)
    from PIL import Image
    im = Image.fromarray(out)
    if out_size and im.size != tuple(out_size):
        im = im.resize(out_size, Image.LANCZOS)
    return im


# ------------------------------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shots", default=",".join(SHOTS.keys()))
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--samples", type=int, default=0)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--keep-exr", action="store_true")
    ap.add_argument("--exr-dir", default="", help="where the linear EXR renders go (default: --out)")
    ap.add_argument("--post-only", action="store_true", help="re-run the post on kept EXRs (no rendering)")
    ap.add_argument("--crop", default="", help="x0,y0,x1,y1 (fractions, y from the top): render only this "
                    "region at the given scale (detail check, writes <shot>_crop.png)")
    args = ap.parse_args([a for a in sys.argv[1:]])
    os.makedirs(args.out, exist_ok=True)
    exr_dir = args.exr_dir or args.out
    os.makedirs(exr_dir, exist_ok=True)
    preview = abs(args.scale - 1.0) > 1e-6
    T = time.time()
    names = [n.strip() for n in args.shots.split(",") if n.strip()]
    scene = None if args.post_only else Scene(quick=preview)
    for name in names:
        t0 = time.time()
        shot = SHOTS[name]
        samples = args.samples or (16 if preview else shot["samples"])
        suffix = "_pv" if preview else ""
        if args.crop:
            suffix = "_crop"
        exr = os.path.join(exr_dir, "_%s%s.exr" % (name, suffix))
        if not args.post_only:
            scene.setup(name, args.scale, samples)
            sc = scene.scene
            sc.render.use_border = bool(args.crop)
            sc.render.use_crop_to_border = bool(args.crop)
            if args.crop:
                x0, y0, x1, y1 = [float(v) for v in args.crop.split(",")]
                sc.render.border_min_x, sc.render.border_max_x = x0, x1
                sc.render.border_min_y, sc.render.border_max_y = 1.0 - y1, 1.0 - y0
            scene.render(exr)
        t1 = time.time()
        img = post(load_exr(exr), **shot.get("post", {}))
        png = os.path.join(args.out, "%s%s.png" % (name, suffix))
        img.save(png, optimize=True)
        if not (args.keep_exr or args.post_only):
            os.remove(exr)
        print("%-11s %dx%d  %d samples  render %.1fs  post %.1fs -> %s" % (
            name, img.size[0], img.size[1], samples, t1 - t0, time.time() - t1, png), flush=True)
    print("total %.1fs" % (time.time() - T), flush=True)


if __name__ == "__main__":
    main()
