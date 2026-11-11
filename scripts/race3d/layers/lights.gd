extends Node3D
## Lights layer of the mode "Modern" (v0.8.0, contract D8, §4.5.6, amendment A-7): every positional light of a race
## lives here – and there are few of them. Real lights are capped at 2 spots + 8 omnis in total, none with a shadow:
##  * the player's low beam: two SpotLight3D on the nose of the car. They light what stands on the ground –
##    vehicles, guardrails, signs, props. The ground itself (road, terrain: render layer 2, GROUND_LAYERS) is left
##    out by every light of this layer and takes the beam as Arcade's cone from the globals ce_headlight_pos,
##    ce_headlight_dir and ce_headlight (range, intensity) – assets/shaders/modern/inc/headlight.gdshaderinc;
##  * a pool of OmniLight3D (levels.omni_pool: 2 / 4 / 8) that moves to the nearest static lamps of the chunks
##    (street lights, later tunnel, canopy and station lamps) – they light vehicles and props under a lamp;
##  * analytical light pools on the ground: the nearest static lamps (at most lights.pools_lamps = 16) and the
##    headlight cones of the traffic ahead (at most lights.pools_traffic = 6, Arcade's rule: cars up to 140 m ahead
##    of the camera, a cone of 34 m). Once per frame the arrays pool_pos_r, pool_col, pool_dir and pool_count go to
##    every material of renderer.pool_materials() (inc/pools.gdshaderinc);
##  * the glints of retro-reflectors inside the player's beam (guardrail reflectors, delineators): one small
##    additive MultiMesh, the strength of each from the beam at its place.
## Interfaces for builders (through the renderer, duck-typed):
##   add_static(parent, lamps)       A-7: static lamps of a chunk part ({pos, dir, role, color, size, range, energy},
##                                   local to `parent`); followed through parent.global_transform, forgotten when
##                                   `parent` leaves the tree
##   add_reflectors(parent, list)    retro-reflectors of a chunk part ({pos, dir, color, size}, local to `parent`)
## How bright: Arcade's numbers. The player's cone adds render.headlight_intensity × min(1, 1.4 × palette.lights)
## to the display value of the road (0.35 at least inside a tunnel); a lamp pool 0.55 × lights at its centre, a
## traffic cone 0.5 × lights. Display values are turned into linear light on top of the ambient light of the frame
## (display_to_light) – in the shader for the player's cone, here for pools and cones.
## Nothing here reads the wall clock or per-frame GPU state; by day the layer costs a few comparisons per frame.
## Owner: renderer core (R1; from the lights package on: R4). Docs: docs/renderer-modern.md.

const GROUND_LAYERS := 2            ## render layer of ground meshes (builders/road.gd): no light of this layer reaches it
const LIGHT_MASK := 0xFFFFF & ~2   ## cull mask of every positional light: everything but the ground
const LAMP_COLOR := Color(1.0, 0.93, 0.8)     ## RoadRenderer.LIGHT_COL
const MAX_POOLS := 22
const HEADLIGHT_H := 0.66           ## height of the low beam's lamps above the road
const HEADLIGHT_HALF_M := 0.62      ## … and their distance from the car's axis
const HEADLIGHT_PITCH_DEG := 2.0
const SPOT_ANGLE_DEG := 30.0
const SPOT_ENERGY := 1.6            ## energy of one spot at full beam
const SPOT_DECAY := 0.6
const TUNNEL_BEAM := 0.35           ## Arcade: the low beam inside a tunnel by day
const TRAFFIC_AHEAD_M := 140.0      ## traffic cones: cars up to this far ahead of the camera
const TRAFFIC_REACH_M := 34.0
const TRAFFIC_LEVEL := 0.5          ## display value a traffic cone adds at its hot spot (× lights)
const POOL_LEVEL := 0.55            ## display value a lamp pool of energy 1 adds at its centre (× lights)
const POOL_AHEAD_M := 40.0          ## lamps are ranked by their distance from this far ahead of the camera
const OMNI_ENERGY := 1.4
const OMNI_REACH := 1.7             ## omni range as a multiple of the lamp's pool radius
const LAMP_DROP_M := 8.0            ## height of a lamp above the road when it cannot be measured
const GLINT_MAX := 24
const GLINT_RADIUS_M := 0.32        ## Arcade: _glow_fixture radius 0.35 .. 0.4 m
const GLINT_GAIN := 1.5

