"""Minimal GLB (glTF 2.0 binary) writer for the model intermediates. No bpy needed.

Written: a node tree, meshes with triangle primitives (POSITION, NORMAL, optional COLOR_0 as normalised
bytes, TEXCOORD_0, TEXCOORD_1, indices) and materials that only carry a name - the name is the material
class of the surface (vpbr, glass, baked, baked_cutout, leaves); the bake drops the materials and keeps
the names. Textures are never embedded: they travel as separate files next to the .glb.
The output is deterministic: same input arrays -> same bytes.
"""
import json
import struct

import numpy as np

FLOAT, UBYTE, USHORT, UINT = 5126, 5121, 5123, 5125
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963


class Glb:
    def __init__(self, generator="ce3d"):
        self.j = {"asset": {"version": "2.0", "generator": generator}, "scene": 0, "scenes": [{"nodes": []}],
                  "nodes": [], "meshes": [], "materials": [], "accessors": [], "bufferViews": [],
                  "buffers": [{"byteLength": 0}]}
        self.bin = bytearray()
        self._mat_index = {}
        self._mesh_index = {}

    # --- buffers ---------------------------------------------------------------------------------

    def _view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin += data
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            v["target"] = target
        self.j["bufferViews"].append(v)
        return len(self.j["bufferViews"]) - 1

    def _accessor(self, arr, ctype, atype, target=None, normalized=False, minmax=False):
        arr = np.ascontiguousarray(arr)
        a = {"bufferView": self._view(arr.tobytes(), target), "componentType": ctype, "count": int(arr.shape[0]),
             "type": atype}
        if normalized:
            a["normalized"] = True
        if minmax:
            a["min"] = [float(x) for x in arr.min(axis=0)]
            a["max"] = [float(x) for x in arr.max(axis=0)]
        self.j["accessors"].append(a)
        return len(self.j["accessors"]) - 1

    # --- materials, meshes, nodes --------------------------------------------------------------------

    def material(self, name):
        """Material stub: only the name (= material class) matters."""
        if name not in self._mat_index:
            self.j["materials"].append({"name": name, "pbrMetallicRoughness": {
                "baseColorFactor": [1.0, 1.0, 1.0, 1.0], "metallicFactor": 0.0, "roughnessFactor": 1.0}})
            self._mat_index[name] = len(self.j["materials"]) - 1
        return self._mat_index[name]

    def mesh(self, name, surfaces):
        """surfaces: [(class name, dict(pos Nx3, nor Nx3, idx M, col Nx4 uint8 | None, uv Nx2 | None,
        uv2 Nx2 | None))] in the order the surfaces shall have. A mesh name is written once: asking for it
        again returns the same mesh (shared wheel meshes)."""
        if name in self._mesh_index:
            return self._mesh_index[name]
        prims = []
        for cls, s in surfaces:
            n = int(s["pos"].shape[0])
            attrs = {"POSITION": self._accessor(s["pos"].astype(np.float32), FLOAT, "VEC3", ARRAY_BUFFER, minmax=True),
                     "NORMAL": self._accessor(s["nor"].astype(np.float32), FLOAT, "VEC3", ARRAY_BUFFER)}
            if s.get("uv") is not None:
                attrs["TEXCOORD_0"] = self._accessor(s["uv"].astype(np.float32), FLOAT, "VEC2", ARRAY_BUFFER)
            if s.get("uv2") is not None:
                attrs["TEXCOORD_1"] = self._accessor(s["uv2"].astype(np.float32), FLOAT, "VEC2", ARRAY_BUFFER)
            if s.get("col") is not None:
                attrs["COLOR_0"] = self._accessor(s["col"].astype(np.uint8), UBYTE, "VEC4", ARRAY_BUFFER,
                                                  normalized=True)
            idx = np.asarray(s["idx"]).reshape(-1)
            if n <= 65535:
                ia = self._accessor(idx.astype(np.uint16), USHORT, "SCALAR", ELEMENT_ARRAY_BUFFER)
            else:
                ia = self._accessor(idx.astype(np.uint32), UINT, "SCALAR", ELEMENT_ARRAY_BUFFER)
            prims.append({"attributes": attrs, "indices": ia, "material": self.material(cls), "mode": 4})
        self.j["meshes"].append({"name": name, "primitives": prims})
        self._mesh_index[name] = len(self.j["meshes"]) - 1
        return self._mesh_index[name]

    def node(self, name, mesh=None, translation=None, rotation=None, parent=None):
        """rotation: quaternion (x, y, z, w). parent: node index, None = scene root."""
        n = {"name": name}
        if mesh is not None:
            n["mesh"] = mesh
        if translation is not None and any(abs(float(x)) > 0.0 for x in translation):
            n["translation"] = [float(x) for x in translation]
        if rotation is not None:
            n["rotation"] = [float(x) for x in rotation]
        self.j["nodes"].append(n)
        i = len(self.j["nodes"]) - 1
        if parent is None:
            self.j["scenes"][0]["nodes"].append(i)
        else:
            self.j["nodes"][parent].setdefault("children", []).append(i)
        return i

    def write(self, path):
        while len(self.bin) % 4:
            self.bin.append(0)
        self.j["buffers"][0]["byteLength"] = len(self.bin)
        js = json.dumps(self.j, separators=(",", ":")).encode("utf-8")
        while len(js) % 4:
            js += b" "
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(path, "wb") as fh:
            fh.write(struct.pack("<4sII", b"glTF", 2, total))
            fh.write(struct.pack("<I4s", len(js), b"JSON"))
            fh.write(js)
            fh.write(struct.pack("<I4s", len(self.bin), b"BIN\x00"))
            fh.write(bytes(self.bin))
        return total
