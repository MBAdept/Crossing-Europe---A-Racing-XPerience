## 2. Funktion im ganzen Netz

Datenscan `m1/QA-R4/sh/scan_data.gd` (kopflos, gemessen, 57 s), alle 64 Etappen des Netzes (ohne Dev-Etappen):
- **Schneewälle**: je Etappe drei Kamerafenster (bei ¼, ½, ¾ der Strecke), jedes Stück, das der Streamer dort will, mit
  dem Terrain-Builder und Schnee gebaut – **2.517 Stücke, 2.331 mit Wall, 884.292 Walldreiecke, 0 Fehler**, höchster
  Wall 0,351 m (Grenze 0,45 m), keine Wall-Reihe in Tunnel, Wasser oder Stadt.
- **Tunnelausfahrt**: alle 26 Tunnel (13 Tunnel × 2 Richtungen) – `EnvironmentRig.exit_ahead()` erkennt jede Ausfahrt
  5 m vor dem Portal (0 Fehler); **keine** zwei Tunnel liegen weniger als 60 m (`EXIT_AFTER_M`) auseinander, das
  Nachglühen kann also nie in die nächste Röhre fallen.
- Niederschlag, Gischt, Spiegelungen, Blaulicht und Nachtgesetz sind etappenunabhängig (Wetter je Start, Fahrzeuge der
  Ansicht, Lampen über `add_lamps()`); `check_light_cap` „deckel“ (im Vollauf, gemessen) fuhr drei Nachtetappen
  (N1 197 Proben, Kiel – Hamburg ab km 76 206 Proben, C1 Regen) mit höchstens 8 Punktlichtern / 2 Spots / 18 Kegeln.
- **Schnittstellen**: `set_zone(kind, amount)` ist wie dokumentiert (`docs/renderer-modern.md` §15.1) und passt zu R5:
  `origin/wip/v080-r5` `builders/tunnel.gd` ruft `env.call("set_zone", "tunnel", amount)` duck-typed nur bei Änderung –
  der Wert hält bis zum nächsten Aufruf, also richtig. `add_lamps()` und seine Rollen sind unverändert (R6, R5 nutzen
  sie; Tunnellampen mit `range` 0 zählen nicht zum Pool – R4 hat das gemeldet). Probe-Zusammenführung mit
  `git merge-tree`: R4 + FIX-M2 nur Konflikte in `tests/golden/modern_slice.{md5,env}` (Code von `lights.gd`,
  `vehicles.gd`, `modern_materials.gd` mischt sich automatisch); R4 + R5 `docs/renderer-modern.md` und `modern_slice.md5`;
  R4 + R6 nur die Modern-Hashes.

## 3. Fairness (gemessen)

- `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` (207 s): **F1** 0 Fälle bis 270 m in
  99.424.500 Stichproben (128 Etappenrichtungen), **F1 Außenspuren** 0 bis 260 m, **F2** höchstens 0,593 trocken /
  0,596 Regen / 0,555 Schnee (≤ 0,60), **F3** 0 von 5.923 Zielen später, **F7** 0 von 2.011.532 Querschnittsseiten,
  Modell 0 abweichend.
- `modern_path_check.gd -- --full` (87 s): kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2.064 m (≥ 2.000).
- **F4/F5/F6** (Render, gemessen): `check_vehicle_lights` 4/4 OK – Rücklicht bei 0,839 × Sicht an N1 (Schnee, 22 Uhr,
  Sichtweite 338 m, Auto bei 283 m) hebt das Bild um 0,090 Leuchtdichte / 0,239 Rot (Schwellen 0,02 / 0,10), Blinker bei
  300 m, Sichtgrenze 0,00 %. `check_night` „verdeckung“: Kuppe und Sattelzug verdecken Auto, Lichtpunkt **und**
  Spiegelung (0 Pixel). R4 berührt `tests/sim/modern_*` und den Kern nicht; Kamera und Gelände unverändert.
- Fairness-Risiko aus B1/B2 (abgeleitet): die schwebende Spiegelung zeigt ein Auto hinter einer Steigung nicht früher
  als Arcade (das Auto selbst ist sichtbar), aber sie ist ein falsches Signal über dem Horizont; der halbierte
  Markierungskontrast im Kegel (B2) betrifft etwas, worauf der Spieler reagiert (Regel 9 sinngemäß).

## 4. Arcade-Gleichheit und Dateibesitz

- `tools/golden.sh check` (einmal, am Ende): @@GOLDEN@@
- `git diff 6e48405..7f0eae2 --stat`: 42 Dateien, +3.219 / −48. Kein eingefrorener Arcade-Pfad (`scripts/race/*`,
  `scripts/gameplay`, `scripts/data`, `data/**`, Sprites, Arcade-Audio). Alle Code-Dateien gehören R4 in W3
  (`environment_rig.gd`, `modern_renderer.gd`, `prewarm.gd`, `layers/{lights,backdrop,vehicles,flares}.gd`,
  `builders/terrain.gd`, `modern_materials.gd`, Shader road/vpbr/glass/baked/leaves/billboard) oder sind neue Dateien
  des Pakets (`layers/weather.gd`, `particles_rain/snow`, `spray`, Tests). `race_session.gd`, `race_renderers.gd`,
  `config/game_config.json` unverändert.
