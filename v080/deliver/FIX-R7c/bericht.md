# FIX-R7c – Nacharbeit nach der unabhängigen Prüfung von R7c (Fern-LOD der Bauten und Pflanzen)

- Basis: R7c `bd1803b` (`origin/wip/v080-r7c`), Prüfbericht `deliver/QA-R7c/bericht.md` (8 Befunde: 3 mittel, 5 niedrig,
  kein Blocker). Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-10`,
  Zweig `worktree-wf_ba4424b4-294-10`, gesichert als `origin/wip/v080-fix-r7c`. Endstand: `3b3107b`.
- Vergleichsbaum für die „vorher“-Messungen: `m1/FIX-R7c/ref` (= `git archive bd1803b` + `.godot`, importiert). QAs
  Bilder ließen sich daraus **bit-genau** nachstellen (Hamburg Deck 12 Uhr, zwei Bilder, und der Countdown Nürnberg –
  Fulda: 0 Pixel Unterschied, `compare -metric AE`) – die Spalte „R7c“ der Bildvergleiche ist QAs Bild desselben
  Simulationsstands.
- **gemessen** = auf dieser VM (llvmpipe unter Xvfb, 4 Kerne geteilt mit anderen Agenten); **angesehen** = Urteil nach
  Bildern; **gefolgert** = hier nicht messbar (echte GPU, Steam Deck, Wirkung auf einen Menschen).
- Dateien (alle im Besitz von R7c laut Brief): `scripts/race3d/builders/props.gd`, `scripts/race3d/modern_materials.gd`
  (eine Zeile in `GLOBALS`), `assets/shaders/modern/inc/lod_band.gdshaderinc`, `config/game_config.json`
  (`graphics.modern.props` und der `_doc`-Text), `docs/renderer-modern-gelaende.md` §9, `tests/unit/race3d/test_props.gd`,
  `tests/race3d/render/check_lod_band.gd` und `tests/golden/modern_slice.*` (nach Ansicht erneuert, Abschnitt 5). Keine eingefrorene Datei,
  kein `environment_rig.gd`, keine fremde Datei.

## 1. Ergebnis in Kürze

- **Alle acht Befunde behoben**, die drei mittleren zuerst, jeder vorher nachgestellt (gemessen bzw. bit-genau
  nachgerendert) und nachher wieder angesehen bzw. gemessen.
- **QR7c-01:** Stadthäuser behalten ihr lod0 bis 60 m („Mittel/Deck“); nur Fachwerkzeilen, Haussmann und Pariser Eckhaus
  enden bei 30 m. Der Hamburger Speicher hat bei „Steam Deck“ wieder seine Kassettentüren (Bild).
- **QR7c-06:** neues globales `ce_lod_still` – bei stehender Kamera (unter 1,5 m/s) zieht sich jedes Band in 0,4 s zu
  seinem fernen Ende zusammen: kein Raster im Countdown, im Stau, beim Polizeistopp, und im ganzen Band steht die
  feinere Stufe (die Eiche im Countdown sieht aus wie in der Basis). Render-Prüfung: 0,00 % Abweichung vom harten Wechsel.
  Die Uhr der Rampe ist `view.time` (dieselbe Ansicht zweimal gezeichnet gibt dasselbe Bild – `check_weather` hatte
  das bei der ersten Fassung mit `dt` gefunden).
- **QR7c-02:** acht neue Tests und drei neue Fälle in `check_lod_band` (zweimal „…_stand“, „fernlicht“); **alle 17
  Mutationen von QA-R7c und sechs neue werden gefangen** (vorher 6 von 17).
- **QR7c-03:** Haken von `props.gd` auf Kiel – Hamburg „Steam Deck“: Mittel 0,148 / 0,155 ms statt 0,282 / 0,264 ms,
  Max 0,50 / 1,00 ms statt 3,61 / 2,93 ms (je zwei Läufe, gemessen); Einhängen max. 1,92 / 2,78 statt 3,18 / 2,04 ms.
- **QR7c-04:** Farb-Mip-Bias je Modell: Fachwerk ab 30 m, alle anderen erst ab 60 m (voll bei 150 m) – die weißen
  Fensterrahmen in Nürnberg (~100 m) sind wieder scharf, das Flimmern bleibt für die gemessenen Häuser ≤ 2 × Sprite
  (außer dem Kontor, das mit jedem Bias 4–5 × flimmert – Geometrie).
- **QR7c-05/-07/-08:** Spielraum der Stufenknoten; `git merge-tree` mit FIX-RINT, FIX-R7a, FIX-R7b ohne Konflikt;
  Anbauten jenseits des Stücks nicht gestellt, höchstens 8 je Modell.
- **Gates (Abschnitt 5):** Import sauber, Skripte 331/0, `run_tests.sh` 816/0 (zweimal, zuletzt auf dem Endstand), Render-Prüfungen 29 von 29 OK (`check_weather` erst nach einer Korrektur dieses Pakets, siehe 5), Sicht und Wege `--full` grün, Arcade-Goldens 20 von 20 und 17 von 17 identisch, Modern-Goldens nach Ansicht erneuert.

## 2. Befunde – nachgestellt, behoben, nachgeprüft

### QR7c-01 (mittel) – Stadthäuser bei „Mittel/Steam Deck“ ab 35 m in lod1 → **behoben**

- **Nachgestellt (gemessen):** QAs Hamburg-Bild Deck 12 Uhr aus `ref` bit-genau wiederholt; der Speicher rechts steht
  bei 35–60 m in lod1 (flache Ladetüren). Ursache: `"tag:city": 35` in `graphics.modern.props.lod0_m` kürzte lod0 aller
  28 Modelle mit dem Tag `city`.
- **Fix:** `tag:city` gestrichen. lod0 endet nur noch für Fachwerkzeile, Fachwerkzeile B, Haussmann und Pariser Eckhaus
  bei 30 m („Mittel“; ihr lod0 flimmert 0,9–1,4 % gegen 0,0–0,3 % beim Sprite, von R7c gemessen); alle anderen Häuser
  behalten ihr `max_dist_m` (60 m bei „Mittel“/„Steam Deck“, 120 m bei „Hoch“ – die Entfernungen der Basis, jetzt je
  Instanz). Die Mechanik je Tag bleibt (Test `test_standing_camera_narrows_the_bands`, Mutation U11).
- **Nachgeprüft (angesehen + gemessen):** `hamburg_deck_speicher_43a1fcc_r7c_fix.png` – die grünen Ladetüren haben
  wieder ihre Kassetten, die Fenster ihre Laibungen; gegen 43a1fcc (vor R7c) unterscheiden sich im ganzen Bild nur
  432 Pixel um mehr als 15 %, gegen R7c 25 139 (2,5 % – QAs Maß). `test_lod_bands_per_model` prüft die Konfiguration
  (Speicher, Kontor, Gründerzeit, Grachtenhaus: kein Ersatz; die vier: 30 m).
- **Rest (Vertragsfrage, Abschnitt 7):** lod0 von Grachtenhaus (0,6 / 0,7 % bei 40 / 60 m) und Chalet (0,4 / 0,7 %)
  flimmert über 2 × Sprite (0,1–0,2 %); ich habe dem Look Vorrang gegeben, wie QA empfiehlt.

### QR7c-06 (mittel) – Raster bei stehender Kamera → **behoben**

- **Nachgestellt (gemessen):** Countdown Nürnberg – Fulda km 0, Deck, 1,5 s aus `ref` bit-genau wie QA; die Eiche
  unten rechts steht im Band 53–67 m und zeigt das geordnete Raster zweier Stufen.
- **Fix (Zeitblende ohne Instanz-Uniform):** neues globales `ce_lod_still` (in `ModernMaterials.GLOBALS`, Vorgabe 0).
  `props.gd` misst in `update()` die Geschwindigkeit der Kamera entlang der Straße: unter 1,5 m/s wächst `ce_lod_still`
  in 0,4 s auf 1, beim Anfahren fällt es ebenso auf 0 (`still_step()`; 0,4 s wie das `xfade` der Fahrzeuge, A-16);
  gesetzt nur bei Änderung; zu Beginn einer Etappe steht die Kamera (`_still` = 1), also gibt es im Countdown kein Raster.
  `inc/lod_band.gdshaderinc` zieht jedes Band zu seinem **fernen Ende** zusammen (bei 1 auf 1 mm): eine stehende Kamera
  sieht je Instanz genau eine Stufe, und zwar im ganzen Band die feinere – nicht die gröbere, wie es eine harte
  Entscheidung in der Bandmitte (QAs Vorschlag; erster Versuch) gezeigt hätte: dort stand die Countdown-Eiche glatt,
  aber in lod1 kantiger als in der Basis. Beide Nachbarstufen verengen dasselbe Band, bleiben also komplementär; das
  Verengen über 0,4 s ist selbst ein Überblenden durch dasselbe Raster; der Schattendurchgang folgt dem verengten Band
  (es wirft die sichtbare Stufe). Bei `ce_lod_still` = 0 läuft derselbe Code wie bei R7c (eigener Zweig, kein
  Rundungsunterschied).
- **Nachgeprüft:** Render-Prüfung `check_lod_band` „lod_ueberblenden_stand“ und „lod_baum_stand“: mit `ce_lod_still` = 1
  weicht kein Schritt der Fahrt durch das Band vom harten Wechsel am Bandende ab (0,00 % der Pixel, Grenze 1 %;
  gemessen); in Fahrt unverändert 0,6 % gegen 7,1 % (Barock) und 1,1 % gegen 36,6 % (Eiche). Mutationen „Stand aus“
  (R7) und „Bandmitte statt Ende“ (R8) werden rot (6,5 % / 7,1 %). Angesehen: `start_countdown_deck_basis_r7c_fix.png`
  (2×) – die Eiche steht glatt und in derselben Stufe wie in der Basis.
- **Uhr der Rampe:** erst `dt` des Hakens; `check_weather` „teilchen“ zeichnet dieselbe Ansicht zweimal und verlangt
  dasselbe Bild – dazwischen wuchs `ce_lod_still` (17 / 18 Pixel anders bei „Steam Deck“). Jetzt ist die Uhr
  `view.time` (Regel 10; `dt` nur ohne sie), dieselbe Ansicht ändert nichts (`b22b90b`, Test). Ein angehaltenes Spiel
  (Zeit steht) behält damit den Zustand vor der Pause.

## 3. Wachen und die niedrigen Befunde

### QR7c-02 (mittel) – Wachen der R7c-Regeln → **behoben**

Neue Tests in `tests/unit/race3d/test_props.gd` (am Dateiende, damit der Zusammenbau mit FIX-RINT nicht kollidiert;
eigener Helfer `_shader_code()`, weil FIX-RINT `_code_only()` in dieselbe Datei bringt):

| Test | bewacht (QA-Mutation) |
|---|---|
| `test_far_light_reaches_the_materials` | Fernlicht-Wert der Konfiguration (Klasse 0,78, Haussmann 0,72) und `shadow_far` (102, 120) auf den Materialien eines werfenden Gebäudes; ohne Schattenwurf volle Sonne (U7) |
| `test_shader_rules_of_the_far_lod` | Shadertext ohne Kommentare: Fernlicht-Gesetz in `ce_far_attenuation` (R3), `light()` von `baked` nimmt es, Alphatest mit `cutout_bias` (R5), Fensterdeckung `cover_k` in `ALBEDO` (R4), Farb-Mip-Bias, Relief nachts (R6), Wiegen aus der Instanzphase, nicht aus der Weltlage (U8), `ce_lod_still` |
| `test_instance_phases_differ` | 16 Gegenstände ≥ 14 verschiedene Phasen; zwei Windräder einer Gruppe nicht im Gleichschritt (U3) |
| `test_ground_sink_and_align_on_a_slope` | sucht einen Hang im synthetischen Gelände (≥ 5 cm Gefälle im Fußkreis), `sink_height` = unabhängig gerechnetes Minimum, der Fels steht dort; Heide geneigt (0,5–30°) zur Geländenormalen hin (U4, U5) |
| `test_attachments_respect_the_corridor_and_the_chunk` | Test-Manifest: angebaute Eiche an einer Stelle im Kurvenkorridor (gesucht, unabhängig vom Gesetz des Korridors – auch nach FIX-R7a/A-17 gültig) fällt weg, das Haus (Ereignis) steht (U10); Anbau jenseits des Stücks nicht gestellt (QR7c-08) |
| `test_standing_camera_narrows_the_bands` | `still_step()` Rampe 0,4 s, Builder folgt der Kamera (30 m/s → 0, Stand → 1), Tag-Ersatz `tag:<tag>` wirkt (U11, seit QR7c-01 ohne Eintrag in der Konfiguration) |
| `test_chunk_lod_walks_only_at_thresholds` | Schwellen der Stücke, kein Schlüsselwechsel ohne gekreuzte Schwelle (QR7c-03), lod0 schon 1 m vor seinem Band an (QR7c-05) |
| `test_albedo_bias_per_model` | Farb-Mip-Bias je Modell aus der Konfiguration auf den Materialien (QR7c-04) |

Render-Prüfung `check_lod_band`: neu „lod_ueberblenden_stand“, „lod_baum_stand“ (QR7c-06) und „fernlicht“ (QA-Vorschlag f:
Haussmann lod1 bei 60 / 140 / 250 m in ±5 %, ohne Fernlicht nachweislich nicht); die Grenze des größten Schritts im
Band von 35 % auf 15 % des harten Wechsels (fängt den gerasterten Schattendurchgang R2: 1,2 % gegen 0,6 %).

**Nachgeprüft mit QAs Mutationen (gemessen, `sh/mutate.py` im Arbeitsbaum, Datei nach jedem Lauf aus dem Speicher
zurück, danach `git status` sauber):**

| Mutation (QA-R7c, eine Zeile) | vorher (QA) | jetzt | fängt |
|---|---|---|---|
| U1 Bänder versetzt | gefangen | gefangen | `test_chunk_lod_shows_one_representation` |
| U2 Knoten immer an | gefangen | gefangen | dto. |
| U3 Phase konstant | grün | **gefangen** | `test_instance_phases_differ` |
| U4 `ground_sink` wirkungslos | grün | **gefangen** | `test_ground_sink_and_align_on_a_slope` |
| U5 `ground_align` wirkungslos | grün | **gefangen** | dto. |
| U6 Anbau nicht gespiegelt | gefangen | gefangen | `test_model_attachments` |
| U7 `far_sun` nicht aus der Konfiguration | grün | **gefangen** | `test_far_light_reaches_the_materials` |
| U8 Wiegen aus der Weltlage | grün | **gefangen** | `test_shader_rules_of_the_far_lod` |
| U10 Anbau ohne `drop_reason()` | grün | **gefangen** | `test_attachments_respect_the_corridor_and_the_chunk` |
| U11 Tag-Ersatz wirkungslos | gefangen | gefangen | `test_standing_camera_narrows_the_bands` |
| R1 kein Raster im Band | gefangen | gefangen | `check_lod_band` (…_stand 6,1 %) |
| R2 Schattendurchgang gerastert | grün | **gefangen** | `check_lod_band` „lod_ueberblenden“ 1,2 % > 15 % von 7,1 % |
| R2b Schatten-Entscheid in der Bandmitte | gefangen | gefangen | `check_lod_band` 9,3 % |
| R3 Fernlicht im Shader aus | grün | **gefangen** | `test_shader_rules_of_the_far_lod` und `check_lod_band` „fernlicht“ (+12 %) |
| R4 Fensterdeckung aus | grün | **gefangen** | `test_shader_rules_of_the_far_lod` |
| R5 Alphatest ohne `cutout_bias` | grün | **gefangen** | dto. |
| R6 Relief nachts nicht zurück | grün | **gefangen** | dto. |
| neu U12 ohne Spielraum der Knoten (QR7c-05) | – | gefangen | `test_chunk_lod_walks_only_at_thresholds` |
| neu U13 `ce_lod_still` nie 1 (QR7c-06) | – | gefangen | `test_standing_camera_narrows_the_bands` |
| neu U14 Anbau jenseits des Stücks (QR7c-08) | – | gefangen | `test_attachments_respect_the_corridor_and_the_chunk` |
| neu U15 ein Farb-Bias für alle (QR7c-04) | – | gefangen | `test_albedo_bias_per_model` |
| neu R7 Stand im Shader aus, R8 Bandmitte statt Ende | – | gefangen | `check_lod_band` …_stand 6,5 / 7,1 % |

17 von 17 (QA: 6 von 17), dazu 6 neue; Logs `m1/FIX-R7c/logs/mut_unit.out`, `mut_render.out`, `mut_render2.out`,
`m1/FIX-R7c/mutlogs/`. (U-Mutationen und R1–R6 liefen auf `60d4ec0`, R2 erneut mit der verschärften Grenze auf `eb97a98`; das Verengen zum
fernen Ende danach betrifft nur `lod_band.gdshaderinc` – dafür liefen R7/R8, `test_props` und `check_lod_band` erneut
auf dem Endstand.)

### QR7c-03 (niedrig) – Haken von `props.gd` teuer, Spitzen bis 4,4 ms → **behoben**

- **Nachgestellt (gemessen):** Kiel – Hamburg „Steam Deck“ mit `ref` (R7c): Haken `props` Mittel 0,28 ms, Max 3,61 ms
  (QA: 0,25–0,27 / 3,8–4,4).
- **Fix:** `_apply_lod()` geht nur noch über die Kinder eines Stücks, wenn dessen Spanne eine seiner Schwellen kreuzt
  (`_thresholds()`: Bandanfänge − 2 m gegen die fernste Instanz, Bandenden + 2 m und Reichweite der Schattenwerfer
  gegen die nächste, die Stufen der Meta „lod“; sortiert, `bsearch`). Vorher war der Schlüssel die auf 1 m gerundete
  Spanne, die sich bei jedem Blick änderte. Die fernste Ecke des Kastens ohne Schleife (je Achse das fernere Ende).
  `quality_lowered()` rechnet die Schwellen neu.
- **Nachgeprüft (gemessen, je zwei Läufe, gleiche VM, abwechselnd):** Tabelle in Abschnitt 4 – Haken `props` Mittel
  0,148 / 0,155 ms statt 0,282 / 0,264 ms, Max 0,50 / 1,00 ms statt 3,61 / 2,93 ms; Einhängen Max 1,92 / 2,78 statt
  3,18 / 2,04 ms. `ERGEBNIS` identisch (Regel 3). Test `test_chunk_lod_walks_only_at_thresholds`.

### QR7c-04 (niedrig) – ferne Fassaden weicher → **behoben (mit Maß)**

- **Nachgestellt (angesehen):** Nürnberg km 102,0 Hoch 12 Uhr: die weißen Fensterrahmen des Barockhauses (~100 m) grau.
- **Gemessen (sparkcam, lod1, „Mittel“, 60 / 100 / 150 m, Anteil kippender Pixel je Viertelpixel-Schritt):**

| Modell | ohne Farb-Bias | 1,25 von 30–120 m (R7c) | 1,25 von 60–150 m (FIX) | Sprite |
|---|---|---|---|---|
| Barockhaus | 0,2 / 0,5 / 1,0 | 0,2 / 0,2 / 0,4 | 0,2 / 0,3 / 0,4 | 0,1 / 0,3 / 0,4 |
| Grachtenhaus B | 0,4 / 0,5 / 0,9 | 0,3 / 0,3 / 0,5 | 0,4 / 0,4 / 0,5 | 0,2 / 0,2 / 0,4 |
| Speicher | 0,2 / 0,2 / 0,4 | 0,1 / 0,1 / 0,3 | 0,2 / 0,2 / 0,3 | 0,1 / 0,2 / 0,2 |
| Gründerzeit | 0,2 / 0,2 / 0,3 | 0,1 / 0,2 / 0,2 | 0,2 / 0,2 / 0,2 | 0,1 / 0,2 / 0,4 |
| Kontor | 0,3 / 0,5 / 0,9 | 0,2 / 0,5 / 0,9 | 0,3 / 0,5 / 0,9 | 0,1 / 0,1 / 0,2 |
| Fachwerkzeile | 0,2 / 0,6 / 1,1 | 0,2 / 0,4 / 0,9 | (bleibt 30–120 m) | 0,1 / 0,2 / 0,4 |

  Ganz ohne Bias (QAs erster Vorschlag „nur Fachwerk“) flimmern Barockhaus (2,5 × Sprite bei 150 m) und Grachtenhaus B
  (2,25 ×) über Leitentscheid 3 – deshalb bleibt der Bias, beginnt aber erst bei 60 m und ist bei 150 m voll (bei 100 m
  0,52 statt 1,09 Stufen). Das Kontor flimmert mit jedem Bias 4–5 × Sprite – Kanten der Geometrie (Asset-Paket).
- **Fix:** `graphics.modern.props.albedo_bias` = {"default": [1,25, 60, 150], Fachwerkzeile / B: [1,25, 30, 120]};
  `props.gd` setzt `albedo_bias` und `albedo_bias_m` je Modell (`albedo_bias_of()`), `PROP_LOOK` trägt den Bias nicht mehr.
- **Nachgeprüft (angesehen):** `nuernberg_hoch_fernhaus_arcade_basis_r7c_fix.png` (3×): die Rahmen sind wieder weiß und
  scharf wie in der Basis.

### QR7c-05 (niedrig) – Stufenknoten bis 2 m zu spät → **behoben**

`n3.visible = span.y >= b.x - LOD_STEP_M and span.x <= b.w + LOD_STEP_M` (QAs Zeile); Test
`test_chunk_lod_walks_only_at_thresholds` (lod0 schon 1 m vor seinem Band an) und Mutation U12 (ohne Spielraum: rot).

### QR7c-07 (niedrig) – Konflikt mit FIX-RINT in `test_props.gd` → **behoben**

Die Notiz über `test_chunk_lod_shows_one_representation` (R7c hatte zwei `##`-Zeilen genau dort eingefügt, wo FIX-RINT
`_code_only()` einfügt) steht jetzt in der Funktion; neue Tests am Dateiende, neuer Helfer heißt `_shader_code()`.
`git merge-tree --write-tree HEAD origin/wip/v080-fix-rint` (3248211): **Exit 0, kein Konflikt**; ebenso mit
`origin/wip/v080-fix-r7a` und `origin/wip/v080-fix-r7b` (gemessen). Zusätzlich in den Bäumen der Zusammenführung (gemessen, `git archive` des `merge-tree`-Ergebnisses + Import): mit FIX-RINT Skripte 331/0 und `test_props` 26/0 (FIX-RINTs `_code_only()` und mein `_shader_code()` nebeneinander), mit FIX-R7a (Korridor nach A-17) Skripte 334/0 und `test_props` 26/0 – der Anbau-Korridor-Test sucht seine Stelle selbst und gilt auch mit der Hülle von A-17.

