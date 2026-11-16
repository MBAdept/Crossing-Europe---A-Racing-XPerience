# AS4 – Landgebäude, Brückenteile und Schiffe für „Modern“ (Bericht)

Paket **AS4** von v0.8.0 „Modern“. Zweig `worktree-wf_aad8d49e-fb4-2` (gesichert als `origin/wip/v080-as4`), Basis
`8f58b2d`, Stand `{{COMMIT}}`. Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2`.
Zahlen sind mit **(gemessen)** oder **(gefolgert)** markiert. Alle Bilder: Software-OpenGL (llvmpipe) unter Xvfb –
Aussagen über echte Grafikkarten und das Steam Deck sind gefolgert.

## Kurzfassung

Vierzehn Echtzeit-Modelle für den Modus „Modern“, alle aus den Sprite-Generatoren (die Sprites sind der Look):
Haus (`house_med`), Kirche, Fabrik, Ladenhaus, Altstadthaus mit Treppengiebel, Wohnblock A und B, Büroturm,
Hausboot, Fähre, Brückenlaterne, Pylon der Schrägseilbrücke, Fachwerkportal – und die Windmühle von AS1b mit echten
Fensteröffnungen statt gemalter Fenster (der einzige Mangel, den AS1b dort nennt). Weitere Land- oder Straßen-Sets ohne
Modell gibt es nicht (Zählung über das ganze Netz, `census_all`).

Neu: der Gebäudebauer `house` (`ce3d/buildings3d.py`) mit geschnittenen Öffnungen (Laibung, Rahmen, Sprossen,
Sohlbank, Scheibe), Türen mit Stufen, Läden, Schallluken, Uhren, Rinnen und Fallrohren, Werkszeichen, Vorhangfassade,
Lochfüller-Bake und Flutlicht; die Brückenbauer `pylon`, `truss`, `lantern` (`ce3d/bridges3d.py`). Alle Budgets
eingehalten (gemessen, Tabelle). Drei Runden; die dritte (voller Export, Renn-Look, Spielkamera, Messung) behob den
Farbsprung beim Stufenwechsel, den Lisenen-Sprung des Büroturms, die zu geringe Dichte am Pylonfuß, grüne Lichtflecken
der Fähre und die Spiegelschrift der Fabrik am linken Fahrbahnrand.

**Alle Gates grün** auf `{{COMMIT}}` (gemessen): Validator OK, Sprite-Geometrie 86 von 86 identisch, `--check-keys`
OK, zweiter erzwungener Export aller 14 Modelle byte-gleich, 12 Modern-Rennläufe ohne Skriptfehler,
`run_tests.sh` bestanden (692 Tests, 141 Checks, 0 Fehler), `golden.sh check` 20 von 20 identisch.
**Schwächstes Modell: die Fähre** (gemalte Kabinenfenster, flache Aufbauten).

{{TABELLE}}

## Runden

{{RUNDEN}}

{{MESSUNGEN}}

{{R5}}

## Gates (auf dem Endstand `{{COMMIT}}`)

{{GATES}}

## Geänderte gemeinsame Dateien (alle rückwärtskompatibel, additiv)

| Datei | Änderung |
|---|---|
| `tools/blender/ce3d/catalog3d.py` | ein Block `# --- AS4 ---`: `BUILDER_CODE` für `house`, `pylon`, `truss`, `lantern`; `AO_TOWN`; die 14 Katalogzeilen (die Mühle als Ersatz der AS1b-Zeile). Ein einziger Diff-Abschnitt, nichts Bestehendes geändert. |
| `tools/blender/export_models.py` | `BUILDERS`/`COST` um die vier Bauer ergänzt (Block `# --- AS4 ---`). |
| `tools/blender/validate_models.py` | `lod1`-Budget = `lod0`-Budget für `rural`, `city`, `pylon` (explizite Detailstufe statt „auto“, siehe Abweichungen). Bewusst nicht in `ce3d/manifest.py` (Teil jedes Cache-Schlüssels). |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`). |
| `docs/modelle.md` | Abschnitt 15 (neu). |

Eigene Dateien: `tools/blender/ce3d/buildings3d.py`, `tools/blender/ce3d/bridges3d.py` (neu), Hooks in
`cesprites/props_buildings.py` und `cesprites/props_road.py` (Voreinstellung = Sprite, kein Sprite-Vertex bewegt:
Geometrie-Gate), `assets/models/props/<14 Modelle>/`. Nicht angefasst: `props3d.py` (Schlüssel von AS1b/AS3), Renderer,
Shader, Fahrzeuge, AS3-Dateien, `city_*`, Wahrzeichen, eingefrorene Arcade-Dateien.

{{REST}}
