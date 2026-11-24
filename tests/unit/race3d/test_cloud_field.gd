extends TestCase
## The cloud field of the mode "Modern" (scripts/race3d/cloud_field.gd, R7d, contract A-27): one field for the sky
## (assets/shaders/modern/sky2d.gdshader) and the cloud shadows on the land (inc/cloud_shadow.gdshaderinc) – its
## texture, the cover and its threshold, the field position across the floating origin, the shadow's strength, and
## the shaders' copies of its constants. Pure data: no scene tree, no renderer.

const SKY := "res://assets/shaders/modern/sky2d.gdshader"
const CLOUDS := "res://assets/shaders/modern/clouds2d.gdshader"
const SHADOW_INC := "res://assets/shaders/modern/inc/cloud_shadow.gdshaderinc"


func test_texture() -> void:
	var img := CloudField.image()
	assert_eq(img.get_width(), CloudField.SIZE)
	assert_eq(img.get_height(), CloudField.SIZE)
	assert_eq(img.get_format(), Image.FORMAT_RGBA8)
	assert_true(img.has_mipmaps(), "Mipmaps (der Himmel liest ferne Wolken auf groben Stufen)")
	# every layer spans its range: domes (r), billows (g), groups (b)
	for ch in 3:
		var lo := 1.0
		var hi := 0.0
		for j in range(0, CloudField.SIZE, 4):
			for i in range(0, CloudField.SIZE, 4):
				var v: float = img.get_pixel(i, j)[ch]
				lo = minf(lo, v)
				hi = maxf(hi, v)
		assert_true(lo < 0.25 and hi > 0.75, "Kanal %d nutzt seinen Bereich: %.2f … %.2f" % [ch, lo, hi])
	# the field tiles: 100 tiles of the domes are 230 of the billows and 37 of the groups
	for p: Vector2 in [Vector2(130.0, 4410.0), Vector2(-2222.0, 777.0)]:
		assert_near(CloudField.composite(p), CloudField.composite(p + Vector2(CloudField.TILE_M * 100.0, 0.0)), 0.02)
	var tex := CloudField.texture()
	assert_true(tex == CloudField.texture(), "eine Textur je Prozess")


func test_cover_and_threshold() -> void:
	var last := INF
	for c: float in [0.05, 0.12, 0.3, 0.6, 0.9]:
		var th := CloudField.threshold(c)
		assert_true(th < last, "Schwelle fällt mit der Bedeckung (%.2f)" % c)
		last = th
		# the share of the field above the threshold is the cover – on another grid than the table's
		var above := 0
		var total := 0
		for j in 61:
			for i in 61:
				var p := Vector2(i + 0.31, j + 0.77) / 61.0 * CloudField.TILE_M
				total += 1
				if CloudField.composite(p) > th:
					above += 1
		assert_near(float(above) / total, c, 0.035, "Anteil über der Schwelle bei Bedeckung %.2f" % c)
	assert_true(CloudField.threshold(0.0) > CloudField.n_max(), "Bedeckung 0: keine Wolke")
	assert_true(CloudField.threshold(1.0) < CloudField.threshold(0.999), "Bedeckung 1: geschlossene Decke")
	assert_true(CloudField.n_max() >= CloudField.threshold(0.001), "n_max ist das höchste n")


func test_cover_for_palette() -> void:
	assert_near(CloudField.cover_for({"overcast": 0.0, "glow": Color(1, 0.6, 0.3, 0.0)}), CloudField.COVER_CLEAR, 1.0e-6)
	assert_near(CloudField.cover_for({"overcast": 0.0, "glow": Color(1, 0.6, 0.3, 1.0)}), CloudField.COVER_CLEAR + CloudField.COVER_EDGE, 1.0e-6)
	assert_near(CloudField.cover_for({"overcast": 1.0}), 1.0, 1.0e-6)
	assert_near(CloudField.cover_for({}), CloudField.COVER_CLEAR, 1.0e-6)
	# real palettes: a clear day has fair-weather heaps, rain and snow a closed deck
	var daytime: Dictionary = ConfigLoader.lookup(cfg(), "daytime", {})
	for h: float in [8.0, 12.0, 19.5, 22.0]:
		assert_between(CloudField.cover_for(Palette.compute(h, "normal", daytime)), CloudField.COVER_CLEAR - 0.001,
			CloudField.COVER_CLEAR + CloudField.COVER_EDGE + 0.001)
	for w: String in ["rain", "snow"]:
		assert_near(CloudField.cover_for(Palette.compute(12.0, w, daytime)), 1.0, 1.0e-3, w)


