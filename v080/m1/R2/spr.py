import json, sys
root = sys.argv[1]
m = json.load(open(root + '/assets/sprites/manifest.json'))
print(m.keys())
sets = m.get('sets', m)
n = 0
for k, v in sets.items():
    if not (k.startswith('props/') or k.startswith('landmarks/')):
        continue
    n += 1
    if n <= 6 or k in ('props/tree_birch', 'props/wind_turbine', 'props/haybale', 'props/bush_round', 'props/streetlight', 'props/farmhouse', 'props/tree_oak'):
        print(k, json.dumps(v)[:900])
print(n)
keys = {}
for k, v in sets.items():
    if k.startswith('props/') or k.startswith('landmarks/'):
        for kk in v.keys():
            keys[kk] = keys.get(kk, 0) + 1
print(keys)
# layers and tags statistics
lay = {}
tags = {}
for k, v in sets.items():
    if k.startswith('props/') or k.startswith('landmarks/'):
        lay[str(v.get('layers'))] = lay.get(str(v.get('layers')), 0) + 1
        for t in v.get('tags', []):
            tags[t] = tags.get(t, 0) + 1
print(lay)
print(tags)
