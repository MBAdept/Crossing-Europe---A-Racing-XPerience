#!/usr/bin/env python3
"""AU-R: bericht.md from the draft (deliver/AU-R/bericht.md, section 1) and the section files, placeholders filled.
usage: assemble_bericht.py <commit> <tests line> <golden line>"""
import os
import sys

S = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(S, "..", "..", "deliver", "AU-R")
commit, tests, golden = sys.argv[1], sys.argv[2], sys.argv[3]
head = open(os.path.join(S, "bericht_head.md"), encoding="utf-8").read()
s1 = open(os.path.join(S, "bericht_sections.md"), encoding="utf-8").read()
s2 = open(os.path.join(S, "bericht_sections2.md"), encoding="utf-8").read()
s3 = open(os.path.join(S, "bericht_sections3.md"), encoding="utf-8").read()
r1 = open(os.path.join(S, "r1_table.md"), encoding="utf-8").read().strip()
ct = open(os.path.join(S, "country_table.md"), encoding="utf-8").read().strip().splitlines()
ct = "\n".join(l.replace("0.", "0,").replace("1.", "1,") if l.startswith("| ") and not l.startswith("| Land") else l
               for l in ct if l.startswith("|"))

char_summary = ("**bestanden**: im Spiel ohne Zufall höchstens 0,97 dB je Terz (Beton, 398 Hz), Lautheit höchstens "
                "0,27 LU daneben; die Schleifen selbst (gehörter Klang nachgebildet) höchstens 0,71 dB")
char_text = """Im Spiel aufgenommen, ohne Zufall (Drift, Böen und Vorbeifahrten aus), 20 s, Gesamtlautstärke 1,0; Terzen
25 Hz–12,5 kHz bis 30 dB unter der lautesten:

| Aufnahme | Lautheit vorher → nachher | größte Terz-Abweichung |
|---|---|---|
| Asphalt 130 km/h, nur Fahrbahn | −27,80 → −27,64 LUFS (+0,16 LU) | 0,49 dB bei 251 Hz |
| Beton 130 km/h, nur Fahrbahn | −22,38 → −22,34 (+0,04) | 0,97 dB bei 398 Hz |
| Pflaster 50 km/h, nur Fahrbahn | −20,98 → −21,20 (−0,22) | 0,74 dB bei 40 Hz |
| Wind 130 km/h, nur Wind | −34,77 → −34,75 (+0,03) | 0,38 dB bei 32 Hz |
| Spielmix Asphalt 130 | −14,91 → −14,99 (−0,08) | 0,39 dB |
| Spielmix Beton 130 | −14,85 → −15,11 (−0,27) | 0,68 dB |
| Spielmix Pflaster 50 | −17,09 → −16,93 (+0,15) | 0,50 dB |

Der Weg dahin: Die neuen Schleifen (andere Seeds, 2–3-mal so lang) wichen zuerst in den tiefen Terzen bis 3,5 dB ab
(Pflaster rechts). Sie sind an die Schleifen von AU-C1 angeglichen – und zwar an das, was davon **zu hören** war:
AU-C1 las dieselbe Schleife auf zwei Spielern eine halbe Länge versetzt, dadurch addierten sich ihre Harmonischen
abwechselnd gleich- und gegenphasig (beim Pflaster +1,0 dB bei 126 Hz). Ohne diese Nachbildung lag Pflaster bei
1,00 dB, der Spielmix Pflaster bei 1,05 dB; mit ihr bei 0,74 und 0,50 dB. Nachbildung des Gehörten für alle Schleifen
bei ihrem Bezugstempo: höchstens 0,71 dB (Pflaster bei 10 kHz), Varianten von Glas, Kleinteilen, Lkw-Schlag
höchstens 0,91 dB."""

