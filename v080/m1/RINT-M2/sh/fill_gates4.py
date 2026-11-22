import sys
p = sys.argv[1] + "/bericht_gates.md"
t = open(p, encoding="utf-8").read()
lines = t.split("\n")
out = []
for ln in lines:
    out.append(ln)
    if ln.startswith("| Modern-Melder prüfen |"):
        out.append("| Modern-Melder auf dem Endstand | `tools/golden.sh modern-check` | `9b02f05` | @@MC2G@@ |")
    if ln.startswith("| Render-Prüfungen |"):
        out.append("| Strukturen auf dem Endstand | `check_structures.gd`, `check_structures_licht.gd` | `9b02f05` | @@STRUCTG@@ |")
    if ln.startswith("| Skripte |"):
        out.append("| Skripte auf dem Endstand | `godot --headless --path . -s res://tests/check_scripts.gd` | `9b02f05` | @@S2@@ |")
t = "\n".join(out)
a = "\nAusgewählte Zeilen der Render-Prüfungen"
b = """
Regel 1: `git diff --stat 515dd51..9b02f05` über alle eingefrorenen Arcade-Dateien des Vertrags (Liste §Rule 1) ist
leer – keine dieser Dateien geändert, auch nicht durch die Merges.

Ausgewählte Zeilen der Render-Prüfungen"""
assert t.count(a) == 1
t = t.replace(a, b)
open(p, "w", encoding="utf-8").write(t)
print("ok")
