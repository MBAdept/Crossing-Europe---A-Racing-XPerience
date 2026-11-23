extends SceneTree
## FIX-R7a probe (headless): the threaded ChunkStreamer with the real props, city and terrain builders on a stage,
## frame by frame (camera 1.2 m per frame): does a frame that commits (any commit time, also a step of a chunk that
## is committed over several frames) also warm the sight corridor? Counts frames with warm, with commit, with both,
## and the corridor's main-thread time. Runs in whichever tree it is started in (FIX-R7a alone or merged with FIX-RINT).
##   godot --headless --path . -s <this> [-- --stage=<dir> --frames=<n> --from-km=<km>]
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const CityB := preload("res://scripts/race3d/builders/city.gd")
const TerrB := preload("res://scripts/race3d/builders/terrain.gd")

var st: ChunkStreamer
var t: Track
var cam := 0.0
var frame := 0
var frames := 3000
var last_commit_us := 0
var last_warm := 0
var n_warm := 0
var n_commit := 0
var n_both := 0
var both_us_max := 0.0
var t_frame_max := 0.0


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var name := "saragossa_pau__saragossa"
	var from_km := 160.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			name = a.substr(8)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
		elif a.begins_with("--from-km="):
			from_km = float(a.substr(10))
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	for dir: Dictionary in Fair.directions(net, []):
		if str(dir["name"]) != name:
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		t = Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		var tp := TerrainProfile.new()
		tp.setup(p, t, tc, net["scenery"])
		st = ChunkStreamer.new()
		st.setup(p, tp, t, cfg, {}, false)
		st.register(TerrB.new())
		st.register(Props.new())
		st.register(CityB.new())
		cam = t.km_to_z(from_km)
		st.update(cam, 900.0)      # load at once
		st.reset_stats()
		last_commit_us = int(st.get("_commit_us_sum"))
		last_warm = int(st.get("_warm_calls"))
		print("PROBE %s from km %.1f, %d frames" % [name, from_km, frames])
		return
	print("PROBE stage not found")
	quit(1)


func _process(_delta: float) -> bool:
	if st == null:
		return true
	var t0 := Time.get_ticks_usec()
	cam += 1.2
	st.update(cam, 900.0)
	var us := float(Time.get_ticks_usec() - t0) / 1000.0
	t_frame_max = maxf(t_frame_max, us)
	var cu := int(st.get("_commit_us_sum"))
	var wc := int(st.get("_warm_calls"))
	var committed := cu != last_commit_us
	var warmed := wc != last_warm
	if committed:
		n_commit += 1
	if warmed:
		n_warm += 1
	if committed and warmed:
		n_both += 1
		both_us_max = maxf(both_us_max, us)
	last_commit_us = cu
	last_warm = wc
	frame += 1
	if frame >= frames:
		var s := st.stats()
		print("PROBE frames %d: warm %d, commit %d, both %d (longest such update %.2f ms); longest update %.2f ms" % [
			frame, n_warm, n_commit, n_both, both_us_max, t_frame_max])
		print("PROBE corridor %s" % str(s.get("corridor", {})))
		print("PROBE streamer commit_ms_max %.2f collect_ms_max %.2f commits %d %s" % [float(s["commit_ms_max"]), float(s["collect_ms_max"]),
			int(s["commits"]), ("commit_steps %d" % int(s["commit_steps"])) if s.has("commit_steps") else ""])
		st.clear()
		st.free()
		st = null
		quit(0)
	return false
