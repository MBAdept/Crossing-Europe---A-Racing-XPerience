#!/usr/bin/env python3
"""QA-R7c: mutation tests in the scratch copy m1/QA-R7c/mut. Each mutation breaks one rule of R7c with one line, runs the
named unit test filters (tools/run_tests.sh <filter> equivalent: tests/run_tests.gd --filter) and/or render checks
(tools/run_render_checks.sh modern <filter>), records whether they turn red, then restores the file from the R7c
worktree. Usage: mutate.py [ids...]"""
import os, subprocess, sys, shutil, time

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c"
MUT = S + "/mut"
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-7"
P = "scripts/race3d/builders/props.gd"
INC = "assets/shaders/modern/inc/lod_band.gdshaderinc"

# id, file, old, new, unit filters, render filters
MUTS = [
    ("U1_band_misaligned", P, "\t\tVector4(d0 - w0, d0 + w0, d1 - w1 if", "\t\tVector4(d0, d0 + w0, d1 - w1 if", ["test_props"], []),
    ("U2_nodes_always_on", P, "\t\t\tn3.visible = span.y >= b.x and span.x <= b.w\n", "\t\t\tn3.visible = true\n", ["test_props"], []),
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
    ("R1_no_dither", INC, "\treturn t < 1.0 - fin || t >= fout;\n", "\treturn false;\n", ["test_props"], ["check_lod_band"]),
    ("R2_shadow_dithers", INC, "\tif (shadow > 0.5) {\n", "\tif (shadow > 5.0) {\n", ["test_props"], ["check_lod_band"]),
    ("R2b_shadow_band_middle", INC, "\t\treturn fin < 1.0 || fout <= 0.0;\n",
     "\t\treturn d < 0.5 * (lod_band.x + lod_band.y) || d > 0.5 * (lod_band.z + lod_band.w);\n", [], ["check_lod_band"]),
    ("R3_far_light_off", INC, "\treturn mix(att, min(att, far_sun), smoothstep(shadow_far.x, shadow_far.y, depth));\n", "\treturn att;\n",
     ["test_props"], ["check_lod_band", "check_props_render"]),
    ("R4_window_cover_off", "assets/shaders/modern/baked.gdshader",
     "\tfloat cover_k = window_cover * step(0.001, emit_energy) * clamp(max(e.r, max(e.g, e.b)) * 3.0, 0.0, 1.0) * night_k;\n",
     "\tfloat cover_k = 0.0;\n", ["test_props"], ["check_props_render"]),
    ("R5_cutout_bias_off", "assets/shaders/modern/baked.gdshader", "\tif (texture(albedo_tex, UV, cutout_bias).a < 0.5) {\n",
     "\tif (texture(albedo_tex, UV).a < 0.5) {\n", ["test_props"], []),
    ("R6_relief_night_off", "assets/shaders/modern/billboard.gdshader",
     "\t\tt.rgb = mix(t.rgb, mean, relief_night * clamp(ce_night, 0.0, 1.0));\n", "\t\tt.rgb = t.rgb;\n", ["test_props"], []),
]


def run(cmd, log, timeout, render=False):
    env = dict(os.environ)
    env["XDG_DATA_HOME"] = S + "/xdg_mut"
    env["MESA_SHADER_CACHE_DIR"] = S + "/mesa_mut"
    env["LP_NUM_THREADS"] = "2"
    os.makedirs(env["XDG_DATA_HOME"], exist_ok=True)
    os.makedirs(env["MESA_SHADER_CACHE_DIR"], exist_ok=True)
    t0 = time.time()
    with open(log, "w") as f:
        try:
            p = subprocess.run(["nice", "-n", "10"] + cmd, cwd=MUT, stdout=f, stderr=subprocess.STDOUT, env=env, timeout=timeout)
            code = p.returncode
        except subprocess.TimeoutExpired:
            code = "timeout"
    return code, time.time() - t0


def memwait():
    while True:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemAvailable"):
                    kb = int(line.split()[1])
        if kb > 3 * 1048576:
            return
        time.sleep(20)


def main():
    only = sys.argv[1:]
    os.makedirs(S + "/mutlogs", exist_ok=True)
    out = open(S + "/mutlogs/mutate.out", "a")
    for mid, rel, old, new, tests, renders in MUTS:
        if only and mid not in only:
            continue
        path = MUT + "/" + rel
        src = open(path).read()
        if src.count(old) != 1:
            msg = f"{mid}: pattern found {src.count(old)} times - SKIPPED"
            print(msg, flush=True)
            out.write(msg + "\n")
            continue
        open(path, "w").write(src.replace(old, new))
        res = []
        try:
            for t in tests:
                memwait()
                log = f"{S}/mutlogs/{mid}_{t}.log"
                code, dt = run(["godot", "--headless", "--path", ".", "-s", "res://tests/run_tests.gd", "--", f"--filter={t}"], log, 900)
                txt = open(log, errors="replace").read()
                summary = [l for l in txt.splitlines() if "Tests," in l and "fehlgeschlagen" in l]
                perr = "PARSE/SCRIPT ERROR" if ("Parse Error" in txt or "SCRIPT ERROR" in txt) else ""
                res.append(f"{t}: exit {code} {summary[-1].strip() if summary else '?'} {perr} ({dt:.0f} s)")
            for rc in renders:
                memwait()
                log = f"{S}/mutlogs/{mid}_{rc}.log"
                code, dt = run(["tools/run_render_checks.sh", "modern", rc], log, 1800, True)
                txt = open(log, errors="replace").read()
                lines = [l.strip() for l in txt.splitlines() if l.startswith("RENDER-CHECK ") and "FEHLER" in l]
                files = [l.strip() for l in txt.splitlines() if l.startswith("RENDER-CHECK-DATEI")]
                res.append(f"{rc}: exit {code} {'; '.join(files)} {('| ' + ' | '.join(lines))[:400] if lines else ''} ({dt:.0f} s)")
        finally:
            shutil.copyfile(WT + "/" + rel, path)
        msg = f"{mid} ({rel}): " + " || ".join(res)
        print(msg, flush=True)
        out.write(msg + "\n")
        out.flush()


if __name__ == "__main__":
    main()
