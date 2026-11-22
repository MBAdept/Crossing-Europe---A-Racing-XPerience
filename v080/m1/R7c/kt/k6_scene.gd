extends "res://tools/kritik/k5_scene.gd"
## KRITIK-5a2 scratch tool (never committed): --mode=lodcol --models=a,b --dists=60,120,250 --x=20 [--sprite]
## Every model at every distance as lod0 and lod1 (and the Arcade sprite stand-in) in the same light: interior mean
## colour of the model's pixels (LODCOL lines: rgb, luma, saturation) and a sheet (rows: model x dist, cols: levels).


func _run() -> void:
	if str(_args.get("mode", "")) != "lodcol":
		super._run()
		return
	var out := str(_args.get("out", ""))
	if not _load_manifest_with_model_sets():
		quit(1)
		return
	_mats = ModernMaterials.new()
	_build_rig()
	# AS5aR2 K2 diagnosis: --shadow_m=<m> sets the sun's shadow reach (0 = no shadows at all)
	if _args.has("shadow_m"):
		var sm := float(str(_args["shadow_m"]))
		for n: Node in _sv.find_children("*", "DirectionalLight3D", true, false):
			var dl := n as DirectionalLight3D
			dl.shadow_enabled = sm > 0.0
			if sm > 0.0:
				dl.directional_shadow_max_distance = sm
			print("k6_scene: Schatten %s, Reichweite %.0f m" % [str(dl.shadow_enabled), dl.directional_shadow_max_distance])
	var models: Array = str(_args.get("models", "")).split(",", false)
	var dists: Array = str(_args.get("dists", "60,120,250")).split(",", false)
	var x := float(str(_args.get("x", "20")))
	var reps: Array = str(_args.get("reps", "lod0,lod1")).split(",", false)
	if _args.has("sprite"):
		reps.append("sprite")
	var tile := _tile_size()
	var sheet := Image.create(tile.x * reps.size(), tile.y * models.size() * dists.size(), false, Image.FORMAT_RGB8)
	_clear()
	var bg := await _frame()
	var row := 0
	for m: Variant in models:
		var mid := str(m)
		for dv: Variant in dists:
			var d := float(str(dv))
			var line := "LODCOL %s %dm" % [mid.get_file(), int(d)]
			for c in reps.size():
				var lod := str(reps[c])
				_clear()
				var pos := Vector3(x, 0.0, -d)
				var pn := _place(mid, lod, pos)
				if pn != null and _args.has("far_sun"):
					_apply_far(pn, float(str(_args["far_sun"])))
				var img := await _frame()
				var rect := _screen_rect(mid, pos)
				var r := Rect2i(rect.grow(2.0)).intersection(Rect2i(Vector2i.ZERO, GAME))
				var mean := _interior_mean(img, bg, r)
				var st := _luma_stats(img, bg, r)
				var col := Color(mean.x, mean.y, mean.z)
				var luma := 0.2126 * mean.x + 0.7152 * mean.y + 0.0722 * mean.z
				line += "  %s rgb(%d,%d,%d) L%.1f S%.3f H%.0f n%d" % [lod, int(mean.x * 255), int(mean.y * 255), int(mean.z * 255),
					luma * 255.0, col.s, col.h * 360.0, int(mean.w)] + " sd%.1f p10 %.0f p90 %.0f" % [st.x, st.y, st.z]
				var zoom := clampi(int(floor(minf(float(tile.x) / maxf(8.0, rect.size.x * 1.15), float(tile.y) / maxf(8.0, rect.size.y * 1.15)))), 1, 8)
				var t := _crop(img, rect, tile, zoom)
				t = await _caption_tile(t, "%s · %s · %d m · %d×" % [mid.get_file(), lod, int(d), zoom])
				sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, row * tile.y))
			print(line)
			row += 1
	var err := sheet.save_png(out)
	print("k6_scene: lodcol -> %s%s" % [out, "" if err == OK else "  FEHLER %d" % err])
	quit(0 if err == OK else 1)


## R7c: the far light of builders/props.gd on the materials of a placed model: shadow_far = (0.85, 1) x the sun's shadow
## reach, far_sun as given (1 = off).
func _apply_far(n: Node, fs: float) -> void:
	var reach := 0.0
	for l: Node in _sv.find_children("*", "DirectionalLight3D", true, false):
		reach = (l as DirectionalLight3D).directional_shadow_max_distance
	for gi: Node in n.find_children("*", "GeometryInstance3D", true, false):
		var mi := gi as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as ShaderMaterial
			if m != null:
				m.set_shader_parameter("shadow_far", Vector2(reach * 0.85, reach) if fs < 0.999 else Vector2.ZERO)
				m.set_shader_parameter("far_sun", fs)


## Luma spread of the model's interior pixels: (std, p10, p90) in 0..255 - the window contrast of a far facade.
func _luma_stats(img: Image, bg: Image, r: Rect2i) -> Vector3:
	var ls: Array[float] = []
	for y in range(maxi(1, r.position.y), mini(GAME.y - 1, r.end.y)):
		for x in range(maxi(1, r.position.x), mini(GAME.x - 1, r.end.x)):
			var inside := true
			for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c := img.get_pixel(x + o.x, y + o.y)
				var g := bg.get_pixel(x + o.x, y + o.y)
				if absf(c.r - g.r) + absf(c.g - g.g) + absf(c.b - g.b) <= 0.03:
					inside = false
					break
			if inside:
				var c := img.get_pixel(x, y)
				ls.append((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0)
	if ls.is_empty():
		return Vector3.ZERO
	ls.sort()
	var m := 0.0
	for v in ls:
		m += v
	m /= float(ls.size())
	var q := 0.0
	for v in ls:
		q += (v - m) * (v - m)
	return Vector3(sqrt(q / float(ls.size())), ls[int(ls.size() * 0.1)], ls[int(ls.size() * 0.9)])
