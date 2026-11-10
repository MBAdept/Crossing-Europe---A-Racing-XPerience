#!/usr/bin/env python3
"""Per-category deflate size of a PCK embedded in an executable: what each category contributes to the
release archive (zip -9 / gzip -9 are deflate too). Usage: pck_compressed.py <exe> <listing_cat.tsv>"""
import sys, zlib, collections, importlib.util, os, time
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('pck_list', os.path.join(here, 'pck_list.py'))
pl = importlib.util.module_from_spec(spec); spec.loader.exec_module(pl)
exe, cat_tsv = sys.argv[1], sys.argv[2]
info, files = pl.read_pck(exe)
cat = {}
for line in open(cat_tsv):
    size, c, src, p = line.rstrip('\n').split('\t')
    cat[p] = c
raw = collections.Counter(); comp = collections.Counter()
t0 = time.time()
with open(exe, 'rb') as f:
    # engine part
    f.seek(0); eng = f.read(info['start'])
    raw['ENGINE (template)'] = len(eng); comp['ENGINE (template)'] = len(zlib.compress(eng, 9)); del eng
    base = info['start'] + info['file_base']
    for p, size, off, fl in files:
        f.seek(base + off)
        data = f.read(size)
        c = cat.get(p, 'other')
        raw[c] += size
        comp[c] += len(zlib.compress(data, 9))
tr = sum(raw.values()); tc = sum(comp.values())
print(f"{'category':28s} {'raw MB':>9s} {'deflate MB':>11s} {'ratio':>6s} {'% of archive':>12s}")
for c, s in sorted(comp.items(), key=lambda kv: -kv[1]):
    print(f"{c:28s} {raw[c]/1e6:9.2f} {s/1e6:11.2f} {s/max(raw[c],1):6.2f} {100*s/tc:12.1f}")
print(f"{'TOTAL':28s} {tr/1e6:9.2f} {tc/1e6:11.2f} {tc/tr:6.2f}   ({time.time()-t0:.0f} s)")
