extends "res://tools/models/prop_scene.gd"
## KRITIK-3 scratch tool (art review of AS3, never committed): extra review modes on top of the review scene
## tools/models/prop_scene.gd (same rig, same race look, same placing and LOD choice).
##   --mode=turn     one row per model, one tile per yaw (--yaws=0,45,…) at --dist (25 m): edge-on cards, backs
##   --mode=slope    the model on a lateral slope (--slope=deg, ground rises away from the road) at --dist / --x;
##                   tiles: whole model, and the trunk foot magnified (--foot_zoom)
##   --mode=sparkle  sub-pixel steps of the model (and of the Arcade sprite stand-in) sideways at --dists:
##                   share of the model's pixels that toggle (max channel step > --thr) between neighbour steps
##   --mode=outline  orthographic view of the sprite camera (6 deg elevation, from the road): silhouettes of lod0 /
##                   lod1 / impostor against the sprite's alpha; PNG overlay per model and the shares printed
##   --mode=under    the model close beside the camera (--x, --dist), whole 1280x720 frame (crown from below)

const SPRITE_ELEV_DEG := 6.0


func _run() -> void:
	var mode := str(_args.get("mode", "turn"))
	if not ["turn", "slope", "sparkle", "outline", "under", "levels"].has(mode):
		super._run()
		return
	var out := str(_args.get("out", ""))
	if out == "" or not _args.has("models"):
		print("kritik_scene: --out und --models angeben")
		quit(1)
		return
	if not _load_manifest_with_model_sets():
		print("kritik_scene: kein Manifest")
		quit(1)
		return
	_mats = ModernMaterials.new()
	_build_rig()
	var models: Array = str(_args["models"]).split(",", false)
	var img: Image
	match mode:
		"turn":
			img = await _turn(models)
		"slope":
			img = await _slope(models)
		"sparkle":
			img = await _sparkle(models)
		"outline":
			img = await _outline(models)
		"under":
			img = await _under(models)
		"levels":
			img = await _levels(models)
	var err := img.save_png(out)
	print("kritik_scene: %s -> %s%s" % [mode, out, "" if err == OK else "  FEHLER %d" % err])
	quit(0 if err == OK else 1)


func _zoom_for(rect: Rect2, tile: Vector2i, zmax: int) -> int:
	return clampi(int(floor(minf(float(tile.x) / maxf(8.0, rect.size.x * 1.15), float(tile.y) / maxf(8.0, rect.size.y * 1.15)))), 1, zmax)


# --- turn ---------------------------------------------------------------------------------------------------------

func _turn(models: Array) -> Image:
	var yaws: Array = str(_args.get("yaws", "0,45,90,135,180,225,270,315")).split(",", false)
	var d := float(str(_args.get("dist", "25")))
	var x := float(str(_args.get("x", "9")))
	var tile := _tile_size()
	var sheet := Image.create(tile.x * yaws.size(), tile.y * models.size(), false, Image.FORMAT_RGB8)
	for r in models.size():
		var mid := str(models[r])
		var lod := str(_args.get("lod", ""))
		if lod == "":
			lod = _level_for(mid, d)
		for c in yaws.size():
			_clear()
			var yaw := deg_to_rad(float(str(yaws[c])))
			var pos := Vector3(x, 0.0, -d)
			_place(mid, lod, pos, yaw)
			var img := await _frame()
			var rect := _screen_rect(mid, pos)
			var zoom := _zoom_for(rect, tile, int(str(_args.get("zoom", "4"))))
			var t := _crop(img, rect, tile, zoom)
			t = await _caption_tile(t, "%s · %s · %d m · Drehung %s° · %d×" % [mid, lod, int(d), str(yaws[c]), zoom])
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
	return sheet


# --- slope --------------------------------------------------------------------------------------------------------

func _ground_node() -> MeshInstance3D:
	for c: Node in _sv.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh is PlaneMesh and (mi.mesh as PlaneMesh).size.x > 1000.0:
			return mi
	return null


