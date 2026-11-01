class_name RoadRenderer
extends Node2D
## Pseudo-3D road renderer (Node2D with _draw, design document "Darstellung und Technik").
##
## Per frame: (1) project one point per segment start from the camera forward (curves accumulate a
## lateral offset, hills come from the segment heights); (2) merge far segments that are thinner than
## render.lod_merge_px into one slice (anti-aliasing + speed) and mark ground hidden behind crests;
## (3) draw sky and background (RaceBackdrop); (4) draw the slices back to front (painter's
## algorithm): ground (grass bands, shoulders, asphalt, markings), structures (guardrails,
## delineators, tunnel walls/ceiling/lamps, canopies), then the sprites of the slice (props, signs,
## cars) sorted by depth, then tunnel portal faces; (5) weather particles, overlays, additive glows.
## Hills hide road and traffic behind crests automatically because nearer ground overdraws them.
## Coloured geometry is batched into few triangle-array commands (GeoBatch).
## Night: per-vertex lighting of the near ground (player headlight cone, traffic headlights, street
## lamps, canopy lights); signs and markings are retro-reflective.
## Vehicles (docs/fahrzeug-darstellung.md, docs/renn-modul.md §8): ortho sprites rotated about the rear
## (traffic, police) get their display yaw from the contract formula with the vehicle length, smoothed per
## vehicle id with cell hysteresis (VehiclePose); trucks/buses with render "box" are textured boxes that
## follow the road slice by slice (BoxVehicle) and are drawn in painter's order with the scene slices;
## the player car is a perspective sprite (anchor = projected ground point of its centre) with a smoothed
## visible yaw and body roll; old ortho player sets keep their rear anchor.
##
## Individual cities (docs/staedte.md): water beside the deck on bridges (quay walls / embankments at the banks,
## sky reflection, glints, city lights at night), railings per bridge type, truss girders and portals,
## pylons with cable fans, landmarks visible far beyond the draw range (fading in with the haze), skyline
## silhouettes in the panorama (RaceBackdrop), fences/hedges of the city scenery, per-city background.
##
## Input: render(view) once per frame (see ARCHITECTURE.md §Renderer-View). Extra view keys used
## here: length (player/cars), countdown, chase01, radar_flash01, camera_in_tunnel; per car id (pose
## smoothing), speed; player steer, lat_speed, push_speed, understeer (visible yaw and roll).
## Owner: race module.

const LIGHT_COL := Color(1.0, 0.93, 0.8)
const LAMP_COL := Color(1.0, 0.82, 0.55)
const TILE := Color("d9d3c2")
const WALL := Color("75716a")
const HAUNCH := Color("57544e")
const CEILING := Color("3e3b35")
const CONCRETE := Color("b9b5aa")
const ROCK := Color("7d7466")
const QUAY := {"canal": Color("7a5648"), "causeway": Color("a9a395"), "river": Color("9a948a"), "stone_arch": Color("a8a090"),
	"truss_arch": Color("8f8b84"), "cable_stayed": Color("a3a29c")}
const RAIL := {"canal": Color("2c3430"), "causeway": Color("c9c6bd"), "river": Color("6d767d"), "stone_arch": Color("d6ccb6"),
	"truss_arch": Color("4f6b55"), "cable_stayed": Color("c4c8cc")}
const SKY_OFFSETS: Array[float] = [0.2, -0.34, 0.44, -0.12, 0.31, -0.48]   ## skyline-only silhouettes (rad)
const STATS_N := 600
# indices of the cached sprite metadata (_spinfo)
const SI_TEX := 0
const SI_PPM := 1
const SI_ANCHOR := 2
const SI_CELL := 3
const SI_COLS := 4         ## {angle name: angle index}
const SI_ROWS := 5         ## {layer: row}
const SI_HALFW := 6
const SI_EXTENT := 7
const SI_MIRROR := 8
const SI_YAWS := 9         ## PackedFloat32Array, degrees per angle index
const SI_GRID := 10        ## cells per sheet row
const SI_NANG := 11        ## number of angles
const SI_PERSP := 12       ## perspective set (player)
const SI_SS := 13          ## supersample of a perspective set
const SI_CAMD := 14        ## camera distance_m of a perspective set
const SI_BOX := 15         ## render: box
const SI_PARTS := 16
const SI_LIGHTS := 17
const SI_TEXSIZE := 18
const SI_OBJ := 19         ## object size (width, length, height)
const SI_REAR := 20        ## explicit rear-pivot ortho sprite (traffic, police): perspective flank warp
const SI_ELEV := 21        ## elevation of the ortho render camera (radians)
const NO_ID := -1000000

var track: Track
var proj: RoadProjection
var cfg: Dictionary = {}
var scenery_db: Dictionary = {}
var view: Dictionary = {}
var batch := GeoBatch.new()
var backdrop := RaceBackdrop.new()
var signs := SignPainter.new()
var show_stats := false

# cached configuration
var _seg_len := 3.0
var _lw := 3.75
var _sh := 2.5
var _k_curve := 0.075
var _fog_start_frac := 0.45
var _edge_line := 0.3
var _lane_line := 0.15
var _grass_band := 4
var _road_band := 2
var _dash := {"autobahn": Vector2i(2, 4), "landstrasse": Vector2i(2, 4), "city": Vector2i(1, 2)}
var _merge_px := 1.5
var _merge_from := 45.0
var _max_merge := 24
var _detail_m := 260.0
var _t_wall_h := 4.2
var _t_ceil_h := 6.2
var _t_haunch := 1.8
var _t_lamp_every := 12.0
var _t_fog_m := 260.0
var _t_peek_m := 45.0
var _delin_every := 50.0
var _hl_range := 80.0
var _hl_int := 0.95
var _guard_post_every := 2
var _crosswalk_every := 330.0
var _prefer_proc := false              ## draw pumps/station/booths/radar procedurally (placeholder sprites)
var _curve_r1 := 120.0                 ## road.curve_radius_at_1_m
# vehicles v2 (render.vehicle_*, render.box_*, render.player_*)
var _veh_tau := 0.12
var _veh_hyst := 0.3
var _veh_max_deg := 30.0
var _veh_warp := true                  ## render.vehicle_warp: perspective flank warp of near ortho cars
var _veh_warp_ratio := 0.06            ## render.vehicle_warp_min_ratio: warp when length / rear depth >= this
var _pl_k := {}
var _pl_lookahead := 10.0
var _pl_tau := 0.15
var _roll_per := 0.22
var _roll_max := 2.5
var _roll_tau := 0.2
var _box := BoxVehicle.new()
# individual cities (render.landmark_*, render.skyline_distance_m)
var _lm_far := 1900.0                  ## landmarks are drawn up to this depth (beyond the draw range)
var _lm_range_k := 2.0                 ## landmark visibility = visibility_m × this (haze), capped by _lm_far
var _sky_dist := 1800.0                ## virtual distance of the panorama silhouettes (size)
var _sky_anchor: Dictionary = {}       ## skyline index -> panorama angle (rad), fixed when first seen
var _bg_cache: Dictionary = {}         ## scenery id -> background with the city overrides
var _water_cache: Dictionary = {}      ## bridge index -> water colour
var _col_cache: Dictionary = {}        ## colour string -> Color
var _lm_amb := Color.WHITE             ## landmark shading of the current draw call (procedural landmarks)
var _lm_haze := 0.0
var _lm_alpha := 1.0

# per-frame projected rows (k = 0 is the segment start at or behind the camera)
var _n := 0
var _base := 0
var _dz := PackedFloat32Array()
var _zw := PackedFloat32Array()
var _xw := PackedFloat32Array()
var _yw := PackedFloat32Array()
var _sx := PackedFloat32Array()
var _sy := PackedFloat32Array()
var _ss := PackedFloat32Array()
var _clip := PackedFloat32Array()
var _ft_out := PackedFloat32Array()
var _ft_tun := PackedFloat32Array()
var _segs: Array[TrackSegment] = []
var _sl_a := PackedInt32Array()
var _sl_b := PackedInt32Array()
var _inv := PackedByteArray()           ## 1 = ground of segment k is back-facing or hidden behind a crest
var _sp_cache: Dictionary = {}          ## sprite set id -> [texture, px per m, anchor, cell, angle cols, layer rows] or []
var _cam_y := 0.0
var _vis := 900.0
var _fog_start := 400.0
var _time := 0.0
var _last_time := -1.0
var _cam_in_tunnel := false

# palette context
var _pal_out: Dictionary = {}
var _pal_tun: Dictionary = {}
var _amb_out := Color.WHITE
var _amb_tun := Color.WHITE
var _fog_outc := Color.WHITE
var _fog_tunc := Color.BLACK
var _amb := Color.WHITE
var _fogc := Color.WHITE
var _ftx := PackedFloat32Array()
var _in_tun_ctx := false
var _lights := 0.0
var _wet := 0.0
var _snow := 0.0

# lighting (night)
var _lit := false
var _lit_rows := 0
var _hl_z := 0.0
var _hl_x := 0.0
var _hl_i := 0.0
var _ls_z := PackedFloat32Array()
var _ls_x := PackedFloat32Array()
var _ls_r := PackedFloat32Array()
var _ls_i := PackedFloat32Array()
var _ls_kind := PackedInt32Array()       ## 0 = pool, 1 = forward cone (car headlights)
# per-row light lists (rows 0.._lit_rows-1): offsets into the flat arrays below
var _rl_off := PackedInt32Array()
var _rl_x := PackedFloat32Array()
var _rl_w := PackedFloat32Array()       ## cone: lateral half width; pool: radius²
var _rl_a := PackedFloat32Array()       ## cone: intensity * along; pool: intensity
var _rl_b := PackedFloat32Array()       ## pool: 1 - dz² / r²
var _rl_kind := PackedByteArray()       ## 0 = cone, 1 = pool

# glows (additive layer)
var _glow_ci: RID
var _glow_mat: CanvasItemMaterial
var _glow_tex: GradientTexture2D
var _gp := PackedVector2Array()
var _gr := PackedFloat32Array()
var _gc := PackedColorArray()

# vehicle poses: id -> PackedFloat64Array [yaw (rad), yaw velocity, cell, last x, last time, lateral m/s, frame]
var _poses: Dictionary = {}
var _pose_frame := 0
var _pose_dt := 0.0
var _pose_last_t := -1.0
# player pose
var _pl_yaw := 0.0
var _pl_yaw_v := 0.0
var _pl_roll := 0.0
var _pl_roll_v := 0.0
var _pl_cell := -1
var _pl_lat := 0.0
var _pl_init := false
var _cam_warned := false
var last_player_pose: Dictionary = {}    ## yaw_deg, roll_deg, cell, anchor, scale of the last frame (tests, debug)

# weather particles (camera space: x lateral, y above road, z depth)
var _wp := PackedVector3Array()
var _wp_kind := ""
var _wrng := RandomNumberGenerator.new()

# statistics
var _times := PackedInt32Array()
var _times_i := 0
var _frames := 0
var _last_us := 0
var _max_us := 0
var _sum_us := 0
var _phase_us := {"sky": 0, "background": 0, "project": 0, "world": 0, "weather": 0, "glow": 0, "w_ground": 0, "w_struct": 0, "w_items": 0, "slices": 0}


func setup(t: Track, p: RoadProjection, config: Dictionary, scenery: Dictionary) -> void:
	track = t
	proj = p
	cfg = config
	scenery_db = scenery
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_seg_len = track.seg_len
	_lw = track.lane_w
	_sh = track.shoulder_w
	_k_curve = _seg_len * _seg_len / float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var r: Dictionary = ConfigLoader.lookup(cfg, "render", {})
	_fog_start_frac = float(r.get("fog_start_frac", 0.45))
	_edge_line = float(r.get("edge_line_m", 0.3))
	_lane_line = float(r.get("lane_line_m", 0.15))
	var stripes: Dictionary = r.get("stripes", {})
	_grass_band = maxi(1, int(stripes.get("grass", 4)))
	_road_band = maxi(1, int(stripes.get("road", 2)))
	var dashes: Dictionary = stripes.get("dash", {})
	for road: String in ["autobahn", "landstrasse", "city"]:
		var d: Array = dashes.get(road, [int(stripes.get("dash_on", 2)), int(stripes.get("dash_off", 4))])
		_dash[road] = Vector2i(int(d[0]), int(d[1]))
	_merge_px = float(r.get("lod_merge_px", 1.5))
	_merge_from = float(r.get("lod_from_m", 45.0))
	_max_merge = int(r.get("lod_max_segments", 24))
	_detail_m = float(r.get("lod_detail_m", 260.0))
	var tc: Dictionary = r.get("tunnel", {})
	_t_wall_h = float(tc.get("wall_height_m", 4.2))
	_t_ceil_h = float(tc.get("ceiling_m", 6.2))
	_t_haunch = float(tc.get("haunch_m", 1.8))
	_t_lamp_every = float(tc.get("light_every_m", 12.0))
	_t_fog_m = float(tc.get("darkness_m", 260.0))
	_t_peek_m = float(tc.get("peek_m", 45.0))
	_delin_every = float(ConfigLoader.lookup(cfg, "road.delineator_every_m", 50.0))
	_crosswalk_every = float(ConfigLoader.lookup(cfg, "road.crosswalk_every_m", 330.0))
	_hl_range = float(r.get("headlight_range_m", 80.0))
	_hl_int = float(r.get("headlight_intensity", 0.95))
	_curve_r1 = maxf(1.0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
	_veh_tau = float(r.get("vehicle_yaw_smooth_s", 0.12))
	_veh_hyst = float(r.get("vehicle_cell_hysteresis", 0.3))
	_veh_max_deg = float(r.get("vehicle_yaw_max_deg", 30.0))
	_veh_warp = bool(r.get("vehicle_warp", true))
	_veh_warp_ratio = float(r.get("vehicle_warp_min_ratio", 0.06))
	_pl_lookahead = float(r.get("player_curve_lookahead_m", 10.0))
	_pl_tau = float(r.get("player_yaw_smooth_s", 0.15))
	_pl_k = {"curve_gain": float(r.get("player_curve_gain", 1.0)), "steer_deg": float(r.get("player_steer_deg", 3.0)),
		"lateral_gain": float(r.get("player_lateral_gain", 1.0)), "understeer_deg": float(r.get("player_understeer_deg", 6.0)),
		"view_gain": float(r.get("player_view_gain", 1.0)), "max_deg": float(r.get("player_yaw_max_deg", 20.0))}
	_roll_per = float(r.get("player_roll_deg_per_mps2", 0.22))
	_roll_max = minf(2.5, float(r.get("player_roll_max_deg", 2.5)))
	_roll_tau = float(r.get("player_roll_smooth_s", 0.2))
	_box.setup(proj, float(r.get("box_slice_m", 2.0)), float(r.get("box_slice_ratio", 0.12)), float(r.get("box_subdiv_px", 1.5)))
	show_stats = bool(ConfigLoader.lookup(cfg, "debug.show_render_stats", false))
	var mode := str(r.get("procedural_props", "auto"))
	var manifest: Variant = ConfigLoader.load_json("res://assets/sprites/manifest.json")
	var placeholders := manifest is Dictionary and str((manifest as Dictionary).get("generator", "")) == "placeholders"
	_prefer_proc = mode == "always" or (mode == "auto" and placeholders)
	_lm_far = float(r.get("landmark_far_m", 1900.0))
	_lm_range_k = float(r.get("landmark_range_factor", 2.0))
	_sky_dist = maxf(200.0, float(r.get("skyline_distance_m", 1800.0)))
	backdrop.setup(proj, batch, float(r.get("background_blend_s", 2.5)))
	backdrop.sprite_cb = _draw_skyline_landmark
	signs.setup(self, batch)
	signs.countries = _country_data()
	_times.resize(STATS_N)
	# additive glow layer (child canvas item drawn after this one)
	_glow_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_glow_ci, get_canvas_item())
	_glow_mat = CanvasItemMaterial.new()
	_glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	RenderingServer.canvas_item_set_material(_glow_ci, _glow_mat.get_rid())
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.55))
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 64
	_glow_tex.height = 64
	_wrng.seed = 77


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _glow_ci.is_valid():
		RenderingServer.free_rid(_glow_ci)


## Country data (GameData.countries) for the country-specific sign styles; {} without the autoload.
func _country_data() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var gd: Node = tree.root.get_node_or_null("GameData") if tree != null and tree.root != null else null
	if gd == null:
		return {}
	var c: Variant = gd.get("countries")
	return c if c is Dictionary else {}


func render(v: Dictionary) -> void:
	view = v
	queue_redraw()


## Frame time statistics of _draw (milliseconds): {frames, avg_ms, p95_ms, max_ms, last_ms}.
func perf_stats() -> Dictionary:
	var n := mini(_frames, STATS_N)
	if n == 0:
		return {"frames": 0, "avg_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0, "last_ms": 0.0}
	var arr: Array[int] = []
	for i in n:
		arr.append(_times[i])
	arr.sort()
	return {"frames": _frames, "avg_ms": float(_sum_us) / float(_frames) / 1000.0,
		"p95_ms": float(arr[int(float(n - 1) * 0.95)]) / 1000.0, "max_ms": float(_max_us) / 1000.0,
		"last_ms": float(_last_us) / 1000.0, "triangles": batch.triangles, "commands": batch.commands,
		"phases_avg_ms": _phase_avg()}


func _phase_avg() -> Dictionary:
	var out := {}
	for k: String in _phase_us:
		out[k] = snappedf(float(_phase_us[k]) / maxf(1.0, float(_frames)) / 1000.0, 0.001)
	return out


# --- frame ----------------------------------------------------------------------------------

func _draw() -> void:
	if track == null or view.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var shake: Vector2 = view.get("shake", Vector2.ZERO)
	draw_set_transform(shake)
	signs.base_offset = shake
	signs.countdown = float(view.get("countdown", -1000.0))
	batch.begin(get_canvas_item())
	_gp.clear()
	_gr.clear()
	_gc.clear()
	_prepare()
	_project()
	_pose_tick()
	var t1 := Time.get_ticks_usec()
	var heading := float(view.get("bg_offset", 0.0))
	var w := proj.screen.x
	var hy := proj.horizon_y
	var t2 := t1
	if not _cam_in_tunnel or _tunnel_exit_visible():
		backdrop.draw_sky(_pal_out, heading, _time)
		t2 = Time.get_ticks_usec()
		var scen_id := str(view.get("scenery", ""))
		var scen: Dictionary = scenery_db.get(scen_id, {})
		var haze := clampf(1.0 - _vis / maxf(1.0, float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0))), 0.0, 1.0)
		var base_y := hy
		if _clip.size() > _n and _clip[_n] < hy:
			base_y = maxf(_clip[_n], hy - 120.0)
		backdrop.landmarks = _skyline_silhouettes(heading)
		backdrop.draw_background(_pal_out, scen_id, _background_for(scen_id, scen), heading, _time, haze * 0.9, base_y)
		batch.rect(Rect2(-40, base_y, w + 80, proj.screen.y - base_y + 40), _exposed(_pal_out["fog"]))
		_draw_far_landmarks()
	else:
		batch.rect(Rect2(-40, -40, w + 80, proj.screen.y + 80), Palette.TUNNEL_FOG)
	var t3 := Time.get_ticks_usec()
	_build_slices()
	_draw_world()
	var t4 := Time.get_ticks_usec()
	_draw_weather()
	_draw_overlays()
	batch.flush()
	var t5 := Time.get_ticks_usec()
	_submit_glows(shake)
	var t6 := Time.get_ticks_usec()
	_phase_us["project"] += t1 - t0
	_phase_us["sky"] += t2 - t1
	_phase_us["background"] += t3 - t2
	_phase_us["world"] += t4 - t3
	_phase_us["weather"] += t5 - t4
	_phase_us["glow"] += t6 - t5
	if show_stats:
		_draw_stats()
	draw_set_transform(Vector2.ZERO)
	_record_time(Time.get_ticks_usec() - t0)


func _record_time(us: int) -> void:
	_last_us = us
	_frames += 1
	_sum_us += us
	_max_us = maxi(_max_us, us)
	_times[_times_i] = us
	_times_i = (_times_i + 1) % STATS_N


func _draw_stats() -> void:
	var st := perf_stats()
	var t := "draw %.2f ms (avg %.2f, p95 %.2f)  tris %d  cmds %d  slices %d" % [float(st["last_ms"]), float(st["avg_ms"]), float(st["p95_ms"]), batch.triangles, batch.commands, _sl_a.size()]
	draw_string(ThemeDB.fallback_font, Vector2(12, proj.screen.y - 12), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 0.6))


func _prepare() -> void:
	_time = float(view.get("time", 0.0))
	_pal_out = view["palette"]
	if bool(_pal_out.get("tunnel", false)):
		push_warning("RoadRenderer: view.palette muss die Außenpalette sein")
	_pal_tun = Palette.tunnel(_pal_out)
	_vis = float(view.get("visibility_m", 900.0))
	_fog_start = _vis * _fog_start_frac
	_lights = float(_pal_out.get("lights", 0.0))
	_wet = float(_pal_out.get("wet", 0.0))
	_snow = float(_pal_out.get("snow", 0.0))
	_cam_in_tunnel = bool(view.get("camera_in_tunnel", track.is_tunnel_at(float(view["camera_z"]))))
	_amb_out = _pal_out["ambient"]
	_fog_outc = _pal_out["fog"]
	_amb_tun = _pal_tun["ambient"]
	_fog_tunc = Palette.TUNNEL_FOG
	if _cam_in_tunnel:
		# eyes adapted to the tunnel: the outside looks over-exposed
		_amb_out = Color(minf(2.0, _amb_out.r * 1.7 + 0.25), minf(2.0, _amb_out.g * 1.7 + 0.25), minf(2.0, _amb_out.b * 1.7 + 0.25))
		_fog_outc = _fog_outc.lerp(Color(1, 1, 0.97), 0.55)
	else:
		_amb_tun = _amb_tun * (0.5 + 0.5 * _lights)
	# headlights and other light sources
	var player: Dictionary = view.get("player", {})
	_lit = _lights > 0.04 or _cam_in_tunnel
	_hl_i = _hl_int * clampf(_lights * 1.4, 0.0, 1.0)
	if _cam_in_tunnel:
		_hl_i = maxf(_hl_i, 0.35)
	if not player.is_empty():
		_hl_z = float(player.get("z", 0.0)) + float(player.get("length", 4.6))
		_hl_x = float(player.get("x", 0.0))
	_ls_z.clear()
	_ls_x.clear()
	_ls_r.clear()
	_ls_i.clear()
	_ls_kind.clear()
	if _lit and _lights > 0.04:
		var cam_z := float(view["camera_z"])
		for c: Dictionary in view.get("cars", []):
			var cz := float(c.get("z", 0.0)) + float(c.get("length", 4.5))
			if cz > cam_z and cz < cam_z + 140.0 and _ls_z.size() < 6:
				_add_light(cz, float(c.get("x", 0.0)), 34.0, 0.5 * _lights, 1)


func _add_light(z: float, x: float, r: float, i: float, kind: int) -> void:
	_ls_z.append(z)
	_ls_x.append(x)
	_ls_r.append(r)
	_ls_i.append(i)
	_ls_kind.append(kind)


## Extra light (0..~1.5) at road position (z, x): headlights, traffic headlights, lamps.
func _light(z: float, x: float) -> float:
	var l := 0.0
	var d := z - _hl_z
	if d > -2.0 and d < _hl_range:
		var along := smoothstep(-2.0, 5.0, d) * (1.0 - smoothstep(_hl_range * 0.3, _hl_range, d))
		var wd := 0.9 + maxf(d, 0.0) * 0.13
		var q := (x - _hl_x) / wd
		l += _hl_i * along / (1.0 + q * q * q * q)
	for i in _ls_z.size():
		var dz := z - _ls_z[i]
		if _ls_kind[i] == 1:
			if dz > -1.0 and dz < _ls_r[i]:
				var along2 := smoothstep(-1.0, 3.0, dz) * (1.0 - smoothstep(_ls_r[i] * 0.3, _ls_r[i], dz))
				var wd2 := 0.9 + maxf(dz, 0.0) * 0.18
				var q2 := (x - _ls_x[i]) / wd2
				l += _ls_i[i] * along2 / (1.0 + q2 * q2 * q2 * q2)
		else:
			var rr := _ls_r[i]
			if absf(dz) < rr:
				var dx := x - _ls_x[i]
				var e := 1.0 - (dz * dz + dx * dx) / (rr * rr)
				if e > 0.0:
					l += _ls_i[i] * e * e
	return l


