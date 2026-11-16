#!/usr/bin/env python3
"""Summarise the mesh dumps: per model and level, paint-code share of the area seen from behind (chase view), the
fixed-colour albedo, mixed-code triangles, glass, lamps – and the difference lod0 -> lod1 -> lod2."""
import json
import sys

VIEW = "rear5"


def level_stats(level):
    tot = {}
    tot_all = 0.0
    glass = 0.0
    mixed = 0
    against = 0
    tris = 0
    alpha_vals = {}
    alb_fixed = [0.0, 0.0, 0.0]
    alb_fixed_w = 0.0
    for part in level["parts"]:
        node = part.get("node", "")
        if "wheel" in node:
            continue
        for s in part.get("surfaces", []):
            tris += s["tris"]
            mixed += s["mixed_code_tris"]
            against += s["normal_against_face"]
            for k, v in s.get("alpha_values", {}).items():
                alpha_vals[k] = alpha_vals.get(k, 0) + v
            for code, e in s["codes"].items():
                pa = e["proj"].get(VIEW, 0.0)
                if s["name"] == "glass":
                    glass += pa
                    tot_all += pa
                    continue
                tot[code] = tot.get(code, 0.0) + pa
                tot_all += pa
                if code == "fixed":
                    for i in range(3):
                        alb_fixed[i] += e["alb"][i] * pa
                    alb_fixed_w += pa
    share = {k: round(v / tot_all, 3) for k, v in tot.items()} if tot_all > 0 else {}
    share["glass_class"] = round(glass / tot_all, 3) if tot_all > 0 else 0
    fixed_alb = [round(c / alb_fixed_w, 3) for c in alb_fixed] if alb_fixed_w > 0 else None
    return {"tris": tris, "proj_m2": round(tot_all, 3), "share": share, "fixed_alb": fixed_alb, "mixed": mixed,
            "against": against, "alphas": dict(sorted(alpha_vals.items()))}


def main():
    for path in sys.argv[1:]:
        d = json.load(open(path))
        print("=====", path.split("/")[-1])
        for mid in sorted(d):
            levels = d[mid]
            print(mid)
            for ln in ("lod0", "lod1", "lod2", "show", "shadow"):
                if ln not in levels:
                    continue
                st = level_stats(levels[ln])
                print("  %-6s tris %6d  proj %.2f m2  share %s  fixed_alb %s  mixedtris %d  against %d  alphas %s" % (
                    ln, st["tris"], st["proj_m2"], st["share"], st["fixed_alb"], st["mixed"], st["against"],
                    st["alphas"]))


if __name__ == "__main__":
    main()
