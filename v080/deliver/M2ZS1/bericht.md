# M2ZS1 – der erste Testbuild (ZS1) in der M2-Linie (Bericht)

Paket **M2ZS1** des Schubs M2: die Behebungen, die nach M2INT in den ersten Testbuild gingen (FIX-ZS1, FIX-WASSER,
FIX-WASSER-R = `39849f0`, beim Nutzer), in die M2-Linie (M2INT `49f221e`) zusammenführen und prüfen, ob jede mit dem
Inhalt von M2 noch hält. Kein Vorgänger (keine `STAND.md`, kein `wip/v080-m2zs1`) – frisch begonnen mit
`git merge --ff-only 49f221e`. Branch `worktree-wf_438996b0-243-2`, Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-2`; jeder Commit gepusht nach
`origin/wip/v080-m2zs1` (Sicherung) und `origin/wip/v080-m2int` (Fast-Forward von `49f221e`).
Commits: `25be6c7` (Merge), `efff1ed` (Pylon nachts, Flugbefeuerung), `b693d33` (`night_albedo` 0,45, Doku),
`6e48405` (Modern-Änderungsmelder, QA-Doku) – **Endkopf `6e48405`**.
„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne); alles über Steam Deck, echte
Grafikkarten, ANGLE/Direct3D und wie etwas auf einen Menschen wirkt, ist **abgeleitet**.

## Urteil

**ZS1 ist in der M2-Linie, und jede seiner Behebungen hält – eine erst nach Nacharbeit.**

- Start bei km 0: das Auto steht im Countdown und 1,5 s nach „LOS!“ an Arcades Stelle (Lackfläche ±1 %, wie FIX-ZS1),
  auch in der Steam-Deck-Stufe; die Lampenringe des Starttors werfen bei „Aus“ keinen Schatten.
- Fernboden: **eine Regel**, die von FIX-WASSER (der Nutzer hat sie); M2INTs eigene Behebung `b341df8` deckte nichts
  darüber hinaus ab und entfällt, ihr Unit-Test bleibt (umgestellt). Elbe und Nord-Ostsee-Kanal liegen unter den
  Brücken wie in ZS1.
- Wahrzeichen-Ersatz der sechs Städte: auf allen 20 Anfahrten da – seit AS4R als Kirchen- bzw. Hochhaus-**Modell**
  (ungetönt).
- **Pylone nachts: nach dem Zusammenführen wieder hellgrau** (84,4 gegen Arcade 60,1): der Pylon ist seit AS4R ein
  Modell, dessen Nachtatlas der angestrahlte Pylon des Sprites ist, und der Mond hellt den hellen Beton auf. Behoben
  (Kopie des Materials ohne Nachtatlas, `night_albedo` 0,45): entlang der ganzen Brücke höchstens Arcade und höchstens
  ZS1 (km 78,1: 55,9). Die **rote Flugbefeuerung blinkt** jetzt wie in Arcade.
- Modern-Änderungsmelder nach dem Ansehen neu: Start und S4 neu, die anderen vier MD5-gleich mit M2INT.
- **Alle Gates grün auf `6e48405`** (gemessen): Import sauber, 310 Skripte, `run_tests.sh` 749/0, Arcade 20/20 und
  17/17 identisch, Modern 6/6 + OpenGL ES, **Render-Prüfungen 19/19** (`check_light_base` jetzt grün, `check_start_km0`,
  K1), Sicht und Pfad `--full`, Builds im Größenbudget (Zip 194,5 MB), Rauchtests Linux, OpenGL ES und Windows/Wine.
- Ehrlich zum Bild: an den geprüften Stellen ist M2ZS1 **nirgends schlechter als ZS1** und an der Köhlbrandbrücke
  nachts besser (Elbphilharmonie und Michel beleuchtet, Seile dünn); gegen **Arcade gleichwertig, nicht deutlich
  besser** – in Belgrad schlechter (generische Kirche statt der Kuppelkirche, wie schon in ZS1).

## 1. Zusammenführung (`25be6c7`, `--no-ff`)

Quelle `origin/wip/v080-fix-wasser-r` = `39849f0` (Zwischenstand 1, beim Nutzer) auf M2INT `49f221e`; Basis beider
Seiten `92ece73`. Vorher geprüft mit `git merge-tree`: Konflikte in `scripts/race3d/layers/far_ground.gd`,
`docs/renderer-modern-gelaende.md`, `tests/golden/modern_slice.md5/.env`; automatisch gemischt `props.gd`,
`vehicles.gd`, `test_props.gd`, `renderer-modern.md`, `qa-v080.md`.

| Konflikt | Lösung |
|---|---|
| `layers/far_ground.gd` | **eine Regel – die von FIX-WASSER** (Testbuild, bewacht von `test_far_ground_water` und K1): `target_height()` = min(tiefste Straße des Fensters − 4 m, tiefstes Wasser − 0,3 m), `lowest_water()` über `Track.bridges`, `window_rows()`. M2INTs `b341df8` (Wasserhöhe in `lowest_road(…, track)`, jede vierte Reihe, Scheibe 4 m unter dem Wasser) entfällt. Geprüft, ob `b341df8` mehr abdeckt: **nein** – `water_level` < 0 tragen nur Reihen in `Track.bridges` (`Track._mark_bridge`, eingefroren: einzige Stelle, die es setzt), dieselben Reihen liest FIX-WASSER vollständig (jede statt jeder vierten) und prüft `s.index == k` (eine aus dem Speicher der Strecke gefallene Reihe liefert bei `b341df8` die erste gehaltene Reihe, also eine falsche Höhe); an den Elbbrücken (3,6 m) hätte `b341df8` die Scheibe 7,6 m statt 4,0 m unter die Straße gelegt und das Bild geändert. Übernommen von `b341df8`: der **Unit-Test** `test_far_ground_lies_below_the_water_of_a_bridge` (synthetische Strecke, jetzt mit einer Brücke in `Track.bridges` und auf `target_height()` umgestellt; prüft zusätzlich, dass jede Wasserreihe gelesen wird – die tiefste liegt zwischen zwei Straßenproben) und der **Befund** „46 von 46 Schiffen auf Wassersegmenten“ in der Doku |
| `docs/renderer-modern-gelaende.md` | Text von FIX-WASSER + ein Absatz zur einen Regel + M2INTs Schiffsbefund |
| `tests/golden/modern_slice.*` | im Merge vorläufig M2INTs Liste, neu erzeugt nach dem Ansehen (Abschnitt 5) |

**Inhaltliche Konflikte** (automatisch gemischt, aber rot – `tools/run_tests.sh unit/race3d/` nach dem Mischen: 118
Tests, 2 rot, gemessen):
- `test_procedural_bridge_pylon_stand_in_stays_dark_at_night`: verlangte eine Sprite-Vertretung des Pylons – seit AS4R
  ist `props/bridge_pylon` ein Modell. Jetzt mit einem Test-Manifest ohne das Pylon-Modell (wie `check_vehicles`
  „kasten“): die dunkle Vertretung bleibt der Rückfall; neu `test_bridge_pylon_is_a_model_with_its_aviation_light`.
- `test_procedural_landmarks_without_sprite_or_model_get_their_fallback`: verlangte die Gruppe `l|<Ersatz-Set>|0` einer
  Vertretung – `props/church` und `props/building_tall` sind seit AS4R Modelle, das Ersatzbild steht als Modell da
  (Gruppe `m|…` mit Wahrzeichen-Flag). Der Test nimmt jetzt beide Formen an (Wahrzeichengesetz, nie gespiegelt,
  `fallback_scale`; Tönung nur bei einer Vertretung) und prüft **alle 20 Anfahrten** in die sechs Städte statt einer
  je Stadt.
Danach 119 von 119 race3d-Unit-Tests grün (gemessen).

## 2. Hält jede Behebung des Testbuilds nach dem Zusammenführen?

| Behebung (ZS1) | hält? | Beleg (gemessen) |
|---|---|---|
| FIX-ZS1: Vorlauf vor der Startlinie, Stück −1, Spielerauto im Countdown (`road_path`, `chunk_streamer`, `chunk_context`, `layers/vehicles`) | **ja** | `test_start_lead_in` 6/6; A/B Start „Mittel“: Lackfläche gegen Arcade Kanten +0,0/+0,5/+0,0/+0,0 % (Countdown 1 s) und +0,0/+1,0/−0,5/+0,5 % (1,5 s nach LOS) – wie FIX-ZS1; Steam-Deck-Stufe 1280 × 800: Auto im Countdown an seinem Platz (Bild); Render-Prüfung `check_start_km0` (Gates) |
| FIX-ZS1: Lampenringe des Starttors werfen bei „Aus“ keinen Schatten (`gantry.gd`) | **ja** | `check_light_base` „schatten“ – bei M2INT der einzige rote Render-Check (Gates) |
| FIX-WASSER: Fernboden unter dem tiefsten Wasser (`far_ground.gd`) | **ja**, eine Regel | `test_far_ground_water` 4/4, `test_terrain_builder` (b341df8, umgestellt) grün; `check_terrain_cover` mit K1 (Gates); A/B Köhlbrandbrücke Tag/Nacht und Holtenau: Wasser wie in ZS1 |
| FIX-WASSER-R: Ersatz-Sets der sechs prozeduralen Wahrzeichen (`props.gd`) | **ja**, jetzt als Modell | `test_props` auf allen 20 Anfahrten (Kirche bzw. Hochhaus als Modell, Wahrzeichengesetz, nie gespiegelt, `fallback_scale`); A/B Belgrad |
| FIX-WASSER-R: Pylone nachts nicht heller als Arcade (`dark_material()`) | **zuerst nein** – mit AS4Rs Pylon-Modell galt die Vertretung nicht mehr (84,4 gegen Arcade 60,1); **nach Nacharbeit ja** (Abschnitt 3) | Messungen Abschnitt 3 |
| FIX-WASSER-R: Prüfposition K1, Draufsicht über `target_height()` | **ja** | `check_terrain_cover` K1, `check_terrain_plan` (Gates) |

## 3. Brückenpylon nachts und Flugbefeuerung (neu, `efff1ed`, `b693d33`)

**Befund nach dem Zusammenführen** (gemessen, Köhlbrandbrücke km 78,1, 22 Uhr, „Hoch“, Bereich von FIX-WASSER-R
x 500–780 × y 150–350, mittlere Leuchtdichte nach Rec. 709 wie in `NACH-WASSER/tools/measure.py`): Arcade 60,1,
ZS1 58,4, **zusammengeführt 84,4** – die Pylone leuchteten wieder hellgrau. Ursache, zwei Teile:
1. Seit AS4R ist `props/bridge_pylon` ein Modell; `dark_material()` von FIX-WASSER-R greift nur bei der
   Sprite-Vertretung. Der Nachtatlas des Modells (`emit.png`, mittlerer Wert 60/255, 85 % der Fläche > 32) ist der
   angestrahlte Pylon des Sprites – genau die Lichtebene, die FIX-WASSER-R abgeschaltet hatte.
2. Ohne Nachtatlas noch 79,5: der Mond beleuchtet die hellen Betonflächen (Albedo ≈ 0,78) und die Seile; Arcades
   prozeduraler Pylon ist nachts Beton × Umgebungslicht (`RoadRenderer._oc`, Licht nur 0,3 × am Fuß).

**Behebung** (`builders/props.gd`, `assets/shaders/modern/baked.gdshader`): Einträge mit `prefer_proc` (nur die Pylone
der Schrägseilbrücken, `Track._build_bridge`) kommen als Modell in eine eigene Gruppe `md|…`; `_dark_model_override()`
gibt dem Knoten eine Kopie des Materials mit `emit_energy` 0 und `night_albedo` = `PYLON_NIGHT_ALBEDO` 0,45 (neuer
Parameter von `baked.gdshader`: Albedo × (1 − (1 − n) × ce_night), Vorgabe 1 = Faktor genau 1,0 – kein anderes
Material ändert sich). Derselbe Shader, keine neue Variante, bei Tag dasselbe Bild.

**Messreihe** (gemessen; 22 Uhr, ab km 77,6 mit 80 km/h und Verkehr; Arcade-Bilder bitgleich mit FIX-WASSER-R):

| km | Arcade | ZS1 (Vertretung) | zusammengeführt | ohne Nachtatlas | `night_albedo` 0,55 / 0,5 | **0,45 (Endstand)** |
|---|---|---|---|---|---|---|
| 77,7 | 76,5 | 79,7 | 83,7 | – | – / 71,6 | **70,7** |
| 78,1 | 60,1 | 58,4 | 84,4 | 79,5 | 60,2 / 58,0 | **55,9** |
| 78,8 | 48,1 | 49,8 | 57,9 | 53,6 | 44,9 / 43,9 | **43,0** |
| 78,9 | 47,7 | – | – | – | – / 43,6 | **42,6** |
| 79,7 | 51,6 | 52,1 | 77,8 | – | – / 53,7 | **51,7** |

0,5 lag bei km 79,7 2 Stufen über Arcade (die Laternen beleuchten dort die Seile neben dem Deck) – darum 0,45: an
allen fünf Stellen höchstens Arcade (79,7: +0,1, Messrauschen) und an allen höchstens ZS1. **Steam-Deck-Stufe**
1280 × 800 (Arcade mit Balken, Bereich 40 Zeilen tiefer), 0,45: km 77,7 / 78,1 / 78,8 – Arcade 76,5 / 60,1 / 48,1,
ZS1 78,4 / 61,0 / 50,9, **M2ZS1 69,2 / 57,7 / 43,5**.

**Rote Flugbefeuerung** (Arcade: `RoadRenderer._pylon` blinkt bei Lichtern > 0,2, an solange
`fmod(time + side × 0,4, 1,6) < 0,8`, Schein max(3 px, 1,2 m), Alpha 0,8 × Lichter). Billig, weil das Pylonmodell
schon einen roten Lampenanker auf 88,3 m hat (bisher Dauerlicht der Ebene `flares`): `props.gd` gibt Ankern ab 25 m
Höhe eines Eintrags `proc` = `pylon` den Takt `PYLON_BLINK` (1,6 s, 0,8 s, Phase Seite × 0,4 s) als `"blink"`;
`layers/flares.gd` lässt eine Lampe mit Takt nur in ihrer Phase leuchten (`blink_lit()`, rein, nach `view.time`, steht
im Pausenbild still) und legt Arcades roten Schein als zweiten Lichtpunkt darum. Unit-Tests: Takt, Phasen ±0,4 s,
Wechsel der Seiten und Tag/Nacht gegen Arcades Formel über 1,6 s in 10-ms-Schritten; Lampenanker rot, ohne Kegel. Im
Bild nicht belegt (Pylonspitzen an den geprüften Stellen hinter dem oberen HUD-Balken).

## 4. Bilder – ehrlich gegen Arcade und gegen den gelieferten ZS1

`tools/ab_shot.sh` (Xvfb, `--fixed-fps 60`, `--gfx-sync`), dieselben Argumente wie die Läufe, aus denen die Bilder von
ZS1 stammen (FIX-ZS1 `kh0`, FIX-WASSER `holtenau`, FIX-WASSER-R `kb_*`, `belgrad`). **Die Arcade-Bilder sind in jeder
verglichenen Szene bitgleich mit denen der ZS1-Läufe** (19 von 19 Bildern: Start 2, Köhlbrandbrücke Nacht 4, Tag 3,
Steam-Deck-Nacht 3, Holtenau 4, Belgrad 3; `cmp`, gemessen) – derselbe Simulationszustand, die
Modern-Bilder lassen sich direkt vergleichen. Dreierbilder Arcade | ZS1 | M2ZS1 in `bilder/` (Hälfte der Größe), alle
angesehen; Rohbilder in `m1/M2ZS1/shots/`.

| Szene | Bild(er) | M2ZS1 gegen ZS1 | M2ZS1 gegen Arcade (ehrlich) |
|---|---|---|---|
| Start Kiel – Hamburg, Countdown 1 s, „Mittel“ | `start_mittel_countdown_1s.jpg` | gleich: Auto an seinem Platz (Lackfläche ±0,5 %), Starttor, Startlinie, Schild „Tankstelle 15 km“; dazu die Bäume von AS3R | gleichwertig, nicht besser: links fehlt Arcades große Eiche (schon in ZS1) |
| Start, 1,5 s nach LOS, „Mittel“ | `start_mittel_los_plus_1_5s.jpg` | gleich (Kanten +0,0/+1,0/−0,5/+0,5 %, FIX-ZS1 maß dasselbe) | gleichwertig |
| Start, Steam-Deck-Stufe 1280 × 800 | `start_deck_countdown_1s.jpg`, `start_deck_los_plus_1_5s.jpg` | (kein Rohbild von ZS1 in dieser Stufe; FIX-ZS1 zeigte den Countdown am Steam-Deck-Format nur über den Erststart) – Auto im Countdown da, 16:10 gefüllt | gleichwertig; Modern füllt 16:10, Arcade mit Balken |
| Köhlbrandbrücke 22 Uhr, „Hoch“, km 77,7 / 78,1 / 78,8 / 78,9 / 79,7 | `kb_nacht_hoch_km*.jpg` | **besser**: Elbphilharmonie und Michel beleuchtet (M2INT, fehlten in ZS1); Pylone dunkel wie in ZS1 (Messreihe Abschnitt 3), Seile dünne dunkle Linien statt der breiten hellen Bänder des Sprites; Elbe und Fähren wie ZS1 | gleichwertig: Pylone so dunkel wie Arcades, Wasser, Schiffe, Wahrzeichen an Arcades Stelle; Spielerauto heller als Arcades Sprite (bekannt) |
| Köhlbrandbrücke 12 Uhr, „Hoch“, km 78,1 / 78,8 / 78,9 | `kb_tag_hoch_km*.jpg` | Pylon als Modell (Beine, Seilfächer bis zur Deckkante) statt Sprite-Vertretung mit verwaschenen Füßen; Wasser wie ZS1 | gleichwertig bis etwas besser (Pylon als Körper, Schatten); die Pylonbeine stehen nah an der Fahrbahn hell im Bild |
| Köhlbrandbrücke 22 Uhr, Steam-Deck-Stufe | `kb_nacht_deck_km*.jpg` | wie „Hoch“: dunkler als ZS1 (69,2 / 57,7 / 43,5 gegen 78,4 / 61,0 / 50,9), Elbphilharmonie da | gleichwertig |
| Köhlbrandbrücke 12 Uhr, Steam-Deck-Stufe | `kb_tag_deck_km*.jpg` | ZS1-Bild aus einem anderen Lauf (60 km/h): Wasser und Schiffe gleich, Pylon als Modell | gleichwertig |
| Holtenauer Hochbrücke (Rostock – Kiel ab km 200), 12 Uhr | `holtenau_0[0-3].jpg` | gleich: Kanal beidseits bis zum Horizont, Fähre auf dem Wasser (Modell von AS4R statt Sprite) | gleichwertig; Arcade zeigt links hinter der Brücke schon Land |
| Ada-Brücke Belgrad (km 198,7 / 199,1 / 199,8 / 200,2 / 200,7), 12 Uhr | `belgrad_0[0-4].jpg` | Ersatzbild jetzt das **Kirchen-Modell** (× 2,3) statt des getönten Sprites: schlanker (Turmseite zur Straße), ungetönt; Pylon als Modell mit weißem Seilfächer statt Sprite-Bändern | **schlechter als Arcade** wie schon ZS1: generische Kirche statt der Kuppelkirche des Heiligen Sava; gegen ZS1 gleichwertig (Modell statt Bild, dafür weniger Masse) |

Nicht im Bild belegt: das **Blinken** der Flugbefeuerung – an den geprüften Stellen liegt die Pylonspitze hinter dem
oberen HUD-Balken (die Brücke liegt hoch). Belegt durch den Unit-Test (Takt gegen Arcades Formel) und die Lampenanker im
Test des Pylonmodells.

## 5. Modern-Änderungsmelder (`6e48405`)

`KEEP=<scratch> tools/golden.sh modern-make` (472 s, gemessen), dann die sechs Bilder angesehen, dann die Liste
committet. Im Merge-Commit stand vorläufig M2INTs Liste (dort im Commit-Text gesagt).

| Bild | M2INT `49f221e` | M2ZS1 | angesehen |
|---|---|---|---|
| `modern_start_mittel_00` (km 0, Countdown 2,2 s) | `e7714a12…` | **`1fa6d0b4…`** | gewollt: Spielerauto im Countdown an Arcades Stelle (FIX-ZS1), Starttor mit drei Lampen, Schild „Tankstelle 15 km“, Bäume von AS3R – bei M2INT fehlte das Auto |
| `modern_s4_mittel_00` (km 80,6, Ende der Köhlbrandbrücke) | `649a97ff…` | **`711d3901…`** | gewollt: Fernboden unter dem Wasser im Fenster (FIX-WASSER); gegen das S4-Bild von ZS1 1,0 % der Bildpunkte anders (Verkehr, Bäume von M2), sonst dasselbe Bild |
| `modern_s2_mittel_00`, `modern_s3_hoch_00`, `modern_s5_niedrig_00`, `modern_s1_nacht_00` | – | MD5-gleich | auch S1 bei Nacht gleich: `night_albedo` lässt mit der Vorgabe 1 jedes andere Material bitgleich |

## 6. Gates auf dem Endkopf `6e48405` (gemessen)

Alle nacheinander mit `m1/M2ZS1/sh/gates.sh` (`nice -n 10`, je Schritt ein eigenes absolutes `XDG_DATA_HOME`, eine
Mesa-Shader-Ablage, Export-Vorlagen in das `XDG_DATA_HOME` der Builds verlinkt), Logs `m1/M2ZS1/gates/<schritt>.log`,
Zeiten `gates/summary.txt` (14:00–15:01 UTC). Jeder Schritt Exit 0.

| Gate | Aufruf | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, 0 Fehlerzeilen (4 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | **310 Skripte geprüft, 0 fehlerhaft** |
| Kopflose Tests | `tools/run_tests.sh` (einmal voll) | **„Tests bestanden“, Exit 0, 881 s: 749 Unit-Tests, 0 fehlgeschlagen** (M2INT 735 + 6 Vorlauf + 4 Fernboden/Wasser + 2 von FIX-WASSER-R + 2 neue: Pylon-Modell, Blinktakt); 175 CHECK-Zeilen OK, 0 FEHLER; u. a. `wahrzeichen` (22 Uhr bis 1 900 m), `bruecke`, `tore`, `inhalt`, `renderer_zeit` 0,718 ms je Bild, `terrain_plan_*` (Draufsicht über `target_height()`) |
| Fairness im ganzen Netz | `godot … -s res://tests/sim/modern_sight.gd -- --full` | **6 von 6 OK** (141 s): F1 0 Fälle bis 270 m in 99 424 500 Stichproben (128 Richtungen), Außenspuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 5 923, F7 0 von 2 011 532, Kameramodell 0 Abweichungen |
| Pfad | `godot … -s res://tests/sim/modern_path_check.gd -- --full` | **2 von 2 OK** (57 s): kleinster Abstand 267,6 m, Schleifen frühestens nach 2 064 m |
| Render-Prüfungen | `tools/run_render_checks.sh all` | **19 von 19 Dateien OK**, Exit 0 (1 384 s), 0 Shader-/Skriptfehler, kein Pufferüberlauf: `check_light_base` „schatten“ **grün** (−0,10 %; bei M2INT rot), `check_start_km0` (Kamera ≤ 1,14 px, Auto-Kanten ≤ 2 px, Boden 0,032), `check_terrain_cover` T1–T4, S1, C1 und **K1: 0,000 % Magenta, Fernboden 0,39 %** (Grenze 2 %; ZS1 0,38 %), `instanzen`, `instanzen_wald`, `check_modern_render`, `check_road_parity`, `check_occlusion`, `check_vehicle_lights`, `check_vehicle_standin`, `check_seam_render` |
| Arcade-Identität | `tools/golden.sh check` (einmal, am Schluss) | **GOLDEN arcade: 20 von 20 identisch** (139 s), **GOLDEN arcade-ui: 17 von 17 identisch** (127 s) |
| Modern-Änderungsmelder | `tools/golden.sh modern-check` | **GOLDEN modern: 6 von 6 identisch** (369 s); **OpenGL ES** `modern_s3_hoch` gegen OpenGL: OK, max. 2/255, PSNR 73,2 dB |
| Linux-Build | `tools/build_linux.sh` (+ `pck_report.py`) | Exit 0; 496,5 MB roh, Archiv geschätzt **184,7 MB** (Warnung 300, Abbruch 330, hart 350); Modern: Modelle 18,73 / 40, Texturen 13,04 / 60, Klang 16,38 / 23, Musik 18,60 / 25 MB |
| Windows-Build | `tools/build_windows.sh` | Exit 0; Zip gemessen **194,5 MB** – wie M2INT (184,7 / 194,5 MB) |
| Rauchtest Linux | `tools/smoke_modern.sh build/CrossingEurope.x86_64 …` | **SMOKE linux: OK** – Arcade 17 s, Modern 31 s, Leistungstest „autobahn“ 9,5 Bilder/s (Software-Grafik, bedeutungslos für echte Grafik), Nutzerdaten im eigenen Ordner |
| Rauchtest OpenGL ES | `DRIVER=opengl3_es tools/smoke_modern.sh …` | **SMOKE linux_opengl3_es: OK** – OpenGL ES 3.2, Arcade 17 s, Modern 74 s, Leistungstest 9,9 Bilder/s |
| Rauchtest Windows unter Wine | `tools/smoke_modern.sh build/CrossingEurope.exe …` (wine64, eigenes Präfix, `TMPDIR` leer) | **SMOKE windows: OK** – wineboot 8 s, Arcade 20 s, Modern 34 s, Leistungstest 9,3 Bilder/s; Nutzerdaten im Präfix |

