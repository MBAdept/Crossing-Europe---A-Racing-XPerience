#!/usr/bin/env python3
"""Renders all sprite sheets of Crossing Europe with Blender (bpy module) and writes the manifest.

Usage (from the repository root):
  /home/user/tools/bpyenv/bin/python tools/blender/render_all.py [--only PREFIX[,PREFIX..]] [--quick]
        [--force] [--out DIR] [--list]

  --only    render only sets whose id starts with one of the prefixes (e.g. traffic/,police/de)
  --quick   few samples (fast previews; cached separately from final renders)
  --force   ignore cached cell renders of the selected sets
  --out     output directory (default assets/sprites); the manifest there is merged/updated
  --list    print the set ids and exit

Format: ARCHITECTURE.md section 12 + docs/fahrzeug-darstellung.md (vehicle display contract v2):
  * sprite sets: one PNG, cells in a grid (index = layer * len(angles) + angle, grid_cols per row,
    sheets <= 4096 px per side); ortho (traffic/police, pivot rear) or perspective (player cars, game
    camera, pivot centre, supersampled)
  * render "box" (trucks/buses): orthographic face images of textured boxes + light overlays, packed
Every render is cached in tools/blender/_cache (keyed by geometry/paint/camera/code hash), so colour
variants reuse shadow and light-layer renders and unchanged sets are not rendered again.
Cycles runs on the CPU (CE_THREADS threads, default 3).
"""
import argparse
import hashlib
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DEFAULT_OUT = os.path.join(ROOT, "assets", "sprites")
CACHE = os.path.join(HERE, "_cache")
GENERATOR = "blender-cesprites-2"
MAX_SHEET = 4096

import bpy  # noqa: E402,F401  (registers bmesh/mathutils for the builder modules)

from cesprites import catalog, compose  # noqa: E402

CODE = {
    "common": ["rig.py", "materials.py", "meshutil.py"],
    "car": ["vehicles.py", "designs.py"],
    "police": ["vehicles.py", "designs.py", "police.py", "textgeo.py"],
    "player": ["curves.py", "carbody.py", "cardetail.py", "player_cars.py", "textgeo.py"],
    "truck": ["vehicles.py", "heavy.py", "textgeo.py"],
    "bus": ["vehicles.py", "heavy.py", "textgeo.py"],
    "prop": ["props.py", "props_nature.py", "props_buildings.py", "props_road.py"],
    "icon": ["icons.py"],
    "landmark": ["props_buildings.py"],      # props_landmarks.py: per landmark via params["rev"]
}


def H(*parts):
    return hashlib.sha1(json.dumps(parts, sort_keys=True, default=str).encode("utf-8")).hexdigest()[:20]


_code_cache = {}


def code_hash(builder, spec=None):
    files = CODE["common"] + CODE.get(builder, [])
    if builder == "prop" and spec is not None:
        # props: only the module that defines the prop (+ shared facade helpers for buildings/road)
        from cesprites import props
        mod = props.PROPS[spec["params"]["name"]][0].__module__.split(".")[-1] + ".py"
        files = CODE["common"] + [mod] + (["props_buildings.py"] if mod == "props_road.py" else [])
    key = builder + ":" + ",".join(files)
    if key in _code_cache:
        return _code_cache[key]
    h = hashlib.sha1()
    for f in files:
        p = os.path.join(HERE, "cesprites", f)
        if os.path.exists(p):
            with open(p, "rb") as fh:
                h.update(fh.read())
    _code_cache[key] = h.hexdigest()[:16]
    return _code_cache[key]


# --- builders -----------------------------------------------------------------------------------

