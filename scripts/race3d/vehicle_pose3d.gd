class_name VehiclePose3D
extends RefCounted
## Pure maths of the vehicle and flare layers of the mode "Modern" (contract §6 R3, D14 F5 / F6) – no nodes, no
## autoloads, unit tested (tests/unit/race3d/test_vehicles.gd, test_fade_law.gd):
##  * the fade law of Arcade (RoadRenderer._item_alpha) by path distance, open road and tunnel (F5),
##  * the pose of a vehicle from two points of the road (rear and front of its collision box): yaw AND pitch
##    follow the road; its own heading (lane change) and, for the player car, the terms of Arcade's player sprite
##    that are not projection (steering, understeer) and the body roll,
##  * the level of detail by path distance (with a little hysteresis),
##  * the lamp levels of the view flags (instance uniforms lamp_a / lamp_b of vpbr.gdshader),
##  * the glow sizes and strengths of Arcade's lamp glows (F6: RoadRenderer.INDICATOR_MIN_PX, INDICATOR_MIN_GLOW_PX).
## Conventions: world = Godot (+X right, +Y up, a vehicle looks along its local -Z, contract §4.5.1); yaw + = the
## nose turns to the right; roll in degrees with Arcade's sign (+ = clockwise as seen from behind: the roof moves
## to the right). Owner: R3. Docs: docs/renderer-modern.md §10.

## Arcade's fade near the camera inside a tunnel (RoadRenderer._item_alpha: dz - 12 m).
const TUNNEL_FADE_FROM_M := 12.0
## LOD hysteresis: a vehicle changes its level only this far (fraction of the limit) beyond it.
const LOD_HYSTERESIS := 0.05
## Lamp roles of the manifest (lights[].role) that make a flare.
const FLARE_ROLES: Array[String] = ["tail", "brake", "ind_l", "ind_r", "beacon_a", "beacon_b", "head", "marker"]
## A tail and a brake anchor closer than this are one rear lamp (one glow, as in Arcade).
const REAR_MERGE_M := 0.25
## Kinds of a flare (custom data .w of the flare MultiMesh, flare.gdshader).
const KIND_GLOW := 0.0               ## plain glow
const KIND_INDICATOR := 1.0          ## glow + lamp core of Arcade's minimum size (INDICATOR_MIN_PX)
## Arcade's indicator (RoadRenderer.INDICATOR_PERIOD_S, INDICATOR_MIN_PX, INDICATOR_MIN_GLOW_PX – copied, not named:
## this file must compile in scripts started with -s, before the autoloads RoadRenderer depends on exist;
## tests/unit/race3d/test_vehicles.gd checks that the copies equal Arcade's values).
const INDICATOR_PERIOD_S := 0.72
const INDICATOR_MIN_PX := Vector2(2.4, 2.0)
const INDICATOR_MIN_GLOW_PX := 4.5
## Arcade's indicator lamp and glow (RoadRenderer._indicator, indicator_glow_px).
const INDICATOR_CORE_W := 0.2        ## core width (m at the vehicle's scale), at least INDICATOR_MIN_PX.x
const INDICATOR_CORE_H := 0.13       ## core height (m), at least INDICATOR_MIN_PX.y
const INDICATOR_GLOW_DAY := 0.55     ## glow radius (m): (0.55 + 0.35 * lights) * s
const INDICATOR_GLOW_NIGHT := 0.35
## Arcade's rear-light glow (RoadRenderer._draw_car): radius (0.32 + brake * 0.12 + lights * 0.18) * s, 2 .. 70 px;
## strength tail * lights * 0.9 + brake * (0.35 + 0.4 * lights).
const REAR_GLOW_R := 0.32
const REAR_GLOW_BRAKE_R := 0.12
const REAR_GLOW_NIGHT_R := 0.18
const REAR_GLOW_MIN_PX := 2.0
const GLOW_MAX_PX := 70.0


