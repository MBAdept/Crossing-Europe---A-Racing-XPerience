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
##                   current speed and next station 0 at the pumps (POL-1, FUEL-5, FUEL-7; dev stage since v0.7.0)
##   carry_tow       race (v0.7.0): a tank carried over that does not reach the first fuel lane even at 60 km/h ->
##                   the tow service before the start (+tow penalty, half a tank, one tow), said in the countdown
##   carry_eco       race (v0.7.0): a carried tank that reaches the first lane only gently -> the countdown names the
##                   top speed, the autopilot drives the economy pace and refuels there, no tow
##   tutorial        Kiel – Hamburg shows the tutorial hints, the dev stage none (TUT-1); since QA v0.7.0 as the first
##                   stage of a race: the low tank is the first hint, the note on the last station comes after it
##   rail_feedback   an understeer slide into the guardrail: speed loss, camera shake and flash (review: the hit
##                   showed only on the speedometer)
##   preload         the last 25 km into Frankfurt (City Limits, buildings, landmarks, skyline, traffic): every sprite
##                   sheet was loaded before the start, none while driving (QA v0.5.1: 13–35 ms hitches). Arcade
##                   (setup.gfx): Modern loads no sprite sheets but the HUD icons.
##   gfx_independent v0.8.0: the last 22 km of the test stage with each renderer class (Modern, then Arcade): the same
##                   result (except "gfx") and the same hash of the player's and every traffic car's state at every
##                   second of the stage – the simulation does not depend on the graphics mode (Rule 3)
##   gfx_fallback    v0.8.0: a Modern renderer that reports healthy() == false (--gfx-debug=fail): the stage runs with
##                   the Arcade renderer and its sprites, the HUD says so, the window is 16:9 again, the result
##                   carries gfx = "arcade" and gfx_fallback, no crash-guard marker is left behind
## The scenarios without their own setup.gfx run in the mode of the command line (-- --graphics=arcade|modern).
## Prints "CHECK <name> OK …" or "CHECK <name> FEHLER …" per scenario; exit code 0 when all pass.
## The scene is accessed untyped (this script compiles before the autoloads the scene uses).

const SCENARIOS := ["coll_right", "coll_left", "coll_middle", "dry_rollout", "dry_into_lane", "finish_rollout", "refuel_chase", "carry_tow", "carry_eco", "tutorial", "no_tutorial", "rail_feedback", "preload", "gfx_independent", "gfx_fallback"]

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
	if _sc == null and not _d.has("relaunch"):   # "relaunch": a scenario is between two scenes of its own
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
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP   # a Modern stage leaves "expand" (GameFlow resets it)


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
	# v0.7.0: on the dev stage (radar zone km 12–17, station at km 20). It ran on Kiel – Hamburg from km 20 (radar at
	# 28, station at 45.9); since the first station of every direction lies 5–20 km after the start, Kiel – Hamburg
	# has its only forward station at km 15 – none ahead of km 20.
	_launch("dev_testetappe", 3.0, {"autopilot": true, "autopilot_speeding": true, "autopilot_refuel": "always"})


func _tick_refuel_chase() -> void:
	if not _d.has("set"):
		_d["set"] = true
		_fuel().fuel_l = _fuel().tank_l * 0.5
		# 180 km/h: too slow to escape – also where the police has to slow down for curves (the escape threshold
		# follows the police: 220 on a straight, less in curves) –, and the police starts police.max_gap_m behind
		# (set below), so the chase is still running when the car reaches the fuel lane a few km after the radar.
		# No traffic: a slower car ahead would let the police catch up before the fuel lane.
		(_sc.get("autopilot") as Object).set("target_kmh", 180.0)
		_sc.set("traffic_enabled", false)
		((_sc.get("traffic") as Object).get("cars") as Array).clear()
		_d["bad_block"] = 0
		_d["bad_hud"] = 0
		return
	var f := _fuel()
	var p := _police()
	if p.state == PoliceSystem.State.CHASE and not _d.has("gap_set"):
		_d["gap_set"] = true
		p.gap_m = float(ConfigLoader.lookup(ConfigLoader.load_merged(), "police.max_gap_m", 600.0))
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
		# the police stop (10 s) is served after the refuel (~17 s for 30 L), not during it
		var ok := int(_d["bad_block"]) == 0 and int(_d["bad_hud"]) == 0 and bool(_d.get("chase_during_refuel", false)) \
			and float(_d.get("stand_s", 0.0)) >= 24.0
		_done(ok, "Verfolgung beim Tanken: Polizei blockiert genau beim Tanken (Abweichungen %d), HUD beim Tanken (Abweichungen %d), Stillstand %.1f s (Tanken + Polizei-Stopp)" % [int(_d["bad_block"]), int(_d["bad_hud"]), float(_d.get("stand_s", 0.0))])
	elif _t > 120.0:
		_done(false, "Zeitlimit (Tankstatus %d, Polizei %d, Tanken gesehen %s, Verfolgung beim Tanken %s)" % [f.state, p.state, str(_d.get("refuel_seen", false)), str(_d.get("chase_during_refuel", false))])


