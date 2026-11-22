# QA-RINT-SYSTEM – unabhängige Prüfung der zweiten Montage von M2 (`9b02f05`, `wip/v080-rint-m2`)

Blickwinkel: Arcade-Gleichheit, Budgets, Robustheit, Builds. Keine Commits, kein Push. Arbeitsbaum
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3` (vorgespult auf `9b02f05`,
sauber), Kopie für Mutationen `…/m1/QA-RINT-SYSTEM/mut` (Stand `9b02f05`, nach jeder Mutation zurückgesetzt), v0.7.0
(= `main` = Tag `v0.7.0`, `e3505e2`) als `git archive` in `…/m1/QA-RINT-SYSTEM/v070` (beide Kopien nach der Prüfung
gelöscht).

Alle Spielläufe mit eigenem absolutem `XDG_DATA_HOME` unter `…/m1/QA-RINT-SYSTEM/xdg/<lauf>` (die Werkzeuge
`golden.sh`/`smoke_modern.sh` legen ihr eigenes leeres an, siehe 8) und ausdrücklichem `--graphics=…`. Maschine: llvmpipe (keine GPU), 4 Kerne, **Last 10–15** durch andere Pakete während der ganzen
Prüfung (gemessen mit `uptime`) – alle Zeit-**Höchstwerte** sind dadurch unzuverlässig (siehe 4.3). Alles über Steam
Deck, echte GPU und Windows-Grafik ist **gefolgert**, nicht gemessen.

Dieser Lauf ist die Fortsetzung eines abgebrochenen Vorgängers (Container-Neustart); dessen Ergebnisse (Testlauf 1,
Etappen-Vergleiche, Einheitsmutationen) habe ich übernommen und, wo nötig, nachgeprüft (siehe Ende von 3.2: eine seiner
Mutationen war fehlerhaft).

## 1. Ergebnis in Kürze

**Urteil: Die Montage `9b02f05` hält alle harten Tore meines Blickwinkels; kein Blocker, kein „high“.** Gegen die
Montage-Meldung habe ich nichts Falsches gefunden – bis auf eine Lücke in der Wächterkraft der Tests und ein Budget,
das seit der Basis nicht erreicht wird.

- **Arcade = v0.7.0**: eingefrorene Dateien unverändert; `golden.sh check` 20/20 + 17/17; ERGEBNIS **und jede
  Verkehrssekunde** bitgleich zu v0.7.0 auf vier Etappenläufen (mit Tankstopp, Grenze, Tunnel, Blitzer, Polizei,
  Regen, Schnee, Nacht); Arcade-Klang byte-gleich (Tests).
- **Regel 3**: Modern = Arcade auf denselben Läufen – kopflos **und** mit echtem Zeichnen unter Xvfb.
- **Tests**: 803/0, Render-Prüfungen 28/28. Von neun Regel-Mutationen werden acht rot; **die Tönung der Modelle
  (A-19) ist für `baked`/`leaves`/`billboard` ungeschützt** (B-02).
- **Budgets**: Instanz-Zensus echt (Mutation → 306 > 230, 144 Ablehnungen), Wald 216/230; Texturspeicher Modern 144,5 <
  Arcade 197,9 MB; Export 191,3 / 200,9 MB (≤ 277). **Einhängen eines Stücks in jeder Messung über 3 ms** (5,2–9,0 ms;
  seit der Basis, B-01); `collect()` der Tankstelle ohne Reserve (B-03). Höchstwerte auf dieser VM (Last 10–15) sind
  verrauscht.
- **Robustheit**: Rückfälle (`--gfx-debug=fail`, Manifest fehlt/kaputt) richtig; Leistungstest-Datei gültig; Wächter
  stuft bei Regen und Schnee herab – nur nicht bei Bildern > 1 s (B-04); Beenden/Neustart in 14 Lagen sauber;
  2 × 20 min Modern ohne Fehlerzeile; Testbuild Linux, GLES und Windows (Wine) starten beide Modi.
- Nebenbefund: Paket **R7a** schreibt seit heute früh in den echten Benutzerordner (B-07, nicht diese Montage).

## 2. Arcade-Gleichheit und Regel 3

### 2.1 Eingefrorene Dateien (Regel 1)
`sh/frozen.sh`: `git diff --stat main HEAD -- <Liste aus §2 Regel 1>` **leer**, ebenso gegen die Basis `515dd51`;
Arbeitsbaum ohne Änderung; 462 Dateien in beiden Ständen (gemessen, `out/frozen.txt`).

### 2.2 ERGEBNIS und Verkehr Arcade v0.7.0 gegen Kopf (`run_stage.gd` + Sekunden-Hash)
`sh/stage_hash.gd` = `run_stage.gd` plus je Simulationssekunde ein Hash aus Spielerzustand und **jedem Verkehrsauto**
(id, z, x, Tempo, Spur, Bremse; Bits exakt) und ein SHA-256 über alle Sekunden. Kopflos, Zeitraffer 40.

| Etappe (Uhr, Wetter, Seed, Tanken) | v0.7.0 Arcade | Kopf Arcade | Kopf Modern (kopflos) | Kopf Modern unter Xvfb, „Steam Deck“ |
|---|---|---|---|---|
| Kiel – Hamburg (12, trocken, 7, auto) | 347 Hashes | **gleich** (27/27 Schlüssel) | **gleich** | **gleich** (347/347, Zeitraffer 16) |
| Testetappe (22, Regen, 11, immer) | 395 | **gleich** | **gleich** | – |
| Bern – Mailand (15, Schnee, 3, auto) | 1355 | **gleich** | **gleich** | – |
| Testetappe (14, trocken, 5, immer, **Raser-Autopilot**) – Tankstellen 2×, Grenze km 65, Tunnel km 50, **Blitzer km 12 ausgelöst, Polizei 1×** | 510 | **gleich** | **gleich** | **gleich** (510/510, Zeitraffer 16) |

Alle gemessen (`out/stages/*.log`, `out/cmp_arcade_v070.txt`, `out/stages_queue*.log`, `out/q/x_dev.log`,
`out/q/x_kh.log`). Regel 3 gilt damit auch mit **echtem Zeichnen** (Xvfb, Modern-Renderer mit allen Bausteinen, nicht
nur kopflos): ERGEBNIS bis auf `gfx` gleich und jede Sekunde des Verkehrs bitgleich.
Hinweis: Bern – Mailand mit `--autopilot-refuel=always` bleibt in **v0.7.0 und im Kopf gleich** bei km 160,5 stehen
(Autopilot, eingefroren) – darum dort `auto`.

### 2.3 Goldens
- `tools/golden.sh check` einmal am Ende auf dem sauberen Kopf (gemessen): **GOLDEN arcade: 20 von 20 identisch**
  (239 s), **GOLDEN arcade-ui: 17 von 17 identisch** (397 s), Exit 0 (`out/q/golden_check.log`). Die Hash-Listen sind
  seit ihrer Erzeugung aus dem Tag v0.7.0 unverändert (Vorgänger, `git log` der drei Dateien).
- Empfindlichkeit (Mutation in der Kopie): ein LSB im Blau von `Palette.ROAD` → `race_s1` **0 von 1**; `ROAD_CITY`
  +9 → `hamburg` **0 von 2** – die Prüfung erkennt kleinste Arcade-Änderungen.
- Modern-Melder `tools/golden.sh modern-check` auf dem Kopf (gemessen): **GOLDEN modern: 6 von 6 identisch**,
  **modern-gles OK** (`modern_s3_hoch` OpenGL ES gegen OpenGL: max. 2/255, PSNR 73,2 dB) (`out/q/golden_modern.log`).

### 2.4 Vertrag §11.3
Der Abschnitt in `docs/dev/v080_contract.md` ist **zeichengleich** mit `…/m1/lead/contract_11_3.md` (5 960 Zeichen,
gemessen); `git diff 515dd51 HEAD -- docs/dev/v080_contract.md` fügt nur 70 Zeilen am Ende an, keine Zeile davor
geändert.

## 3. Tests und ihre Wächterkraft

### 3.1 Läufe
- `tools/run_tests.sh` (Vorgänger, auf `9b02f05`, eigener XDG): **803 Tests, 0 fehlgeschlagen**, alle CHECK-Dateien OK,
  1154 s, Exit 0 (`out/tests1.log`). Ein zweiter Volllauf war nicht nötig (kein Code geändert).
- `tools/run_render_checks.sh all` auf `9b02f05`: **28 von 28 Render-Prüfdateien in Ordnung**, Exit 0 (2 Arcade-Dateien: 16 GLOW-CHECK + FLIP-CHECK OK; 26 Modern-Dateien, u. a. `instanzen*`, `abblendlicht`, `bremsschein`, `nass_kegel`, `spiegelung`, `tankstelle`, `grenze`, `blitz`, `tunnel_bridge_*`, `arcade_gleich`, `rueckfall`, `pause`, `quit_*`; `out/rc_full.log`). Unter Last liefen einzelne Dateien bis 714 s, keine lief in ihr Zeitlimit.

### 3.2 Mutationen (je eine Zeile in der Kopie `mut`, danach zurückgesetzt)

| Regel | Mutation | Erwartet | Ergebnis |
|---|---|---|---|
| A-19 Zensus lädt das Budget | `ModernMaterials.class_for`: nie `VPBR_STATIC` (alle Modelle mit Instanz-Uniforms) | `instanzen_wald` rot | **rot**: 144 Ablehnungen der Engine, Szene 306 > 230 (`out/rmut/static.log`) – Prüfung echt |
| A-20 Fahrzeuge blenden nicht aus | `eye_lamp_spec` 0 → 1 (Rennlook) | `abblendlicht` rot | **rot**: 20 m 11,8 % weiß, 60 m 36,1 % (`out/rmut/eyespec.log`) |
| A-20 Fahrbahn behält das Abblendlicht | `road.gdshader`: `ce_headlight_light` aus der Fahrbahn genommen | `nass_kegel` rot | **rot**: Fahrbahn 0,088 gegen Arcade 0,250 (0,35×, verlangt ≥ 0,7×), Randlinie 0,79× (`out/rmut/roadlight_nass.log`) |
| A-20 (Konstante) | `SPOT_SPECULAR` 0,5 → 0 | – | `vehicle_lights` und `night_nass` **grün, nass_kegel bitgleich 0,219** – die Konstante wirkt auf nichts Geprüftes (bestätigt RINTs Vertragsfrage) |
| A-20 Nachtschein ≤ Arcade + 10 % | `MODEL_BRAKE_NIGHT_NEAR/FAR` → 1,0 | rot | **rot**: Einheit `test_model_glow_gain` und Render `bremsschein` (68,9 > 57) |
| A-19 Tönung der Modelle | `vpbr`: `alb *= v_tint` entfernt | rot | **rot**: `test_props` („vpbr_static multipliert die Albedo“) |
| A-19 Tönung der Modelle | `baked` (und `leaves`): Multiplikation mit `v_tint` entfernt | rot | **grün** in `test_props`, `check_props_render`, `check_models`, `check_facade_render` – **nur der Modern-Golden** `modern_s4_mittel` weicht ab → Befund B-02 |
| A-18 Spieltafel-Regel | Verdeckungsentscheid der Endstütze (`…hides()`) wirkungslos gemacht (Vorgänger) | rot | **rot**: `test_structures` 2 Tests (`out/mut_a18.log`) |
| Regel 2 Goldens | `Palette.ROAD` um 1 LSB | rot | **rot**: `race_s1` 0 von 1 identisch; `Palette.ROAD_CITY` +9 im Blau: `hamburg` 0 von 2 (`out/q/gmut2_*.log`). Erster Versuch mit `ROAD` auf `hamburg` blieb 2/2 gleich – dort fährt man auf Stadtstraße (`ROAD_CITY`), meine Mutation traf das Bild nicht (kein Mangel des Werkzeugs) |
| Modern-Golden | `baked` ohne Tönung | rot | **rot**: 5 von 6, `modern_s4_mittel` ANDERS (`out/q/gmut_modern.log`) |

Korrektur zum Vorgänger: seine Tönungs-Mutation kommentierte die Zeile nur aus (`// alb *= v_tint;`) – der Test sucht
den Text `alb *= v_tint` und fand ihn im Kommentar; daraus folgte fälschlich „ungeschützt“ auch für `vpbr`. Mit
gelöschter Multiplikation ist `vpbr` geschützt, `baked`/`leaves`/`billboard` nicht.

## 4. Budgets

### 4.1 Instanz-Uniforms (A-19)
Render-Prüfungen auf `9b02f05` (gemessen): `instanzen` (Kiel – Hamburg, echter Verkehr) Szene 141, Ebene 128/128;
`instanzen_stadt` (48 eingespeiste Autos) Szene 171, Ebene **176**; `instanzen_wald` Szene **216** von 230, Ebene 208;
keine Ablehnung der Engine. Die Prüfung lädt das Budget wirklich (Mutation oben). Auffällig: in `instanzen_stadt` ist
der Ebenen-Höchstwert (176, jedes Bild) größer als der Szenen-Höchstwert (171, jedes 10. Bild gezählt) → der
Szenenwert unterschätzt die Spitze (Befund B-05). Der eigentliche Torwächter (Ablehnungsmeldung der Engine) ist davon
nicht betroffen.

### 4.2 Texturspeicher (A-6)
`sh/probe_race.gd`, Kiel – Hamburg km 2, 12 Uhr, „Hoch“, 1280×720, 20 s Fahrt mit Autopilot, je Modus ein eigener
Prozess (gemessen, `Performance.RENDER_TEXTURE_MEM_USED`): **Arcade 197,9 MB, Modern 144,5 MB** (Videospeicher 204,2 /
165,8 MB). Modern liegt 53 MB **unter** Arcade – Grenze ist Arcade + 60 MB. Deckt sich mit RINT (201,7 / 109,2 MB bei
„Mittel“). Bei Regen „Hoch“ (Countdown-Sonde) 167,0 MB.

### 4.3 `collect()` je Baustein (A-18) und Einhängen
Xvfb, „Steam Deck“, Zeitraffer 16, ganze Etappe, `ChunkStreamer.stats()` (gemessen, Maschine unter Last 10–15):

| Lauf | collect max je Baustein (Mittel) | Einhängen max / Mittel | Sim-Schritt max (sonst ≈ 1 ms) |
|---|---|---|---|
| Testetappe (Raser) | **Grenze 6,72 (0,069)**, **Tankstelle 3,61 (0,148)**, Schilder 0,71, Rest ≤ 0,16 | **6,74** / 1,05 ms | 142 ms |
| Kiel – Hamburg | Brücke 1,25, Straßenrand 1,21, Tankstelle 0,47, Rest ≤ 0,15 | **8,96** / 1,27 ms | 369 ms |
| Testetappe (Raser), zweiter Lauf, gleiche Eingaben | **Tankstelle 4,86 (0,129)**, Schilder 1,34, Stadt 1,24, Grenze 0,53, Rest ≤ 0,16 | **5,24** / 1,17 ms | 173 ms |

Der Simulationsschritt (reines GDScript, im Mittel 1,1–1,3 ms) erreichte im selben Lauf 142 bzw. 369 ms: die VM hat
den Hauptfaden verdrängt. Einzelne Höchstwerte sind damit **nicht belastbar** – weder als Verstoß noch als Nachweis.
Die Mittel (alle Bausteine ≤ 0,15 ms, Einhängen 1,1–1,3 ms) sind es. Die Grenze mit 6,72 ms im ersten Lauf war
Rauschen (zweiter Lauf gleicher Eingaben 0,53 ms). **Die Tankstelle lag aber in beiden Läufen über 2 ms (3,61 / 4,86)**,
RINT maß auf ruhigerer Maschine 1,36 ms; mit dem Faktor 1,5 des Deck-Kerns (§4.10) wären das ≈ 2,0 ms – das Budget von
A-18 hat für die Tankstelle keine Reserve (Befund B-03, gefolgert). Das Einhängen liegt in **allen** Messungen über dem
Budget 3 ms („Steam Deck“/„Mittel“): hier 6,74 / 5,24 / 8,96 ms, RINT 3,8 / 6,8 ms, Basis `515dd51` 4,2 ms (Befund B-01).
Regel 3 hielt in allen drei Xvfb-Läufen (Hashes bitgleich).

### 4.4 Exportgröße
`tools/build_testbuild.sh 0.8.0-qa QA crossing-europe-qa` mit `OUT` im Prüfordner (eigenes XDG, Vorlagen verlinkt),
danach `tools/pck_report.py` auf beide Programme (gemessen): Exit 0, **Linux-Archiv 191,3 MB, Windows-ZIP 200,9 MB**
(Budget 277, Warnung > 300); der Arbeitsbaum war danach sauber (der Testbuild stellt `project.godot` wieder her).

| Teil (Windows-ZIP) | im Archiv MB | Budget MB |
|---|---|---|
| Programm (Godot-Vorlage) | 37,95 | 38,0 |
| Arcade-Sprites / -Klang | 71,07 / 14,72 | 71,0 / 14,7 (unverändert, Rundung) |
| UI, Schriften, Skripte, Daten | 4,04 | 5,0 |
| Modern: Modelle / Texturen | 19,55 / 18,41 | 40 / 60 |
| Modern: Klang / Musik | 16,38 / 18,60 | 23 / 25 |
| **Summe** | **200,72** (geschätzt) / 200,9 (gemessen) | **277** |

Gleich wie bei RINT (191,1 / 200,9 MB). Dateien: `out/q/build.log`, `out/q/pck_windows.txt`, `out/q/pck_linux.txt`.

## 5. Robustheit

| Prüfung | Ergebnis (gemessen) |
|---|---|
| `--gfx-debug=fail` (Kiel – Hamburg, Mittel) | Rückfall vor dem Start: Renderer `road_renderer.gd`, `gfx_fallback = "selftest:debug"`, Fenster wieder 16:9 (`KEEP`), Meldung „Der Modus „Modern“ lässt sich mit dieser Grafik nicht starten …“, Startwächter-Marke während des Laufs da, danach weg; 0 Fehler (`out/q/fail.log`, `bilder/gfxfail.jpg`) |
| Manifest fehlt | Rückfall, `gfx_fallback = "manifest"`, Meldung „… weil Spieldateien fehlen oder beschädigt sind …“; 0 Fehler (`bilder/nomanifest.jpg`) |
| Manifest kaputt (abgeschnittenes JSON) | dasselbe; eine Engine-Meldung „Parse JSON failed“ (erwartet) |
| Leistungstest `--bench=all --bench-out=…` | Exit 0, `--bench-out` und `user://leistungstest.json` gleich, alle Felder der Doku da, 3 Szenen (4,2 / 1,9 / 3,6 Bilder/s auf llvmpipe), Urteil `too_slow` → Arcade (`out/q/bench_out.json`). `game_version` 0.7.0 im Entwicklungsbaum (Versionsnummer kommt mit REL/Testbuild) |
| Langsamkeitswächter im Countdown mit Regen/Schnee | Bei 1280×720 unter Last (Bilder 1,2–2,5 s) **urteilt der Wächter nicht** (`watchdog` leer): `perf_probe.watch()` verwirft jedes Bild über 1000 ms als Pause, der Countdown endet ohne Urteil → Befund B-04. Bei 640×360 (Bilder 0,6–0,7 s): **Regen und Schnee je „Hoch“ → „Mittel“**, Meldung „Das Bild läuft zu langsam – … auf „Mittel“ gesenkt.“, Teilchen 4 000 → 1 500, `gfx_lowered = medium`, 0 Fehler (`out/q/wd_small.log`, `out/q/wd.log`) |
| Beenden (Fenster schließen) und Neustart in 13 Bildschirmen | Titel, Erststart-Auswahl, Optionen, Fahrzeug-Schauraum, Etappenwahl, Bestenlisten, Leistungstest-Seite, Ergebnis, Rennen beim Laden, im Countdown, in der Fahrt, Arcade-Rennen: Exit 0, **0 Fehler-/Leckzeilen**, keine Startwächter-Marke übrig, Neustart wählt weiter Modern ohne Rückfrage (`out/q/quit.log`). Pausenmenü: Pause nach 170 s Fahrt, Schließen bei 200 s – Baum pausiert, 0 Fehler, keine Marke, Neustart Modern (`out/q/quit_late.log`; im ersten Durchgang kam die Pause noch während des Ladens an und wirkte nicht). Beim kalten Shader-Cache nahm das Spiel das Schließen während des Ladens erst nach 35 s an (llvmpipe kompiliert Shader blockierend; auf echter GPU kürzer, gefolgert) |
| 20 min Modern fahren | Zwei Läufe, je ≥ 20 min Wanduhr, **0 Fehler- und Warnzeilen** außer der bekannten V-Sync-Meldung von llvmpipe: (a) ganzes Spiel über GameFlow, `--stage=kiel_hamburg --autopilot --gfx-preset=medium`, 21 min, Protokoll `user://logs/godot.log` sauber (Lauf per `timeout` beendet, darum ohne Fortschrittsangabe); (b) `stage_hash.gd` unter Xvfb, Bern – Mailand ab km 120 um 18:30 (in die Dämmerung), „Mittel“, 1200 s: km 120 → 161,9, 114 Sekunden-Hashes, keine Engine-Meldung (`out/q/drive20p.out`) |
| Builds Linux/Windows starten Modern und Arcade | `tools/smoke_modern.sh` auf den eigenen Testbuild (gemessen): **SMOKE linux OK, linux_opengl3_es OK, windows OK** (wine64, OpenGL über Mesa – ANGLE/Direct3D lässt sich hier nicht zeigen). Je Arcade und Modern zwei Bilder, Leistungstest „autobahn“ 4,0 / 3,1 / 3,8 Bilder/s, Version `0.8.0-qa`, Vorschlag arcade/low; Nutzerordner jeweils im Prüfordner (`…/xdg/crossing-europe-qa`, unter Wine `drive_c/users/root/AppData/Roaming/crossing-europe-qa`), `~/.local/share/crossing-europe-qa` existiert nicht (`bilder/smoke_linux_arcade_modern_01.jpg`, `bilder/smoke_windows_arcade_modern_01.jpg`) |

## 6. Befunde

Schwere: blocker = darf nicht in den nächsten Testbuild; high = fällt sofort auf; medium = merklich; low = Feinschliff.
**Kein Blocker, kein „high“.**

**B-01 (medium, Budget) – Einhängen eines Stücks über dem Budget 3 ms**
- Wo: `scripts/race3d/chunk_streamer.gd` (Commit-Pfad, `commit_ms_max`), Ausgaben der Bausteine.
- Was: §4.10 erlaubt „chunk commit max“ 3 ms für „Steam Deck“, „Niedrig“, „Mittel“. Gemessen (Xvfb, „Steam Deck“,
  ganze Etappe): Testetappe 6,74 und 5,24 ms, Kiel – Hamburg 8,96 ms (Mittel 1,05–1,27 ms). RINT: 3,8 / 6,8 ms, Basis
  `515dd51` 4,2 ms. Unter der Last dieser VM sind Einzelwerte verrauscht (Sim-Schritt bis 369 ms), aber **keine einzige
  Messung** – auch nicht RINTs auf ruhigerer Maschine – blieb unter 3 ms. Auf dem Deck gefolgert: gelegentlich ein
  verlorenes Bild beim Einhängen.
- Beleg: `out/q/x_dev.log`, `out/q/x_dev2.log`, `out/q/x_kh.log` (Zeile `BUDGET … commit_ms_max`).
- Nachstellen: `sh/q.sh x_dev` (bzw. `stage_hash.gd` unter Xvfb mit `--gfx-preset=deck --timescale=16`, dann
  `PERF.streamer.commit_ms_max`).
- Behebung: das Einhängen wie `warm_step()` unter ein Zeitbudget stellen (Teile eines Stücks über zwei, drei Bilder
  einhängen, Rest im nächsten Bild; die Sichtbarkeit erst setzen, wenn alles hängt) und `chunk_commit_ms_max` in die
  `leistungstest.json` aufnehmen, damit das Deck die Zahl liefert; oder die Leitung legt ein anderes Budget fest.

**B-02 (medium, Tests) – Die Tönungsregel (A-19) ist für `baked`, `leaves`, `billboard` ohne Wächter**
- Wo: `tests/unit/race3d/test_props.gd::test_model_instances_carry_the_placement_tint` (Zeilen 395–401) und die
  Render-Prüfungen.
- Was: Der Test prüft für `baked`/`leaves`/`billboard` nur, dass der Shader `v_tint` aus `INSTANCE_CUSTOM` **liest**,
  nicht, dass er die Albedo damit **multipliziert** (nur für `vpbr_static` wird der Text `alb *= v_tint` gesucht).
  Mutation: `a.rgb *= v_tint;` in `baked.gdshader` und `* v_tint` in `leaves.gdshader` entfernt → `test_props` 13/0,
  `check_props_render`, `check_models`, `check_facade_render` grün. Nur der Modern-Golden `modern_s4_mittel` weicht ab –
  ein Änderungsmelder, den die Montage nach dem Ansehen neu erzeugt (A-18), kein Regelwächter. Die rosa
  Einfamilienhäuser von S4 (RINT: „besser“) könnten so unbemerkt wieder weiß werden.
- Beleg: `out/mut_tint_baked_unit.log`, `out/rmut/tint*.log`, `out/q/gmut_modern.log`.
- Nachstellen: `python3 sh/mutate.py apply assets/shaders/modern/baked.gdshader "	a.rgb *= v_tint;" "	a.rgb *= vec3(1.0);"`,
  dann `tools/run_tests.sh test_props` und `tools/run_render_checks.sh modern props_render` in der Kopie.
- Behebung: im Einheitstest je Klasse die Multiplikation verlangen (z. B. `baked`: `a.rgb *= v_tint`, `leaves`:
  `* v_tint;` in der `ALBEDO`-Zeile, `billboard`: `COLOR.rgb * v_tint`) – besser zusätzlich eine Render-Prüfung in
  `check_props_render`: dasselbe Haus-Modell mit `tint "#ff8080"` und ohne, Rot/Grün-Verhältnis der Wand muss steigen.

**B-03 (low, Budget A-18) – `collect()` der Tankstelle ohne Reserve**
- Wo: `scripts/race3d/builders/station.gd` (`columns_in_chunk`, `canopy_job_rest`, `WARM_BUDGET_MS`).
- Was: A-18 verlangt ≤ 2 ms je Baustein auf „Steam Deck“. Zwei Läufe derselben Fahrt: Tankstelle **3,61 / 4,86 ms**
  (Mittel 0,13–0,15), alle anderen Bausteine im zweiten Lauf ≤ 1,34 ms (der Grenz-Wert 6,72 ms des ersten Laufs war
  Rauschen). RINT maß 1,36 ms; × 1,5 für den Deck-Kern (§4.10) ≈ 2,0 ms – auf dem Gerät gefolgert an der Grenze.
- Beleg: `out/q/x_dev.log`, `out/q/x_dev2.log` (`COLLECT_BY`).
- Nachstellen: `sh/q.sh x_dev2`.
- Behebung: `canopy_job_rest()` in mehr Teile zerlegen (Spuren je Kamerastelle in Häppchen unter `WARM_BUDGET_MS`), so
  dass kein Aufruf über ~1 ms auf dieser VM kommt; `collect_by` in `leistungstest.json` schreiben und auf dem Deck messen.

**B-04 (low, Robustheit) – Der Langsamkeitswächter urteilt nicht, wenn jedes Bild länger als 1 s dauert**
- Wo: `scripts/race3d/perf_probe.gd::watch()` (`float(us) > MAX_FRAME_MS * 1000.0` → Bild verworfen).
- Was: Bei 1280×720 „Hoch“ mit Regen/Schnee und Bildern von 1,2–2,5 s blieb `watchdog` leer, nichts wurde gesenkt, keine
  Meldung – gerade der langsamste Rechner bekommt keine Hilfe. Mit 0,6–0,7 s je Bild (640×360) stuft er korrekt herab.
- Beleg: `out/q/wd.log` (`watchdog ""`, `watchdog_median_ms 0`, `frame_ms_median 1347`) gegen `out/q/wd_small.log`.
- Nachstellen: `probe_race.gd` unter Xvfb 1280×720, `--gfx-preset=high --weather=rain`, mit Countdown, auf einer
  Maschine mit < 1 Bild/s.
- Behebung: im Countdown Bilder über `MAX_FRAME_MS` nicht verwerfen, sondern auf `MAX_FRAME_MS` kappen und zählen (eine
  echte Pause friert den Countdown ohnehin ein); oder am Countdown-Ende mit ≥ 3 solchen Bildern „slow“/„too_slow“ urteilen.

**B-05 (low, Tests) – Der Szenenzähler der Instanzprüfung unterschätzt die Spitze**
- Wo: `tests/race3d/render/check_instance_budget.gd::_process` (Szene nur jedes 10. Bild gezählt).
- Was: `instanzen_stadt`: Fahrzeug-Ebene höchstens **176** Instanzen (jedes Bild), ganze Szene höchstens **171** (nur
  jedes 10. Bild) – die Szene enthält die Ebene, ihre Spitze lag also ≥ 176. Der eigentliche Torwächter (Ablehnung der
  Engine, 0) ist nicht betroffen; die gemeldete Reserve (Wald 216/230) ist aber womöglich kleiner.
- Beleg: `out/rc_full.log`, Zeilen `instanzen_stadt`, `instanzen_wald`.
- Behebung: mit eingespeistem Verkehr jedes Bild zählen, oder zumindest in jedem Bild, in dem die Ebene einen neuen
  Höchstwert erreicht; ausgeben `max(Szene, Ebene + übrige)`.

**B-06 (low, Vertrag/Code) – `SPOT_SPECULAR` wirkt auf nichts Geprüftes**
- Wo: `scripts/race3d/layers/lights.gd:49`, Vertrag §11.3 A-20 erster Spiegelstrich.
- Was: `SPOT_SPECULAR` 0,5 → 0 ändert weder `abblendlicht` noch `nass_kegel` (bitgleich 0,219). Das Abblendlicht der
  Fahrbahn kommt aus `inc/headlight.gdshaderinc` (`ce_headlight_light`) – das ist geschützt (Mutation → `nass_kegel`
  0,35×). RINT hat das als Vertragsfrage gemeldet; ich bestätige es mit Messung.
- Behebung: A-20 Satz 1 auf `ce_headlight_light` beziehen; die Konstante entweder entfernen oder mit einer Prüfung
  versehen, die ihren Zweck (Glanz der Fahrzeuglacke im Kegel?) misst.

**B-07 (low, Regel 8 – nicht diese Montage) – echter Benutzerordner beschrieben**
- Wo: `~/.local/share/godot/app_userdata/Crossing Europe – A Racing Xperience/logs/godot.log`.
- Was: Heute zwischen 08:55 und 09:50 liefen dort **mindestens sechs Sonden des parallel arbeitenden Pakets R7a**
  ohne `XDG_DATA_HOME` (`…/m1/R7a/probe/bench.gd` „BENCH iterations=188000“, `short_arc.gd` „SHORT lanes …“, Läufe mit
  „STEPS long cam …“, „ENV safe1 …“, „CORR …“, einer mit `ERROR: Condition "p_size < 0"`); die Log-Rotation hat dabei
  ältere Protokolle verdrängt. Außerdem liegen dort noch die 31 Shader-Cache-Dateien aus RINTs selbst gemeldetem
  Verstoß (16.11., 13:52). Meine Läufe haben den Ordner nicht berührt (`find -newer` gegen den Stand des Vorgängers;
  alle neuen Dateien dort stammen inhaltlich aus R7a-Sonden).
- Beleg: `out/real_userfolder_godot_log_0855.txt`, `out/real_userfolder_logs_today.txt` (Kopf jedes Protokolls mit Zeit).
- Behebung: R7a exportiert `XDG_DATA_HOME` in seinen Sonden; die Leitung löscht die Shader-Cache-Dateien von RINT
  (harmlos, aber nicht zuzuordnen).

## 7. Geprüft und in Ordnung

- Eingefrorene Arcade-Dateien gegen `main` und gegen die Basis: unverändert (gemessen).
- Arcade-ERGEBNIS und Verkehr bitgleich zu v0.7.0 auf vier Etappenläufen (Kiel – Hamburg, Testetappe nachts im Regen,
  Bern – Mailand im Schnee, Testetappe mit Blitzer und Polizei) (gemessen).
- Regel 3: Modern = Arcade (ERGEBNIS ohne `gfx`, jede Sekunde des Verkehrs) kopflos auf vier Läufen und **mit echtem
  Zeichnen** unter Xvfb auf drei Läufen (gemessen).
- Arcade-Klang: `test_arcade_identity` (Mischer, Effekte, Verkehr/Raum byte-gleich zu v0.7.0) grün; die Montage
  ändert keine Klangdatei (gemessen).
- `tools/golden.sh check`: **20 von 20**, **arcade-ui 17 von 17** identisch; das Werkzeug erkennt eine Änderung von
  einem LSB in `Palette.ROAD` (gemessen).
- Vertrag §11.3 zeichengleich, nur angehängt (gemessen).
- `run_tests.sh` 803/0; `run_render_checks.sh all` 28/28; `test_chunk_services` (bei RINT einmal zeitabhängig rot)
  dreimal hintereinander unter Last grün (gemessen).
- Wächterkraft: A-19-Zensus (lädt das Budget), A-20 Fahrzeuge im Abblendlicht, A-20 Fahrbahn im Abblendlicht,
  Nachtschein der Bremslichter (Einheit und Render), Tönung bei `vpbr`, A-18 Spieltafel-Regel, Arcade-Goldens,
  Modern-Golden – jede Mutation wird rot (gemessen).
- Texturspeicher Modern 144,5 MB < Arcade 197,9 MB (gemessen).
- Exportgröße 191,3 / 200,9 MB, alle Teile im Budget (gemessen).
- Rückfall bei `--gfx-debug=fail`, fehlendem und kaputtem Manifest: Arcade, richtige Meldung, `gfx_fallback`,
  16:9, Marke weg (gemessen).
- Leistungstest `--bench=all`: gültige Datei, gleich der Kopie im Nutzerordner (gemessen).
- Langsamkeitswächter stuft bei Regen und Schnee im Countdown herab, solange ein Bild < 1 s dauert (gemessen).
- Beenden und Neustart in 13 Bildschirmen plus im Pausenmenü sauber (gemessen).
- 2 × 20 min Modern ohne Fehlerzeile (gemessen).
- Testbuild Linux, OpenGL ES und Windows (Wine) starten Arcade und Modern, eigener Nutzerordner (gemessen; echte
  Windows-GPU und Steam Deck: gefolgert, nicht gesehen).

## 7a. Vertragsfragen

- **A-18 / §4.10 – Messbarkeit der Höchstwerte:** „llvmpipe gemessen“ lässt sich auf der geteilten VM nicht belastbar
  erfüllen oder widerlegen (Sim-Schritt bis 369 ms im selben Lauf, Grenze 6,72 → 0,53 ms zwischen zwei gleichen Läufen).
  Vorschlag: Budget als Median der Höchstwerte aus drei Läufen oder als 99. Perzentil; Nachweis auf dem Deck über
  `leistungstest.json` (dort `collect_by` und `chunk_commit_ms_max` ausgeben).
- **§4.10 Einhängen 3 ms:** seit der Basis in keiner Messung erreicht (B-01) – Budget bestätigen oder Arbeit (Aufteilen
  über Bilder) einplanen.
- **A-20 Satz 1** meint mit „specular of the low beam“ in Wahrheit `ce_headlight_light` der Fahrbahn; `SPOT_SPECULAR`
  wirkt auf nichts Geprüftes (B-06, bestätigt RINTs Frage).
- **A-19 Zensus:** mit eingespeistem Verkehr gilt nur die Szenengrenze; die Zählung der Szene sollte jedes Bild laufen
  (B-05), sonst ist „216 von 230“ eine Untergrenze.

## 7b. Hinweise für die nächste Runde

- B-02 (Tönungswächter) ist billig und schützt eine sichtbare Verbesserung – vor dem Testbuild 2 einbauen.
- Budgets auf dem Deck messen: Leistungstest mit `collect_by`/`chunk_commit_ms_max` erweitern (QA owns the scene list).
- Lädt Modern mit kaltem Shader-Cache, nimmt das Spiel das Schließen des Fensters auf llvmpipe erst nach bis zu 35 s an
  (Shader-Übersetzung blockiert den Hauptfaden); auf dem Deck gefolgert kürzer – beim Testbuild beobachten.
- R7a an Regel 8 erinnern (B-07).
- `game_version` in `leistungstest.json` ist im Entwicklungsbaum 0.7.0 – erst der Testbuild setzt die Version (gemessen:
  0.8.0-qa); für Zahlen vom Nutzer nur Testbuilds verwenden.

## 8. Eigene Abweichungen

- Der Vorgänger dieses Laufs wurde durch einen Container-Neustart gestoppt; ich habe seinen Arbeitsbaum und seine
  Ergebnisse weiterverwendet (Testlauf 1 auf `9b02f05`, Etappenvergleiche, Einheitsmutationen).
- Die Prüfungen liefen auf einer stark belasteten VM (Last 10–15, mehrere Pakete); Zeiten sind Proxys.
- Der Neustart-Teil von `sh/quit_restart.sh` startet ein Prüfskript ohne `--graphics`, weil er genau prüft, was ein
  Spielerstart ohne Argumente entscheidet (eigenes XDG, keine Spielszene).
- `tools/golden.sh` und `tools/smoke_modern.sh` legen ihr leeres, absolutes `XDG_DATA_HOME` selbst an –
  `golden.sh` unter `/tmp/ce_golden_*` (TMPDIR), nicht im Prüfordner. Nie der echte Benutzerordner.
- Run_tests habe ich nicht ein zweites Mal ganz laufen lassen (der Vorgänger lief auf demselben Stand; ich habe keinen
  Code geändert); gezielt wiederholt: `test_props`, `test_chunk_services` (3×).

## 9. Dateien

Prüfordner `P = /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-SYSTEM`:
- `P/STAND.md` – Ablauf mit Uhrzeiten; `P/sh/` – alle Skripte (`stage_hash.gd`, `cmp_stages.py`, `stages.sh`,
  `probe_race.gd`, `quit_probe.gd`, `quit_restart.sh`, `mutate.py`, `render_mut.sh`, `q.sh`, `q2.sh`, `q3.sh`, `q4.sh`).
- `P/out/` – alle Protokolle: `tests1.log`, `rc_full.log`, `stages/`, `cmp_arcade_v070.txt`, `frozen.txt`, `rmut/`,
  `q/` (je Aufgabe `<job>.log`, `bench_out.json`, `pck_*.txt`, `golden_check.log`, `gmut*_*.log`, `drive20p.out`),
  `quit/`, `mut_*.log`, `flaky_*.log`, `real_userfolder_*.txt`.
- Lieferordner `…/deliver/QA-RINT-SYSTEM/`: dieser Bericht und `bilder/` (`gfxfail.jpg`, `nomanifest.jpg`,
  `badmanifest.jpg`, `wd_rain.jpg`, `wd_snow.jpg`, `smoke_linux_arcade_modern_01.jpg`,
  `smoke_windows_arcade_modern_01.jpg`, `waechter_schnee_640.jpg` – Meldung des Wächters nach dem Herabstufen).
- Testbuild, Wine-Präfix und behaltene Golden-Bilder habe ich nach der Prüfung gelöscht (Platz).
