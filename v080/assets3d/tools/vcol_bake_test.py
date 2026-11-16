#!/usr/bin/env python3
"""Feasibility: bake procedural base colour / emission to VERTEX COLOURS (lattice assets where an atlas
gets only 2.4 px/m because of thousands of tiny charts). Asset: landmarks/eiffel_tower."""
import os, sys, time
REPO = "/home/user/crossing-europe---a-racing-xperience"
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
import render_all as RA
from ce3d import bake as BK, core
from cesprites import catalog, materials as M, rig as R
spec = {s["id"]: s for s in catalog.all_sets()}[sys.argv[1] if len(sys.argv) > 1 else "landmarks/eiffel_tower"]
rig = R.Rig(quick=True)
RA.build(rig, spec)
objs = core.model_objects(rig)
BK.realize_in_place(objs)
sc = rig.scene
sc.cycles.samples = 1
sc.cycles.use_denoising = False
sc.render.bake.target = "VERTEX_COLORS"
for ob in objs:
    me = ob.data
    ca = me.color_attributes.new("ce_col", "BYTE_COLOR", "CORNER")
    me.color_attributes.active_color = ca
for o in bpy.context.view_layer.objects:
    o.select_set(False)
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
res = {}
for layer in ("base", "lights"):
    M.set_pass(layer)
    undo = []
    if layer == "base":
        # base colour through a temporary emission
        for m in {s.material for o in objs for s in o.material_slots if s.material}:
            nt = m.node_tree
            out = [n for n in nt.nodes if n.bl_idname == "ShaderNodeOutputMaterial"][0]
            bs = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"]
            if not bs or not out.inputs["Surface"].is_linked:
                continue
            old = out.inputs["Surface"].links[0].from_socket
            em = nt.nodes.new("ShaderNodeEmission")
            inp = bs[0].inputs["Base Color"]
            if inp.is_linked:
                nt.links.new(inp.links[0].from_socket, em.inputs["Color"])
            else:
                em.inputs["Color"].default_value = tuple(inp.default_value)
            nt.links.new(em.outputs[0], out.inputs["Surface"])
            undo.append((nt, out, old, em))
    t0 = time.time()
    bpy.ops.object.bake(type="EMIT")
    dt = time.time() - t0
    for nt, out, old, em in undo:
        nt.links.new(old, out.inputs["Surface"])
        nt.nodes.remove(em)
    cols = []
    for ob in objs:
        ca = ob.data.color_attributes["ce_col"]
        a = np.empty(len(ca.data) * 4, dtype=np.float32)
        ca.data.foreach_get("color", a)
        cols.append(a.reshape(-1, 4)[:, :3])
    c = np.concatenate(cols)
    res[layer] = (dt, c.mean(axis=0), c.std(axis=0), len(c))
    print("vertex-colour bake", layer, "%.1f s" % dt, "corners", len(c), "mean", np.round(c.mean(axis=0), 3), "std", np.round(c.std(axis=0), 3), flush=True)
