extends TestCase
## Data module: SaveGame (atomic write, version, robust load) with a temporary file.

const SaveGameScript := preload("res://scripts/data/save_game.gd")
const DIR := "user://test_data_module"


func _save_game(file: String) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var p := DIR.path_join(file)
	JsonFile.remove_all(p)
	var sg: Node = SaveGameScript.new()
	sg.set("path", p)
	return sg


func _state(city: String, total: float) -> Dictionary:
	return {
		"race_id": "kiel_nuernberg", "vehicle": "kombi", "start_hour": 8.5, "current_city": city,
		"waypoint_index": 0,
		"legs": [{"kind": "stage", "id": "kiel_hamburg", "from": "kiel", "to": "hamburg", "time_s": 120.5,
			"avg_kmh": 190.0, "weather": "rain", "start_world_minutes": 510.0, "end_world_minutes": 534.1}],
		"total_time_s": total, "world_minutes": 1254.1, "route": ["kiel", "hamburg"], "seed": 42,
	}


func test_roundtrip() -> void:
	var sg := _save_game("save_roundtrip.json")
	var p := str(sg.get("path"))
	assert_false(sg.call("has_race"), "anfangs kein Spielstand")
	assert_true(sg.call("save_race", _state("hamburg", 120.5)), "gespeichert")
	assert_true(sg.call("has_race"), "Spielstand vorhanden")
	var r: Dictionary = sg.call("load_race")
	assert_eq(str(r["race_id"]), "kiel_nuernberg", "race_id")
	assert_eq(str(r["current_city"]), "hamburg", "current_city")
	assert_eq(typeof(r["waypoint_index"]), TYPE_INT, "waypoint_index als int")
	assert_eq(typeof(r["seed"]), TYPE_INT, "seed als int")
	assert_eq(int(r["seed"]), 42, "seed")
	assert_near(float(r["total_time_s"]), 120.5, 0.0001, "Gesamtzeit")
	assert_near(float(r["start_hour"]), 8.5, 0.0001, "Startstunde")
	assert_eq(r["route"], ["kiel", "hamburg"], "Route")
	assert_eq(str(r["legs"][0]["weather"]), "rain", "Etappen")
	var raw: Variant = JsonFile.read(p)
	assert_eq(int(raw["version"]), 2, "Version in der Datei")
	assert_true(str(raw.get("saved_at", "")) != "", "Zeitstempel")
	sg.free()
	JsonFile.remove_all(p)


func test_atomic_write_keeps_backup() -> void:
	var sg := _save_game("save_atomic.json")
	var p := str(sg.get("path"))
	sg.call("save_race", _state("hamburg", 100.0))
	assert_false(FileAccess.file_exists(p + ".tmp"), "keine Temp-Datei übrig")
	sg.call("save_race", _state("hannover", 300.0))
	assert_true(FileAccess.file_exists(p + ".bak"), "Vorversion als .bak")
	var bak: Variant = JsonFile.read(p + ".bak")
	assert_eq(str(bak["race"]["current_city"]), "hamburg", ".bak enthält den vorigen Stand")
	assert_eq(str(sg.call("load_race")["current_city"]), "hannover", "aktueller Stand")
	sg.free()
	JsonFile.remove_all(p)


func test_corrupt_file_falls_back() -> void:
	JsonFile.quiet = true
	var sg := _save_game("save_corrupt.json")
	var p := str(sg.get("path"))
	sg.call("save_race", _state("hamburg", 100.0))
	sg.call("save_race", _state("hannover", 300.0))
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{\"version\": 2, \"race\": {\"race_id\": ")
	f.close()
	assert_eq(str(sg.call("load_race")["current_city"]), "hamburg", "beschädigt: Sicherung geladen")
	f = FileAccess.open(p + ".bak", FileAccess.WRITE)
	f.store_string("Unsinn")
	f.close()
	assert_true((sg.call("load_race") as Dictionary).is_empty(), "beides kaputt: kein Spielstand")
	assert_false(sg.call("has_race"), "has_race false")
	sg.free()
	JsonFile.remove_all(p)
	JsonFile.quiet = false


func test_old_or_incomplete_files() -> void:
	var sg := _save_game("save_old.json")
	var p := str(sg.get("path"))
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "race": {"race_id": "koenigsrennen", "current_city": "paris"}}))
	f.close()
	var r: Dictionary = sg.call("load_race")
	assert_eq(str(r["race_id"]), "koenigsrennen", "Version 1 lesbar")
	assert_eq(r["legs"], [], "fehlende Felder ergänzt")
	assert_eq(int(r["waypoint_index"]), 0, "waypoint_index Standard")
	f = FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "race": {"vehicle": "kombi"}}))
	f.close()
	assert_true((sg.call("load_race") as Dictionary).is_empty(), "ohne race_id unbrauchbar")
	sg.free()
	JsonFile.remove_all(p)


func test_clear_race() -> void:
	var sg := _save_game("save_clear.json")
	var p := str(sg.get("path"))
	sg.call("save_race", _state("hamburg", 100.0))
	sg.call("save_race", _state("hannover", 200.0))
	sg.call("clear_race")
	assert_false(sg.call("has_race"), "gelöscht")
	assert_false(FileAccess.file_exists(p), "Datei weg")
	assert_false(FileAccess.file_exists(p + ".bak"), "Sicherung weg")
	sg.free()
