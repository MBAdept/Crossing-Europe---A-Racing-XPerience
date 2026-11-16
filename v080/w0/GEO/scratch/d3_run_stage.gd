extends "res://tests/race/run_stage.gd"
## Scratch (GEO, v0.8.0): run_stage with the race3d kernel running beside the Arcade session – does forcing the
## track generation ahead (RoadPath3D / ChunkStreamer, up to ~3.5 km) change the result?
##   --streamer         drive a real ChunkStreamer (debug road, sync) with the session's track every frame
##   --force-ahead=<m>  only force the generation that far ahead of the camera

var _st: ChunkStreamer
var _max_window := 0
var _max_ahead := 0.0


func _process(delta: float) -> bool:
	var done := super._process(delta)
	if _scene == null:
		return done
	var track: Track = _scene.get("track")
	if track == null:
		return done
	var cam_z := float(_scene.get("pos_z")) - 9.0
	if CliArgs.has("force-ahead"):
		track.get_segment(track.segment_index_at(cam_z + CliArgs.get_float("force-ahead", 4000.0)))
	if CliArgs.has("streamer"):
		if _st == null:
			var cfg := ConfigLoader.load_merged()
			var p := RoadPath3D.new()
			var tp := TerrainProfile.new()
			tp.setup(p, track, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), {})
			_st = ChunkStreamer.new()
			_st.setup(p, tp, track, cfg, {}, true)
			_st.register(BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD))
			root.add_child(_st)
		_st.update(cam_z, 900.0)
		_max_ahead = maxf(_max_ahead, float(_st.path.last()) * 3.0 - cam_z)
	_max_window = maxi(_max_window, track.window_size())
	return done


func _report(ok: bool) -> void:
	super._report(ok)
	print("D3 max track window %d segments; path reached up to %.0f m ahead of the camera; streamer %s" % [_max_window, _max_ahead,
		JSON.stringify(_st.stats()) if _st != null else "-"])
