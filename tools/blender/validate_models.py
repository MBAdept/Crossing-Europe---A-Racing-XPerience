#!/usr/bin/env python3
"""Validator of the real-time models (docs/modelle.md).

Usage (from the repository root, plain python3 - no Blender):
  python3 tools/blender/validate_models.py [--only=<glob>] [--report] [--no-godot] [--inspect=<file.json>]

Checks assets/models/ against the rules of the model pipeline and fails (exit 1) on:
  manifest   manifest.json differs from the merge of sets_default.json and the model.json fragments;
             sets_default.json differs from what the sprite manifest gives; a sprite set (except ui/*)
             without a "sets" entry; a set pointing to an unknown model, level of detail or stand-in
  files      a file named by the manifest is missing, a mesh or texture nobody names, hash or byte count
             of a model differ from its files, a texture without (or with a foreign) .import, a .glb
  names      unknown kind, class, node, level of detail or lamp role; surface names of a mesh that differ
             from the classes of its part; more than one surface per class
  budgets    triangles per level of detail, draw calls, cards, shadow caster, texture size, format and
             bytes over the budget of the category; all meshes / all textures over the budget of the game
  vertices   (decoded from the baked files by tools/models/inspect_models.gd) paint codes or lamp channels
             off their values (+-0.02), lamp weights or material values outside 0..1, atlas coordinates of
             baked surfaces outside 0..1, uncompressed surfaces, materials inside a mesh, an automatic
             (decimated) level in a patch-built body; more than a handful of triangles of a vpbr or baked
             surface wound against their normals (inside out: they are culled and cast no shadow)
  lamps      vehicles, every level of detail: a lamp the following driver reacts to shows too little area in
             the direction he looks from (LAMP_MIN_CM2: tail, brake and each indicator from straight behind;
             head and each indicator from straight ahead - projected area by the winding of the triangles);
             a coarser level shows more than LAMP_GROW times the lamp of the finer one (the nearest level
             must not have the smallest lamp); an automatic level that loses lamp area (LAMP_KEEP);
             a light anchor more than ANCHOR_BELOW_MM under the lamp it belongs to, or with a "dir" that is
             no unit vector or looks into the lamp
  sizes      "object" / "extent_m" more than 2 % (at least half a sprite pixel) off the sprite manifest;
             a wheel that does not touch the ground (+-1 cm); a merged far level that floats or sinks;
             vehicles: a level whose bounding box differs from that of lod0 (BOUNDS_TOL_M per side)
--report     one line per model: triangles, draw calls, bytes; export and bake times from the local cache
--no-godot   skip everything that needs the decoded files (the result then says so and is not "OK")
--inspect    use an existing report of inspect_models.gd instead of running Godot
Godot is taken from $GODOT (default "godot"); XDG_DATA_HOME is set to a temporary folder unless the caller gives
an absolute one (Godot ignores a relative value and would use the real user folder).
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from ce3d import EXPORTER, MANIFEST_VERSION  # noqa: E402
from ce3d import manifest as M  # noqa: E402

ROOT = M.ROOT
LOD_NAMES = ("lod0", "lod1", "lod2", "show")
NODE_RE = re.compile(r"^((tractor|trailer)/)?(body|wheel_\d+[lr])$")
HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
PAINT_CODES = (0.0, 0.25, 0.5, 1.0)
CODE_TOL = 0.02
LAMP_CHANNELS = 15              # 0..14 are in use
UV_TOL = 0.002
GROUND_TOL = 0.01
SIZE_TOL = 0.02
IMPOSTOR_MAX = 512
LEAVES_MAX = 1024
TEX_VRAM_TOTAL = 240 * 1024 * 1024
TEX_SOURCE_TOTAL = 60 * 1024 * 1024
FALLBACKS = ("sprite", "box")
# --- lamps (Rule 9: lights and indicators are what the player reacts to) ---
# lamp channels of the vpbr format (ce3d/roles.py)
CH_TAIL, CH_BRAKE, CH_TAIL_BRAKE, CH_IND_L, CH_IND_R, CH_HEAD = 0, 1, 2, 3, 4, 5
# what a vehicle shows per level: (label, channels, end of the car, direction it is seen from)
LAMP_VIEWS = (
    ("Rücklicht von hinten", (CH_TAIL, CH_TAIL_BRAKE), "rear", "back"),
    ("Bremslicht von hinten", (CH_BRAKE, CH_TAIL_BRAKE), "rear", "back"),
    ("Blinker links von hinten", (CH_IND_L,), "rear", "back"),
    ("Blinker rechts von hinten", (CH_IND_R,), "rear", "back"),
    ("Scheinwerfer von vorn", (CH_HEAD,), "front", "front"),
    ("Blinker links von vorn", (CH_IND_L,), "front", "front"),
    ("Blinker rechts von vorn", (CH_IND_R,), "front", "front"),
)
# smallest projected area (cm2) per view, in the order of LAMP_VIEWS. Rear indicators: 60 cm2 is a lamp of
# 12 x 5 cm - at 100 m about 1 x 0.4 px of the 1280-px picture, the flare layer takes over from there (F6).
# The player's own car is never seen from ahead in a race (chase camera): its front indicators only have to exist.
LAMP_MIN_CM2 = {
    "car": (200.0, 100.0, 60.0, 60.0, 80.0, 40.0, 40.0),
    "police": (200.0, 100.0, 60.0, 60.0, 80.0, 40.0, 40.0),
    "heavy": (200.0, 100.0, 60.0, 60.0, 80.0, 40.0, 40.0),
    "player": (200.0, 100.0, 60.0, 60.0, 80.0, 15.0, 15.0),
}
LAMP_GROW = 2.0                 # a coarser level may show at most this many times the lamp of the finer one ...
LAMP_GROW_SLACK_CM2 = 5.0       # ... plus this
LAMP_KEEP = 0.8                 # an automatic (decimated) level keeps at least this share of every lamp's area
ANCHOR_BELOW_MM = 3.0           # a light anchor lies at most this far under its lamp
WINDING_MAX = 8                 # triangles of a surface that may be wound against their normals ("a handful")
# every level of a vehicle fills the bounding box of lod0 (m per side of the box): a coarser level simplifies,
# it does not shrink or lose what sticks out (mirrors, roof rails)
BOUNDS_TOL_M = {"car": 0.03, "police": 0.03, "player": 0.02, "heavy": 0.05}
WINDING_CLASSES = ("vpbr", "baked", "baked_cutout")


class Result:
    def __init__(self):
        self.errors = []
        self.notes = []

    def err(self, where, text):
        self.errors.append("FEHLER %s: %s" % (where, text))

    def note(self, text):
        self.notes.append(text)


# --- manifest ----------------------------------------------------------------------------------------------

def check_manifest(res):
    path = os.path.join(M.MODELS_DIR, "manifest.json")
    if not os.path.exists(path):
        res.err("manifest.json", "fehlt (export_models.py --manifest-only)")
        return None
    man = M.read_json(path)
    if man.get("version") != MANIFEST_VERSION:
        res.err("manifest.json", "Version %r statt %r" % (man.get("version"), MANIFEST_VERSION))
    if man.get("exporter") != EXPORTER:
        res.err("manifest.json", "Exporter %r statt %r" % (man.get("exporter"), EXPORTER))
    merged = M.merge()
    if merged != man:
        res.err("manifest.json", "weicht von sets_default.json + Fragmenten ab (export_models.py --manifest-only)")
    elif M.dumps(merged) + "\n" != open(path, encoding="utf-8").read():
        res.err("manifest.json", "Inhalt stimmt, Schreibweise nicht (export_models.py --manifest-only)")
    sprite = M.read_json(M.SPRITE_MANIFEST)
    defaults = M.read_json(os.path.join(M.MODELS_DIR, M.DEFAULT_SETS)).get("sets", {})
    if defaults != M.default_sets(sprite):
        res.err(M.DEFAULT_SETS, "veraltet gegenüber dem Sprite-Manifest (export_models.py --defaults)")
    want = sorted(s for s in sprite["sets"] if not s.startswith("ui/"))
    sets = man.get("sets", {})
    for sid in want:
        if sid not in sets:
            res.err(sid, "Sprite-Set ohne Eintrag in \"sets\"")
    for sid in sorted(sets):
        if sid not in sprite["sets"] or sid.startswith("ui/"):
            res.err(sid, "Eintrag in \"sets\" ohne Sprite-Set")
    models = man.get("models", {})
    for sid in sorted(sets):
        e = sets[sid]
        ids = ([e["model"]] if "model" in e else []) + list(e.get("variants", []))
        if not ids:
            if e.get("fallback") not in FALLBACKS:
                res.err(sid, "weder Modell noch Platzhalter (fallback %r)" % (e.get("fallback"),))
            continue
        for mid in ids:
            if mid not in models:
                res.err(sid, "Modell %s gibt es nicht" % mid)
            elif e.get("lod") and e["lod"] not in [l["name"] for l in models[mid].get("lods", [])]:
                res.err(sid, "Modell %s hat keine Stufe %s" % (mid, e["lod"]))
        if "showroom" in e and not isinstance(e["showroom"], bool):
            res.err(sid, "showroom ist kein Wahrheitswert")
    return man, sprite


# --- files -------------------------------------------------------------------------------------------------

def named_files(mid, model):
    """Files (relative to assets/models/) the manifest entry of a model names."""
    out = []
    for lod in model.get("lods", []):
        for part in lod.get("parts", []):
            out.append(part.get("mesh", ""))
    if model.get("shadow"):
        out.append(model["shadow"].get("mesh", ""))
    out += list(model.get("textures", {}).values())
    if model.get("impostor"):
        out.append(model["impostor"].get("texture", ""))
    return sorted(set(out))


def check_files(res, mid, model):
    folder = os.path.join(M.MODELS_DIR, mid)
    if not os.path.isdir(folder):
        res.err(mid, "Ordner fehlt")
        return
    named = named_files(mid, model)
    for rel in named:
        if not rel.startswith(mid + "/"):
            res.err(mid, "Datei %s liegt nicht im Ordner des Modells" % rel)
        elif not os.path.exists(os.path.join(M.MODELS_DIR, rel)):
            res.err(mid, "Datei %s fehlt" % rel)
    have = [mid + "/" + f for f in M.model_files(folder)]
    for rel in have:
        if rel not in named:
            res.err(mid, "Datei %s steht nicht im Manifest" % rel)
    digest, total = M.files_hash(folder)
    if model.get("hash") != digest:
        res.err(mid, "hash passt nicht zu den Dateien (neu backen)")
    if model.get("bytes") != total:
        res.err(mid, "bytes %s statt %d" % (model.get("bytes"), total))
    for f in sorted(os.listdir(folder)):
        if f.endswith(M.TEXTURE_EXT) and not os.path.exists(os.path.join(folder, f + ".import")):
            res.err(mid, "%s ohne .import (tools/models/set_model_import.py)" % f)
        if f.endswith(".glb"):
            res.err(mid, "%s gehört nicht ins Repository" % f)


def check_tree(res, man):
    """Folders without a manifest entry, foreign .import files."""
    for mid in M.fragment_ids():
        if mid not in man.get("models", {}):
            res.err(mid, "Fragment ohne Eintrag im Manifest")
    for group in sorted(os.listdir(M.MODELS_DIR)):
        gdir = os.path.join(M.MODELS_DIR, group)
        if not os.path.isdir(gdir):
            continue
        if group not in M.GROUPS:
            res.err(group, "unbekannte Gruppe (erlaubt: %s)" % ", ".join(M.GROUPS))
        for name in sorted(os.listdir(gdir)):
            if os.path.isdir(os.path.join(gdir, name)) and not os.path.exists(os.path.join(gdir, name, "model.json")):
                res.err(group + "/" + name, "Ordner ohne model.json")
    tool = os.path.join(ROOT, "tools", "models", "set_model_import.py")
    p = subprocess.run([sys.executable, tool, "--check", "--quiet"], cwd=ROOT, capture_output=True, text=True)
    if p.returncode != 0:
        res.err("assets/models", ".import-Dateien weichen ab (tools/models/set_model_import.py): "
                + (p.stdout + p.stderr).strip().replace("\n", " | ")[:300])


# --- entries -------------------------------------------------------------------------------------------------

def check_entry(res, mid, model):
    cat = M.category(mid, model)
    if model.get("kind") not in M.KINDS:
        res.err(mid, "unbekannte Art %r" % (model.get("kind"),))
        return
    if cat not in M.BUDGETS:
        res.err(mid, "keine Budget-Kategorie für %r" % cat)
        return
    lods = model.get("lods", [])
    names = [l.get("name") for l in lods]
    if not lods or names[0] != "lod0":
        res.err(mid, "erste Stufe ist nicht lod0")
    if len(set(names)) != len(names):
        res.err(mid, "Stufe doppelt")
    last = 0
    for lod in lods:
        ln = lod.get("name")
        if ln not in LOD_NAMES:
            res.err(mid, "unbekannte Stufe %r" % (ln,))
            continue
        if ln != "show":
            if not lod.get("max_dist_m", 0) > last:
                res.err(mid, "%s: max_dist_m steigt nicht" % ln)
            last = lod.get("max_dist_m", 0)
        nodes = []
        for part in lod.get("parts", []):
            node = part.get("node", "")
            nodes.append(node)
            if not NODE_RE.match(node):
                res.err(mid, "%s: unbekannter Knoten %r" % (ln, node))
            for c in part.get("classes", []):
                if c not in M.CLASSES:
                    res.err(mid, "%s/%s: unbekannte Klasse %r" % (ln, node, c))
            if "wheel" in part:
                w = part["wheel"]
                pos = part.get("pos", [0, 0, 0])
                if not w.get("radius", 0) > 0:
                    res.err(mid, "%s/%s: Rad ohne Radius" % (ln, node))
                elif abs(pos[1] - w["radius"]) > GROUND_TOL:
                    res.err(mid, "%s/%s: Radmitte %.3f m, Radius %.3f m" % (ln, node, pos[1], w["radius"]))
                if node.endswith("l") != (abs(part.get("yaw_deg", 0)) == 180):
                    res.err(mid, "%s/%s: linke Räder sind das um 180 Grad gedrehte rechte Rad" % (ln, node))
        if len(set(nodes)) != len(nodes):
            res.err(mid, "%s: Knoten doppelt" % ln)
        if model["kind"] in ("vehicle", "heavy") and ln in ("lod1", "lod2"):
            if nodes != ["body"]:
                res.err(mid, "%s: ferne Stufen sind ein Netz \"body\"" % ln)
            elif "glass" in lod["parts"][0].get("classes", []):
                res.err(mid, "%s: ferne Stufen haben keine Klasse glass" % ln)
        if model["kind"] not in ("vehicle", "heavy") and nodes != ["body"]:
            res.err(mid, "%s: Requisiten haben nur den Knoten \"body\"" % ln)
    for light in model.get("lights", []):
        if light.get("role") not in M.LIGHT_ROLES:
            res.err(mid, "unbekannte Lichtrolle %r" % (light.get("role"),))
        if len(light.get("pos", [])) != 3 or not light.get("size", 0) > 0 or not HEX_RE.match(str(light.get("color", ""))):
            res.err(mid, "Lichtanker unvollständig: %r" % (light,))
    budget = M.BUDGETS[cat]
    cards = model.get("cards", {})
    if budget.get("cards") and cards.get("lod0", 0) > budget["cards"]:
        res.err(mid, "%d Karten, Budget %d" % (cards["lod0"], budget["cards"]))
    if model.get("shadow") and budget.get("shadow") and model["shadow"].get("tris", 0) > budget["shadow"]:
        res.err(mid, "Schattenwerfer %d Dreiecke, Budget %d" % (model["shadow"]["tris"], budget["shadow"]))
    for lod in lods:
        ln = lod.get("name")
        limit = budget.get(ln)
        if limit is None and ln in ("lod1", "lod2", "show"):
            res.err(mid, "Stufe %s ist für die Kategorie %s nicht vorgesehen" % (ln, cat))
        elif limit is not None and lod.get("tris", 0) > limit:
            res.err(mid, "%s: %d Dreiecke, Budget %d" % (ln, lod.get("tris", 0), limit))


def check_sizes(res, man, sprite):
    """object / extent_m of every set with a model against the sprite manifest."""
    for sid in sorted(man.get("sets", {})):
        e = man["sets"][sid]
        s = sprite["sets"].get(sid)
        if s is None:
            continue
        if "model" not in e:
            if e.get("object") != s.get("object") and s.get("object"):
                res.err(sid, "object des Platzhalters weicht vom Sprite-Manifest ab")
            continue
        model = man["models"].get(e["model"])
        if model is None:
            continue
        px = s["image_width_m"] / s["cell"][0] if s.get("image_width_m") and s.get("cell") else 0.0
        for key, want in (s.get("object") or {}).items():
            got = model.get("object", {}).get(key)
            if got is None or abs(got - want) > max(SIZE_TOL * abs(want), 0.005):
                res.err(sid, "object.%s %s, Sprite %s" % (key, got, want))
        if s.get("extent_m") and model.get("extent_m"):
            for i, key in enumerate(("left", "right")):
                want = s["extent_m"][i]
                got = model["extent_m"].get(key)
                if got is None or abs(got - want) > max(SIZE_TOL * abs(want), 0.5 * px + 0.005):
                    res.err(sid, "extent_m.%s %s, Sprite %s" % (key, got, want))
        elif s.get("extent_m") and model.get("kind") not in ("vehicle", "heavy"):
            res.err(sid, "Modell ohne extent_m (das Sprite hat eines)")


# --- decoded files -------------------------------------------------------------------------------------------

def run_inspect(res):
    env = dict(os.environ)
    # only an absolute XDG_DATA_HOME of the caller counts: Godot ignores a relative one and falls back to
    # ~/.local/share - the real user folder
    if not os.path.isabs(env.get("XDG_DATA_HOME", "")):
        env["XDG_DATA_HOME"] = os.path.abspath(tempfile.mkdtemp(prefix="ce_validate_"))
    godot = env.get("GODOT", "godot")
    out = os.path.join(tempfile.mkdtemp(prefix="ce_inspect_"), "inspect.json")
    cmd = [godot, "--headless", "--path", ROOT, "-s", "res://tools/models/inspect_models.gd", "--", "--out=" + out]
    report = None
    for attempt in range(2):
        try:
            p = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=600)
        except (OSError, subprocess.TimeoutExpired) as ex:
            res.err("godot", "inspect_models.gd lief nicht: %s" % ex)
            return None
        if not os.path.exists(out):
            res.err("godot", "inspect_models.gd schrieb keinen Bericht: " + (p.stdout + p.stderr).strip()[-300:])
            return None
        report = M.read_json(out)
        missing = [k for k, t in report.get("textures", {}).items() if t.get("missing")]
        if not missing or attempt == 1:
            break
        # textures not imported yet (fresh checkout): import once and look again
        subprocess.run([godot, "--headless", "--path", ROOT, "--import"], cwd=ROOT, env=env, capture_output=True,
                       timeout=1200)
    return report


def near(v, targets, tol):
    return any(abs(v - t) <= tol for t in targets)


def check_decoded(res, man, report):
    meshes = report.get("meshes", {})
    textures = report.get("textures", {})
    if not report.get("available"):
        res.err("godot", "ModelDB.available() ist falsch")
    stats = {}
    mesh_total = 0
    for rel, m in meshes.items():
        mesh_total += m.get("bytes", 0)
    if mesh_total > M.MESH_BYTES_TOTAL:
        res.err("assets/models", "Netze %d Bytes, Budget %d" % (mesh_total, M.MESH_BYTES_TOTAL))
    vram = sum(t.get("vram_bytes", 0) for t in textures.values())
    src = sum(t.get("file_bytes", 0) for t in textures.values())
    if vram > TEX_VRAM_TOTAL:
        res.err("assets/models", "Texturen %d Bytes im Grafikspeicher, Budget %d" % (vram, TEX_VRAM_TOTAL))
    if src > TEX_SOURCE_TOTAL:
        res.err("assets/models", "Texturquellen %d Bytes, Budget %d" % (src, TEX_SOURCE_TOTAL))
    for mid in sorted(man["models"]):
        model = man["models"][mid]
        cat = M.category(mid, model)
        budget = M.BUDGETS.get(cat, {})
        st = stats.setdefault(mid, dict(lods={}, draws={}, mesh_bytes=0, tex_bytes=0, vram=0))
        seen = set()
        for li, lod in enumerate(model.get("lods", [])):
            ln = lod.get("name")
            tris = 0
            draws = 0
            for part in lod.get("parts", []):
                rel = part.get("mesh", "")
                m = meshes.get(rel)
                if m is None or m.get("missing"):
                    res.err(mid, "%s: Netz %s lässt sich nicht laden" % (ln, rel))
                    continue
                snames = [s["name"] for s in m["surfaces"]]
                if snames != list(part.get("classes", [])):
                    res.err(mid, "%s/%s: Flächen %s, Manifest %s" % (ln, part.get("node"), snames, part.get("classes")))
                if len(set(snames)) != len(snames):
                    res.err(mid, "%s/%s: mehr als eine Fläche je Klasse" % (ln, part.get("node")))
                tris += sum(s["tris"] for s in m["surfaces"])
                draws += len(m["surfaces"])
                if rel not in seen:
                    seen.add(rel)
                    st["mesh_bytes"] += m.get("bytes", 0)
                    check_mesh(res, mid, rel, m, model, part)
                if "wheel" in part:
                    low = m["aabb"][1] + part.get("pos", [0, 0, 0])[1]
                    if abs(low) > GROUND_TOL:
                        res.err(mid, "%s/%s: Rad steht %.1f mm über dem Boden" % (ln, part.get("node"), low * 1000.0))
                elif model.get("kind") in ("vehicle", "heavy") and ln in ("lod1", "lod2"):
                    if abs(m["aabb"][1]) > GROUND_TOL:
                        res.err(mid, "%s: tiefster Punkt %.1f mm über dem Boden" % (ln, m["aabb"][1] * 1000.0))
            if tris != lod.get("tris"):
                res.err(mid, "%s: %d Dreiecke in den Netzen, %s im Manifest" % (ln, tris, lod.get("tris")))
            dl = budget.get("draws", (None, None, None))
            limit = dl[0] if ln in ("lod0", "show") else (dl[1] if ln == "lod1" else dl[2])
            if limit is not None and draws > limit:
                res.err(mid, "%s: %d Zeichenaufrufe, Budget %d" % (ln, draws, limit))
            st["lods"][ln] = tris
            st["draws"][ln] = draws
        if model.get("shadow"):
            rel = model["shadow"].get("mesh", "")
            m = meshes.get(rel)
            if m is None or m.get("missing"):
                res.err(mid, "Schattenwerfer %s lässt sich nicht laden" % rel)
            else:
                tris = sum(s["tris"] for s in m["surfaces"])
                if tris != model["shadow"].get("tris"):
                    res.err(mid, "Schattenwerfer: %d Dreiecke, %s im Manifest" % (tris, model["shadow"].get("tris")))
                st["lods"]["shadow"] = tris
                st["mesh_bytes"] += m.get("bytes", 0)
                if any(not s.get("compressed") for s in m["surfaces"]) or m.get("has_materials"):
                    res.err(mid, "Schattenwerfer: unkomprimiert oder mit Material")
                for s in m["surfaces"]:
                    w = s.get("winding") or {}
                    if w.get("against", 0) > WINDING_MAX:
                        res.err(mid, "Schattenwerfer: %d von %d Dreiecken zeigen gegen ihre Normalen (sie werfen "
                                     "keinen Schatten)" % (w["against"], w.get("total", 0)))
        check_textures(res, mid, model, cat, textures, st)
        check_bounds(res, mid, model, cat, meshes)
        check_lamps(res, mid, model, cat, meshes)
        check_anchors(res, mid, model, report.get("anchors", {}).get(mid, []))
    return stats, mesh_total, vram, src


def level_aabb(meshes, lod):
    """[min x, min y, min z, max x, max y, max z] of a level in model space (parts posed), or None."""
    lo, hi = [1e30] * 3, [-1e30] * 3
    for part in lod.get("parts", []):
        m = meshes.get(part.get("mesh", ""))
        if m is None or m.get("missing"):
            return None
        a = m["aabb"]
        x0, x1, z0, z1 = a[0], a[3], a[2], a[5]
        if abs(part.get("yaw_deg", 0)) == 180:
            x0, x1, z0, z1 = -x1, -x0, -z1, -z0
        pos = part.get("pos", [0.0, 0.0, 0.0])
        for i, (v0, v1) in enumerate(((x0, x1), (a[1], a[4]), (z0, z1))):
            lo[i] = min(lo[i], v0 + pos[i])
            hi[i] = max(hi[i], v1 + pos[i])
    return lo + hi


def check_bounds(res, mid, model, cat, meshes):
    """Vehicles: every level fills the bounding box of lod0."""
    tol = BOUNDS_TOL_M.get(cat)
    if tol is None or model.get("kind") not in ("vehicle", "heavy"):
        return
    boxes = {lod.get("name"): level_aabb(meshes, lod) for lod in model.get("lods", [])}
    base = boxes.get("lod0")
    if base is None:
        return
    names = ("links", "unten", "vorn", "rechts", "oben", "hinten")
    for ln, box in boxes.items():
        if ln == "lod0" or box is None:
            continue
        off = [(names[i], box[i] - base[i]) for i in range(6) if abs(box[i] - base[i]) > tol]
        if off:
            res.err(mid, "%s: Hüllquader weicht von lod0 ab (%s; erlaubt %.0f mm je Seite)"
                    % (ln, ", ".join("%s %+.0f mm" % (n, d * 1000.0) for n, d in off), tol * 1000.0))


def lamp_view(meshes, lod, channels, end, direction):
    """Projected area (cm2) of the given lamp channels at one end of the model, seen from `direction`
    ("back" | "front"), summed over the meshes of a level."""
    total = 0.0
    for part in lod.get("parts", []):
        m = meshes.get(part.get("mesh", ""))
        if m is None or m.get("missing"):
            continue
        for s in m["surfaces"]:
            for ch in channels:
                e = s.get("lamps", {}).get("%d|%s" % (ch, end))
                if e:
                    total += e[direction] * 1.0e4
    return total


def check_lamps(res, mid, model, cat, meshes):
    """Lamps of vehicles per level of detail, automatic levels of every model."""
    for lod in model.get("lods", []):
        for part in lod.get("parts", []):
            m = meshes.get(part.get("mesh", ""))
            if m is None or m.get("missing"):
                continue
            for s in m["surfaces"]:
                base = {}
                for key, e in s.get("lamps", {}).items():
                    ch = key.split("|")[0]
                    base[ch] = base.get(ch, 0.0) + e["area"]
                for i, level in enumerate(s.get("lamp_lods", [])):
                    for ch, area in sorted(base.items()):
                        if area > 1.0e-4 and level.get(ch, 0.0) < LAMP_KEEP * area:
                            res.err(mid, "%s: automatische Stufe %d behält von Lampenkanal %s nur %.0f von %.0f cm2 "
                                         "(auto_lod abschalten)" % (part.get("mesh", "").split("/")[-1], i + 1, ch,
                                                                    level.get(ch, 0.0) * 1.0e4, area * 1.0e4))
    if model.get("kind") not in ("vehicle", "heavy"):
        return
    mins = LAMP_MIN_CM2.get(cat)
    if mins is None:
        res.err(mid, "keine Lampen-Mindestflächen für die Kategorie %r" % cat)
        return
    by_level = {}
    for lod in model.get("lods", []):
        by_level[lod.get("name")] = [lamp_view(meshes, lod, ch, end, d) for (_l, ch, end, d) in LAMP_VIEWS]
    for ln, areas in by_level.items():
        for (label, _ch, _end, _d), area, need in zip(LAMP_VIEWS, areas, mins):
            if area < need:
                res.err(mid, "%s: %s zeigt %.1f cm2, verlangt mindestens %.0f" % (ln, label, area, need))
    order = [n for n in ("lod0", "lod1", "lod2") if n in by_level]
    for fine, coarse in zip(order[:-1], order[1:]):
        for (label, _ch, _end, _d), a, b in zip(LAMP_VIEWS, by_level[fine], by_level[coarse]):
            if b > a * LAMP_GROW + LAMP_GROW_SLACK_CM2:
                res.err(mid, "%s: %s zeigt %.1f cm2, die feinere Stufe %s nur %.1f (die nahe Stufe darf nicht die "
                             "kleinste Lampe haben)" % (coarse, label, b, fine, a))


def check_anchors(res, mid, model, anchors):
    """Light anchors against the lamps of lod0 (inspect_models.gd: "anchors")."""
    lights = model.get("lights", [])
    for light in lights:
        d = light.get("dir")
        if d is None:
            if model.get("kind") in ("vehicle", "heavy"):
                # contract A-4: anchors carry dir (where the lamp looks) - flares sit a little along it. Only lamps of
                # baked models (light in the atlas) have none
                res.err(mid, "Lichtanker %s bei %s ohne dir (Fahrzeuge: Pflicht, Vertrag A-4)"
                        % (light.get("role"), light.get("pos")))
            continue
        if len(d) != 3 or abs(sum(float(v) ** 2 for v in d) ** 0.5 - 1.0) > 0.01:
            res.err(mid, "Lichtanker %s: dir %r ist kein Einheitsvektor" % (light.get("role"), d))
    if len(anchors) != len(lights):
        res.err(mid, "%d Lichtanker im Manifest, %d im Bericht der dekodierten Netze" % (len(lights), len(anchors)))
        return
    for a in anchors:
        if a.get("dist_mm", -1.0) < 0.0:
            continue                    # no lamp triangles of this role in lod0 (baked models: lamps in the atlas)
        if a.get("below_mm", 0.0) > ANCHOR_BELOW_MM:
            res.err(mid, "Lichtanker %s bei %s liegt %.1f mm unter seiner Lampe (höchstens %.0f)"
                    % (a.get("role"), a.get("pos"), a["below_mm"], ANCHOR_BELOW_MM))
        if a.get("dir_dot", 2.0) < 0.0:
            res.err(mid, "Lichtanker %s bei %s: dir zeigt in die Lampe hinein" % (a.get("role"), a.get("pos")))


def check_mesh(res, mid, rel, m, model, part):
    name = rel.split("/")[-1]
    if m.get("has_materials"):
        res.err(mid, "%s: Netz trägt Materialien (die bindet der Renderer je Klasse)" % name)
    for s in m["surfaces"]:
        cls = s["name"]
        where = "%s[%s]" % (name, cls)
        if not s.get("compressed"):
            res.err(mid, "%s: Fläche ist nicht komprimiert" % where)
        if not model.get("auto_lod") and part.get("node") == "body" and s.get("lods", 0) > 0:
            res.err(mid, "%s: automatische (dezimierte) Stufe in einem Modell ohne auto_lod" % where)
        w = s.get("winding")
        if w and cls in WINDING_CLASSES and w.get("against", 0) > WINDING_MAX:
            res.err(mid, "%s: %d von %d Dreiecken zeigen gegen ihre Normalen (verkehrt herum gewickelt)"
                    % (where, w["against"], w.get("total", 0)))
        if cls == "vpbr":
            if "alpha_values" not in s or "lamp_values" not in s or "uv_range" not in s:
                res.err(mid, "%s: COLOR, UV oder UV2 fehlt" % where)
                continue
            bad = [a for a in s["alpha_values"] if not near(a, PAINT_CODES, CODE_TOL)]
            if bad or s.get("alpha_count", 0) > 64:
                res.err(mid, "%s: Lackcodes neben den Werten 0 / 0.25 / 0.5 / 1: %s" % (where, bad[:6]))
            bad = []
            for v in s["lamp_values"]:
                if near(v, (-1.0,), CODE_TOL):
                    continue
                ch = int(v // 1)
                if v < 0.0 or ch >= LAMP_CHANNELS or abs(v - ch - 0.5) > CODE_TOL:
                    bad.append(v)
            if bad:
                res.err(mid, "%s: Lampenkanäle neben Kanal + 0.5: %s" % (where, bad[:6]))
            lw = s.get("lamp_weight_range", [0, 0])
            if lw[0] < -0.001 or lw[1] > 1.001:
                res.err(mid, "%s: Lampengewicht außerhalb 0..1: %s" % (where, lw))
            uv = s["uv_range"]
            if min(uv) < -UV_TOL or max(uv) > 1.0 + UV_TOL:
                res.err(mid, "%s: Rauheit / Metall außerhalb 0..1: %s" % (where, uv))
        elif cls in ("baked", "baked_cutout", "leaves"):
            uv = s.get("uv_range")
            if uv is None:
                res.err(mid, "%s: UV fehlt" % where)
            elif min(uv) < -UV_TOL or max(uv) > 1.0 + UV_TOL:
                res.err(mid, "%s: Atlas-Koordinaten außerhalb 0..1: %s" % (where, [round(x, 4) for x in uv]))
            if cls == "leaves" and "alpha_values" not in s:
                res.err(mid, "%s: COLOR (Windgewichte) fehlt" % where)
        elif cls == "glass":
            if "alpha_values" not in s:
                res.err(mid, "%s: COLOR (Tönung, Deckkraft) fehlt" % where)


def check_textures(res, mid, model, cat, textures, st):
    tier = M.TEXTURE_TIER.get(cat, 1024)
    classes = set(c for lod in model.get("lods", []) for part in lod.get("parts", []) for c in part.get("classes", []))
    wanted = dict(model.get("textures", {}))
    if model.get("impostor"):
        wanted["impostor"] = model["impostor"].get("texture", "")
    if ("baked" in classes or "baked_cutout" in classes) and "albedo" not in wanted:
        res.err(mid, "Klasse baked ohne Textur albedo")
    if "leaves" in classes and "leaves" not in wanted:
        res.err(mid, "Klasse leaves ohne Textur leaves")
    albedo_side = 0
    for role in ("albedo", "emit", "leaves", "impostor"):
        rel = wanted.get(role)
        if not rel:
            continue
        t = textures.get(rel)
        if t is None or t.get("missing") or "size" not in t:
            res.err(mid, "Textur %s lässt sich nicht laden (importiert?)" % rel)
            continue
        side = max(t["size"])
        alpha = role in ("leaves", "impostor") or (role == "albedo" and "baked_cutout" in classes)
        if role == "albedo":
            albedo_side = side
            limit = tier
        elif role == "emit":
            limit = max(albedo_side // 2, 1) if albedo_side else tier // 2
        else:
            limit = LEAVES_MAX if role == "leaves" else IMPOSTOR_MAX
        if side > limit:
            res.err(mid, "Textur %s: %d px, erlaubt %d" % (role, side, limit))
        if rel.endswith(".png") and side > 1024:
            res.err(mid, "Textur %s: PNG über 1024 px (WebP Qualität 95 nehmen)" % role)
        want_fmt = ("BC3",) if alpha else ("BC1",)
        if t.get("format_name") not in want_fmt:
            res.err(mid, "Textur %s: Format %s statt %s" % (role, t.get("format_name"), want_fmt[0]))
        if not t.get("mipmaps"):
            res.err(mid, "Textur %s ohne Mipmaps" % role)
        if not t.get("import"):
            res.err(mid, "Textur %s ohne .import" % role)
        vram_limit = int(limit * limit * (1.0 if alpha else 0.5) * 4.0 / 3.0) + 64
        if t.get("vram_bytes", 0) > vram_limit:
            res.err(mid, "Textur %s: %d Bytes im Grafikspeicher, erlaubt %d" % (role, t["vram_bytes"], vram_limit))
        st["tex_bytes"] += t.get("file_bytes", 0)
        st["vram"] += t.get("vram_bytes", 0)


# --- report --------------------------------------------------------------------------------------------------

def cache_times():
    """Export and bake seconds per model from the local cache (empty on a fresh checkout)."""
    cache = os.path.join(HERE, "_cache3d")
    out = {}
    rep = os.path.join(cache, "bake_report.json")
    bake = M.read_json(rep) if os.path.exists(rep) else {}
    rep = os.path.join(cache, "export_report.json")
    export = M.read_json(rep) if os.path.exists(rep) else {}
    for mid in M.fragment_ids():
        e = {}
        if mid in export:
            e["export_s"] = export[mid].get("export_s")
        if mid in bake:
            e["bake_s"] = bake[mid].get("bake_s")
        out[mid] = e
    return out


def print_report(man, stats):
    times = cache_times()
    print("%-22s %-9s %-34s %-12s %9s %9s %8s %7s" % ("Modell", "Kategorie", "Dreiecke je Stufe", "Aufrufe", "Netze B",
                                                    "Textur B", "Export s", "Bake s"))
    for mid in sorted(man["models"]):
        model = man["models"][mid]
        st = stats.get(mid, {})
        lods = " ".join("%s %d" % (k, v) for k, v in st.get("lods", {}).items())
        draws = "/".join(str(v) for v in st.get("draws", {}).values())
        t = times.get(mid, {})
        fmt = lambda v: "-" if v is None else ("%.1f" % v if v >= 0.95 else "%.2f" % v)  # noqa: E731
        print("%-22s %-9s %-34s %-12s %9d %9d %8s %7s" % (mid, M.category(mid, model), lods, draws,
                                                          st.get("mesh_bytes", 0), st.get("tex_bytes", 0),
                                                          fmt(t.get("export_s")), fmt(t.get("bake_s"))))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default="*")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--no-godot", action="store_true")
    ap.add_argument("--inspect", default="")
    args = ap.parse_args()
    res = Result()
    got = check_manifest(res)
    if got is None:
        print("\n".join(res.errors))
        print("CHECK models FEHLER (%d)" % len(res.errors))
        return 1
    man, sprite = got
    check_tree(res, man)
    ids = [mid for mid in sorted(man["models"]) if M.match(mid, args.only)]
    for mid in ids:
        check_files(res, mid, man["models"][mid])
        check_entry(res, mid, man["models"][mid])
    check_sizes(res, man, sprite)
    stats = {}
    decoded = False
    if not args.no_godot:
        report = M.read_json(args.inspect) if args.inspect else run_inspect(res)
        if report is not None:
            sub = dict(man, models={mid: man["models"][mid] for mid in ids})
            stats, mesh_total, vram, src = check_decoded(res, sub, report)
            decoded = True
            res.note("Netze %.2f MB von %d MB, Texturen %.2f MB im Grafikspeicher von %d MB, Quellen %.2f MB von %d MB"
                     % (mesh_total / 1048576.0, M.MESH_BYTES_TOTAL // 1048576, vram / 1048576.0,
                        TEX_VRAM_TOTAL // 1048576, src / 1048576.0, TEX_SOURCE_TOTAL // 1048576))
    sets = man.get("sets", {})
    with_model = sum(1 for e in sets.values() if "model" in e)
    print("validate_models: %d Modelle, %d Sets (%d mit Modell, %d Platzhalter)%s"
          % (len(ids), len(sets), with_model, len(sets) - with_model, "" if decoded else " – ohne dekodierte Netze"))
    for n in res.notes:
        print("  " + n)
    if args.report and decoded:
        print_report(dict(man, models={mid: man["models"][mid] for mid in ids}), stats)
    for e in res.errors:
        print(e)
    if res.errors:
        print("CHECK models FEHLER (%d)" % len(res.errors))
        return 1
    if not decoded:
        print("CHECK models UNVOLLSTÄNDIG (Netze nicht dekodiert)")
        return 2
    print("CHECK models OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
