extends TestCase
## Trucks and buses as textured boxes (docs/fahrzeug-darstellung.md §4, BoxVehicle): the drawn box is the
## collision box, faces are visible when they face the camera, the sides bend with the road in slices of at
## most 2 m, the part behind the camera is cut off, faces are emitted far to near, the texture orientation.
## Camera at road z = 0; road samplers: straight, constant curve (lateral offset k * z² / 2), lower road.

const W := 2.55
const L := 16.5
const H := 4.0

var _k := 0.0                  ## curvature of the test road (1/m)
var _cam_h := 3.4              ## camera height above the road


func _road(z: float) -> Vector3:
	return Vector3(_k * z * z * 0.5, -_cam_h, z)


func _proj() -> RoadProjection:
	var p := RoadProjection.new()
	p.setup(ConfigLoader.lookup(cfg(), "render", {}), Vector2(1280, 720))
	return p


func _box() -> BoxVehicle:
	var b := BoxVehicle.new()
	b.setup(_proj(), 2.0, 0.12, 1.5)
	b.tex_size = Vector2(1024, 1024)
	b.debug = true
	return b


func _parts() -> Array:
	var faces := {"rear": Rect2(0, 0, 122, 192), "left": Rect2(130, 0, 792, 192), "right": Rect2(130, 200, 792, 192), "top": Rect2(0, 400, 122, 792)}
	return [{"name": "body", "z0": -L * 0.5, "z1": L * 0.5, "x0": -W * 0.5, "x1": W * 0.5, "y0": 0.0, "y1": H, "faces": faces}]


func _emit(b: BoxVehicle, zc: float, xc: float, z_lo: float = -1000.0, z_hi: float = 1000.0) -> void:
	b.clear()
	b.emit(_parts(), {}, zc, xc, z_lo, z_hi, 0.0, _road, Color.WHITE, 0.0, 0.0)


func _faces(b: BoxVehicle, face: String) -> Array:
	var out: Array = []
	for f: Dictionary in b.faces_out:
		if str(f["face"]) == face:
			out.append(f)
	return out


## Truck 30 m ahead in the right neighbour lane: rear and left flank visible; the bottom edges of the drawn
## faces run exactly along the collision box (lane centre ± W/2, rear ± L/2), every corner is projected with
## the camera and the road.
func test_drawn_box_is_the_collision_box() -> void:
	_k = 0.0
	var p := _proj()
	var b := _box()
	var zc := 30.0 + L * 0.5
	var xc := 3.75
	_emit(b, zc, xc)
	assert_eq(_faces(b, "rear").size(), 1, "Heck sichtbar")
	assert_true(_faces(b, "left").size() >= 8, "linke Flanke sichtbar, in Abschnitte geteilt")
	assert_eq(_faces(b, "right").size(), 0, "rechte Flanke abgewandt")
	assert_eq(_faces(b, "top").size(), 0, "Dach über der Kamera unsichtbar")
	var zmin := INF
	var zmax := -INF
	var xs := {}
	for f: Dictionary in b.faces_out:
		var world: PackedVector3Array = f["world"]
		var screen: PackedVector2Array = f["screen"]
		for i in world.size():
			var w := world[i]
			var r := _road(w.x)
			var expected := p.project(r.x + w.y, r.y + w.z, r.z)
			assert_near(screen[i].distance_to(Vector2(expected.x, expected.y)), 0.0, 0.01, "Ecke projiziert (%s)" % str(f["face"]))
			if w.z == 0.0:
				zmin = minf(zmin, w.x)
				zmax = maxf(zmax, w.x)
				xs[snappedf(w.y, 0.001)] = true
	assert_near(zmin, zc - L * 0.5, 1e-4, "Unterkante beginnt am Heck der Kollisionsbox")
	assert_near(zmax, zc + L * 0.5, 1e-4, "und endet an ihrer Front")
	assert_true(xs.has(snappedf(xc - W * 0.5, 0.001)) and xs.has(snappedf(xc + W * 0.5, 0.001)), "seitlich genau Spurmitte ± Breite/2")
	assert_eq(xs.size(), 2, "keine anderen Seitenlagen")
	var rr := b.rear_rect
	var bl := p.project(xc - W * 0.5, -_cam_h, zc - L * 0.5)
	var tr := p.project(xc + W * 0.5, H - _cam_h, zc - L * 0.5)
	assert_near(rr.position.x, bl.x, 0.01, "Heckfläche links")
	assert_near(rr.end.y, bl.y, 0.01, "Heckfläche unten")
	assert_near(rr.end.x, tr.x, 0.01, "Heckfläche rechts")
	assert_near(rr.position.y, tr.y, 0.01, "Heckfläche oben")


