class_name VehicleStandIn
extends RefCounted
## Stand-in of a vehicle set that has no 3D model in the mode "Modern": Arcade's own picture of that vehicle, so no
## vehicle is ever drawn worse than in Arcade (lead decision for gate 1; docs/renderer-modern.md §10.8). A set with a
## model never comes here – when the manifest gets a model, the stand-in disappears by itself (no set ids in code).
##  * sprite sets (traffic, police: ortho cells, 17 yaw angles, rear pivot; player cars: perspective cells, 21
##    angles): one MultiMesh per sheet (SheetBatch), one instance per car – an upright quad at the cell's anchor,
##    the cell chosen exactly like RoadRenderer._vehicle_cell / _draw_player (VehiclePose.ortho_yaw / player_yaw_target
##    with Arcade's damping and hysteresis), the inputs taken from the 3D camera; near the camera the cell is folded
##    onto the car's rear and flank like Arcade's flank warp – in true 3D every strip stands at its own depth;
##  * box sets (trucks, buses: "render": "box"): a real box per part with Arcade's face pictures (rear, left, right,
##    top; the front shows the rear picture), lamp pictures as overlays, articulated (leading unit and trailer) when
##    the set has more than one part;
##  * light: the sheets carry baked light – modulated like Arcade (ArcadeShade: ambient of the palette or the tunnel,
##    headlights of the player and of the traffic ahead, Arcade's fog tint).
## Pure helpers are static and need no autoload: the sprite database is passed in (the autoload SpriteDB in the game,
## a fixture instance in tests), so -s scripts and unit tests can name this class.
## Owner: R3E (vehicles). Tests: tests/unit/race3d/test_vehicle_standin.gd, tests/race3d/render/check_vehicle_standin.gd.

const KIND_SPRITE := "sprite"
const KIND_BOX := "boxtex"
const MAX_YAWS := 32                    ## yaw table of the shader (vehicle_sprite.gdshader: yaws[32])
const FOLD_MIN_DEG := 1.0               ## Arcade warps only cells turned at least this much (RoadRenderer._car_warp)
const FLOATS := 20                      ## MultiMesh layout: 12 transform + 4 colour + 4 custom
const CASTER_FLOATS := 12
## Articulated box sets (no pivots in the sprite manifest): the coupling of AS1's semitrailer model – kingpin 1.65 m
## behind the front of the trailer part, 1.19 m high; the leading unit turns about its rear axle 0.6 m behind it.
const KINGPIN_BEHIND_FRONT_M := 1.65
const KINGPIN_HEIGHT_M := 1.19
const LEAD_PIVOT_BEHIND_KINGPIN_M := 0.6
## Arcade's modulate of vehicles (RoadRenderer._draw_car / _draw_box_item: _modulate(k, light, alpha, 0.55)).
const REFLECT := 0.55


# --- the sheet of a set ------------------------------------------------------------------------------------------

## What the stand-in of a set is: KIND_SPRITE, KIND_BOX, or "" when the sprite database has no sheet for it (then
## the painted box of ModelFactory.build_box is the last resort). db = SpriteDB (or a fixture instance).
static func kind_of(set_id: String, db: Object) -> String:
	if db == null or not bool(db.call(&"has_set", set_id)):
		return ""
	var s: Dictionary = db.call(&"get_set", set_id)
	if str(s.get("file", "")) == "":
		return ""
	if bool(db.call(&"is_box", set_id)):
		return KIND_BOX if not (db.call(&"box_parts", set_id) as Array).is_empty() else ""
	var c: Vector2 = db.call(&"cell_size", set_id)
	return KIND_SPRITE if c.x > 0.0 and c.y > 0.0 and int(db.call(&"angle_count", set_id)) > 0 else ""


## Everything the layer needs to draw a set from its sheet, without loading the texture (sheet_texture() does):
## kind, cell (px), grid, n (angles), rows {layer: row}, ppm, anchor, size_m (quad width = image_width_m, height),
## yaws, persp, ss (supersample), cam_d, rear (explicit rear pivot: Arcade warps it), elev (rad), obj (w, l, h);
## box sets: parts, lights. {} when the set has no sheet.
static func sheet_info(set_id: String, db: Object) -> Dictionary:
	var kind := kind_of(set_id, db)
	if kind == "":
		return {}
	var s: Dictionary = db.call(&"get_set", set_id)
	var o: Dictionary = db.call(&"object_size", set_id)
	var obj := Vector3(float(o.get("width_m", 1.8)), float(o.get("length_m", 4.5)), float(o.get("height_m", 1.5)))
	var info := {"kind": kind, "set": set_id, "obj": obj}
	if kind == KIND_BOX:
		info["parts"] = db.call(&"box_parts", set_id)
		info["lights"] = db.call(&"box_lights", set_id)
		return info
	var cell: Vector2 = db.call(&"cell_size", set_id)
	var ppm := maxf(0.001, float(db.call(&"pixels_per_meter", set_id)))
	var rows := {}
	var layers: Array = s.get("layers", ["base"])
	for i in layers.size():
		rows[str(layers[i])] = i
	var angles: Array = s.get("angles", ["c"])
	var cols := {}
	for i in angles.size():
		cols[str(angles[i])] = i
	var persp := str(db.call(&"projection", set_id)) == "perspective"
	var cam: Dictionary = db.call(&"camera", set_id)
	var w := cell.x / ppm
	info.merge({"cell": cell, "grid": int(db.call(&"grid_cols", set_id)), "n": angles.size(), "rows": rows, "cols": cols,
		"ppm": ppm, "anchor": db.call(&"anchor", set_id), "size_m": Vector2(w, w * cell.y / cell.x),
		"yaws": db.call(&"yaw_list", set_id), "persp": persp, "ss": float(db.call(&"supersample", set_id)),
		"cam_d": float(cam.get("distance_m", 9.0)),
		"rear": s.has("pivot") and str(db.call(&"pivot", set_id)) == "rear" and not persp,
		"elev": deg_to_rad(float(s.get("elevation_deg", 0.0)))})
	return info


