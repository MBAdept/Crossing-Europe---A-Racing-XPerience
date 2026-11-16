#!/usr/bin/env python3
# Builds gd/qa_tyre_wind.gd from gd/qa_capture_mix.gd: two extra scenarios "wind" and "skid".
S = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM'
src = open(S + '/gd/qa_capture_mix.gd').read()
old = '''		"race_music":
			_am.call("set_music_context", "race", {})
			await _drive(vehicle)'''
assert old in src
src = src.replace(old, old + '''
		"wind":
			await _wind(vehicle)
		"skid":
			await _skid(vehicle)
		"ui":
			await _ui()''')
src += '''

## QA-M2-SYSTEM: wind alone (engine and road muted by --mute-bus): 2 s standstill, then steps held 4 s each.
func _wind(vehicle: String) -> void:
	var cfg := ConfigLoader.load_merged()
	var spec := VehicleModel.resolve_spec(cfg, vehicle)
	var vmax := float(spec.get("vmax_kmh", 245.0))
	_am.call("set_vehicle", vehicle)
	var t0 := _now()
	while _now() - t0 < 2.0:
		_send(0.0, 0.0, vmax)
		await process_frame
	_phase("v0", t0 + 0.5, _now())
	for v in [50.0, 100.0, 150.0, 200.0, 240.0]:
		t0 = _now()
		while _now() - t0 < 4.0:
			_send(v, 0.6, vmax)
			await process_frame
		_phase("v%d" % int(v), t0 + 1.5, _now())


## QA-M2-SYSTEM: tyres (engine and wind muted): 120 km/h; skid 0 (rolling) 3 s, ramp to 1 in 1 s, hold 3 s, back to 0
## for 3 s, skid 0.4 for 3 s, rolling 2 s.
func _skid(vehicle: String) -> void:
	var cfg := ConfigLoader.load_merged()
	var spec := VehicleModel.resolve_spec(cfg, vehicle)
	var vmax := float(spec.get("vmax_kmh", 245.0))
	_am.call("set_vehicle", vehicle)
	var v := 120.0
	var plan := [["roll", 3.0, 0.0, 0.0], ["ramp", 1.0, 0.0, 1.0], ["skid_full", 3.0, 1.0, 1.0], ["release", 3.0, 0.0, 0.0],
		["skid_04", 3.0, 0.4, 0.4], ["roll_end", 2.0, 0.0, 0.0]]
	for p in plan:
		var t0 := _now()
		while _now() - t0 < float(p[1]):
			var f := clampf((_now() - t0) / float(p[1]), 0.0, 1.0)
			_am.call("set_skid", lerpf(float(p[2]), float(p[3]), f))
			_send(v, 0.3, vmax)
			await process_frame
		_phase(str(p[0]), t0 + (0.5 if float(p[1]) > 1.5 else 0.0), _now())
	_am.call("set_skid", 0.0)


## QA-M2-SYSTEM: the menu sounds one by one (no music), 1.0 s apart; one phase per sound.
func _ui() -> void:
	var t0 := _now()
	while _now() - t0 < 1.0:
		await process_frame
	for n in ["ui_move", "ui_ok", "ui_back", "ui/ui_tab", "ui/ui_toggle", "ui/ui_error", "beep", "go", "finish"]:
		t0 = _now()
		_am.call("play", n)
		while _now() - t0 < 1.0:
			await process_frame
		_phase(str(n).replace("/", "_"), t0, _now())
'''
open(S + '/gd/qa_tyre_wind.gd', 'w').write(src)
print('ok')
