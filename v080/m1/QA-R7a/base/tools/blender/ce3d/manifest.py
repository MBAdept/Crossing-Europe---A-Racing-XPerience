"""Model manifest: fragments (assets/models/<group>/<name>/model.json), default sets and the merge to
assets/models/manifest.json. Pure Python (no bpy) - also used by validate_models.py.

manifest.json = {"version", "exporter", "models": {id: entry}, "sets": {sprite set id: entry}}
  models  the "model" entries of all fragments, sorted by id
  sets    assets/models/sets_default.json (one stand-in entry per sprite set except ui/*, generated from
          the sprite manifest and the colour tables of the sprite catalog), overwritten by the "sets" of
          the fragments (a model takes over its sprite sets)
The merge is deterministic; tests/unit/core/test_model_db.gd repeats it and compares.
"""
import fnmatch
import hashlib
import json
import os

from . import EXPORTER, MANIFEST_VERSION

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MODELS_DIR = os.path.join(ROOT, "assets", "models")
SPRITE_MANIFEST = os.path.join(ROOT, "assets", "sprites", "manifest.json")
DEFAULT_SETS = "sets_default.json"
GROUPS = ("player", "traffic", "police", "props", "landmarks")
CLASSES = ("vpbr", "glass", "baked", "baked_cutout", "leaves")
KINDS = ("vehicle", "heavy", "tree", "plant", "rock", "building", "landmark", "furniture")
LIGHT_ROLES = ("head", "tail", "brake", "ind_l", "ind_r", "beacon_a", "beacon_b", "lights", "marker")
TEXTURE_EXT = (".png", ".webp")

# Asset budgets (contract 4.6.9): triangles per LOD, draw calls (= surfaces of all parts) per LOD, extra
# limits. None = no limit / LOD not expected.
BUDGETS = {
    "player": dict(lod0=55000, show=120000, shadow=3000, draws=(6, None, None)),
    "car": dict(lod0=18000, lod1=6000, lod2=1200, shadow=3000, draws=(6, 1, 1)),
    "heavy": dict(lod0=25000, lod1=7000, lod2=1500, shadow=3000, draws=(None, 1, 1)),
    "police": dict(lod0=22000, lod1=6000, lod2=1200, shadow=3000, draws=(6, 1, 1)),
    "tree": dict(lod0=2500, lod1=900, draws=(2, 2, 1), cards=450),
    "plant": dict(lod0=400, lod1=120, draws=(1, 1, 1)),
    "rock": dict(lod0=1500, draws=(1, 1, 1)),
    "cliff": dict(lod0=6000, draws=(1, 1, 1)),
    "rural": dict(lod0=2000, draws=(2, 2, 2)),
    "city": dict(lod0=10000, draws=(2, 2, 2)),
    "landmark": dict(lod0=25000, draws=(2, 2, 2)),
    "furniture": dict(lod0=1500, draws=(1, 1, 1)),
    "pylon": dict(lod0=5000, draws=(1, 1, 1)),
}
# texture tiers (contract D23): longest side of the albedo per category; emission at most half of it
TEXTURE_TIER = {"city": 2048, "landmark": 2048, "rural": 1024, "tree": 1024, "plant": 1024, "rock": 1024,
                "cliff": 1024, "furniture": 1024, "pylon": 1024, "player": 1024, "car": 1024, "heavy": 2048,
                "police": 1024}
MESH_BYTES_TOTAL = 40 * 1024 * 1024


def category(model_id, model):
    """Budget category of a model."""
    kind = model.get("kind", "")
    tags = model.get("tags", [])
    group = model_id.split("/")[0]
    if kind == "vehicle":
        return "player" if group == "player" else ("police" if group == "police" else "car")
    if kind == "heavy":
        return "heavy"
    if kind == "building":
        return "city" if "city" in tags else "rural"
    if kind == "rock":
        return "cliff" if "cliff" in model_id else "rock"
    if kind == "furniture":
        return "pylon" if "pylon" in model_id else "furniture"
    return kind


# --- JSON ------------------------------------------------------------------------------------------------

