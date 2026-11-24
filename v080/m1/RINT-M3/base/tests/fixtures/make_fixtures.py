#!/usr/bin/env python3
"""Vehicle test fixtures for the race module (format: docs/fahrzeug-darstellung.md).

Generates small sprite sheets with a tiny numpy z-buffer rasteriser, so the renderer can be developed and
checked independently of the Blender pipeline:

  sprites/car17.png      traffic car, 17 ortho angles -24..+24 deg (3 deg steps), rear pivot, grid_cols 9
  sprites/police17.png   police car, same angles, layers base/tail/brake/beacon_a/beacon_b
  sprites/player21.png   player car, 21 perspective angles -20..+20 deg (2 deg steps), centre pivot,
                         rendered with the game camera (render.* of config/game_config.json)
  sprites/truck_box.png  semi-trailer truck as textured box (render: box): parts, faces, light overlays
  sprites/manifest.json  overlay manifest: SpriteDB.merge_manifest() or --sprite-manifest=<path>;
                         "aliases" re-point some real sets to the fixtures for in-game screenshots

The models carry helpers for checking the display: the cars have a cyan footprint outline on the ground
(exactly length x width), the truck faces a metre grid with numbers (texture mapping must not swim).

Usage (Pillow + numpy):  python3 tests/fixtures/make_fixtures.py [--out tests/fixtures/sprites]
"""

import argparse
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

SS = 3  # rasteriser supersampling
LIGHT = np.array([-0.45, 0.8, -0.35]) / np.linalg.norm([-0.45, 0.8, -0.35])


# --- geometry -------------------------------------------------------------------------------------

class Solid:
    """Convex solid: faces (vertex index lists) with materials; normals are oriented outwards."""

    def __init__(self, verts, faces, mats):
        self.v = np.array(verts, dtype=np.float64)
        c = self.v.mean(axis=0)
        self.faces = []
        for f, m in zip(faces, mats):
            p = self.v[f]
            n = np.cross(p[1] - p[0], p[2] - p[0])
            if np.linalg.norm(n) < 1e-12:
                continue
            if np.dot(n, p.mean(axis=0) - c) < 0:
                f = list(reversed(f))
            self.faces.append((list(f), m))


def box(x0, x1, y0, y1, z0, z1, mat, mats=None):
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
         (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    f = [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]]
    names = ["rear", "front", "bottom", "top", "left", "right"]
    m = [(mats or {}).get(n, mat) for n in names]
    return Solid(v, f, m)


def frustum(bot, top, mats):
    """bot/top: (x0, x1, y, z0, z1) rectangles; mats: dict rear/front/left/right/top/bottom."""
    bx0, bx1, by, bz0, bz1 = bot
    tx0, tx1, ty, tz0, tz1 = top
    v = [(bx0, by, bz0), (bx1, by, bz0), (bx1, by, bz1), (bx0, by, bz1),
         (tx0, ty, tz0), (tx1, ty, tz0), (tx1, ty, tz1), (tx0, ty, tz1)]
    f = [[0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5], [4, 5, 6, 7], [0, 1, 2, 3]]
    names = ["rear", "front", "left", "right", "top", "bottom"]
    return Solid(v, f, [mats.get(n, mats.get("default")) for n in names])


def extrude(profile, z0, z1, mat, cap_mat=None):
    """Prism along z from a convex (x, y) profile."""
    n = len(profile)
    v = [(x, y, z0) for x, y in profile] + [(x, y, z1) for x, y in profile]
    faces = [list(range(n)), list(range(n, 2 * n))]
    mats = [cap_mat or mat, cap_mat or mat]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
        mats.append(mat)
    return Solid(v, faces, mats)


def wheel(xc, yc, zc, r, half_w, segs=14):
    v = []
    for side in (-1, 1):
        for i in range(segs):
            a = 2 * math.pi * i / segs
            v.append((xc + side * half_w, yc + r * math.sin(a), zc + r * math.cos(a)))
    faces = [list(range(segs)), list(range(segs, 2 * segs))]
    mats = ["hub", "hub"]
    for i in range(segs):
        j = (i + 1) % segs
        faces.append([i, j, segs + j, segs + i])
        mats.append("tyre")
    return Solid(v, faces, mats)


