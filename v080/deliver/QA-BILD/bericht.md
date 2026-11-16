# QA-BILD – unabhängige Prüfung des Schubs M1 (Kopf 9b6adbc): Bild, Fairness, Leistung

Prüfer: QA-BILD (keine Commits, kein Push). Arbeitskopie `.claude/worktrees/wf_ae4df3ba-14f-2`, per `--ff-only` auf
`9b6adbce9b2b1443ee3ec795c16460e3890328b3`. „Gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb, 4 geteilte Kerne,
Last während der Prüfung 4–12 durch andere Aufträge, llvmpipe mit 2 Rasterthreads); alles über echte Grafikkarten,
das Steam Deck und Windows/ANGLE ist „abgeleitet“. Bilder und Clips liegen in diesem Ordner (Abschnitt 8).

## Urteil

Technisch ist der Schub solide: Die Fairness-Rechnungen F1–F3, F7 und die Pfadprüfung halten im vollen Netz genau die
Vertragszahlen (Reserve bei F2 Regen nur 0,004), Rückfall, OpenGL ES, 16:10 auf dem Deck und gleiche
Simulationszustände funktionieren, in Bewegung flimmert nichts und keine Detailstufe springt sichtbar, kein Lauf meldete
eine Instanz-Ablehnung oder einen Skript-/Shaderfehler, der Lack liegt mittags innerhalb 10 % am Sprite.

Bildlich ist Modern **noch nicht deutlich besser als Arcade**. Auf freier Autobahn bei Tag ist es gleichwertig bis
etwas besser (Gelände mit Tiefe, echte Schatten, scharfe Nahmodelle, Felder), an den markanten Stellen von Kiel–Hamburg
aber schlechter: Tankstelle ohne Dach im Tutorial-Moment, Köhlbrandbrücke ohne Geländer, Elbphilharmonie und Michel
fehlen (neu, steht in keiner Lückenliste), kein Zieltor; nachts zwei weiße Mond-Glanzflecken auf dem Spielerauto; kein
Regen/Schnee; ferne Bäume als graublaue „Geisterbäume“; Straßenränder in Kurven durch den Sichtkorridor kahl. Tunnel
anderer Etappen sind offenes grünes Gelände unter schwarzem Himmel (ebenfalls nicht in der Lückenliste).

Leistung (nur Software-Rasterung messbar): Modern kostet auf llvmpipe 6–10 × Arcades Rasterzeit. `render()` liegt unter
dem echten GL-Pfad bei Last 10 im Mittel bei 1,9–2,7 ms (Budget 1,5 bzw. 2,0; Median 1,6 ms), Stück-Einhängen bis
20 ms (Budget 3) – die Budgets werden nur kopflos geprüft. Einzelne Bilder mit 45–479 ms in der Fahrzeug-Ebene, an
wechselnden Stellen, vermutlich Rechenzeitentzug der überlasteten VM. Laden hier 15–37 s (RINT-B: 5,2–5,6 s), fast nur
Aufwärmen. Speicher: über die ganze Etappe Lüttich–Paris (16 min Spielzeit) kein Wachstum, keine
Waisen – kein Leck. Gegen Arcades `_draw` (9 ms) braucht der Renderer in GDScript nur ein Viertel.

Empfehlung für den Testbuild: Tunnel-Abhilfe (oder Modern auf Kiel–Hamburg beschränken), Mondglanz dämpfen und ein
Ersatz-Tankstellendach vorher; Brücke, Zieltor, Wahrzeichen, Wetter als bekannte Lücken in die Testhinweise; die
Leistungstest-Werte vom Deck (render-ms, 1 %-Tief) als einzige echte Leistungsaussage behandeln.

## 1. Befunde (Schwere: Blocker / hoch / mittel / niedrig)

Jeder Befund: wo – was – Beleg (gemessen/abgeleitet) – Nachstellen – Abhilfe. Bildpfade relativ zu diesem Ordner.

### B1 hoch – Tunnel sind in Modern offenes Gelände (andere Etappen des Testbuilds)
- Wo: jede Tunnelstrecke, z. B. U1 (Bern–Mailand km 186, Gotthard) und DEV (dev_testetappe km 48–50). Kein
  `builders/tunnel.gd` (R5, Welle 3); `builders/terrain.gd` legt auch in Tunnelreihen Gras an.
- Was: keine Röhre, keine Wände, kein Portal, kein Hügel – grünes Gelände unter schwarzem Himmel, das HUD meldet
  „TUNNEL“. Arcade zeigt Röhre, Lampen, Notgehweg. Wirkt kaputt, nicht wie ein Platzhalter.
- Beleg (gemessen, Bild): `ab_mittel/U1_ab_00.jpg`, `U1_ab_01.jpg`, `DEV_ab_00.jpg` (Portal und Hügel fehlen), `DEV_ab_01.jpg`.
- Nachstellen: `m1/QA-BILD/tools/ab.sh <ordner> medium U1 DEV -- --shot-times=2,6`.
- Abhilfe: vor dem Testbuild eine Minimalröhre (Kasten aus Wänden und Decke in Arcades Tunnelfarbe je Tunnelreihe,
  Gelände dort weglassen, Portal als Wand mit Öffnung) – oder Modern im Testbuild auf Etappen ohne Tunnel beschränken
  und es in den Hinweisen sagen. Kiel–Hamburg selbst hat keinen Tunnel. In der Lückenliste der Zusammenführung fehlt
  dieser Punkt.

### B2 hoch – Tankstelle an S2 liest sich nicht (Tutorial-Moment von Kiel–Hamburg)
- Wo: Kiel–Hamburg km 13,6–15 (Tankspur); fehlender Builder `station.gd` (R6).
- Was: kein Dach mit „TANKSTELLE“, keine Insel mit Bordstein, keine gelbe Linie; Zapfsäulen stehen im Gras; nachts
  dunkler Vorplatz ohne Dachbeleuchtung. Gerade hier zeigt das Tutorial „in 1,4 km kommt die Tankstelle“.
- Beleg: `ab_mittel/S2_ab_00.jpg`, `ab_varianten/S2H22_ab_00.jpg` (gemessen, Bild).
- Abhilfe: für den Testbuild Arcades Dach als Ersatz (Kasten mit Arcades Dachflächen wie bei den Kasten-Fahrzeugen,
  Lampen über `add_lamps`), Insel/Bordstein und gelbe Linie im Fahrbahn-Shader; sonst R6 vorziehen.

