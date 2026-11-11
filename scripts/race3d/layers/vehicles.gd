extends Node3D
## Layer "vehicles" of the mode "Modern" (contract §6 R3; docs/renderer-modern.md §10): every car of the view –
## traffic, police and the player – as a real 3D model from the model manifest, keyed by the view's vehicle id.
##  * data-driven: a set resolves through ModelDB to a model (any number of levels of detail, articulated units
##    from the manifest "groups") or to its stand-in, a box of the set's size, paint and lamps (ModelFactory.
##    build_box) – a new model appears without a code change, a set without one is never missing;
##  * pose from two points of the road (rear and front of the collision box): yaw and pitch follow the road; own
##    heading from the lateral speed (critically damped like Arcade's sprites); the player car adds steering
##    (steer x 3 deg), understeer (x 6 deg) and the body roll (<= 2.5 deg), and blinks with view.player.visible;
##    articulated vehicles: every unit is posed from its own points, coupled at the pivot of the next unit;
##  * wheels spin with the distance driven (left wheels turned the other way) and the front wheels steer;
##  * level of detail by path distance (graphics levels vehicle_lod0_m / vehicle_lod1_m), with hysteresis;
##  * lamps through the instance uniforms lamp_a / lamp_b (tail with the lights of the palette and inside tunnels,
##    brake, indicators with Arcade's 0.72 s period from blink_t, beacons), the sun mask inside tunnels, the
##    path-distance fade of Arcade (F5, dither) – uniforms are only touched when their value changes;
##  * shadows: the model's caster when the quality levels have vehicle casters, and in every preset a soft
##    contact shadow under the car (one MultiMesh for all);
##  * the flare points of every car go to the layer "flares" each frame (set_vehicle_flares, duck-typed).
## No per-frame allocations in the loop: packed buffers are reused, cars and their nodes are pooled per set.
## Talks to the renderer only through its facade (A-7) and to the flare layer through has_method.
## Owner: R3. Docs: docs/renderer-modern.md §10.

const FLARE_OFFSET_M := 0.06        ## a flare sits this far in front of its lamp (along lights[].dir)
const BEHIND_M := 14.0              ## cars whose front is further behind the camera than this are not drawn
const AHEAD_MARGIN_M := 30.0        ## … and those beyond the visibility plus this
const POOL_PER_SET := 6             ## free cars kept per set for reuse
const LOD_REF_0 := 40.0             ## the manifest's first level is made for this distance (Details "Mittel") …
const LOD_REF_1 := 120.0            ## … and the second for this one
const SHADOW_MARGIN_M := 0.45       ## contact shadow beyond the footprint
const ROLL_PIVOT_Y := 0.38          ## the body rolls about this height
const STEER_DEG := 7.0              ## player's front wheels: steering input share (deg at full lock)
const FLOATS_PER_FLARE := 20        ## MultiMesh layout: 12 transform + 4 colour + 4 custom
const FLOATS_PER_SHADOW := 16       ## 12 transform + 4 custom
const PLAYER_ID := -999999          ## view id of the player car in this layer
## Extra ambient light on the player car (vpbr instance uniform fill, a share of ce_ambient): Arcade draws its player
## sprite brighter than the scene (ambient x 1.15 + 0.08) – the car stays readable in its own shade (the sun stands
## ahead at noon) and at night.
const PLAYER_FILL := 0.7
const BOX_GLOSS := 0.35             ## clear coat of the box stand-in (flat panels mirror the horizon like glass)
## The race look of the shared vehicle materials (the shaders' defaults are neutral – the look of the vertex format
## alone, what the contact sheet shows): [class, uniform, value].
const LOOK: Array = [["vpbr", "env_energy", 1.6], ["vpbr", "paint_base", 0.9], ["vpbr", "flake_strength", 0.6],
	["glass", "env_energy", 2.2]]

## A car of the view and its nodes (pooled per set).
class Car:
	var id := 0
	var set_id := ""
	var info: Dictionary = {}       ## the set's entry of _set_info()
	var root: Node3D                ## posed every frame (child of renderer.world)
	var levels: Dictionary = {}     ## level name -> built node (child of root)
	var lod := ""
	var lod_i := -1                 ## index of lod in the set's lod_names
	var node: Node3D                ## the level shown
	var geo: Array[GeometryInstance3D] = []
	var body: Array[GeometryInstance3D] = []   ## meshes that carry lamps (not the wheels)
	var wheels: Array = []          ## [MeshInstance3D, base Transform3D, radius, left, steer]
	var groups: Array = []          ## [[Node3D, pivot Vector3], …] leading unit first (articulated levels)
	var roll_nodes: Array = []      ## [Node3D, base Transform3D]: what rolls with the body (player)
	var caster: GeometryInstance3D  ## the level's shadow caster (or null)
	var la := Vector4(-1, -1, -1, -1)
	var lb := Vector4(-1, -1, -1, -1)
	var fade := -1.0
	var sun := -1.0
	var shown := false
	var seen := 0
	var yaw := 0.0
	var yaw_v := 0.0
	var last_x := 0.0
	var last_t := -1.0
	var lat := 0.0
	var pose := Transform3D.IDENTITY
	var group_pose: Array[Transform3D] = []
	var z := 0.0
	var x := 0.0
	var dist := 0.0
	var cast := false

