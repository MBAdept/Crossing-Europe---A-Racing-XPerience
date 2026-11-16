extends Node3D
## Layer "flares" of the mode "Modern" (contract D14 F6, amendment A-7; docs/renderer-modern.md §10): the glow of
## every lamp – one MultiMesh, one draw call (assets/shaders/modern/flare.gdshader).
##  * vehicle lamps: the layer "vehicles" hands its flare points over every frame (set_vehicle_flares) – tail, brake
##    and indicator lights, beacons, with Arcade's minimum sizes (an indicator never smaller than
##    RoadRenderer.INDICATOR_MIN_PX with a glow of at least INDICATOR_MIN_GLOW_PX, rear lights at least 2 px);
##  * static lamps: add_static(parent, lamps) (renderer.add_lamps(), A-7) – street, tunnel and canopy lamps of the
##    chunk builders. They follow parent.global_transform and are forgotten when the parent leaves the tree. They
##    glow at night (role "lights" / "street" … follow ce_night; "on" always) as a far-field glow: near the camera
##    the lit lamp geometry carries the light and the glow is a soft halo, from the distance where the lamp is
##    smaller than a pixel the glow alone carries it (Arcade shows its lamps up to the visibility limit); a lamp with
##    a "blink" rhythm (the aviation light of a bridge pylon) is lit only in its phase (blink_lit(), view.time);
##  * occlusion by the depth buffer (in the shader): a lamp behind a crest, a truck or a wall shows 0 pixels.
## Owner: R3. Docs: docs/renderer-modern.md §10.

const FLOATS := 20                   ## per instance: 12 transform + 4 colour + 4 custom (flare.gdshader)
const STATIC_OFFSET_M := 0.12        ## a static lamp's flare sits this far along its direction
const STATIC_K := 0.9                ## glow radius of a static lamp = its size x this (m) …
const STATIC_MIN_PX := 1.6           ## … at least this many px
const STATIC_NEAR_PX := 6.0          ## lamp geometry this large on screen: only the halo share of the glow …
const STATIC_FAR_PX := 1.0           ## … this small: the whole glow
const STATIC_HALO := 0.35            ## halo share near the camera
## Arcade's glow of a street lamp (RoadRenderer._streetlight: radius max(3 px, 2.4 m), colour (1, 0.75, 0.4), alpha
## 0.5 x lights): every lamp that looks down onto a light pool (street and canopy lamps) gets it as a second flare at
## its head, scaled by its energy against a street lamp's (RINT-B: the heads lacked Arcade's warm halo at night)
const LAMP_GLOW_M := 2.4
const LAMP_GLOW_MIN_PX := 3.0
const LAMP_GLOW_A := 1.0             ## flare strength: flare.gdshader adds colour × 0.5 × strength, Arcade colour × alpha 0.5
const LAMP_GLOW_COLOR := Color(1.0, 0.75, 0.4)
const LAMP_GLOW_REF_ENERGY := 0.55   ## PropLibrary.LAMP_ENERGY: a street lamp gets the full glow
const ROLES_NIGHT: Array[String] = ["lights", "street", "lamp", "tunnel", "canopy", "marker", "tail"]
## FIX1: Arcade's halo round a tunnel lamp (RoadRenderer._tunnel_segment: radius max(3 px, 1.6 m), colour LAMP_COL,
## alpha 0.45 x the lamp's visibility) as a second flare of every lamp with the role "tunnel" (builders/tunnel.gd)
const TUNNEL_GLOW_M := 1.6
const TUNNEL_GLOW_MIN_PX := 3.0
const TUNNEL_GLOW_A := 0.9           ## flare.gdshader adds colour × 0.5 × strength: Arcade's alpha 0.45
const TUNNEL_GLOW_COLOR := Color(1.0, 0.82, 0.55)
## M2ZS1: a static lamp with "blink" = Vector3(period s, lit s, phase s) is lit only while blink_lit() – at night
## (lights above BLINK_MIN_NIGHT) and while fposmod(view.time + phase, period) < lit. The red aviation light of a bridge
## pylon blinks so, like Arcade's procedural pylon (RoadRenderer._pylon: lights > 0.2, fmod(time + side × 0.4, 1.6) <
## 0.8), and gets Arcade's glow round it as a second flare (radius max(3 px, 1.2 m), alpha 0.8 × lights).
const BLINK_MIN_NIGHT := 0.2
const BEACON_GLOW_M := 1.2
const BEACON_GLOW_MIN_PX := 3.0
const BEACON_GLOW_A := 1.6           ## flare.gdshader adds colour × 0.5 × strength: Arcade's alpha 0.8

