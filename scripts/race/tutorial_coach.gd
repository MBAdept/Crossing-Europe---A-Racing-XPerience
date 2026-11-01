class_name TutorialCoach
extends RefCounted
## Hints of the tutorial stage (StagePlan.tutorial – Kiel – Hamburg; design document: „Kiel – Hamburg:
## alternativlose Startetappe, gleichzeitig Tutorial"). The race session reports what happens (start,
## fuel announcements, refuelling, radar warning, police chase, a section without speed limit, City
## Limits, the first collision, the first curve that is too fast for the car); the coach turns every topic
## into short German hints – each topic once per stage – and hands them out one after another,
## render.tutorial_hint_s seconds apart, for Hud.show_message. Urgent topics (fuel lane, refuelling, radar,
## chase, City Limits, curve) jump the queue, because the situation they explain is happening right now.
## The texts use the configured numbers.
## The control hints follow the active input: with a gamepad (InputMode.gamepad at setup, e.g. on the
## Steam Deck) only the gamepad hint, otherwise keyboard first, then gamepad.
## Pure logic (no autoloads, no nodes). Owner: race module.

const URGENT := ["fuel_lane", "refuel", "radar", "chase", "city", "curve"]

var hint_s := 6.0                  ## seconds a hint stays on screen (render.tutorial_hint_s)
var gap_s := 0.6                   ## pause between two queued hints
var shown: Array[String] = []      ## topics already triggered (in order)
var gamepad := false               ## gamepad is the active input: control hints for the gamepad only

var _cfg: Dictionary = {}
var _queue: Array[String] = []
var _wait := 0.0


func setup(config: Dictionary) -> void:
	_cfg = config
	hint_s = maxf(1.0, _f("render.tutorial_hint_s", 6.0))
	gamepad = InputMode.gamepad
	shown.clear()
	_queue.clear()
	_wait = 0.0


func _f(path: String, default: float) -> float:
	return float(ConfigLoader.lookup(_cfg, path, default))


## Queues the hints of a topic (only the first time it is triggered). args: values of the situation,
## e.g. {"limit": 120} for "radar". Returns the number of queued hints.
func trigger(topic: String, args: Dictionary = {}) -> int:
	if shown.has(topic):
		return 0
	var texts := hints_for(topic, args)
	if texts.is_empty():
		return 0
	shown.append(topic)
	if URGENT.has(topic):
		for i in range(texts.size() - 1, -1, -1):
			_queue.push_front(texts[i])
		_wait = minf(_wait, 0.0)
	else:
		_queue.append_array(texts)
	return texts.size()


## Keeps the next queued hint back for at least `seconds` (urgent topics still come at once).
func hold(seconds: float) -> void:
	_wait = maxf(_wait, seconds)


## Advances the timer; returns the hint to show now or "" (at most one per call).
func update(dt: float) -> String:
	_wait -= dt
	if _queue.is_empty() or _wait > 0.0:
		return ""
	_wait = hint_s + gap_s
	return _queue.pop_front()


func pending() -> int:
	return _queue.size()


## The hint texts of a topic (German, translatable keys with configured numbers).
func hints_for(topic: String, args: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	match topic:
		"start":
			if not gamepad:
				out.append(tr("Tipp: Lenken mit den Pfeiltasten links/rechts oder A/D"))
				out.append(tr("Tipp: Gas mit Pfeil hoch oder W, Bremse mit Pfeil runter oder S"))
			out.append(tr("Tipp: Gamepad – Stick lenkt, rechter Trigger Gas, linker Trigger Bremse"))
		"fuel_low":
			out.append(tr("Tipp: Nur %d %% im Tank – unterwegs an der Tankstelle nachtanken!") % int(round(float(args.get("percent", 35.0)))))
		"fuel_hud":
			out.append(tr("Tipp: Unten links stehen Tankstand, Reichweite und nächste Tankstelle"))
		"fuel_announce":
			out.append(tr("Tipp: Tankstellen werden %s km vorher angekündigt") % _announce_list())
		"fuel_lane":
			out.append(tr("Tipp: Rechts in die Tankspur und unter %d km/h rollen – dann wird getankt") % int(round(_f("fuel.lane_trigger_speed_kmh", 60.0))))
		"refuel":
			out.append(tr("Tipp: Gas geben bricht das Tanken ab – warte, bis der Tank voll ist"))
		"radar":
			var limit := float(args.get("limit", _f("radar.default_limit_kmh", 120.0)))
			var tol := _f("radar.tolerance", 0.15)
			out.append(tr("Tipp: Toleranz %d %% – bei Limit %d blitzt das Radar erst ab %d km/h") % [int(round(tol * 100.0)), int(round(limit)), int(round(limit * (1.0 + tol)))])
		"chase":
			out.append(tr("Tipp: Flucht gelingt mit im Schnitt %d km/h über %d Sekunden") % [int(round(_f("police.escape_speed_kmh", 220.0))), int(round(_f("police.escape_window_s", 12.0)))])
			out.append(tr("Tipp: Sonst hält dich die Polizei an – %d Sekunden Stillstand") % int(round(_f("police.stop_duration_s", 10.0))))
		"unlimited":
			out.append(tr("Tipp: Kein Tempolimit – aber Vollgas kostet deutlich mehr Sprit"))
		"city":
			out.append(tr("Tipp: City Limits – Tempo %d, dichter Verkehr, keine Tankstelle, kein Radar") % int(args.get("limit", 50)))
		"collision":
			out.append(tr("Tipp: Zusammenstoß – der Wagen wird auf %d km/h abgebremst und abgedrängt") % int(round(_f("collision.target_speed_kmh", 10.0))))
		"curve":
			out.append(tr("Tipp: Vor scharfen Kurven bremsen – sonst schiebt der Wagen nach außen"))
	return out


## "30, 15 und 5" from fuel.announce_km.
func _announce_list() -> String:
	var ks: Array[int] = []
	for k in ConfigLoader.lookup(_cfg, "fuel.announce_km", [30, 15, 5]):
		ks.append(int(k))
	ks.sort()
	ks.reverse()
	var parts: Array[String] = []
	for k in ks:
		parts.append(str(k))
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " " + tr("und") + " " + parts[parts.size() - 1]