var _renderer: Node
var _mats: ModernMaterials
var _levels: Dictionary = {}
var _cfg: Dictionary = {}
var _sets: Array[String] = []        ## vehicle sets of the stage
var _set_cache: Dictionary = {}      ## set id -> info
var _cars: Dictionary = {}           ## view id -> Car
var _free: Dictionary = {}           ## set id -> Array of Car
var _frame := 0
var _requested := false
var _fail := ""
var _casters := false
var _lod0_k := 1.0
var _lod1_k := 1.0
var _fog_frac := 0.45
var _tunnel_fog_m := 260.0
var _curve_r1 := 120.0
var _veh_tau := 0.12
var _pl_tau := 0.15
var _roll_per := 0.22
var _roll_max := 2.5
var _roll_tau := 0.2
var _pl_k: Dictionary = {}
var _pl_yaw := 0.0
var _pl_yaw_v := 0.0
var _pl_roll := 0.0
var _pl_roll_v := 0.0
var _pl_lat := 0.0
var _pl_init := false
var _flares := PackedFloat32Array()
var _flare_n := 0
var _shadow_mm: MultiMesh
var _shadow_node: MultiMeshInstance3D
var _shadow_buf := PackedFloat32Array()
var _shadow_n := 0
var _env_key := Vector4(-1, -1, -1, -1)
var _last_time := -1.0
var _us_sum := 0
var _us_max := 0
var _updates := 0
var _drawn := 0
var _builds := 0
var _fallback_sets: Dictionary = {}


func setup(renderer: Node) -> void:
	_renderer = renderer
	_mats = renderer.get("materials") as ModernMaterials
	if _mats == null:
		_mats = ModernMaterials.shared()
	var cfg: Variant = renderer.get("cfg")
	_cfg = cfg if cfg is Dictionary else {}
	var r: Variant = ConfigLoader.lookup(_cfg, "render", {})
	var rd: Dictionary = r if r is Dictionary else {}
	_fog_frac = float(rd.get("fog_start_frac", 0.45))
	var tun: Variant = rd.get("tunnel", {})
	_tunnel_fog_m = float((tun as Dictionary).get("darkness_m", 260.0)) if tun is Dictionary else 260.0
	_curve_r1 = maxf(1.0, float(ConfigLoader.lookup(_cfg, "road.curve_radius_at_1_m", 120.0)))
	_veh_tau = float(rd.get("vehicle_yaw_smooth_s", 0.12))
	_pl_tau = float(rd.get("player_yaw_smooth_s", 0.15))
	_roll_per = float(rd.get("player_roll_deg_per_mps2", 0.22))
	_roll_max = minf(2.5, float(rd.get("player_roll_max_deg", 2.5)))
	_roll_tau = float(rd.get("player_roll_smooth_s", 0.2))
	_pl_k = {"steer_deg": float(rd.get("player_steer_deg", 3.0)), "lateral_gain": float(rd.get("player_lateral_gain", 1.0)),
		"understeer_deg": float(rd.get("player_understeer_deg", 6.0)), "max_deg": float(rd.get("player_yaw_max_deg", 20.0))}
	for l: Array in LOOK:
		_mats.material(str(l[0]))                     # the shared class material exists before it is tuned
		_mats.set_class_parameter(str(l[0]), str(l[1]), l[2])
	_shadow_mm = MultiMesh.new()
	_shadow_mm.transform_format = MultiMesh.TRANSFORM_3D
	_shadow_mm.use_custom_data = true
	_shadow_mm.mesh = _shadow_quad()
	_shadow_node = MultiMeshInstance3D.new()
	_shadow_node.name = "ContactShadows"
	_shadow_node.multimesh = _shadow_mm
	_shadow_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow_node.material_override = _mats.material("vehicle_shadow")
	_shadow_node.custom_aabb = AABB(Vector3(-6000.0, -2000.0, -6000.0), Vector3(12000.0, 4000.0, 12000.0))
	var world: Variant = renderer.get("world")
	if world is Node3D:
		(world as Node3D).add_child(_shadow_node)


func apply_quality(levels: Dictionary) -> void:
	_levels = levels.duplicate()
	_casters = int(levels.get("shadow_casters", 0)) >= 1
	_lod0_k = float(levels.get("vehicle_lod0_m", LOD_REF_0)) / LOD_REF_0
	_lod1_k = float(levels.get("vehicle_lod1_m", LOD_REF_1)) / LOD_REF_1


