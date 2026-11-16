extends "res://probe_base.gd"
# Headless (dummy renderer): pure main-thread CPU cost per frame of CPUParticles3D and node updates.

func frame_cost(n: int = 120) -> float:
	# the monitor is refreshed once per second: wait, then take the lowest of three consecutive seconds
	var best := 1.0e9
	for k: int in range(3):
		await get_tree().create_timer(1.1).timeout
		best = minf(best, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	return snappedf(best, 0.001)

func frame_cost_old(n: int = 120) -> float:
	var acc: Array[float] = []
	var t0 := Time.get_ticks_usec()
	for i: int in range(n):
		await get_tree().process_frame
		var t1 := Time.get_ticks_usec()
		acc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		t0 = t1
	acc.sort()
	return snappedf(acc[n / 2], 0.001)

func test_particles() -> void:
	world = Node3D.new()
	add_child(world)
	var cam3 := Camera3D.new()
	world.add_child(cam3)
	note("renderer", RenderingServer.get_current_rendering_method() + " / " + DisplayServer.get_name())
	note("empty_frame_ms", await frame_cost())
	var fxs: GDScript = load("res://t_fx.gd")
	var fx: Node = fxs.new()
	add_child(fx)
	for spec: Array in [["rain", 2000], ["rain", 8000], ["rain", 30000], ["snow", 6000], ["spray", 300]]:
		var g: GPUParticles3D = fx.call("make_" + str(spec[0]), int(spec[1]))
		var c := CPUParticles3D.new()
		c.convert_from_particles(g)
		g.free()
		world.add_child(c)
		await get_tree().create_timer(1.0).timeout
		note("cpu_particles_%s_%d_frame_ms" % [spec[0], spec[1]], await frame_cost())
		c.queue_free()
		await frames(3)
