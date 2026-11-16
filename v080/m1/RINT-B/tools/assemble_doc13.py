#!/usr/bin/env python3
"""Assembles renderer-modern.md §13 from the scratch drafts and appends it to the doc (RINT-B helper)."""
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B/"
doc = sys.argv[1]
head = open(S + "doc13.md").read()
cut = head.index("### 13.4 Fahrzeuge im echten Rig")
head = head[:cut]
rim_old = """  Oberkante mit der Tiefe entlang der Blickachse, so ist sie auf dem Bild eine gerade Linie): unter den Silhouetten
  zeigt sich die Leinwand nie."""
rim_new = """  Oberkante mit der Tiefe entlang der Blickachse, so ist sie auf dem Bild eine gerade Linie): unter den Silhouetten
  zeigt sich die Leinwand nie. Der Rand zeigt das Mittel des fernen Bodens (`ce_ground_field_mean`) – das Muster der
  Felder lief auf der 2,4 km fernen Wand in senkrechte Streifen."""
assert rim_old in head
head = head.replace(rim_old, rim_new)
tail = open(S + "doc13_final_tail.md").read()
extra = open(S + "doc13_extra.md").read()
s9 = open(S + "doc13_s9.md").read()
text = head + tail + "\n" + extra + s9
d = open(doc).read()
if "## 13. Zweite Hälfte der Zusammenführung" in d:
    print("schon drin")
    sys.exit(1)
if not d.endswith("\n"):
    d += "\n"
d += "\n" + text
open(doc, "w").write(d)
print("angehängt: %d Zeilen" % text.count("\n"))
