extends Node3D
## Layer "vehicles" of the mode "Modern" (contract §6 R3; docs/renderer-modern.md §10): every car of the view –
## traffic, police and the player – as a real 3D model from the model manifest, keyed by the view's vehicle id.
##  * data-driven: a set resolves through ModelDB to a model (any number of levels of detail, articulated units
##    from the manifest "groups") or to its stand-in – Arcade's own picture of that vehicle (VehicleStandIn, R3E:
##    sprite sets as one MultiMesh per sheet, box sets as real boxes with Arcade's face pictures; their sheets are
##    loaded in prepare(), never while driving), and only when the sheet is missing too a box of the set's size,
##    paint and lamps (ModelFactory.build_box) – a new model appears without a code change, a set without one is
##    never missing and never worse than in Arcade;
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
## Owner: R3 (stand-ins: R3E). Docs: docs/renderer-modern.md §10.

const FLARE_OFFSET_M := 0.06        ## a flare sits this far in front of its lamp (along lights[].dir)
const BEHIND_M := 14.0              ## cars whose front is further behind the camera than this are not drawn
const AHEAD_MARGIN_M := 30.0        ## … and those beyond the visibility plus this
const POOL_PER_SET := 6             ## free cars kept per set for reuse
## RINT-B: Godot's Compatibility renderer gives every geometry instance whose material has instance uniforms (vpbr,
## glass, the stand-in shaders) 16 slots of its global shader buffer, and that buffer is only as large as the GPU's
## uniform block (64 KB = 4096 slots on the build VM and on most desktop drivers): about 250 such instances in the whole
## scene. Beyond that Godot refuses an instance ("Too many instances using shader instance variables") and draws it with
## the values of another one. Pooled cars keep their built levels (lod0 alone is 6 instances), so a race with traffic
## ran past it within seconds (measured). The layer keeps the instances of all built levels – active and pooled cars –
## at most at INSTANCE_BUDGET: pooled cars are freed first, then the levels of active cars that are not shown.
const INSTANCE_BUDGET := 128
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
## RINT-B: unlit vehicle lamps at 0.28 of their lit colour (0.5 read as switched on by day – art review B1), the tail
## light of a combined tail/brake lamp (channel 2) at half the lamp (brake stays more than twice as bright); paint
## exposure (art review A1/B8/C2): a soft knee above 0.7 of the brightest channel (slope 0.45) and 8 % desaturation
## instead of a flat 0.9 on every paint – bright paints no longer clip, mid ones keep their value (measured against the
## sprites, docs/renderer-modern.md §13.4); at night the mirrored palette sky at 0.35 and the player's fill at 0.3 of
## their day values (the metallic player car was +44 % against its sprite at 22:00).
const LOOK: Array = [["vpbr", "env_energy", 1.6], ["vpbr", "paint_base", 1.0], ["vpbr", "paint_knee", 0.7],
	["vpbr", "paint_knee_slope", 0.45], ["vpbr", "paint_desat", 0.08], ["vpbr", "flake_strength", 0.6],
	["vpbr", "lamp_off", 0.28], ["vpbr", "tail_level", 0.5], ["vpbr", "env_night", 0.35], ["vpbr", "fill_night", 0.3],
	["glass", "env_energy", 2.2]]
