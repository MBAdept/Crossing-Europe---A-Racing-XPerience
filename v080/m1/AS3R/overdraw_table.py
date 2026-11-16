"""AS3R scratch: alpha-test overdraw table at 20 m (overdraw.gd + prop_scene --mode=lods --d0=20)."""
import re

L = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/logs"
od = {}
for line in open(L + "/f_overdraw20.txt", encoding="utf-8"):
    m = re.match(r"UEBERZEICHNUNG (\S+) @20 m Kuppeln/Karten (\d+) Dreiecke leaves (\d+) Bildfläche (\d+) px", line)
    if m:
        od[m.group(1)] = (int(m.group(2)), int(m.group(3)), int(m.group(4)))
cov = {}
for line in open(L + "/f_d20.txt", encoding="utf-8"):
    m = re.match(r"STUFEN (\S+)\s+lod0@20m rgb\([\d,]+\) (\d+) px", line)
    if m:
        cov[m.group(1)] = int(m.group(2))
# AS3 before (deliver/AS3/bericht.md 4.4)
before = {"tree_oak": 5.3, "tree_birch": 3.1, "tree_beech": 6.7, "tree_poplar": 9.7, "tree_olive": 4.8, "tree_pine": 7.1,
          "tree_spruce": 8.7, "tree_cypress": 1.9, "tree_palm": 1.5, "tree_oak_b": 5.8, "tree_birch_b": 3.3,
          "tree_beech_b": 6.5, "tree_poplar_b": 9.2, "tree_olive_b": 5.0, "tree_pine_b": 8.5, "tree_spruce_b": 7.4,
          "tree_cypress_b": 1.8, "tree_palm_b": 1.5, "bush_round": 4.3, "bush_round_b": 4.9, "bush_low": 3.7,
          "cover_bush": 4.3, "heather": 3.4}
print("| Modell | Kuppeln/Karten lod0 | Laub-Dreiecke lod0 | Laubfläche (px) | gedeckte Pixel | Überzeichnung nachher (vorher AS3) |")
print("|---|---|---|---|---|---|")
for mid, (n, t, a) in od.items():
    c = cov.get(mid)
    name = mid.split("/")[1]
    print("| %s | %d | %d | %s | %s | %s (%s) |" % (name, n, t, format(a, ",").replace(",", " "),
          format(c, ",").replace(",", " ") if c else "–", ("%.1f×" % (a / c)) if c else "–",
          ("%.1f×" % before[name]) if name in before else "–"))
