### 15.12 AU-R4: Tests als Wächter, Altstadtpflaster wie gehört, Lkw-Aufprall (vorher → nachher)

Zwei unabhängige Abnahmen des Stands AU-R3 (KRITIK-R2-CODE: Code, Auslösung, Regressionen; KRITIK-R2-MESS: Messung)
fanden keinen Blocker – aber vier Regeln, die kein Test schützte (hoch), den Altstadtanteil in Altstädten mit
Steinbrücke oder Tunnel, den Zufall der Vorbeifahrten ohne Test und die knappe Marge von V3 beim Lkw (mittel). AU-R4
ändert `audio_feed.gd` (Zuteilung des Altstadtpflasters), die Tests, die Doku und einen Pegel (`truck.heavy`); keine
Klangdatei, keine Musik. Jeder Befund ist mit dem Werkzeug seines Prüfers nachgestellt; alles gemessen (Godot 4.7.2,
ohne Bildschirm, Dummy-Treiber), gehört hat es niemand.

**Tests (KRITIK-R2-CODE H1–H4, M2, L3).** Verfahren der Prüfung: eine Zeile des Codes brechen, die zuständige
Testdatei laufen lassen – sie muss rot werden.

| Regel | Mutation | vorher | nachher | Test (`test_road_audio.gd`) |
|---|---|---|---|---|
| Quietschen: Tonhöhe je Ereignis, nicht je Bild | M01 | grün | rot – 348 Tonhöhenwechsel in 612 hörbaren Bildern (ohne Bruch 0) | `test_squeal_pitch_per_event` |
| Aufprall-Varianten zufällig statt reihum | M03 | grün | rot – auf jede Variante folgt genau eine | `test_collision_variety` |
| Plattenmuster: der leisere wird nachgestellt | M11 | grün | rot | `test_slab_loops_are_put_back_in_step` (neu) |
| Plattenmuster: erst über `align_ms` | M12 | grün | rot – 0-mal nachgestellt, 30 ms Versatz | dito |
| Pegel je Schicht ±2 dB / überhaupt zufällig / späterer Einsatz | M14 / M15 / M16 | grün | rot | `test_collision_layers_vary_in_level_and_onset` (neu) |
| Vorbeifahrt ±2 dB / Variante zufällig | M17 / M18 | grün | rot | `test_pass_by_variants_and_levels_at_random` (neu) |
| Fahrtwind im Tunnel 0 dB / Glas genau ab 80 km/h | M31 / M32 | grün | rot | `test_wind_zones_gusts_and_fades`, `test_collision_variety` |

Ohne Bruch messen die neuen Tests (gemessen): Plattenmuster bei 120 km/h mit 5·10⁻⁴ Drift in 60 s 4-mal nachgestellt,
jedes Mal bei 6,2 ms (Schwelle 6 ms), danach 0,00 ms, das lautere läuft ungestört; 240 Aufprallschichten: Pegel
−2,00 … +2,00 dB, Streuung 1,13 dB (gleich verteilt 1,15), Einsatz in 100 % später, im Mittel 10,4 ms, höchstens
20,0 ms; 60 Vorbeifahrten: −1,92 … +1,98 dB, beide Varianten des Pfostens, 35 Wiederholungen (zwei Varianten:
zufällig, nicht im Wechsel); 12 Quietscher, 12 verschiedene Tonhöhen, 0 Wechsel während eines Quietschens.
Alle 32 Mutationen der Prüfung und 11 neue für die Zuteilung des Pflasters: siehe Bericht von AU-R4.

**Altstadtpflaster (KRITIK-R2-CODE M1).** Die Zuteilung zählte Steinbrücken und Tunnel als freie Straße; der Feed
spielt dort aber immer Pflaster bzw. Asphalt. Seit AU-R4 gilt der Anteil **wie gehört**: Straße = Altstadt ohne
Brücken und Tunnel; eine Steinbrücke ist Straße, die schon gepflastert ist (`stone_stretches`); ein Tunnel der Etappe
(`tunnel_stretches`) ist keine Straße und ändert die Blöcke der Stadt nur, wenn er den Anteil dieser Ankunft aus dem
Band schiebt; nachgerückt wird bei jeder Altstadt (Abschnitt 8). Werkzeug der Prüfung (`kc_trigger.gd`, alle 64
sichtbaren Etappen in beiden Richtungen, echte `Track`, 1-m-Schritte):

| | AU-R3 | AU-R4 |
|---|---|---|
| Ankünfte außerhalb 0,6 ± 0,05 wie gehört (1-m-Raster) | 14 (Bordeaux, Dresden, Lyon, Paris, Toulouse, Tours 0,70–0,78; Barcelona, Ljubljana 0,549) | 3 (Barcelona 2 ×, Ljubljana: 0,549 im Raster, zugeteilt genau 0,550) |
| dasselbe in genauen Metern aus dem Plan (`cobble_alloc.gd`) | 11 von 100 | 0 von 100 (0,550–0,645) |
| Straßen allein, ohne Steinbrücke (Lesart AU-R3) | 22 außerhalb | 26 außerhalb – Lesart verlassen |
| Regeln der Auslösung (Pflaster, Deck, Beton, Fugen, Zonen, Tankspur) | 0 Verstöße | 0 Verstöße |
| Städte mit verschiedenen Mustern je Ankunft | 0 | 0 |
| Pläne mit gleicher Ausgabe des Prüfskripts | – | 114 von 128, darunter Kiel – Hamburg in beiden Richtungen (Hamburg `P--PP-P-P`) |

Anders klingen nur Bordeaux (0,70 → 0,60), Dresden (0,70 → 0,59), Lyon (0,71 → 0,61), Paris (0,72 / 0,78 → 0,60 /
0,64), Toulouse und Tours (0,70 → 0,60) – je ein Block weniger Pflaster, in Lyon ein Block an anderer Stelle, in Paris
zwei weg und einer dazu; in Saragossa wechselt nur das Kennzeichen eines
Blocks, der ganz auf der Steinbrücke liegt (dort klingt es ohnehin nach Pflaster; im 1-m-Raster 1 m am Brückenende).
Die Tunnel von Hannover – Hamburg (330 m) und Lüttich – Paris (130 m) lassen den Anteil im Band (0,617 / 0,644):
Beide Städte hören bei jeder Ankunft dieselben Blöcke. Beide Lesarten zugleich gehen nicht: Für Dresden, Tours,
Saragossa und Toulouse bringt keine Wahl der Blöcke die Straßen allein und „wie gehört“ zugleich ins Band (alle
Teilmengen durchgerechnet) – die Lesart gehört in §11.2.

**Lkw-Aufprall (KRITIK-R2-MESS M1).** <<TRUCK>>
