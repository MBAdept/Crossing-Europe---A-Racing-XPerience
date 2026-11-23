# NACH-R7c – Nachprüfung der Nacharbeit FIX-R7c (Fern-LOD der Bauten und Pflanzen)

- Geprüfter Stand: FIX-R7c `3b3107b` (`origin/wip/v080-fix-r7c`), Vergleich gegen R7c `bd1803b`, die Basis `9b02f05`
  (RINT-M2) und `43a1fcc` (Basis + AS5aR2, vor R7c). Arbeitsbaum
  `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-12` (nur `--ff-only` auf `3b3107b`,
  keine Commits, kein Push, `git status` am Ende sauber).
- Prüfrolle: Ich habe dem Bericht von FIX-R7c nicht geglaubt, sondern jede Behauptung zu QR7c-01, -02 und -06 selbst
  nachgestellt (Bilder mit `tools/ab_shot.sh`, Mutationen, Render-Prüfungen, Zusammenführungsprobe).
- **gemessen** = auf dieser VM (llvmpipe unter Xvfb, 4 Kerne geteilt); **angesehen** = Urteil nach Bildern, die ich
  geöffnet habe; **gefolgert** = hier nicht messbar (echte GPU, Steam Deck, Wirkung auf einen Menschen, längere Fahrten).
- Die Bilder „Basis“, „43a1fcc“ und „R7c“ sind QA-R7cs Rohbilder (`deliver/QA-R7c/raw`) desselben Simulationsstands. Dass
  sie vergleichbar sind, ist gemessen: meine Arcade-Bilder sind bit-gleich mit QAs Arcade-Bildern (0 px), und meine
  Modern-Bilder des Kopfes sind bit-gleich mit denen, die FIX-R7c geliefert hat (0 px in allen sieben Bildern).

## 1. Ergebnis in Kürze

| Befund | Urteil | Kern des Belegs |
|---|---|---|
| QR7c-01 lod0 aller Stadthäuser 35 m | **behoben** | `tag:city` ist aus der Konfiguration entfernt. Beim Speicher in Hamburg auf „Deck“ sind die Kassettentüren wieder da wie bei 43a1fcc (angesehen). Gegen 43a1fcc unterscheiden sich nur 432 / 1 330 px um mehr als 15 %, gegen R7c 25 139 / 12 757 px (gemessen). |
| QR7c-02 Wachen | **behoben** (im Umfang des Befunds) | Alle zehn QA-Mutationen, die ich auf dem Endstand nachgefahren habe, werden gefangen; die Testfälle (a)–(f) von QA sind vorhanden. Neue Lücken gibt es in den Wachen des **neuen** FIX-Codes (neuer Befund NR7c-02). |
| QR7c-06 Raster bei stehender Kamera | **teilweise** | Im Stand ist es behoben: Die Countdown-Eiche ist glatt (Körnung 0,67 %, Basis 0,73 %, R7c 3,77 %, gemessen). Beim Anfahren und bei jeder Fahrt über 1,5 m/s, etwa im Stau-Kriechgang, kehrt das Raster zurück: 0,8–1,5 s nach „LOS!“ 4,15 % bzw. 3,12 % (gemessen, neuer Befund NR7c-01). |

Neue Befunde (Einzelheiten in Abschnitt 4): **NR7c-01** (niedrig–mittel): Raster und Hin-und-her der Stufen beim Anfahren
bzw. im Kriechgang. **NR7c-02** (niedrig): vier Mutationen am neuen FIX-Code bleiben grün, darunter „das globale
`ce_lod_still` wird nie gesetzt“ – damit lässt sich der ganze QR7c-06-Fix abschalten, ohne dass ein Test rot wird.
**NR7c-03** (Kleinigkeit): Ein Kommentar in `props.gd` beschreibt noch die verworfene Bandmitte.

Gates (Abschnitt 5): Skripte 331/0, `test_props` 26/0, `test_far_ground_water` 4/0, alle Render-Prüfungen der
geänderten Dateien und die Wächter des ersten Testbuilds OK. Arcade ist unverändert: `golden.sh check` meldet 20 von 20
und 17 von 17 identisch. FIX-R7c lässt sich mit FIX-RINT, FIX-R7a und FIX-R7b in jeder geprüften Reihenfolge
konfliktfrei zusammenführen; der einzige Konflikt des Vierer-Zusammenbaus liegt zwischen den anderen drei Zweigen in
`docs/renderer-modern.md`. Im Vierer-Baum sind Skripte, `test_props` und `check_lod_band` grün.

