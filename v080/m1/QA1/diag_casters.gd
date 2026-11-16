extends SceneTree
## QA1 diagnostic: which geometry nodes still cast shadows with "Schatten: Aus" at S1 (check_light_base "schatten").

const RACE := "res://scenes/race/race.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cli := CliArgs.all()
	cli["no-traffic"] = true
	cli["gfx-preset"] = "medium"
	cli["gfx"] = "shadows=0"
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": false, "gfx": "modern"}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while int(sc.get("_sim_steps")) < 30 and n < 6000:
		await process_frame
		n += 1
	var r: Variant = sc.get("renderer")
	print("DIAG levels shadow_casters=", (r as Object).get("levels").get("shadow_casters", -1))
	var world: Node = (r as Object).get("world")
	_list(world, r as Node)
	_list(r as Node, r as Node)
	quit(0)


func _list(node: Node, base: Node) -> void:
	if node is GeometryInstance3D and (node as GeometryInstance3D).visible \
			and (node as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		var gi := node as GeometryInstance3D
		var scr: Variant = gi.get_parent().get_script() if gi.get_parent() != null else null
		print("DIAG CASTER ", base.get_path_to(node), " class=", gi.get_class(), " mode=", gi.cast_shadow, " parent_script=",
			(scr as Script).resource_path if scr is Script else "-", " meta=", gi.get_meta_list())
	for ch: Node in node.get_children():
		_list(ch, base)
