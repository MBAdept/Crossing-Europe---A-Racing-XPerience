W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"


def sub(path, old, new, c=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    assert t.count(old) == c, (path, old[:70], t.count(old))
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)


V = "scripts/race3d/vehicle_pose3d.gd"
sub(V, """## the rear (22:00, 60 m: sports car 150 red pixels against Arcade's 95, sedan at 20 m 654 against 539). The extra brake
## gain fades with the palette's lights to this share of itself (night: 1 + 1.2 × share). The beacon keeps its gain at
## night: with it the model's blue reaches only about half of Arcade's at 60 m (FIX-M2: 103 against 184 blue pixels) and
## check_vehicle_lights "blaulicht" needs it.
const MODEL_BRAKE_NIGHT_SHARE := 0.35""", """## the rear (22:00, 60 m: sports car 150 red pixels against Arcade's 95, sedan at 20 m 654 against 539). The extra brake
## gain fades with the palette's lights to a share of itself that depends on the distance of the car: near
## (MODEL_BRAKE_NIGHT_NEAR at 22 m and closer) the model's lamps need more glow to reach Arcade's light layer, far
## (MODEL_BRAKE_NIGHT_FAR from 60 m) the full gain made the halo larger than Arcade's. Measured at 22:00 (vehicle probe,
## red pixels): one share for all distances gave either sports car 60 m +22 % and sedan 20 m −32 % (0.35) or −1 % and
## −46 % (0.15). The beacon keeps its gain at night: with it the model's blue reaches only about half of Arcade's at
## 60 m (FIX-M2: 103 against 184 blue pixels) and check_vehicle_lights "blaulicht" needs it.
const MODEL_BRAKE_NIGHT_NEAR := 0.6
const MODEL_BRAKE_NIGHT_FAR := 0.15
const MODEL_BRAKE_NEAR_M := 22.0
const MODEL_BRAKE_FAR_M := 60.0""")
sub(V, """## flare point's role, a = lamp_a (its y is the brake level), lights = the palette's lights (0 by day, 1 at night: the
## brake gain fades to MODEL_BRAKE_NIGHT_SHARE of itself).
static func model_glow_gain(role: String, a: Vector4, lights: float = 0.0) -> float:
	match role:
		"rear", "brake":
			var extra := (MODEL_BRAKE_GAIN - 1.0) * lerpf(1.0, MODEL_BRAKE_NIGHT_SHARE, clampf(lights, 0.0, 1.0))
			return 1.0 + extra * clampf(a.y, 0.0, 1.0)""", """## flare point's role, a = lamp_a (its y is the brake level), lights = the palette's lights (0 by day, 1 at night: the
## brake gain fades to its night share), dist_m = the car's distance from the camera (the night share, see above).
static func model_glow_gain(role: String, a: Vector4, lights: float = 0.0, dist_m: float = 0.0) -> float:
	match role:
		"rear", "brake":
			return 1.0 + (MODEL_BRAKE_GAIN - 1.0) * lerpf(1.0, brake_night_share(dist_m), clampf(lights, 0.0, 1.0)) \\
				* clampf(a.y, 0.0, 1.0)""")
sub(V, """## Flare points of a model from its lights[]""", """## Share of the extra brake gain that stays at night for a car dist_m from the camera (MODEL_BRAKE_NIGHT_NEAR …
## MODEL_BRAKE_NIGHT_FAR).
static func brake_night_share(dist_m: float) -> float:
	return lerpf(MODEL_BRAKE_NIGHT_NEAR, MODEL_BRAKE_NIGHT_FAR, smoothstep(MODEL_BRAKE_NEAR_M, MODEL_BRAKE_FAR_M, dist_m))


## Flare points of a model from its lights[]""")
VL = "scripts/race3d/layers/vehicles.gd"
sub(VL, """			s *= VehiclePose3D.model_glow_gain(role, la, lights)   # FIX-M2: a model has no light layer of a sprite""",
    """			s *= VehiclePose3D.model_glow_gain(role, la, lights, car.pose.origin.distance_to(_cam_tr.origin))   # FIX-M2/RINT-M2""")
T = "tests/unit/race3d/test_vehicles.gd"
sub(T, """	var g_night := VehiclePose3D.model_glow_gain("rear", braking, 1.0)
	assert_near(g_night, 1.0 + (VehiclePose3D.MODEL_BRAKE_GAIN - 1.0) * VehiclePose3D.MODEL_BRAKE_NIGHT_SHARE, 1.0e-6, "Bremse nachts")
	assert_true(g_night > 1.0 and g_night < VehiclePose3D.MODEL_BRAKE_GAIN, "nachts zwischen Arcade und Tag (%.2f)" % g_night)
	assert_true(VehiclePose3D.model_glow_gain("rear", braking, 0.5) < VehiclePose3D.model_glow_gain("rear", braking, 0.0)
		and VehiclePose3D.model_glow_gain("rear", braking, 0.5) > g_night, "stetig mit den Lichtern")""", """	var g_night := VehiclePose3D.model_glow_gain("rear", braking, 1.0, 100.0)
	assert_near(g_night, 1.0 + (VehiclePose3D.MODEL_BRAKE_GAIN - 1.0) * VehiclePose3D.MODEL_BRAKE_NIGHT_FAR, 1.0e-6, "Bremse nachts, fern")
	var g_near := VehiclePose3D.model_glow_gain("rear", braking, 1.0, 10.0)
	assert_near(g_near, 1.0 + (VehiclePose3D.MODEL_BRAKE_GAIN - 1.0) * VehiclePose3D.MODEL_BRAKE_NIGHT_NEAR, 1.0e-6, "Bremse nachts, nah")
	assert_true(g_night > 1.0 and g_near > g_night and g_near < VehiclePose3D.MODEL_BRAKE_GAIN, "nachts zwischen Arcade und Tag, nah mehr als fern (%.2f / %.2f)" % [g_near, g_night])
	assert_near(VehiclePose3D.model_glow_gain("rear", braking, 0.0, 100.0), VehiclePose3D.MODEL_BRAKE_GAIN, 1.0e-6, "bei Tag der volle Zuschlag in jeder Entfernung")
	assert_true(VehiclePose3D.model_glow_gain("rear", braking, 0.5, 60.0) < VehiclePose3D.model_glow_gain("rear", braking, 0.0, 60.0)
		and VehiclePose3D.model_glow_gain("rear", braking, 0.5, 60.0) > VehiclePose3D.model_glow_gain("rear", braking, 1.0, 60.0), "stetig mit den Lichtern")""")
sub(T, """		* VehiclePose3D.model_glow_gain("rear", braking, 1.0)""", """		* VehiclePose3D.model_glow_gain("rear", braking, 1.0, 20.0)""")
print("ok")
