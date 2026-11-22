- **K1 (hoch) behoben:** Die Läden leuchten nachts so wie in Arcade. Am Pariser Eckhaus sind es 22,7 % warme Pixel im
  Erdgeschoss (Arcade 28,2 %, vorher 10,9 %), Farbe (233,193,135) gegen Arcade (250,215,157). Hinter dem Glas stehen
  Regale, Waren und Theken. Die Formel teilen beide Chargen, deshalb leuchten auch die Läden in Hamburg (Charge 1)
  doppelt so stark wie vorher. Bei Tag ändert sich nichts.
- **K3 (Gartenbaum) behoben:** Südhaus (588 Platzierungen) und Loire-Haus (209) haben eine Blattkrone aus Karten mit
  den AS3-Blattbüscheln. Die Karten liegen im Ausschneide-Atlas des Hauses, deshalb bleibt es bei zwei
  Zeichenaufrufen. lod1 zeigt dieselben Karten. Der Stufenwechsel ändert beim Südhaus 8,2 % der Pixel (vorher 16,4 %).
- **K4 teilweise:** lod1 der sechs Häuser mit Geländern zeichnet ohne Alpha-Test. Bei 100 m flimmert Haussmann mit
  0,3 % (vorher 1,0 %, Sprite 0,3 %). „Band zu dunkel“ ist abgelehnt (gegen die Füllfarbe ±4 Stufen).
- **K7 verbessert:** Die Geranien sind jetzt Polster.
- **K3 (Gartenmauer 15 px/m) abgelehnt:** Gemessen sind 32,1 px/m. Die Kritik hatte die Kronen gemessen.
- **K2 Ursache gefunden, im Modell nicht behebbar:** Die Fernfassaden bleiben blass. Der dunklere Innenring der
  Fernstufe änderte nichts (p10 bei 250 m −2…+1 Stufen). Die Diagnose zeigt: ohne Sonnenschatten bleiben die Modelle
  über 60–250 m gleich hell (−4…+3 %, Sprite −2…−5 %), mit den Schatten des Rennens werden sie +4…+29 % heller. Ursache
  ist das Ende der Echtzeitschatten, nicht die Mip-Kette – das gehört zum Renderer (R4/R7).
- **Neu und schlechter:** Die Blattkarten flimmern bei 100–150 m stärker als die alte Kugelkrone (Südhaus 1,0 / 1,5 %
  gegen 0,6 / 0,8 %).
- Alle 23 Stadthäuser sind neu exportiert. Fünf fremde Modelle kamen byte-gleich heraus, die Sprites sind
  unverändert (86/86).
