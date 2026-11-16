#!/usr/bin/env python3
"""Assembles deliver/QA-SYSTEM/bericht.md from the parts bericht_teil*.md in the QA-SYSTEM scratch folder."""
import glob
import os

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-SYSTEM"
parts = sorted(glob.glob(os.path.join(S, "bericht_teil*.md")))
out = []
for p in parts:
    with open(p, encoding="utf-8") as fh:
        out.append(fh.read().rstrip() + "\n")
text = "\n".join(out)
os.makedirs(D, exist_ok=True)
with open(os.path.join(D, "bericht.md"), "w", encoding="utf-8") as fh:
    fh.write(text)
print("bericht.md:", len(text.splitlines()), "Zeilen aus", [os.path.basename(p) for p in parts])
