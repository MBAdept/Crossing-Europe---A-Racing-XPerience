#!/usr/bin/env python3
"""QA-R7a: drawn props of the real builds, base vs R7a (dump lines: <dir> <seg> <j> <set> <km>).
Prints per direction: drawn base / R7a, came back (R7a only), newly dropped (base only), by set family; totals."""
import collections, sys
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/logs"


def load(p):
    d = collections.defaultdict(dict)
    for line in open(p):
        a = line.split()
        if len(a) < 5:
            continue
        d[a[0]][(int(a[1]), int(a[2]))] = (a[3], float(a[4]))
    return d


def fam(s):
    s = s.split("/")[-1]
    if s.startswith("city_"):
        return "city_house"
    for k in ["oak", "birch", "beech", "pine", "spruce", "fir", "poplar", "cypress", "olive", "palm", "tree", "conifer", "willow", "linden", "chestnut"]:
        if k in s:
            return "tree"
    if "rock" in s or "cliff" in s or "stone" in s:
        return "rock"
    if "bush" in s or "heath" in s or "hedge" in s or "shrub" in s or "grass" in s:
        return "plant"
    if "house" in s or "farm" in s or "barn" in s or "church" in s or "building" in s or "villa" in s or "hut" in s:
        return "building"
    return "other"


b = load(S + "/dump_all_base.txt")
r = load(S + "/dump_all_r7a.txt")
tot_b = tot_r = 0
back = collections.Counter()
newly = collections.Counter()
newly_list = []
for d in sorted(set(b) | set(r)):
    kb, kr = set(b[d]), set(r[d])
    tot_b += len(kb)
    tot_r += len(kr)
    bk = kr - kb
    nw = kb - kr
    for k in bk:
        back[fam(r[d][k][0])] += 1
    for k in nw:
        newly[fam(b[d][k][0])] += 1
        newly_list.append((d, k, b[d][k]))
    if "-v" in sys.argv:
        print(f"{d:42s} base {len(kb):6d} r7a {len(kr):6d} back {len(bk):5d} newly dropped {len(nw):4d}")
print(f"TOTAL directions {len(set(b) | set(r))}: drawn base {tot_b}, R7a {tot_r}, came back {sum(back.values())} {dict(back)}, newly dropped {sum(newly.values())} {dict(newly)}")
for d, k, v in newly_list[:40]:
    print(f"  NEWLY {d} seg {k[0]} j {k[1]} {v[0]} km {v[1]}")