def car_model(L, W, H, police=False):
    """Simple sedan, rear centre at the origin, nose towards +z, x right, y up."""
    s = []
    lo = [(-W / 2 + 0.06, 0.26), (W / 2 - 0.06, 0.26), (W / 2, 0.40), (W / 2, 0.80),
          (W / 2 - 0.08, 0.93), (-W / 2 + 0.08, 0.93), (-W / 2, 0.80), (-W / 2, 0.40)]
    s.append(extrude(lo, 0.02, L - 0.02, "body"))
    roof_h = H if not police else H - 0.12
    s.append(frustum((-W / 2 + 0.12, W / 2 - 0.12, 0.93, 0.95, L - 1.15),
                     (-W / 2 + 0.30, W / 2 - 0.30, roof_h, 1.55, L - 1.95),
                     {"rear": "glass", "front": "glass", "left": "glass", "right": "glass", "top": "roof", "default": "body"}))
    s.append(box(-W / 2 + 0.02, W / 2 - 0.02, 0.24, 0.42, -0.05, 0.35, "bumper"))
    for sx in (-1, 1):
        a, b = sorted((sx * 0.40, sx * (W / 2 - 0.04)))
        s.append(box(a, b, 0.62, 0.80, -0.03, 0.03, "tail"))
    s.append(box(-0.26, 0.26, 0.42, 0.53, -0.025, 0.01, "plate"))
    s.append(box(-0.22, 0.22, 0.98, 1.03, 0.97, 1.02, "third"))
    for zc in (0.92, L - 0.95):
        for sx in (-1, 1):
            s.append(wheel(sx * (W / 2 - 0.13), 0.33, zc, 0.33, 0.11))
    if police:
        s.append(box(-0.55, -0.02, roof_h, roof_h + 0.12, 2.0, 2.3, "beacon_a"))
        s.append(box(0.02, 0.55, roof_h, roof_h + 0.12, 2.0, 2.3, "beacon_b"))
    return [x for x in s if len(x.faces) > 0]


def ground_quads(L, W, z_off):
    """Footprint outline (exactly L x W) and shadow polygon on the ground."""
    t = 0.05
    x0, x1, z0, z1 = -W / 2, W / 2, z_off, z_off + L
    outline = [
        [(x0, 0, z0), (x1, 0, z0), (x1, 0, z0 + t), (x0, 0, z0 + t)],
        [(x0, 0, z1 - t), (x1, 0, z1 - t), (x1, 0, z1), (x0, 0, z1)],
        [(x0, 0, z0), (x0 + t, 0, z0), (x0 + t, 0, z1), (x0, 0, z1)],
        [(x1 - t, 0, z0), (x1, 0, z0), (x1, 0, z1), (x1 - t, 0, z1)],
    ]
    m = 0.12
    shadow = [(x0 - m, 0, z0 - m), (x1 + m, 0, z0 - m), (x1 + m, 0, z1 + m), (x0 - m, 0, z1 + m)]
    return outline, shadow


def rot_y(p, yaw_deg, pivot):
    a = math.radians(yaw_deg)
    c, s = math.cos(a), math.sin(a)
    q = np.asarray(p, dtype=np.float64) - pivot
    x = q[..., 0] * c + q[..., 2] * s
    z = -q[..., 0] * s + q[..., 2] * c
    out = np.stack([x, q[..., 1], z], axis=-1)
    return out + pivot


# --- cameras --------------------------------------------------------------------------------------

class Ortho:
    def __init__(self, ppm, elev_deg, ax, ay):
        self.ppm, self.ax, self.ay = ppm, ax, ay
        e = math.radians(elev_deg)
        self.ce, self.se = math.cos(e), math.sin(e)
        self.view = np.array([0.0, -self.se, self.ce])

    def project(self, p):
        p = np.asarray(p)
        sx = self.ax + p[..., 0] * self.ppm
        sy = self.ay - (p[..., 1] * self.ce + p[..., 2] * self.se) * self.ppm
        near = -(p[..., 2] * self.ce - p[..., 1] * self.se)  # larger = nearer
        return np.stack([sx, sy, near], axis=-1)

    def facing(self, n, p0):
        return np.dot(n, self.view) < 0