## RINT-B: the far levels of a model (one merged mesh each, no wheel or group nodes) cross-fade over XFADE_S of view
## time with complementary dither masks (vpbr instance uniform xfade) instead of swapping in one frame – the art review
## measured 22–34 % of a car's pixels changing at the 120 m swap. Costs one draw call more per car while it fades.
const XFADE_S := 0.5
const XFADE_LODS: Array[String] = ["lod1", "lod2"]
const STANDIN_SHADER := "vehicle_sprite"   ## assets/shaders/modern/vehicle_sprite.gdshader (through ModernMaterials)
const STANDIN_NEAR_M := 0.3          ## a flat stand-in whose anchor is closer than this is not drawn (Arcade's near plane)
const FLARE_PICTURE_GAP_M := 0.08    ## a lamp glow of a sprite stand-in sits this far in front of its picture

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
	var casters: Array[GeometryInstance3D] = []   ## every shadow caster of the level (one per unit of a box stand-in)
	var disp := PackedFloat32Array([0.0, 0.0, -1.0])   ## sprite stand-in: Arcade's display yaw, its velocity, cell
	var cell := -1                  ## sprite stand-in: cell shown
	var fold := false               ## sprite stand-in: cell folded onto rear and flank
	var pull := 1.0                 ## sprite stand-in: its picture pulled towards the eye by this
	var flare_ref := -1.0           ## sprite stand-in: depth of its picture (its lamp glows go in front of it)
	var batch: VehicleStandIn.SheetBatch   ## sprite stand-in: its sheet's batch
	var yaws := PackedFloat32Array()       ## sprite stand-in: yaw of every cell (degrees)
	var rear_pivot := false                ## sprite stand-in: Arcade warps it (explicit rear pivot)
	var persp := false                     ## sprite stand-in: perspective cells (player)
	var has_beacon := false                ## sprite stand-in: its sheet has beacon layers (police)
	var v_bot := 0.0                       ## sprite stand-in: lowest row of its cell below the anchor (m, negative)
	var mod := Color(-1, -1, -1, -1)   ## box stand-in: modulate set last
	var ovl := Vector4(-1, -1, -1, -1) ## box stand-in: lamp layers set last
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
	var xf_node: Node3D                    ## the level fading out during a cross-fade (null otherwise)
	var xf_lod := ""
	var xf_geo: Array[GeometryInstance3D] = []
	var xf_t0 := 0.0                       ## view time the cross-fade began
	var xf_t := 0.0                        ## its progress, 0..1 (0 without one)

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
var _inst_n := 0                     ## geometry instances of all built levels (active and pooled cars), INSTANCE_BUDGET
var _inst_peak := 0
var _trims := 0                      ## pooled cars and hidden levels freed for the budget
var _fallback_sets: Dictionary = {}
# stand-ins (R3E): Arcade's pictures of the sets without a model
var sprite_db: Object = null         ## the sprite database (null: the autoload SpriteDB); tests may set a fixture
var debug_contact_shadows := true    ## render checks switch the contact shadows off to measure the picture alone
var _db: Object = null
var _standin_tex: Dictionary = {}    ## set id -> sheet texture, loaded in prepare()
var _standin_warned: Dictionary = {}
var _batches: Dictionary = {}        ## set id -> VehicleStandIn.SheetBatch
var _box_mats: Dictionary = {}       ## set id -> ShaderMaterial (box faces)
var _shade := VehicleStandIn.ArcadeShade.new()
var _caster_box: ArrayMesh
var _warp_on := true
var _warp_ratio := 0.06
var _veh_hyst := 0.3
var _veh_max_deg := 30.0
var _pl_lookahead := 10.0
var _pl_k_arcade: Dictionary = {}
var _pl_sprite := PackedFloat32Array([0.0, 0.0, -1.0, 0.0])   ## Arcade's display yaw of the player sprite
var _cam_tr := Transform3D.IDENTITY
var _cam_inv := Transform3D.IDENTITY
var _cam_heading := 0.0
var _standin_drawn := 0
var _standin_loaded_mb := 0.0


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
	# Arcade's cell choice of the stand-ins (RoadRenderer.setup)
	_warp_on = bool(rd.get("vehicle_warp", true))
	_warp_ratio = float(rd.get("vehicle_warp_min_ratio", 0.06))
	_veh_hyst = float(rd.get("vehicle_cell_hysteresis", 0.3))
	_veh_max_deg = float(rd.get("vehicle_yaw_max_deg", 30.0))
	_pl_lookahead = float(rd.get("player_curve_lookahead_m", 10.0))
	_pl_k_arcade = {"curve_gain": float(rd.get("player_curve_gain", 1.0)), "steer_deg": float(rd.get("player_steer_deg", 3.0)),
		"lateral_gain": float(rd.get("player_lateral_gain", 1.0)), "understeer_deg": float(rd.get("player_understeer_deg", 6.0)),
		"view_gain": float(rd.get("player_view_gain", 1.0)), "max_deg": float(rd.get("player_yaw_max_deg", 20.0))}
	var trk: Variant = renderer.get("track")
	_shade.setup(rd, (trk as Track).seg_len if trk is Track else 3.0, float(rd.get("camera_distance_m", 9.0)),
		float(ConfigLoader.lookup(_cfg, "road.streetlight_every_m", 33.0)))
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


## Starts loading the models of every vehicle set of the stage (ctx.sets: traffic/, police/ and player/ sets) and
## loads the sheets of the sets without a model (their stand-ins) – nothing is loaded while driving.
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
	_load_standins()


## The sprite database: `sprite_db` when a test set one, else the autoload SpriteDB (looked up, never named – this
## file must compile where the autoloads do not exist).
func _sprite_db() -> Object:
	if sprite_db != null:
		return sprite_db
	if _db == null:
		var ml := Engine.get_main_loop()
		if ml is SceneTree:
			_db = (ml as SceneTree).root.get_node_or_null(^"SpriteDB")
	return _db


## Loads the sheet of every vehicle set of the stage that has no model (once per stage, in prepare()).
func _load_standins() -> void:
	var db := _sprite_db()
	if db == null:
		return
	for sid: String in _sets:
		if ModelDB.has_model(sid) or _standin_tex.has(sid):
			continue
		if VehicleStandIn.kind_of(sid, db) == "":
			continue
		var tex := VehicleStandIn.sheet_texture(sid, db)
		if tex != null:
			_standin_tex[sid] = tex
			var sz := tex.get_size()
			_standin_loaded_mb += sz.x * sz.y * 1.34 / 1048576.0   # BPTC: 1 byte per pixel, + mipmaps
	_set_cache.clear()


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
## contact shadow; of the stand-ins (R3E) one sprite sheet as a MultiMesh with its hidden casters and one box set.
func warmup_nodes() -> Array:
	var out: Array = []
	var done: Dictionary = {}
	for sid: String in _sets:
		var info := _set_info(sid)
		var sk := str(info.get("standin", ""))
		var key := str(info.get("model_id", "")) if not bool(info.get("box", false)) else "box"
		if sk != "":
			key = sk
		if done.has(key):
			continue
		done[key] = true
		var n: Node3D = null
		if sk == VehicleStandIn.KIND_SPRITE:
			n = _warm_sheet(sid, info)
		elif sk == VehicleStandIn.KIND_BOX:
			n = VehicleStandIn.build_box_node(sid, info["sheet"], _box_mat(sid), (_standin_tex[sid] as Texture2D).get_size(), _mats.material("vpbr"))
			if n != null:
				for gi: GeometryInstance3D in ModelFactory.geometry_of(n):
					gi.visible = true
		else:
			n = ModelFactory.build_box(sid, _mats) if bool(info.get("box", false)) else ModelFactory.build(sid, "", _mats, true)
		if n != null:
			out.append(n)
	return out


