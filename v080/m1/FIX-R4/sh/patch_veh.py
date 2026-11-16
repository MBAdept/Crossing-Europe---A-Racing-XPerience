import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, ("pattern", old[:70], s.count(old))
    s = s.replace(old, new)
rep("""var _wet := 0.0
var _cam_origin := Vector3.ZERO
""", """var _wet := 0.0
var _cam_origin := Vector3.ZERO
var _path: RoadPath3D                ## FIX-R4: the path of this frame (road profile of the streaks)
var _cam_z := 0.0
var _prof := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])   ## the road profile of the car whose flares are put
""")
rep("""	var cam_z := float(view.get("camera_z", 0.0))
	var vis := float(view.get("visibility_m", 900.0))
	var lights := float(pal.get("lights", 0.0))
	var time := float(view.get("time", 0.0))
	var sim_dt := 0.0 if _last_time < 0.0 else clampf(time - _last_time, 0.0, 0.1)""",
"""	var cam_z := float(view.get("camera_z", 0.0))
	_path = path
	_cam_z = cam_z
	var vis := float(view.get("visibility_m", 900.0))
	var lights := float(pal.get("lights", 0.0))
	var time := float(view.get("time", 0.0))
	var sim_dt := 0.0 if _last_time < 0.0 else clampf(time - _last_time, 0.0, 0.1)""")
rep("""## R4: the reflection of a rear lamp on the wet road (layer "flares", flare_streak): Arcade's streaky reflections of
## rear lights (RoadRenderer._wet_reflections, 0.22 × glow × wet) as a quad on the road from the ground under the lamp
## towards the camera. `h` = height of the lamp above the car's ground, `dist` = the car's distance from the camera.
func _put_streak(pos: Vector3, col: Color, s: float, lamp_r: float, h: float, dist: float) -> void:
	var a := s * _wet * STREAK_GAIN
	if a <= 0.004 or h <= 0.05:
		return
	var o := _streak_n * FLOATS_PER_FLARE
	if _streaks.size() < o + FLOATS_PER_FLARE:
		_streaks.resize(maxi(o + FLOATS_PER_FLARE, maxi(32 * FLOATS_PER_FLARE, _streaks.size() * 2)))
	_streaks[o] = 1.0
	_streaks[o + 1] = 0.0
	_streaks[o + 2] = 0.0
	_streaks[o + 3] = pos.x
	_streaks[o + 4] = 0.0
	_streaks[o + 5] = 1.0
	_streaks[o + 6] = 0.0
	_streaks[o + 7] = pos.y
	_streaks[o + 8] = 0.0
	_streaks[o + 9] = 0.0
	_streaks[o + 10] = 1.0
	_streaks[o + 11] = pos.z""",
"""## R4: the reflection of a rear lamp on the wet road (layer "flares", flare_streak): Arcade's streaky reflections of
## rear lights (RoadRenderer._wet_reflections, 0.22 × glow × wet) as a strip on the road from the ground under the lamp
## towards the camera. `h` = height of the lamp above the car's ground, `dist` = the car's distance from the camera,
## `prof` = the road's height profile from the car to the camera (road_profile(); FIX-R4: the strip follows the road –
## level at the height of the car, it hung in the air above a climbing road as a red column, QA-R4 B1).
func _put_streak(pos: Vector3, col: Color, s: float, lamp_r: float, h: float, dist: float, prof: PackedFloat32Array) -> void:
	var a := s * _wet * STREAK_GAIN
	if a <= 0.004 or h <= 0.05:
		return
	var o := _streak_n * FLOATS_PER_FLARE
	if _streaks.size() < o + FLOATS_PER_FLARE:
		_streaks.resize(maxi(o + FLOATS_PER_FLARE, maxi(32 * FLOATS_PER_FLARE, _streaks.size() * 2)))
	put_profile(_streaks, o, prof)
	_streaks[o + 3] = pos.x
	_streaks[o + 7] = pos.y
	_streaks[o + 11] = pos.z""")
rep("""## Length (m) of a lamp's reflection on the wet road for a lamp `dist` metres from the camera: longer far away, where
## the water film shows the grazing reflection over a long stretch (pure).
static func streak_length(dist: float) -> float:
	return clampf(dist * 0.3, STREAK_MIN_M, STREAK_MAX_M)
""", """## Length (m) of a lamp's reflection on the wet road for a lamp `dist` metres from the camera: longer far away, where
## the water film shows the grazing reflection over a long stretch (pure).
static func streak_length(dist: float) -> float:
	return clampf(dist * 0.3, STREAK_MIN_M, STREAK_MAX_M)


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
""")
rep("""	var pts: Array = info["points_rear"] if car.flare_ref > 0.0 else info["points"]
	for p: Dictionary in pts:""",
"""	var pts: Array = info["points_rear"] if car.flare_ref > 0.0 else info["points"]
	var prof_done := false
	for p: Dictionary in pts:""")
rep("""		if _wet > 0.0 and (role == "rear" or role == "tail" or role == "brake") and (p["pos"] as Vector3).y > 0.1:
			# the lamp's reflection on the wet road (its height above the car's ground: the model-space y)
			_put_streak(pos, col, s, lamp_r, (p["pos"] as Vector3).y, (pos - _cam_origin).length())""",
"""		if _wet > 0.0 and (role == "rear" or role == "tail" or role == "brake") and (p["pos"] as Vector3).y > 0.1:
			# the lamp's reflection on the wet road (its height above the car's ground: the model-space y), along the
			# road from the car's rear (car.z) to the camera – one profile for all lamps of the car
			if not prof_done and _path != null:
				road_profile(_path, car.z, _cam_z, _path.z_min(), float(_path.last()) * _path.seg_len, _prof)
				prof_done = true
			_put_streak(pos, col, s, lamp_r, (p["pos"] as Vector3).y, (pos - _cam_origin).length(), _prof)""")
open(p, "w", encoding="utf-8").write(s)
print("patched", p)
