import json, sys
d = json.load(open(sys.argv[1]))
CH = ["tail","brake","tail_brake","ind_l","ind_r","head","drl","reverse","plate","marker","beacon_a","beacon_b","lights","on","flood","reserved"]
for path in sorted(d):
    m = d[path]
    print("=" * 110)
    print(path, "class", m["class"], "bytes", m["bytes"], "uid", m.get("uid"), "deps", m.get("deps"), "name=%r" % m.get("resource_name"),
          "blend", m.get("blend_shapes"), "shadow_mesh", m.get("shadow_mesh"), "custom_aabb", m.get("custom_aabb"))
    print("  aabb", [round(x, 4) for x in m["aabb"]])
    for s in m["surfaces"]:
        print("  surface %-12s verts %6d tris %6d area %8.2f m2  fmt %s  compressed %s  normal %s tangent %s color %s uv %s uv2 %s custom %s bones %s material %s prim %s" % (
            s["name"], s["verts"], s["tris"], s["area_m2"], s["format"], s["compressed"], s["has_normal"], s["has_tangent"], s["has_color"], s["has_uv"], s["has_uv2"], s["has_custom"], s["has_bones"], s["material"], s["primitive"]))
        print("     stored keys", s.get("stored_keys"), "vertex/attr/index bytes", s.get("vertex_bytes"), s.get("attr_bytes"), s.get("index_bytes"), "uv_scale", s.get("uv_scale"), "auto lods", s.get("lods"))
        print("     normals bad length %d, winding agree %d / against %d, degenerate %d, mixed code tris %d, mixed lamp tris %d" % (
            s["normals_bad_length"], s["winding_agree"], s["winding_against"], s["degenerate"], s["mixed_code_tris"], s["mixed_lamp_tris"]))
        if s.get("uv_range"):
            print("     uv range", [round(x, 4) for x in s["uv_range"]])
        if s["name"] == "vpbr":
            print("     paint codes (vertices):", dict(sorted(s["code_hist_vertices"].items(), key=lambda kv: float(kv[0]))))
            print("     paint codes (tris):", dict(sorted(s["code_tris"].items(), key=lambda kv: float(kv[0]))), " area:", {k: round(v, 3) for k, v in sorted(s["code_area"].items(), key=lambda kv: float(kv[0]))})
            print("     UV2.x (vertices):", dict(sorted(s["uv2x_hist_vertices"].items(), key=lambda kv: float(kv[0]))))
            for k in sorted(s["lamp_tris"], key=float):
                v = float(k)
                if v < 0:
                    continue
                ch = int(v)
                b = s["lamp_bounds"][k]
                print("       ch %2d %-10s raw %-7s tris %5d area %8.1f cm2  bounds x[%.3f %.3f] y[%.3f %.3f] z[%.3f %.3f]  weights %s  colours %s" % (
                    ch, CH[ch] if ch < len(CH) else "?", k, s["lamp_tris"][k], s["lamp_area"][k] * 1e4, b[0], b[3], b[1], b[4], b[2], b[5], s["lamp_weights"][k], s["lamp_colors"].get(k)))
            rm = sorted(s["rough_metal_tris"].items(), key=lambda kv: -kv[1])
            print("     rough/metal (tris):", rm[:14], "... %d combos" % len(rm))
        if s["name"] == "glass":
            print("     glass colours:", s.get("glass_colors"))
            rm = sorted(s["rough_metal_tris"].items(), key=lambda kv: -kv[1])
            print("     rough/metal (tris):", rm[:10])
        if s["name"] == "leaves":
            print("     leaf colour range (r amp, g phase, b stiff, a bright) min/max:", [round(x, 3) for x in s["leaf_color_range"]], "normals outward share", round(s["leaf_normals_outward"], 3))