def build(rig, spec):
    b = spec["builder"]
    p = spec["params"]
    if b == "car":
        from cesprites import designs, vehicles
        d = designs.TRAFFIC_MODELS[p["design"]]
        car = vehicles.Car(rig, d, paint=p["paint"], metal=p.get("metal", 0.35), name=p["design"]).build()
        return dict(object=car.object_size())
    if b == "player":
        from cesprites import player_cars
        info = player_cars.build(rig, p)
        info.pop("car", None)
        return info
    if b == "police":
        from cesprites import police
        return police.build(rig, p)
    if b in ("truck", "bus"):
        from cesprites import heavy
        return heavy.build(rig, b, p)
    if b == "prop":
        from cesprites import props
        return props.build(rig, p)
    if b == "icon":
        from cesprites import icons
        return icons.build(rig, p)
    if b == "landmark":
        from cesprites import props_landmarks
        return props_landmarks.build(rig, p)
    raise ValueError("unknown builder " + b)


# --- framing ------------------------------------------------------------------------------------

def plan_frame(rig, spec, info):
    from cesprites import rig as R
    cam = spec["camera"]
    mode = cam.get("mode", "ortho")
    pts = rig.model_points()
    obj = info.get("object") or bbox_object(pts)
    if mode == "ortho":
        vy = cam.get("view_yaw", 0.0)
        yaws = [a[1] + vy for a in cam["angles"]]
        ext = R.extents(pts, yaws, cam["elevation"])
        side, top, bottom = cam.get("margins", (0.1, 0.1, 0.07))
        ppm = cam.get("ppm")
        if cam.get("fit_h"):
            ppm = cam["fit_h"] / (ext[3] - min(0.0, ext[2]) + top + bottom)
        if cam.get("max_w"):
            half = max(-ext[0], ext[1]) + side if cam.get("centered", True) else (ext[1] - ext[0]) / 2 + side
            ppm = min(ppm, cam["max_w"] / (2 * half))
        cell, wm, anchor = R.plan_cell(ext, ppm, side=side, top=top, bottom=bottom, centered=cam.get("centered", True))
        return dict(cell=list(cell), image_width_m=round(wm, 4), anchor=list(anchor), object=obj, ppm=ppm)
    if mode == "perspective":
        # screen region of the car (and its baked shadow) over all angles, seen by the game camera
        gc = cam["game"]
        ss = cam["supersample"]
        x0 = y0 = 1e9
        x1 = y1 = -1e9
        for (_n, yaw) in cam["angles"]:
            for P in (pts, R.shadow_points(pts)):
                sx, sy = R.game_project(P, gc, yaw)
                x0, x1 = min(x0, float(sx.min())), max(x1, float(sx.max()))
                y0, y1 = min(y0, float(sy.min())), max(y1, float(sy.max()))
        m = cam.get("margin_px", 5.0)
        x0, y0, x1, y1 = math.floor(x0 - m), math.floor(y0 - m), math.ceil(x1 + m), math.ceil(y1 + m)
        # supersample: the requested factor, lowered in 0.05 steps until all cells (angles x layers)
        # fit into one sheet of at most MAX_SHEET px per side; cells are multiples of 4 px and the
        # screen rectangle is exactly cell / supersample (lens shift uses the exact rectangle)
        n = len(cam["angles"]) * len(spec["layers"])
        while True:
            cw = int(math.ceil((x1 - x0) * ss / 4.0)) * 4
            ch = int(math.ceil((y1 - y0) * ss / 4.0)) * 4
            try:
                choose_grid(n, cw, ch)
                break
            except ValueError:
                if ss <= 1.0:
                    raise
                ss = round(ss - 0.05, 2)
        rect = [float(x0), float(y0), x0 + cw / ss, y0 + ch / ss]
        f = R.game_focal(gc)
        ax_s = gc["screen"][0] * 0.5
        ay_s = gc["screen"][1] * gc["horizon_y_frac"] + f * gc["height_m"] / gc["distance_m"]
        anchor = [round((ax_s - rect[0]) / (rect[2] - rect[0]), 5), round((ay_s - rect[1]) / (rect[3] - rect[1]), 5)]
        ppm = f * ss / gc["distance_m"]
        return dict(cell=[cw, ch], image_width_m=round(cw / ppm, 4), anchor=anchor, object=obj, ppm=ppm,
                    rect=rect, supersample=ss)
    if mode == "icon":
        cell = cam["cell"]
        ext = R.extents(pts, [cam.get("view_yaw", 0.0)], cam.get("elevation", 0.0))
        w = ext[1] - ext[0]
        h = ext[3] - ext[2]
        pad = cam.get("pad", 0.08)
        wm = max(w * cell[0] / cell[0], h * cell[0] / cell[1]) * (1 + 2 * pad)
        cx = (ext[0] + ext[1]) / 2
        cy = (ext[2] + ext[3]) / 2
        hm = wm * cell[1] / cell[0]
        anchor = (0.5 - cx / wm, 0.5 + cy / hm)
        return dict(cell=list(cell), image_width_m=round(wm, 4), anchor=[round(anchor[0], 4), round(anchor[1], 4)],
                    object=obj, ppm=cell[0] / wm)
    if mode == "showroom":
        from bpy_extras.object_utils import world_to_camera_view
        from mathutils import Vector
        cell = cam["cell"]
        frame = dict(cell=list(cell), object=obj)
        loc, target = showroom_camera(cam, obj)
        setup_camera(rig, spec, dict(frame, image_width_m=1.0, anchor=[0.5, 0.5]), 0.0)
        bpy.context.view_layer.update()
        dist = (Vector(loc) - Vector(target)).length
        wm = 2.0 * dist * math.tan(math.atan(18.0 / cam["lens"]))
        g = world_to_camera_view(bpy.context.scene, rig.cam, Vector((target[0], target[1], 0.0)))
        frame.update(image_width_m=round(wm, 3), anchor=[round(g.x, 4), round(1.0 - g.y, 4)], ppm=cell[0] / wm)
        return frame
    raise ValueError(mode)


