#!/usr/bin/env python3
"""NACH-R7c: one-line mutations on the FIX-R7c head, applied IN the NACH-R7c worktree (no commits) and restored from
`git show HEAD:<file>` after each run. Runs the unit test filter test_props and, for render mutations, the render
check check_lod_band. Usage: mutate.py [ids...]   (writes logs to m1/NACH-R7c/mutlogs, summary mutate.out)"""
import os, subprocess, sys, time

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7c"
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-12"
P = "scripts/race3d/builders/props.gd"
INC = "assets/shaders/modern/inc/lod_band.gdshaderinc"
BAKED = "assets/shaders/modern/baked.gdshader"

MUTS = [
    # QA-R7c mutations that FIX-R7c says are caught now (re-run on the final head)
    ("U3_phase_constant", P, "\treturn hash01(seg_index, item, 29) * 0.999\n", "\treturn 0.0\n", ["test_props"], []),
    ("U4_sink_noop", P, "\t\th = minf(h, ctx.ground(z + cos(a) * r, x + sin(a) * r))\n", "\t\tpass\n", ["test_props"], []),
    ("U5_align_noop", P, "\treturn Basis(axis, minf(ang, deg_to_rad(ALIGN_MAX_DEG))) * basis\n", "\treturn basis\n", ["test_props"], []),
    ("U7_far_sun_not_set", P, "\t\t\tm.set_shader_parameter(\"far_sun\", fs)\n", "\t\t\tm.set_shader_parameter(\"far_sun\", 1.0)\n", ["test_props"], []),
    ("U8_leaves_phase_world", "assets/shaders/modern/leaves.gdshader",
     "\tfloat tree = INSTANCE_CUSTOM.a > 0.5 ? fract(INSTANCE_CUSTOM.a) * 37.0 : wp.x * 0.37 + wp.z * 0.23;\n",
     "\tfloat tree = wp.x * 0.37 + wp.z * 0.23;\n", ["test_props"], []),
    ("U10_attached_never_dropped", P, "\tvar reason := drop_reason(ctx, it, e, z, x, side, seg_index, j, density, cover)\n",
     "\tvar reason := \"\" if bool(it.get(\"attached\", false)) else drop_reason(ctx, it, e, z, x, side, seg_index, j, density, cover)\n",
     ["test_props"], []),
    ("R3_far_light_off", INC, "\treturn mix(att, min(att, far_sun), smoothstep(shadow_far.x, shadow_far.y, depth));\n", "\treturn att;\n",
     ["test_props"], []),
    ("R4_window_cover_off", BAKED,
     "\tfloat cover_k = window_cover * step(0.001, emit_energy) * clamp(max(e.r, max(e.g, e.b)) * 3.0, 0.0, 1.0) * night_k;\n",
     "\tfloat cover_k = 0.0;\n", ["test_props"], []),
    ("R5_cutout_bias_off", BAKED, "\tif (texture(albedo_tex, UV, cutout_bias).a < 0.5) {\n",
     "\tif (texture(albedo_tex, UV).a < 0.5) {\n", ["test_props"], []),
    ("R6_relief_night_off", "assets/shaders/modern/billboard.gdshader",
     "\t\tt.rgb = mix(t.rgb, mean, relief_night * clamp(ce_night, 0.0, 1.0));\n", "\t\tt.rgb = t.rgb;\n", ["test_props"], []),
    # new mutations against the FIX-R7c code itself
    ("N1_no_threshold_refresh", P, "\t\t_thresholds(h)          # new bands and shadow reach: new thresholds (and no stale key)\n",
     "\t\tpass\n", ["test_props"], []),
    ("N2_still_clock_dt", P, "\tif not is_nan(view_time):\n", "\tif false:\n", ["test_props"], []),
    ("N3_no_caster_threshold", P, "\tvar hi := PackedFloat32Array([_shadow_m + SHADOW_KEEP_M])\n", "\tvar hi := PackedFloat32Array()\n",
     ["test_props"], []),
    ("N4_far_corner_min", P, "\t\tvar far := (p - wb.position).abs().max((wb.end - p).abs()).length()\n",
     "\t\tvar far := (p - wb.position).abs().min((wb.end - p).abs()).length()\n", ["test_props"], []),
    ("N5_still_global_never_set", P, "\t\tModernMaterials.set_global(\"ce_lod_still\", _still)\n", "\t\tpass\n", ["test_props"], []),
    ("N6_shader_still_ignored", INC, "\tfloat still = clamp(ce_lod_still, 0.0, 1.0);\n", "\tfloat still = 0.0;\n", ["test_props"], ["check_lod_band"]),
    ("R2_shadow_dithers", INC, "\tif (shadow > 0.5) {\n", "\tif (shadow > 5.0) {\n", [], ["check_lod_band"]),
]


def run(cmd, log, timeout):
    env = dict(os.environ)
    env["XDG_DATA_HOME"] = S + "/xdg_mut"
    env["MESA_SHADER_CACHE_DIR"] = S + "/mesa"
    env["LP_NUM_THREADS"] = "2"
    os.makedirs(env["XDG_DATA_HOME"], exist_ok=True)
    t0 = time.time()
    with open(log, "w") as f:
        try:
            p = subprocess.run(["nice", "-n", "10"] + cmd, cwd=WT, stdout=f, stderr=subprocess.STDOUT, env=env, timeout=timeout)
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


def head_text(rel):
    return subprocess.run(["git", "show", "HEAD:" + rel], cwd=WT, capture_output=True, text=True, check=True).stdout


def main():
    only = sys.argv[1:]
    os.makedirs(S + "/mutlogs", exist_ok=True)
    out = open(S + "/mutlogs/mutate.out", "a")
    for mid, rel, old, new, tests, renders in MUTS:
        if only and mid not in only:
            continue
        path = WT + "/" + rel
        orig = head_text(rel)
        src = open(path).read()
        if src != orig:
            msg = f"{mid}: {rel} differs from HEAD before the mutation - STOP"
            print(msg, flush=True)
            out.write(msg + "\n")
            return
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
                fails = [l.strip() for l in txt.splitlines() if "FAIL" in l or "FEHLER" in l][:3]
                perr = "PARSE/SCRIPT ERROR" if ("Parse Error" in txt or "SCRIPT ERROR" in txt) else ""
                res.append(f"{t}: exit {code} {summary[-1].strip() if summary else '?'} {perr} ({dt:.0f} s) {' | '.join(fails)[:300]}")
            for rc in renders:
                memwait()
                log = f"{S}/mutlogs/{mid}_{rc}.log"
                code, dt = run(["tools/run_render_checks.sh", "modern", rc], log, 1800)
                txt = open(log, errors="replace").read()
                lines = [l.strip() for l in txt.splitlines() if l.startswith("RENDER-CHECK ") and "FEHLER" in l]
                files = [l.strip() for l in txt.splitlines() if l.startswith("RENDER-CHECK-DATEI")]
                res.append(f"{rc}: exit {code} {'; '.join(files)} {('| ' + ' | '.join(lines))[:400] if lines else ''} ({dt:.0f} s)")
        finally:
            open(path, "w").write(orig)
        msg = f"{mid} ({rel}): " + " || ".join(res)
        print(msg, flush=True)
        out.write(msg + "\n")
        out.flush()
    st = subprocess.run(["git", "status", "--porcelain", "--untracked-files=no"], cwd=WT, capture_output=True, text=True).stdout
    out.write(f"git status after: {st.strip() or 'clean'}\n")
    out.close()


if __name__ == "__main__":
    main()
