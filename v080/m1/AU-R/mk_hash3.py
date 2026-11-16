#!/usr/bin/env python3
"""AU-R: hash_check3.gd from hash_check2.gd – the city decision through AudioFeed.cobbled_blocks (exact share per
centre), the per-block fmix32 decision kept as column hash_only; every (city, centre length) once."""
import os

D = os.path.dirname(os.path.abspath(__file__))
t = open(os.path.join(D, "hash_check2.gd"), encoding="utf-8").read()
rep = [
    ('''			if seen_city.has(to_id) or not styles.has(style):
				continue
			seen_city[to_id] = true
			var length := float(plan.get("length_km"))
			var center := float(plan.get("city_center_km"))
			var len_m := maxf(length - center, 0.0) * 1000.0 / ts''',
     '''			var length := float(plan.get("length_km"))
			var center := float(plan.get("city_center_km"))
			var len_m := maxf(length - center, 0.0) * 1000.0 / ts
			var ckey := "%s|%.1f" % [to_id, len_m]
			if seen_city.has(ckey) or not styles.has(style):
				continue
			seen_city[ckey] = true
			var alloc := AudioFeed.cobbled_blocks(to_id, len_m, block_m, share)'''),
    ('''				var n2 := AudioFeed.unit_hash(k) < share''',
     '''				var n2 := bool(alloc.get(b, false))
				var h2 := AudioFeed.unit_hash(k) < share'''),
    ('''				w_new += w if n2 else 0.0''',
     '''				w_new += w if n2 else 0.0
				w_hash += w if h2 else 0.0'''),
    ('''			var w_new := 0.0
''', '''			var w_new := 0.0
			var w_hash := 0.0
'''),
    ('''			cities[to_id] = {"style": style''', '''			cities[ckey] = {"hash_only": snappedf(w_hash / maxf(w_all, 1.0), 0.001), "style": style'''),
    ('''		print("CITY ", JSON.stringify({"city": k, "style": c2["style"], "blocks": c2["blocks"], "m": c2["m"], "old": c2["old"],''',
     '''		print("CITY ", JSON.stringify({"city": k, "style": c2["style"], "blocks": c2["blocks"], "m": c2["m"], "old": c2["old"], "hash_only": c2["hash_only"],'''),
]
for a, b in rep:
    if a not in t:
        raise SystemExit("nicht gefunden: " + a[:60])
    t = t.replace(a, b)
open(os.path.join(D, "hash_check3.gd"), "w", encoding="utf-8").write(t)
print("ok")
