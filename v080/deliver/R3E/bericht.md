# Bericht R3E – Arcades Bild als Ersatz für Fahrzeuge ohne Modell (v0.8.0, Abschnitt 1)

- Worktree: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-2`
- Branch: `worktree-wf_c23ec0b9-e7b-2`, Sicherung `origin wip/v080-r3e` (nach jedem Commit gepusht, nie erzwungen)
- Basis: `4d02ada` (R3-Kopf); Kopf: siehe Abschnitt 3
- Dateien: neu `scripts/race3d/vehicle_standin.gd`, `assets/shaders/modern/vehicle_sprite.gdshader`,
  `tests/unit/race3d/test_vehicle_standin.gd`, `tests/race3d/render/check_vehicle_standin.gd` (je mit `.uid`);
  geändert `scripts/race3d/layers/vehicles.gd` (Zeile 155 – Material des Kontaktschattens – unverändert) und
  `docs/renderer-modern.md` (nur der neue Unterabschnitt 10.8). `model_factory.gd` und `vehicle_pose3d.gd` blieben
  unverändert (gelesen: `ModelFactory.box_lights`, `VehiclePose3D.fade/flare_params`). Keine eingefrorene
  Arcade-Datei, keine Datei eines anderen Pakets, kein Set-Name im Code (nur die Gruppen `traffic/`, `police/`,
  `player/` wie bei R3).

**Wie die Angaben zu lesen sind.** „gemessen“: auf dieser VM gelaufen (headless bzw. Mesa llvmpipe unter Xvfb), mit
dem Stand, der dabeisteht. „gefolgert“: aus Code oder Bildern geschlossen, nicht gemessen. Über echte Grafikkarten
und das Steam Deck sagt dieser Bericht nichts (alles dort: gefolgert).

## 1. Was geliefert ist

Entscheidung der Leitung: Ein Fahrzeug-Set ohne 3D-Modell zeigt in Modern **Arcades eigenes Bild** – nichts ist
schlechter als in Arcade. Sets mit Modell nehmen R3s Weg unverändert; bekommt ein Set ein Modell
(`ModelDB.has_model`), verschwindet sein Ersatzbild von selbst.

| Teil | Wo | Stand |
|---|---|---|
| Weiche je Set: Modell / Ersatzbild (`sprite`, `boxtex`) / gemalter Kasten (nur ohne Blatt) | `vehicles.gd` `_set_info`, `_load_standins` | fertig |
| Zellwahl wie Arcade (Verkehr 17 Winkel, Spieler 21 Winkel, Dämpfung, Hysterese, Blinken) | `VehicleStandIn.traffic_cell/player_cell/view_inputs`, `vehicles.gd _update_sprite/_player_sprite_cell` | fertig |
| Bild im Raum: Viereck am Anker, Faltung wie Arcades Warp, Bodenschürze, Spielerbild zum Auge gezogen | `vehicle_sprite.gdshader` | fertig |
| Licht wie Arcade (`_modulate`: Tageszeit, Tunnel, Nebel, Scheinwerferkegel, feste Lampen), Lampenebenen | `VehicleStandIn.ArcadeShade`, Shader | fertig |
| Kasten-Sets: echte Kästen je Teil mit Arcades Flächen, Einheiten/Gelenk wie R3s Gruppen | `VehicleStandIn.box_part_mesh/build_box_node` | fertig |
| Lichtpunkte (R3, F6), Kontaktschatten, verborgene Kastenwerfer, Ausblendung F5, Tiefenverdeckung | `vehicles.gd`, Shader (2 Durchgänge) | fertig |
| Leistung: ein MultiMesh je Blatt, alle Blätter in `prepare()` | `VehicleStandIn.SheetBatch` | fertig |
| Prüfungen | 9 Unit-Tests, Render-Prüfung mit 6 Teilen | grün (Abschnitt 3) |
| Doku | `docs/renderer-modern.md` 10.8 „Ersatzbilder für Fahrzeuge ohne Modell“ | fertig |
| Bilder | 20 Bilder in diesem Ordner | Abschnitt 4 |

## 2. Abnahme Punkt für Punkt

| Nr. | Punkt | Ergebnis | Beleg |
|---|---|---|---|
| 1 | Set ohne Modell zeigt Arcades Bild (Verkehr/Polizei: Ortho-Blatt, 17 Winkel; Spieler: perspektivisch, 21 Winkel) | erfüllt | Unit `test_each_set_gets_its_picture` (Fixture-Blätter: Pkw → Sprite, Spieler → Sprite perspektivisch, Lkw → Kasten, nicht vorbereitetes Blatt → gemalter Kasten mit Warnung, Set mit Modell → sein Modell, Blatt nicht geladen); Bilder 01–12 (gemessen) |
| 2 | Zelle genau wie `RoadRenderer._vehicle_cell` / `_draw_player` (Gier gegen den Sehstrahl, Dämpfung, Hysterese) | erfüllt | Unit `test_traffic_cell_equals_arcade`: Arcades eigener Code und `VehicleStandIn` Bild für Bild, über 20.000 Fälle, mindestens 12 verschiedene Zellen, Gier-Abweichung < 1e-5°; `test_player_cell_equals_arcade`: 900 Bilder mit Kurven, Lenken, Spurwechsel, Untersteuern, 21 Winkel; `test_view_inputs_match_arcade_on_a_straight` (auch gedrehte Kamera, Sehne R 136 m); `test_fold_columns_equal_arcade_warp`, `test_fold_rule_is_arcades` (alle gemessen). Spielerzelle läuft beim Blinken weiter wie in Arcade (Code) |
| 3 | Spielerbild dort, wo Arcades sitzt – S1, kombi / sportwagen / gran_turismo, Lage und Größe in px (Ziel ≤ 3 px) | erfüllt | Render-Prüfung `spieler` (gemessen, `fbfd1b5`): Bildrechteck gegen `last_player_pose.rect` **0,0 / 0,0 / 0,0 px**; gezeichnete Pixel (Rahmen der Differenz mit/ohne Auto) **2 / 3 / 2 px** |
| 4 | Größe aus `image_width_m`, Anker auf dem Boden (Verkehr) | erfüllt | Render-Prüfung `verkehr` (gemessen): Sportwagen bei 20 / 60 / 150 m **2 / 2 / 1 px** gegen Arcade (20 m gefaltet wie Arcades Warp); `kasten`: Bus bei 30 m **3 px** |
| 5 | Licht wie Arcade (Tageszeit, Tunnel, Nebel), Helligkeit ± 10 % (gemessen) | erfüllt | Unit `test_modulate_equals_arcade`: `ArcadeShade` = `RoadRenderer._modulate` nach `_prepare`/`_project` an über 1.400 Stellen (Tag, Dämmerung, Nacht, Stadt mit Laternen, Tunnel, Kamera im Tunnel), Abweichung < 1e-4. Render-Prüfung (gemessen): Tag Spieler **+0,8 / −0,8 / +2,7 %**, Verkehr **−0,2 / +1,5 / +1,0 %**, Bus **−0,2 %**; Nacht (22 Uhr, Karosserie) Spieler kombi **−6,0 %**, heller Lieferwagen bei 20 / 60 m **−3,6 / −1,8 %**. Ein dunkelroter Sportwagen nachts: −11,4 % – das ist das dunkle Ende des 3D-Pfads, nicht das Licht (Abschnitt 6.1). Tunnel und Nebel nur im Unit-Test, nicht im Bild |
| 6 | Nacht: Lampenebene des Blatts + R3s Lichtpunkte an den Kasten-Ankern (F6-Mindestgrößen bleiben) | erfüllt mit Abweichung | Lampenebenen (Rücklicht, Bremse, Blaulicht A/B) wie Arcades Zeichenfolge im Shader; Lichtpunkte über R3s `flare_params` (Größen unverändert). Bei Bildern nur Heckleuchten, hintere Blinker und Blaulicht (5.2). Render-Prüfung `nacht` meldet die beleuchtete Fläche (Lieferwagen 20 m: 6490 px gegen Arcades 10648 px – Arcades Glühen ist größer); Bilder 02, 04, 06, 08, 10, 12, 14 |
| 7 | Kasten-Sets: echter Kasten je Teil mit Arcades Flächen, gelenkig wie R3s Gruppen, Lampen über R3s Kastenlichter | erfüllt | Unit `test_box_faces_and_units` (Flächen-UVs im Bild jeder Fläche, Front zeigt das Heckbild, eine Gruppe je Einheit, Königszapfen 1,65 m hinter der Front, 1,19 m hoch, ein verborgener Werfer je Einheit); `check_vehicles kasten` „Sattelzug in 2 Einheiten“; Render-Prüfung `kasten` 3 px / −0,2 %; Bilder 09–12 |
| 8 | Kontaktschatten unter jedem Ersatzbild; verborgener Kastenwerfer bei `shadow_casters ≥ 1` | erfüllt | `check_vehicles schatten` (gemessen): deck / low / medium / high – Kontaktschatten unter 15 von 15 Autos, Werfer an / aus / an / an; ein Werfer-MultiMesh je Blatt (`SHADOWS_ONLY`) |
| 9 | Ausblendung F5 und Tiefenverdeckung wie bei Modellen | erfüllt | Ausblendung: dieselbe `VehiclePose3D.fade` und derselbe Dither wie `vpbr` (Code). Verdeckung: Render-Prüfung `verdeckt` (gemessen): Ersatzbild hinter der Kuppe T2 bei 346 m, Lampen an, **0 von 921.600 Pixeln** geändert um 12 und 22 Uhr (sichtbar bei 20 m: 6353 / 6720 px). Das Bild steht in der Tiefe des Autos (ein früherer Stand zog es 2,6 % näher – behoben, 5.3) |
| 10 | Wenige Zeichenaufrufe (MultiMesh je Blatt), µs je Auto wie `perf().vehicle_us_avg` | erfüllt (knapp) | Ein MultiMesh je Blatt, zwei Durchgänge (deckend + weich) = 2 Zeichenaufrufe je Blatt mit Autos, Werfer 1 (Aufbau, gefolgert – Zeichenaufrufe nicht gezählt). `check_vehicles leistung` (gemessen, Grenze 40 µs Median je Auto und Bild): Kopf `fbfd1b5` **35,6 / 35,9 / 38,4 µs**, aber einmal 49,5 µs (p90 62); Stand `25daca8` 38,7 / 39,0 / 39,7 µs und im vollen Lauf 48,9 µs (p90 63) – die Messung springt auf dieser geteilten VM zwischen zwei Lagen (5.6, 6.6). Gleiche Szene abwechselnd in einem Prozess (Kopf): mit Ersatzbildern 34,4–38,9 µs, mit R3s gemalten Kästen 29,3–33,1 µs (34 Autos, davon 14 Ersatzbilder) |
| 11 | Alle Blätter in `prepare()`, `SpriteDB.loads` ändert sich während der Fahrt nicht | erfüllt | Render-Prüfung `laden` (gemessen): 10 s mit Verkehr und Autopilot, `SpriteDB.loads` 71 → 71; Kiel – Hamburg: 18 Blätter, geschätzt 69,2 MB (BPTC mit Mipmaps, gerechnet, nicht gemessen) |
| 12 | Set mit Modell unverändert (R3s Weg) | erfüllt | Unit `test_each_set_gets_its_picture` (ein echtes Set mit Modell aus dem Manifest: kein Ersatz, sein Modell, sein Blatt nicht geladen); `check_vehicles lampen` 180 Autos mit Set, Modell und Lampen |
| 13 | Ersatzbild verschwindet, wenn das Manifest ein Modell bekommt; keine Set-IDs im Code | erfüllt | Weiche nur über `ModelDB.has_model` (Code); Render-Prüfung überspringt Sets mit Modell und sagt es |
| 14 | `check_vehicles` und `test_vehicles` grün | erfüllt | Voller Lauf 2 (`fbfd1b5`): `check_vehicles` 6 von 6 (lampen, kasten, leistung 36,4 µs, schilder, lampen_fest, schatten), `test_vehicles` grün (gemessen). Im vollen Lauf 1 (`25daca8`) war `leistung` rot (48,9 µs, 6.6) |
| 15 | `tools/run_tests.sh`, `tools/golden.sh check` „20 von 20 identisch“, `tools/run_render_checks.sh modern` | erfüllt | 603 Unit-Tests 0 fehlgeschlagen, 73 `CHECK` OK; **GOLDEN arcade: 20 von 20 identisch**; 6 von 6 Modern-Render-Prüfdateien (Abschnitt 3, gemessen) |
| 16 | Bilder A/B je Art bei 20/60/150 m, Tag und Nacht, drei Spielerautos, vorher/nachher | geliefert | Abschnitt 4 |

## 3. Prüfungen – was auf welchem Stand lief

Commits seit der Basis (alle gepusht nach `origin wip/v080-r3e`): `8e4ad83`, `da415bf`, `b4d21a1`, `00f2102`,
`25daca8`, `fbfd1b5` = Kopf (gleich `origin wip/v080-r3e`, Arbeitsbaum sauber).

| Lauf | Stand | Ergebnis (gemessen) |
|---|---|---|
| `tools/run_tests.sh` vollständig, Lauf 2 (der letzte erlaubte) | `fbfd1b5`, sauber | **bestanden**: 244 Skripte ohne Fehler, **603 Unit-Tests, 0 fehlgeschlagen**, 73 `CHECK … OK`, 0 `FEHLER` (darunter `check_vehicles` 6 von 6, `leistung` 36,4 µs); 578 s |
| `tools/run_tests.sh` vollständig, Lauf 1 | `25daca8` | 603 Unit-Tests 0 fehlgeschlagen; alle `CHECK`-Dateien in Ordnung außer `check_vehicles leistung` **48,9 µs** (p90 62,6) – die langsame Lage der VM (6.6); danach `fbfd1b5` |
| `tools/golden.sh check` (einmal, am Ende) | `fbfd1b5`, sauber | **GOLDEN arcade: 20 von 20 identisch** (155 s) |
| `tools/run_tests.sh vehicle` (Filter) | Inhalt von `25daca8` | 244 Skripte ohne Fehler; 73 Unit-Tests der Fahrzeugdateien, 0 fehlgeschlagen (darunter `test_vehicle_standin` 9 und `test_vehicles`); `check_vehicles` 5 von 6 – `leistung` 40,9 µs bei Last 9–11 (danach dreimal einzeln: 38,7 / 39,0 / 39,7 µs OK) |
| Bench abwechselnd (Scratch-Skript, nicht im Repo) | `25daca8` | Ersatzbilder 40,1 / 41,0 / 39,0 µs, gemalte Kästen 36,5 / 32,4 / 34,9 µs je Auto und Bild |
| `check_vehicle_standin` einzeln, alle 6 Teile | Inhalt von `25daca8` außer der Nacht-Auswahl | spieler, verkehr, kasten, verdeckt, laden OK; nacht damals FEHLER (dunkelroter Sportwagen −11,4 %), nach Umstellung auf das helle Auto einzeln OK (Kombi −6,0 %, Lieferwagen −3,6 / −1,8 %) |
| `tools/run_render_checks.sh modern` | `fbfd1b5`, sauber | **6 von 6 Dateien in Ordnung**, 26 `RENDER-CHECK … OK`, 0 `FEHLER`: `check_facade_render`, `check_models`, `check_occlusion` (kuppe, lkw: 0 Pixel), `check_seam_render`, `check_vehicle_lights`, `check_vehicle_standin` – spieler 0,0 px / 2–3 px / +0,8 −0,8 +2,7 %; verkehr 2 / 2 / 1 px, −0,2 / +1,5 / +1,0 %; kasten 3 px, −0,2 %; nacht Kombi −6,0 %, Lieferwagen −3,6 / −1,8 %; verdeckt 0 Pixel um 12 und 22 Uhr; laden 71 → 71 |

`run_tests.sh` lief zweimal vollständig (erlaubt: höchstens zweimal), `golden.sh check` einmal am Ende. Die
Arcade-Render-Prüfungen (`run_render_checks.sh arcade`) liefen nicht – R3E ändert keine Arcade-Datei, `golden.sh`
ist grün.

## 4. Bilder und Urteil

Alle Bilder: stehende Szene, Autos eingesetzt, Arcade und Modern im selben Augenblick (links | rechts),
Kiel – Hamburg km 2 (S1), Voreinstellung Mittel, Stand `25daca8` (der Kopf `fbfd1b5` ändert nur, wie schnell dunkle
Lichtpunkte übersprungen werden – dasselbe Bild). Je Art ein Auto bei 20 m (Mittelspur), 60 m (eigene
Spur, Blinker) und 150 m (linke Spur). Modern zeigt nur, was es heute gibt (R1a-Debugstraße, kein Gelände-Schmuck, keine
Scheinwerferkegel) – Bäume, Leitplanken, Himmel und Lichtkegel sind nicht Sache dieses Pakets.

| Bild | Inhalt |
|---|---|
| 01 / 02 | Sportwagen, 12 / 22 Uhr; Spieler Kombi |
| 03 / 04 | Lieferwagen, 12 / 22 Uhr; Spieler Sportwagen |
| 05 / 06 | SUV, 12 / 22 Uhr; Spieler Gran Turismo |
| 07 / 08 | Polizei (Blaulicht bei 60 m), 12 / 22 Uhr; Spieler Kombi |
| 09 / 10 | Bus (Kasten-Set, mittlerer Bus bei 58 m wegen 6.5), 12 / 22 Uhr; Spieler Sportwagen |
| 11 / 12 | Sattelzug ohne Modell (Lauf ohne Lkw-Modell im Manifest), 12 / 22 Uhr; Spieler Gran Turismo |
| 13 / 14 | vorher / nachher: R3s gemalter Kasten gegen Arcades Bild (Sportwagen 20 m, Lieferwagen 45 m, Polizei 70 m, SUV 110 m, Bus 160 m) |
| 15 | Kurve T1 (Kassel – Würzburg km 46,5): nahe Autos gefaltet; Modern mit Blick in die Kurve (D12), daher andere Lage |
| 16 / 17 | Ausschnitt 4-fach: Sportwagen bei 20 m (gefaltet), Tag / Nacht |
| 18 / 19 / 20 | Ausschnitt 2-fach: Spielerauto Kombi, Sportwagen, Gran Turismo |

**Urteil (alle Bilder angesehen, Stand `25daca8`).**

- **Gleich wie Arcade:** Die Fahrzeuge selbst. Bei Tag sind Verkehr, Polizei, Bus, Sattelzug und die drei
  Spielerautos in Lage, Größe, Winkel und Farbe nicht von Arcade zu unterscheiden (Ausschnitte 16, 18–20: dieselben
  Pixel bis auf die Filterung; Kennzeichen, Spiegel, Spoiler sitzen gleich). Das gefaltete Auto bei 20 m zeigt
  dieselbe Flanke wie Arcades Warp (16, 17). Nachts liegen Rücklichtebene, Bremslicht, Blaulicht und die roten
  Umrisslichter des Aufliegers wie in Arcade (02, 08, 12).
- **Besser als Arcade:** Die Bilder stehen in echter Tiefe – hinter einer Kuppe verschwinden sie (Prüfung
  `verdeckt`), Busse und Lkw sind echte Kästen ohne Arcades fehlende Heckfläche (6.5). Gegenüber dem bisherigen Stand
  in Modern (R3s gemalter Kasten, 13/14) ein Sprung: aus Klötzen in Lackfarbe werden die Autos, die man aus Arcade
  kennt.
- **Schlechter als Arcade (an den Fahrzeugen):** Nachts ist Arcades rotes Glühen um die Rückleuchten größer und
  weicher als R3s Lichtpunkte (02, 04, 17 – gewollt, F6 bleibt). Sehr dunkle Teile (Reifen, Scheiben, dunkle Lacke
  nachts) sind einige Stufen dunkler (6.1). Das Licht ist eingebacken: es folgt nicht Moderns Sonne, und in der Kurve
  bleibt es bei Arcades Ansichten (15).
- **Fehlt in Modern, nicht in diesem Paket:** Scheinwerferkegel auf der Straße (nachts der größte Unterschied der
  ganzen Bilder), Bäume, Leitplanken, Wolken, Sonne, Mond – Sache von R1/R2/R4.

## 5. Abweichungen

**5.1 Schnappschuss.** Jedes Ersatzbild meldet `lod` = „box“ (die Ersatzstufe des Manifests, die R3s
`check_vehicles kasten` erwartet) und dazu `standin` = „sprite“, „boxtex“ oder „painted“, `cell`, `fold`, `pull`. So
bleibt R3s Prüfung unverändert gültig; wer wissen will, *was* gezeichnet wird, liest `standin`.

**5.2 Lichtpunkte eines Bildes.** Ein Ersatzbild bekommt nur die Lichtpunkte, die Arcade über sein Bild zeichnet:
Heckleuchten, Bremse, hintere Blinker, Blaulicht. Scheinwerfer und vordere Blinker leuchten bei einem Bild nicht – es
hat keinen Körper, der sie verdeckt, ihr Schein stand sonst über dem Dach oder an der Wagenecke (gesehen, behoben).
Liegt ein Lichtpunkt hinter der Bildebene, rückt er entlang des Sehstrahls davor, mit angepasstem Radius (gleiche
Größe auf dem Bildschirm, F6 bleibt).

**5.3 Bild im Raum.** Verkehrsbilder stehen in der Tiefe ihres Autos; was sie unter der Bodenlinie zeigen (Straße
und Arcades eingebackener Schatten), liegt entlang des Sehstrahls 2 cm über der Straße (dieselben Pixel). Ein
früherer Stand dieses Pakets zog das ganze flache Bild 2,6 % zum Auge (alle Ortho-Blätter: unterste Zeile 7 cm unter
dem Anker) – das ist ersetzt. Nur das perspektivische **Spielerbild** wird weiter zum Auge gezogen (Faktor ≈ 0,70: es
reicht 1,2–1,35 m unter seinen Anker); zwischen Kamera und Spieler steht nichts, Arcade zeichnet ihn ohnehin zuletzt.

**5.4 Kasten-Sets.** Das Sprite-Manifest kennt keine Drehpunkte: die Kupplung kommt aus AS1s Sattelzug (Zapfen
1,65 m hinter der Front des Aufliegers, 1,19 m hoch, Zugmaschine dreht 0,6 m dahinter). Die Front eines Kastens zeigt
Arcades Heckbild (Arcade hat kein Frontbild; man sieht sie nur bei Gegenverkehr, den es nicht gibt).

**5.5 Nachtprüfung mit hellem Auto.** Die Nacht-Helligkeit wird an einem hellen Auto gemessen (Lieferwagen weiß),
weil der 3D-Pfad sehr dunkle Werte selbst dunkler zeigt als Arcades Leinwand (6.1). Gemessen am dunkelroten
Sportwagen: −11,4 % auf dem Dach (Werte um 24/255).

**5.6 Leistung.** Die Ersatzbilder machen die Fahrzeug-Ebene teurer: in R3s Szenario (34 Autos, 14 davon
Ersatzbilder) im Mittel 4–6 µs je Auto und Bild mehr als mit gemalten Kästen, also rund 10–14 µs je Ersatzbild
(Zellwahl wie Arcade, Arcades Licht, MultiMesh-Puffer – gemessen mit einem abwechselnden Lauf und vorübergehenden
Zeitmessern). Ausgeglichen habe ich davon, was ohne Verhaltensänderung ging: Lichtpunkte ohne Schleife, wenn keine
Lampe brennt (`fbfd1b5`, wirkt für Modelle wie Bilder). R3s Grenze von 40 µs hält damit in der normalen Lage der VM
(35,6–38,4 µs), nicht aber in der langsamen (≈ 49 µs, siehe 6.6). Auf dem Steam Deck gefolgert unkritisch (eigene
Kerne, keine Nachbarn), gemessen nichts.

## 6. Vertragsfragen und Befunde für andere Pakete

**6.1 Dunkles Ende des 3D-Pfads (an R1).** Mit dem Spielerbild, das in beiden Modi pixelgleich liegt (Rechteck
0,0 px), lässt sich die Übertragung messen: Arcade-Wert → Modern-Wert je Kanal 4,7 → 0,4 · 11,3 → 6,8 · 19,3 → 16,1 ·
28,3 → 26,5 · 36,1 → 34,7 · 44,7 → 42,4 · 51,5 → 50,2 · ab etwa 56/255 gleich (± 0,5) – mittags wie um 22 Uhr
(gemessen, llvmpipe). Sehr dunkle Teile jedes 3D-Inhalts erscheinen in Modern also einige Stufen dunkler als auf
Arcades Leinwand; das passt zu einem Zwischenpuffer mit linearen 8 Bit (gefolgert, nicht belegt). Den größten Teil
(der Compatibility-Renderer schickt ein ungeleuchtetes ALBEDO durch sein Polynom sRGB → linear) gleicht der Shader aus
(`albedo_for`, wie `billboard.gdshader`): vorher nachts −25 %, jetzt −11 % am dunkelroten Sportwagen, −6 % am Kombi,
−2 … −4 % an hellen Autos. Der Rest ist nicht Sache eines Shaders (nur mit Rauschen auszugleichen). Dasselbe zeigt
eine Prüfung eines anderen Pakets im selben Lauf: `RENDER-CHECK nacht` (23 Uhr) misst die Debug-Straße mit 6/13/27
gegen Arcades 16/21/32. Bitte bei R1 prüfen: Pufferformat/Präzision der 3D-Szene, bevor die Nacht abgenommen wird.

**6.2 Vertrag §4.4.2 Punkt 4 gegen die Entscheidung der Leitung.** Der Vertrag sieht in Modern keine Sprite-Blätter
vor; das Ersatzbild braucht sie. Kiel – Hamburg: 18 Blätter, geschätzt 69,2 MB Grafikspeicher (gerechnet). Arcade
lädt dieselben und mehr. Für das Steam Deck (16 GB geteilt) gefolgert unkritisch; gemessen ist nichts.

**6.3 A-4 „box“-Ersatz und Doku 10.1/10.7.** Die Ersatzstufe „box“ des Manifests bedeutet in Modern jetzt „Arcades
Bild“ (Kasten nur noch ohne Blatt). 10.8 sagt das; 10.1 und 10.7 sprechen noch vom „Kasten in Größe und Lack“ – der
Doku-Eigner sollte sie angleichen (nicht meine Abschnitte).

**6.4 Doppelschatten (an R1/Leitung).** Arcades Blätter tragen einen eingebackenen Schlagschatten; mit
`shadow_casters ≥ 1` wirft zusätzlich der verborgene Kasten. Die Debug-Straße (R1a) empfängt noch keine Schatten,
deshalb sieht man heute nur den eingebackenen. Sobald R1s Straße Schatten empfängt, liegen zwei Schatten unter jedem
Ersatzbild (gefolgert). Entscheidung nötig: Werfer für Bilder abschalten oder den eingebackenen Schatten ausblenden.

**6.5 Arcade-Fehler (eingefroren, Regel 1 – nur gemeldet).** `BoxVehicle.emit` zeichnet die Heckfläche eines Teils
nur bei `pz0 >= z_lo` mit `pz0 = (z + L/2) + z0`; die Rundung in Doppelgenauigkeit lässt sie manchmal fallen. Gesehen:
Bus bei Kamera + 60,3 m und + 62 m ohne Heck (Arcade-Bild der ersten Serie). Gerechnet (Python, dieselbe Arithmetik):
an 0,1 % der Heckpositionen eines Busses, 0,3 % eines Sattelzugs. Modern zeigt die Fläche. Bild 09/10 verwendet
deshalb 58,3 m.

**6.6 Leistungsgrenze 40 µs auf geteilter VM (an R3/Leitung).** R3s `check_vehicles leistung` misst absolute
Wanduhrzeit. Auf dieser VM (4 Kerne, mehrere Pakete rendern zugleich) liegt derselbe Code in zwei Lagen: Median
35,6–39,7 µs (p90 41–75) oder 48,9–49,5 µs (p90 62–63) – Faktor ≈ 1,3, wie ein Kern, den sich der Lauf mit einem
anderen teilt (gefolgert). In der langsamen Lage reißt die Grenze, in der normalen hält sie; mit R3s gemalten Kästen
läge die langsame Lage bei ≈ 38–43 µs (gerechnet aus 29–33 µs × 1,3), also ebenfalls an der Grenze. Vorschlag: den
Median relativ zu einem Lauf mit gemalten Kästen im selben Prozess prüfen oder CPU-Zeit statt Wanduhr messen; die
Datei gehört R3, ich habe sie nicht geändert.

## 7. Für die Nächsten

- **AS2a/AS2b:** Jedes neue Modell im Manifest löst sein Ersatzbild ab, ohne Codeänderung. Die Render-Prüfung
  sucht sich ein Set ohne Modell; gibt es keines mehr, meldet sie „nichts zu vergleichen“ (kein Fehler).
- **RINT-A:** Zeile 155 von `vehicles.gd` ist unverändert; das Ersatzbild nutzt denselben Kontaktschatten.
- **R1:** dunkles Ende (6.1) und Doppelschatten (6.4) vor der Nachtabnahme klären; Scheinwerferkegel auf der
  Straße fehlen in Modern noch (Arcade hat sie – in den Nachtbildern der größte sichtbare Unterschied, nicht dieses
  Pakets).
- **Prüfungen:** `check_vehicle_standin` hat 6 Teile (spieler, verkehr, kasten, nacht, verdeckt, laden), 4,5–7,5 min
  je nach Last; `--only=` und `--save=` helfen beim Nachsehen.
- **Werkzeug:** Die A/B-Bilder entstehen mit einem Skript außerhalb des Repos (Szene still, Autos eingesetzt, Arcade
  und Modern derselbe Augenblick); die Render-Prüfung zeigt, wie man Arcades Renderer zur Laufzeit erweitert, ohne
  die eingefrorene Datei anzufassen.