### B3 hoch – Köhlbrandbrücke ohne Geländer, Wahrzeichen Hamburgs fehlen
- Wo: Kiel–Hamburg km 80–82 (S4).
- Was: (a) keine Brückengeländer, dunkles Wasser beidseits – liest sich als Damm (bekannt); (b) **neu**: Elbphilharmonie
  und Michel stehen in Arcade bei 6 s am Horizont, in Modern fehlen sie ganz. Arcade zeichnet Wahrzeichen bis
  Sichtweite × 2 (hier 1.800 m, `RoadRenderer.landmark_fade`, voll deckend bis 1.296 m, ohne Aufpoppen); in Modern setzt
  sie nur der Requisiten-Builder in geladenen Stücken, `builders/landmarks.gd` (R7) fehlt. Gemessen (Sonde
  `probe/landmarks.gd`, ab km 80): die Elbphilharmonie wird bei 1.018 m Weg gesetzt, der Michel bei 1.012 m – jenseits
  des Nebelendes (900 m), wo die Requisiten-Shader sie ausdithern; sichtbar werden sie erst unter etwa 765 m und dann
  stark vernebelt (voller Tiefennebel, B7).
- Beleg: `ab_mittel/S4_ab_00.jpg`, `S4_ab_01.jpg`, `details/crop_s4_landmarks.jpg` (Bild),
  `pruefungen/wahrzeichen_hamburg.log` (gemessen).
- Abhilfe: Geländer als einfacher Zaun im Randausstattungs-Builder auf Brückensegmenten; Wahrzeichen jenseits der
  Stücke als Ersatzbild am Pfad bis Arcades Reichweite (Haken der Ebene `backdrop` oder ein kleiner `landmarks.gd` mit
  Sprite-Ersatz), Dunst nach `RoadRenderer.landmark_fade`.

### B4 hoch – Ziel- und Starttor fehlen
- Wo: S5 (Ziel Hamburg), C1 (Ziel Frankfurt voraus); `builders/gantry.gd` (R6) fehlt.
- Was: nur das Schachbrett auf der Fahrbahn; Arcades Brücke „ZIEL“ fehlt (bekannt).
- Beleg: `ab_mittel/S5_ab_00.jpg`, `details/crop_c1_far.jpg`.
- Abhilfe: Minimal-Tor (zwei Pfosten + Banner mit Arcades Bild) vor dem Testbuild.

### B5 hoch – Spielerauto nachts mit weißen Glanzflecken (Mond im Klarlack)
- Wo: `assets/shaders/modern/vpbr.gdshader` `light()`, Klarlack-Spitze `dr = d_ggx(ndh, mix(0.001, 0.1, coat_roughness))`
  ohne Bezug zur Lichtstärke; nachts ist das gerichtete Licht der Mond.
- Was: zwei weiße Flecken auf Dach und Kofferraum der Limousine, sobald der Mond vor dem Wagen steht.
- Beleg (gemessen): DEV 21 Uhr, Wagenausschnitt 560–720 × 490–600: p95-Leuchtdichte 193 gegen Arcade 51, Mittel 39 gegen
  34 (`details/crop_dev_car.jpg`); S1 22 Uhr: p95 112 gegen 50 (`details/crop_s1h22.jpg`).
- Nachstellen: `ab.sh <ordner> medium DEV S1H22`.
- Abhilfe: Klarlack-Spitze nachts dämpfen (Faktor `mix(1.0, 0.08, ce_night)`) oder ihre Spitzenhelligkeit auf die
  Anzeige-Helligkeit der Mondscheibe begrenzen; danach `paintcmp.py` bei 22 Uhr erneut.

### B6 hoch – kein Wetter in der Luft (bekannt, R4)
- N1 ohne Schneefall, N2 ohne Regen und Gischt; Fahrbahn wird nass bzw. bekommt Schneeränder (`ab_mittel/N1_ab_*`,
  `N2_ab_*`). Für Nacht-/Wetter-Etappen ist Modern damit sichtbar schwächer als Arcade.

### B7 mittel – Nebel: Requisiten und Fahrzeuge anders als Boden und als Arcade
- Wo: `baked`, `leaves`, `billboard`, `vpbr`, `sign` nehmen den vollen Tiefennebel der Engine; nur `terrain.gdshader`
  schreibt `FOG` mit Arcades 0,7 × t.
- Was: (a) ferne Bäume als graublaue „Geisterbäume“ auf grünen Feldern, mit dunklem Kontaktschatten darunter; (b)
  Fahrzeuge an der Sichtgrenze verlieren Kontrast gegen Arcade (siehe 3.2, abgeleitet ≈ (1 − t): 30 % bei 0,839 × Sicht).
- Beleg: `details/crop_s1_far.jpg`, `crop_s1_far_nofog.jpg` (mit `--gfx-debug=cover` sind es grüne Bäume), Werte
  129/137/145 gegen Arcade 26/37/19 (gemessen); Kontrast (abgeleitet aus den Mischformeln).
- Abhilfe: dasselbe `FOG`-Gesetz wie das Gelände in `baked/leaves/billboard`; für `vpbr`/`sign` Arcades Gesetz
  (multiplikative Tönung, kein zusätzlicher Dunst über der F5-Ausblendung) und die Pflicht-Render-Prüfung
  „Objekt an der Sichtgrenze < 3 % Kontrast“ (§4.9.2) nachziehen.

### B8 mittel – Sichtkorridor räumt Straßenränder leer
- Wo: `builders/props.gd` `drop_reason()` → „corridor“ (F7 + A-3).
- Was: an T1/T2 fehlen Baumgruppen, Kiefern und ein Findling links der Straße, ersetzt durch 0,5-m-Grasbüschel;
  Modern wirkt dort kahl gegen Arcade.
- Beleg (gemessen): Sonde `m1/QA-BILD/probe/drops.gd` an T2 nach 2 s: in den Stücken 63–70 (−205 … +560 m) 35
  Requisiten als „corridor“ weggelassen, 47 gesetzt; `details/crop_t2_left.jpg`, `crop_t2_far.jpg`.
- Abhilfe: Entscheidung der Leitung (A-3 sieht sie für Zwischenstand 2 vor): Korridor aus der echten Sehne statt der
  stärksten Krümmung rechnen und/oder weggelassene Bäume quer nach außen hinter den Korridor versetzen statt durch
  Büschel zu ersetzen; danach `modern_sight.gd -- --full`.

### B9 mittel – Spielerautos sehen anders aus als ihr Sprite
- Limousine: steile Heckscheibe mit sichtbarem Innenraum statt Arcades Fließheck – wirkt wie ein anderes Auto
  (`details/crop_s1_car01.jpg`); Kompakt mit schwarzem Dach (T3/T4). Lackfarbe dagegen gut (Kofferraum mittags
  Farbton −2,3 … −2,7°, Helligkeit +1 … +3 %, gemessen). Abhilfe: AS1R-Nacharbeit gegen die Sprite-Silhouette.

