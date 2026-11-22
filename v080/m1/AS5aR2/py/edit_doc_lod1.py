p = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2/doc22_draft.md"
s = open(p).read()
rep = [
("""- **lod1 ohne Alpha-Test (`lod1_opaque`).** Die acht Häuser mit Ausschneide-Klasse (Mietshaus, Gründerzeit,
  Südhaus, Loire-Haus, Lyoner Haus, Haussmann, Eckhaus, Chalet) zeichnen lod1 als `baked` mit Rückseiten-Culling: ein""",
 """- **lod1 ohne Alpha-Test (`lod1_opaque`).** Sechs Häuser mit Ausschneide-Klasse (Mietshaus, Gründerzeit, Lyoner
  Haus, Haussmann, Eckhaus, Chalet) zeichnen lod1 als `baked` mit Rückseiten-Culling: ein"""),
("""  lod1 zeigt nur diese Masse in Originalgröße. Weil die Karten Alpha brauchen und ein Stadthaus zwei Zeichenaufrufe
  hat, gibt es sie nur bei Häusern mit Ausschneide-Klasse (`single_cutout`): Südhaus und Loire-Haus (dieses ist dafür
  jetzt `single_cutout`).""",
 """  lod1 bekommt weniger, größere Karten (`n1`, `half1`) und behält dafür die Ausschneide-Klasse – ohne sie zeigte lod1
  nur den Kern, und der Stufenwechsel bei 60 m tauschte beim Südhaus 34,8 statt 16,4 % der Pixel (gemessen). Weil die
  Karten Alpha brauchen und ein Stadthaus zwei Zeichenaufrufe hat, gibt es sie nur bei Häusern mit Ausschneide-Klasse
  (`single_cutout`): Südhaus und Loire-Haus (dieses ist dafür jetzt `single_cutout`)."""),
("""`lod1_opaque` (bool), `leaf_cards` {Kronen-Präfix: dict(n, half, out, el, crown_w, down, core, atlas)}, `leaf_px`""",
 """`lod1_opaque` (bool), `leaf_cards` {Kronen-Präfix: dict(n, half, out, el, crown_w, down, core, atlas, n1, half1)}, `leaf_px`"""),
]
for a, b in rep:
    assert s.count(a) == 1, a[:60]
    s = s.replace(a, b)
open(p, "w").write(s)
print("ok")