## Warm-up node of the sprite stand-ins: one instance of a sheet in a MultiMesh (the instanced variant), on its own
## node – handed over to the renderer, which frees it. (Sprite stand-ins cast no shadow since RINT-B: no caster.)
func _warm_sheet(sid: String, info: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "warm_standin"
	var b := VehicleStandIn.SheetBatch.new(sid, info["sheet"], _sheet_mat(sid, info), root, _caster_mesh(), _mats.material("vpbr"))
	b.casting = false
	b.begin()
	var t := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0))
	b.add(t, Color(1, 1, 1, 1), Vector4(0.0, 1.0, 1.0, 0.0))
	b.commit()
	return root


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
	info["standin"] = ""
	if model.is_empty():
		var kb := ModelFactory.box_kind(set_id, r.get("object", {}))
		lights = ModelFactory.box_lights(r.get("object", {}), str(kb[0]), bool(kb[1]))
		_fallback_sets[set_id] = true
		# Arcade's picture of the set when its sheet was loaded in prepare(); else the painted box (never a load while
		# driving)
		var db := _sprite_db()
		var sheet := VehicleStandIn.sheet_info(set_id, db) if _standin_tex.has(set_id) else {}
		if not sheet.is_empty():
			info["standin"] = str(sheet["kind"])
			info["sheet"] = sheet
			if (info["obj"] as Dictionary).is_empty():
				var o: Vector3 = sheet["obj"]
				info["obj"] = {"width_m": o.x, "length_m": o.y, "height_m": o.z}
		elif db != null and VehicleStandIn.kind_of(set_id, db) != "" and not _standin_warned.has(set_id):
			_standin_warned[set_id] = true
			push_warning("Fahrzeuge: Bild von %s nicht vorbereitet – Ersatzkasten statt Ladens während der Fahrt" % set_id)
	var pts := VehiclePose3D.flare_points(lights)
	var rear_pts: Array = []
	var known := true
	for p: Dictionary in pts:
		p["code"] = _role_code(str(p["role"]))
		known = known and int(p["code"]) >= 0
		# the glows Arcade draws over its picture: rear lamps (they look backwards, model +Z) and beacons
		if str(p["role"]).begins_with("beacon") or (p["dir"] as Vector3).z > 0.0:
			rear_pts.append(p)
	info["points"] = pts
	info["points_rear"] = rear_pts
	info["codes_known"] = known
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
	# stand-ins: the camera of this frame (the renderer placed it before the layers), Arcade's light
	_standin_drawn = 0
	var cam: Variant = _renderer.get("camera")
	if cam is Camera3D:
		_cam_tr = (cam as Camera3D).global_transform if (cam as Camera3D).is_inside_tree() else (cam as Camera3D).transform
		_cam_inv = _cam_tr.affine_inverse()
		_cam_heading = VehicleStandIn.camera_heading(_cam_tr)
	_shade.prepare(view, bool(view.get("camera_in_tunnel", track.is_tunnel_at(cam_z))), track)
	for b: VehicleStandIn.SheetBatch in _batches.values():
		b.begin()
		b.casting = false                  # sprite stand-ins carry their shadow in the picture (RINT-B)
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
	if _inst_n > INSTANCE_BUDGET:
		_trim_instances()
	_inst_peak = maxi(_inst_peak, _inst_n)
	for b: VehicleStandIn.SheetBatch in _batches.values():
		b.commit()
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
	var standin := str(info.get("standin", ""))
	if standin == VehicleStandIn.KIND_SPRITE:
		_update_sprite(car, c, info, is_player, path, track, cam_z, vis, lights, time, sim_dt, length)
		return
	# level of detail (no impostors for vehicles: beyond the last level the last level stays)
	if standin == VehicleStandIn.KIND_BOX:
		if car.lod == "":
			_set_level(car, VehicleStandIn.KIND_BOX)
	elif not bool(info["box"]):
		var names: PackedStringArray = info["lod_names"]
		var i := VehiclePose3D.lod_index(info["lod_limits"], maxf(dist, 0.0), _lod0_k, _lod1_k, car.lod_i)
		if i < 0:
			i = names.size() - 1
		if i >= 0 and i != car.lod_i:
			var old_node := car.node
			var old_geo := car.geo
			var old_lod := car.lod
			var was_shown := car.shown
			_xfade_end(car)
			car.lod_i = i
			_set_level(car, names[i])
			if XFADE_S > 0.0 and was_shown and old_node != null and car.node != null and old_node != car.node \
					and XFADE_LODS.has(old_lod) and XFADE_LODS.has(names[i]):
				_xfade_begin(car, old_node, old_geo, old_lod, time)
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
	if standin == VehicleStandIn.KIND_BOX:
		# Arcade's box faces: modulated like its sprites, tail and brake pictures over them (RoadRenderer._draw_box_item)
		var l_seg := 1.0 if seg_tunnel else lights
		var light_alpha := alpha if lights < 0.3 else minf(1.0, alpha * 1.6)
		var mod := _shade.modulate(z, seg_tunnel, _shade.light_at(z, x, dz), alpha)
		var ovl := Vector4(VehicleStandIn.layer_strength(maxf(float(c.get("tail", 0.0)), l_seg), alpha, light_alpha),
			VehicleStandIn.layer_strength(float(c.get("brake", 0.0)), alpha, light_alpha), 0.0, 0.0)
		_set_box_uniforms(car, Color(mod.r, mod.g, mod.b, snappedf(alpha, 1.0 / 255.0)), ovl)
		car.la = la
		car.lb = lb
	else:
		_set_uniforms(car, alpha, 0.0 if in_tunnel else 1.0, la, lb)
		if car.xf_node != null:
			_xfade_step(car, time, alpha, 0.0 if in_tunnel else 1.0, la, lb)
	# contact shadow and flares
	_add_shadow(car, obj, length, alpha, lights, in_tunnel)
	var l_eff := 1.0 if in_tunnel else lights
	_add_flares(car, info, la, lb, l_eff, alpha, VehiclePose3D.light_alpha(alpha, l_eff))