**Urteil:** FIX-R7c ist eine solide Grundlage für RINT-M3. QR7c-01 und die Wachen sind sauber erledigt. Den Stand löst
das Band, das Anfahren noch nicht. Das ist kein Blocker für den Zusammenbau, sollte aber vor Testbuild 2 gelöst werden:
Der Vorschlag aus NR7c-01 kommt mit derselben globalen Variable aus und ist zugleich die Zeitblende, die A-16 verlangt.

## 2. Diff `bd1803b..3b3107b` – Umfang und Nebenwirkungen

- 8 Commits und 9 Dateien: `lod_band.gdshaderinc`, `config/game_config.json` (nur `graphics`: `_doc` und
  `modern.props`), `docs/renderer-modern-gelaende.md`, `builders/props.gd`, `modern_materials.gd` (eine Zeile in
  `GLOBALS`), `tests/golden/modern_slice.{env,md5}`, `check_lod_band.gd` und `test_props.gd`. Alle diese Dateien gehören
  laut Brief zu R7c (`m1/lead/m5_body.js`, R7c-Abschnitt). Eine eingefrorene Arcade-Datei ist nicht dabei, eine fremde
  Datei auch nicht.
- Die Modern-Goldens hat das Paket selbst erneuert. Der Brief erlaubt das („LOOK … before renewing them in your
  branch“), A-18 und §5 W5 sehen es nicht vor. Von den vier Zweigen ändert nur R7c-Linie `tests/golden/` – das gibt
  keinen Konflikt. Nach dem Zusammenbau erneuert die Montage die Goldens ohnehin einmal.
- Placement: Kein ausgeliefertes Modell nutzt `attach` (`grep '"attach"' assets/models/manifest.json` = 0). Die neue
  Regel „Anbau jenseits des Stücks wird nicht gestellt“ ändert also heute keine Platzierung. Deshalb ist
  `modern_sight --full` nicht nötig (nicht gelaufen).
- Code gelesen und für richtig befunden:
  - Der Schwellen-Schlüssel in `_apply_lod()` stimmt: `bsearch(span.y, false)` gegen „≥ Bandanfang − 2 m“ und `lod0/lod1`,
    `bsearch(span.x, true)` gegen „≤ Bandende + 2 m“ und die Schattenreichweite. Damit wechselt der Schlüssel genau
    dann, wenn sich eine Sichtbarkeit ändern kann.
  - Die fernste Ecke wird je Achse ohne Schleife bestimmt.
  - Das Verengen im Shader ist komplementär (beide Nachbarn verengen dasselbe Band).
  - `ce_lod_hidden()` nimmt das unverengte, also weitere Band, und bleibt damit konservativ.
  - Der Schattendurchgang folgt dem verengten Band.
  - Die Uhr ist `view.time` = `_real_time` der Sitzung. Sie läuft auch im Countdown und steht in der Pause.
    Wird dieselbe Ansicht zweimal gezeichnet, ändert sich nichts.
- Merkpunkt ohne Befund: Bleibt nach einem Rennen `ce_lod_still` = 1 global stehen, wirkt das auf Materialien ohne Band
  (Ausstellungsraum) nicht: Das Standardband (−2, −1, 1e9, 2e9) bleibt auch verengt ohne Verwerfen (nachgerechnet). Die
  Doku sagt „bleibt es 0“. Das stimmt nur in einem frischen Prozess, ist aber folgenlos.

## 3. Die drei Befunde im Einzelnen

### QR7c-01 – lod0 der Stadthäuser → behoben

- Konfiguration: `lod0_m` enthält nur noch Fachwerk, Fachwerk B, Haussmann und Pariser Eckhaus mit je 30 m, `tag:city`
  ist weg. `test_lod_bands_per_model` prüft Speicher, Kontor, Gründerzeit und Grachtenhaus auf „kein Ersatz“.
