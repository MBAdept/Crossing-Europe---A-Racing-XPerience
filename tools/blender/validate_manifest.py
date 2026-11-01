#!/usr/bin/env python3
"""Validates assets/sprites/manifest.json and the sprite sheets (ARCHITECTURE.md section 12 and the
vehicle display contract docs/fahrzeug-darstellung.md).

Usage: python3 tools/blender/validate_manifest.py [--src assets/sprites] [--max-mb 60] [-q]
Exit code 1 if an error was found. Needs Pillow + numpy (no Blender).

Checks
  all sets      required ids (superset of the placeholders), keys and types, file exists, RGBA
  sprite sets   grid layout (grid_cols, index = layer * len(angles) + angle, PNG size), sheets <= 4096 px
                for vehicles, angle/layer names, yaw_deg (one per angle, increasing, "c" = 0), anchors
                inside the cell, transparent cell borders, non-empty light layers, beacon_a != beacon_b
  traffic/police  ortho, pivot "rear", 17 angles -24..24 step 3, anchor = rear bumper on the ground
                (lowest pixels, horizontal centre of the straight view), measured width vs object.width_m
  player        perspective, pivot "center", 21 angles -20..20 step 2, camera = config render.*,
                supersample, car centred on anchor.x, width measured at the rear vs object.width_m
  props, landmarks  standing on the anchor, measured height vs object.height_m; landmarks: one angle "c",
                layers base + lights, tags prop + landmark (no mirror_left), real width/length/height
  box sets      parts with z/x/y ranges, faces inside the sheet and not overlapping, >= 48 px/m,
                face aspect = face metres, non-empty faces, light overlays reference existing faces and
                have the same size, overlays not empty
  total         PNG size budget
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

LAYER_NAMES = {"base", "tail", "brake", "beacon_a", "beacon_b", "lights"}
FACES = ("rear", "left", "right", "top")
PLAYERS = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]
TRAFFIC_MODELS = ["hatch", "sedan", "wagon", "suv", "van", "sports", "truck", "bus"]
POLICE = ["de", "nl", "be", "fr", "es", "ch", "it", "si", "hr", "rs", "bg", "hu", "at", "cz", "pl", "lt", "lv"]
PROPS = ["tree_oak", "tree_beech", "tree_birch", "tree_pine", "tree_spruce", "tree_poplar", "tree_cypress", "tree_olive",
         "tree_palm", "bush_round", "bush_low", "heather", "rock_a", "rock_b", "cliff", "haybale", "farmhouse", "barn",
         "church", "windmill", "wind_turbine", "power_pylon", "factory", "house_med", "building_block_a",
         "building_block_b", "building_tall", "building_oldtown", "building_shop", "streetlight", "delineator",
         "fuel_station", "fuel_pump", "radar_camera", "customs_booth", "ferry_ship"]
UI = ["weather_normal", "weather_rain", "weather_snow", "daytime_day", "daytime_night", "daytime_dawn", "daytime_dusk"]
# landmarks/<name> (docs/staedte.md section 3): one angle "c", base + lights, tags prop + landmark
LANDMARKS = ["eiffel_tower", "elbphilharmonie", "michel", "riesenrad", "stephansdom", "fernsehturm_berlin",
             "frauenkirche_dresden", "frauenkirche_muenchen", "sagrada_familia", "duomo_milano", "campanile_venezia",
             "parlament_budapest", "veitsdom_prag", "kulturpalast_warschau", "nevsky_kathedrale"]
# set ids of tools/placeholders/make_placeholders.py (the manifest must stay a superset)
PLACEHOLDER_IDS = (["player/" + p for p in PLAYERS] + ["showroom/" + p for p in PLAYERS] +
                   ["traffic/sedan_red", "traffic/sedan_blue", "traffic/sedan_silver", "traffic/hatch_green",
                    "traffic/van_white", "traffic/truck_white", "police/de", "police/nl"] +
                   ["props/" + p for p in ["tree_oak", "tree_beech", "tree_birch", "tree_spruce", "tree_poplar", "rock_a",
                                           "wind_turbine", "farmhouse", "windmill", "building_block_a", "building_tall",
                                           "streetlight", "delineator", "fuel_station", "fuel_pump", "radar_camera",
                                           "customs_booth"]])
MAX_SHEET = 4096
MIN_BOX_PPM = 48.0


def angle_list(step, maxdeg):
    n = int(round(maxdeg / step))
    return [-(step * k) for k in range(n, 0, -1)] + [0] + [step * k for k in range(1, n + 1)]


YAW_TRAFFIC = angle_list(3, 24)
YAW_PLAYER = angle_list(2, 20)


class Report:
    def __init__(self, quiet=False):
        self.errors = []
        self.warnings = []
        self.quiet = quiet

    def err(self, sid, msg):
        self.errors.append("%s: %s" % (sid, msg))

    def warn(self, sid, msg):
        self.warnings.append("%s: %s" % (sid, msg))


def game_camera():
    try:
        with open(os.path.join(ROOT, "config", "game_config.json"), encoding="utf-8") as fh:
            r = json.load(fh).get("render", {})
    except (OSError, ValueError):
        r = {}
    return {"height_m": float(r.get("camera_height_m", 3.4)), "distance_m": float(r.get("camera_distance_m", 9.0)),
            "fov_deg": float(r.get("fov_deg", 84.0)), "horizon_y_frac": float(r.get("horizon_y_frac", 0.45))}


def grid_cols(s):
    return int(s.get("grid_cols", len(s["angles"])))


def cell_rect(s, angle, layer):
    cw, ch = s["cell"]
    i = s["layers"].index(layer) * len(s["angles"]) + s["angles"].index(angle)
    g = grid_cols(s)
    return ((i % g) * cw, (i // g) * ch, (i % g + 1) * cw, (i // g + 1) * ch)


def cell_arr(img, s, angle, layer):
    return np.asarray(img.crop(cell_rect(s, angle, layer))).astype(np.float32) / 255.0


def check_sprite_set(sid, s, src, rep):
    for k in ("file", "cell", "angles", "layers", "image_width_m", "anchor", "object", "tags"):
        if k not in s:
            rep.err(sid, "Schluessel fehlt: " + k)
            return 0
    cw, ch = s["cell"]
    if not (isinstance(cw, int) and isinstance(ch, int) and cw > 0 and ch > 0):
        rep.err(sid, "cell ungueltig %s" % s["cell"])
        return 0
    angles, layers = s["angles"], s["layers"]
    if not angles or len(set(angles)) != len(angles):
        rep.err(sid, "angles leer/doppelt")
    if "c" not in angles:
        rep.err(sid, "Winkel 'c' fehlt")
    if not layers or len(set(layers)) != len(layers) or layers[0] != "base":
        rep.err(sid, "layers muessen mit 'base' beginnen und eindeutig sein: %s" % layers)
    for l in layers:
        if l not in LAYER_NAMES:
            rep.err(sid, "unbekannte Ebene " + l)
    if not (s["image_width_m"] > 0):
        rep.err(sid, "image_width_m <= 0")
    ax, ay = s["anchor"]
    if not (0.0 <= ax <= 1.0 and 0.0 <= ay <= 1.0):
        rep.err(sid, "anchor ausserhalb der Zelle %s" % s["anchor"])
    if not isinstance(s["tags"], list) or not all(isinstance(t, str) for t in s["tags"]):
        rep.err(sid, "tags muessen Strings sein")
    for k, v in s["object"].items():
        if not isinstance(v, (int, float)) or v <= 0:
            rep.err(sid, "object.%s ungueltig: %s" % (k, v))
    g = grid_cols(s)
    if not isinstance(g, int) or g < 1:
        rep.err(sid, "grid_cols ungueltig")
        return 0
    yaw = s.get("yaw_deg")
    if yaw is not None:
        if not isinstance(yaw, list) or len(yaw) != len(angles):
            rep.err(sid, "yaw_deg muss eine Liste mit einem Wert je Winkel sein")
            yaw = None
        elif any(b <= a for a, b in zip(yaw[:-1], yaw[1:])):
            rep.err(sid, "yaw_deg nicht streng steigend")
        elif abs(yaw[angles.index("c")]) > 1e-6 if "c" in angles else False:
            rep.err(sid, "Winkel 'c' muss 0 Grad sein")
    elif len(angles) > 1:
        rep.err(sid, "yaw_deg fehlt (mehrere Winkel)")
    cat = sid.split("/")[0]
    if cat in ("player", "traffic", "police"):
        for l in ("tail", "brake"):
            if l not in layers:
                rep.err(sid, "Ebene fehlt: " + l)
        for k in ("width_m", "length_m", "height_m"):
            if k not in s["object"]:
                rep.err(sid, "object." + k + " fehlt")
    if cat in ("traffic", "police"):
        if s.get("projection", "ortho") != "ortho":
            rep.err(sid, "projection muss ortho sein")
        if s.get("pivot") != "rear":
            rep.err(sid, "pivot muss 'rear' sein")
        if yaw is not None and [round(v, 3) for v in yaw] != YAW_TRAFFIC:
            rep.err(sid, "yaw_deg muss -24..24 in 3-Grad-Schritten sein")
    if cat == "player":
        if s.get("projection") != "perspective":
            rep.err(sid, "projection muss perspective sein")
        if s.get("pivot") != "center":
            rep.err(sid, "pivot muss 'center' sein")
        if yaw is not None and [round(v, 3) for v in yaw] != YAW_PLAYER:
            rep.err(sid, "yaw_deg muss -20..20 in 2-Grad-Schritten sein")
        cam = s.get("camera")
        if not isinstance(cam, dict):
            rep.err(sid, "camera fehlt")
        else:
            for k in ("height_m", "distance_m", "fov_deg", "horizon_y_frac", "screen"):
                if k not in cam:
                    rep.err(sid, "camera." + k + " fehlt")
            gc = game_camera()
            for k, v in gc.items():
                if k in cam and abs(float(cam[k]) - v) > 1e-6:
                    rep.err(sid, "camera.%s = %s, Spielkamera (config render.*) = %s -> neu rendern" % (k, cam[k], v))
            if cam.get("screen") != [1280, 720]:
                rep.err(sid, "camera.screen muss [1280, 720] sein")
        if not (isinstance(s.get("supersample"), (int, float)) and s["supersample"] >= 1.0):
            rep.err(sid, "supersample fehlt/ungueltig")
    if cat == "police":
        for l in ("beacon_a", "beacon_b"):
            if l not in layers:
                rep.err(sid, "Ebene fehlt: " + l)
        if "police" not in s["tags"] or sid.split("/")[1] not in s["tags"]:
            rep.err(sid, "tags muessen 'police' und das Laenderkuerzel enthalten")
    if cat == "traffic":
        heavy = sid.split("/")[1].split("_")[0] in ("truck", "bus")
        want = ["traffic", "heavy" if heavy else "car"]
        if any(t not in s["tags"] for t in want):
            rep.err(sid, "tags muessen %s enthalten" % want)
    if cat == "player" and "player" not in s["tags"]:
        rep.err(sid, "tag 'player' fehlt")
    if cat == "landmarks":
        if angles != ["c"]:
            rep.err(sid, "Wahrzeichen haben genau einen Winkel 'c'")
        if "lights" not in layers:
            rep.err(sid, "Ebene fehlt: lights (Anstrahlung nachts)")
        if any(t not in s["tags"] for t in ("prop", "landmark")) or "mirror_left" in s["tags"]:
            rep.err(sid, "tags muessen prop und landmark enthalten (kein mirror_left)")
        for k in ("width_m", "length_m", "height_m"):
            if k not in s["object"]:
                rep.err(sid, "object." + k + " fehlt")
    path = os.path.join(src, s["file"])
    if not os.path.exists(path):
        rep.err(sid, "Datei fehlt: " + s["file"])
        return 0
    size = os.path.getsize(path)
    img = Image.open(path)
    if img.mode != "RGBA":
        rep.err(sid, "PNG ist nicht RGBA (%s)" % img.mode)
        img = img.convert("RGBA")
    n = len(angles) * len(layers)
    rows = int(math.ceil(n / g))
    exp = (cw * g, ch * rows)
    if img.size != exp:
        rep.err(sid, "Bildgroesse %s, erwartet %s (grid_cols %d)" % (img.size, exp, g))
        return size
    if max(img.size) > MAX_SHEET:
        if cat in ("player", "traffic", "police"):
            rep.err(sid, "Sheet groesser als %d px" % MAX_SHEET)
        elif max(img.size) > 16384:
            rep.err(sid, "Bild groesser als 16384 px")
        else:
            rep.warn(sid, "Bild breiter/hoeher als %d px" % MAX_SHEET)
    for a in angles:
        for l in layers:
            c = cell_arr(img, s, a, l)
            border = max(c[0, :, 3].max(), c[-1, :, 3].max(), c[:, 0, 3].max(), c[:, -1, 3].max())
            if border > 0.06:
                rep.err(sid, "Zelle %s/%s beruehrt den Rand (alpha %.2f)" % (a, l, border))
    for l in layers[1:]:
        mx = max(cell_arr(img, s, a, l)[:, :, 3].max() for a in angles)
        if mx < 0.3:
            rep.err(sid, "Ebene %s ist (fast) leer" % l)
    if "beacon_a" in layers and "beacon_b" in layers:
        d = np.abs(cell_arr(img, s, "c", "beacon_a") - cell_arr(img, s, "c", "beacon_b")).max()
        if d < 0.2:
            rep.err(sid, "beacon_a und beacon_b sind gleich")
    a0 = "c" if "c" in angles else angles[0]
    base = cell_arr(img, s, a0, "base")
    solid = base[:, :, 3] > 0.85
    if not solid.any():
        rep.err(sid, "Basisebene leer")
        return size
    ys, xs = np.nonzero(solid)
    ppm = cw / s["image_width_m"]
    arow = ay * ch
    lowest = ys.max()
    if cat in ("traffic", "police"):
        if lowest > arow + 3:
            rep.err(sid, "Fahrzeug reicht %.0f px unter den Bodenanker" % (lowest - arow))
        if lowest < arow - 0.6 * ppm:
            rep.warn(sid, "unterste Pixel %.2f m ueber dem Anker" % ((arow - lowest) / ppm))
        cx = (xs.min() + xs.max()) / 2.0
        if abs(cx - ax * cw) > max(3.0, 0.04 * cw):
            rep.err(sid, "Fahrzeug nicht um anchor.x zentriert (%.0f vs %.0f px)" % (cx, ax * cw))
        w_m = (xs.max() - xs.min() + 1) / ppm
        ow = s["object"].get("width_m", 0)
        if ow and not (0.85 * ow <= w_m <= 1.35 * ow + 0.25):
            rep.err(sid, "gemessene Breite %.2f m passt nicht zu object.width_m %.2f m" % (w_m, ow))
    elif cat == "player":
        cx = (xs.min() + xs.max()) / 2.0
        if abs(cx - ax * cw) > max(3.0, 0.02 * cw):
            rep.err(sid, "Auto nicht um anchor.x zentriert (%.0f vs %.0f px)" % (cx, ax * cw))
        cam = s.get("camera", {})
        ss = float(s.get("supersample", 1.0))
        if cam and "screen" in cam:
            f = cam["screen"][0] * 0.5 / math.tan(math.radians(cam["fov_deg"]) * 0.5)
            L = s["object"]["length_m"]
            # widest row in the lower half of the car = rear bumper/haunches at depth distance - L/2
            low = solid[int(arow - 0.35 * ch):int(arow + 0.25 * ch)]
            widths = [(r.nonzero()[0].max() - r.nonzero()[0].min() + 1) for r in low if r.any()]
            if widths:
                w_m = max(widths) / ss * (cam["distance_m"] - L / 2) / f
                ow = s["object"]["width_m"]
                if not (0.9 * ow <= w_m <= 1.2 * ow):
                    rep.err(sid, "gemessene Heckbreite %.2f m passt nicht zu object.width_m %.2f m" % (w_m, ow))
        # anchor = ground point under the car centre: lowest car pixels (rear) are below it
        if lowest < arow:
            rep.err(sid, "Bodenanker liegt unter dem Heck (Anker %.0f, unterste Pixel %.0f)" % (arow, lowest))
    elif cat in ("props", "landmarks"):
        if lowest > arow + max(3, 1.0 * ppm) and "ship" not in s["tags"]:
            rep.warn(sid, "Requisit reicht %.2f m unter den Anker" % ((lowest - arow) / ppm))
        if lowest < arow - max(4, 1.5 * ppm) and "ship" not in s["tags"]:
            rep.warn(sid, "Requisit schwebt %.2f m ueber dem Anker" % ((arow - lowest) / ppm))
        oh = s["object"].get("height_m", 0)
        h_m = (ys.max() - ys.min() + 1) / ppm
        if oh and not (0.6 * oh <= h_m <= 1.3 * oh + 0.3):
            rep.warn(sid, "gemessene Hoehe %.1f m vs object.height_m %.1f m" % (h_m, oh))
    return size


def face_dims(part, face):
    (x0, x1), (y0, y1), (z0, z1) = part["x"], part["y"], part["z"]
    if face == "rear":
        return x1 - x0, y1 - y0
    if face in ("left", "right"):
        return z1 - z0, y1 - y0
    return x1 - x0, z1 - z0          # top: u = x, v = z


def check_box_set(sid, s, src, rep):
    for k in ("file", "render", "object", "tags", "parts"):
        if k not in s:
            rep.err(sid, "Schluessel fehlt: " + k)
            return 0
    if s["render"] != "box":
        rep.err(sid, "render muss 'box' sein")
    for k in ("width_m", "length_m", "height_m"):
        if not isinstance(s["object"].get(k), (int, float)) or s["object"][k] <= 0:
            rep.err(sid, "object.%s fehlt/ungueltig" % k)
    if sid.startswith("traffic/") and any(t not in s["tags"] for t in ("traffic", "heavy")):
        rep.err(sid, "tags muessen traffic und heavy enthalten")
    path = os.path.join(src, s["file"])
    if not os.path.exists(path):
        rep.err(sid, "Datei fehlt: " + s["file"])
        return 0
    size = os.path.getsize(path)
    img = Image.open(path)
    if img.mode != "RGBA":
        rep.err(sid, "PNG ist nicht RGBA (%s)" % img.mode)
        img = img.convert("RGBA")
    W, Hh = img.size
    if W > MAX_SHEET or Hh > MAX_SHEET:
        rep.err(sid, "Sheet groesser als %d px" % MAX_SHEET)
    arr = np.asarray(img).astype(np.float32) / 255.0
    rects = []
    parts = {}
    L = s["object"].get("length_m", 0)
    for p in s["parts"]:
        name = p.get("name")
        if not name or name in parts:
            rep.err(sid, "Teil ohne/mit doppeltem Namen")
            continue
        parts[name] = p
        for k in ("x", "y", "z"):
            r = p.get(k)
            if not (isinstance(r, list) and len(r) == 2 and r[0] < r[1]):
                rep.err(sid, "%s.%s ungueltig: %s" % (name, k, r))
                return size
        if p["y"][0] < -1e-6:
            rep.err(sid, "%s: y beginnt unter dem Boden" % name)
        if L and (p["z"][0] < -L / 2 - 1e-6 or p["z"][1] > L / 2 + 1e-6):
            rep.err(sid, "%s: z ausserhalb der Fahrzeuglaenge" % name)
        faces = p.get("faces", {})
        for f in ("rear", "left", "right"):
            if f not in faces:
                rep.err(sid, "%s: Flaeche %s fehlt" % (name, f))
        for f, rect in faces.items():
            if f not in FACES:
                rep.err(sid, "%s: unbekannte Flaeche %s" % (name, f))
                continue
            if not (isinstance(rect, list) and len(rect) == 4 and all(isinstance(v, int) for v in rect)):
                rep.err(sid, "%s.%s: rect muss [x, y, w, h] (ganzzahlig) sein" % (name, f))
                continue
            x, y, w, h = rect
            if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > W or y + h > Hh:
                rep.err(sid, "%s.%s: rect %s ausserhalb des Sheets %dx%d" % (name, f, rect, W, Hh))
                continue
            um, vm = face_dims(p, f)
            if w / um < MIN_BOX_PPM - 1e-6 or h / vm < MIN_BOX_PPM - 1e-6:
                rep.err(sid, "%s.%s: %.1f x %.1f px/m < %d" % (name, f, w / um, h / vm, MIN_BOX_PPM))
            # face aspect = face metres: pixels per metre along u and v agree (1 % / 1 px tolerance)
            pu, pv = w / um, h / vm
            if abs(pu - pv) > max(0.01 * pu, 1.0 / min(um, vm)):
                rep.err(sid, "%s.%s: Seitenverhaeltnis %d x %d px passt nicht zu %.2f x %.2f m (%.1f / %.1f px/m)" % (
                    name, f, w, h, um, vm, pu, pv))
            a = arr[y:y + h, x:x + w, 3]
            if a.max() < 0.5:
                rep.err(sid, "%s.%s: Flaeche ist leer" % (name, f))
            rects.append(((x, y, w, h), "%s.%s" % (name, f)))
    for layer, entries in (s.get("lights") or {}).items():
        if layer not in LAYER_NAMES or layer == "base":
            rep.err(sid, "unbekannte Lichtebene %s" % layer)
        for e in entries:
            p = parts.get(e.get("part"))
            if p is None or e.get("face") not in p.get("faces", {}):
                rep.err(sid, "Licht %s verweist auf unbekannte Flaeche %s.%s" % (layer, e.get("part"), e.get("face")))
                continue
            rect = e.get("rect")
            fr = p["faces"][e["face"]]
            if not (isinstance(rect, list) and len(rect) == 4) or rect[2:] != fr[2:]:
                rep.err(sid, "Licht %s %s.%s: Groesse %s != Flaeche %s" % (layer, e["part"], e["face"], rect, fr))
                continue
            x, y, w, h = rect
            if x < 0 or y < 0 or x + w > W or y + h > Hh:
                rep.err(sid, "Licht %s: rect ausserhalb" % layer)
                continue
            if arr[y:y + h, x:x + w, 3].max() < 0.3:
                rep.err(sid, "Licht %s %s.%s ist (fast) leer" % (layer, e["part"], e["face"]))
            rects.append(((x, y, w, h), "%s:%s.%s" % (layer, e["part"], e["face"])))
    for i in range(len(rects)):
        for j in range(i + 1, len(rects)):
            (ax, ay, aw, ah), na = rects[i]
            (bx, by, bw, bh), nb = rects[j]
            if ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah:
                rep.err(sid, "Rechtecke ueberlappen: %s / %s" % (na, nb))
    if "lights" in s:
        for need in ("tail", "brake"):
            if not s["lights"].get(need):
                rep.err(sid, "Lichtebene %s fehlt" % need)
    return size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "assets", "sprites"))
    ap.add_argument("--max-mb", type=float, default=60.0)
    ap.add_argument("-q", action="store_true", help="only errors")
    args = ap.parse_args()
    rep = Report(args.q)
    with open(os.path.join(args.src, "manifest.json"), encoding="utf-8") as fh:
        man = json.load(fh)
    if man.get("version") != 1:
        rep.err("manifest", "version muss 1 sein")
    sets = man.get("sets", {})
    required = (["player/" + p for p in PLAYERS] + ["showroom/" + p for p in PLAYERS] +
                ["police/" + c for c in POLICE] + ["props/" + p for p in PROPS] + ["ui/" + u for u in UI] +
                ["landmarks/" + l for l in LANDMARKS] + PLACEHOLDER_IDS)
    for r in sorted(set(required)):
        if r not in sets:
            rep.err(r, "Set fehlt")
    for m in TRAFFIC_MODELS:
        n = len([k for k in sets if k.startswith("traffic/%s_" % m)])
        if n < 3:
            rep.err("traffic/" + m, "nur %d Farben (mindestens 3)" % n)
    for k in sets:
        if k.startswith("traffic/truck_") or k.startswith("traffic/bus_"):
            if sets[k].get("render") != "box":
                rep.err(k, "Lkw/Busse muessen render 'box' sein")
    total = 0
    per_cat = {}
    for sid in sorted(sets):
        s = sets[sid]
        sz = check_box_set(sid, s, args.src, rep) if s.get("render") == "box" else check_sprite_set(sid, s, args.src, rep)
        total += sz
        cat = sid.split("/")[0]
        per_cat[cat] = per_cat.get(cat, 0) + sz
    if total > args.max_mb * 1024 * 1024:
        rep.err("gesamt", "PNG-Groesse %.1f MB > %.0f MB" % (total / 1048576.0, args.max_mb))
    if not args.q:
        for w in rep.warnings:
            print("WARNUNG", w)
    for e in rep.errors:
        print("FEHLER ", e)
    print("%d Sets, %.1f MB PNG (%s), %d Fehler, %d Warnungen" % (
        len(sets), total / 1048576.0, ", ".join("%s %.1f" % (k, v / 1048576.0) for k, v in sorted(per_cat.items())),
        len(rep.errors), len(rep.warnings)))
    sys.exit(1 if rep.errors else 0)


if __name__ == "__main__":
    main()