### QR7c-08 (niedrig, latent) – Anbauten jenseits des Stücks → **behoben**

Ein Anbau, dessen z außerhalb [seg_a, seg_b) des eigenen Stücks läge, wird nicht gestellt (Boden und Kurvenkorridor wären
die der Randreihe; das Nachbarstück sieht das Haus nicht); höchstens `ATTACH_MAX` = 8 Anbauten je Modell (Nummern
`item × 8 + k` bleiben getrennt). Test im Test-Manifest (Haus 2 m vor dem Stückende, Anbau 6 m weiter: nicht gestellt),
Mutation U14 rot. Folge: Versätze von wenigen Metern verlieren den Anbau nur am Ende eines Stücks – notiert für das
Asset-Paket, das `attach` als erstes nutzt.

## 4. Leistung – ganze Etappe Kiel – Hamburg mit Autopilot, „Steam Deck“ 1280×800 (gemessen)

`tests/race/run_stage.gd -- --graphics=modern --gfx-preset=deck --stage=kiel_hamburg --from=kiel --vehicle=limousine
--hour=12 --weather=normal --seed=11 --timescale=20`, Xvfb, llvmpipe, gemeinsamer Mesa-Cache (je Baum ein Aufwärmlauf
Würzburg – Nürnberg verworfen), abwechselnd FIX-R7c (`fix`) und R7c `bd1803b` (`ref`) – `sh/perf.sh`, Logs
`m1/FIX-R7c/perf/`. Zeichenaufrufe und Primitive: letztes Bild (Ziel in Hamburg).

