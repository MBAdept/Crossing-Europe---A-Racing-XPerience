extends TestCase
## ModelDB and the generated model manifest (docs/modelle.md): every sprite set of the game resolves in the
## graphics mode "Modern" (to a model or to an explicit stand-in), the sizes are the ones of the sprite
## manifest (both modes share the simulation), the manifest is the merge of its fragments, the files it names
## exist and carry what it says.

const SPRITES := "res://assets/sprites/manifest.json"
const REFERENCE: Array[String] = ["landmarks/michel", "player/limousine", "props/farmhouse", "props/streetlight",
	"props/tree_oak", "traffic/sedan"]


func _json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


func _sprite_sets() -> Dictionary:
	var out := {}
	var sets: Dictionary = _json(SPRITES).get("sets", {})
	for sid: String in sets:
		if not sid.begins_with("ui/"):
			out[sid] = sets[sid]
	return out


func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


func test_manifest_is_available() -> void:
	assert_true(ModelDB.load_manifest(), "Manifest lädt")
	assert_true(ModelDB.available(), "available()")
	for mid in REFERENCE:
		assert_false(ModelDB.model(mid).is_empty(), "Referenzmodell " + mid)


func test_every_sprite_set_resolves() -> void:
	ModelDB.load_manifest()
	var sets := _sprite_sets()
	assert_eq(sets.size(), 180, "Sprite-Sets ohne ui/*")
	var with_model := 0
	for sid: String in sets:
		var r := ModelDB.resolve(sid)
		if r.is_empty():
			fail("Set löst nicht auf: " + sid)
			continue
		var has := not (r["model"] as Dictionary).is_empty()
		if has:
			with_model += 1
			assert_eq(str(r["fallback"]), "", sid + ": Modell und Platzhalter zugleich")
			assert_true(ModelDB.has_model(sid), sid + ": has_model")
			assert_true((r["variants"] as Array).has(str(r["model_id"])) or not (r["variants"] as Array).is_empty(), sid + ": Varianten")
		else:
			assert_true(ModelDB.FALLBACKS.has(str(r["fallback"])), sid + ": Platzhalter " + str(r["fallback"]))
			assert_false(ModelDB.has_model(sid), sid + ": has_model ohne Modell")
	assert_true(with_model >= 10, "Sets mit Modell: %d" % with_model)
	assert_eq(ModelDB.set_ids().size(), sets.size(), "sets im Manifest")
	for sid: String in _json(SPRITES).get("sets", {}):
		if sid.begins_with("ui/"):
			assert_true(ModelDB.resolve(sid).is_empty(), sid + " hat keinen Eintrag")
	assert_true(ModelDB.resolve("props/gibt_es_nicht").is_empty(), "unbekanntes Set")


func test_object_sizes_equal_the_sprite_manifest() -> void:
	ModelDB.load_manifest()
	var sets := _sprite_sets()
	for sid: String in sets:
		var want: Dictionary = (sets[sid] as Dictionary).get("object", {})
		var got := ModelDB.object_size(sid)
		for k: String in want:
			if not got.has(k):
				fail("%s: object.%s fehlt" % [sid, k])
			elif absf(float(got[k]) - float(want[k])) > 0.0005:
				fail("%s: object.%s = %s, Sprite %s" % [sid, k, str(got[k]), str(want[k])])
		for k: String in got:
			assert_true(want.has(k), "%s: object.%s kennt das Sprite nicht" % [sid, k])


func test_stand_ins_follow_the_kind_of_set() -> void:
	ModelDB.load_manifest()
	var sets := _sprite_sets()
	for sid: String in sets:
		var r := ModelDB.resolve(sid)
		if r.is_empty() or str(r["fallback"]) == "":
			continue
		var group := sid.get_slice("/", 0)
		var vehicle := group == "player" or group == "traffic" or group == "police" or str((sets[sid] as Dictionary).get("render", "")) == "box"
		assert_eq(str(r["fallback"]), "box" if vehicle else "sprite", sid)
		if group == "traffic" or group == "police" or group == "player":
			assert_true((r["paint"] as Dictionary).has("paint"), sid + ": Lackfarbe des Platzhalters")


func test_manifest_is_the_merge_of_its_fragments() -> void:
	var man := _json(ModelDB.ROOT + ModelDB.MANIFEST)
	var models := {}
	var sets: Dictionary = _json(ModelDB.ROOT + "sets_default.json").get("sets", {}).duplicate(true)
	assert_false(sets.is_empty(), "sets_default.json")
	var groups := DirAccess.get_directories_at(ModelDB.ROOT)
	groups.sort()
	for group in groups:
		var names := DirAccess.get_directories_at(ModelDB.ROOT + group)
		names.sort()
		for n in names:
			var frag := _json(ModelDB.ROOT + group + "/" + n + "/model.json")
			if frag.is_empty():
				fail("Ordner ohne model.json: %s/%s" % [group, n])
				continue
			models[group + "/" + n] = frag.get("model", {})
			var fs: Dictionary = frag.get("sets", {})
			for sid: String in fs:
				sets[sid] = fs[sid]
	assert_true(_same(man.get("models", {}), models), "models = Fragmente (tools/blender/export_models.py --manifest-only)")
	assert_true(_same(man.get("sets", {}), sets), "sets = sets_default.json + Fragmente (export_models.py --manifest-only)")
	assert_eq(int(man.get("version", 0)), 1, "version")


