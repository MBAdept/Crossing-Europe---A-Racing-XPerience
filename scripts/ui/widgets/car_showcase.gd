class_name CarShowcase
extends Control
## Vehicle showroom: the SpriteDB "showroom/<id>" sprite on a glowing turntable platform, with a
## slide/fade animation when the vehicle changes. Falls back to the player sprite or a silhouette.

var vehicle_id := ""
var sprite_id := ""
var _anim := 1.0
var _dir := 1.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_vehicle(id: String, showroom_set: String, dir: float = 1.0) -> void:
	vehicle_id = id
	sprite_id = showroom_set
	_anim = 0.0
	_dir = dir
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_anim = minf(1.0, _anim + delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.78)
	# platform
	for i in 4:
		var rr := Vector2(size.x * (0.42 - i * 0.05), size.y * (0.11 - i * 0.012))
		var pts := PackedVector2Array()
		for k in 48:
			var a := TAU * k / 48.0
			pts.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y))
		draw_colored_polygon(pts, Color(UiTheme.ACCENT_2, 0.05 + i * 0.03))
	var ring := PackedVector2Array()
	for k in 65:
		var a := TAU * k / 64.0
		ring.append(c + Vector2(cos(a) * size.x * 0.42, sin(a) * size.y * 0.11))
	draw_polyline(ring, Color(UiTheme.ACCENT_2, 0.6 + 0.2 * sin(_t * 2.0)), 2.0, true)
	var db: Node = get_node_or_null("/root/SpriteDB")
	var tex: Texture2D = null
	var region := Rect2()
	if db != null:
		for sid in [sprite_id, "player/" + vehicle_id]:
			if db.call("has_set", sid):
				tex = db.call("texture", sid)
				region = db.call("region", sid, "c", "base")
				if tex != null:
					break
	var e := 1.0 - pow(1.0 - _anim, 3.0)
	var off := Vector2((1.0 - e) * 120.0 * _dir, 0)
	var alpha := e
	if tex != null and region.size.x > 0.0:
		var max_w := size.x * 0.92
		var max_h := size.y * 0.8
		var s := minf(max_w / region.size.x, max_h / region.size.y)
		var sz := region.size * s
		var anchor := Vector2(0.5, 0.92)
		if db != null:
			anchor = db.call("anchor", sprite_id) if db.call("has_set", sprite_id) else anchor
		var pos := c - Vector2(sz.x * anchor.x, sz.y * anchor.y) + off
		draw_texture_rect_region(tex, Rect2(pos, sz), region, Color(1, 1, 1, alpha))
	else:
		var body := Rect2(c.x - 150 + off.x, c.y - 90, 300, 80)
		draw_rect(body, Color(UiTheme.ACCENT, 0.6 * alpha))
		draw_string(UiTheme.font(UiTheme.F.HEADING), Vector2(body.position.x, body.position.y + 50), vehicle_id, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 24, Color(1, 1, 1, alpha))