# --- v0.7.0: the tank carried over in a race ---------------------------------------------------------------

## Race stage Hamburg – Hannover (first station 12 km) in the Gran Turismo with a carried tank of `litres`.
func _launch_carry(litres: float) -> void:
	_launch("hamburg_hannover", 0.0, {"mode": "race", "race_id": "kiel_nuernberg", "from_city": "hamburg",
		"vehicle": "gran_turismo", "start_fuel_l": litres, "autopilot": true, "autopilot_target": 300.0})


func _start_carry_tow() -> void:
	_launch_carry(1.9)


func _tick_carry_tow() -> void:
	_collect_messages()
	var cfg := ConfigLoader.load_merged()
	var pen := float(ConfigLoader.lookup(cfg, "fuel.tow_penalty_s", 90.0))
	var f := _fuel()
	var msgs: Array = _d["messages"]
	var told := not msgs.filter(func(m: String) -> bool: return m.contains("Abschleppdienst vor dem Start")).is_empty()
	var ok := bool(_sc.get("start_towed")) and absf(float(_sc.get("penalty_time")) - pen) < 0.001 and int(_stats()["tows"]) == 1 \
		and f.fuel_l >= f.tank_l * float(ConfigLoader.lookup(cfg, "fuel.tow_refill_fraction", 0.5)) - 0.5 and told
	var res: Dictionary = _sc.call("build_result")
	ok = ok and absf(float(res["fuel_start_l"]) - 1.9) < 0.001 and bool(res["start_towed"])
	_done(ok, "1,9 L im Gran Turismo: vor dem Start abgeschleppt %s, Strafe %.0f s, Abschleppen %d, Tank %.1f L, Meldung %s" % [
		str(_sc.get("start_towed")), float(_sc.get("penalty_time")), int(_stats()["tows"]), f.fuel_l, str(told)])


func _start_carry_eco() -> void:
	_launch_carry(3.0)


func _tick_carry_eco() -> void:
	_collect_messages()
	var f := _fuel()
	var km := float(_sc.get("pos_km"))
	var first := float((_sc.get("plan") as StagePlan).fuel_stations_km[0])
	if km < first - 2.0:
		_d["max_v"] = maxf(float(_d.get("max_v", 0.0)), _vehicle().speed)
	if f.state == FuelSystem.State.REFUELING:
		_d["refuel_km"] = km
	if _d.has("refuel_km") and f.state == FuelSystem.State.NORMAL:
		var msgs: Array = _d["messages"]
		var told := not msgs.filter(func(m: String) -> bool: return m.contains("höchstens")).is_empty()
		var check: Dictionary = _sc.get("start_check")
		var ok := not bool(_sc.get("start_towed")) and int(_stats()["tows"]) == 0 and told and str(check.get("state", "")) == "tight" \
			and float(_d["refuel_km"]) <= first + 0.001 and float(_d.get("max_v", 999.0)) <= float(check.get("max_kmh", 0.0)) + 1.0
		_done(ok, "3 L im Gran Turismo: Sparfahrt bis %.0f km/h (Ansage höchstens %.0f km/h), getankt bei km %.2f (Tankstelle %.1f), Abschleppen %d, Meldung %s" % [
			float(_d.get("max_v", 0.0)), float(check.get("max_kmh", 0.0)), float(_d["refuel_km"]), first, int(_stats()["tows"]), str(told)])
	elif f.state == FuelSystem.State.TOWING or int(_stats()["tows"]) > 0:
		_done(false, "abgeschleppt statt Sparfahrt")
	elif _t > 120.0:
		_done(false, "Zeitlimit (km %.1f, Tank %.2f L)" % [km, f.fuel_l])