## Arcade's fade of an item at path distance dz (m from the camera along the road; RoadRenderer._item_alpha): on the
## open road 1 - t² with t from fog_start_frac * visibility (0) to the visibility (1); inside a tunnel (the item's
## segment) 1 - t^1.6 with t from 12 m to tunnel_fog_m (render.tunnel.darkness_m). The simulation's "seen" lies at
## 0.839 x visibility – the vehicles and signs of Modern fade with exactly this law (F5).
static func fade(dz: float, visibility_m: float, fog_start_frac: float, tunnel: bool, tunnel_fog_m: float) -> float:
	if tunnel:
		return 1.0 - pow(clampf((dz - TUNNEL_FADE_FROM_M) / tunnel_fog_m, 0.0, 1.0), 1.6)
	var fog_start := visibility_m * fog_start_frac
	return 1.0 - pow(clampf((dz - fog_start) / maxf(1.0, visibility_m - fog_start), 0.0, 1.0), 2.0)


## Alpha of the lights of a vehicle (RoadRenderer: at night they outlast the body in the fog).
static func light_alpha(alpha: float, lights: float) -> float:
	return alpha if lights < 0.3 else minf(1.0, alpha * 1.6)


## Rigid basis of a vehicle whose rear centre stands on `rear` and front centre on `front` (both on the road, the
## world positions of its collision box ends): -Z along the chord (yaw and pitch of the road), +Y perpendicular to
## it in the vertical plane, then turned by its own heading `yaw` (rad, + = right) and rolled by `roll_deg`
## (Arcade's sign).
static func chord_basis(rear: Vector3, front: Vector3, yaw: float = 0.0, roll_deg: float = 0.0) -> Basis:
	var f := front - rear
	if f.length_squared() < 1.0e-8:
		f = Vector3(0.0, 0.0, -1.0)
	f = f.normalized()
	var right := f.cross(Vector3.UP)
	if right.length_squared() < 1.0e-8:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(f)
	var b := Basis(right, up, -f)
	if yaw != 0.0:
		b = b * Basis(Vector3.UP, -yaw)
	if roll_deg != 0.0:
		b = b * Basis(Vector3.BACK, -deg_to_rad(roll_deg))
	return b


## Pose of a rigid vehicle: origin on the ground under the centre of its collision box (the midpoint of the chord),
## basis as chord_basis().
static func chord_pose(rear: Vector3, front: Vector3, yaw: float = 0.0, roll_deg: float = 0.0) -> Transform3D:
	return Transform3D(chord_basis(rear, front, yaw, roll_deg), (rear + front) * 0.5)


## Leading unit of an articulated vehicle (manifest "groups", e.g. the tractor): posed from the road point under its
## pivot (`gp`) to the vehicle's front (`fp`); origin = the pivot (gp + up x pivot.y). Its parts hang under it
## relative to the pivot (ModelFactory.build(…, articulated = true)).
static func lead_unit(gp: Vector3, fp: Vector3, pivot: Vector3, yaw: float = 0.0) -> Transform3D:
	var b := chord_basis(gp, fp, yaw)
	return Transform3D(b, gp + b.y * pivot.y)


## A following unit (e.g. the trailer): coupled at its pivot to the unit before it (`prev` = that unit's world
## transform, `prev_pivot` = its pivot in model space), its axis from the vehicle's rear ground point `rear` to the
## ground under the coupling.
static func follow_unit(prev: Transform3D, prev_pivot: Vector3, pivot: Vector3, rear: Vector3, yaw: float = 0.0) -> Transform3D:
	var coupling := prev * (pivot - prev_pivot)
	var ground := coupling - prev.basis.y * pivot.y
	return Transform3D(chord_basis(rear, ground, yaw), coupling)


## The four ground corners of a vehicle of width w and length l placed with `pose` (rear left, rear right, front
## right, front left) – the footprint the acceptance test compares with the collision box.
static func footprint(pose: Transform3D, w: float, l: float) -> PackedVector3Array:
	var hw := w * 0.5
	var hl := l * 0.5
	return PackedVector3Array([pose * Vector3(-hw, 0.0, hl), pose * Vector3(hw, 0.0, hl), pose * Vector3(hw, 0.0, -hl),
		pose * Vector3(-hw, 0.0, -hl)])


