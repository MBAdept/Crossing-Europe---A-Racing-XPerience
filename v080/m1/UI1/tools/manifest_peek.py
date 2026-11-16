import json
import sys

root = sys.argv[1]
m = json.load(open(root + '/assets/models/manifest.json'))
print(m.keys(), m.get('version'))
print('models:', list(m['models'].keys()))
sets = m['sets']
print(len(sets))
for k, v in sets.items():
    if k.startswith('showroom') or k.startswith('player'):
        print(k, json.dumps(v)[:300])
lim = m['models']['player/limousine']
print(json.dumps(lim, indent=1)[:5000])
