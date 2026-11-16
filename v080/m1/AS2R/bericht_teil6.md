## 7. Gates

| Gate | Ergebnis (gemessen) |
|---|---|
| Prüfer `validate_models.py --report` | {VALIDATOR} |
| Determinismus, alle Fahrzeuge (14:10) | erzwungener Export + Bake von Spieler, Verkehr, Polizei: `git status` leer (byte-gleich mit dem Commit), zweiter Bake byte-gleich (213 Dateien), `--check-keys` grün |
| Determinismus nach den letzten Änderungen (Polizei, Lkw, Bus) | {DET3} |
| `check_sprite_geometry.py --only player,showroom,traffic,police --jobs 1` | **61 von 61 Sets identisch** (404 s); `carbody` hat den neuen Hook `cap_strips` mit Voreinstellung aus, `player_cars` nur 3D-Hooks |
| Arcade-Dateien | unberührt (Regel 1); kein Sprite neu gerendert |
| Kontaktbögen Tag und Nacht | Bilder 04–09, mit wirksamem Renn-Look (C2), angesehen |
| Showroom-A/B | Bild 03; Schalter bleiben `false` (Abschnitt 6) |
| `tools/run_tests.sh` (einmal) | {TESTS} |
| `tools/golden.sh check` (einmal, am Ende) | {GOLDEN} |

## 10. Bilder in diesem Ordner

Alle mit den Spiel-Shadern und dem Renn-Look, Software-OpenGL; was ein Mensch auf echter Hardware sieht, ist
abgeleitet. Die Bilder 01, 02, 10, 13 und 16 sind die Vergleichsansichten der Kritik, mit ihren Werkzeugen und
Beschriftungen neu gerendert (die Beschriftungen von Bild 16 nennen die Mängel, die Bilder zeigen den neuen Stand).

| Datei | Inhalt |
|---|---|
| `01_spieler_spielkamera_sprite_gegen_modern.jpg` | Spielerautos in 9 m: Arcade-Sprite, Modern mit Renn-Look, neutral, Silhouette; 8 m im Spielbild, „Niedrig“, 30 m |
| `02_spieler_nacht_und_bremse.jpg` | 8 m nachts: Arcade gegen Modern, Rück- und Bremslicht; Tag mit und ohne Bremse (A2: GT) |
| `03_showroom_ab.jpg` | Showroom-A/B: Echtzeit-Stufe `show` gegen das Cycles-Sprite, dieselbe Kamera (AgX) |
| `04_kontaktbogen_spieler_tag.jpg`, `05_kontaktbogen_spieler_nacht.jpg` | alle Stufen bei Tag; nachts jede Lampe einzeln |
| `06_kontaktbogen_verkehr_tag.jpg`, `07_kontaktbogen_verkehr_nacht.jpg` | sechs Verkehrstypen, alle Stufen und Farbsets; nachts SUV, Transporter, Sportwagen je Lampe |
| `08_kontaktbogen_polizei_tag.jpg` | alle 18 Polizeiautos (`lod0`, Heck und Front) |
| `09_lampenkanaele.jpg` | Lampenkanäle 0–14 des Shaders (Prüfbild) |
| `10_verkehr_spielkamera_sprite_gegen_modern.jpg` | SUV, Transporter, Sportwagen in 10/30/80/120 m: Arcade gegen Modern |
| `13_stufenwechsel.jpg` | SUV, Transporter, Sportwagen: Wechsel bei 40 und 120 m, Tag und Nacht, mit Differenzbild (B2, B4); bei SUV und Sportwagen bleibt bei 120 m vor allem ein Ring am Umriss |
| `16_maengel_belege.jpg` | die Stellen von A5, A4, A6, B1–B3, A8 im neuen Stand |
| `21_radlauf_sportwagen_gt.jpg` | A5: Vorderrad von Sportwagen und GT, seitlich, von schräg unten und im Schnitt |
| `30_polizei_de_spielkamera.jpg`, `31_polizei_be_spielkamera.jpg` | Polizei in 20 / 60 / 150 m, Tag und Nacht (Rücklicht, Bremse + Blinker, Blaulicht A), neben dem Arcade-Sprite |
| `32_bus_spielkamera.jpg`, `33_planen_lkw_spielkamera.jpg` | Bus und Planen-Sattelzug ebenso, neben dem Arcade-Quader |
| `34_polizei_be_120m_karoband.jpg` | Wechsel bei 120 m, Belgien: Karos gegen das Band in der neuen Mischfarbe |
| `35_bus_60m_heckscheibe.jpg` | Wechsel bei 60 m, Bus: Heckscheibe mit `GLASS_FAR` |
| `36_suv_120m_rest.jpg` | Wechsel bei 120 m, SUV: was bleibt (Umriss, Normalen; Stand vor dem dunkleren Kennzeichen, das in beiden Stufen gleich ist) |

## 11. Geänderte Dateien und Werkzeuge

Code und Doku (seit `19624cd`): `tools/blender/ce3d/decalgeo.py` (ferne Fenster nach der Kontur, `split_coord`,
Rückstrahler), `traffic3d.py` (ferne Scheibe und Kennzeichen, `cap_strips`, Räder von `lod2`, `_tone`, SUV-Entwurf),
`catalog3d.py` (Kabinen-Stationen von `lod2`, `POLICE_SPEC_CC`), `police3d.py` (`_tone`, `far_windows`,
`CHECK_MEAN_EXP`), `truck3d.py` und `heavy3d.py` (`GLASS_FAR`), `vehicles3d.py` (Felgen, `_clear_front_arches`),
`tools/blender/cesprites/carbody.py` (Hook `cap_strips`, Voreinstellung aus), `cesprites/player_cars.py` (nur
3D-Hooks: GT-Rücklicht, Rückfahrlichter), `tools/models/contact_sheet.gd` (C2), `docs/modelle.md` (Abschnitte 11–16).
Modelle: alle Spieler-, Verkehrs-, Polizei-, Lkw- und Busmodelle neu gebaut (120 Dateien unter `assets/models`,
Manifest).

Werkzeuge (Arbeitsordner `…/scratchpad/v080/m1/AS2R/`, nicht im Repository):

- `bin/rebuild.sh "<glob>" [--force]` – Export, Bake, Manifest, Prüfer (nice 19, ein Prozess);
  `bin/sheet.sh <abs.png> <Kontaktbogen-Argumente>`; `bin/gates.sh`, `bin/gates3.sh`, `bin/final_gates.sh`.
- `kritik/` – die Werkzeuge der Kritik, auf diesen Arbeitsbaum gerichtet: `run_jobs.sh`, `round.sh` (alle
  Vergleichsansichten), `probe.sh <tag> <m> <lodA> <lodB> <sets…>` (Stufenwechsel eines Sets mit Bogen und Zahl),
  `bin/pop_split.py` (Wechsel aufgeteilt in Kennzeichen / Scheibe / Rest), `bin/bandmean.py`, `bin/buswin.py`,
  `bin/winmean.py`, `bin/platemean.py` (mittlere Farben). `kritik/tools_kritik/kritik_render.gd` (und
  `kritik_dump.gd`) muss dafür nach `tools/kritik/` einer Arbeitskopie (unversioniert, nie committen); aus meinem
  Arbeitsbaum ist der Ordner wieder entfernt, `git status` ist leer.
