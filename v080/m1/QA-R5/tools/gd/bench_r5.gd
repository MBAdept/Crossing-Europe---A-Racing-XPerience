extends SceneTree
## QA-R5 micro benchmark (not part of the project): CPU time per chunk of builders/bridge.gd and builders/tunnel.gd
## (collect on the main thread, build on a worker in the game – timed here on the main thread, commit on the main
## thread) and of layers/far_ground.gd when a river enters the window. Minimum of REPEAT runs (load-robust, A-11).
## Runs in the R5 tree and in the base tree (there: tunnel only – the base has no bridge builder and no rivers).
##   godot --headless --path <tree> -s res://tests/qa_r5/bench_r5.gd

const REPEAT := 3
const BRIDGES := [["kiel_hamburg", "kiel", "Köhlbrandbrücke"], ["kiel_hamburg", "kiel", "Elbbrücken"],
	["rostock_kiel", "rostock", "Holtenauer Hochbrücke"], ["frankfurt_koeln", "frankfurt", "Severinsbrücke"],
	["kassel_wuerzburg", "kassel", "Ludwigsbrücke"], ["mailand_venedig", "mailand", "Ponte della Libertà"],
	["slavonski_brod_belgrad", "slavonski_brod", "Ada-Brücke"]]
const TUNNELS := [["bern_mailand", "bern", "Gotthard-Strassentunnel"], ["saragossa_pau", "saragossa", "Somport-Tunnel"]]


class FakeRenderer extends Node:
	var cfg: Dictionary = {}
	var track: Track
	var path: RoadPath3D
	var camera: Camera3D
	var scenery_db: Dictionary = {}
	var world: Node3D
	var materials: Variant = null
	var builders: Dictionary = {}

	func builder(id: String) -> Object:
		return builders.get(id)


var _cfg: Dictionary
var _net: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _track(stage_id: String, from_id: String) -> Track:
	var Fair: GDScript = load("res://tests/race3d/fairness.gd")
	for dir: Dictionary in Fair.call("directions", _net, [stage_id]):
		if str(dir["from"]) == from_id:
			var plan := StagePlan.build(dir["stage"], from_id, _net["cities"], _net["countries"], _cfg, _net["city_db"])
			var t := Track.new()
			t.setup(plan, _cfg, _net["scenery"])
			return t
	return null


func _path(t: Track) -> Array:
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(_cfg, "road.curve_radius_at_1_m", 120.0)))
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(_cfg, "graphics.modern.terrain", {}), _net["scenery"])
	p.set_clear_reach(1842.0)
	return [p, tp]


func _ctx(t: Track, p: RoadPath3D, tp: TerrainProfile, ci: int) -> ChunkContext:
	p.ensure(mini((ci + 1) * 32 + 700, t.segment_count - 1))
	var ctx := ChunkContext.new()
	ctx.cfg = _cfg
	ctx.scenery_db = _net["scenery"]
	ctx.levels = {"shadow_casters": 2, "details": 1}
	ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
	return ctx


## [collect, build, commit] ms (minimum of REPEAT) for one chunk.
func _time_chunk(b: Object, ctx: ChunkContext) -> Array:
	var best := [INF, INF, INF]
	for r in REPEAT:
		var t0 := Time.get_ticks_usec()
		var inp: Variant = b.call("collect", ctx)
		var t1 := Time.get_ticks_usec()
		var part: Dictionary = b.call("build", ctx, inp)
		var t2 := Time.get_ticks_usec()
		var holder := Node3D.new()
		get_root().add_child(holder)
		b.call("commit", ctx, part, holder)
		var t3 := Time.get_ticks_usec()
		holder.queue_free()
		best[0] = minf(best[0], (t1 - t0) / 1000.0)
		best[1] = minf(best[1], (t2 - t1) / 1000.0)
		best[2] = minf(best[2], (t3 - t2) / 1000.0)
		await process_frame
	return best


