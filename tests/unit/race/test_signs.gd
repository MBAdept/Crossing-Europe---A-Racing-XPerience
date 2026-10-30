extends TestCase
## Road signs: country styles from data/countries.json (design document: „Grenzübergänge: Wechsel von
## Schildern …"), board sizes used to fit signs onto tunnel walls.


func _countries() -> Dictionary:
	var d: Variant = ConfigLoader.load_json("res://data/countries.json")
	return (d as Dictionary).get("countries", {}) if d is Dictionary else {}


func test_country_styles_from_data() -> void:
	var data := _countries()
	assert_true(data.size() >= 10, "Länderdaten geladen")
	var de := SignPainter.style_for(data, "DE")
	var nl := SignPainter.style_for(data, "NL")
	var fr := SignPainter.style_for(data, "FR")
	var ch := SignPainter.style_for(data, "CH")
	var it := SignPainter.style_for(data, "IT")
	assert_eq(de["town_bg"], Color.html(str(data["DE"]["signs"]["town_bg"])), "DE: Ortsschild aus den Daten (gelb)")
	assert_eq(de["road"], de["town_bg"], "DE: Wegweiser abseits der Autobahn gelb")
	assert_eq(de["motorway"], Color.html(str(data["DE"]["signs"]["motorway"])), "DE: Autobahn-Wegweiser blau")
	assert_eq(nl["town_bg"], Color.html(str(data["NL"]["signs"]["town_bg"])), "NL: blaues Ortsschild")
	assert_eq(nl["town_fg"], Color.html(str(data["NL"]["signs"]["town_fg"])), "NL: weiße Schrift")
	assert_eq(fr["town_border"], Color.html(str(data["FR"]["signs"]["town_border"])), "FR: roter Rand")
	assert_eq(ch["motorway"], Color.html(str(data["CH"]["signs"]["motorway"])), "CH: grüne Autobahn-Wegweiser")
	assert_eq(ch["road"], SignPainter.BLUE_AB, "CH: Hauptstraßen blau")
	assert_eq(it["road"], SignPainter.BLUE_AB, "IT: Hauptstraßen blau")
	assert_true(de["town_bg"] != nl["town_bg"] and nl["town_bg"] != fr["town_bg"], "Ortsschilder wechseln an der Grenze")
	assert_true(de["motorway"] != ch["motorway"], "Autobahn-Wegweiser wechseln an der Grenze")
	for code: String in data:
		var st := SignPainter.style_for(data, code)
		for pair: Array in [["town_bg", "town_fg"], ["motorway", "motorway_fg"], ["road", "road_fg"]]:
			var bg: Color = st[pair[0]]
			var fg: Color = st[pair[1]]
			assert_true(absf(bg.get_luminance() - fg.get_luminance()) > 0.3, "%s: %s lesbar" % [code, pair[0]])


func test_unknown_country_uses_the_german_style() -> void:
	var st := SignPainter.style_for({}, "XX")
	assert_eq(st["town_bg"], SignPainter.YELLOW, "gelbes Ortsschild")
	assert_eq(st["motorway"], SignPainter.BLUE_AB, "blaue Autobahn-Wegweiser")
	assert_eq(st["road"], SignPainter.YELLOW, "gelbe Wegweiser")
	var custom := SignPainter.style_for({"QQ": {"signs": {"motorway": "#1c7a3c", "road": "#ffffff"}}}, "QQ")
	assert_eq(custom["road"], Color.html("#ffffff"), "eigene Farbe für Wegweiser")
	assert_eq(custom["road_fg"], SignPainter.BLACK, "dunkle Schrift auf hellem Grund")


func test_board_sizes() -> void:
	for kind: String in ["limit", "unlimited", "radar", "fuel", "fuel_lane", "town", "distance", "border", "tunnel", "autobahn", "autobahn_end"]:
		assert_between(SignPainter.board_half_width(kind), 0.5, 2.5, "Schildbreite %s" % kind)
	assert_near(SignPainter.board_half_width("distance"), 2.4, 0.0001, "Wegweiser 4,8 m breit")