## Visible yaw of the player car relative to the road (rad): what Arcade's player sprite shows beyond the
## projection (VehiclePose.player_yaw_target without the curve look-ahead and the view angle – true 3D draws those
## by itself): steering (steer * steer_deg), lane change (own heading * lateral_gain) and understeer
## (understeer * understeer_deg, nose into the bend). k = Arcade's render.player_* values.
static func player_yaw(steer: float, lat_mps: float, speed_mps: float, understeer: float, curve: float, k: Dictionary) -> float:
	var yaw := deg_to_rad(float(k.get("steer_deg", 3.0))) * clampf(steer, -1.0, 1.0)
	yaw += VehiclePose.own_heading(lat_mps, speed_mps) * float(k.get("lateral_gain", 1.0))
	yaw += deg_to_rad(float(k.get("understeer_deg", 6.0))) * clampf(understeer, 0.0, 1.0) * signf(curve)
	var lim := deg_to_rad(float(k.get("max_deg", 20.0)))
	return clampf(yaw, -lim, lim)


## Lateral acceleration of the player car (m/s², + = towards the right) as Arcade computes it for the body roll:
## road curvature at the car plus the change of the steering lateral speed.
static func lateral_accel(speed_mps: float, curve: float, curve_r1: float, dlat_mps2: float) -> float:
	return clampf(speed_mps * speed_mps * curve / maxf(1.0, curve_r1), -12.0, 12.0) + clampf(dlat_mps2, -12.0, 12.0)


## Level of detail of a model at path distance dist_m: the first level whose limit is not exceeded – the first
## level's limit (max_dist_m of the manifest) scaled by lod0_k, every further one by lod1_k (the quality levels'
## vehicle_lod0_m / vehicle_lod1_m against the 40 m / 120 m the manifest is made for); levels with max_dist_m 0
## ("show") are never picked. Beyond the last mesh level: ModelDB.IMPOSTOR when the model has an impostor. With
## `current` (the level shown so far) a limit only counts LOD_HYSTERESIS beyond it, so a vehicle at a limit does
## not flicker between two levels.
static func lod_for(model: Dictionary, dist_m: float, lod0_k: float, lod1_k: float, current: String = "") -> String:
	var lv := lod_levels(model)
	var names: PackedStringArray = lv[0]
	if names.is_empty():
		return ""
	var i := lod_index(lv[1], dist_m, lod0_k, lod1_k, names.find(current))
	if i < 0:
		return ModelDB.IMPOSTOR if model.has("impostor") else names[names.size() - 1]
	return names[i]


## The levels a model is shown at by distance: [PackedStringArray names, PackedFloat32Array max_dist_m] (levels with
## max_dist_m 0 left out) – computed once per model, then lod_index() picks without allocating anything.
static func lod_levels(model: Dictionary) -> Array:
	var names := PackedStringArray()
	var limits := PackedFloat32Array()
	for l: Variant in model.get("lods", []):
		var d: Dictionary = l
		var mx := float(d.get("max_dist_m", 0.0))
		if mx <= 0.0:
			continue
		names.append(str(d.get("name", "")))
		limits.append(mx)
	return [names, limits]


## Index of the level for dist_m (see lod_for): -1 = beyond the last level. current = index shown so far (-1: none).
static func lod_index(limits: PackedFloat32Array, dist_m: float, lod0_k: float, lod1_k: float, current: int = -1) -> int:
	for j in limits.size():
		var lim := limits[j] * (lod0_k if j == 0 else lod1_k)
		if current >= 0:
			# hysteresis: the level shown keeps its range a little longer, a coarser one starts a little later
			lim *= (1.0 + LOD_HYSTERESIS) if j >= current else (1.0 - LOD_HYSTERESIS)
		if dist_m <= lim:
			return j
	return -1


