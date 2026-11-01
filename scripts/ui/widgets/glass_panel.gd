class_name GlassPanel
extends Control
## Frosted-glass card over the title photo (TitleBackdrop): the photo behind the card, blurred (mip levels of the
## same texture, same Ken Burns transform) and tinted dark blue, with chamfered corners like UiIcons.panel, a
## thin border fading from magenta to cyan and a soft light line along the top. Without the photo it falls back
## to a plain translucent panel. The card follows its own on-screen position every frame (slide-in transition).

var cut := 16.0
var border_w := 1.5
var _mat: ShaderMaterial
var _frame: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if TitleBackdrop.photo() != null:
		_mat = TitleBackdrop.glass_material()
		material = _mat
	# the border is drawn by a child without the glass material
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	resized.connect(func() -> void: _frame.queue_redraw())


func _process(_delta: float) -> void:
	if _mat == null:
		return
	# window pixels of this card in the backdrop's space (the backdrop fills the window from its top-left)
	_mat.set_shader_parameter("origin", get_global_rect().position)
	_mat.set_shader_parameter("view_size", get_viewport_rect().size)
	_mat.set_shader_parameter("height", size.y)


func _draw() -> void:
	var pts := UiIcons.chamfer_rect(Rect2(Vector2.ZERO, size), cut)
	if _mat != null:
		draw_colored_polygon(pts, Color.WHITE)
	else:
		draw_colored_polygon(pts, UiTheme.PANEL_SOFT)


func _draw_frame() -> void:
	var pts := UiIcons.chamfer_rect(Rect2(Vector2.ZERO, size), cut)
	pts.append(pts[0])
	var cols := PackedColorArray()
	for p in pts:
		# magenta at the top-left, cyan at the bottom-right
		var k := clampf((p.x / maxf(size.x, 1.0) + p.y / maxf(size.y, 1.0)) * 0.5, 0.0, 1.0)
		cols.append(Color(UiTheme.ACCENT.lerp(UiTheme.ACCENT_2, k), 0.75))
	_frame.draw_polyline_colors(pts, cols, border_w, true)
	# light line along the top edge
	_frame.draw_line(Vector2(cut + 6.0, 1.5), Vector2(size.x - 10.0, 1.5), Color(1, 1, 1, 0.18), 1.0, true)
