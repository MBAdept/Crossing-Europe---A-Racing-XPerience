extends TestCase
## EngineGearbox (engine sound v2, docs/motorsound.md §4): automatic-style gear choice, shifts, launch, idle,
## free revving, limiter – for gearbox profiles shaped like the five cars of the contract (§2), driven with the
## cars' acceleration curves (VehicleModel, config vehicles.types).

const DT := 1.0 / 60.0

## Gearboxes in the spirit of docs/motorsound.md §2 (the real banks bring their own values).
const PROFILES := {
	"kompakt": {"sporty": true,
		"engine": {"idle_rpm": 850, "redline_rpm": 6800, "limiter_rpm": 7000, "fuel": "petrol", "aspiration": "turbo"},
		"gearbox": {"kmh_per_1000rpm": [8.5, 14.0, 20.0, 26.5, 32.5, 38.5, 45.0], "upshift_rpm": [2400, 6600],
			"downshift_rpm": [1300, 3800], "shift_time_s": 0.12, "launch_rpm": 3000}},
	"kombi": {"sporty": false,
		"engine": {"idle_rpm": 780, "redline_rpm": 4600, "limiter_rpm": 4800, "fuel": "diesel", "aspiration": "turbo"},
		"gearbox": {"kmh_per_1000rpm": [10.0, 16.0, 24.5, 32.0, 39.5, 46.5, 53.5, 60.0], "upshift_rpm": [1800, 4300],
			"downshift_rpm": [1100, 2600], "shift_time_s": 0.3, "launch_rpm": 1800}},
	"limousine": {"sporty": false,
		"engine": {"idle_rpm": 650, "redline_rpm": 7000, "limiter_rpm": 7200, "fuel": "petrol", "aspiration": "turbo"},
		"gearbox": {"kmh_per_1000rpm": [9.0, 14.5, 21.5, 28.5, 35.0, 41.5, 47.0, 52.0], "upshift_rpm": [2200, 6800],
			"downshift_rpm": [1200, 3600], "shift_time_s": 0.22, "launch_rpm": 2200}},
	"sportwagen": {"sporty": true,
		"engine": {"idle_rpm": 950, "redline_rpm": 9000, "limiter_rpm": 9200, "fuel": "petrol", "aspiration": "na"},
		"gearbox": {"kmh_per_1000rpm": [7.5, 12.0, 16.5, 21.5, 27.0, 33.0, 40.0], "upshift_rpm": [3500, 8800],
			"downshift_rpm": [1600, 5500], "shift_time_s": 0.1, "launch_rpm": 4000}},
	"gran_turismo": {"sporty": true,
		"engine": {"idle_rpm": 700, "redline_rpm": 7000, "limiter_rpm": 7200, "fuel": "petrol", "aspiration": "turbo"},
		"gearbox": {"kmh_per_1000rpm": [9.0, 14.5, 21.0, 28.5, 35.5, 43.0, 52.0], "upshift_rpm": [3000, 6800],
			"downshift_rpm": [1300, 4200], "shift_time_s": 0.18, "launch_rpm": 2600}},
}


func _gearbox(id: String) -> EngineGearbox:
	var p: Dictionary = PROFILES[id]
	return EngineGearbox.new().setup(p["gearbox"], p["engine"], bool(p["sporty"]))


func _spec(id: String) -> Dictionary:
	return VehicleModel.resolve_spec(cfg(), id)


## Speed after dt seconds at `throttle` on the car's acceleration curve (like VehicleModel._update_driving).
func _accel(spec: Dictionary, v: float, throttle: float) -> float:
	var vmax := float(spec["vmax_kmh"])
	var a0 := float(spec["accel_a0"])
	var q := float(spec["accel_q"])
	if v >= vmax:
		return v
	return VehicleModel.curve_speed(VehicleModel.curve_time(v, vmax, a0, q) + DT * throttle, vmax, a0, q)


## Accelerates from standstill at `throttle` for `seconds`; returns the trace [{t, v, rpm, gear, load, up}].
func _run(gb: EngineGearbox, spec: Dictionary, throttle: float, seconds: float) -> Array:
	var vmax := float(spec["vmax_kmh"])
	var v := 0.0
	var trace: Array = []
	var t := 0.0
	while t < seconds:
		v = _accel(spec, v, throttle)
		var before := gb.rpm
		gb.update(DT, v, throttle, vmax, true)
		trace.append({"t": t, "v": v, "rpm": gb.rpm, "gear": gb.gear, "load": gb.load, "up": gb.ev_upshift,
			"down": gb.ev_downshift, "before": before, "blip": gb.ev_blip})
		t += DT
	return trace


