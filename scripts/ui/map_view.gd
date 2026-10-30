class_name MapView
extends Control
## Europe map for menus: country polygons from data/map/europe_map.json (ARCHITECTURE.md §4.5) –
## without that file a graceful fallback (sea + graticule, no countries) –, the stage network as lines
## between city map_pos, the race route (driven solid, planned dashed), highlighted legs (current
## stage animated, route options), pulsing current position, city labels without overlaps.
## The view auto-fits to `focus_ids` (or the whole network).
##
## Usage: var m := MapView.new(); m.set_network(cities, stages, ferries, map_data)
##        m.route = [...]; m.highlight = [{from, to, style}]; m.current_city = "..."; m.fit_to(ids)
## Highlight styles: "current" (animated), "option", "option_selected", "planned", "ferry".

var cities: Dictionary = {}          ## id -> {name, map_pos?, latlon?, country, dev?}
var links: Array[Dictionary] = []    ## {kind: "stage"|"ferry", id, from, to}
var map_data: Dictionary = {}
var route: Array[String] = []        ## visited/planned city chain
var route_done := 0                  ## number of legs of `route` already driven
var highlight: Array[Dictionary] = []
var current_city := ""
var focus_ids: Array[String] = []
var label_ids: Array[String] = []    ## cities that always get a label (besides route/highlight)
var show_network := true
var show_all_labels := false
var padding := 0.16
var min_span := 80.0                 ## minimum map units shown (avoid absurd zoom on one stage)
var frame := true

var _xf := Transform2D.IDENTITY
var _country_meshes: Dictionary = {}  ## code -> ArrayMesh
var _country_lines: Dictionary = {}   ## code -> PackedVector2Array (segments, map space)
var _route_countries: Dictionary = {}
var _t := 0.0
var _font: Font
var _font_bold: Font


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.font(UiTheme.F.BODY)
	_font_bold = UiTheme.font(UiTheme.F.BODY_BOLD)
	resized.connect(_refit)


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


## Network from plain dictionaries (GameData.cities/stages/ferries/map_data or sample data).
func set_network(p_cities: Dictionary, stages: Dictionary, ferries: Dictionary, p_map: Dictionary) -> void:
	cities = p_cities
	links.clear()
	for id in stages:
		var s: Dictionary = stages[id]
		if bool(s.get("dev", false)):
			continue
		links.append({"kind": "stage", "id": id, "from": str(s.get("from", "")), "to": str(s.get("to", ""))})
	for id in ferries:
		var f: Dictionary = ferries[id]
		links.append({"kind": "ferry", "id": id, "from": str(f.get("from", "")), "to": str(f.get("to", ""))})
	map_data = p_map
	_build_country_meshes()
	_refit()


## Fits the view to these cities (empty = all non-dev cities).
func fit_to(ids: Array) -> void:
	focus_ids.clear()
	for i in ids:
		focus_ids.append(str(i))
	_refit()


## Map position of a city: map_pos, else a simple projection of latlon.
func city_pos(id: String) -> Vector2:
	var c: Dictionary = cities.get(id, {})
	var mp: Variant = c.get("map_pos", null)
	if mp is Array and (mp as Array).size() >= 2:
		return Vector2(float(mp[0]), float(mp[1]))
	var ll: Variant = c.get("latlon", null)
	if ll is Array and (ll as Array).size() >= 2:
		return project_latlon(float(ll[0]), float(ll[1]))
	return Vector2.INF


## Fallback projection (only used if a city has no map_pos).
static func project_latlon(lat: float, lon: float) -> Vector2:
	return Vector2((lon + 12.0) * 17.5, (72.0 - lat) * 27.0)


## Transform map space -> local pixels so that `points` fill `rect_size` with `pad` margin (uniform).
static func compute_fit(points: Array[Vector2], rect_size: Vector2, pad: float, span_min: float) -> Transform2D:
	if points.is_empty() or rect_size.x <= 1.0 or rect_size.y <= 1.0:
		return Transform2D.IDENTITY
	var r := Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	var c := r.get_center()
	var span := Vector2(maxf(r.size.x, span_min), maxf(r.size.y, span_min))
	span *= 1.0 + pad * 2.0
	var s := minf(rect_size.x / span.x, rect_size.y / span.y)
	return Transform2D(0.0, Vector2(s, s), 0.0, rect_size * 0.5 - c * s)