var spots: Array[SpotLight3D] = []
var omnis: Array[OmniLight3D] = []

var _renderer: Node
var _range := 80.0
var _intensity := 0.95
var _max_lamp_pools := 16
var _max_traffic := 6
var _want_spots := 2
var _want_omnis := 4
var _beam := 0.0                    ## intensity of the player's cone this frame (display value)
var _beam_pos := Vector3.ZERO
var _beam_dir := Vector3.FORWARD
var _sent_beam := Vector2(-1.0, -1.0)
var _statics: Array = []            ## [parent: Node3D, entries: Array of {pos, dir, color, range, energy, drop}]
var _reflectors: Array = []         ## [parent: Node3D, entries: Array of {pos, dir, color, size}]
var _static_count := 0
var _ranked: Array = []             ## the nearest lamps: [parent, entry], re-ranked when the camera enters a new segment
var _rank_seg := -1
var _reflector_count := 0
var _pool_pos := PackedVector4Array()
var _pool_col := PackedVector4Array()
var _pool_dir := PackedVector4Array()
var _pool_count := 0
var _pools_sent := 0
var _pool_lamps := 0
var _pool_traffic := 0
var _glints: MultiMeshInstance3D
var _glint_mm: MultiMesh
var _glint_count := 0
var _omni_active := 0
var _spot_active := 0


func setup(renderer: Node) -> void:
	_renderer = renderer
	_pool_pos.resize(MAX_POOLS)
	_pool_col.resize(MAX_POOLS)
	_pool_dir.resize(MAX_POOLS)
	if renderer == null:
		return
	var cfg: Variant = renderer.get("cfg")
	if cfg is Dictionary:
		_range = maxf(10.0, float(ConfigLoader.lookup(cfg, "render.headlight_range_m", _range)))
		_intensity = float(ConfigLoader.lookup(cfg, "render.headlight_intensity", _intensity))
		var l: Variant = ConfigLoader.lookup(cfg, "graphics.modern.lights", {})
		if l is Dictionary:
			_want_spots = clampi(int((l as Dictionary).get("spots", 2)), 0, 2)
			_max_lamp_pools = clampi(int((l as Dictionary).get("pools_lamps", 16)), 0, 16)
			_max_traffic = clampi(int((l as Dictionary).get("pools_traffic", 6)), 0, MAX_POOLS - _max_lamp_pools)
	_build_lights()


## The omni pool follows "Effekte" (2 / 4 / 8); the player's low beam, the light pools on the road and the glints of
## the reflectors are the same in every preset (Rule 9).
func apply_quality(levels: Dictionary) -> void:
	_want_omnis = clampi(int(levels.get("omni_pool", 4)), 0, 8)
	_build_lights()


## The slowness watchdog stepped the preset down: fewer lamps of the omni pool are used (the nodes stay).
func quality_lowered(levels: Dictionary) -> void:
	var want := clampi(int(levels.get("omni_pool", 4)), 0, 8)
	while omnis.size() > want:
		var o: OmniLight3D = omnis.pop_back()
		o.queue_free()
	_rank_seg = -1


func _build_lights() -> void:
	for l: Node in spots:
		l.queue_free()
	for l: Node in omnis:
		l.queue_free()
	spots.clear()
	omnis.clear()
	for i in _want_spots:
		var s := SpotLight3D.new()
		s.name = "Headlight%d" % i
		s.shadow_enabled = false
		s.light_cull_mask = LIGHT_MASK
		s.light_color = LAMP_COLOR
		s.spot_range = _range * 1.05
		s.spot_angle = SPOT_ANGLE_DEG
		s.spot_angle_attenuation = 0.8
		s.spot_attenuation = SPOT_DECAY
		s.light_specular = 0.6
		s.visible = false
		add_child(s)
		spots.append(s)
	for i in _want_omnis:
		var o := OmniLight3D.new()
		o.name = "Lamp%d" % i
		o.shadow_enabled = false
		o.light_cull_mask = LIGHT_MASK
		o.omni_attenuation = 1.0
		o.light_specular = 0.5
		o.visible = false
		add_child(o)
		omnis.append(o)
	if _glints == null:
		_glint_mm = MultiMesh.new()
		_glint_mm.transform_format = MultiMesh.TRANSFORM_3D
		_glint_mm.use_colors = true
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		_glint_mm.mesh = quad
		_glint_mm.instance_count = GLINT_MAX
		_glint_mm.visible_instance_count = 0
		_glints = MultiMeshInstance3D.new()
		_glints.name = "Glints"
		_glints.multimesh = _glint_mm
		_glints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glints.custom_aabb = AABB(Vector3(-1.0e4, -1.0e3, -1.0e4), Vector3(2.0e4, 2.0e3, 2.0e4))
		var mat := ShaderMaterial.new()
		mat.shader = ModernMaterials.shared().shader("reflector")
		_glints.material_override = mat
		_glints.visible = false
		add_child(_glints)


