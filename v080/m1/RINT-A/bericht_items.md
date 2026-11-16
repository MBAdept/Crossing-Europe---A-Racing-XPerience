### 2.1 Kern: Bandspitzen (R2-Bericht §9.1)

Die drei Zeilen aus R2s Versuch (`m1/R2/bin/exp_kernel.sh`) sind in `TerrainProfile._compute()`: die Innenseite wird
auch nach der stärksten Krümmung ihrer Seite im Korridorfenster (`_kappa()`) gekürzt. `check_terrain_plan` ist
streng (`STRICT = true`): 40 Kamerapositionen in 13 Etappenrichtungen, 601 Stücke, 37.488 Streifen –
0 Überlappungen verschiedener Straßenteile, **0 Paare von Bandspitzen** (vorher 71 Paare bis 1,83 m), höchstens
896 Dreiecke je Stück (gemessen). `modern_sight.gd -- --full` danach grün (Zahlen in den Gates).

### 2.2 Licht: Gelände, Fernboden, Lampen, Abblendlicht

- Gelände und Fernboden liegen auf Render-Ebene 2 wie die Fahrbahn (die echten Spots/Punktlichter lassen den Boden
  aus); `terrain.gdshader` und `far_ground.gdshader` binden `inc/pools.gdshaderinc` und `inc/headlight.gdshaderinc`
  ein (Arcades Rückstrahlfaktoren: Gras 0,45, Kies 0,6, Pflaster 0,8, Wasser 0,45); der Fernboden meldet sein
  Material mit `add_pool_material()` an. Gemessen (headless, Kiel – Hamburg km 80, 22 Uhr): Fahrbahn, Gelände und
  Fernboden tragen `pool_count` 16 und dieselbe `pool_ambient`.
- `--gfx-debug=cover`: war schon in `environment_rig.gd` (Nebel aus) und `layers/backdrop.gd` (magenta Leinwand)
  eingebaut (R1); `check_terrain_cover` läuft in den Render-Prüfungen.
- Lampen der Requisiten (`PropLibrary.lamp_pools()`): nach unten (Laterne, Tankdach) Kegel 9 m, eine Gruppe teilt sich
  Arcades Tankstellenlicht (je min(0,55; 1,6/n) – Tankdach 8 × 0,2); Wandlampen (Bauernhaus, Scheune, Zollhäuschen)
  5 m / 0,4, der Kegel liegt höchstens 1,5 m vor der Wand (`lights.gd pool_centre()`, vorher hätte die waagrechte
  Achse den Kegel bis zu ~30 m vor die Wand gelegt); Flugbefeuerung des Windrads (ab 25 m Höhe) ohne Kegel – sie hätte
  einen roten Kegel 300 m neben das Windrad gelegt und das Punktlicht-Pool belegt. Alle gehen über `add_lamps()` an
  `lights` und `flares` (A-7). Gemessen an S4 22 Uhr: 47 feste Lampen in beiden Ebenen, 16 Kegel, 4 Punktlichter,
  34 Lichtpunkte gezeichnet.
- `ce_headlight_pos/_dir/ce_headlight` setzt die Ebene `lights` (R1) in jedem Bild mit Abblendlicht; `sign.gdshader`
  nimmt damit die echten Scheinwerfer (`ce_headlight.y > 0`), der Kamera-Ersatz greift nur noch, wenn niemand sie
  setzt. Lack und Glas bekommen das Abblendlicht von den zwei echten Spots (Ebene 1).

### 2.3 Spiegelungen: eine Quelle

Siehe docs/renderer-modern.md §12.2 und `spiegelung_eine_quelle.png`. Gemessen (Ausschnitt des Spielerautos, S1,
„Hoch“, Mittelwerte RGB): Mittag – beide Quellen 86/102/136, nur Sky der Umgebung 75/92/126, nur analytisch
83/96/122, **neu 83,5/96,4/124,2**; 19:24 Uhr – beide 86/70/83, nur Sky 73,5/64/80, **neu 83/68/79**. Der Pfad ohne
analytischen Himmel (Showroom, Kontaktbogen) ist pixelgleich zu vorher (mittlere Abweichung 0,000).

### 2.4 Rotoren

`vpbr.gdshader` `vertex()`: Lackcode 0,875, Nabe = `UV2.y` × 128 m, Winkel = −`ce_time` × 1,35 rad/s + Phase aus
`MODEL_MATRIX`-Ursprung (x · 0,37 + z · 0,23) – genau AS1bs Vorgabe, nur das Vorzeichen so, dass sich der Rotor von
der Straße (+Z) aus im Uhrzeigersinn dreht. Render-Prüfung `rotor` (in `check_props_render.gd`): Windrad bei
`ce_time` 0 / 0,4 / 0,8 s – Rotor 2.837 / 2.779 Bildpunkte geändert, Turm 0 / 0 (jeder zweite Bildpunkt, gemessen);
Bild `rotor_drei_bilder.png`. Mit der Pause steht er (Prüfung `pause`).

