#!/usr/bin/env python3
"""FIX-R7c: QA-R7c's one-line mutations against the guards of this tree (in the worktree itself, one at a time; the file is
restored from memory after each run and checked against git). Usage: mutate.py [ids...] (unit: test_props; render: the
named render check files)."""
import os, subprocess, sys, time

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c"
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-10"
P = "scripts/race3d/builders/props.gd"
INC = "assets/shaders/modern/inc/lod_band.gdshaderinc"
BK = "assets/shaders/modern/baked.gdshader"

MUTS = [
    ("U1_band_misaligned", P, "\t\tVector4(d0 - w0, d0 + w0, d1 - w1 if", "\t\tVector4(d0, d0 + w0, d1 - w1 if", ["test_props"], []),
    ("U2_nodes_always_on", P, "\t\t\tn3.visible = span.y >= b.x - LOD_STEP_M and span.x <= b.w + LOD_STEP_M\n", "\t\t\tn3.visible = true\n", ["test_props"], []),
    ("U3_phase_constant", P, "\treturn hash01(seg_index, item, 29) * 0.999\n", "\treturn 0.0\n", ["test_props"], []),
    ("U4_sink_noop", P, "\t\th = minf(h, ctx.ground(z + cos(a) * r, x + sin(a) * r))\n", "\t\tpass\n", ["test_props"], []),
    ("U5_align_noop", P, "\treturn Basis(axis, minf(ang, deg_to_rad(ALIGN_MAX_DEG))) * basis\n", "\treturn basis\n", ["test_props"], []),
    ("U6_attach_not_mirrored", P, "\tvar ox := -off.x if flipped else off.x\n", "\tvar ox := off.x\n", ["test_props"], []),
    ("U7_far_sun_not_set", P, "\t\t\tm.set_shader_parameter(\"far_sun\", fs)\n", "\t\t\tm.set_shader_parameter(\"far_sun\", 1.0)\n", ["test_props"], []),
    ("U8_leaves_phase_world", "assets/shaders/modern/leaves.gdshader",
     "\tfloat tree = INSTANCE_CUSTOM.a > 0.5 ? fract(INSTANCE_CUSTOM.a) * 37.0 : wp.x * 0.37 + wp.z * 0.23;\n",
     "\tfloat tree = wp.x * 0.37 + wp.z * 0.23;\n", ["test_props"], []),
    ("U10_attached_never_dropped", P, "\tvar reason := drop_reason(ctx, it, e, z, x, side, seg_index, j, density, cover)\n",
     "\tvar reason := \"\" if bool(it.get(\"attached\", false)) else drop_reason(ctx, it, e, z, x, side, seg_index, j, density, cover)\n",
     ["test_props"], []),
    ("U11_tag_override_ignored", P, "\t\t\treturn float(_lod0_override[\"tag:\" + str(t)])\n", "\t\t\treturn 0.0\n", ["test_props"], []),
    ("U12_margin_off", P, "\t\t\tn3.visible = span.y >= b.x - LOD_STEP_M and span.x <= b.w + LOD_STEP_M\n",
     "\t\t\tn3.visible = span.y >= b.x and span.x <= b.w\n", ["test_props"], []),
    ("U13_still_never", P, "\treturn move_toward(still, 1.0 if speed < LOD_STILL_SPEED else 0.0, dt / LOD_STILL_S)\n",
     "\treturn 0.0\n", ["test_props"], []),
    ("U14_attach_beyond_chunk", P, "\t\t\tif float(ai[\"z\"]) < z_lo or float(ai[\"z\"]) >= z_hi:\n", "\t\t\tif false:\n", ["test_props"], []),
    ("U15_albedo_one_for_all", P, "\tvar v: Variant = _albedo_bias.get(model_id, _albedo_bias.get(\"default\", 0.0))\n",
     "\tvar v: Variant = _albedo_bias.get(\"default\", 0.0)\n", ["test_props"], []),
    ("R1_no_dither", INC, "\treturn t < 1.0 - fin || t >= fout;\n", "\treturn false;\n", ["test_props"], ["check_lod_band"]),
    ("R2_shadow_dithers", INC, "\tif (shadow > 0.5) {\n", "\tif (shadow > 5.0) {\n", ["test_props"], ["check_lod_band"]),
    ("R2b_shadow_band_middle", INC, "\t\treturn fin < 1.0 || fout <= 0.0;\n",
     "\t\treturn d < 0.5 * (lod_band.x + lod_band.y) || d > 0.5 * (lod_band.z + lod_band.w);\n", [], ["check_lod_band"]),
    ("R3_far_light_off", INC, "\treturn mix(att, min(att, far_sun), smoothstep(shadow_far.x, shadow_far.y, depth));\n", "\treturn att;\n",
     ["test_props"], ["check_lod_band"]),
    ("R4_window_cover_off", BK,
     "\tfloat cover_k = window_cover * step(0.001, emit_energy) * clamp(max(e.r, max(e.g, e.b)) * 3.0, 0.0, 1.0) * night_k;\n",
     "\tfloat cover_k = 0.0;\n", ["test_props"], []),
    ("R5_cutout_bias_off", BK, "\tif (texture(albedo_tex, UV, cutout_bias).a < 0.5) {\n",
     "\tif (texture(albedo_tex, UV).a < 0.5) {\n", ["test_props"], []),
    ("R6_relief_night_off", "assets/shaders/modern/billboard.gdshader",
     "\t\tt.rgb = mix(t.rgb, mean, relief_night * clamp(ce_night, 0.0, 1.0));\n", "\t\tt.rgb = t.rgb;\n", ["test_props"], []),
    ("R7_still_off", INC, "\tif (still > 0.0) {\n", "\tif (still > 5.0) {\n", ["test_props"], ["check_lod_band"]),
    ("R8_still_to_middle", INC, "\t\tb = vec4(b.y - w.x, b.y, b.w - w.y, b.w);\n",
     "\t\tb = vec4(b.y - w.x * 0.5 - (b.y - b.x) * 0.5, b.y + w.x * 0.5 - (b.y - b.x) * 0.5, b.w - w.y * 0.5 - (b.w - b.z) * 0.5, b.w + w.y * 0.5 - (b.w - b.z) * 0.5);\n",
     [], ["check_lod_band"]),
]


