## 4. Wachen die beim Zusammenführen geänderten Tests noch ihre Regel? (Mutationen)

Je Regel genau **eine Zeile Produktcode** in der Prüfkopie `m1/QA-M2-SYSTEM/mut` (`git archive` des Kopfes, nie im
Gate-Arbeitsbaum) gebrochen (`bin/mutate.py`), der wachende Test gestartet, die Zeile aus dem Arbeitsbaum
zurückgeholt (`bin/mutations.sh`, Logs `mutations/`). Vorher lief jeder dieser Tests auf der unveränderten Kopie
grün (Grundlinie).

| Regel (Test) | gebrochene Zeile | Ergebnis |
|---|---|---|
| Set ohne Modell als Ersatz gezeigt (`check_vehicles` „kasten“, Test-Manifest) | `layers/vehicles.gd` `_set_level`: Kasten-Ersatz `n = null` | **rot** (`police/at` nicht als Kasten gezeigt) |
| dto. | `_update_car`: Bild-Ersatz statt `_update_sprite(…)` nur `_show(car, false)` | **rot** (`traffic/sports_red` nicht gezeigt) – kopflos läuft auch der Bild-Weg |
| keine Stufe fürs Instanzbudget freigegeben (`leistung`) | `INSTANCE_BUDGET := 8` | **rot** |
| kein Knotenbau, solange dieselben Autos fahren (`leistung`) | `car.levels[lod] = n` entfernt (gebaute Stufen werden nicht behalten, jeder Stufenwechsel baut neu, der alte Knoten bleibt hängen) | **grün – nicht erkannt**: im Messfenster erreicht genau 1 Auto eine neue Stufe, keines wechselt zurück (`34 Knotenbauten beim Erscheinen, 1 erste Stufen im Fenster`) |
| Brückenpylon-Modell nachts dunkel (`test_props` … `is_a_model_with_its_aviation_light`) | `dup.set_shader_parameter("night_albedo", …)` entfernt | Läufer meldet **„ok“, 12 / 0** – der Test bricht mit `SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor` (`test_props.gd:507`, `float(null)`) ab, ohne zu scheitern; rot nur über den `SCRIPT ERROR`-grep von `run_tests.sh` |
| dto. | `dup.set_shader_parameter("emit_energy", 0.0)` entfernt | dto. (`test_props.gd:506`) |
| Wahrzeichen ohne Sprite/Modell mit Ersatz-Set (alle 20 Anfahrten) | `landmark_fallbacks()`: Bedingung nie wahr | **rot** (`test_procedural_landmarks_…_get_their_fallback`) |
| Flugbefeuerung blinkt wie Arcade | `blink_lit`: Phase mit falschem Vorzeichen | **rot** (`test_pylon_beacon_blinks_like_arcade`) |
| Pylon-Vertretung ohne Lichtebene (Test-Manifest ohne Pylon-Modell) | `dark_material`: `lights_rect` nicht genullt | **rot** (`test_procedural_bridge_pylon_stand_in_stays_dark_at_night`) |
| Fernboden unter dem tiefsten Wasser (eine Regel, FIX-WASSER) | `target_height()`: nur noch `lowest_road − drop` | `test_far_ground_water` **rot** (3 von 4); `test_terrain_builder` … `below_the_water_of_a_bridge` (beim Merge umgestellt) **grün – erkennt es nicht**: auf seiner synthetischen Strecke liegt das Wasser (18,09 m) 11,6 m **über** der Scheibe der tiefsten Straße (6,44 m) – die Scheibe ist mit und ohne Wasserterm 6,44 m (gemessen, `gd/qa_farground_nums.gd`); der Test prüft nur noch `lowest_water()` |
| dto., Nachlauf (15.11.): fängt `check_vehicles` „instanzen“ es? | dieselbe Zeile | **rot**: höchstens 577 Instanzen der gebauten Stufen bei Budget 128 (`mutations/mut_leistung_cache_instanzen.log`) – die Regel ist bewacht, nur nicht vom Fall „leistung“ (M2S-03) |
| Pylon-Nachtregel durch das Tor (Nachlauf) | `night_albedo` nicht gesetzt, dann `tools/run_tests.sh test_props` | **Tor rot** („12 Tests, 0 fehlgeschlagen ==> Godot meldet Skriptfehler ==> Tests FEHLGESCHLAGEN“, Exit 1) – über den grep, nicht über den Test (M2S-04) |
| Modern-Änderungsmelder (beim Merge neu erzeugt) | `road.gd`: `lane_line_w` × 1,2 (Spurlinien 20 % breiter; die erste Mutation am Shader-Vorgabewert war wirkungslos, weil `road.gd` den Wert zur Laufzeit setzt) | **rot**: `modern_s3_hoch_00.png: ANDERS`, „GOLDEN modern: 0 von 1 identisch (Teilmenge s3)“, 504 s (`mutations/golden_lane.log`) |

Nach jedem Nachlauf ist die Kopie wieder gleich dem Arbeitsbaum (`vehicles.gd`, `props.gd`, `road.gd` = Arbeitsbaum, `q_followup.log`).
