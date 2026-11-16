W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:70], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)
C = "tests/race3d/render/check_instance_budget.gd"
sub(C, """## Prints "RENDER-CHECK instanzen OK|FEHLER …" with the wall time of the two phases (loading until the first
## simulation step, then the drive); exit code 0 when it passes. Subclasses set their own view time (_sim_s()).
""", """## Prints "RENDER-CHECK instanzen OK|FEHLER …" with the wall time of the two phases (loading until the first
## simulation step, then the drive); exit code 0 when it passes. Subclasses set their own view time (_sim_s()).
## RINT-M2 (A-19, NACH-M2 N-02): a subclass may fill the vehicle budget from the first picture on (_inject_n() test cars
## through tests/race3d/fixtures/vehicle_probe_renderer.gd, kept in view at distances that sweep 20–540 m so every car
## builds its levels) – then the vehicle layer must reach at least LOADED_SHARE of INSTANCE_BUDGET, or the check says it
## was not loaded (FEHLER): only so does it check the whole scene WITH a full vehicle budget (forest, city finish).
""")
sub(C, """const REFUSAL := "Too many instances using shader instance variables"
""", """const REFUSAL := "Too many instances using shader instance variables"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
const LOADED_SHARE := 0.9           ## injected traffic: the vehicle layer reaches at least this share of its budget
## injected traffic: the sets the test cars cycle through (cars, vans, trucks, bus, police: every vehicle class)
const INJECT_SETS: Array = ["traffic/hatch_red", "traffic/sedan_silver", "traffic/suv_white", "traffic/van_white",
	"traffic/truck_red", "traffic/bus_blue", "police/de", "traffic/sports_yellow", "traffic/wagon_darkblue",
	"traffic/hatch_white", "traffic/wagon_white", "traffic/wagon_silver"]
""")
sub(C, """var _wall_live := -1               ## wall clock (ms) when the race ran its first steps: end of the loading phase
""", """var _wall_live := -1               ## wall clock (ms) when the race ran its first steps: end of the loading phase
var _probe: GDScript               ## the probe renderer when the check injects traffic (_inject_n() > 0)
""")
sub(C, """	if _preset() != "":
		CliArgs.all()["gfx-preset"] = _preset()
	_sc = (load(RACE) as PackedScene).instantiate()""", """	if _preset() != "":
		CliArgs.all()["gfx-preset"] = _preset()
	if _inject_n() > 0:
		_probe = load(PROBE)
		load("res://scripts/race/race_renderers.gd").set("modern_script", PROBE)
	_sc = (load(RACE) as PackedScene).instantiate()""")
sub(C, """## Quality preset of the run ("" = the one this machine picks).
func _preset() -> String:
	return ""
""", """## Quality preset of the run ("" = the one this machine picks).
func _preset() -> String:
	return ""


## Test cars kept in view from the start (0 = only the stage's own traffic) – see the header.
func _inject_n() -> int:
	return 0


## The injected cars of this frame: distances sweep 20–540 m with the view time (each car crosses every level of
## detail), three lanes, the sets of INJECT_SETS in turn.
func _inject(view: Dictionary, t: float) -> void:
	var cam_z := float(view.get("camera_z", 0.0))
	var pl: Variant = view.get("player", {})
	var px := float((pl as Dictionary).get("x", 0.0)) if pl is Dictionary else 0.0
	var cars: Array = []
	for i in _inject_n():
		var set_id: String = INJECT_SETS[i % INJECT_SETS.size()]
		var d := 20.0 + fmod(float(i) * 37.0 + t * 26.0, 520.0)
		cars.append({"kind": "car", "id": 9700 + i, "set": set_id, "z": cam_z + d, "x": px + 3.75 * float(i % 3 - 1),
			"length": float(ModelDB.object_size(set_id).get("length_m", 4.7)), "tail": 0.0, "brake": 0.0, "speed": 0.0,
			"blink": 0, "blink_t": 0.0, "heavy": set_id.contains("truck") or set_id.contains("bus")})
	_probe.set("inject", cars)
""")
sub(C, """	var pf: Dictionary = vl.call(&"perf")
	_worst_layer = maxi(_worst_layer, int(pf.get("vehicle_instances", 0)))""", """	if _probe != null:
		_inject(view, float(view.get("time", 0.0)) - _t0)
	var pf: Dictionary = vl.call(&"perf")
	_worst_layer = maxi(_worst_layer, int(pf.get("vehicle_instances", 0)))""")
sub(C, """	if _budget <= 0 or _worst_layer > _budget:
		p.append("Fahrzeug-Ebene höchstens %d Instanzen (%d)" % [_budget, _worst_layer])""", """	if _budget <= 0 or _worst_layer > _budget:
		p.append("Fahrzeug-Ebene höchstens %d Instanzen (%d)" % [_budget, _worst_layer])
	if _probe != null:
		_probe.call("reset")
		load("res://scripts/race/race_renderers.gd").set("modern_script", "res://scripts/race3d/modern_renderer.gd")
		if _worst_layer < int(ceil(float(_budget) * LOADED_SHARE)):
			p.append("Fahrzeug-Ebene nicht belastet: %d von %d Instanzen (verlangt %.0f %%)" % [_worst_layer, _budget, LOADED_SHARE * 100.0])""")
sub(C, """		"%.0f s Verkehr bei 6-facher Zeit (%d Bilder): keine Ablehnung der Engine, Fahrzeug-Ebene höchstens %d Instanzen (Budget %d, %d freigegeben, %d Bauten), ganze Szene höchstens %d mit Instanz-Uniforms (Grenze %d; Laden %.0f s, Fahrt %.0f s)" % [
			sim_s, _frames, _worst_layer, _budget, trims, builds, _worst_scene, SCENE_LIMIT, load_s, drive_s],""",
"""		"%.0f s Verkehr bei 6-facher Zeit (%d Bilder%s): keine Ablehnung der Engine, Fahrzeug-Ebene höchstens %d Instanzen (Budget %d, %d freigegeben, %d Bauten), ganze Szene höchstens %d mit Instanz-Uniforms (Grenze %d; Laden %.0f s, Fahrt %.0f s)" % [
			sim_s, _frames, ", %d eingespeiste Autos" % _inject_n() if _inject_n() > 0 else "", _worst_layer, _budget, trims, builds,
			_worst_scene, SCENE_LIMIT, load_s, drive_s],""")
print("ok")