func test_visible_faces() -> void:
	_k = 0.0
	var b := _box()
	_emit(b, 40.0, 0.0)
	assert_eq(_faces(b, "left").size() + _faces(b, "right").size(), 0, "genau voraus: keine Flanke")
	assert_eq(_faces(b, "rear").size(), 1, "nur das Heck")
	_emit(b, 40.0, -3.75)
	assert_true(_faces(b, "right").size() > 0 and _faces(b, "left").is_empty(), "links der Kamera: rechte Flanke")
	assert_true(BoxVehicle.side_visible(2.0, 10.0, 2.0, 12.0, true), "linke Fläche rechts der Kamera sichtbar")
	assert_false(BoxVehicle.side_visible(2.0, 10.0, 2.0, 12.0, false), "rechte Fläche dort abgewandt")
	# lower road (camera 5 m above it): the roof of a 4 m truck is seen from above
	_cam_h = 5.0
	_emit(b, 40.0, 3.75)
	assert_true(_faces(b, "top").size() > 0, "Dach von oben sichtbar")
	_cam_h = 3.4


## Overtaking a truck: its rear is 5 m behind the camera, the rest beside it. The part behind the near plane is
## cut off and the flank stays visible.
func test_truck_alongside_stays_visible() -> void:
	_k = 0.0
	var b := _box()
	var zc := -5.0 + L * 0.5
	_emit(b, zc, 3.75)
	assert_eq(_faces(b, "rear").size(), 0, "Heck hinter der Kamera: nicht gezeichnet")
	assert_true(b.quads > 0, "Flanke sichtbar (%d Vierecke)" % b.quads)
	var zmin := INF
	for f: Dictionary in _faces(b, "left"):
		for w in (f["world"] as PackedVector3Array):
			zmin = minf(zmin, w.x)
	assert_true(zmin >= b.near - 1e-4, "abgeschnitten an der nahen Ebene (%.3f)" % zmin)
	for q in b.pts:
		assert_true(is_finite(q.x) and is_finite(q.y), "endliche Bildpunkte")


## The sides follow the road in slices of at most 2 m (closer to the camera shorter), back to front.
## Left curve, truck in the right lane: its left flank faces the camera.
func test_slices_follow_the_curve() -> void:
	_k = -0.9 / 120.0
	var b := _box()
	var zc := 25.0 + L * 0.5
	var xc := 3.75
	_emit(b, zc, xc)
	var lefts := _faces(b, "left")
	assert_true(lefts.size() >= 8, "Abschnitte (%d)" % lefts.size())
	for f: Dictionary in lefts:
		var world: PackedVector3Array = f["world"]
		var za := world[0].x
		var zb := world[2].x
		assert_true(zb - za <= 2.0 + 1e-4, "Abschnitt höchstens 2 m (%.2f)" % (zb - za))
	var bounds := b.slice_bounds(2.0, 30.0, 2.0, 0.0)
	for i in range(1, bounds.size()):
		var ds := bounds[i] - bounds[i - 1]
		assert_true(ds <= 2.0 + 1e-4, "Länge <= 2 m")
		assert_true(ds <= maxf(0.12 * bounds[i - 1], 0.125) + 1e-4, "Länge <= 12 %% der Tiefe bei %.1f m" % bounds[i - 1])
	# bending: the bottom corners of the flank lie on the road line lane centre - W/2 at their own z
	var p := _proj()
	for f: Dictionary in lefts:
		var world: PackedVector3Array = f["world"]
		var screen: PackedVector2Array = f["screen"]
		for i: int in [1, 3]:
			var z := world[i].x
			var e := p.project(_k * z * z * 0.5 + xc - W * 0.5, -_cam_h, z)
			assert_near(screen[i].x, e.x, 0.01, "Flanke folgt der Kurve bei z %.1f" % z)
	# far to near
	for i in range(1, b.order.size()):
		assert_true(b.order[i] <= b.order[i - 1] + 1e-4, "von hinten nach vorn gezeichnet")
	# right curve: a truck far ahead in the right lane turns away to the right – its right flank shows
	_k = 0.9 / 120.0
	_emit(b, 50.0 + L * 0.5, xc)
	assert_true(_faces(b, "right").size() > 0 and _faces(b, "left").is_empty(), "Rechtskurve weit voraus: rechte Flanke")
	_k = 0.0


## Slice boundaries are fixed relative to the vehicle: moving the truck does not move them along its body.
func test_slices_are_stable_relative_to_the_vehicle() -> void:
	var b := _box()
	var a := b.slice_bounds(40.0, 56.5, 40.0, 0.0)
	var c := b.slice_bounds(41.3, 57.8, 41.3, 0.0)
	assert_eq(a.size(), c.size(), "gleich viele Abschnitte")
	for i in a.size():
		assert_near(a[i] - 40.0, c[i] - 41.3, 1e-4, "gleiche Lage am Fahrzeug")


