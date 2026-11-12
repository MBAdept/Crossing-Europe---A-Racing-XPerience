extends Node3D
## Layer "weather" of the mode "Modern" (contract §6 R4, §4.10 „Effekte“, Rule 10; docs/renderer-modern.md §15): the
## weather in the air – what Arcade draws in RoadRenderer._draw_weather and its spray, and more of it.
##  * Rain and snow: stateless GPU particles (assets/shaders/modern/particles_rain.gdshader, particles_snow.gdshader) –
##    one MultiMesh of quads whose places are a pure function of the instance number, the camera and ce_time, in a box
##    in camera space that moves with the camera's travel on the road (odo). Nothing is simulated or stored: the
##    picture is deterministic (--gfx-sync, --shot-fast, goldens), stands still in the pause and does not jump at a
##    rebase of the floating origin; there is no particle process shader to compile. (The contract names
##    GPUParticles3D; a GPUParticles3D node keeps per-frame GPU state – A-2: it would stand still with --shot-fast,
##    differ between runs and jump at every rebase. Reported as a contract question.)
##    How many: the level's graphics.levels.effects[].particles (300 / 1,500 / 4,000) in a box per level (RAIN_BOX,
##    SNOW_BOX) – level 0 has at least Arcade's density (240 drops / 420 flakes in Arcade's box), every level shows
##    precipitation (Steam Deck preset included). Off in tunnels (hidden at tunnel01 = 1, dimmed on the portal ramp);
##    no shadow.
##  * Spray behind every car on a wet road above 40 km/h (assets/shaders/modern/spray.gdshader): a plume behind each
##    rear wheel and a trailing mist, larger behind trucks and buses, the player's own at SPRAY_PLAYER; lit on the CPU
##    (ambient, the player's low beam where it reaches the puff, the red of the car's rear lights at night). The vehicle
##    layer hands the sources over every frame (set_spray_sources, duck-typed). At „Effekte: Aus“ (spray off in the
##    contract's table) each car keeps ONE mist puff – Arcade's ellipse – so no preset shows less than Arcade.
## The wet road (darker, smoother, sky mirror) is road.gdshader; the reflections of lamps on it are the layer "flares"
## (flare_streak); snow on the ground and the snow banks are the terrain builder. Nothing here reads the wall clock.
## Owner: R4. Docs: docs/renderer-modern.md §15.

const RAIN := "rain"
const SNOW := "snow"
## Box of the particles per „Effekte“ level: Vector3(half width, nearest z, farthest z) in metres ahead of the camera.
## Arcade: rain 3 … 45 m, snow 2 … 38 m, ±14 m (240 drops = 0.023 per m³, 420 flakes = 0.046 per m³).
const RAIN_BOX: Array[Vector3] = [Vector3(14.0, 3.0, 45.0), Vector3(18.0, 2.0, 55.0), Vector3(22.0, 1.5, 65.0)]
const SNOW_BOX: Array[Vector3] = [Vector3(12.0, 2.0, 30.0), Vector3(16.0, 1.5, 41.0), Vector3(20.0, 1.2, 50.0)]
const BOX_BELOW := -3.6              ## the box reaches this far below the camera (camera height 3.4 m: 0.2 m into the road) …
const BOX_ABOVE := 6.0               ## … and this far above it (Arcade: up to 9 m above the road)
const SPRAY_MIN_KMH := 40.0          ## Arcade: spray from 40 km/h, full at 160 km/h
const SPRAY_FULL_KMH := 160.0
const SPRAY_STRENGTH := 0.34         ## Arcade's ellipse: 0.28
const SPRAY_HEAVY := 1.3             ## trucks and buses throw more
const SPRAY_PLAYER := 0.55           ## the player's own spray (in front of the camera: it must not veil the car)
const SPRAY_TAIL := 0.5              ## red of the car's own rear lights in its spray at night
const MAX_PUFFS := 240
const SOURCE_FLOATS := 13            ## set_spray_sources(): rear (3), forward (3), width, length, fade, km/h, flags, tail, id
const FLAG_PLAYER := 1
const FLAG_HEAVY := 2
const FLAG_TUNNEL := 4
const PUFF_FLOATS := 20              ## MultiMesh: 12 transform + 4 colour + 4 custom
const SPRAY_COLOR := Color(0.9, 0.92, 0.95)   ## Arcade: the fog colour washed half towards this

