class_name EngineGearbox
extends RefCounted
## Gearbox and rpm model of one car for the engine sound (docs/motorsound.md §4). Pure logic – no audio, no
## autoloads; EngineAudio (or a test) calls update() once per frame with speed and throttle.
##
## - Gear choice like an automatic: upshift between upshift_rpm[0] (light throttle) and [1] (full throttle),
##   downshift between downshift_rpm[0] and [1] (hysteresis). The throttle for these thresholds is smoothed
##   (rises in ~0.15 s for kick-down, falls in ~0.8 s so lifting briefly keeps the gear). Kick-down may skip
##   gears. Close to vmax (no more acceleration) it shifts into the gear that holds vmax lower, so the top gear
##   carries vmax when the ratios allow it.
## - Braking (speed falls faster than BRAKE_DECEL with closed throttle) downshifts earlier, gear by gear, with a
##   throttle blip when `blip` is set (sporty cars).
## - Shift = shift_time_s of load cut (upshift) or blip (downshift) while the rpm moves to the new gear with a
##   quick exponential.
## - Launch: in 1st gear the clutch/converter slips at launch_rpm (scaled by throttle) until the wheels catch up.
## - Standstill (or active = false): neutral (gear 0), idle; throttle revs the engine freely with inertia up to
##   the limiter (rev_up_s / rev_down_s).
## - No hunting: a minimum time between shifts, no non-braking downshift within AFTER_UP_S of an upshift, and no
##   shift whose new rpm would immediately trigger the opposite shift (GUARD_RPM).
## Outputs: rpm (always within [idle_rpm, limiter_rpm]), gear (0 = neutral, 1..n), load 0..1 (engine load for the
## sound: throttle, cut while upshifting, blip while downshifting), limiter (at the rev limiter with throttle),
## braking, shifting, shift_dir; events of the last update(): ev_upshift, ev_downshift, ev_blip.

const STAND_KMH := 1.0          ## below: standing (neutral)
const BRAKE_DECEL := 15.0       ## km/h per s; coasting loses ~5, the brakes ~70
const MIN_GAP_S := 0.3          ## minimum time between two shifts (plus shift_time)
const BRAKE_GAP_S := 0.08       ## … while braking (downshift cascade)
const AFTER_UP_S := 1.2         ## no downshift (except braking) this long after an upshift
const GUARD_RPM := 200.0        ## a shift must land this far from the opposite threshold
const CLUTCH_S := 0.35          ## clutch/converter engagement after leaving the standstill
const BLIP_LOAD := 0.85         ## engine load during a throttle blip
const BRAKE_DOWN := 0.3         ## braking downshift point between downshift_rpm[0] and [1] …
const BRAKE_DOWN_BLIP := 0.7    ## … for cars with throttle blips (keeps the revs up, sporty)

var ratios := PackedFloat64Array()      ## km/h per 1000 rpm, index 0 = 1st gear
var idle_rpm := 800.0
var redline_rpm := 6500.0
var limiter_rpm := 6800.0
var up_rpm := Vector2(2500.0, 6200.0)   ## upshift at light / full throttle
var down_rpm := Vector2(1300.0, 3600.0) ## downshift at light / full throttle
var shift_time := 0.25
var launch_rpm := 2500.0
var blip := false
var rev_up_rate := 12000.0              ## rpm/s free revving at full throttle
var rev_down_rate := 8000.0             ## rpm/s falling near the limiter with closed throttle

var rpm := 800.0
var gear := 0
var load := 0.0
var limiter := false
var braking := false
var shifting := false
var shift_dir := 0
var ev_upshift := false
var ev_downshift := false
var ev_blip := false

var _thr_s := 0.0
var _v_prev := -1.0
var _acc_s := 0.0
var _shift_t := 0.0
var _since_shift := 10.0
var _since_up := 10.0
var _blip_t := 0.0
var _clutch_t := 0.0


