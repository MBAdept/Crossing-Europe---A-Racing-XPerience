#!/usr/bin/env python3
"""Exports representative assets as .glb with the real generators (spike).
Usage: bpy-python spike_export.py OUT_DIR case[,case...]"""
import json
import os
import sys
import time

REPO = "/home/user/crossing-europe---a-racing-xperience"
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import render_all as RA  # noqa: E402
from ce3d import export as EX  # noqa: E402
from cesprites import catalog  # noqa: E402
from cesprites import rig as R  # noqa: E402

CASES = {
    # name: (set id, options)
    "player_kompakt_lod0": ("player/kompakt", dict(vehicle=True)),
    "player_kompakt_lod1": ("player/kompakt", dict(vehicle=True, lod_ratio=0.25, lod_min_tris=300)),
    "player_kompakt_lod2": ("player/kompakt", dict(vehicle=True, lod_ratio=0.06, lod_min_tris=150, lod_drop_below=400,
                                                   lod_drop_size=0.12)),
    "player_kompakt_opt1": ("player/kompakt", dict(vehicle=True, planar_deg=1.0)),
    "player_kompakt_opt3": ("player/kompakt", dict(vehicle=True, planar_deg=3.0)),
    "player_kompakt_opt3c50": ("player/kompakt", dict(vehicle=True, planar_deg=3.0, lod_ratio=0.5, lod_min_tris=300)),
    "player_kompakt_opt5c25": ("player/kompakt", dict(vehicle=True, planar_deg=5.0, lod_ratio=0.25, lod_min_tris=200,
                                                      planar_wheels=True)),
    "player_kompakt_c06": ("player/kompakt", dict(vehicle=True, planar_deg=8.0, lod_ratio=0.12, lod_min_tris=100,
                                                  planar_wheels=True, lod_drop_below=300, lod_drop_size=0.10)),
    "player_kompakt_d1": ("player/kompakt", dict(vehicle=True, detail=dict(ring=0.6, step=2.0, res=2.0, off=1.5, wheel=0.75))),
    "player_kompakt_d2": ("player/kompakt", dict(vehicle=True, detail=dict(ring=0.4, step=3.5, res=3.5, off=2.5, wheel=0.5))),
    "player_kompakt_d3": ("player/kompakt", dict(vehicle=True, detail=dict(ring=0.25, step=6.0, res=7.0, off=4.0, wheel=0.33))),
    "traffic_sedan_2k": ("traffic/sedan_red", dict(vehicle=True, atlas=(2048, 2048), paint_mask=True)),
    "traffic_sedan_geo": ("traffic/sedan_red", dict(vehicle=True, decal_geo=True, body_dissolve_deg=2.0, decal_res=0.016, offset_scale=1.5)),
    "traffic_sedan_geo_l1": ("traffic/sedan_red", dict(vehicle=True, decal_geo=True, body_dissolve_deg=6.0, decal_res=0.08,
                                                       offset_scale=3.0)),
    "traffic_sedan_geo_raw": ("traffic/sedan_red", dict(vehicle=True, decal_geo=True)),
    "traffic_sedan": ("traffic/sedan_red", dict(vehicle=True, atlas=(1024, 1024), paint_mask=True)),
    "traffic_truck": ("traffic/truck_white", dict(vehicle=True, atlas=(2048, 1024))),
    "traffic_bus": ("traffic/bus_white", dict(vehicle=True, atlas=(2048, 1024))),
    "police_de": ("police/de", dict(vehicle=True, atlas=(1024, 1024))),
    "building_gruenderzeit": ("props/city_german_gruenderzeit", dict(atlas=(2048, 2048), ppm_max=64.0)),
    "building_gruenderzeit_1k": ("props/city_german_gruenderzeit", dict(atlas=(1024, 1024), ppm_max=64.0)),
    "building_farmhouse": ("props/farmhouse", dict(atlas=(1024, 1024), ppm_max=64.0)),
    "tree_oak": ("props/tree_oak", dict(atlas=(512, 512))),
    "tree_spruce": ("props/tree_spruce", dict(atlas=(512, 512))),
    "landmark_michel": ("landmarks/michel", dict(atlas=(2048, 2048), ppm_max=24.0)),
    "landmark_koelner_dom": ("landmarks/koelner_dom", dict(atlas=(2048, 2048), ppm_max=24.0)),
    "landmark_eiffel": ("landmarks/eiffel_tower", dict(atlas=(2048, 2048), ppm_max=24.0, cutout=True)),
    "building_haussmann": ("props/city_paris_haussmann", dict(atlas=(2048, 2048), ppm_max=64.0, cutout=True)),
    "fuel_station": ("props/fuel_station", dict(atlas=(1024, 1024), ppm_max=96.0)),
    "streetlight": ("props/streetlight", dict(atlas=(256, 256), ppm_max=128.0)),
}


