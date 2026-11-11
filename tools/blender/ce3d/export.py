"""Model data of one export and its intermediates: model.glb + model_meta.json (+ textures).

Node conventions (contract 4.6.2):
  <root>
    lod0 | lod1 | lod2 | show     level of detail (empty node)
      body                        everything that does not turn; props: the whole model
      wheel_<axle><l|r>           axle 0 = front; pivot at the wheel centre, spin axis = local X; a left
                                  wheel is the right wheel mesh turned 180 degrees about Y
    shadow/body                   optional low-poly shadow caster
Meshes are written once per mesh name (file <mesh name>.res after the bake); wheels share one mesh.
"""
import math
import os

import numpy as np

from . import EXPORTER, MANIFEST_VERSION, core
from . import manifest as MF
from .glb import Glb


class Part:
    """One node of a LOD: mesh (class surfaces) + pose."""

    def __init__(self, node, mesh_name, surfaces, pos=None, yaw_deg=0.0, wheel=None, auto_lod=False):
        self.node = node
        self.mesh_name = mesh_name
        self.surfaces = surfaces            # [(class, dict(pos, nor, idx, col, uv, uv2))] in model space
        self.pos = pos                      # model space [x, y, z] or None
        self.yaw_deg = yaw_deg
        self.wheel = wheel                  # {"radius": r, "steer": bool} or None
        self.auto_lod = auto_lod

    def tris(self):
        return core.tri_count(self.surfaces)

    def classes(self):
        return [c for c, _s in self.surfaces]


class Lod:
    def __init__(self, name, max_dist_m, parts):
        self.name = name
        self.max_dist_m = max_dist_m
        self.parts = parts


