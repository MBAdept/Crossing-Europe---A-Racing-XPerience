class_name BoxVehicle
extends RefCounted
## Trucks and buses as perspective-projected textured boxes (docs/fahrzeug-darstellung.md §4, manifest
## "render": "box"). Pure geometry, no nodes: the renderer passes a road sampler and submits the arrays as one
## canvas triangle-array command per vehicle and scene slice (painter's order with the rest of the scene).
##
## Box coordinates (manifest "parts"): relative to the vehicle centre in metres, z along (+ = front), x across
## (+ = right), y height above the road. The vehicle centre stands at road position (zc, xc) – exactly the
## collision box of the TrafficSystem (lane, length, width): all parts follow the road geometry.
##
## Road sampler (Callable): road(z) -> Vector3(x, y, depth) in camera space: lateral offset of the road
## centre from the camera axis, road height relative to the camera (negative = below), depth = z - camera z.
## Side and top faces are cut into slices along the road (at most max_slice_m, closer to the camera at most
## slice_ratio of their depth), each projected with the road geometry of its ends – the box bends with the
## curve. Slices behind the near plane are cut off (a truck beside the player stays visible). Canvas triangles
## map textures affinely; short slices plus a subdivision of each slice into strips of constant depth keep the
## error below about subdiv_px. Faces are visible when their outside faces the camera (left/right per slice,
## top only below the camera, rear when in front of the camera); everything is emitted far to near.
## Face images (seen from outside, u = left -> right, v = top -> bottom): rear u x0->x1, v y1->y0 ·
## left u z1->z0, v y1->y0 · right u z0->z1, v y1->y0 · top u x0->x1, v z1->z0. Owner: race module.

var focal := 711.0
var half_w := 640.0
var horizon := 324.0
var near := 0.3
var screen := Vector2(1280, 720)
var max_slice_m := 2.0
var slice_ratio := 0.12
var subdiv_px := 1.5
var tex_size := Vector2(1, 1)

# output of emit(): one triangle-array command
var pts := PackedVector2Array()
var uvs := PackedVector2Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
var quads := 0
var rear_drawn := false        ## the rear face with the rear lights was emitted (light glows)
var rear_rect := Rect2()       ## its screen rectangle
var order := PackedFloat32Array()   ## depth of every emitted primitive, in drawing order (tests)
var debug := false                  ## record every emitted face in `faces_out` (tests)
var faces_out: Array = []           ## {part, face, world (road z, x, height per corner), screen, uv}

var _order_of: Array = []           ## parts array whose drawing order is cached in _order
var _order := PackedInt32Array()



func setup(proj: RoadProjection, slice_m: float, ratio: float, err_px: float) -> void:
	focal = proj.focal
	half_w = proj.screen.x * 0.5
	horizon = proj.horizon_y
	near = proj.near
	screen = proj.screen
	max_slice_m = maxf(0.25, slice_m)
	slice_ratio = maxf(0.02, ratio)
	subdiv_px = maxf(0.25, err_px)


func clear() -> void:
	pts.clear()
	uvs.clear()
	cols.clear()
	idx.clear()
	quads = 0
	rear_drawn = false
	rear_rect = Rect2()
	order.clear()
	faces_out.clear()