## The player car while it is not drawn (blinking): its pose terms keep running, so it does not jump back – and the
## visible yaw of its picture, as Arcade's _draw_player keeps updating it while the car blinks.
func _player_pose_only(c: Dictionary, path: RoadPath3D, track: Track, z: float, x: float, length: float, sim_dt: float) -> void:
	_player_terms(c, track, z + length * 0.5, float(c.get("speed", 0.0)) / 3.6, sim_dt)
	var info := _set_info(str(c.get("set", "")))
	if str(info.get("standin", "")) == VehicleStandIn.KIND_SPRITE:
		var sheet: Dictionary = info["sheet"]
		var zc := z + length * 0.5
		_player_sprite_cell(c, sheet, sheet["yaws"], path, track, zc, _cam_inv * path.world(zc, x, 0.0), float(c.get("speed", 0.0)) / 3.6, sim_dt)


## A car of a sprite set without a model (R3E): Arcade's picture at its pose – one instance in its sheet's MultiMesh.
## The pose (contact shadow, hidden caster, flares) is computed like a model's; the cell exactly like Arcade's, from
## the camera of this frame: traffic and police by RoadRenderer._vehicle_cell (rear anchor, folded onto rear and flank
## where Arcade warps), the player by RoadRenderer._draw_player (centre anchor, body roll about it).
func _update_sprite(car: Car, c: Dictionary, info: Dictionary, is_player: bool, path: RoadPath3D, track: Track, cam_z: float,
		vis: float, lights: float, time: float, sim_dt: float, length: float) -> void:
	var sheet: Dictionary = info["sheet"]
	var z := car.z
	var x := car.x
	var rear := path.world(z, x, 0.0)
	var front := path.world(z + length, x, 0.0)
	var speed_mps := float(c.get("speed", 0.0)) / 3.6
	if is_player:
		_player_terms(c, track, z + length * 0.5, speed_mps, sim_dt)
		car.yaw = _pl_yaw
	else:
		if sim_dt > 0.0 and time > car.last_t + 0.0005:
			car.lat = (x - car.last_x) / (time - car.last_t)
			car.last_x = x
			car.last_t = time
		var r := VehiclePose.damp(car.yaw, car.yaw_v, VehiclePose.own_heading(car.lat, speed_mps), sim_dt, _veh_tau)
		car.yaw = r.x
		car.yaw_v = r.y
	car.pose = VehiclePose3D.chord_pose(rear, front, car.yaw, 0.0)
	var dz := z - cam_z
	var seg_tunnel := track.is_tunnel_at(z)
	var in_tunnel := track.is_tunnel_at(z + length * 0.5)
	var alpha := VehiclePose3D.fade(dz, vis, _fog_frac, seg_tunnel, _tunnel_fog_m)
	var la := VehiclePose3D.lamp_a(c, in_tunnel)
	var lb := VehiclePose3D.lamp_b(c, in_tunnel)
	car.la = la
	car.lb = lb
	car.fade = alpha
	car.sun = 0.0 if in_tunnel else 1.0
	if alpha <= 0.02:
		_show(car, false)
		return
	# Arcade's light layers (RoadRenderer._draw_car / _draw_player): tail with the lights (always in a tunnel), brake,
	# beacon; drawn with light_alpha over the body
	var l_seg := 1.0 if seg_tunnel else lights
	var light_alpha := alpha if lights < 0.3 else minf(1.0, alpha * 1.6)
	var tail := maxf(float(c.get("tail", 0.0)), l_seg)
	var brake := float(c.get("brake", 0.0))
	var tail_k := 0.0 if tail <= 0.05 else minf(1.0, tail * light_alpha / maxf(alpha, 0.001))
	var brake_k := 0.0 if brake <= 0.05 else minf(1.0, brake * light_alpha / maxf(alpha, 0.001))
	var light_v := _shade.light_at(z, x, dz) if _shade.lit else 0.0
	var mod := _shade.modulate(z, seg_tunnel, light_v, alpha)
	var yaws := car.yaws
	var anchor_t: Transform3D
	var cu: Vector4
	var depth: float
	if car.persp:
		# the player car: anchor = the ground under the centre of the car, cell from Arcade's visible yaw
		var zc := z + length * 0.5
		var centre := path.world(zc, x, 0.0)
		var vc := _cam_inv * centre
		depth = -vc.z
		car.cell = _player_sprite_cell(c, sheet, yaws, path, track, zc, vc, speed_mps, sim_dt)
		car.fold = false
		car.pull = VehicleStandIn.persp_pull(vc.y, car.v_bot)
		anchor_t = Transform3D(car.pose.basis, centre)
		cu = Vector4(float(car.cell), tail_k, brake_k, deg_to_rad(_pl_roll))
		mod = VehicleStandIn.ArcadeShade.player_modulate(mod)
	else:
		# traffic and police: anchor = the rear centre, cell from Arcade's display yaw (contract formula), folded near
		# the camera like Arcade's flank warp
		var vin := VehicleStandIn.view_inputs_car(_cam_inv, rear, front)
		depth = vin.x
		var forced := int((sheet["cols"] as Dictionary).get(str(c["angle"]), 0)) if c.has("angle") else -1
		car.cell = VehicleStandIn.traffic_cell(car.disp, yaws, vin, VehiclePose.own_heading(car.lat, speed_mps), length, _veh_max_deg,
			sim_dt, _veh_tau, _veh_hyst, forced)
		var psi_deg := yaws[car.cell] if car.cell >= 0 and car.cell < yaws.size() else 0.0
		# VehicleStandIn.folds(), inline (RoadRenderer._car_warp)
		car.fold = _warp_on and car.rear_pivot and absf(psi_deg) >= VehicleStandIn.FOLD_MIN_DEG \
			and (depth <= 0.05 or length / depth >= _warp_ratio)
		if not car.fold and depth <= STANDIN_NEAR_M:
			_show(car, false)
			return
		# not pulled: the picture keeps the depth of the car; the shader lays the rows below its ground line onto the road
		car.pull = 1.0
		var bcode := 0.0
		if car.has_beacon:
			var beacon := str(c.get("beacon", ""))
			bcode = 1.0 if beacon == "a" else (2.0 if beacon == "b" else 0.0)
		anchor_t = Transform3D(car.pose.basis, rear)
		cu = Vector4(float(car.cell), tail_k, brake_k, bcode + (4.0 if car.fold else 0.0))
	car.shown = true                 # no node: an instance of the sheet's MultiMesh
	_drawn += 1
	_standin_drawn += 1
	car.flare_ref = depth * car.pull
	mod.a = snappedf(alpha, 1.0 / 255.0)
	car.batch.add(anchor_t, mod, cu, car.fold)
	# no sun shadow and no contact shadow (lead decision, RINT-B): Arcade's picture carries its shadow baked in – the
	# rows below its ground line lie on the road – and a hidden caster or a contact shadow laid a second dark patch
	# beside or under it. Textured boxes (trucks, buses) cast like models (_update_box).
	car.cast = false
	var l_eff := 1.0 if in_tunnel else lights
	_add_flares(car, info, la, lb, l_eff, alpha, VehiclePose3D.light_alpha(alpha, l_eff))


