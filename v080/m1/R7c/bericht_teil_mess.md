## 3. Messungen (alle gemessen auf dieser VM, llvmpipe unter Xvfb; Werkzeuge: Kopien der Prüfszenen von AS5aR2 in `m1/R7c/kt`, `k5.sh`)

### 3.1 Fernlicht (Leitentscheid 2) – `k6_scene --mode=lodcol`, 12 Uhr, Modell 20 m neben der Straße

Mittlere Helligkeit (Luma) des Modells, Abweichung gegen das Nahbild (Hoch: 60 m, Mittel: 50/60 m; lod1, dieselbe
Szene wie AS5aR2 K2). Vorher = ohne Fernlicht (identisch mit den Werten von AS5aR2: Haussmann 134 → 147, Chalet
75 → 96, Lauben 105 → 110, Südhaus 116 → 127, Maashaus 107 → 111 – der neue `light()` des `baked`-Shaders gibt bei 60 m
dieselben Werte wie das eingebaute Licht der Engine).

| Modell | vorher 250 m (Hoch) | far_sun 0,75 Hoch 100 / 140 / 200 / 250 m | Mittel 100 / 140 / 200 / 250 m |
|---|---|---|---|
| Haussmann | +10 % | +2,2 / +2,4 / +3,6 / +4,1 % | +0,5 / +3,9 / +4,3 / +4,3 % |
| Pariser Eckhaus | – | +1,3 / +1,4 / +0,3 / −0,1 % | −0,1 / +1,3 / +1,3 / +0,4 % |
| Lauben | +5 % | −1,5 / −2,9 / −1,9 / −2,2 % | −2,5 / −1,2 / −1,7 / −2,0 % |
| Südhaus | +10 % | +1,6 / +1,1 / +3,4 / +3,0 % | −0,5 / +4,1 / +2,8 / +2,6 % |
| Maashaus | +4 % | +0,6 / +0,8 / −4,8 / −4,1 % | +0,6 / −3,4 / −3,4 / −3,1 % |
| Lütticher Reihe | – | −0,3 / −0,3 / −5,8 / −5,3 % | −0,8 / −4,7 / −5,0 / −4,7 % |
| Grachtenhaus | – | −0,7 / −0,8 / −5,7 / −5,8 % | −0,7 / −4,6 / −4,2 / −5,0 % |
| niederl. Reihe | – | +1,6 / +1,9 / −2,2 / −2,6 % | +0,8 / −2,1 / −2,1 / −2,6 % |
| Gründerzeit | – | −0,5 / −0,9 / −3,8 / −3,7 % | −1,3 / −2,8 / −3,2 / −3,3 % |
| Kontor | – | +3,4 / +4,2 / +0,6 / +1,0 % | +1,1 / +1,0 / +1,3 / +1,1 % |
| Giebelhaus (Hanse) | – | +0,6 / +1,3 / −3,2 / −3,0 % | +0,5 / −2,9 / −2,2 / −2,4 % |
| Barockhaus | – | −0,4 / −0,6 / −4,3 / −4,1 % | −1,2 / −3,1 / −3,8 / −3,6 % |
| Lyoner Haus | – | +0,3 / −0,3 / −2,0 / −2,0 % | −0,5 / −1,5 / −1,5 / −1,5 % |
| house_med | – | +0,2 / −0,9 / −4,8 / −5,4 % | −1,4 / −2,2 / −5,0 / −5,0 % |

Mit 0,75 lagen drei Modelle bei Hoch knapp unter −5 % (−5,3 … −5,8 %) und Haussmann bei +4,1 %; ausgeliefert ist
deshalb 0,78. Nachmessung mit 0,78 (lod0 bis 250 m, das strengere Bild): Lütticher Reihe −3,5 %, Grachtenhaus −0,4 %,
Maashaus −2,7 % bei 200 m – aber Haussmann +5,9 / +6,6 %, house_med −5,4 / −5,1 % und Südhaus +5,5 % (140 m,
Mittel) außerhalb. Diese drei haben eigene Werte (Haussmann 0,72, Südhaus 0,75, house_med 0,85) und sind damit
nachgemessen (Abweichung gegen 60 m bei 100 / 140 / 200 / 250 m):

| Modell (eigener Wert) | Hoch | Mittel |
|---|---|---|
| Haussmann (0,72) | +2,5 / +2,8 / +3,2 / +2,9 % | +0,5 / +3,8 / +3,7 / +2,8 % |
| Südhaus (0,75) | +1,6 / +1,3 / +3,8 / +3,6 % | −0,5 / +4,8 / +3,2 / +3,2 % |
| house_med (0,85) | +0,2 / −0,5 / −1,2 / −2,0 % | −1,4 / +0,5 / −1,5 / −1,8 % |