## Slice boundaries (world z) of [z_a, z_b] for a part whose rear end is at z_part0: fixed positions relative
## to the vehicle (multiples of the slice length from the part's rear end), the slice length a power-of-two
## fraction of max_slice_m chosen from the depth (camera at cam_z) – stable textures while the vehicle moves.
func slice_bounds(z_a: float, z_b: float, z_part0: float, cam_z: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var z := z_a
	out.append(z)
	var guard := 0
	while z < z_b - 0.0005 and guard < 400:
		guard += 1
		var depth := maxf(z - cam_z, near)
		var ds := max_slice_m
		while ds > 0.13 and ds > slice_ratio * depth:
			ds *= 0.5
		var rel := z - z_part0
		var nz := z_part0 + (floorf(rel / ds + 0.0001) + 1.0) * ds
		z = minf(nz, z_b)
		out.append(z)
	return out


## Emits the visible faces of `parts` (SpriteDB.box_parts) of a vehicle centred at road position (zc, xc),
## limited to the road range [z_lo, z_hi) (one scene slice), far to near: parts by their front end, each part's
## side/top slices from its front towards the camera, then its rear face. lights: SpriteDB.box_lights;
## tail/brake 0..1 (overlay strength); col = modulate (ambient, fog, alpha).
func emit(parts: Array, lights: Dictionary, zc: float, xc: float, z_lo: float, z_hi: float, cam_z: float, road: Callable, col: Color, tail: float, brake: float) -> void:
	var z_near := cam_z + near
	if not is_same(parts, _order_of):
		_order_of = parts
		_order = part_order(parts)
	for pi in _order:
		var p: Dictionary = parts[pi]
		var faces: Dictionary = p["faces"]
		var pz0 := zc + float(p["z0"])
		var pz1 := zc + float(p["z1"])
		var a := maxf(maxf(pz0, z_lo), z_near)
		var b := minf(pz1, z_hi)
		if b > a + 0.0005 and (faces.has("left") or faces.has("right") or faces.has("top")):
			var bounds := slice_bounds(a, b, pz0, cam_z)
			var i := bounds.size() - 1
			var rb: Vector3 = road.call(bounds[i])
			while i > 0:
				var ra: Vector3 = road.call(bounds[i - 1])
				order.append((bounds[i - 1] + bounds[i]) * 0.5 - cam_z)
				_slice(p, pi, lights, zc, xc, bounds[i - 1], bounds[i], ra, rb, col, tail, brake)
				rb = ra
				i -= 1
		if faces.has("rear") and pz0 >= z_lo and pz0 < z_hi and pz0 > z_near:
			order.append(pz0 - cam_z)
			_rear(p, pi, lights, zc, xc, road, col, tail, brake)


func _rear_lit(lights: Dictionary, pi: int) -> bool:
	var any := false
	for kind: String in lights:
		for l: Dictionary in lights[kind]:
			any = true
			if int(l["part"]) == pi and str(l["face"]) == "rear":
				return true
	return not any and _order.size() > 0 and pi == _order[_order.size() - 1]


## Part indices far to near (by their front end; parts follow each other along the vehicle).
static func part_order(parts: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in parts.size():
		var z1 := float((parts[i] as Dictionary)["z1"])
		var j := out.size()
		while j > 0 and float((parts[out[j - 1]] as Dictionary)["z1"]) < z1:
			j -= 1
		out.insert(j, i)
	return out


## Left/right face visibility of a face line from (xa, za) to (xb, zb) in camera space (za < zb): the left
## face (outside towards -x) is seen when the camera lies left of the line, i.e. xa * zb - xb * za > 0.
static func side_visible(xa: float, za: float, xb: float, zb: float, left: bool) -> bool:
	var c := xa * zb - xb * za
	return c > 0.0 if left else c < 0.0


func _scr(x: float, y: float, d: float) -> Vector2:
	var s := focal / d
	return Vector2(half_w + x * s, horizon - y * s)


## One slice [za, zb] of the side and top faces of a part; ra/rb = road samples at its ends.
func _slice(p: Dictionary, pi: int, lights: Dictionary, zc: float, xc: float, za: float, zb: float, ra: Vector3, rb: Vector3, col: Color, tail: float, brake: float) -> void:
	var faces: Dictionary = p["faces"]
	if ra.z <= near * 0.999 or rb.z <= ra.z:
		return
	var y0 := float(p["y0"])
	var y1 := float(p["y1"])
	var len_p := maxf(0.001, float(p["z1"]) - float(p["z0"]))
	var ua := (za - zc - float(p["z0"])) / len_p      # 0 at the rear end of the part, 1 at its front
	var ub := (zb - zc - float(p["z0"])) / len_p
	var eps := (rb.z - ra.z) / ra.z
	for side: String in ["left", "right"]:
		if not faces.has(side):
			continue
		var xf := xc + float(p["x0"] if side == "left" else p["x1"])
		var xa := ra.x + xf
		var xb := rb.x + xf
		if not side_visible(xa, ra.z, xb, rb.z, side == "left"):
			continue
		var a0 := _scr(xa, ra.y + y0, ra.z)
		var a1 := _scr(xa, ra.y + y1, ra.z)
		var b0 := _scr(xb, rb.y + y0, rb.z)
		var b1 := _scr(xb, rb.y + y1, rb.z)
		if _offscreen(a0, a1, b0, b1):
			continue
		# u along the image: left face front -> rear, right face rear -> front
		var u_a := (1.0 - ua) if side == "left" else ua
		var u_b := (1.0 - ub) if side == "left" else ub
		var m := _strips(eps, a0.y - a1.y)
		var rect: Rect2 = faces[side]
		if debug:
			_record(pi, side, [Vector3(za, xf, y1), Vector3(za, xf, y0), Vector3(zb, xf, y1), Vector3(zb, xf, y0)], [a1, a0, b1, b0],
				[Vector2(u_a, 0.0), Vector2(u_a, 1.0), Vector2(u_b, 0.0), Vector2(u_b, 1.0)])
		_strip_quad(a1, a0, b1, b0, rect, Vector2(u_a, 0.0), Vector2(u_a, 1.0), Vector2(u_b, 0.0), Vector2(u_b, 1.0), m, col)
		_overlays(lights, pi, side, a1, a0, b1, b0, Vector2(u_a, 0.0), Vector2(u_a, 1.0), Vector2(u_b, 0.0), Vector2(u_b, 1.0), m, col.a, tail, brake)
	if faces.has("top") and ra.y + y1 < 0.0 and rb.y + y1 < 0.0:
		var t_a0 := _scr(ra.x + xc + float(p["x0"]), ra.y + y1, ra.z)
		var t_a1 := _scr(ra.x + xc + float(p["x1"]), ra.y + y1, ra.z)
		var t_b0 := _scr(rb.x + xc + float(p["x0"]), rb.y + y1, rb.z)
		var t_b1 := _scr(rb.x + xc + float(p["x1"]), rb.y + y1, rb.z)
		if not _offscreen(t_a0, t_a1, t_b0, t_b1):
			var mt := _strips(eps, t_a1.x - t_a0.x)
			if debug:
				var x0 := xc + float(p["x0"])
				var x1 := xc + float(p["x1"])
				_record(pi, "top", [Vector3(za, x0, y1), Vector3(za, x1, y1), Vector3(zb, x0, y1), Vector3(zb, x1, y1)], [t_a0, t_a1, t_b0, t_b1],
					[Vector2(0.0, 1.0 - ua), Vector2(1.0, 1.0 - ua), Vector2(0.0, 1.0 - ub), Vector2(1.0, 1.0 - ub)])
			# top image: u x0 -> x1, v front (top of the image) -> rear
			_strip_quad(t_a0, t_a1, t_b0, t_b1, faces["top"], Vector2(0.0, 1.0 - ua), Vector2(1.0, 1.0 - ua), Vector2(0.0, 1.0 - ub), Vector2(1.0, 1.0 - ub), mt, col)
			_overlays(lights, pi, "top", t_a0, t_a1, t_b0, t_b1, Vector2(0.0, 1.0 - ua), Vector2(1.0, 1.0 - ua), Vector2(0.0, 1.0 - ub), Vector2(1.0, 1.0 - ub), mt, col.a, tail, brake)


func _rear(p: Dictionary, pi: int, lights: Dictionary, zc: float, xc: float, road: Callable, col: Color, tail: float, brake: float) -> void:
	var z := zc + float(p["z0"])
	var r: Vector3 = road.call(z)
	if r.z <= near:
		return
	var tl := _scr(r.x + xc + float(p["x0"]), r.y + float(p["y1"]), r.z)
	var br := _scr(r.x + xc + float(p["x1"]), r.y + float(p["y0"]), r.z)
	var tr := Vector2(br.x, tl.y)
	var bl := Vector2(tl.x, br.y)
	if _offscreen(tl, tr, bl, br):
		return
	var rect: Rect2 = (p["faces"] as Dictionary)["rear"]
	if debug:
		var x0 := xc + float(p["x0"])
		var x1 := xc + float(p["x1"])
		_record(pi, "rear", [Vector3(z, x0, float(p["y1"])), Vector3(z, x1, float(p["y1"])), Vector3(z, x0, float(p["y0"])), Vector3(z, x1, float(p["y0"]))],
			[tl, tr, bl, br], [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
	_strip_quad(tl, tr, bl, br, rect, Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), 1, col)
	_overlays(lights, pi, "rear", tl, tr, bl, br, Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), 1, col.a, tail, brake)
	# the rear lights glow at the face that carries the light overlays (else at the rearmost part)
	if _rear_lit(lights, pi):
		rear_drawn = true
		rear_rect = Rect2(tl, br - tl)


func _overlays(lights: Dictionary, pi: int, face: String, a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, ua0: Vector2, ua1: Vector2, ub0: Vector2, ub1: Vector2, m: int, alpha: float, tail: float, brake: float) -> void:
	if lights.is_empty() or (tail <= 0.03 and brake <= 0.03):
		return
	for kind: String in ["tail", "brake"]:
		var k := tail if kind == "tail" else brake
		if k <= 0.03:
			continue
		for l: Dictionary in lights.get(kind, []):
			if int(l["part"]) == pi and str(l["face"]) == face:
				_strip_quad(a0, a1, b0, b1, l["rect"], ua0, ua1, ub0, ub1, m, Color(1, 1, 1, alpha * k))


func _record(pi: int, face: String, world: Array, screen: Array, uv: Array) -> void:
	faces_out.append({"part": pi, "face": face, "world": PackedVector3Array(world), "screen": PackedVector2Array(screen), "uv": PackedVector2Array(uv)})


## Number of strips of constant depth for a slice with relative depth growth eps and an edge of h_px pixels.
func _strips(eps: float, h_px: float) -> int:
	var h := minf(absf(h_px), screen.y * 1.5)
	return clampi(int(ceil(eps * h / (4.0 * subdiv_px))), 1, 10)


func _offscreen(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var m := 4.0
	if a.x < -m and b.x < -m and c.x < -m and d.x < -m:
		return true
	if a.x > screen.x + m and b.x > screen.x + m and c.x > screen.x + m and d.x > screen.x + m:
		return true
	if a.y < -m and b.y < -m and c.y < -m and d.y < -m:
		return true
	return a.y > screen.y + m and b.y > screen.y + m and c.y > screen.y + m and d.y > screen.y + m


## Quad between the near edge a0 -> a1 and the far edge b0 -> b1 (each at constant depth), cut into m strips
## along the edges. uv* = face coordinates 0..1, mapped into `rect` (sheet pixels, inset by half a pixel).
func _strip_quad(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, rect: Rect2, ua0: Vector2, ua1: Vector2, ub0: Vector2, ub1: Vector2, m: int, col: Color) -> void:
	var r := rect.grow(-0.5)
	var inv := Vector2(1.0 / tex_size.x, 1.0 / tex_size.y)
	for i in m:
		var t0 := float(i) / float(m)
		var t1 := float(i + 1) / float(m)
		var base := pts.size()
		pts.append(a0.lerp(a1, t0))
		pts.append(a0.lerp(a1, t1))
		pts.append(b0.lerp(b1, t1))
		pts.append(b0.lerp(b1, t0))
		uvs.append((r.position + r.size * ua0.lerp(ua1, t0)) * inv)
		uvs.append((r.position + r.size * ua0.lerp(ua1, t1)) * inv)
		uvs.append((r.position + r.size * ub0.lerp(ub1, t1)) * inv)
		uvs.append((r.position + r.size * ub0.lerp(ub1, t0)) * inv)
		cols.append(col)
		cols.append(col)
		cols.append(col)
		cols.append(col)
		idx.append(base)
		idx.append(base + 1)
		idx.append(base + 2)
		idx.append(base)
		idx.append(base + 2)
		idx.append(base + 3)
		quads += 1
