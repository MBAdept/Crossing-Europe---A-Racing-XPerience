### 5.1 Prüfer, Budgets, Zeichenaufrufe, Bytes (auf der Kopie, gemessen)

`python3 tools/blender/validate_models.py --report` → `CHECK models OK` (logs/validate.log). Bytes mit derselben
Rechnung wie `tools/pck_report.py` (deflate -9 je Datei der `.res`, `model.json` und importierten `.ctex`;
`py/share.py`, logs/share.log):

| Modell | Platzierungen K–N | Dreiecke lod0 / lod1 | Aufrufe je Stufe | Atlas | Netze B (Archiv) | Texturen PCK (Archiv) |
|---|---|---|---|---|---|---|
| `city_german_house` | 282 | 2 962 / 2 526 | 2 / 2 | 1024² PNG | 97 896 (96 769) | 873 944 (253 529) |
| `city_german_old_fachwerk` | 99 | 6 913 / 1 041 | 2 / 2 | 2048×1024 | 102 857 (99 804) | 1 747 768 (506 772) |
| `city_german_old_fachwerk_b` | 95 | 3 332 / 978 | 2 / 2 | 2048×1024 | 57 697 (55 938) | 1 747 768 (401 478) |
| `city_german_mietshaus` | 77 | 2 176 / 506 | 2 / 2 | 2048×1024 BC3 | 34 819 (33 586) | 3 145 888 (483 204) |
| `city_german_gruenderzeit` | 72 | 4 410 / 2 394 | 2 / 2 | 2048×1024 BC3 | 78 280 (76 412) | 3 145 888 (551 904) |
| `city_hanse_gabled` | 54 | 3 712 / 1 233 | 2 / 2 | 2048×1024 | 69 663 (68 486) | 1 747 768 (664 333) |
| `city_german_old_barock` | 32 | 4 539 / 2 385 | 2 / 2 | 2048×1024 | 90 772 (88 684) | 1 747 768 (462 191) |
| `city_hanse_speicher` | 10 | 8 950 / 1 283 | 2 / 2 | 2048×1024 | 117 875 (114 183) | 1 747 768 (739 759) |
| `city_german_office` | 7 | 427 / 203 | 2 / 2 | 2048×1024 | 11 980 (11 020) | 1 747 768 (360 457) |
| `city_hanse_kontor` | 4 | 9 865 / 749 | 2 / 2 | 2048×1024 | 113 220 (108 978) | 1 747 768 (714 886) |
| `city_hanse_crane` | 3 | 1 260 / 1 052 | 2 / 2 | 1024² PNG | 41 091 (39 384) | 873 944 (114 492) |
| **Summe** | 735 | | | | **0,82 MB (Archiv 0,79 MB)** | **20,27 MB (Archiv 5,25 MB)** |

Alle elf ≤ 10 000 Dreiecke lod0 (größtes: Kontor 9 865) und ≤ 2 Aufrufe je Stufe (Klassen `baked`/`baked_cutout` +
`vpbr`); Archivanteil 0,79 / 5,25 MB unter dem Anteil der Charge (3 / 7 MB). Platzierungen: Zählung von AS5a1 auf
beiden Wegen Kiel – Nürnberg, von mir für die Etappen der Hauptroute nachgezählt (gleiche Größenordnung). Die
Backzeiten (108–1 462 s je Modell, AS5a1-Tabelle) habe ich nicht nachgemessen (kein Neuexport in einer Kritik).
Auffällig: **`city_german_house` lod1 hat 85 % der Dreiecke von lod0** (2 526 / 2 962) – Garten (Hecken, Baum) bleibt
in lod1 fast voll; das häufigste Modell (282) spart an seiner Fernstufe kaum etwas.

### 5.2 Texeldichte der Außenwände (`texel_k5.gd`, lod0, nur die äußersten 1,2 m je Richtung, Modellmaß, gemessen)

px/m = √(UV-Fläche × Atlasgröße / Weltfläche), flächengewichtet; „unten“ = Mitte des Dreiecks < 7,5 m (Erdgeschoss
und 1. OG), „oben“ darüber; Anfahrt = Fassade zur anfahrenden Kamera (+Z), Straße = Flanke zur Fahrbahn (−X).
In Klammern das Minimum im Spiel (geteilt durch den größten Maßstab der Zählung).

