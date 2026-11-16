import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:70])
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'tests/race3d/render/check_props_render.gd'
rep(p, '''##   props_spiegel   what builders/props.gd commits, drawn for real: on a straight road the same props stand on both
##                   sides – the farmhouse (baked model, tag mirror_left), a birch stand-in (billboard, "mirror" of
##                   the scenery rule), a bale stand-in and the street light (vpbr model, mirror_left) with their
##                   contact shadows. The left ones go into mirrored MultiMesh nodes (negative determinant, D24). Seen
##                   from the centre of the road with the sun at the zenith, the picture must be its own mirror image:
##                   a mirrored node drawn inside out (culled faces, dark normals) or a billboard that does not flip
##                   breaks the symmetry. Both halves must show something.
## "-- --save=<absolute folder>" keeps the picture. (Scripts started with -s compile before the autoloads exist.)''', '''##   props_spiegel   what builders/props.gd commits, drawn for real: on a straight road the same props stand on both
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
## "-- --save=<absolute folder>" keeps the pictures. (Scripts started with -s compile before the autoloads exist.)''')
rep(p, '''	await _check_mirror()
	ModelDB.release_all()''', '''	await _check_mirror()
	await _check_rotor()
	ModelDB.release_all()''')
rep(p, '''		[204, {"kind": "prop", "set": "props/tree_birch", "x": off + 9.0, "scale": 1.0}, true],
		[207, {"kind": "prop", "set": "props/haybale", "x": off + 4.0, "scale": 1.0}, true],''', '''		[204, {"kind": "prop", "set": "props/tree_beech", "x": off + 9.0, "scale": 1.0}, true],
		[207, {"kind": "prop", "set": "props/rock_a", "x": off + 4.0, "scale": 1.0}, true],''')
rep(p, '''	for key: String in ["m|props/farmhouse|1", "m|props/streetlight|1", "s|props/tree_birch|1", "s|props/haybale|1"]:''',
    '''	for key: String in ["m|props/farmhouse|1", "m|props/streetlight|1", "s|props/tree_beech|1", "s|props/rock_a|1"]:''')
rep(p, '''	_report("props_spiegel", p, "Bauernhaus, Birke, Strohballen, Laterne je links (gespiegelter Knoten) und rechts: %d / %d Bildpunkte, Abweichung vom Spiegelbild im Mittel %.2f, über 40 Stufen %.2f %% (%s)" % [''',
    '''	_report("props_spiegel", p, "Bauernhaus, Buche, Fels, Laterne je links (gespiegelter Knoten) und rechts: %d / %d Bildpunkte, Abweichung vom Spiegelbild im Mittel %.2f, über 40 Stufen %.2f %% (%s)" % [''')
s = open(p).read()
s += '''

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
'''
open(p, 'w').write(s)
print('ok')