def bbox_object(pts):
    mn = pts.min(axis=0)
    mx = pts.max(axis=0)
    return {"width_m": round(float(mx[0] - mn[0]), 2), "length_m": round(float(mx[1] - mn[1]), 2),
            "height_m": round(float(mx[2]), 2)}


def setup_camera(rig, spec, frame, yaw):
    cam = spec["camera"]
    mode = cam.get("mode", "ortho")
    if mode in ("ortho", "icon"):
        rig.set_yaw(yaw + cam.get("view_yaw", 0.0))
        rig.frame_ortho(cam.get("elevation", 0.0), frame["image_width_m"], frame["cell"], frame["anchor"])
    elif mode == "perspective":
        rig.set_yaw(yaw)
        rig.frame_game(cam["game"], frame["rect"], frame["supersample"])
    else:  # showroom: perspective 3/4 front view aimed at the car centre
        loc, target = showroom_camera(cam, frame["object"])
        rig.set_yaw(cam["yaw"])
        rig.frame_persp(loc, target, cam["lens"], frame["cell"], shift=(cam.get("shift_x", 0.0), cam.get("shift_y", 0.0)))


def showroom_camera(cam, obj):
    L = obj.get("length_m", 4.5)
    Hh = obj.get("height_m", 1.45)
    if cam.get("pivot") == "center":
        tx, ty = 0.0, 0.0                   # the car turns about its centre (player models)
    else:
        a = math.radians(-cam["yaw"])       # root rotation about Z (car turns about its rear-bumper anchor)
        tx, ty = -math.sin(a) * L / 2, math.cos(a) * L / 2
    tz = Hh * cam.get("target_h", 0.42)
    dist = cam.get("dist_per_m", 2.05) * L
    el = math.radians(cam["elevation"])
    loc = (tx, ty - dist * math.cos(el), tz + dist * math.sin(el))
    return loc, (tx, ty, tz)


# --- grid layout --------------------------------------------------------------------------------