## Starts loading the models of every vehicle set of the stage (ctx.sets: traffic/, police/ and player/ sets).
func prepare(ctx: Dictionary) -> void:
	_sets.clear()
	for s: Variant in ctx.get("sets", []):
		var sid := str(s)
		if is_vehicle_set(sid) and not _sets.has(sid):
			_sets.append(sid)
	if not ModelDB.available():
		_fail = "manifest"
		return
	ModelDB.request(_sets, _lods_wanted(), self)
	_requested = true


func prepare_pending() -> int:
	if not _requested or _fail != "":
		return 0
	var n := ModelDB.pending()
	if n == 0 and _fail == "":
		var missing := ModelDB.missing(_sets, _lods_wanted())
		if not missing.is_empty():
			push_warning("Fahrzeuge: Modelldateien fehlen: %s" % ", ".join(missing.slice(0, 6)))
			_fail = "manifest"
	return n


func fail_reason() -> String:
	return _fail


## One node per shader variant the vehicles use (shown two frames behind the loading cover): a built model of every
## distinct vehicle model of the stage at its first level (vpbr + glass, its shadow caster), a box stand-in and the
## contact shadow.
func warmup_nodes() -> Array:
	var out: Array = []
	var done: Dictionary = {}
	for sid: String in _sets:
		var info := _set_info(sid)
		var key := str(info.get("model_id", "")) if not bool(info.get("box", false)) else "box"
		if done.has(key):
			continue
		done[key] = true
		var n: Node3D = ModelFactory.build_box(sid, _mats) if bool(info.get("box", false)) else ModelFactory.build(sid, "", _mats, true)
		if n != null:
			out.append(n)
	return out


static func is_vehicle_set(set_id: String) -> bool:
	return set_id.begins_with("traffic/") or set_id.begins_with("police/") or set_id.begins_with("player/")


func _lods_wanted() -> Array:
	return ["lod0", "lod1", "lod2", "shadow"]


## What the layer knows about a set: {"model_id", "model", "box": bool, "points": flare points, "obj": size,
## "wheelbase"}; cached.
func _set_info(set_id: String) -> Dictionary:
	var c: Variant = _set_cache.get(set_id)
	if c != null:
		return c
	var r := ModelDB.resolve(set_id)
	var model: Dictionary = r.get("model", {})
	var info := {"model_id": str(r.get("model_id", "")), "model": model, "box": model.is_empty(), "obj": r.get("object", {})}
	var lights: Array = model.get("lights", []) if not model.is_empty() else []
	if model.is_empty():
		var kb := ModelFactory.box_kind(set_id, r.get("object", {}))
		lights = ModelFactory.box_lights(r.get("object", {}), str(kb[0]), bool(kb[1]))
		_fallback_sets[set_id] = true
	info["points"] = VehiclePose3D.flare_points(lights)
	var lv := VehiclePose3D.lod_levels(model)
	info["lod_names"] = lv[0]
	info["lod_limits"] = lv[1]
	# wheelbase from the first level's wheels (front and rear axle), for the steering angle
	var wb := 2.7
	if not model.is_empty():
		var zs: Array[float] = []
		for l: Variant in model.get("lods", []):
			for p: Variant in (l as Dictionary).get("parts", []):
				var pd: Dictionary = p
				var pos: Variant = pd.get("pos", null)
				if pd.has("wheel") and pos is Array and (pos as Array).size() >= 3:
					zs.append(float(pos[2]))
			if not zs.is_empty():
				break
		if zs.size() >= 2:
			zs.sort()
			wb = maxf(1.0, zs[zs.size() - 1] - zs[0])
	info["wheelbase"] = wb
	_set_cache[set_id] = info
	return info


# --- every frame ----------------------------------------------------------------------------------------------------

