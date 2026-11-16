import json, sys
root = sys.argv[1]
d = json.load(open(root + '/data/scenery.json'))['scenery']
print(len(d))
for k, v in d.items():
    props = [(p['set'].split('/')[-1], p.get('every_m'), p.get('x'), p.get('count', 1)) for p in v.get('props', [])]
    rest = {kk: vv for kk, vv in v.items() if kk not in ('props', 'background', 'name', 'grass', 'climate')}
    print(k, v.get('grass'), v.get('climate'), rest)
    print('    ', props)
