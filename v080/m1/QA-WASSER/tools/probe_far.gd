extends SceneTree
## QA-WASSER probe: drives layers/far_ground.gd (its own setup()/update(), stand-in renderer facade like the unit
## test) along a stretch and logs the plane height against the old rule and the water of the window.
##   godot --headless --path . -s probe_far.gd -- <stage> <from> <km_a> <km_b> [step_m=1.5] [vis=900]
## Prints: bridges of the track (z0/z1, km), the first/last km where the new plane differs from the old rule,
## the largest step per frame, and a table every 0.5 km.

class FakeRenderer extends Node:
	var cfg: Dictionary = {}
	var track: Track
	var path: RoadPath3D
	var camera: Camera3D
	var scenery_db: Dictionary = {}
	var world: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var stage := a[0]
	var from := a[1]
	var km_a := float(a[2])
	var km_b := float(a[3])
	var step := float(a[4]) if a.size() > 4 else 1.5
	var vis := float(a[5]) if a.size() > 5 else 900.0
	var Fair: Variant = load("res://tests/race3d/fairness.gd")
	var FarGround: Variant = load("res://scripts/race3d/layers/far_ground.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.load_network()
	var t: Track = null
	for dir: Dictionary in Fair.directions(net, [stage]):
		if str(dir["from"]) == from:
			var plan: Variant = StagePlan.build(dir["stage"], from, net["cities"], net["countries"], cfg, net["city_db"])
			t = Track.new()
			t.setup(plan, cfg, net["scenery"])
	if t == null:
		print("FEHLER: keine Richtung %s ab %s" % [stage, from])
		quit(1)
		return
	print("track %s ab %s: seg_len %.2f, rows %d, length_z %.0f m, km/100m %.3f" % [stage, from, t.seg_len, t.segment_count, t.length_z,
		t.z_to_km(100.0) - t.z_to_km(0.0)])
	for br: Dictionary in t.bridges:
		print("  bridge %-28s type %-13s depth %5.1f  z0 %7.0f z1 %7.0f  km %.2f-%.2f" % [str(br["name"]), str(br["type"]), float(br["depth"]),
			float(br["z0"]), float(br["z1"]), float(br["km0"]), float(br["km1"])])
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
	p.ensure(t.segment_count - 1)
	var r := FakeRenderer.new()
	r.cfg = cfg
	r.track = t
	r.path = p
	r.camera = Camera3D.new()
	r.scenery_db = net.get("scenery", {})
	r.world = Node3D.new()
	var fg: Node3D = FarGround.new()
	fg.setup(r)
	var drop := float(ConfigLoader.lookup(cfg, "graphics.modern.terrain.far_ground_drop_m", 4.0))
	var z := t.km_to_z(km_a)
	var zb := t.km_to_z(km_b)
	var first_diff := -1.0
	var last_diff := -1.0
	var max_diff := 0.0
	var max_step := 0.0
	var max_step_km := 0.0
	var prev := INF
	var next_print := km_a
	var water_in := -1.0
	while z <= zb:
		r.camera.position = p.world(z, 0.0, 3.4)
		fg.update({"camera_z": z, "visibility_m": vis}, 1.0 / 60.0)
		var y := float(fg.get("far_y"))
		var old := float(fg.call("lowest_road", p, z, vis)) - drop
		var wy := float(fg.get("water_y"))
		var km := t.z_to_km(z)
		if wy < INF and water_in < 0.0:
			water_in = km
		var d := old - y
		if absf(d) > 0.01:
			if first_diff < 0.0:
				first_diff = km
			last_diff = km
			max_diff = maxf(max_diff, d)
		if prev < INF and absf(y - prev) > max_step:
			max_step = absf(y - prev)
			max_step_km = km
		prev = y
		if km >= next_print:
			print("  km %7.2f z %8.1f  road %7.2f  far_y %7.2f  old %7.2f  diff %6.2f  water_y %s" % [km, z, p.height(int(z / t.seg_len)), y, old, d,
				("%.2f" % wy) if wy < INF else "-"])
			next_print += 0.5
		z += step
	print("RESULT water enters window at km %.2f; plane differs from old rule km %.2f .. %.2f (max %.2f m lower); max step %.3f m per %.1f m (km %.2f), allowed %.3f" % [
		water_in, first_diff, last_diff, max_diff, max_step, step, max_step_km, float(FarGround.FOLLOW_SLOPE) * step])
	fg.free()
	r.world.free()
	r.camera.free()
	r.free()
	quit(0)