class Persp:
    """Game camera: height_m above the ground, distance_m behind the car centre, horizontal view."""

    def __init__(self, f, cx, cy, height, distance):
        self.f, self.cx, self.cy, self.h, self.d = f, cx, cy, height, distance
        self.cam = np.array([0.0, height, -distance])

    def project(self, p):
        p = np.asarray(p)
        z = p[..., 2] + self.d
        sx = self.cx + self.f * p[..., 0] / z
        sy = self.cy - self.f * (p[..., 1] - self.h) / z
        return np.stack([sx, sy, 1.0 / z], axis=-1)

    def facing(self, n, p0):
        return np.dot(n, p0 - self.cam) < 0


# --- rasteriser -----------------------------------------------------------------------------------

def shade(mat, n, layer, palette):
    if layer == "base":
        base = palette.get(mat, (0.5, 0.5, 0.5))
        if mat in ("tail", "third", "beacon_a", "beacon_b"):
            k = 1.0
        else:
            k = 0.42 + 0.62 * max(0.0, float(np.dot(n, LIGHT)))
        if mat == "glass":
            k = 0.55 + 0.35 * max(0.0, float(np.dot(n, LIGHT)))
        return tuple(min(1.0, c * k) for c in base) + (1.0,)
    emit = {
        "tail": {"tail": (1.0, 0.12, 0.06)},
        "brake": {"tail": (1.0, 0.18, 0.1), "third": (1.0, 0.2, 0.12)},
        "beacon_a": {"beacon_a": (0.25, 0.45, 1.0)},
        "beacon_b": {"beacon_b": (0.25, 0.45, 1.0)},
    }[layer]
    return tuple(emit.get(mat, (0.0, 0.0, 0.0))) + (1.0,)


def raster(solids, cam, win, layer, palette, extra_polys=()):
    """Z-buffer rendering of convex solids into window win = (x0, y0, w, h) (screen px)."""
    x0, y0, w, h = win
    W, H = w * SS, h * SS
    zb = np.full((H, W), -np.inf)
    col = np.zeros((H, W, 4), dtype=np.float32)
    polys = []
    for s in solids:
        for f, m in s.faces:
            p = s.v[f]
            n = np.cross(p[1] - p[0], p[2] - p[0])
            n = n / np.linalg.norm(n)
            if not cam.facing(n, p.mean(axis=0)):
                continue
            polys.append((cam.project(p), shade(m, n, layer, palette)))
    for p, c in extra_polys:
        polys.append((cam.project(np.array(p, dtype=np.float64)), c))
    for sp, c in polys:
        for i in range(1, len(sp) - 1):
            _tri(sp[0], sp[i], sp[i + 1], c, x0, y0, zb, col)
    return col


def _tri(a, b, c, color, x0, y0, zb, col):
    H, W = zb.shape
    pts = np.array([a, b, c])
    xs = (pts[:, 0] - x0) * SS
    ys = (pts[:, 1] - y0) * SS
    xmin, xmax = int(max(0, math.floor(xs.min()))), int(min(W - 1, math.ceil(xs.max())))
    ymin, ymax = int(max(0, math.floor(ys.min()))), int(min(H - 1, math.ceil(ys.max())))
    if xmin > xmax or ymin > ymax:
        return
    area = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (ys[1] - ys[0])
    if abs(area) < 1e-9:
        return
    px, py = np.meshgrid(np.arange(xmin, xmax + 1) + 0.5, np.arange(ymin, ymax + 1) + 0.5)
    w0 = ((xs[2] - xs[1]) * (py - ys[1]) - (ys[2] - ys[1]) * (px - xs[1])) / area
    w1 = ((xs[0] - xs[2]) * (py - ys[2]) - (ys[0] - ys[2]) * (px - xs[2])) / area
    w2 = 1.0 - w0 - w1
    inside = (w0 >= -1e-9) & (w1 >= -1e-9) & (w2 >= -1e-9)
    near = w0 * pts[0, 2] + w1 * pts[1, 2] + w2 * pts[2, 2]
    sub_z = zb[ymin:ymax + 1, xmin:xmax + 1]
    sub_c = col[ymin:ymax + 1, xmin:xmax + 1]
    m = inside & (near > sub_z)
    sub_z[m] = near[m]
    sub_c[m] = color


