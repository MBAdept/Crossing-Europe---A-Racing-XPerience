"""Vehicles as real-time models: traffic cars (cesprites.vehicles.Car) and player cars
(cesprites.carbody.SmoothCar). Every level of detail is its own generator build (ce3d.lod).

Traffic car   lod0  body (vpbr + glass) + 4 wheel nodes (one shared wheel mesh), decals cut into the body
              lod1  one merged vpbr mesh incl. wheels, decals cut into the coarser body
              lod2  one merged vpbr mesh, decals painted per triangle
              shadow  bare coarse body + wheels
              colour variants = paint of the sets (instance uniform), one mesh for all
Player car    lod0  race mesh: body (vpbr + glass, interior inside) + 4 wheel nodes; calipers in the body
              show  showroom mesh (finer generator detail), own wheel mesh
              shadow  coarse lofts + wheel cylinders
Model space: origin on the ground under the centre of the collision box, nose at -Z.
"""
import copy
import math
import time

import numpy as np

from . import core, decalgeo, roles
from . import lod as LOD
from .export import Lod, ModelData, Part, sprite_extent

GREY = np.array([120, 120, 120, 255], dtype=np.uint8)

# Lamp parts the sprites never needed (they show the cars from behind, lights as layers): added to a copy
# of the design for the 3D builds. Same decal conventions as cesprites.designs.
CAR_3D = {
    "sedan": dict(
        tail_lamps=[
            dict(part="indicator", poly=[(0.80, 0.793), (0.95, 0.788), (0.95, 0.842), (0.80, 0.846)], outline=False),
        ],
        head_lamps=[
            dict(face="front", part="indicator", poly=[(0.79, 0.642), (0.88, 0.64), (0.88, 0.73), (0.80, 0.73)],
                 outline=False),
            dict(face="front", part="drl", poly=[(0.525, 0.653), (0.78, 0.645), (0.78, 0.663), (0.525, 0.671)],
                 outline=False),
        ],
    ),
}


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
        tr.add_role(mb, role, d, soup.pos[sel], soup.nor[sel], soup.ob.get("ce_lamp"))
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
            meshes[key] = nodes[src].finish(origin=pivots[src])
        for side in ("l", "r"):
            node = "wheel_%d%s" % (axle, side)
            pos = core.model_point(np.asarray(pivots[node]) - origin)
            parts.append(Part(node, key, meshes[key], pos=pos, yaw_deg=180.0 if side == "l" else 0.0,
                              wheel={"radius": round(float(radius), 4), "steer": axle == 0}, auto_lod=auto_lod))
    return parts


# --- traffic cars -----------------------------------------------------------------------------------------

def traffic_design(name):
    from cesprites import designs
    d = copy.deepcopy(designs.TRAFFIC_MODELS[name])
    for k, extra in CAR_3D.get(name, {}).items():
        d[k] = list(d.get(k, [])) + copy.deepcopy(extra)
    return d


def _car_level(spec3d, level, paint_hex, metal):
    from cesprites import meshutil as MU
    from cesprites import rig as R
    from cesprites import vehicles
    rig = R.Rig(quick=True)
    MU.tagging(True)
    try:
        car = vehicles.Car(rig, traffic_design(spec3d["design"]), paint=paint_hex, metal=metal, name=spec3d["design"],
                           detail=LOD.CAR_DETAIL[level]).build()
    finally:
        MU.tagging(False)
    soups = core.soups_of(core.model_objects(rig))
    origin = np.array([0.0, car.L / 2.0, 0.0])
    nodes = {}
    stats = {}
    tr = roles.Translator(overrides={"surface:*": dict(role="paint", slot="paint", rough=0.28, metal=metal)},
                          glass_class=(level == "lod0"), default_paint={"paint": paint_hex})
    if level == "shadow":
        mb = nodes.setdefault("body", core.MeshBuilder())
        for s in soups:
            mb.add("vpbr", s.pos, s.nor, GREY, (0.8, 0.0), roles.NO_LAMP)
        return car, nodes, {}, origin, tr, stats
    pal, tris, stats = decalgeo.car_surfaces(car, {s.name: s for s in soups}, cut=True,
                                             level={"lod0": 0, "lod1": 1, "lod2": 2}[level])
    pivots = {}
    for s in soups:
        node = roles.node_of(s.ob)
        if node.startswith("wheel_") and s.ob.get("ce_pivot") is not None:
            pivots[node] = np.array(list(s.ob["ce_pivot"]), dtype=np.float64)
        if level != "lod0":
            node = "body"
        if s.name in tris:
            t = tris[s.name]
            mb = nodes.setdefault(node, core.MeshBuilder())
            for mi in np.unique(t.mat):
                role, data, lamp = pal.items[int(mi)]
                sel = t.mat == mi
                tr.add_role(mb, role, dict(data), t.pos[sel], t.nor[sel], lamp)
        else:
            _add_soup(nodes, tr, s, node)
    return car, nodes, pivots, origin, tr, stats


