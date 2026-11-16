root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'

# --- streamer: the curve radius of a path that is set up already wins over the default ---------------------------
p = root + 'scripts/race3d/chunk_streamer.gd'
s = open(p).read()
a = '''	_curve_r1 = float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
'''
b = '''	_curve_r1 = float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 1.0 / path.inv_r1))
'''
assert a in s
s = s.replace(a, b)
a = '''## game_cfg = the whole game configuration (ConfigLoader.load_merged()). The path may still be without a setup: the
## first update() starts it behind the camera.
'''
b = '''## game_cfg = the whole game configuration (ConfigLoader.load_merged()); the builders get it as ChunkContext.cfg.
## The path may still be without a setup: the first update() starts it behind the camera.
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)

# --- docs -----------------------------------------------------------------------------------------------------
p = root + 'docs/renderer-modern.md'
s = open(p).read()
a = '''`create_all()` liefert alle vorhandenen Builder; solange `builders/road.gd` fehlt, steht die Debug-Straße an ihrer
Stelle. `create(name)`, `create_layer(name)`, `existing_builders()`, `existing_layers()` für alles Weitere.
'''
b = '''`create_all()` liefert alle vorhandenen Builder; solange `builders/road.gd` fehlt, steht die Debug-Straße an ihrer
Stelle. `create(name)`, `create_layer(name)`, `existing_builders()`, `existing_layers()` für alles Weitere.

### 4.6 Einbau in den Renderer

```gdscript
var path := RoadPath3D.new()
path.setup(track, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
var terrain := TerrainProfile.new()
terrain.setup(path, track, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), scenery_db)
var streamer := ChunkStreamer.new()
add_child(streamer)
streamer.setup(path, terrain, track, cfg, levels, sync)   # cfg: die ganze Spielkonfiguration; levels: Detailstufen
for b: ChunkBuilder in BuilderRegistry.create_all():
	streamer.register(b)
streamer.rebased.connect(_on_rebased)                     # Verschiebung für alles, was Weltpositionen hält
# je Bild
streamer.update(float(view["camera_z"]), sichtweite_m)
```

- `cfg` ist die **ganze** Spielkonfiguration (`ConfigLoader.load_merged()`); die Builder bekommen sie als
  `ChunkContext.cfg` und lesen daraus auch `road.*` und `render.*`. Der Streamer liest `graphics.modern`.
- `levels` sind die aufgelösten Detailstufen; der Kern liest daraus nur `terrain_outer_m` (äußerer Ring).
- `sichtweite_m` ist die Sichtweite der Ansicht – im Tunnel und bei Nebel lädt der Streamer entsprechend weniger.
- Der Streamer ist ein `Node3D`; seine Kinder sind die Stückknoten. Er gehört unter die Welt des Renderers, nicht
  unter einen Knoten, der sich bewegt.
- Fahrzeuge, Lichter und alles andere Bewegliche stehen jedes Bild neu über `path.world()` / `path.frame_at()`; sie
  brauchen `rebased` nicht.
'''
assert a in s
s = s.replace(a, b)

a = '''| `tests/sim/modern_sight.gd` | – | Fairness-Prüfung F1–F3, F7 (Teil von `tools/run_tests.sh`) |
| `tests/sim/modern_path_check.gd` | – | Weltprüfung: Abstand des Pfads zu sich selbst (Teil von `tools/run_tests.sh`) |
'''
b = '''| `tests/sim/modern_sight.gd` | – | Fairness-Prüfung F1–F3, F7 (läuft in `tools/run_tests.sh` über den Haken für `tests/sim/modern_*.gd`) |
| `tests/sim/modern_path_check.gd` | – | Weltprüfung: Abstand des Pfads zu sich selbst (läuft ebenso in `tools/run_tests.sh`) |
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
