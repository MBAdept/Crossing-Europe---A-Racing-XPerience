"""AS5aR2: far-facade comparison from LODCOL logs (k6_scene --mode=lodcol): per model luma and dark tenth (p10) of
lod0 at 60 m and lod1 at 250 m (and the sprite), before (log A) and after (log B).
   python3 lodcmp.py <before.log> <after.log>"""
import re
import sys


def parse(path):
    out = {}
    for line in open(path):
        if "LODCOL" not in line:
            continue
        m = re.match(r".*LODCOL (\S+) (\d+)m\s+(.*)", line)
        if not m:
            continue
        name, dist, rest = m.group(1), int(m.group(2)), m.group(3)
        for lvl in ("lod0", "lod1", "sprite"):
            mm = re.search(lvl + r" rgb\((\d+),(\d+),(\d+)\) L([\d.]+) S([\d.]+) H\d+ n\d+ sd([\d.]+) p10 (\d+) p90 (\d+)", rest)
            if mm:
                out[(name, dist, lvl)] = dict(L=float(mm.group(4)), p10=int(mm.group(7)), p90=int(mm.group(8)),
                                              sd=float(mm.group(6)))
    return out


A, B = parse(sys.argv[1]), parse(sys.argv[2])
names = sorted({k[0] for k in B})
print("%-22s | %-34s | %-34s | %s" % ("Modell", "vorher: L 60->250 (lod1), p10 60->250", "nachher", "Sprite p10 60->250"))
for n in names:
    def row(D):
        a, b = D.get((n, 60, "lod0")), D.get((n, 250, "lod1"))
        if not a or not b:
            return "-"
        return "L %.1f -> %.1f (%+.1f %%), p10 %d -> %d (%+d)" % (a["L"], b["L"], 100 * (b["L"] / a["L"] - 1), a["p10"],
                                                                  b["p10"], b["p10"] - a["p10"])
    s0, s1 = B.get((n, 60, "sprite")), B.get((n, 250, "sprite"))
    sp = "%d -> %d (%+d)" % (s0["p10"], s1["p10"], s1["p10"] - s0["p10"]) if s0 and s1 else "-"
    print("%-22s | %-34s | %-34s | %s" % (n, row(A), row(B), sp))
