#!/usr/bin/env python3
"""Compare two stage_hash.gd logs: ERGEBNIS (all keys except gfx/gfx_*) and the per-second hash lists."""
import json
import sys


def load(p):
    erg, hashes, digest, run = None, [], None, None
    for line in open(p, encoding="utf-8", errors="replace"):
        if line.startswith("ERGEBNIS "):
            erg = json.loads(line[9:])
        elif line.startswith("HASHLIST "):
            hashes = line[9:].strip().split(",")
        elif line.startswith("HASHES "):
            digest = line.split("digest=")[1].split()[0]
        elif line.startswith("RUN "):
            run = json.loads(line[4:])
    return erg, hashes, digest, run


a, b = sys.argv[1], sys.argv[2]
ea, ha, da, ra = load(a)
eb, hb, db, rb = load(b)
if ea is None or eb is None:
    print(f"CMP FEHLER: ERGEBNIS fehlt ({a if ea is None else b})")
    sys.exit(1)
ka = {k: v for k, v in ea.items() if not k.startswith("gfx")}
kb = {k: v for k, v in eb.items() if not k.startswith("gfx")}
diff = sorted(k for k in set(ka) | set(kb) if ka.get(k, "<fehlt>") != kb.get(k, "<fehlt>"))
first = next((i for i, (x, y) in enumerate(zip(ha, hb)) if x != y), -1)
ok = not diff and ha == hb and len(ha) > 30
print(f"CMP {'OK' if ok else 'FEHLER'} keys={len(ka)}/{len(kb)} differing={diff} hashes={len(ha)}/{len(hb)} "
      f"first_diff={first} digest_equal={da == db} gfx={ea.get('gfx', '-')}/{eb.get('gfx', '-')} "
      f"time_s={ea.get('time_s')} refuels={ea.get('refuels')} radar={ea.get('radar_flashes')} "
      f"police={ea.get('police_stops')} collisions={ea.get('collisions')} renderer={rb.get('renderer') if rb else '?'}")
for k in diff[:10]:
    print(f"   {k}: {ka.get(k, '<fehlt>')!r} vs {kb.get(k, '<fehlt>')!r}")
sys.exit(0 if ok else 1)
