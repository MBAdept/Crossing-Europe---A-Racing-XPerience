
### 10.11 Messwerte

| Messung (gemessen auf dieser Maschine) | Wert |
|---|---|
| `render()` in GDScript, headless, 1.500 Bilder einer Fahrt mit 150 km/h ab Kiel – Hamburg km 2, nur Straße, Leitplanken, Rig, Hintergrund, Lichter, Overlay | 0,117 ms im Mittel (höchstens 1,75 ms); mit dem Zeichnen des Hintergrunds (0,494 ms je Neuzeichnen, bei Tag in 19 % der Bilder) 0,208 ms (`check_modern_stage` „kern_zeit“, bestes von höchstens drei Läufen) |
| Einhängen eines Stücks (Straße + Leitplanken), headless | höchstens 0,41 ms |
| Linienlage gegen Arcade (`check_road_parity`) | Gerade 0,23 px; R 400 m 7,11 px bis 150 m; R 136 m 13,27 px bis 100 m; gegen das eigene Kameramodell höchstens 0,32 px |
| Tageslicht bei S1 gegen Arcade (`check_light_base`) | Asphalt −6,7 %, Gras +1,5 % (Geländevertretung), Himmel −4,8 %; „Schatten: Aus“ gegen „Mittel“ −0,32 % (1,25 % des Bodens im Schatten der Leitplanken) |
| Aufwärmen mit kaltem Cache (`warmup_cold.gd`, „Mittel“, 30 s) | 0 Shader-Varianten während der Fahrt um 12 Uhr und um 19:06 Uhr; längstes Bild 497 ms bei Median 179 ms bzw. 362 ms bei 189 ms (Last der Maschine 7–19) |
| `ERGEBNIS` Kiel – Hamburg, Autopilot, Arcade gegen Modern | 28 Schlüssel, nur `gfx` verschieden |
| `modern_sight.gd --full` / `modern_path_check.gd --full` mit `max_chunks` = 18 | F1 0 Fälle bis 270 m (99,4 Mio. Stichproben), F2 höchstens 0,596, F3 0 von 5.923, F7 0; Abstand 267,6 m, 0 Kamerapositionen über 18 Stücken |
WERTE_OPENGL

Was die Zahlen nicht sagen: Zeiten einer echten Grafikkarte und des Steam Deck sind hier nicht messbar; die
Aufwärm-Zeiten unter llvmpipe schwanken mit der Last der Maschine stärker als jede Übersetzung (deshalb zählt die
Prüfung die Cache-Dateien). Die Tageslicht-Probe „Gras“ misst, solange `builders/terrain.gd` fehlt, die
unbeleuchtete Geländevertretung – mit dem echten Gelände misst sie dessen Shader.

### 10.12 Offene Punkte

- **Gelände an das Licht anschließen**: der Gelände-Shader legt sein Mesh wie die Fahrbahn auf Render-Ebene 2 und
  bindet `inc/pools.gdshaderinc` und `inc/headlight.gdshaderinc` ein (`ce_pools_display_light` mit
  `pool_ambient`, Rückstrahlung von Gras 0,45–0,6) und meldet das Material mit `add_pool_material()` an. Sonst
  beleuchten die echten Spots das Gelände nur als kurzen hellen Fleck, und Lampen- und Verkehrskegel fehlen dort.
- **„Schatten: Aus“ gegen „Mittel“**: die Prüfung vergleicht, wie im Bauplan, die mittlere Helligkeit des ganzen
  Bodens. Mit Bäumen und Fahrzeugen liegt mehr Fläche im Schatten, das Mittel sinkt dann zu Recht um mehr als 2 %;
  gemeint ist (D5), dass beleuchtete Flächen gleich hell bleiben – die Prüfung ist dann auf unbeschattete Bereiche
  umzustellen (Entscheidung der Zusammenführung).
- **Mittagssonne**: sie steht hinter dem Wagen; am Himmel fehlt mittags Arcades Sonnenscheibe (Himmel −4,8 % in der
  Probe). Ob eine Scheibe „vorn“ trotzdem gezeichnet werden soll, ist eine Bildentscheidung.
- **Feindetail**: Teernähte quer über die Fahrstreifen, kräftigere Körnung im Nahbereich, Asphalt etwas heller (die
  Probe liegt bei −6,7 %) – kleine Shader-Änderungen, danach `check_road_parity` und `check_light_base` erneut.
- **HUD hinter dem Ladebild**: die Sitzung setzt `hud.state` vor dem Start direkt; wer das HUD umbaut, hält es ohne
  `update_state()` zeichenbar.
