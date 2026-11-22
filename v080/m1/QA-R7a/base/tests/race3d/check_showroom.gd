extends SceneTree
## v0.8.0 (UI1): the 3D showroom of the vehicle selection in the running game (headless, ~5 s), through the generic
## hook of tools/run_tests.sh:
##   godot --headless --path . -s res://tests/race3d/check_showroom.gd
## With "Grafik: Modern" and the limousine forced as a showroom car (the manifest marks no car yet), the vehicle
## screen shows the `show` model in its own transparent 3D world sized in physical pixels; a car without a showroom
## model keeps the sprite; switching "Grafik" to Arcade removes the 3D showroom at once and – leaving Modern – frees
## the model caches and the shared materials; back to Modern it comes back; leaving the screen signs off.
## Scripts of the 3D side are reached at run time (a -s script compiles before the autoloads exist, A-1).
## Prints "CHECK <name> OK|FEHLER" lines; exit code 1 on a failure.

const SHOWROOM := "res://scripts/ui/widgets/showroom_3d.gd"
const MODEL_DB := "res://scripts/core/model_db.gd"
const MATERIALS := "res://scripts/race3d/modern_materials.gd"
const SETTINGS_TEST := "user://test_check_showroom.json"

var _gf: Node
var _settings: Node
var _failed: Array[String] = []
var _n := 0
var _t0 := 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _check(check_name: String, ok: bool, msg: String = "") -> void:
	_n += 1
	print("CHECK %-15s %s  %s" % [check_name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(check_name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _showcase() -> Node:
	var shell: Node = _gf.get("shell")
	var screen: Node = shell.get("current_screen") if shell != null else null
	return screen.get("_show") if screen != null else null


## Waits until the showcase's 3D showroom has built its car (or `max_frames` passed).
func _wait_ready(max_frames: int = 240) -> Node:
	for i in max_frames:
		var sc := _showcase()
		var st: Variant = sc.get("stage3d") if sc != null else null
		if st is Node and is_instance_valid(st) and bool((st as Node).get("ready_to_show")):
			return st
		await process_frame
	return null


func _run() -> void:
	_gf = root.get_node_or_null("GameFlow")
	_settings = root.get_node_or_null("Settings")
	(_gf.get("attract") as Node).set("enabled", false)
	var old_path := str(_settings.get("file_path"))
	_settings.set("file_path", SETTINGS_TEST)
	_settings.set("graphics_mode", "modern")
	var showroom := load(SHOWROOM) as GDScript
	showroom.set("force_sets", ["showroom/limousine"])
	var db := load(MODEL_DB) as GDScript
	# 1 – Modern, limousine: the show model in a transparent world of its own, sized in physical pixels
	_gf.set("draft", {"race_id": "", "vehicle": "limousine"})
	_gf.set("mode", "race")
	_gf.call("go", "vehicle", {"mode": "race"}, true)
	var st := await _wait_ready()
	var sc := _showcase()
	var vp: SubViewport = st.get("viewport") if st != null else null
	var car: Node = null
	if st != null:
		for c in (st.get("_pivot") as Node).get_children():
			car = c
	var scale: Vector2 = root.get_stretch_transform().get_scale()
	var want: Vector2i = showroom.call("physical_size", (st as Control).size if st != null else Vector2.ZERO, scale)
	_check("modern_3d", st != null and (st as Control).visible and car != null and str(car.get_meta("lod", "")) == "show"
		and bool(sc.call("shows_3d")),
		"3D %s, Stufe %s" % [st != null, str(car.get_meta("lod", "")) if car != null else "-"])
	_check("welt", vp != null and vp.own_world_3d and vp.transparent_bg and vp.size == want,
		"eigene Welt %s, durchsichtig %s, Größe %s (soll %s, Faktor %s)" % [vp.own_world_3d if vp else false,
			vp.transparent_bg if vp else false, vp.size if vp else Vector2i.ZERO, want, scale])
	var loads_modern := int(db.get("loads"))
	# 2 – a car without a showroom model keeps the sprite
	var screen: Node = (_gf.get("shell") as Node).get("current_screen")
	sc.call("show_vehicle", "kombi", "showroom/kombi", 1.0)
	await _frames(3)
	_check("sprite", not bool(sc.call("shows_3d")) and str(sc.get("sprite_id")) == "showroom/kombi",
		"Kombi: 3D %s" % bool(sc.call("shows_3d")))
	sc.call("show_vehicle", "limousine", "showroom/limousine", -1.0)
	await _frames(2)
	var again: Variant = sc.get("stage3d")
	_check("zurueck_3d", again is Node and bool((again as Node).get("ready_to_show")) and bool(sc.call("shows_3d")),
		"Limousine sofort wieder in 3D (Zwischenspeicher): %s" % (again is Node and bool((again as Node).get("ready_to_show"))))
	# 3 – "Grafik: Arcade": the 3D showroom goes at once, the caches and the shared materials with it
	_settings.set("graphics_mode", "arcade")
	await _frames(3)
	var mats := load(MATERIALS) as GDScript
	var shared: Variant = mats.get("_shared")
	_check("arcade_frei", sc.get("stage3d") == null and not bool(sc.call("shows_3d")) and int(db.get("loads")) == 0
		and shared == null,
		"3D weg %s, geladene Dateien %d (vorher %d), gemeinsame Materialien %s" % [sc.get("stage3d") == null,
			int(db.get("loads")), loads_modern, "frei" if shared == null else "noch da"])
	# 4 – back to Modern: it comes back on the same screen
	_settings.set("graphics_mode", "modern")
	var st2 := await _wait_ready()
	_check("modern_wieder", st2 != null and _showcase() == sc and screen == (_gf.get("shell") as Node).get("current_screen"),
		"3D wieder da: %s" % (st2 != null))
	# 5 – leaving the screen signs off: no owner left, the caches go
	_gf.call("go", "title", {}, true)
	await _frames(4)
	var owners: Dictionary = db.get("_owners")
	_check("abmelden", owners.is_empty(), "Besitzer bei ModelDB: %d" % owners.size())
	showroom.set("force_sets", [])
	_settings.set("graphics_mode", "")
	_settings.set("file_path", old_path)
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SETTINGS_TEST + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEST + suffix))
	print("CHECKS %s  (%d von %d bestanden, %d s)" % ["OK" if _failed.is_empty() else "FEHLER", _n - _failed.size(), _n,
		(Time.get_ticks_msec() - _t0) / 1000])
	quit(0 if _failed.is_empty() else 1)