## The sheet texture of a set (loads it on the first call – SpriteDB counts that in `loads`).
static func sheet_texture(set_id: String, db: Object) -> Texture2D:
	if db == null:
		return null
	return db.call(&"texture", set_id) as Texture2D


# --- cell choice: Arcade's, with the inputs taken from the 3D camera -------------------------------------------

## Camera-space inputs of Arcade's ortho yaw formula for a car: Vector3(d_r = depth of its rear centre, x_r = lateral
## offset of the rear centre from the camera axis, h = heading of the road chord from the rear to the front relative
## to the camera axis). inv = the inverse of the camera transform, rear = the car's rear centre on the road,
## chord_rear / chord_front = two points of the road one vehicle length apart – the road centre at its rear and
## front, or the car's own rear and front centre (the same direction on a bend of constant radius) – all world,
## origin-relative. On a straight road with the camera on the road axis these are exactly the d_r, xr_road + x and
## chord_heading() of RoadRenderer._vehicle_cell.
static func view_inputs(inv: Transform3D, rear: Vector3, chord_rear: Vector3, chord_front: Vector3) -> Vector3:
	var r := inv * rear
	var a := inv * chord_rear
	var b := inv * chord_front
	var along := -(b.z - a.z)
	var h := atan2(b.x - a.x, along) if absf(along) > 1.0e-6 or absf(b.x - a.x) > 1.0e-6 else 0.0
	return Vector3(-r.z, r.x, h)


## view_inputs() of a car whose own rear and front centre give the chord (two transforms instead of three).
static func view_inputs_car(inv: Transform3D, rear: Vector3, front: Vector3) -> Vector3:
	var r := inv * rear
	var b := inv * front
	var along := -(b.z - r.z)
	var h := atan2(b.x - r.x, along) if absf(along) > 1.0e-6 or absf(b.x - r.x) > 1.0e-6 else 0.0
	return Vector3(-r.z, r.x, h)


## Heading of a camera transform (rad, + = right; the convention of RoadPath3D.fwd_of: forward = (sin a, 0, -cos a)).
static func camera_heading(cam: Transform3D) -> float:
	var f := -cam.basis.z
	return atan2(f.x, -f.z)


## Arcade's cell of a rear-pivot ortho car (RoadRenderer._vehicle_cell): the display yaw VehiclePose.ortho_yaw from
## the view inputs (vin of view_inputs()) and the own heading psi_c, critically damped per car (dt = simulation time
## step, tau = render.vehicle_yaw_smooth_s), the cell picked with hysteresis (render.vehicle_cell_hysteresis).
## st = the car's state [display yaw (rad), its velocity, cell (-1 = new car)], updated in place. An explicit cell
## (forced >= 0, the item's "angle") wins, as in Arcade.
static func traffic_cell(st: PackedFloat32Array, yaws: PackedFloat32Array, vin: Vector3, psi_c: float, length: float,
		max_deg: float, dt: float, tau: float, hyst: float, forced: int = -1) -> int:
	if forced >= 0:
		return forced
	var target := VehiclePose.ortho_yaw(vin.x, vin.y, vin.z, psi_c, length, max_deg)
	if st[2] >= 0.0:
		var r := VehiclePose.damp(st[0], st[1], target, dt, tau)
		st[0] = r.x
		st[1] = r.y
	else:
		st[0] = target
		st[1] = 0.0
	var cell := VehiclePose.pick_cell(yaws, rad_to_deg(st[0]), int(st[2]), hyst)
	st[2] = float(cell)
	return cell


## Arcade's cell of the player car (RoadRenderer._update_player_pose / _draw_player): target VehiclePose.
## player_yaw_target(curve heading, steer, lateral speed, speed, understeer, curve, view angle, k), critically damped
## (tau = render.player_yaw_smooth_s; the first call takes the target), the cell picked with hysteresis.
## curve_heading = road heading player_curve_lookahead_m ahead of the car centre relative to the camera axis,
## view_angle = atan2(lateral, depth) of the car centre in camera space. st = [yaw, velocity, cell, initialised].
static func player_cell(st: PackedFloat32Array, yaws: PackedFloat32Array, curve_heading: float, steer: float, lat_mps: float,
		speed_mps: float, understeer: float, curve: float, view_angle: float, k: Dictionary, dt: float, tau: float, hyst: float) -> int:
	var target := VehiclePose.player_yaw_target(curve_heading, steer, lat_mps, speed_mps, understeer, curve, view_angle, k)
	if st[3] < 0.5:
		st[0] = target
		st[1] = 0.0
		st[3] = 1.0
	else:
		var r := VehiclePose.damp(st[0], st[1], target, dt, tau)
		st[0] = r.x
		st[1] = r.y
	var cell := VehiclePose.pick_cell(yaws, rad_to_deg(st[0]), int(st[2]), hyst)
	st[2] = float(cell)
	return cell


