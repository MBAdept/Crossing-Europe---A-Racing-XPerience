extends SceneTree
## Rendering check (needs a real renderer, not --headless): mirrored sprites are drawn exactly where the
## unmirrored ones would be. Godot 4 keeps the position of a rect with negative width and only mirrors
## the texture; RoadRenderer.flipped_draw_rect relies on that (RENDER-1: left-side buildings used to be
## drawn one image width too far right, i.e. on the road).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       -s res://tests/race/check_sprite_flip.gd
## Prints "FLIP-CHECK OK" and exits 0, else "FLIP-CHECK FEHLER …" and exits 1.
## RoadRenderer is loaded at runtime (-s scripts compile before the autoloads it uses).

var _vp: SubViewport
var _frames := 0
var _rr: GDScript


class Painter extends Node2D:
	var tex: Texture2D
	var flipped_rect := Rect2()
	var plain_rect := Rect2()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 400, 200), Color.BLACK)
		draw_texture_rect_region(tex, flipped_rect, Rect2(0, 0, 100, 40))
		draw_texture_rect_region(tex, plain_rect, Rect2(0, 0, 100, 40))


func _initialize() -> void:
	_rr = load("res://scripts/race/road_renderer.gd")
	var img := Image.create(100, 40, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 50, 40), Color(0, 1, 0))   # left half green
	img.fill_rect(Rect2i(50, 0, 50, 40), Color(1, 0, 0))  # right half red
	var p := Painter.new()
	p.tex = ImageTexture.create_from_image(img)
	var dest := Rect2(100, 20, 100, 40)
	p.flipped_rect = _rr.call("flipped_draw_rect", dest)
	p.plain_rect = Rect2(250, 120, 100, 40)
	_vp = SubViewport.new()
	_vp.size = Vector2i(400, 200)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.add_child(p)
	root.add_child(_vp)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var img := _vp.get_texture().get_image()
	if img == null or img.is_empty():
		print("FLIP-CHECK FEHLER: kein Bild (läuft der Check mit --headless? Er braucht einen echten Renderer)")
		quit(1)
		return true
	var errors: Array[String] = []
	_check_row(img, 40, 100, 199, Color(1, 0, 0), Color(0, 1, 0), "gespiegelt", errors)
	_check_row(img, 140, 250, 349, Color(0, 1, 0), Color(1, 0, 0), "ungespiegelt", errors)
	if errors.is_empty():
		print("FLIP-CHECK OK: gespiegelte Sprites liegen an Ort und Stelle (x 100..199, rot links)")
		quit(0)
	else:
		for e in errors:
			print("FLIP-CHECK FEHLER: ", e)
		quit(1)
	return true


## Row y must be lit exactly from x0 to x1, with left_col on the left and right_col on the right half.
func _check_row(img: Image, y: int, x0: int, x1: int, left_col: Color, right_col: Color, label: String, errors: Array[String]) -> void:
	var first := -1
	var last := -1
	for x in img.get_width():
		var c := img.get_pixel(x, y)
		if c.r + c.g + c.b > 0.5:
			if first < 0:
				first = x
			last = x
	if absi(first - x0) > 1 or absi(last - x1) > 1:
		errors.append("%s: Zeile %d hell von x %d bis %d, erwartet %d bis %d" % [label, y, first, last, x0, x1])
		return
	var lc := img.get_pixel(x0 + 10, y)
	var rc := img.get_pixel(x1 - 10, y)
	if lc.r > 0.5 != (left_col.r > 0.5) or rc.r > 0.5 != (right_col.r > 0.5):
		errors.append("%s: Farben links %s / rechts %s" % [label, str(lc), str(rc)])
