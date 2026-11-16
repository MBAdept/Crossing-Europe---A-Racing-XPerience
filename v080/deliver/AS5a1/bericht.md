# AS5a1 – Stadthäuser german, german_old und hanse als Echtzeit-Modelle (Bericht)

Paket **AS5a1** von v0.8.0 „Modern“ (Stadtgebäude Teil 1, Charge 1 von 2). Zweig `worktree-wf_db8ba6cd-508-1`,
gesichert als `origin/wip/v080-as5a1`; Basis `6e48405` (origin/wip/v080-m2int), Endstand `63544b6`. Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1`. Das Paket lief über mehrere
Neustarts des Containers (drei Nachfolger); dieser Bericht beschreibt den Endstand.

Zahlen sind **(gemessen)** oder **(gefolgert / gerechnet)**; ohne Zusatz in Tabellen gilt „gemessen“. Gemessen heißt:
auf dieser VM (4 Kerne, mit anderen Aufträgen geteilt, Last 17–26), Software-OpenGL (llvmpipe) unter Xvfb, Renn-Look
der Prüfszene (`prop_scene --look=race`) bzw. `tools/ab_shot.sh`. Alles über echte Grafikkarten, das Steam Deck oder
die Wirkung auf einen Menschen ist gefolgert.

## Kurzfassung

Die elf Stadthaus-Sets der Stilfamilien `hanse`, `german` und `german_old` – die Städte des Rennens Kiel – Nürnberg
(Kiel, Hamburg, Bremen, Rostock; Hannover, Kassel, Dortmund, Frankfurt; Würzburg, Nürnberg, Fulda, Erfurt und über
gemischte Stile Leipzig, Magdeburg, München, Passau, Regensburg, Bern) – sind keine Arcade-Bilder mehr, sondern echte
Modelle aus derselben Blender-Geometrie wie die Sprites, mit Tiefe an der Straße, gebackenem Atlas mit
Umgebungsverdeckung, Nachtlicht derselben Fenster wie in Arcade und geschlossenen Rückseiten. Reihenfolge nach
Häufigkeit auf Kiel – Nürnberg (gezählt): Einfamilienhaus 282, Fachwerkzeile 99, Turmhaus 95, Mietshaus 77,
Gründerzeithaus 72, Giebelzeile 54, Barock 32, Speicher 10, Büroturm 7, Kontor 4, Kran 3.

Neu ist der Bauer `city` (`tools/blender/ce3d/cities3d.py`) auf dem Gebäudebauer von AS4 (`buildings3d.py` unverändert –
die AS4-Modelle bleiben byte-gleich). Budget: 427–9 865 Dreiecke lod0, 2 Aufrufe je Stufe; Archivanteil der Charge
Netze 0,79 MB und Texturen 5,25 MB im Archiv (deflate -9 je Datei wie tools/pck_report.py; Anteil der Charge: höchstens 3 MB / 7 MB). Gates siehe unten; das Schwächste: Flimmern und Stufenwechsel der Fachwerkhäuser, Geländer ab 100 m.

## Ergebnis je Modell (Budget)

| Modell | Dreiecke lod0 / lod1 | Aufrufe je Stufe | Atlas | px/m Straße min–max | Rückseite | Netze B (Archiv) | Texturen PCK (Archiv) | Export s (Bauen + Backen) |
|---|---|---|---|---|---|---|---|---|
| `city_german_house` | 2962 / 2526 | 2/2 | 1024×1024 | 60.0–60.0 | 5 gespiegelt, 1 eigene | 97896 (96769) | 873944 (253529) | 565.95 |
| `city_german_old_fachwerk` | 6913 / 1041 | 2/2 | 2048×1024 | 35.01–43.76 | 21 gespiegelt, 3 eigene | 102857 (99804) | 1747768 (506772) | 1461.75 |
| `city_german_old_fachwerk_b` | 3332 / 978 | 2/2 | 2048×1024 | 41.71–52.14 | 8 gespiegelt, 4 eigene | 57697 (55938) | 1747768 (401478) | 1179.38 |
| `city_german_mietshaus` | 2176 / 506 | 2/2 | 2048×1024 | 52.91–138.28 | 4 gespiegelt, 0 eigene | 34819 (33586) | 3145888 (483204) | 1300.94 |
| `city_german_gruenderzeit` | 4410 / 2394 | 2/2 | 2048×1024 | 40.81–140.53 | 6 gespiegelt, 0 eigene | 78280 (76412) | 3145888 (551904) | 745.25 |
| `city_hanse_gabled` | 3712 / 1233 | 2/2 | 2048×1024 | 33.5–41.87 | 24 gespiegelt, 2 eigene | 69663 (68486) | 1747768 (664333) | 607.94 |
| `city_german_old_barock` | 4539 / 2385 | 2/2 | 2048×1024 | 37.79–47.23 | 11 gespiegelt, 4 eigene | 90772 (88684) | 1747768 (462191) | 921.77 |
| `city_hanse_speicher` | 8950 / 1283 | 2/2 | 2048×1024 | 29.83–42.62 | 33 gespiegelt, 11 eigene | 117875 (114183) | 1747768 (739759) | 877.2 |
| `city_german_office` | 427 / 203 | 2/2 | 2048×1024 | 15.92–21.23 | 2 gespiegelt, 0 eigene | 11980 (11020) | 1747768 (360457) | 240.65 |
| `city_hanse_kontor` | 9865 / 749 | 2/2 | 2048×1024 | 28.83–41.19 | 8 gespiegelt, 0 eigene | 113220 (108978) | 1747768 (714886) | 424.65 |
| `city_hanse_crane` | 1260 / 1052 | 2/2 | 1024×1024 | 90.0–90.0 | 3 gespiegelt, 1 eigene | 41091 (39384) | 873944 (114492) | 108.68 |

Summe: Netze 0.82 MB (Archiv 0.79 MB), Texturen 20.27 MB im PCK (Archiv 5.25 MB)

Spalten: Dreiecke je Stufe (`model.json`, nach dem Godot-Bake); Zeichenaufrufe = Oberflächenklassen je Stufe
(`baked`/`baked_cutout` + `vpbr`); Atlas = Albedo- und Lichtatlas; px/m Straße = Texeldichte der Straßenwände aus dem
Bake (Modellmaß; Minimum = Obergeschosse, Maximum = Erdgeschoss/erstes Obergeschoss bzw. Schaufenster); Rückseite =
abgewandte Wände, die die Texel der Straßenwand gespiegelt mitbenutzen („reused walls on the far side“), gegen Wände
mit eigenen Texeln; Bytes = Netze (`.res` + `model.json`) und importierte S3TC-Texturen im PCK, in Klammern deflate -9
wie im Archiv; Export s = Bauen + Backen in Blender (CE_THREADS=3, ein Worker, nice 19, unter Last 17–26).

## Gates (auf dem Endstand, alle gemessen auf dieser VM)

| Gate | Befehl | Ergebnis |
|---|---|---|
| Prüfer | `python3 tools/blender/validate_models.py --report` | `CHECK models OK` – 98 Modelle, 183 Sets (116 mit Modell, 67 Platzhalter); Netze 18,84 von 40 MB, Texturen 57,53 von 240 MB im Grafikspeicher, Quellen 30,20 von 60 MB |
| Budget | Tabelle oben | alle elf ≤ 10 000 Dreiecke lod0 (größtes: Kontor 9 865), 2 Aufrufe je Stufe, Texeldichte Straßenwand ≥ 26 px/m außer Büroturm im Modellmaß (im Spiel 32–57 px/m, gerechnet) |
| Sprite-Geometrie | `check_sprite_geometry.py --only props --jobs 1` (nach der letzten Änderung von `props_cities.py`) | `86 Sprite-Sets gebaut in 358 s: 86 identisch …, 0 verändert, 0 fehlen` – `CHECK sprite_geometry OK` |
| Schlüssel | `export_models.py --check-keys` | `CHECK cache_keys OK 98 Modelle` |
| Determinismus | Kran, Büroturm, Kontor, Speicher nach der letzten Code-Änderung erneut erzwungen exportiert und gebacken (`cycle.sh real`, CE_THREADS=3, wie der erste Export) | `git status` danach leer: Netze, Atlanten, `model.json` und Manifest **byte-gleich**; zugleich der Beweis, dass der Türfix Modelle ohne Rundbogentür nicht verändert. Die zweiten Exporte von Fachwerkzeile, Turmhaus, Barock und Giebelzeile sind die gewollte Änderung |
| AS4-Hausmodelle | `git diff 6e48405 -- assets/models` | außerhalb `props/city_*` nur `manifest.json` (elf Sets jetzt mit Modell); `buildings3d.py` unverändert, Schlüssel der AS4-Modelle unverändert (`stale.py`: houseboat, bridge_* aktuell) – byte-gleich, kein Neuexport nötig |
| Rennen in Modern | `tools/ab_shot.sh` an drei Stadteinfahrten (Abschnitt A/B) | 9 Läufe (3 Orte × Hoch 12/22 Uhr + Mittel 19:30), je Arcade und Modern: alle Bilder da, **0 Skriptfehler** in allen 18 Protokollen; der erste Lauf (Hamburg, Hoch, 12 Uhr) hatte zwei Aufnahmezeiten und lief beim zweiten Bild in Modern ins Zeitlimit (600 s) – das erste Bild ist da |
| Tests | `tools/run_tests.sh` (einmal, vollständig, 1 299 s) | alle Schritte grün bis auf **zwei Zeit-Tests des Klangs** in den Einheitstests: `test_engine3_checks :: test_engine_thread_in_a_running_game` (6 Hänger des Hauptthreads à 400 ms → 40 Aussetzer des Generators) und `test_music_checks :: test_music_in_a_running_game` (Kiel–Hamburg ab km 2). Beide laufen auf km 0–2 ohne Stadthäuser und berühren keine Datei dieses Pakets; Last der Maschine 18–26. Gefiltert wiederholt: `tools/run_tests.sh engine3_checks` → `2 Tests, 0 fehlgeschlagen` (der Motortest war ein Lastausreißer); `tools/run_tests.sh music_checks` → wieder rot: der Schlag nach dem Einzähler kommt in beiden Läufen gleich 239,2 ms nach „LOS!“ (zwei Treiber-Schübe später als die 53,4 ms, die der Test im Kommentar nennt; erlaubt waren 278 bzw. 186 ms je nach längstem Bild). Der Test läuft kopflos mit `--graphics=arcade` (`tests/unit/audio_modern/check_music.gd`) – er lädt weder den Modern-Renderer noch ein Modell; dieses Paket ändert keine Klang- oder Spieldatei. **Nicht von AS5a1 verursacht** (gefolgert aus dem Code); auf der Basis nicht gegengeprüft (Zeit) |
| Arcade | `tools/golden.sh check` (einmal) | `GOLDEN arcade: 20 von 20 identisch`, `GOLDEN arcade-ui: 17 von 17 identisch` |
| Modern | `KEEP=… tools/golden.sh modern-check` | `GOLDEN modern: 4 von 6 identisch`; anders `modern_s4_mittel` (km 80,6, Hamburger Stadtrand) und `modern_s5_niedrig` (Ziel in Hamburg) – dort stehen jetzt die Modelle (Bilder `golden_modern_s4_hamburg_stadtrand_neu.jpg`, `golden_modern_s5_hamburg_ziel_neu.jpg`, angesehen, gewollt). `modern-gles` OK (max. 2/255, PSNR 73,2 dB). Neue Liste aus den behaltenen Bildern geschrieben (dieselbe Renderfunktion wie `modern-make`; ein zweiter Durchlauf von 32 min war auf der geteilten Maschine nicht drin), Commit `63544b6` |
| Archiv | `share.py` (deflate -9 je Datei der `.res`, `model.json` und importierten `.ctex`, wie `tools/pck_report.py`) | Netze **0,79 MB**, Texturen **5,25 MB** im Archiv (Anteil der Charge: ≤ 3 MB / ≤ 7 MB). Kein eigener Linux-Build (Abweichung): die Rechnung ist dieselbe wie im PCK-Bericht; ein Exportlauf mehr auf der geteilten Maschine war nicht drin. Auf den M2ZS1-Stand gerechnet (Netze 18,73 von 40 MB, Texturen 13,04 von 60 MB im Archiv): Netze etwa 19,5 MB (+0,82 MB roh), Texturen etwa 18,3 MB (+5,25 MB) – gerechnet, nicht gemessen |

## Messungen

Alle Zahlen **gemessen** auf dieser VM (Software-OpenGL llvmpipe unter Xvfb, Renn-Look der Prüfszene, Voreinstellung
wie angegeben), wenn nicht anders gesagt. Was ein echter Grafikchip, das Steam Deck oder ein Mensch davon sieht, ist
**gefolgert**.

### Umriss gegen das Sprite (`k4_scene --mode=outline2`, Sprite-Kamera des Sets, Bild `umrisse_sprite_gegen_modell.jpg`)

| Modell | lod0 außerhalb | Sprite gedeckt | IoU lod0 | IoU lod1 |
|---|---|---|---|---|
| `city_german_house` | 0,3 % | 99,7 % | 0,993 | 0,996 |
| `city_german_mietshaus` | 0,5 % | 99,9 % | 0,995 | 0,999 |
| `city_german_gruenderzeit` | 0,0 % | 99,9 % | 0,999 | 0,999 |
| `city_german_office` | 0,0 % | 99,7 % | 0,997 | 0,997 |
| `city_german_old_fachwerk` | 0,1 % | 99,9 % | 0,998 | 0,999 |
| `city_german_old_fachwerk_b` | 0,0 % | 99,9 % | 0,999 | 0,999 |
| `city_german_old_barock` | 0,0 % | 99,9 % | 0,999 | 0,999 |
| `city_hanse_gabled` | 0,1 % | 99,9 % | 0,998 | 0,998 |
| `city_hanse_kontor` | 0,0 % | 98,7 % | 0,987 | 0,987 |
| `city_hanse_speicher` | 0,0 % | 99,9 % | 0,999 | 0,999 |
| `city_hanse_crane` | 2,0 % | 94,0 % | 0,922 | 0,922 |

Proportionen, Geschosse, Dachformen, Giebel und Fensterraster stimmen mit dem Sprite überein (gleicher Generator).
Der Kran bleibt bei 0,92: Gitterstäbe und Seil sind im Modell echte dünne Stäbe, im Sprite weichgezeichnete Pixel.

### Texeldichte

Aus dem Bake (`ppm_road` des Export-Berichts, Modellmaß; Straßenwände = Flächen zur Straße und zur Anfahrt):
Spalte „px/m Straße“ der Budgettabelle. Im Spiel teilt sich das durch den Maßstab der Platzierung (Zählung: 0,85–1,2;
Büroturm 0,37–0,5, dort also das 2- bis 2,7-Fache).

- Vertrag ≥ 26 px/m an den Straßenwänden: erfüllt von allen Gebäuden außer dem Büroturm im Modellmaß (15,9–21,2 px/m,
  im Spiel bei Maßstab 0,37–0,5 **32–57 px/m**, gerechnet aus gemessenem Modellmaß).
- Innenstadt ≥ 40 px/m im Erdgeschoss und ersten Obergeschoss (`floors`): Fachwerkzeile 43,8, Turmhaus 52,1,
  Barock 47,2, Gründerzeit ≥ 40,8, Giebelzeile 41,9, Speicher 42,6, Kontor 41,2 px/m (Modellmaß). Im Spiel bei
  Maßstab bis 1,15–1,2 liegen Kontor (34) und Giebelzeile (36) knapp darunter (gerechnet).
- Obergeschosse 29,8–41,7 px/m (Faktor 0,7–0,8), Dächer 2–6 px/m (Gewicht 0,25–0,55), Rückseiten: Texel der
  Straßenwand gespiegelt (Spalte „Rückseite“: so viele abgewandte Wände ohne eigene Texel).
- Godot-Probe `texel_probe.gd` (UV-Fläche × Atlas gegen Weltfläche je Flächenrichtung, alle Teile gemittelt):
  `meas_texel.log` im Arbeitsordner; dieselbe Größenordnung (Büroturm 8,6–16,7, sonst 22–56 px/m an Wänden).

### Stufenwechsel lod0 → lod1 bei 60 m („Mittel“; `prop_scene --mode=lods`, Anteil der Pixel mit Σ|ΔRGB| > 0,06 / der 3×3-Blöcke, mittlere Helligkeit)

| Modell | 12 Uhr | 22 Uhr |
|---|---|---|
| `city_german_house` | 11,2 / 14,9 %, Helligkeit +2,6 % | 8,8 / 10,9 %, Helligkeit +4,0 % |
| `city_german_mietshaus` | 14,1 / 20,2 %, Helligkeit -1,3 % | 10,7 / 15,3 %, Helligkeit +2,3 % |
| `city_german_gruenderzeit` | 17,9 / 22,3 %, Helligkeit -1,1 % | 13,8 / 19,2 %, Helligkeit +4,5 % |
| `city_german_office` | 2,8 / 2,9 %, Helligkeit -0,1 % | 3,9 / 4,9 %, Helligkeit +1,9 % |
| `city_german_old_fachwerk` | 31,6 / 45,0 %, Helligkeit +4,6 % | 23,6 / 28,8 %, Helligkeit +8,9 % |
| `city_german_old_fachwerk_b` | 16,3 / 19,1 %, Helligkeit +2,4 % | 9,6 / 13,3 %, Helligkeit +5,5 % |
| `city_german_old_barock` | 17,6 / 23,2 %, Helligkeit -1,8 % | 13,8 / 18,3 %, Helligkeit +1,7 % |
| `city_hanse_gabled` | 15,2 / 20,4 %, Helligkeit -2,3 % | 10,0 / 15,0 %, Helligkeit +1,4 % |
| `city_hanse_kontor` | 25,6 / 29,0 %, Helligkeit -1,6 % | 18,6 / 25,1 %, Helligkeit +9,1 % |
| `city_hanse_speicher` | 18,4 / 24,9 %, Helligkeit -1,1 % | 14,8 / 17,1 %, Helligkeit +4,1 % |
| `city_hanse_crane` | 2,0 / 2,2 %, Helligkeit -0,0 % | 2,2 / 2,5 %, Helligkeit +6,7 % |

Kein Fernbild (lod1 gilt bis zum Ende der Sichtweite; „lod1 > Fernbild 0,0 %“). Silhouette, Geschosse und
Fensterrhythmus bleiben; was wechselt, sind Laibungsschatten, Sprossen, Türflügel und – bei den Fachwerkhäusern – die
Hölzer (lod0 echte Hölzer, lod1 das gemalte Fachwerk). Die AS4-Gebäude lagen bei 3–11 %; die Stadthäuser liegen höher
(10–32 %), weil sie mehr Tiefe haben. Die mittlere Helligkeit springt höchstens um 4,6 % am Tag und 9,1 % in der Nacht.

### Flimmern (`my_scene --mode=sparkcam`, Viertelpixel-Schritte seitlich, Anteil der Pixel, die je Schritt um > 0,2 kippen; „Mittel“, 12 Uhr)

| Modell | 40 m | 60 m | 100 m (lod1) | 150 m (lod1) | Sprite 40 / 60 / 100 / 150 m |
|---|---|---|---|---|---|
| `city_german_mietshaus` | 0,3 % | 0,3 % | 0,3 % | 0,4 % | 0,1 / 0,2 / 0,2 / 0,4 % |
| `city_german_gruenderzeit` | 0,6 % | 0,6 % | 0,3 % | 0,4 % | 0,1 / 0,1 / 0,2 / 0,4 % |
| `city_german_old_fachwerk` | 1,1 % | 1,3 % | 0,6 % | 1,1 % | 0,1 / 0,1 / 0,2 / 0,3 % |
| `city_german_old_fachwerk_b` | 1,0 % | 1,0 % | 0,6 % | 0,8 % | 0,2 / 0,2 / 0,4 / 0,6 % |
| `city_hanse_gabled` | 0,5 % | 0,8 % | 0,8 % | 1,3 % | 0,1 / 0,2 / 0,3 / 0,3 % |
| `city_hanse_kontor` | 0,3 % | 0,5 % | 0,5 % | 0,8 % | 0,0 / 0,1 / 0,1 / 0,2 % |

Gemessen auf den Exporten vor dem Türfix (Runde 6 ändert nur Türöffnungen im Erdgeschoss von lod0; Kontor, Mietshaus und Gründerzeit sind unverändert). Die Stadthäuser flimmern 2–10× so stark wie ihre Sprites, absolut 0,3–1,3 % der Pixel je Viertelpixel-Schritt; AS4R nannte Block B mit 1,0 % gegen 0,2 % als Schwäche – die Fachwerkzeile liegt in derselben Größe (Messbild `flimmern_messbild.jpg`).

### Geländer (`baked_cutout`, `mipcov.py` auf den Atlanten)

Deckung des Alpha-Tests (0,5) je Mip-Stufe gegen Mip 0 in 16×16-Blöcken mit Geländer: Mietshaus mip1–3 1,11 / 1,20 /
1,40, mip4 0,29; Gründerzeit 1,12 / 1,19 / 1,32, mip4 0,59. Bis Mip 3 (gerechnet: bis etwa 50 m Abstand bei 150
Texeln je Meter) bleibt das Geländer geschlossen und eher dichter; ab Mip 4 (etwa ab 100 m) dünnt es aus. Halo-Alpha 0,33
(unter der Schwelle 0,5): in den Nahansichten bei Tag und Nacht kein heller oder dunkler Saum zu sehen (angesehen,
nicht gemessen); das Flimmern der Geländer ist in den Werten von Mietshaus und Gründerzeit oben enthalten.

## Im Rennen: Arcade | Modern an drei Stadteinfahrten (`tools/ab_shot.sh`)

Dieselbe Simulation in beiden Modi (Seed 11, Limousine, Autopilot, Verkehr eingeschwungen, fliegender Start mit
50 km/h), Bild 2 s nach dem Start. Positionen aus der Zählung (`census_all.gd`): **Hamburg** (Kiel–Hamburg km 87,6:
Giebelzeilen, Kontor, Speicher, Kran), **Hannover** (Hamburg–Hannover km 141,7: Mietshäuser, Gründerzeithäuser,
Büroturm), **Würzburg** (Kassel–Würzburg km 201,7: Fachwerkzeilen, Turmhäuser, Barock).

| Datei | Ort | Voreinstellung | Uhrzeit | Ergebnis |
|---|---|---|---|---|
| `ab_hannover_hoch_mittag.jpg` | Hannover (Hamburg–Hannover km 141,7) | Hoch | 12 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_hannover_hoch_nacht.jpg` | Hannover (Hamburg–Hannover km 141,7) | Hoch | 22 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_hannover_mittel_daemmerung.jpg` | Hannover (Hamburg–Hannover km 141,7) | Mittel | 19:30 | beide Bilder da, 0 Skriptfehler |
| `ab_hamburg_hoch_mittag.jpg` | Hamburg (Kiel–Hamburg km 87,6) | Hoch | 12 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_hamburg_hoch_nacht.jpg` | Hamburg (Kiel–Hamburg km 87,6) | Hoch | 22 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_hamburg_mittel_daemmerung.jpg` | Hamburg (Kiel–Hamburg km 87,6) | Mittel | 19:30 | beide Bilder da, 0 Skriptfehler |
| `ab_wuerzburg_hoch_mittag.jpg` | Würzburg (Kassel–Würzburg km 201,7) | Hoch | 12 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_wuerzburg_hoch_nacht.jpg` | Würzburg (Kassel–Würzburg km 201,7) | Hoch | 22 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_wuerzburg_mittel_daemmerung.jpg` | Würzburg (Kassel–Würzburg km 201,7) | Mittel | 19:30 | beide Bilder da, 0 Skriptfehler |

**Abweichung vom Auftrag (gemessen, Zeit):** Ein Modern-Lauf mit „Hoch“ braucht auf der geteilten Maschine 6–8 min für
ein Bild (der erste Lauf mit zwei Bildern lief nach 600 s ins Zeitlimit). Statt 18 Läufen (3 Orte × 2 Voreinstellungen ×
3 Uhrzeiten) sind es 9: jeder Ort mit „Hoch“ zu 12 und 22 Uhr und mit „Mittel“ zur Dämmerung (19,5 Uhr) – an
jedem Ort kommen beide Voreinstellungen und alle drei Uhrzeiten vor, nur nicht jede Kombination.

**Was die Bilder zeigen (angesehen):** In Modern stehen an allen drei Einfahrten die Modelle dort, wo Arcade die Bilder
zeigt – gleiche Häuser, gleiche Lage, gleiche Höhe; die Fassaden sind schärfer, mit Tiefe und richtiger Perspektive
statt eines Bildes aus einem festen Blickwinkel. Nachts leuchten in Modern die Fenster und Schaufenster (Kontor mit
Auslage) wie in Arcade. In Hannover fehlt in Modern ein Mietshaus links (Arcade zeigt es etwa 35 m voraus): Die
Ausdehnung des Modells ist dieselbe wie die des Sprites (13,59 / 9,83 m gegen 13,61 / 9,85 m), die Kantenausrichtung
also gleich. Den Platz verwirft eine Ausschlussregel des Requisiten-Builders (`drop_reason`: Sichtkorridor einer Kurve
für dekorative Requisiten oder das Geländeband) – unabhängig davon, ob ein Modell oder ein Platzhalter dort steht
(gefolgert aus dem Code; welche der beiden Regeln, habe ich nicht gemessen). Laut Aufgabenliste beschränkt FIX-M2
(B-01) die Korridorregel auf Vegetation; nach dem Zusammenführen ist zu prüfen, ob das Haus dort steht.
Zur Dämmerung (19:30, Hamburg) leuchten in Modern deutlich weniger Fenster des Kontors als in Arcade, um 22 Uhr
etwa gleich viele: die Lichtrampe über die Uhrzeit ist Sache des Renderers (R4), die Fenster selbst sind dieselben.

**Fahrt durch die Würzburger Altstadt** (`fahrt_wuerzburg_altstadt.mp4`, `tools/ab_clip.sh`, Kassel–Würzburg
ab km 202,0, 12 Uhr, „Hoch“, 10 s, 60 Bilder/s fest, Arcade | Modern): 600 Bilder je Seite, 960×540 je Hälfte, 7,4 MB (gemessen; Modern-Lauf 2 176 s, Arcade 193 s). **Abweichung:** fliegender Start mit 50 km/h, aber der Autopilot beschleunigt trotz Tempo 50 auf 128 km/h (5 s) und bremst dann auf 60 km/h (9,5 s) – eine feste Geschwindigkeit bietet die Rennszene nicht, und ein zweiter Lauf (40 min) war nicht drin. Angesehen (Standbilder bei 1, 5 und 9,5 s in `fahrt_wuerzburg_altstadt_standbilder.jpg`): Fachwerkzeilen, Turmhäuser und Barockhäuser stehen beidseits wie in Arcade, mit Tiefe und richtiger Perspektive; kein Aufblitzen, kein Loch, keine fehlenden Häuser in den Bildern; ob das Umschalten der Stufen in Bewegung auffällt, ist im Film bei dieser Fahrt nicht sicher zu sehen (gefolgert: bei 60 m und 10–32 % Pixelwechsel möglich, siehe Messungen).

## Runden Bauen → Ansehen (Tag, Dämmerung, Nacht) → Beheben

Jede Runde: Export (Probe mit halbem Atlas, ab Runde 4 echt), Bake, Import, Manifest, dann Bilder in der
Spielkamera (12 / 19,5 / 22 Uhr, „hoch“, neben dem Arcade-Sprite), Nahansichten (schräg, Straßenseite, Rückseite,
Dach) und Stufenbilder. Runden 1–4 auf Probe-Exporten, Runde 5 auf den echten Exporten (die committeten Dateien).

| Runde | gesehen | behoben |
|---|---|---|
| 1 (german) | Hecke und Gartenbaum des Einfamilienhauses nach dem Dezimieren kristallin facettiert; gemalte Gauben- und Turmfenster nachts heller als die geschnittenen Scheiben daneben; Glas des Büroturms zu türkis (Sprite spiegelt grauen Himmel); Foyer des Büroturms nachts eine weiße Fläche; eine Abdeckplatte über mehreren Schornsteinen | `shade_smooth` + Dezimierung 0,35/0,4; alles Atlaslicht × 0,55 (Faktor der Scheiben); `albedo_mul` für das Glas (Modell 75/94/103 gegen Sprite 78/95/103 bei 100 m, gemessen); `shop_light` 0,35; eigene Abdeckung je Insel, dann ganz aus (die Generatorschornsteine haben Köpfe) |
| 2 (german_old, hanse) | dunkler, verrauschter Fleck auf gespiegelten Rückwänden (Wand hinter dem Erker: Texel, die nur von innen gesehen werden, waren voll verdeckt); weiße Streifen am Ortgang in lod1 (Dachschräge des Giebelprismas koplanar unter dem Dach); Rückwand-Wiederverwendung griff auch auf Kronen und Gesimse | zweiter Verdeckungslauf (100 m): eingeschlossene Texel nicht abdunkeln (Barock-Rückseite sauber); verdeckte Schrägen entfernen (Haus 4, Barock 28 Flächen); Wiederverwendung nur für Wandmaterialien des Logs |
| 3 (Budget, Stufen) | Speicher 12 170 / 10 482 Dreiecke (über 10 000); lod1 fast so teuer wie lod0, Laibungen bei 60 m und mehr unter einem Pixel | `n_arc` 4 (Bögen), flache lod1 (geschnittene Wand wieder flach, Laibungen/Türen/Lamellen nur lod0): Speicher 8 950 / 1 283, Fachwerkzeile 6 882 / 1 040 |
| 4 (Licht, Dichte) | Foyer des Büroturms an den Fasen (nicht geschnitten) nachts noch weiß; Kontor im Erdgeschoss 39,9 px/m, Obergeschosse 25,9 px/m (Probe); Sockel des Büroturms 17 px/m Modellmaß; Ornamente und Gauben wurden als „Lampe“ geöffnet | `light_mul` (Licht je Material: Foyer 0,35); Kontor Obergeschosse 0,7, Dach 0,25, abgewandt 0,25; Büroturm `floors` bei 12 m (Turm 0,75); nur Lampen der Liste `lamps` öffnen; Farb- und Licht-Bake mit 4 Samples (statt 16: 20 min je 2048er-Atlas) |
| 5 (echte Exporte, alle elf) | Kontaktbögen Tag/Nacht, Spielkamera 8/30/100/250 m zu 12/19,5/22 Uhr neben dem Sprite, Nahansichten: keine Fehler in Umriss, Geschossen, Fensterrhythmus oder Licht. Kleine Mängel: Foyer des Büroturms nachts eine gleichmäßig helle Fläche (gedimmt, ohne Auslage); Konsole unter dem Erker des Fachwerkhauses mit Turm nachts hellgrau; Erkerfenster des Turmhauses nachts gelbe Felder ohne Sprossen (gemalt, nicht geschnitten); Blumenkästen der Fachwerkzeile aus der Nähe facettiert; der Kran aus der Nähe flache rote Kästen (wie der Generator) | deswegen nichts neu exportiert (jede Änderung an `cities3d.py` ändert den Schlüssel aller elf; die Mängel sind klein, selten gesehen – Büroturm 7× – oder Generator-Aussehen; sie stehen unter „Was noch nicht gut ist“) – aber siehe Runde 6 |
| 6 (Stufenbilder der echten Exporte) | lod0 und lod1 bei 60 m nebeneinander: **Rundbogentüren in lod0 rechteckig** (Fachwerkzeile, Barock, Giebelzeile), der 2,8 m breite **Torbogen des Turmhauses ein geripptes Garagentor** – lod1 und Sprite zeigen Bögen und Holztore. Ursache: das Wand-Log vermerkt eine runde Oberkante als `arch` (für die Fensterscheiben), der Türpfad las nur `top` | Türen nehmen `arch` mit; Torbögen über 2,6 m bekommen Holzflügel (`_door_city`). Neu exportiert: die vier betroffenen Modelle; Kran, Büroturm, Kontor und Speicher zur Probe ebenfalls – byte-gleich. Stufenwechsel Turmhaus 17,3 → 16,3 % (gemessen), Bild `tueren_vorher_nachher.jpg` |

## Ehrliche Einordnung

**Was der Spieler jetzt sieht** (Bilder dieses Ordners; Wirkung auf einen Menschen gefolgert):

- **An jeder Stadteinfahrt von Kiel bis Nürnberg** stehen statt flacher Arcade-Bilder echte Häuser – Einfamilienhäuser
  der Vororte (282 Platzierungen), Fachwerkzeilen und Turmhäuser in Würzburg und Nürnberg (194), Mietshäuser und
  Gründerzeitblöcke in Hannover, Kassel, Bremen, Dortmund (149), Giebelhäuser, Speicher, Kontor und Kräne in Kiel,
  Hamburg und Bremen (71). Umriss, Geschosse, Dachformen und Fensterraster stimmen mit dem Sprite überein (IoU ≥ 0,987,
  Kran 0,922, gemessen).
- **Aus der Nähe (5–15 m)** haben die Fassaden Tiefe, die das Sprite nicht hat: Fenster in Laibungen mit Rahmen,
  Sprossen, Sohlbank und Scheibe; Fachwerk als Hölzer vor der Ausfachung; Vorkragungen, Gesimse, Pilaster,
  Fensterverdachungen, Erker; Balkone mit Platten und ausgeschnittenen Geländern; Türen mit Flügeln und Stufen,
  Rundbogentüren mit Bogen; Schaufenster mit Auslage (Regale, Kleiderstange, Theke) hinter dem Glas. Ziegel-, Putz-,
  Sandstein- und Dachdeckungsmuster des Generators im Atlas mit Umgebungsverdeckung, ≥ 40 px/m in Erdgeschoss und
  erstem Obergeschoss der Innenstadthäuser (Modellmaß).
- **Nachts** leuchten dieselben Fenster wie in Arcade, warm und unregelmäßig, Schaufenster mit beleuchteter Auslage,
  die Wandlampe des Einfamilienhauses, Rotlicht und Strahler des Krans, die Flugbefeuerung des Büroturms; bei Tag
  leuchtet nichts.
- **Rückseiten** sind geschlossen und gestaltet (Rückgiebel der Fachwerkhäuser, gespiegelte Straßenwand mit denselben
  Fenstern) – in Kurven sieht man keine offenen Kästen.

**Was noch nicht gut ist** (gemessen, wo eine Zahl steht):

1. **Flimmern in Bewegung** liegt über dem des Sprites: Fachwerkzeile 1,1–1,3 % bei 40–60 m (Sprite 0,1 %), Giebelzeile
   1,3 % bei 150 m (Sprite 0,3 %), Turmhaus 0,8–1,0 % (Sprite 0,2–0,6 %); Mietshaus, Gründerzeit und Kontor 0,3–0,8 %.
   Ursache: Kanten echter Geometrie (Hölzer, Laibungen) und kontrastreiche Atlasmuster ohne Vorfilterung; das Sprite
   ist weichgezeichnet. Mit MSAA („Hoch“) weniger (gefolgert, nicht gemessen).
2. **Stufenwechsel bei 60 m** ändert 10–32 % der Pixel (Fachwerkzeile am meisten: echte Hölzer gegen gemaltes
   Fachwerk, Helligkeit +4,6 % am Tag, +8,9 % nachts; Kontor nachts +9,1 %). Silhouette und Fenster bleiben, aber ein
   aufmerksamer Spieler kann das Umschalten der Fachwerkhäuser sehen. Ein weiches Überblenden ist Sache des Renderers
   (R7, LOD-Feinabstimmung).
3. **Geländer** dünnen ab Mip 4 aus (Deckung 0,29 / 0,59 gegen Mip 0) – etwa ab 100 m (gerechnet): die Balkone
   werden dort heller und luftiger als im Sprite. Mip-Stufen mit erhaltener Deckung bräuchte der Import.
4. **Büroturm-Foyer** nachts eine gleichmäßig gedimmte helle Fläche ohne Auslage (7 Platzierungen); **Erkerfenster**
   des Turmhauses sind gemalt (nachts gelbe Felder ohne Sprossen); die **Konsole** unter dem Erker wirkt nachts zu hell;
   **Blumenkästen** der Fachwerkzeile und **Hecken** des Einfamilienhauses aus der Nähe kantig.
5. **Texeldichte im Spiel**: Kontor und Giebelzeile stehen mit Maßstab bis 1,2 – ihr Erdgeschoss hat dann 34–36 px/m
   statt ≥ 40 (gerechnet aus dem gemessenen Modellmaß).
6. Die **Tönung** der Vororte (Einfamilienhaus `#e8b8a4` in Kiel, Hamburg, Bremen, Rostock usw.) zeichnet der Renderer
   für Modelle noch nicht – bis R7 sie als Instanzfarbe aufträgt, sind diese Häuser in Modern weiß statt rosa.

