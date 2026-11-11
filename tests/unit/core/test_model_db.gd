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
	# beyond the last mesh level a model with an impostor shows the impostor – a caller can tell it is due
	var oak := ModelDB.model("props/tree_oak")
	assert_eq(ModelDB.lod_for_distance(oak, 30.0), "lod0", "Eiche 30 m")
	assert_eq(ModelDB.lod_for_distance(oak, 150.0), "lod1", "Eiche 150 m")
	assert_eq(ModelDB.lod_for_distance(oak, 5000.0), ModelDB.IMPOSTOR, "Eiche jenseits von lod1: Impostor")
	assert_eq(ModelDB.lod_for_distance(oak, 150.0, 0.5), ModelDB.IMPOSTOR, "Eiche 150 m bei halber Reichweite: Impostor")
	assert_eq(ModelDB.lod_for_distance({}, 10.0), "", "Modell ohne Stufen")


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


# --- fixtures written by the tests: a manifest next to copies of real meshes -----------------------------------------

const FIX_DIR := "user://test_model_db"


## Writes a manifest (and the files it should find) below FIX_DIR and returns its path. `copies`: {manifest path:
## res:// source}; files named by the manifest but missing from `copies` simply do not exist.
func _fixture(manifest: Dictionary, copies: Dictionary = {}) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIX_DIR))
	for rel: String in copies:
		var dst := FIX_DIR.path_join(rel)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst.get_base_dir()))
		DirAccess.copy_absolute(ProjectSettings.globalize_path(str(copies[rel])), ProjectSettings.globalize_path(dst))
	var path := FIX_DIR.path_join("manifest.json")
	var fh := FileAccess.open(path, FileAccess.WRITE)
	fh.store_string(JSON.stringify(manifest))
	fh.close()
	return path


func _car(parts: Array, shadow: String = "") -> Dictionary:
	var m := {"kind": "vehicle", "object": {"width_m": 1.8, "length_m": 4.7, "height_m": 1.5},
		"lods": [{"name": "lod0", "max_dist_m": 100000, "tris": 1, "parts": parts}], "tags": []}
	if shadow != "":
		m["shadow"] = {"mesh": shadow, "tris": 1}
	return m


func test_malformed_entries_make_the_manifest_invalid() -> void:
	# entries of the wrong type raised script errors in resolve(), lod() and files_of(); now the manifest as a whole
	# counts as invalid, like a missing one: nothing resolves, Modern falls back
	var good_model := _car([{"node": "body", "mesh": "m/body.res", "classes": ["vpbr"]}])
	var cases := {
		"Set ist ein Text": {"version": 1, "models": {"m": good_model}, "sets": {"a": "m"}},
		"Modell ist ein Text": {"version": 1, "models": {"m": "kaputt"}, "sets": {"a": {"model": "m"}}},
		"lods ist ein Text": {"version": 1, "models": {"m": {"kind": "vehicle", "lods": "lod0"}}, "sets": {"a": {"model": "m"}}},
		"Stufe ist ein Text": {"version": 1, "models": {"m": {"kind": "vehicle", "lods": ["lod0"]}}, "sets": {"a": {"model": "m"}}},
		"Teil ist ein Text": {"version": 1, "models": {"m": {"kind": "vehicle", "lods": [{"name": "lod0", "parts": ["body"]}]}}, "sets": {"a": {"model": "m"}}},
		"parts ist ein Wörterbuch": {"version": 1, "models": {"m": {"kind": "vehicle", "lods": [{"name": "lod0", "parts": {}}]}}, "sets": {"a": {"model": "m"}}},
		"shadow ist ein Text": {"version": 1, "models": {"m": {"kind": "vehicle", "lods": [], "shadow": "s.res"}}, "sets": {"a": {"model": "m"}}},
		"textures ist eine Liste": {"version": 1, "models": {"m": {"kind": "building", "lods": [], "textures": ["a.png"]}}, "sets": {"a": {"model": "m"}}},
		"lights enthält einen Text": {"version": 1, "models": {"m": {"kind": "vehicle", "lods": [], "lights": ["head"]}}, "sets": {"a": {"model": "m"}}},
		"paint des Sets ist ein Text": {"version": 1, "models": {"m": good_model}, "sets": {"a": {"model": "m", "paint": "#ff0000"}}},
		"variants ist ein Text": {"version": 1, "models": {"m": good_model}, "sets": {"a": {"model": "m", "variants": "m"}}},
		"Version ist eine Liste": {"version": [1], "models": {}, "sets": {}},
		"Version 2": {"version": 2, "models": {}, "sets": {}},
	}
	for name: String in cases:
		assert_false(ModelDB.load_manifest(_fixture(cases[name])), name + ": ungültig")
		assert_false(ModelDB.available(), name + ": available()")
		assert_true(ModelDB.resolve("a").is_empty(), name + ": resolve()")
		assert_false(ModelDB.has_model("a"), name + ": has_model()")
		assert_true(ModelDB.files_of("m").is_empty(), name + ": files_of()")
		assert_true(ModelDB.missing(["a"]).is_empty(), name + ": missing() ohne gültiges Manifest")
		assert_true(ModelFactory.build("a", "", null) == null, name + ": build()")
	# what may be absent or odd without harm stays valid
	assert_true(ModelDB.load_manifest(_fixture({"version": 1.0, "models": {"m": good_model}, "sets": {"a": {"model": "m"}, "b": {"fallback": "kiste"}, "c": {"model": "gibt_es_nicht"}}})), "gültig mit Besonderheiten")
	assert_eq(str(ModelDB.resolve("b")["fallback"]), "sprite", "unbekannter Platzhalter = sprite")
	assert_eq(str(ModelDB.resolve("c")["fallback"]), "sprite", "Set mit unbekanntem Modell = Platzhalter")
	assert_true(ModelDB.load_manifest(), "das ausgelieferte Manifest lädt wieder")


