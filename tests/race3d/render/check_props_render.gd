extends SceneTree
## Render check of the props builder of the mode "Modern" (v0.8.0, contract D24, §6 package R2; German docs:
## docs/renderer-modern-gelaende.md) – it needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_props_render.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##
##   props_spiegel   what builders/props.gd commits, drawn for real: on a straight road the same props stand on both
##                   sides – the farmhouse (baked model, tag mirror_left), a beech stand-in (billboard, "mirror" of
##                   the scenery rule), a rock stand-in and the street light (vpbr model, mirror_left) with their
##                   contact shadows. The left ones go into mirrored MultiMesh nodes (negative determinant, D24). Seen
##                   from the centre of the road with the sun at the zenith, the picture must be its own mirror image:
##                   a mirrored node drawn inside out (culled faces, dark normals) or a billboard that does not flip
##                   breaks the symmetry. Both halves must show something. (Birch and bale of the first version have
##                   models since AS1b; trees turn by a random yaw, so stand-ins of sets without a model are used.)
##   rotor           the wind turbine model (vpbr, paint code 0.875 = rotor part, UV2.y = hub height / 128 m) at
##                   ce_time 0 / 0.4 / 0.8 s: the rotor turns about the hub (rotor_speed 1.35 rad/s) – its pixels
##                   change from frame to frame – while the tower stands still (its pixels stay).
## "-- --save=<absolute folder>" keeps the pictures. (Scripts started with -s compile before the autoloads exist.)

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const BACKGROUND := Color(0.42, 0.56, 0.74)
const MAX_MEAN_DIFF := 1.5            ## mean difference (0..255) of a pixel and its mirror pixel, over the object pixels
const MAX_BAD_SHARE := 0.01           ## share of object pixels whose mirror pixel differs by more than 40 levels
const MIN_OBJECT_PIXELS := 2000       ## per half

var _failed: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK props_spiegel FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	await _check_mirror()
	await _check_rotor()
	ModelDB.release_all()
	ModernMaterials.drop_shared()
	print("RENDER-CHECKS %s  (%d fehlgeschlagen)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size()])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-18s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _check_mirror() -> void:
	var p: Array[String] = []
	var cfg := ConfigLoader.load_merged()
	var t: Track = SynTrack.new()
	t.fill(cfg, SynTrack.straight(1200))
	var off := 1.5 * t.lane_w + t.shoulder_w
	var items := [
		[200, {"kind": "prop", "set": "props/farmhouse", "x": off + 6.0, "scale": 1.0, "align": "edge"}, false],
		[204, {"kind": "prop", "set": "props/tree_beech", "x": off + 9.0, "scale": 1.0}, true],
		[207, {"kind": "prop", "set": "props/rock_a", "x": off + 4.0, "scale": 1.0}, true],
		[198, {"kind": "object", "obj": "streetlight", "x": off - 0.6, "scale": 1.0}, false],
	]
	for e: Array in items:
		for side: int in [-1, 1]:
			var it: Dictionary = (e[1] as Dictionary).duplicate()
			it["side"] = side
			it["x"] = float(it["x"]) * float(side)
			if bool(e[2]) and side < 0:
				it["mirror"] = true          # the scenery rule mirrors the left one
			it["z"] = float(int(e[0])) * t.seg_len + 1.0
			t.get_segment(int(e[0])).sprites.append(it)
	var path := RoadPath3D.new()
	path.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
	var terrain := TerrainProfile.new()
	terrain.setup(path, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), {})
	path.set_clear_reach(1842.0)
	path.ensure(6 * 32 + 32 + 700)
	var ctx := ChunkContext.new()
	ctx.cfg = cfg
	ctx.capture(6, 6 * 32, 6 * 32 + 32, path, terrain, t)
	var b := Props.new()
	b.apply_quality({"prop_lod0_m": 60.0, "prop_lod1_m": 200.0, "shadow_casters": 2, "shadow_distance_m": 120.0, "deco_density": 1.0})
	var part := b.build(ctx, b.collect(ctx))
	var groups: Dictionary = part.get("groups", {})
	for key: String in ["m|props/farmhouse|1", "m|props/streetlight|1", "s|props/tree_beech|1", "s|props/rock_a|1"]:
		if not groups.has(key):
			p.append("keine gespiegelte Gruppe %s" % key)
	# the scene: the committed props of the chunk, a camera on the centreline, the sun at the zenith
	var world := Node3D.new()
	root.add_child(world)
	b.commit(ctx, part, world)
	b.update({"camera_z": 6.0 * 32.0 * t.seg_len - 60.0}, 0.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.45)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-PI * 0.5, 0.0, 0.0)            # shines straight down
	sun.shadow_enabled = true
	sun.light_energy = 1.0
	world.add_child(sun)
	ModernMaterials.ensure_globals()
	ModernMaterials.set_global("ce_sun_dir", Vector3.UP)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(Color.WHITE, 1.0))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(Color(0.45, 0.45, 0.45), 1.0))
	ModernMaterials.set_global("ce_night", 0.0)
	ModernMaterials.set_global("ce_headlight", Vector2(0.0, 0.0))
	var cam := Camera3D.new()
	cam.near = 0.5
	cam.far = 1000.0
	cam.fov = 60.0
	world.add_child(cam)
	var fwd := ctx.rows_f[0]
	cam.global_position = ctx.rows_o[0] - fwd * 45.0 + Vector3(0.0, 3.0, 0.0)
	cam.look_at(cam.global_position + fwd + Vector3(0.0, -0.08, 0.0), Vector3.UP)
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir.path_join("props_spiegel.png"))
	var w := img.get_width()
	var h := img.get_height()
	var bg := BACKGROUND
	var obj_l := 0
	var obj_r := 0
	var diff_sum := 0.0
	var bad := 0
	var pairs := 0
	for y in h:
		for x in w / 2:
			var a := img.get_pixel(x, y)
			var c := img.get_pixel(w - 1 - x, y)
			var oa := absf(a.r - bg.r) + absf(a.g - bg.g) + absf(a.b - bg.b) > 0.06
			var oc := absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) > 0.06
			obj_l += 1 if oa else 0
			obj_r += 1 if oc else 0
			if oa or oc:
				var d := (absf(a.r - c.r) + absf(a.g - c.g) + absf(a.b - c.b)) / 3.0 * 255.0
				diff_sum += d
				pairs += 1
				if d > 40.0:
					bad += 1
	var mean := diff_sum / float(maxi(1, pairs))
	var bad_share := float(bad) / float(maxi(1, pairs))
	if obj_l < MIN_OBJECT_PIXELS or obj_r < MIN_OBJECT_PIXELS:
		p.append("zu wenig gezeichnet (links %d, rechts %d Bildpunkte)" % [obj_l, obj_r])
	if mean > MAX_MEAN_DIFF:
		p.append("mittlere Abweichung vom Spiegelbild %.2f (höchstens %.1f)" % [mean, MAX_MEAN_DIFF])
	if bad_share > MAX_BAD_SHARE:
		p.append("%.2f %% der Bildpunkte weichen um mehr als 40 Stufen vom Spiegelbild ab (höchstens %.1f %%)" % [100.0 * bad_share, 100.0 * MAX_BAD_SHARE])
	var counts: Dictionary = part.get("counts", {})
	_report("props_spiegel", p, "Bauernhaus, Buche, Fels, Laterne je links (gespiegelter Knoten) und rechts: %d / %d Bildpunkte, Abweichung vom Spiegelbild im Mittel %.2f, über 40 Stufen %.2f %% (%s)" % [
		obj_l, obj_r, mean, 100.0 * bad_share, str(counts)])
	world.queue_free()
	await process_frame
	b.library.clear(b)


