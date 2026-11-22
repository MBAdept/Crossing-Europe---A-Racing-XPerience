import json, os, sys
root = sys.argv[1]
d = json.load(open(os.path.join(root, 'data/cities.json')))
print(list(d.keys()))
ls = d.get('landmark_sets', {})
print('landmark_sets', len(ls))
man = json.load(open(os.path.join(root, 'assets/sprites/manifest.json'))) if os.path.exists(os.path.join(root, 'assets/sprites/manifest.json')) else {}
sprite_sets = set()
if isinstance(man, dict):
    for k in ('sets', 'sprites'):
        if k in man:
            sprite_sets |= set(man[k].keys()) if isinstance(man[k], dict) else set(x.get('id') for x in man[k])
mm = json.load(open(os.path.join(root, 'assets/models/manifest.json')))
model_sets = set(mm.get('sets', {}).keys())
print('sprite sets', len(sprite_sets), 'model sets', len(model_sets))
for k, v in ls.items():
    sid = v.get('set', k)
    print(k, 'proc=' + str(v.get('proc', '')), 'fb=' + str(v.get('fallback', '')), 'sprite=' + str(sid in sprite_sets), 'model=' + str(sid in model_sets),
          {kk: vv for kk, vv in v.items() if kk not in ('proc', 'fallback')})
