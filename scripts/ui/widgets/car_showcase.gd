class_name CarShowcase
extends Control
## Vehicle showroom: the SpriteDB "showroom/<id>" sprite on a glowing turntable platform, with a
## slide/fade animation when the vehicle changes. Falls back to the player sprite or a silhouette.
## v0.8.0: in the graphics mode "Modern" a car whose showroom set the model manifest marks `showroom: true` is shown
## by the real-time 3D showroom (Showroom3D, scripts/ui/widgets/showroom_3d.gd) in the same place – loaded at run
## time and only in Modern, so an Arcade start never compiles any 3D code. While its model loads the place stays
## empty (no sprite flashing up first); a car without a showroom model keeps the sprite. Switching "Grafik" in the
## options changes it at once (Settings.graphics_changed); leaving Modern frees the 3D showroom.

const SHOWROOM_SCRIPT := "res://scripts/ui/widgets/showroom_3d.gd"

var vehicle_id := ""
var sprite_id := ""
var stage3d: Control = null          ## the 3D showroom (Showroom3D) while the game is Modern, else null
var _anim := 1.0
var _dir := 1.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := get_node_or_null("/root/Settings")
	if st != null and st.has_signal(&"graphics_changed"):
		st.connect(&"graphics_changed", _on_graphics_changed)


func show_vehicle(id: String, showroom_set: String, dir: float = 1.0) -> void:
	vehicle_id = id
	sprite_id = showroom_set
	_anim = 0.0
	_dir = dir
	_update_3d()
	queue_redraw()


## True while the 3D showroom shows the car (or loads it): the sprite and the 2D platform are not drawn then.
func shows_3d() -> bool:
	return stage3d != null and is_instance_valid(stage3d) and (stage3d.visible or bool(stage3d.call(&"is_loading")))


## Modern: the 3D showroom, created for the first car that has a showroom model and kept while the screen lives
## (it hides itself for a car without one – scrolling through the cars does not load a model twice). Arcade: it
## goes, with what it loaded.
func _update_3d() -> void:
	if sprite_id == "" or not is_inside_tree():
		return
	var st := get_node_or_null("/root/Settings")
	var modern := st != null and st.has_method(&"is_modern") and bool(st.call(&"is_modern"))
	if not modern:
		_drop_3d()
		return
	if stage3d == null or not is_instance_valid(stage3d):
		var script: GDScript = load(SHOWROOM_SCRIPT) as GDScript if ResourceLoader.exists(SHOWROOM_SCRIPT) else null
		if script == null or not bool(script.call(&"can_show", sprite_id)):
			return
		stage3d = script.new()
		add_child(stage3d)
	stage3d.call(&"show_vehicle", sprite_id, _dir)


func _drop_3d() -> void:
	if stage3d != null and is_instance_valid(stage3d):
		stage3d.call(&"release")
		stage3d.queue_free()
	stage3d = null


## "Grafik" changed (options): Modern shows the 3D showroom, Arcade the sprite – at once.
func _on_graphics_changed(_mode: String) -> void:
	_update_3d()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_anim = minf(1.0, _anim + delta * 4.0)
	queue_redraw()


func _draw() -> void:
	if shows_3d():
		return   # the 3D showroom draws turntable and car
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