| Lauf | Bildzeit Median / p95 ms | render() Mittel / Max ms | Stück einhängen Max ms | collect() Mittel / Max ms | collect props Max ms | Haken props Mittel / Max ms | Zeichenaufrufe | Primitive / Schatten | Fehler | ERGEBNIS time_s |
|---|---|---|---|---|---|---|---|---|---|---|
| kh_deck_fix_1 | 756 / 924 | 3.00 / 9.74 | 1.92 | 1.66 / 3.94 | 0.083 | 0.148 / 0.50 | 138 | 165471 / 8364 | 0 | 326.3 |
| kh_deck_fix_2 | 770 / 917 | 3.08 / 11.71 | 2.78 | 1.73 / 2.92 | 0.080 | 0.155 / 1.00 | 138 | 165471 / 8364 | 0 | 326.3 |
| kh_deck_ref_1 | 788 / 941 | 3.31 / 17.37 | 3.18 | 1.83 / 3.67 | 0.158 | 0.282 / 3.61 | 132 | 136993 / 8364 | 0 | 326.3 |
| kh_deck_ref_2 | 745 / 916 | 3.11 / 8.53 | 2.04 | 1.70 / 3.09 | 0.096 | 0.264 / 2.93 | 132 | 136993 / 8364 | 0 | 326.3 |
| warm_fix | 444 / 964 | 5.56 / 14.66 | 2.37 | 1.94 / 7.48 | 2.249 | 0.116 / 1.25 | 151 | 174509 / 8448 | 0 | 299.8 |
| warm_ref | 422 / 963 | 5.13 / 14.19 | 2.54 | 1.72 / 3.72 | 2.211 | 0.133 / 0.65 | 151 | 174509 / 8448 | 0 | 299.8 |

