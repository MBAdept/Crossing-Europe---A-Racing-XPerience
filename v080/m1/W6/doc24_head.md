
## 24. Wahrzeichen als Modelle (Welle 6, AS6)

Die 32 Wahrzeichen mit einem Generator in `props_landmarks.py` haben Echtzeit-Modelle aus dem Bauer `prop_baked`
(Referenz `landmarks/michel`, Abschnitt 11): die Geometrie des Generators in echter Größe – Türme, Helme, Fialen,
Kuppeln, Gitter – mit ihren Materialien in einen Atlas gebacken (`baked` bzw. `baked_cutout`), die Lichtebene des
Generators (Anstrahlung, erleuchtete Fenster) in den Emissionsatlas, flache Lampenmaterialien (Flugwarnlichter) als
Lichtanker. Der Renderer zeichnet ein Wahrzeichen aus seinem Modell, sobald das Manifest eines führt
(docs/renderer-modern.md 19.2) – am Renderer hat sich nichts geändert. Mit dem Michel haben damit 33 Sets ein Modell.
In drei Chargen exportiert und angesehen: L1 die neun Wahrzeichen von Kiel–Hamburg bis Riga, L2 Wien bis Mailand,
L3 Venedig bis Bukarest. Reihenfolge der Tabelle wie die Chargen.

Ohne Modell bleiben die zehn Einträge ohne Generator und ohne Sprite (`proc` in `data/cities.json`): Neues Rathaus
Hannover, Florianturm, Völkerschlachtdenkmal, Cuatro Torres, Kirche des Heiligen Sava, Leuchtturm Calais, Herkules
Kassel, Sacré-Cœur, Colonius und der Fernsehturm Riga. Modern zeichnet sie weiter als prozedurale 3D-Form
(renderer-modern.md 19.4), genau wie Arcade sie prozedural zeichnet. Ein Modell setzt einen neuen Generator voraus;
das wäre eigene Arbeit und ist nicht Teil dieser Welle.

