extends SceneTree
## Probe (RINT-B, M2INT: stage arguments): texture memory of a race in one mode (contract A-6: Modern <= Arcade of the
## same stage + 60 MB). Run under Xvfb:
##   godot --path . --rendering-driver opengl3 ... -s <this> -- --mode=arcade|modern [--stage=..] [--from=..] [--km=2]
##       [--hour=12] [--secs=12]
## Prints "TEXMEM {...}" with the engine monitors after the stage has run `secs` seconds (and the peak while running),
## the renderer's tex_mem_mb and the stand-in sheets of the vehicle layer.

var _sc: Node
var _t0 := -1.0
var _peak_tex := 0.0
var _peak_vid := 0.0
var _secs := 12.0
var _mode := "modern"
var _stage := "kiel_hamburg"


func _initialize() -> void:
	var km := 2.0
	var from := "kiel"
	var hour := 12.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			_mode = a.substr(7)
		elif a.begins_with("--secs="):
			_secs = float(a.substr(7))
		elif a.begins_with("--km="):
			km = float(a.substr(5))
		elif a.begins_with("--stage="):
			_stage = a.substr(8)
		elif a.begins_with("--from="):
			from = a.substr(7)
		elif a.begins_with("--hour="):
			hour = float(a.substr(7))
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": _stage, "from_city": from, "vehicle": "limousine",
		"start_world_minutes": hour * 60.0, "weather": "normal", "start_km": km, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "gfx": _mode, "no_countdown": true, "start_speed_kmh": 100.0, "traffic_warmup": true}
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _process(_dt: float) -> bool:
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if _t0 < 0.0:
		_t0 = now
	var tex := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var vid := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	_peak_tex = maxf(_peak_tex, tex)
	_peak_vid = maxf(_peak_vid, vid)
	if now - _t0 >= _secs:
		var r: Variant = _sc.get("renderer")
		var ps: Dictionary = (r as Object).call("perf_stats") if r is Object and (r as Object).has_method("perf_stats") else {}
		print("TEXMEM " + JSON.stringify({"mode": _mode, "stage": _stage, "tex_mb": snappedf(tex, 0.1), "vid_mb": snappedf(vid, 0.1),
			"peak_tex_mb": snappedf(_peak_tex, 0.1), "peak_vid_mb": snappedf(_peak_vid, 0.1),
			"renderer_tex_mem_mb": ps.get("tex_mem_mb", -1), "standin_sheets_mb": ps.get("standin_sheets_mb", -1),
			"standin_sheets": ps.get("standin_sheets", -1), "fallback_sets": ps.get("fallback_sets", -1),
			"draw_calls": ps.get("draw_calls", -1), "primitives": ps.get("primitives", -1),
			"gfx": str(_sc.get("gfx_mode")) if _sc.get("gfx_mode") != null else ""}))
		return true
	return false