func _exposed(c: Color) -> Color:
	if _cam_in_tunnel:
		return c.lerp(Color(1, 1, 0.97), 0.55)
	return c


# --- projection -----------------------------------------------------------------------------

func _project() -> void:
	var cam_z := float(view["camera_z"])
	var cam_x := float(view["camera_x"])
	_cam_y = float(view["camera_y"])
	var cam_y := _cam_y
	_base = mini(int(floor(cam_z / _seg_len)), track.segment_count - 2)
	var count := int(_vis / _seg_len) + 2
	count = maxi(1, mini(count, track.segment_count - 1 - _base))
	_n = count
	# local arrays are much faster to fill in GDScript; assigned to the members afterwards (no copy)
	var a_dz := PackedFloat32Array()
	var a_zw := PackedFloat32Array()
	var a_xw := PackedFloat32Array()
	var a_yw := PackedFloat32Array()
	var a_sx := PackedFloat32Array()
	var a_sy := PackedFloat32Array()
	var a_ss := PackedFloat32Array()
	var a_clip := PackedFloat32Array()
	var a_fo := PackedFloat32Array()
	var a_ft := PackedFloat32Array()
	a_dz.resize(count + 1)
	a_zw.resize(count + 1)
	a_xw.resize(count + 1)
	a_yw.resize(count + 1)
	a_sx.resize(count + 1)
	a_sy.resize(count + 1)
	a_ss.resize(count + 1)
	a_clip.resize(count + 1)
	a_fo.resize(count + 1)
	a_ft.resize(count + 1)
	_segs.resize(count + 1)
	var s0 := track.get_segment(maxi(_base, 0))
	var seg_len := _seg_len
	var frac := (cam_z - float(_base) * seg_len) / seg_len
	var x := 0.0
	var dx := -s0.curve * _k_curve * frac
	var kc := _k_curve
	var half_w := proj.screen.x * 0.5
	var hy := proj.horizon_y
	var focal := proj.focal
	var near := proj.near
	var clip := 1.0e9
	var fog_start := _fog_start
	var fog_span := maxf(1.0, _vis - _fog_start)
	var t_fog := _t_fog_m
	var any_tunnel := _cam_in_tunnel
	var lit_limit := float(view.get("camera_distance", proj.cam_distance)) + _hl_range + 10.0
	if _lit and _lights > 0.04 and track.is_city_at(cam_z + 100.0):
		lit_limit = maxf(lit_limit, 150.0)
	var lit_rows := 0
	var lit := _lit
	for k in count + 1:
		var seg := track.get_segment(maxi(_base + k, 0))
		_segs[k] = seg
		var zw := float(_base + k) * seg_len
		var dz := zw - cam_z
		a_dz[k] = dz
		a_zw[k] = zw
		var xr := x - cam_x
		a_xw[k] = xr
		var y := seg.y
		a_yw[k] = y
		var s := focal / maxf(dz, near)
		a_ss[k] = s
		a_sx[k] = half_w + xr * s
		var sy := hy - (y - cam_y) * s
		a_sy[k] = sy
		if dz > near and sy < clip:
			clip = sy
		a_clip[k] = clip
		a_fo[k] = clampf((dz - fog_start) / fog_span, 0.0, 1.0)
		if seg.tunnel:
			any_tunnel = true
		if lit and dz < lit_limit:
			lit_rows = k + 1
		x += dx
		dx += seg.curve * kc
	if any_tunnel:
		for k in count + 1:
			a_ft[k] = pow(clampf((a_dz[k] - 12.0) / t_fog, 0.0, 1.0), 0.8)
	_dz = a_dz
	_zw = a_zw
	_xw = a_xw
	_yw = a_yw
	_sx = a_sx
	_sy = a_sy
	_ss = a_ss
	_clip = a_clip
	_ft_out = a_fo
	_ft_tun = a_ft
	_lit_rows = lit_rows
	_inv.resize(count + 1)
	for k in count:
		var seg := _segs[k]
		var inv := 0
		if not (seg.tunnel or seg.cover != "" or seg.fuel_zone != 0):
			if _sy[k + 1] >= _sy[k] - 0.02:
				inv = 1
			elif _clip[k] < 1.0e8 and _sy[k + 1] - 1.2 * _ss[k + 1] >= _clip[k]:
				inv = 1
		_inv[k] = inv
	_inv[count] = 0
	if _lit and _lights > 0.04:
		_collect_static_lights()
	if _lit:
		_build_row_lights()


## Per-row light lists: everything that depends only on the row (cone along-factor and width,
## pool distance) is evaluated once per row instead of once per vertex.
func _build_row_lights() -> void:
	var rows := mini(_lit_rows, _n + 1)
	_rl_off.resize(rows + 1)
	_rl_x.clear()
	_rl_w.clear()
	_rl_a.clear()
	_rl_b.clear()
	_rl_kind.clear()
	var cnt := 0
	for k in rows:
		_rl_off[k] = cnt
		var z := _zw[k]
		var d := z - _hl_z
		if _hl_i > 0.0 and d > -2.0 and d < _hl_range:
			var along := smoothstep(-2.0, 5.0, d) * (1.0 - smoothstep(_hl_range * 0.3, _hl_range, d))
			if along > 0.001:
				_rl_x.append(_hl_x)
				_rl_w.append(0.9 + maxf(d, 0.0) * 0.13)
				_rl_a.append(_hl_i * along)
				_rl_b.append(0.0)
				_rl_kind.append(0)
				cnt += 1
		for i in _ls_z.size():
			var dz := z - _ls_z[i]
			if _ls_kind[i] == 1:
				if dz > -1.0 and dz < _ls_r[i]:
					var along2 := smoothstep(-1.0, 3.0, dz) * (1.0 - smoothstep(_ls_r[i] * 0.3, _ls_r[i], dz))
					if along2 > 0.001:
						_rl_x.append(_ls_x[i])
						_rl_w.append(0.9 + maxf(dz, 0.0) * 0.18)
						_rl_a.append(_ls_i[i] * along2)
						_rl_b.append(0.0)
						_rl_kind.append(0)
						cnt += 1
			elif absf(dz) < _ls_r[i]:
				var r2 := _ls_r[i] * _ls_r[i]
				_rl_x.append(_ls_x[i])
				_rl_w.append(r2)
				_rl_a.append(_ls_i[i])
				_rl_b.append(1.0 - dz * dz / r2)
				_rl_kind.append(1)
				cnt += 1
	_rl_off[rows] = cnt


## Street lamps, canopy and border-station lights inside the lit range (pool lights).
func _collect_static_lights() -> void:
	var every := float(ConfigLoader.lookup(cfg, "road.streetlight_every_m", 33.0))
	var last := mini(_lit_rows, _n)
	for k in range(0, last, 3):
		var seg := _segs[k]
		if seg.city and _ls_z.size() < 24:
			var z := _zw[k]
			if fposmod(z, every) < _seg_len * 3.0:
				var zl := z - fposmod(z, every) + _seg_len * 0.5
				var edge := seg.lanes * _lw * 0.5
				_add_light(zl, edge - 0.6, 9.0, 0.55 * _lights, 0)
				_add_light(zl + every * 0.5, -edge + 0.6, 9.0, 0.55 * _lights, 0)
		if (seg.fuel_zone & TrackSegment.FUEL_CANOPY) != 0 and k % 6 == 0 and _ls_z.size() < 24:
			var edge2 := seg.lanes * _lw * 0.5 + seg.fuel_lane * _lw
			_add_light(_zw[k], edge2 + 0.5, 11.0, 0.8 * _lights, 0)
		if seg.cover != "" and k % 4 == 0 and _ls_z.size() < 24:
			_add_light(_zw[k], 0.0, 16.0, 0.7 * _lights, 0)


func _tunnel_exit_visible() -> bool:
	for k in _n:
		if not _segs[k].tunnel and _dz[k] > 0.0:
			return true
	return false


func _has_marking(seg: TrackSegment) -> bool:
	if absf(seg.z - track.length_z) < _seg_len * 2.0 or absf(seg.z - 14.0) < _seg_len * 2.0:
		return true
	return seg.city and not seg.water and fposmod(seg.z, _crosswalk_every) < _seg_len


func _build_slices() -> void:
	_sl_a.clear()
	_sl_b.clear()
	var k := 0
	while k < _n and _dz[k + 1] <= proj.near:
		k += 1
	while k < _n:
		var b := k + 1
		if _inv[k] == 1:
			# invisible ground (behind a crest): one slice, only its sprites are drawn
			while b < _n and _inv[b] == 1 and b - k < 64 and _segs[b].tunnel == _segs[k].tunnel:
				b += 1
		elif _dz[k] > _merge_from:
			while b < _n and b - k < _max_merge and _inv[b] == 0 and _can_merge(k, b):
				b += 1
		_sl_a.append(k)
		_sl_b.append(b)
		k = b


func _can_merge(a: int, b: int) -> bool:
	if _sy[a] - _sy[b + 1] > _merge_px:
		return false
	var sa := _segs[a]
	var sb := _segs[b]
	if sa.tunnel != sb.tunnel or sa.city != sb.city or sa.road != sb.road or sa.guardrail != sb.guardrail:
		return false
	if sa.fuel_zone != sb.fuel_zone or sa.cover != sb.cover or sa.runout != sb.runout or sa.scenery != sb.scenery:
		return false
	if sa.water != sb.water or sa.bridge_i != sb.bridge_i or sb.bank or absf(sa.water_level - sb.water_level) > 0.05:
		return false
	if absf(sa.fuel_lane - sb.fuel_lane) > 0.01 or absf(sa.lanes - sb.lanes) > 0.01:
		return false
	if _has_marking(sb):
		return false
	var t := float(b - a) / float(b + 1 - a)
	return absf(lerpf(_sx[a], _sx[b + 1], t) - _sx[b]) <= 2.0


# --- screen helpers -------------------------------------------------------------------------

## Camera-space road sample at world z: Vector3(lateral offset of the road centre from the camera axis, road
## height relative to the camera, depth). Linear in each segment; extrapolated beyond the projected rows.
func road_at(z: float) -> Vector3:
	var fk := z / _seg_len - float(_base)
	var k := clampi(int(floor(fk)), 0, maxi(0, _n - 1))
	var f := fk - float(k)
	return Vector3(lerpf(_xw[k], _xw[k + 1], f), lerpf(_yw[k], _yw[k + 1], f) - _cam_y, lerpf(_dz[k], _dz[k + 1], f))


## Road heading (radians) relative to the camera axis at world z (slope of the road centre over ±1.5 m).
func road_heading_at(z: float) -> float:
	return atan((road_at(z + 1.5).x - road_at(z - 1.5).x) / 3.0)


## Screen position (x, y, pixels per metre) of road point (segment k, fraction f, lateral x, height h).
func _proj_at(k: int, f: float, x: float, h: float) -> Vector3:
	var dz := lerpf(_dz[k], _dz[k + 1], f)
	if dz <= proj.near:
		return Vector3(0, 0, -1)
	var s := proj.focal / dz
	var xw := lerpf(_xw[k], _xw[k + 1], f)
	var yw := lerpf(_yw[k], _yw[k + 1], f)
	return Vector3(proj.screen.x * 0.5 + (xw + x) * s, proj.horizon_y - (yw + h - _cam_y) * s, s)


func _ctx(tunnel: bool) -> void:
	_in_tun_ctx = tunnel
	if tunnel:
		_amb = _amb_tun
		_fogc = _fog_tunc
		_ftx = _ft_tun
	else:
		_amb = _amb_out
		_fogc = _fog_outc
		_ftx = _ft_out


## Colour of a ground point at row k and lateral x: ambient + local light, then fog.
func _shade(base: Color, k: int, x: float, reflect: float = 1.0) -> Color:
	var r := base.r * _amb.r
	var g := base.g * _amb.g
	var bb := base.b * _amb.b
	if _lit and k < _lit_rows:
		# per-row light list (see _build_row_lights)
		var l := 0.0
		for i in range(_rl_off[k], _rl_off[k + 1]):
			if _rl_kind[i] == 0:
				var q := (x - _rl_x[i]) / _rl_w[i]
				var q2 := q * q
				l += _rl_a[i] / (1.0 + q2 * q2)
			else:
				var dx := x - _rl_x[i]
				var e := _rl_b[i] - dx * dx / _rl_w[i]
				if e > 0.0:
					l += _rl_a[i] * e * e
		if l > 0.0:
			l *= reflect
			r += base.r * l * LIGHT_COL.r
			g += base.g * l * LIGHT_COL.g
			bb += base.b * l * LIGHT_COL.b
	var f := _ftx[k]
	return Color(r + (_fogc.r - r) * f, g + (_fogc.g - g) * f, bb + (_fogc.b - bb) * f, base.a)


## Row colour without local light (fast path): ambient, then fog of row k.
func _rowc(base: Color, k: int) -> Color:
	var f := _ftx[k]
	var r := base.r * _amb.r
	var g := base.g * _amb.g
	var bb := base.b * _amb.b
	return Color(r + (_fogc.r - r) * f, g + (_fogc.g - g) * f, bb + (_fogc.b - bb) * f, base.a)


## Ground-level strip between rows a (near) and b (far) from lateral xa0..xa1 (row a) to xb0..xb1
## (row b), raised by h metres; split into `parts` lateral pieces for smooth night lighting.
func _gstrip(a: int, b: int, xa0: float, xa1: float, xb0: float, xb1: float, base: Color, h: float = 0.0, parts: int = 1, reflect: float = 1.0) -> void:
	var sxa := _sx[a]
	var ssa := _ss[a]
	var sya := _sy[a] - h * ssa
	var sxb := _sx[b]
	var ssb := _ss[b]
	var syb := _sy[b] - h * ssb
	if not (_lit and a < _lit_rows):
		var ca0 := _rowc(base, a)
		var cb0 := _rowc(base, b)
		batch.quad4(Vector2(sxa + xa0 * ssa, sya), Vector2(sxa + xa1 * ssa, sya), Vector2(sxb + xb1 * ssb, syb), Vector2(sxb + xb0 * ssb, syb), ca0, ca0, cb0, cb0)
		return
	if parts <= 1:
		if xa1 - xa0 < 0.8:
			var la := _shade(base, a, (xa0 + xa1) * 0.5, reflect)
			var lb := _shade(base, b, (xb0 + xb1) * 0.5, reflect)
			batch.quad4(Vector2(sxa + xa0 * ssa, sya), Vector2(sxa + xa1 * ssa, sya), Vector2(sxb + xb1 * ssb, syb), Vector2(sxb + xb0 * ssb, syb), la, la, lb, lb)
			return
		batch.quad4(Vector2(sxa + xa0 * ssa, sya), Vector2(sxa + xa1 * ssa, sya), Vector2(sxb + xb1 * ssb, syb), Vector2(sxb + xb0 * ssb, syb),
			_shade(base, a, xa0, reflect), _shade(base, a, xa1, reflect), _shade(base, b, xb1, reflect), _shade(base, b, xb0, reflect))
		return
	var pa := Vector2(sxa + xa0 * ssa, sya)
	var pb := Vector2(sxb + xb0 * ssb, syb)
	var ca := _shade(base, a, xa0, reflect)
	var cb := _shade(base, b, xb0, reflect)
	for i in range(1, parts + 1):
		var t := float(i) / float(parts)
		var xa := lerpf(xa0, xa1, t)
		var xb := lerpf(xb0, xb1, t)
		var na := Vector2(sxa + xa * ssa, sya)
		var nb := Vector2(sxb + xb * ssb, syb)
		var nca := _shade(base, a, xa, reflect)
		var ncb := _shade(base, b, xb, reflect)
		batch.quad4(pa, na, nb, pb, ca, nca, ncb, cb)
		pa = na
		pb = nb
		ca = nca
		cb = ncb


## Painted line on the road: lateral start xa (row a) / xb (row b), width w metres.
## Lines thinner than a pixel are widened to one pixel and faded (coverage anti-aliasing).
func _line(a: int, b: int, xa: float, xb: float, w: float, col: Color, alpha: float) -> void:
	var px := w * _ss[b]
	var wa := maxf(w, 1.0 / _ss[a])
	var wb := maxf(w, 1.0 / _ss[b])
	var al := alpha * minf(1.0, px)
	if al < 0.03:
		return
	_gstrip(a, b, xa, xa + wa, xb, xb + wb, Color(col, al), 0.0, 1, 1.6)


## Vertical face along the road at lateral x (row a: xa, row b: xb) from height h0 to h1.
func _vstrip(a: int, b: int, xa: float, xb: float, h0: float, h1: float, base: Color, reflect: float = 0.6) -> void:
	var sxa := _sx[a]
	var ssa := _ss[a]
	var sxb := _sx[b]
	var ssb := _ss[b]
	var ca: Color
	var cb: Color
	if _lit and a < _lit_rows:
		ca = _shade(base, a, xa, reflect)
		cb = _shade(base, b, xb, reflect)
	else:
		ca = _rowc(base, a)
		cb = _rowc(base, b)
	var ya := _sy[a]
	var yb := _sy[b]
	batch.quad4(Vector2(sxa + xa * ssa, ya - h1 * ssa), Vector2(sxb + xb * ssb, yb - h1 * ssb), Vector2(sxb + xb * ssb, yb - h0 * ssb), Vector2(sxa + xa * ssa, ya - h0 * ssa), ca, cb, cb, ca)


## Horizontal surface at height h between lateral xa0..xa1 (row a) and xb0..xb1 (row b).
func _hstrip(a: int, b: int, xa0: float, xa1: float, xb0: float, xb1: float, h: float, base: Color) -> void:
	_gstrip(a, b, xa0, xa1, xb0, xb1, base, h, 1, 0.3)


func _glow(pos: Vector2, r: float, col: Color) -> void:
	if r < 0.6 or col.a < 0.01:
		return
	if pos.x < -r or pos.x > proj.screen.x + r or pos.y < -r or pos.y > proj.screen.y + r:
		return
	_gp.append(pos)
	_gr.append(r)
	_gc.append(col)


func _submit_glows(shake: Vector2) -> void:
	RenderingServer.canvas_item_clear(_glow_ci)
	RenderingServer.canvas_item_set_transform(_glow_ci, Transform2D(0.0, shake))
	var rid := _glow_tex.get_rid()
	for i in _gp.size():
		var r := _gr[i]
		RenderingServer.canvas_item_add_texture_rect(_glow_ci, Rect2(_gp[i] - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), rid, false, _gc[i])


# --- world ----------------------------------------------------------------------------------

func _draw_world() -> void:
	var buckets := {}
	for item: Dictionary in view.get("cars", []):
		if _is_box(str(item.get("set", ""))):
			_bucket_box(buckets, item)
		else:
			_bucket(buckets, item)
	if view.has("player"):
		_bucket(buckets, view["player"])
	# From outside only the first metres of a tunnel are drawn (the tube deeper inside could curve out
	# of the portal hill); the tube is closed with darkness there. From inside, a tunnel that continues
	# beyond the visible range is closed the same way at the far end.
	var skip_from := _n + 1
	if not _cam_in_tunnel:
		for k in range(1, _n):
			if _segs[k].tunnel and not _segs[k - 1].tunnel:
				var lim := _dz[k] + _t_peek_m
				var j := k
				while j < _n and _segs[j].tunnel and _dz[j] < lim:
					j += 1
				if j < _n and _segs[j].tunnel:
					skip_from = j
					_tunnel_cap(j)
				break
	elif _segs[_n - 1].tunnel and _dz[_n] > proj.near:
		_tunnel_cap(_n)
	for si in range(_sl_a.size() - 1, -1, -1):
		var a := _sl_a[si]
		var b := _sl_b[si]
		if a >= skip_from and _segs[a].tunnel:
			continue
		var hidden := _inv[a] == 1
		_ctx(_segs[a].tunnel)
		var q0 := Time.get_ticks_usec()
		if not hidden:
			_draw_ground(a, b)
		var q1 := Time.get_ticks_usec()
		_draw_structures(a, b, hidden)
		var q2 := Time.get_ticks_usec()
		_draw_items(a, b, buckets)
		var q3 := Time.get_ticks_usec()
		_phase_us["w_ground"] += q1 - q0
		_phase_us["w_struct"] += q2 - q1
		_phase_us["w_items"] += q3 - q2
		_phase_us["slices"] += 1
		if a > 0 and _dz[a] > proj.near:
			var near_seg := _segs[a - 1]
			var far_seg := _segs[a]
			if far_seg.tunnel and not near_seg.tunnel:
				_draw_portal(a)


## Dark cross-section of the tunnel tube at row k.
func _tunnel_cap(k: int) -> void:
	var seg := _segs[mini(k, _n - 1)]
	var l := -seg.lanes * _lw * 0.5 - _sh
	var r := seg.lanes * _lw * 0.5 + seg.fuel_lane * _lw + _sh
	var s := _ss[k]
	batch.rect(Rect2(_sx[k] + l * s - 2.0, _sy[k] - _t_ceil_h * s - 2.0, (r - l) * s + 4.0, _t_ceil_h * s + 4.0), _fog_tunc)


func _bucket(buckets: Dictionary, item: Dictionary) -> void:
	var k := int(floor(float(item["z"]) / _seg_len)) - _base
	if k < 0 or k >= _n:
		return
	if not buckets.has(k):
		buckets[k] = []
	(buckets[k] as Array).append(item)


func _is_box(set_id: String) -> bool:
	var info := _spinfo(set_id)
	return not info.is_empty() and bool(info[SI_BOX])


## Box vehicles (trucks, buses) are cut at the scene slices: every slice they reach gets one item with that
## part of the vehicle, so they take part in the painter's order like the ground (crests hide them, a truck
## beside the player is drawn in depth order with the player car). The part behind the near plane is cut
## off – a truck alongside stays visible while its rear is behind the camera.
func _bucket_box(buckets: Dictionary, car: Dictionary) -> void:
	var z0 := float(car["z"])
	var length := float(car.get("length", 16.5))
	var cam_z := float(view["camera_z"])
	var lo := maxf(z0, cam_z + proj.near)
	var hi := minf(z0 + length, cam_z + _vis)
	if hi <= lo:
		return
	for si in _sl_a.size():
		var a := _sl_a[si]
		var b := _sl_b[si]
		var s0 := _zw[a]
		var s1 := _zw[b]
		if s1 <= lo:
			continue
		if s0 >= hi:
			break
		var r0 := maxf(lo, s0)
		var r1 := minf(hi, s1)
		if r1 <= r0 + 0.001:
			continue
		if not buckets.has(a):
			buckets[a] = []
		(buckets[a] as Array).append({"kind": "box", "car": car, "z0": r0, "z1": r1, "z": (r0 + r1) * 0.5})


func _grass_color(seg: TrackSegment, merged: bool) -> Color:
	var scen: Dictionary = scenery_db.get(seg.scenery, {})
	var gcols: Array = scen.get("grass", ["#5d9a3e", "#56913a"])
	var g0 := Color(str(gcols[0]))
	var g1 := Color(str(gcols[mini(1, gcols.size() - 1)]))
	var c := g0.lerp(g1, 0.5) if merged else (g0 if (seg.index / _grass_band) % 2 == 0 else g1)
	if _snow > 0.0:
		c = c.lerp(Palette.SNOW_GROUND if (seg.index / _grass_band) % 2 == 0 or merged else Palette.SNOW_GROUND.darkened(0.035), 0.94 * _snow)
	return c


func _road_color(seg: TrackSegment, merged: bool, dz: float) -> Color:
	var c := Palette.ROAD
	match seg.road:
		"landstrasse":
			c = Palette.ROAD_LANDSTRASSE
		"city":
			c = Palette.ROAD_CITY
	if not merged and (seg.index / _road_band) % 2 == 1:
		c = c.lightened(0.025)
	if _wet > 0.0:
		c = c.darkened(0.32 * _wet)
		# wet asphalt mirrors the bright sky in the distance
		var sheen := clampf(dz / maxf(80.0, _vis), 0.0, 1.0)
		var sky: Color = _pal_out["sky_bottom"]
		c = c.lerp(Color(sky.r / maxf(0.2, _amb_out.r), sky.g / maxf(0.2, _amb_out.g), sky.b / maxf(0.2, _amb_out.b)), 0.28 * sheen * _wet)
	if _snow > 0.0 and not seg.tunnel:
		c = c.lerp(Color("9fa4ab"), 0.3 * _snow)
	return c


