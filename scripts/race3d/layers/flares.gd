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
## R4: a street or canopy lamp's reflection on the wet road, × its glow × wet (flare_streak); its streak is weighed
## point by point with the Fresnel term of water (negative half width, flare.gdshader fresnel_ref_m)
const STREAK_LAMP := 0.5
## FIX-R4 (QA-R4 B1): a streak is a strip of this many sections along its length, bent over the road's height profile
## (flare.gdshader CE_STREAK) – a flat quad lay level at the height of its lamp's foot and hung in the air over a
## climbing road
const STREAK_SECTIONS := 12

var _renderer: Node
var _mats: ModernMaterials
var _mm: MultiMesh                   ## static lamps
var _node: MultiMeshInstance3D
var _mm_veh: MultiMesh               ## vehicle lamps (the vehicle layer's buffer, handed over as it is)
var _node_veh: MultiMeshInstance3D
## R4: reflections of lamps on the wet road (ModernMaterials.FLARE_STREAK): the vehicle layer's rear lamps and the
## static lamps that look down onto a pool (street and canopy lamps)
var _mm_streak: MultiMesh
var _node_streak: MultiMeshInstance3D
var _mm_sstreak: MultiMesh
var _node_sstreak: MultiMeshInstance3D
var _sbuf := PackedFloat32Array()
var _sn := 0
var _veh_streak_n := 0
var _wet := 0.0
var _prof := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])   ## FIX-R4: road profile of the static streak being put
## RINT-M2 (NACH-R4 N1): a lamp's streak profile is kept while the camera's road position moved less than this – in a
## lamp-lined city at night in the rain every lamp recomputed its seven heights every frame (4.2 µs each, measured by
## NACH-R4: 100 lamps ≈ 0.42 ms per frame); the profile's far end is then at most this far off its camera foot
const PROFILE_KEEP_M := 3.0
var _lamp_prof_n := 0                ## static streaks with a road profile this frame (snapshot, check_night_nass)
var _lamp_prof_max := 0.0            ## … and the largest height of their profiles (m)
var _lamp_prof_computed := 0         ## profiles computed (not taken from the cache) since the start – measurement
var debug_streaks := true            ## render checks switch the reflections on the wet road off (same frame without them)
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
	var smat := _mats.material(ModernMaterials.FLARE_STREAK) as ShaderMaterial
	if smat != null:
		smat.set_shader_parameter(&"focal_px", _focal)
	_mm_streak = _multimesh(streak_mesh())
	_node_streak = _instance(_mm_streak, "WetStreaks", smat)
	_mm_sstreak = _multimesh(streak_mesh())
	_node_sstreak = _instance(_mm_sstreak, "WetStreaksStatic", smat)
	if world is Node3D:
		(world as Node3D).add_child(_node)
		(world as Node3D).add_child(_node_veh)
		(world as Node3D).add_child(_node_streak)
		(world as Node3D).add_child(_node_sstreak)


static func _multimesh(mesh: Mesh = null) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh if mesh != null else _quad()
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


## R4: the vehicle layer's reflections of rear lamps on the wet road (same layout as set_vehicle_flares; drawn with
## the depth-tested streak variant of flare.gdshader).
func set_vehicle_streaks(buf: PackedFloat32Array, count: int) -> void:
	_veh_streak_n = count
	var cap := buf.size() / FLOATS
	if count <= 0 or cap <= 0:
		_mm_streak.visible_instance_count = 0
		_node_streak.visible = false
		return
	if _mm_streak.instance_count != cap:
		_mm_streak.instance_count = cap
	_mm_streak.buffer = buf
	_mm_streak.visible_instance_count = count
	_node_streak.visible = debug_streaks


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
	# [parent, lamps, transform, positions, directions, positions valid, drops, drop z (_drop_of), parent was in the tree]
	_static.append([parent, list, Transform3D(), PackedVector3Array(), PackedVector3Array(), false, null, null, false])
	_static_count += list.size()


