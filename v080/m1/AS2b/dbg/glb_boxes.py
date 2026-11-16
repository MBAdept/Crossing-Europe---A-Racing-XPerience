"""AS2b: per-node AABBs of a cached ce3d GLB (model space, node translation applied).

usage: python3 glb_boxes.py <model.glb> [name-filter] [--ymin=Y]
--ymin: AABB only over vertices above Y (e.g. cab above the chassis)."""
import json
import struct
import sys

import numpy as np


def load(path):
    data = open(path, "rb").read()
    magic, ver, length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF", magic
    off = 12
    js = None
    binc = None
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            binc = chunk
        off += 8 + clen
    return js, binc


def positions(js, binc, acc_i):
    acc = js["accessors"][acc_i]
    bv = js["bufferViews"][acc["bufferView"]]
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    n = acc["count"]
    stride = bv.get("byteStride", 12)
    raw = np.frombuffer(binc, dtype=np.uint8, count=stride * (n - 1) + 12, offset=start)
    out = np.empty((n, 3), dtype=np.float32)
    for i in range(3):
        out[:, i] = np.ndarray((n,), dtype=np.float32, buffer=raw.tobytes(), offset=4 * i, strides=(stride,))
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    ymin = None
    xmax = None
    for a in sys.argv[1:]:
        if a.startswith("--ymin="):
            ymin = float(a.split("=", 1)[1])
        if a.startswith("--xmax="):
            xmax = float(a.split("=", 1)[1])
    js, binc = load(args[0])
    flt = args[1] if len(args) > 1 else ""
    # parent map for translations
    parent = {}
    for i, nd in enumerate(js["nodes"]):
        for c in nd.get("children", []):
            parent[c] = i

    def world_t(i):
        t = np.zeros(3)
        while i is not None:
            t += np.array(js["nodes"][i].get("translation", [0, 0, 0]))
            i = parent.get(i)
        return t

    def full_name(i):
        names = []
        while i is not None:
            names.append(js["nodes"][i].get("name", "?"))
            i = parent.get(i)
        return "/".join(reversed(names))

    for i, nd in enumerate(js["nodes"]):
        if "mesh" not in nd:
            continue
        name = full_name(i)
        if flt and flt not in name:
            continue
        pts = []
        for prim in js["meshes"][nd["mesh"]]["primitives"]:
            pts.append(positions(js, binc, prim["attributes"]["POSITION"]))
        p = np.concatenate(pts) + world_t(i)
        if ymin is not None:
            p = p[p[:, 1] > ymin]
        if xmax is not None:
            p = p[np.abs(p[:, 0]) <= xmax]
        if len(p) == 0:
            continue
        lo = p.min(axis=0)
        hi = p.max(axis=0)
        print("%-40s x %7.3f..%7.3f  y %6.3f..%6.3f  z %7.3f..%7.3f" % (name, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))


main()