## The rotor of the wind turbine turns with ce_time (vpbr vertex(), paint code 0.875), the tower stands still.
func _check_rotor() -> void:
	var p: Array[String] = []
	var mats := ModernMaterials.shared()
	ModelDB.request(["props/wind_turbine"], [], self)
	var guard := 0
	while ModelDB.pending() > 0 and guard < 600:
		await process_frame
		guard += 1
	var node := ModelFactory.build("props/wind_turbine", "", mats)
	if node == null:
		_report("rotor", ["kein Modell props/wind_turbine"], "")
		return
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(node)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0.0)
	world.add_child(sun)
	ModernMaterials.set_global("ce_sun_dir", Vector3(0.0, 0.7, 0.7).normalized())
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(Color.WHITE, 1.0))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(Color(0.5, 0.5, 0.5), 1.0))
	ModernMaterials.set_global("ce_night", 0.0)
	var cam := Camera3D.new()
	cam.near = 0.5
	cam.far = 1000.0
	cam.fov = 70.0
	world.add_child(cam)
	cam.global_position = Vector3(0.0, 60.0, 110.0)          # in front of the rotor (the model looks along +Z)
	cam.look_at(Vector3(0.0, 60.0, 0.0), Vector3.UP)
	cam.current = true
	var shots: Array[Image] = []
	for t: float in [0.0, 0.4, 0.8]:
		ModernMaterials.set_global("ce_time", t)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		shots.append(root.get_texture().get_image())
	ModernMaterials.set_global("ce_time", 0.0)
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(dir)
		for i in shots.size():
			shots[i].save_png(dir.path_join("rotor_t%d.png" % i))
	# the hub sits at the top of the tower: the rotor sweeps the upper part of the picture, the tower stands below
	# the hub in the lower part. Count changed pixels in both parts between consecutive frames.
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var hub_px := cam.unproject_position(Vector3(0.0, 89.6, 0.0))
	var changed_rotor := [0, 0]
	var changed_tower := [0, 0]
	var object_px := 0
	for k in 2:
		var a := shots[k]
		var b := shots[k + 1]
		for y in range(0, h, 2):
			for x in range(0, w, 2):
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				var d := absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
				var near_hub := Vector2(x, y).distance_to(hub_px) < 0.42 * h
				var tower := absf(float(x) - hub_px.x) < 0.04 * w and float(y) > hub_px.y + 0.45 * h
				if k == 0:
					var bg := BACKGROUND
					if absf(ca.r - bg.r) + absf(ca.g - bg.g) + absf(ca.b - bg.b) > 0.06:
						object_px += 1
				if d > 0.1:
					if tower:
						changed_tower[k] += 1
					elif near_hub:
						changed_rotor[k] += 1
	if object_px < 500:
		p.append("zu wenig vom Windrad zu sehen (%d Bildpunkte)" % object_px)
	for k in 2:
		if int(changed_rotor[k]) < 200:
			p.append("Rotor dreht sich nicht (Bild %d -> %d: %d Bildpunkte geändert)" % [k, k + 1, int(changed_rotor[k])])
		if int(changed_tower[k]) > 20:
			p.append("Turm bewegt sich (Bild %d -> %d: %d Bildpunkte geändert)" % [k, k + 1, int(changed_tower[k])])
	_report("rotor", p, "Windrad bei ce_time 0 / 0,4 / 0,8 s: Rotor %d / %d Bildpunkte geändert, Turm %d / %d (jeder zweite Bildpunkt, %d Bildpunkte Windrad)" % [
		int(changed_rotor[0]), int(changed_rotor[1]), int(changed_tower[0]), int(changed_tower[1]), object_px])
	world.queue_free()
	await process_frame
	ModelDB.release_all(self)