## A-7: static lamps of a chunk part. Entries with a range feed the light pools on the ground and the omni pool.
func add_static(parent: Node3D, lamps: Array) -> void:
	if parent == null or lamps.is_empty():
		return
	var entries: Array = []
	for l: Variant in lamps:
		if not (l is Dictionary):
			continue
		var d: Dictionary = l
		var reach := float(d.get("range", 0.0))
		if reach <= 0.0:
			continue
		var dir: Vector3 = d.get("dir", Vector3.DOWN)
		entries.append({"pos": d.get("pos", Vector3.ZERO), "dir": dir.normalized() if dir.length_squared() > 1.0e-6 else Vector3.DOWN,
			"color": d.get("color", LAMP_COLOR), "range": reach, "energy": float(d.get("energy", 1.0)), "drop": -1.0})
	if entries.is_empty():
		return
	_statics.append([parent, entries])
	_static_count += entries.size()
	_rank_seg = -1
	parent.tree_exiting.connect(_forget.bind(_statics, parent), CONNECT_ONE_SHOT)


## Retro-reflectors of a chunk part: {pos, dir (unit, where the reflector looks), color, size (m)}, local to parent.
func add_reflectors(parent: Node3D, list: Array) -> void:
	if parent == null or list.is_empty():
		return
	_reflectors.append([parent, list])
	_reflector_count += list.size()
	parent.tree_exiting.connect(_forget.bind(_reflectors, parent), CONNECT_ONE_SHOT)


func _forget(store: Array, parent: Node3D) -> void:
	for i in store.size():
		if (store[i] as Array)[0] == parent:
			var n := ((store[i] as Array)[1] as Array).size()
			if is_same(store, _statics):
				_static_count -= n
				_rank_seg = -1
			else:
				_reflector_count -= n
			store.remove_at(i)
			return


func update(view: Dictionary, _dt: float) -> void:
	if _renderer == null:
		return
	var pal: Dictionary = view.get("palette", {})
	var lights := clampf(float(pal.get("lights", 0.0)), 0.0, 1.0)
	var env: Node = _renderer.get("env")
	var tunnel01 := 1.0 if bool(view.get("camera_in_tunnel", false)) else 0.0
	var ambient := Color(1.0, 1.0, 1.0)
	if env != null:
		var st: Variant = env.get("state")
		if st is Dictionary and not (st as Dictionary).is_empty():
			tunnel01 = float((st as Dictionary).get("tunnel01", tunnel01))
			ambient = (st as Dictionary).get("ambient", ambient)
	var path: RoadPath3D = _renderer.get("path")
	_update_beam(view, lights, tunnel01, path)
	var lit := (lights > 0.04 or tunnel01 > 0.04) and path != null and path.is_ready()
	if lit:
		_update_pools(view, maxf(lights, tunnel01), lights, ambient, path)
	else:
		_pool_count = 0
		_pool_lamps = 0
		_pool_traffic = 0
		_omni_active = 0
		for o: OmniLight3D in omnis:
			o.visible = false
	_send_pools()
	_update_glints()


