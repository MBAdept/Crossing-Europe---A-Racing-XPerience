import sys
W = sys.argv[1]


def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        assert old in s, (path, old[:70])
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)


patch(W + '/scripts/race3d/modern_materials.gd', [
    ('''const VEHICLE_PLAYER_DESAT := 0.35
''', '''const VEHICLE_PLAYER_DESAT := 0.35
## FIX-RINT (QA-RINT-BILD F-06): the night share of a set whose paint R4's night law does not hold – set -> Vector2(the
## desaturation at night, the paint's value at night). The red sports car: at 22:00 in the rain (render check
## check_night "spielerauto", the red-safe body sample) 1.19 × Arcade's luminance at 1.83 × its saturation – its paint
## (#cc1419) is the most saturated of the five, the sprite's red reads dark (#924750 in the studio light). The others
## stay at 0 / 1 (kompakt 1.05 × / 1.23 ×, Gran Turismo 0.92 × / 0.77 ×, limousine 0.87–0.88 × / 0.95–1.00 ×, Kombi
## 0.86 × / 1.10 ×, measured).
const VEHICLE_PLAYER_NIGHT := {"player/sportwagen": Vector2(0.6, 0.85)}
'''),
    ('''## The paint dictionary of a player car in a race (VEHICLE_PLAYER_DESAT): every colour key moved towards its luminance by
## VEHICLE_PLAYER_DESAT x (1 - night); night = the palette's night amount (0 by day, 1 at night).
static func player_paint(paint: Dictionary, night: float = 0.0) -> Dictionary:
	var out := paint.duplicate()
	var d := VEHICLE_PLAYER_DESAT * (1.0 - clampf(night, 0.0, 1.0))
	for k: String in ["paint", "paint2", "paint3"]:
		if out.has(k) and Color.html_is_valid(str(out[k])):
			var c := Color(str(out[k]))
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			out[k] = "#" + c.lerp(Color(l, l, l), d).to_html(false)
	return out''', '''## The paint dictionary of a player car in a race (VEHICLE_PLAYER_DESAT): every colour key moved towards its luminance by
## VEHICLE_PLAYER_DESAT x (1 - night); night = the palette's night amount (0 by day, 1 at night). FIX-RINT: a set of
## VEHICLE_PLAYER_NIGHT (set_id) takes its own desaturation and value at night instead (blended with the night).
static func player_paint(paint: Dictionary, night: float = 0.0, set_id: String = "") -> Dictionary:
	var out := paint.duplicate()
	var n := clampf(night, 0.0, 1.0)
	var d := VEHICLE_PLAYER_DESAT * (1.0 - n)
	var value := 1.0
	var per: Variant = VEHICLE_PLAYER_NIGHT.get(set_id)
	if per is Vector2:
		d += (per as Vector2).x * n
		value = lerpf(1.0, (per as Vector2).y, n)
	for k: String in ["paint", "paint2", "paint3"]:
		if out.has(k) and Color.html_is_valid(str(out[k])):
			var c := Color(str(out[k]))
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			var m := c.lerp(Color(l, l, l), d)
			out[k] = "#" + Color(m.r * value, m.g * value, m.b * value).to_html(false)
	return out'''),
])

patch(W + '/scripts/race3d/layers/vehicles.gd', [
    ('''			ModelFactory.apply_paint((pc as Car).node, ModernMaterials.player_paint(ModelDB.resolve((pc as Car).set_id).get("paint", {}), nt))''',
     '''			ModelFactory.apply_paint((pc as Car).node, ModernMaterials.player_paint(ModelDB.resolve((pc as Car).set_id).get("paint", {}), nt,
				(pc as Car).set_id))'''),
    ('''		ModelFactory.apply_paint(n, ModernMaterials.player_paint(ModelDB.resolve(car.set_id).get("paint", {}), _paint_night))''',
     '''		ModelFactory.apply_paint(n, ModernMaterials.player_paint(ModelDB.resolve(car.set_id).get("paint", {}), _paint_night, car.set_id))'''),
])

patch(W + '/tests/unit/race3d/test_vehicles.gd', [
    ('''	var dusk := Color(str(ModernMaterials.player_paint(src, 0.5)["paint"]))
	assert_true(dusk.s < Color(str(src["paint"])).s and dusk.s > Color(str(out["paint"])).s, "Dämmerung dazwischen")
''', '''	var dusk := Color(str(ModernMaterials.player_paint(src, 0.5)["paint"]))
	assert_true(dusk.s < Color(str(src["paint"])).s and dusk.s > Color(str(out["paint"])).s, "Dämmerung dazwischen")
	# FIX-RINT (QA-RINT-BILD F-06): the red sports car keeps a night share of its own – less saturated and darker at
	# night, unchanged by day against the others; a set without an entry as before
	var red := {"paint": "#cc1419"}
	var sw_day := Color(str(ModernMaterials.player_paint(red, 0.0, "player/sportwagen")["paint"]))
	var sw_night := Color(str(ModernMaterials.player_paint(red, 1.0, "player/sportwagen")["paint"]))
	assert_eq(sw_day.to_html(false), Color(str(ModernMaterials.player_paint(red, 0.0)["paint"])).to_html(false), "Sportwagen bei Tag wie alle")
	assert_true(sw_night.s < Color("#cc1419").s - 0.2 and sw_night.v < Color("#cc1419").v, "Sportwagen nachts weniger gesättigt und dunkler (%.2f / %.2f)" % [
		sw_night.s, sw_night.v])
	assert_eq(str(ModernMaterials.player_paint(red, 1.0, "player/limousine")["paint"]).to_lower(), "#cc1419", "ohne Eintrag nachts unverändert")
'''),
])
print("ok")