func test_rpm_always_between_idle_and_limiter() -> void:
	for id in PROFILES:
		var gb := _gearbox(id)
		var spec := _spec(id)
		var vmax := float(spec["vmax_kmh"])
		var lo := gb.idle_rpm
		var hi := gb.limiter_rpm
		var v := 0.0
		var bad := 0
		# idle, free revving at the limiter, full-throttle run, coasting, braking, idle
		var plan := [[1.0, 0.0, "stand"], [1.5, 1.0, "stand"], [0.8, 0.0, "stand"], [40.0, 1.0, "accel"],
			[8.0, 0.0, "coast"], [4.0, 0.0, "brake"], [1.0, 0.0, "stand"]]
		for step in plan:
			var t := 0.0
			while t < float(step[0]):
				var thr := float(step[1])
				match str(step[2]):
					"stand":
						v = 0.0
					"accel":
						v = _accel(spec, v, thr)
					"coast":
						v = maxf(0.0, v - 5.0 * DT)
					"brake":
						v = maxf(0.0, v - 70.0 * DT)
				gb.update(DT, v, thr, vmax, true)
				if is_nan(gb.rpm) or gb.rpm < lo - 0.001 or gb.rpm > hi + 0.001 or gb.gear < 0 or gb.gear > gb.top_gear():
					bad += 1
				t += DT
		assert_eq(bad, 0, "%s: Drehzahl immer in [Leerlauf, Begrenzer], Gang gültig" % id)


func test_full_throttle_run_shifts_up_in_order() -> void:
	for id in PROFILES:
		var gb := _gearbox(id)
		var spec := _spec(id)
		var trace := _run(gb, spec, 1.0, 70.0)
		var gears: Array[int] = []
		var downs := 0
		var up_rpms: Array[float] = []
		for s in trace:
			var g := int(s["gear"])
			if g > 0 and (gears.is_empty() or gears[gears.size() - 1] != g):
				gears.append(g)
			if bool(s["down"]):
				downs += 1
			if bool(s["up"]) and float(s["v"]) < float(spec["vmax_kmh"]) * 0.95:
				up_rpms.append(float(s["before"]))
		assert_eq(downs, 0, "%s: kein Rückschalten bei Vollgas" % id)
		for i in gears.size():
			if gears[i] != i + 1:
				fail("%s: Gänge nacheinander 1, 2, 3 … (ist %s)" % [id, str(gears)])
				break
		assert_eq(gears[gears.size() - 1], gb.top_gear(), "%s: höchster Gang bei vmax (%s)" % [id, str(gears)])
		for r in up_rpms:
			assert_between(r, gb.up_rpm.y - 350.0, gb.limiter_rpm, "%s: Hochschalten bei Vollgas nahe upshift_rpm[1]" % id)
		var last: Dictionary = trace[trace.size() - 1]
		assert_true(float(last["v"]) > float(spec["vmax_kmh"]) * 0.97, "%s: vmax erreicht" % id)
		assert_true(float(last["rpm"]) < gb.limiter_rpm - 100.0, "%s: bei vmax unter dem Begrenzer (%d)" % [id, int(last["rpm"])])


func test_light_throttle_shifts_earlier() -> void:
	for id in PROFILES:
		var spec := _spec(id)
		var full := _run(_gearbox(id), spec, 1.0, 25.0)
		var light := _run(_gearbox(id), spec, 0.35, 40.0)
		var f := _first_up_rpms(full, 2)
		var l := _first_up_rpms(light, 2)
		assert_eq(l.size(), 2, "%s: auch mit wenig Gas wird hochgeschaltet" % id)
		if l.size() < 2 or f.size() < 2:
			continue
		var gb := _gearbox(id)
		for i in 2:
			assert_true(l[i] < f[i] - 500.0, "%s: wenig Gas schaltet früher (%d vs. %d)" % [id, int(l[i]), int(f[i])])
			assert_true(l[i] < lerpf(gb.up_rpm.x, gb.up_rpm.y, 0.5), "%s: wenig Gas schaltet in der unteren Hälfte" % id)


func _first_up_rpms(trace: Array, count: int) -> Array[float]:
	var out: Array[float] = []
	for s in trace:
		if bool(s["up"]) and out.size() < count:
			out.append(float(s["before"]))
	return out


