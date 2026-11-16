"""Every landmark a city places (data/cities.json): sprite set? model set? proc? fallback (and is the fallback drawable)?

usage: lm_cover.py <project root>
"""
import json
import os
import sys

root = sys.argv[1]
db = json.load(open(os.path.join(root, "data/cities.json")))
spr = json.load(open(os.path.join(root, "assets/sprites/manifest.json"))).get("sets", {})
mod = json.load(open(os.path.join(root, "assets/models/manifest.json")))
mod_sets = mod.get("sets", {}) if isinstance(mod, dict) else {}
lm_sets = db.get("landmark_sets", {})


def drawable(s):
    return (s in spr) or (s in mod_sets)


rows = []
for cid, c in db.get("cities", {}).items():
    for lm in c.get("landmarks", []):
        s = lm.get("set", "")
        ent = dict(lm_sets.get(s, {}))
        ent.update(lm)
        rows.append((cid, s, s in spr, s in mod_sets, ent.get("proc", ""), ent.get("fallback", ""),
                     drawable(ent.get("fallback", "")) if ent.get("fallback") else None))
none = [r for r in rows if not r[2] and not r[3]]
print("landmarks placed by cities: %d; without sprite and model: %d" % (len(rows), len(none)))
for r in none:
    print("  city=%s set=%s proc=%s fallback=%s fallback_drawable=%s" % (r[0], r[1], r[4], r[5], r[6]))
print("model sets among landmarks:", [r[1] for r in rows if r[3]])
