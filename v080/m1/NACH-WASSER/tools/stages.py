import json, sys, os
root = sys.argv[1]
want = sys.argv[2:]
net = json.load(open(os.path.join(root, 'data/network.json')))
print('keys:', list(net.keys())[:10])
stages = net.get('stages', net.get('edges', []))
if isinstance(stages, dict):
    stages = [dict(v, id=k) for k, v in stages.items()]
for st in stages:
    f, t = str(st.get('from')), str(st.get('to'))
    if any(w in (f, t) for w in want):
        print(st.get('id'), f, '->', t, 'km', st.get('length_km', st.get('km')))
races = net.get('races', [])
if isinstance(races, dict):
    races = [dict(v, id=k) for k, v in races.items()]
for r in races[:20]:
    print('race', r.get('id'), r.get('name', ''), r.get('from', ''), r.get('to', ''), r.get('stages', r.get('routes', ''))[:6] if isinstance(r.get('stages', r.get('routes', '')), list) else '')
