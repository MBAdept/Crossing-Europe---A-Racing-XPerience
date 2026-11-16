import re
import sys

lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
for i, l in enumerate(lines):
    if '"tint"' not in l or '"set"' not in l:
        continue
    ctx = []
    ind = len(l) - len(l.lstrip("\t"))
    for j in range(i - 1, -1, -1):
        lj = lines[j]
        indj = len(lj) - len(lj.lstrip("\t"))
        m = re.search(r'"([^"]+)":\s*[\[{]', lj)
        if indj < ind and m:
            ctx.append(m.group(1))
            ind = indj
        if indj <= 1:
            break
    s = re.search(r'"set": "([^"]+)"', l).group(1)
    tt = re.search(r'"tint": "([^"]+)"', l).group(1)
    print(i + 1, s, tt, "/".join(reversed(ctx)))
