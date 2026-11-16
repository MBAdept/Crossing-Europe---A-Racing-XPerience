#!/usr/bin/env python3
"""KRITIK-R2-MESS: PERF lines of kr_perf_conc.gd (concrete km 42) and perf_asph.gd (asphalt km 76) runs, obj and c1
interleaved: mean / median / p95 / max of feed, road, impact per run; slab locks from the road debug state.
usage: ana_perf.py <logdir> <out.json>"""
import glob
import json
import os
import re
import sys

import numpy as np

RX = re.compile(r"PERF (\w+)\s+Mittel ([\d.]+) ms\s+Median ([\d.]+) ms\s+p95 ([\d.]+) ms\s+max ([\d.]+) ms \((\d+) Bilder\)")


def main():
    d, out = sys.argv[1], sys.argv[2]
    res = {}
    for p in sorted(glob.glob(os.path.join(d, "perf*_*.log"))):
        name = os.path.basename(p)[:-4]          # perfconc1_obj
        m = re.match(r"perf(conc|asph)(\d)_(\w+)", name)
        if not m:
            continue
        kind, rep, head = m.group(1), int(m.group(2)), m.group(3)
        row = {}
        locks = None
        for line in open(p, errors="replace"):
            mm = RX.search(line)
            if mm:
                row[mm.group(1)] = [float(mm.group(i)) for i in range(2, 6)] + [int(mm.group(6))]
            if "PERF road players:" in line:
                try:
                    js = json.loads(line.split("PERF road players:", 1)[1])
                    locks = js.get("slab_locks")
                    row["realigned"] = js.get("slab_realigned")
                except Exception:
                    pass
        row["locks"] = locks
        res.setdefault(kind, {}).setdefault(head, []).append(row)
    for kind in res:
        print(f"== {kind}")
        for head, runs in res[kind].items():
            for slot in ("road", "impact", "feed"):
                vals = [r[slot] for r in runs if slot in r]
                if not vals:
                    continue
                a = np.array(vals)
                print(f"  {head:4s} {slot:6s} Mittel {' / '.join(f'{v:.3f}' for v in a[:, 0])} ms | Median "
                      f"{' / '.join(f'{v:.3f}' for v in a[:, 1])} | p95 {' / '.join(f'{v:.3f}' for v in a[:, 2])} | max "
                      f"{' / '.join(f'{v:.1f}' for v in a[:, 3])}")
            print(f"  {head:4s} Sperren je Lauf: {[r.get('locks') for r in runs]}, Nachstellungen {[r.get('realigned') for r in runs]}")
    json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    main()
