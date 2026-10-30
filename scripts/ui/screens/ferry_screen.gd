class_name FerryScreen
extends UiScreen
## Short ferry scene for ferry legs (e.g. Riga – Rostock): animated sea with the ship crossing,
## a map inset with the crossing, and the fixed time added to the race (fixed_time_s, world_hours).
## Continues automatically after a few seconds or with Enter.

const DURATION := 7.0

var _ferry: Dictionary = {}
var _leg: Dictionary = {}
var _scene: _Sea
var _t := 0.0
var _left := false


func build() -> void:
	bg_dim = 0.85
	_ferry = params.get("ferry", {})
	_leg = params.get("leg", {})
	var title := str(_ferry.get("name", tr("Fähre")))
	add_header(tr("Fähre"), title, GameFlow.race.race_name if GameFlow.race != null else "")
	hints = [[["Enter", "pad:A"], tr("Weiter")]]
	_scene = _Sea.new()
	UiKit.place(self, _scene, Rect2(40, 104, 1200, 380))
	var map := MapView.new()
	map.set_network(UiData.cities(), UiData.stages(), UiData.ferries(), UiData.map_data())
	var a := str(_leg.get("from", _ferry.get("from", "")))
	var b := str(_leg.get("to", _ferry.get("to", "")))
	map.highlight = [{"from": a, "to": b, "style": "ferry"}]
	map.current_city = a
	UiKit.place(self, map, Rect2(40, 496, 420, 168))
	map.fit_to([a, b])
	var info := add_panel(Rect2(480, 496, 760, 168), UiTheme.ACCENT_2, 4)
	info.add_child(UiKit.label(tr("Überfahrt %s – %s") % [UiData.city_name(a), UiData.city_name(b)], UiTheme.F.HEADING, 28, Color.WHITE))
	var fixed := float(_ferry.get("fixed_time_s", 0.0))
	var hours := float(_ferry.get("world_hours", 0.0))
	info.add_child(UiKit.stat_line(tr("Feste Zeit für die Rennwertung"), "+" + UiFormat.time(fixed), UiTheme.GOLD, 22))
	info.add_child(UiKit.stat_line(tr("Dauer der Überfahrt (Weltzeit)"), tr("%d Stunden") % roundi(hours), UiTheme.TEXT, 22))
	if GameFlow.race != null:
		var arrive := GameFlow.race.world_minutes + hours * 60.0
		info.add_child(UiKit.stat_line(tr("Weiterfahrt ab %s") % UiData.city_name(b), tr("%s Uhr") % Units.format_clock(arrive), UiTheme.TEXT, 22))
	var ok := UiKit.button(tr("Weiter"), 24, HORIZONTAL_ALIGNMENT_CENTER)
	ok.pressed.connect(_continue)
	UiKit.place(self, ok, Rect2(1040, 420, 180, 50))
	default_focus = ok


func _process(delta: float) -> void:
	_t += delta
	_scene.progress = clampf(_t / DURATION, 0.0, 1.0)
	if _t >= DURATION + 1.5 and not GameFlow.sample_mode:
		_continue()


func _continue() -> void:
	if _left:
		return
	_left = true
	GameFlow.ferry_done()


func on_cancel() -> void:
	pass


class _Sea extends Control:
	var progress := 0.0
	var _t := 0.0

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var hy := h * 0.42
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, hy), Vector2(0, hy)]),
			PackedColorArray([Color("0b1638"), Color("0b1638"), Color("e0745a"), Color("e0745a")]))
		draw_circle(Vector2(w * 0.78, hy - 10), 46.0, Color("ffd27a"))
		draw_rect(Rect2(0, hy, w, h - hy), Color("0b2a52"))
		# waves
		for row in 9:
			var y := hy + 8.0 + row * row * 3.4 + row * 6.0
			var amp := 1.5 + row * 0.7
			var pts := PackedVector2Array()
			var k := 0.0
			while k <= w:
				pts.append(Vector2(k, y + sin(k * 0.03 + _t * (1.0 + row * 0.2) + row) * amp))
				k += 12.0
			draw_polyline(pts, Color(0.55, 0.75, 1.0, 0.12 + row * 0.03), 1.5 + row * 0.15)
		# ship (sprite if present, else drawn)
		var x := lerpf(-200.0, w + 40.0, progress)
		var bob := sin(_t * 1.6) * 3.0
		var base := Vector2(x, hy + 70 + bob)
		var db: Node = get_node_or_null("/root/SpriteDB")
		if db != null and db.call("has_set", "props/ferry_ship"):
			var tex: Texture2D = db.call("texture", "props/ferry_ship")
			var region: Rect2 = db.call("region", "props/ferry_ship", "c", "base")
			if tex != null and region.size.x > 0.0:
				var s := 220.0 / region.size.x
				draw_texture_rect_region(tex, Rect2(base - Vector2(110, region.size.y * s * 0.9), region.size * s), region)
				return
		var hull := PackedVector2Array([base + Vector2(-110, -20), base + Vector2(120, -20), base + Vector2(96, 14), base + Vector2(-96, 14)])
		draw_colored_polygon(hull, Color("e8ecf4"))
		draw_rect(Rect2(base + Vector2(-96, 2), Vector2(192, 12)), Color("1f5fbf"))
		draw_rect(Rect2(base + Vector2(-70, -48), Vector2(130, 28)), Color("f4f6fb"))
		draw_rect(Rect2(base + Vector2(-40, -70), Vector2(76, 22)), Color("f4f6fb"))
		for i in 8:
			draw_rect(Rect2(base + Vector2(-62 + i * 15, -40), Vector2(8, 8)), Color("2b3b66"))
		draw_rect(Rect2(base + Vector2(10, -92), Vector2(16, 24)), UiTheme.ACCENT)
		# wake
		for i in 6:
			draw_line(base + Vector2(-110 - i * 26, 10 + i * 2), base + Vector2(-130 - i * 26, 10 + i * 2), Color(1, 1, 1, 0.5 - i * 0.07), 2.0)
		var smoke := fmod(_t, 1.0)
		draw_circle(base + Vector2(18 - smoke * 30, -100 - smoke * 20), 6.0 + smoke * 8.0, Color(0.8, 0.8, 0.85, 0.5 * (1.0 - smoke)))
