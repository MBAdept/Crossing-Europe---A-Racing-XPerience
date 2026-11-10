"""Probe: build models with the game's procedural Blender generators and export them as glTF binary."""
import os, sys, json, time, math
REPO = "/home/user/crossing-europe---a-racing-xperience"
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import bpy
from cesprites import catalog, rig as R
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import importlib
spec_by_id = {s["id"]: s for s in catalog.all_sets()}
OUT = sys.argv[1]
ids = sys.argv[2].split(",")

def build(rig, spec):
    # same dispatch as tools/blender/render_all.py:build
    b = spec["builder"]; p = spec["params"]
    if b == "car":
        from cesprites import designs, vehicles
        d = designs.TRAFFIC_MODELS[p["design"]]
        car = vehicles.Car(rig, d, paint=p["paint"], metal=p.get("metal", 0.35), name=p["design"]).build()
        return dict(object=car.object_size())
    if b == "player":
        from cesprites import player_cars
        info = player_cars.build(rig, p); info.pop("car", None); return info
    if b == "police":
        from cesprites import police
        return police.build(rig, p)
    if b in ("truck", "bus"):
        from cesprites import heavy
        return heavy.build(rig, b, p)
    if b == "prop":
        from cesprites import props
        return props.build(rig, p)
    if b == "landmark":
        from cesprites import props_landmarks
        return props_landmarks.build(rig, p)
    raise ValueError(b)

def tree(o, depth=0, lines=None):
    lines.append("  " * depth + "%s [%s]%s" % (o.name, o.type, (" verts=%d polys=%d mats=%d mods=%s" % (len(o.data.vertices), len(o.data.polygons), len(o.data.materials), [m.type for m in o.modifiers])) if o.type == "MESH" else ""))
    for c in o.children:
        tree(c, depth + 1, lines)

def find_node(nt, kind):
    for n in nt.nodes:
        if n.bl_idname == kind:
            return n
    return None

def const_color(sock):
    """Colour of a socket: its default if unlinked, else follow simple chains to a constant."""
    seen = 0
    while sock.is_linked and seen < 8:
        n = sock.links[0].from_node
        seen += 1
        if n.bl_idname == "ShaderNodeRGB":
            return list(n.outputs[0].default_value)
        if n.bl_idname == "ShaderNodeMix":
            # take input A (base) of colour mixes
            for s in n.inputs:
                if s.identifier in ("A_Color",):
                    sock = s
                    break
            else:
                break
            continue
        if n.bl_idname in ("ShaderNodeValToRGB",):
            return list(n.color_ramp.elements[0].color)
        break
    v = sock.default_value
    try:
        return list(v)
    except TypeError:
        return [v, v, v, 1.0]

def const_value(sock, default=0.5):
    if sock.is_linked:
        n = sock.links[0].from_node
        if n.bl_idname == "ShaderNodeValue":
            return float(n.outputs[0].default_value)
        return default
    return float(sock.default_value)

def flatten_materials():
    """Replace every material by a plain Principled BSDF the glTF exporter understands."""
    report = {}
    for m in list(bpy.data.materials):
        if not m.use_nodes or m.name.startswith("FLAT_"):
            continue
        nt = m.node_tree
        p = find_node(nt, "ShaderNodeBsdfPrincipled")
        em = find_node(nt, "ShaderNodeEmission")
        tr = find_node(nt, "ShaderNodeBsdfTransparent")
        gl = find_node(nt, "ShaderNodeBsdfGlossy")
        info = dict(kind="principled" if p else ("lens" if gl or tr else "other"))
        base = [0.5, 0.5, 0.5, 1.0]; metal = 0.0; rough = 0.5; coat = 0.0; alpha = 1.0
        if p is not None:
            base = const_color(p.inputs["Base Color"])
            metal = const_value(p.inputs["Metallic"], 0.0)
            rough = const_value(p.inputs["Roughness"], 0.5)
            try:
                coat = const_value(p.inputs["Coat Weight"], 0.0)
            except KeyError:
                coat = 0.0
            if "Transmission Weight" in p.inputs and const_value(p.inputs["Transmission Weight"], 0.0) > 0.5:
                alpha = 0.35
        elif gl is not None:
            base = const_color(gl.inputs["Color"]); rough = const_value(gl.inputs["Roughness"], 0.05); alpha = 0.55
        ecol = None; estr = 0.0
        if em is not None:
            ecol = const_color(em.inputs["Color"]); estr = const_value(em.inputs["Strength"], 1.0)
        info.update(base=[round(x, 3) for x in base[:3]], metal=round(metal, 3), rough=round(rough, 3), coat=round(coat, 3), emission=ecol and [round(x, 3) for x in ecol[:3]], emission_strength=round(estr, 3), alpha=alpha)
        report[m.name] = info
        # rebuild
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        b = nt.nodes.new("ShaderNodeBsdfPrincipled")
        b.inputs["Base Color"].default_value = (base[0], base[1], base[2], 1.0)
        b.inputs["Metallic"].default_value = metal
        b.inputs["Roughness"].default_value = rough
        b.inputs["Alpha"].default_value = alpha
        try:
            b.inputs["Coat Weight"].default_value = coat
        except KeyError:
            pass
        if ecol is not None:
            b.inputs["Emission Color"].default_value = (ecol[0], ecol[1], ecol[2], 1.0)
            b.inputs["Emission Strength"].default_value = 1.0   # lights are switched by the game (emission energy)
        nt.links.new(b.outputs[0], out.inputs[0])
        if alpha < 1.0:
            try:
                m.surface_render_method = "BLENDED"
            except Exception:
                pass
    return report

summary = {}
for sid in ids:
    spec = spec_by_id[sid]
    t0 = time.time()
    rig = R.Rig(quick=True)
    info = build(rig, spec)
    t_build = time.time() - t0
    lines = []
    tree(rig.root, 0, lines)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    name = sid.replace("/", "_")
    open(os.path.join(OUT, name + "_tree.txt"), "w").write("\n".join(lines))
    # evaluated triangle count (modifiers applied)
    dg = bpy.context.evaluated_depsgraph_get()
    tris = 0
    for o in meshes:
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        o.evaluated_get(dg).to_mesh_clear()
    # remove light/camera, export everything under ROOT
    for o in list(bpy.data.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o)
    res = {}
    for variant in ("raw", "flat"):
        if variant == "flat":
            res["materials"] = flatten_materials()
        path = os.path.join(OUT, "%s_%s.glb" % (name, variant))
        t1 = time.time()
        try:
            bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True,
                                      export_materials="EXPORT", export_normals=True, export_texcoords=True,
                                      export_attributes=True, export_extras=True, export_animations=False,
                                      export_cameras=False, export_lights=False)
            res[variant] = dict(bytes=os.path.getsize(path), export_s=round(time.time() - t1, 2))
        except Exception as e:
            res[variant] = dict(error=str(e))
    summary[sid] = dict(build_s=round(t_build, 2), objects=len(meshes), triangles=tris, info={k: v for k, v in info.items() if k in ("object",)}, **res)
    print("EXPORT", sid, json.dumps({k: v for k, v in summary[sid].items() if k != "materials"}))
json.dump(summary, open(os.path.join(OUT, "export_summary.json"), "w"), indent=1, default=str)
