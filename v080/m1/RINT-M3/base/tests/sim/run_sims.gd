extends SceneTree
## Prints all gameplay simulation tables (design document numbers):
##   godot --headless --path . -s res://tests/sim/run_sims.gd [-- --only=traffic]
## Owner: gameplay module.

const Sim := preload("res://tests/sim/gameplay_sim.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var t0 := Time.get_ticks_msec()
	match only:
		"accel":
			print(Sim.table_accel(cfg))
		"collision":
			print(Sim.table_collision(cfg))
		"police":
			print(Sim.table_police(cfg))
		"refuel":
			print(Sim.table_refuel(cfg))
		"consumption":
			print(Sim.table_consumption(cfg))
		"escape":
			print(Sim.table_escape(cfg))
		"rain":
			print(Sim.table_rain_night(cfg))
		"traffic":
			print(Sim.table_traffic(cfg))
		"understeer":
			print(Sim.table_understeer(cfg))
		_:
			print(Sim.all_tables(cfg))
	print("(%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)
