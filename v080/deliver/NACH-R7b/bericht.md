# NACH-R7b – Nachprüfung der Nacharbeit FIX-R7b (Wahrzeichen nachts, Flugwarnlicht)

Stand: Kopf `c50d58f` (`origin/wip/v080-fix-r7b`), Arbeitsbaum
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-9` (`git merge --ff-only c50d58f`,
keine Commits, kein Push, kein eigener Zweig). Vergleich „R7b vorher“ = eine Kopie von `2c154bc` (`git archive`, im
Kratzordner, danach gelöscht). Kein Vorgänger dieses Laufs (keine STAND.md).
Pfade unten relativ zu `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/`.

„gemessen“ = auf dieser VM (llvmpipe unter Xvfb, vier geteilte Kerne, Last 2–8 durch andere Pakete); „gefolgert“ = hier
nicht messbar (Steam Deck, echte GPU, Wirkung auf einen Menschen).

## Kurz

Beide Befunde, die FIX-R7b zu erledigen hatte, sind **behoben** – nachgestellt im selben Simulationszustand wie QA-R7b,
gegen Arcade und gegen `2c154bc`, mit eigenen Bildern und Messungen:

| Befund | Arcade | R7b `2c154bc` | FIX-R7b `c50d58f` | Urteil |
|---|---|---|---|---|
| B-01 Elbphilharmonie 22 Uhr, QA-Feld (300..380, 232..268), Ø Luminanz („Hoch“ 1280 × 720) | 112,7 (p90 178,4) | 144,5 (p90 197,2) | 116,1 (p90 178,3) = 1,03 × | behoben |
| B-01 dasselbe, Preset „deck“ 1280 × 800 (Feld an der Lage des jeweiligen Bildes) | 112,7 | 143,1 | 114,6 = 1,02 × | behoben |
| B-01 Render-Prüfung `nacht_hell` (obere Hälfte, Maske) | 115,9 | – | 114,5 = 0,99 × | grün |
| B-02 Florianturm 22 Uhr, rote Pixel (QA-Maß), „Hoch“ | 10 (4 × 4 px) | 232 (17 × 19 px) | 15 (4 × 5 px) | behoben |
| B-02 dasselbe, „deck“ 1280 × 800 | 10 (4 × 4) | 237 (17 × 19) | 16 (4 × 5) | behoben |
| B-02 Madrid 22 Uhr (flaches Hochhausdach), rote Pixel | 6 (2 × 3) | 182 (16 × 15) | 6 (3 × 3) | behoben |
| B-02 Render-Prüfung `flugfeuer` (ohne Verkehr) | 28 | – | 28 (≤ 3 × Arcade) | grün |

Alle Messungen gemessen. Die Arcade-Bilder sind pixelgleich mit QA-R7bs (`hamburg_22`: 0 Pixel verschieden), meine
R7b-Bilder geben QAs Werte wieder (Fassade 144,5 wie QA). Die neuen Prüfungen `nacht_hell` und `flugfeuer` habe ich mit
beiden alten Fehlern zurück im Shader laufen lassen (§5a, Mutation): beide schlagen an.

Nebenwirkungen: der Diff `2c154bc..c50d58f` bleibt in sechs Dateien von R7b (plus der Leitungsausnahme
`layers/backdrop.gd`, eine Zeile Logik); keine eingefrorene Datei, keine fremde Datei; Arcade-Golden 20/20 und 17/17.
Ein neuer Befund geringer Schwere (N-1): die Ausrichtung zur Anfahrt (B-05) rückt Modelle und Formen um bis zu 11,9 m
von Arcades Anker weg nach außen – die Aussage „jedes Wahrzeichen an Arcades Anker (0,15 m)“ gilt nur für den Anker
vor dieser Verschiebung und wird von keinem Test über das ganze Netz geprüft.

## 1. Befunde

### B-01 (medium) – Bild-Wahrzeichen nachts heller als Arcade: **behoben**

Code (`landmark.gdshader`, CE_PICTURE): Bild und Lichtebene werden jetzt in Anzeigewerten gemischt,
`disp = mix(min(d, 1), min(l.rgb, 1), wl)`, dann linear, Scheinwerfer nur auf den Bildanteil `(1 − wl)` – genau QAs
Vorschlag und dieselbe Rechnung wie `billboard.gdshader` (dort l. 166–168; `billboard` lässt das Scheinwerferlicht
unter der Lichtebene ganz weg, `landmark` gewichtet es mit `1 − wl` – bei Nacht ohne sichtbaren Unterschied, gefolgert).
Tag unverändert: `wl` ist bei Tag 0, `hamburg_12` unterscheidet sich gegen R7b nur am Michel (Drehung B-05), nicht an
der Elbphilharmonie (gemessen: Unterschiedsfeld x 545..589).

Gemessen (Tabelle oben) und angesehen: `B01_elbphilharmonie_22uhr_zoom.png`. Die Fassade hat wieder Arcades Kontrast –
dunkle blaugraue Scheiben zwischen hellen cremefarbenen Fenstern; R7b war deutlich ausgewaschen. Modern zeigt die
Elbphilharmonie etwas größer und mit dem beleuchteten Kaispeicher-Sockel, den in Arcade Dächer verdecken (Kamera und
Häuser davor, nicht dieser Befund).

### B-02 (medium) – Flugwarnlicht viel größer als Arcades Punkt: **behoben**

Code: `abs(PROJECTION_MATRIX[1][1])` im Pixelmaßstab, Arcades `_lm_glow`-Profil (Scheibe 0,8 a linear zum Rand, Kern
0,35 r mit 1,2 a in der aufgehellten Farbe) und Arcades Maße (Fernsehturm 6 m / 2,5 px / 0,85; Hochhäuser 3 m /
2,5 px / 0,85; Leuchtfeuer 3,5 … 25,5 m / 0,5 … 1 – nachgerechnet gegen `RoadRenderer._lm_tv_tower`, `_lm_skyscrapers`,
`_lm_lighthouse`; das Blinkmuster 1,5 s / 0,75 s der oberen zwei Lichter ist Arcades). Die Erklärung von FIX-R7b (im
Compatibility-Renderer ist die y-Skala der Projektion im Vertex-Schritt negativ) habe ich nicht eigens gemessen; sie
passt zu den Zahlen (mit Vorzeichen griff immer die Sicherheitsgrenze) und `abs()` ist auf jedem Renderer richtig.

Gemessen (Tabelle oben) mit Clustern roter Pixel (`m1/NACH-R7b/sh/redclusters.py`). Angesehen:
`B02_florianturm_22uhr_zoom.png`, `B02_florianturm_deck_22uhr_zoom.png`, `B02_madrid_22uhr_zoom.png`: der rote Fleck
von R7b ist ein kleiner Punkt wie in Arcade; in Madrid sitzt das Licht an der Vorderkante des flachen Dachs (Arcade:
auf dem Dach), gleich groß. Am Florianturm steht der ganze Turm in R7b und FIX-R7b gleich ≈ 50 px rechts von Arcades
(x 676 gegen 626 bei km 225) – unverändert seit R7b, unter der Grenze 5 % der Bildbreite (64 px) von
`wahrzeichen_stelle`; kein Befund dieser Runde.

Die Sicherheitsgrenze ist von 3 % auf 25 % der Tiefe gestiegen. Sie greift nur, wenn Arcades Größe selbst mehr als ein
Viertel der Tiefe wäre (ganz nah); der Zug zur Kamera (`min(1,5 r, 0,5 Tiefe)`) vergrößert einen Punkt dann um bis zu
1,6 ×, bei normaler Größe (6 m auf 600 m) um 1,5 % (gerechnet, nicht im Bild gesehen – kein Wahrzeichenlicht steht so
nah an der Straße, kleinster Eckabstand im Netz 22 m, §3).

## 2. Weitere Änderungen von FIX-R7b – Nebenwirkungen

Gelesen: der ganze Diff `2c154bc..c50d58f` (6 Dateien, +489 / −94). Dateien: `assets/shaders/modern/landmark.gdshader`,
`scripts/race3d/builders/landmarks.gd`, `scripts/race3d/layers/backdrop.gd` (Leitungsausnahme laut QA-R7b),
`tests/unit/race3d/test_landmarks.gd`, `tests/race3d/render/check_landmarks_render.gd`, `docs/renderer-modern.md`
(§18). Keine eingefrorene Datei (Regel 1), `props.gd` unverändert. Die Prüfung liest Arcades privates `_segs` und setzt
`_c` in den Wahrzeichen-Einträgen zur Laufzeit – nur lesend benutzt bzw. in Daten, keine Datei von Arcade geändert.
Überschneidung mit den Nachbarn (gegen `9b02f05`): FIX-RINT ändert nur `docs/renderer-modern.md` mit (andere
Abschnitte), FIX-R7a ebenso, R7c ändert `prop_library.gd` nur additiv (`rep_materials`, `attachments`, `max_dist_m`) –
die von `landmarks.gd` benutzten `sets`, `models`, `mesh_parts` bleiben (gelesen, nicht zusammengeführt).

- **B-03 Anstrahlen (CE_ATLAS)**: Albedo × (1 − f) plus Flutlicht als Emission. Für Modelle ohne Anstrahlen (f = 0,
  Michel, Tag) ist `albedo_for(to_lin(x)) = x` (zwei Newton-Schritte) – kein Unterschied außer Rundung. Bild
  `bremer_dom_22uhr_zoom.png`: der Turm steht an Arcades Stelle (x ≈ 636 gegen 637; R7b ≈ 701) und ist warm angestrahlt
  wie Arcade, etwas heller und wärmer. Render-Prüfung `anstrahlung` grün (1,32 × / 0,97 × Arcade; Fourvière 1,71 × /
  1,05 ×).
- **B-04 Spiegelung**: das gespiegelte Kirchenmodell (negative x-Skalierung des Knotens) zeichnet richtig – im Bild keine
  umgestülpten Flächen, Schatten und Licht plausibel (Bremer Dom, angesehen). `test_anchor_and_mirror_like_arcade_
  network_wide` grün (143 Wahrzeichen, 0,151 m, 23 gespiegelt).
- **B-05 Ausrichtung und Hauptachse**: siehe N-1. Hannover nah 22 Uhr (`hannover_nah_22uhr_kuppelschein_zoom.png`): Kuppel
  an Arcades Stelle und in Arcades Größe, der warme Schein jetzt in Arcades Radius (R7b: auf 3 % der Tiefe begrenzt),
  die Trommel heller als in Arcade. Michel bei Tag (`michel_12uhr_zoom.png`): zur Anfahrt gedreht, Zifferblatt frontal,
  ≈ 7 px neben Arcade.
- **B-06 Skyline in 0,05-Stufen**: `a = snappedf(a, 0.05)`; Werte unter 0,025 fallen auf 0 und werden übersprungen
  (vorher ab 0,01). Der Sprung von 0 auf 5 % Deckung einer fernen Silhouette ist nicht zu sehen (gefolgert).
  `check_landmarks` „skyline“ grün (Paris km 376).
- **B-07 Formen-Cache** nur nach `height_m`: richtig, weil `proc_mesh()` den Maßstab nicht benutzt (gelesen).
- **Bildvergleich R7b → FIX-R7b**: in allen acht Bildpaaren liegen die Unterschiede nur auf den Wahrzeichen
  (gemessen, Rahmen der Pixel mit > 8 Unterschied: Hamburg x 266..589, Dortmund 657..692, Madrid 737..829 usw.) – kein
  anderer Teil des Bildes ändert sich.

## 3. Neue Befunde

### N-1 (low) – Ausrichtung zur Anfahrt verschiebt Modelle bis 11,9 m von Arcades Anker; ungeprüft

`_place()` dreht Modell und Form zur Anfahrt und rückt sie danach um `near_shift` nach außen, damit keine Ecke näher an
die Straße kommt. Diese Verschiebung trifft den Knoten, nicht den Anker aus `resolve_item()` – der Netztest
`test_anchor_and_mirror_like_arcade_network_wide` und der Satz in Bericht und Doku §18.1 („jedes der 143 Wahrzeichen
an Arcades Anker, größter Unterschied 0,15 m“) gelten nur für den Anker davor.
Gemessen mit einer Sonde über alle 128 Etappenrichtungen (dieselben Funktionen `face_heading`, `heading_basis`,
`near_shift` mit dem echten `RoadPath3D`, die Grundrisse aus `mesh_parts`/`proc_mesh`; `m1/NACH-R7b/probe/`,
`m1/NACH-R7b/gates/probe.log`): 66 Modelle und Formen (38 `props/church`, 5 `props/building_tall`, 3 `landmarks/michel`,
20 prozedurale Formen); Drehung bis 33,4° (Kuppelkirche vor Berlin), Verschiebung bis **11,89 m** (Kirche
`bremen_amsterdam` aus Bremen, Drehung −10,6°), 24 über 2 m, 13 über 5 m. Auf dem Bildschirm sind das bei 600 m etwa
14 px, bei 250 m etwa 34 px (gefolgert mit FIX-R7bs eigenem Maß 44,7 px für 37,8 m bei 600 m) – unter der Grenze von
64 px, aber genau der Fehlerart, die B-04 behoben hat. Gut: kein Eck kommt näher an den Fahrbahnrand als bei R7b
(kleinster Abstand jetzt 22,2 m, R7b 21,9 m; für keines kleiner).
Vorschlag: im Netztest auch den Ursprung des fertigen Knotens gegen Arcades Anker prüfen (Grenze z. B. 5 m oder in px
bei 600 m), oder um die straßennahe Ecke statt um den Anker drehen; die Doku um den Wert der Verschiebung ergänzen.

### Hinweis (kein Befund dieser Runde)

- `assets/shaders/modern/reflector.gdshader` Zeile 21 (Besitzer `layers/lights.gd`): `px_per_m =
  PROJECTION_MATRIX[1][1] * 0.5 * VIEWPORT_SIZE.y / dist`, die Mindestgröße `min_px * (VIEWPORT_SIZE.y / 720) /
  px_per_m` – das `VIEWPORT_SIZE.y` kürzt sich heraus, das Vorzeichen nicht: ist die Skala negativ (wie FIX-R7b für den
  Vertex-Schritt fand), wird die Mindestgröße negativ und `max()` wählt immer die Instanzgröße; liest `VIEWPORT_SIZE`
  0, ist es 0/0. Die Mindestgröße der Reflektorpunkte greift dann nie (gefolgert aus dem Code, nicht gemessen; wie
  FIX-R7b gemeldet).

## 4. Gates (Kopf `c50d58f`, gemessen)

Logs in `m1/NACH-R7b/gates/`. Jedes Spiel mit eigenem absolutem `XDG_DATA_HOME`, schwere Läufe einzeln mit `nice -n 10`.

| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | sauber (`m1/NACH-R7b/import.log`) |
| Skripte | `tests/check_scripts.gd` (in `run_tests.sh`) | „334 Skripte geprüft, 0 fehlerhaft“ |
| Einheitstest Wahrzeichen | `tools/run_tests.sh test_landmarks` | 10 Tests, 0 fehlgeschlagen; „Anker wie Arcade bei 143 Wahrzeichen (größter Unterschied 0.151 m), 23 gespiegelt“ |
| Szenenprüfung | `tools/run_tests.sh check_landmarks` | `CHECKS OK`: reichweite, nacht, position (0,0 px Bild und Modell bei 600 m), prozedural, weich, skyline |
| Gehaltene Fixes TB1 | `tools/run_tests.sh far_ground_water`, `… test_props` | 4 / 0 fehlgeschlagen; 13 / 0 fehlgeschlagen |
| Render-Prüfung des Pakets | `tools/run_render_checks.sh modern landmarks_render` | 7/7 OK: `nacht_hell` 0,99 × Arcade, `flugfeuer` 28 rote Pixel (Arcade 28), `anstrahlung` Dom 1,32 × / 0,97 ×, Fourvière 1,71 × / 1,05 ×, `wahrzeichen_stelle` (18, 4) px |
| Gehaltene Render-Prüfungen | `… modern start_km0`, `terrain_cover`, `light_base`, `seam_render` | je OK: kamera ≤ 1,14 px, auto, boden; T1–T4, S1, C1, **K1** 0,000 % Magenta; tageslicht, schatten; selbsttest … `arcade_gleich` 0 Pixel, `fenster_16_10` |
| Fairness | `tests/sim/modern_sight.gd -- --full` | OK: F1 0 Fälle bis 270 m (99.424.500 Stichproben, 128 Richtungen), F1 Spuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 5.923, F7 0 von 2.011.532, Modell 0 abweichend (136 s). Hinweis: `modern_sight` kennt keine Wahrzeichen – für deren neue Lage gilt die Sonde in §3 (kein Eck näher an der Straße) |
| Arcade-Identität (einmal) | `tools/golden.sh check` | „GOLDEN arcade: 20 von 20 identisch“, „GOLDEN arcade-ui: 17 von 17 identisch“ |
| Mutation | `m1/NACH-R7b/sh/mutate.py` + `run_render_checks.sh modern landmarks_render` | beide alten Fehler zurück → `nacht_hell` FEHLER (1,22 ×), `flugfeuer` FEHLER (95.297 rote Pixel, 15,96 % des Bildes); danach Shader aus `HEAD` wiederhergestellt, `git status` leer |

Nicht gelaufen (bewusst): `tools/run_tests.sh` ohne Filter (FIX-R7b grün; hier nur die Dateien der geänderten
Bereiche), `tools/golden.sh modern-check` (A-18: Sache der Montage; FIX-R7b meldet 5/6 mit dem Michel), Etappenläufe
und Leistung (FIX-R7b gemessen; meine Bilder zeigen keine Skript- oder Shaderfehler in den Logs).

## 5. Bilder und ehrliches Urteil gegen Arcade

Alle „Hoch“ 1280 × 720 (Deck-Bilder „deck“ 1280 × 800), Seed 11, Autopilot, Start 50 km/h, Bild nach 1 s (das „LOS!“
liegt in allen Bildern), je Arcade | R7b `2c154bc` | FIX-R7b `c50d58f` im selben Simulationszustand
(`tools/ab_shot.sh` + Modern-Lauf der Kopie). Bögen in `deliver/NACH-R7b/boegen/`, Zooms in `deliver/NACH-R7b/`.

| Bild | Urteil |
|---|---|
| `B01_elbphilharmonie_22uhr_zoom.png`, `boegen/hamburg_22_abc.jpg`, `boegen/deck_hamburg_22_abc.jpg` | **gleich Arcade** in Helligkeit und Kontrast der Fassade (vorher ausgewaschen); Modern zeigt das Gebäude etwas größer, mit beleuchtetem Sockel |
| `B02_florianturm_22uhr_zoom.png`, `B02_florianturm_deck_22uhr_zoom.png`, `boegen/dortmund_22_abc.jpg` | Flugwarnlicht **gleich Arcades Punkt** (vorher roter Fleck); der Turm plastischer als Arcades Fläche; Lage ≈ 50 px rechts von Arcade wie schon bei R7b |
| `B02_madrid_22uhr_zoom.png`, `boegen/madrid_22_abc.jpg` | Licht gleich klein wie Arcade; die Türme nachts mit mehr und helleren Fenstern als Arcade (unverändert seit R7b) |
| `bremer_dom_22uhr_zoom.png`, `boegen/bremerdom_22_abc.jpg` | Turm **an Arcades Stelle** (vorher ≈ 64 px daneben), angestrahlt wie Arcade, etwas wärmer |
| `hannover_nah_22uhr_kuppelschein_zoom.png`, `boegen/nah_hannover_22_abc.jpg` | **plastischer als Arcade**, Kuppelschein in Arcades Größe, Trommel heller als Arcade |
| `michel_12uhr_zoom.png`, `boegen/hamburg_12_abc.jpg` | bei Tag gleichwertig; der Michel zur Anfahrt gedreht, ≈ 7 px neben Arcade |

Ehrlich: FIX-R7b macht die Nachtbilder der Bild-Wahrzeichen und die Lichtpunkte **gleich Arcade** – nicht besser.
Besser als Arcade sind nur die 3D-Formen und Modelle (Hannover, Dortmund, Bremer Dom: plastisch statt flach). Echte
Wahrzeichen-Modelle (AS6) fehlen weiter; die Elbphilharmonie bleibt Arcades Bild.

## 5a. Mutation (wachen die neuen Prüfungen?)

Beide alten Fehler von R7b zugleich in `landmark.gdshader` zurückgesetzt (lineare Mischung in CE_PICTURE, Vorzeichen
der Projektionsskala im Leuchtpunkt): `nacht_hell` FEHLER (Modern 140,8 gegen Arcade 115,9 = 1,22 ×), `flugfeuer`
FEHLER (95.297 rote Pixel gegen 28, Wahrzeichen 15,96 % des Bildes – mit der neuen Sicherheitsgrenze von 25 % wäre der
alte Fehler noch größer als bei R7b). `anstrahlung` bleibt grün (Fourvière 1,06 ×) – es prüft das Anstrahlen, nicht
die Lichtebene; das ist richtig so. Log `m1/NACH-R7b/gates/mutation_B01_B02.log`.

## 6. Hinweise für die Nächsten

1. **RINT-M3**: N-1 entscheiden (Test des Knotenursprungs oder Drehung um die straßennahe Ecke); die Doku §18.1 nennt die
   Verschiebung nicht. Golden `modern_s4_mittel` nach dem Merge neu erzeugen (Michel, wie FIX-R7b).
2. **Besitzer `lights.gd` / `reflector.gdshader`**: Mindestgröße der Reflektorpunkte mit `abs()` und Bildhöhe als Uniform
   (siehe Hinweis §3) – gefolgert.
3. **QA-mid**: Nachtbilder „deck“ für Dortmund, Madrid, Hamburg sind jetzt wie Arcade (hier gemessen); das Leuchtfeuer
   von Calais ist weiter in keinem Bild nachgeprüft. Den Versatz des Florianturms (≈ 50 px bei km 225) mit `look_gain` 0
   ansehen (Kurvengeometrie wie Belgrad?).
4. **AS6**: Modelle mit Hauptachse auf dem Ursprung und +Z zur Anfahrt (wie FIX-R7b schreibt); N-1 betrifft sie ebenso.

## 7. Ablage und Aufräumen

- Werkzeuge: `m1/NACH-R7b/sh/` (`abc.sh`, `pics.sh`, `measure.py`, `redclusters.py`, `zoom.sh`, `gates.sh`,
  `mutate.py`, `make_base.sh`); Sonde `m1/NACH-R7b/probe/test_zz_nach_r7b_probe.gd` (lag nur während der Messung im
  Arbeitsbaum, danach entfernt).
- Rohbilder `m1/NACH-R7b/raw/`; die Kopie von `2c154bc`, die Shader-Caches und die `XDG_DATA_HOME`-Ordner sind gelöscht.
- Arbeitsbaum ohne Änderungen (`git status` leer), kein Commit.