func _slope(models: Array) -> Image:
	var deg := float(str(_args.get("slope", "30")))
	var d := float(str(_args.get("dist", "14")))
	var x := float(str(_args.get("x", "9")))
	var yaw := deg_to_rad(float(str(_args.get("yaw", "0"))))
	var tile := _tile_size()
	var fz := int(str(_args.get("foot_zoom", "4")))
	var ground := _ground_node()
	# the ground plane through the model's anchor, rising in +x (away from the road) by deg; the road keeps y 0
	ground.rotation = Vector3(0.0, 0.0, deg_to_rad(deg))
	ground.position = Vector3(x, 0.0, 0.0)
	var cols := 3
	var sheet := Image.create(tile.x * cols, tile.y * models.size(), false, Image.FORMAT_RGB8)
	for r in models.size():
		var mid := str(models[r])
		var lod := str(_args.get("lod", ""))
		if lod == "":
			lod = _level_for(mid, d)
		_clear()
		var pos := Vector3(x, 0.0, -d)
		_place(mid, lod, pos, yaw)
		var img := await _frame()
		var rect := _screen_rect(mid, pos)
		var t := _crop(img, rect, tile, _zoom_for(rect, tile, 4))
		t = await _caption_tile(t, "%s · %s · Hang %d° · %d m" % [mid, lod, int(deg), int(d)])
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(0, r * tile.y))
		# the foot: 2.4 m wide around the anchor (downhill side towards the road)
		var a := _cam.unproject_position(pos + Vector3(-1.6, -0.9, 0.0))
		var b := _cam.unproject_position(pos + Vector3(1.6, 1.6, 0.0))
		var foot := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
		var t2 := _crop(img, foot, tile, fz)
		t2 = await _caption_tile(t2, "Fuß · %d×" % fz)
		sheet.blit_rect(t2, Rect2i(Vector2i.ZERO, tile), Vector2i(tile.x, r * tile.y))
		# the same from the other side of the road (ground falls away from the camera's side: x mirrored)
		_clear()
		ground.rotation = Vector3(0.0, 0.0, deg_to_rad(-deg))
		ground.position = Vector3(-x, 0.0, 0.0)
		var pos2 := Vector3(-x, 0.0, -d)
		_place(mid, lod, pos2, yaw)
		var img2 := await _frame()
		var a2 := _cam.unproject_position(pos2 + Vector3(-1.6, -0.9, 0.0))
		var b2 := _cam.unproject_position(pos2 + Vector3(1.6, 1.6, 0.0))
		var foot2 := Rect2(Vector2(minf(a2.x, b2.x), minf(a2.y, b2.y)), (b2 - a2).abs())
		var t3 := _crop(img2, foot2, tile, fz)
		t3 = await _caption_tile(t3, "Fuß links (Hang steigt zur Straße hin ab) · %d×" % fz)
		sheet.blit_rect(t3, Rect2i(Vector2i.ZERO, tile), Vector2i(2 * tile.x, r * tile.y))
		ground.rotation = Vector3(0.0, 0.0, deg_to_rad(deg))
		ground.position = Vector3(x, 0.0, 0.0)
	return sheet


# --- sparkle ------------------------------------------------------------------------------------------------------

func _sparkle(models: Array) -> Image:
	var dists: Array = str(_args.get("dists", "40,80,150")).split(",", false)
	var x0 := float(str(_args.get("x", "9")))
	var steps := int(str(_args.get("steps", "8")))
	var thr := float(str(_args.get("thr", "0.2")))
	var sub := float(str(_args.get("sub", "0.25")))          # step in pixels
	var tile := _tile_size()
	var rows: Array = []
	for m: Variant in models:
		rows.append([str(m), ""])
		if _args.has("sprite"):
			rows.append([str(m), "sprite"])
	var sheet := Image.create(tile.x * dists.size(), tile.y * rows.size(), false, Image.FORMAT_RGB8)
	_clear()
	var bg := await _frame()
	for r in rows.size():
		var mid := str(rows[r][0])
		var res: Array[String] = []
		for c in dists.size():
			var d := float(str(dists[c]))
			var lod := str(rows[r][1]) if str(rows[r][1]) != "" else _level_for(mid, d)
			var step_m := d / FOCAL_PX * sub
			var frames: Array = []
			var rect := Rect2()
			for k in steps:
				_clear()
				var pos := Vector3(x0 + step_m * float(k), 0.0, -d)
				_place(mid, lod, pos)
				frames.append(await _frame())
				rect = _screen_rect(mid, pos) if k == 0 else rect.merge(_screen_rect(mid, pos))
			var rr := Rect2i(rect.grow(2.0)).intersection(Rect2i(Vector2i.ZERO, GAME))
			var tog := 0.0
			var area := 0.0
			for k in steps - 1:
				var ia: Image = frames[k]
				var ib: Image = frames[k + 1]
				var nt := 0
				var na := 0
				for y in range(rr.position.y, rr.end.y):
					for xx in range(rr.position.x, rr.end.x):
						var ca := ia.get_pixel(xx, y)
						var cb := ib.get_pixel(xx, y)
						var cg := bg.get_pixel(xx, y)
						var in_a := absf(ca.r - cg.r) + absf(ca.g - cg.g) + absf(ca.b - cg.b) > 0.03
						var in_b := absf(cb.r - cg.r) + absf(cb.g - cg.g) + absf(cb.b - cg.b) > 0.03
						if not (in_a or in_b):
							continue
						na += 1
						if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > thr:
							nt += 1
				tog += float(nt)
				area += float(na)
			var share := 100.0 * tog / maxf(1.0, area)
			res.append("%d m %s: %.1f %% Pixel kippen je Schritt (%d px Fläche)" % [int(d), lod, share, int(area / maxf(1.0, float(steps - 1)))])
			var zoom := _zoom_for(rect, tile, 8)
			var t := _crop(frames[0], rect, tile, zoom)
			t = await _caption_tile(t, "%s · %s · %d m · %.1f %% kippen" % [mid if lod != "sprite" else "Sprite", lod, int(d), share])
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
		print("FLIMMER %s %s  %s" % [mid, str(rows[r][1]), "  |  ".join(res)])
	return sheet


