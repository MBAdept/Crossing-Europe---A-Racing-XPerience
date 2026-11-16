import json, sys, collections
root = sys.argv[1]
c = json.load(open(root + "/data/cities.json"))
cities = c.get("cities", {})
types = collections.Counter()
rows = []
for cid, e in sorted(cities.items()):
    for b in e.get("bridges", []):
        t = b.get("type", "river")
        types[t] += 1
        rows.append((cid, b.get("name", ""), t, "len", b.get("length_m"), "h", b.get("height_m"), "pyl", b.get("pylon_m"),
                     "bank", b.get("bank", ""), "water", b.get("water", ""), "col", b.get("color", ""), "kmf", b.get("km_to_finish"),
                     "ships", b.get("ships", 0), "boats", b.get("boats", "")))
print("bridge types:", dict(types), "total", sum(types.values()))
for r in rows:
    print(r)
n = json.load(open(root + "/data/network.json"))
print(type(n), list(n.keys())[:10])