## 7. Abweichungen, Vertragsfragen, für die Nächsten

**Abweichungen vom Auftrag**
1. Dateibesitz: `builders/props.gd`, `layers/flares.gd`, `assets/shaders/modern/baked.gdshader` gehören R2/R3 bzw. ihren
   Nachfolgern; geändert, weil der Auftrag es verlangt (Pylone nachts nicht heller als Arcade; Warnlicht als Lampe,
   wenn billig). `test_props.gd`/`test_terrain_builder.gd` beim Auflösen der inhaltlichen Konflikte angepasst.
2. Die Pylon-Behebung brauchte mehr als `dark_material()`: neuer Shader-Parameter `night_albedo` (Vorgabe 1, kein
   anderes Material betroffen) – die Nachtbeleuchtung durch den Mond ist kein Nachtatlas.
3. Ersatzbilder der sechs prozeduralen Wahrzeichen sind seit AS4R Modelle und damit **ungetönt** (`fallback_tint`
   gilt nur für Vertretungen); in Belgrad schlanker als das Sprite von ZS1.
4. km 78,9 der Köhlbrandbrücke: das ZS1-Gegenstück ist das Bild bei 4 s (km 78,8); 78,9 ist bei 4,3 s ergänzt.
   Steam-Deck-Tagbilder: ZS1-Vergleich aus einem anderen Lauf (FIX-WASSER, 60 km/h, ohne Verkehr).
