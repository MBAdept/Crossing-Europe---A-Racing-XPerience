#!/usr/bin/env python3
"""Regression check of the sprite geometry (docs/modelle.md, "Sprite-Geometrie bleibt unverändert").

The 3D pipeline (tools/blender/ce3d) adds hooks to the generators in cesprites. The defaults of every
hook must reproduce the sprite models of v0.7.0 exactly - the sprites are not rendered again. This tool
builds every sprite set of the catalog (no rendering) and compares it with the fixture
tools/blender/fixtures/geometry_v070.json, which was written from tag v0.7.0 before the first hook:

  objects, verts, polys, tris   counts of the evaluated meshes (modifiers applied)
  bbox      bounding box in root space (0.1 mm)
  pos       hash of all vertex positions (exact float32 values, objects sorted by name)
  qpos      the same with positions rounded to 0.01 mm (tells float noise from a moved vertex)
  topo      hash of polygons, material indices, smooth flags, corner normals (1e-4) and object flags
  mats      hash of the materials (node trees with all values and links)
  info      hash of what the builder returns for the manifest (object size, box parts, lights)

Usage (from the repository root):
  /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py [--only PREFIX[,PREFIX..]]
        [--jobs 2] [--write] [--fixture PATH] [--verbose]

  --only     check only sets whose id starts with one of the prefixes
  --jobs     worker processes (default 2, at most 2; every worker is a separate Blender instance)
  --write    write the fixture instead of comparing (only on the untouched generators of a release tag)
Exit code 0 = every set identical, 1 = differences or build errors.
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
FIXTURE = os.path.join(HERE, "fixtures", "geometry_v070.json")
FIELDS = ("objects", "verts", "polys", "tris", "bbox", "pos", "qpos", "topo", "mats", "info")
# rough build cost per builder (seconds, measured on the 4-core VM) - only used to balance the workers
COST = {"player": 22.0, "car": 2.5, "police": 3.0, "truck": 3.0, "bus": 4.5, "prop": 3.0, "landmark": 5.0, "icon": 0.3}


# --- worker: build and measure (needs bpy) ------------------------------------------------------------

def _num(v):
    """Stable text of a number / vector / colour (float32 precision of Blender's data)."""
    if isinstance(v, bool):
        return "T" if v else "F"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return "%.7g" % v
    if isinstance(v, str):
        return "s:" + v
    try:
        return "(" + ",".join(_num(x) for x in v) + ")"
    except TypeError:
        return type(v).__name__


_NODE_PROPS = ("operation", "blend_type", "data_type", "use_clamp", "clamp", "feature", "distance", "noise_dimensions",
               "noise_type", "normalize", "offset", "offset_frequency", "squash", "squash_frequency", "interpolation_type",
               "invert", "space", "vector_type", "mode", "distribution", "subsurface_method", "factor_mode",
               "clamp_factor", "clamp_result", "from_instancer", "label")


def _tree_sig(nt, seen):
    """Text signature of a node tree: nodes (type, properties, default values) and links, in node order."""
    out = []
    index = {n.name: i for i, n in enumerate(nt.nodes)}
    for n in nt.nodes:
        row = [n.bl_idname]
        for p in _NODE_PROPS:
            if hasattr(n, p):
                try:
                    row.append("%s=%s" % (p, _num(getattr(n, p))))
                except Exception:
                    pass
        if n.bl_idname == "ShaderNodeValToRGB":
            cr = n.color_ramp
            row.append("ramp=%s/%s/" % (cr.interpolation, cr.color_mode) + ";".join(
                "%s:%s" % (_num(e.position), _num(tuple(e.color))) for e in cr.elements))
        if n.bl_idname == "ShaderNodeGroup" and n.node_tree is not None:
            row.append("group=" + n.node_tree.name)
            # the values inside CE_PASS are render state (materials.set_pass), not part of the model
            if n.node_tree.name not in seen and not n.node_tree.name.startswith("CE_PASS"):
                seen.add(n.node_tree.name)
                row.append("{" + _tree_sig(n.node_tree, seen) + "}")
        for s in n.inputs:
            if hasattr(s, "default_value") and not s.is_linked:
                row.append("i:%s=%s" % (s.identifier, _num(s.default_value)))
        for s in n.outputs:
            if hasattr(s, "default_value") and n.bl_idname in ("ShaderNodeValue", "ShaderNodeRGB"):
                row.append("o:%s=%s" % (s.identifier, _num(s.default_value)))
        out.append("|".join(row))
    for l in nt.links:
        out.append("L %d.%s>%d.%s" % (index[l.from_node.name], l.from_socket.identifier, index[l.to_node.name],
                                      l.to_socket.identifier))
    return "\n".join(out)


def measure(rig, info):
    """Geometry record of the model that hangs on rig.root."""
    import bpy
    import numpy as np
    rig.root.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    obs = [o for o in rig.root.children_recursive if o.type in ("MESH", "CURVE", "FONT", "SURFACE")]
    obs.sort(key=lambda o: o.name)
    h_pos, h_q, h_topo, h_mat = hashlib.sha1(), hashlib.sha1(), hashlib.sha1(), hashlib.sha1()
    nv = npoly = ntri = 0
    lo = np.full(3, 1e30)
    hi = np.full(3, -1e30)
    mats = {}
    for ob in obs:
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        n = len(me.vertices)
        co = np.empty(n * 3, dtype=np.float32)
        me.vertices.foreach_get("co", co)
        mw = np.array(ob.matrix_world, dtype=np.float64)
        wp = co.reshape(-1, 3).astype(np.float64) @ mw[:3, :3].T + mw[:3, 3]
        h_pos.update(ob.name.encode("utf-8"))
        h_pos.update(wp.astype(np.float32).tobytes())
        h_q.update(ob.name.encode("utf-8"))
        h_q.update(np.round(wp * 1e5).astype(np.int64).tobytes())
        if n:
            lo = np.minimum(lo, wp.min(axis=0))
            hi = np.maximum(hi, wp.max(axis=0))
        nl = len(me.loops)
        lv = np.empty(nl, dtype=np.int32)
        me.loops.foreach_get("vertex_index", lv)
        npo = len(me.polygons)
        ls = np.empty(npo, dtype=np.int32)
        me.polygons.foreach_get("loop_start", ls)
        mi = np.empty(npo, dtype=np.int32)
        me.polygons.foreach_get("material_index", mi)
        sm = np.empty(npo, dtype=bool)
        me.polygons.foreach_get("use_smooth", sm)
        cn = np.empty(nl * 3, dtype=np.float32)
        me.corner_normals.foreach_get("vector", cn)
        me.calc_loop_triangles()
        flags = "%s|%s|%d|%d|%d|%s" % (ob.name, ob.type, int(ob.hide_render), int(ob.visible_shadow),
                                       int(ob.is_shadow_catcher), ob.parent.name if ob.parent else "")
        h_topo.update(flags.encode("utf-8"))
        for a in (lv, ls, mi, sm.astype(np.int8), np.round(cn.astype(np.float64) * 1e4).astype(np.int32)):
            h_topo.update(a.tobytes())
        h_topo.update(",".join(s.material.name if s.material else "-" for s in ob.material_slots).encode("utf-8"))
        nv += n
        npoly += npo
        ntri += len(me.loop_triangles)
        ev.to_mesh_clear()
        for s in ob.material_slots:
            if s.material is not None:
                mats[s.material.name] = s.material
    seen = set()
    for name in sorted(mats):
        m = mats[name]
        h_mat.update(name.encode("utf-8"))
        if m.node_tree is not None:
            h_mat.update(_tree_sig(m.node_tree, seen).encode("utf-8"))
    if not nv:
        lo[:] = 0.0
        hi[:] = 0.0
    clean = _plain(info)
    return dict(objects=len(obs), verts=int(nv), polys=int(npoly), tris=int(ntri),
                bbox=[round(float(v), 4) + 0.0 for v in list(lo) + list(hi)],
                pos=h_pos.hexdigest()[:20], qpos=h_q.hexdigest()[:20], topo=h_topo.hexdigest()[:20],
                mats=h_mat.hexdigest()[:20],
                info=hashlib.sha1(json.dumps(clean, sort_keys=True).encode("utf-8")).hexdigest()[:20])


def _plain(v):
    """Builder info without Blender objects (box parts keep their extents and faces)."""
    if isinstance(v, dict):
        return {str(k): _plain(x) for k, x in v.items() if k not in ("objects", "car")}
    if isinstance(v, (list, tuple)):
        return [_plain(x) for x in v]
    if isinstance(v, float):
        return round(v, 6)
    if isinstance(v, (int, str, bool)) or v is None:
        return v
    return type(v).__name__


def worker(ids_file, out_file):
    import render_all as RA
    from cesprites import catalog
    from cesprites import rig as R
    with open(ids_file) as fh:
        ids = json.load(fh)
    sets = {s["id"]: s for s in catalog.all_sets()}
    res = {}
    for sid in ids:
        t0 = time.time()
        try:
            rig = R.Rig(quick=True)
            info = RA.build(rig, sets[sid])
            rec = measure(rig, info)
        except Exception as e:  # noqa
            import traceback
            traceback.print_exc()
            rec = dict(error="%s: %s" % (type(e).__name__, e))
        rec["s"] = round(time.time() - t0, 2)
        res[sid] = rec
        print("  %-40s %6.1f s" % (sid, rec["s"]), flush=True)
        with open(out_file, "w") as fh:
            json.dump(res, fh)


# --- main: distribute, compare ---------------------------------------------------------------------------

def catalog_ids():
    """Set ids and builders of the catalog; the catalog needs bpy (the prop modules import bmesh), so a
    Blender process is asked for it."""
    code = ("import sys, json; sys.path.insert(0, %r); import bpy; from cesprites import catalog; "
            "print('IDS' + json.dumps([[s['id'], s['builder']] for s in catalog.all_sets()]))" % HERE)
    out = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True)
    for line in out.stdout.splitlines():
        if line.startswith("IDS"):
            return json.loads(line[3:])
    raise SystemExit("Katalog nicht lesbar:\n" + out.stdout + out.stderr)