def dumps(v, ind=0):
    """JSON with one-space indentation; lists of scalars and small dicts of scalars stay on one line
    (same layout as the sprite manifest)."""
    pad = " " * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        if all(not isinstance(x, (dict, list)) for x in v.values()) and len(v) <= 6:
            return json.dumps(v, ensure_ascii=False)
        items = [pad + " " + json.dumps(k, ensure_ascii=False) + ": " + dumps(x, ind + 1) for k, x in v.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return json.dumps(v, ensure_ascii=False)
        items = [pad + " " + dumps(x, ind + 1) for x in v]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    return json.dumps(v, ensure_ascii=False)


def write_json(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(dumps(data))
        fh.write("\n")
    os.replace(tmp, path)


def read_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


# --- files -----------------------------------------------------------------------------------------------

def model_files(folder):
    """Files of a model folder that belong to its hash: meshes and texture sources (not model.json, not
    the .import files)."""
    out = []
    for f in sorted(os.listdir(folder)):
        if f.endswith(".res") or f.endswith(TEXTURE_EXT):
            out.append(f)
    return out


def files_hash(folder, files=None):
    """(sha1 hex, total bytes) of the model files - the same rule as tools/models/bake_models.gd."""
    h = hashlib.sha1()
    total = 0
    for f in (files if files is not None else model_files(folder)):
        with open(os.path.join(folder, f), "rb") as fh:
            data = fh.read()
        total += len(data)
        h.update((f + "\n").encode("utf-8"))
        h.update(data)
    return h.hexdigest(), total


def fragment_ids(models_dir=MODELS_DIR):
    out = []
    for group in sorted(os.listdir(models_dir)) if os.path.isdir(models_dir) else []:
        gdir = os.path.join(models_dir, group)
        if not os.path.isdir(gdir):
            continue
        for name in sorted(os.listdir(gdir)):
            if os.path.exists(os.path.join(gdir, name, "model.json")):
                out.append(group + "/" + name)
    return out


# --- default sets ------------------------------------------------------------------------------------------

def default_sets(sprite_manifest=None):
    """Stand-in entry of every sprite set except ui/*: vehicles -> {"fallback": "box"} (their sprite sheets
    are not loaded in Modern), everything else -> {"fallback": "sprite"} (billboard of the Arcade sprite).
    Carries the object size of the sprite manifest and, for vehicles, the paint of the sprite catalog."""
    from cesprites import catalog     # colour tables only: no bpy needed
    sm = sprite_manifest or read_json(SPRITE_MANIFEST)
    paints = {}
    for vid, (col, metal) in catalog.PLAYER_COLORS.items():
        paints["player/" + vid] = {"paint": col, "metal": metal}
    for model, colours in catalog.TRAFFIC_COLORS.items():
        for cname, hexcol in colours:
            paints["traffic/%s_%s" % (model, cname)] = {"paint": hexcol, "metal": catalog.METALLIC.get(cname, 0.35)}
    for cc, p in catalog.POLICE.items():
        paints["police/" + cc] = {"paint": p["body"], "paint2": p["c1"], "paint3": p["c2"], "metal": p.get("metal", 0.3)}
    out = {}
    for sid in sorted(sm["sets"]):
        s = sm["sets"][sid]
        group = sid.split("/")[0]
        if group == "ui":
            continue
        vehicle = group in ("player", "traffic", "police") or s.get("render") == "box"
        e = {"fallback": "box" if vehicle else "sprite"}
        if s.get("object"):
            e["object"] = s["object"]
        if sid in paints:
            e["paint"] = paints[sid]
        out[sid] = e
    return out


def write_default_sets(models_dir=MODELS_DIR):
    path = os.path.join(models_dir, DEFAULT_SETS)
    os.makedirs(models_dir, exist_ok=True)
    write_json(path, {"version": MANIFEST_VERSION, "sets": default_sets()})
    return path


# --- merge ---------------------------------------------------------------------------------------------------

def merge(models_dir=MODELS_DIR):
    """manifest dict from the default sets and all fragments (sorted by model id)."""
    defaults = read_json(os.path.join(models_dir, DEFAULT_SETS))["sets"]
    models = {}
    sets = dict(defaults)
    for mid in fragment_ids(models_dir):
        frag = read_json(os.path.join(models_dir, mid, "model.json"))
        models[mid] = frag["model"]
        for sid, e in frag.get("sets", {}).items():
            sets[sid] = e
    return {"version": MANIFEST_VERSION, "exporter": EXPORTER, "models": models,
            "sets": {k: sets[k] for k in sorted(sets)}}


def write_manifest(models_dir=MODELS_DIR):
    path = os.path.join(models_dir, "manifest.json")
    write_json(path, merge(models_dir))
    return path


def match(model_id, pattern):
    return fnmatch.fnmatchcase(model_id, pattern or "*")