func test_coasting_downshifts() -> void:
	for id in PROFILES:
		var gb := _gearbox(id)
		var spec := _spec(id)
		_run(gb, spec, 1.0, 70.0)
		var v := float(spec["vmax_kmh"]) * 0.99
		var last_gear := gb.gear
		var ups := 0
		var downs := 0
		while v > 0.0:
			v = maxf(0.0, v - 5.0 * DT)
			gb.update(DT, v, 0.0, float(spec["vmax_kmh"]), true)
			if gb.ev_upshift:
				ups += 1
			if gb.ev_downshift:
				downs += 1
				assert_true(gb.gear < last_gear, "%s: Gänge fallen" % id)
			assert_true(gb.load < 0.01, "%s: Schub ohne Last (kein Zwischengas beim Rollen)" % id)
			last_gear = gb.gear
		assert_eq(ups, 0, "%s: kein Hochschalten beim Rollen" % id)
		assert_true(downs >= gb.top_gear() - 2, "%s: beim Ausrollen zurückgeschaltet (%d)" % [id, downs])
		assert_eq(gb.gear, 0, "%s: im Stand Leerlauf (neutral)" % id)


func test_braking_downshifts_with_blip_on_sporty_cars() -> void:
	for id in ["sportwagen", "gran_turismo", "kombi", "limousine"]:
		var gb := _gearbox(id)
		var spec := _spec(id)
		_run(gb, spec, 1.0, 25.0)
		var v := _speed_after(spec, 1.0, 25.0)
		var blips := 0
		var downs := 0
		var max_blip_load := 0.0
		while v > 0.0:
			v = maxf(0.0, v - 70.0 * DT)
			gb.update(DT, v, 0.0, float(spec["vmax_kmh"]), true)
			if gb.ev_downshift:
				downs += 1
				assert_true(gb.braking, "%s: Rückschalten beim Bremsen erkannt (Tempo fällt ohne Gas)" % id)
			if gb.ev_blip:
				blips += 1
			if gb.shifting and gb.shift_dir < 0:
				max_blip_load = maxf(max_blip_load, gb.load)
		assert_true(downs >= 3, "%s: mehrere Rückschaltungen beim Bremsen (%d)" % [id, downs])
		if bool(PROFILES[id]["sporty"]):
			assert_eq(blips, downs, "%s: jede Rückschaltung beim Bremsen mit Zwischengas" % id)
			assert_true(max_blip_load > 0.8, "%s: Zwischengas = kurze Last" % id)
		else:
			assert_eq(blips, 0, "%s: kein Zwischengas" % id)
			assert_true(max_blip_load < 0.01, "%s: keine Last beim Bremsen" % id)


func _speed_after(spec: Dictionary, throttle: float, seconds: float) -> float:
	var v := 0.0
	var t := 0.0
	while t < seconds:
		v = _accel(spec, v, throttle)
		t += DT
	return v


func test_idle_at_standstill() -> void:
	for id in PROFILES:
		var gb := _gearbox(id)
		for i in 120:
			gb.update(DT, 0.0, 0.0, 250.0, true)
		assert_near(gb.rpm, gb.idle_rpm, 1.0, "%s: Leerlauf im Stand" % id)
		assert_eq(gb.gear, 0, "%s: neutral" % id)
		assert_near(gb.load, 0.0, 0.001, "%s: keine Last" % id)


func test_free_revving_with_inertia_up_to_the_limiter() -> void:
	for id in PROFILES:
		var gb := _gearbox(id)
		gb.update(DT, 0.0, 0.0, 250.0, true)
		var t_lim := -1.0
		var t := 0.0
		var limiter_seen := false
		while t < 2.0:
			gb.update(DT, 0.0, 1.0, 250.0, true)
			t += DT
			if t_lim < 0.0 and gb.rpm >= gb.limiter_rpm - 1.0:
				t_lim = t
			limiter_seen = limiter_seen or gb.limiter
			assert_true(gb.rpm <= gb.limiter_rpm, "%s: nie über dem Begrenzer" % id)
		assert_between(t_lim, 0.25, 1.4, "%s: Hochdrehen bis zum Begrenzer mit Trägheit" % id)
		assert_true(limiter_seen, "%s: Begrenzer aktiv" % id)
		assert_eq(gb.gear, 0, "%s: Gasstöße im Stand im Leerlauf (neutral)" % id)
		# release: back to idle, not instantly
		var t_idle := -1.0
		t = 0.0
		while t < 3.0:
			gb.update(DT, 0.0, 0.0, 250.0, true)
			t += DT
			if t_idle < 0.0 and gb.rpm <= gb.idle_rpm + 30.0:
				t_idle = t
		assert_between(t_idle, 0.4, 2.6, "%s: fällt mit Trägheit zurück in den Leerlauf" % id)
		assert_false(gb.limiter, "%s: Begrenzer aus ohne Gas" % id)