### B10 mittel – Leistungsbudgets nur kopflos belegt; GL-Pfad und Einzelspitzen
- Wo: `tests/race3d/check_modern_stage.gd` (`kern_zeit`, `renderer_zeit`), `check_vehicles` (`leistung`) – alle
  kopflos; `ChunkStreamer` (Einhängen), `layers/vehicles.gd`.
- Was (gemessen unter Xvfb, ganze Etappe Kiel–Hamburg, Last 4–14): `render()` im Mittel 2,10 / 1,92 / 2,23–2,67 ms
  (Niedrig / Mittel / Hoch; Budgets 1,2 / 1,5 / 2,0), Median 1,6 ms; Stück-Einhängen bis 9,5 / 20,4 ms (Budget 3; kopflos
  4,8–5,1 ms); Einzelbilder mit 45–479 ms `render()` in 7 von 11 Fahrten an wechselnden Stellen, meist in der
  Fahrzeug-Ebene, ohne Bau/Rückschnitt im selben Bild – wahrscheinlich Rechenzeitentzug der VM, aber nicht bewiesen.
  Laden 15–37 s (RINT-B 5,2–5,6 s), davon 12–28 s Aufwärmen.
- Beleg: Tabelle in Abschnitt 5, `pruefungen/kh_*`, `spikes_*`.
- Abhilfe: Budget-Prüfungen zusätzlich unter Xvfb mit Referenzuhr (perf_clock) laufen lassen; die Zeitstempel je Haken
  (wie `probe/qa_spikes.gd`) in `perf_stats` aufnehmen, damit der Leistungstest des Decks zeigt, welche Ebene eine
  Spitze trägt; auf einer ruhigen Maschine die 45–479-ms-Bilder nachstellen.

### B11 mittel – Pflicht-Render-Prüfungen aus §4.9.2 fehlen noch
- „Objekt an der Sichtgrenze unter 3 % Kontrast“ (F4/F5), „mittlere Helligkeit und kein schwarzes/NaN-Bild je Wetter ×
  Stunde“ und „OpenGL ES = OpenGL“ gibt es nicht als Prüfung. Die ES-Gleichheit habe ich von Hand gemessen (max 2/255,
  PSNR 71,8 / 88,0 dB – bestanden); die Kontrastprüfung ist wegen B7 wichtig. Aufgabe für QA1 (Welle 2).

### B12 niedrig – Kleinigkeiten
- Blattkarten-Kronen mit gezackten Kanten (Alpha-Schnitt ohne Glättung) – `details/crop_s3_tree.jpg`.
- Fernes Straßenstück jenseits einer Kuppe in reiner Nebelfarbe mit Dither-Punkten der ausblendenden Bäume
  (`details/crop_t2_rock.jpg`).
- N1: Fernboden-Bahn unter dem Horizont 75/82/94 gegen Arcades 37–40 – wirkt wie eine Nebelbank
  (`details/crop_n1_horizon.jpg`).
- Fahrbahn: vergossene Fuge neben der Spurlinie als lange dunkle Linie (wie ein Riss), Flicken als harte dunkle
  Rechtecke, nahe Randlinie weich/fleckig (`details/crop_t1_traffic.jpg`, `crop_s1_edge.jpg`, `crop_s1_car01.jpg`).
- Keine Sonnenscheibe mittags (Designentscheidung, bekannt).
- Lkw-Heck nachts im eigenen Abblendlicht fast weiß überstrahlt (30 m, `pruefungen/save/occlusion_lkw.png`); bei
  40–60 m liest sich das Konturband gut (`details/crop_s2h22_truck.jpg`).
- Blick in die Kurve schiebt an T3 ein Winkelschild unter den Tacho (`ab_mittel/T3_ab_01.jpg`).

## 2. Bild: Modern gegen Arcade im selben Simulationszustand

Methode: `tools/ab_shot.sh`-Logik mit eigenem Aufruf (`m1/QA-BILD/tools/abf.sh`): beide Modi mit `--gfx-sync`, festen 60
Bildern/s, gleichem Seed, Aufnahmen nach 2 s und 6 s. Modern lief ebenfalls mit `--shot-fast` und 1,0 s Vorlauf –
geprüft an S2: Bild 00 pixelgleich zum Lauf ohne `--shot-fast`, Bild 01 3 Pixel verschieden (höchstens 15/255), M1 hat
keine Partikel. Voreinstellung „Mittel“ (die Empfehlung für einen Windows-PC mit brauchbarer Grafik), dazu Niedrig,
Hoch, Steam Deck (1280 × 800) und OpenGL ES. Bilder: `ab_mittel/<Position>_ab_00|01.jpg`, `ab_varianten/`,
Ausschnitte in `details/`.

### 2.1 Urteil je Position (Mittel)

| Pos. | Modern gegen Arcade | Bild |
|---|---|---|
| S1 km 2, 12 Uhr | gleichwertig bis leicht besser: Felder mit Struktur, echte Schatten, Windräder mit Rotoren, Leitplanken aus Blech. Schwächer: keine Sonnenscheibe, Spielerlimousine wirkt wie ein anderes Auto (steile Heckscheibe mit sichtbarem Innenraum statt Fließheck), ferne Bäume rechts hinter der Kurve als graublaue „Geisterbäume“ | `S1_ab_00/01`, `details/crop_s1_car01`, `crop_s1_far` |
| S2 Tankspur | **schlechter**: kein Tankstellendach mit „TANKSTELLE“, keine Insel/Bordstein, keine gelbe Linie; Zapfsäulen stehen im Gras. Nachts (22 Uhr) liest sich die Tankstelle kaum (kein beleuchtetes Dach, dunkler Vorplatz) | `S2_ab_00`, `ab_varianten/S2H22_ab_00` |
| S3 km 60 | gleichwertig, Gelände und Schatten besser; Eiche aus Blattkarten mit gezackter, rauschender Krone (Alpha-Schnitt ohne Glättung) | `S3_ab_00`, `crop_s3_tree` |
| S4 km 80 Köhlbrandbrücke | **schlechter**: keine Brückengeländer, dunkles Wasser beidseits – liest sich als Damm. Elbphilharmonie und Michel (in Arcade bei 6 s am Horizont) **fehlen ganz** | `S4_ab_00/01`, `crop_s4_landmarks` |
| S5 Ziel | **schlechter**: Zielbrücke „ZIEL“ fehlt, nur das Schachbrett auf der Fahrbahn | `S5_ab_00` |
| T1 Kassel–Würzburg 46,5 | gleichwertig: Relief gibt Tiefe; links nahe der Straße fehlen Bäume (Sichtkorridor, B8) | `T1_ab_00/01` |
| T2 Kuppe 61,9 | gemischt: Land statt Arcades heller Nebelbahn am Horizont (besser); links fehlen Bäume und ein Findling (35 Requisiten im Korridor weggelassen), dahinter ein fernes Straßenstück in reiner Nebelfarbe mit Dither-Punkten | `T2_ab_00/01`, `crop_t2_left`, `crop_t2_far`, `crop_t2_rock` |
| T3 / T4 Saragossa–Pau | gleichwertig: Blick in die Kurve sauber (Spielerauto 100–110 px aus der Mitte, innerhalb D12), Täler mit Tiefe; Felsen/Findlinge fehlen (bekannt) | `T3_ab_*`, `T4_ab_*` |
| C1 Frankfurt 19:30 | gleichwertig: Stadthäuser, Laternenschein, Ersatzbilder (Sportwagen, Stadtbäume) wie Arcade; Zielbrücke voraus fehlt | `C1_ab_*`, `crop_c1_far` |
| N1 22 Uhr Schnee | **schlechter**: kein Schneefall; Fernboden unter dem Horizont als helle Bahn (75/82/94 gegen Arcade 37–40); Kompakt heller und gesättigter als sein Sprite | `N1_ab_*`, `crop_n1_horizon` |
| N2 Regen | **schlechter**: kein Regen, keine Gischt; nasse Fahrbahn vorhanden | `N2_ab_*` |
| U1 Gotthard | **kaputt**: keine Röhre – offenes grünes Gelände unter schwarzem Himmel, HUD sagt „TUNNEL“ | `U1_ab_00/01` |
| DEV 21 Uhr | **kaputt** im Tunnelteil (wie U1, Portal und Hügel fehlen); Spielerlimousine mit zwei weißen Glanzflecken (Mond) auf Dach und Kofferraum | `DEV_ab_*`, `crop_dev_car` |

