#!/usr/bin/env python3
"""NACH-R6: re-run the B-04 mutations of QA-R6 on the head (one at a time), each followed by
tools/run_tests.sh test_structures; the builder file is restored from git after every mutation."""
import subprocess, sys, pathlib

W = pathlib.Path("/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-4")
S = pathlib.Path("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6")
MUT = {
    "M03": ("scripts/race3d/builders/station.gd", "const CANOPY_H := 5.6", "const CANOPY_H := 5.4"),
    "M06": ("scripts/race3d/builders/border.gd", "const ROOF_H := 6.0", "const ROOF_H := 5.8"),
    "M08": ("scripts/race3d/builders/city.gd", "const LAMP_ENERGY := 1.0", "const LAMP_ENERGY := 0.55"),
}

def run(name, f, old, new):
    p = W / f
    src = p.read_text()
    if old is None:
        # city: the lamp energy constant, whatever its spelling
        import re
        m = re.search(r"const LAMP_ENERGY := ([0-9.]+)", src)
        if not m:
            print(name, "pattern not found"); return
        old = m.group(0); new = "const LAMP_ENERGY := %s" % (float(m.group(1)) * 0.8)
    if src.count(old) != 1:
        print(name, "pattern count", src.count(old)); return
    p.write_text(src.replace(old, new))
    try:
        r = subprocess.run(["nice", "-n", "10", "tools/run_tests.sh", "test_structures"], cwd=W, capture_output=True, text=True,
                           env={**__import__("os").environ, "XDG_DATA_HOME": str(S / "xdg_unit")}, timeout=900)
        out = r.stdout + r.stderr
        (S / "logs" / f"mut_{name}.log").write_text(out)
        fails = [l for l in out.splitlines() if l.startswith("FAIL") or "fehlgeschlagen" in l]
        print(name, f"{old!r} -> {new!r}", "exit", r.returncode, "|", " / ".join(fails[-3:]))
    finally:
        subprocess.run(["git", "checkout", "--", f], cwd=W)

for k in (sys.argv[1:] or MUT.keys()):
    run(k, *MUT[k])
print(subprocess.run(["git", "status", "--short"], cwd=W, capture_output=True, text=True).stdout or "clean")