- Nachgestellt mit `SCREEN=1280x800 GFX_ARGS=--gfx-preset=deck tools/ab_shot.sh … --stage=kiel_hamburg --from=kiel
  --start-km=88.2 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never
  --traffic-warmup --no-countdown --start-speed=50 --shot-times=2,4` (gemessen):

  | Kopf gegen | > 15 % anders, Bild 00 / 01 |
  |---|---|
  | 43a1fcc (vor R7c) | 432 / 1 330 px |
  | R7c `bd1803b` | 25 139 / 12 757 px |
  | Basis `9b02f05` | 1 733 / 2 706 px |
  | FIX-R7cs eigenes Bild | 0 / 0 px (bit-gleich) |

- Angesehen: `qr7c01_hamburg_deck_speicher_arcade_43a1fcc_r7c_kopf.png` (Ausschnitt 1:1). Die grünen Ladetüren haben
  wieder ihre Kassetten, die Fenster ihre Laibungen; das Bild ist wie bei 43a1fcc, bei R7c waren es flache Platten.
  Gegen Arcade ist Modern hier **klar besser**: Backstein, Gesimse und Türen sind plastisch und scharf, Arcade zeigt ein
  weiches Sprite.
- Nebenbei angesehen: Nürnberg „Deck“ km 102,0 (`nu_deck_barockhaus_arcade_basis_r7c_kopf.png`). Das rosa Barockhaus
  bei etwa 35 m steht wieder sauber in lod0 wie in der Basis; bei R7c war es im Band gerastert. Die Fensterrahmen sind
  weiß und scharf. Gegen R7c 276 / 10 400 px (gemessen), gegen Arcade klar besser.
- Rest (FIX-R7c hat es als Vertragsfrage gemeldet, ich bestätige es nur): Grachtenhaus und Chalet flimmern in lod0 bei
  40–60 m mehr als 2 × ihr Sprite. Das ist Leitentscheid 1 gegen 3; hier nicht neu gemessen.

### QR7c-02 – Wachen → behoben (im Umfang des Befunds)

Mutationen auf dem Endstand `3b3107b`: je eine Zeile im Arbeitsbaum, danach aus `git show HEAD:` zurückgeschrieben,
`git status` am Ende sauber (`m1/NACH-R7c/mutate.py`, Logs `m1/NACH-R7c/mutlogs/`). Alles gemessen:

| Mutation | geändert | Ergebnis | fängt |
|---|---|---|---|
| U3 Phase konstant | `instance_phase` → 0 | **rot** | `test_instance_phases_differ` |
| U4 `ground_sink` wirkungslos | Minimum nicht gebildet | **rot** | `test_ground_sink_and_align_on_a_slope` |
| U5 `ground_align` wirkungslos | Basis unverändert | **rot** | dto. |
| U7 `far_sun` nicht gesetzt | 1.0 statt Wert | **rot** | `test_far_light_reaches_the_materials` |
| U8 Laub-Phase aus der Weltlage | `wp.x*0.37…` | **rot** | `test_shader_rules_of_the_far_lod` |
| U10 Anbau nie weggelassen | ohne `drop_reason` | **rot** | `test_attachments_respect_the_corridor_and_the_chunk` |
| R3 Fernlicht aus | `return att` | **rot** | `test_shader_rules_of_the_far_lod` |
| R4 Fensterdeckung aus | `cover_k = 0` | **rot** | dto. |
| R5 Alphatest ohne `cutout_bias` | | **rot** | dto. |
| R6 Relief nachts nicht zurück | | **rot** | dto. |
| R2 Schattendurchgang gerastert | `shadow > 5.0` | **rot** | `check_lod_band` „lod_ueberblenden“ 1,2 % gegen hart 7,1 % (Grenze 15 %) |
| N2 Uhr = dt statt `view.time` | `if false:` | **rot** | `test_standing_camera_narrows_the_bands` |
| N6 Shader ignoriert `ce_lod_still` | `still = 0.0` | **rot** | `test_shader_rules_of_the_far_lod` und `check_lod_band` …_stand 6,50 % / 35,78 % |
| N1 `quality_lowered()` ohne `_thresholds(h)` | | **grün** | – (NR7c-02) |
| N3 Schwelle der Schattenwerfer fehlt | `hi` ohne `_shadow_m + KEEP` | **grün** | – (NR7c-02) |
| N4 fernste Ecke falsch | `.min(` statt `.max(` | **grün** | – (NR7c-02) |
| N5 globales `ce_lod_still` nie gesetzt | `set_global` → `pass` | **grün** | – (NR7c-02) |

