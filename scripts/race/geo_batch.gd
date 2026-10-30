class_name GeoBatch
extends RefCounted
## Collects coloured quads/triangles and submits them as ONE canvas command
## (RenderingServer.canvas_item_add_triangle_array). Every primitive is stored as a quad of four
## vertices (a triangle repeats its last vertex) with a precomputed index pattern, so a quad costs
## 4 + 4 appends. The painter's order is kept by calling flush() before any other draw call on the
## same canvas item (sprites, text). Owner: race module.

var verts := PackedVector2Array()
var cols := PackedColorArray()
var ci: RID
var triangles := 0      ## triangles submitted since begin() (statistics)
var commands := 0       ## triangle-array commands since begin()

var _idx := PackedInt32Array()


func begin(item: RID) -> void:
	ci = item
	verts.clear()
	cols.clear()
	triangles = 0
	commands = 0


func is_empty() -> bool:
	return verts.is_empty()


func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	verts.append(a)
	verts.append(b)
	verts.append(c)
	verts.append(d)
	cols.append(col)
	cols.append(col)
	cols.append(col)
	cols.append(col)


## Quad with one colour per vertex (a, b, c, d in order around the quad).
func quad4(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	verts.append(a)
	verts.append(b)
	verts.append(c)
	verts.append(d)
	cols.append(ca)
	cols.append(cb)
	cols.append(cc)
	cols.append(cd)


func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	quad(a, b, c, c, col)


func tri3(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	quad4(a, b, c, c, ca, cb, cc, cc)


func rect(r: Rect2, col: Color) -> void:
	quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)


## Vertical gradient rectangle (top colour, bottom colour).
func rect_v(r: Rect2, top: Color, bottom: Color) -> void:
	quad4(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), top, top, bottom, bottom)


## Filled ellipse as a triangle fan (center colour, rim colour); two fan triangles per quad.
func ellipse(center: Vector2, radius: Vector2, col: Color, rim: Color, segments: int = 14) -> void:
	var n := maxi(4, segments + segments % 2)
	var prev := center + Vector2(radius.x, 0.0)
	var i := 1
	while i <= n:
		var a1 := TAU * float(i) / float(n)
		var a2 := TAU * float(i + 1) / float(n)
		var p1 := center + Vector2(cos(a1) * radius.x, sin(a1) * radius.y)
		var p2 := center + Vector2(cos(a2) * radius.x, sin(a2) * radius.y)
		quad4(center, prev, p1, p2, col, rim, rim, rim)
		prev = p2
		i += 2


## Upper half of an ellipse (arch), flat side at center.y.
func half_ellipse(center: Vector2, radius: Vector2, col: Color, segments: int = 12) -> void:
	var n := maxi(2, segments + segments % 2)
	var prev := center + Vector2(-radius.x, 0.0)
	var i := 1
	while i <= n:
		var a1 := PI + PI * float(i) / float(n)
		var a2 := PI + PI * float(i + 1) / float(n)
		var p1 := center + Vector2(cos(a1) * radius.x, sin(a1) * radius.y)
		var p2 := center + Vector2(cos(a2) * radius.x, sin(a2) * radius.y)
		quad(center, prev, p1, p2, col)
		prev = p2
		i += 2


## Thin line segment as a quad (width in pixels).
func line(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var n := Vector2(-d.y, d.x) / l * (width * 0.5)
	quad(a - n, b - n, b + n, a + n, col)


## Same as line() but fading from colour a to colour b.
func line2(a: Vector2, b: Vector2, width: float, ca: Color, cb: Color) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var n := Vector2(-d.y, d.x) / l * (width * 0.5)
	quad4(a - n, b - n, b + n, a + n, ca, cb, cb, ca)


## Submits everything collected so far as one triangle-array command.
func flush() -> void:
	var nv := verts.size()
	if nv == 0:
		return
	var ni := nv / 4 * 6
	if _idx.size() < ni:
		var old_q := _idx.size() / 6
		var new_q := maxi(nv / 4, old_q * 2)
		_idx.resize(new_q * 6)
		for q in range(old_q, new_q):
			var b := q * 4
			var o := q * 6
			_idx[o] = b
			_idx[o + 1] = b + 1
			_idx[o + 2] = b + 2
			_idx[o + 3] = b
			_idx[o + 4] = b + 2
			_idx[o + 5] = b + 3
	RenderingServer.canvas_item_add_triangle_array(ci, _idx.slice(0, ni), verts, cols)
	triangles += ni / 3
	commands += 1
	verts.clear()
	cols.clear()
