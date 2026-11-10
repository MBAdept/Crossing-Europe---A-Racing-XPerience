"""Props, buildings and landmarks as real-time models.

  prop_vpbr    flat materials -> one vertex-PBR surface (road furniture, lamps as channel 12)
  prop_baked   procedural materials -> one atlas (albedo + night emission at half size), class baked
               (+ baked_cutout for materials with cut-out masks)
Model space: origin = the sprite anchor (ground, centre of the near face), the prop extends to -Z, +X is
to the right of the travel direction. A prop rendered for the right roadside (tag mirror_left) therefore
shows its -X side to the road and its +Z side to the approaching player.

Options of a catalog entry (ce3d.catalog3d):
  overrides  {material name: dict(role=..., color=hex, rough=, metal=, lamp=, skip=True)}  (prop_vpbr)
  atlas      (W, H) of the albedo atlas; ppm_max caps the texel density (px/m)
  view       'roadside' (road and approach faces 1.0, away faces 0.3, undersides 0.05) | 'allround'
             (all walls and roofs 1.0, undersides 0.05) - texel density weights (contract 4.6.5)
  params     extra generator parameters (e.g. allround=True: windows on every side of a landmark)
  roughness  the one roughness of the baked surfaces
"""
import time

import numpy as np

from . import bake as BK
from . import core, roles
from .export import Lod, ModelData, Part, sprite_extent


def _sprite_spec(set_id):
    from cesprites import catalog
    for s in catalog.all_sets():
        if s["id"] == set_id:
            return s
    raise KeyError(set_id)


def _build_source(spec3d):
    """Builds the generator model of the source sprite set with node tagging on. Returns rig, info, spec."""
    import render_all as RA
    from cesprites import meshutil as MU
    from cesprites import rig as R
    sspec = dict(_sprite_spec(spec3d["source"]))
    if spec3d.get("params"):
        sspec["params"] = dict(sspec["params"], **spec3d["params"])
    rig = R.Rig(quick=True)
    MU.tagging(True)
    try:
        info = RA.build(rig, sspec)
    finally:
        MU.tagging(False)
    return rig, info, sspec


def _objects(rig):
    """Objects of the 3D model: everything tagged except node 'none' (sprite-only effects)."""
    out = []
    for ob in core.model_objects(rig):
        if roles.node_of(ob) != "none":
            out.append(ob)
    return out


def _object_size(info, pts):
    obj = info.get("object")
    if obj:
        return dict(obj)
    mn, mx = pts.min(axis=0), pts.max(axis=0)
    return {"width_m": round(float(mx[0] - mn[0]), 2), "length_m": round(float(mx[1] - mn[1]), 2),
            "height_m": round(float(mx[2]), 2)}


def _finish_model(model_id, spec3d, sspec, info, pts):
    model = ModelData(model_id, spec3d["kind"], _object_size(info, pts))
    model.extent_m = sprite_extent(pts, sspec["camera"].get("view_yaw", 0.0))
    model.tags = list(sspec.get("tags", []))
    model.auto_lod = bool(spec3d.get("auto_lod", False))
    for sid in (spec3d.get("sets") or [model_id]):
        model.sets[sid] = {"model": model_id}
    return model


def build_vpbr(model_id, spec3d):
    t0 = time.time()
    rig, info, sspec = _build_source(spec3d)
    objs = _objects(rig)
    tr = roles.Translator(overrides=spec3d.get("overrides"), glass_class=False)
    mb = core.MeshBuilder()
    for soup in core.soups_of(objs):
        left = tr.add_object(mb, soup)
        if left:
            raise roles.RoleError("%s: object '%s' has %s materials - give a flat override or bake the model"
                                  % (model_id, soup.name, "/".join(sorted(left))))
    pts = mb.points()
    model = _finish_model(model_id, spec3d, sspec, info, pts)
    model.lods = [Lod("lod0", 100000, [Part("body", "lod0_body", mb.finish(), auto_lod=model.auto_lod)])]
    model.lights = tr.lights()
    model.stats = dict(build_s=round(time.time() - t0, 2), objects=len(objs))
    return model


def weight_roadside(n, _ob):
    """Texel density by visibility for a prop on the right roadside (Blender axes: -x = road, -y = the
    approaching player, +z = roofs)."""
    if n[2] < -0.5:
        return 0.05
    if n[2] > 0.3:
        return 1.0                   # roofs are seen from the road and from afar
    if n[0] < -0.5 or n[1] < -0.5:
        return 1.0
    return 0.3


def weight_allround(n, _ob):
    return 0.05 if n[2] < -0.5 else 1.0


def build_baked(model_id, spec3d):
    t0 = time.time()
    rig, info, sspec = _build_source(spec3d)
    objs = _objects(rig)
    core.realize(objs)
    mats = {}
    for ob in objs:
        for s in ob.material_slots:
            if s.material is not None:
                roles.tag(s.material)                 # every material must be tagged
                mats[s.material.name] = s.material
    mat_list = [mats[k] for k in sorted(mats)]
    cut_names = {m.name for m in mat_list if BK.has_cutout(m)}
    size = tuple(spec3d.get("atlas", (1024, 1024)))
    wf = weight_allround if spec3d.get("view") == "allround" else weight_roadside
    baked = BK.bake_atlas(rig, objs, mat_list, size, weight_fn=wf, ppm_max=spec3d.get("ppm_max", 128.0),
                          cutout=bool(cut_names))
    tr = roles.Translator()
    mb = core.MeshBuilder()
    for soup in core.soups_of(objs, uv_layer=BK.UV_NAME):
        uv = soup.uv.copy()
        uv[:, :, 1] = 1.0 - uv[:, :, 1]             # glTF / Godot: v down
        for mi in np.unique(soup.mi):
            mat = soup.material(int(mi))
            sel = soup.mi == mi
            mb.add("baked_cutout" if mat.name in cut_names else "baked", soup.pos[sel], soup.nor[sel], uv=uv[sel])
            # lamps of flat materials (yard lamps ...) become anchors; their glow is in the emission atlas
            role, d = roles.tag(mat)
            lamp = roles.lamp_from_emit(d.get("emit")) if role == "flat" else None
            if lamp is not None and lamp[0] == "lights" and lamp[1] >= 0.25:
                tr.anchors.append((lamp[0], soup.pos[sel].mean(axis=1), core.tri_areas(soup.pos[sel]), lamp[2]))
    pts = mb.points()
    model = _finish_model(model_id, spec3d, sspec, info, pts)
    model.lods = [Lod("lod0", 100000, [Part("body", "lod0_body", mb.finish(), auto_lod=model.auto_lod)])]
    model.lights = tr.lights()
    model.roughness = float(spec3d.get("roughness", 0.9))
    big = max(size) > 1024
    alb_name = "albedo.webp" if big else "albedo.png"
    model.texture_files[alb_name] = BK.encode(baked["albedo"], baked["alpha"], "webp" if big else "png")
    model.textures["albedo"] = alb_name
    if "lights" in baked["emit"]:
        model.texture_files["emit.png"] = BK.encode(BK.half(baked["emit"]["lights"]), None, "png")
        model.textures["emit"] = "emit.png"
    model.stats = dict(build_s=round(time.time() - t0, 2), objects=len(objs), bake=baked["stats"])
    return model
