extends TestCase
## v0.8.0 (UI1): the real-time 3D showroom of the vehicle selection (Showroom3D in CarShowcase) – which sets get it
## (manifest flag `showroom` and the level "show", forced sets), its render size in physical pixels, the framing,
## and that CarShowcase reaches it only at run time (an Arcade start compiles no 3D code). The scene-tree parts –
## switching "Grafik" at once, releasing the caches – are tests/race3d/check_showroom.gd.

const FIX_DIR := "user://test_showroom"


func _limo_show_files() -> Dictionary:
	# the real files of the limousine's show level (the fixture copies them next to its own manifest)
	var m := ModelDB.model("player/limousine")
	var out := {}
	for l: Variant in m.get("lods", []):
		if str((l as Dictionary).get("name", "")) == "show":
			for p: Variant in (l as Dictionary).get("parts", []):
				var f := str((p as Dictionary).get("mesh", ""))
				out[f] = "res://assets/models/" + f
	if m.has("shadow"):
		var sf := str((m["shadow"] as Dictionary).get("mesh", ""))
		out[sf] = "res://assets/models/" + sf
	return out


## A manifest below FIX_DIR with copies of the limousine's show files: "showroom/ja" (showroom: true), "showroom/nein"
## (false), "showroom/ohne_show" (true, but its model has no show level), "showroom/sprite" (a stand-in).
func _fixture() -> String:
	ModelDB.load_manifest()
	var limo := ModelDB.model("player/limousine").duplicate(true)
	var files := _limo_show_files()
	var no_show := limo.duplicate(true)
	var lods: Array = []
	for l: Variant in limo.get("lods", []):
		if str((l as Dictionary).get("name", "")) != "show":
			lods.append(l)
	no_show["lods"] = lods
	var manifest := {"version": 1, "models": {"t/limo": limo, "t/no_show": no_show},
		"sets": {"showroom/ja": {"model": "t/limo", "lod": "show", "showroom": true},
			"showroom/nein": {"model": "t/limo", "lod": "show", "showroom": false},
			"showroom/ohne_show": {"model": "t/no_show", "showroom": true},
			"showroom/sprite": {"fallback": "sprite", "object": {"width_m": 1.9, "length_m": 4.5, "height_m": 1.3}}}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIX_DIR))
	for rel: String in files:
		var dst := FIX_DIR.path_join(rel)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst.get_base_dir()))
		DirAccess.copy_absolute(ProjectSettings.globalize_path(str(files[rel])), ProjectSettings.globalize_path(dst))
	var path := FIX_DIR.path_join("manifest.json")
	var fh := FileAccess.open(path, FileAccess.WRITE)
	fh.store_string(JSON.stringify(manifest))
	fh.close()
	return path


func test_which_sets_get_the_3d_showroom() -> void:
	assert_true(ModelDB.load_manifest(_fixture()), "Fixture-Manifest lädt")
	Showroom3D.force_sets = []
	assert_true(Showroom3D.can_show("showroom/ja"), "showroom: true mit Stufe show: 3D")
	assert_false(Showroom3D.can_show("showroom/nein"), "showroom: false: das Sprite")
	assert_false(Showroom3D.can_show("showroom/ohne_show"), "ohne Stufe show: das Sprite")
	assert_false(Showroom3D.can_show("showroom/sprite"), "Platzhalter: das Sprite")
	assert_false(Showroom3D.can_show("showroom/gibt_es_nicht"), "unbekanntes Set: das Sprite")
	Showroom3D.force_sets = ["showroom/nein", "showroom/sprite"]
	assert_true(Showroom3D.can_show("showroom/nein"), "erzwungen: 3D trotz showroom: false")
	assert_false(Showroom3D.can_show("showroom/sprite"), "erzwungen, aber ohne Modell: das Sprite")
	Showroom3D.force_sets = []
	# a model of the fixture really builds at the show level (no half model)
	var car := ModelFactory.build("showroom/ja", Showroom3D.SHOW_LEVEL, null)
	assert_true(car != null and str(car.get_meta("lod", "")) == "show", "Modell der Stufe show gebaut")
	if car != null:
		assert_true(car.get_node_or_null("body") != null and car.get_node_or_null("shadow") != null, "Karosserie und Schattenwerfer")
		car.free()
	ModelDB.release_all()
	assert_true(ModelDB.load_manifest(), "das ausgelieferte Manifest lädt wieder")