## Texture orientation (contract §4): left face u front -> rear, right face u rear -> front, v top -> bottom.
func test_face_orientation() -> void:
	_k = 0.0
	var b := _box()
	_emit(b, 30.0 + L * 0.5, 3.75)
	var rear_u := -1.0
	var front_u := -1.0
	for f: Dictionary in _faces(b, "left"):
		var world: PackedVector3Array = f["world"]
		var uv: PackedVector2Array = f["uv"]
		for i in world.size():
			if absf(world[i].x - 30.0) < 1e-4:
				rear_u = uv[i].x
			if absf(world[i].x - (30.0 + L)) < 1e-4:
				front_u = uv[i].x
			assert_near(uv[i].y, 0.0 if world[i].z == H else 1.0, 1e-6, "v: oben 0, unten 1")
	assert_near(rear_u, 1.0, 1e-6, "linke Flanke: Heck rechts im Bild")
	assert_near(front_u, 0.0, 1e-6, "linke Flanke: Front links im Bild")
	_emit(b, 30.0 + L * 0.5, -3.75)
	for f: Dictionary in _faces(b, "right"):
		var world: PackedVector3Array = f["world"]
		var uv: PackedVector2Array = f["uv"]
		for i in world.size():
			if absf(world[i].x - 30.0) < 1e-4:
				assert_near(uv[i].x, 0.0, 1e-6, "rechte Flanke: Heck links im Bild")
	var rear: Dictionary = _faces(b, "rear")[0]
	var rw: PackedVector3Array = rear["world"]
	var ruv: PackedVector2Array = rear["uv"]
	for i in rw.size():
		assert_near(ruv[i].x, 0.0 if rw[i].y < -3.75 else 1.0, 1e-6, "Heck: u von x0 nach x1")


## Light overlays use the face geometry with their own rectangle and the given strength.
func test_light_overlays() -> void:
	_k = 0.0
	var b := _box()
	b.debug = false
	var lights := {"brake": [{"part": 0, "face": "rear", "rect": Rect2(200, 400, 122, 192)}]}
	b.clear()
	b.emit(_parts(), lights, 30.0 + L * 0.5, 0.0, -1000.0, 1000.0, 0.0, _road, Color(1, 1, 1, 0.8), 0.0, 1.0)
	assert_eq(b.quads, 2, "Heck + Bremslicht")
	assert_near(b.cols[b.cols.size() - 1].a, 0.8, 1e-6, "Stärke = Alpha × Bremse")
	assert_near(b.uvs[b.uvs.size() - 4].x, 200.5 / 1024.0, 1e-6, "eigenes Rechteck (um ein halbes Pixel eingerückt)")
	b.clear()
	b.emit(_parts(), lights, 30.0 + L * 0.5, 0.0, -1000.0, 1000.0, 0.0, _road, Color(1, 1, 1, 0.8), 0.0, 0.0)
	assert_eq(b.quads, 1, "ohne Bremse kein Bremslicht")


## Semi-trailer: the rear lights glow at the face that carries the light overlays (the trailer), not at the
## cab's rear face in the middle of the vehicle; parts are emitted far to near (cab before trailer).
func test_rear_lights_of_a_semi_trailer() -> void:
	_k = 0.0
	var b := _box()
	var faces := {"rear": Rect2(0, 0, 10, 10), "left": Rect2(0, 0, 10, 10), "right": Rect2(0, 0, 10, 10)}
	var parts: Array = [
		{"name": "trailer", "z0": -8.25, "z1": 5.35, "x0": -1.275, "x1": 1.275, "y0": 0.0, "y1": 4.0, "faces": faces},
		{"name": "cab", "z0": 5.75, "z1": 8.25, "x0": -1.25, "x1": 1.25, "y0": 0.0, "y1": 3.8, "faces": faces}]
	var lights := {"tail": [{"part": 0, "face": "rear", "rect": Rect2(20, 0, 10, 10)}]}
	var p := _proj()
	var zc := 30.0 + 8.25
	# the cab's rear face alone (its scene slice): no glow there
	b.clear()
	b.emit(parts, lights, zc, 3.75, zc + 4.0, zc + 7.0, 0.0, _road, Color.WHITE, 1.0, 0.0)
	var rears := _faces(b, "rear")
	assert_true(rears.size() == 1 and int((rears[0] as Dictionary)["part"]) == 1, "Rückwand des Fahrerhauses gezeichnet")
	assert_false(b.rear_drawn, "dort leuchten keine Rücklichter")
	b.clear()
	b.emit(parts, lights, zc, 3.75, -1000.0, 1000.0, 0.0, _road, Color.WHITE, 1.0, 0.0)
	assert_true(b.rear_drawn, "Rücklichter am Auflieger")
	assert_near(b.rear_rect.end.y, p.project(0.0, -_cam_h, zc - 8.25).y, 0.01, "am Heck des Aufliegers")
	assert_eq(Array(BoxVehicle.part_order(parts)), [1, 0], "Fahrerhaus (weiter vorn) zuerst")
	for i in range(1, b.order.size()):
		assert_true(b.order[i] <= b.order[i - 1] + 1e-4, "von hinten nach vorn")