| Modell | Anfahrt unten | Anfahrt oben | Straße unten | Straße oben | Maßstab max |
|---|---|---|---|---|---|
| Mietshaus | 54,8 (48) | 55,8 | 52,9 (46) | 52,9 | 1,14 |
| Gründerzeithaus | 53,2 (46) | 43,4 (38) | 54,4 (47) | 41,1 (36) | 1,15 |
| Fachwerkzeile | 41,8 (38) | 35,0 (32) | 41,8 (38) | 35,0 | 1,10 |
| Fachwerk mit Turm | 41,9 (38) | 40,3 | 41,1 (37) | 40,2 | 1,10 |
| Barock | 46,4 (41) | 37,4 (33) | 47,2 (41) | 37,8 | 1,14 |
| Giebelzeile | 41,4 (**36**) | 33,5 (29) | 41,9 (37) | 33,5 | 1,14 |
| Speicher | 42,6 (39) | 30,4 (28) | – (Turm vorn) | 28,7 | 1,09 |
| Kontor | 41,2 (**34**) | 29,0 (**24**) | 41,2 (34) | 29,0 (**24**) | 1,20 |
| Büroturm | 20,8 (im Spiel ×2–2,7: 42–56) | 21,2 | 21,2 | 21,2 | 0,37–0,50 |
| Einfamilienhaus | 16,3 (Garagenfront, 5 m²) | – | 60,0 | – | 1,10 |

Vertrag ≥ 26 px/m an Straßenwänden: im Modellmaß erfüllt (außer der kleinen Garagenfront des Einfamilienhauses mit 16 px/m
und dem Büroturm, der im Spiel mit Maßstab 0,37–0,5 auf 42–56 px/m kommt). Im Spiel unterschreitet nur der **Kontor**
bei Maßstab 1,2 oben mit 24 px/m die 26 px/m. Die Vorgabe ≥ 40 px/m für Erdgeschoss und 1. OG der Innenstadthäuser
erfüllen im Modellmaß alle, im Spiel bei großem Maßstab nicht mehr: Kontor 34, Giebelzeile 36–37, Fachwerkzeile 38,
Speicher 39 px/m (gerechnet aus gemessenem Modellmaß). Aus 5–10 m (711 px Brennweite: 70–140 Bildpunkte je Meter) wird
jede dieser Wände 1,5–3,5-fach vergrößert – weich, aber gleichmäßig; Wände, die nur Spiegeltexel der Gegenseite
tragen, sind in diesen Zahlen enthalten (gleiche Dichte).

### 5.3 Stufenwechsel und Fernbild (`prop_scene --mode=lods`, „Mittel“, Anker 20 m seitlich, gemessen)

Anteil der Pixel mit Σ|ΔRGB| > 0,06 beim Wechsel lod0 → lod1 bei 60 m, Helligkeitssprung; dazu lod1 gegen den
Arcade-Platzhalter bei 200 m (nur als Hinweis: der Platzhalter der Prüfszene hat ein eigenes Licht, Abschnitt K8).

| Modell | 12 Uhr | 22 Uhr | Platzhalter dunkler als lod1 (200 m, 12 Uhr) |
|---|---|---|---|
| Fachwerkzeile | 32,0 %, +4,7 % | 23,8 %, +9,0 % | 18,3 % |
| Kontor | 24,7 %, −1,7 % | 18,1 %, +9,9 % | 13,1 % |
| Barock | 18,5 %, −1,7 % | 13,9 %, +1,6 % | 20,9 % |
| Gründerzeithaus | 18,0 %, −0,9 % | 14,1 %, +4,8 % | 22,5 % |
| Speicher | 17,4 %, −0,9 % | 14,0 %, +4,4 % | 10,8 % |
| Fachwerk mit Turm | 16,8 %, +2,7 % | 10,2 %, +5,7 % | 3,1 % |
| Giebelzeile | 14,9 %, −2,1 % | 10,4 %, +1,3 % | 19,6 % |
| Mietshaus | 14,2 %, −1,1 % | 10,5 %, +2,3 % | 20,1 % |
| Einfamilienhaus | 11,1 %, +2,6 % | 9,4 %, +3,9 % | −0,5 % (gleich) |
| Büroturm | 3,3 %, −0,1 % | 4,6 %, +2,1 % | 4,8 % |
| Kran | 2,1 %, −0,1 % | 2,0 %, +7,2 % | 2,6 % |

Kein Fernbild (lod1 bis zur Sichtweite) – nach Vertrag erlaubt („impostor optional“), lod1 ist billig genug (203–2 526
Dreiecke). Im Fahrfilm siehe K5.

### 5.4 Flimmern – siehe K6. 5.5 Geländer – siehe K7.

### 5.6 Umriss gegen das Sprite (`outline2`, Sprite-Kamera −20°/−24°, 6° Höhe, gemessen, Bild 26)

IoU lod0 / lod1: Einfamilienhaus 0,993 / 0,996, Mietshaus 0,995 / 0,999, Gründerzeit 0,999 / 0,999, Büroturm 0,997 /
0,997, Fachwerkzeile 0,998 / 0,999, Fachwerk mit Turm 0,999 / 0,999, Barock 0,999 / 0,999, Giebelzeile 0,998 / 0,998,
Speicher 0,999 / 0,999, Kontor 0,987 / 0,987, Kran 0,922 / 0,922 (dünne Stäbe gegen weichgezeichnete Pixel). Proportionen,
Geschosse, Dachformen, Giebel und Fensterraster stimmen – die Modelle sind kein neuer Entwurf.