func _draw_ground(a: int, b: int) -> void:
	var sa := _segs[a]
	var sb := _segs[b]
	if _sy[b] >= _sy[a] - 0.02:
		return
	var merged := b - a > 1
	var tunnel := sa.tunnel
	var lw := _lw
	var sh := _sh
	var la := -sa.lanes * lw * 0.5
	var lb := -sb.lanes * lw * 0.5
	var ma := -la
	var mb := -lb
	var ra := ma + sa.fuel_lane * lw
	var rb := mb + sb.fuel_lane * lw
	var lit_row := _lit and a < _lit_rows
	var w := proj.screen.x
	# grass (full width; split at night so the headlight cone can light the verge); water on bridges
	if not tunnel and sa.water:
		_draw_water(a, b, sa, merged)
	elif not tunnel:
		var g := _grass_color(sa, merged)
		if lit_row:
			var xl_a := (-40.0 - _sx[a]) / _ss[a]
			var xl_b := (-40.0 - _sx[b]) / _ss[b]
			var xr_a := (w + 40.0 - _sx[a]) / _ss[a]
			var xr_b := (w + 40.0 - _sx[b]) / _ss[b]
			_gstrip(a, b, minf(xl_a, la - sh), la - sh, minf(xl_b, lb - sh), lb - sh, g, 0.0, 1, 0.45)
			_gstrip(a, b, ra + sh, maxf(xr_a, ra + sh), rb + sh, maxf(xr_b, rb + sh), g, 0.0, 1, 0.45)
		else:
			var ca := _rowc(g, a)
			var cb := _rowc(g, b)
			batch.quad4(Vector2(-40, _sy[b]), Vector2(w + 40, _sy[b]), Vector2(w + 40, _sy[a]), Vector2(-40, _sy[a]), cb, cb, ca, ca)
	# shoulders / sidewalks / tunnel walkways
	if tunnel:
		var walk := 0.9
		var sc := Palette.SHOULDER_PAVED.darkened(0.1)
		_gstrip(a, b, la - sh + walk, la, lb - sh + walk, lb, sc)
		_gstrip(a, b, ra, ra + sh - walk, rb, rb + sh - walk, sc)
		_gstrip(a, b, la - sh, la - sh + walk, lb - sh, lb - sh + walk, Color("8f8b82"), 0.25)
		_gstrip(a, b, ra + sh - walk, ra + sh, rb + sh - walk, rb + sh, Color("8f8b82"), 0.25)
		_vstrip(a, b, la - sh + walk, lb - sh + walk, 0.0, 0.25, Color("b4afa4"))
		_vstrip(a, b, ra + sh - walk, rb + sh - walk, 0.0, 0.25, Color("b4afa4"))
	elif sa.city:
		var curb_h := 0.14
		var walk_c := Palette.SIDEWALK if (sa.index / 2) % 2 == 0 or merged else Palette.SIDEWALK_ALT
		if _snow > 0.0:
			walk_c = walk_c.lerp(Palette.SNOW_GROUND, 0.7 * _snow)
		_gstrip(a, b, la - sh, la - 0.25, lb - sh, lb - 0.25, walk_c, curb_h, 2 if lit_row else 1)
		_gstrip(a, b, ra + 0.25, ra + sh, rb + 0.25, rb + sh, walk_c, curb_h, 2 if lit_row else 1)
		var curb := Palette.CURB if sa.index % 2 == 0 or merged else Palette.CURB.darkened(0.12)
		_gstrip(a, b, la - 0.25, la, lb - 0.25, lb, curb, curb_h)
		_gstrip(a, b, ra, ra + 0.25, rb, rb + 0.25, curb, curb_h)
		_vstrip(a, b, la, lb, 0.0, curb_h, curb.darkened(0.15))
		_vstrip(a, b, ra, rb, 0.0, curb_h, curb.darkened(0.15))
	elif sa.water:
		# bridge deck outside the City Limits: paved shoulders up to the railing
		var deck := Palette.SHOULDER_PAVED.darkened(0.05)
		var dx := Track.BRIDGE_DECK_EXTRA_M
		_gstrip(a, b, la - sh - dx, la, lb - sh - dx, lb, deck, 0.0, 2 if lit_row else 1, 0.6)
		_gstrip(a, b, ra, ra + sh + dx, rb, rb + sh + dx, deck, 0.0, 2 if lit_row else 1, 0.8)
	else:
		var shc := Palette.SHOULDER_PAVED if sa.road == "autobahn" else _grass_color(sa, merged).lerp(Palette.SHOULDER, 0.65)
		if sa.road == "autobahn" and _snow > 0.0:
			shc = shc.lerp(Palette.SNOW_GROUND, 0.75 * _snow)
		if sa.road == "autobahn":
			# median side: narrow paved strip, then grass up to the guardrail
			var med := _grass_color(sa, merged).darkened(0.08)
			_gstrip(a, b, la - sh, la - 0.8, lb - sh, lb - 0.8, med, 0.0, 1, 0.45)
			_gstrip(a, b, la - 0.8, la, lb - 0.8, lb, shc, 0.0, 1)
		else:
			_gstrip(a, b, la - sh, la, lb - sh, lb, shc, 0.0, 2 if lit_row else 1, 0.6)
		_gstrip(a, b, ra, ra + sh, rb, rb + sh, shc, 0.0, 2 if lit_row else 1, 0.8)
	# asphalt
	var rc := _road_color(sa, merged, _dz[a])
	var parts := 1
	if lit_row:
		parts = maxi(2, int(ceil(sa.lanes + sa.fuel_lane)) * 2)
	_gstrip(a, b, la, ra, lb, rb, rc, 0.0, parts, 0.9)
	if _snow > 0.0 and not tunnel:
		# snow pushed to the road edges
		_gstrip(a, b, la, la + 0.7, lb, lb + 0.7, Color(0.9, 0.92, 0.94, 0.7), 0.0, 1, 0.8)
		_gstrip(a, b, ma - 0.55, ma, mb - 0.55, mb, Color(0.9, 0.92, 0.94, 0.7), 0.0, 1, 0.8)
	_draw_markings(a, b, sa, sb, la, lb, ma, mb, ra, rb, merged)


func _draw_markings(a: int, b: int, sa: TrackSegment, sb: TrackSegment, la: float, lb: float, ma: float, mb: float, ra: float, rb: float, merged: bool) -> void:
	var white := Palette.LINE
	if _snow > 0.0:
		white = white.lerp(Color("c9cdd3"), 0.5 * _snow)
	var el := _edge_line
	var ll := _lane_line
	if not sa.city:
		_line(a, b, la + 0.15, lb + 0.15, el, white, 1.0)
		var sep := el * (1.6 if sa.fuel_lane > 0.02 else 1.0)
		_line(a, b, ma - 0.15 - sep * 0.5, mb - 0.15 - sep * 0.5, sep, white, 1.0)
		if sa.fuel_lane > 0.02 or sb.fuel_lane > 0.02:
			_line(a, b, ra - 0.15 - el, rb - 0.15 - el, el, white, 1.0)
	if _dz[a] > _detail_m:
		return
	var dash: Vector2i = _dash.get(sa.road, Vector2i(2, 4))
	var cyc := dash.x + dash.y
	var on := true
	var alpha := 1.0
	if merged:
		alpha = float(dash.x) / float(cyc)
	else:
		on = (sa.index % cyc) < dash.x
	if on:
		var n := int(ceil(maxf(sa.lanes, sb.lanes) - 0.01))
		for i in range(1, n):
			var xa := la + float(i) * _lw
			var xb := lb + float(i) * _lw
			if xa > ma - 0.6 or xb > mb - 0.6:
				continue
			_line(a, b, xa - ll * 0.5, xb - ll * 0.5, ll, white, alpha)
	if merged:
		return
	# hatched wedge where the fuel lane opens (diagonal stripes)
	if sa.fuel_lane > 0.05 and sa.fuel_lane < 0.98 and sb.fuel_lane > sa.fuel_lane and sa.index % 2 == 0 and rb - mb > 0.9:
		_gstrip(a, b, ma + 0.15, ma + 0.45, rb - 0.75, rb - 0.45, Color(white, 0.9), 0.0, 1, 1.4)
	# start and finish lines (checkered), city crosswalks
	var z0 := _zw[a]
	if absf(z0 + _seg_len * 0.5 - track.length_z) <= _seg_len * 0.5 or absf(z0 + _seg_len * 0.5 - 14.0) <= _seg_len * 0.5:
		_checker(a, la, ra, lb, rb)
	elif sa.city and not sa.water and fposmod(sa.z, _crosswalk_every) < _seg_len:
		var bars := int((ma - la) / 1.0)
		for i in bars:
			var x0 := la + 0.3 + float(i) * 1.0
			_gstrip(a, b, x0, x0 + 0.5, x0 - la + lb, x0 - la + lb + 0.5, white, 0.0, 1, 1.4)


func _checker(a: int, la: float, ra: float, lb: float, rb: float) -> void:
	var cells := maxi(4, int((ra - la) / 1.0))
	var rows := 2
	for r in rows:
		var f0 := float(r) / float(rows)
		var f1 := float(r + 1) / float(rows)
		var p0 := _proj_at(a, f0, 0.0, 0.0)
		var p1 := _proj_at(a, f1, 0.0, 0.0)
		if p0.z <= 0.0 or p1.z <= 0.0:
			continue
		var l0 := lerpf(la, lb, f0)
		var r0 := lerpf(ra, rb, f0)
		var l1 := lerpf(la, lb, f1)
		var r1 := lerpf(ra, rb, f1)
		for c in cells:
			var t0 := float(c) / float(cells)
			var t1 := float(c + 1) / float(cells)
			var col := Color.WHITE if (c + r) % 2 == 0 else Color(0.08, 0.08, 0.08)
			var cc := _shade(col, a, lerpf(l0, r0, t0), 1.2)
			batch.quad(Vector2(p0.x + lerpf(l0, r0, t0) * p0.z, p0.y), Vector2(p0.x + lerpf(l0, r0, t1) * p0.z, p0.y),
				Vector2(p1.x + lerpf(l1, r1, t1) * p1.z, p1.y), Vector2(p1.x + lerpf(l1, r1, t0) * p1.z, p1.y), cc)


# --- structures (guardrails, delineators, tunnel, canopies) ---------------------------------

func _draw_structures(a: int, b: int, hidden: bool) -> void:
	var sa := _segs[a]
	var sb := _segs[b]
	if hidden:
		return
	var la := -sa.lanes * _lw * 0.5
	var lb := -sb.lanes * _lw * 0.5
	var ra := -la + sa.fuel_lane * _lw
	var rb := -lb + sb.fuel_lane * _lw
	if sa.tunnel:
		_tunnel_segment(a, b, la - _sh, ra + _sh, lb - _sh, rb + _sh)
		return
	var merged := b - a > 1
	if sa.guardrail:
		_guardrail(a, b, la - _sh, lb - _sh, merged)
		if sa.fuel_lane < 0.01 and sb.fuel_lane < 0.01 and sa.cover == "":
			_guardrail(a, b, ra + _sh, rb + _sh, merged)
	if not sa.city and _ss[a] > 1.2:
		_delineators(a, b, sa, la - _sh + 0.3, ra + _sh - 0.3, not sa.guardrail)
	if sa.fuel_zone != 0:
		_fuel_structures(a, b, sa, ra, rb)
	if sa.cover != "":
		_border_cover(a, b, sa, la - _sh, ra + _sh, lb - _sh, rb + _sh)
	if sa.water:
		_bridge_structures(a, b, sa, la, lb, ra, rb, merged)
	elif sa.city:
		_fence(a, b, sa, la, lb, ra, rb, merged)


func _guardrail(a: int, b: int, xa: float, xb: float, merged: bool) -> void:
	var c := Palette.GUARDRAIL
	if _snow > 0.0:
		c = c.lerp(Color.WHITE, 0.3 * _snow)
	_vstrip(a, b, xa, xb, 0.48, 0.56, c.darkened(0.35), 0.8)
	_vstrip(a, b, xa, xb, 0.56, 0.74, c, 0.8)
	_vstrip(a, b, xa, xb, 0.74, 0.8, c.lightened(0.25), 0.8)
	if merged:
		return
	var seg := _segs[a]
	if seg.index % _guard_post_every == 0:
		var s := _ss[a]
		var px := _sx[a] + xa * s
		var pw := maxf(1.0, 0.14 * s)
		var post := _shade(Color("6f747a"), a, xa, 0.5)
		batch.rect(Rect2(px - pw * 0.5, _sy[a] - 0.74 * s, pw, 0.74 * s), post)
		# reflectors on the posts every delineator interval
		if fposmod(_zw[a], _delin_every) < _seg_len * float(_guard_post_every):
			var refl := _shade(Color(1.0, 0.75, 0.3) if xa > 0.0 else Color.WHITE, a, xa, 3.0)
			batch.rect(Rect2(px - pw * 0.6, _sy[a] - 0.68 * s, pw * 1.2, 0.1 * s), refl)
			if _lit:
				var l := _light(_zw[a], xa)
				if l > 0.05:
					_glow(Vector2(px, _sy[a] - 0.63 * s), maxf(2.0, 0.35 * s), Color(1.0, 0.8, 0.5, minf(0.6, l * 0.6)))


func _delineators(a: int, b: int, seg: TrackSegment, xl: float, xr: float, both: bool) -> void:
	var z0 := _zw[a]
	var z1 := _zw[b]
	var z := ceilf(z0 / _delin_every) * _delin_every
	while z < z1:
		var k := clampi(int((z - _zw[0]) / _seg_len), a, b - 1)
		var f := clampf((z - _zw[k]) / _seg_len, 0.0, 1.0)
		if both:
			_delineator(k, f, xl, false)
		if seg.fuel_lane < 0.01 and seg.cover == "" and not seg.guardrail:
			_delineator(k, f, xr, true)
		z += _delin_every


func _delineator(k: int, f: float, x: float, right: bool) -> void:
	var p := _proj_at(k, f, x, 0.0)
	if p.z <= 0.0:
		return
	var s := p.z
	var w := maxf(1.0, 0.13 * s)
	var h := 1.05 * s
	if h < 1.5:
		return
	var white := _shade(Color("f2f2ee"), k, x, 0.5)
	var black := _shade(Color("1a1a1a"), k, x, 0.2)
	batch.rect(Rect2(p.x - w * 0.5, p.y - h, w, h), white)
	batch.rect(Rect2(p.x - w * 0.5, p.y - h + 0.12 * s, w, 0.22 * s), black)
	var refl := Color(1.0, 0.65, 0.2) if right else Color(1, 1, 1)
	var l := _light(_zw[k], x) if _lit and k < _lit_rows else 0.0
	var rc := _shade(refl, k, x, 4.0)
	batch.rect(Rect2(p.x - w * 0.3, p.y - h + 0.16 * s, w * 0.6, 0.12 * s), rc)
	if l > 0.04:
		_glow(Vector2(p.x, p.y - h + 0.22 * s), maxf(2.5, 0.4 * s), Color(refl, minf(0.7, l * 0.8)))


func _tunnel_segment(a: int, b: int, xla: float, xra: float, xlb: float, xrb: float) -> void:
	var wall_h := _t_wall_h
	var ceil_h := _t_ceil_h
	var ins := _t_haunch
	var seg := _segs[a]
	var tile := TILE if (seg.index / 2) % 2 == 0 or b - a > 1 else TILE.darkened(0.06)
	_vstrip(a, b, xla, xlb, 0.25, 2.9, tile, 0.4)
	_vstrip(a, b, xra, xrb, 0.25, 2.9, tile, 0.4)
	_vstrip(a, b, xla, xlb, 2.9, wall_h, WALL, 0.3)
	_vstrip(a, b, xra, xrb, 2.9, wall_h, WALL, 0.3)
	# haunches (slanted ceiling corners) and ceiling
	var ya := _sy[a]
	var yb := _sy[b]
	var sa := _ss[a]
	var sbb := _ss[b]
	var xa := _sx[a]
	var xb := _sx[b]
	var hc := _shade(HAUNCH, a, 0.0, 0.2)
	var hcb := _shade(HAUNCH, b, 0.0, 0.2)
	batch.quad4(Vector2(xa + xla * sa, ya - wall_h * sa), Vector2(xb + xlb * sbb, yb - wall_h * sbb), Vector2(xb + (xlb + ins) * sbb, yb - ceil_h * sbb), Vector2(xa + (xla + ins) * sa, ya - ceil_h * sa), hc, hcb, hcb, hc)
	batch.quad4(Vector2(xa + xra * sa, ya - wall_h * sa), Vector2(xb + xrb * sbb, yb - wall_h * sbb), Vector2(xb + (xrb - ins) * sbb, yb - ceil_h * sbb), Vector2(xa + (xra - ins) * sa, ya - ceil_h * sa), hc, hcb, hcb, hc)
	_hstrip(a, b, xla + ins, xra - ins, xlb + ins, xrb - ins, ceil_h, CEILING)
	# lamp rows on both haunches
	var z := ceilf(_zw[a] / _t_lamp_every) * _t_lamp_every
	while z < _zw[b]:
		var k := clampi(int((z - _zw[0]) / _seg_len), a, b - 1)
		var f := clampf((z - _zw[k]) / _seg_len, 0.0, 1.0)
		var ft := pow(_ft_tun[k], 3.0) if _cam_in_tunnel else pow(_ft_tun[k], 2.0)
		var al := 1.0 - ft
		if al > 0.02:
			for side: float in [-1.0, 1.0]:
				var lx := (xla + ins * 0.5) if side < 0.0 else (xra - ins * 0.5)
				lx = lerpf(lx, (xlb + ins * 0.5) if side < 0.0 else (xrb - ins * 0.5), f)
				var p := _proj_at(k, f, lx, (wall_h + ceil_h) * 0.5)
				if p.z > 0.0:
					var lw2 := maxf(1.2, 0.7 * p.z)
					var lh := maxf(1.0, 0.22 * p.z)
					batch.rect(Rect2(p.x - lw2 * 0.5, p.y - lh * 0.5, lw2, lh), Color(LAMP_COL.lerp(Color.WHITE, 0.4), al))
					_glow(Vector2(p.x, p.y), maxf(3.0, 1.6 * p.z), Color(LAMP_COL, 0.45 * al))
		z += _t_lamp_every
	# emergency niches (green signs) every 150 m on the right wall
	if fposmod(_zw[a], 150.0) < _seg_len and b - a == 1:
		var p2 := _proj_at(a, 0.5, xra - 0.05, 2.2)
		if p2.z > 0.0:
			var gw := 0.9 * p2.z
			batch.rect(Rect2(p2.x - gw, p2.y - 0.45 * p2.z, gw, 0.5 * p2.z), Color(Color("1f9d4a") * (0.6 + 0.4 * (1.0 - _ft_tun[a])), 1.0))
			_glow(Vector2(p2.x - gw * 0.5, p2.y - 0.2 * p2.z), maxf(2.0, 0.8 * p2.z), Color(0.2, 1.0, 0.4, 0.3 * (1.0 - _ft_tun[a])))


## Tunnel entrance seen from outside: an overgrown hill with a concrete portal (headwall,
## wingwalls, chamfered frame) around the opening. The opening itself is left unpainted so the
## tunnel interior drawn before shows through.
func _draw_portal(k: int) -> void:
	_ctx(false)
	var seg := _segs[k]
	var xl := -seg.lanes * _lw * 0.5 - _sh
	var xr := seg.lanes * _lw * 0.5 + seg.fuel_lane * _lw + _sh
	var s := _ss[k]
	var x0 := _sx[k]
	var y0 := _sy[k]
	var ceil_h := _t_ceil_h
	var wall_h := _t_wall_h
	var ins := _t_haunch
	var head_h := ceil_h + 2.4
	var scen: Dictionary = scenery_db.get(seg.scenery, {})
	var gcols: Array = scen.get("grass", ["#5d9a3e"])
	var veg := Color(str(gcols[0])).darkened(0.22)
	if _snow > 0.0:
		veg = veg.lerp(Palette.SNOW_GROUND, 0.8 * _snow)
	var veg_top := _rowc(veg.lightened(0.08), k)
	var veg_bot := _rowc(veg.darkened(0.2), k)
	var conc := _rowc(CONCRETE, k)
	var conc_dark := _rowc(CONCRETE.darkened(0.18), k)
	# hill silhouette (deterministic per tunnel): the summit lies behind the portal, so the
	# silhouette points are projected deeper than the face -> the hill slopes away
	var rng := RandomNumberGenerator.new()
	rng.seed = seg.index * 31 + 7
	var cx := (xl + xr) * 0.5
	var span := 85.0 + (xr - xl) * 0.5
	var peak := 30.0 + rng.randf_range(-5.0, 9.0)
	var xs: Array[float] = []
	var cols := 30
	for i in cols + 1:
		xs.append(cx + (float(i) / float(cols) * 2.0 - 1.0) * span)
	xs.append(xl)
	xs.append(xr)
	xs.sort()
	var dz0 := _dz[k]
	var xw0 := _xw[k]
	var yw0 := _yw[k]
	var hy := proj.horizon_y
	var top_pts: Array[Vector2] = []
	for xw in xs:
		var t := (xw - cx) / span
		var hgt := peak * pow(maxf(0.0, 1.0 - t * t), 1.15) + rng.randf_range(-0.7, 0.9) * (1.0 - absf(t)) * 2.0
		var back := 38.0 * pow(maxf(0.0, 1.0 - absf(t)), 0.8)
		var s2 := proj.focal / maxf(proj.near, dz0 + back)
		top_pts.append(Vector2(proj.screen.x * 0.5 + (xw0 + xw) * s2, hy - (yw0 + maxf(0.0, hgt) - _cam_y) * s2))
	for i in xs.size() - 1:
		var xa := xs[i]
		var xb := xs[i + 1]
		if xb - xa < 0.01:
			continue
		var a0 := x0 + xa * s
		var a1 := x0 + xb * s
		if maxf(a1, top_pts[i + 1].x) < -40.0 or minf(a0, top_pts[i].x) > proj.screen.x + 40.0:
			continue
		# bottom height per vertex: headwall top above the opening, ground elsewhere (no cracks)
		var bha := head_h if (xa >= xl - 0.001 and xa <= xr + 0.001) else 0.0
		var bhb := head_h if (xb >= xl - 0.001 and xb <= xr + 0.001) else 0.0
		var ta := top_pts[i]
		var tb := top_pts[i + 1]
		var ba := Vector2(a0, minf(y0 - bha * s, maxf(ta.y, y0 - bha * s)))
		var bb := Vector2(a1, minf(y0 - bhb * s, maxf(tb.y, y0 - bhb * s)))
		if ta.y < ba.y - 0.1 or tb.y < bb.y - 0.1:
			var cba := veg_bot.lerp(veg_top, clampf(bha / peak, 0.0, 1.0))
			var cbb := veg_bot.lerp(veg_top, clampf(bhb / peak, 0.0, 1.0))
			batch.quad4(ta, tb, bb, ba, veg_top, veg_top, cbb, cba)
	# conifers along the ridge
	var tree_c := veg_top.darkened(0.25)
	for i in range(1, top_pts.size() - 1):
		var tp := top_pts[i]
		if tp.y > y0 - 2.0 * s or rng.randf() < 0.25:
			continue
		var ts := proj.focal / maxf(proj.near, dz0 + 30.0) * rng.randf_range(5.0, 9.0)
		batch.tri(Vector2(tp.x, tp.y - ts), Vector2(tp.x + ts * 0.33, tp.y + 2.0), Vector2(tp.x - ts * 0.33, tp.y + 2.0), tree_c)
	# wingwalls holding the hill, headwall above the opening
	var ol := x0 + xl * s
	var orr := x0 + xr * s
	var wing := 9.0
	batch.quad4(Vector2(x0 + (xl - wing) * s, y0 - 0.6 * s), Vector2(ol, y0 - head_h * s), Vector2(ol, y0), Vector2(x0 + (xl - wing) * s, y0), conc_dark, conc, conc, conc_dark)
	batch.quad4(Vector2(orr, y0 - head_h * s), Vector2(x0 + (xr + wing) * s, y0 - 0.6 * s), Vector2(x0 + (xr + wing) * s, y0), Vector2(orr, y0), conc, conc_dark, conc_dark, conc)
	batch.rect(Rect2(ol - 0.6 * s, y0 - (head_h + 0.35) * s, orr - ol + 1.2 * s, 0.45 * s), conc_dark)
	batch.rect(Rect2(ol, y0 - head_h * s, orr - ol, (head_h - ceil_h) * s), conc)
	# chamfered frame around the opening
	var ot := y0 - ceil_h * s
	var ow := y0 - wall_h * s
	var fw := 0.8 * s
	batch.tri(Vector2(ol, ow), Vector2(ol, ot), Vector2(ol + ins * s, ot), conc)
	batch.tri(Vector2(orr, ow), Vector2(orr, ot), Vector2(orr - ins * s, ot), conc)
	batch.quad(Vector2(ol - fw * 0.2, ow), Vector2(ol + fw * 0.6, ow), Vector2(ol + fw * 0.6, y0), Vector2(ol - fw * 0.2, y0), conc_dark)
	batch.quad(Vector2(orr - fw * 0.6, ow), Vector2(orr + fw * 0.2, ow), Vector2(orr + fw * 0.2, y0), Vector2(orr - fw * 0.6, y0), conc_dark)
	batch.quad(Vector2(ol, ow), Vector2(ol + ins * s, ot), Vector2(ol + ins * s + fw * 0.6, ot + fw * 0.6), Vector2(ol + fw * 0.6, ow), conc_dark)
	batch.quad(Vector2(orr - ins * s, ot), Vector2(orr, ow), Vector2(orr - fw * 0.6, ow), Vector2(orr - ins * s - fw * 0.6, ot + fw * 0.6), conc_dark)
	batch.quad(Vector2(ol + ins * s, ot), Vector2(orr - ins * s, ot), Vector2(orr - ins * s - fw * 0.6, ot + fw * 0.6), Vector2(ol + ins * s + fw * 0.6, ot + fw * 0.6), conc_dark)