Tageszeiten an S1: 6 Uhr und 19:30 gleichwertig (Kegel, Himmel, Lack), 22 Uhr gut lesbar, aber Glanzfleck auf dem Dach
(Fahrzeugausschnitt p95-Leuchtdichte 112 gegen Arcade 50; gemessen) und Abblendlicht auf der Fahrbahn +18 % (112 gegen 95,
Ausschnitt 560–700 × 360–440; gemessen). Lack mittags (Kofferraum, Bereich 590–710 × 600–625): Farbton −2,3 … −2,7°,
Helligkeit +1 … +3 % gegen das Cycles-Sprite – innerhalb 10 % (gemessen, S1 und S3).

### 2.2 Voreinstellungen, Deck, OpenGL ES, Rückfall

- Niedrig (75 % 3D-Auflösung, keine Schattenwerfer): sichtbar weicher, weniger Büsche – nicht besser als Arcade, aber
  auf Software-Grafik ohnehin nicht empfohlen. Hoch ≈ Mittel im Standbild. `ab_varianten/S1_low_ab_*`, `S1_high_ab_*`,
  `details/crop_presets_car`.
- Steam Deck 1280 × 800, Voreinstellung „Steam Deck“: Modern füllt 16:10, HUD in den Ecken, Arcade mit Balken – in
  Ordnung (`ab_varianten/S1_deck_ab_01`).
- OpenGL ES (`--rendering-driver opengl3_es`) gegen OpenGL an S1 Mittel: größte Abweichung 2/255, PSNR 71,8 / 88,0 dB –
  innerhalb der Toleranz von D38 (gemessen). ANGLE selbst ist hier nicht prüfbar (abgeleitet).
- Rückfall (`--gfx-debug=fail`): Arcade-Bild mit der Meldung „Der Modus „Modern“ lässt sich mit dieser Grafik nicht
  starten …“ (`details/rueckfall_fail_00.png`) – in Ordnung.

## 3. Fairness

### 3.1 Volle Läufe (gemessen, 17:44, Last 10–11)

`godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` (161 s) und `modern_path_check.gd -- --full`
(62 s), Protokolle `pruefungen/sight_full.log`, `pruefungen/path_full.log`:

| Regel | Grenze (Vertrag D14, A-3) | gemessen | Reserve |
|---|---|---|---|
| F1 Kamera Mitte | 0 Fälle bis 270 m | 0 bis 270 m, erster Fall 280 m (99.424.500 Stichproben) | 10 m |
| F1 Außenspuren | 0 Fälle bis 260 m | 0 bis 260 m, erster Fall 270 m (326.680.500) | 10 m |
| F2 | ≤ 0,60 | 0,593 trocken, 0,596 Regen, 0,555 Schnee | 0,004 bei Regen |
| F3 | 0 später und im Anhalteweg | 0 von 5.923 (Fahrzeug und Schild); Fahrzeuge Arcade p50 510 m, Modern 534 m; Schilder 612 / 642 m | – |
| F7 | 0 Verstöße | 0 von 2.011.532 Querschnittsseiten | – |
| Modell | 0 Abweichungen | 0 von 394.011, Augpunkt höchstens 0,0002 px | – |
| Pfad | Abstand ≥ 250 m, Schleifen ≥ 2.000 m | 267,6 m (Bukarest–Sibiu km 57,8), Schleifen ab 2.064 m | 17,6 m / 64 m |

Alle Werte stimmen mit dem Vertrag und `docs/renderer-modern.md` §7.3 überein; die Grenzen sind im Code unverändert
(`F1_LIMIT_M` 270, `F1_LANES_LIMIT_M` 260, `F2_RATIO` 0,60). Die Reserven sind dünn: F2 bei Regen 0,004, F1 10 m – jede
Änderung an Kamera, Gelände oder Generator braucht den vollen Lauf (wie §7.6 sagt).

### 3.2 Was die Rechnungen nicht abdecken (eigene Beobachtung)

- **Nebel über der Ausblendung (F4/F5)**: Fahrzeuge (`vpbr`), Schilder (`sign`) und alle Requisiten (`baked`,
  `leaves`, `billboard`) bekommen den vollen Tiefennebel der Engine (Anteil t, linear 0,45 … 1,0 × Sichtweite) und
  Fahrzeuge/Schilder zusätzlich Arcades Ausblendung 1 − t² als Dither. Arcade färbt Sprites dagegen nur
  **multiplikativ** um (`RoadRenderer._modulate`, eingefroren: Modulationsfarbe = (1 − 0,7 t) × Licht + 0,7 t × 1,25 ×
  Nebelfarbe – ein dunkler Wagen bleibt dunkel) und blendet sie mit derselben Ausblendung in den Hintergrund. Der
  Kontrast eines Wagens gegen den Hintergrund ist damit in Modern etwa (1 − t)-mal so groß wie in Arcade: bei
  0,839 × Sichtweite (dort zählt die Simulation ihn als gesehen, t = 0,707) rund 30 %, bei 0,725 × Sichtweite rund
  50 % (abgeleitet aus den Mischformeln, nicht gemessen). Gelände und Fernboden haben seit RINT-B
  Arcades Gesetz (`FOG` mit 0,7 × t in `terrain.gdshader`), Requisiten und Fahrzeuge nicht: deshalb stehen ferne Bäume
  als graublaue „Geisterbäume“ auf grünen Feldern (mit `--gfx-debug=cover` ohne Nebel sind es grüne Bäume –
  `details/crop_s1_far_nofog.jpg`, gemessen 129/137/145 gegen Arcade 26/37/19 an derselben Bildstelle).
  Die Pflicht-Render-Prüfung „Objekt an der Sichtgrenze unter 3 % Kontrast“ aus §4.9.2 gibt es noch nicht.