hoer = """| Datei | Inhalt |
|---|---|
| `fahrt_kiel_hamburg_vorher_nachher.mp3` (1:32) | dieselbe Fahrt zweimal, AU-C1 und AU-R, 2 s Stille dazwischen: Autobahn in den Beton, Köhlbrandbrücke, Rüttelstreifen, Bankett, Leitplanke, Hamburger Innenstadt – dort nachher Asphalt ab 1:21,9, **Pflaster ab 1:23,9, wieder Asphalt ab 1:29,9** (vorher durchgehend Pflaster ab 0:35,7) |
| `fahrt_kiel_hamburg_spielmix_neu.mp3` (0:45) | dieselbe Fahrt nachher mit Rennmusik im Spielmix; Hamburg: Asphalt, Pflaster ab 0:36,4, Asphalt ab 0:42,4 |
| `aufprall_abwechslung_neu.mp3` (0:21) | acht Unfälle (schwer und mittel, einer gegen einen Lkw) mit den gewürfelten Varianten, Pegeln und Einsätzen je Schicht in der .txt |
| `schnee_neu.mp3` (0:17) | Schnee bei 50, 90 und 130 km/h mit der eigenen Knirsch-Schleife |
| `koehlbrandbruecke_fugen_vorher_nachher.mp3` (0:23) | die Brücke mit 120 km/h: vorher 12 Fugen (alle 24 m), nachher 4 (Enden und alle 100 m) |
| `pruefung_qc_determinismus.txt`, `pruefung_run_tests.txt`, `pruefung_golden.txt` | die Prüfläufe |"""

urteil = """- **Was die Messungen sagen**: Die gemessenen Fehler von KRITIK-FAHRBAHN sind behoben, wo es der Vertrag zulässt:
  kein Pochen im Sekundentakt mehr auf Asphalt und Pflaster (0,60 / 0,98 → 0,11 / 0,15), jede Altstadt mit
  Pflaster und Asphalt im Wechsel, Fugen nur dort, wo eine Brücke welche hat, keine Rüttellinie an der Tankspur,
  laute Momente bei voller Lautstärke mindestens 1,6 dB unter 0 dBTP, Unfälle in Varianten. Die Klangfarbe der
  Schleifen ist im Spiel auf 1 dB je Terz und 0,3 LU geblieben.
- **Was nicht erreicht ist**: Beton wiederholt sich weiter im Plattentakt (0,65) – das ist der Takt selbst, nicht
  die Schleife; bei 200 km/h auf Beton greift der Begrenzer etwa 12-mal je Minute um bis 1 dB; vier kleine Länder
  treffen ihren Betonanteil nicht. Alle drei hängen am Pegel der Platten oder an zu wenigen Abschnitten.
- **Was ein Ohr prüfen muss**: ob die schweren Unfälle mit dem 2,5 dB leiseren tiefen Schlag noch genug Wucht haben;
  ob die langsame Pegeldrift je Seite (±1,5 dB) natürlich wirkt oder als Schwanken auffällt; ob Ogg q5 bei den
  Rauschschleifen hörbar ist (gemessen: Nähte sauber, Spektrum gleich).
- **Gehört hat es hier niemand.** Das Urteil liegt bei dir – die Hörproben stehen in diesem Ordner."""

text = head + "\n" + s1 + "\n" + s2 + "\n" + s3
rep = {"{COMMIT}": commit, "{TESTS}": tests, "{GOLDEN}": golden, "{CHAR_SUMMARY}": char_summary,
       "{CHAR_TEXT}": char_text, "{R1_TABLE}": r1, "{COUNTRY_TABLE}": ct, "{HOERPROBEN_TABLE}": hoer, "{URTEIL}": urteil,
       "{R1_ASPH}": "0,603 → 0,111 (0,6–1,6 kHz)", "{R1_COB}": "0,982 → 0,146 (2,5–8 kHz)",
       "{R1_CONC}": "0,887 → 0,647"}
for k, v in rep.items():
    text = text.replace(k, v)
left = [k for k in ("{", "}") if False]
open(os.path.join(D, "bericht.md"), "w", encoding="utf-8").write(text)
import re
print("Platzhalter übrig:", re.findall(r"\{[A-Z_0-9]+\}", text))