def downsample(col):
    H, W, _ = col.shape
    pre = col.copy()
    pre[..., :3] *= pre[..., 3:4]
    pre = pre.reshape(H // SS, SS, W // SS, SS, 4).mean(axis=(1, 3))
    a = pre[..., 3:4]
    rgb = np.where(a > 1e-6, pre[..., :3] / np.maximum(a, 1e-6), 0.0)
    return np.concatenate([rgb, a], axis=-1)


def to_image(arr):
    return Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def shadow_image(cam, win, poly, blur_px):
    x0, y0, w, h = win
    sp = cam.project(np.array(poly, dtype=np.float64))
    img = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(img).polygon([((p[0] - x0) * SS, (p[1] - y0) * SS) for p in sp], fill=255)
    img = img.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(blur_px))
    a = np.asarray(img, dtype=np.float32)[..., None] / 255.0 * 0.5
    return np.concatenate([np.zeros_like(a).repeat(3, axis=-1), a], axis=-1)


def over(top, bottom):
    a = top[..., 3:4]
    b = bottom[..., 3:4]
    out_a = a + b * (1 - a)
    rgb = np.where(out_a > 1e-6, (top[..., :3] * a + bottom[..., :3] * b * (1 - a)) / np.maximum(out_a, 1e-6), 0.0)
    return np.concatenate([rgb, out_a], axis=-1)


def emission_layer(arr):
    """Overlay convention of the sprite pipeline: alpha = brightness (max channel), colour normalised, bloom."""
    rgb = arr[..., :3] * arr[..., 3:4]
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    bloom = np.asarray(img.filter(ImageFilter.GaussianBlur(2.5)), dtype=np.float32) / 255.0
    rgb = np.clip(rgb + bloom * 0.8, 0, 1)
    a = rgb.max(axis=-1, keepdims=True)
    col = np.where(a > 1e-4, rgb / np.maximum(a, 1e-4), 0.0)
    return np.concatenate([col, a], axis=-1)


# --- sheets ---------------------------------------------------------------------------------------