def choose_grid(n, cw, ch, limit=MAX_SHEET):
    """Columns for n cells of cw x ch: both sheet sides <= limit, as square as possible, few holes."""
    best = None
    for cols in range(1, n + 1):
        rows = int(math.ceil(n / cols))
        W, Hh = cols * cw, rows * ch
        if W > limit or Hh > limit:
            continue
        key = (max(W, Hh), cols * rows - n, -cols)
        if best is None or key < best[0]:
            best = (key, cols)
    if best is None:
        raise ValueError("cells %dx%d x %d do not fit into %d px" % (cw, ch, n, limit))
    return best[1]


# --- main ---------------------------------------------------------------------------------------

def cell_path(key):
    return os.path.join(CACHE, "cells", key[:2], key + ".png")


def render_set(spec, args, stats):
    from cesprites import rig as R
    if spec.get("render") == "box":
        return render_box_set(spec, args, stats)
    quick = args.quick
    tag = "q" if quick else "f"
    params = spec["params"]
    paint_keys = spec.get("paint", [])
    geo = {k: v for k, v in params.items() if k not in paint_keys}
    paint = {k: params[k] for k in paint_keys if k in params}
    geo_key = H(spec["builder"], geo, spec["camera"], code_hash(spec["builder"], spec), spec.get("catcher"),
                spec.get("samples"))
    paint_key = H(paint)
    cam = spec["camera"]
    mode = cam.get("mode", "ortho")
    angles = cam.get("angles", [("c", 0.0)])
    if mode in ("showroom", "icon"):
        angles = [("c", 0.0)]
    layers = spec["layers"]
    use_shadow = spec.get("shadow", 0) > 0
    keys = {}
    for an, yaw in angles:
        for layer in layers + (["shadow"] if use_shadow else []):
            if layer == "base":
                keys[(an, layer)] = H(geo_key, an, layer, paint_key, tag)
            else:
                keys[(an, layer)] = H(geo_key, an, layer, tag)
    frame_file = os.path.join(CACHE, "frames", geo_key + ".json")
    frame = None
    if os.path.exists(frame_file) and not args.force:
        with open(frame_file) as fh:
            frame = json.load(fh)
    todo = [(an, yaw, layer) for (an, yaw) in angles for layer in layers + (["shadow"] if use_shadow else [])
            if args.force or not os.path.exists(cell_path(keys[(an, layer)]))]
    t0 = time.time()
    if todo or frame is None:
        rig = R.Rig(quick=quick)
        if spec.get("samples") and not quick:
            rig.samples_base = spec["samples"]
        if spec.get("samples_emit") and not quick:
            rig.samples_emit = spec["samples_emit"]
        info = build(rig, spec)
        if frame is None:
            frame = plan_frame(rig, spec, info)
            frame["extra"] = info.get("extra", {})
            os.makedirs(os.path.dirname(frame_file), exist_ok=True)
            with open(frame_file, "w") as fh:
                json.dump(frame, fh)
        if use_shadow:
            obj = frame["object"]
            size = spec.get("catcher") or max(obj.get("length_m", 5), obj.get("width_m", 5), 5) * 6
            centered = mode == "perspective" or cam.get("pivot") == "center"
            rig.add_catcher(size, size, center=(0.0, 0.0 if centered else obj.get("length_m", 0.0) * 0.5))
        order = ["shadow", "base"] + [l for l in layers if l != "base"]
        for layer in order:
            items = [t for t in todo if t[2] == layer]
            if not items:
                continue
            rig.set_pass(layer)
            for (an, yaw, _l) in items:
                setup_camera(rig, spec, frame, yaw)
                rig.render(cell_path(keys[(an, layer)]))
                stats["cells"] += 1
    # compose the sheet
    ppm = frame.get("ppm") or frame["cell"][0] / frame["image_width_m"]
    fade = spec.get("fade_px", 3.0)
    cells = []
    raw_c = None
    for layer in layers:
        for (an, yaw) in angles:
            arr = compose.load(cell_path(keys[(an, layer)]))
            if layer == "base" and an == "c":
                raw_c = arr          # object only (before the shadow is composited) -> extent_m
            if layer == "base":
                sh = compose.load(cell_path(keys[(an, "shadow")])) if use_shadow else None
                arr = compose.base_post(arr, fade, shadow=sh, shadow_strength=spec.get("shadow", 0.75))
                if spec.get("outline"):
                    arr = compose.outline(arr, **spec["outline"])
            else:
                glows = [(s * ppm, k) for (s, k) in spec.get("glow", {}).get(layer, [(0.03, 0.6)])]
                arr = compose.light_post(arr, glows=glows, fade_px=fade, gain=spec.get("light_gain", {}).get(layer, 1.0),
                                         white_max=0.12 if layer.startswith("beacon") else 0.5)
            cells.append(arr)
    cw, ch = frame["cell"]
    multi = len(angles) > 1
    grid_cols = choose_grid(len(cells), cw, ch) if multi else len(angles)
    img = compose.sheet_grid(cells, frame["cell"], grid_cols)
    out_png = os.path.join(args.out, spec["id"] + ".png")
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    img.save(out_png, optimize=True)
    entry = {"file": spec["id"] + ".png", "cell": frame["cell"]}
    if multi:
        entry["grid_cols"] = grid_cols
    entry["angles"] = [a[0] for a in angles]
    if multi:
        entry["yaw_deg"] = [a[1] for a in angles]
    entry.update({
        "layers": layers,
        "image_width_m": frame["image_width_m"],
        "anchor": frame["anchor"],
        "object": frame["object"],
        "tags": spec["tags"],
    })
    if mode == "ortho":
        if multi:
            entry["projection"] = "ortho"
            entry["pivot"] = cam.get("pivot", "rear")
        entry["elevation_deg"] = cam["elevation"]
        # horizontal extent of the visible object left/right of the anchor (m), measured on the base
        # cell of the straight view -> placement code can keep wide props off the road
        solid = raw_c[:, :, 3] > 0.5
        cols = solid.any(axis=0).nonzero()[0]
        if cols.size and raw_c is not None:
            ax_px = frame["anchor"][0] * frame["cell"][0]
            entry["extent_m"] = [round(float((ax_px - cols[0]) / ppm), 2), round(float((cols[-1] + 1 - ax_px) / ppm), 2)]
    elif mode == "perspective":
        gc = cam["game"]
        entry["projection"] = "perspective"
        entry["pivot"] = "center"
        entry["camera"] = {"height_m": gc["height_m"], "distance_m": gc["distance_m"], "fov_deg": gc["fov_deg"],
                           "horizon_y_frac": gc["horizon_y_frac"], "screen": list(gc["screen"])}
        entry["supersample"] = frame["supersample"]
    entry.update(frame.get("extra", {}))
    dt = time.time() - t0
    print("%-28s %-11s cell %4dx%-4d grid %2d  %5.1fs  (%d cells rendered)" % (
        spec["id"], spec["builder"], cw, ch, grid_cols, dt, len(todo)), flush=True)
    return entry


