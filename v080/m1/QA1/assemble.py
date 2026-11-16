#!/usr/bin/env python3
"""QA1: fill the placeholders of deliver/gate1/bericht.md with the report parts (only those whose file exists)."""
import os
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080"
REPORT = S + "/deliver/gate1/bericht.md"
PARTS = {
    "BERICHT_BILD": S + "/m1/QA1/bericht_bild.md",
    "BERICHT_CLIPS": S + "/m1/QA1/bericht_clips.md",
    "BERICHT_BEFUNDE": S + "/m1/QA1/befunde_draft.md",
    "BERICHT_LEISTUNG": S + "/m1/QA1/bericht_leistung.md",
    "BERICHT_BUILD": S + "/m1/QA1/bericht_build.md",
    "BERICHT_REST": S + "/m1/QA1/bericht_rest.md",
}
text = open(REPORT, encoding="utf-8").read()
for key, path in PARTS.items():
    if key in text and os.path.exists(path):
        part = open(path, encoding="utf-8").read().strip()
        # the befunde draft carries its own "## Befunde" heading: the report has one already
        if key == "BERICHT_BEFUNDE" and part.startswith("## "):
            part = part.split("\n", 1)[1].strip()
        text = text.replace(key, part)
        print("eingesetzt:", key)
for key, val in (a.split("=", 1) for a in sys.argv[1:]):
    text = text.replace(key, val)
    print("eingesetzt:", key)
open(REPORT, "w", encoding="utf-8").write(text)
left = [k for k in list(PARTS) + ["SCHLUSS_GOLDEN", "SCHLUSS_RENDER", "SCHLUSS_TESTS"] if k in text]
print("offen:", ", ".join(left) if left else "nichts")