var _renderer: Node
var _mats: ModernMaterials
var _mm: MultiMesh                   ## static lamps
var _node: MultiMeshInstance3D
var _mm_veh: MultiMesh               ## vehicle lamps (the vehicle layer's buffer, handed over as it is)
var _node_veh: MultiMeshInstance3D
var _buf := PackedFloat32Array()
var _veh := PackedFloat32Array()
var _veh_n := 0
var _n := 0
var _focal := 711.0
var _fog_frac := 0.45
## static lamps: one entry per parent – [parent (Node3D), lamps (Array of Dictionary), cached world transform,
## cached world positions (PackedVector3Array), cached world directions]
var _static: Array = []
var _static_count := 0
var _us_sum := 0
var _us_max := 0
var _updates := 0


func setup(renderer: Node) -> void:
	_renderer = renderer
	_mats = renderer.get("materials") as ModernMaterials
	if _mats == null:
		_mats = ModernMaterials.shared()
	var proj: Variant = renderer.get("proj")
	if proj is RoadProjection:
		_focal = (proj as RoadProjection).focal
	var cfg: Variant = renderer.get("cfg")
	if cfg is Dictionary:
		_fog_frac = float(ConfigLoader.lookup(cfg, "render.fog_start_frac", 0.45))
	var mat := _mats.material("flare") as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"focal_px", _focal)
	var world: Variant = renderer.get("world")
	_mm = _multimesh()
	_node = _instance(_mm, "Flares", mat)
	_mm_veh = _multimesh()
	_node_veh = _instance(_mm_veh, "VehicleFlares", mat)
	if world is Node3D:
		(world as Node3D).add_child(_node)
		(world as Node3D).add_child(_node_veh)


static func _multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad()
	return mm


static func _instance(mm: MultiMesh, node_name: String, mat: Material) -> MultiMeshInstance3D:
	var n := MultiMeshInstance3D.new()
	n.name = node_name
	n.multimesh = mm
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.material_override = mat
	n.custom_aabb = AABB(Vector3(-6000.0, -2000.0, -6000.0), Vector3(12000.0, 4000.0, 12000.0))
	return n


## The vehicle layer's flares of this frame: `count` instances in the MultiMesh layout of flare.gdshader (FLOATS
## floats each, the array may be longer). The buffer goes to the GPU as it is (no copy in GDScript).
func set_vehicle_flares(buf: PackedFloat32Array, count: int) -> void:
	_veh = buf
	_veh_n = count
	var cap := buf.size() / FLOATS
	if count <= 0 or cap <= 0:
		_mm_veh.visible_instance_count = 0
		return
	if _mm_veh.instance_count != cap:
		_mm_veh.instance_count = cap
	_mm_veh.buffer = buf
	_mm_veh.visible_instance_count = count


## Static lamps of a chunk part (renderer.add_lamps(), contract A-7): Array of {"pos": Vector3 (local to parent),
## "dir": Vector3 (local, where the lamp looks), "role", "color": Color, "size": m, "range": m, "energy"}.
func add_static(parent: Node3D, lamps: Array) -> void:
	if parent == null or lamps.is_empty():
		return
	var list: Array = []
	for l: Variant in lamps:
		if l is Dictionary:
			list.append(l)
	if list.is_empty():
		return
	_static.append([parent, list, Transform3D(), PackedVector3Array(), PackedVector3Array(), false])
	_static_count += list.size()