var kind := ""                       ## "rain", "snow" or "" (the stage's weather)
var _renderer: Node
var _mats: ModernMaterials
var _count := 300
var _level := 0
var _spray_full := false
var _box := Vector3(14.0, 3.0, 45.0)
var _particles: MultiMeshInstance3D
var _pmat: ShaderMaterial
var _spray: MultiMeshInstance3D
var _spray_mm: MultiMesh
var _smat: ShaderMaterial
var _src := PackedFloat32Array()
var _src_n := 0
var _buf := PackedFloat32Array()
var _puffs := 0
var _fade := 1.0
var _shown := false
var _cam_h := 3.4
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
		_cam_h = (proj as RoadProjection).cam_height


func apply_quality(levels: Dictionary) -> void:
	_count = clampi(int(levels.get("particles", 300)), 50, 8000)
	_level = level_of(_count)
	_spray_full = bool(levels.get("spray", false))


func prepare(ctx: Dictionary) -> void:
	kind = kind_of(str(ctx.get("weather", "normal")))
	_build()


## The particle level a count belongs to (graphics.levels.effects: 300 / 1,500 / 4,000).
static func level_of(count: int) -> int:
	return 0 if count <= 600 else (1 if count <= 2500 else 2)


## "rain" / "snow" / "" for a weather id of the stage.
static func kind_of(weather: String) -> String:
	return RAIN if weather == RAIN else (SNOW if weather == SNOW else "")


## The box of a kind and level: Vector3(half width, nearest, farthest z).
static func box_for(k: String, level: int) -> Vector3:
	var boxes: Array[Vector3] = SNOW_BOX if k == SNOW else RAIN_BOX
	return boxes[clampi(level, 0, boxes.size() - 1)]


## Particles per cubic metre of a kind, level and count (tests: level 0 at least Arcade's density).
static func density(k: String, level: int, count: int) -> float:
	var b := box_for(k, level)
	return float(count) / (2.0 * b.x * (b.z - b.y) * (BOX_ABOVE - BOX_BELOW))


func _build() -> void:
	if kind == "":
		return
	_box = box_for(kind, _level)
	_pmat = _mats.material("particles_snow" if kind == SNOW else "particles_rain") as ShaderMaterial
	if _pmat != null:
		_pmat.set_shader_parameter(&"box_lo", Vector3(-_box.x, BOX_BELOW, _box.y))
		_pmat.set_shader_parameter(&"box_hi", Vector3(_box.x, BOX_ABOVE, _box.z))
	_particles = _particle_node(_count, _pmat)
	_particles.name = "Precipitation"
	_particles.visible = false
	add_child(_particles)
	if kind == RAIN:
		_smat = _mats.material("spray") as ShaderMaterial
		_spray_mm = MultiMesh.new()
		_spray_mm.transform_format = MultiMesh.TRANSFORM_3D
		_spray_mm.use_colors = true
		_spray_mm.use_custom_data = true
		_spray_mm.mesh = _quad()
		_spray_mm.instance_count = MAX_PUFFS
		_spray_mm.visible_instance_count = 0
		_spray = MultiMeshInstance3D.new()
		_spray.name = "Spray"
		_spray.multimesh = _spray_mm
		_spray.material_override = _smat
		_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spray.custom_aabb = AABB(Vector3(-6000.0, -2000.0, -6000.0), Vector3(12000.0, 4000.0, 12000.0))
		_spray.visible = false
		var world: Variant = _renderer.get("world") if _renderer != null else null
		if world is Node3D:
			(world as Node3D).add_child(_spray)
		else:
			add_child(_spray)
		_buf.resize(MAX_PUFFS * PUFF_FLOATS)


