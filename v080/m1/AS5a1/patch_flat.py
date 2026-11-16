p = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1/tools/blender/ce3d/cities3d.py'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


# 1) build_city: flat lod1 -> no far ring, cutter geometry that the flat wall covers only in lod0
rep('''    opt = dict(spec3d.get("openings") or {})
    record = []
    if spec3d.get("openings", True) is not False:
        record = cut_openings(rig, objs, log, opt, geo, mats, stats)''',
    '''    opt = dict(spec3d.get("openings") or {})
    flat = bool(spec3d.get("lod1_flat", True)) and bool(spec3d.get("lod1"))
    if flat:
        opt.setdefault("far_ring", False)
    record = []
    if spec3d.get("openings", True) is not False:
        record = cut_openings(rig, objs, log, opt, geo, mats, stats)
    if flat:
        stats["lod0_only_parts"] = _lod0_only(geo, FLAT_LOD0_PREFIXES)''')

# 2) helper + constant
rep('''# --- far walls: the texels of the opposite wall ------------------------------------------------------------------''',
    '''# --- the flat lod1 ---------------------------------------------------------------------------------------------------
#
# lod1 of a city building (from the props builder's first switch distance on: 60 m at "Details: Mittel", and the level
# of everything farther away - there is no impostor) is the cut wall flattened again: a copy of every cut wall object,
# its coplanar faces dissolved back into the generator's wall polygons, with the atlas coordinates of the cut wall (the
# hole fillers baked the sprite's window into the atlas: glass, glazing bars, curtains, blinds by day, its light at
# night). No reveals, frames, bars or sills in lod1: at 60 m and more they are under a pixel and only shimmer (AS4R:
# block B at 120 m 1.0 % against the sprite's 0.2 %), and a window-rich facade (the Speicher: 143 openings) spends
# 10,000 triangles on them. lod1 keeps silhouette, storeys, roofs, cornices, dormers and the window rhythm of the sprite.

FLAT_LOD0_PREFIXES = ("ce_reveal", "ce_shop_reveal", "ce_door_", "ce_louvre_")


def _lod0_only(geo, prefixes):
    """Cutter geometry that the flat lod1 wall covers (reveals, door wings, louvres) moves to level lod0."""
    n = 0
    for key in sorted(list(geo.tris)):
        name, level = key
        if level == "both" and any(name.startswith(p) for p in prefixes):
            mat, tris = geo.tris.pop(key)
            geo.tris.setdefault((name, "lod0"), (mat, []))[1].extend(tris)
            n += len(tris)
    return n


def _flat_copies(objs):
    """lod1 copies of the cut walls (objects with a filler, pane or display material), their coplanar faces dissolved
    (delimit UV: one chart stays one polygon), the atlas coordinates kept; the originals become lod0. Called after the
    packing (the atlas coordinates exist) and before the panes are moved back. Returns the copies."""
    import bmesh
    import bpy
    out = []
    for ob in objs:
        if H._level(ob) != "both":
            continue
        if not any(s.material is not None and s.material.get("ce_filler") for s in ob.material_slots):
            continue
        fo = ob.copy()
        fo.data = ob.data.copy()
        fo.name = ob.name + "_flat"
        ob.users_collection[0].objects.link(fo)
        bm = bmesh.new()
        bm.from_mesh(fo.data)
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), use_dissolve_boundaries=False, verts=bm.verts[:],
                                 edges=bm.edges[:], delimit={"UV"})
        bm.to_mesh(fo.data)
        bm.free()
        fo.data.update()
        fo["ce_lvl"] = "lod1"
        ob["ce_lvl"] = "lod0"
        out.append(fo)
    bpy.context.view_layer.update()
    return out


# --- far walls: the texels of the opposite wall ------------------------------------------------------------------''')

# 3) bake_city: flat copies after far uvs, hidden during the AO bake
rep('''    if far:
        stats["far_mapped"] = far_uvs(charts, far[0], far[1], size)''',
    '''    if far:
        stats["far_mapped"] = far_uvs(charts, far[0], far[1], size)
    flat = _flat_copies(objs) if flat_lod1 else []
    stats["flat_copies"] = len(flat)''')
rep('''    if ao:
        t_ao = time.time()
        ao_bk = BK.Baker(rig, objs, mats, size, 1, BK.SAMPLES)
        a = ao_bk.ambient_occlusion(ao.get("distance", 1.5), ao.get("samples", 16), ao.get("ground", True))''',
    '''    if ao:
        t_ao = time.time()
        for fo in flat:
            fo.hide_render = True           # the flat copy would close every opening for the occlusion rays
        ao_bk = BK.Baker(rig, objs, mats, size, 1, BK.SAMPLES)
        a = ao_bk.ambient_occlusion(ao.get("distance", 1.5), ao.get("samples", 16), ao.get("ground", True))
        for fo in flat:
            fo.hide_render = False''')
rep('''    stats["bake_s"] = round(time.time() - t0, 2)
    out["stats"] = stats
    return out


# --- the builder''',
    '''    stats["bake_s"] = round(time.time() - t0, 2)
    out["stats"] = stats
    out["flat"] = flat
    return out


# --- the builder''')
rep('''def bake_city(rig, objs, mats, size, weight_fn=None, ppm_max=512.0, cutout=False, ao=None, far=None, floors=None,
              cut_ppm=CUT_PPM, cut_names=()):''',
    '''def bake_city(rig, objs, mats, size, weight_fn=None, ppm_max=512.0, cutout=False, ao=None, far=None, floors=None,
              cut_ppm=CUT_PPM, cut_names=(), flat_lod1=False):''')
rep('''                      cut_ppm=float(spec3d.get("cut_ppm", CUT_PPM)), cut_names=rail_names)''',
    '''                      cut_ppm=float(spec3d.get("cut_ppm", CUT_PPM)), cut_names=rail_names,
                      flat_lod1=bool(spec3d.get("lod1_flat", True)) and bool(spec3d.get("lod1")))''')
rep('''    objs = objs + far_objs
    lods = []''',
    '''    objs = objs + far_objs + baked.get("flat", [])
    lods = []''')
open(p, 'w').write(s)
print('ok')
