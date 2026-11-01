extends SceneTree
## Network check of the police escape with the curve physics (tools/run_tests.sh, integration part, ~45 s):
## every radar zone of every stage direction × every car × {dry day, rain at night} – each chase must be
## escapable (tests/sim/escape_sim.gd: real PoliceSystem with the police car's curve limit, curve-limited
## player profile, no traffic):
##   ideal  at the car's own curve limit, braking with the full 70 km/h/s before curves
##   good   97 % of the curve limit, braking with only 10 m/s² (earlier and gentler than possible)
##   godot --headless --path . -s res://tests/sim/check_escapes.gd [-- --only=good]
## Prints "CHECK escape_<driver> OK|FEHLER …" (plus the failing chases); exit code 0 when all pass.

const Esc := preload("res://tests/sim/escape_sim.gd")
const DRIVERS := {
	"ideal": {"margin": 1.0, "brake_mps2": 70.0 / 3.6},
	"good": {"margin": 0.97, "brake_mps2": 10.0},
}


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var only := str(CliArgs.all().get("only", ""))
	var drivers: Array = []
	for d: String in DRIVERS:
		if only == "" or only.split(",").has(d):
			drivers.append(d)
	var t0 := Time.get_ticks_msec()
	var opts := {"drivers": {}}
	for d: String in drivers:
		opts["drivers"][d] = DRIVERS[d]
	var res := Esc.sweep_drivers(cfg, opts)
	var failed := false
	for d: String in drivers:
		var r: Dictionary = res[d]
		var fails := 0
		var flashed := 0
		var worst := 0.0
		for key: String in r["total"]:
			fails += int(r["fails"].get(key, 0))
			flashed += int(r["flashed"].get(key, 0))
			for s: float in r["escape_s"].get(key, []):
				worst = maxf(worst, s)
		var ok := fails == 0 and flashed > 0
		failed = failed or not ok
		print("CHECK escape_%-6s %s  %d Radarfelder × %d Fahrzeug/Wetter: %d Verfolgungen, %d nicht zu entkommen, längste Flucht %.1f s (%.0f s)" % [
			d, "OK     " if ok else "FEHLER ", int(r["radars"]), (r["total"] as Dictionary).size(), flashed, fails, worst, (Time.get_ticks_msec() - t0) / 1000.0])
		for f: Dictionary in (r["failures"] as Array).slice(0, 12):
			print("    %s: %s ab %s, Radar km %.1f – %s nach %.1f s (Ø %.0f, nötig %.0f km/h)" % [f["key"], f["stage"], f["from"],
				float(f["radar_km"]), f["result"], float(f["chase_s"]), float(f["avg"]), float(f["escape_kmh"])])
	quit(1 if failed else 0)