func _fuel_structures(a: int, b: int, sa: TrackSegment, ra: float, rb: float) -> void:
	var fz := sa.fuel_zone
	var island_h := 0.18
	if (fz & TrackSegment.FUEL_ISLAND) != 0:
		_gstrip(a, b, ra + 0.35, ra + 2.3, rb + 0.35, rb + 2.3, Color("c9c6bd"), island_h, 1, 0.6)
		_vstrip(a, b, ra + 0.35, rb + 0.35, 0.0, island_h, Color("e0c030"))
	if (fz & TrackSegment.FUEL_CANOPY) != 0:
		var h0 := 5.6
		var x0a := ra - 0.5
		var x1a := ra + 4.6
		var x0b := rb - 0.5
		var x1b := rb + 4.6
		_hstrip(a, b, x0a, x1a, x0b, x1b, h0, Color("9a9c9b"))
		_hstrip(a, b, x0a, x0a + 0.6, x0b, x0b + 0.6, h0 - 0.01, Color("6f7170"))
		_vstrip(a, b, x0a, x0b, h0, h0 + 0.35, Color("c8102e"), 0.5)
		_vstrip(a, b, x0a, x0b, h0 + 0.35, h0 + 0.85, Color("f2f2f0"), 0.5)
		if sa.index % 2 == 0 and b - a == 1:
			var lamp := Color(1, 1, 0.96) if _lights > 0.05 else _rowc(Color("e8e8e2"), a)
			for lx: float in [ra + 0.8, ra + 2.8]:
				var p := _proj_at(a, 0.5, lx, h0 - 0.02)
				if p.z > 0.0:
					batch.rect(Rect2(p.x - 0.5 * p.z, p.y - 0.18 * p.z, 1.0 * p.z, 0.36 * p.z), lamp)
					if _lights > 0.05:
						_glow(Vector2(p.x, p.y), maxf(3.0, 1.8 * p.z), Color(1, 0.97, 0.9, 0.3 * _lights))
		if (fz & TrackSegment.FUEL_CANOPY_FRONT) != 0:
			var s := _ss[a]
			var xx := _sx[a]
			var yy := _sy[a]
			var fasc := Rect2(xx + x0a * s, yy - (h0 + 0.85) * s, (x1a - x0a) * s, 0.85 * s)
			batch.rect(fasc, _shade(Color("f2f2f0"), a, x0a, 0.6))
			batch.rect(Rect2(fasc.position.x, fasc.end.y - 0.35 * s, fasc.size.x, 0.35 * s), _shade(Color("c8102e"), a, x0a, 0.6))
			# pillars at the island
			var pw := maxf(1.0, 0.3 * s)
			var pc := _shade(Color("d0d0cc"), a, ra, 0.5)
			batch.rect(Rect2(xx + (ra + 1.3) * s - pw * 0.5, yy - h0 * s, pw, (h0 - island_h) * s), pc)
			if fasc.size.y > 9.0:
				signs.text(tr("TANKSTELLE"), Vector2(fasc.get_center().x, fasc.position.y + 0.45 * s), 0.32 * s, _shade(Color("1d4f9c"), a, x0a, 0.6), fasc.size.x * 0.8)


func _border_cover(a: int, b: int, sa: TrackSegment, xla: float, xra: float, xlb: float, xrb: float) -> void:
	var h0 := 6.0
	_hstrip(a, b, xla - 1.0, xra + 1.0, xlb - 1.0, xrb + 1.0, h0, Color("8e959c"))
	if _lights > 0.05 and sa.index % 2 == 0:
		for t: float in [0.25, 0.5, 0.75]:
			var p := _proj_at(a, 0.5, lerpf(xla, xra, t), h0 - 0.05)
			if p.z > 0.0:
				batch.rect(Rect2(p.x - 0.9 * p.z, p.y - 0.1 * p.z, 1.8 * p.z, 0.2 * p.z), Color(1, 1, 0.95, _lights))
				_glow(Vector2(p.x, p.y), maxf(3.0, 2.0 * p.z), Color(1, 0.97, 0.9, 0.3 * _lights))
	if sa.cover_front:
		var s := _ss[a]
		var xx := _sx[a]
		var yy := _sy[a]
		var pw := maxf(1.0, 0.55 * s)
		var pc := _shade(Color("b8bcc2"), a, 0.0, 0.5)
		batch.rect(Rect2(xx + (xla - 0.6) * s - pw * 0.5, yy - h0 * s, pw, h0 * s), pc)
		batch.rect(Rect2(xx + (xra + 0.6) * s - pw * 0.5, yy - h0 * s, pw, h0 * s), pc)
		var fasc := Rect2(xx + (xla - 1.6) * s, yy - (h0 + 1.6) * s, (xra - xla + 3.2) * s, 1.6 * s)
		batch.rect(fasc, _shade(Color("f0f0ec"), a, 0.0, 0.8))
		batch.rect(Rect2(fasc.position.x, fasc.end.y - 0.3 * s, fasc.size.x, 0.3 * s), _shade(SignPainter.EU_BLUE, a, 0.0, 0.8))
		var name := ""
		for bd in track.plan.borders:
			if str(bd["to"]) == sa.country_to:
				name = str(bd.get("name_local", bd["to"]))
		if fasc.size.y > 6.0:
			var blue := _shade(SignPainter.EU_BLUE, a, 0.0, 0.8)
			var c := Vector2(fasc.position.x + 1.2 * s, fasc.position.y + 0.65 * s)
			batch.rect(Rect2(c.x - 0.6 * s, c.y - 0.55 * s, 1.2 * s, 1.1 * s), blue)
			for i in 12:
				var ang := TAU * float(i) / 12.0
				var sp := c + Vector2(cos(ang), sin(ang)) * 0.36 * s
				batch.rect(Rect2(sp.x - 0.05 * s, sp.y - 0.05 * s, 0.1 * s, 0.1 * s), _shade(SignPainter.EU_YELLOW, a, 0.0, 0.8))
			signs.text(name.to_upper(), Vector2(fasc.get_center().x, fasc.position.y + 0.95 * s), 0.55 * s, blue, fasc.size.x * 0.7)


# --- sprites and objects --------------------------------------------------------------------

func _draw_items(a: int, b: int, buckets: Dictionary) -> void:
	if b - a == 1 and not buckets.has(a):
		if _dz[a + 1] <= proj.near:
			return
		for p: Dictionary in _segs[a].sprites:
			_draw_item(a, p)
		return
	var items: Array = []
	for k in range(a, b):
		var seg := _segs[k]
		if _dz[k + 1] <= proj.near:
			continue
		for p: Dictionary in seg.sprites:
			items.append([k, p])
		if buckets.has(k):
			for c: Dictionary in buckets[k]:
				items.append([k, c])
	if items.is_empty():
		return
	if items.size() > 1:
		items.sort_custom(func(u: Array, v: Array) -> bool: return float((u[1] as Dictionary).get("z", 0.0)) > float((v[1] as Dictionary).get("z", 0.0)))
	for e: Array in items:
		_draw_item(int(e[0]), e[1])


func _item_alpha(k: int, dz: float) -> float:
	if _segs[k].tunnel:
		return 1.0 - pow(clampf((dz - 12.0) / _t_fog_m, 0.0, 1.0), 1.6)
	return 1.0 - pow(clampf((dz - _fog_start) / maxf(1.0, _vis - _fog_start), 0.0, 1.0), 2.0)


## True when a prop is drawn mirrored: sets rendered for the right roadside (tag mirror_left, or the
## scenery rule's "mirror") are mirrored on the left side, so their front faces the road on both sides.
static func prop_flipped(side: int, rule_mirror: bool, tag_mirror_left: bool) -> bool:
	return side < 0 and (rule_mirror or tag_mirror_left)


## Anchor x of an edge-aligned prop whose near edge (towards the road) shall be at x. extent = manifest
## extent_m [left, right] of the anchor in the unmirrored cell (metres at scale 1). On the right roadside
## the object's left side faces the road; on the left roadside its right side – or, when the sprite is
## mirrored, again its (mirrored) left side.
static func edge_anchor_x(x: float, side: int, flipped: bool, extent: Vector2, scale: float) -> float:
	return x + float(side) * (extent.x if (side > 0 or flipped) else extent.y) * scale


## Screen rect of a sprite cell of size w × h whose ground anchor (normalised, unmirrored cell) stands at
## p. A mirrored cell keeps the anchor at p: its anchor column becomes 1 - anchor.x.
static func sprite_dest(p: Vector2, w: float, h: float, anchor: Vector2, flip: bool) -> Rect2:
	var ax := (1.0 - anchor.x) if flip else anchor.x
	return Rect2(p.x - ax * w, p.y - anchor.y * h, w, h)


## Rect for draw_texture_rect_region that draws a cell mirrored into dest: Godot 4 keeps the position of
## a rect with negative width and only mirrors the texture (checked by tests/race/check_sprite_flip.gd),
## so the mirrored image covers exactly dest.
static func flipped_draw_rect(dest: Rect2) -> Rect2:
	return Rect2(dest.position, Vector2(-dest.size.x, dest.size.y))


## Per-prop data resolved once and cached in the prop dictionary ("_c"):
## [set id ("" = procedural or missing), sprite info, scale, x (edge-aligned), procedural kind, tint]
func _prep_prop(it: Dictionary) -> Array:
	var c: Variant = it.get("_c")
	if c != null:
		return c
	var x := float(it.get("x", 0.0))
	var res: Array
	var proc := str(it.get("proc", ""))
	var set_id := _resolve_set(it)
	if proc != "" and (_prefer_proc or set_id == ""):
		if it.has("align") and bool(it.get("landmark", false)):
			# procedural landmark: x is its near edge -> anchor at its middle
			x += float(int(it.get("side", 1))) * float(it.get("width_m", 30.0)) * 0.5 * float(it.get("scale", 1.0))
		res = ["", [], 1.0, x, proc, Color.WHITE]
	elif set_id == "":
		res = ["", [], 0.0, x, "", Color.WHITE]
	else:
		var info := _spinfo(set_id)
		var sc := _prop_scale(it, set_id)
		if it.has("fit_w"):
			# overhead structures (bridge portals) span the whole deck
			sc = float(it["fit_w"]) / maxf(0.5, (info[SI_OBJ] as Vector3).x)
		if it.has("align"):
			# "edge": x is the near edge of the object -> shift its anchor away from the road by the
			# object's extent towards the road (extent_m of the manifest, else half its width)
			var side := int(it.get("side", 1))
			x = edge_anchor_x(x, side, prop_flipped(side, bool(it.get("mirror", false)), bool(info[8])), info[7], sc)
		var tint := Color(str(it["tint"])) if it.has("tint") else Color.WHITE
		if set_id != str(it.get("set", "")) and it.has("fallback_tint"):
			tint *= Color(str(it["fallback_tint"]))
		res = [set_id, info, sc, x, "", tint]
	it["_c"] = res
	return res


func _draw_item(k: int, it: Dictionary) -> void:
	var z := float(it.get("z", _zw[k]))
	var f := clampf((z - _zw[k]) / _seg_len, 0.0, 1.0)
	var kind := str(it.get("kind", "prop"))
	if kind == "box":
		_draw_box_item(it)
		return
	if kind == "prop":
		var pc := _prep_prop(it)
		var info: Array = pc[1]
		var px := float(pc[3])
		if bool(it.get("landmark", false)):
			var pl := _proj_at(k, f, px, 0.0)
			if pl.z > 0.0:
				_draw_landmark(it, pc, pl, proj.focal / pl.z)
			return
		if not info.is_empty():
			# sprite prop: cheap culling (size, screen) before any shading work
			var p := _proj_at(k, f, px, float(it.get("h", 0.0)))
			if p.z <= 0.0:
				return
			var wpx := (info[3] as Vector2).x / float(info[1]) * p.z * float(pc[2])
			if wpx < 0.8 or p.x + wpx * 0.5 < -4.0 or p.x - wpx * 0.5 > proj.screen.x + 4.0:
				return
			var dz := proj.focal / p.z
			var alpha := _item_alpha(k, dz)
			if alpha <= 0.02:
				return
			_ctx(_segs[k].tunnel)
			var light := _light(z, px) if _lit and dz < _hl_range + 40.0 else 0.0
			_draw_prop_info(k, it, pc, p, alpha, light)
			return
		var proc := str(pc[4])
		if proc == "":
			return
		it["obj"] = proc
		kind = "object"
	var x := float(it.get("x", 0.0))
	var p2 := _proj_at(k, f, x, 0.0)
	if p2.z <= 0.0 or p2.z < 0.35 or p2.x < -12.0 * p2.z - 20.0 or p2.x > proj.screen.x + 12.0 * p2.z + 20.0:
		return
	var dz2 := proj.focal / p2.z
	var alpha2 := _item_alpha(k, dz2)
	if alpha2 <= 0.02:
		return
	_ctx(_segs[k].tunnel)
	var light2 := 0.0
	if _lit and dz2 < _hl_range + 40.0:
		light2 = _light(z, x)
	match kind:
		"sign":
			var lit := Palette.lit(_pal_tun if _segs[k].tunnel else _pal_out, light2 * 1.5)
			if _cam_in_tunnel and not _segs[k].tunnel:
				lit = Color(minf(1.6, lit.r * 1.5 + 0.2), minf(1.6, lit.g * 1.5 + 0.2), minf(1.6, lit.b * 1.5 + 0.2))
			lit = lit.lerp(_fogc, _ftx[k] * 0.85)
			var edges_px := Vector2.ZERO
			if int(it.get("side", 1)) == 0:
				var seg := _segs[k]
				var l := -seg.lanes * _lw * 0.5 - _sh
				var r := seg.lanes * _lw * 0.5 + seg.fuel_lane * _lw + _sh
				edges_px = Vector2(p2.x + (l - x) * p2.z, p2.x + (r - x) * p2.z)
			if not it.has("road"):
				it["road"] = _segs[k].road
			# scale < 1: e.g. a sign fitted onto a tunnel wall (Track._mount_on_tunnel_wall)
			var ssc := float(it.get("scale", 1.0))
			signs.draw(it, p2 if ssc == 1.0 else Vector3(p2.x, p2.y, p2.z * ssc), lit, alpha2, edges_px)
			if str(it.get("sign", "")) == "start" and float(view.get("countdown", -1000.0)) > -2.0:
				_start_light_glows(p2, edges_px)
		"car":
			_draw_car(k, f, it, p2, alpha2, light2)
		"object":
			_draw_object(k, str(it.get("obj", "")), it, p2, alpha2, light2)


func _start_light_glows(p: Vector3, _edges_px: Vector2) -> void:
	var s := p.z
	var cd := float(view.get("countdown", -1000.0))
	var on := 0 if cd <= 0.0 else clampi(4 - int(ceil(cd)), 1, 3)
	for i in 3:
		var c := Vector2(p.x + (1.4 + float(i) * 1.15) * s, p.y - 7.0 * s + 0.8 * s)
		if cd <= 0.0:
			_glow(c, 1.4 * s, Color(0.2, 1.0, 0.3, 0.6))
		elif i < on:
			_glow(c, 1.4 * s, Color(1.0, 0.15, 0.1, 0.6))


## Cached sprite metadata (indices SI_*): texture, pixels per metre, anchor, cell size, {angle name: index}
## (incl. the legacy names l2/l1/c/r1/r2), {layer: row}, half width, extent, mirror_left, yaw per angle,
## grid columns, angle count, perspective?, supersample, camera distance, box?, box parts, box lights,
## texture size, object size (w, l, h) – or [] when the set or its texture does not exist (skipped).
func _spinfo(set_id: String) -> Array:
	var c: Variant = _sp_cache.get(set_id)
	if c != null:
		return c
	var info: Array = []
	var tex := SpriteDB.texture(set_id) if set_id != "" else null
	if tex != null:
		var s := SpriteDB.get_set(set_id)
		var angles: Array = s["angles"]
		var cols := {}
		for i in angles.size():
			cols[str(angles[i])] = i
		for a: String in ["l2", "l1", "c", "r1", "r2"]:
			if not cols.has(a):
				cols[a] = angles.find(SpriteDB.resolve_angle(set_id, a))
		var rows := {}
		var layers: Array = s["layers"]
		for i in layers.size():
			rows[str(layers[i])] = i
		var obj: Dictionary = SpriteDB.object_size(set_id)
		var cell := SpriteDB.cell_size(set_id)
		var ppm := SpriteDB.pixels_per_meter(set_id)
		var half_w := float(obj.get("width_m", cell.x / maxf(ppm, 0.001) * 0.8)) * 0.5
		# extent_m (Blender manifest): distance from the anchor to the near side when placed right / left
		var ext: Array = s.get("extent_m", [half_w, half_w])
		var extent := Vector2(float(ext[0]), float(ext[1])) if ext.size() >= 2 else Vector2(half_w, half_w)
		var mirror_left := (s.get("tags", []) as Array).has("mirror_left")
		var persp := SpriteDB.projection(set_id) == "perspective"
		var cam := SpriteDB.camera(set_id)
		var cam_d := float(cam.get("distance_m", proj.cam_distance))
		if persp and not _cam_warned and _camera_differs(cam):
			_cam_warned = true
			push_warning("RoadRenderer: %s wurde für eine andere Kamera gerendert als render.* – Spieler-Sprites neu rendern" % set_id)
		var obj_v := Vector3(float(obj.get("width_m", half_w * 2.0)), float(obj.get("length_m", 4.5)), float(obj.get("height_m", 1.5)))
		var tex_size := tex.get_size()
		if SpriteDB.is_box(set_id):
			# box faces are seen at grazing angles: anisotropic filtering keeps the side texture sharp
			var ct := CanvasTexture.new()
			ct.diffuse_texture = tex
			ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			tex = ct
		info = [tex, ppm, SpriteDB.anchor(set_id), cell, cols, rows, half_w, extent, mirror_left,
			SpriteDB.yaw_list(set_id), SpriteDB.grid_cols(set_id), angles.size(), persp, SpriteDB.supersample(set_id), cam_d,
			SpriteDB.is_box(set_id), SpriteDB.box_parts(set_id), SpriteDB.box_lights(set_id), tex_size, obj_v,
			s.has("pivot") and SpriteDB.pivot(set_id) == "rear" and not persp and not SpriteDB.is_box(set_id),
			deg_to_rad(float(s.get("elevation_deg", 0.0)))]
	_sp_cache[set_id] = info
	return info


## True when the render camera of a perspective set differs from the game camera (render.*).
func _camera_differs(cam: Dictionary) -> bool:
	if cam.is_empty():
		return false
	var r: Dictionary = ConfigLoader.lookup(cfg, "render", {})
	return absf(float(cam.get("height_m", proj.cam_height)) - proj.cam_height) > 0.01 \
		or absf(float(cam.get("distance_m", proj.cam_distance)) - proj.cam_distance) > 0.01 \
		or absf(float(cam.get("fov_deg", 84.0)) - float(r.get("fov_deg", 84.0))) > 0.01 \
		or absf(float(cam.get("horizon_y_frac", 0.45)) - float(r.get("horizon_y_frac", 0.45))) > 0.001


func _has_layer(set_id: String, layer: String) -> bool:
	var info := _spinfo(set_id)
	return not info.is_empty() and (info[SI_ROWS] as Dictionary).has(layer)


## Sprite set to use for a prop: the set itself, its fallback, or "" if neither exists.
func _resolve_set(it: Dictionary) -> String:
	var set_id := str(it.get("set", ""))
	if set_id != "" and not _spinfo(set_id).is_empty():
		return set_id
	var fb := str(it.get("fallback", ""))
	if fb != "" and not _spinfo(fb).is_empty():
		return fb
	return ""


## Scale of a prop including fallback_scale when its fallback set is drawn.
func _prop_scale(it: Dictionary, set_id: String) -> float:
	var sc := float(it.get("scale", 1.0))
	if set_id != str(it.get("set", "")):
		sc *= float(it.get("fallback_scale", 1.0))
	return sc


## Draws a sprite cell; returns its screen rect (size 0 when skipped).
func _sprite(set_id: String, angle: String, layer: String, p: Vector3, scale: float, modulate: Color, flip: bool = false) -> Rect2:
	var info := _spinfo(set_id)
	if info.is_empty():
		return Rect2()
	return _sprite_i(info, angle, layer, p, scale, modulate, flip)


func _sprite_i(info: Array, angle: String, layer: String, p: Vector3, scale: float, modulate: Color, flip: bool = false) -> Rect2:
	return _sprite_cell(info, int((info[SI_COLS] as Dictionary).get(angle, 0)), layer, p, scale, modulate, flip)


## Source rect of the cell (angle index, layer row) in the sheet (grid layout, contract §1).
static func cell_src(info: Array, angle_index: int, row: int) -> Rect2:
	var cell: Vector2 = info[SI_CELL]
	var i := row * int(info[SI_NANG]) + clampi(angle_index, 0, int(info[SI_NANG]) - 1)
	var g := maxi(1, int(info[SI_GRID]))
	return Rect2(float(i % g) * cell.x, float(i / g) * cell.y, cell.x, cell.y)


## Draws the cell of angle index `ai` on `layer` with its anchor at p (ortho: width from pixels per metre and
## the scale p.z); returns its screen rect (size 0 when skipped).
func _sprite_cell(info: Array, ai: int, layer: String, p: Vector3, scale: float, modulate: Color, flip: bool = false) -> Rect2:
	var row := int((info[SI_ROWS] as Dictionary).get(layer, -1))
	if row < 0:
		return Rect2()
	var cell: Vector2 = info[SI_CELL]
	var w := cell.x / float(info[SI_PPM]) * p.z * scale
	var h := w * cell.y / cell.x
	if w < 0.8 or w > proj.screen.x * 5.0:
		return Rect2()
	var dest := sprite_dest(Vector2(p.x, p.y), w, h, info[SI_ANCHOR], flip)
	if dest.position.x > proj.screen.x + 4.0 or dest.end.x < -4.0 or dest.position.y > proj.screen.y + 4.0 or dest.end.y < -4.0:
		return Rect2()
	var tex: Texture2D = info[SI_TEX]
	batch.flush()
	draw_texture_rect_region(tex, flipped_draw_rect(dest) if flip else dest, cell_src(info, ai, row), modulate)
	return dest


func _modulate(k: int, light: float, alpha: float, reflect: float = 0.6) -> Color:
	var amb := _amb
	var c := Color(minf(1.5, amb.r + light * reflect), minf(1.5, amb.g + light * reflect * 0.95), minf(1.5, amb.b + light * reflect * 0.85))
	# approximate fog for textures: tint towards the (brightened) fog colour and fade out
	var fog := _fogc * 1.25
	c = c.lerp(fog, _ftx[k] * 0.7)
	c.a = alpha
	return c


