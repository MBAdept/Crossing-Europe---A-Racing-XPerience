# Fahrzeugdarstellung v2 – Vertrag zwischen Sprite-Pipeline und Renderer

Anlass (Playtest): Fahrzeuge, die vor einem in eine Kurve einlenken, springen in zwei Stufen auf gedrehte
Ansichten (0°/±12°/±25°) und scheinen dabei mehrere Spuren zu blockieren – man kann aber vorn „durch sie
hindurch“ fahren. Das eigene Auto folgt der Kurve sichtbar nicht. Die Spielerautos sollen deutlich
detailreicher und weniger kantig werden.

Ursachen:

1. Der Renderer berechnet den Darstellungswinkel wie für einen Punkt (Straßenrichtung minus Sehstrahl), ohne
   Fahrzeuglänge. Für ein um das Heck gedrehtes Sprite schwenkt die Front dadurch viel zu weit aus (Lkw: bis
   7 m), während die Kollisionsbox in der Spur bleibt.
2. Nur 5 Winkel mit harten Schwellen (6,5°/18,5°) → sichtbares Springen, große Rundungsfehler.
3. Orthografische Sprites zeichnen die Front im Maßstab des Hecks. Bei langen Fahrzeugen in Kameranähe
   (Überholen eines Lkw) ist das grob falsch.

Lösung: drei Darstellungsarten, im Manifest pro Set festgelegt.

## 1. Manifest-Erweiterungen (abwärtskompatibel)

| Feld | Bedeutung |
|---|---|
| `grid_cols` | Zellen pro Zeile im Sheet. Zellindex `i = ebene * len(angles) + winkel`; Spalte `i % grid_cols`, Zeile `i / grid_cols`. Fehlt das Feld: `grid_cols = len(angles)` (bisheriges Layout: eine Zeile je Ebene). Sheets höchstens 4096 px breit und hoch. |
| `yaw_deg` | Gierwinkel je Eintrag von `angles` (gleiche Reihenfolge), + = nach rechts gedreht (rechte Flanke sichtbar). Der Renderer wählt die Zelle mit dem nächstliegenden Winkel. |
| `pivot` | `"rear"` (Drehung um die Heckmitte am Boden = Anker) oder `"center"` (Drehung um die Fahrzeugmitte). |
| `projection` | `"ortho"` (Standard) oder `"perspective"`. |
| `camera` | nur `perspective`: `{"height_m", "distance_m" (Kamera hinter der Fahrzeugmitte), "fov_deg" (horizontal), "horizon_y_frac", "screen": [1280, 720]}` – genau die Spielkamera (`render.*`), für die gerendert wurde. |
| `supersample` | nur `perspective`: Faktor, mit dem die Zelle größer gerendert wurde als sie im Spiel erscheint (z. B. 2.0). |
| `render` | `"sprite"` (Standard) oder `"box"` (siehe 4). |

Alle bisherigen Felder (`file`, `cell`, `angles`, `layers`, `image_width_m`, `anchor`, `object`, `tags`,
`extent_m`, `elevation_deg`) bleiben gültig. Winkelnamen: `"c"` muss für 0° vorhanden bleiben; übrige Namen
sind frei (z. B. `l24 … l3, c, r3 … r24`), der Renderer arbeitet nur mit `yaw_deg`.

## 2. Pkw im Verkehr und Polizei – `projection: ortho`, `pivot: rear`

- 17 Winkel: −24° … +24° in 3°-Schritten, Drehung um die Heckmitte (Anker = Heckmitte am Boden, für alle
  Winkel gleich), Ebenen wie bisher (`base`, `tail`, `brake`, Polizei zusätzlich `beacon_a`, `beacon_b`).
- Renderer: Darstellungswinkel ψ mit Fahrzeuglänge L (Heckpunkt in Tiefe `d_r` vor der Kamera, seitlicher
  Abstand `x_r` des Hecks von der Kameraachse inkl. Straßenversatz, Straßenrichtung `h` an dieser Stelle
  relativ zur Kameraachse, Eigenrichtung `ψ_c = atan(v_quer / v_längs)` bei Spurwechseln):

  `sin ψ = (d_r · tan(h + ψ_c) − x_r) / (d_r + L)` (begrenzt auf ±30°)

  Damit liegt die Front des um das Heck gedrehten Sprites genau dort, wo die echte Perspektive sie zeigt
  (gemessen im Maßstab des Hecks); das Heck sitzt ohnehin exakt.
- Pro Fahrzeug geglättet (kritisch gedämpft, Zeitkonstante ≈ 0,12 s) und mit Hysterese beim Zellwechsel
  (wechseln erst, wenn die neue Zelle um mehr als 0,3 Schritte näher liegt).

## 3. Spielerauto – `projection: perspective`, `pivot: center`

