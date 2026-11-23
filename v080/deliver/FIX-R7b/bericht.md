# FIX-R7b – Nacharbeit nach der unabhängigen Prüfung von R7b (Wahrzeichen, Skyline, Hintergrund)

Stand: Zweig `wip/v080-fix-r7b` (Kopf siehe §5), Arbeitsbaum
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-6`, Basis `2c154bc` (R7b-Kopf,
`git merge --ff-only`). Kein Vorgänger dieses Laufs (keine STAND.md, kein Zweig `wip/v080-fix-r7b`).
Pfade unten relativ zu `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/`.

„gemessen“ = auf dieser VM (llvmpipe unter Xvfb, vier geteilte Kerne, Last 3–6 durch andere Pakete); „gefolgert“ =
hier nicht messbar (Steam Deck, echte GPU, Wirkung auf einen Menschen).

## Kurz

Alle acht Befunde von QA-R7b sind nachgestellt. Sieben sind behoben und nachgeprüft, einer (B-06) ist zum Teil widerlegt
und billig entschärft. Die Ursache von B-02 war ein Fehler, kein Feintuning: im Compatibility-Renderer ist
`PROJECTION_MATRIX[1][1]` im Vertex-Schritt **negativ**. Darum bekam jeder Leuchtpunkt der Wahrzeichen die
Sicherheitsgrenze (3 % seiner Tiefe) statt seiner Größe. Jetzt (gemessen, gleicher Simulationszustand wie Arcade):

| Befund | vorher (R7b) | jetzt | Arcade |
|---|---|---|---|
| B-01 Elbphilharmonie 22 Uhr, Fassade Ø Luminanz (QA-Feld) | 144,5 | 116,1 | 112,8 |
| B-01 Render-Prüfung „nacht_hell“ (obere Hälfte der Fassade) | – (Mutation: 1,22 ×) | 0,99 × Arcade | 1 |
| B-02 Florianturm 22 Uhr, rote Pixel („Hoch“) | 232 (17 × 19 px) | 15 (4 × 5 px) | 10 (4 × 4 px) |
| B-02 dasselbe, Preset „deck“ 1280 × 800 | 238 | 17 | 16 |
| B-02 Render-Prüfung „flugfeuer“ (ohne Verkehr) | – | 28 | 28 |
| B-03 Bremer Dom 22 Uhr (Modell): Anstrahlen hellt auf / gegen Arcade | ≈ 1,0 × (Mutation) | 1,32 × / 0,97 × | – |
| B-03 Fourvière Lyon 22 Uhr (Bild): Anstrahlen / gegen Arcade | – | 1,71 × / 1,05 × | – |
| B-04 größter Ankerversatz netzweit (143 Wahrzeichen) | 37,8 m (44,7 px bei 600 m) | 0,15 m (0,2 px) | 0 |
| B-04 Bremer Dom, Turm bei ≈ 380 m | ≈ 63 px neben Arcade | ≈ 5 px | – |
| B-05 Leipzig nah: Kuppel | hinter dem Baum verborgen | über/neben dem Baum an Arcades Stelle | sichtbar |

Dateien (alle eigene Dateien von R7b bzw. die Leitungsausnahme `layers/backdrop.gd`; keine eingefrorene Datei, keine
fremde Datei, `props.gd` unverändert): `assets/shaders/modern/landmark.gdshader`, `scripts/race3d/builders/landmarks.gd`,
`scripts/race3d/layers/backdrop.gd` (eine Zeile Logik), `tests/unit/race3d/test_landmarks.gd`,
`tests/race3d/render/check_landmarks_render.gd`, `docs/renderer-modern.md` (nur §18).

## 1. Befunde

### B-01 (medium) – Bild-Wahrzeichen nachts heller als Arcade: **bestätigt, behoben**

Nachgestellt: mein Modern-Bild `hamburg_22` ist pixelgleich mit QA-R7b `raw/hamburg_22_modern_00.png` (0 Pixel
verschieden); Fassadenfeld (300..380, 232..268) Ø Luminanz 144,5 (Arcade 112,8, Basis 116,2) – wie QA gemessen.
Ursache wie von QA beschrieben: CE_PICTURE mischte Bild und Lichtebene in linearen Werten.
Behebung (`landmark.gdshader`, CE_PICTURE): Mischung in Anzeigewerten wie Arcades Leinwand und `billboard.gdshader`,
`disp = mix(min(d, 1), min(l.rgb, 1), wl)`, danach linear; das Scheinwerferlicht nur auf den Bildanteil (1 − wl).
Gemessen danach: 116,1 (p90 178,6 gegen Arcade 178,7). Bild: `bilder/B01_elbphilharmonie_22uhr_zoom.png` – die
Fassade hat wieder Arcades Kontrast (dunkle blaue Scheiben zwischen den hellen), vorher war sie ausgewaschen.
Prüfung: neue Render-Prüfung `nacht_hell` (obere Hälfte der Elbphilharmonie-Pixel, Modern gegen Arcades Bild
desselben Zustands, 0,8 … 1,1 ×): jetzt 0,99 ×; mit zurückgesetzter linearer Mischung 1,22 × → FEHLER (Mutation
`B01`, `m1/FIX-R7b/mut_M17_B01.log`).

### B-02 (medium) – Flugwarnlicht viel größer als Arcades Punkt: **bestätigt, Ursache gefunden, behoben**

Nachgestellt (`dortmund_22`): 232 rote Pixel, 17 × 19 px. QA vermutete den Glow der Nachbearbeitung; das stimmt
nicht: mit `--gfx=effects=0` (Glow aus) bleiben es 233 Pixel (`pics/noglow_dortmund_22_modern_00.png`). Eine Sonde
(`m1/FIX-R7b/probe/glow_probe2.gd`) hat den Leuchtpunkt-Shader am lebenden Material abgewandelt:
`viewport_h` × 10 ändert nichts, `PROJECTION_MATRIX[1][1]` durch die Konstante 1,974 ersetzt → 12 statt 360 rote
Pixel. **Im Compatibility-Renderer ist die y-Skala der Projektion im Vertex-Schritt negativ** (die Szene wird kopfüber in
ihren Puffer gezeichnet); `px_per_m` wurde negativ, `max(px_per_m, 1e-4)` machte die Mindestpixelgröße riesig, und
jeder Leuchtpunkt bekam die Sicherheitsgrenze (3 % seiner Tiefe, bei 606 m 18 m) statt seiner Größe (2,8 m).
Behebung: `abs(PROJECTION_MATRIX[1][1])`; dazu Arcades `_lm_glow`-Profil (weiche Scheibe 0,8 a, linear zum Rand, Kern
0,35 r in der aufgehellten Farbe mit 1,2 a) und Arcades Maße (Fernsehturm 6 m / 2,5 px / 0,85; Hochhäuser 3 m / 2,5 px /
0,85; Kuppelschein 16 m / 4 px / 0,4; Leuchtfeuer 3,5 m, beim Blitz bis 25,5 m, Deckung 0,5 … 1 wie Arcade). Die
Sicherheitsgrenze ist jetzt 25 % der Tiefe (sie greift nur noch ganz nah).
Gemessen: Dortmund 22 Uhr „Hoch“ 15 rote Pixel (4 × 5 px) gegen Arcades 10 (4 × 4); „deck“ 1280 × 800 17 gegen 16
(vorher 238). Render-Prüfung `flugfeuer` jetzt zusätzlich gegen Arcades rote Pixel desselben Zustands (≤ 3 ×): 28
gegen 28; mit dem alten Vorzeichen 95.297 → FEHLER (Mutation `B02`). Bilder: `bilder/B02_florianturm_22uhr_zoom.png`,
`bilder/B02_dortmund_deck_22uhr.png`.
Folge für Madrid: mit der richtigen Größe verdeckte die Brüstung eines flachen Hochhausdachs das Licht in der
Dachmitte von unten (kein Licht im Bild) – die Lichter flacher Dächer sitzen jetzt an der Vorderkante, 0,6 m über
dem Dach (`_skyscrapers`), siehe §3.
Hinweis an andere: `assets/shaders/modern/reflector.gdshader` Zeile 21 rechnet ebenso mit `PROJECTION_MATRIX[1][1]`
und dazu mit `VIEWPORT_SIZE` im Vertex-Schritt (liest dort laut R7b 0) – die Mindestgröße der Reflexe greift dort
vermutlich nie (gefolgert aus dem Code, nicht gemessen; nicht meine Datei).

### B-03 (low) – Anstrahlen gewöhnlicher Requisiten schwach und ungeprüft: **bestätigt, behoben**

CE_ATLAS (Modell, z. B. `props/church` als Dom): das Anstrahlen ist jetzt Licht – `ALBEDO = alb × (1 − f)`,
`EMISSION += alb × Flutlichtfarbe × f` (linear addiert zum Fensterlicht, f = 0,55 × Beleuchtung wie Arcades
`LANDMARK_FLOOD_K`). CE_PICTURE war schon Arcades Gesetz (Bild × Flutlichtfarbe) – geändert nur die Mischung (B-01).
Neue Render-Prüfung `anstrahlung`: dasselbe angehaltene Bild einmal mit dem Anstrahlanteil 0 (am Material) – das
Anstrahlen muss das Wahrzeichen ≥ 1,25 × aufhellen, und es muss 0,8 … 1,25 × so hell sein wie Arcades Pixel desselben
Wahrzeichens. Gemessen 22 Uhr: Bremer Dom (Modell, Hamburg–Bremen km 114,4) 1,32 × / 0,97 × Arcade; Basilika
Fourvière (Bild, Montpellier–Lyon km 300,4) 1,71 × / 1,05 × Arcade. Mutationen M16 (CE_ATLAS ohne Anstrahlen: 1,02 ×,
0,75 × Arcade) und M17 (CE_PICTURE ohne Anstrahlen: 1,02 ×, 0,66 × Arcade) → beide FEHLER, also erkannt (die zwei
Lücken der QA-Mutationsprüfung sind geschlossen). Bild: `bilder/B03_B04_bremer_dom_22uhr_zoom.png` – der Turm ist warm
angestrahlt wie in Arcade, etwas heller und wärmer als Arcades bräunlicher Turm.
Arcades Wahrzeichen-Pixel in den Prüfungen: dasselbe angehaltene Arcade-Bild wird noch einmal gezeichnet, nachdem der
Zwischenspeicher `_c` von `RoadRenderer._prep_prop` in den Wahrzeichen-Einträgen (Track.landmarks und die Einträge
der Abschnitte) leer gesetzt ist – Arcade zeichnet sie dann nicht; an Arcade wird nichts geändert.

### B-04 (low) – Ungespiegelte Kirche links: **bestätigt, behoben (Vertragsfrage D24)**

Arcade spiegelt das Bild eines Wahrzeichens nach `RoadRenderer.prop_flipped(side, mirror, mirror_left)` und misst die
Kante dann mit der anderen Ausdehnung. `landmarks.gd` macht jetzt genau das: `resolve_item` setzt `mirror` nach
Arcades Regel, `edge_anchor_x` nimmt die Ausdehnung der gezeigten Seite, ein Modell steht unter einem Knoten mit
negativer x-Skalierung (ein einzelnes `MeshInstance3D` mit negativer Determinante zeichnet richtig – die Engine dreht
die Wicklung; vgl. D24 für den MultiMesh-Knoten), ein Bild klappt sein Shader um den Anker (`mirror` = −1, wie
`sprite_dest` mit flip). Kein `landmarks/*`-Set trägt `mirror_left`: echte Wahrzeichen (und die AS6-Modelle) werden nie
gespiegelt.
Gemessen: neuer Einheitstest über alle 128 Etappenrichtungen – jedes der 143 Wahrzeichen an Arcades Anker
(`_prep_prop` desselben Eintrags; größter Unterschied 0,151 m = Modell- gegen Sprite-Ausdehnung im Rahmen von A-4,
0,2 px bei 600 m; vorher 37,8 m) und gespiegelt genau wie Arcades Bild (23 Fälle). `check_landmarks` „position“ auf
den geraden Anfahrten: Kirchenmodell 0,0 px (vorher 24,7). Bild Bremer Dom 22 Uhr ≈ 380 m: Turm ≈ 5 px neben Arcades
(vorher ≈ 63 px), `bilder/B03_B04_bremer_dom_22uhr*.png`.
Vertragsfrage: D24 sagt „Landmarks are never mirrored and not turned“. Umgesetzt ist Arcades Regel (gespiegelt nur
eine gewöhnliche Requisite mit `mirror_left` auf der linken Seite) – sonst steht der Dom nicht, wo Arcade ihn zeigt.

### B-05 (low) – Kuppelformen tiefer und seitlich versetzt: **bestätigt, behoben; Rest in Kurven ist nicht B-05**

Zwei Änderungen, wie QA vorschlug:
1. Die prozeduralen Formen stehen mit ihrer **Hauptachse am Anker** (`PROC_AXIS_Z`: Kuppelkirche 22, Fernsehturm 16,
   Leuchtturm 7, Hochhausgruppe 18 Bezugsmeter nach vorn), wie Arcade sie in der Ankerebene zeichnet.
2. Modelle und Formen stehen **mit der Front zur Anfahrt**: einmal beim Entstehen zur Richtung vom Straßenpunkt 600 m
   vor dem Anker (`APPROACH_M`), höchstens 40° (`MAX_TURN`) gegen die Straßenrichtung am Anker; die Drehung bringt keine
   Ecke des Grundrisses näher an die Straße als die Aufstellung längs der Straße (`near_shift`, sonst rückt das
   Wahrzeichen um den Unterschied nach außen). Der Snapshot zeigt `turn_deg`, `shift_m`, `mirror` je Wahrzeichen.
Gemessen/angesehen: Leipzig nah (12 Uhr, auch mit `look_gain` 0, `bilder/B05_leipzig_nah_12uhr*.png`): die Kuppel des
Völkerschlachtdenkmals steht wieder sichtbar neben und über dem Baum, an Arcades Stelle (≈ 20 px); vorher verdeckt.
Hannover nah: unverändert gut, frontal. Belgrad nah (Ada-Brücke, Kurve): Drehung −2,5°, Verschiebung 1,0 m (Sonde
`place_probe.gd`); der Anker selbst projiziert mit `look_gain` 0 auf x ≈ 1.241 (R7b) bzw. 1.245 (jetzt), Arcade zeichnet
die Kirche um x ≈ 1.144. Der Rest von ≈ 100 px ist **nicht die Form**: im selben Bild steht auch der Brückenpylon um
ähnlich viel weiter rechts als in Arcade (`bilder/B05_belgrad_nah_12uhr_look0.png`) – das ist der Unterschied zwischen
Arcades Zeilenmodell und dem echten Pfad in dieser engen Kurve am Brückenkopf (A-3). Durch die Hauptachse am Anker
steht die Vorderseite 23 m näher; die Kirche wirkt dort darum etwas größer als vorher und reicht an den Bildrand.
Prüfung: `test_procedural_shapes` prüft jetzt „Hauptachse am Anker, Körper vor und hinter ihm“; neuer Test
`test_facing_the_approach` (Peilung, Grenze 40°, keine Ecke näher an der Straße bei beiden Seiten, Drehrichtungen und
gespiegelt, negative Determinante).

### B-06 (low) – Spitzen beim Neuzeichnen der Skyline: **zum Teil widerlegt, billig entschärft**

Gemessen mit einer Sonde (`probe/sky_probe.gd`, Paris km 376, Preset „deck“, je 60 erzwungene Neuzeichnungen):
`update()` des Hintergrunds 0,05–0,1 ms mit und ohne Skyline – das Zeichnen selbst (`paint()`) läuft im
`_draw` der Leinwand, **außerhalb** des Hakens, den `perf_stats` misst. `update()` + `paint()`: Median 1,04–1,29 ms mit
Skyline gegen 0,74–1,18 ms ohne (+0,1 … 0,3 ms je Neuzeichnen, zwei Bild-Silhouetten). Die Maxima von 3,0 / 4,3 ms in
den QA-Läufen sind Last: im selben Kopf-Lauf stiegen auch Haken, die R7b nicht berührt, ebenso (Kamera 1,17 → 4,18 ms,
Umgebung 0,67 → 4,19 ms, Kiel–Hamburg). Die Leinwand wird ohnehin bei jeder Kursänderung > 0,00035 rad und alle
0,05–0,09 s neu gezeichnet; das Ausblenden der Skyline erzeugte nur auf Geraden eigene Neuzeichnungen.
Geändert: das Ausblenden geht in Stufen von 0,05 Deckung (`SKY_ALPHA_STEP`), die gezeichnete Deckung ist die der
Signatur (20 statt 67 Neuzeichnungen für ein Ausblenden). Der Unterschied im Bild (5 % Deckung einer fernen
Silhouette) ist nicht zu sehen (gefolgert).

### B-07 (low) – Netz-Cache der Formen: **bestätigt (latent), behoben**

`proc_key()` schlüsselt mit `height_m` allein (das baut `proc_mesh()`), der Knoten trägt den Maßstab; Kommentar von
`proc_mesh` berichtigt.

### B-08 (low) – Doku §18 ungenau: **bestätigt, behoben**

§18.1 (Spiegelung, Ausrichtung zur Anfahrt, 24,7 px / 44,7 px als Vorher-Werte), §18.2 (46 von 143 als Modell:
`props/church` 38, `props/building_tall` 5, `landmarks/michel` 3), §18.3 (Nacht wie Arcade, Anstrahlen als Licht), §18.4
(Hauptachse am Anker, Leuchtpunkte wie `_lm_glow`, die negative Projektionsskala), §18.6 (Tests).

## 2. Bilder und ehrliches Urteil gegen Arcade

Alle Bilder „Hoch“ 1280 × 720 (Deck-Bild „deck“ 1280 × 800), gleicher Simulationszustand wie QA-R7b (Seed 11,
Autopilot, Start 50 km/h, Bild nach 1 s – das „LOS!“ liegt in allen Bildern). Arcade und „R7b vorher“ sind QA-R7bs
Bilder `deliver/QA-R7b/raw/` (mein Modern-Lauf von 2c154bc ist damit pixelgleich, nachgeprüft an `hamburg_22`);
„FIX-R7b“ ist dieser Stand. Bögen in `deliver/FIX-R7b/bilder/`, Einzelbilder `m1/FIX-R7b/pics/` (`r2_*`, `r3_*`,
`r4_*`, `look0_*`).

| Bild | Urteil gegen Arcade |
|---|---|
| `B01_elbphilharmonie_22uhr_zoom.png` | **gleich Arcade** (vorher heller, ausgewaschen). Fassade mit Arcades Kontrast; Modern zeigt den hellen Sockel, den in Arcade Häuser verdecken |
| `B02_florianturm_22uhr_zoom.png`, `B02_dortmund_deck_22uhr.png` | Flugwarnlicht **gleich Arcades Punkt** (vorher großer roter Fleck); der Turm selbst ist plastischer als Arcades Fläche, sein Schaft nachts heller als Arcades (unverändert, kein Befund) |
| `B02_madrid_22uhr_zoom.png` | Licht auf dem flachen Dach jetzt wie Arcade an der Dachkante (mit Arcades Größe vorher von der Brüstung verdeckt); die Türme sind nachts lebhafter beleuchtet als in Arcade |
| `B03_B04_bremer_dom_22uhr_zoom.png` | Turm **an Arcades Stelle** (≈ 5 px statt ≈ 63 px), angestrahlt wie Arcade; etwas wärmer und heller als Arcades bräunlicher Turm (gemessen 0,97 × Arcades Luminanz) |
| `B05_leipzig_nah_12uhr*.png` | **besser als vorher, nahe Arcade**: die Kuppel steht wieder sichtbar an Arcades Stelle; plastischer als Arcades Zeichnung |
| `B05_belgrad_nah_12uhr*.png` | **nicht besser als vorher**: die Kirche zeigt jetzt die Front, steht aber wie vorher am rechten Bildrand, 100 px neben Arcade – derselbe Versatz wie der Brückenpylon (Kurvengeometrie, nicht die Form); durch die Hauptachse am Anker wirkt sie etwas größer |
| `hannover_nah_12uhr.png`, `hannover_nah_22uhr_zoom.png` | **gleichwertig/plastischer als Arcade**; nachts der warme Schein um die Kuppel jetzt in Arcades Größe (vorher auf 3 % der Tiefe begrenzt), etwas kräftiger als Arcades Schein |
| `hamburg_12uhr.png`, `dortmund_12uhr.png` | bei Tag **unverändert** gegen R7b (Michel-Modell zur Anfahrt gedreht, kaum sichtbar anders) |
| `belgrad_nah_22uhr.png`, `calais_22uhr.png` | Belgrad nachts angestrahlt wie Arcade, Lage wie bei Tag; Calais: der Leuchtturm ist an dieser Stelle in allen drei Bildern verdeckt – das Leuchtfeuer in Arcades Größe ist darum **nicht im Bild nachgeprüft** |

Besser als Arcade: die 3D-Formen bei Tag (Hannover, Leipzig, Dortmund – plastisch statt flach). Gleich Arcade: die
Nachtbilder der Bild-Wahrzeichen und die Lichtpunkte. Schlechter als Arcade: nichts Neues; offen bleibt die Lage in
engen Kurven (Belgrad) und das Fehlen echter Wahrzeichen-Modelle (AS6).

## 3. Weitere Änderungen

- Flugwarnlichter flacher Hochhausdächer an der Vorderkante, 0,6 m über dem Dach (Madrid, Frankfurt): mit der
  richtigen Größe verdeckte die Brüstung das Licht in der Dachmitte (`r3_madrid_22`: 0 rote Pixel; `r4_madrid_22`: 14,
  Arcade 6, `bilder/B02_madrid_22uhr_zoom.png`).
- Der Snapshot `landmarks` nennt je Wahrzeichen zusätzlich `mirror`, `turn_deg`, `shift_m`.
- Doku §18 in `docs/renderer-modern.md` (siehe B-08).

## 4. Vertragsfragen

- **D24** „Landmarks are never mirrored and not turned“: umgesetzt ist Arcades Spiegelregel (B-04) und „Front zur
  Anfahrt“ (B-05). Vorschlag für §11.4: „Ein Wahrzeichen wird gespiegelt, wo Arcade sein Bild spiegelt (eine gewöhnliche
  Requisite mit `mirror_left` links); kein `landmarks/*`-Modell wird gespiegelt. Modelle und Formen stehen mit der Front
  zur Anfahrt (Peilung vom Straßenpunkt 600 m davor, höchstens 40° gegen die Straße, nie näher an der Straße).“
- **Abnahme R7 „Stelle bei 600 m auf gerader Anfahrt“** (V-2 von QA): nur drei gerade Anfahrten im Netz; jetzt durch
  den Netzscan als Einheitstest ergänzt (143 Wahrzeichen am Anker wie Arcade, ≤ 0,15 m). In engen Kurven bleibt der
  Unterschied zwischen Arcades Zeilenmodell und dem echten Pfad (Belgrad ≈ 100 px auch mit `look_gain` 0, für alle
  Objekte gleich) – das ist A-3, kein Wahrzeichen-Fehler.
- **A-18 Golden** `modern_s4_mittel`: weicht weiter ab (Michel aus `landmarks.gd`, jetzt zusätzlich zur Anfahrt
  gedreht); nicht neu erzeugt – Sache der Montage RINT-M3.

## 5. Gates (Kopf `c50d58f`, gemessen)

Logs in `m1/FIX-R7b/` (`gates/`, `run_tests_full.log`, `golden_check.log`). Jedes Spiel mit eigenem absolutem
`XDG_DATA_HOME`, schwere Läufe einzeln mit `nice -n 10`.

| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | sauber (`import.log`, 0 Fehler) |
| Skripte | `tests/check_scripts.gd` (in `run_tests.sh`) | „334 Skripte geprüft, 0 fehlerhaft“ |
| Tests voll (einmal) | `tools/run_tests.sh` | **bestanden** (955 s): 813 Einheitstests / 0 fehlgeschlagen (10 in `test_landmarks.gd`), alle `check_*` OK, darunter `check_landmarks` 6/6, `modern_sight` (schneller Teil) und gehalten `test_far_ground_water`, `test_props`. Der Lauf begann auf `b0130bd`; `c50d58f` (Licht der flachen Hochhausdächer, Doku) danach mit `run_tests.sh landmarks` grün (27 s) |
| Arcade-Identität | `tools/golden.sh check` | „GOLDEN arcade: 20 von 20 identisch“, „GOLDEN arcade-ui: 17 von 17 identisch“ |
| Modern-Golden | `tools/golden.sh modern-check` | „GOLDEN modern: 5 von 6 identisch“ – `modern_s4_mittel` ANDERS wie schon bei R7b; OpenGL ES gegen OpenGL OK (2/255, 73,2 dB). Angesehen (KEEP, Kopf gegen 2c154bc): 624 Pixel, nur der Michel (jetzt zur Anfahrt gedreht, zeigt sein Zifferblatt frontal), `bilder/golden_modern_s4_michel_zoom.png`. **Nicht neu erzeugt** (A-18: die Montage) |
| Render-Prüfungen | `tools/run_render_checks.sh all` | „29 von 29 Render-Prüfdateien in Ordnung“, jede in ihrer Kopf-Frist; `check_landmarks_render` 7/7 (s. §1), gehalten `check_start_km0`, `check_terrain_cover` mit K1, `check_light_base`, Instanzbudget-Prüfungen |
| Fairness | `tests/sim/modern_sight.gd -- --full` | OK: F1 0 Fälle bis 270 m (99.424.500 Stichproben, 128 Richtungen), F1 Spuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 5.923, F7 0 von 2.011.532, Modell 0 abweichend |
| Pfad | `tests/sim/modern_path_check.gd -- --full` | OK: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2.064 m (≥ 2.000) |
| Mutationen | `m1/FIX-R7b/sh/mutate.py` + `run_render_checks.sh modern landmarks_render` | B01, B02, M16, M17 je einzeln erkannt (`mut_M16_B02.log`, `mut_M17_B01.log`), danach Shader per git zurückgesetzt |

**Ganze Etappe in Modern** (`tests/race/run_stage.gd`, Autopilot, Preset „deck“ 1280 × 800, Zeitraffer 40, Seed 7,
Xvfb/llvmpipe; Basis = Kopie von `2c154bc` im selben Zeitfenster; `sh/perfsum.py`; gemessen, echte Hardware gefolgert):

| Lauf | render() Ø / max ms | Stück-Commit max ms | collect Ø / max ms | Draw Calls / Primitive | Haken `landmarks` Ø / max ms | Haken `backdrop` Ø / max ms | Skriptfehler | ERGEBNIS |
|---|---|---|---|---|---|---|---|---|
| Kiel–Hamburg Kopf (1) | 3,77 / 21,5 | 2,3 | 1,61 / 2,8 | 137 / 181.987 | 0,051 / 0,94 | 0,161 / 2,88 | 0 | gleich |
| Kiel–Hamburg Basis (1) | 3,76 / 10,8 | 2,0 | 1,66 / 2,8 | 137 / 181.987 | 0,049 / 0,34 | 0,146 / 0,45 | 0 | gleich |
| Kiel–Hamburg Kopf (2) | 3,72 / 11,3 | 1,7 | 1,63 / 3,9 | 137 / 181.987 | 0,076 / 6,16 | 0,150 / 1,47 | 0 | gleich |
| Kiel–Hamburg Basis (2) | 3,83 / 19,9 | 2,0 | 1,57 / 2,8 | 137 / 181.987 | 0,048 / 0,40 | 0,140 / 0,33 | 0 | gleich |
| Bremen–Dortmund Kopf | 4,48 / 12,0 | 6,6 | 1,76 / 6,7 | 128 / 160.366 | 0,035 / 0,34 | 0,157 / 1,33 | 0 | gleich |
| Bremen–Dortmund Basis | 4,39 / 11,5 | 3,0 | 1,71 / 4,4 | 128 / 160.366 | 0,035 / 0,29 | 0,147 / 1,33 | 0 | gleich |

Lesart: Mittelwerte, Draw Calls und Primitive gleich (Regel 3: `ERGEBNIS` in Kopf und Basis gleich, md5 ohne `gfx`
`440840040c` bzw. `738ca98d81`). Die Maxima sind Einzelbilder unter Fremdlast und streuen (Kamera-Haken der Basis bis
8,7 ms). Auf Kiel–Hamburg lag das Maximum des Hakens `landmarks` im Kopf zweimal höher (0,94 / 6,16 gegen 0,34 / 0,40 ms);
eine Sonde (`probe/make_probe.gd`) misst das Erzeugen eines Wahrzeichen-Knotens: Michel-Modell 0,12 ms (Basis 0,06),
Elbphilharmonie 0,11 ms (0,09), das Bild seines Entstehens 1,16 ms – die 6,16 ms sind ein einzelnes Bild ohne
erkennbaren Zusammenhang (gefolgert: Last). `collect()` des Builders unverändert 0,001 ms (A-18).

## 6. Hinweise für die Nächsten

1. **RINT-M3**: `tests/golden/modern_slice.*` nach dem Merge neu erzeugen (Michel in `modern_s4_mittel`, angesehen).
   Vertrag §11.4: D24 für Wahrzeichen nach §4 dieses Berichts fassen.
2. **Besitzer `layers/lights.gd` / `reflector.gdshader`** (nicht meine Datei): Zeile 21 rechnet die Mindestgröße der
   Reflexe mit `PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y` im Vertex-Schritt – beides ist im Compatibility-Renderer dort
   unbrauchbar (y-Skala negativ, `VIEWPORT_SIZE` laut R7b 0). Vorschlag: `abs(PROJECTION_MATRIX[1][1])` und die
   Bildhöhe als Uniform wie `landmark.gdshader` (`viewport_h`). Gefolgert aus dem Code, nicht gemessen.
3. **R7c / Besitzer `props.gd`**: toter Pfad der fernen Vertretungen (wie R7b gemeldet) – unverändert offen.
4. **QA-mid**: Nachtbilder mit „deck“ für Dortmund, Madrid, Hamburg ansehen (jetzt wie Arcade); das Leuchtfeuer von
   Calais ist in keinem Bild sichtbar geprüft (in allen drei Modi verdeckt) – eine Stelle mit freier Sicht suchen.
   Wahrzeichen-Nahpunkte (≈ 250 m) statt 600 m nehmen; in engen Kurven (Belgrad) mit `look_gain` 0 vergleichen.
5. **AS6**: Ein Modell für `landmarks/<name>` steht mit +Z zur Anfahrt und wird nie gespiegelt (kein `mirror_left`);
   Ursprung = Anker des Sprites. Für die sechs prozeduralen Einträge: die Hauptachse auf den Ursprung legen (wie
   `PROC_AXIS_Z`), sonst steht die Kuppel hinter Arcades Stelle.
6. **Belgrad (Ada-Brücke)**: der Versatz von ≈ 100 px gegen Arcade betrifft das ganze Bild in dieser Kurve (Pylon wie
   Kirche) – Sache des Kerns/der Kurvenparität (A-3), nicht der Wahrzeichen.

## 7. Dateien und Ablage

- Zweig `wip/v080-fix-r7b`, Commits `fab45d7`, `818150b`, `b0130bd`, `c50d58f` (alle gepusht).
- Bilder: `deliver/FIX-R7b/bilder/` (Zoom- und Vergleichsbögen), Einzelbilder `m1/FIX-R7b/pics/`.
- Werkzeuge: `m1/FIX-R7b/sh/` (`mshot.sh`, `batch.sh`, `probe.sh`, `zoom.py`, `red.py`, `cmp.py`, `mutate.py`,
  `perfsum.py`, `gates.sh`, `extra.sh`), Sonden `m1/FIX-R7b/probe/`.
- Die Basis-Kopie und alle Benutzer-/Shader-Caches sind gelöscht.
