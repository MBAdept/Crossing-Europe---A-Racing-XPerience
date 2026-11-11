"""Player cars as real-time models (cesprites.carbody.SmoothCar + cardetail + player_cars) and the helpers the
other vehicle builders share (traffic cars: ce3d.traffic3d, truck: ce3d.truck3d). Every level of detail is its
own generator build (ce3d.lod).

Player car    lod0  race mesh: body (vpbr + glass, interior inside) + 4 wheel nodes; calipers in the body
              show  showroom mesh (finer generator detail), own wheel mesh
              shadow  coarse lofts + wheel cylinders
Model space: origin on the ground under the centre of the collision box, nose at -Z.
"""
import copy
import math
import os
import time

import numpy as np

from . import core, decalgeo, extras3d, interior3d, roles
from . import lod as LOD
from .export import Lod, ModelData, Part, sprite_extent

GREY = np.array([120, 120, 120, 255], dtype=np.uint8)
SLIVER_M = 1.5e-4          # triangles lower than this are dropped (core.MeshBuilder.finish)

def _sprite_spec(set_id):
    from cesprites import catalog
    for s in catalog.all_sets():
        if s["id"] == set_id:
            return s
    raise KeyError(set_id)


def _add_soup(nodes, tr, soup, default_node):
    """Adds a soup to the MeshBuilders of its nodes; a material may send its faces to another node
    (material["ce_node"]: brake calipers belong to the body)."""
    left = set()
    for mi in np.unique(soup.mi):
        mat = soup.material(int(mi))
        node = str(mat.get("ce_node", default_node)) if mat is not None else default_node
        sel = soup.mi == mi
        role, d = tr.describe(mat)
        if d.get("skip") or role == "fx":
            continue
        if role in ("surface", "proc"):
            left.add(role)
            continue
        mb = nodes.setdefault(node, core.MeshBuilder())
        sink = soup.ob.get("ce_sink")
        shift = None
        if sink is not None and str(sink).split(":")[0] in decalgeo.AXES:
            # a sunk lamp part ("<projection>:<depth>"): its anchor lies in the opening
            shift = decalgeo.AXES[str(sink).split(":")[0]] * float(str(sink).split(":")[1])
        tr.add_role(mb, role, d, soup.pos[sel], soup.nor[sel], soup.ob.get("ce_lamp"), anchor_shift=shift)
    if left:
        raise roles.RoleError("object '%s' has untranslated %s materials" % (soup.name, "/".join(sorted(left))))


def _wheel_parts(nodes, pivots, origin, radius, mesh_name, same_axles, auto_lod=True):
    """Wheel nodes -> parts: the right wheel of an axle is the mesh, the left one is the same mesh turned by
    180 degrees. same_axles: front and rear share one mesh."""
    parts = []
    meshes = {}
    for axle in (0, 1):
        key = mesh_name if same_axles else "%s_%s" % (mesh_name, "f" if axle == 0 else "r")
        src = "wheel_%dr" % (0 if same_axles else axle)
        if key not in meshes:
            meshes[key] = nodes[src].finish(origin=pivots[src], min_height=SLIVER_M)
        for side in ("l", "r"):
            node = "wheel_%d%s" % (axle, side)
            pos = core.model_point(np.asarray(pivots[node]) - origin)
            parts.append(Part(node, key, meshes[key], pos=pos, yaw_deg=180.0 if side == "l" else 0.0,
                              wheel={"radius": round(float(radius), 4), "steer": axle == 0}, auto_lod=auto_lod))
    return parts


# --- player cars ------------------------------------------------------------------------------------------

PLAYER_OVERRIDES = {
    # procedural grille shaders (slats / honeycomb): a dark flat stand-in under the bars of the 3D build
    "proc:*": dict(role="flat", color="#0a0a0b", rough=0.55, metal=0.2),
    # paint: glossier than the sprite material - the real-time paint has no clear-coat reflection of the sky
    "paint:*": dict(rough=0.2),
    # alloy rims: a mirror-like metal shows the dark road and wheel arch in real time - less metallic, a bit rougher
    "*_rim": dict(metal=0.55, rough=0.3),
}
# look of the glazing and of the lamp lenses (class glass): opacity of the tinted panes over the cabin, of the
# coloured lenses (the lamp parts under them carry the colour and the light) and of clear headlight lenses
PLAYER_GLASS = dict(glass_opacity=0.36, lens_opacity=0.10, clear_lens_opacity=0.08)
GLASS_OVERLAP_M = 0.008        # the panes overlap the edge of their opening by this much (the black band)
POCKET_SPAN_M = 0.09           # objects whose faces under a lamp outline lie this close behind the front one share the recess
LINER = dict(color="#232427", rough=0.85)


