class_name GeoBatch
extends RefCounted
## Collects coloured quads/triangles and submits them as ONE canvas command
## (RenderingServer.canvas_item_add_triangle_array). Every primitive is stored as a quad of four
## vertices (a triangle repeats its last vertex) with a precomputed index pattern, so a quad costs
## 4 + 4 appends. The painter's order is kept by calling flush() before any other draw call on the
## same canvas item (sprites, text).
##
## Glow quads (glow_rect, RoadRenderer glow occlusion, docs/renn-modul.md §2): additive light quads drawn in
## painter's order with the rest of the batch. Their UVs point into the glow atlas (glow_tex: the radial gradient
## at u 0..GLOW_U1) shifted by +2 in u – the shader of the canvas item (RoadRenderer.GLOW_SHADER) adds a vertex with
## UV.x >= 2 and draws every other one normally. A flush that contains glow quads gives all other vertices the UV
## of the atlas' white block (WHITE_UV), so their colour stays exactly the same; a flush without glow quads is the
## plain untextured call as before. Owner: race module.

const GLOW_U1 := 64.0 / 72.0               ## right edge of the gradient in the atlas (72 px wide)
const WHITE_UV := Vector2(70.0 / 72.0, 0.5)  ## centre of the atlas' white block
const GLOW_FLAG_U := 2.0                    ## u offset that marks a glow vertex

var verts := PackedVector2Array()
var cols := PackedColorArray()
var ci: RID
var triangles := 0      ## triangles submitted since begin() (statistics)
var commands := 0       ## triangle-array commands since begin()
var glow_tex: RID       ## glow atlas (RoadRenderer.glow_atlas_image); needed once glow_rect is used
var glow_quads := 0     ## glow quads submitted since begin() (statistics)

var _idx := PackedInt32Array()
var _gq := PackedInt32Array()       ## first vertex of every glow quad of the current batch
var _gv := PackedFloat32Array()     ## its atlas v range (v0, v1)
var _uvw := PackedVector2Array()    ## WHITE_UV, grown on demand


func begin(item: RID) -> void:
	ci = item
	verts.clear()
	cols.clear()
	_gq.clear()
	_gv.clear()
	triangles = 0
	commands = 0
	glow_quads = 0


## Additive glow quad from (x0, y0) to (x1, y1) showing the atlas gradient rows v0..v1 (0..1 = the whole disc; a
## horizontal band of a glow passes the band's part, so adjacent bands with the same edge y join without a seam).
func glow_rect(x0: float, y0: float, x1: float, y1: float, col: Color, v0: float = 0.0, v1: float = 1.0) -> void:
	_gq.append(verts.size())
	_gv.append(v0)
	_gv.append(v1)
	quad(Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1), col)


## Number of glow quads waiting in the current batch.
func pending_glows() -> int:
	return _gq.size()


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
	if _gq.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci, _idx.slice(0, ni), verts, cols)
	else:
		RenderingServer.canvas_item_add_triangle_array(ci, _idx.slice(0, ni), verts, cols, glow_uvs(), PackedInt32Array(),
			PackedFloat32Array(), glow_tex)
		glow_quads += _gq.size()
		_gq.clear()
		_gv.clear()
	triangles += ni / 3
	commands += 1
	verts.clear()
	cols.clear()


## UVs of the current batch for a flush with glow quads: WHITE_UV for every vertex, the flagged atlas corners
## (u + GLOW_FLAG_U) for the glow quads.
func glow_uvs() -> PackedVector2Array:
	var nv := verts.size()
	if _uvw.size() < nv:
		var old := _uvw.size()
		_uvw.resize(maxi(nv, old * 2))
		for i in range(old, _uvw.size()):
			_uvw[i] = WHITE_UV
	var uv := _uvw.slice(0, nv)
	for i in _gq.size():
		var q := _gq[i]
		var v0 := _gv[i * 2]
		var v1 := _gv[i * 2 + 1]
		uv[q] = Vector2(GLOW_FLAG_U, v0)
		uv[q + 1] = Vector2(GLOW_FLAG_U + GLOW_U1, v0)
		uv[q + 2] = Vector2(GLOW_FLAG_U + GLOW_U1, v1)
		uv[q + 3] = Vector2(GLOW_FLAG_U, v1)
	return uv