func update(view: Dictionary, _dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_n = 0
	_sn = 0
	_lamp_prof_n = 0
	_lamp_prof_max = 0.0
	_wet = clampf(float((view.get("palette", {}) as Dictionary).get("wet", 0.0)), 0.0, 1.0)
	if bool(view.get("camera_in_tunnel", false)):
		_wet = 0.0
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
	if _sn > 0:
		if _mm_sstreak.instance_count < _sn:
			_mm_sstreak.instance_count = maxi(_sn, maxi(32, _mm_sstreak.instance_count * 2))
		if _sbuf.size() != _mm_sstreak.instance_count * FLOATS:
			_sbuf.resize(_mm_sstreak.instance_count * FLOATS)
		_mm_sstreak.buffer = _sbuf
	_mm_sstreak.visible_instance_count = _sn
	_node_sstreak.visible = _sn > 0 and debug_streaks
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
	var cam_z := float(view.get("camera_z", 0.0))
	var cam: Camera3D = _renderer.get("camera")
	if cam == null:
		return
	var cam_t := cam.global_transform if cam.is_inside_tree() else cam.transform
	var cam_inv := cam_t.affine_inverse()
	var i := 0
	while i < _static.size():
		var e: Array = _static[i]
		var pv: Variant = e[0]
		if not is_instance_valid(pv) or (bool(e[8]) and not (pv as Node3D).is_inside_tree()):
			_static_count -= (e[1] as Array).size()
			_static.remove_at(i)
			continue
		if not (pv as Node3D).is_inside_tree():
			# FIX-RINT (B-01): a chunk committed over several frames enters the tree when its last builder is done –
			# its lamps wait for it (a parent that LEFT the tree is forgotten above)
			i += 1
			continue
		e[8] = true
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
			var energy := float(l.get("energy", 1.0))
			if energy <= 0.0:
				continue      # RINT-M2 (QA-R6): a lamp switched off this frame (radar flash, countdown lamp) costs no instance
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
			# optional "halo": the share of its strength near the camera instead of STATIC_HALO (1 for a pure glow without
			# lit geometry – the radar flash; R6)
			var s := on * energy * alpha * lerpf(float(l.get("halo", STATIC_HALO)), 1.0, far)
			var col: Color = l.get("color", Color(1.0, 0.9, 0.7))
			_put(p, dirs[j], col, s, size * STATIC_K, STATIC_MIN_PX, 0.0, size * 0.5)
			# optional "glow": false – no warm glow of a street lamp's head (a lamp under a canopy, R6)
			if dirs[j].y < -0.5 and float(l.get("range", 0.0)) > 0.0 and bool(l.get("glow", true)):
				# Arcade's warm glow round the head of a street or canopy lamp
				var g := on * alpha * LAMP_GLOW_A * clampf(energy / LAMP_GLOW_REF_ENERGY, 0.0, 1.0)
				_put(p, dirs[j], LAMP_GLOW_COLOR, g, LAMP_GLOW_M, LAMP_GLOW_MIN_PX, 0.0, size * 0.5)
				if _wet > 0.0:
					# R4: its reflection on the wet road, from the foot of its pool towards the camera
					var drop := _drop_of(e, j, p, parent)
					if drop > 0.5:
						# (negative half width: the shader weighs the streak with the Fresnel term of water) – along
						# the road's profile from the lamp's foot to the camera (FIX-R4)
						_lamp_profile(e, j, cam_z)
						var hw := -maxf(size * 0.9, 0.35)
						_put_streak(p, LAMP_GLOW_COLOR, g * _wet * STREAK_LAMP, hw, drop, depth, size * 0.5)
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


## Height of static lamp j of entry e above the road beside it (cached per entry; recomputed when the parent moves):
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
## road position into _prof (road_profile(); level when there is no path).
func _lamp_profile(e: Array, j: int, cam_z: float) -> void:
	var path: RoadPath3D = _renderer.get("path") if _renderer != null else null
	if path == null or not path.is_ready() or e.size() < 8 or not (e[7] is PackedFloat32Array):
		_prof.fill(0.0)
		return
	var n := (e[1] as Array).size()
	while e.size() < 10:
		e.append(null)
	if not (e[8] is PackedFloat32Array) or (e[8] as PackedFloat32Array).size() != n * 6:
		var pc := PackedFloat32Array()
		pc.resize(n * 6)
		var zc := PackedFloat32Array()
		zc.resize(n)
		zc.fill(-1.0e9)
		e[8] = pc
		e[9] = zc
	var cached: PackedFloat32Array = e[8]
	var at: PackedFloat32Array = e[9]
	if absf(at[j] - cam_z) < PROFILE_KEEP_M:
		for i in 6:
			_prof[i] = cached[j * 6 + i]
	else:
		var z := (e[7] as PackedFloat32Array)[j]
		road_profile(path, z, cam_z, path.z_min(), float(path.last()) * path.seg_len, _prof)
		for i in 6:
			cached[j * 6 + i] = _prof[i]
		at[j] = cam_z
		e[8] = cached
		e[9] = at
		_lamp_prof_computed += 1
	_lamp_prof_n += 1
	for i in 6:
		_lamp_prof_max = maxf(_lamp_prof_max, absf(_prof[i]))


## Height of a world point above the nearest boundary of the integrated path – searched inside the chunk above
## `parent` (the streamer names chunk nodes "Chunk<index>"), else along the whole path – and that boundary's road
## position: Vector2(height, z) (0, 0 when there is no path).
func _ground_drop(p: Vector3, parent: Node) -> Vector2:
	var path: RoadPath3D = _renderer.get("path") if _renderer != null else null
	if path == null or not path.is_ready():
		return Vector2.ZERO
	var from := path.first
	var to := path.last()
	var step := 4
	var streamer: Variant = _renderer.get("streamer")
	var node: Node = parent
	while node != null and streamer is ChunkStreamer:
		var nm := String(node.name)
		if nm.begins_with("Chunk") and nm.substr(5).is_valid_int():
			from = maxi(from, nm.substr(5).to_int() * (streamer as ChunkStreamer).chunk_segments)
			to = mini(to, from + (streamer as ChunkStreamer).chunk_segments)
			step = 1
			break
		node = node.get_parent()
	var best := INF
	var drop := 0.0
	var best_k := from
	for k in range(from, to + 1, step):
		var q := path.point(k)
		var d := (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
		if d < best:
			best = d
			drop = p.y - q.y
			best_k = k
	return Vector2(clampf(drop, 0.0, 40.0), float(best_k) * path.seg_len)


func _put_streak(pos: Vector3, col: Color, a: float, half_w: float, h: float, depth: float, lamp_r: float) -> void:
	if a <= 0.004:
		return
	var o := _sn * FLOATS
	if _sbuf.size() < o + FLOATS:
		_sbuf.resize(maxi(o + FLOATS, maxi(32 * FLOATS, _sbuf.size() * 2)))
	put_profile(_sbuf, o, _prof)
	_sbuf[o + 3] = pos.x
	_sbuf[o + 7] = pos.y
	_sbuf[o + 11] = pos.z
	_sbuf[o + 12] = col.r
	_sbuf[o + 13] = col.g
	_sbuf[o + 14] = col.b
	_sbuf[o + 15] = a
	_sbuf[o + 16] = half_w
	_sbuf[o + 17] = h
	_sbuf[o + 18] = clampf(depth * 0.3 + h, 4.0, 26.0)
	_sbuf[o + 19] = lamp_r
	_sn += 1


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
	var out: Array = [n]
	if _node_streak != null and _node_streak.material_override != null:
		var mm2 := MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		mm2.use_colors = true
		mm2.use_custom_data = true
		mm2.mesh = streak_mesh()
		mm2.instance_count = 1
		mm2.set_instance_transform(0, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.0, 0.0)), Vector3(0.0, 0.8, 0.0)))
		mm2.set_instance_color(0, Color(1.0, 0.2, 0.1, 0.3))
		mm2.set_instance_custom_data(0, Color(0.15, 0.8, 6.0, 0.1))
		var n2 := MultiMeshInstance3D.new()
		n2.multimesh = mm2
		n2.material_override = _node_streak.material_override
		out.append(n2)
	return out


