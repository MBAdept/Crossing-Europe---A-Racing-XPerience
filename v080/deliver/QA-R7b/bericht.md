# QA-R7b – unabhängige Prüfung von R7b (Wahrzeichen, Skyline, Hintergrund)

Geprüfter Stand: `2c154bc` (origin/wip/v080-r7b) gegen die Basis `9b02f05` (RINT-M2). Arbeitsbaum
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-4` (nur `merge --ff-only 2c154bc`,
keine Commits, kein Push). Basis als Kopie ohne Git (`git archive 9b02f05` + Importcache): `m1/QA-R7b/base`;
Mutationskopie von `2c154bc`: `m1/QA-R7b/mut` (beide Kopien nach der Prüfung gelöscht; neu anlegen mit `m1/QA-R7b/sh/make_base.sh` / `make_mut.sh`). Pfade unten relativ zu
`/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/`.

„gemessen“ = auf dieser VM (llvmpipe unter Xvfb, vier geteilte Kerne; Last 6–10 durch andere Pakete während der
ganzen Prüfung – Zeitmaxima sind darum verrauscht); „gefolgert“ = hier nicht messbar (Steam Deck, echte GPU, wie es
auf einen Menschen wirkt).

## Kurz

**Urteil:** R7b ist solide und darf mit zwei kleinen Nacharbeiten (B-01, B-02, je wenige Zeilen) in RINT-M3. Kein
Blocker, nichts Gebrochenes: Arcade 20/20 + 17/17 identisch, `run_tests.sh` voll grün, Fairness `--full` grün,
Render-Auswahl 6/6, Datenscan aller 143 Wahrzeichen in 128 Etappenrichtungen ohne Abweichung von Arcade, Dateibesitz
eingehalten (eine gemeldete fremde Testdatei). Die neuen Prüfungen wachen (16 von 18 Mutationen erkannt).

**Bild gegen Arcade (ehrlich):** besser als die Basis überall, wo Arcade prozedural zeichnet – Dortmund, Madrid,
Calais, Hannover, Belgrad hatten breite Ersatzbilder, jetzt stehen dort echte 3D-Formen an Arcades Stelle; Hannover und
Dortmund wirken besser als Arcades flache Zeichnung. Bild-Wahrzeichen bei Tag gleich Arcade. **Schlechter als
Arcade:** nachts die Elbphilharmonie (+28 % Luminanz, B-01, auch gegen die Basis) und das rote Flugwarnlicht (23 ×
Arcades Fläche, B-02); in der Nähe stehen Kuppelformen tiefer/seitlich (Leipzig verdeckt, Belgrad +85 px, B-05); die
ungespiegelte Kirche links steht bis 37,8 m näher an der Straße (B-04). An den meisten 600-m-Einfahrten verdecken
Häuser das Wahrzeichen in allen Modi – dort ist kein Unterschied zu sehen.


## 1. Gates und Funktion

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Import | Exit 0 | `m1/QA-R7b/import.log` |
| `tools/run_tests.sh` (voll, einmal) | **bestanden** (945 s): 334 Skripte / 0 fehlerhaft, 811 Einheitstests / 0 fehlgeschlagen (8 in `test_landmarks.gd`), alle `tests/race3d/check_*.gd` OK, darunter `check_landmarks` 6/6 und `check_minimal_structures` „wahrzeichen“ (verweist auf den Builder); gehalten: `test_far_ground_water`, `test_props` | `m1/QA-R7b/gates/run_tests.log` |
| Datenscan aller 128 Etappenrichtungen (eigenes Skript) | **143 Wahrzeichen, 0 Abweichungen** von Arcade in Darstellungsart, Set, Maßstab und Tönung (Arcade über `RoadRenderer._prep_prop` desselben Eintrags, Modern über `resolve_item`); jede der 42 verschiedenen Darstellungen baut headless (`_make` mit Stub-Renderer: Knoten, Netze, Materialpaare); jede Skyline-Silhouette ist zeichenbar (Bild oder Arcades prozedurale Art) | `m1/QA-R7b/scan_landmarks.log`, Skript `m1/QA-R7b/sh/scan_landmarks.gd` |
| Darstellungen im Netz | Bild 77×, Modell 46× (`props/church` 38, `props/building_tall` 5, `landmarks/michel` 3), 3D-Form 20× (Kuppelkirche 13 – Hannover, Leipzig, Belgrad aus allen Richtungen –, Fernsehturm 4, Hochhausgruppe 2, Leuchtturm 1); keine ohne Darstellung | ebd. „SCAN reps“ |
| Ankerversatz gegen Arcade (alle 143) | größter 37,8 m: Magdeburger Dom (`props/church` × 2,9 links, Arcade spiegelt, Modern nie) = **44,7 px bei 600 m** (Grenze 64 px). R7b nennt 24,7 px – das gilt nur für die drei geraden Anfahrten | ebd. „groesster Ankerversatz“ |
| Gerade 640-m-Anfahrten | bestätigt: nur 3 im Netz (Burgos; Kirche vor Slavonski Brod aus beiden Richtungen) | `m1/QA-R7b/lm_km.txt` |
| Fairness `tests/sim/modern_sight.gd -- --full` | **OK**: F1 0 Fälle bis 270 m (99.424.500 Stichproben, 128 Richtungen), F1 Spuren 0 bis 260 m (326.680.500), F2 ≤ 0,593 / 0,596 / 0,555 (≤ 0,60), F3 0 von 5.923, F7 0 von 2.011.532, Modell 0 abweichend (139 s) | `m1/QA-R7b/gates/modern_sight_full.log` |
| Fairness `tests/sim/modern_path_check.gd -- --full` | **OK**: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2.064 m (≥ 2.000) | `m1/QA-R7b/gates/modern_path_check_full.log` |
| Render-Prüfungen (Auswahl, `tools/run_render_checks.sh modern <datei>`) | **6 von 6 OK**: `check_landmarks_render` (wahrzeichen_stelle 18 px, weich 0,23, nacht 659 helle Pixel, flugfeuer 242 rote Pixel), `check_start_km0`, `check_terrain_cover` (mit K1), `check_light_base`, `check_props_render`, `check_occlusion` – die Korrekturen des ersten Testbuilds halten. Die übrigen 23 Dateien nicht wiederholt (Zeit; R7b hat alle 29 auf genau diesem Stand grün gemeldet; R7b ändert keine Datei, die sie prüfen, außer dem Hintergrund) | `m1/QA-R7b/gates/rc_*.log` |
| Arcade-Identität `tools/golden.sh check` (einmal, am Ende) | **GOLDEN arcade: 20 von 20 identisch, GOLDEN arcade-ui: 17 von 17 identisch** | `m1/QA-R7b/gates/golden_check.log` |
| Regel 3 (eine Simulation) | `ERGEBNIS` Kopf = Basis auf Kiel–Hamburg und Bremen–Dortmund (Deck, Seed 7, md5 gleich) | `m1/QA-R7b/gates/perf_*_deck_12.log` |

### 1.1 Dateibesitz (git diff 9b02f05..2c154bc --stat)

13 Dateien, +2.540/−5: `builders/landmarks.gd`, `assets/shaders/modern/landmark.gdshader`, ihre Tests
(`tests/unit/race3d/test_landmarks.gd`, `tests/race3d/check_landmarks.gd`, `tests/race3d/render/check_landmarks_render.gd`)
und `.uid`-Dateien – eigene Dateien; `scripts/race3d/layers/backdrop.gd` – Ausnahme der Leitung; `docs/renderer-modern.md`
– nur neuer §18 (Doku-Abschnitt Wahrzeichen, erlaubt). **Fremd:** `tests/race3d/check_minimal_structures.gd` (+4 Zeilen,
von R7b gemeldet, sachlich nötig: die alte Prüfung „wahrzeichen“ prüfte die fernen Vertretungen von `props.gd`, die mit
dem Builder nicht mehr laufen). Keine eingefrorene Arcade-Datei, `props.gd`, `billboard/baked.gdshader` und
`config/game_config.json` unverändert. Die Ente-Typ-Weiche in `props.gd` (Zeilen 88, 122, 329, 539, 741) besteht schon
auf der Basis – nachgesehen.

### 1.2 Wächten die neuen Prüfungen ihre Regel? (je eine Zeile gebrochen, `m1/QA-R7b/sh/mutate.py`)

| # | gebrochene Regel | Prüfung | Ergebnis |
|---|---|---|---|
| M1 | Arcades Gesetz (0,72 L → 0,70 L) | `test_landmarks` | erkannt |
| M2 | Reichweite nachts bis `landmark_far_m` | `test_landmarks` | erkannt |
| M3 | Leuchtturm nicht mehr als 3D-Form | `test_landmarks` | erkannt |
| M4 | Anker der Form (Mitte wie Arcade) | `test_landmarks` | erkannt |
| M5 | Fernsehturm breit statt schlank (N2) | `test_landmarks` | erkannt |
| M6 | `instance uniform` im Shader (A-19) | `test_landmarks` | erkannt |
| M7 / M7b | Tönung fehlt im Bild- / Modellmaterial (N1) | `test_landmarks` | erkannt |
| M8 | Reichweite auf dem Pfad 900 m | `check_landmarks` reichweite, nacht | erkannt |
| M9 | kein durchscheinendes Material ab 0,70 L (B-09) | `check_landmarks` weich | erkannt |
| M10 | Skyline blendet nicht aus | `check_landmarks` skyline | erkannt |
| M11 | Anker +60 m | `check_landmarks` position | erkannt (nur über Burgos: die beiden Kirchen bleiben mit 46 px unter 64 px) |
| M12 | Weiche in `props.gd` aus | `check_landmarks` reichweite | erkannt |
| M13 | Kuppelkirche nicht als Form | `check_landmarks` prozedural | erkannt |
| M14 | Leuchtpunkt riesig | Render `flugfeuer` | erkannt |
| M15 | Anker +120 m | Render `wahrzeichen_stelle` | erkannt |
| M16 | **Anstrahlung eines Modells als Wahrzeichen entfernt** (Shader CE_ATLAS) | `test_landmarks`, `check_landmarks` nacht | **nicht erkannt** |
| M17 | **Anstrahlung eines Bildes als Wahrzeichen entfernt** (Shader CE_PICTURE) | `test_landmarks`, `check_landmarks` nacht | **nicht erkannt** |

Logs: `m1/QA-R7b/mutlogs/mutate.log`, `mutate_render.log`, `mutate_flood.log` (je Mutation ein Volllog `mut_M*.log`).

## 2. Leistung (gemessen auf llvmpipe unter Last 8–10; Steam Deck gefolgert)

**Ganze Etappe, Preset „deck“, 1280 × 800, Zeitraffer 40, Seed 7** (`tests/race/run_stage.gd`, Kopf = Arbeitsbaum,
Basis = Kopie 9b02f05; `m1/QA-R7b/gates/perf_<stand>_<etappe>_deck_12.log`, Skript `m1/QA-R7b/sh/perf.sh`):

| Etappe | Stand | render() Ø / max ms | Stück-Commit max ms | collect Ø / max ms | Draw Calls / Primitive (letztes Bild) | `landmarks` Ø / max ms | `backdrop` Ø / max ms | `props` Ø / max ms | ERGEBNIS |
|---|---|---|---|---|---|---|---|---|---|
| Kiel–Hamburg | Basis | 4,89 / 148,5 | 4,9 | 1,80 / 4,2 | 137 / 181.987 | – | 0,138 / 0,56 | 0,106 / 1,29 | gleich |
| Kiel–Hamburg | R7b | 4,30 / 19,0 | 2,1 | 1,81 / 5,7 | 137 / 181.987 | 0,050 / 0,36 | 0,182 / 3,03 | 0,051 / 0,20 | gleich |
| Bremen–Dortmund | Basis | 6,06 / 79,1 | 5,1 | 2,06 / 9,3 | 128 / 160.366 | – | 0,163 / 1,43 | 0,072 / 0,55 | gleich |
| Bremen–Dortmund | R7b | 6,70 / 352,9 | 6,2 | 2,02 / 8,1 | 128 / 160.366 | 0,046 / 2,93 | 0,179 / 4,29 | 0,053 / 1,28 | gleich |

Lesart: Mittelwerte gleich (±10 %, so weit streut die Fremdlast; Bildzeit-Median dieser Läufe 870 ms – die VM war
überbucht). Maxima einzelner Bilder sind hier Rauschen (Basis 148 ms, Kopf 353 ms ohne Zusammenhang mit dem Paket).
Wiederholbar höher im Kopf: das Maximum von `backdrop` (3,0 / 4,3 ms gegen 0,6 / 1,4 ms; die Skyline zeichnet Arcades
2D-Silhouetten beim Neuzeichnen der Leinwand) und Einzelbilder von `landmarks` bis 2,9 ms (gefolgert: das Bild, in dem
ein Wahrzeichen-Knoten mit seinen Materialien entsteht). `collect()` des Builders: 0,001 ms (A-18 ≤ 2 ms erfüllt).

**Kosten an den Einfahrten** (eigene Sonde `m1/QA-R7b/sh/lm_cost.gd`: dasselbe angehaltene Bild mit und ohne die
Wahrzeichen-Knoten, „deck“; `m1/QA-R7b/gates/lm_cost_deck.log`):

| Stelle | Draw Calls | Primitive | lebende Wahrzeichen |
|---|---|---|---|
| Hamburg km 85,6, 12 Uhr | 286 → 288 (+2) | +3.026 | Elbphilharmonie (Bild, 605 m), Michel (Modell, 765 m) |
| Hamburg km 77,4, 22 Uhr | 217 → 219 (+2) | +3.026 | beide durchscheinend (1.425 / 1.585 m) |
| Dortmund km 225, 22 Uhr | 230 → 232 (+2) | +1.018 | Florianturm (Form, 605 m) |
| Madrid km 228, 22 Uhr | 210 → 212 (+2) | +134 | Cuatro Torres (Form, 605 m) |
| Leipzig km 106,5, 12 Uhr | 321 → 325 (+4) | +4.193 | Völkerschlachtdenkmal (Form, 255 m), City-Hochhaus (Modell, 655 m) |
| Belgrad km 200, 22 Uhr | 224 → 226 (+2) | +1.638 | Hram (Form, 265 m) |

Weit unter dem Deck-Budget (650 Draw Calls, 450.000 Primitive). Keine Instanz-Uniform (Test + Mutation M6).

## 3. Code-Durchsicht (gegen Arcades eingefrorenen Code)

Gelesen: `builders/landmarks.gd` (1.051 Zeilen), `landmark.gdshader`, Diff von `layers/backdrop.gd`, die drei Prüfdateien,
§18 der Renderer-Doku; daneben `RoadRenderer._prep_prop / _resolve_set / _draw_far_landmarks / _draw_landmark /
landmark_fade / _skyline_silhouettes / _draw_skyline_landmark / _lm_tv / _lm_skyscrapers`, `Track._build_landmark`,
`props.gd` (Weiche), `modern_renderer.gd` (Haken, `rebased` an Buildern).

Stimmt mit Arcade überein (nachgerechnet): Reichweite L und Nachtreichweite, Deckung `1 − smoothstep(0,72 L, L, d)`,
Dunst `0,85 × (d − Nebelbeginn)/(L − Nebelbeginn)`, Beleuchtung `Nacht × (1 − smoothstep(0,8 F, F, d))`, Anstrahlen
0,55 × Beleuchtung für gewöhnliche Requisiten; Auswahl Set → Ersatz-Set → prozedural wie `_prep_prop`/`_resolve_set`
(für die Wahrzeichen, die `Track._build_landmark` ohne `fallback` anlegt); Anker einer prozeduralen Art = Mitte
(`x + Seite × width_m/2 × scale`); Fernsehturm: Flugwarnlichter bei 252 m fest, 300/368 m 1,5 s blinkend wie `_lm_tv`;
jedes `landmark`-Ereignis von `Track` hat sein Gegenstück in `Track.landmarks` (die Weiche in `props.gd` lässt also
nichts fallen); `rebased()` erreicht auch Builder (`_rebase_listeners` aus allen Haken).

Auffällig (Befunde in §5):
- `proc_key()` schlüsselt den Netz-Cache mit `height_m × scale`, `proc_mesh()` baut aber mit `height_m` allein; der Knoten
  trägt `scale` (`_place`). Zwei Einträge derselben Art und Farben mit gleichem Produkt, aber anderem `scale` bekämen das
  falsche Netz (heute im Netz kein solcher Fall – latent). Der Kommentar von `proc_mesh` („the node carries no scale of
  its own“) widerspricht `_place`.
- CE_ATLAS (Modelle der Klasse `baked`) strahlt eine gewöhnliche Requisite nachts nur über die **beleuchtete** Albedo an
  (`alb × flood_color × 1,6`), nicht als Licht; CE_PICTURE dagegen setzt die Farbe direkt (wie Arcade). Im Bild
  (Bremer Dom, 22 Uhr, 380 m) hebt das den Turm nur um etwa +10/255 Rot gegen die Basis; keine Prüfung wacht darüber
  (Mutationen M16/M17).
- Modelle und Formen werden mit der Straßenrichtung an ihrem Anker gedreht (`_place`, `turned`), der Vertrag sagt in D24
  „Landmarks are never mirrored **and not turned**“ – siehe Vertragsfragen.
- `KEEP_BEHIND_M` 320 m: ein passiertes Bild-Wahrzeichen bleibt bis 320 m hinter der Kamera stehen (Arcade zeichnet es
  ab z < cam_z nicht mehr); unsichtbar hinter der Kamera, kostet aber einen Draw Call – vernachlässigbar.

## 4. Bilder – ehrlich gegen Arcade und gegen die Basis

Alle Bilder: `tools/ab_shot.sh` (Arcade | Modern R7b) plus derselbe Modern-Lauf in der Basis-Kopie
(`m1/QA-R7b/sh/abc.sh`), gleicher Simulationszustand (Seed 11, Autopilot, Start 50 km/h, Bild nach 1 s – das „LOS!“
liegt in allen drei Bildern), „Details: Hoch“ 1280 × 720, Deck-Bilder Preset „deck“ 1280 × 800. Einzelbilder und Tripel
`deliver/QA-R7b/raw/<name>_{arcade,basis,modern}_00.png`, `<name>_abc.jpg`; Bögen `deliver/QA-R7b/boegen/`.
Positionen wie R7b (Einfahrt ≈ 600 m vor dem ersten Wahrzeichen, Nahbild ≈ 250 m; 1 Etappen-km = 100 m Straße).

### 4.1 Einfahrten (≈ 600 m), 12:00 und 22:00

| Stadt | Wahrzeichen | 12:00 | 22:00 |
|---|---|---|---|
| Hamburg | Elbphilharmonie (Bild), Michel (Modell) | **gleich** Arcade, Stelle gleich; R7b = Basis | Michel gleich; **Elbphilharmonie heller als Arcade und als die Basis** (Fassade Ø Luminanz 112,7 / 116,2 / 144,5, p90 178 / 178 / 197 – Befund B-01) |
| Dortmund | Florianturm (3D-Form) | **besser als die Basis** (dort ein breites Bürohochhaus mit Fensterraster), **etwa gleich Arcade**, plastischer (Kugel, Fensterring, rot-weiße Antenne); steht ≈ 45 px rechts von Arcades Zeichnung (Kurve + Kamerablick, < 64 px) | Turm und Ring wie Arcade, Schaft heller; **rotes Flugwarnlicht 17 × 19 px statt Arcades 4 × 4 px (232 gegen 10 rote Pixel)** – Befund B-02 |
| Madrid | Cuatro Torres (3D-Form) | **besser als die Basis** (dort ein dunkler Büroblock), nah an Arcade: zwei hellblaue Glastürme an derselben Stelle (± 6 px); Arcades feines Fassadenraster ist in Modern zu Geschossbändern vereinfacht | lebhafter als Arcade (mehr helle Bürofenster), Flugwarnlicht wieder ≈ 4 × Arcades Durchmesser (B-02) |
| Calais | Leuchtturm (3D-Form) | **besser als die Basis** (dort eine Kirche mit Turm als Ersatz), schlanker weißer Turm mit Laterne; in Arcade an dieser Stelle hinter einem Baum/Haus verborgen | Laterne hell, Turm angestrahlt; Basis zeigt den dunklen Kirchenumriss – besser |
| Belgrad, Hannover, Leipzig, Paris, Nürnberg | (verdeckt) | Wahrzeichen in **allen drei** Bildern hinter Häusern – kein Vergleich möglich; Rest des Bildes R7b = Basis | ebenso; unter der Horizontzeile dunkles Land, kein heller Streifen |
| Brüssel | Atomium, Koekelberg (Bilder) | in beiden Modern-Bildern sichtbar, in Arcade von einer Häuserzeile verdeckt, die Modern fehlt – **auch auf der Basis** (Stadtbauten, nicht R7b) | ebenso |

### 4.2 Gewöhnliche Requisite als Wahrzeichen nachts (`props/church`, 38 von 143 Wahrzeichen des Netzes)

`flood2_bremen_22` (Hamburg–Bremen km 114,4, Bremer Dom ≈ 380 m voraus, 22 Uhr): Arcade zeigt den angestrahlten Turm
(Ø RGB 102/106/73 im Turmfeld), die Basis 79/101/62, R7b 89/106/63 – R7b ist näher an Arcade als die Basis, bleibt
aber dunkler. Der Turm steht in Modern **≈ 63 px rechts** von Arcades Turm: Arcade spiegelt `props/church` links
(`mirror_left`), Modern nie (D24) – der Turm rückt damit um (16,08 − 3,06) m × 2,6 = 33,9 m an die Straße. Netzweit
bis 37,8 m (Magdeburger Dom, 44,7 px bei 600 m). `flood_bremen_22` (40 m davor): in Modern steht die 73 m lange,
92 m hohe Seitenwand des Kirchenmodells neben dem Gehweg, Arcade zeigt dort Bäume (die flache Karte steht außerhalb
des Bildes) – gleich auf der Basis, also nicht von R7b, aber ein Hinweis für AS6/Stadtbilder.

### 4.3 Nahbilder (≈ 250 m), 12:00 – die prozeduralen Formen

- **Hannover** (`nah_hannover_12`): **deutlich besser als die Basis** (dort eine Kirche mit Spitzturm als Ersatz) und
  **gleichwertig zu Arcade, plastischer**: Kuppelbau mit grüner Hauptkuppel, Seitenkuppeln und Fensterreihen an Arcades
  Stelle und in Arcades Größe.
- **Belgrad** (`nah_belgrad_12`, Ada-Brücke, Kurve): **besser als die Basis** (Turmkirche als Ersatz); die weiße
  Kuppelkirche mit grünen Kuppeln steht aber am rechten Bildrand, breiter und ≈ 85 px rechts von Arcades Zeichnung
  (R7b hat das selbst gemessen) – die Form ist mit der Straße an ihrem Anker gedreht und zeigt ihre Seitenwand.
- **Leipzig** (`nah_leipzig_12`): Arcade zeigt das Völkerschlachtdenkmal mit Kuppel rechts über einem Baum; in Modern
  (Basis und R7b) ist es **nicht zu sehen** – bei R7b ragt nur ein Stück graue Wand hinter dem (in Modern größeren)
  Baum hervor. Ursache (gefolgert aus der Form): die Hauptkuppel steht 22 m × 1,14 = 25 m hinter dem Anker, Arcade
  zeichnet sie am Anker; bei 255 m sitzt sie damit ≈ 22 px tiefer und 9 % kleiner und verschwindet hinter der Krone.
  **Schlechter als Arcade** an dieser Stelle (Befund B-05).

### 4.4 Nahbilder 22:00

- **Hannover**: Kuppelbau warm angestrahlt an Arcades Stelle, etwas heller als Arcades Anstrahlung – gleichwertig;
  die Basis zeigt die angestrahlte Ersatzkirche mit Spitzturm – R7b besser.
- **Belgrad**: angestrahlte Kuppelkirche wie Arcade, aber am rechten Bildrand abgeschnitten (Versatz wie bei Tag).

## 5. Befunde

Schwere: blocker = darf nicht in Testbuild 2; high = fällt sofort auf; medium = merklich; low = Feinschliff.

**B-01 (medium) – Bild-Wahrzeichen nachts heller als Arcade und als die Basis (Elbphilharmonie +28 %).**
Wo: `assets/shaders/modern/landmark.gdshader`, CE_PICTURE, `vec3 col = mix(x, lit, wl)` (Zeile ≈ 236).
Was: Das Bild und seine Lichtebene werden im **linearen** Raum gemischt (`x` und `lit` sind beide schon linearisiert);
Arcade (`_sprite_i` „base“ + „lights“ mit Alpha) und der Vorgänger `billboard.gdshader` (Zeile 168:
`mix(min(d, 1.0), l.rgb, light_cover)`) mischen im **Anzeigeraum**. Eine lineare Mischung von dunkler Fassade und
hellem Fenster ergibt sichtbar hellere Mischpixel (Beispiel 0,1/0,9 bei 50 %: 0,50 sRGB gegen 0,67).
Beleg (gemessen): `raw/hamburg_22_*` (Kiel–Hamburg km 85,6, 22 Uhr, Hoch) – Fassadenfeld (300..380, 232..268) Ø
Luminanz Arcade 112,7, Basis 116,2, **R7b 144,5**; p90 178,4 / 178,3 / 197,2; Zoom `deliver/QA-R7b/bilder/elbphilharmonie_nacht_zoom.png`.
Betrifft alle 32 Bild-Wahrzeichen mit Lichtebene nachts und in der Dämmerung (Elbphilharmonie liegt auf der Teststrecke).
Nachstellen: `m1/QA-R7b/sh/abc.sh <out> high 1280x720 --stage=kiel_hamburg --from=kiel --start-km=85.6 --hour=22 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1`.
Behebung: im Anzeigeraum mischen wie `billboard.gdshader`:
`vec3 disp = mix(min(d, vec3(1.0)), min(l.rgb, vec3(1.0)), wl); vec3 col = pow((disp + 0.055) / 1.055, vec3(2.4)) + to_lin(base) * headlight_color * v_head * (1.0 - wl);`
und eine Render-Prüfung „Bild nachts nicht heller als Arcade“ (Fassadenfeld der Elbphilharmonie ≤ 1,1 × Arcade).

**B-02 (medium) – Flugwarnlicht der 3D-Formen viel größer als Arcades Punkt.**
Wo: `builders/landmarks.gd` `_tv_tower` / `_skyscrapers` (`kit.glow(..., 0.6, 5.0, 2.5, ...)` bzw. `0.6, 3.0, 2.5`),
`landmark.gdshader` CE_GLOW (Radius `max(UV2.x, UV2.y/px_per_m)`, additiv, danach der Glow der Nachbearbeitung).
Beleg (gemessen): `raw/dortmund_22_*` (Bremen–Dortmund km 225, 22 Uhr): rote Pixel (r ≥ 110, r > 1,8 g, r > 1,8 b)
**Arcade 10 (4 × 4 px), R7b 232 (17 × 19 px)**, Spitzenwert 255; Madrid 22 Uhr gleich groß. R7b schreibt „etwa dreimal“
– es sind ≈ 4,5 × im Durchmesser, 23 × in der Fläche. Die Prüfung `flugfeuer` begrenzt nur nach oben auf 3 % des Bildes.
Behebung: Arcades Maß übernehmen (`_lm_glow`: weicher Fleck mit Radius max(2,5 px, 6 m × s), Kern 0,35 r) – z. B.
Größe 1,5 m, Mindestgröße 1,5 px, Stärke ≤ 0,35, damit die Glow-Stufe ihn nicht aufbläht; in `flugfeuer` eine Grenze
„rote Pixel ≤ 3 × Arcades“ derselben Stelle.

**B-03 (low) – Anstrahlung gewöhnlicher Requisiten als Wahrzeichen: schwach und ungeprüft.**
Wo: `landmark.gdshader` CE_ATLAS `alb = mix(alb, alb * flood_color * 1.6, flood)` (Zeile ≈ 267) – das Anstrahlen
wirkt nur über die beleuchtete Albedo, nachts also kaum; CE_PICTURE dagegen setzt die Farbe wie Arcade.
Beleg (gemessen): `raw/flood2_bremen_22_*` Turmfeld Ø RGB Arcade 102/106/73, Basis 79/101/62, R7b 89/106/63 –
besser als die Basis, dunkler als Arcade. Mutationen M16/M17 (Anstrahlung im Shader entfernt): **keine Prüfung schlägt an**.
Behebung: in CE_ATLAS zusätzlich `EMISSION += alb * flood_color * flood * k` (k so, dass das Turmfeld ≈ Arcade
trifft, wie Kanal 14 der Formen) und eine Prüfung (Render: Turmfeld des Bremer Doms 22 Uhr ≥ 0,85 × Arcade; oder
headless: Material `lm_fade.w > 0` nachts für `props/church`).

**B-04 (low) – Unpiegelte Kirche als Wahrzeichen links: Turm bis 37,8 m näher an der Straße als in Arcade.**
Wo: `builders/landmarks.gd` `resolve_item` (`PropsBuilderMath.edge_anchor_x` mit den Ausdehnungen der
ungespiegelten Seite). Arcade spiegelt `props/church` links (`mirror_left`, `prop_flipped`).
Beleg (gemessen): Datenscan – größter Ankerversatz 37,8 m (Magdeburger Dom × 2,9 = 44,7 px bei 600 m, unter 64 px);
Bild `raw/flood2_bremen_22_*`: Turm ≈ 63 px rechts von Arcades bei ≈ 380 m. R7b nennt 24,7 px als Höchstwert (nur die
geraden Anfahrten).
Behebung (Entscheidung der Leitung, D24): Modell an Arcades Anker setzen (Ausdehnungen der gespiegelten Seite,
`edge_anchor_x(x, side, true, ext, sc)`), der Baukörper rückt dann nach außen, weg von der Straße; oder den Knoten mit
negativer x-Skalierung spiegeln (ein einzelnes `MeshInstance3D` mit negativer Determinante zeichnet richtig, D24 betrifft
MultiMesh).

**B-05 (low) – Kuppelformen stehen mit der Front am Anker: Kuppel tiefer, in Kurven seitlich versetzt.**
Wo: `builders/landmarks.gd` `_domed_church` (Körper bis −44 m, Hauptkuppel bei z = −22 × k), `_place` (gedreht mit
der Straße am Anker).
Beleg (gemessen/gefolgert): `raw/nah_leipzig_12_*` – Arcades Kuppel über dem Baum sichtbar, in Modern verdeckt;
`raw/nah_belgrad_12_*` – ≈ 85 px rechts, breiter (R7b-Messung bestätigt).
Behebung: Form um die halbe Tiefe nach vorn setzen (Hauptkuppel am Anker, wie Arcade sie zeichnet) und sie zur
Anfahrt drehen statt zur Straße am Anker (z. B. Richtung vom Pfadpunkt 600 m vor dem Anker, einmal je Wahrzeichen) –
siehe Vertragsfrage V-1.

**B-06 (low) – Spitzen beim Neuzeichnen der Skyline.**
Wo: `layers/backdrop.gd` (`_sky_sig` mit Deckung auf 0,015 gerundet → Neuzeichnen der ganzen Leinwand bei jedem
Schritt des Ausblendens; Arcades 2D-Zeichnungen in `paint()`).
Beleg (gemessen, unter Last): `backdrop`-Haken max 3,0 / 4,3 ms auf zwei ganzen Etappen gegen 0,56 / 1,43 ms der
Basis; Mittel +0,02–0,04 ms.
Behebung: Deckung gröber runden (0,05) oder während des Ausblendens höchstens jedes zweite Bild neu zeichnen.

**B-07 (low) – Latenter Fehler im Netz-Cache der Formen.**
Wo: `builders/landmarks.gd` `proc_key()` (Schlüssel `height_m × scale`) gegen `proc_mesh()` (baut mit `height_m`) und
`_place()` (skaliert den Knoten mit `scale`). Zwei Einträge gleicher Art/Farben mit gleichem Produkt, aber anderem
`scale` bekämen ein falsch großes Netz. Heute kein solcher Fall im Netz (Datenscan).
Behebung: Schlüssel mit `height_m` allein; Kommentar von `proc_mesh` („the node carries no scale“) berichtigen.

**B-08 (low) – Doku §18 ungenau.**
Wo: `docs/renderer-modern.md` §18.1/18.2: „Modell … Heute: nur `landmarks/michel`“ – tatsächlich zeichnen 46 der 143
Wahrzeichen als Modell (`props/church` 38, `props/building_tall` 5, Michel 3); „24,7 px … Spiegelung“ als Höchstwert –
netzweit 44,7 px.
Behebung: die zwei Sätze berichtigen.

## 6. Vertragsfragen

- **V-1 D24 „Landmarks are never mirrored and not turned“.** R7b dreht Modelle und Formen mit der Straße an ihrem Anker
  (A-4-Platzierung wie Requisiten) und spiegelt nie. Arcade spiegelt aber eine gewöhnliche Requisite, die als
  Wahrzeichen steht (`props/church` links, 38 Fälle), und zeichnet jedes Wahrzeichen von vorn („c“-Zelle). Folgen: B-04
  (Turm bis 37,8 m näher an der Straße) und B-05 (Seitenwand in Kurven, Belgrad ≈ 85 px). Bitte entscheiden: (a)
  „not turned“ heißt „Front zur Anfahrt“ – Ausrichtung einmal je Wahrzeichen zur Richtung vom Pfadpunkt ≈ 600 m davor;
  (b) Requisiten mit `mirror_left` dürfen als Wahrzeichen links gespiegelt werden (einzelner Knoten mit negativer
  Skalierung, nicht MultiMesh) oder werden an Arcades gespiegeltem Anker unspiegelt aufgestellt.
- **V-2 Abnahme „Stelle bei 600 m auf gerader Anfahrt“** ist im Netz kaum prüfbar: nur 3 gerade 640-m-Anfahrten
  (bestätigt), alle zehn Städte biegen, und bei 600 m verdecken Häuser das Wahrzeichen in beiden Modi fast überall.
  Vorschlag: die Abnahme ergänzen um Nahbilder (≈ 250 m) und um einen Datenscan des Ankers über alle 143 Wahrzeichen
  (dieser Bericht: höchstens 44,7 px bei 600 m) – und Kurvenbilder mit `look_gain` 0 (A-3).
- **V-3 A-18 / Golden `modern_slice`**: R7b ändert `modern_s4_mittel` gewollt (Michel aus `landmarks.gd`, ≤ 2/255
  laut R7b); nach A-18 erzeugt die Montage RINT-M3 die Liste neu – nicht nachgemessen (Zeit), Hinweis bleibt.

## 7. Hinweise für die Nächsten

1. **R7b/Leitung vor RINT-M3**: B-01 (Mischung im Anzeigeraum) und B-02 (Flugwarnlicht auf Arcades Maß) sind je
   wenige Zeilen in `landmark.gdshader` / `landmarks.gd`; beide sind Nachtbilder auf der Teststrecke (Elbphilharmonie)
   bzw. in Dortmund/Madrid.
2. **Integration (RINT-M3)**: `tests/race3d/check_minimal_structures.gd` (+4 Zeilen von R7b) ist eine fremde Datei –
   beim Zusammenführen mit FIX-RINT auf Konflikte achten; `tests/golden/modern_slice.*` nach dem Merge neu erzeugen (A-18).
3. **R7c / Besitzer `props.gd`**: toten Pfad der fernen Vertretungen entfernen (R7b-Hinweis, bestätigt: die Weiche
   `_skip_landmarks` lässt `_update_far_landmarks` sofort zurückkehren); `docs/renderer-modern-gelaende.md` Z. 185.
4. **AS6**: Schnittstelle in §18.2 reicht; dabei beachten, dass `landmarks.gd` immer `reps[0]` (LOD0) bis 1.900 m zeigt
   (kein LOD-Wechsel) – 25.000 Dreiecke je Modell sind bei 1–2 Wahrzeichen im Bild tragbar (gefolgert), Glas/Laub meiden.
5. **QA-mid**: Nachtbilder mit „deck“ (Glow an) für Dortmund/Madrid (Flugwarnlicht) und die Elbphilharmonie ansehen;
   die Nahpunkte dieses Berichts (≈ 250 m) für Wahrzeichen nehmen – bei 600 m verdecken Häuser fast alles.
6. **Stadtbauten (nicht R7b, auch auf der Basis)**: Brüssel km 206,4 fehlt Arcades Häuserzeile vor dem Atomium; das
   Kirchenmodell `props/church` als Wahrzeichen ist 73 m lang und 92 m hoch (× 2,6) und steht 40 m vor dem Bremer Dom
   als Wand neben dem Gehweg (`raw/flood_bremen_22_*`).

### 4.5 Steam-Deck-Preset („deck“, 1280 × 800; Arcade mit Balken)

`raw/deck_dortmund_225.0_{12,22}_*`: bei Tag schlanker Fernsehturm statt des Bürohochhauses der Basis – besser; Modern
füllt das Fenster. Nachts dasselbe Flugwarnlicht wie bei „Hoch“ (238 gegen Arcades ≈ 16 rote Pixel im Turmfeld; der
Glow ist bei „deck“ an) – B-02 gilt auch auf dem Deck (gefolgert für das Gerät: gleiche Shader, gleiche Pixelgröße).

### 4.6 Skyline und Horizont (A-10), Dämmerung

- **S1 (km 2), S4 (km 80), S5 (km 94)**, `boegen/horizont_S1_S5.jpg`: unter der Horizontzeile liest der Fernboden als
  fernes Land (grün bzw. grau-blau bis zum Dunst), kein heller Streifen, kein Wandmuster – wie Arcade. R7b = Basis
  (S1, S5: 0 Pixel verschieden; S4: 3 Pixel – die Turmspitze des Michel 1,26 km voraus, jetzt aus `landmarks.gd`).
  Die Skyline-Silhouetten von Hamburg (Michel, Elbphilharmonie) sind an diesen Stellen richtig ausgeblendet (in
  Reichweite bzw. passiert) – nie doppelt.
- **Kassel** (`raw/skyline_kassel_*`, City Limits km 148,5): der Herkules erscheint als Arcades 2D-Silhouette bei −24°
  auf der Grundlinie (143 Pixel gegen die Basis, die keine Skyline hatte) – in Arcade an dieser Stelle von einem Dach
  verdeckt. Funktioniert wie Arcade.
- **19:30** (nur Kopf, `boegen/hamburg.jpg`, `boegen/dortmund.jpg`): Elbphilharmonie und Michel an Arcades Stelle; der
  Fernsehturm in Dortmund zeigt sein rotes Licht schon in der Dämmerung (Arcade erst später) – unauffällig.
- Nicht geprüft (Zeit): Skyline Köln (Colonius) und Riga (Fernsehturm, St. Petri) im Bild; headless bestätigt der
  Datenscan nur, dass jede Silhouette zeichenbar ist.

## 8. Geprüft und in Ordnung

- Arcade-Identität 20/20 + 17/17; keine eingefrorene Datei berührt; `props.gd`, `billboard/baked.gdshader`,
  `config/game_config.json` unverändert; Fairness F1–F3/F7 `--full` und Pfadprüfung `--full` grün.
- `run_tests.sh` voll grün; Render-Auswahl 6/6 grün (Korrekturen des ersten Testbuilds halten: `check_start_km0`,
  `check_terrain_cover` mit K1, `check_light_base`, `test_far_ground_water`, `test_props`).
- Jedes der 143 Wahrzeichen in allen 128 Etappenrichtungen hat dieselbe Darstellung, dasselbe Set, denselben Maßstab
  und dieselbe Tönung wie Arcade und baut headless; jede Skyline-Silhouette ist zeichenbar.
- Arcades Gesetz (Reichweite, Deckung, Dunst, Beleuchtung bis 1.900 m, Anstrahl-Anteil) exakt; weiches Ausblenden statt
  Dither ab 0,70 L (Render-Prüfung „weich“ 0,23 ≪ 1); keine Instanz-Uniform; `collect()` 0,001 ms.
- Die 3D-Formen sind bei Tag **klar besser als die Basis** (Dortmund, Madrid, Calais, Hannover, Belgrad hatten breite
  Ersatzbilder) und an Arcades Stelle; Hannover und Dortmund sehen besser aus als Arcades flache Zeichnungen.
- Bild-Wahrzeichen bei Tag gleich Arcade und gleich der Basis (Hamburg, Paris-Clip, Brüssel).
- Neue Prüfungen wachen über ihre Regeln (16 von 18 Mutationen erkannt; die zwei Lücken sind B-03).
- Draw Calls +2…+4 je Einfahrt (Deck), `ERGEBNIS` identisch mit der Basis.
- R7b-Clips (`deliver/R7b/clips/anfahrt_{hamburg,paris}.mp4`) als Kontaktbogen angesehen
  (`m1/QA-R7b/clip/*_sheet.jpg`): Michel und Eiffelturm an Arcades Stelle, kein Springen.