## Margin below the lowest row of a pulled perspective picture (vehicle_sprite.gdshader: pull_margin).
const PULL_MARGIN_M := 0.15


## Factor (<= 1) by which an upright perspective picture is pulled towards the eye (scaled about it: the same pixels,
## a nearer depth) so that its lowest row does not reach under the road: ay = height of its anchor relative to the eye
## (negative below it), vb = its lowest row relative to the anchor (negative). The same as persp_pull() of
## vehicle_sprite.gdshader. The player's picture reaches far below its anchor – the rear of the car is nearer than the
## ground point under its centre – and would otherwise be cut off by the road.
static func persp_pull(ay: float, vb: float) -> float:
	if ay > -0.1:
		return 1.0
	return clampf(ay / (ay + vb - PULL_MARGIN_M), 0.3, 1.0)


## True when Arcade draws the cell through its flank warp (RoadRenderer._car_warp): render.vehicle_warp on, a set with
## an explicit rear pivot, the cell turned at least FOLD_MIN_DEG, and the car long against the depth of its rear
## (length / d_r >= render.vehicle_warp_min_ratio). A rear at or behind the camera always folds (Arcade drops such a
## car; in true 3D the part of its flank ahead of the camera stays visible).
static func folds(warp_on: bool, rear_pivot: bool, psi_deg: float, length: float, d_r: float, ratio: float) -> bool:
	if not warp_on or not rear_pivot or absf(psi_deg) < FOLD_MIN_DEG:
		return false
	return d_r <= 0.05 or length / d_r >= ratio


