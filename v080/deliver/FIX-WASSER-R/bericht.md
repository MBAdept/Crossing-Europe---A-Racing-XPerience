# FIX-WASSER-R – Behebungen nach der unabhängigen Prüfung QA-WASSER (Testbuild „Zwischenstand 1“)

Für die Leitung. Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-3`,
Branch `worktree-wf_bdb6e1e1-c64-3`, Sicherung `origin/wip/v080-fix-wasser-r`. Keine Vorgängerin (kein `STAND.md`, kein
Remote-Zweig) – frisch begonnen um 09:38 UTC mit `git merge --ff-only 0ad9012` (FIX-WASSER-Kopf).
Commits: `2011ec8` (Spielcode + Tests), `39849f0` (Doku). „gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb);
alles über Steam Deck, echte Grafikkarten und wie etwas auf einen Menschen wirkt, ist **abgeleitet**.

## Urteil

**Beide mittleren Befunde sind behoben, der neue Testbuild ist gebaut, geliefert und geprüft.** B1 und B2 habe ich im
Projekt nachgestellt (Bilder vorher), die Ursache gefunden und in einer Spieldatei behoben
(`scripts/race3d/builders/props.gd`); zwei neue Unit-Tests bewachen das, jeder erkennt seine Mutation. B5 hat jetzt
eine Render-Prüfung, die den Wasserfehler von FIX-WASSER nachweislich erkennt (alter Stand rot mit 31,96 %
Fernboden). Die Nutzerdokumente sind korrigiert (B4). B3 (Kaimauern, fernes Ufer) bleibt offen und steht in
`was_neu.md`. Alle Gates grün auf `39849f0`: 705/0 Tests, Arcade 20/20 und 17/17 identisch, Modern 6/6 identisch,
Render-Prüfungen 18/18.

Ehrlich zum Bild: Nachts ist Modern an der Köhlbrandbrücke jetzt **gleichwertig** mit Arcade (vorher schlechter: weiß
leuchtende Pylone) – nicht besser; die beleuchtete Elbphilharmonie und das rote Warnlicht fehlen weiter. Bei Tag
unverändert (bitgleich): gleichwertig bis etwas besser. In Belgrad, Hannover, Leipzig, Dortmund, Calais und Madrid
steht jetzt ein Wahrzeichen an Arcades Stelle – aber ein **generisches Ersatzbild** (Kirche bzw. Hochhaus), nicht das
wiedererkennbare Bauwerk, das Arcade zeichnet: besser als die leere Wiese vorher, **schlechter als Arcade**.

## 1. Befunde von QA-WASSER – nachgestellt, behoben, geprüft

| Befund | nachgestellt (gemessen) | Behebung | geprüft |
|---|---|---|---|
| **B1** mittel – sechs Wahrzeichen fehlen in Modern | Projektlauf mit dem `props.gd` von `0ad9012`: Ada-Brücke Belgrad km 198,6–199,6 – Arcade zeigt die Kuppelkirche rechts, Modern nichts (`bilder/belgrad_0*_arcade_vorher_nachher.jpg`, Mitte). Datenabgleich: 10 Sets aus `landmark_sets` haben weder Sprite noch Modell, 6 davon stehen in einer `landmarks`-Liste einer Stadt (Belgrad, Hannover, Leipzig, Dortmund, Calais, Madrid) – die anderen 4 nur in Skylines (Hintergrund, nicht betroffen) | `scripts/race3d/builders/props.gd`: Hat ein Wahrzeichen weder Modell noch Sprite, nimmt Modern das Ersatz-Set seines **Etappenplan-Eintrags** (`landmark_fallbacks(track)`: `plan.landmarks` mit `proc` und `fallback`) – der eingefrorene `Track._build_landmark` streicht `fallback` bei `proc`, `fallback_scale` und `fallback_tint` bleiben am Eintrag. Im Stück (`_place()`) und als ferne Vertretung (`_update_far_landmarks()`); eine getönte ferne Vertretung ist ein MultiMesh mit einer Instanz, damit die Tönung schon vor dem Stück gilt. `prepare()`/`collect()` laden die Ersatz-Sets | Unit-Test `test_procedural_landmarks_without_sprite_or_model_get_their_fallback` (alle Wahrzeichen aller Städte in Modern zeichenbar; auf echten Strecken in alle sechs Städte steht das Ersatzbild in seinem Stück, mit `fallback_scale` und `fallback_tint`); Mutation „kein Ersatz-Set“ → genau dieser Test rot (die anderen 8 grün). Bilder: Belgrad und Hannover jetzt mit Ersatzbild an Arcades Stelle |
| **B2** mittel – Pylone der Köhlbrandbrücke nachts fast weiß | Projektlauf mit `props.gd` von `0ad9012`, 22 Uhr, „Hoch“: Pylonbereich (Bildpunkte 500–780 × 150–350) mittlere Helligkeit **103,8** gegen Arcade **60,1**, Anteil über 200/255: 23,8 % gegen 6,4 %. **Ursache:** Modern zeigt den Pylon als Vertretung des Arcade-Sprites `props/bridge_pylon`; dessen Lichtebene ist ein **angestrahlter Pylon** (weiß-blau, mittleres Alpha 0,48) – Arcade zeigt dieses Sprite nie (`prefer_proc`: prozeduraler Pylon, nachts Beton × Umgebungslicht, dazu ein blinkendes rotes Licht). Kein Lampen- oder Pool-Licht (der Billboard-Shader kennt keine Pools) | `props.gd`: Einträge mit `prefer_proc` (nur die Pylone der Schrägseilbrücken) kommen in eine eigene Gruppe `d|<set>|<gespiegelt>` mit `dark_material()` – Kopie des Vertretungsmaterials mit `lights_rect` = 0 (keine Lichtebene) und `headlight_color` = 0 (sonst würde das Scheinwerferlicht, am Fuß gerechnet, das ganze 88-m-Billboard aufhellen). Gleicher Shader, keine neue Variante | Nachher: Pylonbereich **58,4** (Arcade 60,1), über 200/255: 6,1 % (Arcade 6,4 %) – gemessen. Tag: vorher = nachher **bitgleich** in 4 von 4 Bildern (gemessen, `cmp`). Unit-Test `test_procedural_bridge_pylon_stand_in_stays_dark_at_night`; Mutation „nicht dunkel“ → genau dieser Test rot. Steam-Deck-Stufe nachts ebenso dunkel (`kb_nacht_deck_1280x800_ab_01.jpg`). **Nicht behoben:** die verwaschenen Pylonfüße aus der Nähe bei Tag (Vertretung statt Modell) und das rote Warnlicht (lag in der Lichtebene, ist jetzt mit ihr weg) |
| **B3** niedrig – keine Kaimauer/Böschung, kein fernes Ufer | aus den Bildern von QA-WASSER übernommen (`deliver/QA-WASSER/bilder/linux_koehlbrand_tag_hoch_km80_2_brueckenende_ab.jpg`, `linux_holtenau_ab_hamburg_km86_0_ab.jpg`), nicht neu gerendert | **nicht behoben** – Kaimauern und Böschungen gehören zum offenen Brückenbau (R5), Fernwasser/fernes Ufer zum Fernboden (R2); beides ist keine kleine Änderung. Für den Nutzer ein Satz in `was_neu.md` | – |
| **B4** niedrig – Nutzerdokumente | Texte gelesen; `scripts/core/cli_args.gd` liest nur `OS.get_cmdline_user_args()` (nach `--`) – bestätigt | `deliver/FIX-WASSER/was_neu.md`: Bergetappen-Satz ersetzt („Vor und in Kurven … auch auf flachen Etappen, z. B. links am Start von Kiel – Hamburg“), neu unter „Was noch fehlt“: Pylone (flach, Füße verwaschen; nachts jetzt dunkelgrau, rotes Warnlicht fehlt), Wahrzeichen-Ersatzbild in sechs Städten, fehlende Ufer. `deliver/FIX-WASSER/steamdeck_checkliste.md`: Notfall unter Windows ` -- --graphics=arcade` mit den zwei Strichen; Prüfsummen mit `sha256sum -c --ignore-missing SHA256SUMS` und warum ohne den Schalter zwei „FAILED“ kommen. `build_testbuild.sh` bleibt unverändert (Besitz Integration/QA1) | gelesen |
| **B5** niedrig – keine Render-Prüfung am Wasser, Draufsicht mit alter Regel | Code gelesen: `check_terrain_cover.gd` prüft nur Magenta – eine Scheibe über der Elbe ist aber kein Loch, sie ist **cyan**; die von QA vorgeschlagene Position mit 0,2 % Magenta wäre auch mit dem alten Fehler grün geblieben (abgeleitet, dann gemessen: alter Stand 0,000 % Magenta) | `tests/race3d/render/check_terrain_cover.gd`: Position **K1** (Kiel – Hamburg ab Kiel, km 78,1, 12 Uhr) mit zusätzlicher Grenze **höchstens 2 % Fernboden (cyan)** unter dem Horizont. `tests/race3d/check_terrain_plan.gd --dump`: `far_y` jetzt über `FarGround.target_height()` (eine Fassaden-Attrappe wie im Unit-Test von FIX-WASSER) | K1 gemessen: **0,000 % Magenta, 0,38 % Fernboden – OK**; mit dem `far_ground.gd` vor FIX-WASSER (`3a23cb8`) **31,96 % Fernboden – FEHLER** (die Prüfung erkennt den Rückfall). Dump läuft, `far_y` an T1–T4 geschrieben |

## 2. Bilder – ehrlich gegen Arcade (alle angesehen)

Projektläufe (`tools/ab_shot.sh`, Xvfb, `--fixed-fps 60`, `--gfx-sync`); „vorher“ = derselbe Lauf mit dem `props.gd` von
`0ad9012`, vorübergehend in die Arbeitskopie gesetzt und danach aus HEAD wiederhergestellt. In
`deliver/FIX-WASSER-R/bilder/`:

- `kb_nacht_high_0[0-3]_arcade_vorher_nachher.jpg`, `kb_nacht_pylone_ausschnitt_arcade_vorher_nachher.jpg` – 22 Uhr,
  „Hoch“: **vorher** zwei weiß leuchtende Pylonbeine über der Fahrbahn, **nachher** betongrau wie Arcade. Die Seile bleiben
  als helle, dünne Linien sichtbar (sie sind Teil des Grundbilds des Sprites) – Arcade zeigt sie ähnlich hell.
  **Nachts ist Modern an der Brücke jetzt gleichwertig mit Arcade** (vorher schlechter): Elbe, Fähren, Seilfächer, Licht
  auf der Fahrbahn. Schlechter bleibt: die **Elbphilharmonie leuchtet in Arcade, in Modern ist sie nachts nicht zu sehen**
  (schon vorher so, nicht Teil der Befunde; siehe „Für die Nächsten“), und das blinkende rote Warnlicht der Pylone fehlt.
- `kb_nacht_deck_1280x800_ab_01.jpg` – Steam-Deck-Stufe, 1280 × 800, nachts: Pylone dunkel, wie „Hoch“.
- `kb_tag_high_0[0-3]_arcade_vorher_nachher.jpg` – 12 Uhr: vorher = nachher **bitgleich** (gemessen). Bei Tag bleibt
  Modern gleichwertig bis etwas besser (Wasser, Seilfächer, Schatten); die Pylonfüße aus der Nähe sind weiter
  weißlich verwaschen (Sprite-Vertretung, keine Geometrie).
- `belgrad_0[0-2]_arcade_vorher_nachher.jpg` – Ada-Brücke Belgrad: **vorher kein Wahrzeichen**, **nachher** steht rechts
  eine Kirche an Arcades Stelle in ähnlicher Größe. Ehrlich: es ist das **generische Ersatzbild** (Dorfkirche mit
  Turm, getönt), nicht die Kuppelkirche des Heiligen Sava, die Arcade prozedural zeichnet – erkennbar ist das
  Wahrzeichen in Modern also noch nicht. Besser als die leere Wiese, **schlechter als Arcade**.
- `hannover_neues_rathaus_ersatz_ab_0[12].jpg` – Hamburg – Hannover km 147: Arcade zeigt das Neue Rathaus (Kuppel),
  Modern jetzt die Ersatz-Kirche an derselben Stelle links. Gleiches Urteil wie Belgrad.
- Leipzig (Dresden – Leipzig km 107,6–108,8): in den drei Bildern zeigt **weder Arcade noch Modern** das
  Völkerschlachtdenkmal (Häuser und Bäume davor) – kein Beleg im Bild, nur der Unit-Test.

- `belgrad_fern_km187_4_ab.jpg`, `belgrad_fern_1530m_horizont_arcade_oben_modern_unten.jpg` – die **ferne Vertretung**
  (1,53 km voraus, jenseits der geladenen Stücke): Arcade zeigt die Kuppel blass im Dunst am Horizont, Modern jetzt
  die Ersatz-Kirche an fast derselben Stelle, im Gesetz der Wahrzeichen ausgedithert; kein Skriptfehler im Lauf
  (gemessen). Nebenbei gesehen (nicht Teil der Befunde, **nicht untersucht**): am Stadtrand von Belgrad (km 187,4)
  fehlen in Modern rechts der Straße die beigen Mauern und die Häuser, die Arcade dort zeigt – links stehen sie. Die
  Änderung dieses Pakets berührt nur Einträge ohne Modell und Sprite bzw. mit `prefer_proc`; die Ursache liegt also
  vermutlich schon im Stand davor (abgeleitet, nicht mit einem Vorher-Bild belegt).

## 3. Gates (auf `39849f0`, gemessen)

Nacheinander mit `nice -n 5`, eigenes absolutes `XDG_DATA_HOME`, Logs `m1/FIX-WASSER-R/gates/` (`summary.txt`):

| Gate | Ergebnis |
|---|---|
| `godot --headless --path . --import` | Exit 0, 0 Fehlerzeilen |
| `tests/check_scripts.gd` | 307 Skripte geprüft, 0 fehlerhaft |
| `tools/run_tests.sh` (voll) | **705 Tests, 0 fehlgeschlagen** (FIX-WASSER: 703 – die zwei neuen Tests), alle headless Checks OK, „Tests bestanden“ (876 s) |
| `tools/golden.sh check` | **GOLDEN arcade: 20 von 20 identisch**, **arcade-ui: 17 von 17 identisch** (287 s) |
| `tools/golden.sh modern-check` | **GOLDEN modern: 6 von 6 identisch** – kein `modern-make` nötig (keiner der sechs Änderungsmelder zeigt einen Brückenpylon bei Nacht oder eines der sechs Wahrzeichen); OpenGL ES gegen OpenGL an S3: max. 2/255, PSNR 73,2 dB – OK (635 s) |
| `tools/run_render_checks.sh all` | **18 von 18 Render-Prüfdateien in Ordnung** (Arcade: Glanz-Verdeckung 16 OK, Sprite-Spiegelung; Modern: 16 Dateien). Geländesperre: T1–T4, S1, C1 mit denselben Werten wie bei QA-WASSER (0,000 % Magenta), **K1 0,000 % Magenta, 0,38 % Fernboden – OK** |

Fairness (F1–F3, F7, Regel 3) gehört zu `run_tests.sh` und ist grün. Die Änderung berührt die Simulation nicht:
`props.gd` liest Strecke und Plan und schreibt nur seine Knoten; sie lässt nichts weg, sie stellt nur etwas dazu
(ein Ersatzbild genau dort neben der Straße, wo Arcade selbst sein – meist breiteres – Wahrzeichen zeichnet, ab
dessen Vorderkante `x_m` jenseits des Banketts) bzw. dunkelt ein Bild ab – nichts, worauf der Spieler reagieren muss,
wird verdeckt oder verändert (abgeleitet aus dem Code und den Bildern).

## 4. Testbuild

`OUT=m1/FIX-WASSER-R/testbuild tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand` aus dem
sauberen, gepushten `39849f0` (181 s; Exportvorlagen über ein eigenes `XDG_DATA_HOME` verlinkt). Danach
`project.godot` wieder `0.7.0`, Arbeitskopie sauber (gemessen).

| | |
|---|---|
| `BUILDINFO.txt` | Testbuild 0.8.0-zs1 (ZS1), Windows-Version 0.8.0.1, Nutzerordner `crossing-europe-zwischenstand`, Commit `39849f0263921f798da4326b83dff30d83a947d2`, Godot 4.7.2 |
| Linux-Archiv | `CrossingEurope-ZS1-linux-x86_64.tar.gz` 146.922.278 B, SHA-256 `c5699811…eec63` |
| Windows-Archiv | `CrossingEurope-ZS1-windows-x86_64.zip` 156.566.753 B, SHA-256 `3cf4984a…bcd4fa5` |
| Programme | `CrossingEurope-ZS1.x86_64` `59248e24…` (440,7 MB), `CrossingEurope-ZS1.exe` `96130d5d…` (476,5 MB); Spielpaket 1.011 Dateien |
| Größe | 146,9 / 156,6 MB – unter den Grenzen (Warnung 300, Abbruch 330, hart 350 MB) |
| Auslieferung | die fünf Dateien in `deliver/FIX-WASSER/build/` **ersetzt**; die ersetzten (Build aus `0ad9012`) liegen in `m1/FIX-WASSER-R/alt/`. Dort `sha256sum -c --ignore-missing SHA256SUMS`: beide Archive und `LIZENZEN.txt` **OK** (gemessen) |

## 5. Smoke-Tests und Bilder aus den gelieferten Programmen

Alle mit den **gelieferten** Programmen (gemessen; Skripte `m1/FIX-WASSER-R/smokes.sh`, `export_shots.sh`,
`chooser_walk.sh`, Logs `logs/smokes.log`, `smoke/`):

| Lauf | Ergebnis |
|---|---|
| Spielpaket gegen den vorigen ZS1-Build (`alt/`, aus `0ad9012`), Verzeichnis mit MD5 je Datei (`pck_diff.py` von QA-WASSER) | **1 von 1.011 Dateien verschieden: `scripts/race3d/builders/props.gdc`** (25.480 → 27.471 B), keine neu, keine weg – genau die Änderung dieses Pakets |
| `tools/smoke_modern.sh` Linux-Export | **SMOKE linux: OK** – Arcade OK (17 s), Modern OK (75 s), Leistungstest „autobahn“ 11,3 fps (llvmpipe, bedeutungslos für echte Grafik), Version 0.8.0-zs1, Nutzerordner `…/crossing-europe-zwischenstand` |
| dito mit `DRIVER=opengl3_es` (der Weg, den ANGLE unter Windows nimmt) | **SMOKE linux_opengl3_es: OK** – OpenGL ES 3.2, Arcade OK, Modern OK, Leistungstest OK (11,1 fps) |
| dito Windows-Export unter Wine (wine64, eigenes `WINEPREFIX`, `TMPDIR` leer, Pfade `Z:…`) | **SMOKE windows: OK** – Arcade OK, Modern OK, Leistungstest OK (10,5 fps), Nutzerordner `AppData/Roaming/crossing-europe-zwischenstand`; die Logs tragen `platform/windows/…` (wirklich die `.exe`) |
| Erster Start wie ein Spieler (Linux-Export ohne Argumente, 1280 × 800, Tastatur über xdotool) | „GRAFIK WÄHLEN“ erscheint (auf dieser Software-Grafik ist Arcade empfohlen, erwartet), Wechsel auf Modern, Titel mit **v0.8.0-zs1**, Rennen → Fahrzeug → Startzeit → Etappenbildschirm Kiel – Hamburg → Ladebalken → Countdown in Modern mit dem Auto an der Startlinie → Pause-Menü. `settings.json`: `graphics_mode` = `modern`; 0 Skriptfehler (`export_linux_erststart_*.jpg`) |
| Stehender Start Kiel – Hamburg, Linux-Export, „Mittel“, 1 s im Countdown und 1,5 s nach „LOS!“ (Uhr 0:01.48) | Modern zeigt das Auto **an Arcades Platz**, Starttor mit Lampen, Startlinie, Schild „Tankstelle 15 km“ (`export_linux_start_km0_*_ab.jpg`) |
| Köhlbrandbrücke km 78,6, fliegender Start, „Hoch“, 12 Uhr und 22 Uhr, Linux-Export | Tag: **die Elbe unter und neben der Brücke**, Elbphilharmonie und Michel am Horizont; Nacht: Elbe dunkel, **Pylone betongrau** wie Arcade (`export_linux_koehlbrand_*_km78_9_ab.jpg`) |
| dieselben sechs Szenen (Start, Brücke Tag, Brücke Nacht; je Arcade und Modern) mit dem Windows-Export unter Wine | alle Exit 0; **pixelgleich mit dem Linux-Export in 12 von 12 Bildern** (0 Bildpunkte verschieden, gemessen) (`export_windows_*`) |

Alle Exportbilder mit `--fixed-fps 60` und `--gfx-sync` (wie QA-WASSER). Ein Spieler startet ohne diese Schalter –
das Bild ist dasselbe, nur in Echtzeit (abgeleitet).

## 6. Abweichungen

1. Dateibesitz: `builders/props.gd`, `tests/unit/race3d/test_props.gd`, `tests/race3d/check_terrain_plan.gd`,
   `tests/race3d/render/check_terrain_cover.gd` gehören R2 (§5); geändert im Auftrag der Leitung wie bei FIX-WASSER.
2. B3 nicht behoben (R5/R2-Arbeit, nicht klein); nur der Satz in `was_neu.md`.
3. B2 teilweise: nachts behoben, die Pylonfüße bei Tag nicht (braucht ein Modell). Das rote Warnlicht der Pylonspitze
   lag in der Lichtebene des Sprites und ist mit ihr weg (Arcade blinkt).
4. B1 mit dem von QA zuerst genannten Weg (Ersatz-Sprite aus dem Katalog), nicht mit Arcades Zeichnung als Billboard –
   die sechs Wahrzeichen sind damit da, aber nicht wiederzuerkennen.
5. B5 anders als vorgeschlagen: Grenze auf **Cyan** (Fernboden) statt nur Magenta – die vorgeschlagene Magenta-Grenze
   hätte den Fehler nicht erkannt (gemessen: alter Stand 0,000 % Magenta, 31,96 % Cyan).
6. „Vorher“-Bilder: das `props.gd` von `0ad9012` vorübergehend in die Arbeitskopie gesetzt (kein zweiter Worktree), danach
   aus HEAD wiederhergestellt (`git status` sauber, im Log).
7. Exportbilder mit `--fixed-fps 60` und `--gfx-sync` (wie QA-WASSER; FIX-WASSER ohne), damit Arcade und Modern dieselben
   Zeitpunkte zeigen und „Hoch“ stehen bleibt.
8. Zwei kurze Modern-Läufe (ferne Vertretung Belgrad, je etwa 2 min, `nice -n 10`) liefen neben dem vollen
   `run_tests.sh` – kurz zwei schwere Läufe zugleich; sonst alles nacheinander. Die Maschine war sonst leer (Last 0,1
   vor dem Start).

## 7. Vertragsfragen

1. Wahrzeichen nur mit prozeduraler Zeichnung (`proc`, ohne Sprite und Modell) haben in Modern keinen Besitzer und keine
   Vertretung im Vertrag (A-4 nennt für Wahrzeichen „sprite“). Umgesetzt: das Ersatz-Set des Katalogs; endgültig erst mit
   den Wahrzeichen-Modellen (AS6, W6). Der Vertrag sollte das bis dahin so festhalten.
2. §4.9.2 „terrain cover“ kennt nur die Magenta-Grenze; eine verdeckende Scheibe ist kein Loch. Vorschlag: Positionen mit
   Wasser bekommen eine Fernboden-Grenze (K1: 2 %).
3. D16/A-3 beschreiben den Fernboden noch als „tiefste Straße − 4 m“; richtig ist min(…, tiefstes Wasser − 0,3 m)
   (von QA-WASSER, weiter offen).
4. Fernwasser und Ufer (Kaimauer, Böschung, fernes Ufer) haben keinen klaren Besitzer zwischen R2 und R5 (von QA-WASSER,
   weiter offen).

## 8. Für die Nächsten

1. B3: Kaimauern/Böschungen am Brückenende (R5) und Fernwasser/fernes Ufer im Fernboden (R2).
2. Pylon als Modell (AS4R hat einen; mit M2INT) – dann gilt `dark_material()` nicht mehr für ihn; das rote Warnlicht als
   statische Lampe (`add_lamps`, Rolle Befeuerung) oder im Modell.
3. Wahrzeichen der sechs Städte: Arcades prozedurale Zeichnung einmal in ein Billboard rendern oder die Modelle (AS6).
4. Die Elbphilharmonie ist nachts in Modern nicht zu sehen (Arcade: beleuchtet) – ferne Wahrzeichen und ihre Lichtebene
   nachts prüfen (QA-WASSER 2.3, nicht in den Befunden).
5. M2INT: `props.gd`, `test_props.gd`, `check_terrain_plan.gd`, `check_terrain_cover.gd` übernehmen; danach
   `tools/run_tests.sh test_props` und `tools/run_render_checks.sh modern terrain_cover`.
6. Belgrad, Stadtrand (Slavonski Brod – Belgrad km 187,4): rechts der Straße fehlen in Modern Mauern und Häuser, die
   Arcade zeigt (`bilder/belgrad_fern_km187_4_ab.jpg`) – gesehen, nicht untersucht (R2/R6).
7. Unabhängige Prüfung des neuen Builds: nur `props.gdc` ist anders als im von QA-WASSER freigegebenen Build; zu prüfen
   sind also die Pylone nachts (Köhlbrandbrücke, alle Stufen) und die Wahrzeichen der sechs Städte.

## 9. Dateien

- Bericht und Bilder: `deliver/FIX-WASSER-R/bericht.md`, `deliver/FIX-WASSER-R/bilder/`.
- Nutzerdokumente (geändert): `deliver/FIX-WASSER/was_neu.md`, `deliver/FIX-WASSER/steamdeck_checkliste.md`.
- Build: `deliver/FIX-WASSER/build/` (ersetzt). Die ersetzten Dateien (Build aus `0ad9012`, von QA-WASSER geprüft und
  freigegeben) liegen weiter in `m1/FIX-WASSER-R/alt/` (290 MB) – als Rückfall für die Leitung, falls sie den neuen
  Build nicht ohne eigene Prüfung ausliefern will; danach löschbar. Die Arbeitskopie des Builds (`testbuild/`),
  das Wine-Präfix und die Shader-Caches sind gelöscht.
- Arbeitsdateien: `m1/FIX-WASSER-R/` – `STAND.md`, Skripte (`before_queue.sh`, `after_queue.sh`, `modern_only.sh`,
  `triptych.sh`, `k1_measure.sh`, `gates.sh`, `build.sh`, `deliver.sh`, `smokes.sh`, `export_shots.sh`,
  `chooser_walk.sh`), Logs `logs/`, `gates/`, Bilder `before/`, `shots/`, `k1/`, `smoke/`.