- Die Testfälle (a) bis (f), die QA vorgeschlagen hat, sind alle da:
  - (a) Fernlicht auf dem Material
  - (b) Shadertext ohne Kommentare
  - (c) Phasen
  - (d) Hang
  - (e) Anbau im Kurvenkorridor
  - (f) Render-Prüfung „fernlicht“: gemessen +3,7 / +3,9 % mit Fernlicht, +11,9 / +12,2 % ohne
- U1, U2, U6, U11, R1 und R2b habe ich nicht erneut gefahren. QA hat sie schon auf R7c gefangen, und die Tests dazu sind
  unverändert.

### QR7c-06 – Raster bei stehender Kamera → teilweise behoben

- **Stand behoben** (gemessen + angesehen). Countdown Nürnberg – Fulda km 0, „Deck“, 1,5 s:
  - `qr7c06_countdown_deck_eiche_arcade_basis_r7c_kopf.png` (2×): Die Eiche ist im Kopf glatt und in lod0 wie in der
    Basis; bei R7c war sie gerastert.
  - Körnungsmaß `grain.py` (Anteil der Kronenpixel mit mehr als 24 Luma-Stufen Abstand zum 3×3-Median): Basis 0,73 %,
    R7c 3,77 %, Kopf 0,67 %.
  - `check_lod_band` „…_stand“: 0,00 % Abweichung vom harten Wechsel (gemessen).
  - Gegen Arcade ist die Eiche klar besser: plastische Krone mit Licht und Schatten, Arcade zeigt ein weiches Sprite.
- **Anfahren nicht behoben** (gemessen + angesehen). Dieselbe Szene mit Bildern bei 1,5 / 3,3 / 3,8 / 4,5 / 6,0 s
  (`qr7c06_anfahren_deck_eiche_1.5_3.3_3.8_4.5_6.0s.png`):

  | Zeitpunkt | Zustand | Körnung |
  |---|---|---|
  | 1,5 s | Countdown | 0,67 % |
  | 3,3 s | | 0,69 % |
  | 3,8 s | 16 km/h | **4,15 %** |
  | 4,5 s | | **3,12 %** |
  | 6,0 s | Eiche aus dem Bild | – |

  Sobald die Kamera schneller als 1,5 m/s fährt, öffnet sich das Band in 0,4 s wieder ganz. Die Eiche steht dann noch
  mitten im Band (53–67 m) und zeigt das Raster wie bei R7c, so lange, bis sie das Band verlassen hat. Beim langsamen
  Anfahren ist das etwa 1 s; im Stau-Kriechgang mit 2–5 m/s wären es 3–7 s je Baum (gefolgert aus 14 m Bandbreite).
- Dazu kommt ein Hin und Her der Stufen: Im Stand zeigt die Eiche lod0, weil das Band zum fernen Ende verengt ist. Beim
  Anfahren blendet trotz Annäherung lod1 zur Hälfte ein, erst später wieder lod0. QA hatte den Stau ausdrücklich genannt;
  der Stau ist überwiegend Kriechen. Deshalb lautet mein Urteil „teilweise“. Lösungsvorschlag: siehe NR7c-01.

## 4. Neue Befunde

### NR7c-01 (niedrig–mittel) – Raster beim Anfahren und im Kriechgang, Stufe springt zurück

- **Wo:** `builders/props.gd` `_update_still()` / `still_step()` (eine Schwelle 1,5 m/s, sonst 0) und
  `inc/lod_band.gdshaderinc` `ce_lod_discard()`.
- **Problem:** Das Band ist räumlich (±12 %, 4–25 m). Bei geringer Geschwindigkeit dauert der Weg durch das Band
  Sekunden statt der 0,3–0,5 s aus A-16. `ce_lod_still` kennt nur zwei Zustände, „steht“ und „fährt“.
- **Beleg (gemessen + angesehen):** Siehe QR7c-06 oben – Körnung 4,15 % bei 3,8 s und 3,12 % bei 4,5 s, gegen 0,67 % im
  Countdown und 0,73 % in der Basis.
