#!/usr/bin/env python3
"""AU-R: hash_check4.gd from hash_check3.gd – the concrete decision ("new") through an AudioFeed set up from the
configuration (section_key + concrete_threshold_for), the plain fmix32 decision kept as "hash_only"."""
import os

D = os.path.dirname(os.path.abspath(__file__))
t = open(os.path.join(D, "hash_check3.gd"), encoding="utf-8").read()
rep = [
    ('''	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 10.0))''',
     '''	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 10.0))
	var feed := AudioFeed.new()
	feed.setup(ConfigLoader.lookup(cfg, "audio.modern", {}))'''),
    ('''				var key := "%s|%s|%.3f|%s|%s" % [str(plan.get("stage_id")), str(s.get("name", "")), float(s.get("length_km", 0.0)),
					c, str(s.get("scenery", ""))]''',
     '''				var key := AudioFeed.section_key(str(plan.get("stage_id")), s)'''),
    ('''				var n := AudioFeed.unit_hash(key) < p''',
     '''				var n := AudioFeed.unit_hash(key) < feed.concrete_threshold_for(c, p)
				var hn := AudioFeed.unit_hash(key) < p'''),
    ('''				var row: Array = country.get(c, [0.0, 0.0, 0.0, 0, p])''',
     '''				var row: Array = country.get(c, [0.0, 0.0, 0.0, 0, p, 0.0])
				row[5] = float(row[5]) + (km if hn else 0.0)'''),
    ('''			"old": snappedf(float(row[1]) / maxf(km, 0.001), 0.001), "new": snappedf(float(row[2]) / maxf(km, 0.001), 0.001)}))''',
     '''			"old": snappedf(float(row[1]) / maxf(km, 0.001), 0.001), "new": snappedf(float(row[2]) / maxf(km, 0.001), 0.001),
			"hash_only": snappedf(float(row[5]) / maxf(km, 0.001), 0.001)}))'''),
]
for a, b in rep:
    if a not in t:
        raise SystemExit("nicht gefunden: " + a[:70])
    t = t.replace(a, b)
open(os.path.join(D, "hash_check4.gd"), "w", encoding="utf-8").write(t)
print("ok")
