"""AS5a1 scratch: fill the TABELLE placeholder of docs/modelle.md section 20 from budget_table.md.
   python3 fill_docs_table.py <worktree>"""
import os
import re
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1/"
WT = sys.argv[1]
count = {"city_german_house": 282, "city_german_old_fachwerk": 99, "city_german_old_fachwerk_b": 95,
         "city_german_mietshaus": 77, "city_german_gruenderzeit": 72, "city_hanse_gabled": 54,
         "city_german_old_barock": 32, "city_hanse_speicher": 10, "city_german_office": 7, "city_hanse_kontor": 4,
         "city_hanse_crane": 3}
rows = ["| Set | Platzierungen Kiel–Nürnberg | Dreiecke lod0 / lod1 | Atlas | px/m Straßenwand (Modellmaß) | "
        "Archiv Netze / Texturen |", "|---|---|---|---|---|---|"]


def n(v):
    return "{:,}".format(int(v)).replace(",", " ")


for line in open(S + "budget_table.md"):
    m = re.match(r"\| `(\w+)` \| (\d+) / (\d+) \| [^|]+\| ([^|]+)\| ([\d.]+)–([\d.]+) \|[^|]+\| \d+ \((\d+)\) \| "
                 r"\d+ \((\d+)\) \|", line)
    if not m:
        continue
    mid, t0, t1, atl, p0, p1, mz, tz = m.groups()
    pm = ("%.0f–%.0f" % (float(p0), float(p1))) if p0 != p1 else "%.0f" % float(p0)
    rows.append("| `%s` | %d | %s / %s | %s | %s | %.0f / %.0f kB |" % (mid, count[mid], n(t0), n(t1), atl.strip(), pm,
                                                                       int(mz) / 1000, int(tz) / 1000))
tab = "\n".join(rows)
p = os.path.join(WT, "docs", "modelle.md")
s = open(p).read()
if "\nTABELLE\n" not in s:
    sys.exit("kein Platzhalter TABELLE")
s = s.replace("\nTABELLE\n", "\n" + tab + "\n\nSumme der elf Modelle im Archiv (deflate -9 je Datei, wie `tools/pck_report.py`): "
              "Netze 0,79 MB, Texturen\n5,25 MB. Zwei Zeichenaufrufe je Stufe (`baked` bzw. `baked_cutout` + `vpbr`), kein "
              "Fernbild.\n", 1)
open(p, "w").write(s)
print(tab)
