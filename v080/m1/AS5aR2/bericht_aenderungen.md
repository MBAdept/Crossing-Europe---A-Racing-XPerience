## 3. Was geändert ist (Code und Katalog)

| Datei | Änderung | Zweck |
|---|---|---|
| `tools/blender/ce3d/cities3d.py` | `_display_mat`: Lichtschicht = Lichtfarbe × Stärke × `PANE_LIGHT_K` × `SHOP_GLOW` 1,6 (war 1,25) × (0,3 + 0,75 × √Innenfarbe) (war 0,2 + 0,8 × Innenfarbe), dazu ein Deckenlicht-Band im oberen Viertel (+0,35) | K1: Läden nachts so hell wie Arcade, Auslage bleibt lesbar (nie eine flache weiße Fläche) |
| `tools/blender/ce3d/cities3d.py` | `_log_walls` reicht `inner_k` (`INNER_K` 0,75) und `bars_k` (`BARS_K` 0,35) an `wallmat` weiter | K2/K6: Innenring und gemalte Sprossen der Fernstufe zum Glas hin |
| `tools/blender/ce3d/cities3d.py` | `lod1_opaque`: lod1 zeichnet die Ausschneide-Teile als `baked` (Alpha-Test aus, Rückseiten-Culling) | K4: kein Flimmern der Schwelle in lod1, Geländer als Band |
| `tools/blender/ce3d/cities3d.py` | Blattkarten (lod0 und, mit `n1`, lod1): `_crown_logger`, `_leaf_cards`, `_leaf_setup`, `_leaf_reserve`, `_leaf_paste`, `_leaf_uv`, `_leaf_sheet`, `_scale_about`; `bake_city(leaf_px)` reserviert das Feld; `_finish_city(leaf)` klebt die Blattbüschel in den Atlas und legt die Karten in lod0 | K3: Gartenbaum als Blattkrone statt Steintraube |
| `tools/blender/ce3d/cities3d.py` | `_flower_shape` | K7: Geranien als Polster |
| `tools/blender/cesprites/props_cities.py` | `wallmat(..., inner_k=0.0, bars_k=0.0)` + `_toward` – nur wirksam mit `inner_frame` (nur der 3D-Bau setzt ihn) | Hook K2; Sprites unverändert (k = 0 gibt denselben Knotengraphen) |
| `tools/blender/ce3d/catalog3d.py` (Block `# --- AS5a ---`) | `lod1_opaque=True` für Mietshaus, Gründerzeit, Lyoner Haus, Haussmann, Eckhaus, Chalet; `leaf_cards` Südhaus und Loire-Haus mit denselben Karten in lod1 (`n1`, `half1`; Loire-Haus dafür `single_cutout`); `flower_shape` Chalet; kleinere `lod1_decimate` der Gartenkronen | Katalog |
| `assets/models/props/city_*/**` (23) | neu exportiert | |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`) | |
| `docs/modelle.md` | Abschnitt 22, Stand-Zeile | Doku |

Geteilte Pipeline-Dateien (`core`, `glb`, `roles`, `bake`, `lod`, `manifest`, `export`, `export_models.py`,
`validate_models.py`, `tools/models/**`, `model_db.gd`) und `buildings3d.py` sind **nicht** geändert – die acht
AS4-Hausmodelle haben ihren Schlüssel behalten (byte-gleich ohne Neu-Export). Der Renderer ist nicht berührt.