- **Haken `props`:** im Mittel halbiert (0,15 statt 0,27 ms), Spitzen 0,5–1,0 statt 2,9–3,6 ms. Er liegt noch über den
  0,10 ms vor R7c (QA): die Spanne jedes Stücks wird weiter alle 2 m gerechnet (ein `AABB`-Transform und zwei
  Vektorrechnungen je Stück) – über die Kinder läuft er nur noch an Schwellen.
- **Primitive im Zielbild +21 %** (165 471 statt 136 993): die Hamburger Stadthäuser zeigen bis 60 m wieder lod0
  (QR7c-01); 43a1fcc (vor R7c) hatte dort 158 344 (QA). Weit unter dem Deck-Budget von 450 000 (§4.10). Zeichenaufrufe
  138 statt 132 (Budget 650).
- `render()` Mittel 3,00 / 3,08 ms gegen 3,31 / 3,11 ms – gleich im Rahmen des Lärms; Bildzeit gleich.
- `collect()` aller Bausteine max. 2,9–3,9 ms – in beiden Bäumen über den 2 ms von A-18 (der Anteil von `props` ist
  0,08 ms; nicht von R7c/FIX-R7c, notiert).
- `ERGEBNIS` aller Läufe identisch (time_s 326,3; Regel 3), 0 Fehlerzeilen.