## The four columns of a folded cell (what vehicle_sprite.gdshader computes per vertex), left to right, as
## [sprite x (m from the anchor), s (lateral from the rear centre, + right), t (ahead of the rear)] – Arcade's
## VehiclePose.warp_columns with one strip per face (rear face, flank, beyond the front). psi = yaw of the cell (rad),
## x_left / x_right = the cell edges in metres from the anchor.
static func fold_columns(psi: float, width: float, length: float, x_left: float, x_right: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var sn := sin(psi)
	var cs := cos(psi)
	var hw := width * 0.5
	if psi > 0.0:
		var corner := clampf(hw * cs, x_left, x_right)
		var front := clampf(hw * cs + length * sn, corner, x_right)
		var tf := clampf((front - hw * cs) / maxf(sn, 1.0e-4), 0.0, length)
		var x3 := maxf(x_right, front)
		out.append_array([minf(x_left, corner), minf(x_left, corner) / cs, 0.0, corner, hw, 0.0, front, hw, tf,
			x3, hw + (x3 - front) / cs, tf])
	else:
		var corner := clampf(-hw * cs, x_left, x_right)
		var front := clampf(-hw * cs + length * sn, x_left, corner)
		var tf := clampf((front + hw * cs) / minf(sn, -1.0e-4), 0.0, length)
		var x0 := minf(x_left, front)
		var x3 := maxf(x_right, corner)
		out.append_array([x0, -hw - (front - x0) / cs, tf, front, -hw, tf, corner, -hw, 0.0, x3, x3 / cs, 0.0])
	return out


# --- light: Arcade's modulate ------------------------------------------------------------------------------------

## Arcade's light of sprites and box faces (RoadRenderer._prepare, _light, _ctx, _modulate): ambient of the palette
## (inside tunnels the tunnel's, with the eye adapted when the camera is inside one), the light of the player's
## headlights and of the traffic ahead, the fog tint of the row. prepare() once per frame, then modulate() per car.
class ArcadeShade:
	var hl_range := 80.0
	var hl_int := 0.95
	var fog_start_frac := 0.45
	var t_fog := 260.0
	var seg_len := 3.0
	var lights := 0.0
	var lit := false
	var cam_in_tunnel := false
	var cam_z := 0.0
	var fog_start := 405.0
	var fog_span := 495.0
	var amb_out := Color.WHITE
	var fog_out := Color.WHITE
	var amb_tun := Color.WHITE
	var fog_tun := Color.BLACK
	var hl_i := 0.0
	var hl_z := -1.0e9
	var hl_x := 0.0
	var ls_z := PackedFloat32Array()
	var ls_x := PackedFloat32Array()
	var ls_r := PackedFloat32Array()
	var ls_i := PackedFloat32Array()
	var ls_kind := PackedInt32Array()     ## 1 = cone of a car ahead, 0 = pool of a static lamp
	var cam_distance := 9.0
	var lamp_every := 33.0
	var vis := 900.0

	## render.* of the configuration (headlight_range_m, headlight_intensity, fog_start_frac, tunnel.darkness_m), the
	## segment length, the camera distance (render.camera_distance_m) and road.streetlight_every_m.
	func setup(render_cfg: Dictionary, segment_length: float, camera_distance: float = 9.0, streetlight_every: float = 33.0) -> void:
		hl_range = float(render_cfg.get("headlight_range_m", 80.0))
		hl_int = float(render_cfg.get("headlight_intensity", 0.95))
		fog_start_frac = float(render_cfg.get("fog_start_frac", 0.45))
		var tun: Variant = render_cfg.get("tunnel", {})
		t_fog = float((tun as Dictionary).get("darkness_m", 260.0)) if tun is Dictionary else 260.0
		seg_len = maxf(0.1, segment_length)
		cam_distance = camera_distance
		lamp_every = maxf(1.0, streetlight_every)

	## Once per frame (RoadRenderer._prepare and the light part of _project): palette, tunnel state of the camera,
	## headlights of the player and the traffic ahead, and – lit – the pools of the static lamps of the track near
	## the camera (RoadRenderer._collect_static_lights: city street lights, fuel canopies, covers).
	func prepare(view: Dictionary, camera_in_tunnel: bool, track: Track = null) -> void:
		var pal: Dictionary = view.get("palette", {})
		vis = float(view.get("visibility_m", 900.0))
		cam_z = float(view.get("camera_z", 0.0))
		fog_start = vis * fog_start_frac
		fog_span = maxf(1.0, vis - fog_start)
		lights = float(pal.get("lights", 0.0))
		cam_in_tunnel = camera_in_tunnel
		amb_out = pal.get("ambient", Color.WHITE)
		fog_out = pal.get("fog", Color(0.75, 0.8, 0.85))
		amb_tun = Palette.TUNNEL_AMBIENT
		fog_tun = Palette.TUNNEL_FOG
		if cam_in_tunnel:
			amb_out = Color(minf(2.0, amb_out.r * 1.7 + 0.25), minf(2.0, amb_out.g * 1.7 + 0.25), minf(2.0, amb_out.b * 1.7 + 0.25))
			fog_out = fog_out.lerp(Color(1, 1, 0.97), 0.55)
		else:
			amb_tun = amb_tun * (0.5 + 0.5 * lights)
		lit = lights > 0.04 or cam_in_tunnel
		hl_i = hl_int * clampf(lights * 1.4, 0.0, 1.0)
		if cam_in_tunnel:
			hl_i = maxf(hl_i, 0.35)
		var player: Variant = view.get("player", {})
		if player is Dictionary and not (player as Dictionary).is_empty():
			hl_z = float((player as Dictionary).get("z", 0.0)) + float((player as Dictionary).get("length", 4.6))
			hl_x = float((player as Dictionary).get("x", 0.0))
		ls_z.clear()
		ls_x.clear()
		ls_r.clear()
		ls_i.clear()
		ls_kind.clear()
		if lit and lights > 0.04:
			for c: Variant in view.get("cars", []):
				var cd: Dictionary = c
				var cz := float(cd.get("z", 0.0)) + float(cd.get("length", 4.5))
				if cz > cam_z and cz < cam_z + 140.0 and ls_z.size() < 6:
					_add(cz, float(cd.get("x", 0.0)), 34.0, 0.5 * lights, 1)
			if track != null:
				_static_lights(track, float(view.get("camera_distance", cam_distance)))

	func _add(z: float, x: float, r: float, i: float, kind: int) -> void:
		ls_z.append(z)
		ls_x.append(x)
		ls_r.append(r)
		ls_i.append(i)
		ls_kind.append(kind)

	## RoadRenderer._collect_static_lights over the rows of RoadRenderer._project that are lit (depth below the
	## camera distance + headlight reach + 10 m, at least 150 m when a city starts within 100 m), every third row
	## from the camera's segment on.
	func _static_lights(track: Track, cam_dist: float) -> void:
		var base := mini(int(floor(cam_z / seg_len)), track.segment_count - 2)
		var lit_limit := cam_dist + hl_range + 10.0
		if track.is_city_at(cam_z + 100.0):
			lit_limit = maxf(lit_limit, 150.0)
		var rows := 0
		var row_cap := mini(int(vis / seg_len) + 2, track.segment_count - 1 - base) + 1
		while rows < row_cap and float(base + rows) * seg_len - cam_z < lit_limit:
			rows += 1
		var lw := track.lane_w
		for k in range(0, rows, 3):
			var seg := track.get_segment(maxi(base + k, 0))
			if seg == null:
				continue
			var z := float(base + k) * seg_len
			if seg.city and ls_z.size() < 24:
				if fposmod(z, lamp_every) < seg_len * 3.0:
					var zl := z - fposmod(z, lamp_every) + seg_len * 0.5
					var edge := seg.lanes * lw * 0.5
					_add(zl, edge - 0.6, 9.0, 0.55 * lights, 0)
					_add(zl + lamp_every * 0.5, -edge + 0.6, 9.0, 0.55 * lights, 0)
			if (seg.fuel_zone & TrackSegment.FUEL_CANOPY) != 0 and k % 6 == 0 and ls_z.size() < 24:
				_add(z, seg.lanes * lw * 0.5 + seg.fuel_lane * lw + 0.5, 11.0, 0.8 * lights, 0)
			if seg.cover != "" and k % 4 == 0 and ls_z.size() < 24:
				_add(z, 0.0, 16.0, 0.7 * lights, 0)

	## Extra light at road position (z, x) – RoadRenderer._light (player's cone, cones of the traffic ahead, pools of
	## static lamps).
	func light(z: float, x: float) -> float:
		var l := 0.0
		var d := z - hl_z
		if d > -2.0 and d < hl_range:
			var along := smoothstep(-2.0, 5.0, d) * (1.0 - smoothstep(hl_range * 0.3, hl_range, d))
			var wd := 0.9 + maxf(d, 0.0) * 0.13
			var q := (x - hl_x) / wd
			l += hl_i * along / (1.0 + q * q * q * q)
		for i in ls_z.size():
			var dz := z - ls_z[i]
			if ls_kind[i] == 1:
				if dz > -1.0 and dz < ls_r[i]:
					var along2 := smoothstep(-1.0, 3.0, dz) * (1.0 - smoothstep(ls_r[i] * 0.3, ls_r[i], dz))
					var wd2 := 0.9 + maxf(dz, 0.0) * 0.18
					var q2 := (x - ls_x[i]) / wd2
					l += ls_i[i] * along2 / (1.0 + q2 * q2 * q2 * q2)
			else:
				var rr := ls_r[i]
				if absf(dz) < rr:
					var dx := x - ls_x[i]
					var e := 1.0 - (dz * dz + dx * dx) / (rr * rr)
					if e > 0.0:
						l += ls_i[i] * e * e
		return l

	## Light at a car whose rear is at road position (z, x), dz m ahead of the camera (0 beyond the headlight reach,
	## as in RoadRenderer._draw_item).
	func light_at(z: float, x: float, dz: float) -> float:
		return light(z, x) if lit and dz < hl_range + 40.0 else 0.0

	## RoadRenderer._modulate(k, light, alpha, reflect) for an item in the row of road position z (the segment of
	## its rear; tunnel = that segment is inside a tunnel): ambient + light, then Arcade's fog tint of the row.
	func modulate(z: float, tunnel: bool, light_v: float, alpha: float, reflect: float = REFLECT) -> Color:
		var amb := amb_tun if tunnel else amb_out
		var c := Color(minf(1.5, amb.r + light_v * reflect), minf(1.5, amb.g + light_v * reflect * 0.95),
			minf(1.5, amb.b + light_v * reflect * 0.85))
		var dz_row := floorf(z / seg_len) * seg_len - cam_z
		var f: float
		if tunnel:
			f = pow(clampf((dz_row - 12.0) / t_fog, 0.0, 1.0), 0.8)
		else:
			f = clampf((dz_row - fog_start) / fog_span, 0.0, 1.0)
		var fog := (fog_tun if tunnel else fog_out) * 1.25
		c = c.lerp(fog, f * 0.7)
		c.a = alpha
		return c

	## Arcade's player sprite is brighter than the scene (RoadRenderer._draw_player).
	static func player_modulate(m: Color) -> Color:
		return Color(minf(1.3, m.r * 1.15 + 0.08), minf(1.3, m.g * 1.15 + 0.08), minf(1.3, m.b * 1.15 + 0.1), m.a)


## Strength of a light layer over the body (Arcade draws it with light_alpha x level over the body drawn with alpha;
## the stand-in fades by dither, so the layer gets the ratio): level x light_alpha / alpha, at most 1.
static func layer_strength(level: float, alpha: float, light_alpha: float) -> float:
	if level <= 0.05:
		return 0.0
	return clampf(level * light_alpha / maxf(alpha, 0.001), 0.0, 1.0)


# --- nodes: sprite sheets ----------------------------------------------------------------------------------------

## Mesh of a sprite instance: 4 columns x 2 rows (UV.x = column 0..3, UV.y = 0 top / 1 bottom), three quads – the
## shader places the columns (flat quad or the fold).
static func sprite_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var nrm := PackedVector3Array()
	for c in 4:
		for r in 2:
			v.append(Vector3(float(c), -float(r), 0.0))
			uv.append(Vector2(float(c), float(r)))
			col.append(Color.WHITE)
			nrm.append(Vector3.BACK)
	var idx := PackedInt32Array()
	for c in 3:
		var a := c * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


static var _soft: Dictionary = {}      ## base shader instance id -> its CE_SOFT variant


## The second pass of vehicle_sprite.gdshader: the same source compiled with CE_SOFT (blends the soft parts the
## opaque pass leaves out). One per base shader.
static func soft_shader(base: Shader) -> Shader:
	if base == null:
		return null
	var key := base.get_instance_id()
	var sh: Shader = _soft.get(key)
	if sh == null:
		sh = Shader.new()
		sh.code = base.code.replace("shader_type spatial;", "shader_type spatial;\n#define CE_SOFT")
		_soft[key] = sh
	return sh


## Material of a sheet (kind 0: sprite cells, kind 1: box faces): the opaque pass (alpha scissor, writes depth) with
## the soft pass as its next_pass, both with the sheet's fixed uniforms.
static func sheet_material(shader: Shader, info: Dictionary, tex: Texture2D) -> ShaderMaterial:
	var mat := _material(shader, info, tex)
	var soft := soft_shader(shader)
	if soft != null:
		mat.next_pass = _material(soft, info, tex)
	return mat


static func _material(shader: Shader, info: Dictionary, tex: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter(&"sheet", tex)
	var ts := tex.get_size() if tex != null else Vector2.ONE
	mat.set_shader_parameter(&"tex_px", ts)
	if str(info.get("kind", "")) == KIND_BOX:
		mat.set_shader_parameter(&"kind", 1)
		return mat
	mat.set_shader_parameter(&"kind", 0)
	mat.set_shader_parameter(&"cell_px", info["cell"])
	mat.set_shader_parameter(&"grid", int(info["grid"]))
	mat.set_shader_parameter(&"n_angles", int(info["n"]))
	var rows: Dictionary = info["rows"]
	mat.set_shader_parameter(&"rows", Vector4(float(rows.get("base", 0)), float(rows.get("tail", -1)), float(rows.get("brake", -1)),
		float(rows.get("beacon_a", -1))))
	mat.set_shader_parameter(&"row_beacon_b", float(rows.get("beacon_b", -1)))
	mat.set_shader_parameter(&"size_m", info["size_m"])
	mat.set_shader_parameter(&"anchor", info["anchor"])
	mat.set_shader_parameter(&"persp", bool(info["persp"]))
	mat.set_shader_parameter(&"elev", float(info["elev"]))
	var obj: Vector3 = info["obj"]
	mat.set_shader_parameter(&"car_wl", Vector2(obj.x, obj.y))
	var y := PackedFloat32Array()
	y.resize(MAX_YAWS)
	var yl: PackedFloat32Array = info["yaws"]
	for i in mini(yl.size(), MAX_YAWS):
		y[i] = yl[i]
	mat.set_shader_parameter(&"yaws", y)
	return mat


## All cars of one sprite sheet in one MultiMesh (the opaque pass and the soft pass: two draw calls), the hidden box
## casters of its cars in a second MultiMesh (shadow pass only). The instances go straight into the buffer in the
## order the cars come (the opaque pass writes depth, so only soft parts of two cars of the same sheet could
## overlap out of order – the bodies never do).
class SheetBatch:
	var set_id := ""
	var info: Dictionary = {}
	var mat: ShaderMaterial
	var mm: MultiMesh
	var node: MultiMeshInstance3D
	var caster_mm: MultiMesh
	var caster_node: MultiMeshInstance3D
	var n := 0
	var cn := 0
	var last_n := 0
	var last_cn := 0
	var out := PackedFloat32Array()
	var cbuf := PackedFloat32Array()
	var casting := false

	func _init(p_set: String, p_info: Dictionary, material: ShaderMaterial, parent: Node3D, caster_mesh: Mesh, caster_mat: Material) -> void:
		set_id = p_set
		info = p_info
		mat = material
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = VehicleStandIn.sprite_mesh()
		node = MultiMeshInstance3D.new()
		node.name = "standin_" + p_set.replace("/", "_")
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3(-6000.0, -2000.0, -6000.0), Vector3(12000.0, 4000.0, 12000.0))
		node.visible = false
		parent.add_child(node)
		if caster_mesh != null:
			caster_mm = MultiMesh.new()
			caster_mm.transform_format = MultiMesh.TRANSFORM_3D
			caster_mm.mesh = caster_mesh
			caster_node = MultiMeshInstance3D.new()
			caster_node.name = "standin_caster_" + p_set.replace("/", "_")
			caster_node.multimesh = caster_mm
			caster_node.material_override = caster_mat
			caster_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			caster_node.custom_aabb = node.custom_aabb
			caster_node.visible = false
			parent.add_child(caster_node)

	func begin() -> void:
		n = 0
		cn = 0

	## One car: t = its frame at the anchor (origin-relative world), col = modulate (a = fade), cu = custom data.
	## with_basis false: only the anchor is written – an upright picture parallel to the screen needs no more (the
	## shader reads the basis only for a folded cell).
	func add(t: Transform3D, col: Color, cu: Vector4, with_basis: bool = true) -> void:
		var o := n * FLOATS
		if out.size() < o + FLOATS:
			out.resize(maxi(o + FLOATS, maxi(8 * FLOATS, out.size() * 2)))
		if with_basis:
			var b := t.basis
			out[o] = b.x.x
			out[o + 1] = b.y.x
			out[o + 2] = b.z.x
			out[o + 4] = b.x.y
			out[o + 5] = b.y.y
			out[o + 6] = b.z.y
			out[o + 8] = b.x.z
			out[o + 9] = b.y.z
			out[o + 10] = b.z.z
		elif out[o + 5] == 0.0:
			out[o] = 1.0          # a slot never written: identity, so the instance is never degenerate
			out[o + 5] = 1.0
			out[o + 10] = 1.0
		out[o + 3] = t.origin.x
		out[o + 7] = t.origin.y
		out[o + 11] = t.origin.z
		out[o + 12] = col.r
		out[o + 13] = col.g
		out[o + 14] = col.b
		out[o + 15] = col.a
		out[o + 16] = cu.x
		out[o + 17] = cu.y
		out[o + 18] = cu.z
		out[o + 19] = cu.w
		n += 1

	## The hidden box caster of a car (its pose, scaled to the caster mesh's unit size when that is a unit box).
	func add_caster(t: Transform3D) -> void:
		if caster_mm == null:
			return
		var need := (cn + 1) * CASTER_FLOATS
		if cbuf.size() < need:
			cbuf.resize(maxi(need, maxi(8 * CASTER_FLOATS, cbuf.size() * 2)))
		VehicleStandIn.put_transform(cbuf, cn * CASTER_FLOATS, t)
		cn += 1

	## Hands the instances of this frame to the MultiMesh (a sheet without cars in this and the last frame costs
	## nothing).
	func commit() -> void:
		if n == 0 and last_n == 0 and cn == 0 and last_cn == 0:
			return
		if mm.instance_count < n:
			mm.instance_count = maxi(n, maxi(8, mm.instance_count * 2))
		var size := mm.instance_count * FLOATS
		if out.size() != size:
			out.resize(size)
		if n > 0:
			mm.buffer = out
		if n != last_n:
			mm.visible_instance_count = n
			node.visible = n > 0
			last_n = n
		if caster_mm != null and (cn > 0 or last_cn > 0):
			if caster_mm.instance_count < cn:
				caster_mm.instance_count = maxi(cn, maxi(8, caster_mm.instance_count * 2))
				cbuf.resize(caster_mm.instance_count * CASTER_FLOATS)
			if cbuf.size() != caster_mm.instance_count * CASTER_FLOATS:
				cbuf.resize(caster_mm.instance_count * CASTER_FLOATS)
			if cn > 0:
				caster_mm.buffer = cbuf
			if cn != last_cn:
				caster_mm.visible_instance_count = cn
				caster_node.visible = cn > 0 and casting
				last_cn = cn

	func free_nodes() -> void:
		if is_instance_valid(node):
			node.queue_free()
		if is_instance_valid(caster_node):
			caster_node.queue_free()


static func put_transform(buf: PackedFloat32Array, o: int, t: Transform3D) -> void:
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


## A unit box (-0.5 .. 0.5 in x and z, 0 .. 1 in y) for hidden casters scaled per instance.
static func unit_box() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lo := Vector3(-0.5, 0.0, -0.5)
	var hi := Vector3(0.5, 1.0, 0.5)
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	var faces := [[4, 5, 6, 7], [1, 0, 3, 2], [5, 1, 2, 6], [0, 4, 7, 3], [7, 6, 2, 3], [0, 1, 5, 4]]
	for f: Array in faces:
		var a: Vector3 = c[f[0]]
		var b: Vector3 = c[f[1]]
		var d: Vector3 = c[f[2]]
		var e: Vector3 = c[f[3]]
		st.set_normal((b - a).cross(d - a).normalized())
		for p: Vector3 in [a, d, b, a, e, d]:
			st.add_vertex(p)
	return st.commit()


# --- nodes: box sets ---------------------------------------------------------------------------------------------

## The units of a box set, front first: [{"name", "parts": [part index], "pivot": Vector3 (model space)}]. One part:
## one rigid unit. More parts (tractor and trailer): the front part leads and turns about a pivot
## LEAD_PIVOT_BEHIND_KINGPIN_M behind the kingpin of the part behind it; every following part couples at its own
## kingpin (KINGPIN_BEHIND_FRONT_M behind its front, KINGPIN_HEIGHT_M high). Model space: -Z = front (box z + = front).
static func box_units(parts: Array) -> Array:
	var order := []
	for i in parts.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return float((parts[a] as Dictionary)["z1"]) > float((parts[b] as Dictionary)["z1"]))
	var units: Array = []
	if order.size() < 2:
		units.append({"name": "body", "parts": order, "pivot": Vector3.ZERO})
		return units
	for k in order.size():
		var p: Dictionary = parts[order[k]]
		var nm := str(p.get("name", "part%d" % k))
		if k == 0:
			var nxt: Dictionary = parts[order[1]]
			var kz := float(nxt["z1"]) - KINGPIN_BEHIND_FRONT_M - LEAD_PIVOT_BEHIND_KINGPIN_M
			units.append({"name": nm, "parts": [order[k]], "pivot": Vector3(0.0, 0.0, -kz)})
		else:
			var kz2 := float(p["z1"]) - KINGPIN_BEHIND_FRONT_M
			units.append({"name": nm, "parts": [order[k]], "pivot": Vector3(0.0, KINGPIN_HEIGHT_M, -kz2)})
	return units