# --- guardrail hit feedback ------------------------------------------------------------------------

func _start_rail_feedback() -> void:
	_launch("dev_testetappe", 3.0, {})


func _tick_rail_feedback() -> void:
	var v := _vehicle()
	if not _d.has("set"):
		_d["set"] = true
		_sc.set("traffic_enabled", false)
		((_sc.get("traffic") as Object).get("cars") as Array).clear()
		# 200 km/h, right next to the guardrail on the left, sliding outwards with 6 m/s (understeer drift)
		var e := _track().road_edges_at(float(_sc.get("pos_z")))
		v.speed = 200.0
		v.x = e.x - _track().shoulder_w + v.width_m * 0.5 + 0.05
		v.push_speed = -6.0
		return
	var stats: Dictionary = _sc.get("drive_stats")
	if int(stats["rail_hits"]) >= 1:
		var shake := float(_sc.get("_shake_t"))
		var flash: Color = (_sc.get("hud") as Object).get("_flash")
		var ok := v.speed < 200.0 * 0.8 and shake > 0.3 and is_equal_approx(flash.g, 0.55) and flash.a > 0.2
		_done(ok, "Leitplanke mit Abdrift %.1f m/s: Tempo 200 -> %.0f km/h, Wackeln %.2f s, Aufblitzen %s" % [v.rail_impact, v.speed, shake, str(flash)])
	elif _t > 3.0:
		_done(false, "keine Leitplanke erreicht (x %.2f)" % v.x)


# --- TUT-1 ---------------------------------------------------------------------------------------

## Kiel – Hamburg as the first stage of a race (the tank carries on into Hamburg – Hannover).
func _start_tutorial() -> void:
	_launch("kiel_hamburg", 0.0, {"autopilot": true, "mode": "race", "race_id": "kiel_nuernberg", "from_city": "kiel"})


func _tick_tutorial() -> void:
	_collect_messages()
	if bool(_sc.get("finished")) or _t > 400.0:
		var msgs: Array = _d.get("messages", [])
		var tips: Array = msgs.filter(func(m: String) -> bool: return m.begins_with("Tipp:"))
		var want := ["Lenken", "Gas mit", "Gamepad", "% im Tank", "Unten links", "angekündigt", "Kein Tempolimit", "Toleranz", "Tankspur und unter", "Gas geben bricht", "City Limits –"]
		var missing: Array[String] = []
		for w: String in want:
			if tips.filter(func(m: String) -> bool: return m.contains(w)).is_empty():
				missing.append(w)
		for m in tips:
			print("    ", m)
		# QA v0.7.0: the low tank is the first hint (urgent hints keep their order, none comes with "LOS!"), and in a race
		# the note on the last station comes behind it – not with the 5-km announcement and the coach's fuel-lane hint
		var first_ok := not tips.is_empty() and str(tips[0]).contains("% im Tank")
		var early := msgs.has("Letzte Tankstelle vor dem Ziel – der Tank geht in die nächste Etappe mit")
		var late := not msgs.filter(func(m: String) -> bool: return m.begins_with("Das war die letzte Tankstelle")).is_empty()
		_done(missing.is_empty() and bool(_sc.get("finished")) and first_ok and late and not early,
			"Tutorial: %d Hinweise, fehlend %s, zuerst der Tank %s, letzte Tankstelle danach %s (nicht an der Ansage %s)" % [
			tips.size(), str(missing), str(first_ok), str(late), str(not early)])


func _start_no_tutorial() -> void:
	_launch("dev_testetappe", 0.0, {"autopilot": true})


func _tick_no_tutorial() -> void:
	_collect_messages()
	if _t > 40.0:
		var tips: Array = (_d.get("messages", []) as Array).filter(func(m: String) -> bool: return m.begins_with("Tipp:"))
		_done(tips.is_empty() and _sc.get("coach") == null, "andere Etappe ohne Tutorial-Hinweise (%d)" % tips.size())


# --- QA v0.5.1: sprite sheets loaded before the start ---------------------------------------------------------