5. Modern-Änderungsmelder: `modern-make` mit `KEEP` gerendert, die sechs Bilder angesehen, dann die Liste committet
   (statt erst `modern-check` und dann `modern-make` – spart einen 14-min-Lauf; `modern-check` lief als Gate danach).

**Vertragsfragen**
1. D16/A-3: der Fernboden steht im Vertrag noch als „tiefste Straße − 4 m“; die Regel des Testbuilds ist
   min(…, tiefstes Wasser − 0,3 m) (FIX-WASSER, seit M2ZS1 auch in der M2-Linie). Bitte nachtragen.
2. A-4/A-9: Wahrzeichen nur mit prozeduraler Zeichnung haben keine Vertretung im Vertrag; umgesetzt ist das Ersatz-Set
   des Etappenplan-Eintrags – seit AS4R als Modell ohne `fallback_tint`. Der Vertrag sollte sagen, ob eine Tönung für
   Modelle nötig ist (Leipzig #8a857a dunkler Stein) oder bis AS6 so bleibt.
3. A-16/D19: der Nachtatlas des Pylonmodells ist der angestrahlte Pylon des Sprites, den Arcade nie zeigt. Der Renderer
   schaltet ihn für `prefer_proc` ab; sauberer wäre ein Atlas nur mit der Befeuerung (Assets).
4. Nachtlicht der Modelle: der „Bodengesetz“-Abgleich (RINT-B) stimmt ebenen Boden auf Arcade ab; senkrechte helle
   Flächen bekommen vom tiefen Mond mehr Licht als Arcades Umgebungslicht-Gesetz – beim Pylon +40 %. `night_albedo`
   ist eine Stellschraube je Material; ob ein allgemeines Nachtgesetz für senkrechte Flächen nötig ist, entscheidet R4.

**Für die Nächsten**
1. Assets (AS5/AS6): den Nachtatlas von `props/bridge_pylon`/`_bare` ohne das Flutlicht des Sprites backen (nur die
   Befeuerung); danach kann `_dark_model_override()` den Atlas wieder zeigen, `night_albedo` bleibt.
2. R5: Pylonhöhe und Seilfächer je Brücke (`height_m`, `cables`); Arcades Warnlicht sitzt auf `height_m` + 1,6 m, das
   Modell auf 88,3 m. Kaimauern, Böschungen, fernes Ufer (QA-WASSER B3) weiter offen.
3. R4: prüfen, ob andere helle senkrechte Flächen (Gebäude, Brückenteile) nachts heller als Arcade sind (der Mond);
   `night_albedo` von `baked.gdshader` ist die Stellschraube je Material.
4. Wahrzeichen-Ersatz als Modell: `fallback_tint` fehlt (Leipzig dunkler Stein, Madrid bläulich) – eine Tönung über die
   Kopie von `_landmark_override()` wäre klein; endgültig die Wahrzeichen-Modelle (AS6).
5. Ein Bild der blinkenden Befeuerung fehlt (an den geprüften Stellen liegt die Pylonspitze hinter dem HUD-Balken) –
   bei R5 eine Stelle mit der Spitze im Bild wählen.
6. M2INTs offene Punkte gelten weiter (Niederschlag R4, nahe Requisiten R5, Lack der Spielerautos, Spielerauto nachts
   heller als sein Sprite – auch in diesen Bildern sichtbar).


## 8. Dateien

- Geändert gegen `49f221e` (25 Dateien): aus ZS1 `scripts/race3d/{road_path,chunk_context,chunk_streamer}.gd`,
  `layers/{vehicles,far_ground}.gd`, `builders/{gantry,props}.gd`, `tests/race3d/render/check_start_km0.gd`,
  `tests/race3d/render/check_terrain_cover.gd`, `tests/race3d/check_terrain_plan.gd`,
  `tests/unit/race3d/{test_start_lead_in,test_far_ground_water}.gd`; von M2ZS1 außerdem `builders/props.gd`
  (Pylon-Modell dunkel, Blinktakt), `layers/flares.gd` (`blink_lit`), `assets/shaders/modern/baked.gdshader`
  (`night_albedo`), `tests/unit/race3d/{test_props,test_terrain_builder}.gd`, `tests/golden/modern_slice.{md5,env}`,
  Doku `docs/{renderer-modern,renderer-modern-gelaende,qa-v080,modelle}.md`.
- Bilder für die Leitung: `deliver/M2ZS1/bilder/` – 26 Dreierbilder Arcade | ZS1 | M2ZS1 (halbe Größe) und
  `pylon_nacht_km78_1_arcade_zs1_vorher_nachher.jpg` (Pylonbereich: Arcade, ZS1, zusammengeführt, behoben).
- Arbeitsdateien: `m1/M2ZS1/` – `STAND.md`, Skripte `sh/` (`tests.sh`, `ab.sh`, `modern_only.sh`, `measure.py`,
  `paintbox.py`, `tri.sh`, `tris.sh`, `pictures.sh`, `after.sh`, `modern_make.sh`, `gates.sh`), Rohbilder `shots/`,
  Proben `probe/`, Modern-Änderungsmelder `golden_make_keep/`, Logs `logs/`, Gates `gates/`.
- Build im Worktree unter `build/` (aus `6e48405`, nicht committet, `/build/` ist ignoriert):
  `CrossingEurope-windows-x86_64.zip` 194,5 MB und `LIZENZEN.txt`; die nackten Programme (496,5 / 532,3 MB), das
  Wine-Präfix, die Daten-Ordner und Mesa-Ablagen der Läufe sind nach den Gates gelöscht (Platz).
