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

Format: ARCHITECTURE.md section 12 (one PNG per set, columns = angles, rows = layers, equal cells).
Every cell render is cached in tools/blender/_cache (keyed by geometry/paint/camera/code hash), so
colour variants reuse shadow and light-layer renders and unchanged sets are not rendered again.
Cycles runs on the CPU with 2 threads.
"""
import argparse
import hashlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DEFAULT_OUT = os.path.join(ROOT, "assets", "sprites")
CACHE = os.path.join(HERE, "_cache")
GENERATOR = "blender-cesprites-1"

import bpy  # noqa: E402,F401  (registers bmesh/mathutils for the builder modules)

from cesprites import catalog, compose  # noqa: E402

CODE = {
    "common": ["rig.py", "materials.py", "meshutil.py"],
    "car": ["vehicles.py", "designs.py"],
    "police": ["vehicles.py", "designs.py", "police.py", "textgeo.py"],
    "truck": ["vehicles.py", "heavy.py", "textgeo.py"],
    "bus": ["vehicles.py", "heavy.py", "textgeo.py"],
    "prop": ["props.py", "props_nature.py", "props_buildings.py", "props_road.py"],
    "icon": ["icons.py"],
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
        d = designs.PLAYER_MODELS.get(p["design"]) if p.get("group") == "player" else designs.TRAFFIC_MODELS[p["design"]]
        car = vehicles.Car(rig, d, paint=p["paint"], metal=p.get("metal", 0.35), name=p["design"]).build()
        return dict(object=car.object_size())
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
        import math
        from bpy_extras.object_utils import world_to_camera_view
        from mathutils import Vector
        cell = cam["cell"]
        frame = dict(cell=list(cell), object=obj)
        loc, target = showroom_camera(cam, obj)
        setup_camera(rig, spec, dict(frame, image_width_m=1.0, anchor=[0.5, 0.5]), 0.0)
        import bpy
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
    else:  # showroom: perspective 3/4 front view aimed at the (rotated) car centre
        loc, target = showroom_camera(cam, frame["object"])
        rig.set_yaw(cam["yaw"])
        rig.frame_persp(loc, target, cam["lens"], frame["cell"], shift=(0.0, cam.get("shift_y", 0.0)))


def showroom_camera(cam, obj):
    import math
    L = obj.get("length_m", 4.5)
    H = obj.get("height_m", 1.45)
    a = math.radians(-cam["yaw"])          # root rotation about Z (car rotates about its rear-bumper anchor)
    tx, ty = -math.sin(a) * L / 2, math.cos(a) * L / 2
    tz = H * 0.42
    dist = cam.get("dist_per_m", 2.05) * L
    el = math.radians(cam["elevation"])
    loc = (tx, ty - dist * math.cos(el), tz + dist * math.sin(el))
    return loc, (tx, ty, tz)


# --- main ---------------------------------------------------------------------------------------

def cell_path(key):
    return os.path.join(CACHE, "cells", key[:2], key + ".png")


def render_set(spec, args, stats):
    from cesprites import rig as R
    quick = args.quick
    tag = "q" if quick else "f"
    params = spec["params"]
    paint_keys = spec.get("paint", [])
    geo = {k: v for k, v in params.items() if k not in paint_keys}
    paint = {k: params[k] for k in paint_keys if k in params}
    geo_key = H(spec["builder"], geo, spec["camera"], code_hash(spec["builder"], spec), spec.get("catcher"))
    paint_key = H(paint)
    angles = spec["camera"].get("angles", [("c", 0.0)])
    if spec["camera"].get("mode") in ("showroom", "icon"):
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
        info = build(rig, spec)
        if frame is None:
            frame = plan_frame(rig, spec, info)
            frame["extra"] = info.get("extra", {})
            os.makedirs(os.path.dirname(frame_file), exist_ok=True)
            with open(frame_file, "w") as fh:
                json.dump(frame, fh)
        if use_shadow:
            size = spec.get("catcher") or max(frame["object"].get("length_m", 5), frame["object"].get("width_m", 5), 5) * 6
            rig.add_catcher(size, size, center=(0.0, frame["object"].get("length_m", 0.0) * 0.5))
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
    ppm = frame["cell"][0] / frame["image_width_m"]
    fade = spec.get("fade_px", 3.0)
    grid = []
    raw_c = None
    for layer in layers:
        row = []
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
            row.append(arr)
        grid.append(row)
    img = compose.sheet(grid, frame["cell"])
    out_png = os.path.join(args.out, spec["id"] + ".png")
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    img.save(out_png, optimize=True)
    entry = {
        "file": spec["id"] + ".png",
        "cell": frame["cell"],
        "angles": [a[0] for a in angles],
        "layers": layers,
        "image_width_m": frame["image_width_m"],
        "anchor": frame["anchor"],
        "object": frame["object"],
        "tags": spec["tags"],
    }
    cam = spec["camera"]
    if cam.get("mode", "ortho") == "ortho":
        entry["elevation_deg"] = cam["elevation"]
        if len(angles) > 1:
            entry["yaw_deg"] = {a[0]: a[1] for a in angles}
        # horizontal extent of the visible object left/right of the anchor (m), measured on the base
        # cell of the straight view -> placement code can keep wide props off the road
        solid = raw_c[:, :, 3] > 0.5
        cols = solid.any(axis=0).nonzero()[0]
        if cols.size and raw_c is not None:
            ax_px = frame["anchor"][0] * frame["cell"][0]
            entry["extent_m"] = [round(float((ax_px - cols[0]) / ppm), 2), round(float((cols[-1] + 1 - ax_px) / ppm), 2)]
    entry.update(frame.get("extra", {}))
    dt = time.time() - t0
    print("%-28s %-11s cell %4dx%-4d  %5.1fs  (%d cells rendered)" % (
        spec["id"], spec["builder"], frame["cell"][0], frame["cell"][1], dt, len(todo)), flush=True)
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
    # drop entries whose sheet is missing, keep stable order
    sets_out = {}
    for sid in sorted(manifest["sets"]):
        e = manifest["sets"][sid]
        if os.path.exists(os.path.join(args.out, e["file"])):
            sets_out[sid] = e
    manifest["sets"] = sets_out
    with open(man_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
    print("done: %d sets, %d cells rendered, %.1f min" % (len(sets), stats["cells"], (time.time() - t0) / 60.0))
    if failed:
        print("FEHLGESCHLAGEN:", ", ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()
