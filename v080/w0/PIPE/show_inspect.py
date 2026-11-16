import json
import sys

D = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE/'
r = json.load(open(D + 'inspect.json'))
flt = sys.argv[1] if len(sys.argv) > 1 else ''
for k, v in r['meshes'].items():
    if flt not in k:
        continue
    print(k, v['bytes'], [round(x, 3) for x in v['aabb']])
    for s in v['surfaces']:
        row = {}
        for kk, vv in s.items():
            row[kk] = vv if not isinstance(vv, list) or len(vv) < 12 else str(vv[:12]) + '...'
        print('   ', row)
for k, v in r['textures'].items():
    if flt in k:
        print(k, v)
