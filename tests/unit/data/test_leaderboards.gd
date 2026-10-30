extends TestCase
## Data module: leaderboards (LeaderboardStore) – ranking, vehicle filter, per-vehicle storage, seeding,
## persistence with a temporary file and robustness against damaged files.

const NetworkTest := preload("res://tests/unit/data/test_network_data.gd")
const DIR := "user://test_data_module"
const KEY := "stage:test:fwd"


func _store(file: String = "", lengths: Callable = Callable(), lb: Dictionary = {}) -> LeaderboardStore:
	var c := cfg()
	if not lb.is_empty():
		c = ConfigLoader.deep_merge(c, {"leaderboard": lb})
	var s := LeaderboardStore.new()
	s.setup(c, file, lengths)
	return s


func _entry(name: String, time_s: float, vehicle: String) -> Dictionary:
	return {"name": name, "time_s": time_s, "avg_kmh": 150.0, "vehicle": vehicle, "weather": "normal",
		"start_hour": 8.0, "daytime": "day", "date": "2026-10-30"}


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var p := DIR.path_join(name)
	JsonFile.remove_all(p)
	return p


func _names(list: Array) -> Array[String]:
	var out: Array[String] = []
	for e in list:
		out.append(str(e["name"]))
	return out


func test_ranking_and_ties() -> void:
	var s := _store("", Callable(), {"seed_entries": false})
	assert_eq(s.would_rank(KEY, 100.0), 1, "leere Liste: Platz 1")
	assert_eq(s.submit(KEY, _entry("A", 100.0, "kombi")), 1, "erster Eintrag")
	assert_eq(s.submit(KEY, _entry("B", 90.0, "kombi")), 1, "schneller: Platz 1")
	assert_eq(s.would_rank(KEY, 100.0), 3, "gleiche Zeit landet hinter dem bestehenden Eintrag")
	assert_eq(s.submit(KEY, _entry("C", 100.0, "kompakt")), 3, "submit = would_rank")
	assert_eq(_names(s.top(KEY)), ["B", "A", "C"] as Array[String], "Reihenfolge")
	assert_eq(str(s.record(KEY)["name"]), "B", "Rekord")
	assert_eq(s.would_rank(KEY, 0.0), 0, "ungültige Zeit")
	assert_eq(s.submit(KEY, {"name": "kaputt"}), 0, "Eintrag ohne Zeit wird ignoriert")
	for i in 7:
		s.submit(KEY, _entry("F%d" % i, 50.0 + i, "sportwagen"))
	assert_eq(s.top(KEY).size(), 10, "Top 10")
	assert_eq(s.would_rank(KEY, 100.0, "all"), 0, "langsamer als Platz 10: kein Platz")
	assert_eq(s.would_rank(KEY, 95.0), 9, "Platz 9 (hinter 7×F und B)")
	assert_eq(s.top(KEY, "", 3).size(), 3, "count begrenzt")


func test_vehicle_filter_and_per_vehicle_storage() -> void:
	var s := _store("", Callable(), {"seed_entries": false, "store_per_vehicle": true})
	for i in 12:
		s.submit(KEY, _entry("S%d" % i, 100.0 + i, "sportwagen"))
	for i in 3:
		s.submit(KEY, _entry("K%d" % i, 200.0 + i, "kompakt"))
	assert_eq(s.top(KEY, "all").size(), 10, "gesamt: Top 10")
	assert_eq(str(s.top(KEY, "")[9]["name"]), "S9", "gesamt nur Sportwagen")
	assert_eq(s.top(KEY, "sportwagen").size(), 10, "je Fahrzeug höchstens 10 gespeichert")
	assert_eq(s.entries(KEY).size(), 13, "10 Sportwagen + 3 Kompakt")
	assert_eq(_names(s.top(KEY, "kompakt")), ["K0", "K1", "K2"] as Array[String], "Kompakt-Liste vollständig")
	assert_eq(s.would_rank(KEY, 150.0, "all"), 0, "gesamt kein Platz")
	assert_eq(s.would_rank(KEY, 150.0, "kompakt"), 1, "Kompakt: Platz 1")
	assert_eq(s.rank_for_vehicle(KEY, 201.5, "kompakt"), 3, "rank_for_vehicle")
	assert_true(s.qualifies(KEY, 150.0, "kompakt"), "Namenseingabe für Kompakt-Bestzeit")
	assert_false(s.qualifies(KEY, 150.0, "sportwagen"), "keine Namenseingabe")
	assert_eq(s.submit(KEY, _entry("K!", 150.0, "kompakt"), "kompakt"), 1, "submit mit Filter: Rang in der Kompakt-Liste")
	assert_eq(str(s.record(KEY, "kompakt")["name"]), "K!", "Kompakt-Rekord")
	var shared := _store("", Callable(), {"seed_entries": false, "store_per_vehicle": false})
	for i in 12:
		shared.submit(KEY, _entry("S%d" % i, 100.0 + i, "sportwagen"))
	assert_eq(shared.submit(KEY, _entry("K", 150.0, "kompakt"), "kompakt"), 0, "nur Gesamtliste: Kompakt fällt heraus")
	assert_true(shared.top(KEY, "kompakt").is_empty(), "Kompakt-Ansicht leer")
	assert_eq(shared.entries(KEY).size(), 10, "nur 10 gespeichert")


