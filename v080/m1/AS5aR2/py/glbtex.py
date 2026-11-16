"""AS5aR2: texel density of the triangles of a model.glb (cache) inside a box (glTF coords, y up):
   python3 glbtex.py <glb> <atlas w> <atlas h> x0,x1,y0,y1,z0,z1 [min area]"""
import json
import struct
import sys

import numpy as np

p = sys.argv[1]
W, H = int(sys.argv[2]), int(sys.argv[3])
box = [float(v) for v in sys.argv[4].split(",")]
amin = float(sys.argv[5]) if len(sys.argv) > 5 else 0.05
b = open(p, "rb").read()
jl = struct.unpack("<I", b[12:16])[0]
js = json.loads(b[20:20 + jl])
bin0 = 20 + jl + 8
CT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def acc(i):
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    off = bin0 + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = a["count"] * NC[a["type"]]
    dt = np.dtype(CT[a["componentType"]])
    return np.frombuffer(b[off:off + n * dt.itemsize], dtype=dt).reshape(a["count"], NC[a["type"]])


for m in js["meshes"]:
    for pr in m["primitives"]:
        if "TEXCOORD_0" not in pr["attributes"]:
            continue
        P = acc(pr["attributes"]["POSITION"]).astype(np.float64)
        U = acc(pr["attributes"]["TEXCOORD_0"]).astype(np.float64)
        I = acc(pr["indices"]).reshape(-1, 3)
        a, bb, c = P[I[:, 0]], P[I[:, 1]], P[I[:, 2]]
        ctr = (a + bb + c) / 3
        sel = ((ctr[:, 0] > box[0]) & (ctr[:, 0] < box[1]) & (ctr[:, 1] > box[2]) & (ctr[:, 1] < box[3])
               & (ctr[:, 2] > box[4]) & (ctr[:, 2] < box[5]))
        cr = np.cross(bb - a, c - a)
        area = np.linalg.norm(cr, axis=1) * 0.5
        ua, ub, uc = U[I[:, 0]] * [W, H], U[I[:, 1]] * [W, H], U[I[:, 2]] * [W, H]
        d1, d2 = ub - ua, uc - ua
        uar = np.abs(d1[:, 0] * d2[:, 1] - d1[:, 1] * d2[:, 0]) * 0.5
        dens = np.sqrt(uar / np.maximum(area, 1e-9))
        nrm = cr / np.maximum(np.linalg.norm(cr, axis=1), 1e-9)[:, None]
        for k in np.nonzero(sel & (area > amin))[0][:60]:
            print("%s mat %s ctr %s n %s area %.2f dens %.1f" % (m.get("name"), pr.get("material"), np.round(ctr[k], 2),
                                                                  np.round(nrm[k], 2), area[k], dens[k]))