def _shift(outline, proj, dy):
    """Outline of the build space (y = 0 at the rear bumper) in root space (car centred)."""
    if proj == "side":
        return [(p[0] + dy, p[1]) for p in outline]
    if proj == "top":
        return [(p[0], p[1] + dy) for p in outline]
    return list(outline)


def _open_cabin(car, lay, soups):
    """Transparent glazing needs openings: cuts the outline of every pane (inside its black band) out of the
    greenhouse and out of the seal patch under the glass, opens the deck of the lower body under the greenhouse
    and removes the floor of the greenhouse loft. Returns the triangles of the lining (pos, nor): the remaining
    greenhouse seen from inside."""
    by_name = {s.name: s for s in soups}
    dy = -car.L / 2.0
    pillars = [(proj, [decalgeo.inset(_shift(o, proj, dy), 0.004)]) for (proj, _sym, o) in car.glass_pillars]
    green = by_name[car.green.name]
    stats = dict(removed=0)

    def cut(soup, proj, signs, hole):
        keeps = [k for (pp, ks) in pillars if pp == proj for k in ks]
        for sgn in signs:
            pos, nor, mat, n = decalgeo.cut_holes(soup.pos, soup.nor, soup.mi, proj, sgn, [hole], keeps)
            soup.pos, soup.nor, soup.mi, soup.n = pos, nor, mat, pos.shape[0]
            stats["removed"] += n
    for (_name, proj, sym, outline, seal_ob) in car.panes:
        hole = decalgeo.inset(_shift(outline, proj, dy), GLASS_OVERLAP_M)
        signs = (1, -1) if (sym and proj == "side") else (1,)
        cut(green, proj, signs, hole)
        if seal_ob is not None and seal_ob.name in by_name:
            cut(by_name[seal_ob.name], proj, signs, hole)
    # floor of the greenhouse loft (lies inside the body): faces looking down
    fn = np.cross(green.pos[:, 1] - green.pos[:, 0], green.pos[:, 2] - green.pos[:, 0])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    keep = fn[:, 2] > -0.5
    green.pos, green.nor, green.mi = green.pos[keep], green.nor[keep], green.mi[keep]
    green.n = green.pos.shape[0]
    # deck of the lower body under the greenhouse
    body = by_name[car.body.name]
    hole = _shift(interior3d.deck_opening(car, lay), "top", dy)
    pos, nor, mat, n = decalgeo.cut_holes(body.pos, body.nor, body.mi, "top", 1, [hole], n_min=0.3)
    body.pos, body.nor, body.mi, body.n = pos, nor, mat, pos.shape[0]
    stats["removed"] += n
    return green.pos[:, ::-1, :].copy(), -green.nor[:, ::-1, :], stats


def _lamp_pockets(car, soups):
    """Recessed lamp units (cesprites.cardetail.lamp with detail "lamp_depth"): sinks the body faces under the
    outline of every unit and closes the step with walls (decalgeo.pocket). Of several objects under one outline
    (target "all") the one in front takes the recess. Returns the number of triangles of floors and walls."""
    by_name = {s.name: s for s in soups}
    dy = -car.L / 2.0
    n_min = max(0.05, 0.8 * float(car.detail.get("graze", 0.22)))
    total = 0
    for pk in car.lamp_pockets:
        proj = pk["proj"]
        targets = [by_name[o.name] for o in car.targets[pk["target"]] if o.name in by_name]
        outline = _shift(pk["outline"], proj, dy)
        variants = [(outline, 1)]
        if pk["sym"]:
            variants.append(([(-p[0], p[1]) for p in outline], 1) if proj != "side" else (outline, -1))
        for (ol, sgn) in variants:
            found = []
            for s in targets:
                mats = list(s.mats)
                i_floor, i_wall = len(mats), len(mats) + 1
                pos, nor, mat, st = decalgeo.pocket(s.pos, s.nor, s.mi, proj, sgn, ol, pk["depth"], i_floor, i_wall, n_min)
                if st["floor"] > 0:
                    found.append((s, pos, nor, mat, st))
            if not found:
                raise roles.RoleError("lamp unit '%s' of %s finds no body under its outline" % (pk["tag"], car.name))
            # a unit may lie on two objects (tail lamps of a hatchback: body and greenhouse); what is clearly
            # behind the front one (a bumper under the body's end) stays as it is
            front = max(f[4]["front"] for f in found)
            for (s, pos, nor, mat, st) in found:
                if st["front"] < front - POCKET_SPAN_M:
                    continue
                s.mats = list(s.mats) + [pk["housing"], pk["wall"]]
                s.pos, s.nor, s.mi, s.n = pos, nor, mat, pos.shape[0]
                total += st["floor"] + st["walls"]
    return total


