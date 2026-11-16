import json, sys, os
root = sys.argv[1]
db = json.load(open(os.path.join(root, 'data/cities.json')))
sets = db.get('landmark_sets', {})
print('landmark_sets:', len(sets))
cities = db.get('cities', {})
tinted = []
procs = []
for cid, c in cities.items():
    for lm in c.get('landmarks', []):
        s = lm.get('set', '')
        ent = dict(sets.get(s, {}))
        ent.update(lm)
        if 'tint' in ent:
            tinted.append((cid, s, ent.get('tint'), 'proc' in ent))
        if 'proc' in ent:
            procs.append((cid, s, ent.get('proc'), ent.get('fallback'), ent.get('fallback_scale'), ent.get('fallback_tint')))
print('landmarks with tint (city, set, tint, proc):')
for t in tinted:
    print('  ', t)
print('proc landmarks (city, set, proc, fallback, fallback_scale, fallback_tint):')
for p in procs:
    print('  ', p)