# --- box mode (trucks, buses) -------------------------------------------------------------------

FACE_ORDER = ("rear", "left", "right", "top")


def face_camera(part, face, L):
    """(location, rotation, ortho width, width_m, height_m) of the orthographic face-on camera.
    Box coordinates: z along the vehicle (+ front, origin = vehicle centre), x right, y up; Blender:
    X = x, Y = z + L/2 (rear at Y = 0), Z = y."""
    x0, x1 = part["x"]
    z0, z1 = part["z"]
    y0, y1 = part["y"]
    far = 60.0
    yc = (y0 + y1) / 2
    if face == "rear":
        return (((x0 + x1) / 2, z0 + L / 2 - far, yc), (math.pi / 2, 0.0, 0.0), x1 - x0, x1 - x0, y1 - y0)
    if face == "left":
        return ((x0 - far, (z0 + z1) / 2 + L / 2, yc), (math.pi / 2, 0.0, -math.pi / 2), z1 - z0, z1 - z0, y1 - y0)
    if face == "right":
        return ((x1 + far, (z0 + z1) / 2 + L / 2, yc), (math.pi / 2, 0.0, math.pi / 2), z1 - z0, z1 - z0, y1 - y0)
    if face == "top":
        return (((x0 + x1) / 2, (z0 + z1) / 2 + L / 2, y1 + far), (0.0, 0.0, 0.0), x1 - x0, x1 - x0, z1 - z0)
    raise ValueError(face)


