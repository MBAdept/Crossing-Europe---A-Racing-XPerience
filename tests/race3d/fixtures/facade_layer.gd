extends Node
## Test double of a dynamic layer of the Modern renderer (tests/race3d/check_facade.gd, render checks of the
## skeleton): it has every optional hook of the facade (contract amendment A-7), draws nothing and records what
## the renderer does with it. One script serves every layer id – and the environment rig: the renderer names the
## node after its id ("backdrop", "lights", … / "Environment"), that name is the key of everything recorded.
## Statics, set by the test before a stage starts:
##   pending_frames   id -> number of polls for which prepare_pending() answers 1 (-1 = for ever)
##   fail_after       id -> [polls, reason]: fail_reason() answers `reason` from that poll on
##   warm_meshes      true: warmup_nodes() hands out a lit MeshInstance3D per layer (render checks count its pixels)

static var pending_frames: Dictionary = {}
static var fail_after: Dictionary = {}
static var warm_meshes := false
## Recorded.
static var log: Array[String] = []          ## "<id>.<hook>" in call order (update and prepare_pending only the first time)
static var at_setup: Dictionary = {}        ## id -> what the facade offered in setup()
static var at_update: Dictionary = {}       ## id -> state of the renderer at the first update()
static var at_warmup: Dictionary = {}       ## id -> state of the renderer when warmup_nodes() was asked
static var updates: Dictionary = {}         ## id -> number of update() calls
static var statics: Array = []              ## [id, instance id of the parent, lamps] of add_static()
static var shifts: Array = []               ## [id, shift] of rebased()
static var warm_ids: Array[int] = []        ## instance ids of the warm-up nodes handed out
static var quality_seen: Dictionary = {}    ## id -> levels of apply_quality()
static var ctx_seen: Dictionary = {}        ## id -> ctx of prepare()

var renderer: Node
var id := ""
var _polls := 0
var _fail_polls := 0


static func reset() -> void:
	pending_frames = {}
	fail_after = {}
	warm_meshes = false
	log.clear()
	at_setup = {}
	at_update = {}
	at_warmup = {}
	updates = {}
	statics = []
	shifts = []
	warm_ids.clear()
	quality_seen = {}
	ctx_seen = {}


func setup(p_renderer: Node) -> void:
	renderer = p_renderer
	id = str(name)
	log.append(id + ".setup")
	var layers: Array[String] = []
	for l: String in ["backdrop", "far_ground", "lights", "vehicles", "flares", "weather", "overlay", "post"]:
		if renderer.call("layer", l) != null:
			layers.append(l)
	var path: RoadPath3D = renderer.get("path")
	at_setup[id] = {"layers": layers, "camera": renderer.get("camera") != null, "world": renderer.get("world") != null,
		"streamer": renderer.get("streamer") != null, "materials": renderer.get("materials") != null,
		"chase": renderer.get("chase") != null, "terrain": renderer.get("terrain") != null, "path": path != null,
		"path_ready": path != null and path.is_ready(), "levels": (renderer.get("levels") as Dictionary).has("preset"),
		"prep": (renderer.get("prep") as Dictionary).has("plan"), "in_tree": is_inside_tree(),
		"probe_builder": renderer.call("builder", "facade_probe") != null}


func apply_quality(levels: Dictionary) -> void:
	log.append(id + ".apply_quality")
	quality_seen[id] = levels


func prepare(ctx: Dictionary) -> void:
	log.append(id + ".prepare")
	ctx_seen[id] = ctx


func prepare_pending() -> int:
	_polls += 1
	if _polls == 1:
		log.append(id + ".prepare_pending")
	var n := int(pending_frames.get(id, 0))
	return 1 if n < 0 or _polls <= n else 0


func fail_reason() -> String:
	_fail_polls += 1
	var f: Variant = fail_after.get(id)
	if f is Array and _fail_polls >= int((f as Array)[0]):
		return str((f as Array)[1])
	return ""


func warmup_nodes() -> Array:
	log.append(id + ".warmup_nodes")
	var streamer: ChunkStreamer = renderer.get("streamer")
	at_warmup[id] = {"chunks": streamer.chunk_count(), "pending_chunks": streamer.pending_count(), "updates": int(updates.get(id, 0)),
		"prepared": bool(renderer.call("is_prepared"))}
	var n: Node3D
	if warm_meshes:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.0, 2.0, 2.0)
		mi.mesh = box
		mi.position = Vector3(0.0, 1.0, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.0, 1.0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		n = mi
	else:
		n = Node3D.new()
	n.name = "Warm_" + id
	warm_ids.append(n.get_instance_id())
	return [n]


func update(view: Dictionary, _dt: float) -> void:
	updates[id] = int(updates.get(id, 0)) + 1
	if int(updates[id]) > 1:
		return
	log.append(id + ".update")
	var path: RoadPath3D = renderer.get("path")
	var chase: ChaseCamera3D = renderer.get("chase")
	var camera: Camera3D = renderer.get("camera")
	var streamer: ChunkStreamer = renderer.get("streamer")
	var want := chase.transform(view, path) if path != null and path.is_ready() else Transform3D.IDENTITY
	var others_pending := 0
	for l: String in pending_frames:
		var n := int(pending_frames[l])
		var other: Node = renderer.call("layer", l)
		if other != null and (n < 0 or int(other.get("_polls")) <= n):
			others_pending += 1
	at_update[id] = {"path_ready": path != null and path.is_ready(), "chunks": streamer.chunk_count(),
		"pending_chunks": streamer.pending_count(), "camera_placed": camera.global_transform.origin.distance_to(want.origin) < 0.001,
		"view_is_current": is_same(renderer.get("view"), view), "others_pending": others_pending,
		"visibility": float(renderer.get("visibility_m")) == float(view.get("visibility_m", -1.0))}


func rebased(shift: Vector3) -> void:
	log.append(id + ".rebased")
	shifts.append([id, shift])


func add_static(parent: Node3D, lamps: Array) -> void:
	statics.append([id, parent.get_instance_id(), lamps])


func perf() -> Dictionary:
	return {"instances": 3, "lights_omni": 1 if id == "lights" else 0, "fallback_sets": 2 if id == "vehicles" else 0}


func snapshot() -> Dictionary:
	return {"vehicles": [{"id": id}], "lights": {"omni": 1 if id == "lights" else 0, "pools": 2}, "props": {id: 1}}
