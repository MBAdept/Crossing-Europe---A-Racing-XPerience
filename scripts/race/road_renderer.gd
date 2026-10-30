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
##
## Input: render(view) once per frame (see ARCHITECTURE.md §Renderer-View). Extra view keys used
## here: length (player/cars), countdown, chase01, radar_flash01, camera_in_tunnel.
## Owner: race module.

const LIGHT_COL := Color(1.0, 0.93, 0.8)
const LAMP_COL := Color(1.0, 0.82, 0.55)
const TILE := Color("d9d3c2")
const WALL := Color("75716a")
const HAUNCH := Color("57544e")
const CEILING := Color("3e3b35")
const CONCRETE := Color("b9b5aa")
const ROCK := Color("7d7466")
const STATS_N := 600

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

# per-frame projected rows (k = 0 is the segment start at or behind the camera)
var _n := 0
var _base := 0
var _dz := PackedFloat32Array()
var _zw := PackedFloat32Array()
var _xw := PackedFloat32Array()
var _yw := PackedFloat32Array()
var _hd := PackedFloat32Array()
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
	show_stats = bool(ConfigLoader.lookup(cfg, "debug.show_render_stats", false))
	var mode := str(r.get("procedural_props", "auto"))
	var manifest: Variant = ConfigLoader.load_json("res://assets/sprites/manifest.json")
	var placeholders := manifest is Dictionary and str((manifest as Dictionary).get("generator", "")) == "placeholders"
	_prefer_proc = mode == "always" or (mode == "auto" and placeholders)
	backdrop.setup(proj, batch, float(r.get("background_blend_s", 2.5)))
	signs.setup(self, batch)
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
		backdrop.draw_background(_pal_out, scen_id, scen.get("background", {}), heading, _time, haze * 0.9, base_y)
		batch.rect(Rect2(-40, base_y, w + 80, proj.screen.y - base_y + 40), _exposed(_pal_out["fog"]))
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
	var a_hd := PackedFloat32Array()
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
	a_hd.resize(count + 1)
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
		a_hd[k] = dx / seg_len
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
	_hd = a_hd
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
	return seg.city and fposmod(seg.z, _crosswalk_every) < _seg_len


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
	if absf(sa.fuel_lane - sb.fuel_lane) > 0.01 or absf(sa.lanes - sb.lanes) > 0.01:
		return false
	if _has_marking(sb):
		return false
	var t := float(b - a) / float(b + 1 - a)
	return absf(lerpf(_sx[a], _sx[b + 1], t) - _sx[b]) <= 2.0


# --- screen helpers -------------------------------------------------------------------------

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
	# grass (full width; split at night so the headlight cone can light the verge)
	if not tunnel:
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
	elif sa.city and fposmod(sa.z, _crosswalk_every) < _seg_len:
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
		res = ["", [], 1.0, x, proc, Color.WHITE]
	elif set_id == "":
		res = ["", [], 0.0, x, "", Color.WHITE]
	else:
		var info := _spinfo(set_id)
		var sc := _prop_scale(it, set_id)
		if it.has("align"):
			# "edge": x is the near edge of the object -> shift its anchor away from the road by the
			# object's extent towards the road (extent_m of the manifest, else half its width)
			var side := int(it.get("side", 1))
			var ext: Vector2 = info[7]
			x += float(side) * (ext.x if side > 0 else ext.y) * sc
		res = [set_id, info, sc, x, "", Color(str(it["tint"])) if it.has("tint") else Color.WHITE]
	it["_c"] = res
	return res


func _draw_item(k: int, it: Dictionary) -> void:
	var z := float(it.get("z", _zw[k]))
	var f := clampf((z - _zw[k]) / _seg_len, 0.0, 1.0)
	var kind := str(it.get("kind", "prop"))
	if kind == "prop":
		var pc := _prep_prop(it)
		var info: Array = pc[1]
		var px := float(pc[3])
		if not info.is_empty():
			# sprite prop: cheap culling (size, screen) before any shading work
			var p := _proj_at(k, f, px, 0.0)
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
			if str(it.get("sign", "")) == "distance":
				it["road"] = _segs[k].road
			signs.draw(it, p2, lit, alpha2, edges_px)
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


