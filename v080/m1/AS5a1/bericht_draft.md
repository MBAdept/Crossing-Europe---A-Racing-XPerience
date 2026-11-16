# AS5a1 – Stadthäuser german, german_old und hanse als Echtzeit-Modelle (Bericht)

Paket **AS5a1** von v0.8.0 „Modern“. Zweig `worktree-wf_db8ba6cd-508-1`, gesichert als `origin/wip/v080-as5a1`;
Basis `6e48405`, Endstand `@@HEAD@@`. Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1`.
Zahlen sind mit **(gemessen)** oder **(gefolgert)** markiert; ohne Zusatz in Tabellen gilt „gemessen“. Gemessen heißt:
auf dieser VM (4 Kerne, mit anderen Aufträgen geteilt, Last 17–20), Software-OpenGL (llvmpipe) unter Xvfb, Renn-Look
der Prüfszene (`prop_scene --look=race`) bzw. `tools/ab_shot.sh`. Alles über echte Grafikkarten, das Steam Deck oder
die Wirkung auf einen Menschen ist gefolgert.

## Kurzfassung

@@KURZ@@

## Ergebnis je Modell (Budget)

@@BUDGET@@

## Gates (auf dem Endstand)

@@GATES@@

## Messungen

@@MESS@@

## Runden Bauen → Ansehen → Beheben

@@RUNDEN@@

## Ehrliche Einordnung

@@EINORDNUNG@@

## Geänderte gemeinsame Dateien (rückwärtskompatibel, additiv)

| Datei | Änderung |
|---|---|
| `tools/blender/ce3d/catalog3d.py` | ein Block `# --- AS5a ---` vor `model_ids()`: `BUILDER_CODE["city"]`, `AO_CITY`, elf Einträge `props/city_*` |
| `tools/blender/export_models.py` | `BUILDERS["city"]`, `COST["city"]` (zwei Zeilen im Block `# --- AS5a ---`) |
| `tools/blender/cesprites/props_cities.py` | Hook `close3d` (Voreinstellung aus = Sprite): `timber_house(..., close3d=False)` gibt `front_gable` einen Rückgiebel; `german_old_fachwerk` liest `p["close3d"]`. Kein Sprite-Vertex bewegt (Geometrie-Gate) |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`) |
| `docs/modelle.md` | Statuszeile, neuer Abschnitt 20 |

Neu und eigen: `tools/blender/ce3d/cities3d.py` (Bauer `city`), `assets/models/props/city_{german,german_old,hanse}_*`.
Nicht angefasst: `ce3d/buildings3d.py` (Schlüssel der AS4-Modelle), `props3d.py`, `bake.py`, `roles.py`, Renderer
(`scripts/race3d/**`), Shader, Fahrzeuge, Vegetation, Wahrzeichen, Sprites, Sprite-Manifest, eingefrorene Dateien.

## Lieferung

@@LIEFERUNG@@