- **Nachstellen:**
  `SCREEN=1280x800 GFX_ARGS=--gfx-preset=deck tools/ab_shot.sh <out> --stage=nuernberg_fulda --from=nuernberg
  --start-km=0 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never
  --traffic-warmup --shot-times=1.5,3.3,3.8,4.5,6.0`, dann die Eiche rechts ausschneiden (`m1/NACH-R7c/montage.sh`,
  `grain.py`).
- **Vorschlag:** Mit derselben globalen Variable die Bandbreite an die Geschwindigkeit binden statt an „steht / fährt“:
  `ce_lod_band_m` = Kamerageschwindigkeit × 0,4 s, und im Shader `w' = min(w, ce_lod_band_m)` beim Verengen zum fernen
  Ende.
  - Im Stand bleibt der harte Wechsel am fernen Ende, wie FIX-R7c ihn jetzt hat.
  - Beim Anfahren bleibt eine Instanz mitten im Band in lod0, solange `w'` kleiner ist als ihr Abstand zum Bandende –
    also kein Raster und kein Zurückspringen.
  - Eine Instanz, die das ferne Ende kreuzt, blendet in etwa 0,4 s über, bei jeder Geschwindigkeit. Das ist genau die
    Zeitblende von A-16, ohne Zustand je Instanz.
  - Wer es kleiner will: die Schwelle 1,5 m/s durch eine Rampe ersetzen (1 bei 0 m/s, 0 erst ab etwa 10 m/s).

### NR7c-02 (niedrig) – Wachen des neuen FIX-Codes lückenhaft

- **Wo:** `tests/unit/race3d/test_props.gd`.
- **Problem:** Vier einzeilige Mutationen am neuen Code bleiben grün (Tabelle oben):
  - **N5** (`set_global("ce_lod_still")` entfernt) schaltet den QR7c-06-Fix im Spiel ganz ab.
    `test_standing_camera_narrows_the_bands` prüft nur `lod_still()` des Builders, und `check_lod_band` setzt die globale
    Variable selbst.
  - **N1:** Fehlt `_thresholds(h)` in `quality_lowered()`, schalten die Stufenknoten nach einer Absenkung durch den
    Wächter an veralteten Schwellen. Zwischen alter und neuer Bandgrenze fehlt dann der Knoten der gröberen Stufe, und
    es entstehen Löcher (gefolgert aus dem Code).
  - **N3:** Die Schwelle der Schattenwerfer kann fehlen, ohne dass ein Test es merkt.
  - **N4:** Die fernste Ecke im Zweig mit echter Kamera ist ungeprüft; kein Test hat eine Renderer-Kamera.
- **Beleg (gemessen):** `m1/NACH-R7c/mutlogs/mutate.out` – „26 Tests, 0 fehlgeschlagen“ bei N1, N3, N4 und N5.
- **Vorschlag:**
  - (a) Den Wert festhalten, den `ModernMaterials.set_global()` zuletzt gesetzt hat (kleiner Spiegel in
    `modern_materials.gd`, auch Datei von R7), und im Test prüfen, dass nach `update()` im Stand 1 und in Fahrt 0 ankommt.
  - (b) Im Test von `quality_lowered`: nach `quality_lowered()` + `update()` an einer Kamera zwischen alter und neuer
    Bandgrenze ist der Knoten lod1 sichtbar.
  - (c) Ein Stück mit Werfer knapp innerhalb und außerhalb von `_shadow_m + SHADOW_KEEP_M` prüfen.
  - (d) `_span()` mit einem `eye`-Vektor gegen eine Schleife über die 8 Ecken prüfen.

### NR7c-03 (Kleinigkeit) – Kommentar beschreibt die verworfene Bandmitte

`scripts/race3d/builders/props.gd` Z. 75, an `LOD_STILL_SPEED`: „every band narrows to a hard swap at its middle“. Der
Code und der Shader verengen zum **fernen Ende**. Die Doku in `renderer-modern-gelaende.md` §9.1 ist richtig.

## 5. Gates auf `3b3107b` (meine Läufe, Logs `m1/NACH-R7c/gates/`, `XDG_DATA_HOME` absolut unter `m1/NACH-R7c/`)

