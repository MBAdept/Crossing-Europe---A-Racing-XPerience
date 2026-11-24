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


## Store with another time-lapse factor (a time.time_scale override in game_config.json).
func _store_ts(file: String, time_scale: float, lengths: Callable = Callable(), profiles: Callable = Callable()) -> LeaderboardStore:
	var s := LeaderboardStore.new()
	s.setup(ConfigLoader.deep_merge(cfg(), {"time": {"time_scale": time_scale}}), file, lengths, profiles)
	return s


## Shipped time-lapse factor (time.time_scale).
func _ts() -> float:
	return float(ConfigLoader.lookup(cfg(), "time.time_scale", 10.0))


## Largest difference between an entry's time and length / avg_kmh: avg_kmh is rounded to 0.1 km/h.
func _avg_tolerance(e: Dictionary) -> float:
	return float(e["time_s"]) * 0.05 / maxf(float(e["avg_kmh"]) - 0.05, 1.0) + 0.01


func _entry(name: String, time_s: float, vehicle: String) -> Dictionary:
	return {"name": name, "time_s": time_s, "avg_kmh": 150.0, "vehicle": vehicle, "weather": "normal",
		"start_hour": 8.0, "daytime": "day", "date": "2026-10-30"}


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var p := DIR.path_join(name)
	_remove(p)
	return p


## The file with its temp/backup/corrupt companions and the backups of a time-lapse conversion (".2", ".3" … when a
## backup of that name already existed).
func _remove(p: String) -> void:
	JsonFile.remove_all(p)
	for suffix in [LeaderboardStore.LEGACY_BACKUP_SUFFIX, ".f10", ".f12"]:
		JsonFile.remove_all(p + suffix)
		for n in range(2, 5):
			JsonFile.remove_all("%s%s.%d" % [p, suffix, n])


func _names(list: Array) -> Array[String]:
	var out: Array[String] = []
	for e in list:
		out.append(str(e["name"]))
	return out


func _times(list: Array) -> Array[float]:
	var out: Array[float] = []
	for e in list:
		out.append(float(e["time_s"]))
	return out


## Same times within 1 ms (a JSON round trip may move a value rounded to 1/100 s by one unit in the last place).
func _assert_times_near(actual: Array[float], expected: Array[float], msg: String) -> void:
	assert_eq(actual.size(), expected.size(), msg + ": Anzahl")
	for i in mini(actual.size(), expected.size()):
		assert_near(actual[i], expected[i], 0.001, "%s (%d)" % [msg, i])


## A real entry over km at avg_kmh, measured with factor ts (plus fixed_s, a race's ferry time).
func _real(name: String, km: float, avg_kmh: float, vehicle: String, ts: float, fixed_s: float = 0.0) -> Dictionary:
	var e := _entry(name, snappedf(Units.game_seconds_for(km, avg_kmh, ts) + fixed_s, 0.01), vehicle)
	e["avg_kmh"] = avg_kmh
	return e


func _find(list: Array, name: String) -> Dictionary:
	for e in list:
		if str(e["name"]) == name:
			return e
	return {}


func _seeded(list: Array, seeded: bool) -> Array:
	return list.filter(func(e: Dictionary) -> bool: return bool(e.get("seeded", false)) == seeded)


func _write(file: String, data: Dictionary) -> void:
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


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
		assert_near(float(e["time_s"]), ref / float(e["avg_kmh"]) * 3600.0 / _ts(), _avg_tolerance(e), "Zeit passt zu Länge und Schnitt")
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


