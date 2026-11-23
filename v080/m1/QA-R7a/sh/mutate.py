#!/usr/bin/env python3
"""QA-R7a: mutation tests in the scratch copy m1/QA-R7a/mut. Each mutation breaks one rule with one line, runs the
named unit test files (and optionally modern_sight normal mode), records whether they turn red, then restores the
file from the R7a worktree. Usage: mutate.py [ids...]"""
import os, subprocess, sys, shutil, time

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a"
MUT = S + "/mut"
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-5"

MUTS = [
    ("M1_fan_right", "scripts/race3d/sight_corridor.gd",
     "\t\t\t\t\t\tif w > _wr[wi]:\n\t\t\t\t\t\t\t_wr[wi] = w\n",
     "\t\t\t\t\t\tpass\n", ["test_sight_corridor"], False),
    ("M2_simple_cam_outer", "scripts/race3d/sight_corridor.gd",
     "\t\tvar cx := _grx[qc] if right else _glx[qc]\n\t\tvar cz := _grz[qc] if right else _glz[qc]\n",
     "\t\tvar cx := _glx[qc] if right else _grx[qc]\n\t\tvar cz := _glz[qc] if right else _grz[qc]\n", ["test_sight_corridor"], False),
    ("M3_f2_ratio", "scripts/race3d/sight_corridor.gd",
     "const F2_RATIO := 0.6\n", "const F2_RATIO := 0.7\n", ["test_sight_corridor"], True),
    ("M4_curve_tol", "scripts/race3d/sight_corridor.gd",
     "const CURVE_TOLERANCE := 1.05\n", "const CURVE_TOLERANCE := 1.0\n", ["test_sight_corridor"], False),
    ("M5_terrain_ignores_env", "scripts/race3d/terrain_profile.gd",
     "\t\t\tcorr = maxf(sight.width(k, -1 if si == 0 else 1), corr + BEND_FLOOR_M)\n",
     "\t\t\tcorr = corr + BEND_FLOOR_M\n", ["test_terrain_profile", "test_sight_corridor"], True),
    ("M6_reach_ignored", "scripts/race3d/chunk_context.gd",
     "m - maxf(reach, 0.0) <= cw", "m <= cw", ["test_chunk_streamer"], False),
    ("M7_city_mid_only", "scripts/race3d/builders/city.gd",
     "\t\tif ctx.in_bend_corridor(zm, (xa + xb) * 0.5) or ctx.in_bend_corridor(z0, xa) or ctx.in_bend_corridor(z1, xb):\n",
     "\t\tif ctx.in_bend_corridor(zm, (xa + xb) * 0.5):\n", ["test_structures"], False),
    ("M8_border_pillar_never_in_sight", "scripts/race3d/builders/border.gd",
     "\treturn env > 0.0 and out - PILLAR_W * 0.5 <= env\n", "\treturn false\n", ["test_structures"], False),
    ("M9_margin_negative", "scripts/race3d/sight_corridor.gd",
     "const MARGIN_M := 0.05 ", "const MARGIN_M := -0.5 ", ["test_sight_corridor", "test_terrain_profile"], False),
    ("M10_bend_floor_zero", "scripts/race3d/terrain_profile.gd",
     "const BEND_FLOOR_M := 0.55\n", "const BEND_FLOOR_M := 0.0\n", ["test_terrain_profile", "test_sight_corridor", "test_chunk_streamer"], True),
]


def run(cmd, log, timeout):
    env = dict(os.environ)
    env["XDG_DATA_HOME"] = S + "/xdg_mut"
    os.makedirs(env["XDG_DATA_HOME"], exist_ok=True)
    t0 = time.time()
    with open(log, "w") as f:
        try:
            p = subprocess.run(["nice", "-n", "10"] + cmd, cwd=MUT, stdout=f, stderr=subprocess.STDOUT, env=env, timeout=timeout)
            code = p.returncode
        except subprocess.TimeoutExpired:
            code = "timeout"
    return code, time.time() - t0


def main():
    only = sys.argv[1:]
    os.makedirs(S + "/logs/mut", exist_ok=True)
    for mid, rel, old, new, tests, sight in MUTS:
        if only and mid not in only:
            continue
        path = MUT + "/" + rel
        src = open(path).read()
        if src.count(old) != 1:
            print(f"{mid}: pattern found {src.count(old)} times - SKIPPED", flush=True)
            continue
        open(path, "w").write(src.replace(old, new))
        res = []
        for t in tests:
            log = f"{S}/logs/mut/{mid}_{t}.log"
            code, dt = run(["godot", "--headless", "--path", ".", "-s", "res://tests/run_tests.gd", "--", f"--filter={t}"], log, 900)
            txt = open(log).read()
            summary = [l for l in txt.splitlines() if "Tests," in l and "fehlgeschlagen" in l]
            res.append(f"{t}: exit {code} {summary[-1].strip() if summary else '?'} ({dt:.0f} s)")
        if sight:
            log = f"{S}/logs/mut/{mid}_modern_sight.log"
            code, dt = run(["godot", "--headless", "--path", ".", "-s", "res://tests/sim/modern_sight.gd"], log, 1800)
            txt = open(log).read()
            f7 = [l for l in txt.splitlines() if "CHECK modern_sight_f7" in l]
            res.append(f"modern_sight: exit {code} {f7[-1].strip() if f7 else '?'} ({dt:.0f} s)")
        shutil.copyfile(WT + "/" + rel, path)
        print(f"{mid} ({rel}): " + " | ".join(res), flush=True)


main()
