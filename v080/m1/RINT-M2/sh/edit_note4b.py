W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:70], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)
F = "tests/race3d/render/check_vehicle_lights.gd"
sub(F, """##   sichtgrenze    F4/F5""", """##   bremsschein    RINT-M2 (A-20, NACH-M2 N-01): the extra glow of a MODEL's brake lights (VehiclePose3D.MODEL_BRAKE_GAIN)
##                  is there by day and fades at night: pixels the brake lifts by at least +0.03 red (brake on against
##                  off, same moment) around a braking sports car at 60 m – by day at least BRAKE_DAY_MIN_PX (Arcade's glow
##                  law alone, gain 1.0, stays below), at 22:00 at most BRAKE_NIGHT_MAX_PX (the full day gain at night
##                  goes above) – and a braking sedan at 20 m at 22:00 at most BRAKE_NIGHT20_MAX_PX
##   sichtgrenze    F4/F5""")
sub(F, """const CHECKS := ["blinker", "ruecklicht_n1", "bremslicht", "blaulicht", "abblendlicht", "sichtgrenze"]""",
"""const CHECKS := ["blinker", "ruecklicht_n1", "bremslicht", "blaulicht", "abblendlicht", "bremsschein", "sichtgrenze"]""")
sub(F, """## Kiel – Hamburg: start positions tried""", """## bremsschein (RINT-M2): limits of the pixels the brake lifts – set from the measurements in the comment of
## _check_bremsschein()
const BRAKE_DAY_MIN_PX := 0
const BRAKE_NIGHT_MAX_PX := 100000
const BRAKE_NIGHT20_MAX_PX := 100000
## Kiel – Hamburg: start positions tried""")
sub(F, """# --- sichtgrenze (FIX1) -------------------------------------------------------------------------------------------
""", """# --- bremsschein (RINT-M2) ------------------------------------------------------------------------------------------

## Pixels whose red the brake lifts by more than +0.03 (on against off) in the footprint of the car's rear, widened by
## the glow.
func _brake_lift(r: Node, set_id: String, z: float, x: float, lights: float) -> int:
	var size: Dictionary = ModelDB.object_size(set_id)
	var on := await _shot([_car(9901, set_id, z, x, {"tail": lights, "brake": 1.0})])
	var off := await _shot([_car(9901, set_id, z, x, {"tail": lights, "brake": 0.0})])
	_keep(on, "bremsschein_%s_%03d_%02d" % [set_id.get_file(), int(z - float((r.get("view") as Dictionary)["camera_z"])), int(lights * 10.0)])
	var rect := _footprint(r, z + 0.5, x, 1.0, float(size.get("width_m", 1.9)), float(size.get("height_m", 1.4)))
	var grow := maxi(10, int(rect.size.x * 0.6))
	rect = rect.grow(grow)
	var lifted := 0
	for py in range(maxi(rect.position.y, 0), mini(rect.end.y, on.get_height())):
		for px in range(maxi(rect.position.x, 0), mini(rect.end.x, on.get_width())):
			lifted += 1 if on.get_pixel(px, py).r - off.get_pixel(px, py).r > 0.03 else 0
	return lifted


func _check_bremsschein() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	for hour: float in [12.0, 22.0]:
		var sc: Node = await _launch_clear({"start_world_minutes": hour * 60.0}, CLEAR_KMS, [20.0, 60.0], 0.0)
		var r: Node = sc.get("renderer")
		var view: Dictionary = r.get("view")
		var cam_z := float(view["camera_z"])
		var x := float((view["player"] as Dictionary).get("x", 0.0))
		var lights := float((view["palette"] as Dictionary).get("lights", 0.0))
		var sports := await _brake_lift(r, "traffic/sports_yellow", cam_z + 60.0, x, lights)
		if hour < 18.0:
			_need(p, sports >= BRAKE_DAY_MIN_PX, "12 Uhr: Sportwagen bei 60 m hebt %d Pixel (mindestens %d)" % [sports, BRAKE_DAY_MIN_PX])
			msgs.append("12 Uhr Sportwagen 60 m %d Pixel" % sports)
		else:
			var sedan := await _brake_lift(r, "traffic/sedan_silver", cam_z + 20.0, x, lights)
			_need(p, lights > 0.9, "Nacht (Lichter der Palette %.2f)" % lights)
			_need(p, sports <= BRAKE_NIGHT_MAX_PX, "22 Uhr: Sportwagen bei 60 m hebt %d Pixel (höchstens %d)" % [sports, BRAKE_NIGHT_MAX_PX])
			_need(p, sedan <= BRAKE_NIGHT20_MAX_PX, "22 Uhr: Limousine bei 20 m hebt %d Pixel (höchstens %d)" % [sedan, BRAKE_NIGHT20_MAX_PX])
			msgs.append("22 Uhr Sportwagen 60 m %d, Limousine 20 m %d Pixel" % [sports, sedan])
		await _free(sc)
	_report("bremsschein", p, "Schein des Bremslichts der Modelle – " + "; ".join(msgs))


# --- sichtgrenze (FIX1) -------------------------------------------------------------------------------------------
""")
print("ok")