def build_car(model_id, spec3d):
    from cesprites import catalog
    t0 = time.time()
    design = spec3d["design"]
    colours = dict(catalog.TRAFFIC_COLORS[design])
    set_ids = list(spec3d.get("sets") or [])
    first = set_ids[0].split("_", 1)[1]
    paint_hex = colours[first]
    metal = catalog.METALLIC.get(first, 0.35)
    sspec = _sprite_spec(spec3d["source"])
    lods = []
    stats = {}
    model = None
    for level in ("lod0", "lod1", "lod2"):
        car, nodes, pivots, origin, tr, st = _car_level(spec3d, level, paint_hex, metal)
        stats[level] = st
        if level == "lod0":
            model = ModelData(model_id, spec3d["kind"], car.object_size())
            pts = np.concatenate([mb.points() for mb in nodes.values()])
            model.extent_m = sprite_extent(pts, 0.0)
            model.lights = tr.lights(origin=origin)
            d = car.d
            same = d.get("tire_w_rear", d["tire_w"]) == d["tire_w"]
            parts = [Part("body", "lod0_body", nodes["body"].finish(origin=origin))]
            parts += _wheel_parts(nodes, pivots, origin, car.R, "wheel", same)
            lods.append(Lod("lod0", LOD.VEHICLE_LOD_DIST["lod0"], parts))
        else:
            lods.append(Lod(level, LOD.VEHICLE_LOD_DIST[level], [Part("body", level + "_body",
                                                                       nodes["body"].finish(origin=origin))]))
    car, nodes, _p, origin, _tr, _st = _car_level(spec3d, "shadow", paint_hex, metal)
    model.shadow = Part("body", "shadow", nodes["body"].finish(origin=origin))
    model.lods = lods
    model.paint = {"paint": paint_hex, "metal": metal}
    model.tags = list(sspec.get("tags", []))
    for sid in set_ids:
        cname = sid.split("_", 1)[1]
        model.sets[sid] = {"model": model_id, "paint": {"paint": colours[cname], "metal": catalog.METALLIC.get(cname, 0.35)}}
    model.stats = dict(build_s=round(time.time() - t0, 2), decals=stats)
    return model


# --- player cars ------------------------------------------------------------------------------------------

PLAYER_OVERRIDES = {
    # procedural grille shaders (slats / honeycomb): a dark flat stand-in
    "proc:*": dict(role="flat", color="#0c0c0d", rough=0.5, metal=0.2),
}


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
    finally:
        MU.tagging(False)
    car = info["car"]
    objs = core.model_objects(rig)
    soups = core.soups_of(objs)
    tr = roles.Translator(overrides=PLAYER_OVERRIDES, glass_opacity=spec3d.get("glass_opacity", 1.0),
                          default_paint={"paint": params["paint"]})
    nodes = {}
    pivots = {}
    for s in soups:
        node = roles.node_of(s.ob)
        if node.startswith("wheel_"):
            mw = s.ob.matrix_world
            pivots[node] = np.array([mw[0][3], mw[1][3], mw[2][3]], dtype=np.float64)
        _add_soup(nodes, tr, s, node)
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
            nn = np.array(nor, dtype=np.float64)
            nn /= np.maximum(np.linalg.norm(nn, axis=2, keepdims=True), 1e-9)
            mb.add("vpbr", np.array(pos), nn, GREY, (0.8, 0.0), roles.NO_LAMP)
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
        parts = [Part("body", level + "_body", nodes["body"].finish())]
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