## gb = bank "gearbox", eng = bank "engine" (docs/motorsound.md §1). sporty_default: throttle blips when the
## bank does not set gearbox.blip itself.
func setup(gb: Dictionary, eng: Dictionary, sporty_default: bool = false) -> EngineGearbox:
	ratios = PackedFloat64Array()
	for r in gb.get("kmh_per_1000rpm", [10.0]):
		ratios.append(maxf(float(r), 0.1))
	if ratios.is_empty():
		ratios.append(10.0)
	idle_rpm = maxf(float(eng.get("idle_rpm", 800.0)), 100.0)
	redline_rpm = maxf(float(eng.get("redline_rpm", 6500.0)), idle_rpm + 500.0)
	limiter_rpm = maxf(float(eng.get("limiter_rpm", redline_rpm)), redline_rpm)
	var up: Array = gb.get("upshift_rpm", [idle_rpm * 3.0, redline_rpm * 0.95])
	var down: Array = gb.get("downshift_rpm", [idle_rpm * 1.6, redline_rpm * 0.55])
	up_rpm = Vector2(float(up[0]), minf(float(up[1]), limiter_rpm))
	down_rpm = Vector2(minf(float(down[0]), up_rpm.x - 100.0), minf(float(down[1]), up_rpm.y - 100.0))
	shift_time = clampf(float(gb.get("shift_time_s", 0.25)), 0.05, 1.0)
	launch_rpm = clampf(float(gb.get("launch_rpm", idle_rpm * 2.5)), idle_rpm, redline_rpm)
	blip = bool(gb.get("blip", sporty_default))
	var diesel := str(eng.get("fuel", "petrol")) == "diesel"
	var turbo := str(eng.get("aspiration", "")) == "turbo"
	var up_s := float(gb.get("rev_up_s", 0.9 if diesel else (0.6 if turbo else 0.45)))
	var down_s := float(gb.get("rev_down_s", 1.6 if diesel else (1.25 if turbo else 1.05)))
	var span := limiter_rpm - idle_rpm
	rev_up_rate = span / maxf(up_s, 0.05)
	# the falling rate shrinks towards idle (0.3 + 0.7·x): limiter -> idle takes ≈ 1.7 · span / rate
	rev_down_rate = 1.7 * span / maxf(down_s, 0.05)
	reset()
	return self


## Generic profile when no bank exists (fallback sound, engine_state()): petrol engine 800–6800/min,
## geometric ratios with vmax at 5400/min in the top gear.
static func generic(vmax_kmh: float, gears: int = 6) -> EngineGearbox:
	var n := clampi(gears, 3, 10)
	var v := maxf(vmax_kmh, 80.0)
	var top := v / 5.4
	var first := v * 0.24 / 6.3
	var list := []
	for i in n:
		list.append(first * pow(top / first, float(i) / float(n - 1)))
	return EngineGearbox.new().setup(
		{"kmh_per_1000rpm": list, "upshift_rpm": [2500, 6200], "downshift_rpm": [1300, 3600], "shift_time_s": 0.25,
			"launch_rpm": 2200},
		{"idle_rpm": 800, "redline_rpm": 6500, "limiter_rpm": 6800, "fuel": "petrol", "aspiration": "turbo"})


func reset() -> void:
	rpm = idle_rpm
	gear = 0
	load = 0.0
	limiter = false
	braking = false
	shifting = false
	shift_dir = 0
	ev_upshift = false
	ev_downshift = false
	ev_blip = false
	_thr_s = 0.0
	_v_prev = -1.0
	_acc_s = 0.0
	_shift_t = 0.0
	_since_shift = 10.0
	_since_up = 10.0
	_blip_t = 0.0
	_clutch_t = 0.0


func top_gear() -> int:
	return ratios.size()


## Engine rpm in gear g (1..n) at a speed, without clutch slip or limits.
func wheel_rpm(speed_kmh: float, g: int) -> float:
	return speed_kmh / ratios[clampi(g, 1, ratios.size()) - 1] * 1000.0


## Upshift and downshift points (rpm) for a (smoothed) throttle 0..1.
func thresholds(throttle01: float) -> Vector2:
	var t := clampf(throttle01, 0.0, 1.0)
	return Vector2(lerpf(up_rpm.x, up_rpm.y, pow(t, 1.5)), lerpf(down_rpm.x, down_rpm.y, t))


## One frame: speed of the car (km/h), throttle 0..1, current vmax (for the top-gear rule, 0 = unknown),
## active = engine drives the car (false = neutral, e.g. after the finish).
func update(dt: float, speed_kmh: float, throttle: float, vmax_kmh: float = 0.0, active: bool = true) -> void:
	ev_upshift = false
	ev_downshift = false
	ev_blip = false
	if dt <= 0.0:
		return
	var v := maxf(speed_kmh, 0.0)
	var thr := clampf(throttle, 0.0, 1.0)
	_thr_s += (thr - _thr_s) * (1.0 - exp(-dt / (0.15 if thr > _thr_s else 0.8)))
	if _v_prev < 0.0:
		_v_prev = v
	_acc_s += ((v - _v_prev) / dt - _acc_s) * (1.0 - exp(-dt / 0.15))
	_v_prev = v
	braking = thr < 0.05 and _acc_s < -BRAKE_DECEL and v > STAND_KMH
	_since_shift += dt
	_since_up += dt
	limiter = false
	if not active or v < STAND_KMH:
		_neutral(dt, thr)
	else:
		_drive(dt, v, thr, vmax_kmh)
	rpm = clampf(rpm, idle_rpm, limiter_rpm)