- Abweichungen: `assets/shaders/modern/flare.gdshader` hat in W3 keinen Besitzer (W1: R3) – R4 hat es als Vertragsfrage
  gemeldet, sinnvoll beim Besitzer von `flares.gd`. `tests/golden/modern_slice.{md5,env}` hat in W3 keinen Besitzer
  (§5: „–“); R4, R5, R6 und FIX-M2 haben sie alle neu erzeugt → bei RINT-M2 nach dem Zusammenführen einmal
  `golden.sh modern-make` statt Handmischen. Neue Testdateien (`tests/race3d/check_light_cap.gd`,
  `check_weather_tabelle*.gd`, `tests/unit/race3d/test_weather.gd`) liegen in Modern-Testordnern – zulässig.

## 5. Tests, Render-Prüfungen und Mutationen

**`tools/run_tests.sh`** (Vollauf 1 von 2 erlaubten, 1.319 s, gemessen): 762 Einheitstests, **2 rot**, alle CHECK-Dateien
grün (u. a. `check_light_cap`, `check_modern_stage` mit `kern_zeit` 0,389 ms, Sicht, Weg, `check_terrain_plan`):
- `test_engine3_checks` „thread“ (Audio, 15 Aussetzer bei 6 Hängern des Hauptthreads – Last; R4 berührt kein Audio).
- `test_chunk_services` „threaded“: `commit()` 23 statt 25 – ein Wettlauf im Kern-Test, nicht R4: einzeln wiederholt
  Kopf 1 von 2 und 0 von 6 rot, **Basis 1 von 6 rot** (gemessen).
- Die geschützten Tests des ersten Testbuilds sind grün: `test_far_ground_water` 4/4, `test_props` 12/12.

**Render-Prüfungen** (`tools/run_render_checks.sh modern <Datei>`, je Datei, gemeinsamer Mesa-Cache, gemessen):

| Datei | Ergebnis |
|---|---|
| `check_night.gd` | 4/4 OK (344 s): Fahrbahn N1 +4,9 % (Mittel und Steam Deck), Spielerauto 1,04/0,93/… Sättigung 0,95/0,73/0,91, Verdeckung 0 Pixel, Blaulicht 7.848 blauer |
| `check_weather.gd` | 5/5 OK (472 s): Teilchen 7.343/20.021/45.417 Bildpunkte Regen, Gischt 1 bzw. 3 Wolken, nass, Tunnel aus, Schneewall 0,35 m |
| `check_vehicle_lights.gd` | 4/4 OK (90 s), F6 an N1 |
| `check_start_km0.gd` | 3/3 OK (258 s) – Fix des ersten Testbuilds hält |
| `check_light_base.gd` | 2/2 OK (142 s) – Tageslicht −6,6 % Asphalt, Schatten ±0,09 % |
| `check_terrain_cover.gd` | 7/7 OK (78 s) inkl. **K1** 0,000 % Magenta |
@@RCREST@@

Die Zahlen von `check_night` und `check_weather` stimmen auf die Stelle mit R4s Bericht überein (bestimmte Bilder).

**Mutationen** (`m1/QA-R4/sh/mutate.py`: eine Zeile je Regel in einer Kopie des Kopfes gebrochen, der zuständige Test
gefahren, Datei zurückgesetzt; gemessen):

| Nr. | Regel | gebrochen | Ergebnis |
|---|---|---|---|
| U1 | jede Effekte-Stufe ≥ Arcades Dichte | `RAIN_BOX[0]` 24 × 70 m statt 14 × 45 m | **erkannt** (`test_weather`) |
| U2 | Aufwärm-Ebene ohne echte Lichter | `LIGHT_MASK` ohne `~(1 << 19)` | **erkannt** (`test_light_pool`, 2 Tests) |
| U3 | `set_zone("tunnel")` ersetzt `tunnel_blend` | Zweig `if _zones.has("tunnel")` tot | **erkannt** (`test_set_zone`) |
| U4 | Nachtgesetz Mond ≥ 55° | `MOON_MIN_ELEV_DEG` 15 | **erkannt** (`test_night_moon_and_floor`) |
| U5 | Nachglühen klingt über 60 m stetig ab | Abklingweg × 10 (Sprung von 0,39 auf 0 bei 60 m) | **nicht erkannt** (`test_exit_ramp` prüft nur „bei 60 m vorbei“ und „fällt“) |
| U6 | Blaulicht leuchtet nur nachts | Schwelle `lights <= 0.04` aus | **erkannt** (`test_beacon_of`) |
| U7 | Gischt auch bei „Effekte: Aus“ | eine Wolke → keine | **erkannt** (`test_spray_puffs`) |
| U8 | Schneewall ≤ 0,45 m | `BANK_MAX_M` 0,95 | nicht erkannt von den Einheitstests (keiner prüft die Höhe; nur die Render-Prüfung, s. R4) |
@@MUTREST@@