## Lamp levels of a car of the view (instance uniforms of vpbr.gdshader): lamp_a = (tail, brake, indicator left,
## indicator right), lamp_b = (head, reverse, beacon A, beacon B). Tail and head lights burn with the lights of the
## palette (car.tail) and always inside a tunnel; an indicator burns in the first half of every
## RoadRenderer.INDICATOR_PERIOD_S after it was switched on (car.blink_t, as in Arcade).
static func lamp_a(car: Dictionary, in_tunnel: bool) -> Vector4:
	var tail := maxf(float(car.get("tail", 0.0)), 1.0 if in_tunnel else 0.0)
	var blink := int(car.get("blink", 0))
	var lit := blink != 0 and indicator_lit(float(car.get("blink_t", 0.0)))
	return Vector4(tail, clampf(float(car.get("brake", 0.0)), 0.0, 1.0), 1.0 if lit and blink < 0 else 0.0,
		1.0 if lit and blink > 0 else 0.0)


static func lamp_b(car: Dictionary, in_tunnel: bool) -> Vector4:
	var head := maxf(float(car.get("tail", 0.0)), 1.0 if in_tunnel else 0.0)
	var beacon := str(car.get("beacon", ""))
	return Vector4(head, 0.0, 1.0 if beacon == "a" else 0.0, 1.0 if beacon == "b" else 0.0)


## Strength (0..1, before the vehicle's fade) and radius law of the glow of a flare point (Arcade's glows):
## Vector4(strength, radius factor k (radius = k * px per m), smallest radius (px), kind). a / b = lamp_a / lamp_b,
## lights = palette lights (1 inside a tunnel). Roles of flare points (flare_points()): "rear" = a tail light that
## is also the brake light (Arcade draws one glow per rear lamp from both: tail at night, brake by day and night),
## "tail", "brake" (a lamp of its own, e.g. the third brake light), "ind_l", "ind_r", "beacon_a", "beacon_b",
## "head", "marker".
static func flare_params(role: String, a: Vector4, b: Vector4, lights: float) -> Vector4:
	match role:
		"rear":
			return Vector4(clampf(a.x * lights * 0.9 + a.y * (0.35 + 0.4 * lights), 0.0, 1.0),
				REAR_GLOW_R + a.y * REAR_GLOW_BRAKE_R + lights * REAR_GLOW_NIGHT_R, REAR_GLOW_MIN_PX, KIND_GLOW)
		"tail":
			return Vector4(clampf(a.x * lights * 0.9, 0.0, 1.0), REAR_GLOW_R + lights * REAR_GLOW_NIGHT_R, REAR_GLOW_MIN_PX,
				KIND_GLOW)
		"brake":
			return Vector4(clampf(a.y * (0.35 + 0.4 * lights), 0.0, 1.0),
				(REAR_GLOW_R + REAR_GLOW_BRAKE_R + lights * REAR_GLOW_NIGHT_R) * 0.7, REAR_GLOW_MIN_PX, KIND_GLOW)
		"ind_l", "ind_r":
			var on := a.z if role == "ind_l" else a.w
			return Vector4(on * (0.75 + 0.2 * lights), INDICATOR_GLOW_DAY + INDICATOR_GLOW_NIGHT * lights,
				INDICATOR_MIN_GLOW_PX + lights, KIND_INDICATOR)
		"beacon_a":
			return Vector4(b.z * 0.7, 1.2 + lights, 3.0, KIND_GLOW)
		"beacon_b":
			return Vector4(b.w * 0.45, 1.2 + lights, 3.0, KIND_GLOW)
		"head":
			return Vector4(b.x * lights * 0.8, 0.45 + 0.25 * lights, 2.0, KIND_GLOW)
		"marker":
			return Vector4(a.x * lights * 0.7, 0.22 + 0.12 * lights, 1.5, KIND_GLOW)
	return Vector4.ZERO