func update(view: Dictionary, _dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_n = 0
	var need := _static_count * FLOATS * 2       # a core and, for lamps over a pool, Arcade's glow
	if _buf.size() < need:
		_buf.resize(maxi(need, maxi(128 * FLOATS, _buf.size() * 2)))
	_add_statics(view)
	if _mm.instance_count < _n or _mm.instance_count == 0:
		_mm.instance_count = maxi(_n, maxi(128, _mm.instance_count * 2))
	if _n > 0:
		if _buf.size() != _mm.instance_count * FLOATS:
			_buf.resize(_mm.instance_count * FLOATS)
		_mm.buffer = _buf
	_mm.visible_instance_count = _n
	var us := Time.get_ticks_usec() - t0
	_us_sum += us
	_us_max = maxi(_us_max, us)
	_updates += 1


func _add_statics(view: Dictionary) -> void:
	if _static.is_empty():
		return
	var pal: Dictionary = view.get("palette", {})
	var night := clampf(float(pal.get("lights", 0.0)), 0.0, 1.0)
	var in_tunnel := bool(view.get("camera_in_tunnel", false))
	var vis := float(view.get("visibility_m", 900.0))
	var time := float(view.get("time", 0.0))
	var cam: Camera3D = _renderer.get("camera")
	if cam == null:
		return
	var cam_t := cam.global_transform if cam.is_inside_tree() else cam.transform
	var cam_inv := cam_t.affine_inverse()
	var i := 0
	while i < _static.size():
		var e: Array = _static[i]
		var pv: Variant = e[0]
		if not is_instance_valid(pv) or not (pv as Node3D).is_inside_tree():
			_static_count -= (e[1] as Array).size()
			_static.remove_at(i)
			continue
		var parent: Node3D = pv
		var gt := parent.global_transform
		var lamps: Array = e[1]
		if not bool(e[5]) or not gt.is_equal_approx(e[2]):
			# (re)compute the world positions only when the parent moved (chunks move on a rebase)
			var ps := PackedVector3Array()
			var ds := PackedVector3Array()
			for l: Dictionary in lamps:
				var d: Vector3 = l.get("dir", Vector3.DOWN)
				if d.length_squared() < 1.0e-6:
					d = Vector3.DOWN
				var wd := (gt.basis * d).normalized()
				ps.append(gt * (l.get("pos", Vector3.ZERO) as Vector3) + wd * STATIC_OFFSET_M)
				ds.append(wd)
			e[2] = gt
			e[3] = ps
			e[4] = ds
			e[5] = true
		var pos: PackedVector3Array = e[3]
		var dirs: PackedVector3Array = e[4]
		for j in lamps.size():
			var l: Dictionary = lamps[j]
			var role := str(l.get("role", "lights"))
			var on := 1.0 if role == "on" else (maxf(night, 1.0 if in_tunnel else 0.0) if ROLES_NIGHT.has(role) else night)
			if on <= 0.01:
				continue
			var blink: Variant = l.get("blink")
			if blink != null and not blink_lit(blink, time, night):
				continue
			var p := pos[j]
			var depth := -(cam_inv * p).z
			if depth <= 0.5:
				continue
			var alpha := VehiclePose3D.fade(depth, vis, _fog_frac, in_tunnel, 260.0)
			if alpha <= 0.01:
				continue
			var size := float(l.get("size", 0.4))
			var px := size * _focal / depth
			# far-field: the glow takes over where the lamp itself shrinks below a pixel
			var far := clampf((STATIC_NEAR_PX - px) / (STATIC_NEAR_PX - STATIC_FAR_PX), 0.0, 1.0)
			var energy := float(l.get("energy", 1.0))
			var s := on * energy * alpha * lerpf(STATIC_HALO, 1.0, far)
			var col: Color = l.get("color", Color(1.0, 0.9, 0.7))
			_put(p, dirs[j], col, s, size * STATIC_K, STATIC_MIN_PX, 0.0, size * 0.5)
			if dirs[j].y < -0.5 and float(l.get("range", 0.0)) > 0.0:
				# Arcade's warm glow round the head of a street or canopy lamp
				var g := on * alpha * LAMP_GLOW_A * clampf(energy / LAMP_GLOW_REF_ENERGY, 0.0, 1.0)
				_put(p, dirs[j], LAMP_GLOW_COLOR, g, LAMP_GLOW_M, LAMP_GLOW_MIN_PX, 0.0, size * 0.5)
			elif role == "tunnel":
				_put(p, dirs[j], TUNNEL_GLOW_COLOR, on * alpha * TUNNEL_GLOW_A, TUNNEL_GLOW_M, TUNNEL_GLOW_MIN_PX, 0.0, size * 0.5)
			elif blink != null:
				# Arcade's red glow round the blinking aviation light of a bridge pylon
				_put(p, dirs[j], col, night * alpha * BEACON_GLOW_A, BEACON_GLOW_M, BEACON_GLOW_MIN_PX, 0.0, size * 0.5)
		i += 1


## True while a blinking static lamp ("blink" = Vector3(period s, lit s, phase s)) is lit at view time `time`: only at
## night (lights above BLINK_MIN_NIGHT), and for `lit` seconds of every period – Arcade's aviation light of a bridge
## pylon (RoadRenderer._pylon). A lamp without a valid rhythm is always lit. Pure (unit test).
static func blink_lit(blink: Variant, time: float, night: float) -> bool:
	if not (blink is Vector3):
		return true
	var b: Vector3 = blink
	if b.x <= 0.0:
		return true
	return night > BLINK_MIN_NIGHT and fposmod(time + b.z, b.x) < b.y


func _put(pos: Vector3, dir: Vector3, col: Color, s: float, k: float, min_px: float, kind: float, lamp_r: float) -> void:
	var o := _n * FLOATS
	if _buf.size() < o + FLOATS:
		_buf.resize(maxi(o + FLOATS, _buf.size() * 2))
	_buf[o] = 1.0
	_buf[o + 1] = 0.0
	_buf[o + 2] = dir.x
	_buf[o + 3] = pos.x
	_buf[o + 4] = 0.0
	_buf[o + 5] = 1.0
	_buf[o + 6] = dir.y
	_buf[o + 7] = pos.y
	_buf[o + 8] = 0.0
	_buf[o + 9] = 0.0
	_buf[o + 10] = dir.z
	_buf[o + 11] = pos.z
	_buf[o + 12] = col.r
	_buf[o + 13] = col.g
	_buf[o + 14] = col.b
	_buf[o + 15] = s
	_buf[o + 16] = k
	_buf[o + 17] = min_px
	_buf[o + 18] = kind
	_buf[o + 19] = lamp_r
	_n += 1


## The floating origin moved: the cached positions of static lamps are recomputed (their parents moved).
func rebased(_shift: Vector3) -> void:
	for e: Array in _static:
		e[5] = false


## A fresh node per shader variant (the renderer shows it behind the loading cover and frees it): one flare.
func warmup_nodes() -> Array:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad()
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0)))
	mm.set_instance_color(0, Color(1.0, 0.2, 0.1, 0.5))
	mm.set_instance_custom_data(0, Color(0.4, 2.0, 1.0, 0.1))
	var n := MultiMeshInstance3D.new()
	n.multimesh = mm
	n.material_override = _node.material_override if _node != null else _mats.material("flare")
	return [n]