def _player_level(spec3d, level):
    from cesprites import meshutil as MU
    from cesprites import player_cars
    from cesprites import rig as R
    sspec = _sprite_spec(spec3d["source"])
    params = dict(sspec["params"])
    params["detail"] = dict(LOD.PLAYER_DETAIL[level], extras=True)
    rig = R.Rig(quick=True)
    MU.tagging(True)
    try:
        info = player_cars.build(rig, params)
        car = info["car"]
        # the parts of the 3D build are made in build space (ray casts onto the body): the car back to where
        # it was built, then to its place again
        import bpy
        car.center.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        info["extras"] = extras3d.build_extras(car, fine=(level == "show"))
        lay = interior3d.build_interior(car, fine=(level == "show"))
        car.finish()
    finally:
        MU.tagging(False)
    objs = core.model_objects(rig)
    soups = core.soups_of(objs)
    pocket_tris = _lamp_pockets(car, soups)
    extras3d.uncover_pockets(car, {s.name: s for s in soups}, lambda o, pr: _shift(o, pr, -car.L / 2.0), decalgeo.cut_holes)
    lin_pos, lin_nor, cut_stats = _open_cabin(car, lay, soups)
    if os.environ.get("CE_STATS"):
        import re
        groups = {}
        for s_ in soups:
            key = re.sub(r"\.\d+$", "", s_.name)
            e = groups.setdefault(key, [0, 0])
            e[0] += s_.n
            if s_.n:
                g = np.cross(s_.pos[:, 1] - s_.pos[:, 0], s_.pos[:, 2] - s_.pos[:, 0])
                e[1] += int((np.einsum("ij,ij->i", g, s_.nor.sum(axis=1)) < 0).sum())
        print("--- %s %s: %d triangles in %d objects (+ lining %d)" % (
            spec3d["design"], level, sum(v[0] for v in groups.values()), len(soups), lin_pos.shape[0]))
        for k, v in sorted(groups.items(), key=lambda kv: -kv[1][0])[:int(os.environ.get("CE_STATS") or 45)]:
            print("   %6d  %s%s" % (v[0], k, "   (%d wound against their normals)" % v[1] if v[1] else ""))
    over = dict(PLAYER_OVERRIDES)
    over.update(spec3d.get("overrides", {}))
    tr = roles.Translator(overrides=over, default_paint={"paint": params["paint"]},
                          glass_opacity=spec3d.get("glass_opacity", PLAYER_GLASS["glass_opacity"]),
                          lens_opacity=PLAYER_GLASS["lens_opacity"], clear_lens_opacity=PLAYER_GLASS["clear_lens_opacity"])
    nodes = {}
    pivots = {}
    for s in soups:
        if s.n == 0:
            continue
        node = roles.node_of(s.ob)
        if node.startswith("wheel_"):
            mw = s.ob.matrix_world
            pivots[node] = np.array([mw[0][3], mw[1][3], mw[2][3]], dtype=np.float64)
        _add_soup(nodes, tr, s, node)
    # lining of the greenhouse: the cut loft seen from inside
    col = np.empty(4, dtype=np.uint8)
    col[:3] = core.srgb8(core.hex_to_lin(LINER["color"]))
    col[3] = 255
    nodes["body"].add("vpbr", lin_pos, lin_nor, col, (LINER["rough"], 0.0), roles.NO_LAMP)
    info["cabin"] = dict(lining_tris=int(lin_pos.shape[0]), removed=cut_stats["removed"], pocket_tris=pocket_tris)
    return car, info, params, nodes, pivots, tr