func _start_preload() -> void:
	_launch("dortmund_frankfurt", 200.0, {"autopilot": true, "from_city": "dortmund", "start_speed_kmh": 150.0, "gfx": "arcade"})
	var db := root.get_node("SpriteDB")
	_d["loads0"] = int(db.get("loads"))
	_d["pre"] = (_sc.get("preloaded_sets") as Array).size()


func _tick_preload() -> void:
	if bool(_sc.get("finished")) or _t > 300.0:
		var db := root.get_node("SpriteDB")
		var n := int(db.get("loads")) - int(_d["loads0"])
		var log: Array = db.get("load_log")
		var late: Array = log.slice(maxi(0, log.size() - n)) if n > 0 else []
		_done(n == 0 and bool(_sc.get("finished")), "Dortmund – Frankfurt ab km 200: %d Blätter vorab, %d während der Fahrt nachgeladen %s" % [
			int(_d["pre"]), n, str(late)])


# --- v0.8.0: graphics modes -------------------------------------------------------------------------------------

## Script file of the scene's renderer ("road_renderer.gd" = Arcade, "modern_renderer.gd" = Modern).
func _renderer_file() -> String:
	var r: Variant = _sc.get("renderer")
	if r == null or not (r is Object) or (r as Object).get_script() == null:
		return ""
	return str(((r as Object).get_script() as Script).resource_path).get_file()


## Hash of the simulation state: the player's car and every traffic car (exact bits of the numbers).
func _sim_hash() -> int:
	var v := _vehicle()
	var a := PackedFloat64Array([float(_sc.get("pos_z")), v.x, v.speed, _fuel().fuel_l, float(_sc.get("stage_time")),
		float(_sc.get("penalty_time")), float(v.state)])
	for c in _traffic().cars:
		a.append_array(PackedFloat64Array([float(c.id), c.z, c.x, c.speed, float(c.lane), 1.0 if c.braking else 0.0]))
	return hash(a.to_byte_array())


func _launch_gfx(mode: String) -> void:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_launch("dev_testetappe", 108.0, {"autopilot": true, "gfx": mode, "seed": 5, "traffic_warmup": true, "start_speed_kmh": 120.0})
	_d["mode"] = mode
	_d["sec"] = -1
	_d["hashes_" + mode] = []
	_d["cars_" + mode] = 0


func _start_gfx_independent() -> void:
	_launch_gfx("modern")


func _tick_gfx_independent() -> void:
	if _d.has("relaunch"):
		# the first scene was freed at the end of the last step
		var next := str(_d["relaunch"])
		_d.erase("relaunch")
		_launch_gfx(next)
		return
	var mode := str(_d["mode"])
	if not _d.has("class_" + mode):
		_d["class_" + mode] = _renderer_file()
		_d["scene_gfx_" + mode] = str(_sc.get("gfx"))
		_d["aspect_" + mode] = int(root.content_scale_aspect)
	var sec := int(floor(float(_sc.get("stage_time"))))
	if bool(_sc.get("running")) and not bool(_sc.get("finished")) and sec != int(_d["sec"]):
		_d["sec"] = sec
		(_d["hashes_" + mode] as Array).append(_sim_hash())
		_d["cars_" + mode] = maxi(int(_d["cars_" + mode]), _traffic().cars.size())
	if not bool(_sc.get("finished")) and _t < 400.0:
		return
	_d["res_" + mode] = _sc.call("build_result")
	_d["finished_" + mode] = bool(_sc.get("finished"))
	if mode == "modern":
		_sc.queue_free()   # gone at the end of this step; the Arcade scene starts in the next one
		_sc = null
		_d["relaunch"] = "arcade"
		_t = 0.0
		return
	var a: Dictionary = (_d["res_arcade"] as Dictionary).duplicate()
	var m: Dictionary = (_d["res_modern"] as Dictionary).duplicate()
	var gfx_ok := str(a.get("gfx", "")) == "arcade" and str(m.get("gfx", "")) == "modern" and not m.has("gfx_fallback")
	a.erase("gfx")
	m.erase("gfx")
	var ha: Array = _d["hashes_arcade"]
	var hm: Array = _d["hashes_modern"]
	var first_diff := -1
	for i in mini(ha.size(), hm.size()):
		if ha[i] != hm[i]:
			first_diff = i
			break
	var ok := bool(_d["finished_arcade"]) and bool(_d["finished_modern"]) and gfx_ok and a == m and JSON.stringify(a) == JSON.stringify(m) \
		and ha.size() == hm.size() and ha.size() >= 30 and first_diff < 0 and int(_d["cars_arcade"]) >= 3 \
		and str(_d["class_modern"]) == "modern_renderer.gd" and str(_d["class_arcade"]) == "road_renderer.gd" \
		and str(_d["scene_gfx_modern"]) == "modern" and int(_d["aspect_modern"]) == Window.CONTENT_SCALE_ASPECT_EXPAND \
		and int(_d["aspect_arcade"]) == Window.CONTENT_SCALE_ASPECT_KEEP
	_done(ok, "Teststadt – Testdorp ab km 108 mit %s und %s: Ergebnis gleich %s (Zeit %.3f / %.3f s), Verkehrs-Hash in %d / %d Sekunden gleich%s, bis zu %d Autos, Seitenverhältnis Modern %s" % [
		str(_d["class_modern"]), str(_d["class_arcade"]), str(a == m), float(m.get("time_s", -1.0)), float(a.get("time_s", -2.0)),
		hm.size(), ha.size(), "" if first_diff < 0 else " – erste Abweichung in Sekunde %d" % first_diff, int(_d["cars_arcade"]),
		"füllt das Fenster" if int(_d["aspect_modern"]) == Window.CONTENT_SCALE_ASPECT_EXPAND else "FALSCH"])


