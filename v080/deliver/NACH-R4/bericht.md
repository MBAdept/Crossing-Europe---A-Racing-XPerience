# NACH-R4 – Nachprüfung der Nacharbeit FIX-R4 (Licht, Nacht, Wetter)

Geprüft: Kopf `b156763` (`origin/wip/v080-fix-r4`) gegen R4s Kopf `7f0eae2` und gegen Arcade. Prüfrolle: keine Commits,
kein Push, kein eigener Zweig. Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7`
(per `git merge --ff-only b156763` auf den Kopf gesetzt, nichts geändert). R4-Vergleichsstand: Kopie des Worktrees mit den
18 Dateien von `7f0eae2` (`m1/NACH-R4/sh/mkbase.sh`), danach für die Mutationen wieder auf den Kopf gesetzt
(`m1/NACH-R4/mut`). „gemessen“ = auf dieser VM (llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne, Last 8–13 durch
andere Pakete); alles über Steam Deck, echte Grafikkarten und die Wirkung auf Menschen ist **abgeleitet**. Alle Läufe
mit absolutem `XDG_DATA_HOME` unter `m1/NACH-R4/`, `--graphics=` ausdrücklich, schwere Jobs nacheinander mit `nice -n 10`
(`QA_M2_FERTIG` lag vor).

## Urteil

**FIX-R4 (`b156763`) ist eine tragfähige Grundlage für die Zusammenführung RINT-M2.** Beide hohen Befunde sind
behoben und von mir nachgemessen: die rote Säule über fernen Autos an Steigungen ist weg (rote Bildpunkte über dem
Auto bei 4 s / 6,2 s: R4 168 / 793 → **0 / 0**, Arcade 0), und der nasse Kegel im Abblendlicht liegt bei **54 gegen
Arcades 61** (R4: 108), auch unter Laternen (Köhlbrandbrücke Fahrbahn 65–68 gegen Arcade 62–67, R4 88–103). Die neuen
Prüfungen (`check_night_nass.gd`) schlagen auf **R4s echtem Code** an (1,73 × / 0,42 ×; 1.328 Bildpunkte über dem
Dach) und sind auf dem Kopf grün; die Einheitstests fangen die Mutationen U5, U8, R3 und zwei weitere. Alle Tore, die ich
gefahren habe, sind grün: Arcade **20 von 20** und **17 von 17** identisch, Modern-Änderungsmelder **6 von 6**,
**765** Einheitstests ohne Fehler, neun Render-Prüfdateien grün einschließlich der geschützten Korrekturen des ersten
Testbuilds (`check_start_km0`, `check_terrain_cover` mit K1, `check_light_base`; `test_far_ground_water`, `test_props`).
Keine eingefrorene Arcade-Datei berührt.

**Offen bleibt B3** (mittel): der silberne Gran Turismo liest sich nachts im Regen hellsilbern statt marineblau-grau
(Sättigung 0,77 × bzw. 0,70 × Arcade bei gleicher Helligkeit) – hier ist Modern **schlechter** als Arcade; das gehört
ins Lack-Paket (FIX-M2 B-06 / R7). Zwei neue niedrige Punkte: die Kosten der Laternen-Profile in Städten sind nicht
gemessen (4,2 µs je Streifen und Bild, Einzelmessung) und der Laternenweg hat keine eigene Render-Prüfung.

**Look, ehrlich gegen Arcade**: nachts im Regen ist Modern in der Stadt (Frankfurt) und auf der Köhlbrandbrücke jetzt
klar besser als Arcade – warme Laternen- und rote Rücklichtspiegelungen liegen auf der nassen Fahrbahn, die Fahrbahn ist
so hell wie bei Arcade statt cremefarben; auf der freien Autobahn (N2N) gleichwertig (Kegel etwas dezenter, Markierung
klarer, ferne Rücklichter als Streifen statt Punkt). Schlechter bleibt nur das silberne Spielerauto. Alle Zahlen
llvmpipe; Steam Deck abgeleitet.

## Befunde von QA-R4 – Ergebnis der Nachprüfung

| Nr. | Schwere | FIX-R4 meldet | Nachprüfung | Beleg (Kurz) |
|---|---|---|---|---|
| B1 | hoch | behoben | **behoben** | rote Säule über dem fernen Auto: N2N 4 s R4 168 → 0 rote Bildpunkte, 6,2 s R4 793 → 0 (Arcade 0); Köhlbrandbrücke und Frankfurt im Regen: Spiegelungen liegen auf der Fahrbahn; `spiegelung` schlägt auf R4s Code an (1.328 Bildpunkte) |
| B2 | hoch | behoben | **behoben** | Kegel N2N 2 s: Arcade 61, R4 108, FIX **54** (0,89 ×); Markierung Weber 3,87 gegen Arcade 2,73; unter Laternen (Köhlbrandbrücke) Fahrbahn voraus Arcade 62–67, R4 88–103, FIX 65–68; `nass_kegel` auf R4s Code 1,73 × / 0,42 × → FEHLER, auf dem Kopf 0,88 × / 1,19 × → OK |
| B3 | mittel | offen (teilweise) | **teilweise** (offen) | Karosserie GT: Sättigung `check_night` 0,77 × (R4 0,73 ×), mein Ausschnitt 0,70 × (R4 0,62 ×), Helligkeit gleich (Median 46 / 46); im Bild weiter hellsilbern statt marineblau-grau |
| B4 | mittel | behoben | **behoben** | neue Prüfungen fangen die echten Fehler (R4-Code: beide FEHLER) und die Mutationen U5, U8, R3 (Netz 0,897 m), Profil aus, Wächter aus |
| B5 | niedrig | behoben | **behoben** (Code + Einheitstest; im Spiel nicht beobachtet) | `quality_lowered()` wird vom Wächter aufgerufen (`modern_renderer.gd` Z. 599); Mutation „sichtbare Zahl nicht gesetzt“ → Test rot |
| B6 | niedrig | behoben | **behoben** (Einheitstest, kein Bild) | `exit_after_timed()`; Sprung bei 60 m gefangen (U5) |
| B7 | niedrig | behoben (in der Grenze) | **behoben** (in der Grenze) | DEV 21 Uhr 0,87 × / Sättigung 1,00 ×; Köhlbrandbrücke 22 Uhr Regen Ausschnitt 1,21 × (Grenze 1,25 ×), sichtbar etwas königsblauer als das Sprite |
| B8 | niedrig | behoben | **behoben laut Code** (nicht im Bild geprüft) | `render_priority = RENDER_PRIORITY_MIN` am Blendmaterial |
| B9 | niedrig | Vertragsfrage | Vertragsfrage bleibt | `flare.gdshader` ohne W3-Besitzer, `tests/golden/modern_slice.*` (W3 „–“) geändert |

## 1. Nachgestellt – sind die Bilder bestimmt?

Dieselben Argumente wie QA-R4 (`tools/ab_shot.sh`, N2N = Dortmund – Frankfurt km 121, 22 Uhr, Regen, Gran Turismo,
Saat 14, Autopilot, Verkehr, „Hoch“, `--shot-times=2,4,6.2`; Skripte `m1/NACH-R4/sh/ab.sh`, `sh/mshot.sh`, Lagen
`sh/pos.sh` = QA-R4s). Gemessen mit `compare -metric AE`:
- meine Arcade-Bilder = die der Prüfung QA-R4: **0 Bildpunkte** Unterschied (2 s, 4 s);
- mein R4-Lauf (`7f0eae2`, Kopie) = QA-R4s Kopf-Bilder: **0** (2 s, 4 s);
- mein Kopf-Lauf = FIX-R4s Lieferbilder (`m1/FIX-R4/pics`): **0** (2 s, 4 s).
Die Bilder sind also bestimmt; FIX-R4s Bilder zeigen den Kopf, den ich geprüft habe.

## 2. B1 – rote Säule über fernen Autos (behoben)

**Code** (`flare.gdshader` CE_STREAK, `layers/flares.gd`, `layers/vehicles.gd`): der Streifen ist ein Band aus 12
Abschnitten; die sonst ungenutzte Basis der MultiMesh-Instanz trägt sechs Straßenhöhen zwischen Lampenfuß und Kamerafuß
(Spalten 0/1, Spalte 2 x = 1 = „Profil da“), der Shader legt das Band auf eine Catmull-Rom-Kurve durch diese Punkte.
Geprüft: Pufferlayout (`put_profile`) passt zu Godots Zeilenlayout 3×4 und zu `MODEL_MATRIX[0..2]` im Shader; der
Shader schreibt `POSITION` direkt aus Weltkoordinaten (die Basis verzerrt also nichts), `render_mode unshaded` (keine
Normalenmatrix aus der entarteten Basis); der Ursprung (Lampe) bleibt unberührt; ohne Profil liegt das Band eben (alte
Lage). Je Auto ein Profil (vom Heck zur Kamera, nur bei nasser Straße), je Laterne eines ab der Stelle, an der
`_drop_of()` ihre Höhe misst (dort neu gemerkt). Beide `_put_streak()` haben genau einen Aufrufer, der das Profil vorher
setzt – kein veraltetes Profil möglich.

**Bild** (gemessen, rote Bildpunkte R > 45, R > 1,25 G und B oberhalb des fernen Autos, Kasten x 600–680 / y 215–308
bei 4 s bzw. x 600–710 / y 215–292 bei 6,2 s, abzüglich des Bannerrandes, den Arcade gleich hat):

| | Arcade | R4 `7f0eae2` | FIX-R4 `b156763` |
|---|---|---|---|
| 4 s | 0 | **168** | **0** |
| 6,2 s | 0 | **793** (bis an das Banner) | **0** |

`bilder/01_B1_…png`: bei R4 die rote, gestreifte Säule, bei FIX-R4 zwei schmale rote Streifen **unter** dem Auto auf
der nassen Fahrbahn (Arcade: ein Punkt). Auch an zwei weiteren nassen Nachtstellen mit Laternen und Steigung liegen die
Spiegelungen auf der Straße: Köhlbrandbrücke 22 Uhr Regen (Rampe zur Brückenmitte, Laternen auf der Brücke,
`bilder/04_…`) und Frankfurt km 221 21:30 Regen (`bilder/05_…`) – keine Säule, kein schwebender Streifen.

**Prüfung bewacht den echten Fehler**: `check_night_nass.gd` mit den Prüfdateien des Kopfes auf **R4s Code** (Kopie
`7f0eae2`): `spiegelung` **FEHLER – 1.328 Bildpunkte über dem Dach** (Auto 296 m voraus, 21,8 m über dem Kamerafuß;
Bild `rc/pics_base_nass/night_spiegelung_steigung.png`: rote Säule bis in den Himmel); auf dem Kopf **OK – 0 Bildpunkte
über dem Dach, 15 darunter**. Einheitstest `test_streak_follows_the_road_profile`: Mutation „Profil aus“
(`put_profile` Spalte 2 x = 0) → rot.

**Lücke** (niedrig): die Render-Prüfung deckt nur Rückleuchten ab; die Laternen-Streifen hängen am selben Shader, ihr
Profil (`_lamp_profile`) prüft nur das Bild der Köhlbrandbrücke, keine Prüfung.

## 3. B2 – nasse Fahrbahn im Abblendlicht (behoben)

**Code** (`road.gdshader`): neben `base` führt der Shader `lit` (Asphalt × (1 − Spiegel), Markierung × (1 − 0,07 nass)
× (1 − 0,35 Spiegel), Schnee, Start/Ziel-Karo, Nachtanhebung und Klemme wie `base`); `EMISSION` = Bodengesetz(`base`) +
Lichter × `lit`. Trocken ist `lit` rechnerisch gleich `base` (dieselben Operationen) → trockene Bilder unverändert;
Seitenstreifen ohne Spiegel (`lit = side`) – stimmig. Nur Asphalt-Zweig (`kind == 0`), sonst `lit = base`.

**Gemessen** (N2N 2 s, „Hoch“, Median der Leuchtdichte x 560–720 / y 380–440; Weber-Kontrast: hellster Punkt x 420–860
gegen Median x 560–720, Median der Zeilen 368–376):

| | Arcade | R4 | FIX-R4 |
|---|---|---|---|
| Kegel | 61 | 108 (1,77 ×) | **54 (0,89 ×)** |
| Markierung Weber | 2,73 | 1,17 | **3,87** |

Unter Laternen (Köhlbrandbrücke 22 Uhr Regen, Fahrbahn voraus x 520–760 / y 340–420, 2 / 4 / 6 s): Arcade 63 / 67 / 62,
R4 88 / 97 / 103, FIX-R4 **68 / 65 / 68** – der cremefarbene Fleck unter den Laternen ist auch dort weg
(`bilder/04_…`, Unterschiedsbild: die ganze beleuchtete Fahrbahn). Frankfurt 21:30 Regen ebenso (`bilder/05_…`).
`check_night_nass` „nass_kegel“ auf **R4s Code: FEHLER 1,73 × / Randlinie 0,42 ×**, auf dem Kopf **OK 0,88 × / 1,19 ×**.
Wettertabelle Regen 22 Uhr 0,89 × / Kontrast 0,84 × (Grenzen 0,8–1,35 / ≥ 0,5) – grün.

Im Bild (`bilder/02_…`): Moderns Kegel ist dezenter als Arcades weicher heller Fleck (0,89 ×), die Markierung im Kegel
klarer als bei Arcade; die ferne Himmelsspiegelung bleibt. Gleichwertig, nicht besser – Arcades Lichtkegel liest sich
etwas deutlicher als „Scheinwerfer“.

## 4. B3 – silberner Gran Turismo nachts im Regen (teilweise, offen)

`ENV_NIGHT_TINT` 0,8 (Himmel, den Lack/Metall/Glas spiegeln, nimmt nachts den Ton des Umgebungslichts an). Gemessen:
`check_night spielerauto` GT **0,92 × / Sättigung 0,77 ×** (R4 laut QA-R4 0,93 × / 0,73 ×); mein Ausschnitt der Karosserie
(x 560–720 / y 490–600, L > 30, ohne Rücklicht): Median-Leuchtdichte Arcade 46 / R4 46 / FIX 46, Sättigung Arcade 0,518 /
R4 0,324 / FIX **0,365 (0,70 ×)**. Im Bild (`bilder/03_…`): Arcade marineblau-grau, R4 und FIX hellgrau-silbern, FIX
kaum merklich bläulicher. **Schlechter als Arcade**; die Helligkeit stimmt, der Ton fehlt. Die Schranke `CAR_SAT_MIN`
steht weiter auf 0,7 (0,77 × geht knapp durch). Gehört zu FIX-M2 B-06 / R7 (Lack).

## 5. B4 – Prüflücken (behoben)

- Die neuen Render-Prüfungen schlagen auf dem **echten R4-Code** an (oben), nicht nur auf einer künstlichen Mutation.
- Einheitstests mit Mutationen (Kopf-Kopie `m1/NACH-R4/mut`, nach dem Lauf gelöscht; `sh/mut.py`, je Datei `tests/run_tests.gd --filter`,
  Ergebnis `m1/NACH-R4/mut_run.log`): ohne Mutation beide Dateien grün; **U5** (Nachglühen springt bei 60 m: 0,399 → 0)
  → `test_exit_ramp` rot; **U8** (`BANK_MAX_M` 0,95) → `test_snow_bank_mesh_height` rot; **R3** (Profilscheitel × 2,6 →
  höchster Wallpunkt **0,897 m** im gebauten Netz) → rot; Profil aus → `test_streak_follows_the_road_profile` rot;
  Wetter-Wächter ohne `visible_instance_count` → `test_weather_follows_the_watchdog` rot. Eine Mutation blieb grün:
  die Zeitgrenze in `exit_after_timed()` wegnehmen – sie ist gleichwertig (das Zeitmaß in `u` erreicht bei
  `EXIT_AFTER_S` ohnehin 1), keine Lücke.
- `check_weather` „schneewall“ misst jetzt das Netz (`bank_max_m`): gemessen 0,35 m, OK.

## 6. B5–B8 (Code und Einheitstests)

- **B5**: `weather.gd quality_lowered(levels)` – der Wächter ruft Haken mit dieser Methode (`modern_renderer.gd`
  `_lower_quality()` Z. 599); Zahl, Kasten, Gischt der niedrigeren Stufe, `visible_instance_count` statt neuem Puffer.
  Einheitstest grün, Mutation rot. Im echten Herabstufen nicht beobachtet (abgeleitet).
- **B6**: `exit_after_timed(d, dt)` – über 108 km/h bestimmt der Weg (R4s Look, Einheitstest), darunter die Zeit, höchstens
  2 s. Uhr aus `view.time` (pausiert mit dem Spiel). Kein Bild (eine langsame Tunnelausfahrt hätte einen eigenen Aufbau
  gebraucht).
- **B7**: `sheen_wash` 0,35, nur im Nacht-Schimmer des Spielerautos (`fill > 0`, `sky_night`) – Tag und statische
  Modelle unberührt. `check_night` DEV 21 Uhr 0,87 × / 1,00 ×; Köhlbrandbrücke 22 Uhr Regen (Ausschnitt) Leuchtdichte
  1,06 ×, Sättigung **1,21 ×** – in der Grenze 1,25 ×, sichtbar etwas königsblauer als das Sprite.
- **B8**: `render_priority = RENDER_PRIORITY_MIN` am Blendviereck der Ausfahrt – richtig für einen Shader, der den
  Bildschirm liest; nicht im Bild geprüft (wie bei FIX-R4).

## 7. Diff 7f0eae2..b156763 – Nebenwirkungen und Dateien

18 Dateien (+689 / −72): `assets/shaders/modern/{flare,road,vpbr}.gdshader`, `scripts/race3d/{environment_rig,
modern_materials}.gd`, `layers/{flares,vehicles,weather}.gd`, `builders/terrain.gd`, R4s Tests, `check_night_nass.gd`
(neu), `tests/golden/modern_slice.{md5,env}`, `docs/renderer-modern.md`. **Keine eingefrorene Arcade-Datei, nichts in
`scripts/race`, `scripts/core`, `scripts/ui`, `config`, `project.godot`** (git diff leer). Außerhalb der W3-Tabelle:
`flare.gdshader` (kein Besitzer, Shader von R4s `flares.gd`) und `tests/golden/modern_slice.*` (W3 „–“) – B9, bekannt.

Nebenwirkungen geprüft:
- `ENV_NIGHT_TINT` erreicht über `set_class_parameter("vpbr"/"glass")` auch **alle statischen Modelle** (`vpbr|static`:
  Brücken, Gebäude, Schilderbrücken, Bäume) und Glas. Gemessen R4 gegen FIX an der Köhlbrandbrücke und in Frankfurt
  nachts: Zeilen 0–269 (Himmel, Pylon, Stadt, Laternenmasten, Häuser) **0 Bildpunkte > 2/255** verändert – unsichtbar.
- `sheen_wash` wirkt nur im Nacht-Schimmer des Spielerautos.
- Das Profil der Streifen: 7 `height_at()` je Auto/Laterne mit Spiegelung. Gemessen (Einzeltest headless,
  `m1/NACH-R4/sh/nach_r4_bench.gd`, lief in der gelöschten Kopf-Kopie, Last 8+): **4,2 µs je `road_profile()`** → 100 Streifen je Bild ≈ 0,42 ms auf dieser VM
  (Stadt mit vielen Laternen im Regen); FIX-R4 hat nur die Autobahn Kiel – Hamburg gemessen (+0,02–0,06 ms). Steam Deck:
  abgeleitet ≈ halb so viel. Hinweis an PERF/QA-M2-BILD, kein Fehler.
- `terrain.gd`: `debug()` hat ein neues Feld `bank_max_m` (nur Schnee); `_snow_banks()` hat einen Parameter mehr –
  kein anderer Aufrufer (grep).

## 8. Bilder (angesehen, Arcade = derselbe Simulationsschritt)

| Bild | Stelle | ehrlich gegen Arcade |
|---|---|---|
| `01_B1_…Saeule_4s_6s_Arcade_R4_FIX.png` | N2N, Ausschnitt 3× | Säule weg; Spiegelung als zwei schmale rote Streifen unter dem fernen Auto (Arcade: Punkt) – physikalisch richtig, gleichwertig bis besser |
| `02_B2_…Kegel_Arcade_R4_FIX.png` | N2N 2 s | cremefarbener Fleck weg; Kegel dezenter als Arcades (0,89 ×), Markierung klarer – gleichwertig |
| `03_B3_GT_nachts_Regen_…png` | N2N 2 s, Spielerauto | **schlechter**: GT hellsilbern statt marineblau-grau (B3 offen) |
| `04_KBN_Koehlbrand_22Uhr_Regen_6s_…Diff.png` | Kiel – Hamburg km 79,6, 22 Uhr, Regen | **besser als Arcade**: warme Laternenspiegelungen liegen auf dem nassen Brückendeck, Fahrbahn so hell wie Arcade (R4: cremefarben); Limousine etwas königsblauer als das Sprite |
| `05_C1_Frankfurt_21Uhr30_Regen_4s_…png` | Frankfurt km 221, 21:30, Regen | **besser als Arcade** in der Stimmung (nasse Stadt, Spiegelungen der Rück- und Laternenlichter auf der Fahrbahn); R4s grünlich-helle Fahrbahn ist weg; die vielen orangen Streifen im rechten Fahrstreifen sind kräftig |
| `06/07/08_…ganz.jpg` | ganze A/B-Bilder N2N, KBN, C1 | wie oben |

## 9. Tore (auf `b156763`, gemessen)

Alle Läufe nacheinander, `nice -n 10`, absolutes `XDG_DATA_HOME`/`TMPDIR` unter `m1/NACH-R4/`; Logs `m1/NACH-R4/gates/`
und `m1/NACH-R4/rc/`. Worktree vor und nach den Toren unverändert (`git status` leer).

| Tor | Befehl | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0 |
| Arcade-Gleichheit | `tools/golden.sh check` (einmal) | **GOLDEN arcade: 20 von 20 identisch** (202 s), **GOLDEN arcade-ui: 17 von 17 identisch** (262 s) |
| Modern-Änderungsmelder | `tools/golden.sh modern-check` (KEEP) | **GOLDEN modern: 6 von 6 identisch** (1.032 s) – FIX-R4s neuer Hash für `modern_s1_nacht` ist nachvollziehbar, die fünf Tagesbilder unverändert; **modern-gles OK** (max. 2/255, PSNR 73,2 dB); `modern_s1_nacht` angesehen (Limousine marineblau, lesbar) |
| Skripte + Einheits- und Kopfprüfungen | `tools/run_tests.sh` (Vollauf, einmal) | **319 Skripte, 0 fehlerhaft; 765 Einheitstests, 0 fehlgeschlagen; 149 CHECK-OK-Zeilen, 0 FEHLER; „Tests bestanden (950 s)“** – darin `test_far_ground_water` (4/4), `test_props`, `modern_sight` (F1 0 Fälle bis 270 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 874, F7 0, Modell 0 abweichend), `modern_path_check` (267,6 m, Schleifen ab 2.064 m) |
| Render: Nacht | `tools/run_render_checks.sh modern check_night` | `check_night.gd` **4/4 OK** (Fahrbahn N1 +4,9 %; Spielerauto: Kompakt 1,05 × / 1,23 ×, GT 0,92 × / 0,77 ×, S1-Limousine 0,88 × / 0,95 ×, DEV-Limousine 0,87 × / 1,00 ×; Verdeckung 0 Pixel; Blaulicht), `check_night_nass.gd` **2/2 OK** (nass_kegel 0,88 × / Randlinie 1,19 ×; spiegelung 0 Pixel über dem Dach, 15 darunter) |
| Render: Wetter | `… modern check_weather` | `check_weather.gd` **5/5 OK** (teilchen, gischt, nass, tunnel, schneewall ≤ 0,35 m im Netz), `check_weather_tabelle.gd` OK (Regen 22 Uhr 0,89 × / Kontrast 0,84 ×), `check_weather_tabelle_schnee.gd` OK |
| Render: geschützte Korrekturen des ersten Testbuilds | `… check_start_km0`, `check_terrain_cover`, `check_light_base` | **3/3 OK** (Kamera ≤ 1,14 px, Auto, Boden), **7/7 OK inkl. K1** (0 % Magenta), **2/2 OK** (Tageslicht, Schatten) |
| Render: Fahrzeuglichter | `… check_vehicle_lights` | **4/4 OK** (Blinker, Rücklicht N1, Bremslicht, Sichtgrenze) |
| Prüfungen gegen R4s Code | `check_night_nass.gd` (Kopf-Prüfdateien) auf der Kopie `7f0eae2` | **2/2 FEHLER** wie gewollt (1,73 × / 0,42 ×; 1.328 Pixel über dem Dach) |
| Mutationen | `m1/NACH-R4/sh/mut.py` (Kopf-Kopie) | U5, U8, R3, Profil aus, Wächter aus → jeweils rot; ohne Mutation grün |

Nicht gelaufen: `run_render_checks.sh all` (nur die Dateien der geänderten Ebenen und die geschützten Korrekturen),
`modern_sight --full` (keine Platzierung geändert – Kamera, Weg, Gelände, Verkehr unberührt; der Standardlauf in
`run_tests.sh` ist grün), keine Ganz-Etappen-Leistungsmessung (QA-M2-BILD misst die Leistung; Einzelmessung unten).

## 10. Neue Befunde

- **N1 – niedrig – Leistung der Laternen-Profile in Städten nicht gemessen.** `flares.gd _lamp_profile()` rechnet je
  Laterne mit Spiegelung und Bild ein Profil (7 `height_at()`), auch wenn sich die Kamera kaum bewegt hat. Gemessen
  (Einzeltest headless, Last 8+): 4,2 µs je `road_profile()` → 100 Streifen ≈ 0,42 ms je Bild auf dieser VM; FIX-R4 hat
  nur die Autobahn Kiel – Hamburg gemessen (+0,02–0,06 ms). Vorschlag: Profil je Laterne zwischenspeichern und erst neu
  rechnen, wenn die Kamera ≥ 2–5 m weiter ist; an C1 21:30 Regen messen (PERF / QA-M2-BILD). Steam Deck abgeleitet.
- **N2 – niedrig – Prüflücke Laternen-Streifen.** `check_night_nass` „spiegelung“ prüft nur die Rückleuchten eines
  Verkehrsautos; den Laternenweg (`_drop_of()` merkt die Straßenstelle, `_lamp_profile()`) bewacht nur das Bild der
  Köhlbrandbrücke (`bilder/04`). Vorschlag: einen Fall mit statischen Lampen auf einer Rampe (Köhlbrandbrücke km 79,
  22 Uhr, Regen) in „spiegelung“ aufnehmen.
- Keine weiteren neuen Befunde: keine eingefrorene Datei, keine Datei außerhalb von R4s W3-Besitz außer den bekannten
  (B9), statische Modelle nachts unverändert, trockene Fahrbahn rechnerisch unverändert, Tagesbilder bit-gleich
  (Modern-Änderungsmelder 6/6).

## 11. Vertragsfragen

1. `assets/shaders/modern/flare.gdshader` hat in §5 (A-8) keinen W3-Besitzer; R4 und FIX-R4 haben ihn geändert. Vorschlag
   (wie FIX-R4): der Besitzer von `layers/flares.gd` besitzt seinen Shader.
2. `tests/golden/modern_slice.{md5,env}` (W3 „–“): FIX-R4 hat den Hash `modern_s1_nacht` ersetzt – nachvollziehbar
   (modern-check 6/6). RINT-M2 erzeugt die Liste nach dem Zusammenführen mit `golden.sh modern-make` neu.
3. §6 R4 kennt die nasse Nacht nicht als Abnahme; `check_night_nass.gd` (Kegel 0,7–1,15 × Arcade, Randlinie ≥ 0,8 ×,
   keine Spiegelung über dem Dach) sollte dort stehen.

## 12. Für die nächsten Pakete

1. **FIX-M2 B-06 / R7 (Lack)**: B3 – GT nachts im Regen Sättigung 0,77 × (`check_night`) bzw. 0,70 × (Ausschnitt), Helligkeit
   gleich; danach `CAR_SAT_MIN` auf 0,85. Schnell: `check_night -- --only=spielerauto --fall=Turismo`.
2. **RINT-M2**: Konflikte erwartet nur in `tests/golden/modern_slice.*` und `docs/renderer-modern.md`; nach dem
   Zusammenführen `golden.sh modern-make` und die Nachtbilder ansehen (Limousine: FIX-M2 Tag-Entsättigung + `sheen_wash`).
3. **PERF / QA-M2-BILD**: N1 (Laternen-Profile in der Stadt bei Nacht und Regen messen; ggf. zwischenspeichern).
4. **R4-Nachfolger / QA**: N2 (Laternenfall in „spiegelung“); B8 und B6 (langsame Ausfahrt) sind weiter nur aus dem Code
   bzw. Einheitstest belegt.
5. **Look**: Limousine unter Laternen im Regen 1,21 × Sättigung (Grenze 1,25 ×) – knapp; die vielen orangen
   Laternenstreifen in Frankfurt sind kräftig, aber stimmig.

## 13. Arbeitsdateien

Skripte `m1/NACH-R4/sh/` (ab.sh, mshot.sh, rc.sh, rcd.sh, queue1–3.sh, measure.py, body.py, diffmap.py, mut.py),
Bilder `m1/NACH-R4/shots/{head,base}`, Ausschnitte `m1/NACH-R4/crops`, Prüf-Logs `m1/NACH-R4/rc`, Tore `m1/NACH-R4/gates`,
Mutationen `m1/NACH-R4/mut_run.log`. Lieferbilder `deliver/NACH-R4/bilder/01–10`.