func update(view: Dictionary, dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	var path: RoadPath3D = _renderer.get("path")
	var track: Track = _renderer.get("track")
	if path == null or not path.is_ready() or track == null:
		return
	_frame += 1
	_flare_n = 0
	_shadow_n = 0
	_drawn = 0
	var pal: Dictionary = view.get("palette", {})
	_set_environment(pal)
	var cam_z := float(view.get("camera_z", 0.0))
	var vis := float(view.get("visibility_m", 900.0))
	var lights := float(pal.get("lights", 0.0))
	var time := float(view.get("time", 0.0))
	var sim_dt := 0.0 if _last_time < 0.0 else clampf(time - _last_time, 0.0, 0.1)
	if dt <= 0.0:
		sim_dt = 0.0
	_last_time = time
	var z_lo := float(path.first) * path.seg_len
	var z_hi := float(path.last()) * path.seg_len
	for c: Variant in view.get("cars", []):
		_update_car(c, false, path, track, cam_z, vis, lights, time, sim_dt, z_lo, z_hi)
	var player: Variant = view.get("player", null)
	if player is Dictionary and not (player as Dictionary).is_empty():
		_update_car(player, true, path, track, cam_z, vis, lights, time, sim_dt, z_lo, z_hi)
	# cars that left the view go back to their set's pool
	for id: Variant in _cars.keys():
		var car: Car = _cars[id]
		if car.seen != _frame:
			_release(car)
			_cars.erase(id)
	_commit_shadows()
	var fl: Variant = _renderer.call(&"layer", "flares")
	if fl is Object and (fl as Object).has_method(&"set_vehicle_flares"):
		(fl as Object).call(&"set_vehicle_flares", _flares, _flare_n)
	var us := Time.get_ticks_usec() - t0
	_us_sum += us
	_us_max = maxi(_us_max, us)
	_updates += 1


func _update_car(c: Dictionary, is_player: bool, path: RoadPath3D, track: Track, cam_z: float, vis: float, lights: float,
		time: float, sim_dt: float, z_lo: float, z_hi: float) -> void:
	var set_id := str(c.get("set", ""))
	if set_id == "":
		return
	var id := PLAYER_ID if is_player else int(c.get("id", -1000000))
	var info := _set_info(set_id)
	var obj: Dictionary = info["obj"]
	var length := float(c.get("length", obj.get("length_m", 4.5)))
	var z := float(c.get("z", 0.0))
	var x := float(c.get("x", 0.0))
	var car: Car = _cars.get(id)
	if car != null and car.set_id != set_id:
		_release(car)
		_cars.erase(id)
		car = null
	var dz := z - cam_z
	var out_of_range := z + length < cam_z - BEHIND_M or dz > vis + AHEAD_MARGIN_M or z < z_lo or z + length > z_hi
	if out_of_range or (is_player and not bool(c.get("visible", true))):
		if car != null:
			car.seen = _frame
			_show(car, false)
			if is_player:
				_player_pose_only(c, path, track, z, x, length, sim_dt)
		return
	if car == null:
		car = _acquire(set_id, id)
		_cars[id] = car
		car.last_x = x
		car.last_t = time
		car.yaw = 0.0
		car.yaw_v = 0.0
	car.seen = _frame
	car.z = z
	car.x = x
	var dist := z + length * 0.5 - cam_z
	car.dist = dist
	# level of detail (no impostors for vehicles: beyond the last level the last level stays)
	if not bool(info["box"]):
		var names: PackedStringArray = info["lod_names"]
		var i := VehiclePose3D.lod_index(info["lod_limits"], maxf(dist, 0.0), _lod0_k, _lod1_k, car.lod_i)
		if i < 0:
			i = names.size() - 1
		if i >= 0 and i != car.lod_i:
			car.lod_i = i
			_set_level(car, names[i])
	elif car.lod == "":
		_set_level(car, "box")
	if car.node == null:
		_show(car, false)
		return
	_show(car, true)
	_drawn += 1
	# pose: chord of the road from the rear to the front of the collision box, own heading, player terms
	var rear := path.world(z, x, 0.0)
	var front := path.world(z + length, x, 0.0)
	var speed_mps := float(c.get("speed", 0.0)) / 3.6
	var roll := 0.0
	if is_player:
		_player_terms(c, track, z + length * 0.5, speed_mps, sim_dt)
		car.yaw = _pl_yaw
		roll = _pl_roll
	else:
		if sim_dt > 0.0 and time > car.last_t + 0.0005:
			car.lat = (x - car.last_x) / (time - car.last_t)
			car.last_x = x
			car.last_t = time
		var target := VehiclePose.own_heading(car.lat, speed_mps)
		var r := VehiclePose.damp(car.yaw, car.yaw_v, target, sim_dt, _veh_tau)
		car.yaw = r.x
		car.yaw_v = r.y
	car.pose = VehiclePose3D.chord_pose(rear, front, car.yaw, 0.0)
	car.root.transform = car.pose
	if not car.groups.is_empty():
		_pose_groups(car, path, z, x, length)
	if is_player and not car.roll_nodes.is_empty():
		var rb := Transform3D(Basis(Vector3.BACK, -deg_to_rad(roll)), Vector3.ZERO)
		var piv := Transform3D(Basis.IDENTITY, Vector3(0.0, ROLL_PIVOT_Y, 0.0))
		var rt := piv * rb * piv.affine_inverse()
		for rn: Array in car.roll_nodes:
			(rn[0] as Node3D).transform = rt * (rn[1] as Transform3D)
	# wheels: roll with the distance driven, the front wheels steer
	if not car.wheels.is_empty():
		var curv := track.curve_at(z + length * 0.5) / _curve_r1
		var steer := float(c.get("steer", 0.0)) if is_player else 0.0
		var delta := VehiclePose3D.steer_angle(float(info["wheelbase"]), curv, steer, STEER_DEG if is_player else 0.0)
		if not is_player:
			delta += car.yaw * 0.5
		var steer_b := Basis(Vector3.UP, -delta)
		for w: Array in car.wheels:
			var base: Transform3D = w[1]
			var spin := VehiclePose3D.wheel_spin(z, float(w[2]), bool(w[3]))
			var b := base.basis * Basis(Vector3.RIGHT, spin)
			if bool(w[4]):
				b = steer_b * b
			(w[0] as Node3D).transform = Transform3D(b, base.origin)
	# fade, sun mask, lamps
	var seg_tunnel := track.is_tunnel_at(z)
	var in_tunnel := track.is_tunnel_at(z + length * 0.5)
	var alpha := VehiclePose3D.fade(dz, vis, _fog_frac, seg_tunnel, _tunnel_fog_m)
	var la := VehiclePose3D.lamp_a(c, in_tunnel)
	var lb := VehiclePose3D.lamp_b(c, in_tunnel)
	_set_uniforms(car, alpha, 0.0 if in_tunnel else 1.0, la, lb)
	# contact shadow and flares
	_add_shadow(car, obj, length, alpha, lights, in_tunnel)
	var l_eff := 1.0 if in_tunnel else lights
	_add_flares(car, info, la, lb, l_eff, alpha, VehiclePose3D.light_alpha(alpha, l_eff))


## The player car while it is not drawn (blinking): its pose terms keep running, so it does not jump back.
func _player_pose_only(c: Dictionary, _path: RoadPath3D, track: Track, z: float, _x: float, length: float, sim_dt: float) -> void:
	_player_terms(c, track, z + length * 0.5, float(c.get("speed", 0.0)) / 3.6, sim_dt)


## Visible yaw and body roll of the player car, smoothed like Arcade's sprite (render.player_*).
func _player_terms(c: Dictionary, track: Track, zc: float, speed_mps: float, sim_dt: float) -> void:
	var lat := float(c.get("lat_speed", 0.0))
	var curve := track.curve_at(zc)
	var target := VehiclePose3D.player_yaw(float(c.get("steer", 0.0)), lat, speed_mps, float(c.get("understeer", 0.0)), curve, _pl_k)
	var dlat := (lat - _pl_lat) / sim_dt if _pl_init and sim_dt > 0.0 else 0.0
	if sim_dt > 0.0 or not _pl_init:
		_pl_lat = lat
	var roll_t := VehiclePose.roll_target_deg(VehiclePose3D.lateral_accel(speed_mps, curve, _curve_r1, dlat), _roll_per, _roll_max)
	if not _pl_init:
		_pl_init = true
		_pl_yaw = target
		_pl_roll = roll_t
		return
	var r := VehiclePose.damp(_pl_yaw, _pl_yaw_v, target, sim_dt, _pl_tau)
	_pl_yaw = r.x
	_pl_yaw_v = r.y
	var q := VehiclePose.damp(_pl_roll, _pl_roll_v, roll_t, sim_dt, _roll_tau)
	_pl_roll = clampf(q.x, -_roll_max, _roll_max)
	_pl_roll_v = q.y


## Articulated units: the leading unit from its pivot's road point to the front of the vehicle, every following unit
## from the rear of the vehicle to the ground under its coupling point on the unit before it.
func _pose_groups(car: Car, path: RoadPath3D, z: float, x: float, length: float) -> void:
	var inv := car.pose.affine_inverse()
	var half := length * 0.5
	var prev_t := Transform3D.IDENTITY
	var prev_pivot := Vector3.ZERO
	for i in car.groups.size():
		var g: Array = car.groups[i]
		var pivot: Vector3 = g[1]
		var t: Transform3D
		if i == 0:
			t = VehiclePose3D.lead_unit(path.world(z + half - pivot.z, x, 0.0), path.world(z + length, x, 0.0), pivot, car.yaw)
		else:
			t = VehiclePose3D.follow_unit(prev_t, prev_pivot, pivot, path.world(z, x, 0.0), car.yaw)
		(g[0] as Node3D).transform = inv * t
		prev_t = t
		prev_pivot = pivot


func _set_uniforms(car: Car, alpha: float, sun: float, la: Vector4, lb: Vector4) -> void:
	var a := snappedf(alpha, 1.0 / 255.0)
	if absf(a - car.fade) > 0.001:
		car.fade = a
		for gi: GeometryInstance3D in car.geo:
			gi.set_instance_shader_parameter(&"fade", a)
	if sun != car.sun:
		car.sun = sun
		for gi: GeometryInstance3D in car.geo:
			gi.set_instance_shader_parameter(&"sun", sun)
	if la != car.la or lb != car.lb:
		car.la = la
		car.lb = lb
		for gi: GeometryInstance3D in car.body:
			gi.set_instance_shader_parameter(&"lamp_a", la)
			gi.set_instance_shader_parameter(&"lamp_b", lb)


## Contact shadow of a car: a soft rounded rectangle of its footprint under its pose (MultiMesh instance).
func _add_shadow(car: Car, obj: Dictionary, length: float, alpha: float, lights: float, in_tunnel: bool) -> void:
	var w := float(obj.get("width_m", 1.8))
	var strength := 0.55 if car.cast else 0.72
	strength *= lerpf(1.0, 0.6, clampf(lights, 0.0, 1.0)) if not in_tunnel else 0.75
	strength *= alpha
	if strength <= 0.01:
		return
	var hw := w * 0.5
	var hl := length * 0.5
	var sx := 2.0 * (hw + SHADOW_MARGIN_M)
	var sz := 2.0 * (hl + SHADOW_MARGIN_M)
	var t := car.pose * Transform3D(Basis.from_scale(Vector3(sx, 1.0, sz)), Vector3(0.0, 0.02, 0.0))
	var need := (_shadow_n + 1) * FLOATS_PER_SHADOW
	if _shadow_buf.size() < need:
		_shadow_buf.resize(maxi(need, _shadow_buf.size() * 2))
	var o := _shadow_n * FLOATS_PER_SHADOW
	_put_transform(_shadow_buf, o, t)
	_shadow_buf[o + 12] = strength
	_shadow_buf[o + 13] = hw
	_shadow_buf[o + 14] = hl
	_shadow_buf[o + 15] = SHADOW_MARGIN_M
	_shadow_n += 1


func _commit_shadows() -> void:
	if _shadow_mm.instance_count < _shadow_n:
		_shadow_mm.instance_count = maxi(_shadow_n, maxi(32, _shadow_mm.instance_count * 2))
		_shadow_buf.resize(_shadow_mm.instance_count * FLOATS_PER_SHADOW)
	if _shadow_n > 0:
		if _shadow_buf.size() != _shadow_mm.instance_count * FLOATS_PER_SHADOW:
			_shadow_buf.resize(_shadow_mm.instance_count * FLOATS_PER_SHADOW)
		_shadow_mm.buffer = _shadow_buf
	_shadow_mm.visible_instance_count = _shadow_n


## Flares of a car: every flare point whose glow has strength; position along the lamp's direction, in the pose of
## its unit (articulated: the unit it belongs to).
func _add_flares(car: Car, info: Dictionary, la: Vector4, lb: Vector4, lights: float, alpha: float, light_alpha: float) -> void:
	var pts: Array = info["points"]
	for p: Dictionary in pts:
		var role: String = p["role"]
		var fp := VehiclePose3D.flare_params(role, la, lb, lights)
		if fp.x <= 0.004:
			continue
		var a := light_alpha if (role == "ind_l" or role == "ind_r" or role == "head" or role == "marker") else alpha
		var s := fp.x * a
		if s <= 0.004:
			continue
		var local: Vector3 = (p["pos"] as Vector3) + (p["dir"] as Vector3) * FLARE_OFFSET_M
		var t := car.pose
		if not car.groups.is_empty():
			t = _unit_of(car, local)
		var pos := t * local
		var dir := (t.basis * (p["dir"] as Vector3)).normalized()
		var col: Color = p["color"]
		_put_flare(pos, dir, col, s, fp.y, fp.z, fp.w, float(p["size"]) * 0.5)


## World transform of the articulated unit a model-space point belongs to (the last unit whose pivot lies ahead of
## it), in model coordinates of that unit (pivot offset applied).
func _unit_of(car: Car, local: Vector3) -> Transform3D:
	var best := -1
	for i in car.groups.size():
		var pivot: Vector3 = (car.groups[i] as Array)[1]
		if i == 0 or local.z >= pivot.z:
			best = i
	var g: Array = car.groups[best]
	var node: Node3D = g[0]
	var pivot: Vector3 = g[1]
	return car.pose * node.transform * Transform3D(Basis.IDENTITY, -pivot)


func _put_flare(pos: Vector3, dir: Vector3, col: Color, s: float, k: float, min_px: float, kind: float, lamp_r: float) -> void:
	var need := (_flare_n + 1) * FLOATS_PER_FLARE
	if _flares.size() < need:
		_flares.resize(maxi(need, maxi(64 * FLOATS_PER_FLARE, _flares.size() * 2)))
	var o := _flare_n * FLOATS_PER_FLARE
	# basis: identity, its z column = the lamp's direction (for shaders that want it); origin = the lamp
	_flares[o] = 1.0
	_flares[o + 1] = 0.0
	_flares[o + 2] = dir.x
	_flares[o + 3] = pos.x
	_flares[o + 4] = 0.0
	_flares[o + 5] = 1.0
	_flares[o + 6] = dir.y
	_flares[o + 7] = pos.y
	_flares[o + 8] = 0.0
	_flares[o + 9] = 0.0
	_flares[o + 10] = dir.z
	_flares[o + 11] = pos.z
	_flares[o + 12] = col.r
	_flares[o + 13] = col.g
	_flares[o + 14] = col.b
	_flares[o + 15] = s
	_flares[o + 16] = k
	_flares[o + 17] = min_px
	_flares[o + 18] = kind
	_flares[o + 19] = lamp_r
	_flare_n += 1


static func _put_transform(buf: PackedFloat32Array, o: int, t: Transform3D) -> void:
	buf[o] = t.basis.x.x
	buf[o + 1] = t.basis.y.x
	buf[o + 2] = t.basis.z.x
	buf[o + 3] = t.origin.x
	buf[o + 4] = t.basis.x.y
	buf[o + 5] = t.basis.y.y
	buf[o + 6] = t.basis.z.y
	buf[o + 7] = t.origin.y
	buf[o + 8] = t.basis.x.z
	buf[o + 9] = t.basis.y.z
	buf[o + 10] = t.basis.z.z
	buf[o + 11] = t.origin.z


## Environment the clear coat, metals and glass mirror (vpbr uniforms): the sky of the palette, the road below.
func _set_environment(pal: Dictionary) -> void:
	var top: Color = pal.get("sky_top", Color(0.11, 0.36, 0.79))
	var bottom: Color = pal.get("sky_bottom", Color(0.73, 0.87, 0.96))
	var amb: Color = pal.get("ambient", Color.WHITE)
	var key := Vector4(top.r + top.g * 3.0 + top.b * 7.0, bottom.r + bottom.g * 3.0 + bottom.b * 7.0, amb.r + amb.g * 3.0 + amb.b * 7.0, 0.0)
	if key.is_equal_approx(_env_key):
		return
	_env_key = key
	var fog: Color = pal.get("fog", bottom)
	var horizon := bottom.lerp(fog, 0.35)
	var ground := Color(0.30 * amb.r, 0.31 * amb.g, 0.32 * amb.b)
	var tunnel: Color = Palette.TUNNEL_AMBIENT
	for cls: String in ["vpbr", "glass"]:
		_mats.set_class_parameter(cls, "env_zenith", top)
		_mats.set_class_parameter(cls, "env_horizon", horizon)
		_mats.set_class_parameter(cls, "env_ground", ground)
		_mats.set_class_parameter(cls, "env_tunnel", tunnel * 0.45)


# --- nodes and pool ---------------------------------------------------------------------------------------------------

func _acquire(set_id: String, id: int) -> Car:
	var list: Variant = _free.get(set_id)
	var car: Car
	if list is Array and not (list as Array).is_empty():
		car = (list as Array).pop_back()
	else:
		car = Car.new()
		car.set_id = set_id
		car.info = _set_info(set_id)
		car.root = Node3D.new()
		car.root.name = "car_%s" % set_id.replace("/", "_")
		var world: Variant = _renderer.get("world")
		if world is Node3D:
			(world as Node3D).add_child(car.root)
	car.id = id
	car.la = Vector4(-1, -1, -1, -1)
	car.lb = Vector4(-1, -1, -1, -1)
	car.fade = -1.0
	car.sun = -1.0
	car.lat = 0.0
	car.root.visible = false
	car.shown = false
	return car


func _release(car: Car) -> void:
	_show(car, false)
	var list: Variant = _free.get(car.set_id)
	if not (list is Array):
		list = []
		_free[car.set_id] = list
	if (list as Array).size() < POOL_PER_SET:
		(list as Array).append(car)
	else:
		car.root.queue_free()


func _show(car: Car, on: bool) -> void:
	if car.shown != on:
		car.shown = on
		car.root.visible = on


## Shows level `lod` of a car (built on first use, kept for reuse).
func _set_level(car: Car, lod: String) -> void:
	if car.node != null:
		car.node.visible = false
	var n: Node3D = car.levels.get(lod)
	if n == null:
		if lod == "box":
			n = ModelFactory.build_box(car.set_id, _mats)
		else:
			n = ModelFactory.build(car.set_id, lod, _mats, true)
			if n == null:
				n = ModelFactory.build_box(car.set_id, _mats)     # never a missing car
		if n == null:
			car.node = null
			car.lod = lod
			return
		_builds += 1
		car.root.add_child(n)
		car.levels[lod] = n
	n.visible = true
	car.node = n
	car.lod = lod
	car.geo = ModelFactory.geometry_of(n)
	car.body.clear()
	car.wheels.clear()
	car.groups.clear()
	car.roll_nodes.clear()
	car.caster = null
	var wheel_nodes: Dictionary = {}
	var model: Dictionary = (car.info as Dictionary).get("model", {})
	var entry := ModelDB.lod(model, lod) if not model.is_empty() else {}
	var wheel_parts: Dictionary = {}
	for p: Variant in entry.get("parts", []):
		var pd: Dictionary = p
		if pd.has("wheel"):
			var nm := str(pd.get("node", ""))
			wheel_parts[nm.substr(nm.find("/") + 1) if nm.find("/") >= 0 else nm] = pd
	for wp: Variant in n.get_meta("wheels", []):
		var w := n.get_node_or_null(wp as NodePath) as MeshInstance3D
		if w == null:
			continue
		wheel_nodes[w] = true
		var pd: Dictionary = wheel_parts.get(str(w.name), {})
		var wd: Dictionary = pd.get("wheel", {})
		var yaw := float(pd.get("yaw_deg", 0.0))
		car.wheels.append([w, w.transform, float(wd.get("radius", 0.33)), absf(yaw - 180.0) < 1.0, bool(wd.get("steer", false))])
	for g: Variant in n.get_meta("groups", []):
		var gd: Dictionary = g
		var gn := n.get_node_or_null(gd["path"] as NodePath) as Node3D
		if gn != null:
			car.groups.append([gn, gd["pivot"]])
	for gi: GeometryInstance3D in car.geo:
		if gi.name == "shadow":
			car.caster = gi
		elif not wheel_nodes.has(gi):
			car.body.append(gi)
			if car.id == PLAYER_ID and gi.get_parent() == n:
				car.roll_nodes.append([gi, gi.transform])
	_apply_casting(car)
	# readability of the player car (Arcade brightens its player sprite as well) and a matt coat on the stand-in
	var fill := PLAYER_FILL if car.id == PLAYER_ID else 0.0
	var gloss := BOX_GLOSS if lod == "box" else 1.0
	for gi: GeometryInstance3D in car.geo:
		if fill > 0.0:
			gi.set_instance_shader_parameter(&"fill", fill)
		if gloss < 1.0:
			gi.set_instance_shader_parameter(&"gloss", gloss)
	car.la = Vector4(-1, -1, -1, -1)
	car.lb = Vector4(-1, -1, -1, -1)
	car.fade = -1.0
	car.sun = -1.0


## Shadow casting of the level shown: the model's caster when the quality levels have vehicle casters (else hidden,
## and nothing casts – the contact shadow carries it); a box stand-in casts itself.
func _apply_casting(car: Car) -> void:
	car.cast = _casters
	if car.caster != null:
		car.caster.visible = _casters
		return
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _casters else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for gi: GeometryInstance3D in car.geo:
		gi.cast_shadow = mode


static func _shadow_quad() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.0, -0.5), Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, 0.5)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


