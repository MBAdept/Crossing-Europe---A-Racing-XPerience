W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:70], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)

sub("scripts/race3d/vehicle_pose3d.gd",
"""const MODEL_BRAKE_GAIN := 2.2
const MODEL_BEACON_GAIN := 2.4
""",
"""const MODEL_BRAKE_GAIN := 2.2
const MODEL_BEACON_GAIN := 2.4
## RINT-M2 (A-20, NACH-M2 N-01): MODEL_BRAKE_GAIN is for daylight, where a red halo over grey or yellow paint barely reads
## as red. At night Arcade's glow law alone already draws a large red halo, and the full gain put three big red halos over
## the rear (22:00, 60 m: sports car 150 red pixels against Arcade's 95, sedan at 20 m 654 against 539). The extra brake
## gain fades with the palette's lights to this share of itself (night: 1 + 1.2 × share). The beacon keeps its gain at
## night: with it the model's blue reaches only about half of Arcade's at 60 m (FIX-M2: 103 against 184 blue pixels) and
## check_vehicle_lights "blaulicht" needs it.
const MODEL_BRAKE_NIGHT_SHARE := 0.5
""")
sub("scripts/race3d/vehicle_pose3d.gd",
"""## Factor on the flare strength of a lamp of a MODEL (not of a sprite stand-in) – see MODEL_BRAKE_GAIN. role = the
## flare point's role, a = lamp_a (its y is the brake level).
static func model_glow_gain(role: String, a: Vector4) -> float:
	match role:
		"rear", "brake":
			return 1.0 + (MODEL_BRAKE_GAIN - 1.0) * clampf(a.y, 0.0, 1.0)
""",
"""## Factor on the flare strength of a lamp of a MODEL (not of a sprite stand-in) – see MODEL_BRAKE_GAIN. role = the
## flare point's role, a = lamp_a (its y is the brake level), lights = the palette's lights (0 by day, 1 at night: the
## brake gain fades to MODEL_BRAKE_NIGHT_SHARE of itself).
static func model_glow_gain(role: String, a: Vector4, lights: float = 0.0) -> float:
	match role:
		"rear", "brake":
			var extra := (MODEL_BRAKE_GAIN - 1.0) * lerpf(1.0, MODEL_BRAKE_NIGHT_SHARE, clampf(lights, 0.0, 1.0))
			return 1.0 + extra * clampf(a.y, 0.0, 1.0)
""")
sub("scripts/race3d/layers/vehicles.gd",
"""			s *= VehiclePose3D.model_glow_gain(role, la)   # FIX-M2: a model has no light layer of a sprite""",
"""			s *= VehiclePose3D.model_glow_gain(role, la, lights)   # FIX-M2: a model has no light layer of a sprite""")
# unit test
sub("tests/unit/race3d/test_vehicles.gd",
"""	assert_true(VehiclePose3D.MODEL_BRAKE_GAIN > 1.0 and VehiclePose3D.MODEL_BEACON_GAIN > 1.0, "Zuschläge > 1")
""",
"""	assert_true(VehiclePose3D.MODEL_BRAKE_GAIN > 1.0 and VehiclePose3D.MODEL_BEACON_GAIN > 1.0, "Zuschläge > 1")
	# RINT-M2 (A-20): the brake gain is for daylight – at night it fades to MODEL_BRAKE_NIGHT_SHARE of the extra gain,
	# steadily with the palette's lights; the beacon keeps its gain
	var g_night := VehiclePose3D.model_glow_gain("rear", braking, 1.0)
	assert_near(g_night, 1.0 + (VehiclePose3D.MODEL_BRAKE_GAIN - 1.0) * VehiclePose3D.MODEL_BRAKE_NIGHT_SHARE, 1.0e-6, "Bremse nachts")
	assert_true(g_night > 1.0 and g_night < VehiclePose3D.MODEL_BRAKE_GAIN, "nachts zwischen Arcade und Tag (%.2f)" % g_night)
	assert_true(VehiclePose3D.model_glow_gain("rear", braking, 0.5) < VehiclePose3D.model_glow_gain("rear", braking, 0.0)
		and VehiclePose3D.model_glow_gain("rear", braking, 0.5) > g_night, "stetig mit den Lichtern")
	assert_near(VehiclePose3D.model_glow_gain("rear", tail, 1.0), 1.0, 1.0e-6, "nachts nur Rücklicht: Arcades Stärke")
	assert_near(VehiclePose3D.model_glow_gain("beacon_a", Vector4.ZERO, 1.0), VehiclePose3D.MODEL_BEACON_GAIN, 1.0e-6, "Blaulicht nachts")
""")
sub("tests/unit/race3d/test_vehicles.gd",
"""	var night := VehiclePose3D.flare_params("rear", Vector4(1.0, 1.0, 0.0, 0.0), Vector4.ZERO, 1.0).x \\
		* VehiclePose3D.model_glow_gain("rear", braking)""",
"""	var night := VehiclePose3D.flare_params("rear", Vector4(1.0, 1.0, 0.0, 0.0), Vector4.ZERO, 1.0).x \\
		* VehiclePose3D.model_glow_gain("rear", braking, 1.0)""")
print("ok")