- **Verdeckung durch Requisiten/Bauten** prüft keine Rechnung (bekannt, §7.4).
- **F3 nur trocken bei Tag** (wie die Studie).
- **Schild unter dem Tacho**: an T3 (6 s) schiebt der Blick in die Kurve das Winkelschild der Außenseite unter den
  Tacho (`ab_mittel/T3_ab_01.jpg`); es war vorher lange sichtbar (F1) – nur eine Beobachtung.

## 4. Bewegung (Clips, 60 Bilder/s fest, Autopilot)

Aufnahmen mit dem Movie Maker (`--write-movie … --fixed-fps 60`, `--no-watchdog`, ohne `--gfx-sync`, d. h. mit
Arbeiter-Threads wie beim Spieler), Arcade und Modern aus demselben Startzustand, nebeneinander geschnitten ab dem
ersten Rennbild (Modern zeigt 15 Bilder lang das Ladebild):

| Clip | Inhalt | Datei |
|---|---|---|
| S1 Kiel–Hamburg ab km 2, 12 Uhr, Modern „Hoch“ | 13 s Autobahn, Überholen, Kurve mit Winkeln, Windräder | `clips/s1_ab_arcade_modern_hoch.mp4`, nur Modern 18 s: `clips/s1_modern_hoch_60fps.mp4` |
| T4 Saragossa–Pau km 198,8, 11 Uhr, „Mittel“ | 9,5 s enge Kurve (R ≈ 136 m), Blick in die Kurve, Schild „Tankstelle 5 km“ | `clips/t4_ab_arcade_modern_mittel.mp4` |
| N1 Hamburg–Hannover km 71, 22 Uhr, Schnee, „Mittel“ | Nacht, Abblendlicht, Rücklichter | `clips/n1_ab_arcade_modern_mittel.mp4` |

Einzelbilder (gemessen am Clip, `m1/QA-BILD/tools/seq.py`):
- Ferne Fahrbahn S1 (Bilder 300–307, 3-fach vergrößert): Striche und Randlinien laufen ruhig, kein Flimmern, keine
  Treppen; mittlere Bildänderung im fernen Band (Zeilen 290–360) von Bild zu Bild 4,1 (Median) / 8,3 (Maximum, beim
  Ausblenden von „LOS!“) – keine Ausreißer, die ein Aufpoppen anzeigen würden.
- Detailstufen: Gelber Sportwagen (Ersatzbild) 180–240, blauer Kombi (Modell) 860–926 beim Zurückfallen, Eichen
  334–344: kein sichtbarer Sprung.
- T4 (Bilder 150–300 in 30er-Schritten): Gelände ohne Löcher und Nähte, Talboden schließt; die Innenseite der Kurve ist
  bis auf Grasbüschel leer (Sichtkorridor, B8).
- Sichtbar in Bewegung: die graublauen „Geisterbäume“ am Horizont (B7) stehen in jedem Bild als blasse Flecken über
  den Feldern.
- Kosten der Aufnahme unter llvmpipe (Last 8–11, 2 Rasterthreads, „GPU render time“ des Movie Makers): S1 Arcade
  132 ms je Bild, Modern „Hoch“ 1.317 ms (10 ×); T4 Arcade 103 ms, Modern „Mittel“ 681 ms (6,6 ×) – gemessen, aber nur
  Software-Rasterung; über echte GPUs sagt das Verhältnis wenig (abgeleitet).

## 5. Leistung

### 5.1 Methode

Sonde `m1/QA-BILD/probe/qa_drive.gd` unter Xvfb (llvmpipe mit 2 Rasterthreads, `nice -n 10`, Last der VM 4–14 durch
andere Aufträge): Kiel–Hamburg ab km 0 mit dem Autopiloten (12 Uhr, Limousine, Seed 11, Tankstopp bei km 13,9). Je Bild:
Wanduhr-Bildzeit, GDScript-Zeit von `render()` (Differenz von `ModernRenderer._render_us`), ob ein Stück eingehängt wurde;
alle 5 s Speicher und Zähler; am Ende `perf_stats()`. Damit die Läufe fertig werden, lief die Simulation mit
`--timescale=2` – die Sitzung erlaubt dann 8 Physikschritte je Bild, jedes Bild bewegt die Welt also um bis zu 0,13 s
(8 × ein 60-Hz-Bild): die GDScript-Zeiten je Bild sind eher zu hoch, Bildzeiten unter llvmpipe sagen nichts über echte
Grafikkarten. „Hoch“ dauerte so 1 s je Bild: ganz nur km 0–33,7 (Abbruch aus Zeitgründen), dazu km 78–95 (City Limits)
als eigener Lauf. Zusätzlich `probe/qa_spikes.gd`: misst jede Ebene/jeden Builder mit `update()` einzeln über
Stellvertreter in `_updaters` (keine Datei des Spiels geändert).

### 5.2 Ergebnisse (gemessen)