func _draw_prop_info(k: int, it: Dictionary, pc: Array, p: Vector3, alpha: float, light: float) -> void:
	var info: Array = pc[1]
	var scale := float(pc[2])
	# props rendered for the right roadside (tag mirror_left) are mirrored on the left side
	var flip := prop_flipped(int(it.get("side", 1)), bool(it.get("mirror", false)), bool(info[8]))
	var mod := _modulate(k, light, alpha)
	var tint: Color = pc[5]
	if tint != Color.WHITE:
		mod = Color(mod.r * tint.r, mod.g * tint.g, mod.b * tint.b, mod.a)
	var r := _sprite_i(info, "c", "base", p, scale, mod, flip)
	if r.size.x <= 0.0:
		return
	if _lights > 0.05 and (info[5] as Dictionary).has("lights"):
		_sprite_i(info, "c", "lights", p, scale, Color(1, 1, 1, alpha * _lights), flip)


# --- vehicles (docs/fahrzeug-darstellung.md, docs/renn-modul.md §8) ------------------------------------

## Once per frame: simulation time step for the pose smoothing (0 while paused or frozen); forgets
## vehicles that were not drawn for a while.
func _pose_tick() -> void:
	var t := float(view.get("time", 0.0))
	_pose_dt = 0.0 if _pose_last_t < 0.0 else clampf(t - _pose_last_t, 0.0, 0.1)
	_pose_last_t = t
	_pose_frame += 1
	if _pose_frame % 120 == 0:
		for id: int in _poses.keys():
			if _pose_frame - int((_poses[id] as PackedFloat64Array)[6]) > 240:
				_poses.erase(id)


## Cell (angle index) of an ortho vehicle sprite rotated about its rear (traffic, police): display yaw from
## the contract formula with the vehicle length (VehiclePose.ortho_yaw: rear depth and lateral offset, road
## heading as the chord from the rear to the front, own heading from the lateral speed during lane changes),
## critically damped per vehicle id (render.vehicle_yaw_smooth_s), cell hysteresis
## (render.vehicle_cell_hysteresis). An explicit "angle" in the item forces that cell.
func _vehicle_cell(k: int, f: float, it: Dictionary, info: Array) -> int:
	if it.has("angle"):
		return int((info[SI_COLS] as Dictionary).get(str(it["angle"]), 0))
	var length := float(it.get("length", (info[SI_OBJ] as Vector3).y))
	var z := float(it.get("z", _zw[k]))
	var x := float(it.get("x", 0.0))
	var speed := float(it.get("speed", 100.0)) / 3.6
	var d_r := lerpf(_dz[k], _dz[k + 1], f)
	var xr_road := lerpf(_xw[k], _xw[k + 1], f)
	var h := VehiclePose.chord_heading(xr_road, road_at(z + length).x, length)
	var id := int(it.get("id", NO_ID))
	var known := id != NO_ID and _poses.has(id)
	var st: PackedFloat64Array
	if known:
		st = _poses[id]
	else:
		st = PackedFloat64Array([0.0, 0.0, -1.0, x, _pose_last_t, 0.0, 0.0])
	# lateral speed = change of x over simulation time (lane changes, lane geometry)
	if known and _pose_last_t > st[4] + 0.0005:
		st[5] = (x - st[3]) / (_pose_last_t - st[4])
		st[3] = x
		st[4] = _pose_last_t
	var target := VehiclePose.ortho_yaw(d_r, xr_road + x, h, VehiclePose.own_heading(st[5], speed), length, _veh_max_deg)
	if known:
		var r := VehiclePose.damp(st[0], st[1], target, _pose_dt, _veh_tau)
		st[0] = r.x
		st[1] = r.y
	else:
		st[0] = target
		st[1] = 0.0
	var cell := VehiclePose.pick_cell(info[SI_YAWS], rad_to_deg(st[0]), int(st[2]), _veh_hyst)
	st[2] = float(cell)
	st[6] = float(_pose_frame)
	if id != NO_ID:
		_poses[id] = st
	return cell


## Smoothed display yaw (degrees) of a vehicle id in the last frame (tests, debug); NAN if unknown.
func vehicle_yaw_deg(id: int) -> float:
	if not _poses.has(id):
		return NAN
	return rad_to_deg((_poses[id] as PackedFloat64Array)[0])


## Cell (angle index) shown for a vehicle id in the last frame (tests, debug); -1 if unknown.
func vehicle_cell(id: int) -> int:
	if not _poses.has(id):
		return -1
	return int((_poses[id] as PackedFloat64Array)[2])


func _draw_car(k: int, f: float, it: Dictionary, p: Vector3, alpha: float, light: float) -> void:
	var set_id := str(it.get("set", ""))
	var info := _spinfo(set_id)
	if info.is_empty():
		return
	if bool(it.get("player", false)):
		_draw_player(k, it, info, p, alpha, light)   # updates the pose also while blinking
		return
	if not bool(it.get("visible", true)):
		return
	var cell := _vehicle_cell(k, f, it, info)
	var mod := _modulate(k, light, alpha, 0.55)
	var rows: Dictionary = info[SI_ROWS]
	var lights := _lights if not _segs[k].tunnel else 1.0
	var tail := maxf(float(it.get("tail", 0.0)), lights)
	var brake := float(it.get("brake", 0.0))
	var light_alpha := alpha if _lights < 0.3 else minf(1.0, alpha * 1.6)
	var beacon := str(it.get("beacon", ""))
	# layers [name, colour]: base, then the light overlays
	var layers: Array = [["base", mod]]
	if tail > 0.05 and rows.has("tail"):
		layers.append(["tail", Color(1, 1, 1, light_alpha * tail)])
	if brake > 0.05 and rows.has("brake"):
		layers.append(["brake", Color(1, 1, 1, light_alpha * brake)])
	if beacon != "" and rows.has("beacon_" + beacon):
		layers.append(["beacon_" + beacon, Color(1, 1, 1, light_alpha)])
	var warp := _car_warp(it, info, cell, p)
	if not warp.is_empty():
		if not _draw_warped(info, cell, layers, warp):
			return
	else:
		var r := _sprite_cell(info, cell, "base", p, 1.0, mod)
		if r.size.x <= 0.0:
			return
		for l: Array in layers.slice(1):
			_sprite_cell(info, cell, str(l[0]), p, 1.0, l[1])
	var obj: Vector3 = info[SI_OBJ]
	var cw := obj.x
	var ch := obj.z
	var s := p.z
	# glows: tail/brake lights (night or braking), police beacon; they follow the yawed rear (pivot) a little
	var glow_a := clampf(tail * lights * 0.9 + brake * (0.35 + 0.4 * lights), 0.0, 1.0) * alpha
	var yaw := deg_to_rad((info[SI_YAWS] as PackedFloat32Array)[cell]) if cell >= 0 else 0.0
	var gx := cw * 0.38 * cos(yaw) * s
	if glow_a > 0.03:
		var gy := p.y - ch * 0.42 * s
		var gr := clampf((0.32 + brake * 0.12 + lights * 0.18) * s, 2.0, 70.0)
		var gcol := Color(1.0, 0.16, 0.06, 0.5 * glow_a)
		_glow(Vector2(p.x - gx, gy), gr, gcol)
		_glow(Vector2(p.x + gx, gy), gr, gcol)
		if _wet > 0.0 and lights > 0.2:
			_wet_reflections(PackedVector2Array([Vector2(p.x - gx, p.y), Vector2(p.x + gx, p.y)]), s, 0.22 * glow_a * _wet, 0.8 * s)
	if beacon != "":
		var bc := Color(0.25, 0.45, 1.0, 0.7 * alpha) if beacon == "a" else Color(0.35, 0.55, 1.0, 0.45 * alpha)
		var bx := p.x + (-0.25 if beacon == "a" else 0.25) * s + 2.2 * sin(yaw) * s
		_glow(Vector2(bx, p.y - (ch + 0.1) * s), maxf(3.0, (1.2 + lights) * s), bc)
	# spray in the rain
	var spd := float(it.get("speed", 100.0))
	if _wet > 0.0 and not _segs[k].tunnel and spd > 40.0:
		var sa := clampf((spd - 40.0) / 120.0, 0.0, 1.0) * 0.28 * alpha * _wet
		var spray := Color(_fogc.lerp(Color(0.9, 0.92, 0.95), 0.5), sa)
		batch.ellipse(Vector2(p.x, p.y - 0.45 * s), Vector2(cw * 0.75 * s, 0.6 * s), spray, Color(spray, 0.0), 12)


## Screen columns of the perspective flank warp (VehiclePose.warp_columns / warp_screen) for a traffic or
## police car near the camera; empty when the plain sprite is drawn (render.vehicle_warp off, sets without an
## explicit rear pivot, far away – vehicle length / rear depth below render.vehicle_warp_min_ratio – or hardly
## any flank visible). The rotated ortho sprite places the front correctly but draws it at the scale of the
## rear; the warp draws every strip of the cell at its own depth (docs/renn-modul.md §8).
func _car_warp(it: Dictionary, info: Array, cell: int, p: Vector3) -> PackedFloat32Array:
	var none := PackedFloat32Array()
	if not _veh_warp or not bool(info[SI_REAR]) or p.z <= 0.0:
		return none
	var yaws: PackedFloat32Array = info[SI_YAWS]
	if cell < 0 or cell >= yaws.size():
		return none
	var psi := deg_to_rad(yaws[cell])
	var obj: Vector3 = info[SI_OBJ]
	var length := float(it.get("length", obj.y))
	var d_r := proj.focal / p.z
	if absf(psi) < deg_to_rad(1.0) or length / d_r < _veh_warp_ratio:
		return none
	var cellv: Vector2 = info[SI_CELL]
	var ppm := maxf(float(info[SI_PPM]), 0.001)
	var w := cellv.x / ppm * p.z
	if w < 0.8 or w > proj.screen.x * 5.0:
		return none
	var an: Vector2 = info[SI_ANCHOR]
	var n := clampi(int(ceil(length / d_r * 12.0)), 2, 16)
	var cols := VehiclePose.warp_columns(psi, obj.x, length, -an.x * cellv.x / ppm, (1.0 - an.x) * cellv.x / ppm, n)
	if cols.is_empty():
		return none
	var tan_c := 0.0
	var id := int(it.get("id", NO_ID))
	if _poses.has(id):
		tan_c = tan(VehiclePose.own_heading((_poses[id] as PackedFloat64Array)[5], float(it.get("speed", 100.0)) / 3.6))
	return VehiclePose.warp_screen(cols, psi, float(it.get("z", 0.0)), float(it.get("x", 0.0)), tan_c, road_at,
		proj.focal, proj.screen.x * 0.5, proj.horizon_y, proj.near, an.y * cellv.y / ppm, (an.y - 1.0) * cellv.y / ppm,
		float(info[SI_ELEV]))


## Draws the layers ([name, colour], base first) of a cell through the warp columns as one triangle array
## (one quad per strip and layer). Returns false when the car is off screen (nothing drawn).
func _draw_warped(info: Array, cell: int, layers: Array, warp: PackedFloat32Array) -> bool:
	var nc := warp.size() / 4
	if nc < 2:
		return false
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for i in nc:
		x0 = minf(x0, warp[i * 4 + 1])
		x1 = maxf(x1, warp[i * 4 + 1])
		y0 = minf(y0, warp[i * 4 + 2])
		y1 = maxf(y1, warp[i * 4 + 3])
	if x1 < -4.0 or x0 > proj.screen.x + 4.0 or y1 < -4.0 or y0 > proj.screen.y + 4.0:
		return false
	var cellv: Vector2 = info[SI_CELL]
	var ppm := float(info[SI_PPM])
	var au := (info[SI_ANCHOR] as Vector2).x * cellv.x
	var ts: Vector2 = info[SI_TEXSIZE]
	var rows: Dictionary = info[SI_ROWS]
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for l: Array in layers:
		var src := cell_src(info, cell, int(rows.get(str(l[0]), 0)))
		var col: Color = l[1]
		var v0 := (src.position.y + 0.5) / ts.y
		var v1 := (src.end.y - 0.5) / ts.y
		for i in nc - 1:
			var a := i * 4
			var b := a + 4
			var ua := (src.position.x + clampf(au + warp[a] * ppm, 0.5, cellv.x - 0.5)) / ts.x
			var ub := (src.position.x + clampf(au + warp[b] * ppm, 0.5, cellv.x - 0.5)) / ts.x
			# the column mapping is exact; a strip whose edges differ in height (trapezoid) is cut into rows,
			# otherwise its two affine triangles bend horizontal lines of the texture (zigzag near the camera)
			var dh := absf((warp[a + 3] - warp[a + 2]) - (warp[b + 3] - warp[b + 2]))
			var m := clampi(int(ceil(sqrt(dh / 1.5))), 1, 10)
			for j in m:
				var f0 := float(j) / float(m)
				var f1 := float(j + 1) / float(m)
				var base := pts.size()
				pts.append(Vector2(warp[a + 1], lerpf(warp[a + 2], warp[a + 3], f0)))
				pts.append(Vector2(warp[b + 1], lerpf(warp[b + 2], warp[b + 3], f0)))
				pts.append(Vector2(warp[b + 1], lerpf(warp[b + 2], warp[b + 3], f1)))
				pts.append(Vector2(warp[a + 1], lerpf(warp[a + 2], warp[a + 3], f1)))
				uvs.append(Vector2(ua, lerpf(v0, v1, f0)))
				uvs.append(Vector2(ub, lerpf(v0, v1, f0)))
				uvs.append(Vector2(ub, lerpf(v0, v1, f1)))
				uvs.append(Vector2(ua, lerpf(v0, v1, f1)))
				for q in 4:
					cols.append(col)
				idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	batch.flush()
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols, uvs, PackedInt32Array(),
		PackedFloat32Array(), (info[SI_TEX] as Texture2D).get_rid())
	batch.triangles += idx.size() / 3
	batch.commands += 1
	return true


## Streaky reflections of rear lights on the wet road below the given ground points (soft, fading downwards).
func _wet_reflections(points: PackedVector2Array, s: float, a: float, length: float) -> void:
	var rc := Color(1.0, 0.22, 0.12, a)
	for q in points:
		batch.quad4(Vector2(q.x - 0.08 * s, q.y - 0.02 * s), Vector2(q.x + 0.08 * s, q.y - 0.02 * s), Vector2(q.x + 0.14 * s, q.y + length), Vector2(q.x - 0.14 * s, q.y + length), rc, rc, Color(rc, 0.0), Color(rc, 0.0))


## Visible yaw and body roll of the player car (smoothed, render.player_*): target from
## VehiclePose.player_yaw_target (curve look-ahead, steering, lane change, understeer, view angle), roll from
## the lateral acceleration (road curvature at the car + change of the steering lateral speed).
func _update_player_pose(it: Dictionary, zc: float, xc: float, dc: float, speed: float) -> void:
	var lat := float(it.get("lat_speed", 0.0))
	var curve := track.curve_at(zc) if track != null else 0.0
	var heading := road_heading_at(zc + _pl_lookahead)
	var target := VehiclePose.player_yaw_target(heading, float(it.get("steer", 0.0)), lat, speed,
		float(it.get("understeer", 0.0)), curve, atan2(xc, dc), _pl_k)
	var dlat := 0.0
	if _pl_init and _pose_dt > 0.0:
		dlat = (lat - _pl_lat) / _pose_dt
	if _pose_dt > 0.0 or not _pl_init:
		_pl_lat = lat
	var a_lat := clampf(speed * speed * curve / _curve_r1, -12.0, 12.0) + clampf(dlat, -12.0, 12.0)
	var roll_t := VehiclePose.roll_target_deg(a_lat, _roll_per, _roll_max)
	if not _pl_init:
		_pl_init = true
		_pl_yaw = target
		_pl_yaw_v = 0.0
		_pl_roll = roll_t
		_pl_roll_v = 0.0
		return
	var r := VehiclePose.damp(_pl_yaw, _pl_yaw_v, target, _pose_dt, _pl_tau)
	_pl_yaw = r.x
	_pl_yaw_v = r.y
	var q := VehiclePose.damp(_pl_roll, _pl_roll_v, roll_t, _pose_dt, _roll_tau)
	_pl_roll = clampf(q.x, -_roll_max, _roll_max)
	_pl_roll_v = q.y


## The player car. Perspective sets (contract §3): anchor on the projected ground point of the car centre,
## scale = render camera distance / actual depth / supersample. Old ortho sets keep the rear anchor. Both show
## the cell of the smoothed visible yaw (hysteresis) and lean by the body roll (rotation about the anchor);
## brake/tail layers, blinking (visible) and shake (draw transform) as before.
func _draw_player(k: int, it: Dictionary, info: Array, p_rear: Vector3, alpha: float, light: float) -> void:
	var length := float(it.get("length", 4.6))
	var zc := float(it["z"]) + length * 0.5
	var rc := road_at(zc)
	var dc := maxf(rc.z, proj.near)
	var xc := rc.x + float(it.get("x", 0.0))
	_update_player_pose(it, zc, xc, dc, float(it.get("speed", 0.0)) / 3.6)
	var cell: int
	if it.has("angle") and not it.has("steer"):
		cell = int((info[SI_COLS] as Dictionary).get(str(it["angle"]), 0))
	else:
		cell = VehiclePose.pick_cell(info[SI_YAWS], rad_to_deg(_pl_yaw), _pl_cell, _veh_hyst)
	_pl_cell = cell
	var persp := bool(info[SI_PERSP])
	var anchor_pt: Vector2
	var scale: float
	if persp:
		var s := proj.focal / dc
		anchor_pt = Vector2(proj.screen.x * 0.5 + xc * s, proj.horizon_y - rc.y * s)
		scale = VehiclePose.perspective_scale(float(info[SI_CAMD]), dc, float(info[SI_SS]))
	else:
		anchor_pt = Vector2(p_rear.x, p_rear.y)
		scale = p_rear.z / maxf(float(info[SI_PPM]), 0.001)
	var size: Vector2 = (info[SI_CELL] as Vector2) * scale
	var an: Vector2 = info[SI_ANCHOR]
	var dest := Rect2(-an * size, size)
	var roll := deg_to_rad(_pl_roll)
	last_player_pose = {"yaw_deg": rad_to_deg(_pl_yaw), "roll_deg": _pl_roll, "cell": cell, "anchor": anchor_pt,
		"scale": scale, "perspective": persp, "rect": Rect2(anchor_pt + dest.position, size)}
	if size.x < 1.0 or not bool(it.get("visible", true)):
		return
	var mod := _modulate(k, light, alpha, 0.55)
	mod = Color(minf(1.3, mod.r * 1.15 + 0.08), minf(1.3, mod.g * 1.15 + 0.08), minf(1.3, mod.b * 1.15 + 0.1), alpha)
	var rows: Dictionary = info[SI_ROWS]
	var tex: Texture2D = info[SI_TEX]
	var lights := _lights if not _segs[k].tunnel else 1.0
	var tail := maxf(float(it.get("tail", 0.0)), lights)
	var brake := float(it.get("brake", 0.0))
	var light_alpha := alpha if _lights < 0.3 else minf(1.0, alpha * 1.6)
	var shake: Vector2 = view.get("shake", Vector2.ZERO)
	batch.flush()
	draw_set_transform(anchor_pt + shake, roll, Vector2.ONE)
	draw_texture_rect_region(tex, dest, cell_src(info, cell, int(rows.get("base", 0))), mod)
	if tail > 0.05 and rows.has("tail"):
		draw_texture_rect_region(tex, dest, cell_src(info, cell, int(rows["tail"])), Color(1, 1, 1, light_alpha * tail))
	if brake > 0.05 and rows.has("brake"):
		draw_texture_rect_region(tex, dest, cell_src(info, cell, int(rows["brake"])), Color(1, 1, 1, light_alpha * brake))
	draw_set_transform(shake)
	# glows at the rear lights, rotated with the car
	var obj: Vector3 = info[SI_OBJ]
	var glow_a := clampf(tail * lights * 0.9 + brake * (0.35 + 0.4 * lights), 0.0, 1.0) * alpha
	if glow_a <= 0.03:
		return
	var pts := _player_light_points(persp, info, cell, anchor_pt, p_rear, dc, obj)
	var rot := Transform2D(roll, anchor_pt)
	var s_rear := pts[2].x
	var gr := clampf((0.32 + brake * 0.12 + lights * 0.18) * s_rear, 2.0, 70.0)
	var gcol := Color(1.0, 0.16, 0.06, 0.5 * glow_a)
	var ground := PackedVector2Array()
	for i in 2:
		_glow(rot * (pts[i] - anchor_pt), gr, gcol)
		ground.append(rot * (pts[3 + i] - anchor_pt))
	if _wet > 0.0 and lights > 0.2:
		_wet_reflections(ground, s_rear, 0.12 * glow_a * _wet, 0.45 * s_rear)


## Screen points of the player's rear lights before the roll: [left light, right light, (rear scale, 0),
## left ground point, right ground point]. Perspective: the car as rendered for the cell (yaw about its centre,
## seen from the render camera), placed by the anchor and scale; ortho: around the rear anchor as before.
func _player_light_points(persp: bool, info: Array, cell: int, anchor_pt: Vector2, p_rear: Vector3, dc: float, obj: Vector3) -> PackedVector2Array:
	var cw := obj.x
	var ch := obj.z
	var out := PackedVector2Array()
	if not persp:
		var s := p_rear.z
		var yaw0 := deg_to_rad((info[SI_YAWS] as PackedFloat32Array)[cell]) if cell >= 0 else 0.0
		var gx := cw * 0.38 * cos(yaw0) * s
		out.append(Vector2(p_rear.x - gx, p_rear.y - ch * 0.42 * s))
		out.append(Vector2(p_rear.x + gx, p_rear.y - ch * 0.42 * s))
		out.append(Vector2(s, 0.0))
		out.append(Vector2(p_rear.x - gx, p_rear.y))
		out.append(Vector2(p_rear.x + gx, p_rear.y))
		return out
	var yaw := deg_to_rad((info[SI_YAWS] as PackedFloat32Array)[cell]) if cell >= 0 else 0.0
	var d := float(info[SI_CAMD])
	var hcam := proj.cam_height
	var half_l := obj.y * 0.5
	var k := proj.focal * d / maxf(dc, 0.01)     # game px per (metre / render depth)
	var pts_h: Array[float] = [ch * 0.42, 0.0]
	var tmp: Array[Vector2] = []
	var s_rear := 0.0
	for hy: float in pts_h:
		for side: float in [-1.0, 1.0]:
			var lx := side * cw * 0.38
			var x := lx * cos(yaw) - half_l * sin(yaw)
			var z := -lx * sin(yaw) - half_l * cos(yaw)
			var depth := maxf(d + z, 0.1)
			tmp.append(anchor_pt + Vector2(k * x / depth, k * ((hcam - hy) / depth - hcam / d)))
			s_rear = k / depth
	out.append(tmp[0])
	out.append(tmp[1])
	out.append(Vector2(s_rear, 0.0))
	out.append(tmp[2])
	out.append(tmp[3])
	return out


## Truck/bus part inside one scene slice (bucketed by _bucket_box): BoxVehicle projects the visible faces of
## all parts with the road geometry (slices <= render.box_slice_m), far to near, with the ambient/fog/night
## modulate of sprites; tail/brake overlays on top; one textured triangle array per item. A soft shadow on
## the road under the body comes first; the rear lights glow when the rear face is in this slice.
func _draw_box_item(it: Dictionary) -> void:
	var car: Dictionary = it["car"]
	if not bool(car.get("visible", true)):
		return
	var info := _spinfo(str(car.get("set", "")))
	if info.is_empty():
		return
	var obj: Vector3 = info[SI_OBJ]
	var length := float(car.get("length", obj.y))
	var zc := float(car["z"]) + length * 0.5
	var xc := float(car.get("x", 0.0))
	var z0 := float(it["z0"])
	var z1 := float(it["z1"])
	var zm := (z0 + z1) * 0.5
	var km := clampi(int(floor(zm / _seg_len)) - _base, 0, _n - 1)
	var dz := maxf(road_at(zm).z, proj.near)
	var alpha := _item_alpha(km, dz)
	if alpha <= 0.02:
		return
	_ctx(_segs[km].tunnel)
	var light := _light(zm, xc) if _lit and dz < _hl_range + 40.0 else 0.0
	var mod := _modulate(km, light, alpha, 0.55)
	var lights := _lights if not _segs[km].tunnel else 1.0
	var tail := maxf(float(car.get("tail", 0.0)), lights)
	var brake := float(car.get("brake", 0.0))
	var light_alpha := alpha if _lights < 0.3 else minf(1.0, alpha * 1.6)
	_box_shadow(km, xc, z0, z1, obj.x, alpha)
	_box.clear()
	_box.tex_size = info[SI_TEXSIZE]
	var k_l := light_alpha / maxf(alpha, 0.001)
	_box.emit(info[SI_PARTS], info[SI_LIGHTS], zc, xc, z0, z1, float(view["camera_z"]), road_at, mod, tail * k_l, brake * k_l)
	if _box.quads > 0:
		batch.flush()
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _box.idx, _box.pts, _box.cols, _box.uvs,
			PackedInt32Array(), PackedFloat32Array(), (info[SI_TEX] as Texture2D).get_rid())
		batch.triangles += _box.quads * 2
		batch.commands += 1
	if not _box.rear_drawn:
		return
	var glow_a := clampf(tail * lights * 0.9 + brake * (0.35 + 0.4 * lights), 0.0, 1.0) * alpha
	if glow_a > 0.03:
		var rr := _box.rear_rect
		var s := rr.size.x / maxf(obj.x, 0.1)
		var gy := rr.end.y - 0.85 * s
		var gr := clampf((0.36 + brake * 0.12 + lights * 0.2) * s, 2.0, 80.0)
		var gcol := Color(1.0, 0.16, 0.06, 0.5 * glow_a)
		_glow(Vector2(rr.position.x + rr.size.x * 0.12, gy), gr, gcol)
		_glow(Vector2(rr.end.x - rr.size.x * 0.12, gy), gr, gcol)
		if _wet > 0.0 and lights > 0.2:
			_wet_reflections(PackedVector2Array([Vector2(rr.position.x + rr.size.x * 0.12, rr.end.y), Vector2(rr.end.x - rr.size.x * 0.12, rr.end.y)]), s, 0.22 * glow_a * _wet, 0.8 * s)