func _refit() -> void:
	var pts: Array[Vector2] = []
	var ids: Array = focus_ids if not focus_ids.is_empty() else cities.keys()
	for id in ids:
		if bool(cities.get(id, {}).get("dev", false)) and focus_ids.is_empty():
			continue
		var p := city_pos(str(id))
		if p != Vector2.INF:
			pts.append(p)
	_xf = compute_fit(pts, size, padding, min_span)
	_route_countries.clear()
	for id in route:
		_route_countries[str(cities.get(id, {}).get("country", ""))] = true
	for h in highlight:
		_route_countries[str(cities.get(str(h.get("to", "")), {}).get("country", ""))] = true
	queue_redraw()


func refresh() -> void:
	_refit()


func _build_country_meshes() -> void:
	_country_meshes.clear()
	_country_lines.clear()
	var list: Array = map_data.get("countries", [])
	for c in list:
		if not c is Dictionary:
			continue
		var code := str(c.get("code", ""))
		var verts := PackedVector2Array()
		var idx := PackedInt32Array()
		var lines := PackedVector2Array()
		for poly in c.get("polygons", []):
			var pts := PackedVector2Array()
			for p in poly:
				if p is Array and (p as Array).size() >= 2:
					pts.append(Vector2(float(p[0]), float(p[1])))
			if pts.size() < 3:
				continue
			for i in pts.size():
				lines.append(pts[i])
				lines.append(pts[(i + 1) % pts.size()])
			var tri := Geometry2D.triangulate_polygon(pts)
			if tri.is_empty():
				continue
			var base := verts.size()
			verts.append_array(pts)
			for t in tri:
				idx.append(base + t)
		_country_lines[code] = lines
		if idx.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_country_meshes[code] = mesh


func _p(id: String) -> Vector2:
	var mp := city_pos(id)
	return _xf * mp if mp != Vector2.INF else Vector2.INF


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, UiTheme.SEA)
	_draw_graticule()
	if not _country_meshes.is_empty() or not _country_lines.is_empty():
		draw_set_transform_matrix(_xf)
		for code in _country_meshes:
			var col := UiTheme.LAND.lightened(0.12) if _route_countries.has(code) else UiTheme.LAND
			draw_mesh(_country_meshes[code], null, Transform2D.IDENTITY, col)
		for code in _country_lines:
			draw_multiline(_country_lines[code], Color(0.36, 0.45, 0.85, 0.55))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if show_network:
		for l in links:
			var a := _p(str(l["from"]))
			var b := _p(str(l["to"]))
			if a == Vector2.INF or b == Vector2.INF:
				continue
			if l["kind"] == "ferry":
				draw_dashed_line(a, b, Color(0.4, 0.65, 1.0, 0.45), 2.0, 6.0)
			else:
				draw_line(a, b, Color(0.42, 0.52, 0.95, 0.38), 2.0, true)
	_draw_route()
	_draw_highlights()
	_draw_cities()
	if frame:
		draw_rect(r, Color(UiTheme.ACCENT_2, 0.35), false, 1.5)
		var k := 16.0
		for corner in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), size]:
			var sx := 1.0 if corner.x == 0.0 else -1.0
			var sy := 1.0 if corner.y == 0.0 else -1.0
			draw_line(corner, corner + Vector2(k * sx, 0), UiTheme.ACCENT_2, 3.0)
			draw_line(corner, corner + Vector2(0, k * sy), UiTheme.ACCENT_2, 3.0)
	if cities.is_empty():
		draw_string(_font, Vector2(0, size.y * 0.5), tr("Karte nicht verfügbar"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, UiTheme.TEXT_DIM)


func _draw_graticule() -> void:
	var col := Color(0.3, 0.42, 0.8, 0.08)
	var step := 40.0
	var x := fmod(_xf.origin.x, step)
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), col, 1.0)
		x += step
	var y := fmod(_xf.origin.y, step)
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0)
		y += step


func _draw_route() -> void:
	for i in range(1, route.size()):
		var a := _p(route[i - 1])
		var b := _p(route[i])
		if a == Vector2.INF or b == Vector2.INF:
			continue
		if i <= route_done:
			draw_line(a, b, Color(UiTheme.GOLD, 0.3), 9.0, true)
			draw_line(a, b, UiTheme.GOLD, 4.0, true)
		else:
			draw_dashed_line(a, b, Color(UiTheme.GOLD, 0.8), 3.0, 8.0)