### 2.5 Requisiten

- **Varianten**: eine je Stück und Set (`chunk_variant()`, stabiler Hash aus Stücknummer und Set) statt je Requisite.
- **Bodendecker**: `graphics.modern.props.bend_cover = ["props/cover_bush", "props/cover_grass"]`; weggelassene
  Pflanzen im Kurvenkorridor werden ein (Busch) bzw. drei (Baum) Stücke ≤ 0,5 m, nie näher als 0,8 m an der
  Fahrbahnkante, nicht in den City Limits (an C1 lagen sonst Grasbüschel auf dem Pflaster – gesehen, behoben).
  Vorher/nachher `bodendecker_T2_T4_vorher_nachher.jpg`: T4 2.115, T2 365 Bildpunkte geändert (gemessen) – an T4
  Strauchpolster und Grasbüschel auf der kahlen Innenseite, an T2 kaum sichtbar.
- **Helle Rauten am Horizont von S1**: gemessen mit Ausblenden einzelner Knoten – ohne die Fernbild-Knoten
  verschwinden 555 Bildpunkte in den Zeilen 300–319 (die Rauten), ohne die Kontaktschatten 418 andere (Zeilen
  318–401, der echte Fleck unter nahen Bäumen). Ursache: Fernbilder jenseits des Nebelendes sind reine Nebelfarbe vor
  den dunstigen Silhouetten des Hintergrunds. `billboard.gdshader` und `leaves.gdshader` blenden zwischen 0,85 und
  1,0 der Sichtweite mit geordnetem Dither aus; Bild `rauten_horizont_S1_vorher_nachher.png`.

### 2.6 Sitzung: ganze Etappe, Pause, Rückfall, Freigabe, Prozessende

- `tests/race3d/render/check_session_modern.gd` (neu, in `run_render_checks.sh`): `pause` – 30 Bilder in der Pause
  0 Bildpunkte verschieden, danach 132.660 (gemessen); `rueckfall` – `--gfx-debug=fail` mit echtem Selbsttest:
  `road_renderer.gd`, `gfx` arcade, `gfx_fallback` `selftest:debug`, 16:9 mit Balken; `freigabe` – nach der
  Modern-Etappe 55 Netze und geteilte Materialien, nach der Arcade-Etappe 0 Netze, 0 Texturen, keine geteilten
  Materialien.
- `RaceRenderers.leave_modern(always)` ist die eine Freigabe-Stelle (A-4); GameFlow ruft sie beim Wechsel aus den
  Menüs und beim Beenden (vorher hatten GameFlow und RaceRenderers je eine eigene Freigabe).
- Prozessende: `AudioManager` stoppt beim Beenden Motor, Schleifen und Einzelgeräusche und wartet 60 ms, bis der
  Audio-Server die Wiedergaben verworfen hat. Gemessen mit `--verbose` (Rennszene mit Bildaufnahme, die den Prozess
  beendet): vorher 2 von 3, 2 von 4, 2 von 5 Arcade-Läufen mit „3–9 ObjectDB instances leaked at exit“
  (`AudioStreamPlaybackWAV`, `AudioStreamWAV`, `AudioStreamGeneratorPlayback`); mit nur der Wartezeit noch 2 von 5;
  mit Stopp + Wartezeit **0 von 6 (Arcade), 0 von 3 (Modern)**.
- Ganze Etappe: siehe Gates (Fahrt unter Xvfb).

### 2.7 Prüfungen in den Läufern

- `tools/run_tests.sh`: `check_options_tabs.gd -- --graphics=arcade`, `check_attract.gd -- --graphics=modern`,
  `check_attract_scenes.gd -- --graphics=modern` (UI1); die neuen `tests/race3d/check_*.gd` nimmt der Haken mit.
- `tools/run_render_checks.sh` findet alle `tests/race3d/render/check_*.gd` über den Dateinamen (11 Dateien:
  facade, light_base, models, occlusion, props_render, road_parity, seam, session_modern, showroom, terrain_cover,
  vehicle_lights) – keine Änderung am Skript nötig.