| Kiel–Hamburg, 12 Uhr | Niedrig (ganz) | Mittel (ganz) | Hoch km 0–33,7 | Hoch km 78–95 (Stadt) | Arcade (ganz) |
|---|---|---|---|---|---|
| Laden bis zur ersten Rennszene | 15,1 s | 32,1 s | 37,5 s | 33,1 s | 0,65 s |
| davon Vorbereitung / Aufwärmen / Selbsttest | 14,0 / 12,1 / 0,72 s | 29,8 / 27,4 / 1,19 s | – | 30,5 / 28,0 / 1,39 s | – |
| Renderer-GDScript je Bild, Mittel (Budget §4.10) | 2,10 ms (1,2) | 1,92 ms (1,5) | 2,23 ms (2,0) | 2,67 ms (2,0) | `_draw` 8,96 ms |
| dto. p50 / p95 / p99 / max | 1,60 / 4,40 / 8,9 / 166 | 1,59 / 3,66 / 6,8 / 93 | 1,55 / 5,58 / 10,1 / 61 | 1,68 / 3,96 / 9,3 / 479 | p95 16,8, max 118 |
| Bilder mit Stück-Einhängen: p50 / p95 / max | 2,55 / 5,9 / 13,3 ms | 2,61 / 6,5 / 21,9 ms | 2,58 / 5,5 / 10,7 ms | 2,77 / 8,2 / 8,7 ms | – |
| `chunk_commit_ms_max` der Fahrt (Budget) | 9,5 ms (3) | 20,4 ms (3) | 3,3 ms (4) | 0,9 ms (4); beim Laden 54 ms | – |
| Zeichenaufrufe sichtbarer Durchgang Median / max (Budget inkl. Schatten) | 118 / 145 (400) | 135 / 162 (900) | 154 / 170 (1.500) | 171 / 183 (1.500) | – |
| Dreiecke Median / max (Budget) | 92 k / 128 k (250 k) | 99 k / 148 k (700 k) | 103 k / 132 k (1,5 M) | 119 k / 136 k (1,5 M) | – |
| Texturspeicher max | 155 MB | 174 MB | 188 MB | 187 MB | 207 MB |
| Prozess-RSS max | 937 MB | 981 MB | 1.012 MB | 1.058 MB | 578 MB |
| Bildzeit p50 unter llvmpipe (nur Software) | 223 ms | 670 ms | 1.032 ms | 1.232 ms | 148 ms |
| `ERGEBNIS` gegen Arcade | 28 Schlüssel, nur `gfx` anders | 28, nur `gfx` | – | – | – |

Den Schattendurchgang meldet der Compatibility-Renderer mit 0 Aufrufen; die Zeichenaufrufe oben sind nur der sichtbare
Durchgang. Sie und die Dreiecke liegen weit unter den Budgets. Der Renderer braucht in GDScript ein Viertel bis ein
Drittel von Arcades `_draw` (8,96 ms) – der Rückgewinn, den der Vertrag erwartet. Texturspeicher Modern unter Arcade
(wie RINT-B), RSS +400 MB (llvmpipe hält Texturen und Programme im Hauptspeicher; auf dem Deck geteilt, abgeleitet).

### 5.3 Spitzen

- Stück-Einhängen: unter Xvfb (echter GL-Pfad, Puffer werden synchron hochgeladen) bis 20,4 ms, kopflos in denselben
  Strecken 4,8–5,1 ms (`qa_spikes`, Last 10, `nice 19`); RINT-B prüft das Budget 3 ms nur kopflos und normiert
  (0,42–0,78 ms). Auf der Bildzeit von llvmpipe fallen Einhänge-Bilder nicht auf (p50 640 gegen 671 ms bei Mittel).
- Einzelbilder mit 45–479 ms `render()`: in 7 von 11 Fahrten (Xvfb und kopflos) je 1–2, an wechselnden Stellen
  (km 0,1 / 13,9 Tankstopp / 27,4 / 73,0 / 80,4 / 91,3 / 91,7 / 93,3 / 95,1 Ziel), meist in `vehicles.gd` (die eigene
  Uhr der Fahrzeug-Ebene zeigte 55, 92, 132, 169 und 474 ms), nie auf einem Einhänge-Bild, nie mit einem neuen Set, Bau oder Budget-Rückschnitt im
  selben Bild (`qa_spikes`: Bauten +0, Rückschnitte +0). An derselben Stelle nicht wiederholbar (Start ab km 85: keine
  Spitze). Wahrscheinlichste Ursache: der Prozess bekam bei Last 10–14 und `nice 10/19` zeitweise kaum Rechenzeit –
  eine Code-Ursache ist damit nicht ausgeschlossen. Am Tankstopp (km 13,9) 30–61 ms in 2 von 5 Fahrten.
- GL-Pfad gegen kopflos, Leistungstest-Szene „Stadt bei Nacht im Regen“ (Dortmund–Frankfurt km 216, 22 Uhr, Regen):
  kopflos `render()` im Mittel 1,14 ms (max 12,4), unter Xvfb mit „Mittel“ 1,80 ms (max 4,5); je Haken unter Xvfb
  Fahrzeuge 0,59, Lichter 0,27, Lichtpunkte 0,17, Gelände 0,15, Hintergrund 0,10 ms, Rest (Umgebung, Streamer, Kamera)
  ≈ 0,4 ms (`pruefungen/spikes_city_night*.log`). Der GL-Pfad kostet hier also ≈ +0,65 ms. QA-SYSTEMs Leistungstest
  maß in derselben Szene 7,10 ms (`script_ms` = `render_ms_avg` des Fensters, Voreinstellung Niedrig, Last 13) – das
  konnte ich nicht nachstellen; auf einer ruhigen Maschine nachmessen, bevor man es dem Deck-Ergebnis gegenüberstellt.
  Die Budget-Prüfungen (`kern_zeit`, `renderer_zeit`, `leistung`) laufen alle kopflos.

### 5.4 Speicher über 20 Minuten Fahrt

Lüttich–Paris ganz (395 km der Etappe, 16,2 min Spielzeit – die Etappe war vor den geplanten 20 min zu Ende),
Voreinstellung Mittel, `--timescale=32` (64 Physikschritte je Bild), 356 eingehängte Stücke, Proben alle 10 s
(`pruefungen/mem_modern_medium_samples.jsonl`, gemessen):

| Spielzeit | km | RSS | Skript-/Engine-Heap | Objekte | Knoten | Waisen | Texturen | Video gesamt |
|---|---|---|---|---|---|---|---|---|
| 1 s | 0 | 913 MB | 96,8 MB | 3.682 | 265 | 0 | 137,7 MB | 149,6 MB |
| 211 s | 94 | 937 MB | 102,9 MB | 3.925 | 348 | 0 | 142,0 MB | 152,8 MB |
| 483 s | 211 | 939 MB | 103,7 MB | 3.946 | 332 | 0 | 142,8 MB | 153,2 MB |
| 793 s | 355 | 937 MB | 103,9 MB | 3.938 | 311 | 0 | 142,8 MB | 153,2 MB |
| 971 s (Ziel Paris) | 395 | 939 MB | 100,4 MB | 3.210 | 414 | 0 | 143,8 MB | 154,8 MB |

Nach dem Anlaufen (erste 100 s) steht alles: kein Wachstum bei Speicher, Objekten, Ressourcen (262 konstant), keine
verwaisten Knoten, Texturspeicher +6 MB über die ganze Fahrt (neue Schilder/Ersatzbilder der Stadt), Stücke 9–14,
Fahrzeug-Instanzen am Budget (≤ 128). **Kein Hinweis auf ein Leck.** QA-SYSTEM fand bei 20 min Echtzeit im Rennen
Kiel–Nürnberg dasselbe (RSS +4 %). Bei 64 Physikschritten je Bild gab es wieder Einzelspitzen von 55–178 ms `render()`,
diesmal nicht in der Fahrzeug-Ebene (deren Uhr blieb unter 9 ms) – vermutlich der Pfad-/Streckenaufbau bei 60 m Weg je
Bild; für echte Bildraten nicht aussagekräftig.