## Cell of the player's picture (RoadRenderer._draw_player: an explicit "angle" without steering wins, else Arcade's
## visible yaw). vc = the ground under the car centre in camera space.
func _player_sprite_cell(c: Dictionary, sheet: Dictionary, yaws: PackedFloat32Array, path: RoadPath3D, track: Track, zc: float,
		vc: Vector3, speed_mps: float, sim_dt: float) -> int:
	if c.has("angle") and not c.has("steer"):
		return int((sheet["cols"] as Dictionary).get(str(c["angle"]), 0))
	var heading := wrapf(path.heading_at(zc + _pl_lookahead) - _cam_heading, -PI, PI)
	return VehicleStandIn.player_cell(_pl_sprite, yaws, heading, float(c.get("steer", 0.0)), float(c.get("lat_speed", 0.0)),
		speed_mps, float(c.get("understeer", 0.0)), track.curve_at(zc), atan2(vc.x, maxf(-vc.z, 0.3)), _pl_k_arcade, sim_dt,
		_pl_tau, _veh_hyst)


## The batch of a sprite sheet (created on first use: its material, MultiMesh and caster MultiMesh).
func _batch(set_id: String, info: Dictionary) -> VehicleStandIn.SheetBatch:
	var b: VehicleStandIn.SheetBatch = _batches.get(set_id)
	if b != null:
		return b
	var world: Node3D = _renderer.get("world")
	b = VehicleStandIn.SheetBatch.new(set_id, info["sheet"], _sheet_mat(set_id, info), world, _caster_mesh(), _mats.material("vpbr"))
	b.casting = false
	_batches[set_id] = b
	return b


func _sheet_mat(set_id: String, info: Dictionary) -> ShaderMaterial:
	return VehicleStandIn.sheet_material(_mats.shader(STANDIN_SHADER), info["sheet"], _standin_tex.get(set_id))


## Material of the faces of a box set (one per sheet).
func _box_mat(set_id: String) -> ShaderMaterial:
	var m: ShaderMaterial = _box_mats.get(set_id)
	if m == null:
		var info := _set_info(set_id)
		m = VehicleStandIn.sheet_material(_mats.shader(STANDIN_SHADER), info["sheet"], _standin_tex.get(set_id))
		_box_mats[set_id] = m
	return m


## Mesh of the hidden casters of the sprite stand-ins: a box of unit size, scaled per car.
func _caster_mesh() -> ArrayMesh:
	if _caster_box == null:
		_caster_box = VehicleStandIn.unit_box()
	return _caster_box


