## Geänderte gemeinsame Dateien (rückwärtskompatibel, additiv)

| Datei | Änderung | Zweck |
|---|---|---|
| `tools/blender/ce3d/catalog3d.py` | ein Block `# --- AS5a ---` vor `model_ids()`: `BUILDER_CODE["city"]`, `AO_CITY`, elf Einträge `props/city_*` | die elf Modelle und der Code, der ihren Schlüssel bildet |
| `tools/blender/export_models.py` | `BUILDERS["city"]`, `COST["city"]` (drei Zeilen im Block `# --- AS5a ---`) | der Bauer `city` im Exporter, seine Kostenschätzung für die Verteilung auf Worker |
| `tools/blender/cesprites/props_cities.py` | Hook `close3d` (Voreinstellung aus = Sprite): `timber_house(..., close3d=False)` gibt `front_gable` einen Rückgiebel; `german_old_fachwerk` liest `p["close3d"]` | Rückgiebel der Fachwerkhäuser mit Giebel zur Straße (im Sprite offen); kein Sprite-Vertex bewegt (Geometrie-Gate) |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`) | elf Sets jetzt mit Modell statt Platzhalter |
| `docs/modelle.md` | Statuszeile, neuer Abschnitt 20 | Dokumentation des Bauers, der Hooks, der Tönung, Einordnung |

Neu und eigen: `tools/blender/ce3d/cities3d.py` (Bauer `city`), `assets/models/props/city_{german,german_old,hanse}_*`
(elf Ordner). **Nicht angefasst:** `ce3d/buildings3d.py` (Schlüssel der acht AS4-Hausmodelle unverändert – sie sind
byte-gleich, `git diff 6e48405 -- assets/models` zeigt außerhalb von `props/city_*` nur das Manifest), `props3d.py`,
`bake.py`, `roles.py`, `lod.py`, `glb.py`, `validate_models.py`, `tools/models/**`, `model_db.gd`, der Renderer
(`scripts/race3d/**`, `assets/shaders/modern/**`), Fahrzeuge, Vegetation, Wahrzeichen, Sprites, Sprite-Manifest,
eingefrorene Arcade-Dateien. Die Prüfwerkzeuge der Kunstkritik (`tools/kritik/`, unversioniert) lagen nur während der
Messungen im Worktree und sind vor den Tests gelöscht.
