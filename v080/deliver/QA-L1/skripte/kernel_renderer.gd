extends "res://scripts/race3d/modern_renderer.gd"
## QA lens 1 (scratch): the wave-0 stub plus the geometry kernel – path, terrain, threaded streamer with the debug
## road, chase camera – to check D3 behind the real seam: does the stage still give Arcade's result?

var path: RoadPath3D
var terrain: TerrainProfile
var streamer: ChunkStreamer
var cam_model: ChaseCamera3D
var _window_max := 0
var _chunks_max := 0
var _ahead_max := 0.0

func prepare(ctx: Dictionary) -> void:
	super.prepare(ctx)
	path = RoadPath3D.new()
	terrain = TerrainProfile.new()
	terrain.setup(path, track, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), scenery_db)
	streamer = ChunkStreamer.new()
	add_child(streamer)
	streamer.setup(path, terrain, track, cfg, levels, CliArgs.has("gfx-sync"))
	for b: ChunkBuilder in BuilderRegistry.create_all():
		streamer.register(b)
	cam_model = ChaseCamera3D.new()
	cam_model.setup(proj, ConfigLoader.lookup(cfg, "graphics.modern.camera", {}))

func render(view: Dictionary) -> void:
	super.render(view)
	if streamer == null:
		return
	var cam_z := float(view.get("camera_z", 0.0))
	streamer.update(cam_z, float(view.get("visibility_m", 900.0)))
	var extra := CliArgs.get_float("qa-ahead", 0.0)
	if extra > 0.0:
		path.ensure(int((cam_z + extra) / track.seg_len))   # generation forced even farther ahead
	_camera.global_transform = cam_model.transform(view, path)
	_chunks_max = maxi(_chunks_max, streamer.chunk_count())
	_window_max = maxi(_window_max, track.window_size())
	_ahead_max = maxf(_ahead_max, float(path.last()) * track.seg_len - cam_z)

func perf_stats() -> Dictionary:
	var s := super.perf_stats()
	s["qa_kernel"] = {"chunks_max": _chunks_max, "track_window_max": _window_max, "path_ahead_max_m": _ahead_max,
		"streamer": streamer.stats() if streamer != null else {}}
	return s
