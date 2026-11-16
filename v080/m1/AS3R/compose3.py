"""AS3R scratch: race pictures Modern before (KRITIK-3, be866d2) | after (final head), same arguments and seed."""
import sys
sys.argv = [sys.argv[0], "none"]
exec(open("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/compose.py", encoding="utf-8").read())
KAB = M1 + "/KRITIK-3/ab"
AB = M1 + "/AS3R/ab"


def pair(name, idx, box):
    b = crop(KAB + "/%s_modern_%s.png" % (name, idx), box)
    a = crop(AB + "/%s_modern_%s.png" % (name, idx), box)
    return [(b, "vorher (be866d2)"), (a, "nachher")]


sheet(DL + "/08_rennen_modern_vorher_nachher.jpg",
      "Im Rennen: Modern vorher | nachher (gleicher Simulationszustand, gleiche Saat)",
      "Zeilen 1–2: Kiel–Hamburg km 54,9 auf dem Steam Deck (Eiche, Busch, Birke; Zeile 2 vergrößert); Zeilen 3–4: Barcelona–Montpellier km 42,7, Hoch (Olive, Palmen, Zypressen; Zeile 4 vergrößert)",
      [pair("kh54_deck", "01", (0, 0.12, 1, 0.62)),
       pair("kh54_deck", "01", (0.04, 0.16, 0.42, 0.5)),
       pair("bm42_hoch", "01", (0, 0.33, 1, 0.8)),
       pair("bm42_hoch", "01", (0.5, 0.33, 1.0, 0.68))])
