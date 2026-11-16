extends ModernRenderer
## Scratch probe of the wave-0 integration (NOT part of the repository): the stub renderer of the core package plus
## the geometry kernel, wired exactly as docs/renderer-modern.md §4.6 and §6.3 describe – path, terrain profile,
## chunk streamer with the builders of the registry (today: the debug road), chase camera. It answers one question
## no single package could: does the kernel run behind the real renderer seam of the race session, and does the
## stage still give the same result (D3 – the kernel forces the track generation ahead)?
## Loaded through RaceRenderers.modern_script by run_stage_probe.gd.

var path: RoadPath3D
var terrain: TerrainProfile
var streamer: ChunkStreamer
var cam_model: ChaseCamera3D
var _p_updates := 0
var _p_update_us := 0
var _p_update_us_max := 0
var _p_first_update_us := -1
var _p_chunks_max := 0
var _p_pending_max := 0
var _p_rebases := 0
var _p_yaw_max := 0.0
var _p_track_window_max := 0
var _p_far_max := 0.0


func prepare(ctx: Dictionary) -> void:
	super.prepare(ctx)
	path = RoadPath3D.new()
	path.setup(track, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
	terrain = TerrainProfile.new()
	var terrain_cfg: Variant = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	terrain.setup(path, track, terrain_cfg if terrain_cfg is Dictionary else {}, scenery_db)
	streamer = ChunkStreamer.new()
	add_child(streamer)
	streamer.setup(path, terrain, track, cfg, levels, bool(ctx.get("sync", false)))
	for b: ChunkBuilder in BuilderRegistry.create_all():
		streamer.register(b)
	streamer.rebased.connect(func(_shift: Vector3) -> void: _p_rebases += 1)
	cam_model = ChaseCamera3D.new()
	var cam_cfg: Variant = ConfigLoader.lookup(cfg, "graphics.modern.camera", {})
	cam_model.setup(proj, cam_cfg if cam_cfg is Dictionary else {})
	_plane.visible = false


func render(view: Dictionary) -> void:
	super.render(view)
	if streamer == null:
		return
	var t0 := Time.get_ticks_usec()
	streamer.update(float(view.get("camera_z", 0.0)), float(view.get("visibility_m", 900.0)))
	var us := Time.get_ticks_usec() - t0
	if _p_first_update_us < 0:
		_p_first_update_us = us
	else:
		_p_update_us += us
		_p_update_us_max = maxi(_p_update_us_max, us)
		_p_updates += 1
	var tr := cam_model.transform(view, path)
	_camera.global_transform = tr
	var fr: Dictionary = cam_model.frustum(_viewport_size(), view.get("shake", Vector2.ZERO))
	_camera.set_frustum(float(fr["size"]), fr["offset"], float(fr["near"]), float(fr["far"]))
	_p_chunks_max = maxi(_p_chunks_max, streamer.chunk_count())
	_p_pending_max = maxi(_p_pending_max, streamer.pending_count())
	_p_yaw_max = maxf(_p_yaw_max, absf(rad_to_deg(cam_model.look_yaw(path, float(view.get("camera_z", 0.0))))))
	_p_far_max = maxf(_p_far_max, tr.origin.length())
	var window: Variant = track.get("_segs")
	if window is Dictionary:
		_p_track_window_max = maxi(_p_track_window_max, (window as Dictionary).size())


func perf_stats() -> Dictionary:
	var s := super.perf_stats()
	var n := maxf(1.0, float(_p_updates))
	s["chunks"] = streamer.chunk_count() if streamer != null else 0
	s["probe"] = {"kernel": true, "updates": _p_updates, "first_update_ms": float(_p_first_update_us) / 1000.0,
		"update_ms_avg": float(_p_update_us) / n / 1000.0, "update_ms_max": float(_p_update_us_max) / 1000.0,
		"chunks_max": _p_chunks_max, "pending_max": _p_pending_max, "rebases": _p_rebases,
		"look_yaw_max_deg": _p_yaw_max, "camera_from_origin_max_m": _p_far_max,
		"track_window_max": _p_track_window_max,
		"builders": streamer.builders().size() if streamer != null else 0,
		"streamer": streamer.stats() if streamer != null else {}}
	return s