## 5. Gates auf dem Endstand

Alle Läufe auf dieser VM, Logs `m1/FIX-R7c/gates/`; `XDG_DATA_HOME` absolut unter `m1/FIX-R7c/`.

| Gate | Befehl | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, keine Fehlerzeile |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | „331 Skripte geprüft, 0 fehlerhaft“ |
| Tests (zweimal voll) | `tools/run_tests.sh` | auf `d20ea92`: Exit 0 – 816 Tests, 0 fehlgeschlagen, alle CHECK-Dateien OK (1000 s); **auf dem Endstand `3b3107b` (nach der Uhr-Korrektur `b22b90b`): Exit 0 – 816 Tests, 0 fehlgeschlagen, „Tests bestanden (965 s)“** (808 + 8 neue) |
| Render-Prüfungen | `tools/run_render_checks.sh all` | **29 von 29 Dateien OK** – in drei Läufen, weil `run_render_checks.sh all` an der 2-h-Grenze meines Hintergrundauftrags nach 16 Dateien (alle OK, `gates/render_checks.log`) abgebrochen wurde; die übrigen 13 einzeln (`render_checks_2.log`, `render_checks_3.log`), jede in der Zeitgrenze ihres Kopfes. Dabei fand **`check_weather` „teilchen“ einen Fehler dieses Pakets**: die Prüfung zeichnet dieselbe Ansicht zweimal und verlangt dasselbe Bild; mit `dt` als Uhr wuchs `ce_lod_still` zwischen den beiden Aufrufen (17 / 18 Pixel anders bei „Steam Deck“, Regen / Schnee). Korrigiert in `b22b90b` (die Uhr ist `view.time`, Regel 10; Test dazu) – danach `check_weather` OK, und R7c (`ref`) im selben Lauf ebenfalls OK (A-11). Nach `b22b90b` liefen `check_weather`, `check_weather_tabelle_schnee`, `check_lod_band`, `check_start_km0` und `check_session_modern` erneut: OK (`check_weather_tabelle` lief noch mit dem Stand davor: OK). Darunter die Wächter des ersten Testbuilds: `check_start_km0`, `check_terrain_cover` (mit K1), `check_light_base` OK; `check_instance_budget*` OK. `check_lod_band`: lod_ueberblenden 0,6 % gegen hart 7,1 %, lod_baum 1,1 % gegen 36,6 %, beide …_stand 0,00 %, fernlicht +3,7 / +3,9 % (ohne +11,9 / +12,2 %). |
| Sicht | `godot --headless -s res://tests/sim/modern_sight.gd -- --full` | Exit 0: F1 0 Fälle bis 270 m in 99 424 500 Stichproben (128 Etappenrichtungen), Spuren 0 bis 260 m, F2 höchstens 0,593 / 0,596 / 0,555, F3 Modern p10/p50 186/534 m (Arcade 180/510), F7 0 von 2 011 532 Querschnittsseiten |
| Wege | `godot --headless -s res://tests/sim/modern_path_check.gd -- --full` | Exit 0: kleinster Abstand 267,6 m, Schleifen OK |
| Modern-Goldens | `tools/golden.sh modern-check` (Bilder behalten) | vor der Erneuerung 0 von 6 identisch – **gewollt**: R7c `ref` gibt im selben Lauf 6 von 6 identisch, der Unterschied FIX-R7c gegen R7c ist in fünf Bildern unter 40 Stufen (0,01–11 % der Pixel um 1–40 Stufen: Farb-Bias ab 60 m), nur `modern_s4_mittel` 0,19 % über 40 Stufen – dort ist das gerasterte Garagentor des nahen Hauses (R7c: Band bei 35 m) wieder glatt (angesehen, `modern_golden_s4_r7c_fix_differenz.jpg`). Danach `tools/golden.sh modern-make` auf `b22b90b` (727 s): 6 Hashes, die Bilder byte-gleich mit den angesehenen (`cmp`), Commit `3b3107b`. |
| Arcade-Identität (einmal, am Ende) | `tools/golden.sh check` | Exit 0 auf `3b3107b`: **„GOLDEN arcade: 20 von 20 identisch“ (160 s), „GOLDEN arcade-ui: 17 von 17 identisch“ (189 s)** |
| Etappe mit Autopilot | `tests/race/run_stage.gd` Kiel – Hamburg „Steam Deck“ (Abschnitt 4) und Würzburg – Nürnberg | 3 Läufe FIX-R7c ohne Skript- oder Shaderfehler, `ERGEBNIS` gleich R7c |
| Zusammenbau-Probe | `git merge-tree --write-tree HEAD origin/wip/v080-<zweig>` | `fix-rint` (3248211), `fix-r7a`, `fix-r7b`: Exit 0, kein Konflikt; in den Bäumen mit FIX-RINT und FIX-R7a: Skripte 331/0 bzw. 334/0, `test_props` 26/0 |

