## 6. Gates am letzten Kopf (9b6adbc)

Alle Läufe mit eigenem absoluten `XDG_DATA_HOME` (unter `m1/RINT-B/xdg_*`), `nice -n 10`, ein schwerer Lauf zur Zeit.

| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, keine Zeile `ERROR`/`WARNING`, Baum unverändert |
| Tests (1) | `tools/run_tests.sh` (Stand 3d84e0b) | Exit 0 in 854 s: `692 Tests, 0 fehlgeschlagen`, alle `CHECK … OK` (u. a. `instanzen`, `ueberblendung`, `renderer_zeit` 0,726 ms, `kern_zeit` 0,247 ms, `leistung` 33,9 µs) |
| Tests (2) | `tools/run_tests.sh` (9b6adbc) | RUN2 |
| Golden | `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch (151 s)` |
| Render | `tools/run_render_checks.sh all` | `==> 16 von 16 Render-Prüfdateien in Ordnung` (Arcade: Glow 16 OK, Sprite-Flip; Modern: facade, instance_budget (neu), light_base, models, occlusion, props, quit_sound (neu), road_parity, seam, session_modern, showroom, terrain_cover, vehicle_lights, vehicle_standin) |
| modern_sight / path_check `--full` | – | nicht nötig: Kern (Streamer, Pfad) und Platzierung unverändert; geändert sind Shader, Ebenen, der Ladebalken |
| Modelle | `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (28 Modelle, 182 Sets; Netze 4,47 MB, Texturen 15,94 MB) |
| Export-Determinismus | `export_models.py --only=traffic/truck --force`, ebenso `traffic/sedan`, danach `bake_models.gd` | glb gleich (sha1 31ef148a…, 89308252…), Neubacken lässt den Baum unverändert |
| Sprite-Geometrie | `check_sprite_geometry.py --jobs 2` | `187 Sprite-Sets … 187 identisch (davon 1 mit anderer Flächenreihenfolge)`, `CHECK sprite_geometry OK` |
| ERGEBNIS Arcade = Modern | `tests/race/run_stage.gd --timescale=40` je Modus | kiel_hamburg, dev_testetappe (21 Uhr, Regen), saragossa_pau (Schnee): 28 Schlüssel, einziger Unterschied das Feld `gfx` (arcade/modern) – Fahrzeit, Tempo, Sprit, Strafen gleich |
| Modern-Autopilot Kiel–Hamburg unter Xvfb | `run_stage.gd --graphics=modern --timescale=4` (Xvfb, opengl3) | im Ziel, ERGEBNIS gleich dem headless-Lauf; 260 s Wand; perf_stats: Preset low, 96 Zeichenaufrufe, 85 820 Primitive, Bild median 86 ms (llvmpipe), render() 1,76 ms, Textur 154,6 MB, Fahrzeug-Instanzen 119 (Spitze 128 = Budget, 11 freigegeben), keine Ablehnung des Puffers |
| Texturspeicher | `probe/texmem_probe.gd` | Arcade 221,1 MB, Modern 166,8 MB (Grenze Arcade + 60 MB) |
| Linux-Build | `tools/build_linux.sh` | Exit 0; 440,6 MB, Archiv geschätzt 146,7 MB – „in Ordnung“ (Grenzen 300/330/350) |
| Windows-Build | `tools/build_windows.sh` | Exit 0; Zip gemessen 156,5 MB – „in Ordnung“ |
| Windows unter Wine | `wine64 CrossingEurope.exe -- --graphics=modern --bench=autobahn --bench-seconds=5` (eigenes Präfix, `dinput8=d`, ALSA-Null, `TMPDIR` leer, `wineserver -w`) | Modern-Etappe gefahren: kein `fallback`, 8,7 Bilder/s, 44 Bilder, Laden 5,41 s; Linux-Build ebenso: 10,3 Bilder/s |
| Leistungstest | `-- --graphics=modern --bench=all --bench-out=…` | `leistungstest.json` (user:// und `--bench-out`) mit perf_stats: Autobahn 11,0 / Stadt Nacht Regen 2,4 / Berg Tunnel 7,0 Bilder/s, script_ms 1,6–2,0, Laden 5,8–8,9 s; Urteil „zu langsam“, Vorschlag Arcade (llvmpipe) |

Hinweis: `script_ms` des Leistungstests (1,6–2,0 ms) ist Wanduhr unter Xvfb, die CPU teilt sich mit dem Software-
Rasterer; das Budget 1,5 ms (`renderer_zeit`) gilt headless auf das normale Tempo der VM umgerechnet (0,73–0,80 ms).

## 7. Dateien (eigene Änderungen seit b473e90)

Shader: `assets/shaders/modern/{far_ground,road,terrain,vpbr}.gdshader`, `inc/ground.gdshaderinc`,
`inc/ground_law.gdshaderinc` (neu). Skripte: `scripts/race3d/{environment_rig,modern_materials,modern_renderer}.gd`,
`scripts/race3d/layers/{backdrop,far_ground,flares,vehicles}.gd`, `scripts/ui/game_flow.gd`,
`scripts/ui/widgets/showroom_3d.gd`. Modelle: `assets/models/traffic/truck/*` (Kanal 15), `assets/models/manifest.json`;
`tools/blender/ce3d/{roles,truck3d}.py`, `tools/blender/validate_models.py`. Prüfungen:
`tests/race3d/check_{vehicles,modern_stage}.gd`, `tests/race3d/fixtures/perf_clock.gd` (neu),
`tests/race3d/render/check_{quit_sound,instance_budget}.gd` (neu), `tools/run_render_checks.sh`,
`tools/models/contact_sheet.gd`. Bild: `assets/ui/gfx_preview_modern.webp` (vorher ein Platzhalter von 1 KB). Doku:
`docs/renderer-modern.md` (§11.1/11.7/11.8, neuer §13), `docs/modelle.md`, `ARCHITECTURE.md` §15. Keine eingefrorene
Arcade-Datei geändert (geprüft: `git diff fd27c16..HEAD` über die Liste von Regel 1 ist leer).

## 8. Commits (Zweig `worktree-wf_ae4df3ba-14f-1`, gesichert auf `wip/v080-rint-b`)

dfc99b6 R3E, 94ce4a2 AS1R, b473e90 AU-D1 (Zusammenführungen) · f198858 Nachbearbeitung exakt, Bodengesetz, Horizont,
Laternenschein, Lack, Zeitprüfungen · 9eac32f Überblendung, Rückstrahler, Nachtlack, Showroom-Look · a8abb01
Instanzbudget · 3d84e0b Ladebalken, Showroom-A/B · 8f58b2d Doku §13 · 9b6adbc Vorschaubild Modern.

## 9. Für die Nächsten

- Start- und Zieltor, Tankstellendach, Brückengeländer, Felsbrocken und Sonnenscheibe fehlen in Modern (Abschnitt 5).
- Das erste Laden der Startansicht ist ein Bild von 1,6–1,9 s (`ChunkStreamer.update` lädt beim ersten Aufruf alles):
  hinter dem Ladebild über mehrere Bilder verteilen, mit Fortschritt je Stück.
- `INSTANCE_BUDGET` 128 setzt voraus, dass der Rest der Szene unter ~120 Instanzen mit `instance uniform` bleibt (gemessen
  34–72, Aufwärmen bis 135): neue Shader mit Instanz-Uniforms (Requisiten, M2) müssen in dieses Budget passen –
  `check_instance_budget.gd` schlägt sonst an.
- Lack nachts (Limousine +32 %) und in der Dämmerung mit der Sonne voraus (Kompakt −16 %), Abblendlicht auf der
  Fahrbahn 9–38 % heller als Arcade: Kandidaten für den nächsten Look-Durchgang.
- Showroom: erst bei einem Echtzeitbild, das mit dem Sprite mithält, `showroom: true` setzen (Kontaktbogen mit
  `--showroom` zeigt jetzt den echten Look).
