#!/usr/bin/env python3
"""Exports the real-time models of the mode "Modern" from the procedural generators (docs/modelle.md).

Step 1 - export: generators -> own GLB writer -> intermediates (never committed):
  /home/user/tools/bpyenv/bin/python tools/blender/export_models.py [--only=<glob>] [--force] [--jobs=2] [--list]
      -> tools/blender/_cache3d/<group>/<name>/{model.glb, model_meta.json, *.png|*.webp}
Step 2 - bake (headless Godot):
  godot --headless --path . -s res://tools/models/bake_models.gd -- [--only=<glob>]
      -> assets/models/<group>/<name>/{*.res, model.json, textures (+ .import)}
  godot --headless --path . --import                                       (imports new textures)
Step 3 - manifest:
  /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only
      -> assets/models/manifest.json (merge of all model.json fragments over assets/models/sets_default.json)
Step 4 - check and look:
  python3 tools/blender/validate_models.py
  tools/models_contact_sheet.sh <out.png> [--only=<glob>] [--night]

  --only=<glob>    models whose id matches (e.g. "traffic/*", "props/tree_*"); default all
  --force          ignore the cache
  --jobs=N         worker processes, 1 or 2 (every worker is a separate Blender instance)
  --list           print the model ids and exit
  --manifest-only  only step 3 (works with plain python3, no Blender needed)
  --defaults       rewrite assets/models/sets_default.json from the sprite manifest and the sprite catalog
  --check-keys     self-test of the cache key: a changed paint, tag or view angle in the sprite catalog gives
                   the models that read it a new key (prints "CHECK cache_keys OK|FEHLER"; needs Blender)
A model is exported again when its cache key changes: hash of builder code + parameters + exporter version
(ce3d.catalog3d.cache_key: code files, the catalog entry, the resolved sprite sets and colour tables it reads).
The model folders of the cache hold only what depends on the model - two exports give byte-equal folders.
Timings and counts of the last export of every model are in _cache3d/export_report.json (next to
bake_report.json of the bake): compare two caches with  diff -r -x '*_report.json' <a> <b>.
"""
import argparse
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
CACHE = os.path.join(HERE, "_cache3d")
# rough export cost per builder (s) - only used to balance two workers
COST = {"player": 150.0, "car": 40.0, "heavy": 30.0, "tree": 30.0, "prop_vpbr": 3.0, "prop_baked": 120.0}


BUILDERS = {"prop_vpbr": ("ce3d.props3d", "build_vpbr"), "prop_baked": ("ce3d.props3d", "build_baked"),
            "tree": ("ce3d.veg3d", "build_tree"), "car": ("ce3d.traffic3d", "build_car"),
            "player": ("ce3d.vehicles3d", "build_player"), "heavy": ("ce3d.truck3d", "build_truck")}
# AS1b (wave 2): bushes and ground cover (docs/modelle.md section 14)
BUILDERS.update({"bush": ("ce3d.veg3d", "build_bush"), "grass": ("ce3d.veg3d", "build_grass")})
COST.update({"bush": 8.0, "grass": 2.0})


def builder(name):
    import importlib
    mod, fn = BUILDERS[name]
    return getattr(importlib.import_module(mod), fn)


def ensure_cache():
    os.makedirs(CACHE, exist_ok=True)
    gi = os.path.join(CACHE, ".gitignore")
    if not os.path.exists(gi):
        with open(gi, "w") as fh:
            fh.write("# intermediates of tools/blender/export_models.py - never committed\n*\n")
    gd = os.path.join(CACHE, ".gdignore")
    if not os.path.exists(gd):
        # Godot must not import the intermediates (it would turn every model.glb into a scene)
        with open(gd, "w") as fh:
            fh.write("")


def worker(ids, force, report_path=""):
    import bpy  # noqa: F401  (registers bmesh / mathutils for the generator modules)

    from ce3d import catalog3d
    from ce3d import manifest as MF
    failed = 0
    report = {}
    for mid in ids:
        spec = catalog3d.MODELS[mid]
        out_dir = os.path.join(CACHE, mid)
        key = catalog3d.cache_key(mid)
        meta_path = os.path.join(out_dir, "model_meta.json")
        if not force and os.path.exists(meta_path):
            try:
                if MF.read_json(meta_path).get("key") == key:
                    print("EXPORT %-28s aus dem Cache" % mid, flush=True)
                    continue
            except ValueError:
                pass
        t0 = time.time()
        try:
            model = builder(spec["builder"])(mid, spec)
            meta = model.write(out_dir, key)
            model.stats["export_s"] = round(time.time() - t0, 2)
            report[mid] = dict(model.stats, key=key)
        except Exception:
            import traceback
            traceback.print_exc()
            failed += 1
            print("EXPORT %-28s FEHLER" % mid, flush=True)
            continue
        lods = ", ".join("%s %d" % (l["name"], l["tris"]) for l in meta["model"]["lods"])
        print("EXPORT %-28s %6.1f s  %s  glb %.0f kB" % (mid, time.time() - t0, lods, meta["glb_bytes"] / 1024.0),
              flush=True)
    if report_path:
        MF.write_json(report_path, report)
    sys.exit(1 if failed else 0)


