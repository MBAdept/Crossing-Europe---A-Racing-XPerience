import re, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
a = t.index("<<<<<<< HEAD\n")
b = t.index("=======\n", a)
c = t.index(">>>>>>> origin/wip/v080-fix-r5\n", b)
head = t[a + len("<<<<<<< HEAD\n"):b]
r5 = t[b + len("=======\n"):c]
r5 = r5.replace("## 15. Tunnel, Brücken, Wasser und Ufer (Bauabschnitt R5)", "## 16. Tunnel, Brücken, Wasser und Ufer (Bauabschnitt R5)")
r5 = r5.replace("### 15.1 Zone „Tunnel“", "### 16.1 Zone „Tunnel“").replace("### 15.2 Wasser im Licht", "### 16.2 Wasser im Licht")
if not head.endswith("\n\n"):
    head = head.rstrip("\n") + "\n\n"
t = t[:a] + head + r5 + t[c + len(">>>>>>> origin/wip/v080-fix-r5\n"):]
assert "<<<<<<<" not in t and ">>>>>>>" not in t
open(p, "w", encoding="utf-8").write(t)
print("ok")