## 6. Bilder (angesehen; Arcade | R7c `bd1803b` | FIX-R7c, gleicher Simulationsstand)

Alle Modern-Bilder aus diesem Baum mit dem Renn-Aufruf von QA-R7c (`--gfx-sync`, Seed 11, Autopilot, Start 50 km/h,
Bilder 2 s und 4 s nach dem Start; Countdown: Bild bei 1,5 s), Arcade und R7c aus QAs Lieferung (bit-genau
nachgestellt). „Pixel anders“ = Pixel, die sich gegen R7c um mehr als 15 % unterscheiden (`compare -fuzz 15%`).

| Bild | gegen R7c (gemessen) | angesehen: gegen R7c / Basis | gegen Arcade |
|---|---|---|---|
| `hamburg_deck_speicher_43a1fcc_r7c_fix.png` (QR7c-01; 43a1fcc \| R7c \| FIX, Ausschnitt 1:1) | 2,5 % des Bildes (25 139 px), gegen 43a1fcc nur 432 px | **behoben:** die grünen Ladetüren des Speichers haben wieder ihre Kassetten, Fensterlaibungen mit Tiefe – wie vor R7c | besser: Backstein und Türen plastisch (Arcade: flaches Sprite) |
| `hh_deck_h12_tri_00/01.jpg` | 25 139 / 12 757 px | wie oben; sonst gleich | besser (Tiefe, Gehweg, Bäume) |
| `start_countdown_deck_basis_r7c_fix.png` (QR7c-06; Basis \| R7c \| FIX, 2×) | gegen die Basis 2 342 px | **behoben:** die Eiche unten rechts steht glatt und in lod0 wie in der Basis, kein Raster | gleich bis besser |
| `start_nu_deck_h12_tri_00.jpg` | 1 567 px | wie oben | gleich bis besser (Starttor, Bäume plastisch) |
| `start_nu_high_h12_tri_00.jpg` | 318 px | gleich (bei „Hoch“ liegen die Bänder bei 120 m; dort steht im Countdown keine Instanz im Band) | besser (Starttor, Bäume plastisch) |
| `nuernberg_hoch_fernhaus_arcade_basis_r7c_fix.png` (QR7c-04; Arcade \| Basis \| R7c \| FIX, 3×) | 2 582 px (Bild 00) | **behoben:** die weißen Fensterrahmen des fernen Barockhauses (~100 m) sind wieder weiß und scharf wie in der Basis; R7c grau und verwaschen | besser: Volutengiebel, Erker und Gauben plastisch |
| `nu_high_h12_tri_00/01.jpg`, `nu_deck_h12_tri_00/01.jpg` | 2 582 / 44 px; 276 / 10 400 px | Hoch: gleich bis auf das ferne Haus; Deck: das rosa Barockhaus rechts bis 60 m in lod0 (QR7c-01) | besser: Fachwerk plastisch, Gehweg, Laternen |
| `pa_deck_h12_tri_*`, `pa_high_h12_tri_*` | 0–2 px | gleich (Haussmann und Eckhaus enden weiter bei 30 m) | besser: Haussmann 3D, Kaimauer, Geländer |
| `hh_high_h12_tri_*`, `am_high_h12_tri_*` | 874–978 px; 1 557–1 905 px | gleich; ferne Giebel minimal schärfer | Hamburg besser; Amsterdam besser bis gleich (Grachtenhäuser, Hausboote) |

