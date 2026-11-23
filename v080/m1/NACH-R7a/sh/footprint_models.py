#!/usr/bin/env python3
"""Compare the footprint model of the push-out patch (reach = width_m/2 for trees/rocks, extent for aligned houses,
no yaw) with each model's AABB from the manifest.
For random-yaw classes (tree, plant, rock): the real reach towards the road is up to the largest horizontal
distance of the AABB from the origin in any direction -> bounded by max(|x|,|z|) (round crowns) and hypot (boxes).
For face_road: yaw up to +-20 deg."""
import json, sys, math
root = sys.argv[1]
m = json.load(open(root + "/assets/models/manifest.json"))
models = m["models"]
rows = []
for mid, md in models.items():
    tags = md.get("tags", [])
    obj = md.get("object", {})
    w = float(obj.get("width_m", 0) or 0)
    L = float(obj.get("length_m", w) or w)
    h = float(obj.get("height_m", 0) or 0)
    kind = md.get("kind", "")
    a = md.get("aabb")
    if h <= 0.5 or not a or kind == "landmark":
        continue
    x0, y0, z0, x1, y1, z1 = a
    r_axis = max(abs(x0), abs(x1), abs(z0), abs(z1))
    r_diag = math.hypot(max(abs(x0), abs(x1)), max(abs(z0), abs(z1)))
    half = 0.5 * w
    fr = "face_road" in tags
    rand = kind in ("tree", "plant", "rock", "vegetation", "cliff") or "ground_sink" in tags
    if rand:
        ex_axis = r_axis - half
        ex_diag = r_diag - half
        rows.append((ex_axis, mid, kind, w, L, h, "rand-yaw: axis +%.2f diag +%.2f" % (ex_axis, ex_diag)))
    if fr:
        ang = math.radians(20)
        # near edge z (towards the road along -z? unknown) - generic: corner of the w x L box rotated by 20 deg
        ext_rot = 0.5 * w * math.sin(ang) + 0.5 * L * math.cos(ang)
        rows.append((ext_rot - 0.5 * L, mid, kind, w, L, h, "face_road: corner +%.2f over half-depth %.1f" % (ext_rot - 0.5 * L, 0.5 * L)))
rows.sort(reverse=True)
for r in rows[: int(sys.argv[2]) if len(sys.argv) > 2 else 60]:
    print("%-40s %-10s w %5.1f L %5.1f h %5.1f  %s" % (r[1], r[2], r[3], r[4], r[5], r[6]))
print("models considered:", len(rows))
