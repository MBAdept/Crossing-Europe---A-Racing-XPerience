"""Minimal GLB (glTF 2.0 binary) writer: nodes, meshes with primitives (POSITION, NORMAL, TEXCOORD_0,
COLOR_0, indices), PBR materials (factors + embedded PNG/JPEG/WebP textures), extras. No bpy needed."""
import json
import struct

import numpy as np

FLOAT, UBYTE, USHORT, UINT = 5126, 5121, 5123, 5125
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963


class Glb:
    def __init__(self, generator="ce3d-spike"):
        self.j = {"asset": {"version": "2.0", "generator": generator}, "scene": 0, "scenes": [{"nodes": []}],
                  "nodes": [], "meshes": [], "materials": [], "accessors": [], "bufferViews": [],
                  "buffers": [{"byteLength": 0}]}
        self.bin = bytearray()
        self._mat_index = {}
        self._img_index = {}

    # --- buffers -------------------------------------------------------------------------------
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

    # --- images / materials ----------------------------------------------------------------------
    def image(self, key, data, mime="image/png"):
        if key in self._img_index:
            return self._img_index[key]
        self.j.setdefault("images", []).append({"bufferView": self._view(data), "mimeType": mime, "name": key})
        self.j.setdefault("samplers", [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}])
        self.j.setdefault("textures", []).append({"source": len(self.j["images"]) - 1, "sampler": 0, "name": key})
        self._img_index[key] = len(self.j["textures"]) - 1
        return self._img_index[key]

    def material(self, name, color=(1, 1, 1, 1), metal=0.0, rough=0.5, emissive=None, emissive_strength=None,
                 alpha_mode=None, alpha_cutoff=None, double_sided=False, base_tex=None, mr_tex=None, emissive_tex=None,
                 normal_tex=None, extras=None):
        if name in self._mat_index:
            return self._mat_index[name]
        pbr = {"baseColorFactor": [float(c) for c in color], "metallicFactor": float(metal),
               "roughnessFactor": float(rough)}
        if base_tex is not None:
            pbr["baseColorTexture"] = {"index": base_tex}
        if mr_tex is not None:
            pbr["metallicRoughnessTexture"] = {"index": mr_tex}
        m = {"name": name, "pbrMetallicRoughness": pbr}
        if emissive is not None:
            m["emissiveFactor"] = [float(min(1.0, c)) for c in emissive[:3]]
            if emissive_strength is not None and emissive_strength != 1.0:
                m.setdefault("extensions", {})["KHR_materials_emissive_strength"] = {
                    "emissiveStrength": float(emissive_strength)}
                ext = self.j.setdefault("extensionsUsed", [])
                if "KHR_materials_emissive_strength" not in ext:
                    ext.append("KHR_materials_emissive_strength")
        if emissive_tex is not None:
            m["emissiveTexture"] = {"index": emissive_tex}
            m.setdefault("emissiveFactor", [1.0, 1.0, 1.0])
        if normal_tex is not None:
            m["normalTexture"] = {"index": normal_tex}
        if alpha_mode:
            m["alphaMode"] = alpha_mode
        if alpha_cutoff is not None:
            m["alphaCutoff"] = float(alpha_cutoff)
        if double_sided:
            m["doubleSided"] = True
        if extras:
            m["extras"] = extras
        self.j["materials"].append(m)
        self._mat_index[name] = len(self.j["materials"]) - 1
        return self._mat_index[name]

    # --- meshes / nodes --------------------------------------------------------------------------
    def mesh(self, name, prims, extras=None):
        """prims: [dict(pos Nx3, nor Nx3, idx M (flat), uv Nx2|None, col Nx4 uint8|None, material index)]"""
        out = []
        for p in prims:
            attrs = {"POSITION": self._accessor(p["pos"].astype(np.float32), FLOAT, "VEC3", ARRAY_BUFFER, minmax=True),
                     "NORMAL": self._accessor(p["nor"].astype(np.float32), FLOAT, "VEC3", ARRAY_BUFFER)}
            if p.get("uv") is not None:
                attrs["TEXCOORD_0"] = self._accessor(p["uv"].astype(np.float32), FLOAT, "VEC2", ARRAY_BUFFER)
            if p.get("uv2") is not None:
                attrs["TEXCOORD_1"] = self._accessor(p["uv2"].astype(np.float32), FLOAT, "VEC2", ARRAY_BUFFER)
            if p.get("col") is not None:
                attrs["COLOR_0"] = self._accessor(p["col"].astype(np.uint8), UBYTE, "VEC4", ARRAY_BUFFER, normalized=True)
            idx = p["idx"]
            n = p["pos"].shape[0]
            if n <= 65535:
                ia = self._accessor(idx.astype(np.uint16), USHORT, "SCALAR", ELEMENT_ARRAY_BUFFER)
            else:
                ia = self._accessor(idx.astype(np.uint32), UINT, "SCALAR", ELEMENT_ARRAY_BUFFER)
            out.append({"attributes": attrs, "indices": ia, "material": p["material"], "mode": 4})
        m = {"name": name, "primitives": out}
        if extras:
            m["extras"] = extras
        self.j["meshes"].append(m)
        return len(self.j["meshes"]) - 1

    def node(self, name, mesh=None, translation=None, rotation=None, scale=None, children=None, extras=None, root=False):
        n = {"name": name}
        if mesh is not None:
            n["mesh"] = mesh
        if translation is not None:
            n["translation"] = [float(x) for x in translation]
        if rotation is not None:
            n["rotation"] = [float(x) for x in rotation]
        if scale is not None:
            n["scale"] = [float(x) for x in scale]
        if children:
            n["children"] = list(children)
        if extras:
            n["extras"] = extras
        self.j["nodes"].append(n)
        i = len(self.j["nodes"]) - 1
        if root:
            self.j["scenes"][0]["nodes"].append(i)
        return i

    def add_child(self, parent, child):
        self.j["nodes"][parent].setdefault("children", []).append(child)

    def write(self, path, extras=None):
        if extras:
            self.j["scenes"][0]["extras"] = extras
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
