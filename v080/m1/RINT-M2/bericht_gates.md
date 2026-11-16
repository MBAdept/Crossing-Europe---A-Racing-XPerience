
## 4. Tore (Befehle und Ausgaben)

Läufe über `sh/gates.sh <Schritt>` (Kopie von M2INTs Skript: eigenes absolutes `XDG_DATA_HOME` je Schritt,
`nice -n 10`, `LP_NUM_THREADS=2`, ein schwerer Lauf zur Zeit über die Warteschlange). Neben dieser Montage lief auf
der Maschine das Paket AS5a2 (nice 19) – Zeiten und Höchstwerte sind davon beeinflusst.

| Tor | Befehl | Stand | Ergebnis |
|---|---|---|---|
| Import | `godot --headless --path . --import` | `1cd689d` | Exit 0, 0 Fehlerzeilen (14 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | `1cd689d` | „330 Skripte geprüft, 0 fehlerhaft“ |
| Tests Lauf 1 | `tools/run_tests.sh` | `1cd689d` | **802 Tests, 0 fehlgeschlagen**; 150 CHECK-Zeilen OK, 0 FEHLER (1008 s) |
| Tests Lauf 2 | `tools/run_tests.sh` | @@T2STAND@@ | @@T2@@ |
| Arcade-Goldens (einmal) | `tools/golden.sh check` | `1cd689d` | **GOLDEN arcade: 20 von 20 identisch**, **arcade-ui: 17 von 17 identisch** |
| Modern-Melder ansehen | `KEEP=… tools/golden.sh modern-check` | `1cd689d` | 0 von 6 identisch (erwartet nach den Merges); alle sechs angesehen (`bilder/goldens_modern_sechs.jpg`); `modern-gles` OK (2/255, 73,2 dB) |
| Modern-Melder neu | `tools/golden.sh modern-make` | `c72d484` | MD5 gleich den behaltenen Bildern von `1cd689d`; Commit `6b17293` |
| Modern-Melder prüfen | `tools/golden.sh modern-check` | `6b17293` | **GOLDEN modern: 6 von 6 identisch**, **modern-gles OK** (max. 2/255, PSNR 73,2 dB) |
| Render-Prüfungen | `tools/run_render_checks.sh all` | `b673df5` | **27 von 28 Dateien OK**; rot nur `check_props_render` „props_spiegel“ – die Prüfung erwartete das Einfamilienhaus noch als Ersatzbild (seit AS5a ein Modell); angepasst, einzeln: `props_spiegel` OK, `rotor` OK (`ab2a400`); die Strukturprüfung (`countdown`, `zieltor`, `grenze`, `blitz`) auf dem Endstand `02051f7` erneut OK |
| Sicht | `modern_sight.gd --full`, `modern_path_check.gd --full` | `b673df5` | **6 von 6 OK** (`f1` 0 Fälle bis 270 m in 99,4 Mio. Stichproben, `f1_lanes`, `f2` ≤ 0,596, `f3` 0 von 5923, `f7`, `model`); Pfad **2 von 2 OK** (Abstand ≥ 267,6 m, Schleifen ≥ 2064 m) |
| ERGEBNIS Arcade = Modern | `run_stage.gd` (Zeitraffer 40) | `b673df5` | **Kiel – Hamburg, Testetappe, Saragossa – Pau: je 28 Schlüssel identisch (außer gfx)** |
| Texturspeicher | `probe/texmem_probe.gd` (20 s Fahrt) | `b673df5` | Arcade 201,7 / 200,6 MB, Modern **109,2 / 110,8 MB** (Kiel – Hamburg / Dortmund – Frankfurt; Spitze 109,2 / 110,8) |
| Prüfer, Schlüssel, Sprites, Klang | `validate_models.py --report`, `export_models.py --check-keys`, `check_sprite_geometry.py`, `audio_qc.py` | @@VSTAND@@ | @@VAL@@ |
| Export-Determinismus | zwei AS5a-Modelle zweimal `--force` exportiert und gebacken | @@VSTAND@@ | @@DET@@ |
| Leistung neben `515dd51` | `run_stage.gd` unter Xvfb, Zeitraffer 40 | @@VSTAND@@ | §4.1 |
| Builds | `tools/build_linux.sh`, `tools/build_windows.sh`, `pck_report.py` | @@VSTAND@@ | @@BUILD@@ |
| Rauchtest | `tools/smoke_modern.sh` (Linux, GLES, Windows unter wine64) | @@VSTAND@@ | @@SMOKE@@ |

Ausgewählte Zeilen der Render-Prüfungen (`b673df5`):
- `abblendlicht` OK – roter Lkw 22 Uhr, 20 m: 0,5 % weiß, Mittel 0,24; 60 m: 0,0 %, 0,17.
- `bremsschein` OK – 12 Uhr Sportwagen 60 m Rot 33,1; 22 Uhr Sportwagen 60 m Rot 28,3, Limousine 20 m Rot 436,1.
- `blaulicht` OK – Polizei (Modell) 60 m: 12 Uhr 309, 22 Uhr 1157 Pixel deutlich blauer.
- `nass_kegel` OK – N2 22 Uhr Regen, eigene Spur 16–34 m: Modern 0,219, Arcade 0,250 (0,88×), Randlinie 1,19×;
  `spiegelung` OK (0 Pixel über dem Dach); `laternen` OK (Profil bis 15,84 m, 4 von 160 gerechnet).
- `tunnel_bridge_U1_ausfahrt` OK – Ausfahrt 0,584 = 0,66 × Arcade (verlangt 0,6), 0,0 % reines Weiß, Rahmen 0,501.
- `instanzen` 141 / `instanzen_wald` 216 / `instanzen_stadt` 171 von 230, keine Ablehnung.
- `spielerauto` OK – Sättigung Kompakt N1 1,23×, Gran Turismo N2 0,77×, Limousine S1 0,95× (Notiz 10).
- `tankstelle` OK – 21 Uhr Tankspur Modern 0,406, Arcade 0,459; `grenze` OK.
