## Brückenteile: Maße und Anschlusspunkte (für R5)

**Gemessen** am Generatornetz (`cesprites/props_cities.py`, unverändert) und an `model.json` der Modelle. Angaben im
Modellraum des Manifests (Godot: +X quer, +Y oben, −Z = Blender +Y entlang der Fahrbahn); Ursprung = Fußpunkt.

**`props/bridge_pylon`** – ein Bein (die Brücke stellt zwei; Arcade bei x = ±7,5 m von der Fahrbahnmitte)
- Fuß auf Fahrbahnhöhe (Requisiten-Builder: Teile mit „bridge“ bei h = 0 = Deck). AABB x −6,62…3,00, y 0…88,75,
  z ±82,69 m.
- Bein: 4,4 × 6,0 m am Fuß → 2,7 × 3,6 m bei 82 m, 3,5° zur Fahrbahn geneigt (Kopf bei x ≈ −5,0 m). Kopf bis
  83,2 m, Kappe bis 88,0 m. Flugbefeuerung: Anker (−5,47 | 88,30 | 0), Richtung (−1, 0, 0), rot, ohne Lichtfleck
  (`BEACON_MIN_H_M` 25).
- Seile: 10 je Seite. Kopfanker y = 79,0 − 2,6·k m (k = 0…9), x ≈ −5,1…−4,4 m, ±0,6 m entlang der Fahrbahn;
  Deckanker x = −4,2 m, y = 0,6 m, entlang der Fahrbahn ±(16,0 + 7,4·k) m = ±16,0…±82,6 m. Seilstärke lod0 0,28 m,
  lod1 0,34 m (vierseitige Prismen).
- Feste Höhe (Sprite). Arcade zeichnet den Pylon prozedural mit `height_m` der Brücke (50–120 m); der
  Requisiten-Builder skaliert Modelle nicht nach `height_m` → Vertragsfrage. Zieht R5 die Seile selbst (bis zum
  echten Deckrand), braucht es einen Pylon ohne Seile: eine Katalogzeile mit `cables` auf ein leeres Präfix.

**`props/bridge_truss_arch`** – Portal über der Fahrbahn
- Objekt 32,4 × 15,6 × 1,8 m; AABB x ±16,5, y −0,1…15,9, z −2,25…0,45 m. Zwei Fachwerkebenen 1,8 m hintereinander
  (z = 0 und z = −1,8 m).
- Pfosten innen x = ±14,7 m, außen ±15,9 m → lichte Weite 29,4 m; Untergurt im Scheitel 13,2 m, Obergurt 15,3 m.
- Der Requisiten-Builder skaliert gleichmäßig mit `fit_w / 32,4` (Fahrbahnbreite) – alle Maße skalieren mit.
- Hängelampen: Anker (±5,0 | 10,79 | −0,9), Richtung nach unten, Lichtfleck auf der Fahrbahn.

**`props/bridge_lamp`** – Laterne am Geländer
- AABB x ±1,18, y 0…4,83, z ±0,36 m; Säule 3,82 m.
- Drei Laternen: Anker (±0,92 | 4,12 | 0) und (0 | 3,96 | 0), Richtung nach unten, Farbe #ffd890.