def env():
    e = dict(os.environ)
    e["XDG_DATA_HOME"] = S + "/xdg_mut"
    e["MESA_SHADER_CACHE_DIR"] = S + "/mesa"
    e["LP_NUM_THREADS"] = "2"
    os.makedirs(e["XDG_DATA_HOME"], exist_ok=True)
    return e


def run(cmd, log, timeout):
    t0 = time.time()
    with open(log, "w") as f:
        try:
            p = subprocess.run(["nice", "-n", "10"] + cmd, cwd=WT, stdout=f, stderr=subprocess.STDOUT, env=env(), timeout=timeout)
            code = p.returncode
        except subprocess.TimeoutExpired:
            code = "timeout"
    return code, time.time() - t0


def main():
    only = sys.argv[1:]
    unit_only = "--unit" in only
    render_only = "--render" in only
    only = [o for o in only if not o.startswith("--")]
    os.makedirs(S + "/mutlogs", exist_ok=True)
    out = open(S + "/mutlogs/mutate.out", "a")
    for mid, rel, old, new, tests, renders in MUTS:
        if only and mid not in only:
            continue
        path = os.path.join(WT, rel)
        orig = open(path, encoding="utf-8").read()
        if orig.count(old) != 1:
            line = "%s SKIP: Zeile %d mal gefunden" % (mid, orig.count(old))
            print(line); out.write(line + "\n"); out.flush()
            continue
        open(path, "w", encoding="utf-8").write(orig.replace(old, new))
        res = []
        try:
            for t in ([] if render_only else tests):
                log = "%s/mutlogs/%s_%s.log" % (S, mid, t)
                code, dt = run(["godot", "--headless", "--path", ".", "-s", "res://tests/run_tests.gd", "--", "--filter=" + t], log, 900)
                txt = open(log, encoding="utf-8", errors="replace").read()
                fails = [l for l in txt.splitlines() if l.startswith("FAIL") or "SCRIPT ERROR" in l]
                caught = code != 0 or len(fails) > 0
                res.append("%s %s (%s, %.0f s)%s" % (t, "GEFANGEN" if caught else "gruen", code, dt,
                    (": " + fails[0][:140]) if fails else ""))
            if not unit_only:
                for r in renders:
                    log = "%s/mutlogs/%s_%s.log" % (S, mid, r)
                    code, dt = run(["tools/run_render_checks.sh", "modern", r], log, 2400)
                    txt = open(log, encoding="utf-8", errors="replace").read()
                    bad = [l for l in txt.splitlines() if "FEHLER" in l and "RENDER-CHECK " in l]
                    caught = code != 0
                    res.append("%s %s (%s, %.0f s)%s" % (r, "GEFANGEN" if caught else "gruen", code, dt, (": " + bad[0][:160]) if bad else ""))
        finally:
            open(path, "w", encoding="utf-8").write(orig)
        line = "%s  %s" % (mid, " | ".join(res))
        print(line); out.write(line + "\n"); out.flush()
    d = subprocess.run(["git", "status", "--short"], cwd=WT, capture_output=True, text=True).stdout
    print("git status nach den Mutationen:\n" + d)


if __name__ == "__main__":
    main()