func test_files_exist_and_meshes_carry_the_manifest() -> void:
	ModelDB.load_manifest()
	for mid in ModelDB.model_ids():
		var m := ModelDB.model(mid)
		for f in ModelDB.files_of(mid):
			assert_true(FileAccess.file_exists(ModelDB.ROOT + f), "Datei " + f)
			if not f.ends_with(".res"):
				assert_true(FileAccess.file_exists(ModelDB.ROOT + f + ".import"), f + ".import")
		for l: Variant in m.get("lods", []):
			var ld: Dictionary = l
			var tris := 0
			for p: Variant in ld.get("parts", []):
				var pd: Dictionary = p
				var mesh := ModelDB.mesh(str(pd["mesh"]))
				if mesh == null:
					fail("Netz lädt nicht: " + str(pd["mesh"]))
					continue
				var names: Array = []
				for s in mesh.get_surface_count():
					names.append(mesh.surface_get_name(s))
					assert_true(mesh.surface_get_material(s) == null, str(pd["mesh"]) + ": Netz ohne Material")
					tris += mesh.surface_get_array_index_len(s) / 3
				assert_eq(names, pd.get("classes", []), "%s %s/%s: Flächen = Klassen" % [mid, str(ld["name"]), str(pd["node"])])
			assert_eq(tris, int(ld.get("tris", -1)), "%s %s: Dreiecke" % [mid, str(ld["name"])])
	ModelDB.release_all()
	assert_eq(ModelDB.loads, 0, "release_all() leert den Zähler")


func test_reference_sets() -> void:
	ModelDB.load_manifest()
	var paints := {}
	for c: String in ["red", "silver", "black", "blue"]:
		var r := ModelDB.resolve("traffic/sedan_" + c)
		assert_eq(str(r.get("model_id", "")), "traffic/sedan", "traffic/sedan_" + c)
		paints[str((r.get("paint", {}) as Dictionary).get("paint", ""))] = true
	assert_eq(paints.size(), 4, "vier Farbsets der Limousine des Verkehrs")
	var show := ModelDB.resolve("showroom/limousine")
	assert_eq(str(show.get("model_id", "")), "player/limousine", "showroom/limousine")
	assert_eq(str(show.get("lod", "")), "show", "Showroom zeigt die Stufe show")
	assert_false(ModelDB.lod(show["model"], "show").is_empty(), "Stufe show")
	assert_true(ModelDB.lod(show["model"], "lod7").is_empty(), "unbekannte Stufe")
	var sedan := ModelDB.model("traffic/sedan")
	assert_eq(ModelDB.lod_for_distance(sedan, 10.0), "lod0", "10 m")
	assert_eq(ModelDB.lod_for_distance(sedan, 80.0), "lod1", "80 m")
	assert_eq(ModelDB.lod_for_distance(sedan, 500.0), "lod2", "500 m")
	assert_eq(ModelDB.lod_for_distance(sedan, 80.0, 0.5), "lod2", "80 m bei halber Reichweite")
	assert_eq(ModelDB.lod_for_distance(sedan, 1.0e9), "lod2", "jenseits der letzten Stufe")
	var limo := ModelDB.model("player/limousine")
	assert_eq(ModelDB.lod_for_distance(limo, 0.0), "lod0", "show wird nie nach Entfernung gewählt")
	assert_true(ModelDB.files_of("player/limousine", ["lod0"]).has("player/limousine/lod0_body.res"), "files_of lod0")
	assert_false(ModelDB.files_of("player/limousine", ["lod0"]).has("player/limousine/show_body.res"), "files_of ohne show")
	assert_true(ModelDB.files_of("props/tree_oak").has("props/tree_oak/impostor.png"), "Impostor gehört zu den Dateien")


func test_resolving_loads_nothing() -> void:
	ModelDB.load_manifest()
	for sid in ModelDB.set_ids():
		ModelDB.resolve(sid)
		ModelDB.object_size(sid)
	assert_eq(ModelDB.loads, 0, "resolve() lädt keine Datei")


func test_request_loads_in_the_background() -> void:
	ModelDB.load_manifest()
	ModelDB.request(["props/streetlight", "traffic/sedan_red"], ["lod0"])
	var guard := 0
	while ModelDB.pending() > 0 and guard < 4000:
		OS.delay_msec(5)
		guard += 1
	assert_eq(ModelDB.pending(), 0, "alles Angeforderte ist geladen")
	var before := ModelDB.loads
	assert_true(before >= 3, "geladene Dateien: %d" % before)
	assert_true(ModelDB.mesh("props/streetlight/lod0_body.res") != null, "Netz aus dem Cache")
	assert_true(ModelDB.mesh("traffic/sedan/wheel.res") != null, "Rad aus dem Cache")
	assert_eq(ModelDB.loads, before, "mesh() nach request() lädt nichts mehr")
	ModelDB.release_all()
	assert_eq(ModelDB.loads, 0, "release_all()")


func test_missing_manifest_resolves_nothing() -> void:
	assert_false(ModelDB.load_manifest("res://assets/models/gibt_es_nicht.json"), "fehlendes Manifest")
	assert_false(ModelDB.available(), "available() ohne Manifest")
	assert_true(ModelDB.resolve("traffic/sedan_red").is_empty(), "resolve() ohne Manifest")
	assert_true(ModelDB.model_ids().is_empty(), "model_ids() ohne Manifest")
	assert_true(ModelDB.load_manifest(), "das ausgelieferte Manifest lädt wieder")
	assert_true(ModelDB.has_model("traffic/sedan_red"), "nach load_manifest()")
