#!/usr/bin/env python3
"""R7c: FLIMMER lines of my_scene sparkcam logs as a markdown table.  sparktab.py <log> [<log> ...]"""
import re
import sys

for p in sys.argv[1:]:
    tag = p.split("/")[-1].replace(".log", "")
    for line in open(p, encoding="utf-8", errors="replace"):
        if not line.startswith("FLIMMER"):
            continue
        head = line.split()
        model = head[1].replace("props/", "")
        rep = head[2] if not head[2].endswith("m") else ""
        vals = re.findall(r"(\d+) m (\S+): ([0-9.]+) %", line)
        print("| %s | %s | %s | %s |" % (tag, model, vals[0][1] if vals else rep, " / ".join("%s m %s" % (v[0], v[2]) for v in vals)))
