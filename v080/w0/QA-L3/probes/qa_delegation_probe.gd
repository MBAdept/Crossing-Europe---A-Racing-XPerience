extends SceneTree
## QA lens 3: contract §4.7.1 checked call by call. With the Modern profile every existing AudioManager call must
## reach ModernAudio and leave the Arcade state untouched; the new calls do nothing with the Arcade profile; the
## three volume settings act on Master, MSfx and MMusic only.
##   godot [--headless] --path . --fixed-fps 60 -s <this> -- --graphics=arcade
## Prints "DELEG <name> OK|FEHLER …"; exit code 0 when all pass.

var _am: Node
var _failed: Array[String] = []
const ARCADE_VARS: Array[String] = ["_engine_speed", "_engine_throttle", "_engine_vmax", "_engine_active", "_engine_t",
	"_wind_speed", "_siren_on", "_siren_dist", "_rain_explicit", "_rain_explicit_t", "_skid_explicit", "_skid_explicit_t",
	"_hint_t", "_hint_rain", "_hint_skid", "_hint_siren", "_hint_chase", "_vehicle_id", "_stopped_frame", "_traffic_t",
	"_tunnel", "_music_wanted", "_next_oneshot", "_eng_start_pending", "_gear", "_throttle_s", "_pitch_s", "_shift_dip"]


