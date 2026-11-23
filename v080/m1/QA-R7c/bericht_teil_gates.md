## 3. Gates und Funktion (alles gemessen auf dieser VM, Stand `bd1803b`, Logs in `m1/QA-R7c/gates/`, `scan/`, `mutlogs/`)

| Prüfung | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import .` | Exit 0, keine Fehlerzeile (nur der Dateiname `ui_error.wav`) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | Exit 0 (9 s) |
| Tests (einmal voll, von höchstens 2) | `tools/run_tests.sh` | Exit 0 – **808 Tests, 0 fehlgeschlagen**, alle CHECK-Dateien OK, „Tests bestanden (983 s)“ |
| Render-Prüfungen | `tools/run_render_checks.sh all` | Exit 0 – **29 von 29 Render-Prüfdateien in Ordnung** (3873 s), darunter `check_start_km0`, `check_terrain_cover` (K1), `check_light_base`, `check_lod_band` (Barockhaus hart 7,1 % → Band 0,6 %, Eiche 36,6 % → 1,1 %, Deckung −0,0 %), `check_instance_budget*` (höchstens 141 / 171 / 216 Instanzen mit Instanz-Uniforms, Grenze 230) |
| Sicht F1–F3, F7, Modell | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | Exit 0 (137 s): F1 0 Fälle bis 270 m in 99 424 500 Stichproben (128 Etappen), F1 Spuren 0 bis 260 m, F2 höchstens 0,593 / 0,596 / 0,555, F3 0 von 5923 Zielen später als Arcade, F7 0 von 2 011 532 Querschnittsseiten, Modell 0 abweichend |
| Wege | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` | Exit 0 (55 s): kleinster Abstand 267,6 m, Schleifen OK |
| Arcade-Identität | `tools/golden.sh check` (einmal, am Ende) | siehe Abschnitt 3.5 |
| Modelle | `python3 tools/blender/validate_models.py --no-godot` | 110 Modelle, 183 Sets, Manifest = Fragmente (kein Fehler; Netze nur über `check_models` in den Tests dekodiert: OK) |
| Zusammenbau-Probe | `git merge-tree --write-tree bd1803b <zweig>` | mit `wip/v080-r7a` (509bb16), `wip/v080-r7b` (2c154bc), `wip/v080-fix-r7b` (818150b) ohne Konflikt; mit `wip/v080-fix-rint` (3248211) **ein Konflikt in `tests/unit/race3d/test_props.gd`**; `modern_materials.gd` ändern beide, Git mischt es selbst |

### 3.1 Besitz der Dateien (Regel 1 und 7)

`git diff 9b02f05..bd1803b --stat`: 131 Dateien. Davon bringt die verlangte Mischung von `wip/v080-as5ar2` (43a1fcc)
die Modelle, `tools/blender/*`, `docs/modelle.md` und `assets/models/manifest.json` (neu erzeugt, nicht von Hand). R7c
selbst (`git diff 43a1fcc..bd1803b --stat`, 17 Dateien): `builders/props.gd`, `prop_library.gd`, `model_factory.gd`,
`modern_materials.gd`, `baked/billboard/leaves.gdshader`, neu `inc/lod_band.gdshaderinc`, `config/game_config.json`
(nur `graphics.modern.props` und der `_doc`-Text, kein `landmark_*`), `docs/renderer-modern-gelaende.md`, Tests
(`test_props.gd`, neu `check_lod_band.gd`, `check_props_render.gd`) und `tests/golden/modern_slice.*` (Brief gegen A-18,
gemeldet). **Keine eingefrorene Arcade-Datei** (`scripts/race/…`, `scripts/gameplay/`, `scripts/data/`, Audio, Sprites,
`data/`: 0 Treffer). Die Korridor-Semantik von `ChunkContext` (R7a) und der Wahrzeichen-Block (R7b) sind unberührt;
`environment_rig.gd` (angebotene Ausnahme) nicht benutzt.

### 3.2 Funktion im ganzen Netz (Datenscan, gemessen)

Eigene Probe `m1/QA-R7c/probe/scan_r7c.gd`: echte Stück-Bauten von `props.gd` + `city.gd` über den ausgelieferten
`ChunkStreamer` (sync), **alle 128 Richtungen + DEV**, in drei Bäumen:

| Baum | gezeichnete Requisiten | im Korridor weggelassen | Band / Laufzeit |
|---|---|---|---|
| R7c `bd1803b` | 195 741 | 35 492 | 156 s |
| `43a1fcc` (Basis + AS5aR2, vor R7c) | 195 741 | 35 492 | 136 s |
| Basis `9b02f05` | 195 739 | 35 494 | 134 s |

- R7c gegen `43a1fcc`: die sortierten Listen (Strecke, Segment, Nummer, Set, x, z, Maßstab, Spiegelung) sind
  **identisch (0 Zeilen Unterschied)** – die Stufen, Bänder, Tags und Phasen nehmen nichts weg und stellen nichts um.
  Gegen die Basis 9b02f05 unterscheiden sich 3950 Zeilen nur in x um 0,04 m (Kantenmaß der AS5aR2-Modelle) und
  zwei Stadthäuser (Amsterdam – Lüttich Segment 7414, Pau – Toulouse 6334) stehen jetzt, die vorher im Korridor
  wegfielen – das ist die Mischung (neue Kantenmaße), nicht R7c.
- Jede gebaute Modell-MultiMesh trägt ein Band (241 150 Knoten, 0 mit verdrehtem Band), jede der 602 113 geprüften
  Instanzen hat Custom-a in [1, 2) (Tönungsschalter + Phase); 46 041 Schattenwerfer-Knoten.
- Bänder aller **77 Requisiten-/Wahrzeichen-Modelle** des Manifests bei „Details“ Niedrig/Mittel/Hoch
  (`probe/bands_all.gd`, 231 Fälle): die Rasteranteile der Darstellungen ergeben an jeder Entfernung 0–4000 m genau 1
  (kein Loch, nichts doppelt), die letzte Darstellung reicht bis „endlos“. Mittel: Stadthäuser lod0 31–39 m,
  Fachwerk/Paris 26–34 m, übrige Gebäude, Büsche, Kirche 53–67 m, Bäume 53–67 / 176–224 m, einstufige Modelle immer.
- `ground_sink`: 3355 Felsen/Klippen im Netz, tiefste Absenkung 0,33 m = höchstens 10 % ihrer Höhe – nichts
  verschwindet im Boden.
- Anbauten (`attach`): kein ausgeliefertes Modell nutzt sie (0 im ganzen Netz).
