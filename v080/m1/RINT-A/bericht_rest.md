## 4. Abweichungen

1. **Varianten je Stück** statt je Requisite (§4.6.6 nennt „segment index and prop index“): sonst kostet jede Variante
   eigene Knoten und Zeichenaufrufe (Auftrag: „variants per chunk by a stable hash“).
2. **„≤ 2 Zeichenaufrufe je Set und Stück“** gilt je Seite: AS1bs Häuser haben zwei Flächen (`baked` + Scheiben in
   `vpbr`), auf beiden Straßenseiten mit dem gespiegelten Knoten (D24) also 4 je Stück (gemessen im Unit-Test).
3. **Bodendecker** nur für weggelassene **Pflanzen** und nicht in den City Limits; Felsen und Häuser einer
   Landschaftsregel bleiben im Korridor weggelassen (Leitentscheidung offen bis Zwischenstand 2).
4. **Spiegelquelle**: der analytische Himmel (R3) statt des `Sky` der Umgebung (D7) für Lack, Glas und alles in
   `vpbr`; Fahrbahn, Gelände und Requisiten behalten den `Sky` (gemessen, §12.2 der Renderer-Doku).
5. **Rotor im Uhrzeigersinn** (Vorzeichen des Winkels negativ) statt AS1bs `+ce_time` – sonst von der Straße aus gegen
   den Uhrzeigersinn, anders als echte Anlagen.
6. **Ende der Sicht**: Fernbilder und Laub blenden zwischen 0,85 und 1,0 der Sichtweite aus (vorher reine Nebelfarbe
   vor den Silhouetten). Arcade blendet seine Sprites ähnlich aus; F4 betrifft das nicht (kein stärkerer Nebel).
7. **Lampen der Requisiten**: Gruppen teilen sich Arcades Tankstellenlicht, Wandlampen bekommen 5 m vor der Wand,
   Flugbefeuerung keinen Kegel – A-7 nennt nur `range`/`energy` je Lampe, keine Regel dafür.
8. **`scripts/audio/audio_manager.gd`** geändert (Stopp und 60 ms beim Beenden, AU-B-Hinweis), obwohl die Datei in
   diesem Schub keinem Paket gehört – der Auftrag verlangt saubere Prozessenden; nur `_exit_tree()`.
9. **`tools/run_render_checks.sh` nicht geändert**: es findet alle `tests/race3d/render/check_*.gd` selbst; neu ist
   `check_session_modern.gd` (Pause, Rückfall, Freigabe), `check_props_render.gd` hat die Prüfung `rotor` dazu.
10. **Dateien anderer Pakete für Fehler der Zusammenführung**: `flare.gdshader` (R3: volle Stärke bis zu einer halben
    Bildpunkt-Diagonale, 2.8), `props.gd warmup_nodes()` (R2: je Modell statt je Klasse, 2.8) und die Prüfungen
    `check_vehicles` `lampen_fest`, `check_models` `klassen`, `check_occlusion` `lkw`, `check_modern_stage`
    `kern_zeit` (2.7) – keine Datei aus der R3E-Liste außer der einen Zeile `vehicle_shadow`.
11. **`tools/run_tests.sh` zweimal, beide Male mit einer roten Prüfung** (1.: `lampen_fest`, 2.: `kern_zeit`, beide
    Prüfungen der Zusammenführung angepasst); ein dritter Gesamtlauf war nicht erlaubt – `check_modern_stage.gd`
    lief danach einzeln grün.

## 5. Probleme im Bauplan

1. **§4.6.6 vs. Zeichenaufruf-Budget**: Varianten je Requisite und ≤ 2 Aufrufe je Set und Stück widersprechen sich;
   mit zwei Flächen und beiden Seiten (D24) sind es 4. Vorschlag: Budget „je Set, Stück und Seite“, Varianten je
   Stück (so umgesetzt).
2. **D7 (Sky als Spiegelquelle für Lack und Glas)**: im Rennen spiegelten Sky und R3s analytischer Himmel doppelt
   (+3 … +11 Stufen am Auto); der Sky fehlt bei „Effekte: Aus“. Umgesetzt: analytisch für `vpbr`/`glass`, Sky für den
   Rest – der Bauplan sollte das so festhalten.