func test_a_model_with_a_missing_file_is_not_built() -> void:
	# half a model is no model: a car whose body file is gone was built as four wheels and a shadow caster
	var body := "res://assets/models/props/streetlight/lod0_body.res"
	var wheel := "res://assets/models/traffic/sedan/wheel.res"
	var parts := [{"node": "body", "mesh": "car/body.res", "classes": ["vpbr"]},
		{"node": "wheel_0r", "mesh": "car/wheel.res", "classes": ["vpbr"], "pos": [0.8, 0.3, -1.4], "wheel": {"radius": 0.3, "steer": true}}]
	var manifest := {"version": 1, "models": {
			"t/whole": _car(parts, "car/caster.res"),
			"t/no_body": _car([{"node": "body", "mesh": "car/gone.res", "classes": ["vpbr"]}, parts[1]]),
			"t/no_wheel": _car([parts[0], {"node": "wheel_0r", "mesh": "car/gone_wheel.res", "classes": ["vpbr"], "wheel": {"radius": 0.3, "steer": true}}]),
			"t/no_caster": _car(parts, "car/gone_caster.res"),
			"t/empty": _car([])},
		"sets": {"whole": {"model": "t/whole"}, "no_body": {"model": "t/no_body"}, "no_wheel": {"model": "t/no_wheel"},
			"no_caster": {"model": "t/no_caster"}, "empty": {"model": "t/empty"}}}
	assert_true(ModelDB.load_manifest(_fixture(manifest, {"car/body.res": body, "car/wheel.res": wheel, "car/caster.res": body})), "Fixture lädt")
	ModelDB.warn_missing = false      # the missing files are the point of this test
	assert_true(ModelDB.missing(["whole"]).is_empty(), "vollständiges Modell: nichts fehlt")
	var whole := ModelFactory.build("whole", "", null)
	assert_true(whole != null and whole.get_child_count() == 3, "vollständiges Modell: body, Rad, Schattenwerfer")
	if whole != null:
		whole.free()
	assert_eq(ModelFactory.multimesh_parts("whole", "").size(), 3, "multimesh_parts: body, Rad, Schattenwerfer")
	for sid: String in ["no_body", "no_wheel", "no_caster", "empty"]:
		assert_true(ModelDB.has_model(sid), sid + ": das Manifest nennt ein Modell")
		var node := ModelFactory.build(sid, "", null)
		assert_true(node == null, sid + ": build() liefert kein halbes Modell")
		if node != null:
			node.free()
		assert_true(ModelFactory.multimesh_parts(sid, "").is_empty(), sid + ": multimesh_parts() liefert nichts")
	assert_eq(ModelDB.missing(["no_body"]), ["car/gone.res"] as Array[String], "missing() nennt die fehlende Karosserie")
	assert_eq(ModelDB.missing(["no_wheel", "no_caster", "whole"]), ["car/gone_caster.res", "car/gone_wheel.res"] as Array[String], "missing() über mehrere Sets, sortiert")
	assert_true(ModelDB.missing(["empty", "gibt_es_nicht"]).is_empty(), "missing(): nichts genannt, nichts fehlt")
	ModelDB.warn_missing = true
	assert_true(ModelDB.load_manifest(), "das ausgelieferte Manifest lädt wieder")
	assert_true(ModelDB.missing(ModelDB.set_ids()).is_empty(), "im ausgelieferten Manifest fehlt keine Datei")


