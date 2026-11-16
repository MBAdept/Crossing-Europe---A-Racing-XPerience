import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
def rep(old, new, n=1):
    global s
    assert s.count(old) == n, ("pattern", old[:70], s.count(old))
    s = s.replace(old, new)
rep("""const STREAK_LAMP := 0.5
""", """const STREAK_LAMP := 0.5
## FIX-R4 (QA-R4 B1): a streak is a strip of this many sections along its length, bent over the road's height profile
## (flare.gdshader CE_STREAK) – a flat quad lay level at the height of its lamp's foot and hung in the air over a
## climbing road
const STREAK_SECTIONS := 12
""")
rep("""var _veh_streak_n := 0
var _wet := 0.0
""", """var _veh_streak_n := 0
var _wet := 0.0
var _prof := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])   ## FIX-R4: road profile of the static streak being put
""")
rep("""	_mm_streak = _multimesh()
	_node_streak = _instance(_mm_streak, "WetStreaks", smat)
	_mm_sstreak = _multimesh()
	_node_sstreak = _instance(_mm_sstreak, "WetStreaksStatic", smat)""",
"""	_mm_streak = _multimesh(_strip())
	_node_streak = _instance(_mm_streak, "WetStreaks", smat)
	_mm_sstreak = _multimesh(_strip())
	_node_sstreak = _instance(_mm_sstreak, "WetStreaksStatic", smat)""")
rep("""static func _multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad()
	return mm""",
"""static func _multimesh(mesh: Mesh = null) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh if mesh != null else _quad()
	return mm""")
rep("""	var time := float(view.get("time", 0.0))
	var cam: Camera3D = _renderer.get("camera")
	if cam == null:
		return""",
"""	var time := float(view.get("time", 0.0))
	var cam_z := float(view.get("camera_z", 0.0))
	var cam: Camera3D = _renderer.get("camera")
	if cam == null:
		return""")
rep("""					var drop := _drop_of(e, j, p, parent)
					if drop > 0.5:
						# (negative half width: the shader weighs the streak with the Fresnel term of water)
						var hw := -maxf(size * 0.9, 0.35)
						_put_streak(p, LAMP_GLOW_COLOR, g * _wet * STREAK_LAMP, hw, drop, depth, size * 0.5)""",
"""					var drop := _drop_of(e, j, p, parent)
					if drop > 0.5:
						# (negative half width: the shader weighs the streak with the Fresnel term of water) – along
						# the road's profile from the lamp's foot to the camera (FIX-R4)
						_lamp_profile(e, j, cam_z)
						var hw := -maxf(size * 0.9, 0.35)
						_put_streak(p, LAMP_GLOW_COLOR, g * _wet * STREAK_LAMP, hw, drop, depth, size * 0.5)""")
rep("""## Height of static lamp j of entry e above the road beside it (cached per entry; recomputed when the parent moves):
## the nearest boundary of the integrated path, like the lights layer's pools.
func _drop_of(e: Array, j: int, p: Vector3, parent: Node3D) -> float:
	if e.size() < 7 or not (e[6] is PackedFloat32Array) or (e[6] as PackedFloat32Array).size() != (e[1] as Array).size():
		var d := PackedFloat32Array()
		d.resize((e[1] as Array).size())
		d.fill(-1.0)
		if e.size() < 7:
			e.append(d)
		else:
			e[6] = d
	var drops: PackedFloat32Array = e[6]
	if drops[j] < 0.0:
		drops[j] = _ground_drop(p, parent)
		e[6] = drops
	return drops[j]


## Height of a world point above the nearest boundary of the integrated path – searched inside the chunk above
## `parent` (the streamer names chunk nodes "Chunk<index>"), else along the whole path (0 when there is no path).
func _ground_drop(p: Vector3, parent: Node) -> float:
	var path: RoadPath3D = _renderer.get("path") if _renderer != null else null
	if path == null or not path.is_ready():
		return 0.0""",
"""## Height of static lamp j of entry e above the road beside it (cached per entry; recomputed when the parent moves):
## the nearest boundary of the integrated path, like the lights layer's pools. FIX-R4: the road position z of that
## boundary is cached beside it (e[7]) for the streak's profile.
func _drop_of(e: Array, j: int, p: Vector3, parent: Node3D) -> float:
	var n := (e[1] as Array).size()
	if e.size() < 8 or not (e[6] is PackedFloat32Array) or (e[6] as PackedFloat32Array).size() != n:
		var d := PackedFloat32Array()
		d.resize(n)
		d.fill(-1.0)
		var zs := PackedFloat32Array()
		zs.resize(n)
		while e.size() < 8:
			e.append(null)
		e[6] = d
		e[7] = zs
	var drops: PackedFloat32Array = e[6]
	if drops[j] < 0.0:
		var got := _ground_drop(p, parent)
		drops[j] = got.x
		e[6] = drops
		var zs: PackedFloat32Array = e[7]
		zs[j] = got.y
		e[7] = zs
	return drops[j]


## FIX-R4: the road profile from static lamp j of entry e (its road position, cached by _drop_of()) to the camera's
## road position into _prof (Vehicles.road_profile(); level when there is no path).
func _lamp_profile(e: Array, j: int, cam_z: float) -> void:
	var path: RoadPath3D = _renderer.get("path") if _renderer != null else null
	if path == null or not path.is_ready() or e.size() < 8 or not (e[7] is PackedFloat32Array):
		_prof.fill(0.0)
		return
	var z := (e[7] as PackedFloat32Array)[j]
	Vehicles.road_profile(path, z, cam_z, path.z_min(), float(path.last()) * path.seg_len, _prof)


## Height of a world point above the nearest boundary of the integrated path – searched inside the chunk above
## `parent` (the streamer names chunk nodes "Chunk<index>"), else along the whole path – and that boundary's road
## position: Vector2(height, z) (0, 0 when there is no path).
func _ground_drop(p: Vector3, parent: Node) -> Vector2:
	var path: RoadPath3D = _renderer.get("path") if _renderer != null else null
	if path == null or not path.is_ready():
		return Vector2.ZERO""")