func _neutral(dt: float, thr: float) -> void:
	if gear != 0:
		gear = 0
		shifting = false
		shift_dir = 0
		_shift_t = 0.0
		_blip_t = 0.0
	var span := maxf(limiter_rpm - idle_rpm, 1.0)
	var target := idle_rpm + span * 1.08 * thr
	var diff := target - rpm
	if diff > 0.0:
		rpm += minf(diff, rev_up_rate * (0.15 + 0.85 * thr) * dt * clampf(diff / 400.0, 0.12, 1.0))
	elif diff < 0.0:
		var x := clampf((rpm - idle_rpm) / span, 0.0, 1.0)
		rpm -= minf(-diff, rev_down_rate * (0.3 + 0.7 * x) * dt * clampf(-diff / 250.0, 0.12, 1.0))
	if rpm >= limiter_rpm:
		rpm = limiter_rpm
		limiter = thr > 0.3
	load = thr


func _drive(dt: float, v: float, thr: float, vmax: float) -> void:
	if gear == 0:
		gear = _start_gear(v)
		_clutch_t = CLUTCH_S
		_since_shift = 0.0
	if shifting:
		_shift_t -= dt
		if _shift_t <= 0.0:
			shifting = false
			shift_dir = 0
	if not shifting:
		_choose_gear(v, thr, vmax)
	var target := wheel_rpm(v, gear)
	if gear == 1:
		# launch: the clutch (or converter) slips until the wheels catch up
		target = maxf(target, idle_rpm * 1.05 + (launch_rpm - idle_rpm * 1.05) * thr)
	target = maxf(target, idle_rpm)
	if target >= limiter_rpm:
		target = limiter_rpm
		limiter = thr > 0.3
	var tau := 0.04
	if shifting:
		tau = shift_time * 0.28
		if _blip_t > 0.0:
			target = minf(target * 1.05, limiter_rpm)
	elif _clutch_t > 0.0:
		tau = 0.12
	_clutch_t -= dt
	rpm += (target - rpm) * (1.0 - exp(-dt / tau))
	load = thr
	if shifting:
		var p := clampf(1.0 - _shift_t / shift_time, 0.0, 1.0)
		if shift_dir > 0:
			load = thr * smoothstep(0.5, 1.0, p)
		elif _blip_t > 0.0:
			load = maxf(thr, BLIP_LOAD)
	_blip_t -= dt


func _choose_gear(v: float, thr: float, vmax: float) -> void:
	if _since_shift < shift_time + (BRAKE_GAP_S if braking else MIN_GAP_S):
		return
	var n := ratios.size()
	var th := thresholds(_thr_s)
	var up_at := th.x
	var down_at := th.y
	if braking:
		down_at = lerpf(down_rpm.x, down_rpm.y, BRAKE_DOWN_BLIP if blip else BRAKE_DOWN)
	var r := wheel_rpm(v, gear)
	if gear < n and not braking:
		var r_next := wheel_rpm(v, gear + 1)
		var near_top := vmax > 0.0 and v >= vmax * 0.965 and _acc_s < 2.5 and thr > 0.2
		var guard := 0.0 if _acc_s > 1.5 else GUARD_RPM
		if (r >= up_at or near_top) and r_next > down_at + guard:
			_shift(gear + 1)
			return
	if gear > 1 and r <= down_at:
		if not braking and _since_up < AFTER_UP_S:
			return
		var up_guard := (up_rpm.y if braking else up_at) - GUARD_RPM
		var g := gear - 1
		if not braking and _thr_s > 0.7:
			# kick-down: skip gears until the rpm sits comfortably above the downshift point
			while g > 1 and wheel_rpm(v, g) < down_at + GUARD_RPM and wheel_rpm(v, g - 1) <= up_guard:
				g -= 1
		if wheel_rpm(v, g) <= up_guard:
			_shift(g)


## Gear when the car starts moving: 1st from standstill; already rolling (model started at speed): the highest
## gear with a comfortable rpm.
func _start_gear(v: float) -> int:
	var want := maxf(idle_rpm * 1.3, down_rpm.x + 300.0)
	for g in range(ratios.size(), 0, -1):
		if wheel_rpm(v, g) >= want:
			return g
	return 1


func _shift(g: int) -> void:
	shift_dir = 1 if g > gear else -1
	gear = g
	shifting = true
	_shift_t = shift_time
	_since_shift = 0.0
	if shift_dir > 0:
		_since_up = 0.0
		ev_upshift = true
	else:
		ev_downshift = true
		if blip and braking:
			_blip_t = shift_time * 0.6
			ev_blip = true