def run_builds(items, jobs, verbose):
    jobs = max(1, min(jobs, len(items)))
    chunks = [[] for _ in range(jobs)]
    load = [0.0] * jobs
    for sid, builder in sorted(items, key=lambda it: -COST.get(it[1], 3.0)):
        k = load.index(min(load))
        chunks[k].append(sid)
        load[k] += COST.get(builder, 3.0)
    tmp = tempfile.mkdtemp(prefix="ce_geo_")
    procs = []
    for k, ids in enumerate(chunks):
        idf = os.path.join(tmp, "ids%d.json" % k)
        outf = os.path.join(tmp, "out%d.json" % k)
        with open(idf, "w") as fh:
            json.dump(ids, fh)
        cmd = ["nice", "-n", "10", sys.executable, os.path.abspath(__file__), "--worker", idf, outf]
        procs.append((subprocess.Popen(cmd, stdout=None if verbose else subprocess.DEVNULL,
                                       stderr=None if verbose else subprocess.DEVNULL), outf))
    res = {}
    for p, outf in procs:
        p.wait()
        if os.path.exists(outf):
            with open(outf) as fh:
                res.update(json.load(fh))
    return res


def write_fixture(path, sets):
    """One line per set: stable text, small diffs."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write('{\n "version": 1,\n "source": "tag v0.7.0 (cesprites before the first 3D hook)",\n "fields": %s,\n'
                 ' "sets": {\n' % json.dumps(list(FIELDS)))
        fh.write(",\n".join("  %s: %s" % (json.dumps(k), json.dumps(sets[k])) for k in sorted(sets)))
        fh.write("\n }\n}\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default="")
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--fixture", default=FIXTURE)
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--worker", nargs=2, metavar=("IDS", "OUT"))
    args = ap.parse_args()
    if args.worker:
        worker(*args.worker)
        return
    items = catalog_ids()
    if args.only:
        pre = [p for p in args.only.split(",") if p]
        items = [it for it in items if any(it[0].startswith(p) for p in pre)]
    t0 = time.time()
    res = run_builds(items, min(args.jobs, 2), args.verbose)
    dt = time.time() - t0
    errors = [sid for sid, _b in items if "error" in res.get(sid, {"error": "kein Ergebnis"})]
    if args.write:
        if errors:
            print("FEHLER beim Bauen:", ", ".join(errors))
            sys.exit(1)
        sets = {}
        if args.only and os.path.exists(args.fixture):
            with open(args.fixture, encoding="utf-8") as fh:
                sets.update(json.load(fh).get("sets", {}))
        for sid, _b in items:
            sets[sid] = [res[sid][f] for f in FIELDS]
        write_fixture(args.fixture, sets)
        print("Fixture geschrieben: %s (%d Sets gebaut in %.0f s, %.0f s Rechenzeit)" % (
            os.path.relpath(args.fixture), len(items), dt, sum(r.get("s", 0.0) for r in res.values())))
        return
    with open(args.fixture, encoding="utf-8") as fh:
        fx = json.load(fh)
    fields = fx["fields"]
    bad = 0
    noise = 0
    for sid, _b in items:
        r = res.get(sid)
        if r is None or "error" in r:
            print("FEHLER   %-40s %s" % (sid, (r or {}).get("error", "kein Ergebnis")))
            bad += 1
            continue
        want = fx["sets"].get(sid)
        if want is None:
            print("NEU      %-40s nicht in der Fixture (Sprite-Sets ändern sich in v0.8.0 nicht)" % sid)
            bad += 1
            continue
        w = dict(zip(fields, want))
        diff = [f for f in fields if r.get(f) != w.get(f)]
        if not diff:
            continue
        if diff == ["pos"]:
            # same vertices within 0.01 mm, same counts, topology, normals and materials: float noise only
            noise += 1
            print("RAUSCHEN %-40s Positionen innerhalb 0,01 mm gleich, aber nicht bitgleich" % sid)
            continue
        bad += 1
        print("ANDERS   %-40s geändert: %s" % (sid, ", ".join(diff)))
        for f in diff:
            if f in ("objects", "verts", "polys", "tris", "bbox"):
                print("           %-8s %s -> %s" % (f, w.get(f), r.get(f)))
    missing = [] if args.only else sorted(set(fx["sets"]) - {it[0] for it in items})
    for sid in missing:
        print("FEHLT    %-40s steht in der Fixture, aber nicht mehr im Katalog" % sid)
    n = len(items)
    print("%d Sprite-Sets gebaut in %.0f s: %d identisch, %d nur Fließkomma-Rauschen, %d verändert, %d fehlen" % (
        n, dt, n - bad - noise, noise, bad, len(missing)))
    ok = bad == 0 and noise == 0 and not missing
    print("CHECK sprite_geometry %s" % ("OK" if ok else "FEHLER"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