def main():
    out_dir = sys.argv[1]
    cases = sys.argv[2].split(",")
    os.makedirs(out_dir, exist_ok=True)
    sets = {s["id"]: s for s in catalog.all_sets()}
    rep_path = os.path.join(out_dir, "export_report.json")
    rep = {}
    if os.path.exists(rep_path):
        with open(rep_path) as fh:
            rep = json.load(fh)
    for cname in cases:
        sid, opts = CASES[cname]
        opts = dict(opts, name=cname)
        spec = sets[sid]
        t0 = time.time()
        rig = R.Rig(quick=True)
        info = RA.build(rig, spec)
        info.pop("car", None)
        if opts.get("detail"):
            # generator-level LOD: coarser lofts and patch grids (monkeypatched constants; no decimation)
            from cesprites import carbody as CB
            from cesprites import cardetail as CD
            from cesprites import player_cars as PC
            dt = opts["detail"]
            saved = (CB.N_UNDER, CB.N_RB, CB.N_LS, CB.N_US, CB.N_RE, CB.N_DECK, CB.N_GB, CB.N_GS, CB.N_GR, CB.N_ROOF)
            k = dt["ring"]
            CB.N_UNDER, CB.N_RB, CB.N_LS, CB.N_US, CB.N_RE, CB.N_DECK = [max(2, int(round(v * k))) for v in saved[:6]]
            CB.N_GB, CB.N_GS, CB.N_GR, CB.N_ROOF = [max(2, int(round(v * k))) for v in saved[6:]]
            orig_patch = CB.SmoothCar.patch
            orig_stations = CB.C.stations
            orig_lathe = CD._lathe_x

            def patch(self, outline, proj, mat, offset=0.0015, res=0.012, **kw):
                return orig_patch(self, outline, proj, mat, offset=offset * dt.get("off", 1.0), res=res * dt["res"], **kw)

            def stations(y0, y1, step, **kw):
                if "dense" in kw:
                    kw["dense"] = [(a, b, st * dt["step"]) for (a, b, st) in kw["dense"]]
                if "ends" in kw:
                    kw["ends"] = tuple((r, 0 if n == 0 else max(4, int(n * dt["ring"]))) for (r, n) in kw["ends"])
                return orig_stations(y0, y1, step * dt["step"], **kw)

            def lathe(bm, prof, segs, **kw):
                return orig_lathe(bm, prof, max(12, int(segs * dt.get("wheel", 1.0))), **kw)
            CB.SmoothCar.patch = patch
            CB.C.stations = stations
            CD._lathe_x = lathe
            spec2 = dict(spec)
            spec2["params"] = dict(spec["params"])
            design = dict(PC.DESIGNS[spec["params"]["design"]])
            design["g_step"] = design.get("g_step", 0.02) * dt["step"]
            saved_design = PC.DESIGNS[spec["params"]["design"]]
            PC.DESIGNS[spec["params"]["design"]] = design
            try:
                rig = R.Rig(quick=True)
                info = RA.build(rig, spec2)
                info.pop("car", None)
            finally:
                (CB.N_UNDER, CB.N_RB, CB.N_LS, CB.N_US, CB.N_RE, CB.N_DECK, CB.N_GB, CB.N_GS, CB.N_GR, CB.N_ROOF) = saved
                CB.SmoothCar.patch = orig_patch
                CB.C.stations = orig_stations
                CD._lathe_x = orig_lathe
                PC.DESIGNS[spec["params"]["design"]] = saved_design
        if opts.get("decal_geo"):
            # traffic car: rebuild with the Car object to convert its shader decals into geometry
            from ce3d import decalgeo
            from cesprites import designs, vehicles
            rig = R.Rig(quick=True)
            p_ = spec["params"]
            car = vehicles.Car(rig, designs.TRAFFIC_MODELS[p_["design"]], paint=p_["paint"], metal=p_.get("metal", 0.35),
                               name=p_["design"]).build()
            info = dict(object=car.object_size())
            dstat = decalgeo.convert(rig, car, offset_scale=opts.get("offset_scale", 1.0), res=opts.get("decal_res", 0.02),
                                     body_dissolve_deg=opts.get("body_dissolve_deg", 0.0))
            print("decal geometry:", dstat, flush=True)
        tb = time.time() - t0
        if opts.get("paint_mask") is True:
            from cesprites import materials as M
            opts["paint_mask"] = M.srgb(spec["params"]["paint"])
        st = EX.export_set(rig, spec, info, out_dir, opts)
        st["build_s"] = round(tb, 2)
        rep[cname] = st
        print("%-26s tris %7d verts %7d surfaces %2d  glb %8.1f kB  build %5.1fs export %5.1fs  %s" % (
            cname, st["tris"], st["verts"], st["draw_surfaces"], st["glb_bytes"] / 1024.0, tb, st["total_s"],
            st.get("bake", "")), flush=True)
        with open(rep_path, "w") as fh:
            json.dump(rep, fh, indent=1, default=str)


if __name__ == "__main__":
    main()