## Mesh of one part of a box set in model space (-Z = front, +X = right, +Y = up; origin = vehicle centre on the
## ground): the faces of Arcade's BoxVehicle with their pictures (rear, left, right, top), the front with the rear
## picture (seen from ahead), lamp pictures of the face as UV2 (tail) and CUSTOM0.xy (brake); x < 0 = none.
static func box_part_mesh(part: Dictionary, part_index: int, lights: Dictionary, tex_size: Vector2) -> ArrayMesh:
	var faces: Dictionary = part.get("faces", {})
	var x0 := float(part["x0"])
	var x1 := float(part["x1"])
	var y0 := float(part["y0"])
	var y1 := float(part["y1"])
	var zr := -float(part["z0"])      # rear end (model +Z)
	var zf := -float(part["z1"])      # front end (model -Z)
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var idx := PackedInt32Array()
	var inv := Vector2(1.0 / maxf(tex_size.x, 1.0), 1.0 / maxf(tex_size.y, 1.0))
	# [face picture, corners (top-left, top-right, bottom-right, bottom-left as seen from outside), normal, mirror]
	var spec := [
		["rear", [Vector3(x0, y1, zr), Vector3(x1, y1, zr), Vector3(x1, y0, zr), Vector3(x0, y0, zr)], Vector3.BACK],
		["left", [Vector3(x0, y1, zf), Vector3(x0, y1, zr), Vector3(x0, y0, zr), Vector3(x0, y0, zf)], Vector3.LEFT],
		["right", [Vector3(x1, y1, zr), Vector3(x1, y1, zf), Vector3(x1, y0, zf), Vector3(x1, y0, zr)], Vector3.RIGHT],
		["top", [Vector3(x0, y1, zf), Vector3(x1, y1, zf), Vector3(x1, y1, zr), Vector3(x0, y1, zr)], Vector3.UP],
		["front", [Vector3(x1, y1, zf), Vector3(x0, y1, zf), Vector3(x0, y0, zf), Vector3(x1, y0, zf)], Vector3.FORWARD],
	]
	for sp: Array in spec:
		var face := str(sp[0])
		var pic := "rear" if face == "front" else face
		if not faces.has(pic):
			continue
		var rect: Rect2 = (faces[pic] as Rect2).grow(-0.5)
		var tail := _overlay_rect(lights, "tail", part_index, pic)
		var brake := _overlay_rect(lights, "brake", part_index, pic) if face != "front" else Rect2()
		if face == "front":
			tail = Rect2()
		var corners: Array = sp[1]
		var base := v.size()
		var fuv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in 4:
			v.append(corners[i])
			nrm.append(sp[2])
			var f: Vector2 = fuv[i]
			uv.append((rect.position + rect.size * f) * inv)
			uv2.append((tail.grow(-0.5).position + tail.grow(-0.5).size * f) * inv if tail.size.x > 0.0 else Vector2(-1.0, -1.0))
			var b := (brake.grow(-0.5).position + brake.grow(-0.5).size * f) * inv if brake.size.x > 0.0 else Vector2(-1.0, -1.0)
			c0.append_array([b.x, b.y, 0.0, 0.0])
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	if v.is_empty():
		return mesh
	var fmt := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
	return mesh


