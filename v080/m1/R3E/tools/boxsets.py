import json, sys
root = sys.argv[1]
sm = json.load(open(root + '/assets/sprites/manifest.json'))
sets = sm['sets']
for k, s in sorted(sets.items()):
    if s.get('render') == 'box':
        print(k, json.dumps({kk: v for kk, v in s.items() if kk not in ('parts', 'lights')})[:600])
        for p in s.get('parts', []):
            print('   part', json.dumps(p))
        print('   lights', json.dumps(s.get('lights')))