**Was fehlt:** Messungen auf echter Grafikkarte und dem Steam Deck; die zweite Hälfte der Stilfamilien (AS5a2/AS5b);
Bäume der AS3-Modelle in den Gärten (der Gartenbaum des Einfamilienhauses ist der dezimierte Generatorbaum).

**Am schwächsten** (für die Kunstkritik): das Flimmern und der Stufenwechsel der Fachwerkzeile – des zweithäufigsten
Sets – und die Geländer ab 100 m.

## Geänderte gemeinsame Dateien (rückwärtskompatibel, additiv)

| Datei | Änderung | Zweck |
|---|---|---|
| `tools/blender/ce3d/catalog3d.py` | ein Block `# --- AS5a ---` vor `model_ids()`: `BUILDER_CODE["city"]`, `AO_CITY`, elf Einträge `props/city_*` | die elf Modelle und der Code, der ihren Schlüssel bildet |
| `tools/blender/export_models.py` | `BUILDERS["city"]`, `COST["city"]` (drei Zeilen im Block `# --- AS5a ---`) | der Bauer `city` im Exporter, seine Kostenschätzung für die Verteilung auf Worker |
| `tools/blender/cesprites/props_cities.py` | Hook `close3d` (Voreinstellung aus = Sprite): `timber_house(..., close3d=False)` gibt `front_gable` einen Rückgiebel; `german_old_fachwerk` liest `p["close3d"]` | Rückgiebel der Fachwerkhäuser mit Giebel zur Straße (im Sprite offen); kein Sprite-Vertex bewegt (Geometrie-Gate) |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`) | elf Sets jetzt mit Modell statt Platzhalter |
| `docs/modelle.md` | Statuszeile, neuer Abschnitt 20 | Dokumentation des Bauers, der Hooks, der Tönung, Einordnung |

Neu und eigen: `tools/blender/ce3d/cities3d.py` (Bauer `city`), `assets/models/props/city_{german,german_old,hanse}_*`
(elf Ordner). **Nicht angefasst:** `ce3d/buildings3d.py` (Schlüssel der acht AS4-Hausmodelle unverändert – sie sind
byte-gleich, `git diff 6e48405 -- assets/models` zeigt außerhalb von `props/city_*` nur das Manifest), `props3d.py`,
`bake.py`, `roles.py`, `lod.py`, `glb.py`, `validate_models.py`, `tools/models/**`, `model_db.gd`, der Renderer
(`scripts/race3d/**`, `assets/shaders/modern/**`), Fahrzeuge, Vegetation, Wahrzeichen, Sprites, Sprite-Manifest,
eingefrorene Arcade-Dateien. Die Prüfwerkzeuge der Kunstkritik (`tools/kritik/`, unversioniert) lagen nur während der
Messungen im Worktree und sind vor den Tests gelöscht.

## Lieferung (dieser Ordner)

Alle Bilder auf dieser VM gerendert (llvmpipe), Renn-Look, „Hoch“, wenn nicht anders angegeben.

| Datei | Inhalt |
|---|---|
| `kontaktbogen_{german,altstadt,hanse}_{tag,nacht}.jpg` | jedes Modell, lod0 und lod1, Anfahrt und Rückseite, mit Dreieckszahl; Tag und 22 Uhr |
| `spielkamera_{german,altstadt,hanse}_{mittag,daemmerung,nacht}.jpg` | Spielkamera bei 8, 30, 100 und 250 m neben der Straße, je oben Modell, unten das Arcade-Sprite in derselben Lage; 12 / 19,5 / 22 Uhr |
| `nahansicht_{german,altstadt,hanse}_{tag,nacht}.jpg` | Straßenfassaden aus der Nähe (schräg und von der Straße), 12 und 22 Uhr |
| `tueren_vorher_nachher.jpg` | Runde 6: Rundbogentüren in lod0 vorher rechteckig (Torbogen des Turmhauses als Garagentor), nachher mit Bogen und Flügeln wie lod1 und Sprite |
| `umrisse_sprite_gegen_modell.jpg` | Umriss in der Sprite-Kamera: Sprite, lod0, lod1 (grün = beide, orange = nur Modell, blau = nur Sprite) |
| `stufen_{ger,old,han}_tag_nacht.jpg` | Stufenwechsel: lod0 und lod1 bei 60 m, lod1 und Sprite bei 200 m; 12 und 22 Uhr, „Mittel“ |
| `flimmern_messbild.jpg` | Messbild der Flimmermessung (Modell und Sprite bei 40/60/100/150 m) |
| `toenungen.jpg` | die fünf getönten Platzierungen: Modell, Modell-Albedo × Tönung, Sprite × Tönung, Sprite |
| `ab_*.jpg` | Arcade \| Modern aus demselben Simulationszustand an drei Stadteinfahrten (siehe Abschnitt A/B) |
| `fahrt_wuerzburg_altstadt.mp4` | 10 s Fahrt durch die Würzburger Altstadt, Arcade \| Modern, 60 Bilder/s fest, Autopilot 50–128 km/h (siehe Abschnitt A/B); `fahrt_wuerzburg_altstadt_standbilder.jpg`: Bilder bei 1, 5 und 9,5 s |
| `golden_modern_s4_hamburg_stadtrand_neu.jpg`, `golden_modern_s5_hamburg_ziel_neu.jpg` | die beiden geänderten Modern-Goldens (Stadthäuser statt Arcade-Bilder), angesehen vor dem Neuschreiben der Liste |
| `bericht.md` | dieser Bericht |
