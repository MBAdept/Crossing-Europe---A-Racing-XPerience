extends TestCase
## Fade law of the mode "Modern" (contract D14 F5, acceptance of R3): vehicles and signs fade by PATH distance with
## exactly the law of Arcade's RoadRenderer._item_alpha – on the open road and inside a tunnel – checked against the
## frozen Arcade code itself at 20 distances per case. The sign shader repeats the formula on the GPU
## (assets/shaders/modern/sign.gdshader); its source is checked to carry the same constants.

const SIGN_SHADER := "res://assets/shaders/modern/sign.gdshader"


## Arcade's own _item_alpha(k, dz) for one segment (tunnel or not) and a sight distance: a RoadRenderer that is
## never added to the tree, with the members _item_alpha reads set as its _prepare() would set them.
func _arcade_alpha(rr: RoadRenderer, tunnel: bool, vis: float, dz: float) -> float:
	var seg := TrackSegment.new()
	seg.tunnel = tunnel
	var segs: Array[TrackSegment] = [seg]
	rr.set("_segs", segs)
	rr.set("_vis", vis)
	rr.set("_fog_start", vis * float(rr.get("_fog_start_frac")))
	return float(rr.call("_item_alpha", 0, dz))


func test_fade_equals_arcade_item_alpha() -> void:
	var rr := RoadRenderer.new()
	var frac := float(rr.get("_fog_start_frac"))
	var tfog := float(rr.get("_t_fog_m"))
	var worst := 0.0
	var count := 0
	for vis: float in [900.0, 420.0, 150.0]:
		for i in 20:
			var dz := vis * 1.15 * float(i) / 19.0
			var a := _arcade_alpha(rr, false, vis, dz)
			var m := VehiclePose3D.fade(dz, vis, frac, false, tfog)
			worst = maxf(worst, absf(a - m))
			count += 1
	for i in 20:
		var dz := 330.0 * float(i) / 19.0
		var a := _arcade_alpha(rr, true, 900.0, dz)
		var m := VehiclePose3D.fade(dz, 900.0, frac, true, tfog)
		worst = maxf(worst, absf(a - m))
		count += 1
	rr.free()
	assert_eq(count, 80, "20 Entfernungen je Fall (drei Sichtweiten auf freier Strecke, Tunnel)")
	assert_true(worst < 1.0e-6, "Ausblendung = RoadRenderer._item_alpha (größte Abweichung %.9f)" % worst)


func test_fade_law_shape() -> void:
	# the simulation's "seen" lies at 0.839 x visibility: there the fade is half way (1 - ((0.839 - 0.45) / 0.55)²)
	var a := VehiclePose3D.fade(0.839 * 900.0, 900.0, 0.45, false, 260.0)
	assert_between(a, 0.49, 0.51, "bei 0,839 × Sichtweite halb ausgeblendet (%.3f)" % a)
	assert_eq(VehiclePose3D.fade(0.0, 900.0, 0.45, false, 260.0), 1.0, "nah: voll")
	assert_eq(VehiclePose3D.fade(900.0, 900.0, 0.45, false, 260.0), 0.0, "an der Sichtweite: weg")
	assert_eq(VehiclePose3D.fade(-5.0, 900.0, 0.45, false, 260.0), 1.0, "hinter der Kamera: voll")
	assert_eq(VehiclePose3D.fade(12.0, 900.0, 0.45, true, 260.0), 1.0, "Tunnel: bis 12 m voll")
	assert_eq(VehiclePose3D.fade(272.0, 900.0, 0.45, true, 260.0), 0.0, "Tunnel: 12 m + darkness_m weg")
	# lights outlast the body at night (RoadRenderer: light_alpha)
	assert_eq(VehiclePose3D.light_alpha(0.5, 0.0), 0.5, "Tag: Lichter wie der Wagen")
	assert_near(VehiclePose3D.light_alpha(0.5, 1.0), 0.8, 1.0e-6, "Nacht: Lichter 1,6 × (höchstens 1)")


func test_sign_shader_uses_the_same_law() -> void:
	var code := FileAccess.get_file_as_string(SIGN_SHADER)
	assert_true(code.contains("pow(clamp((dz - 12.0) / tunnel_fog_m, 0.0, 1.0), 1.6)"), "Schilder im Tunnel: Arcades Tunnelgesetz")
	assert_true(code.contains("pow(clamp((dz - fs) / max(1.0, visibility - fs), 0.0, 1.0), 2.0)"), "Schilder: 1 − t² ab fog_start")
	assert_true(code.contains("float fs = visibility * fog_frac;"), "fog_start = Sichtweite × render.fog_start_frac")
