"""Lamp areas (cm2, projected, by winding) and anchor distances of the AS1 models from inspect.json."""
import json
import sys

d = json.load(open(sys.argv[1]))
out = []
for path, m in sorted(d["meshes"].items()):
    if not (path.startswith("player/") or path.startswith("traffic/")):
        continue
    acc = {}
    for srf in m.get("surfaces", []):
        for key, v in (srf.get("lamps") or {}).items():
            ch, end = key.split("|")
            view = "back" if end == "rear" else "front"
            acc[(int(ch), end)] = acc.get((int(ch), end), 0.0) + v[view] * 1e4
    if not acc:
        continue

    def a(chs, end):
        return sum(acc.get((c, end), 0.0) for c in chs)
    out.append("%-32s hinten: Rueck %5.0f Brems %5.0f Bl-l %4.0f Bl-r %4.0f Rueckf %4.0f Umriss %4.0f Kennz %4.0f | vorn: Scheinw %5.0f TFL %4.0f Bl-l %4.0f Bl-r %4.0f" % (
        path.replace(".res", ""), a([0, 2], "rear"), a([1, 2], "rear"), a([3], "rear"), a([4], "rear"), a([7], "rear"),
        a([9], "rear"), a([8], "rear"), a([5], "front"), a([6], "front"), a([3], "front"), a([4], "front")))
for mid, lst in sorted(d["anchors"].items()):
    if mid.startswith("player") or mid.startswith("traffic"):
        out.append("%-20s Lichtanker %2d, groesster Abstand %.1f mm, tiefster unter der Lampe %.1f mm, Rollen %s" % (
            mid, len(lst), max(x["dist_mm"] for x in lst), max(x["below_mm"] for x in lst),
            ",".join(sorted({x["role"] for x in lst}))))
print("\n".join(out))
