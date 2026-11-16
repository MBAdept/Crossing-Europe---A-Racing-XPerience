#!/usr/bin/env python3
"""Deep comparison of two qa_audio_probe.gd outputs. Usage: cmp_probe.py a.json b.json [--ignore=path1,path2]"""
import json, sys
a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
ignore = []
for arg in sys.argv[3:]:
    if arg.startswith('--ignore='):
        ignore = arg[9:].split(',')
diffs = []
def walk(x, y, path):
    if any(path.startswith(i) for i in ignore):
        return
    if isinstance(x, dict) and isinstance(y, dict):
        for k in sorted(set(x) | set(y)):
            p = path + '/' + str(k)
            if k not in x: diffs.append((p, 'only in B', None, y[k]))
            elif k not in y: diffs.append((p, 'only in A', x[k], None))
            else: walk(x[k], y[k], p)
    elif isinstance(x, list) and isinstance(y, list):
        if len(x) != len(y):
            diffs.append((path, 'list length', len(x), len(y)))
        for i in range(min(len(x), len(y))):
            walk(x[i], y[i], path + '[%d]' % i)
    else:
        if x != y:
            diffs.append((path, 'value', x, y))
sections = ['static', 'drive', 'static_after_drive']
for s in sections:
    n0 = len(diffs)
    walk(a.get(s), b.get(s), s)
    print('%-20s %s' % (s, 'IDENTICAL' if len(diffs) == n0 else '%d differences' % (len(diffs) - n0)))
for d in diffs[:60]:
    print('   ', d[0], '|', d[1], '|', str(d[2])[:90], '->', str(d[3])[:90])
if len(diffs) > 60: print('    …', len(diffs) - 60, 'more')
for k in ['counts_boot', 'counts_before_fingerprint', 'counts_end']:
    print(k, 'A', a.get(k)); print(' ' * len(k), 'B', b.get(k))
print('notes B:', b.get('notes'), '| profile_after:', b.get('profile_after'))
sys.exit(1 if diffs else 0)