# --- data for tests and statistics ----------------------------------------------------------------------------------

## Contract §4.4.5: vehicles [{id, set, model, lod, z, x, yaw_deg, lamps}] (+ fade, sun, pos, shown, box, player; cast =
## the level shown casts shadows, caster = its shadow hull is shown: 1 / 0, -1 without a hull).
func snapshot() -> Dictionary:
	var list: Array = []
	for id: Variant in _cars:
		var car: Car = _cars[id]
		var p := car.pose.origin
		list.append({"id": int(id), "set": car.set_id, "model": str((car.info as Dictionary).get("model_id", "")),
			"lod": car.lod, "z": car.z, "x": car.x, "yaw_deg": rad_to_deg(car.yaw), "dist": car.dist,
			"lamps": {"tail": car.la.x, "brake": car.la.y, "ind_l": car.la.z, "ind_r": car.la.w, "head": car.lb.x,
				"beacon_a": car.lb.z, "beacon_b": car.lb.w},
			"fade": car.fade, "sun": car.sun, "pos": [p.x, p.y, p.z], "shown": car.shown,
			"box": bool((car.info as Dictionary).get("box", false)), "player": int(id) == PLAYER_ID,
			"cast": car.cast, "caster": -1 if car.caster == null else int(car.caster.visible),
			"basis": [car.pose.basis.x, car.pose.basis.y, car.pose.basis.z]})
	return {"vehicles": list, "vehicle_flares": _flare_n}