# --- outline ------------------------------------------------------------------------------------------------------

func _outline(models: Array) -> Image:
	_load_sprites()
	var lods: Array = str(_args.get("lods", "lod0,lod1,impostor")).split(",", false)
	var ppm := float(str(_args.get("ppm", "24")))
	# plain background, no fog: a flat magenta world
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1.0, 0.0, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var osv := SubViewport.new()
	osv.own_world_3d = true
	osv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	osv.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(osv)
	var we := WorldEnvironment.new()
	we.environment = env
	osv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.4, 0.0)
	osv.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.5
	cam.far = 2000.0
	osv.add_child(cam)
	var holder := Node3D.new()
	osv.add_child(holder)
	var tiles: Array[Image] = []
	var th := deg_to_rad(SPRITE_ELEV_DEG)
	var fwd := Vector3(0.0, -sin(th), -cos(th))
	var up := Vector3(0.0, cos(th), -sin(th))
	var report: Array[String] = []
	for m: Variant in models:
		var mid := str(m)
		var sid := _set_of_model(mid)
		var sp: Dictionary = _sprites.get(sid, {})
		if sp.is_empty():
			print("kritik_scene: kein Sprite für %s" % mid)
			continue
		var cellpx: Array = sp.get("cell", [64, 64])
		var w := float(sp.get("image_width_m", 1.0))
		var h := w * float(cellpx[1]) / float(cellpx[0])
		var anchor: Array = sp.get("anchor", [0.5, 1.0])
		var px := Vector2i(int(round(w * ppm)), int(round(h * ppm)))
		osv.size = px
		cam.size = w
		var c := -(float(anchor[0]) - 0.5) * w * Vector3.RIGHT - (0.5 - float(anchor[1])) * h * up - 300.0 * fwd
		cam.look_at_from_position(c, c + fwd, up)
		# the sprite's mask, scaled to px (alpha >= 0.5, the dark baked ground shadow below the cut removed)
		var stex := load(str(sp.get("root", SPRITE_ROOT)) + str(sp.get("file", ""))) as Texture2D
		var simg := stex.get_image()
		if simg.is_compressed():
			simg.decompress()
		simg.convert(Image.FORMAT_RGBA8)
		var cell := simg.get_region(Rect2i(0, 0, int(cellpx[0]), int(cellpx[1])))
		cell.resize(px.x, px.y, Image.INTERPOLATE_BILINEAR)
		var smask := PackedByteArray()
		smask.resize(px.x * px.y)
		var s_n := 0
		for y in px.y:
			for x in px.x:
				var col := cell.get_pixel(x, y)
				var keep := col.a >= 0.5 and not (col.a < PropLibrary.STANDIN_SHADOW_CUT and maxf(col.r, maxf(col.g, col.b)) < 0.1)
				smask[y * px.x + x] = 1 if keep else 0
				s_n += 1 if keep else 0
		var row_tiles: Array[Image] = []
		var line: Array[String] = []
		for lod_v: Variant in lods:
			var lod := str(lod_v)
			for ch: Node in holder.get_children():
				ch.free()
			var node: Node3D
			if lod == "impostor":
				node = ModelFactory.build_impostor(mid, _mats)
			else:
				node = ModelFactory.build(mid, lod, _mats)
			if node == null:
				line.append("%s fehlt" % lod)
				continue
			holder.add_child(node)
			for _i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := osv.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			var ov := Image.create(px.x, px.y, false, Image.FORMAT_RGB8)
			var m_n := 0
			var out_n := 0
			var both := 0
			var trunk_row := int(round(float(anchor[1]) * float(px.y) - 1.5 * ppm))   # 1.5 m above the ground
			var t_m := 0
			var t_s := 0
			for y in px.y:
				for x in px.x:
					var col := img.get_pixel(x, y)
					var above := float(y) < float(anchor[1]) * float(px.y)      # the sprite ends at the ground line
					var mm := above and not (col.r > 0.9 and col.g < 0.1 and col.b > 0.9)
					var ss := above and smask[y * px.x + x] == 1
					if mm:
						m_n += 1
						if ss:
							both += 1
						else:
							out_n += 1
					if y == trunk_row:
						t_m += 1 if mm else 0
						t_s += 1 if ss else 0
					var o := Color(0.92, 0.92, 0.92)
					if mm and ss:
						o = Color(0.36, 0.58, 0.29)
					elif mm:
						o = Color(0.95, 0.55, 0.1)          # model outside the sprite: orange
					elif ss:
						o = Color(0.55, 0.7, 0.95)          # sprite not covered: light blue
					ov.set_pixel(x, y, o)
			line.append("%s %.1f %% außerhalb, Sprite zu %.1f %% gedeckt, Stamm in 1,5 m: Modell %.2f m / Sprite %.2f m" % [
				lod, 100.0 * float(out_n) / maxf(1.0, float(m_n)), 100.0 * float(both) / maxf(1.0, float(s_n)),
				float(t_m) / ppm, float(t_s) / ppm])
			row_tiles.append(ov)
			ov.save_png("%s_%s_%s.png" % [str(_args.get("out", "")).get_basename(), mid.get_file(), lod])
		report.append("UMRISS %s (Sprite %s)  %s" % [mid, sid, "  |  ".join(line)])
		print(report[-1])
		# one row: the overlays side by side
		var rw := 0
		var rh := 0
		for t: Image in row_tiles:
			rw += t.get_width() + 6
			rh = maxi(rh, t.get_height())
		var rowimg := Image.create(maxi(rw, 8), maxi(rh, 8), false, Image.FORMAT_RGB8)
		rowimg.fill(Color(1, 1, 1))
		var xo := 0
		for t: Image in row_tiles:
			rowimg.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(xo, rh - t.get_height()))
			xo += t.get_width() + 6
		tiles.append(rowimg)
	# stack the rows
	var sw := 0
	var sh := 0
	for t: Image in tiles:
		sw = maxi(sw, t.get_width())
		sh += t.get_height() + 10
	var sheet := Image.create(maxi(sw, 8), maxi(sh, 8), false, Image.FORMAT_RGB8)
	sheet.fill(Color(1, 1, 1))
	var yo := 0
	for t: Image in tiles:
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(0, yo))
		yo += t.get_height() + 10
	return sheet