## Darkened road under a box vehicle between z0 and z1 (footprint + 0.15 m to each side).
func _box_shadow(k: int, xc: float, z0: float, z1: float, width: float, alpha: float) -> void:
	var ra := road_at(z0)
	var rb := road_at(z1)
	if ra.z <= proj.near or rb.z <= ra.z:
		return
	var hw := width * 0.5 + 0.15
	var sa := proj.focal / ra.z
	var sb := proj.focal / rb.z
	var cx := proj.screen.x * 0.5
	var c := Color(0.0, 0.0, 0.0, 0.32 * alpha * (1.0 - _ftx[k]))
	batch.quad(Vector2(cx + (ra.x + xc - hw) * sa, proj.horizon_y - ra.y * sa), Vector2(cx + (ra.x + xc + hw) * sa, proj.horizon_y - ra.y * sa),
		Vector2(cx + (rb.x + xc + hw) * sb, proj.horizon_y - rb.y * sb), Vector2(cx + (rb.x + xc - hw) * sb, proj.horizon_y - rb.y * sb), c)


# --- procedural objects ---------------------------------------------------------------------

func _draw_object(k: int, obj: String, it: Dictionary, p: Vector3, alpha: float, light: float) -> void:
	var s := p.z
	if s < 0.4:
		return
	var side := int(it.get("side", 1))
	match obj:
		"streetlight":
			_streetlight(k, p, side, alpha)
		"fuel_pylon":
			_fuel_pylon(k, p, alpha, light)
		"pump":
			_pump(k, p, alpha, light)
		"station":
			_station(k, p, alpha, light)
		"radar_cam":
			_radar_cam(k, p, alpha, light)
		"booth":
			_booth(k, p, side, alpha, light)
		"truss_portal":
			_truss_portal(k, it, p, alpha, light)
		"pylon":
			_pylon(k, it, p, alpha, light)
		"bridge_lamp":
			_bridge_lamp(k, it, p, alpha, light)


func _oc(base: Color, k: int, light: float, alpha: float, reflect: float = 0.5) -> Color:
	var c := Color(base.r * minf(1.5, _amb.r + light * reflect), base.g * minf(1.5, _amb.g + light * reflect), base.b * minf(1.5, _amb.b + light * reflect))
	c = c.lerp(_fogc, _ftx[k] * 0.9)
	c.a = alpha
	return c


func _streetlight(k: int, p: Vector3, side: int, alpha: float) -> void:
	var s := p.z
	var pole := _oc(Color("5b6066"), k, 0.0, alpha)
	var h := 8.5 * s
	var pw := maxf(1.0, 0.18 * s)
	batch.rect(Rect2(p.x - pw * 0.5, p.y - h, pw, h), pole)
	var arm := -float(side) * 2.2 * s
	batch.line(Vector2(p.x, p.y - h), Vector2(p.x + arm, p.y - h - 0.25 * s), maxf(1.0, 0.12 * s), pole)
	var lamp := Vector2(p.x + arm, p.y - h - 0.15 * s)
	batch.rect(Rect2(lamp.x - 0.45 * s, lamp.y - 0.1 * s, 0.9 * s, 0.24 * s), pole)
	if _lights > 0.05:
		batch.rect(Rect2(lamp.x - 0.38 * s, lamp.y + 0.1 * s, 0.76 * s, 0.09 * s), Color(1.0, 0.9, 0.65, alpha * _lights))
		_glow(lamp + Vector2(0, 0.2 * s), maxf(3.0, 2.4 * s), Color(1.0, 0.75, 0.4, 0.5 * _lights * alpha))
		if _segs[k].water:
			_water_reflection(k, p, side, 2.5, Color(1.0, 0.75, 0.4, 0.45 * _lights * alpha))


func _fuel_pylon(k: int, p: Vector3, alpha: float, light: float) -> void:
	var s := p.z
	var col := _oc(Color("d9d9d6"), k, light, alpha)
	batch.rect(Rect2(p.x - 0.18 * s, p.y - 6.0 * s, 0.36 * s, 6.0 * s), col)
	var board := Rect2(p.x - 1.1 * s, p.y - 9.6 * s, 2.2 * s, 3.8 * s)
	batch.rect(board, _oc(Color("1d4f9c"), k, light, alpha, 1.2))
	batch.rect(Rect2(board.position.x, board.position.y, board.size.x, 0.7 * s), _oc(Color("c8102e"), k, light, alpha, 1.2))
	var white := _oc(Color.WHITE, k, light, alpha, 1.2)
	if _lights > 0.05:
		white = Color(1, 1, 1, alpha)
		_glow(board.get_center(), maxf(3.0, 2.6 * s), Color(0.5, 0.7, 1.0, 0.25 * _lights * alpha))
	batch.rect(Rect2(p.x - 0.35 * s, board.position.y + 1.0 * s, 0.5 * s, 0.9 * s), white)
	batch.rect(Rect2(p.x + 0.2 * s, board.position.y + 1.15 * s, 0.1 * s, 0.6 * s), white)
	signs.text("1,79", Vector2(p.x, board.end.y - 0.95 * s), 0.5 * s, white, 1.9 * s)
	signs.text("1,85", Vector2(p.x, board.end.y - 0.25 * s), 0.5 * s, white, 1.9 * s)


func _pump(k: int, p: Vector3, alpha: float, light: float) -> void:
	var s := p.z
	var body := Rect2(p.x - 0.45 * s, p.y - 2.0 * s, 0.9 * s, 1.85 * s)
	batch.rect(body, _oc(Color("eeeeea"), k, light, alpha))
	batch.rect(Rect2(body.position.x, body.position.y, body.size.x, 0.45 * s), _oc(Color("c8102e"), k, light, alpha))
	var disp := Rect2(p.x - 0.28 * s, p.y - 1.45 * s, 0.56 * s, 0.32 * s)
	if _lights > 0.05:
		batch.rect(disp, Color(0.6, 1.0, 0.7, alpha))
		_glow(disp.get_center(), maxf(2.0, 0.8 * s), Color(0.5, 1.0, 0.6, 0.3 * _lights * alpha))
	else:
		batch.rect(disp, _oc(Color("223326"), k, light, alpha))


func _station(k: int, p: Vector3, alpha: float, light: float) -> void:
	var s := p.z
	var bw := 22.0 * s
	var bh := 4.6 * s
	var r := Rect2(p.x - bw * 0.5, p.y - bh, bw, bh)
	batch.rect(r, _oc(Color("e6e3dc"), k, light, alpha))
	batch.rect(Rect2(r.position.x - 0.4 * s, r.position.y - 0.9 * s, bw + 0.8 * s, 1.0 * s), _oc(Color("1d4f9c"), k, light, alpha, 1.0))
	var win := Color(1.0, 0.86, 0.55, alpha) if _lights > 0.3 else _oc(Color("7fa4c4"), k, light, alpha)
	batch.rect(Rect2(r.position.x + 1.5 * s, r.position.y + 1.2 * s, bw * 0.55, 2.4 * s), win)
	batch.rect(Rect2(r.end.x - 4.5 * s, r.position.y + 1.2 * s, 2.0 * s, 3.4 * s), _oc(Color("5a6470"), k, light, alpha))
	if _lights > 0.3:
		_glow(Vector2(r.position.x + 1.5 * s + bw * 0.275, r.position.y + 2.4 * s), maxf(4.0, 7.0 * s), Color(1.0, 0.8, 0.5, 0.25 * _lights * alpha))
	signs.text(tr("TANKSTELLE"), Vector2(r.get_center().x, r.position.y - 0.15 * s), 0.6 * s, Color(1, 1, 1, alpha) if _lights > 0.3 else _oc(Color.WHITE, k, light, alpha, 1.0), bw * 0.9)


func _radar_cam(k: int, p: Vector3, alpha: float, light: float) -> void:
	var s := p.z
	var col := _oc(Color("8e959c"), k, light, alpha)
	batch.rect(Rect2(p.x - 0.09 * s, p.y - 2.6 * s, 0.18 * s, 2.6 * s), col)
	var box := Rect2(p.x - 0.35 * s, p.y - 3.4 * s, 0.7 * s, 0.85 * s)
	batch.rect(box, _oc(Color("d8dadc"), k, light, alpha, 0.8))
	batch.rect(Rect2(box.position.x + 0.1 * s, box.position.y + 0.12 * s, 0.5 * s, 0.32 * s), _oc(Color("202428"), k, light, alpha))
	var flash := float(view.get("radar_flash01", 0.0))
	if flash > 0.05:
		_glow(box.get_center(), maxf(6.0, 6.0 * s * flash), Color(1, 1, 1, flash * alpha))


func _booth(k: int, p: Vector3, side: int, alpha: float, light: float) -> void:
	var s := p.z
	var bw := 3.0 * s
	var bh := 2.8 * s
	var r := Rect2(p.x - bw * 0.5, p.y - bh, bw, bh)
	batch.rect(r, _oc(Color("e8e8e4"), k, light, alpha))
	batch.rect(Rect2(r.position.x - 0.2 * s, r.position.y - 0.35 * s, bw + 0.4 * s, 0.4 * s), _oc(Color("3c4a5a"), k, light, alpha))
	var win := Color(1.0, 0.88, 0.6, alpha) if _lights > 0.3 else _oc(Color("8aaccc"), k, light, alpha)
	batch.rect(Rect2(r.position.x + 0.3 * s, r.position.y + 0.6 * s, bw - 0.6 * s, 1.0 * s), win)
	if _lights > 0.3:
		_glow(r.get_center(), maxf(3.0, 2.5 * s), Color(1.0, 0.85, 0.55, 0.25 * _lights * alpha))
	var _unused := side


# --- individual cities: water, bridges, fences (docs/staedte.md) ------------------------------------

const TRUSS_H := 4.2          ## height of the side girders of truss bridges (m)
const TRUSS_PANEL := 7.5      ## panel length of the side girders (m)


func _color(c: String) -> Color:
	var v: Variant = _col_cache.get(c)
	if v == null:
		v = Color(c)
		_col_cache[c] = v
	return v


## Water colour of the bridge on seg: bridge "water", else scenery "water", else the default per type.
func _water_base(seg: TrackSegment) -> Color:
	var v: Variant = _water_cache.get(seg.bridge_i)
	if v != null:
		return v
	var c := ""
	if seg.bridge_i >= 0 and seg.bridge_i < track.bridges.size():
		c = str(track.bridges[seg.bridge_i].get("water", ""))
	if c == "":
		c = str((scenery_db.get(seg.scenery, {}) as Dictionary).get("water", ""))
	if c == "":
		c = str(CityData.WATER_COLOR.get(seg.bridge, "#4b6878"))
	var col := Color(c)
	_water_cache[seg.bridge_i] = col
	return col


## Water colour of row k: ambient-lit base that mirrors more of the sky towards the horizon (grazing
## angle), then fog. Night: the sky is dark, so is the water.
static func water_tint(base: Color, amb: Color, sky: Color, dz: float) -> Color:
	var fres := clampf(0.16 + dz / 600.0, 0.16, 0.7)
	return Color(base.r * amb.r, base.g * amb.g, base.b * amb.b).lerp(sky, fres)


func _water_row(base: Color, k: int) -> Color:
	var c := water_tint(base, _amb, _pal_out["sky_bottom"], _dz[k])
	if _snow > 0.0:
		c = c.lerp(Color(0.75, 0.8, 0.84), 0.15 * _snow)
	return c.lerp(_fogc, _ftx[k])


## Water under and beside the bridge deck: one full-width band per slice at the height of the ground
## under the deck (TrackSegment.water_level: the water surface, rising to the road on the bank slopes –
## quay walls, embankments); the deck, drawn afterwards, covers it. Slopes facing away are skipped. Near
## the camera light ripples / sun glints flicker at fixed spots of each segment.
func _draw_water(a: int, b: int, sa: TrackSegment, merged: bool) -> void:
	var depth := sa.water_depth
	var sb := _segs[b]
	var la := sa.water_level
	var lb := sb.water_level if sb.water else 0.0
	var ya := _sy[a] - la * _ss[a]
	var yb := _sy[b] - lb * _ss[b]
	if yb >= ya - 0.01:
		return
	var w := proj.screen.x
	if la > -depth + 0.05 or lb > -depth + 0.05:
		# bank slope (quay wall or embankment) between ground and water
		var q: Color = QUAY.get(sa.bridge, QUAY["river"])
		if sa.bridge_i >= 0 and sa.bridge_i < track.bridges.size() and str(track.bridges[sa.bridge_i].get("bank", "")) != "":
			q = _color(str(track.bridges[sa.bridge_i]["bank"]))
		var qa := _rowc(q.darkened(0.35 * clampf(-la / depth, 0.0, 1.0)), a)
		var qb := _rowc(q.darkened(0.35 * clampf(-lb / depth, 0.0, 1.0)), b)
		batch.quad4(Vector2(-40, yb), Vector2(w + 40, yb), Vector2(w + 40, ya), Vector2(-40, ya), qb, qb, qa, qa)
		return
	var base := _water_base(sa)
	var ca := _water_row(base, a)
	var cb := _water_row(base, b)
	batch.quad4(Vector2(-40, yb), Vector2(w + 40, yb), Vector2(w + 40, ya), Vector2(-40, ya), cb, cb, ca, ca)
	if merged or _dz[a] > 320.0:
		return
	# glints: thin streaks across the current at fixed spots per segment (a fraction of a segment deep)
	var deck := sa.lanes * _lw * 0.5 + _sh + 1.0
	var sun := bool(_pal_out.get("sun_visible", false)) and _lights < 0.3
	var sky_top: Color = _pal_out["sky_top"]
	var hi := Color(1.0, 0.98, 0.92) if sun else sky_top.lightened(0.3)
	if _lights > 0.3:
		hi = Color(1.0, 0.78, 0.45)   # night: shimmering reflections of the city lights
	var v := sa.index * 92821 + 17
	for j in 5:
		v = (v * 1103515245 + 12345) & 0x7fffffff
		var xc := (float(v % 4000) / 4000.0 - 0.5) * 130.0
		if absf(xc) < deck:
			continue
		var ph := sin(_time * (1.3 + float(j) * 0.4) + float(sa.index) * 0.9 + float(j) * 2.3)
		if ph < 0.2:
			continue
		var half := 0.7 + float((v >> 12) % 100) * 0.035
		var f0 := float((v >> 5) % 70) / 100.0
		var p0 := _proj_at(a, f0, xc, -depth)
		var p1 := _proj_at(a, f0 + 0.12, xc, -depth)
		if p0.z <= 0.0 or p1.z <= 0.0:
			continue
		var al := (0.42 if sun else 0.2) * (ph - 0.2) / 0.8 * (1.0 - _ftx[a])
		var c := _rowc(Color(hi, al), a)
		if _lights > 0.3:
			c = Color(hi.lerp(_fogc, _ftx[a] * 0.7), 0.5 * _lights * (ph - 0.2) / 0.8)
		var top := minf(p1.y, p0.y - 0.8)
		batch.quad(Vector2(p0.x - half * p0.z, p0.y), Vector2(p0.x + half * p0.z, p0.y), Vector2(p1.x + half * p1.z * 0.8, top), Vector2(p1.x - half * p1.z * 0.8, top), c)


func _bridge_color(seg: TrackSegment) -> Color:
	if seg.bridge_i >= 0 and seg.bridge_i < track.bridges.size():
		var c := str(track.bridges[seg.bridge_i].get("color", ""))
		if c != "":
			return _color(c)
	return RAIL.get(seg.bridge, RAIL["river"])


## Railing at the outer deck edges (type-specific), side girders of truss bridges.
func _bridge_structures(a: int, b: int, sa: TrackSegment, la: float, lb: float, ra: float, rb: float, merged: bool) -> void:
	var extra := 0.0 if sa.city else Track.BRIDGE_DECK_EXTRA_M
	var col := _bridge_color(sa)
	for x: Vector2 in [Vector2(la - _sh - extra, lb - _sh - extra), Vector2(ra + _sh + extra, rb + _sh + extra)]:
		match sa.bridge:
			"stone_arch":
				_balustrade(a, b, x.x, x.y, col, merged)
			"canal":
				_iron_railing(a, b, x.x, x.y, col, merged, 1.02)
			"causeway":
				_vstrip(a, b, x.x, x.y, 0.0, 0.82, col, 0.5)
				_vstrip(a, b, x.x, x.y, 0.82, 0.92, col.lightened(0.12), 0.5)
			_:
				_steel_railing(a, b, x.x, x.y, col, merged)
		if sa.bridge == "truss_arch":
			var o := signf(x.x) * 0.35
			_truss_girder(a, b, x.x + o, x.y + o, col, merged)


func _steel_railing(a: int, b: int, xa: float, xb: float, col: Color, merged: bool) -> void:
	_vstrip(a, b, xa, xb, 0.0, 0.28, CONCRETE, 0.5)
	_vstrip(a, b, xa, xb, 0.5, 0.56, col.darkened(0.15), 0.6)
	_vstrip(a, b, xa, xb, 0.98, 1.1, col, 0.6)
	if not merged and _ss[a] > 1.5 and _segs[a].index % 2 == 0:
		var s := _ss[a]
		var pw := maxf(1.0, 0.1 * s)
		batch.rect(Rect2(_sx[a] + xa * s - pw * 0.5, _sy[a] - 1.1 * s, pw, 0.82 * s), _shade(col.darkened(0.2), a, xa, 0.5))


## Stone balustrade: plinth, balusters (single near the camera, a translucent band farther away),
## handrail, pedestals every 12 m.
func _balustrade(a: int, b: int, xa: float, xb: float, col: Color, merged: bool) -> void:
	_vstrip(a, b, xa, xb, 0.0, 0.24, col.darkened(0.22), 0.5)
	if merged or _ss[a] < 3.0:
		_vstrip(a, b, xa, xb, 0.24, 0.92, Color(col.darkened(0.08), 0.55), 0.5)
	else:
		var bc := _shade(col.darkened(0.04), a, xa, 0.5)
		for i in 5:
			var f := (float(i) + 0.5) / 5.0
			var q := _proj_at(a, f, lerpf(xa, xb, f), 0.24)
			if q.z <= 0.0:
				continue
			var bw := maxf(1.0, 0.14 * q.z)
			batch.rect(Rect2(q.x - bw * 0.5, q.y - 0.68 * q.z, bw, 0.68 * q.z), bc)
	_vstrip(a, b, xa, xb, 0.92, 1.14, col.lightened(0.08), 0.5)
	if not merged and _segs[a].index % 4 == 0 and _ss[a] > 0.8:
		var s := _ss[a]
		batch.rect(Rect2(_sx[a] + xa * s - 0.28 * s, _sy[a] - 1.32 * s, 0.56 * s, 1.32 * s), _shade(col.lightened(0.03), a, xa, 0.5))


## Wrought-iron railing (canal bridges, iron fences): rails and thin bars (a translucent band far away).
func _iron_railing(a: int, b: int, xa: float, xb: float, col: Color, merged: bool, h: float) -> void:
	_vstrip(a, b, xa, xb, h * 0.42, h * 0.47, col, 0.5)
	_vstrip(a, b, xa, xb, h - 0.07, h, col, 0.5)
	if merged or _ss[a] < 2.0:
		_vstrip(a, b, xa, xb, 0.1, h, Color(col, 0.3), 0.4)
		return
	var bc := _shade(col, a, xa, 0.5)
	for i in 5:
		var f := (float(i) + 0.5) / 5.0
		var q := _proj_at(a, f, lerpf(xa, xb, f), 0.1)
		if q.z <= 0.0:
			continue
		var bw := maxf(1.0, 0.05 * q.z)
		batch.rect(Rect2(q.x - bw * 0.5, q.y - (h - 0.1) * q.z, bw, (h - 0.1) * q.z), bc)


## Side girder of a truss bridge: chords along the deck edge, verticals and alternating diagonals every
## TRUSS_PANEL metres (thin lines, the water stays visible between them).
func _truss_girder(a: int, b: int, xa: float, xb: float, col: Color, _merged: bool) -> void:
	_vstrip(a, b, xa, xb, TRUSS_H - 0.45, TRUSS_H, col, 0.5)
	_vstrip(a, b, xa, xb, 0.0, 0.4, col.darkened(0.15), 0.5)
	if _dz[a] > 520.0:
		return
	var z0 := _zw[a]
	var z1 := _zw[b]
	var lc := _rowc(col.darkened(0.1), a)
	var zp := ceilf(z0 / TRUSS_PANEL) * TRUSS_PANEL
	while zp < z1:
		var x := lerpf(xa, xb, (zp - z0) / maxf(0.001, z1 - z0))
		var p0 := _proj_world(zp, x, 0.35)
		var p1 := _proj_world(zp, x, TRUSS_H - 0.4)
		if p0.z > 0.0 and p1.z > 0.0:
			var wdt := maxf(1.0, 0.2 * p0.z)
			batch.line(Vector2(p0.x, p0.y), Vector2(p1.x, p1.y), wdt, lc)
			var up := int(floorf(zp / TRUSS_PANEL + 0.5)) % 2 == 0
			var p2 := _proj_world(zp + TRUSS_PANEL, x, TRUSS_H - 0.4 if up else 0.35)
			var p3 := p0 if up else p1
			if p2.z > 0.0:
				batch.line(Vector2(p3.x, p3.y), Vector2(p2.x, p2.y), wdt * 0.8, lc)
		zp += TRUSS_PANEL


## Fence, hedge or garden wall of the city scenery ("fence": {style picket|hedge|wall|iron, color, x
## (m behind the sidewalk), h, gap_every_m, gap_m}) along both sides, with gaps for gates and driveways.
func _fence(a: int, b: int, sa: TrackSegment, la: float, lb: float, ra: float, rb: float, merged: bool) -> void:
	if _dz[a] > 240.0:
		return
	var fv: Variant = (scenery_db.get(sa.scenery, {}) as Dictionary).get("fence")
	if not fv is Dictionary:
		return
	var fd: Dictionary = fv
	var style := str(fd.get("style", "picket"))
	var col := _color(str(fd.get("color", "#d8d2c4")))
	var off := float(fd.get("x", 0.6))
	var h := float(fd.get("h", 1.1))
	var every := float(fd.get("gap_every_m", 24.0))
	var gap := float(fd.get("gap_m", 3.5))
	for side: int in [-1, 1]:
		if every > 0.0 and fposmod(sa.z + (every * 0.5 if side > 0 else 0.0), every) < gap:
			continue
		var xa := (la - _sh - off) if side < 0 else (ra + _sh + off)
		var xb := (lb - _sh - off) if side < 0 else (rb + _sh + off)
		match style:
			"hedge":
				var dp := 0.8 * float(side)
				_hstrip(a, b, xa, xa + dp, xb, xb + dp, h, col.lightened(0.1))
				_vstrip(a, b, xa, xb, 0.0, h, col, 0.5)
			"wall":
				_vstrip(a, b, xa, xb, 0.0, h, col, 0.5)
				_vstrip(a, b, xa, xb, h, h + 0.08, col.lightened(0.15), 0.5)
			"iron":
				_vstrip(a, b, xa, xb, 0.0, 0.3, col.lightened(0.35), 0.5)
				_iron_railing(a, b, xa, xb, col, merged, h)
			_:
				_vstrip(a, b, xa, xb, h * 0.22, h * 0.3, col.darkened(0.12), 0.5)
				_vstrip(a, b, xa, xb, h * 0.68, h * 0.76, col.darkened(0.12), 0.5)
				if merged or _ss[a] < 2.2:
					_vstrip(a, b, xa, xb, 0.05, h, Color(col, 0.55), 0.5)
				else:
					var pc := _shade(col, a, xa, 0.5)
					for i in 4:
						var f := (float(i) + 0.5) / 4.0
						var q := _proj_at(a, f, lerpf(xa, xb, f), 0.05)
						if q.z <= 0.0:
							continue
						var pw := maxf(1.0, 0.09 * q.z)
						batch.rect(Rect2(q.x - pw * 0.5, q.y - (h - 0.12) * q.z, pw, (h - 0.12) * q.z), pc)
						batch.tri(Vector2(q.x - pw * 0.5, q.y - (h - 0.12) * q.z), Vector2(q.x + pw * 0.5, q.y - (h - 0.12) * q.z), Vector2(q.x, q.y - h * q.z), pc)


