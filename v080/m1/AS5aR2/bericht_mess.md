## 4. Vorher / nachher je Befund (gemessen, wenn nicht anders gesagt)

### K1 – Schaufenster nachts (hoch): behoben

| Messung (`py/litpx.py`: warme Pixel r > 170, r ≥ g ≥ b, r − b > 50) | Arcade | vorher (AS5a2) | nachher |
|---|---|---|---|
| Paris km 387,9, 22 Uhr, Hoch, +2 s: Erdgeschoss Eckhaus (Kasten 740–1075 × 300–400) – Anteil | 28,2 % | 10,9 % | **22,7 %** (0,80 × Arcade) |
| dasselbe – mittlere Farbe (Luma) | (250,215,157) – 218 | (192,150,105) – 159 | **(233,193,135) – 197** |
| dasselbe, Wohnfenster darüber (740–1100 × 60–300) | 4,56 % | 3,86 % | 3,86 % (unverändert, wie gewollt) |
| +4 s, Ladenflanke rechts (880–1280 × 100–470) – Anteil | 24,2 % | 4,8 % | **9,4 %** |
| Charge 1, Gründerzeithaus 30 m, 22 Uhr (Prüfszene, Erdgeschoss) | – | 16,7 %, (186,143,96) | **31,7 %, (234,190,129)** |
| Charge 1, Kontorhaus 100 m / 250 m | – | 5,6 % / 3,0 % | **10,1 % / 9,0 %** |

Die Läden des Eckhauses erreichen 80 % der Arcade-Fläche und 90 % ihrer Helligkeit (Ziel der Kritik: Anteil ≥ 0,7 ×
Arcade, Ladenpixel 190–210 – erfüllt). An der Ladenflanke bei 4 s bleibt Modern bei 0,39 × Arcade: dort zeigt Arcade
die beleuchtete Flanke als große, zur Kamera gedrehte Bildfläche, Modern sieht die 35 cm tief liegenden Auslagen unter
spitzem Winkel hinter Laibung und Sprossen (Geometrie, nicht Helligkeit; angesehen). Bei Tag unverändert: die Auslage
bleibt hinter dem dunklen Glas (Nahansichten 12 Uhr angesehen, Nachtatlas wirkt nur über `ce_night`).

### K2 – Fernfassaden blass, Fenster rosa-lila (mittel): Ursache gefunden – Renderer, nicht Modell

**Erster Versuch (im Modell, ausgeliefert, wirkungslos gegen K2):** Innenring der Fernstufe 0,75 des Weges zum Glas,
gemalte Sprossen 0,35 (Atlas angesehen: Ring grau statt weiß). Dieselbe Prüfszene wie die Kritik
(`k6_scene --mode=lodcol`, Hoch, 12 Uhr): am dunklen Zehntel bei 250 m fast nichts.

| Modell | p10 lod0 60 m → lod1 250 m vorher | nachher | Sprite |
|---|---|---|---|
| Haussmann | 55 → 78 (+23) | 54 → 77 (+23) | 42 → 53 (+11) |
| Lauben | 56 → 81 (+25) | 54 → 80 (+26) | 56 → 58 (+2) |
| Maashaus | 61 → 83 (+22) | 59 → 81 (+22) | 64 → 70 (+6) |
| Südhaus | 65 → 83 (+18) | 66 → 81 (+15) | 59 → 63 (+4) |
| niederl. Reihenhäuser | 45 → 66 (+21) | 45 → 64 (+19) | 43 → 54 (+11) |
| Eckhaus | 66 → 84 (+18) | 65 → 82 (+17) | 44 → 59 (+15) |

**Diagnose (Nachfolger-Lauf, `k2diag.sh`, gemessen):** Die Modelle werden mit der Entfernung *heller* – das kann eine
Mip-Kette nicht (sie erhält den Mittelwert). Dieselbe Szene dreimal (Schatten-Reichweite über `--shadow_m`, nur im
Prüfwerkzeug), mittlere Helligkeit lod0 bei 60 → 250 m und dunkles Zehntel p10:

| Modell | Schatten wie im Rennen (200 m) | Reichweite 1 000 m | ohne Sonnenschatten | Sprite |
|---|---|---|---|---|
| Haussmann | 134 → 147 (+10 %), p10 +22 | 136 → 142 (+5 %), p10 +16 | 106 → 106 (−1 %), p10 +9 | 112 → 110, p10 +11 |
| Chalet | 75 → 96 (+29 %), p10 +23 | 76 → 83 (+8 %), p10 +10 | 71 → 70 (−1 %), p10 +4 | 74 → 70, p10 +3 |
| Lauben | 105 → 110 (+5 %), p10 +24 | 106 → 104 (−2 %), p10 +14 | 83 → 79 (−4 %), p10 +7 | 92 → 89, p10 +4 |
| Südhaus | 116 → 127 (+10 %), p10 +8 | 117 → 119 (+2 %), p10 +1 | 94 → 93 (−1 %), p10 +1 | 101 → 98, p10 +5 |
| Maashaus | 107 → 111 (+4 %), p10 +22 | 107 → 110 (+3 %), p10 +21 | 78 → 80 (+3 %), p10 +15 | 91 → 89, p10 +7 |

Ohne Sonnenschatten erfüllen vier von fünf Modellen das Abnahmekriterium der Kritik (Luma ±3 %, p10 ≤ +8 – Haussmann
+9 knapp, Maashaus +15 nicht). Die Fernblässe kommt also vom **Ende der Echtzeitschatten** (Hoch: Reichweite 200 m,
ausgeblendet ab 170 m; Mittel: 120 m, ab 102 m – daher „ab 100 m“ der Kritik) und von der **groben Auflösung der
letzten Schattenstufe** (mit 1 000 m Reichweite bleibt p10 +10…+21): jenseits davon fällt die Sonne voll auf
Laibungen, Arkaden, Balkon- und Traufschatten. Das Sprite hat seine Schatten eingebacken. Die „rosa-lila“ Fenster der
Lauben bei 250 m sind im Bild mit Rennschatten zu sehen, ohne Schatten sind sie grau (angesehen,
`k2_ursache_schattenreichweite.jpg`). Ohne Schatten ist das ganze Bild dunkler (vermutlich rechnet der
Kompatibilitäts-Renderer das Sonnenlicht dann in einem anderen Durchgang); verglichen wird nur der Verlauf über die
Entfernung. Im Modell ist das nicht zu beheben (stärkeres eingebackenes AO würde die Nahansicht doppelt abdunkeln);
Abhilfe im Renderer (notes_for_next). Bleibender Modellanteil: Maashaus p10 +15 gegen +7 ohne Schatten.

### K3 – Gartenbaum als Klumpen (mittel–hoch): behoben

Blattkarten statt facettierter Kugelkrone (Nahansicht angesehen, Lieferbild `gartenbaum_vorher_nachher.jpg`).
Kosten: Südhaus lod0 5 359 → 5 820 Dreiecke, lod1 3 716 → 3 916; Loire-Haus lod0 3 910 → 4 250, lod1 1 874 → 2 100;
Texturen im Archiv +24 bzw. +53 kB (Alpha-Kanal). Stufenwechsel bei 60 m (Mittel, 12 / 22 Uhr): Südhaus
8,2 / 4,3 % (vorher 16,4 / 7,8 %), Loire-Haus 8,6 / 6,0 % (11,9 / 7,8 %). Flimmern (Viertelpixel-Schritte, 40 / 60 / 100 /
150 m): Südhaus 0,9 / 0,9 / 1,0 / 1,5 % (vorher 0,4 / 0,4 / 0,6 / 0,8 %; Sprite 0,2 / 0,3 / 0,4 / 0,6), Loire-Haus 0,5 / 0,7 / 1,3 / 1,6 % (vorher
0,4 / 0,5 / 1,0 / 1,4 %) – die Blattkarten flimmern wie jede ausgeschnittene Laubkarte etwas mehr als die Kugelkrone.