## The player's low beam: the two spots and the globals of the cone on the ground.
func _update_beam(view: Dictionary, lights: float, tunnel01: float, path: RoadPath3D) -> void:
	var player: Dictionary = view.get("player", {})
	var beam := _intensity * clampf(lights * 1.4, 0.0, 1.0)
	beam = maxf(beam, TUNNEL_BEAM * tunnel01)
	if player.is_empty() or path == null or not path.is_ready():
		beam = 0.0
	_beam = beam
	_spot_active = 0
	if beam <= 0.001:
		for s: SpotLight3D in spots:
			s.visible = false
		if _sent_beam.y != 0.0:
			_sent_beam = Vector2(_range, 0.0)
			ModernMaterials.set_global("ce_headlight", _sent_beam)
		return
	var z := float(player.get("z", 0.0)) + float(player.get("length", 4.6))
	var x := float(player.get("x", 0.0))
	var heading := path.heading_at(z)
	var fwd := RoadPath3D.fwd_of(heading)
	var right := RoadPath3D.right_of(heading)
	_beam_pos = path.world(z, x, HEADLIGHT_H)
	_beam_dir = fwd
	ModernMaterials.set_global("ce_headlight_pos", _beam_pos)
	ModernMaterials.set_global("ce_headlight_dir", fwd)
	if not is_equal_approx(_sent_beam.y, beam) or not is_equal_approx(_sent_beam.x, _range):
		_sent_beam = Vector2(_range, beam)
		ModernMaterials.set_global("ce_headlight", _sent_beam)
	var aim := (fwd * cos(deg_to_rad(HEADLIGHT_PITCH_DEG)) - Vector3.UP * sin(deg_to_rad(HEADLIGHT_PITCH_DEG))).normalized()
	var basis := Basis.looking_at(aim, Vector3.UP)
	for i in spots.size():
		var s := spots[i]
		var side := -1.0 if i == 0 else 1.0
		if spots.size() == 1:
			side = 0.0
		s.transform = Transform3D(basis, _beam_pos + right * (side * HEADLIGHT_HALF_M) - fwd * 0.15)
		s.light_energy = SPOT_ENERGY * beam / _intensity * (2.0 / float(spots.size()))
		s.visible = true
		_spot_active += 1


