extends SceneTree
## Scenario checks of the race session in the real race scene (headless, fast time):
##   godot --headless --path . -s res://tests/race/check_session.gd [-- --only=coll_right,tutorial]
## Scenarios (review findings in brackets):
##   coll_right / coll_left / coll_middle  rear hit exactly in line -> pushed to the side with more room,
##                                        left on a tie (COLL-1)
##   dry_rollout     empty tank at 200 km/h behind a slower car -> collision, tow counted after the tow
##                   (COLL-3, FUEL-1, FUEL-3)
##   dry_into_lane   empty tank rolls into the fuel lane and refuels -> no tow counted (FUEL-3)
##   finish_rollout  after the finish line the car collides instead of driving through (COLL-3)
##   refuel_chase    police chase into a refuel: police blocked while refuelling, HUD range at the
##                   current speed and next station 0 at the pumps (POL-1, FUEL-5, FUEL-7)
##   tutorial        Kiel – Hamburg shows the tutorial hints, the dev stage none (TUT-1)
## Prints "CHECK <name> OK …" or "CHECK <name> FEHLER …" per scenario; exit code 0 when all pass.
## The scene is accessed untyped (this script compiles before the autoloads the scene uses).

const SCENARIOS := ["coll_right", "coll_left", "coll_middle", "dry_rollout", "dry_into_lane", "finish_rollout", "refuel_chase", "tutorial", "no_tutorial"]

var _queue: Array[String] = []
var _name := ""
var _sc: Node
var _t := 0.0
var _d: Dictionary = {}
var _ours: Object = null
var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	var only := str(CliArgs.all().get("only", ""))
	for s: String in SCENARIOS:
		if only == "" or only.split(",").has(s):
			_queue.append(s)
	var ts := 20.0
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = int(60.0 * ts)
	Engine.max_physics_steps_per_frame = 64
	_wall0 = Time.get_ticks_msec()


func _physics_process(delta: float) -> bool:
	if _sc == null:
		if _queue.is_empty():
			print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
			quit(0 if _failed.is_empty() else 1)
			return true
		_name = _queue.pop_front()
		_d = {}
		_t = 0.0
		_ours = null
		call("_start_" + _name)
		return false
	_t += delta
	call("_tick_" + _name)
	return false


# --- helpers ------------------------------------------------------------------------------------

