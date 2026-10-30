extends TestCase
## Data module: the GameData autoload script, instantiated directly (tests do not rely on autoloads).

const GameDataScript := preload("res://scripts/data/game_data.gd")


func test_wrapper_api() -> void:
	var gd: Node = GameDataScript.new()
	var races: Dictionary = gd.get("races")
	assert_true(races.has("kiel_nuernberg"), "Rennen geladen")
	assert_eq(str(gd.get("network_source")), "res://data/network.json", "eingebautes Netz")
	var visible_races: Array = gd.call("visible_race_ids")
	assert_eq(visible_races, ["kiel_nuernberg", "dresden_dortmund", "muenchen_bremen", "koenigsrennen"], "Rennen im Menü")
	var visible_stages: Array = gd.call("visible_stage_ids")
	assert_false(visible_stages.has("dev_testetappe"), "Entwickler-Etappe versteckt")
	assert_eq(str(visible_stages[0]), "kiel_hamburg", "Tutorial-Etappe zuerst")
	var plan: StagePlan = gd.call("get_stage_plan", "hamburg_hannover", "hannover")
	assert_true(plan != null and plan.reversed, "Rückrichtung")
	assert_true(plan.warnings.is_empty(), "keine Warnungen")
	assert_eq(str(gd.call("stage_board_key", "hamburg_hannover", "hannover")), "stage:hamburg_hannover:rev", "Etappen-Schlüssel")
	assert_eq(str(gd.call("race_board_key", "koenigsrennen")), "race:koenigsrennen", "Renn-Schlüssel")
	var opts: Array = gd.call("next_options", "kiel_nuernberg", "hamburg", 0, ["kiel", "hamburg"])
	assert_eq(opts.size(), 2, "Wahl in Hamburg")
	assert_true((gd.call("validate") as Array).is_empty(), "Daten gültig: %s" % str(gd.get("warnings")))
	var ferry := false
	for leg in gd.call("connections_from", "riga"):
		ferry = ferry or str(leg["kind"]) == "ferry"
	assert_true(ferry, "Fähre ab Riga")
	var summary: Dictionary = gd.call("stage_summary", "bern_mailand", "bern")
	assert_eq(int(summary["tunnels"]), 3, "drei Tunnel")
	assert_eq(str(summary["name"]), "Bern – Mailand", "Anzeigename")
	assert_true(str(summary["roads"]) != "", "Straßennummern")
	var race: Dictionary = gd.call("race_summary", "kiel_nuernberg")
	assert_eq(int(race["routes"]), 2, "zwei Routen")
	assert_near(float(gd.call("board_length_km", "race:kiel_nuernberg")), float(race["min_km"]), 0.01, "Rennlänge")
	assert_eq(str(gd.call("city_name", "luettich")), "Lüttich", "deutscher Name")
	assert_eq(str(gd.call("country_name", "CH")), "Schweiz", "Ländername")
	assert_eq(str(gd.call("police_set_for", "IT")), "police/it", "Polizei-Sprite")
	assert_eq(str(gd.call("next_target", "koenigsrennen", 0)), "hamburg", "erstes Ziel")
	assert_true((gd.call("map_size") as Vector2).x > 0.0, "Karte geladen")
	assert_true((gd.call("city_map_pos", "kiel") as Vector2).distance_to(gd.call("project_latlon", 54.323, 10.123)) < 1.0, "Projektion")
	assert_true(gd.call("missing_scenery_ids") is Array, "fehlende Landschaften als Liste")
	gd.free()