func _run() -> void:
	_cfg = ConfigLoader.load_merged()
	_net = (load("res://tests/race3d/fairness.gd") as GDScript).call("load_network")
	var has_bridge := FileAccess.file_exists("res://scripts/race3d/builders/bridge.gd")
	var TunnelB: GDScript = load("res://scripts/race3d/builders/tunnel.gd")
	for want: Array in TUNNELS:
		var t := _track(want[0], want[1])
		var tu: Dictionary = {}
		for x: Dictionary in t.plan.tunnels:
			if str(x["name"]) == str(want[2]):
				tu = x
		var pt := _path(t)
		var zp := t.km_to_z(float(tu["start_km"]))
		var c0 := int(floor(zp / t.seg_len / 32.0))
		var b: Object = TunnelB.new()
		var worst := [0.0, 0.0, 0.0]
		var tot := [0.0, 0.0, 0.0]
		var n := 0
		for ci in range(c0 - 1, c0 + 5):
			var ctx := _ctx(t, pt[0], pt[1], ci)
			var ms: Array = await _time_chunk(b, ctx)
			for k in 3:
				worst[k] = maxf(worst[k], float(ms[k]))
				tot[k] += float(ms[k])
			n += 1
			print("BENCH tunnel %s chunk %d: collect %.2f build %.2f commit %.2f ms" % [want[2], ci, ms[0], ms[1], ms[2]])
		print("BENCH-SUM tunnel %s: max collect %.2f build %.2f commit %.2f ms; mean build %.2f commit %.2f" % [want[2], worst[0], worst[1], worst[2], tot[1] / n, tot[2] / n])
	if not has_bridge:
		print("BENCH no bridge builder in this tree")
		quit(0)
		return
	var BridgeB: GDScript = load("res://scripts/race3d/builders/bridge.gd")
	var FarG: GDScript = load("res://scripts/race3d/layers/far_ground.gd")
	for want: Array in BRIDGES:
		var t := _track(want[0], want[1])
		var br: Dictionary = {}
		var bi := -1
		for i in t.bridges.size():
			if str(t.bridges[i]["name"]) == str(want[2]):
				br = t.bridges[i]
				bi = i
		if br.is_empty():
			print("BENCH missing %s" % want[2])
			continue
		var pt := _path(t)
		var b: Object = BridgeB.new()
		var c0 := int(floor(float(br["z0"]) / t.seg_len / 32.0))
		var c1 := int(floor(float(br["z1"]) / t.seg_len / 32.0))
		var worst := [0.0, 0.0, 0.0]
		for ci in range(c0, c1 + 1):
			var ctx := _ctx(t, pt[0], pt[1], ci)
			var ms: Array = await _time_chunk(b, ctx)
			for k in 3:
				worst[k] = maxf(worst[k], float(ms[k]))
			print("BENCH bridge %s chunk %d: collect %.2f build %.2f commit %.2f ms" % [want[2], ci, ms[0], ms[1], ms[2]])
		print("BENCH-SUM bridge %s: max collect %.2f build %.2f commit %.2f ms" % [want[2], worst[0], worst[1], worst[2]])
		# far ground: the frame in which the river enters the window (fresh layer each time)
		var best := INF
		var best_all := INF
		for r in REPEAT:
			var fr := FakeRenderer.new()
			fr.cfg = _cfg
			fr.track = t
			fr.path = pt[0]
			fr.camera = Camera3D.new()
			fr.scenery_db = _net["scenery"]
			fr.world = Node3D.new()
			get_root().add_child(fr.world)
			fr.builders["bridge"] = BridgeB.new()
			var fg: Node3D = FarG.new()
			fg.call("setup", fr)
			var cam_z := float(br["z0"]) - 900.0
			(pt[0] as RoadPath3D).ensure(mini(int((float(br["z1"]) + 2000.0) / t.seg_len), t.segment_count - 1))
			var t0 := Time.get_ticks_usec()
			fg.call("update_rivers", pt[0], t, cam_z, 900.0, 0.0)
			var t1 := Time.get_ticks_usec()
			best = minf(best, (t1 - t0) / 1000.0)
			# the whole update hook at that position (target height, rivers, land)
			var fg2: Node3D = FarG.new()
			fg2.call("setup", fr)
			var t2 := Time.get_ticks_usec()
			fg2.call("update_rivers", pt[0], t, cam_z, 900.0, 0.0)
			fg2.call("target_height", pt[0], t, cam_z, 900.0)
			var t3 := Time.get_ticks_usec()
			best_all = minf(best_all, (t3 - t2) / 1000.0)
			var rivers: Dictionary = fg.get("_rivers")
			if r == 0:
				print("BENCH far_ground %s: rivers built %d, land %s" % [want[2], rivers.size(), str(fg.get("land_y"))])
			fg.free()
			fg2.free()
			fr.world.queue_free()
			fr.camera.free()
			fr.free()
			await process_frame
		print("BENCH-SUM far_ground %s: update_rivers (build) min %.2f ms, with target_height %.2f ms" % [want[2], best, best_all])
	ModernMaterials.drop_shared()
	quit(0)
