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
- Einheitstests mit Mutationen (Kopf-Kopie `m1/NACH-R4/mut`, `sh/mut.py`, je Datei `tests/run_tests.gd --filter`,
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
  `mut/tests/nach_r4_bench.gd`, Last 8+): **4,2 µs je `road_profile()`** → 100 Streifen je Bild ≈ 0,42 ms auf dieser VM
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

@@GATES@@

## 10. Neue Befunde

@@NEU@@
