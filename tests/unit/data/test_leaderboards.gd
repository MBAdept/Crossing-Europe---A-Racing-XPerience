extends TestCase
## Data module: leaderboards (LeaderboardStore) – ranking, vehicle filter, per-vehicle storage, seeding,
## persistence with a temporary file and robustness against damaged files.

const NetworkTest := preload("res://tests/unit/data/test_network_data.gd")
const DIR := "user://test_data_module"
const KEY := "stage:test:fwd"


func _store(file: String = "", lengths: Callable = Callable(), lb: Dictionary = {}, profiles: Callable = Callable()) -> LeaderboardStore:
	var c := cfg()
	if not lb.is_empty():
		c = ConfigLoader.deep_merge(c, {"leaderboard": lb})
	var s := LeaderboardStore.new()
	s.setup(c, file, lengths, profiles)
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
	# seed_avg_kmh is the average of a typical stage (seed_ref_km, with its City Limits)
	var ref := float(ConfigLoader.lookup(cfg(), "leaderboard.seed_ref_km", 235.0))
	var lengths := func(key: String) -> float: return ref if key.begins_with("stage:") else 0.0
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
		assert_near(float(e["time_s"]), ref / float(e["avg_kmh"]) * 300.0, 0.3, "Zeit passt zu Länge und Schnitt")
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


## Review v0.5.0 (QA): every board got default entries in the same 125–165 km/h band, from the length alone – on the
## tutorial Kiel – Hamburg (95 km, 20 of them City Limits, a fuel stop because it starts with 35 % tank) the record
## 2:52.73 was only 4 % slower than the fastest car without any traffic, and even the 10th place was out of reach of
## a careful driver. Now the entries follow the make-up of the board (RoadNetwork.board_profile): City Limits at
## seed_city_kmh, the fuel stop of a stage that starts with a partly filled tank, the ferry of a race. Rule: the best
## entry at least 15 % slower than the fastest car without traffic, the 10th at most 10 % faster than the careful
## autopilot at 08:00 (measured with run_stage.gd / run_race.gd: sports car at vmax without traffic 166.6 s, autopilot
## limousine 282.7–330.4 s).
func test_seed_entries_follow_the_stage_make_up() -> void:
	var n := NetworkTest.load_network(cfg())
	var s := _store("", Callable(n, "board_length_km"), {}, Callable(n, "board_profile"))
	var tut := s.top("stage:kiel_hamburg:fwd", "all", 10)
	assert_eq(tut.size(), 10, "10 Starteinträge")
	assert_true(float(tut[0]["time_s"]) >= 166.6 * 1.15, "Tutorial: Rekord %.1f s nicht schneller als 15 %% über der Zeit ohne Verkehr" % float(tut[0]["time_s"]))
	assert_true(float(tut[9]["time_s"]) >= 282.7 * 0.9, "Tutorial: 10. Platz %.1f s erreichbar" % float(tut[9]["time_s"]))
	var back := s.top("stage:kiel_hamburg:rev", "all", 10)
	assert_true(float(back[0]["time_s"]) < float(tut[0]["time_s"]) - 20.0, "Rückrichtung ohne Pflicht-Tankstopp schneller")
	assert_eq(int(n.board_profile("stage:kiel_hamburg:fwd")["fuel_stops"]), 1, "Tankstopp gehört zum Tutorial")
	assert_eq(int(n.board_profile("stage:kiel_hamburg:rev")["fuel_stops"]), 0, "Rückrichtung: voller Tank")
	# the typical stage keeps its times: seed_ref_km / seed_avg_kmh
	var ref := float(ConfigLoader.lookup(cfg(), "leaderboard.seed_ref_km", 235.0))
	var avg: Array = ConfigLoader.lookup(cfg(), "leaderboard.seed_avg_kmh", [125, 165])
	var city: Array = ConfigLoader.lookup(cfg(), "leaderboard.seed_city_kmh", [60, 80])
	assert_near(s.seed_hours(ref, 20.0, float(avg[1]), float(city[1])), ref / float(avg[1]), 0.0001, "typische Etappe unverändert (schnell)")
	assert_near(s.seed_hours(ref, 20.0, float(avg[0]), float(city[0])), ref / float(avg[0]), 0.0001, "typische Etappe unverändert (langsam)")
	# short stages (fixed 20 km of City Limits) are slower on average than long ones
	var short := s.record("stage:hamburg_bremen:fwd")
	var long := s.record("stage:luettich_paris:fwd")
	assert_true(float(short["avg_kmh"]) < float(long["avg_kmh"]) - 10.0, "kurze Etappe langsamer im Schnitt (%.0f gegen %.0f km/h)"
		% [float(short["avg_kmh"]), float(long["avg_kmh"])])
	# a race adds its ferry time
	var kr := n.board_profile("race:koenigsrennen")
	assert_true(float(kr["fixed_s"]) >= 240.0, "Königsrennen: Fährzeit Riga – Rostock")
	var plain := s.seed_entries_for("race:koenigsrennen", float(kr["length_km"]), {"stages": kr["stages"], "fuel_stops": kr["fuel_stops"]})
	var with_ferry := s.seed_entries_for("race:koenigsrennen", float(kr["length_km"]), kr)
	assert_near(float(with_ferry[0]["time_s"]) - float(plain[0]["time_s"]), float(kr["fixed_s"]), 0.05, "Fährzeit in den Starteinträgen")


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
