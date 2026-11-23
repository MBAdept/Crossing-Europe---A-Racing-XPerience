#!/usr/bin/env python3
"""R7c: bericht.md from the parts in m1/R7c and the placeholder values in fill.json.  assemble.py <out.md>"""
import json
import os
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c"
parts = ["bericht_kopf.md", "bericht_teil_ergebnis.md", "bericht_teil_umsetzung.md", "bericht_teil_mess.md",
         "bericht_teil_mess2.md", "bericht_teil_mess3.md", "bericht_teil_bilder.md", "bericht_teil_gates.md",
         "bericht_teil_leistung.md", "bericht_teil_offen.md", "bericht_teil_naechste.md", "bericht_teil_lieferung.md"]
fill = json.load(open(os.path.join(S, "fill.json"), encoding="utf-8"))
text = ""
for p in parts:
    t = open(os.path.join(S, p), encoding="utf-8").read().strip("\n")
    text += t + "\n\n"
for k, v in fill.items():
    text = text.replace("@@" + k + "@@", v)
left = [w for w in text.split("@@")[1::2]]
if left:
    print("offene Platzhalter:", left)
open(sys.argv[1], "w", encoding="utf-8").write(text.rstrip("\n") + "\n")
print("geschrieben", sys.argv[1], len(text.splitlines()), "Zeilen")