3. **Horizont**: Fernboden-Kragen und Leinwand unter der Horizontzeile sind laut D16/R1/R2 reine Nebelfarbe; Arcade
   zeigt bei klarem Wetter Gras bis zur Horizontzeile (gemessen an S1: Arcade Zeilen 321 ff. 91/149/61, Modern Zeilen
   324–329 197/219/237). Das ergibt einen hellen Streifen unter den Silhouetten (an T4 wie eine Wasserfläche) – mehr
   „Nebel“ als Arcade an derselben Bildstelle (Geist von F4). Braucht eine Bildentscheidung (Fernboden bei klarer
   Sicht nicht bis zur reinen Nebelfarbe).
4. **A-4 / §4.11 „leaving Modern“** hatte zwei Eigentümer im Code (GameFlow und RaceRenderers); jetzt eine Stelle
   (`RaceRenderers.leave_modern(always)`).
5. **§4.9.4 Bildzeit-Regel** bleibt lastabhängig (R1); gezählt habe ich zusätzlich die übersetzten Varianten.
6. **Prozessende-Lecks** stammen auch aus Arcade (gefroren: `EngineAudio`); behoben in `AudioManager`, nicht in der
   gefrorenen Datei.
7. **3D-Auflösung und Fahrzeuglichter**: „Niedrig“ zeichnet mit 75 % (Voreinstellung für Software-Grafik), der
   Bauplan verlangt zugleich, dass keine Stufe Fahrzeuglichter abdunkelt. Er sollte sagen, dass Lichtpunkte gegen die
   3D-Auflösung abgesichert sein müssen, und die Render-Prüfungen der Pakete liefen bisher mit der Voreinstellung der
   Maschine (llvmpipe → „Niedrig“) – R3 ohne R1 also mit 100 %. Vorschlag: Lichter-Prüfungen bei „Niedrig“ und „Hoch“.
8. **Aufwärmen „je Shader-Variante ein Knoten“** (§9 Haken, D10) reicht nicht: Treiber übersetzen auch je
   Texturformat und Vertex-Aufbau. Vorschlag: „jede Darstellung jedes geladenen Modells, so wie sie gezeichnet wird“.

## 6. Für RINT-B und die nächsten

1. **Horizontstreifen** (Problem 3): Entscheidung und kleine Shader-Änderung im Fernboden (Nebel deckeln bei klarer
   Sicht) oder Silhouetten tiefer; danach `check_terrain_cover` und A/B S1, T1, T4.
2. **Laternen nachts**: Kegel und Lichtpunkte sind da, aber der Schein am Leuchtenkopf ist schwach (Halo-Anteil 0,35
   nah); Arcade wirkt in S4 nachts stimmungsvoller – `layers/flares.gd` (`STATIC_HALO`) oder Glow abstimmen (R4).
3. **Nachtboden zu hell**: N1 Schneeboden +21 … +42 % gegen Arcade (Fahrbahn gleich), S2 nachts Gras heller – R1s
   Lichtgesetz für den Nachtboden, Nachtabgleich in R4.
4. **R3E/AS1R zusammenführen**: in `layers/vehicles.gd` habe ich nur `material("vehicle_shadow")` geändert; `vpbr`
   und `glass` tragen jetzt den Ein-Quellen-Pfad (env_energy > 0) – AS1R stimmt Glas mit `mirror` ab, das im Rennen
   nur noch die analytische Spiegelung skaliert.
5. **Vorschaubilder** der Grafikwahl (`tools/gfx_previews.sh`, UI1) erst nach R3E/AS1R neu erzeugen.
6. **Tankstelle**: `props/fuel_station` und `fuel_pump` zeichnet heute der Requisiten-Builder; das Dach über der
   Tankspur fehlt bis R6 – an S2 steht ein Pfeiler mit Platte am Rand (Teil des Modells), wirkt unfertig.
7. **F7 an T2/T4**: Bodendecker sind aus 3,4 m kaum zu sehen; Felsen/Häuser im Korridor entscheidet die Leitung mit den
   Bergbildern.
8. **`docs/renderer-modern.md` §12** beschreibt alles aus dieser Zusammenführung; ARCHITECTURE.md §15 (DOC, Welle 8):
   `RaceRenderers.leave_modern(always)`, `quality_lowered`, `gfx_lowered`.
9. **Ferne Heckleuchten bei 75 %** (R3E): mit dem Lichtpunkt sichtbar (+0,16 Rot in 150 m), aber nur ein rötlicher
   Schein, kein klarer roter Punkt wie bei 100 %; ein Leuchtenkern von einem Bildpunkt (wie beim Blinker) wäre der
   nächste Schritt. Das Aufwärmen je Modell kostet unter llvmpipe rund 10 s mehr Vorbereitung – auf dem Deck messen.