# --- under --------------------------------------------------------------------------------------------------------

func _under(models: Array) -> Image:
	var d := float(str(_args.get("dist", "12")))
	var x := float(str(_args.get("x", "5")))
	var sc := float(str(_args.get("scale", "1")))
	var yaw := deg_to_rad(float(str(_args.get("yaw", "0"))))
	var half := Vector2i(640, 360)
	var cols := 2 if _args.has("sprite") else 1
	var sheet := Image.create(half.x * cols, half.y * models.size(), false, Image.FORMAT_RGB8)
	for r in models.size():
		var mid := str(models[r])
		for c in cols:
			_clear()
			var lod := "sprite" if c == 1 else _level_for(mid, d)
			var holder := _place(mid, lod, Vector3(x, 0.0, -d), yaw if c == 0 else 0.0, sc)
			var img := await _frame()
			img.resize(half.x, half.y, Image.INTERPOLATE_LANCZOS)
			img = await _caption_tile(img, "%s · %s · %.0f m voraus, %.1f m seitlich · Maßstab %.2f" % [mid if c == 0 else "Arcade-Sprite", lod, d, x, sc])
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, half), Vector2i(c * half.x, r * half.y))
	return sheet


# --- levels: brightness, saturation and contrast of every level at the swap distances --------------------------------