## Instance uniforms of a box stand-in (only when they change): modulate (a = fade) and the lamp layers.
func _set_box_uniforms(car: Car, mod: Color, ovl: Vector4) -> void:
	if not mod.is_equal_approx(car.mod):
		car.mod = mod
		car.fade = mod.a
		for gi: GeometryInstance3D in car.body:
			gi.set_instance_shader_parameter(&"modulate", mod)
	if not ovl.is_equal_approx(car.ovl):
		car.ovl = ovl
		for gi: GeometryInstance3D in car.body:
			gi.set_instance_shader_parameter(&"ovl", ovl)


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
	if not debug_contact_shadows:
		return
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


## Lamp level that decides whether a flare point glows at all (before the full VehiclePose3D.flare_params): the
## point's role code of _role_code() against the lamp uniforms; 0 = dark.
static func _lamp_level(code: int, la: Vector4, lb: Vector4, lights: float) -> float:
	match code:
		0:
			return la.x * lights + la.y
		1, 8:
			return la.x * lights
		2:
			return la.y
		3:
			return la.z
		4:
			return la.w
		5:
			return lb.z
		6:
			return lb.w
		7:
			return lb.x * lights
	return 1.0


static func _role_code(role: String) -> int:
	return ["rear", "tail", "brake", "ind_l", "ind_r", "beacon_a", "beacon_b", "head", "marker"].find(role)


## Flares of a car: every flare point whose glow has strength; position along the lamp's direction, in the pose of
## its unit (articulated: the unit it belongs to). A sprite stand-in only has the points Arcade draws a glow for (its
## rear lamps and beacons: info "points_rear").
func _add_flares(car: Car, info: Dictionary, la: Vector4, lb: Vector4, lights: float, alpha: float, light_alpha: float) -> void:
	# nothing switched on (most cars by day): every lamp of a known role is dark (_lamp_level 0) – no loop
	if la == Vector4.ZERO and lb == Vector4.ZERO and bool(info.get("codes_known", false)):
		return
	var pts: Array = info["points_rear"] if car.flare_ref > 0.0 else info["points"]
	for p: Dictionary in pts:
		if _lamp_level(int(p["code"]), la, lb, lights) <= 0.0:
			continue          # dark: no need for the full glow law
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
		var k := fp.y
		var lamp_r := float(p["size"]) * 0.5
		if car.flare_ref > 0.0:
			# a sprite stand-in is a picture at the depth flare_ref: Arcade draws the glows of its rear lamps and
			# beacons over it and none of lamps that look away (head lamps, front indicators – the picture has no
			# body to hide them, its glass may be clear). A glow that lies behind the picture goes in front of it
			# along the ray to the eye, its radius factors scaled so it keeps its size on the screen.
			var to_eye := _cam_tr.origin - pos
			if not role.begins_with("beacon") and dir.dot(to_eye) <= 0.0:
				continue
			var v := _cam_inv * pos
			var lim := car.flare_ref - FLARE_PICTURE_GAP_M
			if -v.z > lim and lim > 0.05:
				var kk := lim / -v.z
				pos = _cam_tr * (v * kk)
				k *= kk
				lamp_r *= kk
		_put_flare(pos, dir, col, s, k, fp.z, fp.w, lamp_r)


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
		if str((car.info as Dictionary).get("standin", "")) != VehicleStandIn.KIND_SPRITE:
			car.root = Node3D.new()
			car.root.name = "car_%s" % set_id.replace("/", "_")
			var world: Variant = _renderer.get("world")
			if world is Node3D:
				(world as Node3D).add_child(car.root)
		else:
			# a sprite stand-in has no node of its own: it is an instance of its sheet's MultiMesh
			var sheet: Dictionary = (car.info as Dictionary)["sheet"]
			car.batch = _batch(set_id, car.info)
			car.yaws = sheet["yaws"]
			car.rear_pivot = bool(sheet["rear"])
			car.persp = bool(sheet["persp"])
			car.has_beacon = (sheet["rows"] as Dictionary).has("beacon_a") or (sheet["rows"] as Dictionary).has("beacon_b")
			car.v_bot = ((sheet["anchor"] as Vector2).y - 1.0) * (sheet["size_m"] as Vector2).y
	car.id = id
	car.la = Vector4(-1, -1, -1, -1)
	car.lb = Vector4(-1, -1, -1, -1)
	car.mod = Color(-1, -1, -1, -1)
	car.ovl = Vector4(-1, -1, -1, -1)
	car.fade = -1.0
	car.sun = -1.0
	car.lat = 0.0
	car.disp = PackedFloat32Array([0.0, 0.0, -1.0])
	car.cell = -1
	car.fold = false
	car.pull = 1.0
	car.flare_ref = -1.0
	if car.root != null:
		car.root.visible = false
	car.shown = false
	return car


func _release(car: Car) -> void:
	_xfade_end(car)
	_show(car, false)
	var list: Variant = _free.get(car.set_id)
	if not (list is Array):
		list = []
		_free[car.set_id] = list
	if (list as Array).size() < POOL_PER_SET:
		(list as Array).append(car)
	else:
		_drop(car)


