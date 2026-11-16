extends SceneTree
## QA attacks B-D (headless): corrupt files, thread loading (request / pending), release_all and reload.
## --corrupt=<dir with manifest.json and corrupt .res>

var _n_ok := 0
var _n_bad := 0

func _arg(key: String, default: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return default


func _say(ok: bool, text: String) -> void:
	if ok:
		_n_ok += 1
	else:
		_n_bad += 1
	print("%s %s" % ["  ok   " if ok else "  FAIL ", text])


func _wait(max_polls: int = 4000) -> int:
	var guard := 0
	while ModelDB.pending() > 0 and guard < max_polls:
		OS.delay_msec(2)
		guard += 1
	return guard


func _initialize() -> void:
	print("== D1 request of every set with a model, all levels")
	ModelDB.load_manifest()
	var with_model: Array = []
	for sid in ModelDB.set_ids():
		if ModelDB.has_model(sid):
			with_model.append(sid)
	_say(ModelDB.loads == 0, "nothing loaded before the request (loads %d)" % ModelDB.loads)
	var t0 := Time.get_ticks_usec()
	ModelDB.request(with_model)
	var t1 := Time.get_ticks_usec()
	var p0 := ModelDB.pending()
	var polls := _wait()
	var t2 := Time.get_ticks_usec()
	print("   request() took %.2f ms, pending right after: %d, done after %d polls / %.1f ms, loads %d" % [(t1 - t0) / 1000.0, p0, polls, (t2 - t1) / 1000.0, ModelDB.loads])
	_say(ModelDB.pending() == 0, "pending() reaches 0")
	var files := {}
	for mid in ModelDB.model_ids():
		for f in ModelDB.files_of(mid):
			files[f] = true
	_say(ModelDB.loads == files.size(), "loads %d == files of all models %d" % [ModelDB.loads, files.size()])
	var before := ModelDB.loads
	var all_there := true
	for f: String in files:
		if f.ends_with(".res"):
			if ModelDB.mesh(f) == null:
				all_there = false
		elif ModelDB.texture(f) == null:
			all_there = false
	_say(all_there, "every mesh and texture is there")
	_say(ModelDB.loads == before, "mesh()/texture() after pending()==0 load nothing more")
	var tex := ModelDB.texture("props/farmhouse/albedo.png")
	print("   farmhouse albedo: %s %dx%d" % [tex.get_class() if tex != null else "null", tex.get_width() if tex != null else 0, tex.get_height() if tex != null else 0])

	print("== D2 request twice, request of stand-ins, unknown sets, forced level")
	ModelDB.release_all()
	_say(ModelDB.loads == 0, "release_all() resets loads")
	ModelDB.request(["traffic/sedan_red", "traffic/sedan_red", "traffic/sedan_blue"], ["lod2"])
	ModelDB.request(["traffic/sedan_red"], ["lod2"])
	_wait()
	_say(ModelDB.loads == 1, "one file for lod2 of the sedan, asked four times (loads %d)" % ModelDB.loads)
	ModelDB.request(["police/de", "props/ferry_ship", "gibt/es_nicht", "ui/icon_fuel"], [])
	_say(ModelDB.pending() == 0 and ModelDB.loads == 1, "stand-ins and unknown sets request nothing")
	ModelDB.release_all()
	ModelDB.request(["showroom/limousine"], ["lod0"])
	_wait()
	var show_loaded := ModelDB._meshes.has("player/limousine/show_body.res")
	var lod0_loaded := ModelDB._meshes.has("player/limousine/lod0_body.res")
	print("   showroom/limousine with lods=[lod0]: show_body cached %s, lod0_body cached %s, loads %d" % [str(show_loaded), str(lod0_loaded), ModelDB.loads])
	ModelDB.release_all()
	ModelDB.request(["showroom/limousine"], [])
	_wait()
	print("   showroom/limousine with lods=[]: loads %d (all levels)" % ModelDB.loads)
	ModelDB.release_all()
	ModelDB.request(["props/tree_oak"], ["lod1"])
	_wait()
	print("   props/tree_oak with lods=[lod1]: loads %d, cached %s, textures %s" % [ModelDB.loads, str(ModelDB._meshes.keys()), str(ModelDB._textures.keys())])
	_say(not ModelDB._meshes.has("props/tree_oak/shadow.res"), "the shadow caster is not loaded unless 'shadow' is asked")

	print("== D3 mesh() while its threaded load is still running")
	ModelDB.release_all()
	ModelDB.request(["player/limousine"], ["show"])
	var pend := ModelDB._pending.size()
	var m := ModelDB.mesh("player/limousine/show_body.res")
	_say(m != null and m.get_surface_count() == 2, "mesh() of a pending file waits and returns it (pending before: %d)" % pend)
	_wait()
	_say(ModelDB.pending() == 0, "pending 0 afterwards")

	print("== C1 release_all() while loads are pending, then use again")
	ModelDB.release_all()
	ModelDB.request(with_model)
	var pn := ModelDB._pending.size()
	ModelDB.release_all()
	_say(ModelDB.pending() == 0 and ModelDB.loads == 0 and ModelDB._meshes.is_empty(), "release_all() with %d pending loads: nothing pending, caches empty" % pn)
	var l0 := ModelDB.loads
	var m2 := ModelDB.mesh("traffic/sedan/lod0_body.res")
	_say(m2 != null, "mesh() works after release_all()")
	print("   NOTE a request() made by a new owner before an old owner's release_all() is gone: pending()==0, loads %d -> %d: the file was loaded synchronously by mesh()" % [l0, ModelDB.loads])

	print("== C2 resources are really freed after release_all()")
	var wr: WeakRef = weakref(m2)
	var wr_tex: WeakRef = weakref(ModelDB.texture("landmarks/michel/albedo.webp"))
	m2 = null
	m = null
	tex = null
	ModelDB.release_all()
	_say(wr.get_ref() == null, "the mesh is freed once ModelDB and the caller dropped it")
	_say(wr_tex.get_ref() == null, "the texture is freed once ModelDB dropped it")

	print("== C3 release_all() leaves materials on meshes that nodes still hold")
	var mats := ModernMaterials.new()
	var car := ModelFactory.build("traffic/sedan_red", "lod0", mats)
	var body_mesh: ArrayMesh = (car.get_node("body") as MeshInstance3D).mesh
	_say(body_mesh.surface_get_material(0) != null, "build() set the class material on the shared mesh")
	ModelDB.release_all()
	mats.clear()
	var again := ModelDB.mesh("traffic/sedan/lod0_body.res")
	_say(again == body_mesh, "while a node holds the mesh, a reload gives the same object back")
	_say(again.surface_get_material(0) != null, "... and it still carries the material of the dropped ModernMaterials instance (stale material)")
	var mats2 := ModernMaterials.new()
	var car2 := ModelFactory.build("traffic/sedan_blue", "lod0", mats2)
	var same := (car2.get_node("body") as MeshInstance3D).mesh.surface_get_material(0) == mats2.material("vpbr")
	_say(same, "a second ModernMaterials instance replaces the material on the shared mesh")
	var first_now := (car.get_node("body") as MeshInstance3D).mesh.surface_get_material(0) == mats2.material("vpbr")
	print("   NOTE the first car (built with the first instance) now draws with the second instance's material: %s" % str(first_now))
	car.free()
	car2.free()
	again = null
	body_mesh = null
	ModelDB.release_all()

	print("== C4 load_manifest(fixture) and back")
	var fx := _arg("corrupt", "")
	_say(ModelDB.load_manifest(fx.path_join("manifest.json")), "fixture manifest loads")
	print("== B corrupt files (fixture %s)" % fx)
	for f: String in ["traffic/sedan/lod0_body.res", "props/streetlight/lod0_body.res", "props/farmhouse/lod0_body.res", "traffic/sedan/lod1_body.res"]:
		var mm := ModelDB.mesh(f)
		print("   mesh(%s) -> %s" % [f, "null" if mm == null else "ArrayMesh with %d surfaces" % mm.get_surface_count()])
	var node := ModelFactory.build("traffic/sedan_red", "lod0", null)
	var kids: Array = []
	if node != null:
		for c in node.get_children():
			kids.append(str(c.name))
		node.free()
	print("   build(traffic/sedan_red, lod0) with a truncated body file -> %s" % str(kids))
	var node2 := ModelFactory.build("props/streetlight", "lod0", null)
	print("   build(props/streetlight) with a garbage file -> %s" % ("null" if node2 == null else "node with %d children" % node2.get_child_count()))
	if node2 != null:
		node2.free()
	ModelDB.release_all()
	ModelDB.request(["traffic/sedan_red", "props/streetlight", "props/farmhouse"], ["lod0"])
	var polls2 := _wait()
	print("   request() of corrupt files: pending %d after %d polls, loads %d" % [ModelDB.pending(), polls2, ModelDB.loads])
	var t := ModelDB.texture("props/farmhouse/albedo.png")
	print("   fixture texture outside the import system: %s" % ("null" if t == null else "%s %dx%d mipmaps %s" % [t.get_class(), t.get_width(), t.get_height(), str(t.get_image().has_mipmaps())]))
	_say(ModelDB.load_manifest(), "back to the shipped manifest")
	_say(ModelDB.mesh("traffic/sedan/lod0_body.res") != null and ModelDB.mesh("traffic/sedan/lod0_body.res").get_surface_count() == 2, "the shipped mesh loads (root switched back)")
	ModelDB.release_all()
	print("QA attack_loading: %d ok, %d FAIL" % [_n_ok, _n_bad])
	quit(0)