rep("""	var best := INF
	var drop := 0.0
	for k in range(from, to + 1, step):
		var q := path.point(k)
		var d := (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
		if d < best:
			best = d
			drop = p.y - q.y
	return clampf(drop, 0.0, 40.0)""",
"""	var best := INF
	var drop := 0.0
	var best_k := from
	for k in range(from, to + 1, step):
		var q := path.point(k)
		var d := (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
		if d < best:
			best = d
			drop = p.y - q.y
			best_k = k
	return Vector2(clampf(drop, 0.0, 40.0), float(best_k) * path.seg_len)""")
rep("""	var o := _sn * FLOATS
	if _sbuf.size() < o + FLOATS:
		_sbuf.resize(maxi(o + FLOATS, maxi(32 * FLOATS, _sbuf.size() * 2)))
	_sbuf[o] = 1.0
	_sbuf[o + 1] = 0.0
	_sbuf[o + 2] = 0.0
	_sbuf[o + 3] = pos.x
	_sbuf[o + 4] = 0.0
	_sbuf[o + 5] = 1.0
	_sbuf[o + 6] = 0.0
	_sbuf[o + 7] = pos.y
	_sbuf[o + 8] = 0.0
	_sbuf[o + 9] = 0.0
	_sbuf[o + 10] = 1.0
	_sbuf[o + 11] = pos.z""",
"""	var o := _sn * FLOATS
	if _sbuf.size() < o + FLOATS:
		_sbuf.resize(maxi(o + FLOATS, maxi(32 * FLOATS, _sbuf.size() * 2)))
	Vehicles.put_profile(_sbuf, o, _prof)
	_sbuf[o + 3] = pos.x
	_sbuf[o + 7] = pos.y
	_sbuf[o + 11] = pos.z""")
rep("""		mm2.mesh = _quad()
		mm2.instance_count = 1
		mm2.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.8, 0.0)))""",
"""		mm2.mesh = _strip()
		mm2.instance_count = 1
		mm2.set_instance_transform(0, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.0, 0.0)), Vector3(0.0, 0.8, 0.0)))""")
rep("""static func _quad() -> ArrayMesh:""",
"""## FIX-R4: the mesh of a streak – a strip from y = -1 to 1 in STREAK_SECTIONS sections (x = -1 / 1 across), so that it
## can follow the road's profile.
static func _strip() -> ArrayMesh:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in STREAK_SECTIONS + 1:
		var y := -1.0 + 2.0 * float(i) / float(STREAK_SECTIONS)
		v.append(Vector3(-1.0, y, 0.0))
		v.append(Vector3(1.0, y, 0.0))
	for i in STREAK_SECTIONS:
		var a := i * 2
		idx.append_array(PackedInt32Array([a, a + 3, a + 1, a, a + 2, a + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


static func _quad() -> ArrayMesh:""")
open(p, "w", encoding="utf-8").write(s)
print("patched", p)