### 5.5 Was echte Hardware braucht (abgeleitet)

- **CPU**: Renderer-GDScript hier 1,6 ms Median / 2–2,7 ms Mittel unter Last; das Steam Deck ist laut Vertrag ≈ 1,5 ×
  langsamer als diese VM ohne Last → etwa 1,5–3 ms Renderer, dazu Simulation ≈ 0,5–1 ms, HUD/Sitzung ≈ 1,5 ms und die
  Übergabe von 150–250 Zeichenaufrufen inkl. Schatten (≈ 1 ms) – zusammen etwa 5–7 ms je Bild: für 60 Bilder/s reicht
  es, sofern QA-SYSTEMs 7,1 ms in der Stadt-Nacht-Szene ein Lastartefakt sind (meine Messung dort: 1,8 ms).
- **GPU**: unbekannt. Unter llvmpipe kostet Modern 6–10 × Arcades Rasterzeit (Mittel 681–746, Hoch 1.317 ms gegen
  Arcade 103–132 ms je Bild), getrieben von Pixel-Shadern (Fahrbahn mit vielen Rauschstufen, Gelände, Blattkarten mit
  Alpha-Schnitt, Schatten mit 2–4 Kaskaden, MSAA). Grobe Schätzung: Steam Deck mit „Steam Deck“-Voreinstellung bei
  1280 × 800 etwa 8–14 ms GPU je Bild – 60 Bilder/s knapp, 40/45 Bilder/s sicher; ein Mittelklasse-PC (GTX-1060-Klasse)
  bei 1080p „Mittel“ etwa 4–7 ms. Erst der Leistungstest des Nutzers (Gate 1) misst das.
- **Laden**: hier 15–37 s, fast alles Aufwärmen (8 Bilder in vier Lichtsituationen mit 49 Aufwärm-Knoten); auf einer
  echten GPU sind das Millisekunden je Bild plus die Übersetzung der Shader beim ersten Start – geschätzt 3–8 s beim
  ersten Mal, 1–3 s danach. RINT-Bs 5,2–5,6 s ließen sich hier nicht nachstellen (Last, 2 statt 4 Rasterthreads).

## 6. Geprüft und in Ordnung

- Gleicher Simulationszustand in beiden Modi an allen 14 Positionen (HUD-Zeit, km, Tempo, Tank identisch) – das
  A/B-Werkzeug zeigt wirklich dieselbe Lage.
- `--shot-fast` mit 1,0 s Vorlauf liefert für Modern dieselben Bilder wie ohne (S2: 0 bzw. 3 Pixel verschieden).
- Kamera: Fahrbahn, Linien und Fahrzeuge liegen an Arcades Stellen auf Geraden; Blick in die Kurve ruhig, Spielerauto
  höchstens ≈ 110 px aus der Mitte (T3/T4, innerhalb D12).
- Verkehr: Modelle (Limousine, Schrägheck, Kombi) sitzen auf der Fahrbahn, Räder am Boden, LOD0 nahe der
  Kamera scharf (besser als Arcades vergrößerte Sprites, `details/crop_s4_cars.jpg`); Ersatzbilder (Kombi, Sportwagen,
  Gran Turismo als Spieler; Sportwagen, Lieferwagen, Bus im Verkehr; Stadtbäume) sehen aus wie in Arcade.
- Schilder lesbar, gleiche Größe und Lage wie Arcade, Pfosten stehen im Boden (`details/crop_s1_sign.jpg`, T4
  „Tankstelle 5 km“).
- Tageszeiten 6 Uhr und 19:30 gleichwertig, 22 Uhr lesbar mit Abblendlicht und Rücklichtschein; Laternenschein in C1.
- Lack mittags innerhalb 10 % gegen das Cycles-Sprite (gemessen, S1 und S3).
- Steam Deck 1280 × 800: Modern füllt 16:10, HUD in den Ecken.
- OpenGL ES gegen OpenGL: max. 2/255, PSNR 71,8 / 88,0 dB.
- Rückfall: `--gfx-debug=fail` → Arcade mit der Meldung im HUD.
- Bewegung (Clip S1 „Hoch“, 60 Bilder/s fest, Einzelbilder 180–240, 300–307, 334–344, 860–926): keine flimmernden
  Linien oder Striche, keine sichtbaren Sprünge beim Wechsel der Detailstufen von Bäumen und Autos, keine Löcher im
  Gelände; mit `--gfx-debug=cover` kein Magenta unter dem Horizont an S1.
- Fairness F1–F3, F7 und Pfad: alle Grenzen eingehalten, Zahlen wie im Vertrag (Abschnitt 3).
- Logs aller Läufe (A/B, Clips, Fahrten, Prüfungen): keine „Too many instances“-Ablehnung, kein SCRIPT/SHADER ERROR.
  „ObjectDB instances were leaked at exit“ nur nach hartem Ende (`--quit-after`, Ende der Aufnahmen) und in Arcade und
  Modern gleich (25/25, 3/3) – nichts Modern-Eigenes.
- `ERGEBNIS` der ganzen Etappe Kiel–Hamburg unter Xvfb: Niedrig und Mittel gegen Arcade 28 Schlüssel, nur `gfx` anders.
- Render-Prüfungen der Bildlinse grün (Abschnitt 7), Arcade-Golden 20 von 20.

## 7. Tore (am Kopf 9b6adbc)

| Tor | Ergebnis | Beleg |
|---|---|---|
| Arcade-Identität `tools/golden.sh check` (einmal, zum Schluss, 20:13) | **20 von 20 identisch** | `pruefungen/golden.log` |
| Fairness `modern_sight.gd -- --full`, `modern_path_check.gd -- --full` | alle CHECK OK (Abschnitt 3) | `pruefungen/sight_full.log`, `path_full.log` |
| `ERGEBNIS` Arcade gegen Modern, ganze Etappe Kiel–Hamburg unter Xvfb (Niedrig, Mittel) | 28 Schlüssel, nur `gfx` verschieden | `pruefungen/kh_*.log` |
| Render-Prüfungen der Bildlinse | alle OK: `check_terrain_cover` (T1–T4, S1, C1: 0,000 % Magenta), `check_road_parity` (Gerade 0,22 px, R 400 m 7,09 px, R 136 m 13,27 px, 16:10/21:9 gefüllt), `check_light_base` (Asphalt −6,6 %, Gras −1,8 %, Himmel −4,8 %; Schatten Aus/Mittel −0,10 %), `check_vehicle_lights` (Blinker 300 m Kern 4 × 4 / 3 × 2 px, Rücklicht N1 bei 283 m +0,137 Leuchtdichte, Bremse 50/150/300 m Rot +0,76/+0,16/+0,67), `check_occlusion` (Kuppe und Lkw 0 Pixel), `check_vehicle_standin` (alle Ersatzbilder 0–2 px und ±5 % gegen Arcade) | `pruefungen/render_*.log`, `pruefungen/*.save.log`, Bilder `pruefungen/save/` |
| `tools/run_tests.sh` | nicht selbst gelaufen (Zeit): QA-SYSTEM am selben Kopf – Einheitstests 692/0, aber der Haken der Modern-Prüfungen lief nicht, `check_facade` scheitert dort unter Last (QS-01/02) | `deliver/QA-SYSTEM/bericht.md` |
| Pflicht-Render-Prüfungen §4.9.2, die es noch nicht gibt | „Objekt an der Sichtgrenze < 3 % Kontrast“ (F4/F5), „mittlere Helligkeit / kein schwarzes Bild je Wetter × Stunde“, „OpenGL ES = OpenGL“ (hier von Hand: max 2/255, PSNR 71,8 dB – bestanden) | – |