## Light pools on the ground: the nearest lamps and the cones of the traffic ahead; the omni pool on the same lamps.
func _update_pools(view: Dictionary, lamps_on: float, lights: float, ambient: Color, path: RoadPath3D) -> void:
	var n := 0
	var cam_z := float(view.get("camera_z", 0.0))
	var z_lo := float(path.first) * path.seg_len
	var z_hi := float(path.last()) * path.seg_len
	var ref := path.centre_at(clampf(cam_z + POOL_AHEAD_M, z_lo, z_hi))
	# lamps: ranked by their distance from a point ahead of the camera – anew when the camera enters a new segment
	# or the set of lamps changed; in between only the chosen ones are followed
	var keep := maxi(_max_lamp_pools, omnis.size()) + 1
	var cam_seg := int(floor(cam_z / path.seg_len))
	if cam_seg != _rank_seg:
		_rank_seg = cam_seg
		_ranked.clear()
		if _static_count > 0:
			var all: Array = []
			for pair: Array in _statics:
				var parent: Node3D = pair[0]
				if not parent.is_inside_tree():
					_rank_seg = -1          # a chunk that is not in the tree yet: rank again in the next frame
					continue
				var tr := parent.global_transform
				for e: Dictionary in pair[1]:
					var wp: Vector3 = tr * (e["pos"] as Vector3)
					all.append([(wp.x - ref.x) * (wp.x - ref.x) + (wp.z - ref.z) * (wp.z - ref.z), parent, e])
			all.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
			for i in mini(all.size(), keep):
				_ranked.append([all[i][1], all[i][2]])
	var dist := PackedFloat32Array()
	var pos: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	for r: Array in _ranked:
		var node: Variant = r[0]
		if not is_instance_valid(node) or not (node as Node3D).is_inside_tree():
			_rank_seg = -1
			dist.append(INF)
			pos.append(Vector3.ZERO)
			dirs.append(Vector3.DOWN)
			continue
		var parent: Node3D = node
		var tr := parent.global_transform
		var e: Dictionary = r[1]
		var wp: Vector3 = tr * (e["pos"] as Vector3)
		dist.append(sqrt((wp.x - ref.x) * (wp.x - ref.x) + (wp.z - ref.z) * (wp.z - ref.z)))
		pos.append(wp)
		dirs.append((tr.basis * (e["dir"] as Vector3)).normalized())
		if float(e["drop"]) < 0.0:
			e["drop"] = _lamp_drop(parent, wp, path)
	var lamp_n := mini(_ranked.size(), _max_lamp_pools)
	var next_d := dist[lamp_n] if _ranked.size() > lamp_n else INF
	for i in lamp_n:
		if is_inf(dist[i]):
			continue
		var e: Dictionary = _ranked[i][1]
		var centre := pos[i] + dirs[i] * (float(e["drop"]) / maxf(-dirs[i].y, 0.3))
		# the farthest lamp fades before the next one takes its place: no light pops on or off
		var fade := 1.0 if is_inf(next_d) else clampf((next_d - dist[i]) / maxf(next_d * 0.15, 1.0), 0.0, 1.0)
		var light := display_to_light(POOL_LEVEL * float(e["energy"]) * lamps_on * fade, e["color"], ambient)
		_pool_pos[n] = Vector4(centre.x, centre.y, centre.z, float(e["range"]))
		_pool_col[n] = Vector4(light.r, light.g, light.b, 0.0)
		_pool_dir[n] = Vector4.ZERO
		n += 1
	_pool_lamps = n
	# the omni pool on the nearest lamps
	_omni_active = 0
	var omni_n := mini(_ranked.size(), omnis.size())
	var omni_next := dist[omni_n] if _ranked.size() > omni_n else INF
	for i in omnis.size():
		var o := omnis[i]
		if i >= omni_n or is_inf(dist[i]):
			o.visible = false
			continue
		var e2: Dictionary = _ranked[i][1]
		var fade2 := 1.0 if is_inf(omni_next) else clampf((omni_next - dist[i]) / maxf(omni_next * 0.15, 1.0), 0.0, 1.0)
		o.position = pos[i]
		o.omni_range = float(e2["range"]) * OMNI_REACH
		o.light_color = e2["color"]
		o.light_energy = OMNI_ENERGY * float(e2["energy"]) * lamps_on * fade2
		o.visible = o.light_energy > 0.001
		if o.visible:
			_omni_active += 1
	# headlight cones of the traffic ahead (Arcade: the first six cars of the view up to 140 m ahead of the camera)
	var traffic := 0
	if lights > 0.04 and _max_traffic > 0:
		for c: Dictionary in view.get("cars", []):
			var cz := float(c.get("z", 0.0)) + float(c.get("length", 4.5))
			if cz <= cam_z or cz >= cam_z + TRAFFIC_AHEAD_M or cz < z_lo or cz > z_hi:
				continue
			var p := path.world(cz, float(c.get("x", 0.0)), 0.0)
			var f := RoadPath3D.fwd_of(path.heading_at(cz))
			var light := display_to_light(TRAFFIC_LEVEL * lights, LAMP_COLOR, ambient)
			_pool_pos[n] = Vector4(p.x, p.y, p.z, TRAFFIC_REACH_M)
			_pool_col[n] = Vector4(light.r, light.g, light.b, 1.0)
			_pool_dir[n] = Vector4(f.x, f.y, f.z, 0.0)
			n += 1
			traffic += 1
			if traffic >= _max_traffic:
				break
	_pool_traffic = traffic
	_pool_count = n


## Height of a lamp above the road beside it: the nearest row of its chunk (the chunk node above `parent` is named
## "Chunk<index>" by the streamer), else of the whole path.
func _lamp_drop(parent: Node3D, wp: Vector3, path: RoadPath3D) -> float:
	var from := path.first
	var to := path.last()
	var step := 8
	var streamer: ChunkStreamer = _renderer.get("streamer")
	var node: Node = parent
	while node != null and streamer != null:
		var nm := String(node.name)
		if nm.begins_with("Chunk") and nm.substr(5).is_valid_int():
			from = maxi(from, nm.substr(5).to_int() * streamer.chunk_segments)
			to = mini(to, from + streamer.chunk_segments)
			step = 2
			break
		node = node.get_parent()
	var best := INF
	var drop := LAMP_DROP_M
	for k in range(from, to + 1, step):
		var p := path.point(k)
		var d := (p.x - wp.x) * (p.x - wp.x) + (p.z - wp.z) * (p.z - wp.z)
		if d < best:
			best = d
			drop = wp.y - p.y
	return clampf(drop, 0.5, 40.0)