func test_seeded_entries() -> void:
	var lengths := func(key: String) -> float: return 100.0 if key.begins_with("stage:") else 0.0
	var s := _store("", lengths)
	var list := s.top("stage:kiel_hamburg:fwd", "all", 10)
	assert_eq(list.size(), 10, "10 Starteinträge")
	var names: Array = ConfigLoader.lookup(cfg(), "leaderboard.seed_names", [])
	var avg: Array = ConfigLoader.lookup(cfg(), "leaderboard.seed_avg_kmh", [150, 190])
	var prev := 0.0
	for e in list:
		assert_true(bool(e.get("seeded", false)), "als seeded markiert")
		assert_true(names.has(str(e["name"])), "Name aus seed_names")
		assert_between(float(e["avg_kmh"]), float(avg[0]) - 0.1, float(avg[1]) + 0.1, "Schnitt im Bereich")
		assert_near(float(e["time_s"]), 100.0 / float(e["avg_kmh"]) * 300.0, 0.2, "Zeit passt zu Länge und Schnitt")
		assert_true(float(e["time_s"]) >= prev, "sortiert")
		prev = float(e["time_s"])
	var again := _store("", lengths).top("stage:kiel_hamburg:fwd", "all", 10)
	assert_eq(_names(again), _names(list), "deterministisch je Liste")
	assert_near(float(again[0]["time_s"]), float(list[0]["time_s"]), 0.0001, "gleiche Zeiten")
	var other := s.top("stage:kiel_hamburg:rev", "all", 10)
	assert_true(_names(other) != _names(list) or float(other[0]["time_s"]) != float(list[0]["time_s"]), "andere Liste, andere Einträge")
	assert_true(s.top("race:unbekannt").is_empty(), "Länge 0: keine Starteinträge")
	assert_true(_store("", lengths, {"seed_entries": false}).top("stage:kiel_hamburg:fwd").is_empty(), "seed_entries aus")
	assert_eq(s.submit("stage:kiel_hamburg:fwd", _entry("Profi", 1.0, "kombi")), 1, "echte Zeit schlägt Starteinträge")
	assert_false(bool(s.record("stage:kiel_hamburg:fwd").get("seeded", false)), "Rekord ist jetzt echt")


func test_race_board_seeded_from_shortest_route() -> void:
	var n := NetworkTest.load_network(cfg())
	var s := _store("", Callable(n, "board_length_km"))
	var best: Dictionary = s.record("race:kiel_nuernberg")
	var shortest := float(n.race_routes("kiel_nuernberg")[0]["km"])
	assert_near(float(best["time_s"]), shortest / float(best["avg_kmh"]) * 300.0, 0.5, "Rennliste aus der kürzesten Route")
	assert_true(best.has("route"), "Renn-Einträge haben route")
	var stage_best: Dictionary = s.record("stage:hamburg_hannover:fwd")
	assert_near(float(stage_best["time_s"]), 150.0 / float(stage_best["avg_kmh"]) * 300.0, 0.5, "Etappenliste aus der Etappenlänge")


func test_persistence_roundtrip() -> void:
	var p := _path("lb_roundtrip.json")
	var s := _store(p, Callable(), {"seed_entries": false})
	s.submit(KEY, _entry("A", 120.0, "kombi"))
	s.submit("race:kiel_nuernberg", _entry("R", 2000.0, "kompakt"))
	assert_true(FileAccess.file_exists(p), "Datei geschrieben")
	assert_false(FileAccess.file_exists(p + ".tmp"), "keine Temp-Datei übrig")
	assert_true(FileAccess.file_exists(p + ".bak"), "Sicherung der Vorversion")
	var raw: Variant = JsonFile.read(p)
	assert_eq(int(raw["version"]), LeaderboardStore.VERSION, "Version in der Datei")
	var s2 := _store(p, Callable(), {"seed_entries": false})
	s2.load_boards()
	assert_eq(_names(s2.top(KEY)), ["A"] as Array[String], "Etappenliste geladen")
	assert_eq(str(s2.record("race:kiel_nuernberg")["vehicle"]), "kompakt", "Rennliste geladen")
	assert_eq(s2.board_keys(), ["race:kiel_nuernberg", KEY] as Array[String], "Schlüssel")
	JsonFile.remove_all(p)


func test_corrupt_and_old_files() -> void:
	JsonFile.quiet = true
	var p := _path("lb_corrupt.json")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{ kaputt")
	f.close()
	var s := _store(p, Callable(), {"seed_entries": false})
	s.load_boards()
	assert_true(s.boards.is_empty(), "beschädigte Datei: leer starten")
	assert_ne_str(s.load_problem, "", "Problem gemeldet")
	assert_true(FileAccess.file_exists(p + ".corrupt"), "beschädigte Datei aufbewahrt")
	assert_eq(s.submit(KEY, _entry("A", 100.0, "kombi")), 1, "danach normal weiter")
	s.submit(KEY, _entry("B", 110.0, "kombi"))   # .bak now holds the file with A only
	f = FileAccess.open(p, FileAccess.WRITE)
	f.store_string("[1, 2")
	f.close()
	var s2 := _store(p, Callable(), {"seed_entries": false})
	s2.load_boards()
	assert_eq(_names(s2.top(KEY)), ["A"] as Array[String], "Hauptdatei kaputt: Sicherung gelesen")
	JsonFile.remove_all(p)
	f = FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "boards": {KEY: [{"time_s": "x"}, 5, {"name": "ok", "time_s": 50, "vehicle": "kombi"}], "x": "kein Array"}}))
	f.close()
	var s3 := _store(p, Callable(), {"seed_entries": false})
	s3.load_boards()
	assert_eq(s3.entries(KEY).size(), 1, "ungültige Einträge verworfen, Version 1 gelesen")
	assert_eq(str(s3.record(KEY)["name"]), "ok", "gültiger Eintrag")
	assert_true(s3.load_problem == "", "kein Fehler bei alter Version")
	JsonFile.remove_all(p)
	JsonFile.quiet = false


func assert_ne_str(actual: String, unexpected: String, msg: String) -> void:
	if actual == unexpected:
		fail("%s: erwartet ≠ '%s'" % [msg, unexpected])