class ModelData:
    """Everything the manifest entry and the intermediates of one model need."""

    def __init__(self, model_id, kind, obj):
        self.id = model_id
        self.kind = kind
        self.object = obj                   # {"width_m", "length_m", "height_m"} as in the sprite manifest
        self.extent_m = None                # {"left", "right"} of the anchor in the sprite view
        self.lods = []
        self.shadow = None                  # Part
        self.lights = []
        self.paint = None
        self.textures = {}                  # {"albedo": file, "emit": file, "leaves": file}
        self.texture_files = {}             # file name -> bytes
        self.roughness = None
        self.impostor = None                # {"texture": file, "size_m": [w, h], ...}
        self.auto_lod = False
        self.tags = []
        self.sets = {}
        self.extra = {}                     # further manifest keys (cards, variants ...)
        self.stats = {}                     # report only: timings and counts, written to export_report.json

    # --- measurements -------------------------------------------------------------------------------

    def aabb(self):
        """[min x, min y, min z, max x, max y, max z] of LOD0 in model space (part poses applied)."""
        lo = np.full(3, 1e30)
        hi = np.full(3, -1e30)
        for part in self.lods[0].parts:
            off = np.asarray(part.pos if part.pos is not None else (0.0, 0.0, 0.0))
            for _c, s in part.surfaces:
                p = s["pos"]
                if part.yaw_deg:
                    a = math.radians(part.yaw_deg)
                    ca, sa = math.cos(a), math.sin(a)
                    p = np.stack([p[:, 0] * ca + p[:, 2] * sa, p[:, 1], -p[:, 0] * sa + p[:, 2] * ca], axis=1)
                lo = np.minimum(lo, p.min(axis=0) + off)
                hi = np.maximum(hi, p.max(axis=0) + off)
        return [round(float(v), 3) + 0.0 for v in list(lo) + list(hi)]

    # --- manifest entry -----------------------------------------------------------------------------

    def entry(self):
        prefix = self.id + "/"
        e = {"kind": self.kind, "object": self.object}
        if self.extent_m is not None:
            e["extent_m"] = self.extent_m
        e["aabb"] = self.aabb()
        lods = []
        for lod in self.lods:
            parts = []
            for p in lod.parts:
                d = {"node": p.node, "mesh": prefix + p.mesh_name + ".res", "classes": p.classes()}
                if p.pos is not None:
                    d["pos"] = [round(float(v), 4) + 0.0 for v in p.pos]
                if p.yaw_deg:
                    d["yaw_deg"] = p.yaw_deg
                if p.wheel is not None:
                    d["wheel"] = p.wheel
                parts.append(d)
            lods.append({"name": lod.name, "max_dist_m": lod.max_dist_m, "tris": sum(p.tris() for p in lod.parts),
                         "parts": parts})
        e["lods"] = lods
        if self.shadow is not None:
            e["shadow"] = {"mesh": prefix + self.shadow.mesh_name + ".res", "tris": self.shadow.tris()}
        if self.lights:
            e["lights"] = self.lights
        if self.paint:
            e["paint"] = self.paint
        if self.textures:
            e["textures"] = {k: prefix + v for k, v in self.textures.items()}
        if self.roughness is not None:
            e["roughness"] = self.roughness
        if self.impostor is not None:
            imp = dict(self.impostor)
            imp["texture"] = prefix + imp["texture"]
            e["impostor"] = imp
        e.update(self.extra)
        e["auto_lod"] = bool(self.auto_lod)
        e["tags"] = list(self.tags)
        return e

    # --- intermediates ---------------------------------------------------------------------------------

    def write(self, out_dir, key=""):
        """Writes model.glb, the textures and model_meta.json; returns the meta dict.
        Everything written here depends on the model alone: two exports of the same model give byte-equal
        folders (a plain diff compares two caches). What changes from run to run - the timings in
        self.stats - goes to <cache>/export_report.json (export_models.py), not into these files."""
        os.makedirs(out_dir, exist_ok=True)
        for f in os.listdir(out_dir):
            os.remove(os.path.join(out_dir, f))
        g = Glb(EXPORTER)
        meshes = {}

        def add(part, parent):
            if part.mesh_name not in meshes:
                meshes[part.mesh_name] = {"tris": part.tris(), "auto_lod": bool(part.auto_lod),
                                          "verts": int(sum(s["pos"].shape[0] for _c, s in part.surfaces))}
            mi = g.mesh(part.mesh_name, part.surfaces)
            rot = None
            if part.yaw_deg:
                a = math.radians(part.yaw_deg) * 0.5
                rot = (0.0, math.sin(a), 0.0, math.cos(a))
            g.node(part.node, mesh=mi, translation=part.pos, rotation=rot, parent=parent)
        root = g.node(self.id.replace("/", "_"))
        for lod in self.lods:
            ln = g.node(lod.name, parent=root)
            for p in lod.parts:
                add(p, ln)
        if self.shadow is not None:
            sn = g.node("shadow", parent=root)
            add(self.shadow, sn)
        glb_bytes = g.write(os.path.join(out_dir, "model.glb"))
        for name in sorted(self.texture_files):
            with open(os.path.join(out_dir, name), "wb") as fh:
                fh.write(self.texture_files[name])
        meta = {"version": MANIFEST_VERSION, "exporter": EXPORTER, "id": self.id, "key": key,
                "model": self.entry(), "sets": self.sets, "meshes": {k: meshes[k] for k in sorted(meshes)},
                "textures": sorted(self.texture_files), "glb_bytes": glb_bytes}
        MF.write_json(os.path.join(out_dir, "model_meta.json"), meta)
        return meta


def sprite_extent(points, view_yaw_deg=0.0):
    """extent_m {"left", "right"} as the sprite pipeline measures it: horizontal extent of the object left
    and right of the anchor (the origin) in the sprite's view, i.e. turned by view_yaw about the vertical
    axis. points: (N, 3) Blender space."""
    a = math.radians(-view_yaw_deg)
    px = points[:, 0] * math.cos(a) - points[:, 1] * math.sin(a)
    return {"left": round(float(-px.min()), 2) + 0.0, "right": round(float(px.max()), 2) + 0.0}