- `check_light_base` → `schatten`: vergleicht beleuchtete, unbeschattete Flächen (Bildpunkte, die in einem Bild um
  > 0,04 dunkler sind, zählen nicht; mindestens 75 % des Bodens unbeschattet). Gemessen an S1: **−0,09 %** auf
  94,1 % des Bodens; das alte Maß (ganzer Boden) läge bei −1,69 % (5,6 % des Bodens im Schatten der Werfer).
- An den Stand nach AS1b angepasst: `props_spiegel` (Buche/Fels als Vertretungen statt Birke/Strohballen, die jetzt
  Modelle sind und sich drehen), `test_props.gd` (Varianten je Stück, Wandlampen, Tankdach, Flugbefeuerung,
  Bodendecker; Zeichenaufrufe je Set, Stück und Seite).
- Im ersten Gate-Lauf rot und an die Zusammenführung angepasst (Prüfungen, kein Spielcode): `check_vehicles`
  `lampen_fest` (die Etappe meldet jetzt eigene feste Lampen an – Grundlinie statt absoluter Zahlen),
  `check_models` `klassen` (das Bauernhaus von AS1b zeigt seine Anfahrtsseite auf +Z wie alle Requisiten, A-4 – die
  Prüfung dreht es nicht mehr um 180°), `check_occlusion` `lkw` (der Lichtkegel des verdeckten Autos beleuchtet seit
  der Lichter-Ebene zu Recht die Fahrbahn neben dem Sattelzug; die Prüfung gilt den Lampen und lässt die Kegel des
  Verkehrs weg).
- Im zweiten (letzten) Gesamtlauf rot: `check_modern_stage` → `kern_zeit` 0,618 ms (Grenze 0,6 ms; im ersten Lauf
  0,499 ms). Die Prüfung beschreibt den Renderer-Kern „ohne Fahrzeug-, Requisiten- und Gelände-Ebene“, maß seit der
  Zusammenführung aber alles, was `render()` jetzt aktualisiert. Neues Testdouble `tests/race3d/fixtures/core_renderer.gd`
  (Straße, Randausstattung, Hintergrund, Lichter, Overlay – wie R1 es ausgeliefert hat): Kern 0,194 ms allein,
  0,251 ms im Lauf der ganzen Datei, `check_modern_stage.gd` einzeln 7 von 7 OK (gemessen). Die Zeit des ganzen
  Renderers steht in den `perf_stats` der Etappe (Gates).

### 2.8 Zwei Fehler, die erst die Gates zeigten

- **Bremslicht in 150 m bei „Niedrig“** (`check_vehicle_lights` → `bremslicht` rot): „Niedrig“ ist die Voreinstellung
  für Software-Grafik und zeichnet das 3D-Bild mit 75 % (R1); R3s Prüfung lief ohne R1, also immer mit 100 %.
  Gemessen am selben Bild: 75 % Rot +0,07 in 150 m, 100 % +0,57, „Hoch“ +0,55 – die Leuchte fällt zwischen die
  Bildpunkte, der Lichtpunkt hatte die volle Stärke nur genau im Mittelpunkt. `flare.gdshader` hält die volle Stärke
  bis zu einer halben Bildpunkt-Diagonale des 3D-Bilds und behält den Radius: „Niedrig“ 50 / 150 / 300 m
  +0,60 / +0,16 / +0,33, 100 % +0,74 / +0,57 / +0,20, „Hoch“ +0,73 / +0,55 / +0,47 (gemessen). Bild
  `bremslicht_150m_niedrig_vorher_nachher.png`. Ehrlich: bei 75 % bleibt eine ferne Leuchte ein rötlicher Schein,
  nicht der klare rote Punkt von 100 %.
- **Kaltstart: 2 Shader-Varianten mitten in der Fahrt** (`warmup_cold.gd`, Kiel – Hamburg km 2, „Mittel“, 12 Uhr):
  376 Varianten vor dem Start, 2 nach 3,0 s. Eingegrenzt mit Mesas Quelltext-Ablage (`MESA_SHADER_DUMP_PATH`): kein
  neuer GLSL-Quelltext nach dem Ladebild, also Treiber-Varianten bekannter Programme; dieselben 2 auch ohne Verkehr
  (`--no-traffic`) und ohne HUD (`--no-hud`). Ursache: `props.gd warmup_nodes()` zeigte nur das erste Modell jeder
  Materialklasse, als MeshInstance3D. Jetzt jede Darstellung jedes geladenen Modells wie in `commit()` (MultiMesh,
  Schattenteile als Werfer): 389 Varianten vor dem Start, **0 während der Fahrt**, 48 statt 17 Aufwärm-Knoten; das
  Aufwärmen dauerte unter llvmpipe bei Last 7 rund 10 s länger (42 s statt 30–32 s).