## v0.7.0: in a race the tank carries over – every stage after the first starts with what the last one left, so the
## default entries of a race board count a fuel stop for each of them (plus the tutorial's partly filled first tank).
## A stage board is unchanged: a single stage starts full (the tutorial with its 35 %).
func test_race_board_counts_a_fuel_stop_per_carried_stage() -> void:
	var n := NetworkTest.load_network(cfg())
	var kn := n.board_profile("race:kiel_nuernberg")
	assert_eq(int(kn["stages"]), 5, "Kiel – Nürnberg: 5 Etappen auf der kürzesten Route")
	assert_eq(int(kn["fuel_stops"]), 5, "4 Etappen mit übernommenem Tank + Tutorial mit 35 %")
	var dd := n.board_profile("race:dresden_dortmund")
	assert_eq(int(dd["fuel_stops"]), int(dd["stages"]) - 1, "Dresden – Dortmund: voller Start, dann je Etappe ein Stopp")
	assert_eq(int(n.board_profile("stage:hamburg_hannover:fwd")["fuel_stops"]), 0, "Einzeletappe startet voll")


func test_race_board_seeded_from_shortest_route() -> void:
	var n := NetworkTest.load_network(cfg())
	var s := _store("", Callable(n, "board_length_km"))
	var best: Dictionary = s.record("race:kiel_nuernberg")
	var shortest := float(n.race_routes("kiel_nuernberg")[0]["km"])
	assert_near(float(best["time_s"]), shortest / float(best["avg_kmh"]) * 3600.0 / _ts(), _avg_tolerance(best), "Rennliste aus der kürzesten Route")
	assert_true(best.has("route"), "Renn-Einträge haben route")
	var stage_best: Dictionary = s.record("stage:hamburg_hannover:fwd")
	assert_near(float(stage_best["time_s"]), 150.0 / float(stage_best["avg_kmh"]) * 3600.0 / _ts(), _avg_tolerance(stage_best), "Etappenliste aus der Etappenlänge")


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
	assert_near(float(raw["time_scale"]), _ts(), 0.0001, "Zeitraffer-Faktor in der Datei")
	var s2 := _store(p, Callable(), {"seed_entries": false})
	s2.load_boards()
	assert_eq(_names(s2.top(KEY)), ["A"] as Array[String], "Etappenliste geladen")
	assert_near(float(s2.record(KEY)["time_s"]), 120.0, 0.0001, "gleicher Faktor: Zeit unverändert")
	assert_eq(str(s2.record("race:kiel_nuernberg")["vehicle"]), "kompakt", "Rennliste geladen")
	assert_eq(s2.board_keys(), ["race:kiel_nuernberg", KEY] as Array[String], "Schlüssel")
	assert_eq(s2.conversion_note, "", "nichts umgerechnet")
	_remove(p)


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
	assert_near(float(s3.record(KEY)["time_s"]), 50.0 * LeaderboardStore.LEGACY_TIME_SCALE / _ts(), 0.01, "Version 1 ohne Faktor: Faktor 12 umgerechnet")
	assert_true(s3.load_problem == "", "kein Fehler bei alter Version")
	_remove(p)
	JsonFile.quiet = false


