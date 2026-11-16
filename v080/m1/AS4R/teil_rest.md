## Geänderte gemeinsame Dateien (rückwärtskompatibel, additiv)

| Datei | Änderung |
|---|---|
| `tools/blender/ce3d/catalog3d.py` | nur im Block `# --- AS4 ---`: Einträge von Pylon (aufrecht, `fan`, `extent_source`), Kirche (`plaster`), Fabrik (`skylight`), Büroturm (`light_scale`, Glasverlauf, Foyer), Laden (`sign` mit `logo="bag"`, `light_scale`), Fachwerkportal (`web_k`, `web_dark`, `steel`), Windmühle (nur Kommentar); neu `props/bridge_pylon_bare` (Set `modern_only`) |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`): 42 Modelle, 183 Sets (54 mit Modell) |
| `docs/modelle.md` | Abschnitt 15: Unterabschnitt „Nacharbeit nach der Kunstkritik (AS4R)“, Tabelle nachgezogen |

Keine Änderung an `core`, `glb`, `roles`, `bake`, `lod`, `manifest`, `export`, `export_models.py`,
`validate_models.py`, `tools/models/**`, `model_db.gd`. Eigene Dateien: `ce3d/buildings3d.py`, `ce3d/bridges3d.py`,
Hook `plaster` in `cesprites/props_buildings.py` (Voreinstellung = Sprite), `assets/models/props/<15 Modelle>`.
Nicht angefasst: `props3d.py`, Renderer, Shader, Fahrzeuge, AS3-Dateien, `city_*`, Wahrzeichen, eingefrorene Dateien.

Hinweis zur Zusammenführung: `cesprites/props_buildings.py` gehört zum Schlüssel des Bauers `building` (AS1b:
Bauernhaus, Scheune, Tankstelle, Zollhäuschen …) – deren Schlüssel ändern sich, ihre Dateien nicht (nur
`church()` hat einen Hook bekommen; Geometrie-Gate grün).

## Abweichungen

- **Fensterscheiben im Atlas statt `vpbr`-Lampen** (D20 nennt Nachtfenster Vertex-Codes): Kanal 12 zeigt
  unbeleuchtet die halbe Leuchtfarbe – braune Scheiben bei Tag. Die Scheibe ist der zurückgesetzte Lochfüller
  (Glas im Albedo, Licht im Nachtlicht-Atlas, `baked`-Klasse, wie es §4.6.4 für gebackene Modelle vorsieht).
- **Scheiben 8 % zum Himmel getönt und ohne Umgebungsverdeckung** (gegenüber dem Glas des Sprites rund 10 Stufen
  heller): sonst flimmerten die Rahmenkanten der Wohnblöcke stärker als bei AS4.
- **Pylon: Fächer 36 m statt „≤ 60 m“ der Kritik**: 60 m ragten bei drei der fünf Brücken über das Brückenende;
  Seilachse bei x −1,15 statt −1,4 m (die 0,32 m starken Seile enden so außerhalb der Geländerlinie).
- **Pylon: `extent_m` aus dem Generatornetz** (Wert des Sprites) statt aus dem Modell – der kürzere Fächer hätte die
  Ausdehnung in der Sprite-Ansicht verkleinert; der Pylon wird nicht kantenbündig gestellt.
- **Neues Set `props/bridge_pylon_bare`** (`modern_only`, von keiner Etappe gestellt) für R2/R5.
- **M7 in der Höhe abgelehnt** (Windmühle unverändert; echter Rest 1,3–1,7× das Sprite, ein Umbau der Flügel half
  nicht) und **M10 Fabrik-Seitenwand abgelehnt** – Belege in der Befundtabelle.
- **Nicht behoben (niedrig):** fensterlose Rückseite des Hausboots (Wände aus `props_cities.py`), unscharfes Fenster
  im Rückgiebel der Kirche, Fähre aus der Nähe, flache Schaufenster.

## Vertragsfragen

- **D20 / §4.6.4 – Nachtfenster:** Ein Nachtrag sollte Fensterscheiben von Gebäuden im Nachtlicht-Atlas der
  `baked`-Klasse festhalten (Kanal 12 nur für Lampen mit Lichtanker) oder `vpbr` eine Tagesfarbe für Kanal 12 geben
  (`lights_day_tint`, R4). Belege: Kritik M3, AS1b- und AS4-Bericht.
- **§4.6.6 / §4.6.8 – `extent_m` = Sprite:** Die Regel setzt gleiche Geometrie voraus. Für Requisiten, die nicht
  kantenbündig gestellt werden (Pylon), sollte der Prüfer die Abweichung erlauben oder `extent_m` aus dem Sprite
  übernehmen lassen (hier: `extent_source`).
- **Brückenpylon als Modell:** Arcade passt Höhe (`height_m` 50–120 m) und Fächer (`cables` 33,8–62,6 m) je Brücke an;
  ein Modell fester Form passt nie zu allen. Vorschlag: der Pylon ohne Seile (`props/bridge_pylon_bare`) als Teil,
  Seile vom Renderer (R2 jetzt, R5 später).

## Bedarf bei anderen Paketen

- **R2 (jetzt, Testbuild):** Requisiten mit `h` < 0 (Fähren, Hausboote) auslassen, solange kein Wasser-Bauer
  registriert ist – auf Kiel–Hamburg stehen bei km 78,9 / 79,1 / 84,6 Fähren auf der Wiese.
- **R2/R5:** `props/bridge_pylon_bare` + Seile je Brücke aus `height_m`, `cables` und der Deckkante (wie
  `RoadRenderer._pylon()`), Pylon nach `height_m` / 88,8 nur in der Höhe skaliert; Maße unten.
- **R3/R4 (`vpbr.gdshader`):** Die Rotorphase (`wp0.x × 0,37 + wp0.z × 0,23`) hängt an der ursprungsrelativen Position:
  bei jedem Versatz des Ursprungs (alle 2 km, `rebase_m`) springen alle Flügel. Eine Phase aus einem festen Wert
  (z. B. Instanzfarbe oder Strecken-z) würde es lösen.
- **R4 (Nacht):** Fensterlicht kommt jetzt aus dem Nachtlicht-Atlas (`emit_energy` 1,6), abgeglichen gegen Arcade
  (Spitze 216 gegen 225 bei 23 Uhr); wer `emit_energy` ändert, gleicht hier nach.
- **AS1b-Gebäude (Bauernhaus, Zollhäuschen, Tankstelle):** haben noch Kanal-12-Scheiben (dasselbe Braun-Blau bei Tag).
  Mit dem Bauer `house` (wie die Windmühle) wären sie behoben; `props3d.py` teilt seinen Schlüssel mit den Büschen
  von AS3, darum hier nicht angefasst.
- **Prüfwerkzeuge:** Flimmern drehender Modelle mit bewegter Kamera messen (`my_scene.gd --mode=sparkcam` im Scratch);
  Texeldichte je Wandebene statt je Richtungsfach.

## Maße für R5 (geändert gegenüber AS4)

**`props/bridge_pylon`** (Modellraum des Manifests: +X quer, +Y oben, −Z entlang der Fahrbahn; Ursprung = Fußpunkt
= Aufstellpunkt des Requisits, Deckhöhe y = 0)
- AABB x −1,575 … 3,949, y 0 … 88,75, z ±36,15 m. Bein senkrecht, Mitte bei x +0,9 m; Querschnitt 4,4 × 6,0 m am Fuß
  (x −1,3 … 3,1), 2,7 × 3,6 m bei 82 m; Kopf bis 83,2 m, Kappe bis 88,0 m; Sockel x −1,3 … 3,9, z ±4,0, 0,8 m hoch.
- Seile: 7 je Seite, 0,32 m stark. Kopfanker y 55 … 79 m (4 m Teilung), x = 0,9 − (2,2 − 0,85 y/82) + 0,05 m
  (Straßenseite des Beins), z ±0,6 m; Deckanker x −1,15 m, y 1,1 m, z ±(8,0 + 4,667 k) m, k = 0 … 6 (der höchste Anker
  zum weitesten Punkt, keine Kreuzung).
- Flugbefeuerung: Anker (0,45 | 88,3 | 0), Richtung (−1, 0, 0), rot.
- `props/bridge_pylon_bare`: dasselbe ohne Seile; AABB x −1,3 … 3,949, z ±4,0 m.
- Fachwerkportal und Laterne: unverändert (Maße im AS4-Bericht).