## Today no car of the shipped manifest is good enough for the showroom (AS1 decides with an A/B per car); the two
## player cars with a show level can be forced, the others stay sprites.
func test_shipped_manifest_and_forced_limousine() -> void:
	ModelDB.load_manifest()
	Showroom3D.force_sets = []
	for id: String in ["limousine", "kompakt", "kombi", "sportwagen", "gran_turismo"]:
		var sid := "showroom/" + id
		assert_eq(Showroom3D.can_show(sid), bool(ModelDB.resolve(sid).get("showroom", false)) and ModelDB.has_model(sid),
			sid + ": wie das Manifest sagt")
	Showroom3D.force_sets = ["showroom/limousine"]
	assert_true(Showroom3D.can_show("showroom/limousine"), "Limousine erzwungen: 3D")
	assert_false(Showroom3D.can_show("showroom/kombi"), "Kombi hat (noch) kein Modell: Sprite")
	Showroom3D.force_sets = []
	var r := ModelDB.resolve("showroom/limousine")
	assert_eq(str(r.get("lod", "")), "show", "das Showroom-Set nennt die Stufe show")


func test_render_size_in_physical_pixels() -> void:
	assert_eq(Showroom3D.physical_size(Vector2(660, 400), Vector2(1.5, 1.5)), Vector2i(990, 600), "1080p: 990 × 600 Pixel")
	assert_eq(Showroom3D.physical_size(Vector2(660, 400), Vector2(1, 1)), Vector2i(660, 400), "720p und Steam Deck: 660 × 400")
	assert_eq(Showroom3D.physical_size(Vector2(660, 400), Vector2(2, 2)), Vector2i(1320, 800), "4K-Fenster mit Faktor 2")
	assert_eq(Showroom3D.physical_size(Vector2(3, 0), Vector2(1, 1)), Vector2i(16, 16), "nie kleiner als 16 Pixel")


func test_framing() -> void:
	var d_wide := Showroom3D.fit_distance(2.9, 16.0 / 9.0)
	var d_square := Showroom3D.fit_distance(2.9, 1.0)
	assert_true(d_wide < d_square, "breiteres Bild: die Kamera darf näher")
	assert_true(Showroom3D.fit_distance(4.0, 1.65) > Showroom3D.fit_distance(2.9, 1.65), "größerer Drehteller: weiter weg")
	# the turntable fills FILL of the width: its edge projects to that share of the half width
	var aspect := 660.0 / 400.0
	var d := Showroom3D.fit_distance(2.9, aspect)
	var half_h := atan(tan(deg_to_rad(Showroom3D.CAM_FOV_DEG) * 0.5) * aspect)
	assert_near(asin(2.9 / d), half_h * Showroom3D.FILL, 0.0005, "Drehteller füllt FILL der Bildbreite")
	assert_eq(Showroom3D.footprint_centre({"aabb": [-1.15, 0.0, -2.43, 1.15, 1.49, 2.44]}), Vector3(0.0, 0.0, 0.005), "Mitte der Grundfläche")
	assert_eq(Showroom3D.footprint_centre({}), Vector3.ZERO, "ohne aabb: der Ursprung")


## CarShowcase reaches the 3D showroom only through its path at run time: a class name, a preload or a type there
## would compile ModelDB, ModelFactory and ModernMaterials at every Arcade start (check_arcade_lean).
func test_car_showcase_loads_the_showroom_only_at_run_time() -> void:
	var code: Array[String] = []
	for line: String in FileAccess.get_file_as_string("res://scripts/ui/widgets/car_showcase.gd").split("\n"):
		code.append(line.get_slice("#", 0))   # comments may name it
	var src := "\n".join(code)
	assert_false(src.contains("Showroom3D"), "CarShowcase nennt die Klasse Showroom3D nicht")
	for name: String in ["ModelDB", "ModelFactory", "ModernMaterials", "preload("]:
		assert_false(src.contains(name), "CarShowcase nennt %s nicht" % name)
	assert_true(src.contains(CarShowcase.SHOWROOM_SCRIPT.get_file()), "lädt das Skript über seinen Pfad")