### K4 – Geländer (mittel): Flimmern in lod1 behoben; „Band zu dunkel“ abgelehnt

| Flimmern (Anteil kippender Pixel) 40 / 60 / 100 / 150 m | vorher | nachher | Sprite |
|---|---|---|---|
| Haussmann | 1,0 / 1,2 / **1,0 / 0,6** % | 0,9 / 1,1 / **0,3 / 0,5** % | 0,0 / 0,2 / 0,3 / 0,4 % |
| Eckhaus | 1,1 / 1,2 / **1,0 / 0,7** % | 1,1 / 1,1 / **0,2 / 0,4** % | 0,1 / 0,2 / 0,2 / 0,3 % |
| Grachtenhäuser B | 0,7 / 1,0 / 0,6 / 0,9 % | 0,5 / 0,8 / 0,5 / 0,9 % | 0,1 / 0,2 / 0,2 / 0,4 % |
| Lauben | 0,3 / 0,4 / 0,3 / 0,5 % | 0,2 / 0,3 / 0,3 / 0,5 % | 0,1 / 0,1 / 0,2 / 0,3 % |

Ab der Stufe lod1 (60 m „Mittel“, 120 m „Hoch“) flimmern Haussmann und Eckhaus jetzt wie ihr Sprite. lod0 bei
40–60 m bleibt 5–10 × Sprite: Alpha-Test der Gitter in lod0 (A-22) und die geometrischen Rahmen und Sprossen (vpbr)
– das braucht TAA/Mip-Bias oder ein kürzeres lod0 im Renderer (R7, A-22 nennt `max_dist_m`).
Bandhelligkeit gegen die Füllfarbe (`mipband.py`, Mip 1–4): Haussmann +1,0 / +1,0 / +1,8 / −0,5, Lyon +1,2 / +0,9 /
+3,6 / +0,3, Südhaus +0,2 / −0,2 / −1,3 / −3,0, Chalet +0,1 / −0,5 / −0,6 / −3,0 Stufen.

### K5 – Stufenwechsel (R7) und K6 – Sprossen

Stufenwechsel bei 60 m „Mittel“, 12 Uhr (Anteil geänderter Pixel, Helligkeit), vorher → nachher: Haussmann
14,2 % / +0,1 → 16,5 % / −0,6; Eckhaus 13,3 / +0,3 → 15,2 / −0,4; Grachtenhäuser 18,3 / −0,3 → 17,7 / −2,6;
Grachtenhäuser B 17,5 / −0,5 → 17,0 / −1,9; Maashaus 16,2 / −0,1 → 15,9 / −1,6; niederl. Reihe 14,4 / +0,6 → 14,2 /
−0,4; Lyon 14,6 / +0,3 → 14,4 / −0,3; belg. Reihe 16,4 / +0,4 → 16,2 / −0,9; Chalet 14,9 / +0,6 → 13,0 / −0,3; Lauben
9,1 / +0,4 → 8,7 / −0,4. Nachts (22 Uhr): Haussmann +2,5 %, Eckhaus +2,6 %, Lauben +5,3 %, Lyon +4,6 % (vorher +3,0 /
+3,5 / +4,9 / +4,0). Der dunklere Innenring macht lod1 bei Tag 0,3–2,6 % dunkler als lod0; das Überblenden bleibt R7.

### K7 – Geranien (niedrig): verbessert

Kugeln längs des Kastens gestreckt und flach (angesehen, Lieferbild `geranien_vorher_nachher.jpg`): aus 10 m ein
niedriges, rot-grünes Polster statt einer Kette großer Kugeln; aus nächster Nähe noch als einzelne Tupfen lesbar.

### K10 – lod1-Ersparnis

Südhaus lod1/lod0: vorher 69 %, nachher 67 % – die Blattkarten liegen in beiden Stufen (mit weniger Karten in lod1 sprang die Krone beim Wechsel: 27,5 % bzw. 34,8 % der Pixel).