## Sends the pool arrays to every registered ground material (only the count while nothing is lit).
func _send_pools() -> void:
	if _pool_count == 0 and _pools_sent == 0:
		return
	var mats: Array = _renderer.call(&"pool_materials")
	for m: Variant in mats:
		var mat := m as ShaderMaterial
		if mat == null:
			continue
		if _pool_count > 0:
			mat.set_shader_parameter("pool_pos_r", _pool_pos)
			mat.set_shader_parameter("pool_col", _pool_col)
			mat.set_shader_parameter("pool_dir", _pool_dir)
		mat.set_shader_parameter("pool_count", _pool_count)
	_pools_sent = _pool_count


## Glints of the reflectors inside the player's beam.
func _update_glints() -> void:
	if _glints == null:
		return
	if _beam <= 0.02 or _reflector_count == 0:
		if _glint_count != 0:
			_glint_count = 0
			_glint_mm.visible_instance_count = 0
			_glints.visible = false
		return
	var n := 0
	for pair: Array in _reflectors:
		var parent: Node3D = pair[0]
		if not parent.is_inside_tree():
			continue
		var tr := parent.global_transform
		if (tr.origin - _beam_pos).length_squared() > (_range + 120.0) * (_range + 120.0):
			continue
		for e: Dictionary in pair[1]:
			var wp: Vector3 = tr * (e["pos"] as Vector3)
			var shape := headlight_shape(wp, _beam_pos, _beam_dir, _range)
			if shape <= 0.01:
				continue
			# a reflector throws the light back where it came from: it has to look at the car
			var facing := (tr.basis * (e["dir"] as Vector3)).normalized().dot((_beam_pos - wp).normalized())
			var strength := clampf(_beam * shape * GLINT_GAIN * smoothstep(0.0, 0.5, facing), 0.0, 1.0)
			if strength <= 0.02:
				continue
			var c: Color = e["color"]
			_glint_mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * GLINT_RADIUS_M), wp))
			_glint_mm.set_instance_color(n, Color(c.r, c.g, c.b, strength))
			n += 1
			if n >= GLINT_MAX:
				break
		if n >= GLINT_MAX:
			break
	_glint_count = n
	_glint_mm.visible_instance_count = n
	_glints.visible = n > 0


## Shape of the player's cone on the ground, 0..1 – the law of inc/headlight.gdshaderinc (RoadRenderer._light).
static func headlight_shape(world_pos: Vector3, lamp_pos: Vector3, lamp_dir: Vector3, reach: float) -> float:
	var rel := world_pos - lamp_pos
	var d := rel.x * lamp_dir.x + rel.z * lamp_dir.z
	if d <= -2.0 or d >= reach:
		return 0.0
	var sx := rel.x - lamp_dir.x * d
	var sz := rel.z - lamp_dir.z * d
	var q := sqrt(sx * sx + sz * sz) / (0.9 + maxf(d, 0.0) * 0.13)
	var q2 := q * q
	return smoothstep(-2.0, 5.0, d) * (1.0 - smoothstep(reach * 0.3, reach, d)) / (1.0 + q2 * q2)


## Linear light that adds the display value `level` (tinted with `colour`) to a surface lit by the linear ambient
## light `ambient` – Arcade adds light in display values (albedo × (ambient + level)).
static func display_to_light(level: float, colour: Color, ambient: Color) -> Color:
	var out := Color.BLACK
	for ch in 3:
		var a := pow(maxf(ambient[ch], 0.0), 0.4545)
		out[ch] = maxf(pow(a + level * colour[ch], 2.2) - ambient[ch], 0.0)
	return out


func perf() -> Dictionary:
	return {"lights_omni": _omni_active, "lights_spot": _spot_active}


func snapshot() -> Dictionary:
	return {"lights": {"omni": _omni_active, "spot": _spot_active, "pools": _pool_count, "pools_lamps": _pool_lamps,
		"pools_traffic": _pool_traffic, "omni_pool": omnis.size(), "static_lamps": _static_count, "reflectors": _reflector_count,
		"glints": _glint_count, "beam": snappedf(_beam, 0.0001), "beam_range_m": _range}}