## The unit nodes of an articulated car of the view (tests): [] for a rigid one or an unknown id.
func debug_units(id: int) -> Array:
	var car: Car = _cars.get(id)
	var out: Array = []
	if car != null:
		for g: Array in car.groups:
			out.append(g[0])
	return out


## The world transform of a car's level node and of its units (tests, pictures): {"pose", "units": [Transform3D]}.
func debug_pose(id: int) -> Dictionary:
	var car: Car = _cars.get(id)
	if car == null:
		return {}
	var units: Array = []
	for g: Array in car.groups:
		units.append(car.pose * (g[0] as Node3D).transform)
	return {"pose": car.pose, "units": units, "lod": car.lod}


func perf() -> Dictionary:
	var pooled := 0
	for k: Variant in _free:
		pooled += (_free[k] as Array).size()
	return {"vehicles": _drawn, "fallback_sets": _fallback_sets.size(), "vehicle_us_avg": float(_us_sum) / maxf(1.0, float(_updates)),
		"vehicle_us_max": _us_max, "vehicle_builds": _builds, "vehicle_pool": pooled, "contact_shadows": _shadow_n}


func _exit_tree() -> void:
	for id: Variant in _cars:
		var car: Car = _cars[id]
		if is_instance_valid(car.root):
			car.root.queue_free()
	for k: Variant in _free:
		for car: Car in _free[k]:
			if is_instance_valid(car.root):
				car.root.queue_free()
	_cars.clear()
	_free.clear()
	if is_instance_valid(_shadow_node):
		_shadow_node.queue_free()
	if _requested:
		ModelDB.release_all(self)
		_requested = false
