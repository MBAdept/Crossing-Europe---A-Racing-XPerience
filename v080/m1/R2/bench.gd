extends SceneTree
## Scratch bench of package R2: a Modern stage driven by the autopilot for N seconds (headless or under Xvfb);
## prints perf_stats() of the renderer.  godot [--headless] --path . --fixed-fps 60 -s bench.gd -- --graphics=modern
##   [--where=S1|S3|C1|T4] [--secs=20] [--gfx-preset=medium] [--no-sync]

const RACE := "res://scenes/race/race.tscn"
const WHERE := {
	"S1": ["kiel_hamburg", "kiel", 2.0, 12.0, "limousine", 11],
	"S3": ["kiel_hamburg", "kiel", 60.0, 12.0, "limousine", 11],
	"S4": ["kiel_hamburg", "kiel", 80.0, 12.0, "limousine", 11],
	"C1": ["dortmund_frankfurt", "dortmund", 216.0, 19.5, "sportwagen", 15],
	"T1": ["kassel_wuerzburg", "kassel", 46.0, 15.0, "kombi", 12],
	"T4": ["saragossa_pau", "saragossa", 197.0, 11.0, "kompakt", 4],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cli := CliArgs.all()
	var where := str(cli.get("where", "S1"))
	var secs := float(cli.get("secs", 20.0))
	var w: Array = WHERE[where]
	var setup := {"mode": "single", "race_id": "", "stage_id": str(w[0]), "from_city": str(w[1]), "vehicle": str(w[4]),
		"start_world_minutes": float(w[3]) * 60.0, "weather": str(cli.get("weather", "normal")), "start_km": float(w[2]), "autopilot": true,
		"seed": int(w[5]), "gfx": "modern", "no_countdown": true, "start_speed": 120.0}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var r: Node = sc.get("renderer")
	var t0 := Time.get_ticks_msec()
	while not bool(r.call(&"is_prepared")):
		await process_frame
	var prep := Time.get_ticks_msec() - t0
	var frames := int(secs * 60.0)
	var wall := Time.get_ticks_msec()
	for i in frames:
		await process_frame
	wall = Time.get_ticks_msec() - wall
	var ps: Dictionary = r.call(&"perf_stats")
	var snap: Dictionary = r.call(&"debug_snapshot")
	var props := 0
	for k: String in (snap.get("props", {}) as Dictionary):
		props += int(snap["props"][k])
	print("BENCH %s %s: prepare %d ms, %d frames in %d ms (%.2f ms/frame wall), render() avg %.3f ms max %.2f ms, chunks %d, build avg %.2f max %.2f ms, commit max %.2f ms, draw calls %d (+%d shadow), primitives %d (+%d shadow), instances %d, props in view %d, fallback sets %d, tex %.1f MB" % [
		where, str(ps.get("preset", "")), prep, frames, wall, float(wall) / float(frames), float(ps["render_ms_avg"]), float(ps["render_ms_max"]), int(ps["chunks"]),
		float(ps["chunk_build_ms_avg"]), float(ps["chunk_build_ms_max"]), float(ps["chunk_commit_ms_max"]), int(ps["draw_calls"]), int(ps["draw_calls_shadow"]),
		int(ps["primitives"]), int(ps["primitives_shadow"]), int(ps.get("instances", 0)), props, int(ps.get("fallback_sets", 0)), float(ps.get("tex_mem_mb", 0.0))])
	var st: Dictionary = ps.get("streamer", {})
	print("BENCH streamer: collect avg %.2f max %.2f ms, commit avg %.2f ms, builds %d; km %.1f" % [float(st.get("collect_ms_avg", 0.0)), float(st.get("collect_ms_max", 0.0)),
		float(st.get("commit_ms_avg", 0.0)), int(st.get("builds", 0)), float((sc.get("track") as Track).z_to_km(float(snap["camera"]["z"])))])
	sc.queue_free()
	await process_frame
	await process_frame
	ModelDB.release_all()
	ModernMaterials.drop_shared()
	quit(0)