## v0.7.0 (time-lapse factor 10 instead of 12): a leaderboards file of v0.6.0 (version 2, no "time_scale" = factor 12) is
## converted once. Stage boards: real entries × 12/10 – average speed, names and order stay –, the default entries
## new (as on a fresh install). Race boards are archived and start afresh with new default entries (fuel carry-over,
## the 8-h pause and the factor change race totals). The old file stays as leaderboards.json.v06, the new one is
## version 3 with "time_scale" – a second load changes nothing.
func test_v06_file_converted_once() -> void:
	var n := NetworkTest.load_network(cfg())
	var lengths := Callable(n, "board_length_km")
	var profiles := Callable(n, "board_profile")
	var stage := "stage:hamburg_hannover:fwd"
	var race := "race:kiel_nuernberg"
	var km := n.board_length_km(stage)
	var old := _store_ts("", 12.0, lengths, profiles)   # what v0.6.0 seeded and stored (factor 12)
	var old_stage: Array = old.entries(stage).duplicate(true)
	var mine := [_real("Profi", km, 200.0, "sportwagen", 12.0), _real("Zweite", km, 180.0, "kombi", 12.0),
		_real("Langsam", km, 120.0, "kompakt", 12.0)]
	old_stage.append_array(mine)
	var old_race: Array = old.entries(race).duplicate(true)
	old_race.append(_real("Rennfahrer", n.board_length_km(race), 170.0, "limousine", 12.0))
	var p := _path("lb_v06.json")
	_write(p, {"version": 2, "boards": {stage: old_stage, race: old_race}})
	var s := _store(p, lengths, {}, profiles)
	s.load_boards()
	assert_ne_str(s.conversion_note, "", "umgerechnet")
	var conv := s.entries(stage)
	var reals := _seeded(conv, false)
	assert_eq(_names(reals), ["Profi", "Zweite", "Langsam"] as Array[String], "echte Einträge: gleiche Reihenfolge")
	for i in mini(reals.size(), mine.size()):
		var before: Dictionary = mine[i]
		var t := float(reals[i]["time_s"])
		assert_near(t, float(before["time_s"]) * 12.0 / _ts(), 0.01, "%s: Zeit × 12/10" % before["name"])
		assert_near(float(reals[i]["avg_kmh"]), float(before["avg_kmh"]), 0.0001, "%s: Schnitt bleibt" % before["name"])
		assert_near(Units.avg_speed_kmh(km, t, _ts()), float(before["avg_kmh"]), 0.05, "%s: Zeit passt zum Schnitt" % before["name"])
	var fresh := _store("", lengths, {}, profiles).entries(stage)   # a fresh install at the new factor
	var seeds := _seeded(conv, true)
	assert_eq(_names(seeds), _names(fresh), "Starteinträge wie bei einer Neuinstallation")
	assert_eq(_times(seeds), _times(fresh), "Startzeiten wie bei einer Neuinstallation")
	var rb := s.entries(race)
	assert_eq(_times(rb), _times(_store("", lengths, {}, profiles).entries(race)), "Rennliste neu begonnen")
	assert_true(_seeded(rb, false).is_empty(), "Rennliste: nur Starteinträge")
	var bak: Variant = JsonFile.read(p + LeaderboardStore.LEGACY_BACKUP_SUFFIX)
	assert_true(bak is Dictionary, "alte Datei als .v06 aufbewahrt")
	if bak is Dictionary:
		assert_eq(int(bak["version"]), 2, "Sicherung: Version 2")
		assert_eq((bak["boards"][race] as Array).size(), old_race.size(), "Sicherung: Rennliste vollständig")
	var raw: Variant = JsonFile.read(p)
	assert_eq(int(raw["version"]), LeaderboardStore.VERSION, "neue Datei: Version 3")
	assert_near(float(raw["time_scale"]), _ts(), 0.0001, "neue Datei: Faktor")
	assert_false((raw["boards"] as Dictionary).has(race), "Rennliste nicht mehr in der Datei")
	# a second load changes nothing
	var text := FileAccess.get_file_as_string(p)
	var bak_text := FileAccess.get_file_as_string(p + LeaderboardStore.LEGACY_BACKUP_SUFFIX)
	var s2 := _store(p, lengths, {}, profiles)
	s2.load_boards()
	assert_eq(s2.conversion_note, "", "zweites Laden: nichts umgerechnet")
	_assert_times_near(_times(s2.entries(stage)), _times(conv), "zweites Laden: gleiche Zeiten")
	assert_eq(FileAccess.get_file_as_string(p), text, "Datei unverändert")
	assert_eq(FileAccess.get_file_as_string(p + LeaderboardStore.LEGACY_BACKUP_SUFFIX), bak_text, "Sicherung unverändert")
	_remove(p)