func test_empty_level_means_the_sets_own_level() -> void:
	ModelDB.load_manifest()
	# build() and multimesh_parts() resolve "" the same way: the set's own level (show), else lod0
	var show := ModelFactory.multimesh_parts("showroom/limousine", "")
	assert_true(show.size() >= 5, "showroom/limousine: Teile der Stufe show")
	if not show.is_empty():
		assert_true(is_same(show[0]["mesh"], ModelDB.mesh("player/limousine/show_body.res")), "multimesh_parts('') nimmt die Stufe show des Sets")
	var node := ModelFactory.build("showroom/limousine", "", null)
	assert_true(node != null and str(node.get_meta("lod")) == "show", "build('') nimmt die Stufe show des Sets")
	if node != null:
		node.free()
	var race := ModelFactory.multimesh_parts("player/limousine", "")
	assert_true(not race.is_empty() and is_same(race[0]["mesh"], ModelDB.mesh("player/limousine/lod0_body.res")), "ohne eigene Stufe: lod0")
	assert_eq(ModelFactory.level_of(ModelDB.resolve("showroom/limousine"), "lod0"), "lod0", "eine genannte Stufe gilt")
	ModelDB.release_all()


func test_owners_keep_the_caches_of_each_other() -> void:
	ModelDB.load_manifest()
	var old_stage := RefCounted.new()
	var new_stage := RefCounted.new()
	ModelDB.request(["props/streetlight"], ["lod0"], old_stage)
	while ModelDB.pending() > 0:
		OS.delay_msec(2)
	# the next stage requests before the last one has left (GameFlow), then the old one signs off
	ModelDB.request(["traffic/sedan_red"], ["lod0"], new_stage)
	ModelDB.release_all(old_stage)
	while ModelDB.pending() > 0:
		OS.delay_msec(2)
	var loaded := ModelDB.loads
	assert_true(loaded >= 3, "die Anforderungen der neuen Etappe überleben den Abgang der alten (%d Dateien)" % loaded)
	assert_true(ModelDB.mesh("traffic/sedan/lod0_body.res") != null, "Netz der neuen Etappe im Cache")
	assert_eq(ModelDB.loads, loaded, "… ohne neu zu laden")
	ModelDB.release_all(new_stage)
	assert_eq(ModelDB.loads, 0, "die letzte Besitzerin gibt die Caches frei")
	# an owner that was freed without signing off does not hold the caches for ever
	var gone := Node.new()
	ModelDB.request(["props/streetlight"], ["lod0"], gone)
	gone.free()
	var last := RefCounted.new()
	ModelDB.request(["props/streetlight"], ["lod0"], last)
	while ModelDB.pending() > 0:
		OS.delay_msec(2)
	ModelDB.release_all(last)
	assert_eq(ModelDB.loads, 0, "eine freigegebene Besitzerin zählt nicht mehr")
	# without an owner: unconditionally (mode switch)
	ModelDB.request(["props/streetlight"], ["lod0"], RefCounted.new())
	ModelDB.release_all()
	assert_eq(ModelDB.loads, 0, "release_all() ohne Besitzerin leert immer")


func test_materials_share_one_instance() -> void:
	var a := ModernMaterials.shared()
	assert_true(a != null and is_same(a, ModernMaterials.shared()), "shared() liefert immer dieselbe Instanz")
	ModernMaterials.set_global("ce_night", 0.0)     # registers the globals itself: no engine error without an instance
	ModernMaterials.drop_shared()
	assert_false(is_same(a, ModernMaterials.shared()), "nach drop_shared() eine neue")
	ModernMaterials.drop_shared()