## A MultiMesh node of `count` particle quads (every instance transform the identity: the shader places them).
static func _particle_node(count: int, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _quad()
	mm.instance_count = count
	var b := PackedFloat32Array()
	b.resize(count * 12)
	for i in count:
		b[i * 12] = 1.0
		b[i * 12 + 5] = 1.0
		b[i * 12 + 10] = 1.0
	mm.buffer = b
	var n := MultiMeshInstance3D.new()
	n.multimesh = mm
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.custom_aabb = AABB(Vector3(-1.0e5, -1.0e4, -1.0e5), Vector3(2.0e5, 2.0e4, 2.0e5))
	return n


## The vehicle layer's spray sources of this frame (SOURCE_FLOATS each: rear centre on the ground (world), forward
## unit vector, width, length, fade, km/h, flags, tail light 0..1, car id). The buffer is read, not kept.
func set_spray_sources(buf: PackedFloat32Array, count: int) -> void:
	_src = buf
	_src_n = mini(count, buf.size() / SOURCE_FLOATS)


func update(view: Dictionary, _dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_updates += 1
	if kind == "" or _renderer == null:
		return
	var path: RoadPath3D = _renderer.get("path")
	var cam: Camera3D = _renderer.get("camera")
	if path == null or not path.is_ready() or cam == null:
		return
	var pal: Dictionary = view.get("palette", {})
	var tunnel01 := 1.0 if bool(view.get("camera_in_tunnel", false)) else 0.0
	var env: Node = _renderer.get("env")
	if env != null:
		var st: Variant = env.get("state")
		if st is Dictionary and not (st as Dictionary).is_empty():
			tunnel01 = float((st as Dictionary).get("tunnel01", tunnel01))
	_fade = clampf(1.0 - tunnel01, 0.0, 1.0)
	var amount := float(pal.get("snow", 0.0)) if kind == SNOW else float(pal.get("wet", 0.0))
	_shown = _fade > 0.001 and amount > 0.0
	var cam_z := float(view.get("camera_z", 0.0))
	var z_lo := float(path.first) * path.seg_len
	var z_hi := float(path.last()) * path.seg_len
	var heading := path.heading_at(clampf(cam_z, z_lo, z_hi))
	var fwd := RoadPath3D.fwd_of(heading)
	var cam_t := cam.global_transform if cam.is_inside_tree() else cam.transform
	var speed := float(view.get("speed", 0.0)) / 3.6
	if _particles != null:
		_particles.visible = _shown
		if _shown and _pmat != null:
			_pmat.set_shader_parameter(&"cam_pos", cam_t.origin)
			_pmat.set_shader_parameter(&"cam_fwd", fwd)
			_pmat.set_shader_parameter(&"odo", fposmod(cam_z, _box.z - _box.y))
			_pmat.set_shader_parameter(&"cam_vel", fwd * speed)
			_pmat.set_shader_parameter(&"fade", _fade * amount)
	if _spray != null:
		_update_spray(view, pal, amount)
	var us := Time.get_ticks_usec() - t0
	_us_sum += us
	_us_max = maxi(_us_max, us)


func _update_spray(_view: Dictionary, pal: Dictionary, wet: float) -> void:
	_puffs = 0
	if wet <= 0.0 or _src_n <= 0 or _fade <= 0.001:
		_spray_mm.visible_instance_count = 0
		_spray.visible = false
		return
	var lights := clampf(float(pal.get("lights", 0.0)), 0.0, 1.0)
	var fog: Color = pal.get("fog", Color(0.6, 0.65, 0.7))
	var amb: Color = pal.get("ambient", Color.WHITE)
	var env: Node = _renderer.get("env")
	if env != null:
		var st: Variant = env.get("state")
		if st is Dictionary and not (st as Dictionary).is_empty():
			amb = (st as Dictionary).get("display", amb)
	var base := fog.lerp(SPRAY_COLOR, 0.5)
	var lit := Color(minf(1.0, amb.r + 0.2), minf(1.0, amb.g + 0.2), minf(1.0, amb.b + 0.2))
	var lights_layer: Node = _renderer.call(&"layer", "lights")
	var has_beam := lights_layer != null and lights_layer.has_method(&"beam_at")
	for i in _src_n:
		var o := i * SOURCE_FLOATS
		var kmh := _src[o + 9]
		var flags := int(_src[o + 10])
		if flags & FLAG_TUNNEL != 0 or kmh <= SPRAY_MIN_KMH:
			continue
		var k := clampf((kmh - SPRAY_MIN_KMH) / (SPRAY_FULL_KMH - SPRAY_MIN_KMH), 0.0, 1.0)
		var s := k * SPRAY_STRENGTH * wet * _fade * _src[o + 8]
		if flags & FLAG_HEAVY != 0:
			s *= SPRAY_HEAVY
		if flags & FLAG_PLAYER != 0:
			s *= SPRAY_PLAYER
		if s <= 0.004:
			continue
		var rear := Vector3(_src[o], _src[o + 1], _src[o + 2])
		var f := Vector3(_src[o + 3], _src[o + 4], _src[o + 5])
		var right := f.cross(Vector3.UP).normalized()
		var back := -f
		var w := _src[o + 6]
		var tail := _src[o + 11] * lights
		var seed := fposmod(_src[o + 12] * 0.6180339, 1.0)
		var heavy := flags & FLAG_HEAVY != 0
		var rise := 0.6 + 2.2 * k
		var puffs: Array = spray_puffs(rear, back, right, w, k, heavy, _spray_full)
		for j in puffs.size():
			if _puffs >= MAX_PUFFS:
				break
			var pf: Array = puffs[j]
			var pos: Vector3 = pf[0]
			var size: Vector2 = pf[1]
			var share: float = pf[2]
			var red: float = pf[3]
			var beam := float(lights_layer.call(&"beam_at", pos)) if has_beam else 0.0
			var col := Color(base.r * lit.r + beam, base.g * lit.g + beam * 0.93, base.b * lit.b + beam * 0.8)
			col = col.lerp(Color(1.0, 0.16, 0.07), clampf(tail * SPRAY_TAIL * red, 0.0, 0.8))
			_put_puff(pos, size, Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0), clampf(s * share, 0.0, 1.0)),
				seed + float(j) * 0.37, rise)
	_spray_mm.visible_instance_count = _puffs
	if _puffs > 0:
		_spray_mm.buffer = _buf
	_spray.visible = _puffs > 0