| Gate | Befehl | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import .` | Exit 0, keine Fehlerzeile |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | „331 Skripte geprüft, 0 fehlerhaft“ |
| Unit `test_props` | `-s res://tests/run_tests.gd -- --filter=test_props` | „26 Tests, 0 fehlgeschlagen“ |
| Unit `test_far_ground_water` | dto. | „4 Tests, 0 fehlgeschlagen“ |
| Render `check_lod_band` | `tools/run_render_checks.sh modern check_lod_band` | OK: lod_ueberblenden 0,6 % gegen hart 7,1 %, lod_baum 1,1 % gegen 36,6 %, beide …_stand 0,00 %, fernlicht +3,7 / +3,9 % (ohne Fernlicht +11,9 / +12,2 %) |
| Render `check_start_km0` | dto. | OK (Kamera 1,14 px, Auto +0/+1 px, Boden 0,034) |
| Render `check_terrain_cover` | dto. | OK, T1–T4, S1, C1 und K1: 0,000 % Magenta, K1 Fernboden 0,00 % |
| Render `check_light_base` | dto. | OK (tageslicht, schatten) |
| Render `check_weather` | dto. (nur `check_weather.gd` – dort fand FIX-R7c seinen dt-Fehler) | OK (teilchen, gischt, nass, tunnel, schneewall) |
| Render `check_props_render` | dto. | OK (props_spiegel, rotor) |
| Render `check_session_modern` | dto. | OK (pause: 30 Bilder in der Pause 0 px verschieden – die Uhr `view.time` steht; rueckfall; freigabe) |
| Render `check_instance_budget` | dto. (`check_instance_budget.gd`) | OK (Fahrzeug-Ebene höchstens 128, ganze Szene höchstens 141 mit Instanz-Uniforms, Grenze 230) |
| Mutationen | `m1/NACH-R7c/mutate.py` | 13 von 17 rot (Abschnitt 3), 4 grün (NR7c-02) |
| Zusammenführung | `git merge-tree` in einem Scratch-Klon (`--shared`), Zweierproben und Ketten in drei Reihenfolgen | Mit FIX-RINT, FIX-R7a und FIX-R7b je Exit 0. Viererkette in drei Reihenfolgen: Der einzige Konflikt ist `docs/renderer-modern.md` zwischen FIX-RINT / FIX-R7a / FIX-R7b – keine Datei von FIX-R7c. Den Vierer-Baum (Reihenfolge R7a → R7b → FIX-RINT → FIX-R7c) habe ich mit `git archive` und `.godot` ausgepackt und importiert (Exit 0). Ergebnisse: Skripte „338 Skripte geprüft, 0 fehlerhaft“; `test_props` 26/0, `test_far_ground_water` 4/0, `test_chunk_streamer` 9/0, `test_sight_corridor` 8/0; `check_lod_band` OK, mit denselben Werten wie auf dem Kopf. |
| Arcade-Identität (einmal, am Ende) | `tools/golden.sh check` | Exit 0: „GOLDEN arcade: 20 von 20 identisch“ (164 s), „GOLDEN arcade-ui: 17 von 17 identisch“ (196 s) |

Nicht gelaufen: `tools/run_tests.sh` komplett, weil FIX-R7c es zweimal auf dem Endstand hatte und ich nur Dateien mit
eigenen Prüfungen geändert sehe; die übrigen Render-Prüfungen; `modern_sight --full` (keine Platzierung geändert).

## 6. Bilder (angesehen) – `deliver/NACH-R7c/`

| Datei | Inhalt | Urteil |
|---|---|---|
| `qr7c01_hamburg_deck_speicher_arcade_43a1fcc_r7c_kopf.png` | Speicher Hamburg, „Deck“, 1:1: Arcade, 43a1fcc, R7c, Kopf | Kopf = 43a1fcc (Kassettentüren), R7c flach; Modern klar besser als Arcade |
| `hh_deck_h12_tri_00/01.jpg` | ganzes Bild: Arcade, R7c, Kopf | gleich zu R7c bis auf den Speicher; Modern besser als Arcade (Tiefe, Gehweg, Bäume) |
| `qr7c06_countdown_deck_eiche_arcade_basis_r7c_kopf.png` | Countdown-Eiche 2×: Arcade, Basis, R7c, Kopf | Kopf glatt wie die Basis, R7c gerastert; Modern klar besser als Arcade |
| `qr7c06_anfahren_deck_eiche_1.5_3.3_3.8_4.5_6.0s.png` | dieselbe Eiche beim Anfahren | Raster bei 3,8 und 4,5 s (NR7c-01) |
| `nu_deck_barockhaus_arcade_basis_r7c_kopf.png`, `nu_deck_h12_tri_00/01.jpg` | Nürnberg „Deck“ | Barockhaus sauber in lod0 wie in der Basis; Modern klar besser als Arcade |

