## 2. Die Befunde der Kritik – selbst geprüft

| Befund | Prüfung (gemessen/angesehen) | Urteil |
|---|---|---|
| K1 Schaufenster nachts dunkler (hoch) | Nachtatlas Haussmann: Ladenpixel R-Median 128–145 gegen Fenster 221 (8 bit, gemessen); Formel `_display_mat`: Licht ≈ 0,25 × Lichtfarbe gegen 0,83 × bei Wohnfenstern (gerechnet) | **bestätigt** – behoben |
| K2 Fernfassaden blass, Fenster rosa-lila (mittel) | Ursache gefunden: der Innenrahmen-Ring von AS5aR1 (`inner_frame`, 6 cm Rahmenfarbe innen im gemalten Fenster) verdoppelt das Weiß eines Fensters der Fernstufe gegenüber dem Sprite: Weißanteil der Fensterzelle 36 % statt 23 % (Südhaus-Fenster 1,15 × 1,9 m, gerechnet), Mittel der Zelle ≈ 115 statt 90 Luma | **bestätigt** – behoben |
| K3 Gartenbaum als Klumpen (mittel–hoch) | Nahansicht Südhaus angesehen: facettierte Kugelkrone | **bestätigt** – behoben (Blattkarten) |
| K3 Gartenmauer 14–16 px/m | Exportbericht AS5a2: `ppm_road_min` 32,53 = 0,6 × 54,21 (die Mauer ist die einzige Straßenwand mit Gewicht < 1); GLB-Dreiecke der Probe: Mauer außen 0,60 × ppm, innen 0,18 ×, Abdeckung 0,30 × (gemessen). Die 15 px/m der Kritik sind die Kronen von Platane und Oleander (Gewicht 0,3 × 54 = 16), die im Messkasten `K5_OUTER` 4,5 m am Straßenrand liegen | **abgelehnt** (Mauer 32,5 px/m ≥ 26) |
| K4 Geländer schließen sich in kleinen Mips (mittel) | Deckung wächst (Haussmann 1,16/1,55/1,96/2,74, bestätigt) – das ist die Absicht von A-22 (`cut_fill`): die Lücken tragen die Farbe hinter dem Geländer; gegen diese Farbe bleibt die Helligkeit des Bandes in allen Mips innerhalb ±4 Stufen (mipband mit Hintergrund = Füllfarbe: Haussmann +1,0/+1,0/+1,8/−0,5; Lyon +1,2/+0,9/+3,6/+0,3; Südhaus +0,2/−0,2/−1,3/−3,0; Chalet +0,1/−0,5/−0,6/−3,0, gemessen). Die −53 Stufen der Kritik rechnen mit hellem Stein hinter dem Geländer. Eine deckungserhaltende Lücke (Alpha je Karte gewählt, ausprobiert: Haussmann Mip 4 0,92 statt 2,74) verliert die Dunkelheit (durchgelassene Texel tragen die Mischfarbe, gefolgert und am Atlas gerechnet) | **teilweise bestätigt**: Flimmern bestätigt – lod1 jetzt ohne Alpha-Test; „Band zu dunkel" abgelehnt |
| K5 Stufenwechsel ohne Überblenden | R7 (A-22) | nicht Modell |
| K6 Flimmern Sprossen/Rahmen | in lod1 gemalte Sprossen und Innenring jetzt dunkler (K2); lod0-Sprossen sind Geometrie (vpbr) | teilweise behoben |
| K7 Geranien als Perlenkette (niedrig) | angesehen | **bestätigt** – behoben |
| K8 Rückseiten Eckhaus (niedrig) | – | nicht behoben (8 Platzierungen, selten zu sehen) |
| K9 keine Wandleuchten (niedrig) | Arcade zeigt dort auch keine | nicht behoben |
| K10 lod1 spart wenig (Südhaus 69 %) | – | behoben über Kronen-Dezimierung |