- Neue, glatte und detailreiche Modelle (Subdivision, weiche Übergänge, echte Leuchtengrafiken,
  Felgen, Diffusor, Auspuff, Spiegel, Kennzeichen …), gerendert **mit der Spielkamera** (`camera`):
  Kamera `height_m` über dem Boden, `distance_m` hinter der Fahrzeugmitte, waagrechter Blick, horizontale
  Brennweite aus `fov_deg` bei `screen`-Breite, Horizont bei `horizon_y_frac`. Die Zelle zeigt genau den
  Bildausschnitt um das Auto (Objektiv-Shift), `supersample`-fach vergrößert.
- 21 Winkel: −20° … +20° in 2°-Schritten, Drehung um die Fahrzeugmitte. `anchor` = projizierter
  Bodenpunkt der Fahrzeugmitte in der Zelle (für alle Winkel gleich).
- Renderer: zeichnet die Zelle mit dem Anker auf dem projizierten Bodenpunkt der Fahrzeugmitte, Maßstab
  `distance_m / tatsächliche Tiefe / supersample` (bei der Standardkamera also 1/supersample).
  Sichtbarer Gierwinkel = gedämpfte Summe aus Kurvenvorschau (Straßenrichtung einige Meter voraus),
  Lenkeinschlag, Spurwechsel-Querbewegung und Untersteuern; dazu eine leichte Neigung (Rotation um den Anker,
  höchstens ±2,5°) aus der Querbeschleunigung. Kennwerte in `render.player_*`.
- Wird die Kamera in der Konfiguration verändert, müssen die Spieler-Sprites neu gerendert werden; das
  Manifest dokumentiert die verwendete Kamera.

## 4. Lkw und Busse – `render: box`

Kein gedrehtes Sprite, sondern perspektivisch projizierte, texturierte Quader, die der Straße abschnittsweise
folgen. Format:

```json
"traffic/truck_white": {
  "file": "traffic/truck_white.png",
  "render": "box",
  "object": { "width_m": 2.55, "length_m": 16.5, "height_m": 4.0 },
  "tags": ["traffic", "heavy"],
  "parts": [
    { "name": "trailer", "z": [-8.25, 5.35], "x": [-1.275, 1.275], "y": [0.0, 4.0],
      "faces": { "rear": [x, y, w, h], "left": [x, y, w, h], "right": [x, y, w, h], "top": [x, y, w, h] } },
    { "name": "cab", "z": [5.75, 8.25], "x": [-1.25, 1.25], "y": [0.0, 3.8], "faces": { … } }
  ],
  "lights": {
    "tail":  [ { "part": "trailer", "face": "rear", "rect": [x, y, w, h] } ],
    "brake": [ { "part": "trailer", "face": "rear", "rect": [x, y, w, h] } ]
  }
}
```

- Koordinaten relativ zur Fahrzeugmitte in Metern: `z` längs (+ = vorn), `x` quer (+ = rechts), `y` Höhe über
  Boden. `rect` = Pixelrechteck im Sheet. `top` ist optional.
- Jedes Flächenbild deckt genau das Rechteck der Fläche ab (ohne Rand) und darf Transparenz enthalten
  (z. B. zwischen den Achsen, Umriss des Fahrerhauses). Mindestens 48 px/m.
- Bildausrichtung, jeweils **von außen** auf die Fläche gesehen (u = Bild links→rechts, v = oben→unten):
  `rear` (Ebene z = z0): u: x0 → x1, v: y1 → y0 · `left` (x = x0): u: z1 → z0 (vorn links im Bild),
  v: y1 → y0 · `right` (x = x1): u: z0 → z1, v: y1 → y0 · `top` (y = y1, Front oben im Bild): u: x0 → x1,
  v: z1 → z0.
- Lichtüberlagerungen haben dieselbe Ausrichtung und Größe wie ihre Fläche (nur die Leuchten, sonst
  transparent) und werden nachts bzw. beim Bremsen darübergelegt.
- Renderer: sichtbar sind Flächen, deren Außenseite zur Kamera zeigt (Heck immer bei Fahrzeugen vor der
  Kamera; links/rechts je nach seitlicher Lage; Dach nur, wenn die Kamera höher ist). Seiten- und
  Dachflächen werden längs in Abschnitte von höchstens 2 m geteilt und mit der Straßengeometrie dieser
  Abschnitte projiziert (biegen sich mit der Kurve); Abschnitte hinter der Kamera werden abgeschnitten, damit
  ein Lkw neben dem Spieler sichtbar bleibt. Flächen eines Fahrzeugs werden von hinten nach vorn gezeichnet.

## 5. Größen und Speicher

- Fahrzeug-Sheets werden mit VRAM-Kompression (BPTC/S3TC) importiert; Sheets höchstens 4096 px je Seite;
  PNG-Gesamtbudget der Sprites ≈ 60 MB.
- SpriteDB lädt Sets erst bei Bedarf.