Ehrlich: Nachts (F-04, Nachtatlas der Modelle), im Lyon-Vorort und im Wald (Korridor, R7a) bleibt Modern hinter Arcade,
wie QA-R7c es für R7c festgestellt hat – FIX-R7c ändert daran nichts (nicht in diesen Befunden, nicht neu
angesehen). Das Kontor flimmert in lod1 bei 100–150 m 4–5 × so stark wie sein Sprite (Geometrie, Asset-Paket).

## 7. Abweichungen und Vertragsfragen

- **Leitentscheid 1 gegen 3 (QR7c-01, Vertragsfrage):** Stadthäuser außer Fachwerk/Paris behalten lod0 bis 60 m
  („Mittel“), obwohl lod0 von Grachtenhaus (0,6 / 0,7 % bei 40 / 60 m) und Chalet (0,4 / 0,7 %) mehr als 2 × ihr Sprite
  (0,1–0,2 %) flimmert (R7c gemessen). Ich habe dem Look Vorrang gegeben, wie QA-R7c empfiehlt (lod1 des Speichers ist
  Sprite-Niveau); die Leitung sollte das bestätigen oder die Asset-Pakete die Kassetten in lod1 backen lassen.
- **A-16 Zeitblende (QR7c-06):** jetzt ein Mischweg ohne Zustand je Instanz: in Fahrt das Wegband (wie R7c), bei
  stehender Kamera eine echte Zeitblende von 0,4 s über das globale `ce_lod_still` (keine Instanz-Uniform, A-19 bleibt).
  Statt der von QA vorgeschlagenen harten Entscheidung in der **Bandmitte** zieht sich das Band zu seinem **fernen Ende**
  zusammen – so steht beim Stand die feinere Stufe (Countdown-Bild wie die Basis). Neue globale Variable in
  `ModernMaterials.GLOBALS` (Datei im Besitz von R7c; ein Steckplatz des globalen Puffers).
- **A-22 `max_dist_m` in `model.json`:** weiter über `graphics.modern.props.lod0_m` je Modell (Besitz der Asset-Pakete,
  wie bei R7c); der Tag-Ersatz `tag:city` ist gestrichen, die Mechanik je Tag bleibt (Test).
