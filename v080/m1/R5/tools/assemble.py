#!/usr/bin/env python3
"""R5: puts the report together from its parts into deliver/R5/bericht.md (placeholders {{…}} must be gone)."""
import os, sys
R5 = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5"
OUT = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R5/bericht.md"
PARTS = ["bericht_kopf.md", "bericht_teil_abnahme.md", "bericht_teil_gebaut2.md", "bericht_teil_entscheidungen2.md",
         "bericht_teil_bilder2.md", "bericht_teil_mess2.md", "bericht_teil_tests.md", "bericht_teil_gates.md",
         "bericht_teil_leistung.md", "bericht_teil_naechste.md", "bericht_teil_vertrag.md", "bericht_teil_orte.md"]
text = []
for p in PARTS:
    with open(os.path.join(R5, p), encoding="utf-8") as f:
        text.append(f.read().rstrip() + "\n")
out = "\n".join(text)
left = [l for l in out.splitlines() if "{{" in l]
if left:
    print("PLATZHALTER:", *left[:5], sep="\n  ")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(out)
print(OUT, len(out.splitlines()), "Zeilen")
sys.exit(1 if left else 0)