## QA v0.7.0: a round trip v0.7.0 → v0.6.0 → v0.7.0. v0.6.0 rewrites the file as version 2 without a factor but keeps
## the entries' fields – the stamp "ts" of every v0.7.0 entry survives. Back in v0.7.0 those stay as they are (before:
## converted once more, × 1.44 in total), the stage entry v0.6.0 added is converted × 12/10, its race entry archived, the
## race entry of v0.7.0 kept (before: dropped with the whole race board). The file of the round trip is kept as well
## (".v06.2"; the first ".v06" stays as it was).
func test_round_trip_through_v06_keeps_converted_times() -> void:
	var n := NetworkTest.load_network(cfg())
	var lengths := Callable(n, "board_length_km")
	var profiles := Callable(n, "board_profile")
	var stage := "stage:hamburg_hannover:fwd"
	var race := "race:kiel_nuernberg"
	var km := n.board_length_km(stage)
	var race_km := n.board_length_km(race)
	var p := _path("lb_roundtrip_v06.json")
	_write(p, {"version": 2, "boards": {stage: [_real("Schnell", km, 200.0, "sportwagen", 12.0)],
		race: [_real("Rennfahrer", race_km, 170.0, "limousine", 12.0)]}})
	var s := _store(p, lengths, {}, profiles)
	s.load_boards()
	var schnell := _find(s.entries(stage), "Schnell")
	assert_near(float(schnell["ts"]), _ts(), 0.0001, "umgerechneter Eintrag trägt seinen Faktor")
	s.submit(race, _real("Prüfer", race_km, 160.0, "kombi", _ts()))
	var pruefer := float(_find(s.entries(race), "Prüfer")["time_s"])
	var first_bak := FileAccess.get_file_as_string(p + LeaderboardStore.LEGACY_BACKUP_SUFFIX)
	# v0.6.0 on the same data: keeps the entries with their fields, adds its own, writes version 2 without a factor
	var raw: Dictionary = JsonFile.read(p)
	var b: Dictionary = raw["boards"]
	(b[stage] as Array).append(_real("Alt", km, 190.0, "kompakt", 12.0))
	(b[race] as Array).append(_real("AltRennen", race_km, 150.0, "kompakt", 12.0))
	_write(p, {"version": 2, "boards": b})
	var back := _store(p, lengths, {}, profiles)
	back.load_boards()
	assert_ne_str(back.conversion_note, "", "Datei aus v0.6.0: umgerechnet")
	assert_near(float(_find(back.entries(stage), "Schnell")["time_s"]), float(schnell["time_s"]), 0.001, "umgerechnete Etappenzeit bleibt (nicht noch einmal × 1,2)")
	var alt := _find(back.entries(stage), "Alt")
	assert_near(float(alt["time_s"]), float(_real("Alt", km, 190.0, "kompakt", 12.0)["time_s"]) * 12.0 / _ts(), 0.01, "neuer Eintrag aus v0.6.0: × 12/10")
	assert_near(float(alt["avg_kmh"]), 190.0, 0.0001, "sein Schnitt bleibt")
	assert_near(float(_find(back.entries(race), "Prüfer")["time_s"]), pruefer, 0.001, "Renneintrag von v0.7.0 bleibt")
	assert_true(_find(back.entries(race), "AltRennen").is_empty(), "Renneintrag von v0.6.0 archiviert")
	var bak2: Variant = JsonFile.read(p + LeaderboardStore.LEGACY_BACKUP_SUFFIX + ".2")
	assert_true(bak2 is Dictionary and not _find(bak2["boards"][race], "AltRennen").is_empty(), "Datei der Rundreise als .v06.2 aufbewahrt")
	assert_eq(FileAccess.get_file_as_string(p + LeaderboardStore.LEGACY_BACKUP_SUFFIX), first_bak, "erste Sicherung .v06 unverändert")
	var again := _store(p, lengths, {}, profiles)
	again.load_boards()
	assert_eq(again.conversion_note, "", "danach: nichts mehr umgerechnet")
	_remove(p)


