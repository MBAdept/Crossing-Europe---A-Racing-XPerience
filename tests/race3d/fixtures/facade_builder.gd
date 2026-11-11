extends ChunkBuilder
## Test double of a chunk builder of the Modern renderer (tests/race3d/check_facade.gd, render checks of the
## skeleton): it has every optional hook of the facade (contract amendment A-7) next to collect / build / commit and
## records what the renderer and the streamer do with it. In commit() it uses the services of the chunk context as a
## real builder does: one static lamp per chunk through renderer.add_lamps() and its one material through
## renderer.add_pool_material(). update() and rebased() exist only to prove that builders never get them.
## Statics, set by the test before a stage starts:
##   builder_id       id() of the builder ("facade_probe"; "terrain" lets it stand for the terrain builder)
##   pending_polls    number of polls for which prepare_pending() answers 1
##   fail_after       [polls, reason]: fail_reason() answers `reason` from that poll on ([] = never)

static var builder_id := "facade_probe"
static var pending_polls := 0
static var fail_after: Array = []
## Recorded. The call order goes into the log of the layer fixture (FacadeLayer.log: "<id>.<hook>", collect and
## commit only the first time), so that one list shows builders and layers together.
static var at_setup: Dictionary = {}
static var services_in_collect: Array = []  ## ctx.services of every collect()
static var services_in_commit: Array = []
static var off_main := 0                    ## collect() / commit() calls that were not on the main thread
static var commits := 0
static var lamp_parents: Array = []         ## instance ids of the nodes the lamps were registered with
static var forbidden := 0                   ## update() / rebased() calls (must stay 0)
static var warm_ids: Array[int] = []
static var material: ShaderMaterial

const FacadeLayer := preload("res://tests/race3d/fixtures/facade_layer.gd")

var renderer: Node
var _main := OS.get_main_thread_id()
var _polls := 0
var _fail_polls := 0
var _mutex := Mutex.new()
var _built := false


static func reset() -> void:
	builder_id = "facade_probe"
	pending_polls = 0
	fail_after = []
	at_setup = {}
	services_in_collect = []
	services_in_commit = []
	off_main = 0
	commits = 0
	lamp_parents = []
	forbidden = 0
	warm_ids.clear()
	material = null


func id() -> String:
	return builder_id


func setup(p_renderer: Node) -> void:
	renderer = p_renderer
	FacadeLayer.log.append(builder_id + ".setup")
	at_setup = {"layers_exist": renderer.call("layer", "post") != null, "streamer": renderer.get("streamer") != null,
		"registered": renderer.call("builder", builder_id) == self, "camera": renderer.get("camera") != null}


func apply_quality(_levels: Dictionary) -> void:
	FacadeLayer.log.append(builder_id + ".apply_quality")


func prepare(_ctx: Dictionary) -> void:
	FacadeLayer.log.append(builder_id + ".prepare")


func prepare_pending() -> int:
	_polls += 1
	if _polls == 1:
		FacadeLayer.log.append(builder_id + ".prepare_pending")
	return 1 if _polls <= pending_polls else 0


func fail_reason() -> String:
	_fail_polls += 1
	if fail_after.size() >= 2 and _fail_polls >= int(fail_after[0]):
		return str(fail_after[1])
	return ""


func warmup_nodes() -> Array:
	FacadeLayer.log.append(builder_id + ".warmup_nodes")
	var n := Node3D.new()
	n.name = "Warm_" + builder_id
	warm_ids.append(n.get_instance_id())
	return [n]


func update(_view: Dictionary, _dt: float) -> void:
	forbidden += 1


func rebased(_shift: Vector3) -> void:
	forbidden += 1


func perf() -> Dictionary:
	return {"instances": 3}


func snapshot() -> Dictionary:
	return {"props": {"probe": commits}, "signs": [{"kind": "probe", "z": 0.0, "x": 0.0}]}


func collect(ctx: ChunkContext) -> Variant:
	if OS.get_thread_caller_id() != _main:
		off_main += 1
	if services_in_collect.is_empty():
		FacadeLayer.log.append(builder_id + ".collect")
	services_in_collect.append(ctx.services)
	return {"rows": ctx.row_count()}


## Worker thread: only the snapshot arrays of the context (never ctx.services).
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	_mutex.lock()
	var first := not _built
	_built = true
	_mutex.unlock()
	var p := ctx.local(float(ctx.seg_a) * ctx.seg_len, 0.0, 0.0)
	return {"rows": int((input as Dictionary)["rows"]), "first": first, "origin": [p.x, p.y, p.z]}


func commit(ctx: ChunkContext, _part: Dictionary, parent: Node3D) -> void:
	if OS.get_thread_caller_id() != _main:
		off_main += 1
	if commits == 0:
		FacadeLayer.log.append(builder_id + ".commit")
	commits += 1
	services_in_commit.append(ctx.services)
	var node := Node3D.new()
	node.name = "FacadeProbe"
	parent.add_child(node)
	var r: Variant = ctx.services.get("renderer")
	if r == null:
		return   # a test without a renderer: no lamp registration, the builder still works
	if material == null:
		material = ShaderMaterial.new()
	(r as Object).call("add_pool_material", material)
	(r as Object).call("add_lamps", node, [{"pos": Vector3(0.0, 8.0, 0.0), "dir": Vector3.DOWN, "role": "street",
		"color": Color(1.0, 0.9, 0.7), "size": 0.6, "range": 9.0, "energy": 1.0}])
	lamp_parents.append(node.get_instance_id())


func debug(part: Dictionary) -> Dictionary:
	return {"rows": int(part.get("rows", 0))}