## 8. Dateien und Werkzeuge

Abgabeordner `<scratch>/v080/deliver/QA-BILD/`:
- `ab_mittel/` – A/B-Bögen aller Referenzpositionen S1–S5, T1–T4, C1, N1, N2, U1, DEV bei 2 s und 6 s, Voreinstellung Mittel
- `ab_varianten/` – S1 um 6 Uhr, 19:30, 22 Uhr; S2 um 22 Uhr; S1 mit Niedrig, Hoch und Steam Deck (1280 × 800)
- `details/` – vergrößerte Ausschnitte zu den Befunden (`crop_*.jpg`), Rückfallbild
- `clips/` – `s1_ab_arcade_modern_hoch.mp4`, `t4_ab_arcade_modern_mittel.mp4`, `n1_ab_arcade_modern_mittel.mp4`
  (nebeneinander, gleicher Simulationszustand), `s1_modern_hoch_60fps.mp4`
- `pruefungen/` – Protokolle: Fairness (`sight_full.log`, `path_full.log`), Leistungsfahrten (`kh_*`, `mem_*`),
  Golden, Render-Prüfungen, gespeicherte Prüfbilder

Werkzeuge (Arbeitsordner `<scratch>/v080/m1/QA-BILD/`, nicht im Repository):
- `tools/ab.sh <ordner> <voreinstellung> <Position …> [-- Argumente]` und `tools/abf.sh` – A/B wie `tools/ab_shot.sh`,
  Modern mit `--shot-fast` und 1 s Vorlauf (an S2 gegen den vollen Lauf geprüft); Positionen S1–S5, T1–T4, C1, N1,
  N2, U1, DEV und Varianten
- `tools/clip.sh`, `tools/abclip.py` – Movie-Maker-Clips mit 60 Bildern/s und A/B-Schnitt
- `tools/crop.py`, `tools/seq.py` – Ausschnitte und Bildfolgen aus Clips
- `probe/qa_drive.gd` + `tools/drive.sh` – ganze Etappe mit Bild-für-Bild-Zeiten, Speicherproben, `perf_stats`
- `probe/qa_spikes.gd` – Zeit jeder Ebene/jedes Builders (`update()`), Stellvertreter in `_updaters`
- `probe/drops.gd` – weggelassene Requisiten je Stück (`props.gd` → `debug()`)
- `tools/perfsum.py` – Auswertung der Fahrten

Vorsicht beim Nachstellen: `race_session.gd` setzt bei `--timescale` selbst `max_physics_steps_per_frame =
clamp(ceil(ts) × 2, 8, 128)` – ein eigenes `--max-steps` der Sonde wird überschrieben.

## 9. Abweichungen, Vertragsfragen, Hinweise für die Nächsten

Abweichungen von meinem Auftrag
- „Hoch“ nicht als eine ganze Fahrt: bei 1 s je Bild hätte sie 37 min gedauert; gefahren km 0–33,7 und km 78–95.
- Speicherfahrt 16,2 statt 20 min Spielzeit (Lüttich–Paris war zu Ende); dazu QA-SYSTEMs 20-min-Lauf (RSS +4 %).
- `tools/run_tests.sh` nicht selbst gelaufen (Zeit; QA-SYSTEM am selben Kopf); `golden.sh check` einmal zum Schluss.
- A/B mit eigenem Aufruf statt `tools/ab_shot.sh`: Modern mit `--shot-fast` und 1 s Vorlauf (an S2 geprüft, gleich).
- Leistungsfahrten mit `--timescale=2` (8 Physikschritte je Bild) statt Echtzeit – sonst nicht in endlicher Zeit.

Vertragsfragen (contract_issues)
- §4.10/A-6: Die Zeitbudgets (`render()` 1,2–2,0 ms, Einhängen 3–4 ms) werden nur kopflos geprüft; unter dem echten
  GL-Pfad liegen sie hier darüber (Einhängen bis 20 ms). Der Vertrag sollte sagen, ob ein Budget kopflos-normiert oder
  im GL-Pfad gilt.
- D14 F4/F5: „nie mehr Nebel als Arcade“ ist nur für statische Kulisse formuliert und als Tiefennebel 0,45–1,0 definiert;
  Arcade tönt Sprites aber nur mit 0,7 × t multiplikativ. Für Fahrzeuge/Schilder fehlt eine Regel, ob über der
  F5-Ausblendung noch Nebel liegen darf (B7).
- §4.9.2: drei Pflicht-Render-Prüfungen fehlen (B11) – wer liefert sie vor dem Gate-Build (QA1)?
- D22/Gate 1 „andere Etappen mit Platzhaltern“: Tunnel haben in M1 keinen Platzhalter (B1).

Für die Nächsten (notes_for_next)
- Vor dem Testbuild: B1 (Tunnel-Abhilfe oder Beschränkung), B5 (Mondglanz), B2 (Ersatz-Tankstellendach).
- Wahrzeichen bis Arcades Reichweite zeigen (B3b) – ohne R7 als Ersatzbild am Pfad.
- Nebelgesetz für Requisiten/Fahrzeuge vereinheitlichen und die Kontrast-Prüfung schreiben (B7, B11).
- Korridor-Entscheidung mit diesen Bildern (B8) vor Gate 2 treffen.
- Zeitstempel je Haken in `perf_stats` (B10), damit der Leistungstest des Decks Spitzen zuordnet; Einzelspitzen auf
  einer ruhigen Maschine nachstellen.
- Werkzeuge in `<scratch>/v080/m1/QA-BILD/tools` und `probe/` (Abschnitt 8) sind wiederverwendbar.