## A later change of the factor (a time.time_scale override in game_config.json) converts a version-3 file the same way,
## in both directions – race boards too, their ferry time stays. The file of each factor is kept once as
## "<path>.f<factor>"; back at the first factor the times are the original ones.
func test_time_scale_override_converts_both_ways() -> void:
	var lengths := func(key: String) -> float: return 300.0 if key.begins_with("stage:") else 1200.0
	var profiles := func(key: String) -> Dictionary: return {"stages": 5, "fixed_s": 240.0} if key.begins_with("race:") else {"stages": 1}
	var race := "race:test"
	var p := _path("lb_override.json")
	var s := _store(p, lengths, {}, profiles)
	s.submit(KEY, _real("A", 300.0, 200.0, "kombi", _ts()))
	s.submit(KEY, _real("B", 300.0, 170.0, "kompakt", _ts()))
	s.submit(race, _real("R", 1200.0, 180.0, "limousine", _ts(), 240.0))
	var a0 := float(_find(s.entries(KEY), "A")["time_s"])
	var b0 := float(_find(s.entries(KEY), "B")["time_s"])
	var r0 := float(_find(s.entries(race), "R")["time_s"])
	var first_text := FileAccess.get_file_as_string(p)
	var first_bak := p + ".f" + LeaderboardStore.factor_text(_ts())
	var s12 := _store_ts(p, 12.0, lengths, profiles)
	s12.load_boards()
	assert_ne_str(s12.conversion_note, "", "Faktor 12: umgerechnet")
	assert_near(float(_find(s12.entries(KEY), "A")["time_s"]), a0 * _ts() / 12.0, 0.01, "Etappe: Zeit × 10/12")
	var r := _find(s12.entries(race), "R")
	assert_near(float(r["time_s"]), (r0 - 240.0) * _ts() / 12.0 + 240.0, 0.01, "Rennen: gefahrene Zeit × 10/12, Fähre bleibt")
	assert_near(Units.avg_speed_kmh(1200.0, float(r["time_s"]) - 240.0, 12.0), 180.0, 0.05, "Rennschnitt ohne Fähre bleibt")
	assert_near(float(r["avg_kmh"]), 180.0, 0.0001, "Schnitt-Feld bleibt")
	assert_eq(_times(_seeded(s12.entries(KEY), true)), _times(_store_ts("", 12.0, lengths, profiles).entries(KEY)), "Starteinträge für Faktor 12 neu")
	assert_eq(FileAccess.get_file_as_string(first_bak), first_text, "Datei mit Faktor 10 aufbewahrt")
	assert_near(float(JsonFile.read(p)["time_scale"]), 12.0, 0.0001, "Datei jetzt mit Faktor 12")
	var back := _store(p, lengths, {}, profiles)
	back.load_boards()
	assert_near(float(_find(back.entries(KEY), "A")["time_s"]), a0, 0.01, "zurück: Zeit A wie vorher")
	assert_near(float(_find(back.entries(KEY), "B")["time_s"]), b0, 0.01, "zurück: Zeit B wie vorher")
	assert_near(float(_find(back.entries(race), "R")["time_s"]), r0, 0.01, "zurück: Rennzeit wie vorher")
	assert_eq(_names(back.top(KEY)), _names(s.top(KEY)), "zurück: gleiche Liste")
	assert_true(FileAccess.file_exists(p + ".f12"), "Datei mit Faktor 12 aufbewahrt")
	assert_eq(FileAccess.get_file_as_string(first_bak), first_text, "erste Sicherung nicht überschrieben")
	var again := _store(p, lengths, {}, profiles)
	again.load_boards()
	assert_eq(again.conversion_note, "", "drittes Laden: nichts umgerechnet")
	_remove(p)


func assert_ne_str(actual: String, unexpected: String, msg: String) -> void:
	if actual == unexpected:
		fail("%s: erwartet ≠ '%s'" % [msg, unexpected])
