import sys
S = sys.argv[1]
for name, a, b in [
    ("bericht_gates.md", "@@STRUCTG@@", "**7 von 7 OK**: `countdown`, `zieltor`, `grenze`, `blitz`; `tankstelle` (21 Uhr Tankspur 0,406 / Arcade 0,459), `stadt` (0,491 / 0,501), `schatten` (mit eigenem `XDG_DATA_HOME`, der echte Benutzerordner unberührt)"),
    ("bericht_teil6.md", "@@STRUCT@@", "7 von 7 OK"),
]:
    p = S + "/" + name
    t = open(p, encoding="utf-8").read()
    assert t.count(a) == 1, a
    t = t.replace(a, b)
    open(p, "w", encoding="utf-8").write(t)
print("ok")