func snapshot() -> Dictionary:
	return {"lights": {"flares": _n + _veh_n, "static_lamps": _static_count}}


func perf() -> Dictionary:
	return {"flares": _n + _veh_n, "flare_us_avg": float(_us_sum) / maxf(1.0, float(_updates)), "flare_us_max": _us_max}


## The flares of the last frame as plain data (tests): [{pos, color, strength, k, min_px, kind, lamp_r, vehicle}].
func flares() -> Array:
	var out: Array = []
	for src: Array in [[_veh, _veh_n, true], [_buf, _n, false]]:
		var b: PackedFloat32Array = src[0]
		for i in int(src[1]):
			var o := i * FLOATS
			out.append({"pos": Vector3(b[o + 3], b[o + 7], b[o + 11]), "color": Color(b[o + 12], b[o + 13], b[o + 14]),
				"strength": b[o + 15], "k": b[o + 16], "min_px": b[o + 17], "kind": b[o + 18], "lamp_r": b[o + 19],
				"vehicle": bool(src[2])})
	return out


static func _quad() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1.0, -1.0, 0.0), Vector3(1.0, -1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(-1.0, 1.0, 0.0)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _exit_tree() -> void:
	if is_instance_valid(_node):
		_node.queue_free()
	if is_instance_valid(_node_veh):
		_node_veh.queue_free()
	_static.clear()
	_static_count = 0
