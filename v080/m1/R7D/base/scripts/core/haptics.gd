class_name Haptics
extends RefCounted
## Gamepad vibration in the race (Steam Deck: Steam Input turns it into the haptic pulses of the controller): what
## the car does is felt, not only heard and seen – a collision, a guardrail hit and the scraping along it, the
## shoulder or grass at speed, understeer from its first sign (a light buzz: "Gas weg"), the radar flash.
## Off with Settings.vibration = false (Optionen "Vibration", default on), while a keyboard is the active input
## (InputMode.gamepad), with the autopilot (attract demos) and while paused; stopped at the finish and when the
## scene ends. The race session calls pulse() on events and update() every simulation step with the continuous
## level (level_for()); at most `max_rate_hz` calls per second reach the pad, each lasting only `refresh_s`, so
## the vibration ends by itself if the game stalls. Values: config input.vibration (scale, the pulses, the
## continuous levels). Pure logic – the output goes through `start_cb` / `stop_cb` (tests replace them).

var enabled := true                  ## Settings.vibration and a player at the controls (no autopilot)
var active := true                   ## a gamepad is the active input (InputMode.gamepad) – else the pad stays quiet
var device := 0                      ## the pad the player uses (InputMode.device)
var scale := 1.0                     ## input.vibration.scale (0 = off)
var max_rate_hz := 15.0
var refresh_s := 0.25
## The config values (input.vibration) – [weak, strong, seconds] for pulses, weak levels for the continuous ones.
var v: Dictionary = {}
var start_cb: Callable = func(d: int, weak: float, strong: float, seconds: float) -> void: Input.start_joy_vibration(d, weak, strong, seconds)
var stop_cb: Callable = func(d: int) -> void: Input.stop_joy_vibration(d)

var _pulse := Vector2.ZERO           ## weak, strong of the running pulse
var _pulse_t := 0.0
var _sent := Vector2.ZERO            ## what the pad got last (ZERO = stopped)
var _since := 1.0e9                  ## seconds since the last call


const DEFAULTS := {
	"scale": 1.0, "max_rate_hz": 15.0, "refresh_s": 0.25,
	"collision": [0.5, 0.9, 0.35],
	"rail_hit_min": [0.4, 0.3, 0.12], "rail_hit_max": [0.4, 0.9, 0.35], "rail_hit_full_mps": 8.0,
	"rail_scrape": 0.35, "off_road": [0.12, 0.25], "off_road_min_kmh": 30.0,
	"understeer_from": 0.15, "understeer": [0.1, 0.35], "radar_flash": [0.2, 0.2, 0.2],
}


func configure(cfg: Dictionary) -> void:
	v = DEFAULTS.duplicate(true)
	var c: Variant = ConfigLoader.lookup(cfg, "input.vibration", {})
	if c is Dictionary:
		for k: String in c:
			if not k.begins_with("_"):
				v[k] = c[k]
	scale = clampf(float(v["scale"]), 0.0, 2.0)
	max_rate_hz = clampf(float(v["max_rate_hz"]), 2.0, 60.0)
	refresh_s = clampf(float(v["refresh_s"]), 0.05, 2.0)


func _triple(key: String) -> Array:
	var a: Variant = v.get(key, DEFAULTS.get(key, [0.0, 0.0, 0.0]))
	return a if a is Array and (a as Array).size() >= 3 else DEFAULTS[key]


## A pulse of `seconds` (stronger values and the longer time win over a running one).
func pulse(weak: float, strong: float, seconds: float) -> void:
	if not enabled or scale <= 0.0 or seconds <= 0.0:
		return
	var p := Vector2(weak, strong)
	_pulse = p if _pulse_t <= 0.0 else _pulse.max(p)
	_pulse_t = maxf(_pulse_t, seconds)


## Collision with traffic.
func collision() -> void:
	var a := _triple("collision")
	pulse(float(a[0]), float(a[1]), float(a[2]))


## Guardrail hit; impact_mps = the drift that hit the rail (VehicleModel.rail_impact) – a touch is short and light,
## an understeer slide into the rail a hard knock.
func rail_hit(impact_mps: float) -> void:
	var k := clampf(impact_mps / maxf(0.01, float(v.get("rail_hit_full_mps", 8.0))), 0.0, 1.0)
	var lo := _triple("rail_hit_min")
	var hi := _triple("rail_hit_max")
	pulse(lerpf(float(lo[0]), float(hi[0]), k), lerpf(float(lo[1]), float(hi[1]), k), lerpf(float(lo[2]), float(hi[2]), k))


func radar_flash() -> void:
	var a := _triple("radar_flash")
	pulse(float(a[0]), float(a[1]), float(a[2]))


## Continuous level (weak, strong) of the car's state: the shoulder / grass from off_road_min_kmh (stronger with
## the speed), scraping along the guardrail, understeer from understeer_from (0.1 + 0.35 × understeer).
func level_for(speed_kmh: float, off_road: int, rail_contact: bool, understeer: float) -> Vector2:
	var weak := 0.0
	var min_kmh := float(v.get("off_road_min_kmh", 30.0))
	if off_road > 0 and speed_kmh > min_kmh:
		var o: Array = v.get("off_road", [0.12, 0.25])
		weak = lerpf(float(o[0]), float(o[1]), clampf((speed_kmh - min_kmh) / 170.0, 0.0, 1.0))
	if rail_contact and speed_kmh > 20.0:
		weak = maxf(weak, float(v.get("rail_scrape", 0.35)))
	if understeer >= float(v.get("understeer_from", 0.15)):
		var u: Array = v.get("understeer", [0.1, 0.35])
		weak = maxf(weak, float(u[0]) + float(u[1]) * clampf(understeer, 0.0, 1.0))
	return Vector2(weak, 0.0)


## Advances the pulse and sends the combined level (pulse and `level`, the stronger per motor, × scale) – at most
## max_rate_hz times per second, again before refresh_s runs out while it lasts, stop when it is over.
## Returns what the pad should do now.
func update(dt: float, level: Vector2) -> Vector2:
	_since += dt
	_pulse_t -= dt
	var want := level
	if _pulse_t > 0.0:
		want = want.max(_pulse)
	else:
		_pulse = Vector2.ZERO
	want = (want * scale).clamp(Vector2.ZERO, Vector2.ONE) if enabled and active else Vector2.ZERO
	if want.x < 0.01 and want.y < 0.01:
		if _sent != Vector2.ZERO:
			stop_cb.call(device)
			_sent = Vector2.ZERO
		return Vector2.ZERO
	var changed := absf(want.x - _sent.x) > 0.04 or absf(want.y - _sent.y) > 0.04
	if _since >= 1.0 / max_rate_hz and (changed or _since >= refresh_s * 0.5):
		start_cb.call(device, want.x, want.y, refresh_s)
		_sent = want
		_since = 0.0
	return want


## Ends any vibration now (pause, finish, scene end) and drops a running pulse.
func stop() -> void:
	_pulse = Vector2.ZERO
	_pulse_t = 0.0
	if _sent != Vector2.ZERO:
		stop_cb.call(device)
	_sent = Vector2.ZERO


## Options: a short pulse on the pad in use when "Vibration" is switched on (what it feels like).
static func test_pulse() -> void:
	if InputMode.gamepad:
		Input.start_joy_vibration(InputMode.device, 0.35, 0.6, 0.25)