def check_keys():
    import bpy  # noqa: F401

    from ce3d import catalog3d
    problems = catalog3d.check_keys()
    for p in problems:
        print("  " + p)
    print("CHECK cache_keys %s  %d Modelle: ein geänderter Lack, Metallwert, Blickwinkel oder eine Markierung im "
          "Sprite-Katalog ergibt für genau die betroffenen Modelle einen neuen Schlüssel" % (
              "OK    " if not problems else "FEHLER", len(catalog3d.MODELS)))
    sys.exit(1 if problems else 0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default="*")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--manifest-only", action="store_true")
    ap.add_argument("--defaults", action="store_true")
    ap.add_argument("--check-keys", action="store_true")
    ap.add_argument("--worker", default="")
    ap.add_argument("--report", default="")
    args = ap.parse_args()
    if args.worker:
        worker([i for i in args.worker.split(",") if i], args.force, args.report)
        return
    if args.check_keys:
        check_keys()
        return
    from ce3d import catalog3d
    from ce3d import manifest as MF
    if args.list:
        for mid in catalog3d.model_ids():
            s = catalog3d.MODELS[mid]
            print("%-28s %-10s %s" % (mid, s["builder"], s["source"]))
        print(len(catalog3d.MODELS), "Modelle")
        return
    if args.defaults or (args.manifest_only and not os.path.exists(os.path.join(MF.MODELS_DIR, MF.DEFAULT_SETS))):
        print("geschrieben:", os.path.relpath(MF.write_default_sets()))
        if not args.manifest_only:
            return
    if args.manifest_only:
        path = MF.write_manifest()
        m = MF.read_json(path)
        n_model = sum(1 for e in m["sets"].values() if "model" in e)
        print("geschrieben: %s (%d Modelle, %d Sets: %d mit Modell, %d Platzhalter)" % (
            os.path.relpath(path), len(m["models"]), len(m["sets"]), n_model, len(m["sets"]) - n_model))
        return
    ids = [m for m in catalog3d.model_ids() if MF.match(m, args.only)]
    if not ids:
        print("kein Modell passt auf", args.only)
        sys.exit(1)
    ensure_cache()
    jobs = max(1, min(2, args.jobs, len(ids)))
    chunks = [[] for _ in range(jobs)]
    load = [0.0] * jobs
    for mid in sorted(ids, key=lambda m: (-COST.get(catalog3d.MODELS[m]["builder"], 30.0), m)):
        k = load.index(min(load))
        chunks[k].append(mid)
        load[k] += COST.get(catalog3d.MODELS[mid]["builder"], 30.0)
    env = dict(os.environ)
    env.setdefault("CE_THREADS", "2" if jobs > 1 else "3")
    t0 = time.time()
    procs = []
    parts = []
    for i, ch in enumerate(chunks):
        part = os.path.join(CACHE, ".export_report_%d.json" % i)
        if os.path.exists(part):
            os.remove(part)
        parts.append(part)
        cmd = ["nice", "-n", "10", sys.executable, os.path.abspath(__file__), "--worker", ",".join(ch), "--report", part]
        if args.force:
            cmd.append("--force")
        procs.append(subprocess.Popen(cmd, env=env))
    code = 0
    for p in procs:
        code |= p.wait()
    # timings and counts of this run (never part of the model folders): the exported models replace their entries
    report_path = os.path.join(CACHE, "export_report.json")
    report = MF.read_json(report_path) if os.path.exists(report_path) else {}
    for part in parts:
        if os.path.exists(part):
            report.update(MF.read_json(part))
            os.remove(part)
    MF.write_json(report_path, {k: report[k] for k in sorted(report)})
    print("Export: %d Modelle in %.0f s%s" % (len(ids), time.time() - t0, " - mit FEHLERN" if code else ""))
    if not code:
        print("weiter mit: godot --headless --path . -s res://tools/models/bake_models.gd -- --only=%s" % args.only)
    sys.exit(1 if code else 0)


if __name__ == "__main__":
    main()