func _start_gfx_fallback() -> void:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var settings := root.get_node("Settings")
	_d["marker"] = str(settings.get("marker_path"))
	_d["guard_before"] = bool(settings.get("crash_guard"))
	settings.set("crash_guard", false)
	CliArgs.all()["gfx-debug"] = "fail"   # the Modern renderer reports healthy() == false
	_launch("dev_testetappe", 3.0, {"autopilot": true, "gfx": "modern", "no_countdown": false})
	CliArgs.all().erase("gfx-debug")
	# right after the build: Modern is preparing, its marker is written
	_d["class_start"] = _renderer_file()
	_d["marker_start"] = FileAccess.file_exists(str(_d["marker"]))
	_d["steps_start"] = int(_sc.get("_sim_steps"))


func _tick_gfx_fallback() -> void:
	_collect_messages()
	if float(_sc.get("stage_time")) < 2.0 and _t < 30.0:
		return   # until 2 s after the countdown (it only starts once the fallback is done)
	var res: Dictionary = _sc.call("build_result")
	var msgs: Array = _d.get("messages", [])
	var told := msgs.has("Der Modus „Modern“ lässt sich mit dieser Grafik nicht starten. Das Spiel läuft im Modus „Arcade“ weiter.")
	var pre: Array = _sc.get("preloaded_sets")
	var settings := root.get_node("Settings")
	var ok := str(_d["class_start"]) == "modern_renderer.gd" and bool(_d["marker_start"]) and int(_d["steps_start"]) == 0 \
		and _renderer_file() == "road_renderer.gd" and str(_sc.get("gfx")) == "arcade" \
		and str(_sc.get("gfx_fallback")) == "selftest:debug" and told and bool(_sc.get("running")) \
		and str(res.get("gfx", "")) == "arcade" and str(res.get("gfx_fallback", "")) == "selftest:debug" \
		and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP and pre.has("player/limousine") and pre.size() > 20 \
		and not FileAccess.file_exists(str(_d["marker"])) and _vehicle().speed > 5.0
	settings.set("crash_guard", bool(_d["guard_before"]))
	_done(ok, "erzwungener Fehler: erst %s (Marker %s), dann %s, gfx %s, gfx_fallback '%s', Meldung %s, %d Sprite-Sets geladen, Fenster 16:9 %s, Marker danach %s, Etappe läuft (%.0f km/h)" % [
		str(_d["class_start"]), "geschrieben" if bool(_d["marker_start"]) else "FEHLT", _renderer_file(), str(res.get("gfx", "")),
		str(res.get("gfx_fallback", "")), str(told), pre.size(), str(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP),
		"entfernt" if not FileAccess.file_exists(str(_d["marker"])) else "NOCH DA", _vehicle().speed])
