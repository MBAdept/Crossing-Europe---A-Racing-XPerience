#!/usr/bin/env python3
"""Bake anti-aliasing test: farmhouse (brick shader) at 1024^2 with 1 and 8 samples; times + crops."""
import os, sys, time
REPO = "/home/user/crossing-europe---a-racing-xperience"
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
import render_all as RA
from ce3d import bake as BK, core, export as EX
from cesprites import catalog, rig as R
out = sys.argv[1]
spec = {s["id"]: s for s in catalog.all_sets()}["props/farmhouse"]
for samples, size in ((16, 2048), (16, 4096)):
    rig = R.Rig(quick=True)
    RA.build(rig, spec)
    objs = core.model_objects(rig)
    BK.realize_in_place(objs)
    names = set()
    for ob in objs:
        for s in ob.material_slots:
            if s.material and core.mat_info(s.material)["cls"] in ("mask", "proc"):
                names.add(s.material.name)
    bobjs = [o for o in objs if any(s.material and s.material.name in names for s in o.material_slots)]
    charts = BK.box_unwrap(bobjs, lambda m: m is not None and m.name in names)
    ppm = BK.pack(charts, (size, size), ppm_max=256.0, gutter=3 * size // 1024)
    BK.write_uvs(charts, (size, size))
    bk = BK.Baker(rig, bobjs, [bpy.data.materials[k] for k in sorted(names)], (size, size))
    rig.scene.cycles.samples = samples
    t0 = time.time()
    alb = bk.bake_input("Base Color")
    dt = time.time() - t0
    data, im = BK.to_png_bytes(alb, linear_to_srgb=True)
    from PIL import Image
    im = im.resize((1024, 1024), Image.LANCZOS)
    im.save(os.path.join(out, "farmhouse_albedo_ss%d.png" % size))
    print("samples", samples, "ppm %.1f" % ppm, "bake_s %.1f" % dt, "png", len(data), flush=True)