## The puffs of one car: [[centre (world), half size (m), share of the strength, share of the rear-light red], …].
## rear = centre of the rear on the ground, back / right unit vectors, w = width, k = 0..1 speed factor. Full spray
## (Effekte ≥ 1): a plume behind each rear wheel and a trailing mist; otherwise one mist puff where Arcade draws its
## ellipse (half size 0.75 × width × 0.6 m, 0.45 m up). Pure (unit test).
static func spray_puffs(rear: Vector3, back: Vector3, right: Vector3, w: float, k: float, heavy: bool, full: bool) -> Array:
	var up := Vector3.UP
	if not full:
		return [[rear + back * 0.5 + up * 0.45, Vector2(w * 0.75, 0.6), 1.0, 0.6]]
	var g := 1.45 if heavy else 1.0
	var out: Array = []
	for side: float in [-1.0, 1.0]:
		out.append([rear + back * (0.35 * g) + right * (side * w * 0.36) + up * (0.32 * g), Vector2(w * 0.26 + 0.18 * g, 0.42 * g), 0.9, 1.0])
	out.append([rear + back * ((1.3 + 0.9 * k) * g) + up * (0.6 * g), Vector2(w * (0.7 + 0.15 * k), 0.75 * g) * (1.0 + 0.35 * k), 0.75, 0.35])
	return out


func _put_puff(pos: Vector3, half: Vector2, col: Color, seed: float, rise: float) -> void:
	var o := _puffs * PUFF_FLOATS
	_buf[o] = 1.0
	_buf[o + 1] = 0.0
	_buf[o + 2] = 0.0
	_buf[o + 3] = pos.x
	_buf[o + 4] = 0.0
	_buf[o + 5] = 1.0
	_buf[o + 6] = 0.0
	_buf[o + 7] = pos.y
	_buf[o + 8] = 0.0
	_buf[o + 9] = 0.0
	_buf[o + 10] = 1.0
	_buf[o + 11] = pos.z
	_buf[o + 12] = col.r
	_buf[o + 13] = col.g
	_buf[o + 14] = col.b
	_buf[o + 15] = col.a
	_buf[o + 16] = half.x
	_buf[o + 17] = half.y
	_buf[o + 18] = fposmod(seed, 1.0)
	_buf[o + 19] = rise
	_puffs += 1


## Fresh nodes per shader variant, shown behind the loading cover (D10: no hitch when the rain first appears).
func warmup_nodes() -> Array:
	var out: Array = []
	if kind == "":
		return out
	var p := _particle_node(8, _pmat)
	out.append(p)
	if _smat != null:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = _quad()
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0)))
		mm.set_instance_color(0, Color(0.7, 0.7, 0.75, 0.3))
		mm.set_instance_custom_data(0, Color(1.0, 0.6, 0.3, 1.0))
		var n := MultiMeshInstance3D.new()
		n.multimesh = mm
		n.material_override = _smat
		out.append(n)
	return out


func perf() -> Dictionary:
	return {"particles": _count if _shown else 0, "spray_puffs": _puffs,
		"weather_us_avg": float(_us_sum) / maxf(1.0, float(_updates)), "weather_us_max": _us_max}


func snapshot() -> Dictionary:
	return {"weather": {"kind": kind, "particles": _count, "level": _level, "shown": _shown, "fade": snappedf(_fade, 0.001),
		"box": [_box.x, _box.y, _box.z], "spray_full": _spray_full, "spray_sources": _src_n, "spray_puffs": _puffs}}


static func _quad() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1.0, -1.0, 0.0), Vector3(1.0, -1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(-1.0, 1.0, 0.0)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _exit_tree() -> void:
	if is_instance_valid(_spray) and _spray.get_parent() != self:
		_spray.queue_free()
