extends Node3D
## Test double of the Modern renderer for tests/race3d/check_seam.gd: it implements the renderer interface of the
## seam (docs/dev/v080_contract.md §4.4.1), draws nothing and records what the race session does with it – the
## order of the calls, the crash-guard marker at its creation, the contexts it gets, how many views arrive before
## it is prepared. The test sets how many frames the preparation takes and whether (and when) it fails.
## RaceRenderers.modern_script points here while the test runs.

signal quality_lowered(preset: String)

## Set by the test before a stage starts.
static var marker_path := ""
static var prepare_frames := 6
static var fail_at_frame := -1          ## preparation frame from which healthy() is false (-1 = never)
static var fail_text := "shader"
## Recorded.
static var log: Array[String] = []
static var marker_at_init := false
static var instances := 0
static var levels_seen: Dictionary = {}
static var ctx_seen: Dictionary = {}
static var views_before_prepared := 0
static var views_after_prepared := 0
static var last_view: Dictionary = {}

var _frame := -1
var _prepared := false
var _failed := false


static func reset() -> void:
	log.clear()
	marker_at_init = false
	instances = 0
	levels_seen = {}
	ctx_seen = {}
	views_before_prepared = 0
	views_after_prepared = 0
	last_view = {}


func _init() -> void:
	instances += 1
	marker_at_init = marker_path != "" and FileAccess.file_exists(marker_path)
	log.append("init")


func setup(_track: Object, _proj: Object, _cfg: Dictionary, _scenery_db: Dictionary) -> void:
	log.append("setup")


func apply_quality(levels: Dictionary) -> void:
	levels_seen = levels
	log.append("apply_quality")


func prepare(ctx: Dictionary) -> void:
	ctx_seen = ctx
	_frame = 0
	log.append("prepare")


func _process(_delta: float) -> void:
	if _frame < 0 or _prepared or _failed:
		return
	_frame += 1
	if fail_at_frame >= 0 and _frame >= fail_at_frame:
		_failed = true
	elif _frame >= prepare_frames:
		_prepared = true
		log.append("prepared")


func is_prepared() -> bool:
	return _prepared


func prepare_progress() -> float:
	return clampf(float(maxi(_frame, 0)) / float(maxi(prepare_frames, 1)), 0.0, 1.0)


func healthy() -> bool:
	return not _failed


func fail_reason() -> String:
	return fail_text if _failed else ""


func render(view: Dictionary) -> void:
	last_view = view
	if _prepared:
		views_after_prepared += 1
	else:
		views_before_prepared += 1


func perf_stats() -> Dictionary:
	return {"mode": "modern", "preset": str(levels_seen.get("preset", ""))}


func debug_snapshot() -> Dictionary:
	return {"camera": {}, "chunks": [], "vehicles": [], "lights": {}, "props": {}, "signs": [], "quality": levels_seen}


func world_to_screen(_z: float, _x: float, _h: float) -> Vector3:
	return Vector3.ZERO


func _exit_tree() -> void:
	log.append("exit")