## Cached sprite metadata: [texture, pixels per metre, anchor, cell size, {angle: column}, {layer: row}]
## or [] when the set or its texture does not exist (missing sprites are skipped).
func _spinfo(set_id: String) -> Array:
	var c: Variant = _sp_cache.get(set_id)
	if c != null:
		return c
	var info: Array = []
	var tex := SpriteDB.texture(set_id) if set_id != "" else null
	if tex != null:
		var cols := {}
		for a: String in ["l2", "l1", "c", "r1", "r2"]:
			cols[a] = (SpriteDB.get_set(set_id)["angles"] as Array).find(SpriteDB.resolve_angle(set_id, a))
		var rows := {}
		var layers: Array = SpriteDB.get_set(set_id)["layers"]
		for i in layers.size():
			rows[str(layers[i])] = i
		var obj: Dictionary = SpriteDB.object_size(set_id)
		var half_w := float(obj.get("width_m", SpriteDB.cell_size(set_id).x / SpriteDB.pixels_per_meter(set_id) * 0.8)) * 0.5
		# extent_m (Blender manifest): distance from the anchor to the near side when placed right / left
		var ext: Array = SpriteDB.get_set(set_id).get("extent_m", [half_w, half_w])
		var extent := Vector2(float(ext[0]), float(ext[1])) if ext.size() >= 2 else Vector2(half_w, half_w)
		var mirror_left := (SpriteDB.get_set(set_id).get("tags", []) as Array).has("mirror_left")
		info = [tex, SpriteDB.pixels_per_meter(set_id), SpriteDB.anchor(set_id), SpriteDB.cell_size(set_id), cols, rows, half_w, extent, mirror_left]
	_sp_cache[set_id] = info
	return info


func _has_layer(set_id: String, layer: String) -> bool:
	var info := _spinfo(set_id)
	return not info.is_empty() and (info[5] as Dictionary).has(layer)


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
	var row := int((info[5] as Dictionary).get(layer, -1))
	if row < 0:
		return Rect2()
	var cell: Vector2 = info[3]
	var col := int((info[4] as Dictionary).get(angle, 0))
	var w := cell.x / float(info[1]) * p.z * scale
	var h := w * cell.y / cell.x
	if w < 0.8 or w > proj.screen.x * 5.0:
		return Rect2()
	var an: Vector2 = info[2]
	var ax := (1.0 - an.x) if flip else an.x
	var dest := Rect2(p.x - ax * w, p.y - an.y * h, w, h)
	if dest.position.x > proj.screen.x + 4.0 or dest.end.x < -4.0 or dest.position.y > proj.screen.y + 4.0 or dest.end.y < -4.0:
		return Rect2()
	var src := Rect2(float(col) * cell.x, float(row) * cell.y, cell.x, cell.y)
	var tex: Texture2D = info[0]
	batch.flush()
	if flip:
		draw_texture_rect_region(tex, Rect2(dest.position.x + w, dest.position.y, -w, h), src, modulate)
	else:
		draw_texture_rect_region(tex, dest, src, modulate)
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
	var flip := int(it.get("side", 1)) < 0 and (bool(it.get("mirror", false)) or bool(info[8]))
	var mod := _modulate(k, light, alpha)
	var tint: Color = pc[5]
	if tint != Color.WHITE:
		mod = Color(mod.r * tint.r, mod.g * tint.g, mod.b * tint.b, mod.a)
	var r := _sprite_i(info, "c", "base", p, scale, mod, flip)
	if r.size.x <= 0.0:
		return
	if _lights > 0.05 and (info[5] as Dictionary).has("lights"):
		_sprite_i(info, "c", "lights", p, scale, Color(1, 1, 1, alpha * _lights), flip)


func _car_angle(k: int, f: float, x: float, p: Vector3) -> String:
	var heading := lerpf(_hd[k], _hd[mini(k + 1, _n)], f)
	var dz := proj.focal / p.z
	var xr := lerpf(_xw[k], _xw[k + 1], f) + x
	var yaw := rad_to_deg(atan(heading) - atan2(xr, maxf(dz, 0.5)))
	if yaw > 18.5:
		return "r2"
	if yaw > 6.5:
		return "r1"
	if yaw < -18.5:
		return "l2"
	if yaw < -6.5:
		return "l1"
	return "c"


