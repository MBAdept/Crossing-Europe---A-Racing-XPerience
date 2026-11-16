# NACH-WASSER – Nachprüfung der Behebungsrunde FIX-WASSER-R am gelieferten Testbuild (ZS1 aus `39849f0`)

Für die Leitung. Reine Prüfrolle: keine Commits, kein Push, kein eigener Branch. Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-4` (`git merge --ff-only 39849f0`,
danach unverändert, `git status` leer). Arbeitsdateien unter `m1/NACH-WASSER/` (`STAND.md`, `notes.md` mit allen
Messwerten, Skripte `tools/`, Logs `logs/`, Roh-PNGs `shots/`, `shots_win/`).

„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb bzw. Wine 9.0); alles über Steam Deck, echte Grafikkarten und wie
etwas auf einen Menschen wirkt, ist **abgeleitet**. Alle Bilder stammen aus den **gelieferten Programmen**
(`deliver/FIX-WASSER/build/`, frisch entpackt), mit `--fixed-fps 60 --gfx-sync`, eigenem absolutem `XDG_DATA_HOME` je
Lauf, `--graphics=arcade|modern` ausdrücklich, Wine mit eigenem `WINEPREFIX` und ohne `TMPDIR`. „Vorher“: die PNGs von
QA-WASSER (`m1/QA-WASSER/shots/`, Build aus `0ad9012`, gleiche Argumente – die Arcade-Bilder sind in allen
verglichenen Szenen bitgleich, also derselbe Simulationszustand) bzw. eigene Läufe des alten Builds
(`m1/FIX-WASSER-R/alt/`).

## Urteil

**Der gelieferte Build darf zum Nutzer.** Er ist genau der geprüfte Stand: Prüfsummen stimmen, `BUILDINFO` nennt
`39849f0`, im Spielpaket ist gegenüber dem von QA-WASSER freigegebenen Build **nur `props.gdc`** anders, Linux- und
Windows-Paket sind gleich. Arcade ist unverändert (golden 20/20 und 17/17; Arcade-Bilder alt = neu in jeder Szene),
Windows unter Wine zeichnet pixelgleich wie Linux (12/12). **B2 nachts ist behoben** – auf Hoch, Mittel, Niedrig und Steam
Deck sind die Pylone betongrau statt weiß, und alt/neu unterscheiden sich **nur** auf den Pylonbeinen; bei Tag und am
Start ist das Bild **bitgleich** mit dem alten Build (die verwaschenen Pylonfüße bei Tag bleiben, wie gemeldet).
**B1 ist behoben, aber nur mit einem Ersatzbild**: alle sechs Wahrzeichen stehen jetzt da (auf allen 20 Anfahrten im
Stück gezeichnet, gemessen), sind aber generische Kirchen bzw. Hochhäuser – in Dortmund und Madrid ein riesiger
Büroblock (211 × 71 m bzw. 250 × 85 m), in Calais eine Dorfkirche statt des Leuchtturms. Das steht ehrlich in
`was_neu.md`. Gates grün, keine blockierenden neuen Fehler; drei niedrige Befunde (Abschnitt 4).

Ehrlich zum Bild: An den geprüften Stellen ist Modern **nicht deutlich besser** als Arcade. Köhlbrandbrücke nachts:
gleichwertig (vorher schlechter), die beleuchtete Elbphilharmonie fehlt weiter, die Seilfächer sind breite Bänder statt
dünner Linien; bei Tag gleichwertig bis etwas besser (Wasser, echte Geländer), die Pylonfüße aus der Nähe weißlich
verwaschen. Start km 0: gleichwertig (links fehlen die Bäume, die Arcade zeigt – absichtlich, dokumentiert). Belgrad,
Hannover, Calais, Dortmund, Madrid: **schlechter als Arcade** (Ersatzbild statt Wahrzeichen), aber besser als vorher
(gar nichts).

## 1. Ist der gelieferte Build der geprüfte Stand? (gemessen)

| Prüfung | Ergebnis |
|---|---|
| `sha256sum -c --ignore-missing SHA256SUMS` in `deliver/FIX-WASSER/build/` | `CrossingEurope-ZS1-linux-x86_64.tar.gz: OK`, `CrossingEurope-ZS1-windows-x86_64.zip: OK`, `LIZENZEN.txt: OK` |
| entpackte Programme gegen `SHA256SUMS` | `CrossingEurope-ZS1.x86_64` `59248e24…00f` und `CrossingEurope-ZS1.exe` `96130d5d…619` – beide wie in der Liste |
| `BUILDINFO.txt` | 0.8.0-zs1, Windows-Version 0.8.0.1, Nutzerordner `crossing-europe-zwischenstand`, Commit **`39849f0263921f798da4326b83dff30d83a947d2`**, Godot 4.7.2.stable.official.ed1daf0bf |
| Spielpaket alter Build (`0ad9012`, von QA-WASSER freigegeben) gegen neuen Linux-Build (Pfad, Größe, MD5 je Datei) | 1.011 / 1.011 Dateien, **1 verschieden: `scripts/race3d/builders/props.gdc`** (25.480 → 27.471 B), 0 neu, 0 weg |
| Spielpaket Linux gegen Windows (neu) | **0 Unterschiede** (1.011 Dateien) |
| `props.gdc` aus dem Build (entpackt, 92.700 B Token-Puffer) | enthält die neuen Bezeichner `landmark_fallbacks`, `dark_material`, `_lm_fallback`, `_dark_mats` – der Build trägt die Behebung |

## 2. Diff `0ad9012..39849f0` – Seiteneffekte und eingefrorene Dateien (Code gelesen)

Sieben Dateien: `scripts/race3d/builders/props.gd`, `tests/unit/race3d/test_props.gd`,
`tests/race3d/check_terrain_plan.gd`, `tests/race3d/render/check_terrain_cover.gd`, `docs/qa-v080.md`,
`docs/renderer-modern.md`, `docs/renderer-modern-gelaende.md`. **Keine** Datei aus der Liste von Regel 1, nichts unter
`data/`, `assets/`, `scripts/race/`; nichts davon speist die Simulation (Regel 3).

- **B2 (`dark_material()`)**: Kopie des Vertretungsmaterials mit `lights_rect = 0` und `headlight_color = 0`. In
  `billboard.gdshader` ist die Lichtebene über `lights_rect.z > 0.0` geschaltet, das Scheinwerferlicht mit
  `headlight_color` multipliziert – beides greift. Tag/Nacht kommt aus den globalen `ce_*`-Werten, die Kopie veraltet
  also nicht. Gleicher Shader, keine neue Programmvariante (abgeleitet). Betroffen sind nur Einträge mit `prefer_proc` –
  laut `Track._build_bridge` (eingefroren) ausschließlich die Pylone der Schrägseilbrücken.
- **B1 (`landmark_fallbacks()`)**: Ersatz-Set aus `track.plan.landmarks` (`proc` + `fallback`), nur wenn das Set weder
  Modell noch Sprite hat; im Stück (`_place()`, mit `fallback_scale` und `fallback_tint`) und als ferne Vertretung. Wie
  Arcade: Vorderkante an `x_m`, nie gespiegelt, als Wahrzeichen nie im Sichtkorridor weggelassen. Die Tabelle wird im
  Hauptthread jedes Mal neu angelegt (nie verändert), die Bau-Threads lesen also eine stehende Tabelle – kein
  Datenrennen (gelesen).
- **Seiteneffekt (Befund N1)**: `_update_far_landmarks()` liest jetzt das `tint` **jedes** fernen Wahrzeichens. 20
  Wahrzeichen-Einträge der Städte mit Sprite tragen ein `tint` (z. B. „Rathausturm“ auf Hamburg → Kiel km 92,8,
  City-Hochhaus Leipzig, viele `props/church`); deren ferne Vertretung ist jetzt getönt wie im Stück und wie in Arcade
  (vorher ungetönt, bis das Stück übernahm). Eine Verbesserung, aber größer als der Bericht von FIX-WASSER-R sagt („berührt
  nur Einträge ohne Modell und Sprite bzw. mit `prefer_proc`“) und durch keinen Test und kein Bild belegt. Auf Kiel →
  Hamburg ohne Wirkung (Elbphilharmonie und Michel haben kein `tint`); an der Ankunft in Kiel (Hamburg → Kiel, ab km 90,6,
  vier Aufnahmen) sind alt und neu **bitgleich** (gemessen; der Turm ist dort nicht als ferne Vertretung im Bild).
- Tests: Die zwei neuen Unit-Tests prüfen genau die Behebungen (Material der Pylone; Ersatz-Set, Maßstab und Tönung der
  sechs Wahrzeichen im Stück); die ferne Vertretung prüft keiner.

## 3. Die Befunde der unabhängigen Prüfung – am gelieferten Build

### B1 (mittel) – sechs Wahrzeichen fehlten in Modern → **behoben (mit generischem Ersatzbild)**

| Beleg | Ergebnis |
|---|---|
| Datenabgleich (`tools/lm_cover.py`): Wahrzeichen der Städte ohne Sprite und ohne Modell | genau 6 (Belgrad, Hannover, Leipzig, Dortmund, Calais, Madrid); jedes Ersatz-Set (`props/church`, `props/building_tall`) ist zeichenbar |
| Headless mit dem Kern-Kontext des Unit-Tests (`tools/lm_chunk_check.gd`): **jede** Anfahrt in die sechs Städte | **20 von 20** Anfahrten: Ersatzbild im Stück des Wahrzeichens gezeichnet (der Unit-Test prüft je Stadt nur eine Anfahrt) |
| Headless (`tools/lm_corridor.gd`): steht ein Ersatzbild im Sichtkorridor einer Kurve (F7)? | **nein** – 0 von 15 Messpunkten der Grundfläche auf allen 20 Anfahrten; die Fairness ist nicht berührt |
| Belgrad, Ada-Brücke km 199,8, „Hoch“ (QA-Wiederholung) | Ersatzkirche rechts an Arcades Stelle; alt/neu unterscheiden sich **nur** im Rechteck x 1036–1175, y 87–344 (die Kirche), Arcade bitgleich |
| Hannover km 147,5 / 148,2 | Ersatzkirche links statt Neuem Rathaus, ähnlich groß |
| Calais km 209,8 | Dorfkirche statt Leuchtturm (Arcade: weißer Turm mit schwarzer Laterne) |
| Dortmund km 153,1 | **riesiger Büroblock** (Hochhaus × 3,2: 211 m hoch, 71 m breit) rechts; alt/neu unterscheiden sich nur um diesen Block. Arcades schlanker Fernsehturm ist dort noch hinter Stadthäusern verdeckt; Modern lässt diese Häuser (wie schon im alten Build) im Sichtkorridor der Kurve weg, der Block steht frei und beherrscht die rechte Bildhälfte. Ab km 154,6 verlässt er das Bild nach rechts (Anker 142 m neben der Straße), Arcade zeigt den Turm bis km 154,8 |
| Madrid km 231,1 | ein Büroblock (× 3,8: 250 × 85 m) statt der vier schlanken Türme – als „Hochhaus“ noch am ehesten passend |
| Leipzig | nur headless (gezeichnet auf 5 von 5 Anfahrten); FIX-WASSER-R sah es in keinem Modus im Bild |
| `tools/run_tests.sh test_props` | `test_procedural_landmarks_without_sprite_or_model_get_their_fallback` ok (9 Tests, 0 fehlgeschlagen) |

Urteil B1: Die Lücke („kein Wahrzeichen“) ist geschlossen, genau mit dem ersten Weg, den QA vorgeschlagen hat. Die
Wahrzeichen sind aber **nicht wiederzuerkennen**; in Dortmund wirkt der Ersatz-Büroblock fremd (Befund N2).

### B2 (mittel) – Pylone der Köhlbrandbrücke nachts fast weiß, Pylonfüße bei Tag verwaschen → **teilweise**

| Beleg | Ergebnis |
|---|---|
| 22 Uhr, „Hoch“, ab km 77,6 mit Verkehr (QA-Wiederholung), Pylonbeine bei km 78,1 (Bildpunkte x 518–550 / 648–690, y 285–340), mittlere Helligkeit 0–255 | Modern **50,5 / 46,4**, Arcade 66,3 / 45,1; alter Build (QA-WASSER-PNG, gleiche Szene) **210,2 / 131,2** mit 83 % / 50 % der Bildpunkte über 200 |
| dasselbe bei km 79,6 (zweites Pylonpaar, nah) | Modern 46,0 / 35,1, Arcade 42,0 / 30,7 |
| FIX-WASSER-Rs Bereich (500–780 × 150–350, km 78,1; enthält HUD-Banner) | Modern 58,0 (6,1 % über 200), Arcade 60,2 (6,4 %), alter Build 103,0 (23,6 %) – deckt sich mit 58,4 / 60,1 / 103,8 bei FIX-WASSER-R |
| „Mittel“ und „Niedrig“ (gleiche Szene) | Pylonbeine 50,5 / 46,4 bzw. 50,7 / 46,0 – wie „Hoch“ |
| „Steam Deck“, 1280 × 800 (QA-Argumente) | dunkelgrau; alt/neu unterscheiden sich nur auf den Pylonen (2,1–9,5 % der Bildpunkte), Arcade bitgleich |
| alt gegen neu, „Hoch“, km 79,6 | Unterschied **nur** auf den zwei Pylonbeinen (Rechteck x 376–846, y 0–421), alles andere bitgleich |
| Tag, „Hoch“, ab km 79,0 mit Verkehr (QA-Argumente) | alt = neu **bitgleich** in 4 von 4 Modern- und 4 von 4 Arcade-Bildern → die Pylonfüße nah an der Kamera sind weiter weißlich verwaschen (nicht behoben, wie gemeldet) |
| Windows unter Wine, Nacht „Hoch“ | 8 von 8 Bildern pixelgleich mit Linux |
| Unit-Test `test_procedural_bridge_pylon_stand_in_stays_dark_at_night` | ok |

Urteil B2: Nachts **behoben** (Überstrahlung weg; Pylonbeine −16 bis +4 Helligkeitsstufen gegen Arcade). Offen wie
gemeldet: Pylonfüße bei Tag (braucht das Pylon-Modell), das rote Warnlicht (lag in der Lichtebene; Arcade blinkt
eines). Nebenbei: die Seilfächer sind nachts breite, mattblaue Bänder (Teil des Sprites), Arcade zeichnet dünne Linien.

### Die übrigen Punkte von FIX-WASSER-R

- **B3** (niedrig, Kaimauern/fernes Ufer): **nicht behoben**, steht in `was_neu.md` („Ufer“) – nicht neu geprüft.
- **B4** (niedrig, Nutzerdokumente): **behoben**. `steamdeck_checkliste.md`: der Prüfsummenbefehl liefert genau dreimal
  „OK“ (gemessen); `-- --graphics=arcade` ist richtig (`CliArgs` liest `OS.get_cmdline_user_args()`). `was_neu.md`
  passt zu meinen Bildern (Pylone nachts dunkelgrau, Warnlicht fehlt, Elbphilharmonie nachts nicht zu sehen,
  Ersatzbild „Kirche oder Hochhaus“ in den sechs Städten).
- **B5** (niedrig, Render-Prüfung am Wasser): **behoben** – `tools/run_render_checks.sh modern terrain_cover` auf
  `39849f0`: 7 von 7 OK, **K1 0,000 % Magenta, 0,38 % Fernboden** (Grenze 2 %), gleiche Werte wie bei FIX-WASSER-R.

## 4. Neue Befunde (alle niedrig, keiner blockiert die Auslieferung)

- **N1 – Getönte ferne Vertretung für alle Wahrzeichen mit `tint`, nicht nur die sechs** (Code, siehe 2). Verbesserung
  (gleich wie im Stück und in Arcade), aber nicht berichtet und nicht getestet. Vorschlag: im Bericht/`docs` nennen und
  einen Test für die ferne Vertretung eines getönten Wahrzeichens ergänzen.
- **N2 – Ersatzbild in falscher Gestalt und Größe**: Dortmund (Fernsehturm → Büroblock 211 × 71 m), Madrid (vier Türme
  → ein Block 250 × 85 m), Calais (Leuchtturm → Dorfkirche). Die Maße folgen dem eingefrorenen `fallback_scale`, der für
  Arcades Ersatz-Sprite gedacht war. Vorschlag: im Code je `proc`-Art ein passenderes Set bzw. die Breite begrenzen,
  Arcades prozedurale Zeichnung einmal in ein Billboard rendern (QAs zweiter Weg) – oder bis AS6 so lassen; `was_neu.md`
  sagt es schon allgemein.
- **N3 – In Städten fallen auf der Kurveninnenseite auch Häuser weg** (vorbestehend, Regel F7, nicht von dieser Runde):
  Dortmund km 152,99–154,51 sieben Stadthäuser rechts („corridor“, gemessen; im alten Build genauso). Auf Kiel – Hamburg
  fällt nur Vegetation weg (51 Pflanzen, 1 Heuballen), auf dem Rennen Kiel – Nürnberg aber auch Häuser:
  Hamburg – Hannover 10, Hannover – Kassel 3, Kassel – Würzburg 12 (gemessen, `tools/drop_summary.gd`). `was_neu.md`
  nennt nur „Bäume und Felsen“ – für die Rennen ein Satz „in Städten auch einzelne Häuser“. Das erklärt auch FIX-WASSER-Rs
  Beobachtung am Belgrader Stadtrand (km 187,4).

## 5. Bilder – ehrlich gegen Arcade (alle angesehen), `deliver/NACH-WASSER/bilder/`

| Datei | Was | Urteil |
|---|---|---|
| `linux_koehlbrand_nacht_hoch_km78_1_ab.jpg`, `…km78_8_ab.jpg`, `…km79_6_ab.jpg` | Brücke 22 Uhr, „Hoch“, Verkehr | Pylone grau wie Arcade; Elbphilharmonie fehlt in Modern; gleichwertig |
| `linux_koehlbrand_nacht_km79_6_modern_alt_neu_unterschied.jpg` | alt / neu / Unterschied (rot) | nur die Pylonbeine ändern sich |
| `linux_koehlbrand_nacht_km78_1_pylone_ausschnitt_arcade_modern.jpg` | Ausschnitt, 2-fach | Pylone in Modern so dunkel wie in Arcade, Seile breiter |
| `linux_koehlbrand_nacht_km78_1_modern_mittel_links_niedrig_rechts.jpg` | „Mittel“ und „Niedrig“ | ebenso dunkel |
| `linux_koehlbrand_nacht_deck_1280x800_km78_1_ab.jpg`, `…deck_km79_6_modern_alt_neu_unterschied.jpg` | Steam-Deck-Stufe | dunkel; nur Pylone geändert |
| `linux_koehlbrand_tag_hoch_km79_5_ab.jpg` | Tag | bitgleich mit vorher; Wasser und Seilfächer gut, Pylone weißlicher als Arcade |
| `linux_start_km0_countdown_ab.jpg`, `linux_start_km0_los_plus_1_5s_ab.jpg` | Start, „Mittel“ | Auto, Starttor, Schild wie Arcade; bitgleich mit vorher und mit FIX-WASSER-R |
| `windows_wine_koehlbrand_nacht_hoch_km78_1_ab.jpg`, `windows_wine_start_km0_los_plus_1_5s_ab.jpg` | Windows-Export | pixelgleich mit Linux |
| `linux_belgrad_ada_km199_8_ersatzkirche_ab.jpg`, `linux_belgrad_km199_8_modern_alt_neu_unterschied.jpg` | Belgrad | Ersatzkirche statt Kuppelkirche; nur sie ist neu |
| `linux_hannover_km147_5_ersatzkirche_ab.jpg`, `…km148_2_ersatzkirche_ab.jpg` | Hannover | Ersatzkirche statt Neuem Rathaus |
| `linux_calais_km209_8_leuchtturm_ersatzkirche_ab.jpg` | Calais | Dorfkirche statt Leuchtturm – schlechter als Arcade |
| `linux_dortmund_km153_1_ersatz_hochhaus_ab.jpg`, `linux_dortmund_km153_1_modern_alt_neu_unterschied.jpg`, `linux_dortmund_km154_6_ab.jpg`, `linux_dortmund_km154_7_ab.jpg` | Dortmund | Büroblock statt Fernsehturm, beherrscht das Bild; ab km 154,6 rechts aus dem Bild, Arcade zeigt den Turm noch |
| `linux_madrid_km231_1_ersatz_hochhaus_ab.jpg` | Madrid | ein Block statt vier Türme |

## 6. Gates (gemessen, auf `39849f0` bzw. den gelieferten Programmen, nacheinander, `nice`)

| Gate | Ausgabe |
|---|---|
| `godot --headless --path . --import` | Exit 0 |
| `tools/golden.sh check` (einmal) | `GOLDEN arcade: 20 von 20 identisch (149 s)`, `GOLDEN arcade-ui: 17 von 17 identisch (214 s)`, Exit 0 |
| `tools/run_tests.sh test_props` | `307 Skripte geprüft, 0 fehlerhaft`; `9 Tests, 0 fehlgeschlagen`; `==> Tests bestanden (20 s)` |
| `tools/run_render_checks.sh modern terrain_cover` | `RENDER-CHECKS OK (0 fehlgeschlagen, 77 s)`; T1–T4, S1, C1, K1 OK; K1: 0,000 % Magenta, Fernboden 0,38 % |
| Prüfsummen, `BUILDINFO`, Spielpaket alt/neu und Linux/Windows | siehe Abschnitt 1 |
| Exportläufe Linux (26: 24 mit dem gelieferten, 2 mit dem alten Build) und Windows/Wine (4) | alle Exit 0, in keinem der 30 Logs `SCRIPT ERROR`, `SHADER ERROR` oder ein Rückfall auf Arcade; die Windows-Logs tragen `platform/windows/…` (wirklich die `.exe`) |

Nicht wiederholt: das volle `tools/run_tests.sh` (FIX-WASSER-R: 705/0) und `golden.sh modern-check` (6/6) – das
Spielpaket unterscheidet sich vom freigegebenen nur in `props.gdc`, und dessen Tests und Bilder habe ich gezielt geprüft.
Fairness-Tests (F1–F3, F7) gehören zum vollen Lauf; die Änderung berührt die Simulation nicht (Code), und kein
Ersatzbild steht in einem Sichtkorridor (gemessen, B1).

## 7. Abweichungen

1. „Vorher“-Bilder größtenteils aus den PNGs von QA-WASSER (gleiche Argumente, Arcade bitgleich) statt eigener Läufe des
   alten Builds; eigene Läufe des alten Builds nur für Hamburg → Kiel und Dortmund.
2. Neben den Godot-Renderläufen liefen vier kurze headless-Prüfskripte (je 7–11 s, `nice -n 10/15`); zeitweise lief
   auf der Maschine auch eine Testreihe eines anderen Pakets.
3. Volle Testreihe und `modern-check` nicht wiederholt (Begründung in 6).
4. Bildschirme für Belgrad/Hannover/Calais/Dortmund/Madrid ohne `--weather=normal`/`--autopilot-refuel=never` – die
   Arcade-Bilder Belgrads sind trotzdem bitgleich mit QA-WASSERs (gleiches Wetter, gemessen).

## 8. Vertragsfragen

1. A-4 nennt für Wahrzeichen als Vertretung nur „sprite“; Wahrzeichen nur mit prozeduraler Zeichnung brauchen eine
   festgeschriebene Vertretung bis AS6 (wie von FIX-WASSER-R gemeldet) – mit der Frage, ob `fallback_scale` (für Arcades
   Ersatz-Sprite gedacht) dafür taugt (N2).
2. F7 lässt in Städten Gebäude der Landschaftsregel weg (N3); der Vertrag (A-3) beschreibt Bodendecker nur für Pflanzen
   – ob Häuser auf der Kurveninnenseite wegfallen dürfen, sollte die Leitung festhalten.

## 9. Für die Nächsten

1. N2: passendere Vertretung je `proc`-Art (Turm statt Büroblock, Leuchtturm statt Kirche) oder Arcades Zeichnung als
   Billboard; endgültig AS6.
2. N1: Test für die getönte ferne Vertretung (z. B. „Rathausturm“ Kiel von Hamburg aus, km 80–85).
3. N3: `was_neu.md` für Rennen um „in Städten auch einzelne Häuser“ ergänzen; R2/R6 entscheiden, ob Stadthäuser in
   Kurven bleiben dürfen.
4. B2-Rest: Pylon als Modell (AS4R/M2INT), rotes Warnlicht als statische Lampe; Elbphilharmonie nachts.
5. `m1/FIX-WASSER-R/alt/` (290 MB, alter Build) kann gelöscht werden, sobald die Leitung ausgeliefert hat.

## 10. Dateien und Aufräumen

- Bericht und Bilder: `deliver/NACH-WASSER/bericht.md`, `deliver/NACH-WASSER/bilder/` (23 JPGs).
- Messwerte: `m1/NACH-WASSER/notes.md`; Logs `m1/NACH-WASSER/logs/` (`golden.log`, `tests_props.log`,
  `render_terrain_cover.log`, `queue1–6.log`, `lm_chunk_check.log`, `lm_corridor.log`, `drop_check_*.log`,
  `drop_summary.log`); Skripte `m1/NACH-WASSER/tools/`; Roh-PNGs `shots/`, `shots_win/` (74 MB).
- Gelöscht: entpackte Builds (neu und alt), Wine-Präfix, `XDG_DATA_HOME`-Ordner, Mesa-Caches, behaltene Golden-Bilder.
  Der Worktree ist unverändert (`git status` leer).