## Flare points of a model from its lights[] (manifest format: role, pos, dir, size, color): [{"role", "pos":
## Vector3, "dir": Vector3 (unit, model space), "size": float, "color": Color}]. A tail and a brake anchor closer than
## REAR_MERGE_M become ONE point "rear" (Arcade draws one glow per rear lamp from both lights); roles outside
## FLARE_ROLES are left out. Order: as in lights[] (the merged point at the place of its tail anchor).
static func flare_points(lights: Array) -> Array:
	var pts: Array = []
	for l: Variant in lights:
		if not (l is Dictionary):
			continue
		var d: Dictionary = l
		var role := str(d.get("role", ""))
		if not FLARE_ROLES.has(role):
			continue
		var p: Variant = d.get("pos", [])
		if not (p is Array) or (p as Array).size() < 3:
			continue
		var dv: Variant = d.get("dir", [])
		var dir := Vector3(0.0, 0.0, 1.0) if role in ["tail", "brake", "marker"] else Vector3(0.0, 0.0, -1.0)
		if role.begins_with("beacon"):
			dir = Vector3.UP
		if dv is Array and (dv as Array).size() >= 3:
			var v := Vector3(float(dv[0]), float(dv[1]), float(dv[2]))
			if v.length_squared() > 1.0e-6:
				dir = v.normalized()
		var col := Color(str(d.get("color", "#ffffff"))) if Color.html_is_valid(str(d.get("color", ""))) else Color.WHITE
		pts.append({"role": role, "pos": Vector3(float(p[0]), float(p[1]), float(p[2])), "dir": dir,
			"size": float(d.get("size", 0.2)), "color": col})
	# one glow per rear lamp: a tail anchor takes the brake anchor next to it
	var out: Array = []
	var used: Dictionary = {}
	for i in pts.size():
		if used.has(i):
			continue
		var a: Dictionary = pts[i]
		if str(a["role"]) == "tail" or str(a["role"]) == "brake":
			var other := "brake" if str(a["role"]) == "tail" else "tail"
			for j in range(i + 1, pts.size()):
				var b: Dictionary = pts[j]
				if not used.has(j) and str(b["role"]) == other and (b["pos"] as Vector3).distance_to(a["pos"]) <= REAR_MERGE_M:
					var t: Dictionary = a if str(a["role"]) == "tail" else b
					var m := t.duplicate()
					m["role"] = "rear"
					m["size"] = maxf(float(a["size"]), float(b["size"]))
					used[j] = true
					a = m
					break
		out.append(a)
	return out


## True while an indicator switched on blink_t seconds ago is lit: the first half of every INDICATOR_PERIOD_S
## (RoadRenderer.indicator_lit).
static func indicator_lit(blink_t: float) -> bool:
	return fposmod(maxf(blink_t, 0.0), INDICATOR_PERIOD_S) < INDICATOR_PERIOD_S * 0.5


## Radius (logical px) of a glow with radius factor k at s px per metre: k * s, at least min_px, at most 70 px
## (Arcade's clamp).
static func glow_px(k: float, s: float, min_px: float) -> float:
	return clampf(k * s, min_px, maxf(min_px, GLOW_MAX_PX))


## Size (logical px) of an indicator's lamp core at s px per metre (RoadRenderer._indicator: 0.2 s x 0.13 s,
## at least INDICATOR_MIN_PX).
static func indicator_core_px(s: float) -> Vector2:
	return Vector2(clampf(INDICATOR_CORE_W * s, INDICATOR_MIN_PX.x, 30.0),
		clampf(INDICATOR_CORE_H * s, INDICATOR_MIN_PX.y, 20.0))


## Rotation angle (rad) of a wheel about its local X after the vehicle has covered `distance_m` (rolling without
## slip): right wheels (yaw 0) turn by -distance / radius; a left wheel is the right wheel turned 180° about Y, so
## the same motion is the opposite angle about its own X (contract §4.6.2).
static func wheel_spin(distance_m: float, radius_m: float, left: bool) -> float:
	var a := fposmod(distance_m / maxf(radius_m, 0.05), TAU)
	return a if left else -a


## Steering angle of the front wheels (rad, + = right): the geometric angle of the road bend over the wheelbase
## plus a share of the player's steering input (steer -1..1, at most steer_deg).
static func steer_angle(wheelbase_m: float, curvature: float, steer: float, steer_deg: float) -> float:
	return atan(wheelbase_m * curvature) + deg_to_rad(steer_deg) * clampf(steer, -1.0, 1.0)