func _draw_car(k: int, f: float, it: Dictionary, p: Vector3, alpha: float, light: float) -> void:
	if not bool(it.get("visible", true)):
		return
	var set_id := str(it.get("set", ""))
	var player := bool(it.get("player", false))
	var angle := str(it["angle"]) if it.has("angle") else _car_angle(k, f, float(it.get("x", 0.0)), p)
	var mod := _modulate(k, light, alpha, 0.55)
	if player:
		mod = Color(minf(1.3, mod.r * 1.15 + 0.08), minf(1.3, mod.g * 1.15 + 0.08), minf(1.3, mod.b * 1.15 + 0.1), alpha)
	var r := _sprite(set_id, angle, "base", p, 1.0, mod)
	if r.size.x <= 0.0:
		return
	var lights := _lights if not _segs[k].tunnel else 1.0
	var tail := maxf(float(it.get("tail", 0.0)), lights)
	var brake := float(it.get("brake", 0.0))
	var light_alpha := alpha if _lights < 0.3 else minf(1.0, alpha * 1.6)
	if tail > 0.05 and _has_layer(set_id, "tail"):
		_sprite(set_id, angle, "tail", p, 1.0, Color(1, 1, 1, light_alpha * tail))
	if brake > 0.05 and _has_layer(set_id, "brake"):
		_sprite(set_id, angle, "brake", p, 1.0, Color(1, 1, 1, light_alpha * brake))
	var beacon := str(it.get("beacon", ""))
	if beacon != "" and _has_layer(set_id, "beacon_" + beacon):
		_sprite(set_id, angle, "beacon_" + beacon, p, 1.0, Color(1, 1, 1, light_alpha))
	var obj: Dictionary = SpriteDB.object_size(set_id)
	var cw := float(obj.get("width_m", 1.8))
	var ch := float(obj.get("height_m", 1.5))
	var s := p.z
	# glows: tail/brake lights (night or braking), police beacon
	var glow_a := clampf(tail * lights * 0.9 + brake * (0.35 + 0.4 * lights), 0.0, 1.0) * alpha
	if glow_a > 0.03:
		var gy := p.y - ch * 0.42 * s
		var gr := clampf((0.32 + brake * 0.12 + lights * 0.18) * s, 2.0, 70.0)
		var gcol := Color(1.0, 0.16, 0.06, 0.5 * glow_a)
		_glow(Vector2(p.x - cw * 0.38 * s, gy), gr, gcol)
		_glow(Vector2(p.x + cw * 0.38 * s, gy), gr, gcol)
		if _wet > 0.0 and lights > 0.2:
			# streaky reflections of the rear lights on the wet road (soft, fading towards the viewer)
			var rc := Color(1.0, 0.22, 0.12, (0.12 if player else 0.22) * glow_a * _wet)
			var rl := (0.45 if player else 0.8) * s
			for side: float in [-1.0, 1.0]:
				var x0 := p.x + side * cw * 0.38 * s
				batch.quad4(Vector2(x0 - 0.08 * s, p.y - 0.02 * s), Vector2(x0 + 0.08 * s, p.y - 0.02 * s), Vector2(x0 + 0.14 * s, p.y + rl), Vector2(x0 - 0.14 * s, p.y + rl), rc, rc, Color(rc, 0.0), Color(rc, 0.0))
	if beacon != "":
		var bc := Color(0.25, 0.45, 1.0, 0.7 * alpha) if beacon == "a" else Color(0.35, 0.55, 1.0, 0.45 * alpha)
		var bx := p.x + (-0.25 if beacon == "a" else 0.25) * s
		_glow(Vector2(bx, p.y - (ch + 0.1) * s), maxf(3.0, (1.2 + lights) * s), bc)
	# spray in the rain
	var spd := float(it.get("speed", 100.0))
	if _wet > 0.0 and not _segs[k].tunnel and spd > 40.0 and not player:
		var sa := clampf((spd - 40.0) / 120.0, 0.0, 1.0) * 0.28 * alpha * _wet
		var spray := Color(_fogc.lerp(Color(0.9, 0.92, 0.95), 0.5), sa)
		batch.ellipse(Vector2(p.x, p.y - 0.45 * s), Vector2(cw * 0.75 * s, 0.6 * s), spray, Color(spray, 0.0), 12)


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
