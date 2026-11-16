#!/usr/bin/env python3
"""QA lens 3: compares the game data (PCK) of two exported executables file by file (MD5 of every file's bytes).
   pck_diff.py <tools dir with pck_report.py> <old exe> <new exe> [--tsv out.tsv]"""
import sys, hashlib, collections, os
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
import pck_report as pr
old, new = sys.argv[2], sys.argv[3]
def digest(path):
    info, files = pr.read_pck(path)
    out = {}
    with open(path, 'rb') as f:
        for name, off, size, flags in files:
            f.seek(off); out[name] = (hashlib.md5(f.read(size)).hexdigest(), size)
    return info, out
io, fo = digest(old); inn, fn = digest(new)
print('alt: %s  PCK %d Dateien, Programm davor %d Bytes' % (os.path.basename(old), len(fo), io['start']))
print('neu: %s  PCK %d Dateien, Programm davor %d Bytes' % (os.path.basename(new), len(fn), inn['start']))
only_old = sorted(set(fo) - set(fn)); only_new = sorted(set(fn) - set(fo))
changed = sorted(n for n in fo if n in fn and fo[n][0] != fn[n][0]); same = [n for n in fo if n in fn and fo[n][0] == fn[n][0]]
def group(names, table):
    c = collections.Counter(); b = collections.Counter()
    for n in names:
        parts = n.split('/'); k = '/'.join(parts[:3]) if parts[0] in ('assets', '.godot') else '/'.join(parts[:2])
        c[k] += 1; b[k] += table[n][1]
    return ['%s: %d Dateien, %.1f kB' % (k, c[k], b[k] / 1000) for k in sorted(c)]
print('identisch: %d Dateien, %.1f MB' % (len(same), sum(fo[n][1] for n in same) / 1e6))
print('nur im alten Build: %d' % len(only_old)); [print('   ', n) for n in only_old[:40]]
print('geändert: %d' % len(changed)); [print('   %-70s %9d -> %9d Bytes' % (n, fo[n][1], fn[n][1])) for n in changed[:80]]
print('nur im neuen Build: %d Dateien, %.2f MB' % (len(only_new), sum(fn[n][1] for n in only_new) / 1e6)); [print('   ', g) for g in group(only_new, fn)]
# Arcade assets: every file below these roots must be identical
frozen_roots = ('assets/sprites/', 'assets/audio/engines/', 'assets/audio/traffic/', 'assets/audio/music/', 'data/', 'scripts/gameplay/', 'scripts/data/')
import re
def is_frozen(n):
    if n.startswith(frozen_roots): return True
    return False
bad = [n for n in changed + only_old if is_frozen(n)]
imported_changed = [n for n in changed if n.startswith('.godot/imported/')]
imported_only_old = [n for n in only_old if n.startswith('.godot/imported/')]
print('eingefrorene Pfade geändert oder entfernt: %d %s' % (len(bad), bad[:10]))
print('importierte Dateien (.godot/imported) geändert: %d, entfernt: %d' % (len(imported_changed), len(imported_only_old)))
if '--tsv' in sys.argv:
    with open(sys.argv[sys.argv.index('--tsv') + 1], 'w') as t:
        for n in sorted(set(fo) | set(fn)):
            t.write('%s\t%s\t%s\t%s\n' % (n, 'gleich' if n in same else 'geändert' if n in changed else 'nur alt' if n in only_old else 'nur neu', fo.get(n, ('', ''))[1], fn.get(n, ('', ''))[1]))
