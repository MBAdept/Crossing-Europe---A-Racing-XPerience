
## 9. Hinweise für die Nächsten

1. **R7c / Besitzer von `props.gd`**: den toten Pfad der fernen Vertretungen entfernen (`_update_far_landmarks`,
   `_far`, `landmark_material`, `_landmark_override`, `landmark_fallbacks`) und `docs/renderer-modern-gelaende.md`
   Zeile 185 nachziehen (beschreibt noch das Ersatz-Set für prozedurale Wahrzeichen – jetzt 3D-Formen in §18.4).
2. **Integration / QA**: `tests/golden/modern_slice.*` nach dem Zusammenführen neu erzeugen (`modern_s4_mittel`:
   Michel, höchstens 2/255).
3. **AS6**: Modell in `assets/models/manifest.json` für `landmarks/<name>` genügt (§18.2): Ursprung = Anker des
   Sprites, −Z vom Fahrer weg, Klassen `baked`/`baked_cutout`/`vpbr`; Nachtlicht über Emissionsatlas bzw. Kanäle
   10–14. Auch die sechs prozeduralen Einträge (z. B. `landmarks/florianturm`) nehmen ein Modell an.
4. **Stadtbauten (AS5a2/R7c)**: Brüssel km 206,4 – Arcades Häuserzeile vor dem Atomium fehlt in Modern (auch auf der
   Basis). Paris – dunkle „X“ an Fassaden (Geländer) der Stadtgebäude.
5. **QA-mid**: Bei 600 m verdecken Häuser das Wahrzeichen in fast allen Stadteinfahrten (beide Modi) – für die
   Wahrzeichen die Nahpunkte aus `m1/R7b/sh/batch3.sh` nehmen (etwa 250 m davor).
6. **QA-mid**: Skyline im Bild nur an Kassel und Paris geprüft; ein Durchgang durch alle Städte mit Skyline-Einträgen
   lohnt (`backdrop.skyline` im Snapshot).
7. **Leuchtpunkte anderer Shader**: wer im Vertex-Schritt Pixelgrößen braucht, die Bildhöhe als Uniform übergeben
   (`VIEWPORT_SIZE` las dort 0, gefolgert).
8. **Feinschliff (Entscheidung der Leitung)**: (a) Flugwarnlicht des Fernsehturms nachts etwa dreimal so groß wie
   Arcades Punkt (`landmarks.gd`, `_tv_tower`: Stärke 0,6, Größe 5 m, Mindestgröße in Pixeln). (b) Die Formen stehen
   mit der Vorderseite am Anker; Arcade zeichnet flach am Anker. Die Form um ihre halbe Tiefe nach vorn zu setzen
   (Kuppel am Anker) brächte die Nahbilder in Kurven näher an Arcade (gefolgert; gemessen Leipzig −65 px, Belgrad
   +85 px bei 260 m);
   `test_procedural_shapes` prüft die Lage der Formen mit.
9. **R7c**: die Clips bei „Mittel“ für die LOD-Abnahme sollten eine Wahrzeichen-Anfahrt enthalten (z. B. Hamburg ab
   km 89).
