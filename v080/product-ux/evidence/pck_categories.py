#!/usr/bin/env python3
"""Categorises the files of a PCK listing (pck_list.py --tsv) by their source in the project.
Usage: pck_categories.py <listing.tsv> <project dir>"""
import sys, os, re, collections, glob

tsv, proj = sys.argv[1], sys.argv[2]
# imported file -> source path
imp2src = {}
for root, dirs, files in os.walk(proj):
    if '/.godot' in root or '/build' in root or '/.git' in root:
        continue
    for fn in files:
        if fn.endswith('.import'):
            src = os.path.relpath(os.path.join(root, fn[:-7]), proj)
            txt = open(os.path.join(root, fn), encoding='utf-8', errors='replace').read()
            for m in re.finditer(r'^path(?:\.[a-z0-9_]+)?="res://([^"]+)"', txt, re.M):
                imp2src[m.group(1)] = src
            m = re.search(r'dest_files=\[([^\]]*)\]', txt)
            if m:
                for d in re.findall(r'"res://([^"]+)"', m.group(1)):
                    imp2src[d] = src

def category(src):
    p = src
    if p.startswith('assets/sprites/'):
        sub = p.split('/')[2]
        return 'sprites/' + sub
    if p.startswith('assets/audio/'):
        return 'audio/' + p.split('/')[2]
    if p.startswith('assets/'):
        return 'assets/' + p.split('/')[1]
    if p.startswith('scripts/') or p.endswith('.gdc') or p.endswith('.gd'):
        return 'scripts'
    if p.startswith('data/') or p.startswith('config/'):
        return 'data+config'
    if p.startswith('.godot/'):
        return 'godot-internal'
    return 'other:' + p.split('/')[0]

tot = collections.Counter(); cnt = collections.Counter(); unk = []
rows = []
for line in open(tsv):
    size, p = line.rstrip('\n').split('\t')
    size = int(size)
    src = imp2src.get(p)
    if src is None:
        if p.startswith('.godot/imported/'):
            unk.append((size, p)); src = p
        else:
            src = p
    c = category(src)
    tot[c] += size; cnt[c] += 1
    rows.append((size, c, src, p))
total = sum(tot.values())
print(f"{'category':28s} {'files':>6s} {'MB':>9s} {'%':>6s}")
for c, s in sorted(tot.items(), key=lambda kv: -kv[1]):
    print(f"{c:28s} {cnt[c]:6d} {s/1e6:9.2f} {100*s/total:6.1f}")
print(f"{'TOTAL':28s} {sum(cnt.values()):6d} {total/1e6:9.2f}")
if unk:
    print('unmapped imported files:', len(unk), sum(s for s, _ in unk) / 1e6, 'MB')
    for s, p in sorted(unk, reverse=True)[:10]:
        print('  ', s, p)
# write rows for later use
with open(os.path.splitext(tsv)[0] + '_cat.tsv', 'w') as f:
    for size, c, src, p in sorted(rows, reverse=True):
        f.write(f"{size}\t{c}\t{src}\t{p}\n")