func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _check(name: String, ok: bool, msg: String) -> void:
	print("DELEG %-22s %s  %s" % [name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(name)


func _arcade() -> Dictionary:
	var d := {}
	for k in ARCADE_VARS:
		d[k] = _am.get(k)
	d["_last_play"] = (_am.get("_last_play") as Dictionary).duplicate()
	d["_traffic_vehicles"] = (_am.get("_traffic_vehicles") as Array).size()
	d["_eng"] = _am.get("_eng")
	d["_preview"] = _am.get("_preview")
	d["_vol"] = (_am.get("_vol") as Dictionary).duplicate()
	var playing := 0
	for c in _am.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).playing:
			playing += 1
	d["playing"] = playing
	var t: Variant = _am.get("_traffic")
	if t != null:
		d["traffic_listener_z"] = (t as Object).get("listener_z")
		d["traffic_siren_on"] = (t as Object).get("_siren_on")
	var r: Variant = _am.get("_room")
	if r != null:
		d["room_blend"] = (r as Object).get("blend")
	return d


func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k: String in a:
		var same: bool = is_same(a[k], b[k]) if (a[k] is Object or b[k] is Object) else a[k] == b[k]
		if not same:
			out.append("%s: %s -> %s" % [k, str(a[k]), str(b[k])])
	return out


func _buses() -> Dictionary:
	var d := {}
	for i in AudioServer.bus_count:
		d[AudioServer.get_bus_name(i)] = [snappedf(AudioServer.get_bus_volume_db(i), 0.001), AudioServer.is_bus_mute(i)]
	return d


func _run() -> void:
	for i in 4:
		await process_frame
	_am = root.get_node("AudioManager")
	var st: Node = root.get_node("Settings")
	var headless := DisplayServer.get_name() == "headless"
	# 0. signatures of the additions
	var want := {"set_profile": 1, "profile": 0, "set_race_music": 1, "set_music_context": 2, "set_track": 2,
		"set_vehicle_state": 1, "event": 2}
	var sig_ok := true
	var sig: Array = []
	for m: Dictionary in _am.get_method_list():
		if want.has(m["name"]):
			var n := (m["args"] as Array).size()
			var defaults := (m["default_args"] as Array).size()
			sig.append("%s/%d(%d default)" % [m["name"], n, defaults])
			if n != int(want[m["name"]]):
				sig_ok = false
			want.erase(m["name"])
	_check("signaturen", sig_ok and want.is_empty(), "%s%s" % [", ".join(sig), "" if want.is_empty() else " – FEHLT: " + str(want.keys())])
	# 1. unknown ids count as arcade; idempotent
	_am.call("set_profile", "irgendwas")
	var p1 := str(_am.call("profile"))
	_am.call("set_profile", "modern")
	var m1: Variant = _am.get("_modern")
	_am.call("set_profile", "modern")
	var m2: Variant = _am.get("_modern")
	_check("profil_id", p1 == "arcade" and str(_am.call("profile")) == "modern" and is_same(m1, m2) and m1 != null,
		"unbekannte Kennung -> %s; zweimal modern: derselbe Knoten %s" % [p1, str(is_same(m1, m2))])
	var mo: Object = m1
	await process_frame
	# 2. every existing call: reaches ModernAudio, Arcade untouched
	var calls: Array = [
		["set_engine", [123.0, 0.7, 222.0, true], func() -> bool: return is_equal_approx(mo.get("_engine_speed"), 123.0) and is_equal_approx(mo.get("_engine_throttle"), 0.7) and is_equal_approx(mo.get("_engine_vmax"), 222.0) and mo.get("_engine_active") == true],
		["set_wind", [77.0], func() -> bool: return is_equal_approx(mo.get("_wind_speed"), 77.0)],
		["set_siren", [true, 0.42], func() -> bool: return mo.get("_siren_on") == true and is_equal_approx(mo.get("_siren_dist"), 0.42)],
		["set_rain", [0.33], func() -> bool: return is_equal_approx(mo.get("_rain_explicit"), 0.33)],
		["set_skid", [0.44], func() -> bool: return is_equal_approx(mo.get("_skid_explicit"), 0.44)],
		["play", ["ui_ok"], func() -> bool: return (mo.get("_last_play") as Dictionary).has("ui_ok")],
		["play", ["crash", -2.0], func() -> bool: return (mo.get("_last_play") as Dictionary).has("crash")],
		["set_traffic", [[{"id": 5, "set": "traffic/sedan_blue", "z": 20.0, "x": 1.9, "length": 4.7, "speed": 100.0}], {"z": 1.0, "x": 0.5, "speed": 90.0}], func() -> bool: return (mo.get("_vehicles") as Array).size() == 1 and float((mo.get("_listener") as Dictionary).get("x", 0.0)) == 0.5],
		["set_environment", [{"tunnel": true}], func() -> bool: return mo.get("_tunnel") == true],
		["hud_hints", [{"weather": "rain", "understeer": 0.5, "police_state": "chase", "police_gap_m": 60.0}], func() -> bool: return is_equal_approx(mo.get("_hint_rain"), 1.0) and mo.get("_hint_chase") == true],
		["set_vehicle", ["kombi"], func() -> bool: return str((mo.get("engine") as Object).get("vehicle_id")) == "kombi"],
		["preview_engine", ["kompakt"], func() -> bool: return headless or (mo.get("engine") as Object).get("_preview") != null],
		["set_music", [true], func() -> bool: return bool((mo.get("music") as Object).call("wanted"))],
		["stop_all", [], func() -> bool: return int(mo.get("_stopped_frame")) == Engine.get_process_frames()],
	]
	for c: Array in calls:
		var before := _arcade()
		_am.callv(c[0], c[1])
		var reached: bool = (c[2] as Callable).call()
		var changed := _diff(before, _arcade())
		_check("ruf_" + str(c[0]), reached and changed.is_empty(), "%s%s kommt bei ModernAudio an: %s; Arcade-Zustand unverändert: %s%s" % [
			c[0], str(c[1]).left(40), str(reached), str(changed.is_empty()), "" if changed.is_empty() else " " + str(changed)])
		await process_frame
	# read-back calls answer from ModernAudio
	_am.call("set_vehicle", "limousine")
	for i in 30:
		_am.call("set_engine", 150.0, 1.0, 245.0, true)
		await process_frame
	var es: Dictionary = _am.call("engine_state")
	var arcade_es: Dictionary = {"rpm": 0.0}
	var ae: Variant = _am.get("_eng")
	if ae != null:
		arcade_es = (ae as Object).call("state")
	var back_ok := float(es.get("rpm", 0.0)) > 900.0 and (_am.call("engine_perf") as Dictionary).has("skips") \
		and (_am.call("traffic_perf") as Dictionary).has("avg_ms") and (_am.call("traffic_state") as Dictionary).has("tunnel_blend")
	_check("ruf_abfragen", back_ok and _am.get("_eng") == null, "engine_state %.0f/min aus ModernAudio (Arcade-Motor: %s), engine_perf, traffic_perf, traffic_state" % [
		float(es.get("rpm", 0.0)), "keiner" if _am.get("_eng") == null else str(arcade_es)])
	# 3. the new calls with the Modern profile
	var tr := RefCounted.new()
	_am.call("set_race_music", false)
	_am.call("set_music_context", "race", {"stage": "x"})
	_am.call("set_track", tr, null)
	_am.call("set_vehicle_state", {"z": 100.0, "x": 0.0, "speed": 120.0})
	_am.call("event", "collision", {"speed_kmh": 100.0, "heavy": false, "side": 0})
	var new_ok: bool = str(mo.get("_music_context")) == "race" and not (mo.get("_state") as Dictionary).is_empty() \
		and int((mo.get("events_seen") as Dictionary).get("collision", 0)) == 1 and (mo.get("feed") as Object).get("track") == tr
	_check("neu_modern", new_ok, "set_race_music, set_music_context (%s), set_track, set_vehicle_state, event (%s) erreichen ModernAudio" % [
		str(mo.get("_music_context")), str(mo.get("events_seen"))])
	_am.call("set_track", null, null)
	_am.call("set_music_context", "menu", {})
	_am.call("set_race_music", true)
	# 4. volumes: Master, MSfx, MMusic
	var m0 := float(st.get("master_volume"))
	var s0 := float(st.get("sfx_volume"))
	var u0 := float(st.get("music_volume"))
	st.set("master_volume", 1.0)
	st.set("sfx_volume", 1.0)
	st.set("music_volume", 1.0)
	_am.call("apply_volumes")
	var full := _buses()
	st.set("sfx_volume", 0.5)
	_am.call("apply_volumes")
	var half_sfx := _buses()
	st.set("sfx_volume", 1.0)
	st.set("music_volume", 0.25)
	_am.call("apply_volumes")
	var quarter_music := _buses()
	st.set("music_volume", 1.0)
	st.set("master_volume", 0.5)
	_am.call("apply_volumes")
	var half_master := _buses()
	st.set("master_volume", 1.0)
	st.set("sfx_volume", 0.0)
	st.set("music_volume", 0.0)
	_am.call("apply_volumes")
	var zero := _buses()
	var problems: Array = []
	var changed_sfx: Array = []
	var changed_music: Array = []
	var changed_master: Array = []
	for b: String in full:
		if full[b] != half_sfx[b]:
			changed_sfx.append(b)
		if full[b] != quarter_music[b]:
			changed_music.append(b)
		if full[b] != half_master[b]:
			changed_master.append(b)
	if changed_sfx != ["SFX", "MSfx"]:
		problems.append("Effekte 0,5 ändert %s" % str(changed_sfx))
	if changed_music != ["Music", "MMusic"]:
		problems.append("Musik 0,25 ändert %s" % str(changed_music))
	if changed_master != ["Master"]:
		problems.append("Gesamt 0,5 ändert %s" % str(changed_master))
	var d_sfx := float(half_sfx["MSfx"][0]) - float(full["MSfx"][0])
	var d_music := float(quarter_music["MMusic"][0]) - float(full["MMusic"][0])
	var d_master := float(half_master["Master"][0]) - float(full["Master"][0])
	if absf(d_sfx - linear_to_db(0.5)) > 0.01:
		problems.append("MSfx um %.2f dB statt %.2f" % [d_sfx, linear_to_db(0.5)])
	if absf(d_music - linear_to_db(0.25)) > 0.01:
		problems.append("MMusic um %.2f dB statt %.2f" % [d_music, linear_to_db(0.25)])
	if absf(d_master - linear_to_db(0.5)) > 0.01:
		problems.append("Master um %.2f dB statt %.2f" % [d_master, linear_to_db(0.5)])
	if not bool(zero["MSfx"][1]) or not bool(zero["MMusic"][1]):
		problems.append("bei 0 nicht stumm: MSfx %s, MMusic %s" % [str(zero["MSfx"]), str(zero["MMusic"])])
	_check("lautstaerke", problems.is_empty(), "Effekte 0,5: %s um %.2f dB; Musik 0,25: %s um %.2f dB; Gesamt 0,5: %s um %.2f dB; bei 0 stumm: MSfx %s, MMusic %s%s" % [
		str(changed_sfx), d_sfx, str(changed_music), d_music, str(changed_master), d_master, str(zero["MSfx"][1]), str(zero["MMusic"][1]),
		"" if problems.is_empty() else " – " + "; ".join(problems)])
	st.set("master_volume", m0)
	st.set("sfx_volume", s0)
	st.set("music_volume", u0)
	_am.call("apply_volumes")
	# 5. back to Arcade: the new calls do nothing there
	_am.call("stop_all")
	_am.call("set_music", false)
	_am.call("set_profile", "arcade")
	await process_frame
	await process_frame
	var before2 := _arcade()
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var buses := AudioServer.bus_count
	_am.call("set_race_music", false)
	_am.call("set_music_context", "race", {})
	_am.call("set_track", tr, null)
	_am.call("set_vehicle_state", {"z": 1.0, "x": 0.0, "speed": 50.0})
	for e: String in ["stage_start", "countdown", "go", "collision", "rail_hit", "radar_flash", "chase_start", "escaped", "busted",
			"refuel_start", "refuel_done", "out_of_fuel", "tow", "stage_finish"]:
		_am.call("event", e, {})
	_am.call("set_track", null, null)
	var ch := _diff(before2, _arcade())
	_check("neu_arcade", ch.is_empty() and _am.get("_modern") == null and AudioServer.bus_count == buses
		and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes,
		"die fünf neuen Aufrufe und 14 Ereignisse mit Arcade: Zustand unverändert %s, Knoten %d, Busse %d" % [str(ch.is_empty()) if ch.is_empty() else str(ch), nodes, buses])
	_am.call("set_race_music", true)
	print("DELEG-ERGEBNIS %s (%d fehlgeschlagen, %s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), DisplayServer.get_name()])
	quit(0 if _failed.is_empty() else 1)