## Interior pixels of the model (the pixel and its 4 neighbours differ from bg): mean rgb, mean HSV saturation,
## std of luma, count.
func _stats(img: Image, bg: Image, r: Rect2i) -> Dictionary:
	var sum := Vector3.ZERO
	var s_sum := 0.0
	var l_sum := 0.0
	var l2 := 0.0
	var n := 0
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
				sum += Vector3(c.r, c.g, c.b)
				s_sum += c.s
				var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				l_sum += l
				l2 += l * l
				n += 1
	if n == 0:
		return {"n": 0}
	var m := sum / float(n)
	var lm := l_sum / float(n)
	return {"n": n, "rgb": m, "sat": s_sum / float(n), "luma": lm, "std": sqrt(maxf(0.0, l2 / float(n) - lm * lm)),
		"hue": Color(m.x, m.y, m.z).h * 360.0}


func _levels(models: Array) -> Image:
	var x := float(str(_args.get("x", "9")))
	var tile := _tile_size()
	var cols := [["lod0", _lod0_m], ["lod1", _lod0_m], ["lod1", _lod1_m], ["far", _lod1_m], ["sprite", _lod1_m]]
	var sheet := Image.create(tile.x * cols.size(), tile.y * models.size(), false, Image.FORMAT_RGB8)
	_clear()
	var bg := await _frame()
	for r in models.size():
		var mid := str(models[r])
		var reps := _reps(mid)
		var line: Array[String] = []
		var st: Array = []
		for c in cols.size():
			var lod := str(cols[c][0])
			if lod == "far":
				lod = reps[2]
			var d := float(cols[c][1])
			_clear()
			var pos := Vector3(x, 0.0, -d)
			var node := _place(mid, lod, pos)
			var img := await _frame()
			var rect := _screen_rect(mid, pos)
			var rr := Rect2i(rect.grow(2.0)).intersection(Rect2i(Vector2i.ZERO, GAME))
			var s := _stats(img, bg, rr) if node != null else {"n": 0}
			st.append(s)
			if int(s.get("n", 0)) > 0:
				var m: Vector3 = s["rgb"]
				line.append("%s@%d (%d,%d,%d) L%.1f S%.2f H%.0f sd%.1f n%d" % [lod, int(d), int(m.x * 255.0), int(m.y * 255.0), int(m.z * 255.0),
					float(s["luma"]) * 255.0, float(s["sat"]), float(s["hue"]), float(s["std"]) * 255.0, int(s["n"])])
			else:
				line.append("%s@%d -" % [lod, int(d)])
			var zoom := _zoom_for(rect, tile, 8)
			var t := _crop(img, rect, tile, zoom)
			t = await _caption_tile(t, "%s · %s · %d m · %d×" % [mid, lod, int(d), zoom])
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
		print("PEGEL %s  %s" % [mid, "  ".join(line)])
		# relative jumps: lod0->lod1 at d0, lod1->far at d1, far->sprite at d1
		var pairs := [[0, 1, "lod0>lod1"], [2, 3, "lod1>fern"], [3, 4, "fern>sprite"]]
		var rel: Array[String] = []
		for p: Array in pairs:
			var a: Dictionary = st[int(p[0])]
			var b: Dictionary = st[int(p[1])]
			if int(a.get("n", 0)) == 0 or int(b.get("n", 0)) == 0:
				continue
			var dl := 100.0 * (float(b["luma"]) - float(a["luma"])) / maxf(0.001, float(a["luma"]))
			var ds := 100.0 * (float(b["sat"]) - float(a["sat"])) / maxf(0.001, float(a["sat"]))
			var dsd := 100.0 * (float(b["std"]) - float(a["std"])) / maxf(0.001, float(a["std"]))
			var dh := fposmod(float(b["hue"]) - float(a["hue"]) + 180.0, 360.0) - 180.0
			rel.append("%s: Helligkeit %+.1f %%, Sättigung %+.1f %%, Kontrast %+.1f %%, Farbton %+.0f°" % [str(p[2]), dl, ds, dsd, dh])
		print("SPRUNG %s  %s" % [mid, "  |  ".join(rel)])
	return sheet