func test_launch_slips_at_launch_rpm() -> void:
	for id in PROFILES:
		var gb := _gearbox(id)
		var spec := _spec(id)
		var trace := _run(gb, spec, 1.0, 1.5)
		var mid: Dictionary = trace[int(0.6 / DT)]
		var wheel := gb.wheel_rpm(float(mid["v"]), 1)
		assert_eq(int(mid["gear"]), 1, "%s: 1. Gang beim Anfahren" % id)
		if wheel < gb.launch_rpm * 0.8:
			assert_near(float(mid["rpm"]), gb.launch_rpm, gb.launch_rpm * 0.12, "%s: Kupplung schleift bei launch_rpm" % id)


func test_no_hunting_at_vmax_and_while_cruising() -> void:
	for id in PROFILES:
		var gb := _gearbox(id)
		var spec := _spec(id)
		var vmax := float(spec["vmax_kmh"])
		_run(gb, spec, 1.0, 70.0)
		var shifts := 0
		for i in int(20.0 / DT):
			gb.update(DT, vmax, 1.0, vmax, true)
			if gb.ev_upshift or gb.ev_downshift:
				shifts += 1
		assert_eq(shifts, 0, "%s: bei vmax kein Schalten" % id)
		# cruise at 130 km/h with an autopilot-like throttle (1.0 / 0.6 / 0 every few frames)
		shifts = 0
		var pattern := [1.0, 1.0, 0.6, 0.6, 0.6, 0.0, 0.0, 0.6, 1.0, 0.0]
		for i in int(30.0 / DT):
			gb.update(DT, 130.0 + 1.5 * sin(i * 0.05), float(pattern[i % pattern.size()]), vmax, true)
			if i > int(3.0 / DT) and (gb.ev_upshift or gb.ev_downshift):
				shifts += 1
		assert_eq(shifts, 0, "%s: kein Pendeln beim Dahinrollen" % id)
		# lower vmax (rain, hill): settles, then stays
		shifts = 0
		var v2 := vmax * 0.82
		for i in int(15.0 / DT):
			gb.update(DT, v2, 1.0, v2, true)
			if i > int(3.0 / DT) and (gb.ev_upshift or gb.ev_downshift):
				shifts += 1
		assert_eq(shifts, 0, "%s: kein Pendeln bei gesenkter vmax" % id)


func test_top_gear_holds_vmax_below_limiter() -> void:
	for id in PROFILES:
		var gb := _gearbox(id)
		var vmax := float(_spec(id)["vmax_kmh"])
		var top := gb.wheel_rpm(vmax, gb.top_gear())
		assert_true(top < gb.limiter_rpm, "%s: vmax im höchsten Gang unter dem Begrenzer (%d)" % [id, int(top)])
		assert_true(top > gb.down_rpm.y, "%s: vmax im höchsten Gang über der Rückschaltdrehzahl" % id)


func test_kickdown_skips_gears_without_hunting() -> void:
	var gb := _gearbox("gran_turismo")
	# cruise at 120 km/h with light throttle until the gear settles high
	for i in int(12.0 / DT):
		gb.update(DT, 120.0, 0.25, 270.0, true)
	var cruise_gear := gb.gear
	assert_true(cruise_gear >= 5, "leichtes Gas: hoher Gang (%d)" % cruise_gear)
	var t := 0.0
	var v := 120.0
	var spec := _spec("gran_turismo")
	var down_at := -1.0
	var ups_soon := 0
	while t < 2.0:
		v = _accel(spec, v, 1.0)
		gb.update(DT, v, 1.0, 270.0, true)
		if gb.ev_downshift and down_at < 0.0:
			down_at = t
		elif gb.ev_upshift and down_at >= 0.0 and t - down_at < 1.0:
			ups_soon += 1
		t += DT
	assert_between(down_at, 0.0, 0.6, "Kickdown nach dem Gasgeben")
	assert_true(gb.gear <= cruise_gear - 2, "Kickdown überspringt Gänge (%d -> %d)" % [cruise_gear, gb.gear])
	assert_eq(ups_soon, 0, "kein sofortiges Hochschalten nach dem Kickdown")


func test_generic_profile() -> void:
	var gb := EngineGearbox.generic(250.0, 6)
	assert_eq(gb.top_gear(), 6, "6 Gänge")
	assert_true(gb.wheel_rpm(250.0, 6) < gb.limiter_rpm, "vmax unter dem Begrenzer")
	var spec := _spec("limousine")
	var trace := _run(gb, spec, 1.0, 60.0)
	var last: Dictionary = trace[trace.size() - 1]
	assert_eq(int(last["gear"]), 6, "erreicht den höchsten Gang")
