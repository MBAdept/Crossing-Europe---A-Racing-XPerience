class_name MenuBackground
extends Control
## Animated retro-modern menu backdrop (80s synthwave): night sky with stars, striped sunset sun,
## mountain silhouettes, a highway running to the horizon over a scrolling perspective grid.
## `target_dim` darkens it for information-dense screens (animated).

var horizon_frac := 0.6
var sun_x_frac := 0.7
var dim := 0.0
var target_dim := 0.0
var scroll_speed := 1.2
var _t := 0.0
var _stars: Array[Vector3] = []
var _far: PackedVector2Array
var _near: PackedVector2Array


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	for i in 140:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.85, rng.randf() * TAU))
	_far = _ridge(rng, 26, 0.17, 0.05)
	_near = _ridge(rng, 18, 0.11, 0.035)


## Ridge points in normalized coordinates (x 0..1, y = height above horizon as fraction of height).
func _ridge(rng: RandomNumberGenerator, n: int, amp: float, base: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var x := float(i) / n
		var valley := clampf(absf(x - sun_x_frac) / 0.16, 0.0, 1.0)
		var hgt := (base + rng.randf() * amp) * (0.25 + 0.75 * valley)
		pts.append(Vector2(x, hgt))
	return pts


func _process(delta: float) -> void:
	_t += delta
	dim = move_toward(dim, target_dim, delta * 2.5)
	queue_redraw()


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw() -> void:
	var vs := size if size.x > 2.0 else get_viewport_rect().size
	var w := vs.x
	var h := vs.y
	var hy := h * horizon_frac
	var vp := Vector2(w * sun_x_frac, hy)
	# sky
	_vgrad(Rect2(0, 0, w, hy * 0.5), Color("04051a"), Color("100a34"))
	_vgrad(Rect2(0, hy * 0.5, w, hy * 0.5 + 1.0), Color("100a34"), Color("47104f"))
	for s in _stars:
		var a := 0.35 + 0.35 * sin(_t * 1.7 + s.z)
		draw_rect(Rect2(s.x * w, s.y * hy * 0.9, 2, 2), Color(1, 1, 1, a))
	# sun with animated stripes in its lower half (smooth edges: one trapezoid per slice)
	var sr := 124.0
	var sc := Vector2(vp.x, hy - 78.0)
	draw_circle(sc, sr * 1.7, Color(1.0, 0.3, 0.55, 0.05))
	draw_circle(sc, sr * 1.25, Color(1.0, 0.45, 0.4, 0.06))
	var slices := 64
	var stripe_phase := fposmod(_t * 0.18, 1.0)
	for i in slices:
		var y0 := sc.y - sr + 2.0 * sr * i / slices
		var y1 := y0 + 2.0 * sr / slices
		var rel := ((y0 + y1) * 0.5 - sc.y) / sr
		if rel > 0.12:
			# 6 stripes below the centre, gaps grow towards the bottom and drift downwards
			var band := fposmod((rel - 0.12) / 0.88 * 6.0 - stripe_phase, 1.0)
			var gap := 0.12 + 0.5 * (rel - 0.12)
			if band < gap:
				continue
		var h0 := sqrt(maxf(0.0, sr * sr - (y0 - sc.y) * (y0 - sc.y)))
		var h1 := sqrt(maxf(0.0, sr * sr - (y1 - sc.y) * (y1 - sc.y)))
		var f := float(i) / slices
		var col := Color("ffe66b").lerp(Color("ff8a2a"), clampf(f * 1.6, 0.0, 1.0)).lerp(UiTheme.ACCENT, clampf(f * 1.6 - 0.7, 0.0, 1.0))
		draw_colored_polygon(PackedVector2Array([Vector2(sc.x - h0, y0), Vector2(sc.x + h0, y0), Vector2(sc.x + h1, y1 + 0.5), Vector2(sc.x - h1, y1 + 0.5)]), col)
	# mountains
	_draw_ridge(_far, w, hy, h, Color("2a0f52"), Color(UiTheme.ACCENT, 0.35))
	_draw_ridge(_near, w, hy, h, Color("180737"), Color(UiTheme.ACCENT_2, 0.4))
	# ground
	draw_rect(Rect2(0, hy, w, h - hy), Color("0a0322"))
	draw_rect(Rect2(0, hy - 1, w, 3), Color(UiTheme.ACCENT, 0.9))
	_vgrad(Rect2(0, hy - 14, w, 13), Color(UiTheme.ACCENT, 0.0), Color(UiTheme.ACCENT, 0.25))
	# perspective grid
	var depth := 28
	var scroll := fmod(_t * scroll_speed, 1.0)
	for i in depth:
		var z := 1.0 + i - scroll
		if z < 0.35:
			continue
		var y := hy + (h - hy) * 0.35 / z
		var a := clampf(1.0 - z / depth, 0.0, 1.0)
		draw_line(Vector2(0, y), Vector2(w, y), Color(UiTheme.ACCENT, 0.55 * a * a + 0.04), 1.0 + a)
	for j in range(-16, 17):
		var xb := vp.x + j * 150.0
		draw_polyline_colors(PackedVector2Array([vp, Vector2(vp.x + (xb - vp.x) * 2.2, hy + (h - hy) * 2.2)]),
			PackedColorArray([Color(UiTheme.ACCENT, 0.0), Color(UiTheme.ACCENT, 0.7)]), 1.5)
	# highway
	var rb := 300.0
	var road := PackedVector2Array([vp + Vector2(-3, 0), vp + Vector2(3, 0), Vector2(vp.x + rb, h), Vector2(vp.x - rb, h)])
	draw_colored_polygon(road, Color("0e0627"))
	draw_line(vp + Vector2(-3, 0), Vector2(vp.x - rb, h), UiTheme.ACCENT_2, 2.5, true)
	draw_line(vp + Vector2(3, 0), Vector2(vp.x + rb, h), UiTheme.ACCENT_2, 2.5, true)
	var dash_scroll := fmod(_t * scroll_speed * 2.0, 2.0)
	var k := 0.0
	while k < depth:
		var z0 := 1.0 + k - dash_scroll
		var z1 := z0 + 0.9
		k += 2.0
		if z0 < 0.36:
			continue
		var y0 := hy + (h - hy) * 0.35 / z0
		var y1 := hy + (h - hy) * 0.35 / z1
		var w0 := 6.0 * 0.35 / z0 * 3.0
		var w1 := 6.0 * 0.35 / z1 * 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(vp.x - w1, y1), Vector2(vp.x + w1, y1), Vector2(vp.x + w0, y0), Vector2(vp.x - w0, y0)]),
			Color(UiTheme.GOLD, clampf(1.2 - z0 / depth, 0.0, 1.0)))
	if dim > 0.001:
		draw_rect(Rect2(0, 0, w, h), Color(0.015, 0.02, 0.07, dim))


func _draw_ridge(pts: PackedVector2Array, w: float, hy: float, h: float, fill: Color, rim: Color) -> void:
	var poly := PackedVector2Array()
	var rim_pts := PackedVector2Array()
	for p in pts:
		var q := Vector2(p.x * w, hy - p.y * h)
		poly.append(q)
		rim_pts.append(q)
	poly.append(Vector2(w, hy + 1))
	poly.append(Vector2(0, hy + 1))
	draw_colored_polygon(poly, fill)
	draw_polyline(rim_pts, rim, 1.5, true)
