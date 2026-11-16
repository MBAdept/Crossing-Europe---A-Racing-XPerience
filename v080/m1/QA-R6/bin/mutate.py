#!/usr/bin/env python3
"""QA-R6: break one line per rule in the scratch copy and see whether test_structures (unit) fails.
Usage: mutate.py [ids…]  – writes mut/results.txt and per-mutation logs."""
import os, subprocess, sys, time

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6"
M = S + "/mut"
B = "scripts/race3d/builders/"
MUTS = [
    ("M01 fuel lane edge +0.2 m", B + "station.gd",
     "var e := (ctx.rows_edge[i].y + ctx.rows_edge[i + 1].y) * 0.5   # paved right edge incl. the fuel lane",
     "var e := (ctx.rows_edge[i].y + ctx.rows_edge[i + 1].y) * 0.5 + 0.2"),
    ("M02 station column never moves for a sign (F1)", B + "station.gd",
     "if z >= zf - PLINTH_W * 0.5 and z < r1:", "if z >= zf - PLINTH_W * 0.5 and z < r0:"),
    ("M03 canopy soffit 5.4 m instead of 5.6 m", B + "station.gd",
     "const CANOPY_H := 5.6 ", "const CANOPY_H := 5.4 "),
    ("M04 border pillar never moves for a sign (F1)", B + "border.gd",
     "if int(s[1]) == side and float(s[0]) >= zf - PLINTH_HALF and float(s[0]) < r1:",
     "if int(s[1]) == side and float(s[0]) >= zf - PLINTH_HALF and float(s[0]) < r0:"),
    ("M05 border pillars ignore the bend corridor (F7)", B + "border.gd",
     'if str(p[2]) != "front" and ctx.in_bend_corridor(zp, px):', "if false:"),
    ("M06 border roof 5.8 m", B + "border.gd", "const ROOF_H := 6.0 ", "const ROOF_H := 5.8 "),
    ("M07 city: right-side street lights only", B + "city.gd",
     'var side := int(it.get("side", 1))\n\t\t\tvar z := float(it.get("z", seg["z"]))',
     'var side := int(it.get("side", 1))\n\t\t\tif side < 0:\n\t\t\t\tcontinue\n\t\t\tvar z := float(it.get("z", seg["z"]))'),
    ("M08 city lamp energy 0.55 (PropLibrary's)", B + "city.gd", "const LAMP_ENERGY := 1.0", "const LAMP_ENERGY := 0.55"),
    ("M09 city fences ignore the bend corridor (F7)", B + "city.gd",
     "if ctx.in_bend_corridor(zm, (xa + xb) * 0.5):", "if false:"),
    ("M10 countdown one lamp late", B + "gantry.gd",
     "var on := 0 if cd <= 0.0 else clampi(4 - int(ceil(cd)), 1, 3)",
     "var on := 0 if cd <= 0.0 else clampi(3 - int(ceil(cd)), 1, 3)"),
    ("M11 radar flash below 0.05", B + "radar.gd", "if f <= 0.05:", "if f <= 0.0:"),
    ("M12 station casts with shadows off", B + "station.gd",
     'var casts := int(ctx.levels.get("shadow_casters", 0)) >= 1\n\tvar mi: MeshInstance3D = null',
     'var casts := true\n\tvar mi: MeshInstance3D = null'),
    ("M13 all R6 nodes: dynamic vpbr (instance uniforms)", B + "station.gd",
     "mi.material_override = mats.material(ModernMaterials.VPBR_STATIC)",
     'mi.material_override = mats.material("vpbr")'),
    ("M14 station: no pylon", B + "station.gd",
     '_pylon(ctx, kit, pan, glows, it, sa, price_uv)\n\t\t\t\tpylons += 1', 'pass'),
    ("M15 gantry: no countdown lamps", B + "gantry.gd",
     'lamps.append({"pos": lc + Vector3(0.0, 0.0, 0.09), "i": i})', "pass"),
    ("M16 city lamps: no light pool", B + "city.gd",
     '"size": float(l.get("size", 0.44)), "range": LAMP_RANGE_M, "energy": LAMP_ENERGY})',
     '"size": float(l.get("size", 0.44)), "range": 0.0, "energy": LAMP_ENERGY})'),
    ("M17 border: country name not upper case", B + "border.gd", "return name.to_upper()", "return name"),
    ("M18 station: canopy also on island-only segments", B + "station.gd",
     "if (fz & TrackSegment.FUEL_CANOPY) != 0:\n\t\t\tcanopies += 1",
     "if (fz & (TrackSegment.FUEL_CANOPY | TrackSegment.FUEL_ISLAND)) != 0:\n\t\t\tcanopies += 1"),
]


def run(tag):
    log = f"{M}/mut_{tag}.log"
    env = dict(os.environ, XDG_DATA_HOME=f"{S}/xdg/mut")
    os.makedirs(env["XDG_DATA_HOME"], exist_ok=True)
    t0 = time.time()
    with open(log, "w") as f:
        p = subprocess.run(["nice", "-n", "19", "timeout", "900", "godot", "--headless", "--path", ".", "-s",
                            "res://tests/run_tests.gd", "--", "--filter=test_structures"], cwd=M, stdout=f,
                           stderr=subprocess.STDOUT, env=env)
    txt = open(log).read()
    fails = [l for l in txt.splitlines() if "FAIL" in l or "SCRIPT ERROR" in l or "Parse Error" in l]
    return p.returncode, fails, time.time() - t0


def main():
    want = sys.argv[1:]
    out = open(f"{M}/results.txt", "a")
    if not want or "M00" in want:
        rc, fails, dt = run("M00")
        out.write(f"M00 unchanged: exit {rc}, {len(fails)} fail lines, {dt:.0f}s\n")
        out.flush()
    for tag_name, path, old, new in MUTS:
        tag = tag_name.split()[0]
        if want and tag not in want:
            continue
        fp = os.path.join(M, path)
        src = open(fp).read()
        n = src.count(old)
        if n != 1:
            out.write(f"{tag_name}: PATTERN FOUND {n} TIMES – skipped\n")
            out.flush()
            continue
        open(fp, "w").write(src.replace(old, new))
        try:
            rc, fails, dt = run(tag)
        finally:
            open(fp, "w").write(src)
        verdict = "CAUGHT" if (rc != 0 or fails) else "NOT CAUGHT"
        first = fails[0].strip()[:160] if fails else ""
        out.write(f"{tag_name}: {verdict} (exit {rc}, {len(fails)} fail lines, {dt:.0f}s) {first}\n")
        out.flush()
    out.write("DONE\n")


if __name__ == "__main__":
    main()
