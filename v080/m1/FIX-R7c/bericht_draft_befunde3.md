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