func snapshot() -> Dictionary:
	return {"lights": {"flares": _n + _veh_n, "static_lamps": _static_count, "wet_streaks": _sn + _veh_streak_n,
		"lamp_streak_profiles": _lamp_prof_n, "lamp_streak_profile_max_m": snappedf(_lamp_prof_max, 0.001),
		"lamp_streak_profiles_computed": _lamp_prof_computed}}


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


## FIX-R4 (QA-R4 B1): the road's height profile from road position z_from (the foot of a lamp) to z_cam (the camera's
## foot) for flare.gdshader's streak: out[i] = road height at (i + 1) / 6 of that way minus the height at z_from
## (6 values; z clamped into [z_lo, z_hi], the part of the path that exists).
static func road_profile(path: RoadPath3D, z_from: float, z_cam: float, z_lo: float, z_hi: float, out: PackedFloat32Array) -> void:
	var a := clampf(z_from, z_lo, z_hi)
	var b := clampf(z_cam, z_lo, z_hi)
	var h0 := path.height_at(a)
	for i in 6:
		out[i] = path.height_at(lerpf(a, b, float(i + 1) / 6.0)) - h0


## FIX-R4: a streak's profile into the basis of its instance transform in a MultiMesh buffer at offset o (flare.gdshader
## CE_STREAK: columns 0 and 1 hold the six heights, column 2 x = 1 says a profile is given). Pure.
static func put_profile(buf: PackedFloat32Array, o: int, prof: PackedFloat32Array) -> void:
	buf[o] = prof[0]
	buf[o + 4] = prof[1]
	buf[o + 8] = prof[2]
	buf[o + 1] = prof[3]
	buf[o + 5] = prof[4]
	buf[o + 9] = prof[5]
	buf[o + 2] = 1.0
	buf[o + 6] = 0.0
	buf[o + 10] = 0.0


## FIX-R4: the mesh of a streak – a strip from y = -1 to 1 in STREAK_SECTIONS sections (x = -1 / 1 across), so that it
## can follow the road's profile.
static func streak_mesh() -> ArrayMesh:
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
	if is_instance_valid(_node_streak):
		_node_streak.queue_free()
	if is_instance_valid(_node_sstreak):
		_node_sstreak.queue_free()
	_static.clear()
	_static_count = 0
