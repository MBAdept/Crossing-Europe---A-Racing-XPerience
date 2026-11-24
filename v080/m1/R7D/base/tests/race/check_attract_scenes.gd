extends SceneTree
## Attract demos (docs/ui.md "Attract-Modus"): runs every configured scene of attract.scenes for its full demo_s through
## the real game (GameFlow, title, AttractMode, race scene, autopilot) and checks that it is a good demo:
##   * it ends by time – not at the finish of the stage (QA v0.5.0: Wien reached the ZIEL gantry and stood still)
##   * no collision, no guardrail hit, never beside the road
##   * nothing close in front of the car: nearest car ahead in its path ≥ MIN_GAP_M, in the first START_S ≥
##     START_GAP_M (QA: a demo started 15 m behind a car doing 38 km/h)
##   * no crawl: average ≥ MIN_AVG_KMH (QA: Paris and Hamburg crawled at 52/55 km/h behind city traffic)
## The demos are deterministic (seed per scene), so this pins the tuned scene values (km, seed, cruise_kmh).
##   godot --headless --path . --fixed-fps 60 -s res://tests/race/check_attract_scenes.gd [-- --only=wien,paris]
## Exit code 0 = every scene passed. About 2 minutes for 7 scenes.
## Note: autoload classes are accessed untyped (this script compiles before the autoloads exist).

const STATE_IDLE := 0
const STATE_DEMO := 2
const MIN_GAP_M := 10.0
const START_S := 3.0
const START_GAP_M := 15.0
const MIN_AVG_KMH := 70.0

var _gf: Node
var _am: Node
var _clock := 0.0
var _wall0 := 0
var _only: Array = []
var _todo: Array = []
var _in_demo := false
var _race: Node = null
var _t0 := 0.0
var _s: Dictionary = {}
var _scene: Dictionary = {}
var _failed: Array[String] = []
var _booted := false
var _next_index := -1               ## scene of the next demo, set once the title is back (AttractMode advances its own)


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	var only := str(CliArgs.all().get("only", ""))
	_only = only.split(",", false) if only != "" else []
	_boot.call_deferred()


func _boot() -> void:
	_gf = root.get_node_or_null("GameFlow")
	if _gf == null or _gf.get("attract") == null:
		print("FEHLER: GameFlow/AttractMode fehlt")
		quit(1)
		return
	_am = _gf.get("attract")
	var scenes: Array = _am.get("scenes")
	for i in scenes.size():
		var id := str((scenes[i] as Dictionary).get("id", ""))
		if _only.is_empty() or _only.has(id):
			_todo.append(i)
	if _todo.is_empty():
		print("FEHLER: keine Szene")
		quit(1)
		return
	_am.set("idle_s", 0.3)
	_next_index = int(_todo[0])
	_gf.call("boot")
	_booted = true


func _process(delta: float) -> bool:
	_clock += delta
	if (Time.get_ticks_msec() - _wall0) / 1000.0 > 900.0:
		print("FEHLER: Zeitlimit")
		quit(2)
		return false
	if not _booted:
		return false
	var st := int(_am.get("state"))
	if _next_index >= 0 and st == STATE_IDLE:
		_am.set("scene_index", _next_index)
		_next_index = -1
	if st == STATE_DEMO and not _in_demo:
		_start_demo()
	if _in_demo:
		if st == STATE_DEMO and _race != null and is_instance_valid(_race):
			_sample(delta)
		else:
			_end_demo()
	return false


func _start_demo() -> void:
	_in_demo = true
	_race = _gf.get("current")
	_scene = (_am.get("current_scene") as Dictionary).duplicate(true)
	_t0 = _clock
	_s = {"n": 0, "v_sum": 0.0, "v_min": INF, "gap": INF, "gap_t": 0.0, "start_gap": INF}


func _sample(_delta: float) -> void:
	var t := _clock - _t0
	var v: Object = _race.get("vehicle")
	var speed := float(v.get("speed"))
	_s["n"] = int(_s["n"]) + 1
	_s["v_sum"] = float(_s["v_sum"]) + speed
	if t > 0.5:
		_s["v_min"] = minf(float(_s["v_min"]), speed)
	var z := float(_race.get("pos_z"))
	var x := float(v.get("x"))
	var gap := INF
	for c in (_race.get("traffic").get("cars") as Array):
		if c.z > z and absf(c.x - x) < (c.width + float(v.get("width_m"))) * 0.5:
			gap = minf(gap, c.z - z - (c.length + float(v.get("length_m"))) * 0.5)
	if gap < float(_s["gap"]):
		_s["gap"] = gap
		_s["gap_t"] = t
	if t <= START_S:
		_s["start_gap"] = minf(float(_s["start_gap"]), gap)


func _end_demo() -> void:
	_in_demo = false
	var id := str(_scene.get("id", "?"))
	var n := maxi(1, int(_s["n"]))
	var stats: Dictionary = _race.get("stats") if _race != null and is_instance_valid(_race) else {}
	var ds: Dictionary = _race.get("drive_stats") if _race != null and is_instance_valid(_race) else {}
	var reason := str(_am.get("last_end_reason"))
	var avg := float(_s["v_sum"]) / float(n)
	var coll := int(stats.get("collisions", -1))
	var rails := int(ds.get("rail_hits", -1))
	var off := float(ds.get("off_road_s", -1.0))
	var ok := reason == "time" and coll == 0 and rails == 0 and off <= 0.0 and float(_s["gap"]) >= MIN_GAP_M \
		and float(_s["start_gap"]) >= START_GAP_M and avg >= MIN_AVG_KMH
	var line := "CHECK %-10s %-7s Ende %s, Ø %.0f km/h (min %.0f), Kollisionen %d, Leitplanke %d, neben der Fahrbahn %.1f s, kleinster Abstand %.1f m (t=%.1f s), in den ersten %.0f s %.1f m" % [
		id, "OK" if ok else "FEHLER", reason, avg, float(_s["v_min"]), coll, rails, off, float(_s["gap"]), float(_s["gap_t"]),
		START_S, float(_s["start_gap"])]
	print(line)
	if not ok:
		_failed.append(id)
	_race = null
	_todo.pop_front()
	if _todo.is_empty():
		_am.set("enabled", false)
		print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(),
			(Time.get_ticks_msec() - _wall0) / 1000.0])
		quit(0 if _failed.is_empty() else 1)
		return
	_next_index = int(_todo[0])