- **Leitentscheid 3, Farb-Bias:** neuer Konfigurationsschlüssel `graphics.modern.props.albedo_bias` (je Modell
  [Stufen, von, bis]) – gemessen gewählt (Abschnitt 2, QR7c-04).
- **QR7c-08:** Anbauten jenseits des eigenen Stücks werden ausgelassen statt dem Nachbarstück übergeben – das Nachbarstück
  sieht die Gegenstände dieses Stücks nicht (`ChunkContext.segs` reicht nur eine Reihe weiter; Kern, nicht meine Datei).
- **A-18 Modern-Goldens:** der Brief erlaubt `modern-make`, wo ein Modern-Golden gewollt anders ist; ich habe die Bilder vorher angesehen (Abschnitt 5) und erneuert – die Montage erneuert sie ohnehin.
- `check_lod_band`: Grenze des größten Schritts von 35 % auf 15 % des harten Wechsels verschärft (gemessen 8,5 %; der
  gerasterte Schattendurchgang 17 %) – wird ein Haus-Asset umgebaut, ist der Wert neu anzusehen.

## 8. Für die nächsten Pakete

1. **Zusammenbau RINT-M3:** `git merge-tree` des Endstands mit `origin/wip/v080-fix-rint`, `-fix-r7a`, `-fix-r7b` ohne
   Konflikt (gemessen). In den Zusammenführungen mit FIX-RINT und mit FIX-R7a je für sich: Skripte fehlerfrei, `test_props` 26/0 (gemessen); die Dreier-Zusammenführung habe ich nicht geprüft. Danach `tools/run_tests.sh test_props` und `tools/run_render_checks.sh modern
   check_lod_band`.
2. **Asset-Paket Stadthäuser:** lod1 des Speichers (1 283 statt 8 950 Dreiecke) mit gebackenen Türkassetten und
   Laibungen; das Kontor flimmert in lod1 bei 100–150 m 4–5 × sein Sprite (Kanten der Geometrie, der Farb-Bias hilft
   nicht); Grachtenhaus und Chalet in lod0 bei 40–60 m 3–4 × (Leitentscheid 1 gegen 3, Vertragsfrage).
3. **Asset-Paket, das `attach` als erstes nutzt:** Versätze klein halten (ein Anbau jenseits des eigenen 96-m-Stücks wird
   nicht gestellt); höchstens 8 je Modell. `H.LOD0_M` je Stil in `cities3d.py` (30 m Fachwerk/Paris) – dann
   `graphics.modern.props.lod0_m` leeren.
4. **Besitzer von `vpbr.gdshader`:** `ModernMaterials.STATIC_INJECT` in den Shader übernehmen (unverändert von R7c).
5. **`collect()` aller Bausteine** auf Kiel – Hamburg „Steam Deck“ max. 2,9–3,9 ms in R7c und FIX-R7c (A-18: 2 ms; der
   Anteil von `props` 0,08 ms) – Leitung/QA-mid.
6. **QA-mid:** den Paris-Clip und einen Clip mit Halt (Stau/Polizei) bei „Mittel“ ansehen: beim Anhalten blendet das
   Band in 0,4 s zur feineren Stufe, beim Anfahren zurück (gefolgert, hier nur als Standbild und Render-Prüfung gesehen).
7. **Nachtfenster F-04, Lyon-Vorort und Wald (R7a):** unverändert gegen Arcade schwächer – nicht von R7c/FIX-R7c.

## 9. Lieferung (`deliver/FIX-R7c/`)

| Datei | Inhalt |
|---|---|
| `bericht.md` | dieser Bericht |
| `hamburg_deck_speicher_43a1fcc_r7c_fix.png` | QR7c-01: Speicher bei „Steam Deck“, 43a1fcc (vor R7c) \| R7c \| FIX-R7c, Ausschnitt 1:1 |
| `start_countdown_deck_basis_r7c_fix.png` | QR7c-06: Countdown Nürnberg – Fulda, Basis \| R7c \| FIX-R7c, 2× |
| `nuernberg_hoch_fernhaus_arcade_basis_r7c_fix.png` | QR7c-04: fernes Barockhaus, Arcade \| Basis \| R7c \| FIX-R7c, 3× |
| `<ort>_<stufe>_h12_tri_NN.jpg` | Arcade \| R7c \| FIX-R7c: `hh_deck`, `hh_high`, `nu_high`, `nu_deck`, `pa_deck`, `pa_high`, `am_high`, `start_nu_deck`, `start_nu_high` |
| `modern_goldens_r7c_fix_differenz.jpg` | die sechs Modern-Goldens: R7c \| FIX-R7c \| Differenz × 4 |
| `modern_golden_s4_r7c_fix_differenz.jpg` | modern_s4_mittel vergrößert (das einzige mit Änderungen über 40 Stufen: das gerasterte Garagentor von R7c ist glatt) |

Werkzeuge und Rohdaten (ungetrackt): `m1/FIX-R7c/sh/` (`shot.sh`, `pics.sh`, `perf.sh`, `mutate.py`, `kt.sh`,
`queue*.sh`), `m1/FIX-R7c/py/` (`perftab.py`, `gmdiff.py`), `m1/FIX-R7c/kt/fx_scene.gd` (sparkcam mit den Uniforms der
Requisiten; braucht R7cs Kopien in `m1/R7c/kt`), Logs `m1/FIX-R7c/logs/`, `gates/`, `perf/`, `mutlogs/`, `kt_out/`.
