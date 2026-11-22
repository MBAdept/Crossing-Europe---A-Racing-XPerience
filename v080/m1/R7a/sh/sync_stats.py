#!/usr/bin/env python3
"""R7a: the corridor counters of PERF lines.  sync_stats.py <log>..."""
import json
import os
import sys

for p in sys.argv[1:]:
    for line in open(p, encoding="utf-8", errors="replace"):
        if line.startswith("PERF "):
            d = json.loads(line[5:])
            s = {k: v for k, v in d.get("streamer", {}).items() if "corridor" in k}
            ld = {k: v for k, v in d.get("load", {}).items() if "corridor_sync" in k}
            print(os.path.basename(p), "streamer", s, "load", ld)