func test_field_position_across_the_floating_origin() -> void:
	var a := Vector2(1234.5, -987.25)
	for shift: Vector2 in [Vector2(2000.0, 0.0), Vector2(-4096.0, 8192.0)]:
		# after rebased(shift) a point that stayed in the world sits at a + shift in the origin-relative frame
		var before := CloudField.field_pos(a, Vector2.ZERO, 37.0)
		var after := CloudField.field_pos(a + shift, shift, 37.0)
		assert_near(before.distance_to(after), 0.0, 1.0e-3, "Wolkenfeld bleibt bei Verschiebung %s" % shift)
	# the drift: steady, along the wind
	var d := CloudField.drift(10.0)
	assert_near(d.length(), CloudField.DRIFT_MS * 10.0, 1.0e-3)
	assert_near(d.normalized().dot(CloudField.WIND_DIR.normalized()), 1.0, 1.0e-6)


func test_shadow_strength() -> void:
	assert_near(CloudField.shadow_strength({"night": 0.0, "overcast": 0.0}, 0.0), CloudField.SHADOW, 1.0e-6)
	assert_near(CloudField.shadow_strength({"night": 1.0, "overcast": 0.0}, 0.0), 0.0, 1.0e-6, "nachts keine Wolkenschatten")
	assert_near(CloudField.shadow_strength({"night": 0.0, "overcast": 1.0}, 0.0), 0.0, 1.0e-6, "geschlossene Decke: diffuses Licht")
	assert_near(CloudField.shadow_strength({"night": 0.0, "overcast": 0.0}, 1.0), 0.0, 1.0e-6, "im Tunnel keine")
	assert_true(CloudField.SHADOW <= 0.25, "ein Wolkenschatten nimmt höchstens ein Viertel")


## The shaders carry copies of the field's constants (a shader cannot read GDScript): they must match.
func test_shader_constants_match() -> void:
	var w := CloudField.W
	assert_near(w.x + w.y + w.z, 1.0, 1.0e-6, "Gewichte ergeben 1")
	var inc := FileAccess.get_file_as_string(SHADOW_INC)
	assert_true(inc.contains("const vec3 CE_CLOUD_W = vec3(%s, %s, %s);" % [_f(w.x), _f(w.y), _f(w.z)]), "CE_CLOUD_W = CloudField.W")
	assert_true(inc.contains("const vec2 CE_CLOUD_DETAIL = vec2(%s, %s);" % [_f(CloudField.DETAIL.x), _f(CloudField.DETAIL.y)]), "CE_CLOUD_DETAIL = CloudField.DETAIL")
	var sky := FileAccess.get_file_as_string(CLOUDS)
	assert_true(sky.contains("uniform vec3 weights = vec3(%s, %s, %s);" % [_f(w.x), _f(w.y), _f(w.z)]), "clouds2d weights = CloudField.W")
	assert_true(sky.contains("uniform vec4 field = vec4(%s, %s, %s, %s);" % [_f(CloudField.TILE_M), _f(CloudField.HEIGHT_M), _f(CloudField.DETAIL.x), _f(CloudField.DETAIL.y)]), "clouds2d field = CloudField")
	assert_true(sky.contains("uniform float thick = %s;" % _f(CloudField.THICK_M)), "clouds2d thick = CloudField.THICK_M")
	assert_true(sky.contains("uniform float column_k = %s;" % _f(CloudField.COLUMN_K)), "clouds2d column_k = CloudField.COLUMN_K")
	for path: String in [SKY, CLOUDS]:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			assert_false(line.get_slice("//", 0).contains("TIME"), "Himmel nur aus Sichtzeit, nie TIME (Regel 10): " + line)


static func _f(v: float) -> String:
	var s := String.num(v, 4)
	return s if s.contains(".") else s + ".0"
