extends "res://tools/kritik/k4_scene.gd"
## AS5a1 scratch tool (never committed): --mode=tint --items=<model>@<x>#<rrggbb>;... --dist=35
## One row per item: the model, the model with its albedo atlas multiplied by the tint (sRGB, as the props builder
## multiplies a stand-in and R7 will multiply a model instance), the Arcade sprite with the tint, the sprite without.


func _run() -> void:
	if str(_args.get("mode", "")) != "tint":
		super._run()
		return
	var out := str(_args.get("out", ""))
	if not _load_manifest_with_model_sets():
		quit(1)
		return
	_mats = ModernMaterials.new()
	_build_rig()
	var items: Array = str(_args.get("items", "")).split(";", false)
	var d := float(str(_args.get("dist", "35")))
	var tile := _tile_size()
	var sheet := Image.create(tile.x * 4, tile.y * items.size(), false, Image.FORMAT_RGB8)
	for r in items.size():
		var spec := str(items[r])
		var tint_hex := spec.get_slice("#", 1)
		var mx := spec.get_slice("#", 0)
		var mid := mx.get_slice("@", 0)
		var x := float(mx.get_slice("@", 1))
		var tint := Color("#" + tint_hex)
		var pos := Vector3(x, 0.0, -d)
		for c in 4:
			_clear()
			var lod := "lod0" if c < 2 else "sprite"
			var holder := _place(mid, lod, pos)
			if holder == null:
				continue
			if c == 1:
				_tint_model(holder, mid, tint)
			elif c == 2:
				_tint_sprite(holder, tint)
			var img := await _frame()
			var rect := _screen_rect(mid, pos)
			var zmax := int(str(_args.get("zoom", "2")))
			var zoom := clampi(int(floor(minf(float(tile.x) / maxf(8.0, rect.size.x * 1.15), float(tile.y) / maxf(8.0, rect.size.y * 1.15)))), 1, zmax)
			var t := _crop(img, rect, tile, zoom)
			var what: String = ["Modell", "Modell × Tönung #" + tint_hex, "Sprite × Tönung #" + tint_hex, "Sprite"][c]
			t = await _caption_tile(t, "%s · %s · %d m" % [mid.get_slice("/", 1), what, int(d)])
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
	var err := sheet.save_png(out)
	print("tint_scene: -> %s%s" % [out, "" if err == OK else "  FEHLER %d" % err])
	quit(0 if err == OK else 1)


## The baked surfaces of the model under holder get a copy of their material whose albedo atlas is multiplied by tint.
func _tint_model(holder: Node3D, mid: String, tint: Color) -> void:
	var m := ModelDB.model(mid)
	var rel := str((m.get("textures", {}) as Dictionary).get("albedo", ""))
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/models/" + rel))
	if img == null:
		return
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(p.r * tint.r, p.g * tint.g, p.b * tint.b, p.a))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	for mi: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var mesh := inst.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat is ShaderMaterial and (mat as ShaderMaterial).get_shader_parameter("albedo_tex") != null:
				var dup := (mat as ShaderMaterial).duplicate() as ShaderMaterial
				dup.set_shader_parameter("albedo_tex", tex)
				inst.set_surface_override_material(s, dup)


## The sprite stand-in drawn with the tint as its per-instance colour (a MultiMesh of one, as the props builder does).
func _tint_sprite(holder: Node3D, tint: Color) -> void:
	for mi: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = inst.mesh
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D.IDENTITY)
		mm.set_instance_color(0, tint)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = inst.material_override
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.get_parent().add_child(mmi)
		mmi.transform = inst.transform
		inst.queue_free()