func _draw_highlights() -> void:
	for h in highlight:
		var a := _p(str(h.get("from", "")))
		var b := _p(str(h.get("to", "")))
		if a == Vector2.INF or b == Vector2.INF:
			continue
		var style := str(h.get("style", "current"))
		match style:
			"option":
				draw_dashed_line(a, b, Color(UiTheme.ACCENT_2, 0.55), 3.0, 7.0)
			"option_selected":
				draw_line(a, b, Color(UiTheme.ACCENT_2, 0.25), 12.0, true)
				draw_line(a, b, UiTheme.ACCENT_2, 5.0, true)
				_draw_packets(a, b, Color.WHITE)
			"planned":
				draw_dashed_line(a, b, Color(UiTheme.GOLD, 0.75), 3.0, 8.0)
			"ferry":
				draw_dashed_line(a, b, Color(0.5, 0.75, 1.0, 0.95), 4.0, 9.0)
				_draw_packets(a, b, Color(0.7, 0.9, 1.0))
			_:
				draw_line(a, b, Color(UiTheme.ACCENT, 0.3), 14.0, true)
				draw_line(a, b, UiTheme.ACCENT, 5.0, true)
				_draw_packets(a, b, Color.WHITE)


func _draw_packets(a: Vector2, b: Vector2, col: Color) -> void:
	var dist := a.distance_to(b)
	if dist < 4.0:
		return
	var n := maxi(1, int(dist / 46.0))
	for i in n:
		var f := fmod(_t * 0.35 + float(i) / n, 1.0)
		draw_circle(a.lerp(b, f), 3.0, Color(col, 0.9 * sin(f * PI)))


func _draw_cities() -> void:
	var important := {}
	for id in route:
		important[id] = 1
	for h in highlight:
		important[str(h.get("from", ""))] = 1
		important[str(h.get("to", ""))] = 1
	for id in label_ids:
		important[id] = 1
	if current_city != "":
		important[current_city] = 2
	# dots
	for id in cities:
		var c: Dictionary = cities[id]
		if bool(c.get("dev", false)) and not important.has(id):
			continue
		var p := _p(str(id))
		if p == Vector2.INF or not Rect2(Vector2(-20, -20), size + Vector2(40, 40)).has_point(p):
			continue
		if important.has(id):
			draw_circle(p, 6.0, Color(0.02, 0.03, 0.1))
			draw_circle(p, 4.5, Color.WHITE)
		else:
			draw_circle(p, 3.0, Color(0.6, 0.66, 0.9, 0.7))
	# pulsing current position
	if current_city != "":
		var cp := _p(current_city)
		if cp != Vector2.INF:
			var ph := fmod(_t * 0.9, 1.0)
			draw_arc(cp, 7.0 + ph * 16.0, 0.0, TAU, 32, Color(UiTheme.ACCENT, 1.0 - ph), 2.5, true)
			draw_circle(cp, 6.5, UiTheme.ACCENT)
			draw_circle(cp, 3.0, Color.WHITE)
	# labels (important first, greedy without overlaps)
	var placed: Array[Rect2] = []
	var order: Array = []
	if current_city != "":
		order.append(current_city)
	for id in important:
		if id != current_city:
			order.append(id)
	if show_all_labels:
		for id in cities:
			if not important.has(id) and not bool(cities[id].get("dev", false)):
				order.append(id)
	for id in order:
		var p := _p(str(id))
		if p == Vector2.INF:
			continue
		var city_label := str(cities.get(id, {}).get("name", id))
		var is_imp := important.has(id)
		var fs := 18 if is_imp else 14
		var font := _font_bold if is_imp else _font
		var sz := font.get_string_size(city_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var cands := [Vector2(9, -6), Vector2(-9 - sz.x, -6), Vector2(-sz.x * 0.5, -12), Vector2(-sz.x * 0.5, sz.y + 6), Vector2(9, sz.y * 0.6)]
		for off: Vector2 in cands:
			var base := p + off
			var rect := Rect2(base.x - 2, base.y - sz.y * 0.8, sz.x + 4, sz.y)
			if not Rect2(Vector2.ZERO, size).encloses(rect):
				continue
			var hit := false
			for q in placed:
				if q.intersects(rect):
					hit = true
					break
			if hit:
				continue
			placed.append(rect)
			var col := Color.WHITE if is_imp else Color(0.7, 0.75, 0.95, 0.75)
			if str(id) == current_city:
				col = UiTheme.GOLD
			draw_string_outline(font, base, city_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.02, 0.03, 0.1, 0.85))
			draw_string(font, base, city_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			break
