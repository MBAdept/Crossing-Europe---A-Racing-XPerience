#!/usr/bin/env python3
"""Fix-wave helper: prints the lamp areas, winding and anchors of an inspect_models.gd report."""
import json, sys
r = json.load(open(sys.argv[1]))
only = sys.argv[2] if len(sys.argv) > 2 else ""
CH = ["tail", "brake", "tail_brake", "ind_l", "ind_r", "head", "drl", "reverse", "plate", "marker", "beacon_a", "beacon_b", "lights", "on", "flood"]
for f in sorted(r["meshes"]):
    if only and only not in f:
        continue
    m = r["meshes"][f]
    for s in m["surfaces"]:
        w = s.get("winding", {})
        if s.get("lamps"):
            print("==", f, "winding", w)
            for k in sorted(s["lamps"], key=lambda k: (int(k.split("|")[0]), k)):
                e = s["lamps"][k]
                ch, end = k.split("|")
                b = e["bounds"]
                print("   %-10s %-5s tris %4d area %7.1f cm2 back %7.1f front %7.1f side %7.1f  x %.3f..%.3f z %.3f..%.3f" % (
                    CH[int(ch)], end, e["tris"], e["area"] * 1e4, e["back"] * 1e4, e["front"] * 1e4, e["side"] * 1e4, b[0], b[3], b[2], b[5]))
            if s.get("lamp_lods"):
                print("   auto levels:", [{CH[int(k)]: round(v * 1e4, 1) for k, v in lv.items()} for lv in s["lamp_lods"]])
        elif w.get("against"):
            print("==", f, s["name"], "winding", w)
for mid, a in r.get("anchors", {}).items():
    if only and only.split("/")[0] not in mid:
        continue
    print("ANCHORS", mid)
    for e in a:
        print("   %-8s pos %s dist %6.1f mm below %6.1f mm dir_dot %.2f" % (e["role"], e["pos"], e["dist_mm"], e["below_mm"], e["dir_dot"]))
