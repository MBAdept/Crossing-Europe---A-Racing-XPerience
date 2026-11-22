
## 6. Gates auf dem Endstand `2c154bc`

Alle Läufe nacheinander mit `nice -n 10`, `XDG_DATA_HOME` = eigener Ordner unter dem Notizbuch, Speicherwächter
(< 3 GB frei → warten). Ausgaben vollständig in `m1/R7b/gates/` (Skript `m1/R7b/sh/gates.sh`).

| Gate | Befehl | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, 0 Fehler (6 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | „334 Skripte geprüft, 0 fehlerhaft“ |
| Tests | `tools/run_tests.sh` (einmal, voll) | „==> Tests bestanden (995 s)“ – 811 Einheitstests ok (davon 8 in `test_landmarks.gd`), alle `tests/race3d/check_*.gd` OK, darunter `check_landmarks` 6/6 und `check_minimal_structures` „wahrzeichen“ (verweist auf den Builder); gehalten: `test_far_ground_water` (3), `test_props` (13) |
| Golden Arcade | `tools/golden.sh check` | „GOLDEN arcade: 20 von 20 identisch“, „GOLDEN arcade-ui: 17 von 17 identisch“ |
| Golden Modern | `tools/golden.sh modern-check` | „GOLDEN modern: 5 von 6 identisch“; `modern_s4_mittel` ANDERS; OpenGL ES gegen OpenGL OK (max. 2/255, 73,2 dB). Angesehen (s. u.); **nicht neu erzeugt** |
| Render-Prüfungen | `tools/run_render_checks.sh all` | „29 OK, 0 failed“ (5.147 s); `check_landmarks_render`: wahrzeichen_stelle (18 px), wahrzeichen_weich (0,23), wahrzeichen_nacht (659 helle Pixel), flugfeuer (242 rote Pixel, 0,40 % des Bildes); gehalten: `check_start_km0`, `check_terrain_cover` (mit K1), `check_light_base`; Instanzbudget: ganze Szene höchstens 141 / 172 / 216 mit Instanz-Uniforms (Grenze 230) |
| Sicht | `godot --headless -s res://tests/sim/modern_sight.gd -- --full` | Exit 0: f1 0 Fälle bis 270 m (99.424.500 Stichproben, 128 Richtungen), f1_lanes 0 bis 260 m, f2 ≤ 0,596, f3 0 von 5.923, f7 0 von 2.011.532, model 0 abweichend |
| Pfad | `godot --headless -s res://tests/sim/modern_path_check.gd -- --full` | Exit 0: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2.064 m (≥ 2.000) |
| Ganze Etappe Modern | `xvfb-run … godot … -s res://tests/race/run_stage.gd -- --stage=… --seed=7 --timescale=40 --graphics=modern --gfx-preset=medium` | Kiel–Hamburg und Dresden–Leipzig mit dem Autopiloten: `ok: true`, 0 Skriptfehler, je auf Kopf und Basis (§7) |

**`modern_s4_mittel` (Kiel–Hamburg km 80, Mittel)**: auf Kopf und Basis mit `KEEP=` neu gerechnet
(`m1/R7b/golden_s4_head/`, `…_base/`; die Basis trifft ihren Hash). Unterschied: 369 Pixel, höchstens **2/255**, alle
im Feld x 430–533, y 253–310 – das ist der Michel 1,26 km voraus (Turmspitze), den jetzt `landmarks.gd` mit
`landmark.gdshader` statt `props.gd` mit `baked.gdshader` zeichnet. Mit dem Auge nicht zu sehen; gewollt. Nach A-18
gehört `tests/golden/modern_slice.*` der Integration und QA („packages do not regenerate it“) – darum kein
`modern-make` (Vertragsfrage §8: die Aufgabe nennt `modern-make` für gewollte Änderungen).

## 7. Leistung: ganze Etappe Modern, Kopf gegen Basis

`tests/race/run_stage.gd`, Zeitraffer 40, Seed 7, „Mittel“, 1280 × 720, llvmpipe unter Xvfb, vier geteilte Kerne mit
Last anderer Pakete – **gemessen**; echte Hardware **gefolgert**. Basis = `9b02f05` (RINT-M2, Kopie mit eigenem
`.godot`). render() / Stück / collect aus `perf_stats()` am Etappenende; Draw Calls und Primitive des letzten Bildes.

| Etappe | Stand | ok | Skriptfehler | render() Ø / max ms | Stück-Commit max ms | collect Ø / max ms | Draw Calls | Primitive | Textur MB | `landmarks` Ø / max ms | `backdrop` Ø / max ms | `props` Ø / max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Kiel–Hamburg | Basis | ja | 0 | 4,76 / 77,1 | 5,6 | 1,89 / 3,4 | 156 | 181.985 | 95,1 | – | 0,152 / 1,9 | 0,109 / 1,2 |
| Kiel–Hamburg | Kopf | ja | 0 | 4,38 / 61,6 | 2,3 | 1,67 / 2,8 | 156 | 181.985 | 97,6 | 0,054 / 0,6 | 0,174 / 2,9 | 0,069 / 1,2 |
| Dresden–Leipzig | Basis | ja | 0 | 5,29 / 60,0 | 3,4 | 1,89 / 6,6 | 184 | 223.856 | 87,4 | – | 0,158 / 4,8 | 0,107 / 1,2 |
| Dresden–Leipzig | Kopf | ja | 0 | 5,70 / 97,7 | 2,7 | 2,03 / 6,0 | 188 | 223.856 | 87,4 | 0,056 / 1,2 | 0,171 / 2,8 | 0,069 / 1,2 |

Lesart: render() im Mittel gleich (± 9 %, so weit streut llvmpipe unter fremder Last; die Maxima sind einzelne Bilder
mit Fremdlast). Der Builder `landmarks` kostet im Hauptthread 0,05 ms je Bild, höchstens 1,2 ms – unter der Grenze
von 2 ms (A-18; gemessen bei „Mittel“, für „Deck“ gefolgert: der Builder hängt nicht von der Stufe ab); sein
`collect()` ist leer (0,001 ms). `props` wird um 0,04 ms je Bild billiger (gefolgert: die fernen Vertretungen laufen nicht mehr).
`backdrop` +0,02 ms (Skyline). Draw Calls +4 am Ziel Leipzig (gefolgert: die Kuppelform des Völkerschlachtdenkmals mit
Flächen und Leuchtpunkten, deckend und im Schatten), Textur +2,5 MB am Ziel Hamburg (Ursache nicht gemessen; im Budget
von A-6). Die Wanduhr (233–274 s) misst den ganzen Prozess unter Fremdlast und ist kein Vergleich.