def _player_shadow(spec3d):
    """Shadow caster: the lower body and the greenhouse lofted at a handful of stations, wheels as drums."""
    from cesprites import carbody as CB
    from cesprites import player_cars
    from cesprites import rig as R
    sspec = _sprite_spec(spec3d["source"])
    p = sspec["params"]
    d = player_cars.DESIGNS[p["design"]]
    rig = R.Rig(quick=True)
    car = CB.SmoothCar(rig, d, paint=p["paint"], metal=p.get("metal", 0.3), name=p["design"],
                       detail=LOD.PLAYER_DETAIL["shadow"])
    ys = {car.lb0, car.lb1}
    for i in range(1, 12):
        ys.add(car.lb0 + (car.lb1 - car.lb0) * i / 12.0)
    for ya in (car.y_ra, car.y_fa):
        ys.update((ya - car.Ra, ya - car.Ra * 0.5, ya, ya + car.Ra * 0.5, ya + car.Ra))
    lower = car._loft_object("shadow_lower", sorted(ys), car.lower_half, car.paint)
    g0, g1 = d["g_range"]
    green = car._loft_object("shadow_green", [g0 + (g1 - g0) * i / 9.0 for i in range(10)], car.green_half, car.paint)
    car.finish()
    mb = core.MeshBuilder()
    for s in core.soups_of([lower, green]):
        mb.add("vpbr", s.pos, s.nor, GREY, (0.8, 0.0), roles.NO_LAMP)
    # wheels: 12-sided drums
    tw = d["tw"]
    inset = d.get("wheel_inset", 0.02)
    n = 12
    for ya in (car.y_ra, car.y_fa):
        for side in (1, -1):
            x1 = side * (car.W2 - inset)
            x0 = x1 - side * tw
            cy, cz = ya - car.L / 2.0, car.R
            ring = [(cy + car.R * math.cos(2 * math.pi * k / n), cz + car.R * math.sin(2 * math.pi * k / n))
                    for k in range(n)]
            pos, nor = [], []
            for k in range(n):
                a, b = ring[k], ring[(k + 1) % n]
                quad = [(x0, a[0], a[1]), (x1, a[0], a[1]), (x1, b[0], b[1]), (x0, b[0], b[1])]
                nrm = ((0.0, (a[0] + b[0]) / 2 - cy, (a[1] + b[1]) / 2 - cz),) * 3
                pos += [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]
                nor += [nrm, nrm]
                for x, sx in ((x0, -side), (x1, side)):
                    pos.append([(x, cy, cz), (x, a[0], a[1]), (x, b[0], b[1])])
                    nor.append(((sx, 0.0, 0.0),) * 3)
            pp = np.array(pos, dtype=np.float64)
            nn = np.array(nor, dtype=np.float64)
            nn /= np.maximum(np.linalg.norm(nn, axis=2, keepdims=True), 1e-9)
            # every triangle wound to its normal (counter-clockwise seen from outside, as the generator meshes):
            # the same vertex order for both caps and both sides turned one cap of every drum and the mantles of
            # one side inside out - with back-face culling those faces cast no shadow
            flip = np.einsum("ij,ij->i", np.cross(pp[:, 1] - pp[:, 0], pp[:, 2] - pp[:, 0]), nn.sum(axis=1)) < 0.0
            pp[flip] = pp[flip][:, ::-1]
            nn[flip] = nn[flip][:, ::-1]
            mb.add("vpbr", pp, nn, GREY, (0.8, 0.0), roles.NO_LAMP)
    return mb


def build_player(model_id, spec3d):
    from cesprites import catalog
    t0 = time.time()
    design = spec3d["design"]
    col, metal = catalog.PLAYER_COLORS[design]
    sspec = _sprite_spec(spec3d["source"])
    model = None
    lods = []
    stats = {}
    origin = np.zeros(3)
    for level, wheel_mesh in (("lod0", "wheel"), ("show", "show_wheel")):
        t1 = time.time()
        car, info, params, nodes, pivots, tr = _player_level(spec3d, level)
        d = car.d
        same = d.get("tw_r", d["tw"]) == d["tw"]
        parts = [Part("body", level + "_body", nodes["body"].finish(min_height=SLIVER_M))]
        parts += _wheel_parts(nodes, pivots, origin, car.R, wheel_mesh, same)
        lods.append(Lod(level, 100000 if level == "lod0" else 0, parts))
        if level == "lod0":
            model = ModelData(model_id, spec3d["kind"], dict(info["object"]))
            model.lights = tr.lights()
        stats[level] = dict(build_s=round(time.time() - t1, 2))
    model.shadow = Part("body", "shadow", _player_shadow(spec3d).finish())
    model.lods = lods
    model.paint = {"paint": col, "metal": metal}
    model.tags = list(sspec.get("tags", []))
    for sid, extra in (spec3d.get("sets") or {model_id: {}}).items():
        e = {"model": model_id}
        e.update(extra)
        e["paint"] = {"paint": col, "metal": metal}
        model.sets[sid] = e
    model.stats = dict(build_s=round(time.time() - t0, 2), levels=stats)
    return model