def render_box_set(spec, args, stats):
    from cesprites import rig as R
    quick = args.quick
    tag = "q" if quick else "f"
    params = spec["params"]
    geo_key = H("box", spec["builder"], params, spec["camera"], code_hash(spec["builder"], spec))
    meta_file = os.path.join(CACHE, "frames", geo_key + ".json")
    meta = None
    if os.path.exists(meta_file) and not args.force:
        with open(meta_file) as fh:
            meta = json.load(fh)
    cam = spec["camera"]
    layers = spec["layers"]

    def key(part, face, layer):
        return H(geo_key, part, face, layer, tag)

    t0 = time.time()
    rig = None
    def needed(m):
        out = [(p["name"], f, "base") for p in m["parts"] for f in p["faces"]]
        for layer in layers:
            if layer != "base":
                out += [(e["part"], e["face"], layer) for e in m["lights"].get(layer, [])]
        return out

    if meta is None or args.force or any(not os.path.exists(cell_path(key(*k))) for k in needed(meta)):
        rig = R.Rig(quick=quick)
        if spec.get("samples") and not quick:
            rig.samples_base = spec["samples"]
        info = build(rig, spec)
        meta = dict(object=info["object"], parts=[], lights=info.get("lights", {}), L=info["object"]["length_m"])
        for p in info["parts"]:
            meta["parts"].append(dict(name=p["name"], x=p["x"], y=p["y"], z=p["z"], faces=p["faces"]))
        os.makedirs(os.path.dirname(meta_file), exist_ok=True)
        with open(meta_file, "w") as fh:
            json.dump(meta, fh)
        rig.box_lighting()
        part_objs = {p["name"]: p["objects"] for p in info["parts"]}
        all_objs = [o for p in info["parts"] for o in p["objects"]]
        L = meta["L"]
        for layer in ["base"] + [l for l in layers if l != "base"]:
            rig.set_pass(layer)
            if layer == "base":
                rig.box_lighting()
            for p in meta["parts"]:
                faces = p["faces"] if layer == "base" else [e["face"] for e in meta["lights"].get(layer, [])
                                                             if e["part"] == p["name"]]
                vis = set(part_objs[p["name"]])
                for o in all_objs:
                    o.hide_render = o not in vis
                for f in faces:
                    kp = cell_path(key(p["name"], f, layer))
                    if os.path.exists(kp) and not args.force:
                        continue
                    loc, rot, ow, wm, hm = face_camera(p, f, L)
                    ppm = cam["ppm_rear"] if f == "rear" else cam["ppm"]
                    rig.frame_face(loc, rot, ow, int(round(wm * ppm)), int(round(hm * ppm)))
                    rig.render(kp)
                    stats["cells"] += 1
    # compose: every face (base) + light overlays, packed with 4 px edge-extended padding
    items = []
    for p in meta["parts"]:
        for f in p["faces"]:
            items.append((p["name"], f, "base"))
    for layer in layers:
        if layer == "base":
            continue
        for e in meta["lights"].get(layer, []):
            items.append((e["part"], e["face"], layer))
    images = {}
    for (pn, f, layer) in items:
        arr = compose.load(cell_path(key(pn, f, layer)))
        if layer == "base":
            arr = compose.box_face_post(arr)
        else:
            ppm = cam["ppm_rear"] if f == "rear" else cam["ppm"]
            glows = [(s * ppm, k) for (s, k) in spec.get("glow", {}).get(layer, [(0.03, 0.6)])]
            arr = compose.light_post(arr, glows=glows, fade_px=0.0, gain=spec.get("light_gain", {}).get(layer, 1.0))
        images[(pn, f, layer)] = arr
    sheet, rects = compose.pack(images, pad=4, align=4, limit=MAX_SHEET)
    out_png = os.path.join(args.out, spec["id"] + ".png")
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    sheet.save(out_png, optimize=True)
    parts = []
    for p in meta["parts"]:
        parts.append({"name": p["name"], "z": p["z"], "x": p["x"], "y": p["y"],
                      "faces": {f: rects[(p["name"], f, "base")] for f in p["faces"]}})
    lights = {}
    for layer in layers:
        if layer == "base":
            continue
        lights[layer] = [{"part": e["part"], "face": e["face"], "rect": rects[(e["part"], e["face"], layer)]}
                         for e in meta["lights"].get(layer, [])]
    entry = {"file": spec["id"] + ".png", "render": "box", "object": meta["object"], "tags": spec["tags"],
             "parts": parts, "lights": lights}
    print("%-28s %-11s box sheet %dx%d  %5.1fs" % (spec["id"], spec["builder"], sheet.size[0], sheet.size[1],
                                                  time.time() - t0), flush=True)
    return entry


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default="")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args([a for a in sys.argv[1:]])
    sets = catalog.all_sets()
    if args.list:
        for s in sets:
            print(s["id"], s["builder"], "x".join(s["layers"]))
        print(len(sets), "sets")
        return
    if args.only:
        prefixes = [p for p in args.only.split(",") if p]
        sets = [s for s in sets if any(s["id"].startswith(p) for p in prefixes)]
    os.makedirs(args.out, exist_ok=True)
    man_path = os.path.join(args.out, "manifest.json")
    manifest = {"version": 1, "generator": GENERATOR, "sets": {}}
    if os.path.exists(man_path):
        with open(man_path, encoding="utf-8") as fh:
            old = json.load(fh)
        manifest["sets"].update(old.get("sets", {}))
    stats = {"cells": 0}
    t0 = time.time()
    failed = []
    for s in sets:
        try:
            manifest["sets"][s["id"]] = render_set(s, args, stats)
        except Exception:
            import traceback
            traceback.print_exc()
            failed.append(s["id"])
            print("FEHLER beim Rendern von", s["id"], flush=True)
        # write the manifest after every set (long runs can be inspected / resumed)
        write_manifest(man_path, manifest, args.out)
    write_manifest(man_path, manifest, args.out)
    print("done: %d sets, %d renders, %.1f min" % (len(sets), stats["cells"], (time.time() - t0) / 60.0))
    if failed:
        print("FEHLGESCHLAGEN:", ", ".join(failed))
        sys.exit(1)


