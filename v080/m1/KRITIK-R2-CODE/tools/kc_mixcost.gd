extends SceneTree
## KRITIK-R2-CODE: CPU cost of the mixer for N looping players (Dummy audio driver, real-time mixing thread):
## --kind=ogg (the Vorbis loops of assets/audio/modern/vehicle that AU-R introduced), --kind=wav (mono 16-bit WAV
## loops of the same folder), --kind=none; --n=<players>, --secs=<seconds>. Reads the CPU time of every thread of the
## process from /proc (Linux) before and after and prints the busiest threads (the mixer is the one that grows with n).
##   godot --headless --audio-driver Dummy --path <tree> -s <this> -- --kind=ogg --n=14 --secs=20

var _t0 := 0
var _secs := 20.0
var _start: Dictionary = {}
var _players: Array = []


func _initialize() -> void:
	_setup.call_deferred()


func _setup() -> void:
	await process_frame
	Engine.max_fps = 20
	var args := CliArgs.all()
	var kind := str(args.get("kind", "none"))
	var n := int(args.get("n", 14))
	_secs = float(args.get("secs", 20.0))
	var ogg := ["tyre_asphalt", "tyre_asphalt_b", "wind_low", "wind_low_b", "wind_mid", "wind_mid_b", "wind_high", "wind_high_b",
		"tyre_wet", "tyre_wet_b", "tyre_concrete", "tyre_concrete_b", "wind_buffet", "wind_buffet_b", "tyre_snow", "tyre_snow_b"]
	var wav := ["slab_slow", "slab_fast", "squeal", "scrub", "rail_scrape"]
	for i in n:
		var path := ""
		if kind == "ogg":
			path = "res://assets/audio/modern/vehicle/%s.ogg" % ogg[i % ogg.size()]
		elif kind == "wav":
			path = "res://assets/audio/modern/vehicle/%s.wav" % wav[i % wav.size()]
		else:
			break
		var st: AudioStream = load(path)
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.volume_db = -40.0
		p.pitch_scale = 1.03
		root.add_child(p)
		p.play(0.37 * float(i))
		_players.append(p)
	_start = _threads()
	_t0 = Time.get_ticks_msec()
	print("MIX start kind=%s n=%d" % [kind, _players.size()])


func _threads() -> Dictionary:
	var out := {}
	var d := DirAccess.open("/proc/self/task")
	if d == null:
		return out
	for tid: String in d.get_directories():
		var f := FileAccess.open("/proc/self/task/%s/stat" % tid, FileAccess.READ)
		if f == null:
			continue
		var s := f.get_line()
		var rp := s.rfind(")")
		var name := s.substr(s.find("(") + 1, rp - s.find("(") - 1)
		var parts := s.substr(rp + 2).split(" ")
		# fields after ")": state(0) ppid(1) ... utime(11) stime(12) (0-based in this slice)
		out[tid] = [name, int(parts[11]) + int(parts[12])]
	return out


func _process(_delta: float) -> bool:
	if _t0 == 0 or Time.get_ticks_msec() - _t0 < int(_secs * 1000.0):
		return false
	var end := _threads()
	var wall := float(Time.get_ticks_msec() - _t0) / 1000.0
	var rows: Array = []
	var total := 0
	for tid: String in end:
		var t0 := int((_start.get(tid, ["", 0]) as Array)[1])
		var dt: int = int(end[tid][1]) - t0
		total += dt
		rows.append([dt, tid, str(end[tid][0])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var top: Array = []
	for i in mini(4, rows.size()):
		top.append({"tid": rows[i][1], "name": rows[i][2], "cpu_pct": snappedf(float(rows[i][0]) / wall, 0.01)})
	var playing := 0
	for p: AudioStreamPlayer in _players:
		playing += 1 if p.playing else 0
	print("MIX ", JSON.stringify({"players": _players.size(), "playing": playing, "wall_s": snappedf(wall, 0.01),
		"process_cpu_pct": snappedf(float(total) / wall, 0.01), "top_threads": top}))
	quit(0)
	return true