## Screen position (x, y, px per m) of the world point at track z, lateral x, height h above the road
## (road_at: extrapolated beyond the projected rows); z = -1 when behind the near plane.
func _proj_world(z: float, x: float, h: float) -> Vector3:
	var r := road_at(z)
	if r.z <= proj.near:
		return Vector3(0, 0, -1)
	var s := proj.focal / r.z
	return Vector3(proj.screen.x * 0.5 + (r.x + x) * s, proj.horizon_y - (r.y + h) * s, s)


## Straight line between two world points, clipped at the near plane; width in metres (at least 0.8 px).
func _world_line(z0: float, x0: float, h0: float, z1: float, x1: float, h1: float, width_m: float, col: Color) -> void:
	var zn := float(view["camera_z"]) + proj.near + 0.5
	if z0 < zn and z1 < zn:
		return
	if z0 < zn:
		var t := (zn - z0) / (z1 - z0)
		x0 = lerpf(x0, x1, t)
		h0 = lerpf(h0, h1, t)
		z0 = zn
	elif z1 < zn:
		var t := (zn - z1) / (z0 - z1)
		x1 = lerpf(x1, x0, t)
		h1 = lerpf(h1, h0, t)
		z1 = zn
	var p0 := _proj_world(z0, x0, h0)
	var p1 := _proj_world(z1, x1, h1)
	if p0.z <= 0.0 or p1.z <= 0.0:
		return
	batch.line(Vector2(p0.x, p0.y), Vector2(p1.x, p1.y), maxf(0.8, width_m * minf(p0.z, p1.z)), col)


func _steel_of(it: Dictionary) -> Color:
	var c := str(it.get("color", ""))
	return _color(c) if c != "" else RAIL.get(str(it.get("bridge", "truss_arch")), RAIL["truss_arch"])


## Overhead portal of a truss bridge (procedural stand-in for props/bridge_truss_arch): legs at the deck
## edges, a steel arch over the whole deck (fit_w), tie beam and lattice bracing.
func _truss_portal(k: int, it: Dictionary, p: Vector3, alpha: float, light: float) -> void:
	var s := p.z
	var hw := float(it.get("fit_w", 16.0)) * 0.5 - 0.4
	var steel := _steel_of(it)
	var col := _oc(steel, k, light, alpha, 0.4)
	var dark := _oc(steel.darkened(0.3), k, light, alpha, 0.3)
	var leg_h := 6.4
	var apex := 14.0
	var lw := maxf(1.0, 0.75 * s)
	for sd: float in [-1.0, 1.0]:
		batch.rect(Rect2(p.x + sd * hw * s - lw * 0.5, p.y - leg_h * s, lw, leg_h * s), col)
	var n := 12
	var pts: Array[Vector2] = []
	for i in n + 1:
		var t := float(i) / float(n)
		pts.append(Vector2(p.x + lerpf(-hw, hw, t) * s, p.y - (leg_h + (apex - leg_h) * sin(t * PI)) * s))
	for i in n:
		batch.line(pts[i], pts[i + 1], maxf(1.0, 0.85 * s), col)
	var tie := p.y - leg_h * s
	batch.line(Vector2(p.x - hw * s, tie), Vector2(p.x + hw * s, tie), maxf(1.0, 0.5 * s), dark)
	if s > 1.0:
		for i in range(1, n):
			var bot := Vector2(pts[i].x, tie)
			batch.line(bot, pts[i], maxf(1.0, 0.18 * s), dark)
			batch.line(bot, pts[i + 1] if i % 2 == 0 else pts[i - 1], maxf(1.0, 0.14 * s), dark)


## Pylon of a cable-stayed bridge (procedural stand-in for props/bridge_pylon) with its fan of stay cables
## down to the deck edge as real 3D lines in front of and behind it.
func _pylon(k: int, it: Dictionary, p: Vector3, alpha: float, light: float) -> void:
	var s := p.z
	var hgt := float(it.get("height_m", 80.0))
	var conc := _oc(Color("d3d1ca"), k, light, alpha, 0.3)
	var shade := _oc(Color("a7a59d"), k, light, alpha, 0.3)
	var w0 := 3.6 * s
	var w1 := 2.2 * s
	batch.quad4(Vector2(p.x - w1 * 0.5, p.y - hgt * s), Vector2(p.x + w1 * 0.5, p.y - hgt * s), Vector2(p.x + w0 * 0.5, p.y), Vector2(p.x - w0 * 0.5, p.y), conc, conc, shade, shade)
	batch.rect(Rect2(p.x - w1 * 0.6, p.y - (hgt + 1.6) * s, w1 * 1.2, 1.6 * s), shade)
	var side := float(int(it.get("side", 1)))
	var z := float(it.get("z", 0.0))
	var x := float(it.get("x", 0.0))
	var span := float(it.get("cables", 50.0))
	var cable := _oc(Color("ecebe6"), k, light, alpha * 0.9, 0.3)
	var x_deck := x - side * 1.4
	for i in 7:
		var d := span * float(i + 1) / 7.0
		var ht := hgt * (0.95 - 0.05 * float(i))
		_world_line(z, x, ht, z + d, x_deck, 1.1, 0.07, cable)
		_world_line(z, x, ht, z - d, x_deck, 1.1, 0.07, cable)
	if _lights > 0.2 and fmod(_time + side * 0.4, 1.6) < 0.8:
		_glow(Vector2(p.x, p.y - (hgt + 1.6) * s), maxf(3.0, 1.2 * s), Color(1, 0.15, 0.1, 0.8 * _lights * alpha))


## Ornamental bridge lamp (procedural stand-in for props/bridge_lamp): three globes on stone bridges, one
## on causeways; lit at night with a reflection on the water.
func _bridge_lamp(k: int, it: Dictionary, p: Vector3, alpha: float, light: float) -> void:
	var s := p.z
	var hgt := 4.4
	var post := _oc(Color("2e3833"), k, light, alpha, 0.3)
	batch.rect(Rect2(p.x - 0.32 * s, p.y - 0.9 * s, 0.64 * s, 0.9 * s), post)
	batch.rect(Rect2(p.x - 0.1 * s, p.y - hgt * s, 0.2 * s, hgt * s), post)
	var lit := _lights > 0.05
	var globe := Color(1.0, 0.93, 0.72, alpha) if lit else _oc(Color("e9e5da"), k, light, alpha, 0.8)
	var heads: Array[Vector2] = [Vector2(0.0, hgt + 0.35)]
	if str(it.get("bridge", "")) == "stone_arch":
		heads = [Vector2(-0.55, hgt - 0.1), Vector2(0.55, hgt - 0.1), Vector2(0.0, hgt + 0.45)]
		batch.line(Vector2(p.x - 0.6 * s, p.y - (hgt - 0.35) * s), Vector2(p.x + 0.6 * s, p.y - (hgt - 0.35) * s), maxf(1.0, 0.08 * s), post)
	for hd in heads:
		var c := Vector2(p.x + hd.x * s, p.y - hd.y * s)
		batch.ellipse(c, Vector2(0.24 * s, 0.3 * s), globe, globe, 8)
		if lit:
			_glow(c, maxf(3.0, 1.6 * s), Color(1.0, 0.8, 0.45, 0.45 * _lights * alpha))
	if lit and _segs[k].water:
		_water_reflection(k, p, int(it.get("side", 1)), 1.8, Color(1.0, 0.78, 0.45, 0.4 * _lights * alpha))


