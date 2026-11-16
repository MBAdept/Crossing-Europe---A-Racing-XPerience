## 5. Messungen (gemessen)

**Dreiecke, Budgets §4.6.9, Zeichenaufrufe** (`validate_models.py --report`, Exportbericht):

| Modell | lod0 | lod1 | lod2 | show | Werfer | Aufrufe | Netze (Bytes) |
|---|---|---|---|---|---|---|---|
| `player/limousine` | 44 095 / 55 000 | – | – | 94 629 / 120 000 | 2 320 / 3 000 | 6 / 6 | NETZ_L |
| `player/kompakt` | 47 524 | – | – | 100 332 | 2 320 | 6 / 6 | NETZ_K |
| `traffic/sedan` | 17 555 / 18 000 | 5 809 / 6 000 | 1 149 / 1 200 | – | 972 | 6 / 1 / 1 | NETZ_S |
| `traffic/hatch` | 17 636 | 5 661 | 1 180 | – | 988 | 6 / 1 / 1 | NETZ_H |
| `traffic/wagon` | 17 464 | 5 941 | 1 141 | – | 940 | 6 / 1 / 1 | NETZ_W |
| `traffic/truck` | 18 084 / 25 000 | 4 672 / 7 000 | 1 490 / 1 500 | – | 476 | 13 / 1 / 1 | NETZ_T |

Vorher (AS1): Limousine lod0 45 764, Kompakt 50 080, Verkehr lod0 17 317–17 888 (Kombi 112 Luft), Werfer Pkw 604–652.
Platz geschaffen hat der Reifen mit 9 Profilpunkten (rund 300 Dreiecke je Rad, `tyre_lite`); ausgegeben für runde
Stoßfänger-Enden, Fugen und Emblem, Kennzeichen in `lod2`, Werfer mit Radlauföffnungen.

**Innenraum der Rennstufe** (Exportbericht, samt Verkleidung): Limousine 3 560, Kompakt 3 658 (vorher 5 602 und
6 268; Budget 6 000).

**Freigang Räder ↔ Karosserie** (Netzanalyse wie in der Kritik: Ecken der Karosserie im Reifenvolumen, Räder
drehend, Vorderräder −25° … +25°): FREIGANG

**Schattenwerfer** (Exportbericht): Spielerautos vorher bis 30,0 mm (Limousine, Grillgrund) bzw. 16,9 mm (Kompakt)
außerhalb der Haut samt Mulden, nachher 12,0 mm innen. Werfer-Ansicht (Bild 09): rot nur an Kanten, in den Trommeln
hinter den Felgen und hinter dem durchsichtigen Glas (dort sieht man den Kabinenteil des Werfers durch die Scheiben;
im Spiel wirft er nur Schatten).

**Lampen** (`bin/ana.py lamps`: Kanal, Gewicht, Fläche von hinten): LAMPEN

**Stufenwechsel** (Spielkamera 1280 × 720, Tag, Anteil der Autopixel, die sich um mehr als 24 Stufen ändern;
`bin/pop.sh` + `bin/popmeasure.py`; Bild 07):

| Auto | 40 m `lod0`→`lod1` vorher → jetzt | 120 m `lod1`→`lod2` vorher → jetzt |
|---|---|---|
| Limousine (Verkehr) | 11,4 % → 9,8 % | 32 % (Kritik) / 28,2 % (eigene Messung vorher) → 22,3 % |
| Schrägheck | 7,7 % → 6,6 % | 38 % / 34,4 % → 34,4 % (ohne dunklen Heckabschluss: Budget) |
| Kombi | 6,2 % → 8,1 % | 24 % / 29,7 % → 28,7 % |

(Die Kritik maß mit ihrem eigenen Werkzeug; „eigene Messung vorher“ ist mein Werkzeug auf dem Stand vor den
Stufenänderungen, aber schon mit den neuen Felgen und dem neuen Glas.) Bei 160 m ändern sich 10–18 Bildpunkte
(17–32 %): Ein späterer Wechsel macht den Sprung kleiner, nicht seltener.