## Picture of a lamp layer (tail / brake) on a face of a part (SpriteDB.box_lights); Rect2() = none.
static func _overlay_rect(lights: Dictionary, layer: String, part_index: int, face: String) -> Rect2:
	for l: Variant in lights.get(layer, []):
		var d: Dictionary = l
		if int(d.get("part", -1)) == part_index and str(d.get("face", "")) == face:
			return d["rect"]
	return Rect2()


## Node of a box set's stand-in: root (meta set, model_id "", lod KIND_BOX, wheels [], lights = flare anchors of the
## painted box (ModelFactory.box_lights), groups when articulated, box true) / one Node3D per unit at its pivot /
## the part meshes (material = the sheet's box material) and one hidden box caster per unit ("shadow", shadows
## only). The unit nodes are posed by the vehicle layer like the groups of a model.
static func build_box_node(set_id: String, info: Dictionary, mat: ShaderMaterial, tex_size: Vector2, caster_mat: Material) -> Node3D:
	var parts: Array = info.get("parts", [])
	if parts.is_empty():
		return null
	var obj: Vector3 = info["obj"]
	var lights: Dictionary = info.get("lights", {})
	var root := Node3D.new()
	root.name = set_id.replace("/", "_") + "_standin"
	var units := box_units(parts)
	var groups: Array = []
	var articulated := units.size() > 1
	for u: Dictionary in units:
		var parent: Node3D = root
		var pivot: Vector3 = u["pivot"]
		if articulated:
			var gn := Node3D.new()
			gn.name = str(u["name"])
			gn.position = pivot
			root.add_child(gn)
			parent = gn
			groups.append({"name": gn.name, "pivot": pivot, "path": NodePath(gn.name)})
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for pi: int in u["parts"]:
			var p: Dictionary = parts[pi]
			var mi := MeshInstance3D.new()
			mi.name = "part_" + str(p.get("name", pi))
			mi.mesh = box_part_mesh(p, pi, lights, tex_size)
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = -pivot if articulated else Vector3.ZERO
			parent.add_child(mi)
			lo = Vector3(minf(lo.x, float(p["x0"])), minf(lo.y, float(p["y0"])), minf(lo.z, -float(p["z1"])))
			hi = Vector3(maxf(hi.x, float(p["x1"])), maxf(hi.y, float(p["y1"])), maxf(hi.z, -float(p["z0"])))
		var cast := MeshInstance3D.new()
		cast.name = "shadow"
		cast.mesh = unit_box()
		cast.material_override = caster_mat
		cast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var size := hi - lo
		var centre := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
		cast.transform = Transform3D(Basis.from_scale(Vector3(size.x, maxf(size.y, 0.1), size.z)), centre - (pivot if articulated else Vector3.ZERO))
		cast.visible = false
		parent.add_child(cast)
	var police := set_id.begins_with("police/")
	root.set_meta("set", set_id)
	root.set_meta("model_id", "")
	root.set_meta("lod", KIND_BOX)
	root.set_meta("wheels", [] as Array[NodePath])
	root.set_meta("lights", ModelFactory.box_lights({"width_m": obj.x, "length_m": obj.y, "height_m": obj.z}, "heavy" if obj.y > 7.0 else "car", police))
	root.set_meta("box", true)
	root.set_meta("standin", true)
	if articulated:
		root.set_meta("groups", groups)
	return root