## Frees a car that is in no list any more (its root with every built level) and takes its instances off the count.
func _drop(car: Car) -> void:
	for lod: Variant in car.levels:
		var n: Variant = car.levels[lod]
		if n is Node3D and is_instance_valid(n):
			_inst_n -= ModelFactory.geometry_of(n as Node3D).size()
	car.levels.clear()
	car.node = null
	car.geo = []
	if car.root != null and is_instance_valid(car.root):
		car.root.queue_free()
	car.root = null


## Geometry instances of every built level of the active and pooled cars, counted from the nodes (tests: equals
## perf().vehicle_instances, the count the budget keeps).
func debug_level_instances() -> int:
	var n := 0
	var all: Array = _cars.values()
	for k: Variant in _free:
		all.append_array(_free[k] as Array)
	for car: Car in all:
		for lod: Variant in car.levels:
			var node: Variant = car.levels[lod]
			if node is Node3D and is_instance_valid(node) and not (node as Node3D).is_queued_for_deletion():
				n += ModelFactory.geometry_of(node as Node3D).size()
	return n


## Keeps the instances of the built levels within INSTANCE_BUDGET: pooled cars first (from the fullest pool), then the
## levels of active cars that are neither shown nor fading out. A freed level is built again when it is needed.
func _trim_instances() -> void:
	while _inst_n > INSTANCE_BUDGET:
		var fullest: Array = []
		for k: Variant in _free:
			var l: Array = _free[k]
			if l.size() > fullest.size():
				fullest = l
		if fullest.is_empty():
			break
		_drop(fullest.pop_back() as Car)
		_trims += 1
	if _inst_n <= INSTANCE_BUDGET:
		return
	for id: Variant in _cars:
		var car: Car = _cars[id]
		for lod: Variant in car.levels.keys():
			var n: Variant = car.levels[lod]
			if not (n is Node3D) or not is_instance_valid(n) or n == car.node or n == car.xf_node:
				continue
			_inst_n -= ModelFactory.geometry_of(n as Node3D).size()
			car.levels.erase(lod)
			(n as Node3D).queue_free()
			_trims += 1
			if _inst_n <= INSTANCE_BUDGET:
				return


func _show(car: Car, on: bool) -> void:
	if car.shown != on:
		car.shown = on
		if car.root != null:
			car.root.visible = on


## Starts the cross-fade from the level just left (old_node) to the one _set_level() just showed: the old level stays
## visible and dithers out while the new one dithers in (vpbr xfade); its shadow hull is hidden (one caster).
func _xfade_begin(car: Car, old_node: Node3D, old_geo: Array[GeometryInstance3D], old_lod: String, time: float) -> void:
	old_node.visible = true
	car.xf_node = old_node
	car.xf_lod = old_lod
	car.xf_geo = old_geo
	car.xf_t0 = time
	car.xf_t = 0.0
	for gi: GeometryInstance3D in old_geo:
		if gi.name == "shadow":
			gi.visible = false
		gi.set_instance_shader_parameter(&"xfade", -0.002)
	for gi: GeometryInstance3D in car.geo:
		gi.set_instance_shader_parameter(&"xfade", 0.002)


## One frame of a cross-fade: progress by view time (paused game: it holds), the old level follows the new one's fade,
## sun mask and lamps; done after XFADE_S.
func _xfade_step(car: Car, time: float, alpha: float, sun: float, la: Vector4, lb: Vector4) -> void:
	var t := (time - car.xf_t0) / XFADE_S
	if t >= 1.0 or t < 0.0:
		_xfade_end(car)
		return
	t = maxf(t, 0.002)
	car.xf_t = t
	var a := snappedf(alpha, 1.0 / 255.0)
	for gi: GeometryInstance3D in car.geo:
		gi.set_instance_shader_parameter(&"xfade", t)
	for gi: GeometryInstance3D in car.xf_geo:
		gi.set_instance_shader_parameter(&"xfade", -t)
		gi.set_instance_shader_parameter(&"fade", a)
		gi.set_instance_shader_parameter(&"sun", sun)
		gi.set_instance_shader_parameter(&"lamp_a", la)
		gi.set_instance_shader_parameter(&"lamp_b", lb)


## Ends a cross-fade (finished, interrupted by another switch, or the car released): the old level hides, both drop
## their dither mask.
func _xfade_end(car: Car) -> void:
	if car.xf_node == null:
		return
	if is_instance_valid(car.xf_node) and car.xf_node != car.node:
		car.xf_node.visible = false
	for gi: GeometryInstance3D in car.xf_geo:
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter(&"xfade", 0.0)
	for gi: GeometryInstance3D in car.geo:
		gi.set_instance_shader_parameter(&"xfade", 0.0)
	car.xf_node = null
	car.xf_lod = ""
	car.xf_geo = []
	car.xf_t = 0.0