def write_manifest(man_path, manifest, out_dir):
    sets_out = {}
    for sid in sorted(manifest["sets"]):
        e = manifest["sets"][sid]
        if os.path.exists(os.path.join(out_dir, e["file"])):
            sets_out[sid] = e
    data = {"version": 1, "generator": GENERATOR, "sets": sets_out}
    tmp = man_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(dumps_compact(data))
        fh.write("\n")
    os.replace(tmp, man_path)


def dumps_compact(v, ind=0):
    """JSON with one-space indentation; lists of scalars and small dicts of scalars stay on one line."""
    pad = " " * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        if all(not isinstance(x, (dict, list)) for x in v.values()) and len(v) <= 6:
            return json.dumps(v, ensure_ascii=False)
        items = [pad + " " + json.dumps(k, ensure_ascii=False) + ": " + dumps_compact(x, ind + 1) for k, x in v.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return json.dumps(v, ensure_ascii=False)
        if all(isinstance(x, list) and all(not isinstance(y, (dict, list)) for y in x) for x in v):
            return "[" + ", ".join(json.dumps(x, ensure_ascii=False) for x in v) + "]"
        items = [pad + " " + dumps_compact(x, ind + 1) for x in v]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    return json.dumps(v, ensure_ascii=False)


if __name__ == "__main__":
    main()
