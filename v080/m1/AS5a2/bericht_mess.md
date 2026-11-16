## 5. Budget und Messungen

### 5.1 Budgettabelle (gemessen: Export-Bericht, `validate_models.py --report`, Archivschätzung wie `tools/pck_report.py`)

| Set | Platzierungen (Netz) | Maßstab im Spiel | Dreiecke lod0 / lod1 | Atlas | px/m EG + 1. OG / darüber (Modellmaß) | Archiv Netze / Texturen | Export |
|---|---|---|---|---|---|---|---|
| `city_french_sud` | 588 | 0,80–1,10 | 5 359 / 3 716 | 1024×1024 | 54 / 54 | 119 / 394 kB | 312 s |
| `city_belgian_terrace` | 315 | 0,90–1,15 | 2 586 / 1 162 | 2048×1024 | 64 / 51 | 46 / 550 kB | 474 s |
| `city_french_maison` | 209 | 0,90–1,10 | 3 910 / 1 874 | 1024×1024 | 51 / 51 | 90 / 311 kB | 280 s |
| `city_french_immeuble` | 202 | 0,95–1,14 | 4 020 / 2 486 | 2048×1024 | 65 / 52 | 75 / 566 kB | 755 s |
| `city_dutch_terrace` | 130 | 0,90–1,10 | 3 346 / 1 060 | 1024×1024 | 46 / 46 | 73 / 287 kB | 227 s |
| `city_belgian_stone` | 96 | 0,91–1,15 | 1 336 / 278 | 1024×1024 | 55 / 44 | 21 / 267 kB | 177 s |
| `city_paris_haussmann` | 55 | 0,95–1,10 | 6 518 / 3 714 | 2048×1024 | 50 / 38 | 125 / 601 kB | 651 s |
| `city_swiss_chalet` | 54 | 0,90–1,10 | 3 128 / 1 280 | 1024×1024 | 53 / 53 | 56 / 282 kB | 166 s |
| `city_dutch_canal` | 51 | 0,95–1,10 | 3 734 / 1 802 | 2048×1024 | 50 / 40 | 77 / 631 kB | 483 s |
| `city_swiss_laube` | 46 | 0,95–1,10 | 4 865 / 942 | 2048×1024 | 44 / 35 | 70 / 569 kB | 308 s |
| `city_dutch_canal_b` | 22 | 0,95–1,10 | 3 623 / 1 543 | 2048×1024 | 47 / 38 | 69 / 683 kB | 461 s |
| `city_paris_corner` | 8 | 1,00–1,09 | 5 675 / 3 418 | 2048×1024 | 47 / 35 | 112 / 653 kB | 800 s |

Summe (deflate -9 je Datei): Netze 0,93 MB, Texturen 5,79 MB. „Export“ = Zeit des letzten echten Exports mit Bake.

Grenzen (§4.6.9, Auftrag): Stadthaus lod0 ≤ 10 000 Dreiecke (größtes: Haussmann 6 518), ≤ 2 Zeichenaufrufe je Stufe
(alle 2/2), Texturen in der Stufe (2048×1024 Innenstadt, 1024×1024 Vorort/Einzelhaus), Archivanteil der Charge
≤ 3 MB Netze und ≤ 7 MB Texturen (gemessen: 0,93 MB / 5,79 MB). Texeldichte im Spiel = Modellmaß / Maßstab: das
Erdgeschoss liegt bei ≥ 40 px/m außer bei den Lauben im größten Maßstab 1,10 (39,8), alle Straßenwände ≥ 26 px/m.
Backzeit = Export mit Cycles-Bake und AO, `nice -n 19`, eine Instanz, CE_THREADS 3, auf der geteilten Maschine
(gemessen; beim zweiten Export der Runde 5 waren es 98–504 s).

### 5.2 Stufenwechsel, Flimmern, Geländer (llvmpipe, Prüfszene im Renn-Look, gemessen)

| Messung | Ergebnis |
|---|---|
| Stufenwechsel lod0 → lod1 bei 60 m, „Mittel“, 12 Uhr | 9,1 % (Lauben) … 18,3 % (Grachtenhäuser) der Pixel, Helligkeit −0,5 … +0,6 %; Charge 1 nach der Nacharbeit: 13–27 % |
| dasselbe, 22 Uhr | 7,8 … 14,5 % der Pixel, Helligkeit +0,6 … +4,9 % (Chalet, Lauben am höchsten) |
| Flimmern (Pixel, die je Viertelpixel-Kameraschritt kippen, 40 / 60 / 100 / 150 m; Sprite in Klammern) | Haussmann 1,0 / 1,2 / 1,0 / 0,6 % (0,0 / 0,2 / 0,3 / 0,4); Grachtenhäuser 0,8 / 1,1 / 0,8 / 1,1 % (0,1 / 0,2 / 0,3 / 0,4); belgische Reihe 0,4 / 0,6 / 0,4 / 0,4 % (0,1 / 0,1 / 0,2 / 0,3); Lyon 0,8 / 0,6 / 0,3 / 0,5 % (0,2 / 0,2 / 0,3 / 0,5); Chalet 0,5 / 0,9 / 1,0 / 1,3 % (0,2 / 0,2 / 0,4 / 0,5) |
| Geländer in den Mip-Stufen 1–4 (`mipband.py`: Deckung gegen Mip 0, Helligkeit des Bandes in 8-Bit-Luma) | Haussmann Deckung 1,16 / 1,55 / 1,96 / 2,74, Helligkeit +1,0 / +1,0 / +1,8 / −0,5; Eckhaus −2,1 … +0,3; Lyon +0,3 … +3,6; Südhaus −3,0 … +0,2; Chalet −3,0 … +0,1 – das Geländer wird zum Band mit seiner mittleren Helligkeit, verschwindet nicht (Charge 1 vor `cut_fill`: −13,6 … +18,0) |
| Umriss gegen das Sprite (Sprite-Kamera, IoU) | IoU 0,945 (Chalet) … 0,999 (Grachtenhäuser), lod0 = lod1 bis auf 0,003; 0,0–2,5 % der Modellfläche außerhalb des Sprites (Südhaus und Loire-Haus: Baumkronen), Sprite zu 95,5–100 % gedeckt (Chalet: linke Traufe und Giebelwand wenige Pixel innen); zehn von zwölf ≥ 0,996 (gemessen, `umrisse_sprite_gegen_modell.jpg`) |
| Tönung `#ead6cc` (Reihenhäuser Ruhrgebiet) | Albedo × Tönung entspricht dem getönten Sprite (angesehen, `toenung_reihenhaeuser_ruhr.jpg`) |

Die Prüfszene vergleicht die Helligkeit bei 200 m gegen den Arcade-Platzhalter der Szene; der ist dort 11–23 % zu
dunkel (Werkzeugvorbehalt der Kritik von Charge 1) – Helligkeit nur im Rennen beurteilt (Abschnitt 7).
