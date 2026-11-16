## 3. Wie gebaut wurde – Bauer `city`, Hooks, geänderte Dateien

Alle zwölf Modelle kommen aus dem Bauer `city` von AS5a1/AS5aR1 (`tools/blender/ce3d/cities3d.py`): Öffnungen mit
Laibung, Rahmen, Sprossen, Sohlbank und versenkter Scheibe (Tag: das gemalte Glas des Sprites, Nacht: sein Licht aus
dem Lichtatlas, `emit_energy` 1,6 wie AS4R), Läden mit Auslage, Türen mit Stufen, Fensterläden als Geometrie,
Rückwände auf den Texeln der Straßenwand, flache lod1 ab 60 m, Ausschneide-Geländer mit `cut_fill`. Neu in diesem
Paket (alles rückwärtskompatibel, Voreinstellung = altes Verhalten; Beweis: die elf Modelle von Charge 1, die
Brückenteile und das Hausboot kommen byte-gleich heraus, Abschnitt 6):

| Option (Katalog) | Wozu |
|---|---|
| `rail_module` {Objekt-Präfix: L} | Geländer als wiederholtes Modul: Jedes Geländerobjekt wird bei u = k·L geschnitten (L = Vielfaches des Rasters des Generators), eine Fläche über ein ganzes Modul wird gebacken, alle anderen bekommen (u − k·L, z) dieses Moduls; Ober-, Unter- und Stirnflächen die Farbe des Handlaufs; schräge Platten (Eckhaus) lesen u = x. Vorher hätte ein durchgehender Haussmann-Balkon von 22 m bei 150 Texeln je Meter mehr Fläche gebraucht als der ganze 2048×1024-Atlas; die Fenstergitter des Lyoner Hauses kosteten in der ersten Probe die Hälfte des Atlas. |
| `weights.solid` {Präfix: Gewicht} | Baumkronen, Hortensien, Oleander, Hecken: Gewicht unabhängig von der Blickrichtung, nie „verdeckt“ – die Unterseiten der dezimierten Kronen bekamen weniger als einen Texel und zeigten hellgraue Flecken (Runde 0, Bild `r0sud`). |
| `openings.cover_skip` (Präfixe) | Objekte, die kein Fenster verdecken: Fenstergitter 10–16 cm vor dem Glas (Lyon, Paris), Geranien und Blumenkästen (Bern), Traufen knapp über den obersten Fenstern (Reihenhäuser, Lauben). Vorher blieben 8–33 Fenster je Modell gemalt. |
| `openings.chamfer` | Fenster und Laden der 45°-Ecke des Haussmann-Eckhauses werden geschnitten. Nebenbei behoben: Die Raster der Ecke wurden vorher in die Rückwand geschnitten (`_grid_faces`). |
| `smooth` (Präfixe) | Blumenkugeln glatt schattiert (vorher facettierte „Plastiksteine“). |

Hooks im Generator `props_cities.py` (Voreinstellung = Sprite; `check_sprite_geometry.py --only props --jobs 1`:
86 von 86 identisch): `close3d` für `dutch_canal` (über `_canal_house(side=…, close3d=…)`), `dutch_canal_b`,
`dutch_terrace`, `belgian_terrace`, `belgian_stone`, `french_immeuble`, `swiss_laube` – Tabelle in
`docs/modelle.md` Abschnitt 21. `french_sud`, `french_maison`, `swiss_chalet` und die Haussmann-Blöcke haben im
Generator schon Fenster an der Straßenflanke.

Geänderte geteilte Dateien (je ein Satz Zweck):

| Datei | Zweck |
|---|---|
| `tools/blender/ce3d/catalog3d.py` | zwölf Einträge im Block `# --- AS5a ---` (zweites `MODELS.update`, „AS5a2“) |
| `tools/blender/ce3d/cities3d.py` | die fünf Optionen oben (rückwärtskompatibel) und ihre Doku im Modultext |
| `tools/blender/cesprites/props_cities.py` | Hooks `close3d` (additiv, Sprite unverändert) |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`) |
| `docs/modelle.md` | Kopfzeile und Abschnitt 21 |

Nicht geändert: `buildings3d.py` (die acht AS4-Häuser behalten ihren Schlüssel), `bake.py`, `export_models.py`,
`validate_models.py`, `model_db.gd`, Renderer, Shader, Sprites.
