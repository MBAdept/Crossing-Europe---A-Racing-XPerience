#!/usr/bin/env python3
"""AU-R3: summary of a trigger log (trigger_log2.gd): rows in the city centre and on bridges with their paving,
joint events per deck, and a deterministic fingerprint of the events (name, z, side, set, deck).
usage: ana_rows.py <log> [--rows]"""
import json
import sys


def load(path):
    rows, evs, summary, result = [], [], None, None
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("ROW "):
            rows.append(json.loads(line[4:]))
        elif line.startswith("EV "):
            evs.append(json.loads(line[3:]))
        elif line.startswith("SUMMARY "):
            summary = json.loads(line[8:])
        elif line.startswith("ERGEBNIS "):
            result = json.loads(line[9:])
    return rows, evs, summary, result


def main():
    rows, evs, summary, result = load(sys.argv[1])
    show = "--rows" in sys.argv
    by = {}
    for r in rows:
        t = r.get("truth", {})
        f = r["f"]
        key = ("centre" if t.get("center") else "city" if t.get("city") else "open") + ("/bridge:" + t["bridge"] if t.get("bridge") else "")
        d = by.setdefault(key, {})
        d[f["paving"]] = d.get(f["paving"], 0) + 1
        if show and (t.get("center") or t.get("bridge")):
            print(f'  t={r["t"]:6.1f} km={r["km"]:8.3f} v={r["v"]:5.1f} truth_bridge={t.get("bridge",""):10s} centre={t.get("center")} '
                  f'feed: bridge={f["bridge"]:10s} deck={f["deck"]:8s} paving={f["paving"]:8s} L={f["surface_l"]:8s} R={f["surface_r"]}')
    print("rows by place / paving:")
    for k in sorted(by):
        print(f"  {k:28s} {by[k]}")
    joints = {}
    for e in evs:
        if e["name"] == "joint":
            k = f'{e["kind"]}/{e.get("deck","")}'
            joints[k] = joints.get(k, 0) + 1
    print("joints:", joints)
    if summary:
        print("counts:", json.dumps(summary["counts"], sort_keys=True))
    if result:
        print("ERGEBNIS time_s=%.3f distance=%.1f collisions=%d" % (result["time_s"], result["distance_km"], result["collisions"]))


if __name__ == "__main__":
    main()