func _launch(stage: String, start_km: float, extra: Dictionary = {}) -> void:
	var setup := {"mode": "single", "race_id": "", "stage_id": stage, "from_city": "", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": start_km, "autopilot": false,
		"no_countdown": true, "seed": 3}
	setup.merge(extra, true)
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _done(ok: bool, msg: String) -> void:
	print("CHECK %-15s %s  %s" % [_name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(_name)
	_sc.queue_free()
	_sc = null


func _vehicle() -> VehicleModel:
	return _sc.get("vehicle")


func _traffic() -> TrafficSystem:
	return _sc.get("traffic")


func _fuel() -> FuelSystem:
	return _sc.get("fuel")


func _police() -> PoliceSystem:
	return _sc.get("police")


func _track() -> Track:
	return _sc.get("track")


func _stats() -> Dictionary:
	return _sc.get("stats")


## Puts the player into a lane at a speed and one traffic car dz metres ahead (same x + dx).
func _place(lane: int, speed: float, dz: float, dx: float, car_speed: float) -> void:
	var v := _vehicle()
	var z: float = _sc.get("pos_z")
	v.x = _track().lane_center_x(z, lane)
	v.speed = speed
	_sc.set("cam_x", v.x)
	var tr := _traffic()
	tr.cars.clear()
	var c := TrafficSystem.Car.new()
	c.id = 4711
	c.z = z + dz
	c.x = v.x + dx
	c.lane = lane
	c.speed = car_speed
	c.cruise_speed = car_speed
	c.set_id = "traffic/sedan_blue"
	c.lane_cooldown = 1000.0
	c.lane_timer = 1000.0
	tr.cars.append(c)
	_ours = c


## Keeps only the injected car on the road (the spawner keeps adding traffic far ahead).
func _only_ours() -> void:
	var tr := _traffic()
	for c in tr.cars.duplicate():
		if c != _ours:
			tr.cars.erase(c)


func _hud_messages() -> Array[String]:
	var out: Array[String] = []
	var hud: Object = _sc.get("hud")
	for m: Dictionary in hud.get("_messages"):
		out.append(str(m["text"]))
	return out


## Collects every HUD message once (they live at least 1.5 s, so polling every step sees them all).
func _collect_messages() -> void:
	var seen: Array = _d.get("messages", [])
	for m in _hud_messages():
		if not seen.has(m):
			seen.append(m)
	_d["messages"] = seen


# --- COLL-1: centre hits -------------------------------------------------------------------------

func _start_coll_right() -> void:
	_launch("dev_testetappe", 3.0, {})
	_d["lane"] = 2
	_d["expect"] = -1


func _start_coll_left() -> void:
	_launch("dev_testetappe", 3.0, {})
	_d["lane"] = 0
	_d["expect"] = 1


func _start_coll_middle() -> void:
	_launch("dev_testetappe", 3.0, {})
	_d["lane"] = 1
	_d["expect"] = -1


func _tick_coll_right() -> void:
	_tick_coll()


func _tick_coll_left() -> void:
	_tick_coll()


func _tick_coll_middle() -> void:
	_tick_coll()


func _tick_coll() -> void:
	if _ours == null:
		_place(int(_d["lane"]), 150.0, 30.0, 0.01, 60.0)
		return
	_only_ours()
	var v := _vehicle()
	if v.state == VehicleModel.State.CRASH:
		var dir := v.crash_dir
		var names := {-1: "links", 1: "rechts"}
		_done(dir == int(_d["expect"]), "Spur %d, Auffahrunfall genau von hinten -> geschoben nach %s (erwartet %s)" % [int(_d["lane"]), names.get(dir, "?"), names[int(_d["expect"])]])
	elif _t > 8.0:
		_done(false, "keine Kollision")


# --- COLL-3 / FUEL-1 / FUEL-3: empty tank --------------------------------------------------------

func _start_dry_rollout() -> void:
	_launch("dev_testetappe", 3.0, {})


func _tick_dry_rollout() -> void:
	if _ours == null:
		_place(2, 200.0, 45.0, 0.0, 90.0)
		_fuel().fuel_l = 0.0
		_d["max_overlap"] = 0.0
		return
	_only_ours()
	var v := _vehicle()
	var z: float = _sc.get("pos_z")
	var c: TrafficSystem.Car = _ours
	var overlap := (c.length + v.length_m) * 0.5 - absf(c.z - z)
	if absf(c.x - v.x) < (c.width + v.width_m) * 0.5 and not v.invulnerable:
		_d["max_overlap"] = maxf(float(_d["max_overlap"]), overlap)
	if _fuel().rolling_out:
		_d["rolled"] = true
	if v.state == VehicleModel.State.CRASH:
		_d["crashed"] = true
	if _fuel().state == FuelSystem.State.TOWING and not _d.has("tows_while_towing"):
		_d["tows_while_towing"] = int(_stats()["tows"])
	_collect_messages()
	if _d.has("tows_while_towing") and _fuel().state == FuelSystem.State.NORMAL:
		var ok: bool = bool(_d.get("crashed", false)) and float(_d["max_overlap"]) < 1.0 and int(_d["tows_while_towing"]) == 0 and int(_stats()["tows"]) == 1
		var msgs: Array = _d["messages"]
		ok = ok and msgs.has(tr("Tank leer! Der Abschleppdienst kommt …"))
		_done(ok, "Ausrollen mit leerem Tank: Kollision %s, tiefste Überlappung ohne Kollision %.2f m, Abschleppen gezählt %d -> %d" % [str(_d.get("crashed", false)), float(_d["max_overlap"]), int(_d["tows_while_towing"]), int(_stats()["tows"])])
	elif _t > 60.0:
		_done(false, "Zeitlimit (Zustand %d, Tempo %.0f)" % [_fuel().state, v.speed])


func _start_dry_into_lane() -> void:
	_launch("dev_testetappe", 76.6, {"autopilot": true, "autopilot_refuel": "always"})


func _tick_dry_into_lane() -> void:
	if not _d.has("set"):
		_d["set"] = true
		_vehicle().speed = 130.0
		_fuel().fuel_l = _fuel().tank_l * 0.002
		return
	_collect_messages()
	if _fuel().state == FuelSystem.State.REFUELING:
		_d["refueled"] = true
	if bool(_d.get("refueled", false)) and _fuel().state == FuelSystem.State.NORMAL:
		var msgs: Array = _d["messages"]
		var ok := int(_stats()["tows"]) == 0 and msgs.has(tr("Tank leer! Rechts in die Tankspur rollen lassen"))
		_done(ok, "leer in die Tankspur gerollt und getankt: Abschleppen %d, Meldung %s" % [int(_stats()["tows"]), str(msgs.filter(func(m: String) -> bool: return m.begins_with("Tank leer")))])
	elif _fuel().state == FuelSystem.State.TOWING:
		_done(false, "abgeschleppt statt getankt")
	elif _t > 60.0:
		_done(false, "Zeitlimit")


# --- COLL-3: finish roll-out ---------------------------------------------------------------------

func _start_finish_rollout() -> void:
	_launch("dev_testetappe", 129.6, {})


func _tick_finish_rollout() -> void:
	if _ours == null:
		# 33 m before the line at 145 km/h, a 30 km/h car 55 m ahead: they meet just after the finish
		_place(1, 145.0, 55.0, 0.0, 30.0)
		_d["max_overlap"] = 0.0
		return
	_only_ours()
	var v := _vehicle()
	var z: float = _sc.get("pos_z")
	var c: TrafficSystem.Car = _ours
	if bool(_sc.get("finished")):
		_d["finished"] = true
		if not _d.has("coll_at_finish"):
			_d["coll_at_finish"] = int(_stats()["collisions"])
		if v.state == VehicleModel.State.CRASH:
			_d["crashed"] = true
		var overlap := (c.length + v.length_m) * 0.5 - absf(c.z - z)
		if absf(c.x - v.x) < (c.width + v.width_m) * 0.5 and not v.invulnerable:
			_d["max_overlap"] = maxf(float(_d["max_overlap"]), overlap)
	if bool(_d.get("finished", false)) and (v.speed < 1.0 or _t > 12.0):
		var ok: bool = bool(_d.get("crashed", false)) and float(_d["max_overlap"]) < 1.0 and int(_stats()["collisions"]) == int(_d["coll_at_finish"])
		_done(ok, "nach dem Ziel: Kollision %s, tiefste Überlappung %.2f m, Kollisionen der Etappe %d (unverändert)" % [str(_d.get("crashed", false)), float(_d["max_overlap"]), int(_stats()["collisions"])])
	elif _t > 20.0:
		_done(false, "Zeitlimit")


# --- POL-1 (session side), FUEL-5, FUEL-7 -----------------------------------------------------------

func _start_refuel_chase() -> void:
	_launch("kiel_hamburg", 20.0, {"autopilot": true, "autopilot_speeding": true, "autopilot_refuel": "always"})


func _tick_refuel_chase() -> void:
	if not _d.has("set"):
		_d["set"] = true
		_fuel().fuel_l = _fuel().tank_l * 0.5
		# 200 km/h: too slow to escape (220), so the chase is still running when the car refuels
		(_sc.get("autopilot") as Object).set("target_kmh", 200.0)
		_d["bad_block"] = 0
		_d["bad_hud"] = 0
		return
	var f := _fuel()
	var p := _police()
	if p.blocked != (f.state != FuelSystem.State.NORMAL):
		_d["bad_block"] = int(_d["bad_block"]) + 1
	if f.state == FuelSystem.State.REFUELING:
		_d["refuel_seen"] = true
		if p.state != PoliceSystem.State.IDLE:
			_d["chase_during_refuel"] = true
		var hs: Dictionary = _sc.call("_hud_state", 12.0)
		var v := _vehicle()
		if absf(float(hs["next_station_km"])) > 0.0001 or absf(float(hs["range_km"]) - f.range_km(v.speed)) > 0.01:
			_d["bad_hud"] = int(_d["bad_hud"]) + 1
	if _vehicle().speed < 0.5 and not bool(_sc.get("finished")):
		_d["stand_s"] = float(_d.get("stand_s", 0.0)) + 1.0 / float(Engine.physics_ticks_per_second) * Engine.time_scale
	if bool(_d.get("refuel_seen", false)) and f.state == FuelSystem.State.NORMAL and p.state == PoliceSystem.State.IDLE and _vehicle().speed > 60.0:
		var ok := int(_d["bad_block"]) == 0 and int(_d["bad_hud"]) == 0 and bool(_d.get("chase_during_refuel", false))
		_done(ok, "Verfolgung beim Tanken: Polizei blockiert genau beim Tanken (Abweichungen %d), HUD beim Tanken (Abweichungen %d), Stillstand %.1f s" % [int(_d["bad_block"]), int(_d["bad_hud"]), float(_d.get("stand_s", 0.0))])
	elif _t > 120.0:
		_done(false, "Zeitlimit (Tankstatus %d, Polizei %d, Tanken gesehen %s, Verfolgung beim Tanken %s)" % [f.state, p.state, str(_d.get("refuel_seen", false)), str(_d.get("chase_during_refuel", false))])


# --- TUT-1 ---------------------------------------------------------------------------------------

func _start_tutorial() -> void:
	_launch("kiel_hamburg", 0.0, {"autopilot": true})


func _tick_tutorial() -> void:
	_collect_messages()
	if bool(_sc.get("finished")) or _t > 400.0:
		var tips: Array = (_d.get("messages", []) as Array).filter(func(m: String) -> bool: return m.begins_with("Tipp:"))
		var want := ["Lenken", "Gas mit", "Gamepad", "% im Tank", "Unten links", "angekündigt", "Kein Tempolimit", "Toleranz", "Tankspur und unter", "Gas geben bricht", "City Limits –"]
		var missing: Array[String] = []
		for w: String in want:
			if tips.filter(func(m: String) -> bool: return m.contains(w)).is_empty():
				missing.append(w)
		for m in tips:
			print("    ", m)
		_done(missing.is_empty() and bool(_sc.get("finished")), "Tutorial: %d Hinweise, fehlend %s" % [tips.size(), str(missing)])


func _start_no_tutorial() -> void:
	_launch("dev_testetappe", 0.0, {"autopilot": true})


func _tick_no_tutorial() -> void:
	_collect_messages()
	if _t > 40.0:
		var tips: Array = (_d.get("messages", []) as Array).filter(func(m: String) -> bool: return m.begins_with("Tipp:"))
		_done(tips.is_empty() and _sc.get("coach") == null, "andere Etappe ohne Tutorial-Hinweise (%d)" % tips.size())
