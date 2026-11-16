#!/usr/bin/env python3
"""AU-R: the final measured numbers into the report drafts (replacements must each match once)."""
import os

S = os.path.dirname(os.path.abspath(__file__))
REP = {
    "bericht_head.md": [
        ("Unfall und Höchsttempo bei Gesamtlautstärke 1,0 bis −0,6 dBTP", "Unfall und schlimmster Fall bei Gesamtlautstärke 1,0 bis −0,5 dBTP"),
        ("alles höchstens −1,5 dBTP", "alles höchstens −1,6 dBTP"),
    ],
    "bericht_sections.md": [
        ("**bestanden**: −1,71 / −3,06 / −1,62 dBTP (Lkw −1,66); vorher −0,62 / −2,77 / −0,47",
         "**bestanden**: −1,71 / −2,93 / −1,59 dBTP (Lkw −1,66); vorher −0,62 / −2,77 / −0,47"),
        ("**200 km/h auf Beton nicht**: 12 Eingriffe je Minute, höchstens 1,4 dB (mit dem Pegel von AU-C1 wären es 15 und 1,5 dB) – die Plattenschläge liegen bei −2,5 dBFS",
         "**200 km/h auf Beton nicht**: 12 Eingriffe je Minute, höchstens 1,0 dB (mit dem Pegel von AU-C1 wären es 16 und 1,5 dB) – die Plattenschläge liegen bei −2,7 dBFS"),
        ("**bestanden**: −14,8 LUFS (Gesamtlautstärke 0,8)", "**bestanden**: −14,9 LUFS (Gesamtlautstärke 0,8)"),
    ],
    "bericht_sections2.md": [
        ("| Höchsttempo, Motor + Fahrbahn + Wind (Asphalt) | −2,77 | **−3,06** | 0 |",
         "| Höchsttempo, Motor + Fahrbahn + Wind (Asphalt) | −2,77 | **−2,93** | 0 |"),
        ("| −0,47 | **−1,62** | bis 7,2 dB (die Szene liegt fast durchgehend darüber; ihre Lautheit −8,1 → −9,3 LUFS) |",
         "| −0,47 | **−1,59** | bis 8,0 dB (die Szene liegt fast durchgehend darüber; ihre Lautheit −8,1 → −9,3 LUFS) |"),
        ("| Reisen 200 km/h auf Beton, 60 s | (15 Überschreitungen, höchstens 1,47 dB) | – | 12 Eingriffe, höchstens 1,40 dB, 2,7 % der Zeit |",
         "| Reisen 200 km/h auf Beton, eine Minute | (15 Überschreitungen in 57 s, höchstens 1,47 dB) | – | 11 Eingriffe in 56 s, höchstens 0,96 dB, 2,4 % der Zeit |"),
        ("Höchsttempo: −14,8 LUFS bei Gesamtlautstärke\n0,8 (Plan −15 ± 1).", "Höchsttempo: −14,9 LUFS bei Gesamtlautstärke\n0,8 (Plan −15 ± 1)."),
    ],
    "bericht_sections3.md": [
        ("Die Plattenschläge liegen dort bei −2,5 dBFS, genau an der Obergrenze\n   −2 dB; 12 Eingriffe je Minute bis 1,4 dB",
         "Die Plattenschläge liegen dort bei −2,7 dBFS, knapp unter der Obergrenze\n   −2 dB; 12 Eingriffe je Minute bis 1,0 dB"),
    ],
}
for f, pairs in REP.items():
    p = os.path.join(S, f)
    t = open(p, encoding="utf-8").read()
    for a, b in pairs:
        n = t.count(a)
        if n != 1:
            print("NICHT EINMAL (%d): %s :: %s" % (n, f, a[:70]))
            continue
        t = t.replace(a, b)
    open(p, "w", encoding="utf-8").write(t)
print("fertig")