## Soft light spot drawn in painter's order (radial alpha gradient in the batch, not the additive layer):
## nearer geometry covers it – reflections under a deck, lights of landmarks behind buildings or hills.
func _soft(pos: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx < 0.5 or col.a < 0.01 or pos.x < -rx or pos.x > proj.screen.x + rx or pos.y < -ry or pos.y > proj.screen.y + ry:
		return
	batch.ellipse(pos, Vector2(rx, ry), col, Color(col, 0.0), 12)


## Reflection of a lamp on the water a little outside the deck edge: an elongated soft streak at the water
## level (night), covered by the nearer deck where the water is hidden under it.
func _water_reflection(k: int, p: Vector3, side: int, out_m: float, col: Color) -> void:
	var s := p.z
	var c := Vector2(p.x + float(side) * out_m * s, p.y + _segs[k].water_depth * s)
	_soft(c, maxf(1.5, 0.8 * s), maxf(4.0, 3.2 * s), col)
	_soft(c, maxf(1.0, 0.3 * s), maxf(2.0, 1.6 * s), Color(1.0, 0.95, 0.85, col.a))


# --- individual cities: landmarks and skyline (docs/staedte.md) -------------------------------------

## Scenery background with the per-city overrides (cities.json "background") inside the City Limits.
func _background_for(scen_id: String, scen: Dictionary) -> Dictionary:
	var bg: Dictionary = scen.get("background", {})
	var over: Dictionary = track.plan.city_background
	if over.is_empty() or not scen_id.begins_with("city"):
		return bg
	var c: Variant = _bg_cache.get(scen_id)
	if c == null:
		var m := bg.duplicate(true)
		for key: String in over:
			m[key] = over[key]
		_bg_cache[scen_id] = m
		c = m
	return c


## Alpha (x) and haze (y) of a landmark at depth dz: landmarks keep their contrast in the haze far beyond
## the draw range (range = visibility × range_k, at most far_m); they fade out over the last 28 % of it and
## blend towards the fog colour from the fog start on. Continuous everywhere (no pop-in).
static func landmark_fade(dz: float, vis: float, fog_start: float, range_k: float, far_m: float) -> Vector2:
	var l := clampf(vis * range_k, minf(vis, 600.0), maxf(far_m, vis))
	return Vector2(1.0 - smoothstep(l * 0.72, l, dz), clampf((dz - fog_start) / maxf(1.0, l - fog_start), 0.0, 1.0) * 0.85)


func _landmark_range() -> float:
	return clampf(_vis * _lm_range_k, minf(_vis, 600.0), maxf(_lm_far, _vis))


## Landmarks beyond the projected rows: the road is extrapolated straight from the last row (its heading at
## the end of the draw range, its height flat). Drawn after the background, before the scene.
func _draw_far_landmarks() -> void:
	if track.landmarks.is_empty() or _n < 2:
		return
	var cam_z := float(view["camera_z"])
	var z_end := _zw[_n]
	var lim := maxf(_landmark_range(), _lm_far if _lights > 0.05 else 0.0)
	var items: Array = []
	for it: Dictionary in track.landmarks:
		var z := float(it["z"])
		if z >= z_end and z - cam_z <= lim:
			items.append(it)
	if items.is_empty():
		return
	items.sort_custom(func(u: Dictionary, v: Dictionary) -> bool: return float(u["z"]) > float(v["z"]))
	var y_rel := _yw[_n] - _cam_y
	for it: Dictionary in items:
		var z := float(it["z"])
		var d := z - cam_z
		var pc := _prep_prop(it)
		var r := road_at(z)
		var s := proj.focal / d
		_draw_landmark(it, pc, Vector3(proj.screen.x * 0.5 + (r.x + float(pc[3])) * s, proj.horizon_y - y_rel * s, s), d)


## A landmark (sprite or procedural stand-in) at screen anchor p (x, y, px per m) and depth dz with the
## landmark haze (landmark_fade) instead of the prop fog; its lights layer (illumination) stays visible at
## night up to render.landmark_far_m.
func _draw_landmark(it: Dictionary, pc: Array, p: Vector3, dz: float) -> void:
	var fade := landmark_fade(dz, _vis, _fog_start, _lm_range_k, _lm_far)
	var lights_a := 0.0
	if _lights > 0.05:
		lights_a = _lights * (1.0 - smoothstep(_lm_far * 0.8, _lm_far, dz))
	if fade.x <= 0.01 and lights_a <= 0.01:
		return
	_ctx(false)
	_lm_amb = _amb_out
	_lm_haze = fade.y
	_lm_alpha = fade.x
	var info: Array = pc[1]
	if not info.is_empty():
		var flip := prop_flipped(int(it.get("side", 1)), bool(it.get("mirror", false)), bool(info[SI_MIRROR]))
		var tint: Color = pc[5]
		var mod := Color(_amb_out.r, _amb_out.g, _amb_out.b).lerp(_fog_outc * 1.15, fade.y)
		if fade.x > 0.01:
			_sprite_i(info, "c", "base", p, float(pc[2]), Color(mod.r * tint.r, mod.g * tint.g, mod.b * tint.b, fade.x), flip)
		if lights_a > 0.01 and (info[SI_ROWS] as Dictionary).has("lights"):
			_sprite_i(info, "c", "lights", p, float(pc[2]), Color(1, 1, 1, lights_a), flip)
	elif str(pc[4]) != "":
		_draw_landmark_proc(str(pc[4]), it, p, lights_a)


## Panorama silhouettes of the destination's skyline landmarks (cities.json "skyline") inside the City
## Limits: anchored to the panorama when first seen – one that is also passed as a prop starts in its true
## direction – then turning with it; faded out while that prop is within landmark range (no double).
func _skyline_silhouettes(heading: float) -> Array:
	var sky: Array[Dictionary] = track.plan.skyline
	var cam_z := float(view["camera_z"])
	if sky.is_empty() or not track.is_city_at(cam_z + proj.cam_distance):
		return []
	var out: Array = []
	var l := _landmark_range()
	for i in sky.size():
		var e: Dictionary = sky[i]
		var a := 1.0
		var prop_km := float(e.get("prop_km", -1.0))
		var dz := 0.0
		if prop_km >= 0.0:
			dz = track.km_to_z(prop_km) - cam_z
			a = smoothstep(l, l * 1.15, dz) if dz > 0.0 else 0.0
		if a <= 0.01:
			continue
		if not _sky_anchor.has(i):
			_sky_anchor[i] = heading + _skyline_offset(i, e, dz)
		out.append({"entry": e, "angle": float(_sky_anchor[i]), "alpha": a, "s": proj.focal / _sky_dist})
	return out


func _skyline_offset(i: int, e: Dictionary, dz: float) -> float:
	var az := float(e.get("azimuth_deg", NAN))
	if not is_nan(az):
		return deg_to_rad(az)
	if dz > 0.0:
		for it: Dictionary in track.landmarks:
			if str(it["set"]) == str(e["set"]):
				return atan2(road_at(float(it["z"])).x + float(_prep_prop(it)[3]), dz)
	return SKY_OFFSETS[i % SKY_OFFSETS.size()]


## RaceBackdrop.sprite_cb: a skyline silhouette standing on the panorama base line at pos (s = px per m).
func _draw_skyline_landmark(entry: Dictionary, pos: Vector2, s: float, alpha: float, haze: float) -> void:
	var pc := _prep_prop(entry)
	_lm_amb = _amb_out
	_lm_haze = haze
	_lm_alpha = alpha
	var p := Vector3(pos.x, pos.y, s)
	var info: Array = pc[1]
	var lights := _lights * alpha
	if not info.is_empty():
		var tint: Color = pc[5]
		var mod := Color(_amb_out.r, _amb_out.g, _amb_out.b).lerp(_fog_outc * 1.15, haze)
		_sprite_i(info, "c", "base", p, float(pc[2]), Color(mod.r * tint.r, mod.g * tint.g, mod.b * tint.b, alpha), false)
		if lights > 0.02 and (info[SI_ROWS] as Dictionary).has("lights"):
			_sprite_i(info, "c", "lights", p, float(pc[2]), Color(1, 1, 1, lights), false)
	elif str(pc[4]) != "":
		_draw_landmark_proc(str(pc[4]), entry, p, lights)


## Light of a landmark (illumination, aviation lights): a soft spot in painter's order with a bright core,
## so buildings or hills in front of the landmark cover it (the additive glow layer would shine through).
func _lm_glow(pos: Vector2, r: float, col: Color, stretch: float = 1.0) -> void:
	_soft(pos, r, r * stretch, Color(col, minf(1.0, col.a * 0.8)))
	_soft(pos, r * 0.35, r * 0.35 * stretch, Color(col.lightened(0.5), minf(1.0, col.a * 1.2)))


## Colour of a procedural landmark part: ambient, haze towards the fog, landmark alpha.
func _lmc(base: Color, a: float = 1.0) -> Color:
	var c := Color(base.r * _lm_amb.r, base.g * _lm_amb.g, base.b * _lm_amb.b).lerp(_fog_outc, _lm_haze)
	c.a = _lm_alpha * a
	return c


## Procedural landmark stand-ins until the Blender sprite exists (cities.json landmark_sets "proc").
func _draw_landmark_proc(proc: String, it: Dictionary, p: Vector3, lights_a: float) -> void:
	var hgt := float(it.get("height_m", 40.0)) * float(it.get("scale", 1.0))
	var span := maxf(hgt, float(it.get("width_m", 0.0)) * float(it.get("scale", 1.0)) * 0.6) * p.z
	if span < 1.5 or p.x + span < -10.0 or p.x - span > proj.screen.x + 10.0 or p.y - span > proj.screen.y:
		return
	match proc:
		"lattice_tower":
			_lm_lattice(p, hgt, lights_a)
		"tv_tower":
			_lm_tv(p, hgt, lights_a)
		"ferris_wheel":
			_lm_wheel(p, hgt, lights_a)
		"column":
			_lm_column(p, hgt, lights_a)
		"campanile":
			_lm_campanile(p, hgt, lights_a)
		"domed_church":
			_lm_domed(it, p, hgt, lights_a)
		"parliament":
			_lm_parliament(p, hgt, lights_a)
		"palace_tower":
			_lm_palace(p, hgt, lights_a)
		"skyscrapers":
			_lm_skyscrapers(p, hgt, lights_a)


## Half width (m) of the Eiffel tower's silhouette at height h (exponential profile of the real tower).
static func eiffel_half_width(h: float) -> float:
	return 3.0 + 59.0 * exp(-h / 72.0)


func _hbar(p: Vector3, s: float, h: float, thick: float, half: float, col: Color) -> void:
	batch.rect(Rect2(p.x - half * s, p.y - (h + thick) * s, 2.0 * half * s, thick * s), col)


## Lattice tower (Eiffel tower, 330 m): curved legs with the arch, platforms, shaft, antenna; golden
## illumination and a beacon at night.
func _lm_lattice(p: Vector3, hgt: float, lights_a: float) -> void:
	var s := p.z * hgt / 330.0
	var passes: Array[Color] = [_lmc(Color("6f5544"))]
	if lights_a > 0.02:
		passes.append(Color(1.0, 0.72, 0.34, lights_a * 0.85))
	for col: Color in passes:
		var steps: Array[float] = [0.0, 14.0, 30.0, 44.0, 57.0, 75.0, 95.0, 117.0]
		for sd: float in [-1.0, 1.0]:
			for i in steps.size() - 1:
				var h0 := steps[i]
				var h1 := steps[i + 1]
				var o0 := eiffel_half_width(h0)
				var o1 := eiffel_half_width(h1)
				var i0 := maxf(0.0, o0 - lerpf(16.0, 9.5, h0 / 117.0))
				var i1 := maxf(0.0, o1 - lerpf(16.0, 9.5, h1 / 117.0))
				batch.quad(Vector2(p.x + sd * o0 * s, p.y - h0 * s), Vector2(p.x + sd * i0 * s, p.y - h0 * s),
					Vector2(p.x + sd * i1 * s, p.y - h1 * s), Vector2(p.x + sd * o1 * s, p.y - h1 * s), col)
		var ia := eiffel_half_width(10.0) - 15.0
		var prev := Vector2.ZERO
		for i in 9:
			var t := float(i) / 8.0
			var pt := Vector2(p.x + lerpf(-ia, ia, t) * s, p.y - (10.0 + 28.0 * (1.0 - pow(2.0 * t - 1.0, 2.0))) * s)
			if i > 0:
				batch.line(prev, pt, maxf(1.0, 3.0 * s), col)
			prev = pt
		_hbar(p, s, 57.0, 6.0, eiffel_half_width(57.0) + 3.0, col)
		_hbar(p, s, 115.0, 4.5, eiffel_half_width(115.0) + 2.0, col)
		var ups: Array[float] = [119.5, 160.0, 205.0, 245.0, 276.0]
		for i in ups.size() - 1:
			var w0 := eiffel_half_width(ups[i])
			var w1 := eiffel_half_width(ups[i + 1])
			batch.quad(Vector2(p.x - w0 * s, p.y - ups[i] * s), Vector2(p.x + w0 * s, p.y - ups[i] * s),
				Vector2(p.x + w1 * s, p.y - ups[i + 1] * s), Vector2(p.x - w1 * s, p.y - ups[i + 1] * s), col)
		_hbar(p, s, 276.0, 6.0, 7.0, col)
		batch.quad(Vector2(p.x - 3.4 * s, p.y - 282.0 * s), Vector2(p.x + 3.4 * s, p.y - 282.0 * s),
			Vector2(p.x + 1.8 * s, p.y - 302.0 * s), Vector2(p.x - 1.8 * s, p.y - 302.0 * s), col)
		batch.line(Vector2(p.x, p.y - 302.0 * s), Vector2(p.x, p.y - 330.0 * s), maxf(1.0, 1.2 * s), col)
	if 330.0 * s > 140.0 and lights_a < 0.5:
		# cross bracing of the shaft
		var lc := _lmc(Color("4e3b2f"), 0.8)
		var h := 125.0
		while h < 268.0:
			var w0 := eiffel_half_width(h)
			var w1 := eiffel_half_width(h + 18.0)
			batch.line(Vector2(p.x - w0 * s, p.y - h * s), Vector2(p.x + w1 * s, p.y - (h + 18.0) * s), maxf(1.0, 0.8 * s), lc)
			batch.line(Vector2(p.x + w0 * s, p.y - h * s), Vector2(p.x - w1 * s, p.y - (h + 18.0) * s), maxf(1.0, 0.8 * s), lc)
			h += 18.0
	if lights_a > 0.02:
		_lm_glow(Vector2(p.x, p.y - 300.0 * s), maxf(4.0, 14.0 * s), Color(1.0, 0.85, 0.6, 0.5 * lights_a))
		if fmod(_time, 60.0) < 9.0:
			# the hourly sparkle
			var v := int(_time * 12.0) * 7919
			for i in 14:
				v = (v * 1103515245 + 12345) & 0x7fffffff
				var hh := float(v % 290)
				var ww := eiffel_half_width(hh) * (float((v >> 9) % 200) / 100.0 - 1.0)
				_lm_glow(Vector2(p.x + ww * s, p.y - hh * s), maxf(1.5, 2.0 * s), Color(1, 1, 1, 0.8 * lights_a))


## Television tower (Berlin Fernsehturm, 368 m; any height): tapered shaft, sphere with window ring,
## antenna with red/white bands; aviation lights at night.
func _lm_tv(p: Vector3, hgt: float, lights_a: float) -> void:
	var s := p.z * hgt / 368.0
	var conc := _lmc(Color("dcdbd6"))
	var conc_d := _lmc(Color("b5b4ae"))
	var hs: Array[float] = [0.0, 40.0, 100.0, 200.0]
	var ws: Array[float] = [16.0, 11.5, 7.5, 4.5]
	for i in 3:
		batch.quad4(Vector2(p.x - ws[i] * s, p.y - hs[i] * s), Vector2(p.x, p.y - hs[i] * s), Vector2(p.x, p.y - hs[i + 1] * s), Vector2(p.x - ws[i + 1] * s, p.y - hs[i + 1] * s), conc, conc, conc, conc)
		batch.quad4(Vector2(p.x, p.y - hs[i] * s), Vector2(p.x + ws[i] * s, p.y - hs[i] * s), Vector2(p.x + ws[i + 1] * s, p.y - hs[i + 1] * s), Vector2(p.x, p.y - hs[i + 1] * s), conc_d, conc_d, conc_d, conc_d)
	var c := Vector2(p.x, p.y - 213.0 * s)
	batch.ellipse(c, Vector2(16.0 * s, 16.0 * s), _lmc(Color("c4c9d1")), _lmc(Color("8e949e")), 20)
	batch.rect(Rect2(p.x - 15.2 * s, c.y - 1.6 * s, 30.4 * s, 3.2 * s), _lmc(Color("4f5a68")))
	batch.quad(Vector2(p.x - 3.2 * s, p.y - 229.0 * s), Vector2(p.x + 3.2 * s, p.y - 229.0 * s), Vector2(p.x + 2.6 * s, p.y - 252.0 * s), Vector2(p.x - 2.6 * s, p.y - 252.0 * s), conc)
	for i in 10:
		var h0 := 252.0 + float(i) * 11.6
		var w0 := lerpf(1.9, 0.6, float(i) / 10.0)
		var w1 := lerpf(1.9, 0.6, float(i + 1) / 10.0)
		var band := _lmc(Color("c8402e") if i % 2 == 0 else Color("eeeeea"))
		batch.quad(Vector2(p.x - w0 * s, p.y - h0 * s), Vector2(p.x + w0 * s, p.y - h0 * s), Vector2(p.x + w1 * s, p.y - (h0 + 11.6) * s), Vector2(p.x - w1 * s, p.y - (h0 + 11.6) * s), band)
	if lights_a > 0.02:
		batch.rect(Rect2(p.x - 15.2 * s, c.y - 1.6 * s, 30.4 * s, 3.2 * s), Color(1.0, 0.85, 0.55, 0.8 * lights_a))
		var blink := fmod(_time, 1.5) < 0.75
		for hh: float in [252.0, 300.0, 368.0]:
			if blink or hh < 300.0:
				_lm_glow(Vector2(p.x, p.y - hh * s), maxf(2.5, 6.0 * s), Color(1, 0.12, 0.08, 0.85 * lights_a))


## Giant Ferris wheel (Wiener Riesenrad, 65 m): A-frame supports, rim, spokes, gondolas; bulbs at night.
func _lm_wheel(p: Vector3, hgt: float, lights_a: float) -> void:
	var s := p.z * hgt / 65.0
	var red := _lmc(Color("a8372c"))
	var steel := _lmc(Color("5f5a55"))
	var c := Vector2(p.x, p.y - 34.0 * s)
	var r := 30.5 * s
	for sd: float in [-1.0, 1.0]:
		batch.line(Vector2(p.x + sd * 21.0 * s, p.y), c, maxf(1.0, 1.4 * s), steel)
		batch.line(Vector2(p.x + sd * 11.0 * s, p.y), c, maxf(1.0, 0.9 * s), steel)
	var n := 32
	var rim: Array[Vector2] = []
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		rim.append(c + Vector2(cos(a), sin(a)) * r)
	for i in n:
		batch.line(rim[i], rim[i + 1], maxf(1.0, 0.9 * s), red)
	for i in 16:
		batch.line(c, rim[i * 2], maxf(0.8, 0.22 * s), steel)
	var rot := _time * 0.03
	for i in 15:
		var a := rot + TAU * float(i) / 15.0
		var q := c + Vector2(cos(a), sin(a)) * r
		batch.rect(Rect2(q.x - 2.6 * s, q.y, 5.2 * s, 3.0 * s), red)
	if lights_a > 0.02:
		for i in range(0, n, 2):
			_lm_glow(rim[i], maxf(1.5, 1.6 * s), Color(1.0, 0.85, 0.55, 0.7 * lights_a))


## Monument column with a statue (Freiheitsdenkmal Riga, 42 m): granite base, travertine column, copper
## figure holding three golden stars; illuminated at night.
func _lm_column(p: Vector3, hgt: float, lights_a: float) -> void:
	var s := p.z * hgt / 42.0
	var granite := _lmc(Color("9a948a"))
	batch.rect(Rect2(p.x - 11.0 * s, p.y - 4.0 * s, 22.0 * s, 4.0 * s), granite)
	batch.rect(Rect2(p.x - 7.5 * s, p.y - 8.5 * s, 15.0 * s, 4.5 * s), granite)
	batch.quad(Vector2(p.x - 1.8 * s, p.y - 34.0 * s), Vector2(p.x + 1.8 * s, p.y - 34.0 * s), Vector2(p.x + 2.6 * s, p.y - 8.5 * s), Vector2(p.x - 2.6 * s, p.y - 8.5 * s), _lmc(Color("ddd5c4")))
	var copper := _lmc(Color("6f9c86"))
	batch.quad(Vector2(p.x - 0.9 * s, p.y - 40.0 * s), Vector2(p.x + 0.9 * s, p.y - 40.0 * s), Vector2(p.x + 1.4 * s, p.y - 34.0 * s), Vector2(p.x - 1.4 * s, p.y - 34.0 * s), copper)
	batch.line(Vector2(p.x - 0.6 * s, p.y - 39.0 * s), Vector2(p.x - 0.2 * s, p.y - 42.6 * s), maxf(1.0, 0.5 * s), copper)
	batch.line(Vector2(p.x + 0.6 * s, p.y - 39.0 * s), Vector2(p.x + 0.2 * s, p.y - 42.6 * s), maxf(1.0, 0.5 * s), copper)
	var gold := _lmc(Color("e8c060"))
	for i in 3:
		batch.rect(Rect2(p.x + float(i - 1) * 1.1 * s - 0.4 * s, p.y - 43.6 * s, 0.8 * s, 0.8 * s), gold)
	if lights_a > 0.02:
		for i in 3:
			_lm_glow(Vector2(p.x + float(i - 1) * 1.1 * s, p.y - 43.2 * s), maxf(1.5, 1.2 * s), Color(1.0, 0.85, 0.4, 0.8 * lights_a))
		_lm_glow(Vector2(p.x, p.y - 20.0 * s), maxf(3.0, 9.0 * s), Color(1.0, 0.9, 0.7, 0.25 * lights_a), 2.5)


## Bell tower (Campanile di San Marco, 99 m): brick shaft with pilasters, white belfry, attic, copper
## pyramid with the golden angel.
func _lm_campanile(p: Vector3, hgt: float, lights_a: float) -> void:
	var s := p.z * hgt / 99.0
	var brick := _lmc(Color("b47a60"))
	batch.rect(Rect2(p.x - 6.0 * s, p.y - 50.0 * s, 12.0 * s, 50.0 * s), brick)
	batch.rect(Rect2(p.x + 1.5 * s, p.y - 50.0 * s, 4.5 * s, 50.0 * s), _lmc(Color("98604a")))
	var dark := _lmc(Color("7a4a38"))
	for xo: float in [-3.0, 0.0, 3.0]:
		batch.rect(Rect2(p.x + (xo - 0.3) * s, p.y - 48.0 * s, maxf(0.8, 0.6 * s), 46.0 * s), dark)
	batch.rect(Rect2(p.x - 6.6 * s, p.y - 61.0 * s, 13.2 * s, 11.0 * s), _lmc(Color("ece6d8")))
	for i in 4:
		batch.rect(Rect2(p.x + (-5.4 + float(i) * 2.9) * s, p.y - 59.0 * s, 1.8 * s, 7.0 * s), _lmc(Color("3a3430")))
	batch.rect(Rect2(p.x - 6.0 * s, p.y - 72.0 * s, 12.0 * s, 11.0 * s), brick)
	batch.tri(Vector2(p.x - 6.6 * s, p.y - 72.0 * s), Vector2(p.x + 6.6 * s, p.y - 72.0 * s), Vector2(p.x, p.y - 95.0 * s), _lmc(Color("6f9c86")))
	batch.rect(Rect2(p.x - 0.6 * s, p.y - 99.0 * s, 1.2 * s, 4.0 * s), _lmc(Color("e0b850")))
	if lights_a > 0.02:
		batch.rect(Rect2(p.x - 6.0 * s, p.y - 72.0 * s, 12.0 * s, 72.0 * s), Color(1.0, 0.78, 0.5, 0.35 * lights_a))
		_lm_glow(Vector2(p.x, p.y - 56.0 * s), maxf(3.0, 7.0 * s), Color(1.0, 0.85, 0.6, 0.45 * lights_a))


## Domed church (Alexander-Newski-Kathedrale, Frauenkirche Dresden, Sacré-Cœur …): body with roof, side
## domes, drum and main dome with lantern and cross; colours "wall"/"dome" from the catalogue.
func _lm_domed(it: Dictionary, p: Vector3, hgt: float, lights_a: float) -> void:
	var s := p.z * hgt / 80.0
	var wall_c := _color(str(it.get("wall", "#ece6d6")))
	var dome_c := _color(str(it.get("dome", "#d8b04a")))
	var wall := _lmc(wall_c)
	var shade := _lmc(wall_c.darkened(0.16))
	var dome := _lmc(dome_c)
	var dome_d := _lmc(dome_c.darkened(0.25))
	batch.rect(Rect2(p.x - 32.0 * s, p.y - 30.0 * s, 64.0 * s, 30.0 * s), wall)
	batch.rect(Rect2(p.x + 10.0 * s, p.y - 30.0 * s, 22.0 * s, 30.0 * s), shade)
	batch.quad(Vector2(p.x - 34.0 * s, p.y - 30.0 * s), Vector2(p.x + 34.0 * s, p.y - 30.0 * s), Vector2(p.x + 30.0 * s, p.y - 36.0 * s), Vector2(p.x - 30.0 * s, p.y - 36.0 * s), shade)
	for sd: float in [-1.0, 1.0]:
		var cx := p.x + sd * 22.0 * s
		batch.ellipse(Vector2(cx, p.y - 44.0 * s), Vector2(6.5 * s, 7.5 * s), dome, dome_d, 12)
		batch.rect(Rect2(cx - 5.5 * s, p.y - 44.0 * s, 11.0 * s, 8.0 * s), wall)
		batch.line(Vector2(cx, p.y - 51.0 * s), Vector2(cx, p.y - 56.0 * s), maxf(0.8, 0.5 * s), dome_d)
	batch.ellipse(Vector2(p.x, p.y - 54.0 * s), Vector2(13.5 * s, 16.0 * s), dome, dome_d, 18)
	batch.rect(Rect2(p.x - 12.0 * s, p.y - 54.0 * s, 24.0 * s, 18.0 * s), wall)
	for i in 5:
		batch.rect(Rect2(p.x + (-9.0 + float(i) * 4.2) * s, p.y - 51.0 * s, 1.4 * s, 8.0 * s), _lmc(wall_c.darkened(0.45)))
	batch.rect(Rect2(p.x - 2.0 * s, p.y - 74.0 * s, 4.0 * s, 5.0 * s), dome)
	batch.line(Vector2(p.x, p.y - 74.0 * s), Vector2(p.x, p.y - 80.0 * s), maxf(0.8, 0.6 * s), dome_d)
	batch.line(Vector2(p.x - 1.6 * s, p.y - 78.0 * s), Vector2(p.x + 1.6 * s, p.y - 78.0 * s), maxf(0.8, 0.5 * s), dome_d)
	if lights_a > 0.02:
		batch.rect(Rect2(p.x - 32.0 * s, p.y - 36.0 * s, 64.0 * s, 36.0 * s), Color(1.0, 0.8, 0.5, 0.3 * lights_a))
		_lm_glow(Vector2(p.x, p.y - 56.0 * s), maxf(4.0, 16.0 * s), Color(1.0, 0.82, 0.5, 0.4 * lights_a))


## Neo-gothic parliament (Budapest, 268 m wide, dome 96 m): long facade with red roof, spires along the
## ridge, side towers, central drum and ribbed dome; golden floodlight at night.
func _lm_parliament(p: Vector3, hgt: float, lights_a: float) -> void:
	var s := p.z * hgt / 96.0
	var wall := _lmc(Color("ece4d4"))
	var shade := _lmc(Color("cfc6b4"))
	var roof := _lmc(Color("b04a3a"))
	var dark := _lmc(Color("6e665a"))
	batch.rect(Rect2(p.x - 134.0 * s, p.y - 28.0 * s, 268.0 * s, 28.0 * s), wall)
	batch.quad(Vector2(p.x - 134.0 * s, p.y - 28.0 * s), Vector2(p.x + 134.0 * s, p.y - 28.0 * s), Vector2(p.x + 128.0 * s, p.y - 37.0 * s), Vector2(p.x - 128.0 * s, p.y - 37.0 * s), roof)
	if 268.0 * s > 220.0:
		for row in 2:
			var xw := -128.0
			while xw < 128.0:
				batch.rect(Rect2(p.x + xw * s, p.y - (9.0 + float(row) * 9.0) * s, 2.2 * s, 4.5 * s), dark)
				xw += 6.0
	var xs := -126.0
	while xs <= 126.0:
		batch.tri(Vector2(p.x + (xs - 1.2) * s, p.y - 36.0 * s), Vector2(p.x + (xs + 1.2) * s, p.y - 36.0 * s), Vector2(p.x + xs * s, p.y - 46.0 * s), wall)
		xs += 12.6
	for xt: float in [-108.0, -62.0, 62.0, 108.0]:
		batch.rect(Rect2(p.x + (xt - 3.0) * s, p.y - 50.0 * s, 6.0 * s, 22.0 * s), shade)
		batch.tri(Vector2(p.x + (xt - 3.4) * s, p.y - 50.0 * s), Vector2(p.x + (xt + 3.4) * s, p.y - 50.0 * s), Vector2(p.x + xt * s, p.y - 62.0 * s), roof)
	batch.rect(Rect2(p.x - 24.0 * s, p.y - 44.0 * s, 48.0 * s, 44.0 * s), wall)
	batch.ellipse(Vector2(p.x, p.y - 62.0 * s), Vector2(15.0 * s, 24.0 * s), roof, _lmc(Color("8a3a2e")), 18)
	batch.rect(Rect2(p.x - 14.0 * s, p.y - 62.0 * s, 28.0 * s, 18.0 * s), shade)
	for i in 6:
		batch.rect(Rect2(p.x + (-11.0 + float(i) * 4.4) * s, p.y - 59.0 * s, 1.5 * s, 10.0 * s), dark)
	batch.rect(Rect2(p.x - 2.2 * s, p.y - 89.0 * s, 4.4 * s, 5.0 * s), wall)
	batch.tri(Vector2(p.x - 2.4 * s, p.y - 89.0 * s), Vector2(p.x + 2.4 * s, p.y - 89.0 * s), Vector2(p.x, p.y - 96.0 * s), roof)
	if lights_a > 0.02:
		batch.rect(Rect2(p.x - 134.0 * s, p.y - 37.0 * s, 268.0 * s, 37.0 * s), Color(1.0, 0.78, 0.42, 0.45 * lights_a))
		_lm_glow(Vector2(p.x, p.y - 62.0 * s), maxf(5.0, 24.0 * s), Color(1.0, 0.8, 0.45, 0.5 * lights_a))


## Stepped high-rise in the style of Socialist Classicism (Palace of Culture Warsaw, 237 m): wings, set-back
## tiers with pinnacles, clock storey, crown and spire; floodlit at night.
func _lm_palace(p: Vector3, hgt: float, lights_a: float) -> void:
	var s := p.z * hgt / 237.0
	var wall := _lmc(Color("ddd2bc"))
	var shade := _lmc(Color("bdb19a"))
	var tiers: Array[Vector3] = [Vector3(45.0, 0.0, 30.0), Vector3(30.0, 30.0, 62.0), Vector3(22.0, 62.0, 102.0),
		Vector3(16.0, 102.0, 136.0), Vector3(11.0, 136.0, 162.0), Vector3(8.0, 162.0, 182.0), Vector3(6.0, 182.0, 190.0)]
	for tr: Vector3 in tiers:
		batch.rect(Rect2(p.x - tr.x * s, p.y - tr.z * s, 2.0 * tr.x * s, (tr.z - tr.y) * s), wall)
		batch.rect(Rect2(p.x + tr.x * 0.35 * s, p.y - tr.z * s, tr.x * 0.65 * s, (tr.z - tr.y) * s), shade)
		if tr.y > 0.0 and tr.y < 170.0:
			for sd: float in [-1.0, 1.0]:
				var px := p.x + sd * (tr.x + 3.0) * s
				batch.rect(Rect2(px - 1.6 * s, p.y - (tr.y + 14.0) * s, 3.2 * s, 14.0 * s), shade)
				batch.tri(Vector2(px - 1.8 * s, p.y - (tr.y + 14.0) * s), Vector2(px + 1.8 * s, p.y - (tr.y + 14.0) * s), Vector2(px, p.y - (tr.y + 21.0) * s), shade)
	batch.tri(Vector2(p.x - 3.0 * s, p.y - 190.0 * s), Vector2(p.x + 3.0 * s, p.y - 190.0 * s), Vector2(p.x, p.y - 237.0 * s), shade)
	if 237.0 * s > 160.0:
		var dark := _lmc(Color("8a8070"), 0.7)
		for i in 9:
			var xv := -20.0 + float(i) * 5.0
			batch.rect(Rect2(p.x + xv * s, p.y - 100.0 * s, maxf(0.8, 0.8 * s), 36.0 * s), dark)
	if lights_a > 0.02:
		batch.rect(Rect2(p.x - 30.0 * s, p.y - 190.0 * s, 60.0 * s, 160.0 * s), Color(1.0, 0.82, 0.55, 0.22 * lights_a))
		_lm_glow(Vector2(p.x, p.y - 172.0 * s), maxf(3.0, 6.0 * s), Color(1.0, 0.95, 0.8, 0.6 * lights_a))
		if fmod(_time, 1.5) < 0.75:
			_lm_glow(Vector2(p.x, p.y - 237.0 * s), maxf(2.5, 4.0 * s), Color(1, 0.12, 0.08, 0.85 * lights_a))


## Cluster of high-rises (Frankfurt's banking district, Madrid's Cuatro Torres): glass towers of different
## heights and tops; lit windows and aviation lights at night.
func _lm_skyscrapers(p: Vector3, hgt: float, lights_a: float) -> void:
	var s := p.z * hgt / 259.0
	# x offset, half width, height, colour, top (0 flat, 1 mast, 2 pyramid)
	var towers: Array = [[-62.0, 14.0, 150.0, "7f97ad", 0], [58.0, 13.0, 175.0, "c9bfa8", 2], [-20.0, 18.0, 259.0, "6a8098", 1],
		[22.0, 15.0, 205.0, "95aec4", 1], [86.0, 11.0, 120.0, "8aa0b4", 0]]
	for t: Array in towers:
		var xo := float(t[0])
		var hw := float(t[1])
		var th := float(t[2])
		var base := Color(str(t[3]))
		batch.rect(Rect2(p.x + (xo - hw) * s, p.y - th * s, 2.0 * hw * s, th * s), _lmc(base))
		batch.rect(Rect2(p.x + (xo + hw * 0.3) * s, p.y - th * s, hw * 0.7 * s, th * s), _lmc(base.darkened(0.18)))
		match int(t[4]):
			1:
				batch.line(Vector2(p.x + xo * s, p.y - th * s), Vector2(p.x + xo * s, p.y - (th + 22.0) * s), maxf(0.8, 0.8 * s), _lmc(base.darkened(0.3)))
			2:
				batch.tri(Vector2(p.x + (xo - hw) * s, p.y - th * s), Vector2(p.x + (xo + hw) * s, p.y - th * s), Vector2(p.x + xo * s, p.y - (th + 24.0) * s), _lmc(base.darkened(0.1)))
		if lights_a > 0.02:
			var v := int(absf(xo)) * 977 + 13
			var rows := int(th / 9.0)
			for r in rows:
				for c in 4:
					v = (v * 1103515245 + 12345) & 0x7fffffff
					if v % 100 < 35:
						batch.rect(Rect2(p.x + (xo - hw + 2.0 + float(c) * (hw * 2.0 - 4.0) / 4.0) * s, p.y - (th - 4.0 - float(r) * 9.0) * s, maxf(0.8, 2.4 * s), maxf(0.8, 2.0 * s)), Color(1.0, 0.88, 0.6, 0.8 * lights_a))
			if fmod(_time + absf(xo) * 0.01, 1.6) < 0.8:
				_lm_glow(Vector2(p.x + xo * s, p.y - th * s), maxf(2.5, 3.0 * s), Color(1, 0.12, 0.08, 0.85 * lights_a))


# --- weather and overlays -------------------------------------------------------------------

func _draw_weather() -> void:
	var weather := str(view.get("weather", "normal"))
	var dt := 0.016
	if _last_time >= 0.0:
		dt = clampf(_time - _last_time, 0.0, 0.1)
	_last_time = _time
	if weather == "normal":
		_wp.clear()
		_wp_kind = ""
		return
	var rain := weather == "rain"
	var n := 240 if rain else 420
	var z_near := 3.0 if rain else 2.0
	var z_far := 45.0 if rain else 38.0
	if _wp_kind != weather or _wp.size() != n:
		_wp_kind = weather
		_wp.resize(n)
		for i in n:
			_wp[i] = Vector3(_wrng.randf_range(-14.0, 14.0), _wrng.randf_range(0.0, 9.0), _wrng.randf_range(z_near, z_far))
	var v := float(view.get("speed", 0.0)) / 3.6
	var fall := 8.5 if rain else 1.2
	var hide := 0.0 if _cam_in_tunnel else 1.0
	var col := Color(0.8, 0.84, 0.92, 0.3 * hide) if rain else Color(1, 1, 1, 0.85 * hide)
	col = Color(col.r * minf(1.0, _amb_out.r + 0.35), col.g * minf(1.0, _amb_out.g + 0.35), col.b * minf(1.0, _amb_out.b + 0.35), col.a)
	var h := proj.cam_height
	for i in n:
		var q := _wp[i]
		q.z -= v * dt
		q.y -= fall * dt
		if rain:
			q.x += 0.6 * dt
		else:
			q.x += sin(_time * 0.9 + float(i)) * 0.7 * dt
		if q.z < z_near or q.y < -0.3 or absf(q.x) > 15.0:
			var respawn_far := q.z < z_near
			q = Vector3(_wrng.randf_range(-14.0, 14.0), _wrng.randf_range(4.0, 9.0) if not respawn_far else _wrng.randf_range(0.0, 9.0), _wrng.randf_range(z_far * 0.6, z_far) if respawn_far else q.z)
		_wp[i] = q
		if hide <= 0.0:
			continue
		var p0 := proj.project(q.x, q.y - h, q.z)
		if p0.x < -10.0 or p0.x > proj.screen.x + 10.0 or p0.y < -10.0 or p0.y > proj.screen.y + 10.0:
			continue
		if rain:
			# short streak: where the drop was 18 ms ago (higher and farther away)
			var bt := 0.018
			var p1 := proj.project(q.x - 0.6 * bt, q.y - h + fall * bt * 2.5, q.z + v * bt)
			batch.line(Vector2(p1.x, p1.y), Vector2(p0.x, p0.y), clampf(0.01 * p0.z, 0.8, 1.6), col)
		else:
			var sz := clampf(0.045 * p0.z, 1.2, 5.5)
			if v > 25.0:
				var p1 := proj.project(q.x, q.y - h + fall * 0.01, q.z + v * 0.008)
				batch.line(Vector2(p1.x, p1.y), Vector2(p0.x, p0.y), sz, Color(col, col.a * 0.9))
			else:
				batch.rect(Rect2(p0.x - sz * 0.5, p0.y - sz * 0.5, sz, sz), col)


func _draw_overlays() -> void:
	var chase := float(view.get("chase01", 0.0))
	if chase > 0.02:
		var w := proj.screen.x
		var hgt := proj.screen.y
		var phase := fmod(_time * 2.5, 1.0) < 0.5
		var blue := Color(0.15, 0.3, 1.0, 0.32 * chase)
		var red := Color(1.0, 0.1, 0.1, 0.22 * chase)
		_glow(Vector2(0 if phase else w, hgt), 330.0, blue)
		_glow(Vector2(w if phase else 0, hgt), 260.0, red)
