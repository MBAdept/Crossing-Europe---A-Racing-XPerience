extends TestCase
## ChunkStreamer.services / ChunkContext.services (contract amendment A-7): the dictionary the renderer hands to
## the builders – {"renderer", "materials"} – reaches every chunk context in collect() and commit(), on the main
## thread, in sync and in threaded mode; without a renderer it is {} and a builder works without it.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")


## Records the services dictionary every hook of a builder sees; registers a lamp through the renderer if there is one.
class Probe extends ChunkBuilder:
	var main_id := OS.get_main_thread_id()
	var mutex := Mutex.new()
	var in_collect: Array = []
	var in_commit: Array = []
	var off_main := 0
	var builds := 0
	var without := 0                   ## commits that found no renderer and went on without it

	func id() -> String:
		return "services_probe"

	func collect(ctx: ChunkContext) -> Variant:
		if OS.get_thread_caller_id() != main_id:
			off_main += 1
		in_collect.append(ctx.services)
		return null

	func build(_ctx: ChunkContext, _input: Variant) -> Dictionary:
		mutex.lock()
		builds += 1
		mutex.unlock()
		return {}

	func commit(ctx: ChunkContext, _part: Dictionary, parent: Node3D) -> void:
		if OS.get_thread_caller_id() != main_id:
			off_main += 1
		in_commit.append(ctx.services)
		var renderer: Variant = ctx.services.get("renderer")
		if renderer == null:
			without += 1
			return
		(renderer as Object).call("add_lamps", parent, [{"pos": Vector3.ZERO, "role": "street"}])


## Stands for the renderer: counts what the builders register.
class FakeRenderer extends RefCounted:
	var lamps := 0
	var parents: Array = []

	func add_lamps(parent: Node3D, lamps_in: Array) -> void:
		lamps += lamps_in.size()
		parents.append(parent.name)


func _streamer(sync: bool, probe: ChunkBuilder) -> ChunkStreamer:
	var n := 1600
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = 0.4 * sin(float(i) * 0.013)
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves)
	var p := RoadPath3D.new()
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg(), "graphics.modern.terrain", {}), {})
	var st := ChunkStreamer.new()
	st.setup(p, tp, t, cfg(), {}, sync)
	st.register(probe)
	return st


func test_context_has_empty_services_by_default() -> void:
	assert_eq(ChunkContext.new().services, {}, "ChunkContext.services ohne Renderer")
	var st := ChunkStreamer.new()
	assert_eq(st.services, {}, "ChunkStreamer.services ohne Renderer")
	st.free()


func test_without_renderer_builders_get_an_empty_dictionary() -> void:
	var probe := Probe.new()
	var st := _streamer(true, probe)
	st.update(300.0, 600.0)
	assert_true(st.chunk_count() >= 4 and st.pending_count() == 0, "Stücke geladen (%d)" % st.chunk_count())
	assert_eq(probe.in_collect.size(), st.chunk_count(), "collect() je Stück")
	assert_eq(probe.in_commit.size(), st.chunk_count(), "commit() je Stück")
	for s: Variant in probe.in_collect + probe.in_commit:
		assert_true(s is Dictionary and (s as Dictionary).is_empty(), "services ist {} ohne Renderer")
	assert_eq(probe.without, st.chunk_count(), "der Builder arbeitet ohne Renderer weiter")
	st.clear()
	st.free()


func test_services_reach_collect_and_commit_on_the_main_thread() -> void:
	for sync: bool in [true, false]:
		var probe := Probe.new()
		var st := _streamer(sync, probe)
		var renderer := FakeRenderer.new()
		var mats := RefCounted.new()
		st.services = {"renderer": renderer, "materials": mats}
		var cam_z := 100.0
		while cam_z < 1500.0:
			st.update(cam_z, 600.0)
			cam_z += 30.0
		st.flush()
		assert_true(st.is_idle() and probe.builds >= 8, "%s: Stücke gebaut (%d)" % ["sync" if sync else "threaded", probe.builds])
		assert_eq(probe.in_collect.size(), probe.builds, "collect() je gebautem Stück")
		assert_eq(probe.in_commit.size(), probe.builds, "commit() je gebautem Stück")
		for s: Variant in probe.in_collect + probe.in_commit:
			assert_true(is_same(s, st.services), "dasselbe Wörterbuch wie ChunkStreamer.services")
			assert_true((s as Dictionary).get("renderer") == renderer and (s as Dictionary).get("materials") == mats, "renderer und materials")
		assert_eq(probe.off_main, 0, "collect() und commit() im Hauptthread")
		assert_eq(renderer.lamps, probe.builds, "commit() erreicht den Renderer über ctx.services (add_lamps)")
		assert_true(renderer.parents.size() > 0 and str(renderer.parents[0]).begins_with("Chunk"), "mit dem Stückknoten als parent")
		assert_eq(probe.without, 0, "kein Stück ohne Renderer")
		st.clear()
		st.free()


## setup() of the streamer keeps the services: the renderer may set them before or after.
func test_services_survive_setup() -> void:
	var probe := Probe.new()
	var st := _streamer(true, probe)
	var marker := {"renderer": FakeRenderer.new()}
	st.services = marker
	st.setup(st.path, st.terrain, st.track, cfg(), {}, true)
	st.register(probe)
	st.update(200.0, 500.0)
	assert_true(not probe.in_commit.is_empty() and is_same(probe.in_commit[0], marker), "services nach setup() noch gesetzt")
	st.clear()
	st.free()
