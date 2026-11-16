# Bericht R1a – Renderer-Gerüst (v0.8.0, Abschnitt 1, Arbeitsgang A)

- Worktree: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1`
- Branch: `worktree-wf_3b561c53-566-1`; Kopf `65c7560` = `origin wip/v080-r1a` (gleicher Hash, nachgesehen)
- Basis: `2b41e16`; 9 Commits, 18 Dateien (+ 10 `.uid`), keine eingefrorene und keine fremde Datei
- Zwei Bearbeiter: der erste wurde nach rund 35 Minuten durch einen Container-Neustart beendet (Commit `7dbd654`:
  Gerüst, `services`, erste Fassung der Lichtkegel, `check_facade.gd` mit Prüf-Ebene, -Builder und -Renderer,
  Unit-Tests). Der zweite hat den Stand durchgesehen, übernommen und fertiggestellt.

**Wie die Angaben zu lesen sind.** „gemessen“ / „gelaufen“ heißt: auf dieser VM gesehen (headless bzw. Mesa llvmpipe
unter Xvfb), mit dem Stand, der dabeisteht. „gerechnet“ heißt gerechnet. Was nur im Code steht und nie lief, steht
in Abschnitt 6. Über echte Grafikkarten und das Steam Deck sagt dieser Bericht nichts.

## 1. Was geliefert ist

| Nr. | Auftrag | Stand |
|---|---|---|
| 1 | `scripts/race3d/modern_renderer.gd`: Gerüst mit der Fassade aus A-7, `pool_materials()`, Haken, Vorbereitung über Bilder, eingebaute Umgebung | fertig |
| 2 | `ChunkStreamer.services` / `ChunkContext.services` mit Unit-Test | fertig (4 Tests) |
| 3 | `assets/shaders/modern/inc/pools.gdshaderinc`, erste Fassung, mit Render-Prüfung | fertig; zusätzlich `ce_pools_emission()` |
| 4 | `tools/ab_shot.sh` | fertig; ein Fehler (wechselnde Beschriftungsschrift) erst beim Ansehen der Bilder gefunden und behoben |
| 5 | Prüfungen und Abschlussläufe | siehe Abschnitt 3 – die vollständigen Läufe stehen auf `72938cd`, nicht auf dem Kopf |
| 6 | `docs/renderer-modern.md` §9 „Aufbau: Fassade, Ebenen, Haken“ | fertig; nach den Messungen in mehreren Punkten berichtigt |
| – | A/B-Bild Kiel – Hamburg km 2 | `kiel_hamburg_km2_ab_00.jpg` |

## 2. Der Renderer in Kürze

- `setup → apply_quality → prepare → render`. `prepare()` baut Pfad, Geländeprofil, `ChaseCamera3D`, die `Camera3D`
  (Frustum für die logische Bildgröße), `world`, `ModernMaterials.shared()`, die Umgebung (Rig oder eingebaut), den
  Streamer mit `BuilderRegistry.create_all()` und `services`, dann jede Ebene, deren Datei es gibt. Geladen wird mit
  `load()` zur Laufzeit.
- Haken an Umgebung, Buildern und Ebenen (freiwillig, per `has_method`): `setup`, `apply_quality`, `prepare`,
  `prepare_pending`, `fail_reason`, `warmup_nodes`, `update`, `rebased`, `perf`, `snapshot`; `add_static` an
  `lights` / `flares`.
- Vorbereitung: Selbsttest (einmal je Prozess) → alle `prepare_pending()` 0 → Startansicht geladen → Aufwärm-Knoten
  zwei gezeichnete Bilder hinter dem Ladebild → `is_prepared()`. Bis dahin `dt` = 0.
- `healthy()` / `fail_reason()`: `selftest:<grund>`, Gründe der Haken, `script:<datei>`, `timeout`.
- Eingebaute Umgebung und eingebauter Himmel, solange `environment_rig.gd` / `layers/backdrop.gd` fehlen; die
  Debug-Straße bleibt die Straße, solange `builders/road.gd` fehlt.

## 3. Prüfungen – auf welchem Stand was lief

| Lauf | Stand | Ergebnis |
|---|---|---|
| `tools/run_tests.sh`, vollständig | `faaf3e7` | bestanden: 576 Unit-Tests, 73 Prüfungen, 0 `FEHLER`; 541 s |
| `tools/run_tests.sh`, vollständig | `72938cd` | bestanden: 576 Unit-Tests, 73 Prüfungen, 0 `FEHLER`; 534 s |
| `tools/golden.sh check` | `72938cd`, sauberer Arbeitsbaum | 20 von 20 identisch, 149 s |
| `tools/golden.sh check` | gemischter Baum zwischen `faaf3e7` und `72938cd` | 20 von 20 identisch (deshalb wiederholt) |
| `tools/run_render_checks.sh all` | `faaf3e7` | 5 von 5 Dateien in Ordnung, 167 s |
| `tools/run_render_checks.sh all` | Inhalt von `72938cd`, unmittelbar vor dem Commit | 5 von 5 in Ordnung, 115 s (glow 16, flip 1, `check_facade_render` 4, `check_models` 6, `check_seam_render` 6) |
| `tests/race/run_stage.gd`, Arcade gegen Modern | `300a571` und `72938cd` | Kiel – Hamburg (12 Uhr) und dev_testetappe (21 Uhr, Regen): je 28 Schlüssel, nur `gfx` verschieden |

**Der Kopf `65c7560` unterscheidet sich von `72938cd` in vier Dateien:** `docs/renderer-modern.md`,
`tests/race3d/check_facade.gd` (Tunnel-Teil), `tests/race3d/render/check_facade_render.gd` (neue Prüfung
„strasse“) und `tools/ab_shot.sh` (Schrift der Beschriftung). Auf dem Kopf selbst gelaufen sind nur:
`check_scripts` (228 Skripte, 0 fehlerhaft), `check_facade.gd` (8 Prüfungen OK), `check_facade_render.gd`
(5 Prüfungen OK) und `tools/ab_shot.sh` (elf Aufrufe). **Nicht** erneut gelaufen auf dem Kopf: die vollständige
`run_tests.sh`, `golden.sh` und die übrigen Render-Prüfdateien.

`tools/run_tests.sh` wurde dreimal gestartet: einen Start brach ich nach 3,5 Minuten ab (ich hatte Quelldateien
geändert), zwei Läufe liefen vollständig. Der Auftrag erlaubt zwei Läufe; der abgebrochene Start kommt dazu.

Zwei Zählfehler von mir, berichtigt: Ich hatte „80 Prüfungen“ geschrieben (auch in der Commit-Nachricht von
`72938cd`, die veröffentlicht ist und stehen bleibt) – 7 der 80 Zeilen sind Summenzeilen, es sind 73. Und „17
Dateien“ – es sind 18.

Einzelprüfungen dieses Bauabschnitts (letzter Lauf):

| Prüfung | Ergebnis |
|---|---|
| `tests/race3d/check_facade.gd`: haken, fassade, lampen, rebased, statistik, ausfall, umgebung, geruest | 8 OK |
| `tests/race3d/check_seam.gd`: 8 bisherige + `vertrag` | 9 OK (auf `72938cd`) |
| `tests/race3d/render/check_seam_render.gd`: 6, davon `modern_bild` und `fenster_16_10` angepasst | 6 OK (Inhalt von `72938cd`) |
| `tests/race3d/render/check_facade_render.gd`: licht, strasse, nacht, pools, aufwaermen | 5 OK; licht, pools und aufwaermen zeigten in jedem Lauf seit ihrer letzten Änderung dieselben Werte (mehrere Läufe, nicht gezählt), nacht lief zweimal mit denselben Werten, strasse einmal (dazu einmal als Arbeitsskript mit demselben Ergebnis) |
| Unit-Tests `tests/unit/race3d/` | 41, 0 fehlgeschlagen (neu: 4 + 3) |

## 4. Messwerte

| Messung | Wert | Stand |
|---|---|---|
| `render()` in GDScript, headless, 30 s Fahrt, ab km 2 / ab km 60 (je ein Lauf) | im Mittel 0,156 / 0,149 ms, höchstens 2,1 / 2,8 ms | `300a571` |
| dasselbe | im Mittel 0,173 / 0,150 ms, höchstens 2,4 / 2,2 ms; Sync-Modus 0,192 ms, höchstens 5,8 ms | `72938cd` |
| Vorbereitung headless | 74–77 ms, dann 79–89 ms | `300a571`, `72938cd` |
| Vorbereitung unter Xvfb, erste Modern-Etappe des Prozesses | 405–808 ms, davon Selbsttest 202–591 ms | mehrere |
| Zeichenaufrufe / Dreiecke des Gerüst-Bildes bei km 2 | 12 / 13.056 | `72938cd` |
| Kamera: `Camera3D.unproject_position()` gegen `world_to_screen()` | 0,0005 px (1280×720), 0,0001 px (1280×800) | `72938cd` |
| Licht mittags: ebene Platte (Albedo 0,38) im Licht / im Schatten | 99/99/99 (Arcade 97/97/97) / 47/48/51 (erwartet 48/49/52) | Kopf |
| Nacht, 23 Uhr: beleuchtete Platte / Debug-Straße | 17/22/34 (Arcade 21/25/36) / 6/13/27 (Arcade 16/21/32) | Kopf |
| Kasten über der bloßen Debug-Straße | 0 von 1.296 Bildpunkten darunter verändert: kein Schatten | Kopf |
| Lichtkegel: Mitte / halber Radius / außerhalb / zwei Kegel | 230/187/123 (erwartet 231/188/124) / 178/145/94 (179/145/94) / 0 / 169/169/210 (170/170/211) | Kopf |
| Lichtkegel auf beleuchteter Platte | +36/30/23 (erwartet +36/30/23) | Kopf |
| Aufwärm-Knoten | in 2 gezeichneten Bildern sichtbar (Ladebild für die Prüfung ausgeblendet), mit Ladebild 0 Proben | Kopf |
| `tools/ab_shot.sh`, vier Aufrufe derselben Position | viermal byte-gleiche Arcade- und Modern-Bilder | Kopf |

Die beiden Zeitrunden liegen auf verschiedenen Ständen und bestehen aus je einem Lauf. Wie stark die Zeiten hier
von Lauf zu Lauf streuen, habe ich nicht gemessen; der Unterschied zwischen den Runden lässt sich deshalb nicht
dem Haken der Debug-Straße zuschreiben.

**Das Lichtgesetz der eingebauten Umgebung ist schlechter, als ich zuerst schrieb.** Gemessen sind genau zwei
Punkte (Albedo 0,38, mittags und 23 Uhr, klar). Gerechnet (`lichtgesetz_tabelle.txt` in diesem Ordner: Rohausgabe
eines Arbeitsskripts, Abweichung einer ebenen Fläche von Arcades Farbe, ungünstigster Farbkanal, je Stunde, Wetter
und Albedo; nur ein Durchgang des Renderers) trifft es Arcade nur für mittlere Albedos am hellen Tag (−3,6 … +6,9 %
für Albedo 0,3 … 0,9). In der Dämmerung und nachts liegen dunkle Flächen bis −59 % darunter und helle bis +35 %
darüber; das gemessene Nachtbild ist noch dunkler als die Rechnung. Die alte Fassung der Dokumentation („bei Tag
höchstens 7,5 %“, „nachts ein Viertel heller“) war zu günstig; `docs/renderer-modern.md` §9.6 ist berichtigt, der
Kopfkommentar von `scripts/race3d/plain_environment.gd` **nicht** (siehe Abschnitt 6).

## 5. Abweichungen vom Auftrag / Bauplan

1. **`update()` und `rebased()` auch an Buildern.** A-7 kommentiert beide mit „layers“, der Auftrag zählt sie zu den
   Haken „of layers AND builders“. Umgesetzt ist die Obermenge (Builder nach der Kamera, vor den Ebenen).
2. **`dt` = 0, solange die Etappe vorbereitet wird** – die Zahl der Vorbereitungsbilder schwankt, der Zustand beim
   Start soll davon nicht abhängen.
3. **Zwei Dateien für die eingebaute Umgebung** (`plain_environment.gd`, `plain_sky.gd`); sie setzt mehr Globals als
   verlangt und wird nicht als `env` gezeigt (A-7: `env` ist das Rig).
4. **`pools.gdshaderinc` hat drei Helfer mehr** (`ce_pools_emission`, `ce_pools_encode`, `ce_pools_to_lin`).
5. **Zusätzliche Ausfallgründe** `script:<datei>` und ein Zeitlimit `graphics.modern.prepare_timeout_s` (Vorgabe im
   Code 120 s; die Konfigurationsdatei ist nicht angefasst).
6. **`tools/ab_shot.sh`**: Kürzel S1–S5 (S2 = km 13,6: §4.9.2 nennt für die erste Tankspur keinen Kilometer),
   Vorgabe 2 s nach dem Start, Arcade mit `--shot-fast`, je Lauf ein eigener leerer `XDG_DATA_HOME`.
7. **Nachts kein Mondlicht in der eingebauten Umgebung** (Energie 0); D5 („moon by night“) löst das Rig von R1.
8. **`modern_bild` und `fenster_16_10` zweigeteilt**: erst das Gerüst allein (exakt), dann der ausgelieferte
   Renderer mit dem, was für jeden Inhalt gilt – sonst würde die Prüfung rot, sobald R1–R3 ihre Dateien ablegen.
9. **`ERGEBNIS`-Gleichheit** ist als Lauf gemessen, nicht als neue automatische Prüfung angelegt
   (`check_session` → `gfx_independent` prüft sie headless; `check_modern_stage.gd` gehört R1).
10. **Kern-Datei `builders/debug_road.gd` geändert**: ein Haken `update()` färbt die unbeleuchtete Vertretung mit
    `palette.ambient` (vorher war der Boden nachts taghell). Und: nach den vollständigen Abschlussläufen kamen noch
    zwei Commits (Prüfungen/Dokumentation, dann die Korrektur an `tools/ab_shot.sh`) – siehe Abschnitt 3.

## 6. Was nicht nachgewiesen ist

- **`--gfx-debug=cover`** (Canvas magenta, Nebel aus): steht im Code der eingebauten Umgebung und des Himmels, ist
  in diesem Bauabschnitt nie gelaufen.
- **Die `ce_*`-Globals**: werden gesetzt; kein Bild und keine Prüfung dieses Bauabschnitts liest sie. Ob die Werte
  zu den Modell-Shadern passen, zeigt sich erst mit Fahrzeugen und Requisiten.
- **Zeitlimit**: Dass es auslöst, prüft `ausfall` (headless, 0,3 s). Dass es bei einem minimierten Fenster oder
  nach dem Ruhezustand **nicht** auslöst, ist überlegt und nicht ausprobiert.
- **Export**: `.gdshaderinc` sollte mit `export_filter="all_resources"` im Paket landen – gefolgert, kein Export
  gebaut.
- **Tunnel**: Zustandswerte headless geprüft (`umgebung`, Bern – Mailand km 186), ein Bild angesehen. Mehr nicht –
  kein anderer Tunnel, keine Einfahrt, keine Ausfahrt.
- **Kopfkommentar von `scripts/race3d/plain_environment.gd`** nennt die zu günstigen Zahlen des Lichtgesetzes
  („by day within −4 .. +7 %“, „at night … up to a quarter brighter“). Bekannt falsch, nicht mehr geändert (kein
  Code unter `scripts/` nach den Abschlussläufen); R1 ersetzt die Datei.
- **Die beiden Beispiele der Dokumentation** liefen im echten Renderer (headless und einmal unter Xvfb), sind aber
  keine Dateien des Repositorys und werden von keiner Prüfung ausgeführt.
- **Echte Grafikkarte, Steam Deck, Windows/ANGLE**: nichts.

## 7. Bilder in diesem Ordner

- `kiel_hamburg_km2_ab_00.jpg` (+ `_arcade_00.png`, `_modern_00.png`): derselbe Zustand in beiden Modi (0:02.00,
  km 2,7, 146 km/h). **Modern ist klar schlechter als Arcade**: Himmelsverlauf ohne Sonne und Wolken, die
  Debug-Straße ohne Spurmarkierung und Leitplanken, flächiges Gelände in zwei Grüntönen; kein Wagen, kein Verkehr,
  keine Bäume. Besser ist nichts. Gleich sind Horizont, Fluchtpunkt, Fahrbahnbreite und HUD.
- `kiel_hamburg_km2_nacht_ab_00.jpg`: 23 Uhr. Arcade: Sterne, Mond, Scheinwerferkegel, Rücklichter. Gerüst: dunkler
  Verlauf, fast schwarze Fahrbahn – dunkler als Arcade und ohne jedes Licht.
- `bern_mailand_km186_tunnel_ab_00.jpg`: im Gotthardtunnel. Arcade: Röhre, Wände, Lampen, Verkehr. Gerüst: eine
  dunkle Fläche und die warm gefärbte Fahrbahn mit Banketten, sonst nichts (der Tunnel-Builder kommt später).
- `kiel_hamburg_s2_s5_ab.jpg`: S2–S5. Das Werkzeug trifft die Stellen (Tankstelle voraus, km 60, Köhlbrandbrücke
  in den City Limits, Ziel unmittelbar voraus); das Gerüst zeigt überall nur Straße und Boden.
- `facade_licht.png`, `facade_strasse.png`, `facade_nacht.png`, `facade_pools.png`, `facade_aufwaermen.png`: die
  beurteilten Bilder der Render-Prüfungen.
- `beispiel_ebene_builder.png`: die beiden Beispiele der Dokumentation unter Xvfb – ein kleiner dunkelroter Kasten
  auf der Fahrbahn (Ebene) und dünne Pfosten am rechten Bankett (Builder). Es funktioniert; ansehnlich ist es nicht.
- `lichtgesetz_tabelle.txt`: siehe Abschnitt 4.

## 8. Hinweise für R1, R2, R3 und RINT

1. Datei ablegen genügt (`builders/<name>.gd`, `layers/<name>.gd`, `environment_rig.gd`); `modern_renderer.gd`
   ändert danach nur R1.
2. R1: mit `environment_rig.gd` entfällt die eingebaute Umgebung (das Rig setzt dann die `ce_*`-Globals und hält
   das eine Schattenlicht), mit `layers/backdrop.gd` der eingebaute Himmel, mit `builders/road.gd` die Debug-Straße.
3. R1: `layers/lights.gd` setzt je Bild `pool_pos_r`, `pool_col`, `pool_count` auf jedem Material aus
   `renderer.pool_materials()` und bietet `add_static(parent, lamps)`.
4. R1: nicht im Gerüst – Renderzustände je Qualitätsstufe (MSAA, 3D-Auflösung, Schattenatlas), Countdown-Wächter
   und `quality_lowered` (deklariert, nie gesendet), `graphics.modern.max_chunks` = 18, `prepare_timeout_s` in der
   Konfiguration.
5. R2: ein Builder mit `id()` „terrain“ schaltet die Geländeringe der Debug-Straße ab; Materialien der Lichtkegel
   mit `renderer.add_pool_material()` anmelden.
6. R3: Positionen gibt es erst ab dem ersten `update()`. Auf der Debug-Straße wirft ein Fahrzeug **keinen
   Schatten** (gemessen) – das ist die unbeleuchtete Vertretung, kein Fehler der Fahrzeug-Ebene.
7. Alle: Nachtbilder auf dem Gerüst taugen nur als Hintergrund – der Boden ist dunkler als in Arcade, das
   Lichtgesetz stimmt nachts für dunkle und helle Flächen nicht (Abschnitt 4).
8. Alle: `check_facade.gd` → `geruest` verlangt, dass nach einer Etappe jeder Knoten frei ist.
9. Projektleitung: niemand ruft bisher `ModelDB.release_all()` + `ModernMaterials.drop_shared()` beim Verlassen des
   Modus. `ARCHITECTURE.md` §15 beschreibt noch den Platzhalter-Renderer (Datei gesperrt).
10. Integration: die vollständigen Läufe auf dem Kopf `65c7560` nachholen (Abschnitt 3).
