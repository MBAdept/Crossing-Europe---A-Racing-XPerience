#!/usr/bin/env python3
"""AU-R4: per arrival with a stone bridge – is there ANY choice of blocks that keeps both readings of the old-town
share in 0.6 ± 0.05: 'heard' (stone bridges count as cobbled street) and 'street' (stone bridges left out)?
Brute force over all subsets of blocks (exact metres from cobble_alloc.gd ROW blocks). Also the reachable range."""
import itertools, json, sys

rows = [json.loads(l[4:]) for l in open(sys.argv[1]) if l.startswith("ROW ")]
seen = set()
for r in rows:
    key = (r["to"], r["stone_m"], r["gap_m"])
    if r["stone_m"] <= 0 or key in seen:
        continue
    seen.add(key)
    bl = r["blocks"]
    street = [b[0] for b in bl]
    stone = sum(b[1] for b in bl)
    T = sum(street)
    B = T + stone
    best = None
    both = 0
    for mask in itertools.product([0, 1], repeat=len(bl)):
        c = sum(s for s, m in zip(street, mask) if m)
        h = (c + stone) / B
        s = c / T
        if abs(h - 0.6) <= 0.05 + 1e-9 and abs(s - 0.6) <= 0.05 + 1e-9:
            both += 1
            d = max(abs(h - 0.6), abs(s - 0.6))
            if best is None or d < best[0]:
                best = (d, round(h, 3), round(s, 3))
    lo_c = max(0.55 * B - stone, 0.55 * T)
    hi_c = min(0.65 * B - stone, 0.65 * T)
    print(f"{r['to']:13s} stone {stone:5.0f} street {T:6.0f} heard-new {r['heard_new']:.3f} street-new {r['street_new']:.3f} | "
          f"window for cobbled street metres [{lo_c:6.1f}, {hi_c:6.1f}] ({hi_c - lo_c:5.1f} m) | subsets in both bands: {both:4d}"
          + (f", best heard {best[1]} street {best[2]}" if best else ""))