## Shows level `lod` of a car (built on first use, kept for reuse).
func _set_level(car: Car, lod: String) -> void:
	if car.node != null:
		car.node.visible = false
	var n: Node3D = car.levels.get(lod)
	if n == null:
		if lod == "box":
			n = ModelFactory.build_box(car.set_id, _mats)
		elif lod == VehicleStandIn.KIND_BOX:
			var info: Dictionary = car.info
			var tex: Texture2D = _standin_tex.get(car.set_id)
			n = VehicleStandIn.build_box_node(car.set_id, info["sheet"], _box_mat(car.set_id), tex.get_size() if tex != null else Vector2.ONE,
				_mats.material("vpbr"))
			if n == null:
				n = ModelFactory.build_box(car.set_id, _mats)     # never a missing car
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
		_inst_n += ModelFactory.geometry_of(n).size()
	n.visible = true
	car.node = n
	car.lod = lod
	car.geo = ModelFactory.geometry_of(n)
	car.body.clear()
	car.wheels.clear()
	car.groups.clear()
	car.roll_nodes.clear()
	car.caster = null
	car.casters.clear()
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
			car.casters.append(gi)
		elif not wheel_nodes.has(gi):
			car.body.append(gi)
			if car.id == PLAYER_ID and gi.get_parent() == n:
				car.roll_nodes.append([gi, gi.transform])
	_apply_casting(car)
	# readability of the player car (Arcade brightens its player sprite as well) and a matt coat on the stand-in
	var fill := PLAYER_FILL if car.id == PLAYER_ID and lod != VehicleStandIn.KIND_BOX else 0.0
	var gloss := BOX_GLOSS if lod == "box" else 1.0
	for gi: GeometryInstance3D in car.geo:
		if fill > 0.0:
			gi.set_instance_shader_parameter(&"fill", fill)
		if gloss < 1.0:
			gi.set_instance_shader_parameter(&"gloss", gloss)
	car.la = Vector4(-1, -1, -1, -1)
	car.lb = Vector4(-1, -1, -1, -1)
	car.mod = Color(-1, -1, -1, -1)
	car.ovl = Vector4(-1, -1, -1, -1)
	car.fade = -1.0
	car.sun = -1.0


## Shadow casting of the level shown: the model's caster when the quality levels have vehicle casters (else hidden,
## and nothing casts – the contact shadow carries it); the painted box casts itself, Arcade's box faces never (their
## hidden casters, one per unit, do).
func _apply_casting(car: Car) -> void:
	car.cast = _casters
	if not car.casters.is_empty():
		for gi: GeometryInstance3D in car.casters:
			gi.visible = _casters
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
		var ci: Dictionary = car.info
		var sk := str(ci.get("standin", ""))
		# every stand-in reports the manifest's fallback level "box"; which picture it shows is "standin": "sprite"
		# (Arcade's sprite), "boxtex" (Arcade's box faces) or "painted" (the painted box, no sheet)
		if bool(ci.get("box", false)) and sk == "":
			sk = "painted"
		list.append({"id": int(id), "set": car.set_id, "model": str(ci.get("model_id", "")),
			"lod": "box" if bool(ci.get("box", false)) else car.lod, "z": car.z, "x": car.x, "yaw_deg": rad_to_deg(car.yaw), "dist": car.dist,
			"lamps": {"tail": car.la.x, "brake": car.la.y, "ind_l": car.la.z, "ind_r": car.la.w, "head": car.lb.x,
				"beacon_a": car.lb.z, "beacon_b": car.lb.w},
			"fade": car.fade, "sun": car.sun, "pos": [p.x, p.y, p.z], "shown": car.shown,
			"box": bool((car.info as Dictionary).get("box", false)), "player": int(id) == PLAYER_ID,
			"cast": car.cast, "caster": -1 if car.caster == null else int(car.caster.visible),
			"basis": [car.pose.basis.x, car.pose.basis.y, car.pose.basis.z],
			"standin": sk, "cell": car.cell, "fold": car.fold, "pull": car.pull, "xfade": snappedf(car.xf_t, 0.001),
			"xf_lod": car.xf_lod})
	return {"vehicles": list, "vehicle_flares": _flare_n}


## The stand-ins of the stage (tests): {set id: kind} of every vehicle set without a model whose sheet was loaded,
## and the instances of every sprite sheet drawn last frame {set id: count}.
func standin_state() -> Dictionary:
	var kinds := {}
	for sid: String in _standin_tex:
		kinds[sid] = VehicleStandIn.kind_of(sid, _sprite_db())
	var drawn := {}
	for sid: String in _batches:
		drawn[sid] = (_batches[sid] as VehicleStandIn.SheetBatch).n
	return {"kinds": kinds, "drawn": drawn, "sheets_mb": _standin_loaded_mb}


## The sheet batch of a set (tests, pictures): null when none was made.
func debug_batch(set_id: String) -> Object:
	return _batches.get(set_id)


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
		"vehicle_us_max": _us_max, "vehicle_builds": _builds, "vehicle_pool": pooled, "contact_shadows": _shadow_n,
		"vehicle_instances": _inst_n, "vehicle_instances_peak": _inst_peak, "vehicle_trims": _trims,
		"standin_cars": _standin_drawn, "standin_sheets": _standin_tex.size(), "standin_sheets_mb": _standin_loaded_mb}


func _exit_tree() -> void:
	for id: Variant in _cars:
		var car: Car = _cars[id]
		if car.root != null and is_instance_valid(car.root):
			car.root.queue_free()
	for k: Variant in _free:
		for car: Car in _free[k]:
			if car.root != null and is_instance_valid(car.root):
				car.root.queue_free()
	for b: VehicleStandIn.SheetBatch in _batches.values():
		b.free_nodes()
	_batches.clear()
	_box_mats.clear()
	_standin_tex.clear()
	_cars.clear()
	_free.clear()
	_inst_n = 0
	if is_instance_valid(_shadow_node):
		_shadow_node.queue_free()
	if _requested:
		ModelDB.release_all(self)
		_requested = false