Ehrlich gegen Arcade:

- Bei Tag ist Modern in den angesehenen Stadtbildern klar besser als Arcade: Tiefe, Gesimse, Türen, plastische Kronen.
- Nachts, im Lyon-Vorort und im Wald bleibt Modern laut QA-R7c und FIX-R7c hinter Arcade. Das habe ich hier nicht neu
  angesehen; FIX-R7c ändert daran nichts.
- Das Anfahren nach dem Countdown zeigt etwa 1 s lang gerasterte Kronen im Band – das ist schlechter als die Basis,
  in der Arcade gibt es so etwas nicht.

## 7. Vertragsfragen

1. **A-16:** A-16 verlangt eine Zeitblende von 0,3–0,5 s. Gebaut ist ein Wegband plus eine globale Zeitrampe „steht /
   fährt“. Die Leitung sollte entweder das Wegband ausdrücklich annehmen, oder sie nimmt die geschwindigkeitsabhängige
   Bandbreite aus NR7c-01 – die erfüllt A-16 ohne Zustand je Instanz.
2. **A-18 gegen Brief:** Die Modern-Goldens hat das Paket erneuert. Der Brief erlaubt es, A-18 und §5 nicht. Es entsteht
   kein Konflikt (nur dieser Zweig ändert `tests/golden/`), und nach dem Zusammenbau wird ohnehin neu erzeugt.
3. **Leitentscheid 1 gegen 3** (von FIX-R7c gemeldet, hier bestätigt): Grachtenhaus und Chalet in lod0 flimmern über
   2 × ihr Sprite; der Look hat Vorrang bekommen.

## 8. Für die nächsten Schritte

1. **RINT-M3:** FIX-R7c zuletzt oder in beliebiger Reihenfolge mergen; nur `docs/renderer-modern.md` braucht eine Hand,
   und zwar zwischen FIX-RINT, R7a und R7b. Danach `test_props` und `check_lod_band` laufen lassen. Den Vierer-Baum habe ich geprüft (Abschnitt 5): Skripte, `test_props`, `test_chunk_streamer`, `test_sight_corridor` und `check_lod_band` sind grün. Damit ist FIX-R7cs offener Punkt „Dreier-Zusammenführung nicht geprüft“ erledigt.
2. **R7 (Nacharbeit vor Testbuild 2):**
   - NR7c-01: Bandbreite = Geschwindigkeit × 0,4 s – betrifft `props.gd` und `lod_band.gdshaderinc`, beides Dateien von R7.
   - NR7c-02: die Tests (a)–(d).
   - NR7c-03: den Kommentar korrigieren.
3. **QA-mid:** einen Clip vom Start (Countdown → 10 s Fahrt) und vom Stau-Kriechgang bei „Mittel/Deck“ Bild für Bild
   ansehen, ob in den ersten Sekunden Kronen und Fassaden im Band rastern.

## 9. Werkzeuge und Rohdaten (ungetrackt, `m1/NACH-R7c/`)

- Skripte:
  - `pics.sh`, `driveoff.sh` – Bilder mit `ab_shot.sh`
  - `cmp.sh` – Pixelvergleich
  - `montage.sh` – Ausschnitte
  - `grain.py` – Körnungsmaß
  - `mutate.py` – Mutationen
  - `q_mut.sh`, `q_render.sh` – Warteschlangen
  - `chain_merge.sh`, `merge_tree_export.sh` – Zusammenführungsprobe im Scratch-Klon `mclone`
- Logs: `logs/`, `gates/`, `mutlogs/`
- Rohbilder: `shots/`
