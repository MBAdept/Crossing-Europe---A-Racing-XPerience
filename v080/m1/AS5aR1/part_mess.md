### Stufenwechsel lod0 → lod1 bei 60 m („Mittel“, `prop_scene --mode=lods`, Anker 20 m seitlich; Pixel mit Σ|ΔRGB| > 0,06 / Helligkeitssprung)

| Modell | 12 Uhr vorher (Kritik) | 12 Uhr nachher | 22 Uhr vorher (Kritik) | 22 Uhr nachher |
|---|---|---|---|---|
| Fachwerkzeile | 32,0 %, +4,7 % | **27,1 %, +3,2 %** | 23,8 %, +9,0 % | **18,7 %, +5,0 %** |
| Kontor | 24,7 %, −1,7 % | 25,7 %, +2,7 % | 18,1 %, +9,9 % | 19,5 %, **+8,1 %** |
| Barock | 18,5 %, −1,7 % | 19,1 %, −0,5 % | 13,9 %, +1,6 % | 14,2 %, +1,6 % |
| Gründerzeithaus | 18,0 %, −0,9 % | 18,6 %, +0,1 % | 14,1 %, +4,8 % | 14,3 %, +4,3 % |
| Speicher | 17,4 %, −0,9 % | 17,9 %, +1,1 % | 14,0 %, +4,4 % | 14,1 %, **+3,6 %** |
| Fachwerk mit Turm | 16,8 %, +2,7 % | 16,9 %, +0,6 % | 10,2 %, +5,7 % | 10,2 %, **+3,5 %** |
| Giebelzeile | 14,9 %, −2,1 % | 16,8 %, −0,8 % | 10,4 %, +1,3 % | 11,6 %, +0,8 % |
| Mietshaus | 14,2 %, −1,1 % | 13,7 %, +0,1 % | 10,5 %, +2,3 % | 10,1 %, +1,7 % |
| Einfamilienhaus | 11,1 %, +2,6 % | 17,2 %, +3,0 % (Gartenstufe 0,5) | 9,4 %, +3,9 % | 11,5 %, +4,3 % |
| Büroturm | 3,3 %, −0,1 % | 3,3 %, −0,1 % | 4,6 %, +2,1 % | 4,6 %, +2,1 % |
| Kran | 2,1 %, −0,1 % | 2,1 %, −0,1 % | 2,0 %, +7,2 % | 1,9 %, +4,4 % |

Der Rahmenring im gemalten Glas (`inner_frame`) nimmt den Nachtsprung dort, wo viele Fenster beleuchtet sind
(Fachwerkzeile, Turmhaus, Speicher, Kontor); der Anteil geänderter Pixel sinkt nur bei der Fachwerkzeile deutlich
(echte gegen gemalte Hölzer bleiben). Giebelzeile +1,9 Punkte: Ihre Straßenflanke mit 18 neuen Öffnungen liegt jetzt
mit im Bild. Einfamilienhaus siehe K10.

### Flimmern (`my_scene --mode=sparkcam`, Viertelpixel-Schritte seitlich, „Mittel“, 12 Uhr)

| Modell | 40 m | 60 m | 100 m (lod1) | 150 m (lod1) | Sprite 40 / 60 / 100 / 150 m |
|---|---|---|---|---|---|
| Fachwerkzeile | 1,2 % (vorher 1,1) | 1,4 % (1,4) | 0,6 % (0,6) | 1,1 % (1,1) | 0,1 / 0,1 / 0,2 / 0,4 % |
| Fachwerk mit Turm | 1,5 % (AS5a1: 1,0) | 1,4 % (1,0) | 0,6 % (0,6) | 1,1 % (0,8) | 0,2 / 0,3 / 0,4 / 0,5 % |
| Giebelzeile | 0,6 % (0,5) | 0,8 % (0,7) | 0,9 % (1,1) | 1,2 % (1,3) | 0,1 / 0,1 / 0,3 / 0,4 % |
| Gründerzeithaus | 0,6 % (0,6) | 0,7 % (0,5) | 0,3 % (0,3) | 0,3 % (0,4) | 0,1 / 0,1 / 0,2 / 0,4 % |

Nicht besser. Die 3 cm schmaleren Hölzer liegen zwar auf gemaltem Holz, aber Hölzer 3,5 cm vor der Wand zeigen bei
flachem Blick ihre Seitenflächen, und deren Kanten liegen über der Ausfachung. Das Turmhaus flimmert mehr, weil seine
Straßenflanke jetzt 19 Fenster mit Rahmen und Sprossen und der Erker Futter hat – Tiefe, die die Kritik gefordert hat.

### Geländer (`mipband.py` auf den gelieferten Atlanten; Kastenfilter in 8 Bit wie die Engine)

| Atlas | Deckung Mip 1 / 2 / 3 / 4 gegen Mip 0 | Helligkeit des Bandes gegen Mip 0 (Luma), Mip 1 / 2 / 3 / 4 |
|---|---|---|
| Mietshaus vorher | 1,11 / 1,20 / 1,40 / **0,30** | −2,3 / −4,2 / −8,2 / **+14,4** |
| Mietshaus nachher | 1,14 / 1,51 / 1,90 / 3,09 | +0,8 / +0,2 / +0,4 / −0,8 |
| Gründerzeithaus vorher | 1,12 / 1,19 / 1,32 / **0,59** | −5,2 / −8,4 / −13,6 / **+18,0** |
| Gründerzeithaus nachher | 1,15 / 1,54 / 2,01 / 2,84 | +1,1 / +0,8 / +2,3 / −0,0 |

Die Deckung steigt mit Absicht über 1: In den kleinen Mips schließt sich das Geländer zu einem Band, dessen Texel die
Mischfarbe aus Stäben und Hintergrund tragen – die Helligkeit, die das Auge bei Stäben unter einem Pixel sieht, bleibt
in jeder Stufe (|ΔL| ≤ 2,3 statt bis 18). Mip 0 ist unverändert (Deckung 0,32 bzw. 0,35 wie vorher), aus der Nähe
also dieselben Stäbe. „Hintergrund“ ist die Farbe aus dem Katalog (`cut_fill.color`: die verschattete Wand hinter dem
Balkon) – das Verfahren ist so gut wie diese Schätzung.

### Umriss gegen das Sprite (`k4_scene --mode=outline2`)

IoU lod0 / lod1 unverändert: Einfamilienhaus 0,993 / 0,993 (vorher 0,996: die dezimierte Hecke), Mietshaus 0,995 /
0,999, Gründerzeit 0,999, Büroturm 0,997, Fachwerkzeile 0,998 / 0,999, Turmhaus 0,999, Barock 0,999, Giebelzeile
0,998, Speicher 0,999, Kontor 0,987, Kran 0,922. Die neuen Öffnungen und Maueranker ändern den Umriss nicht.

### Texeldichte

Aus dem Bake (Modellmaß, Straßenwände): unverändert bis auf die Fachwerkzeile 34,2–42,7 px/m (vorher 35,0–43,8; die
neuen Laibungen der Flanke kosten Atlasfläche). Vertrag ≥ 26 px/m erfüllt außer Büroturm im Modellmaß (im Spiel bei
Maßstab 0,37–0,5: 32–57 px/m, gerechnet), wie bei AS5a1.