def sheet(cells, grid_cols, cw, ch):
    n = len(cells)
    rows = (n + grid_cols - 1) // grid_cols
    out = Image.new("RGBA", (grid_cols * cw, rows * ch), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        out.paste(c, ((i % grid_cols) * cw, (i // grid_cols) * ch))
    assert out.width <= 4096 and out.height <= 4096, "Sheet zu groß"
    return out


def angle_names(yaws):
    return ["c" if y == 0 else ("l%d" % -y if y < 0 else "r%d" % y) for y in yaws]


PAL_CAR = {"body": (0.12, 0.45, 0.75), "roof": (0.12, 0.45, 0.75), "glass": (0.12, 0.16, 0.2),
           "bumper": (0.16, 0.16, 0.17), "tail": (0.45, 0.05, 0.04), "third": (0.35, 0.05, 0.04),
           "plate": (0.92, 0.92, 0.88), "tyre": (0.07, 0.07, 0.07), "hub": (0.55, 0.56, 0.58)}
PAL_POLICE = dict(PAL_CAR, body=(0.9, 0.91, 0.93), roof=(0.9, 0.91, 0.93), beacon_a=(0.1, 0.2, 0.55),
                  beacon_b=(0.1, 0.2, 0.55))
PAL_PLAYER = dict(PAL_CAR, body=(0.78, 0.12, 0.1), roof=(0.7, 0.1, 0.08))


def ortho_set(name, L, W, H, ppm, elev, layers, palette, police=False):
    yaws = list(range(-24, 25, 3))
    solids0 = car_model(L, W, H, police)
    outline, shadow = ground_quads(L, W, 0.0)
    # cell: rotation about the rear centre; widest at +-24 deg
    half_w = (W / 2) * math.cos(math.radians(24)) + L * math.sin(math.radians(24)) + 0.35
    cw = int(math.ceil(2 * half_w * ppm / 4.0)) * 4
    top_m = H * math.cos(math.radians(elev)) + L * math.sin(math.radians(elev)) + 0.25
    margin = 8
    ch = int(math.ceil(top_m * ppm)) + margin
    ch = (ch + 3) // 4 * 4
    ax, ay = cw / 2.0, ch - margin
    cam = Ortho(ppm, elev, ax, ay)
    win = (0, 0, cw, ch)
    cells = {}
    pivot = np.zeros(3)
    for yaw in yaws:
        solids = [Solid(rot_y(s.v, yaw, pivot), [f for f, _ in s.faces], [m for _, m in s.faces]) for s in solids0]
        for layer in layers:
            extra = []
            if layer == "base":
                extra = [(rot_y(np.array(q), yaw, pivot), (0.1, 0.95, 0.95, 1.0)) for q in outline]
            arr = downsample(raster(solids, cam, win, layer, palette, extra))
            if layer == "base":
                arr = over(arr, shadow_image(cam, win, rot_y(np.array(shadow), yaw, pivot), 2.0))
            else:
                arr = emission_layer(arr)
            cells[(layer, yaw)] = to_image(arr)
    ordered = [cells[(layer, yaw)] for layer in layers for yaw in yaws]
    grid_cols = 9
    img = sheet(ordered, grid_cols, cw, ch)
    entry = {
        "file": name + ".png", "cell": [cw, ch], "grid_cols": grid_cols,
        "angles": angle_names(yaws), "yaw_deg": [float(y) for y in yaws], "layers": layers,
        "image_width_m": round(cw / ppm, 4), "anchor": [round(ax / cw, 4), round(ay / ch, 4)],
        "pivot": "rear", "projection": "ortho", "elevation_deg": elev,
        "object": {"width_m": W, "length_m": L, "height_m": H},
    }
    return img, entry


def perspective_set(name, L, W, H, render_cfg, supersample, layers, palette):
    yaws = list(range(-20, 21, 2))
    cam_h = float(render_cfg["camera_height_m"])
    cam_d = float(render_cfg["camera_distance_m"])
    fov = float(render_cfg["fov_deg"])
    hy = float(render_cfg["horizon_y_frac"])
    screen = (1280, 720)
    f = (screen[0] * 0.5) / math.tan(math.radians(fov) * 0.5) * supersample
    cx, cy = screen[0] * 0.5 * supersample, screen[1] * hy * supersample
    cam = Persp(f, cx, cy, cam_h, cam_d)
    solids0 = car_model(L, W, H)
    # model around the car centre (pivot = centre)
    for s in solids0:
        s.v[:, 2] -= L / 2
    outline, shadow = ground_quads(L, W, -L / 2)
    centre = np.zeros(3)
    # crop window: union over all angles (+ margin for the soft shadow)
    pts = []
    for yaw in yaws:
        for s in solids0:
            pts.append(cam.project(rot_y(s.v, yaw, centre))[:, :2])
        pts.append(cam.project(rot_y(np.array(shadow, dtype=np.float64), yaw, centre))[:, :2])
    pts = np.concatenate(pts)
    m = 6
    x0 = int(math.floor(pts[:, 0].min())) - m
    x1 = int(math.ceil(pts[:, 0].max())) + m
    y0 = int(math.floor(pts[:, 1].min())) - m
    y1 = int(math.ceil(pts[:, 1].max())) + m
    # symmetric about the screen centre column
    half = max(cx - x0, x1 - cx)
    x0, x1 = int(math.floor(cx - half)), int(math.ceil(cx + half))
    cw, ch = x1 - x0, y1 - y0
    win = (x0, y0, cw, ch)
    cells = {}
    for yaw in yaws:
        solids = [Solid(rot_y(s.v, yaw, centre), [f for f, _ in s.faces], [mm for _, mm in s.faces]) for s in solids0]
        for layer in layers:
            extra = []
            if layer == "base":
                extra = [(rot_y(np.array(q, dtype=np.float64), yaw, centre), (0.1, 0.95, 0.95, 1.0)) for q in outline]
            arr = downsample(raster(solids, cam, win, layer, palette, extra))
            if layer == "base":
                arr = over(arr, shadow_image(cam, win, rot_y(np.array(shadow, dtype=np.float64), yaw, centre), 3.0))
            else:
                arr = emission_layer(arr)
            cells[(layer, yaw)] = to_image(arr)
    ordered = [cells[(layer, yaw)] for layer in layers for yaw in yaws]
    grid_cols = 7
    img = sheet(ordered, grid_cols, cw, ch)
    ground = cam.project(np.array([0.0, 0.0, 0.0]))
    entry = {
        "file": name + ".png", "cell": [cw, ch], "grid_cols": grid_cols,
        "angles": angle_names(yaws), "yaw_deg": [float(y) for y in yaws], "layers": layers,
        "anchor": [round((ground[0] - x0) / cw, 5), round((ground[1] - y0) / ch, 5)],
        "pivot": "center", "projection": "perspective", "supersample": supersample,
        "camera": {"height_m": cam_h, "distance_m": cam_d, "fov_deg": fov, "horizon_y_frac": hy, "screen": list(screen)},
        "object": {"width_m": W, "length_m": L, "height_m": H},
    }
    return img, entry


# --- box truck ------------------------------------------------------------------------------------

PPM_BOX = 48


def _font(px):
    try:
        return ImageFont.load_default(size=px)
    except TypeError:
        return ImageFont.load_default()


def _px(m):
    return int(round(m * PPM_BOX))


def wheel_disc(d, cx, cy, r):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(22, 22, 24, 255))
    d.ellipse([cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55], fill=(150, 152, 156, 255))
    d.ellipse([cx - r * 0.15, cy - r * 0.15, cx + r * 0.15, cy + r * 0.15], fill=(60, 60, 64, 255))


def trailer_side(length, height, rear_left=True):
    """Side face as seen from outside. Right side: rear on the left (u: z0 -> z1); left side: front on the
    left (u: z1 -> z0). The metre grid counts from the rear, the arrow points to the rear."""
    w, h = _px(length), _px(height)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def u(m):  # image column of a point m metres in front of the rear end
        return _px(m) if rear_left else w - _px(m)

    body_y = h - _px(1.25)
    d.rectangle([0, 0, w - 1, body_y], fill=(236, 238, 240, 255), outline=(120, 124, 130, 255), width=2)
    d.rectangle([0, _px(0.55), w - 1, _px(1.05)], fill=(30, 90, 170, 255))
    for m in range(0, int(length) + 1):
        x = u(m)
        d.line([x, _px(0.15), x, body_y - 2], fill=(150, 154, 160, 255), width=1)
        d.text((x + 3 if rear_left else x - 17, _px(1.15)), str(m), fill=(40, 40, 40, 255), font=_font(14))
    label = "<- HECK   FIXTURE BOX" if rear_left else "FIXTURE BOX   HECK ->"
    d.text((u(4.0) if rear_left else u(4.0) - _px(5.5), _px(0.62)), label, fill=(255, 255, 255, 255), font=_font(22))
    d.rectangle([0, h - _px(1.25), w - 1, h - _px(1.05)], fill=(45, 47, 50, 255))
    for zc in (1.3, 2.6, 3.9):
        wheel_disc(d, u(zc), h - _px(0.5), _px(0.5))
    a, b = sorted((u(4.6), u(9.8)))
    d.rectangle([a, h - _px(0.75), b, h - _px(0.5)], fill=(150, 152, 156, 255))
    a, b = sorted((u(10.4), u(10.5)))
    d.rectangle([a, h - _px(1.05), b, h - _px(0.12)], fill=(60, 60, 64, 255))
    for m in range(1, int(length), 3):
        a, b = sorted((u(m), u(m) + (8 if rear_left else -8)))
        d.rectangle([a, body_y - 8, b, body_y - 2], fill=(255, 150, 20, 255))
    return img


def trailer_rear(width, height):
    w, h = _px(width), _px(height)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body_y = h - _px(1.25)
    d.rectangle([0, 0, w - 1, body_y], fill=(222, 224, 228, 255), outline=(90, 94, 100, 255), width=3)
    d.line([w // 2, 4, w // 2, body_y - 4], fill=(90, 94, 100, 255), width=3)
    for x in (w // 4, 3 * w // 4):
        d.line([x, 6, x, body_y - 6], fill=(140, 144, 150, 255), width=2)
    d.text((w // 2 - 22, _px(0.8)), "REAR", fill=(30, 90, 170, 255), font=_font(18))
    d.rectangle([0, h - _px(1.25), w - 1, h - _px(1.05)], fill=(45, 47, 50, 255))
    for sx in (0, 1):
        x0 = _px(0.08) if sx == 0 else w - _px(0.08) - _px(0.5)
        d.rectangle([x0, h - _px(1.0), x0 + _px(0.5), h - 1], fill=(22, 22, 24, 255))
    d.rectangle([_px(0.05), h - _px(0.62), w - _px(0.05), h - _px(0.45)], fill=(200, 60, 40, 255))
    for sx in (0, 1):
        x0 = _px(0.1) if sx == 0 else w - _px(0.1) - _px(0.42)
        d.rectangle([x0, h - _px(0.98), x0 + _px(0.42), h - _px(0.72)], fill=(90, 20, 18, 255))
    d.rectangle([w // 2 - _px(0.26), h - _px(0.98), w // 2 + _px(0.26), h - _px(0.86)], fill=(240, 240, 232, 255))
    return img


def trailer_top(width, length):
    w, h = _px(width), _px(length)
    img = Image.new("RGBA", (w, h), (196, 199, 204, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=(110, 114, 120, 255), width=3)
    for m in range(1, int(length) + 1):
        d.line([0, _px(m), w, _px(m)], fill=(170, 174, 180, 255), width=1)
    return img


def cab_side(length, height, rear_left=True):
    w, h = _px(length), _px(height)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - _px(1.0)], fill=(200, 40, 35, 255), outline=(90, 20, 18, 255), width=2)
    d.rectangle([_px(0.9), _px(0.55), w - _px(0.25), _px(1.45)], fill=(40, 52, 64, 255))
    d.rectangle([_px(0.85), _px(1.6), w - _px(0.3), h - _px(1.05)], outline=(120, 25, 20, 255), width=2)
    d.rectangle([_px(0.1), h - _px(1.0), _px(0.7), h - _px(0.85)], fill=(45, 47, 50, 255))
    wheel_disc(d, w - _px(1.25), h - _px(0.5), _px(0.5))
    img = img if rear_left else img.transpose(Image.FLIP_LEFT_RIGHT)
    return img


def plain(w_m, h_m, rgb, outline=(60, 60, 64)):
    img = Image.new("RGBA", (_px(w_m), _px(h_m)), rgb + (255,))
    ImageDraw.Draw(img).rectangle([0, 0, img.width - 1, img.height - 1], outline=outline + (255,), width=2)
    return img


def lamps(width, height, brake):
    w, h = _px(width), _px(height)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = (255, 40, 25, 255) if brake else (230, 30, 20, 220)
    for sx in (0, 1):
        x0 = _px(0.1) if sx == 0 else w - _px(0.1) - _px(0.42)
        d.rectangle([x0, h - _px(0.98), x0 + _px(0.42), h - _px(0.72)], fill=c)
    if brake:
        d.rectangle([w // 2 - _px(0.3), _px(0.1), w // 2 + _px(0.3), _px(0.2)], fill=c)
    return img.filter(ImageFilter.GaussianBlur(1.2))


def pack(faces, pad=4, max_w=2048):
    """Shelf packing with replicated borders; returns (atlas, {key: [x, y, w, h]})."""
    items = sorted(faces.items(), key=lambda kv: -kv[1].height)
    x = y = shelf = 0
    pos = {}
    for k, im in items:
        if x + im.width + 2 * pad > max_w:
            x, y, shelf = 0, y + shelf, 0
        pos[k] = (x + pad, y + pad)
        x += im.width + 2 * pad
        shelf = max(shelf, im.height + 2 * pad)
    W = max_w
    H = y + shelf
    H = 1 << (H - 1).bit_length()
    atlas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rects = {}
    for k, im in items:
        px, py = pos[k]
        big = im.resize((im.width + 2 * pad, im.height + 2 * pad), Image.NEAREST)
        big.paste(im, (pad, pad))
        # replicate the borders into the padding (no bleeding with mipmaps)
        arr = np.asarray(big).copy()
        a = np.asarray(im)
        arr[:pad, pad:-pad] = a[0:1]
        arr[-pad:, pad:-pad] = a[-1:]
        arr[pad:-pad, :pad] = a[:, 0:1]
        arr[pad:-pad, -pad:] = a[:, -1:]
        arr[:pad, :pad] = a[0, 0]
        arr[:pad, -pad:] = a[0, -1]
        arr[-pad:, :pad] = a[-1, 0]
        arr[-pad:, -pad:] = a[-1, -1]
        atlas.paste(Image.fromarray(arr, "RGBA"), (px - pad, py - pad))
        rects[k] = [px, py, im.width, im.height]
    return atlas, rects


def truck_box():
    L, W, H = 16.5, 2.55, 4.0
    tr = {"z": [-8.25, 5.35], "x": [-1.275, 1.275], "y": [0.0, 4.0]}
    cab = {"z": [5.75, 8.25], "x": [-1.25, 1.25], "y": [0.0, 3.8]}
    ch = {"z": [5.35, 5.75], "x": [-0.5, 0.5], "y": [0.45, 1.15]}
    tl = tr["z"][1] - tr["z"][0]
    faces = {
        ("trailer", "rear"): trailer_rear(2.55, 4.0),
        ("trailer", "right"): trailer_side(tl, 4.0, True),
        ("trailer", "left"): trailer_side(tl, 4.0, False),
        ("trailer", "top"): trailer_top(2.55, tl),
        ("cab", "rear"): plain(2.5, 3.8, (70, 72, 76)),
        ("cab", "right"): cab_side(2.5, 3.8, True),
        ("cab", "left"): cab_side(2.5, 3.8, False),
        ("cab", "top"): plain(2.5, 2.5, (186, 36, 32)),
        ("chassis", "left"): plain(0.4, 0.7, (40, 42, 45)),
        ("chassis", "right"): plain(0.4, 0.7, (40, 42, 45)),
        ("chassis", "top"): plain(1.0, 0.4, (40, 42, 45)),
        ("lights", "tail"): lamps(2.55, 4.0, False),
        ("lights", "brake"): lamps(2.55, 4.0, True),
    }
    atlas, rects = pack(faces)
    parts = []
    for name, p in (("trailer", tr), ("cab", cab), ("chassis", ch)):
        f = {k[1]: rects[k] for k in rects if k[0] == name}
        parts.append({"name": name, "z": p["z"], "x": p["x"], "y": p["y"], "faces": f})
    entry = {
        "file": "truck_box.png", "render": "box",
        "object": {"width_m": W, "length_m": L, "height_m": H},
        "parts": parts,
        "lights": {"tail": [{"part": "trailer", "face": "rear", "rect": rects[("lights", "tail")]}],
                   "brake": [{"part": "trailer", "face": "rear", "rect": rects[("lights", "brake")]}]},
    }
    return atlas, entry


def save(img, path, quantize):
    """Saves a sheet; fixtures are stored as 256-colour palette PNGs (with alpha) to keep the repository small."""
    if quantize:
        img = img.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    img.save(path, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "sprites"))
    ap.add_argument("--full-color", action="store_true", help="RGBA instead of palette PNGs")
    args = ap.parse_args()
    q = not args.full_color
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(ROOT, "config", "game_config.json"), encoding="utf-8") as fh:
        render_cfg = json.load(fh)["render"]
    sets = {}
    img, e = ortho_set("car17", 4.7, 1.82, 1.48, 52, 9.0, ["base", "tail", "brake"], PAL_CAR)
    save(img, os.path.join(args.out, "car17.png"), q)
    e["tags"] = ["fixture", "car"]
    sets["fixture/car17"] = e
    img, e = ortho_set("police17", 4.8, 1.84, 1.65, 52, 9.0, ["base", "tail", "brake", "beacon_a", "beacon_b"], PAL_POLICE, police=True)
    save(img, os.path.join(args.out, "police17.png"), q)
    e["tags"] = ["fixture", "police"]
    sets["fixture/police17"] = e
    img, e = perspective_set("player21", 4.85, 1.86, 1.48, render_cfg, 1.25, ["base", "tail", "brake"], PAL_PLAYER)
    save(img, os.path.join(args.out, "player21.png"), q)
    e["tags"] = ["fixture", "player"]
    sets["fixture/player21"] = e
    img, e = truck_box()
    save(img, os.path.join(args.out, "truck_box.png"), q)
    e["tags"] = ["fixture", "heavy"]
    sets["fixture/truck_box"] = e
    manifest = {
        "version": 2,
        "generator": "tests/fixtures/make_fixtures.py",
        "_doc": "Testdaten des Renn-Moduls (docs/fahrzeug-darstellung.md). Im Spiel: --sprite-manifest=res://tests/fixtures/sprites/manifest.json; aliases zeigen echte Sets auf die Testdaten.",
        "sets": sets,
        "aliases": {
            "traffic/sedan_*": "fixture/car17",
            "traffic/hatch_*": "fixture/car17",
            "traffic/truck_*": "fixture/truck_box",
            "police/*": "fixture/police17",
            "player/*": "fixture/player21",
        },
    }
    with open(os.path.join(args.out, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
    for k, v in sets.items():
        print(k, v.get("cell", ""), v.get("file"))


if __name__ == "__main__":
    main()
