#!/usr/bin/env python3
"""Validates assets/sprites/manifest.json and the sprite sheets (ARCHITECTURE.md section 12).

Usage: python3 tools/blender/validate_manifest.py [--src assets/sprites] [--max-mb 40] [-q]
Exit code 1 if an error was found. Needs Pillow + numpy (no Blender).

Checks: required set ids (superset of the placeholders), keys and types, file exists, PNG size =
cells x angles/layers, angle and layer names/order, anchors inside the cell and consistent with the
rendered pixels (ground row, horizontal centre), metric width (opaque width / px-per-metre vs.
object.width_m), transparent cell borders, non-empty light layers, total size budget.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

VEHICLE_ANGLES = ["l2", "l1", "c", "r1", "r2"]
LAYER_NAMES = {"base", "tail", "brake", "beacon_a", "beacon_b", "lights"}
PLAYERS = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]
TRAFFIC_MODELS = ["hatch", "sedan", "wagon", "suv", "van", "sports", "truck", "bus"]
POLICE = ["de", "nl", "be", "fr", "es", "ch", "it", "si", "hr", "rs", "bg", "hu", "at", "cz", "pl", "lt", "lv"]
PROPS = ["tree_oak", "tree_beech", "tree_birch", "tree_pine", "tree_spruce", "tree_poplar", "tree_cypress", "tree_olive",
         "tree_palm", "bush_round", "bush_low", "heather", "rock_a", "rock_b", "cliff", "haybale", "farmhouse", "barn",
         "church", "windmill", "wind_turbine", "power_pylon", "factory", "house_med", "building_block_a",
         "building_block_b", "building_tall", "building_oldtown", "building_shop", "streetlight", "delineator",
         "fuel_station", "fuel_pump", "radar_camera", "customs_booth", "ferry_ship"]
UI = ["weather_normal", "weather_rain", "weather_snow", "daytime_day", "daytime_night", "daytime_dawn", "daytime_dusk"]
# set ids of tools/placeholders/make_placeholders.py (the manifest must stay a superset)
PLACEHOLDER_IDS = (["player/" + p for p in PLAYERS] + ["showroom/" + p for p in PLAYERS] +
                   ["traffic/sedan_red", "traffic/sedan_blue", "traffic/sedan_silver", "traffic/hatch_green",
                    "traffic/van_white", "traffic/truck_white", "police/de", "police/nl"] +
                   ["props/" + p for p in ["tree_oak", "tree_beech", "tree_birch", "tree_spruce", "tree_poplar", "rock_a",
                                           "wind_turbine", "farmhouse", "windmill", "building_block_a", "building_tall",
                                           "streetlight", "delineator", "fuel_station", "fuel_pump", "radar_camera",
                                           "customs_booth"]])


class Report:
    def __init__(self, quiet=False):
        self.errors = []
        self.warnings = []
        self.quiet = quiet

    def err(self, sid, msg):
        self.errors.append("%s: %s" % (sid, msg))

    def warn(self, sid, msg):
        self.warnings.append("%s: %s" % (sid, msg))


def cell_arr(img, s, angle, layer):
    cw, ch = s["cell"]
    c = s["angles"].index(angle)
    r = s["layers"].index(layer)
    return np.asarray(img.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))).astype(np.float32) / 255.0


def check_set(sid, s, src, rep):
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
    cat = sid.split("/")[0]
    if cat in ("player", "traffic", "police"):
        if angles != VEHICLE_ANGLES:
            rep.err(sid, "Fahrzeug-Winkel muessen %s sein" % VEHICLE_ANGLES)
        for l in ("tail", "brake"):
            if l not in layers:
                rep.err(sid, "Ebene fehlt: " + l)
        for k in ("width_m", "length_m", "height_m"):
            if k not in s["object"]:
                rep.err(sid, "object." + k + " fehlt")
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
    path = os.path.join(src, s["file"])
    if not os.path.exists(path):
        rep.err(sid, "Datei fehlt: " + s["file"])
        return 0
    size = os.path.getsize(path)
    img = Image.open(path)
    if img.mode != "RGBA":
        rep.err(sid, "PNG ist nicht RGBA (%s)" % img.mode)
        img = img.convert("RGBA")
    exp = (cw * len(angles), ch * len(layers))
    if img.size != exp:
        rep.err(sid, "Bildgroesse %s, erwartet %s" % (img.size, exp))
        return size
    if max(img.size) > 16384:
        rep.err(sid, "Bild groesser als 16384 px")
    elif max(img.size) > 8192:
        rep.warn(sid, "Bild breiter/hoeher als 8192 px")
    # transparent borders in every cell
    for a in angles:
        for l in layers:
            c = cell_arr(img, s, a, l)
            border = max(c[0, :, 3].max(), c[-1, :, 3].max(), c[:, 0, 3].max(), c[:, -1, 3].max())
            if border > 0.06:
                rep.err(sid, "Zelle %s/%s beruehrt den Rand (alpha %.2f)" % (a, l, border))
            if l != "base" and cat != "ui":
                pass
    # light layers must contain light somewhere
    for l in layers[1:]:
        mx = max(cell_arr(img, s, a, l)[:, :, 3].max() for a in angles)
        if mx < 0.3:
            rep.err(sid, "Ebene %s ist (fast) leer" % l)
    if "beacon_a" in layers and "beacon_b" in layers:
        d = np.abs(cell_arr(img, s, "c", "beacon_a") - cell_arr(img, s, "c", "beacon_b")).max()
        if d < 0.2:
            rep.err(sid, "beacon_a und beacon_b sind gleich")
    # anchor / metric checks on the base layer
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
    if cat in ("player", "traffic", "police"):
        if lowest > arow + 3:
            rep.err(sid, "Fahrzeug reicht %.0f px unter den Bodenanker" % (lowest - arow))
        if lowest < arow - 0.6 * ppm:
            rep.warn(sid, "unterste Pixel %.2f m ueber dem Anker" % ((arow - lowest) / ppm))
        cx = (xs.min() + xs.max()) / 2.0
        if abs(cx - ax * cw) > max(3.0, 0.04 * cw):
            rep.err(sid, "Fahrzeug nicht um anchor.x zentriert (%.0f vs %.0f px)" % (cx, ax * cw))
        wpx = xs.max() - xs.min() + 1
        w_m = wpx / ppm
        ow = s["object"].get("width_m", 0)
        if ow and not (0.85 * ow <= w_m <= 1.35 * ow + 0.25):
            rep.err(sid, "gemessene Breite %.2f m passt nicht zu object.width_m %.2f m" % (w_m, ow))
    elif cat == "props":
        if lowest > arow + max(3, 1.0 * ppm) and "ship" not in s["tags"]:
            rep.warn(sid, "Requisit reicht %.2f m unter den Anker" % ((lowest - arow) / ppm))
        if lowest < arow - max(4, 1.5 * ppm) and "ship" not in s["tags"]:
            rep.warn(sid, "Requisit schwebt %.2f m ueber dem Anker" % ((arow - lowest) / ppm))
        oh = s["object"].get("height_m", 0)
        h_m = (ys.max() - ys.min() + 1) / ppm
        if oh and not (0.6 * oh <= h_m <= 1.3 * oh + 0.3):
            rep.warn(sid, "gemessene Hoehe %.1f m vs object.height_m %.1f m" % (h_m, oh))
    return size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "assets", "sprites"))
    ap.add_argument("--max-mb", type=float, default=40.0)
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
                PLACEHOLDER_IDS)
    for r in sorted(set(required)):
        if r not in sets:
            rep.err(r, "Set fehlt")
    for m in TRAFFIC_MODELS:
        n = len([k for k in sets if k.startswith("traffic/%s_" % m)])
        if n < 3:
            rep.err("traffic/" + m, "nur %d Farben (mindestens 3)" % n)
    total = 0
    per_cat = {}
    for sid in sorted(sets):
        sz = check_set(sid, sets[sid], args.src, rep)
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
