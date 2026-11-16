#!/usr/bin/env python3
"""Assembles deliver/QA-BILD/bericht.md from the parts in m1/QA-BILD (head, verdict, findings, picture, fairness,
motion, performance, ok, gates, files)."""
import os

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-BILD"
parts = ["bericht_kopf.md", "bericht_befunde.md", "bericht_bild.md", "bericht_fair.md", "bericht_bewegung.md",
         "bericht_leistung.md", "bericht_ok.md", "bericht_tore.md", "bericht_dateien.md", "bericht_vertrag.md"]
out = []
for p in parts:
    path = os.path.join(S, p)
    if os.path.exists(path):
        out.append(open(path, encoding="utf-8").read().rstrip() + "\n")
    else:
        out.append("<!-- fehlt: %s -->\n" % p)
open(os.path.join(D, "bericht.md"), "w", encoding="utf-8").write("\n".join(out))
print(os.path.join(D, "bericht.md"), sum(len(x) for x in out), "Zeichen")
