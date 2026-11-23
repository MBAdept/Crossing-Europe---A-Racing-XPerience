#!/usr/bin/env python3
"""FIX-R7a: drawn props of the real builds (realbuild.gd dumps: <dir> <seg> <j> <set> <km>), variant vs base and vs
R7a. dumpdiff.py <variant dump> -> came back / newly dropped against base and R7a, by family; per position near the
review places (km window)."""
import collections, gzip, sys

Q = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/logs"


def load(p):
    d = collections.defaultdict(dict)
    op = gzip.open if p.endswith(".gz") else open
    with op(p, "rt") as f:
        for line in f:
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


def diff(a, b):
    """items in b not in a (came back), items in a not in b (newly dropped)"""
    back = collections.Counter()
    gone = collections.Counter()
    nb = ng = 0
    for d in set(a) | set(b):
        ka, kb = set(a[d]), set(b[d])
        for k in kb - ka:
            back[fam(b[d][k][0])] += 1
            nb += 1
        for k in ka - kb:
            gone[fam(a[d][k][0])] += 1
            ng += 1
    return nb, back, ng, gone


v = load(sys.argv[1])
base = load(Q + "/dump_all_base.txt.gz")
r7a = load(Q + "/dump_all_r7a.txt.gz")
tot = lambda d: sum(len(x) for x in d.values())
print("drawn: base %d, R7a %d, variant %d" % (tot(base), tot(r7a), tot(v)))
nb, back, ng, gone = diff(base, v)
print("vs base: back %d %s; newly dropped %d %s" % (nb, dict(back.most_common()), ng, dict(gone.most_common())))
nb, back, ng, gone = diff(r7a, v)
print("vs R7a:  back %d %s; dropped %d %s" % (nb, dict(back.most_common()), ng, dict(gone.most_common())))
# review places: direction, km window
places = {"T1": ("kassel_wuerzburg__kassel", 46.5), "T2": ("kassel_wuerzburg__kassel", 61.9), "T3": ("saragossa_pau__saragossa", 172.8),
          "T4": ("saragossa_pau__saragossa", 198.8), "C1": ("dortmund_frankfurt__dortmund", 221.0), "S0": ("kiel_hamburg__kiel", 0.0),
          "S4": ("kiel_hamburg__kiel", 80.0), "Muenchen": ("muenchen_nuernberg__nuernberg", 161.7),
          "Belgrad": ("slavonski_brod_belgrad__slavonski_brod", 187.4), "Hannover": ("hamburg_hannover__hamburg", 142.4),
          "Lyon": ("montpellier_lyon__montpellier", 297.4), "Bern": ("lyon_bern__lyon", 302.7), "Nuernberg": ("wuerzburg_nuernberg__wuerzburg", 102.7)}
print("per place (items 0..0.3 km ahead of the camera): base / R7a / variant")
for name, (d, km) in places.items():
    def cnt(x):
        return sum(1 for k, (s, kk) in x[d].items() if km - 0.01 <= kk <= km + 0.3)
    def keys(x):
        return {k for k, (s, kk) in x[d].items() if km - 0.01 <= kk <= km + 0.3}
    kb, kr, kv = keys(base), keys(r7a), keys(v)
    print("  %-9s %4d / %4d / %4d   vs R7a: +%d -%d   vs base: +%d -%d" % (name, len(kb), len(kr), len(kv), len(kv - kr), len(kr - kv),
                                                                           len(kv - kb), len(kb - kv)))