Schlussmessung der übrigen Häuser mit ihren ausgelieferten Werten (lod0 bis 250 m; Kontor, Chalet und Fachwerk auch
in lod1, der Stufe, die das Spiel jenseits von 35 m zeigt):

| Modell (Wert) | Hoch 100 / 140 / 200 / 250 m | Mittel 100 / 140 / 200 / 250 m |
|---|---|---|
| niederl. Reihe (0,78) | +2,1 / +2,8 / +0,7 / −0,8 % | +1,0 / −0,1 / +0,6 / −0,9 % |
| Lyoner Haus (0,78) | +0,6 / −0,2 / −0,7 / −0,8 % | −0,4 / −0,2 / −0,1 / −0,2 % |
| Gründerzeit (0,78) | −0,1 / −0,6 / −2,2 / −2,5 % | −1,2 / −1,3 / −1,8 / −2,2 % |
| Barockhaus (0,78) | −0,4 / −0,6 / −2,9 / −3,4 % | −1,2 / −1,9 / −2,4 / −2,9 % |
| Giebelhaus (0,78) | +1,1 / +2,0 / −1,7 / −0,9 % | +0,7 / −1,1 / −0,6 / −0,2 % |
| Pariser Eckhaus (0,78) | +1,5 / +1,6 / +1,6 / +1,1 % | −0,1 / +2,8 / +2,4 / +1,5 % |
| Lauben (0,78) | −1,2 / −2,6 / −0,6 / −0,9 % | −2,3 / −0,1 / −0,4 / −0,8 % |
| Kontor (0,78) **lod0** | **+7,8 / +11,2 / +12,1 / +13,3 %** | +4,0 / **+11,6 / +13,1 / +13,6 %** |
| Kontor (0,78) lod1 | +3,4 / +4,2 / +1,7 / +1,9 % | +1,1 / +2,1 / +2,5 / +2,3 % |
| Fachwerkzeile (0,85) lod0 / lod1 | −0,1 / −0,9 / −2,3 / −2,6 – +1,4 / +1,5 / +1,1 / +1,0 % | −1,7 / −1,1 / −1,9 / −2,3 – +0,0 / +0,9 / +1,7 / +1,4 % |
| Fachwerkzeile B (0,85) lod0 / lod1 | −1,9 / −3,4 / −4,1 / −2,7 – −1,7 / −2,8 / −1,9 / −2,0 % | −3,4 / −1,3 / −3,7 / −2,4 – −2,8 / −1,0 / −1,6 / −1,6 % |
| Chalet lod1 mit 0,35 | +2,4 / +0,8 / **+6,3** / +4,1 % | −0,5 / **+5,6** / +3,3 / +3,7 % |
| Chalet lod1 mit **0,30** (ausgeliefert) | +2,4 / +0,8 / +3,6 / +1,3 % | −0,5 / +2,8 / +0,7 / +0,9 % |

Damit liegen alle 17 gemessenen Häuser mit ihren ausgelieferten Werten bei 100–250 m in ±5 % des Bildes bei 60 m
(gemessen; Haussmann, Südhaus, house_med und die drei belgisch-niederländischen mit 0,78 nur in lod0). Ausnahme: das
Kontor in lod0 wird fern bis 13 % heller (seine tiefen Laibungen werfen in lod0 viel Eigenschatten) – im Spiel endet
lod0 der Stadthäuser aber bei 35 m („Mittel“) bzw. 70 m („Hoch“), jenseits davon steht lod1, und das liegt in ±5 %.

Suche der Einzelwerte: Chalet vorher +29 % bei 250 m (Hoch), 0,3 → +1,1 %, 0,45 → +8,8 %; 0,35 lag bei 200 m über
5 % (Tabelle), ausgeliefert 0,3. Fachwerk 0,85 (0,75 → −4,5 / −5,7 % bei Mittel). Bäume (Mittel, 0,75): Eiche
+2,0 / +2,7 % bei 140 / 250 m (vorher +4,4 %), Kiefer lod1 +3,9 % bei 140 m; ausgeliefert 0,8.

### 3.2 Flimmern (Leitentscheid 3) – `my_scene --mode=sparkcam`, Mittel, 12 Uhr, Anteil kippender Pixel je Viertelpixel-Schritt
