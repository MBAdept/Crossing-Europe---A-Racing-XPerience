"""AS3R scratch: outline against the sprite, before (KRITIK-3 outline_all.log) and after (<tag>_outline.log)."""
import re
import sys

M1 = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1"


def umriss(path):
    out = {}
    for line in open(path, encoding="utf-8"):
        if not line.startswith("UMRISS"):
            continue
        mid = line.split()[1]
        lv = {}
        for seg in line.split("  ", 1)[1].split("|"):
            m = re.match(r"\s*(lod0|lod1|impostor) ([\d.]+) % außerhalb, Sprite zu ([\d.]+) % gedeckt, Stamm in 1,5 m: Modell ([\d.]+) m / Sprite ([\d.]+) m", seg)
            if m:
                lv[m.group(1)] = tuple(float(m.group(i)) for i in range(2, 6))
        out[mid] = lv
    return out


tag = sys.argv[1] if len(sys.argv) > 1 else "z"
b = umriss(M1 + "/KRITIK-3/logs/outline_all.log")
a = umriss(M1 + "/AS3R/logs/%s_outline.log" % tag)
print("| Modell | lod0 außerhalb / Sprite gedeckt vorher | nachher | Fernbild vorher | nachher | Stamm 1,5 m lod1 / Fernbild / Sprite nachher |")
print("|---|---|---|---|---|---|")
for mid, lv in a.items():
    bb = b.get(mid, {})

    def f(d, k):
        v = d.get(k)
        return ("%.1f / %.1f %%" % (v[0], v[1])).replace(".", ",") if v else "–"
    l1 = lv.get("lod1")
    im = lv.get("impostor")
    stem = ("%.2f / %.2f / %.2f m" % (l1[2], im[2], im[3])).replace(".", ",") if (l1 and im) else "–"
    print("| %s | %s | %s | %s | %s | %s |" % (mid.split("/")[1], f(bb, "lod0"), f(lv, "lod0"), f(bb, "impostor"),
                                              f(lv, "impostor"), stem))
