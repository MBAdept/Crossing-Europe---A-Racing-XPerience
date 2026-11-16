extends "res://tools/kritik/kritik_scene.gd"
## KRITIK-4 scratch tool (art review of AS4, never committed). Extra modes on top of kritik_scene.gd (KRITIK-3) and
## tools/models/prop_scene.gd (AS3: --look=race, same rig, same placing and LOD choice as the props builder).
##   --mode=dist2     --items=<spec>;<spec>..  spec = model@x[*scale][^h]  (x < 0: left roadside, mirrored like the
##                    props builder when the model carries mirror_left); --dist=30,100,250,400; --sprite adds a row
##                    with the Arcade sprite stand-in at the same anchor and scale; --water draws a water plane at h
##   --mode=outline2  like outline (sprite camera, silhouettes against the sprite's alpha) but with the sprite camera of
##                    cesprites: the set's view_yaw (table below) and the elevation of the sprite manifest
##   --mode=close     --items=<model> --views=front,oblique,road,roof,back: perspective views around the model
##                    (1280x720 each, also written as <out>_<view>.png), --fov=40
##   --mode=approach  --items=<spec> --from=400 --to=20 --kmh=120 --fps=30: the game camera drives towards the model,
##                    every frame written as <out>_NNN.jpg, the level chosen like the props builder (hysteresis 6 m)
##   --mode=street    --items=<spec>;..  --every=28: the specs repeated along the road from 15 m on (a street), one
##                    full game frame (levels by distance)

const VIEW_YAW := {"house_med": -24.0, "church": -24.0, "factory": -22.0, "windmill": 0.0, "farmhouse": -24.0,
	"barn": -24.0, "building_block_a": -20.0, "building_block_b": -20.0, "building_tall": -20.0,
	"building_oldtown": -20.0, "building_shop": -20.0, "ferry_ship": 0.0, "houseboat": -20.0, "bridge_pylon": -20.0,
	"bridge_truss_arch": 0.0, "bridge_lamp": 0.0}
const HYST_M := 6.0

var _water: MeshInstance3D


func _run() -> void:
	var mode := str(_args.get("mode", "dist2"))
	if not ["dist2", "outline2", "close", "approach", "street"].has(mode):
		super._run()
		return
	var out := str(_args.get("out", ""))
	if out == "" or not _args.has("items"):
		print("k4_scene: --out und --items angeben")
		quit(1)
		return
	if not _load_manifest_with_model_sets():
		print("k4_scene: kein Manifest")
		quit(1)
		return
	_mats = ModernMaterials.new()
	_build_rig()
	var items: Array = str(_args["items"]).split(";", false)
	if _args.has("water"):
		_add_water(float(str(_args.get("water_h", "0"))))
	var img: Image
	match mode:
		"dist2":
			img = await _dist2(items)
		"outline2":
			img = await _outline2(items)
		"close":
			img = await _close(items, out)
		"approach":
			var n: int = await _approach(items, out)
			print("k4_scene: approach -> %d Bilder" % n)
			quit(0 if n > 0 else 1)
			return
		"street":
			img = await _street(items)
	var err := img.save_png(out)
	print("k4_scene: %s -> %s%s" % [mode, out, "" if err == OK else "  FEHLER %d" % err])
	quit(0 if err == OK else 1)


## spec "model@x*scale^h" -> {mid, x, scale, h, mirror}
func _spec(s: String) -> Dictionary:
	var mid := s
	var x := 9.0
	var sc := 1.0
	var h := 0.0
	var has_h := false
	if s.contains("^"):
		h = float(s.get_slice("^", 1))
		has_h = true
		s = s.get_slice("^", 0)
	if s.contains("*"):
		sc = float(s.get_slice("*", 1))
		s = s.get_slice("*", 0)
	if s.contains("@"):
		x = float(s.get_slice("@", 1))
		s = s.get_slice("@", 0)
	mid = s
	var m := ModelDB.model(mid)
	var mirror := x < 0.0 and (m.get("tags", []) as Array).has("mirror_left")
	return {"mid": mid, "x": x, "scale": sc, "h": h, "has_h": has_h, "mirror": mirror}


func _add_water(h: float) -> void:
	_water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000.0, 4000.0)
	_water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.16, 0.24, 0.30)
	wm.roughness = 0.12
	wm.metallic = 0.0
	_water.material_override = wm
	_water.position = Vector3(0.0, h + 0.005, 0.0)
	_sv.add_child(_water)


func _rect_scaled(mid: String, pos: Vector3, sc: float, mirror: bool) -> Rect2:
	var m := ModelDB.model(mid)
	var bb: Array = m.get("aabb", [-1, 0, -1, 1, 2, 1])
	var r := Rect2()
	var first := true
	for i in 8:
		var p := Vector3(float(bb[0] if i & 1 == 0 else bb[3]), float(bb[1] if i & 2 == 0 else bb[4]),
			float(bb[2] if i & 4 == 0 else bb[5])) * sc
		if mirror:
			p.x = -p.x
		p += pos
		if _cam.is_position_behind(p):
			continue
		var s := _cam.unproject_position(p)
		if first:
			r = Rect2(s, Vector2.ZERO)
			first = false
		else:
			r = r.expand(s)
	return r


# --- dist2 --------------------------------------------------------------------------------------------------------

func _dist2(items: Array) -> Image:
	var dists: Array = str(_args.get("dist", "30,100,250,400")).split(",", false)
	var tile := _tile_size()
	var rows: Array = []
	for it: Variant in items:
		rows.append([_spec(str(it)), ""])
		if _args.has("sprite"):
			rows.append([_spec(str(it)), "sprite"])
	var sheet := Image.create(tile.x * dists.size(), tile.y * rows.size(), false, Image.FORMAT_RGB8)
	for r in rows.size():
		var sp: Dictionary = rows[r][0]
		var mid := str(sp["mid"])
		for c in dists.size():
			var d := float(str(dists[c]))
			_clear()
			var lod := str(rows[r][1]) if str(rows[r][1]) != "" else _level_for(mid, d)
			var pos := Vector3(float(sp["x"]), float(sp["h"]), -d)
			var holder := _place(mid, lod, pos, 0.0, float(sp["scale"]), bool(sp["mirror"]) and lod != "sprite")
			var img := await _frame()
			var rect := _rect_scaled(mid, pos, float(sp["scale"]), bool(sp["mirror"]))
			var on := rect.intersects(Rect2(Vector2.ZERO, Vector2(GAME))) and holder != null
			var zmax := int(str(_args.get("zoom", "4")))
			var zoom := clampi(int(floor(minf(float(tile.x) / maxf(8.0, rect.size.x * 1.1), float(tile.y) / maxf(8.0, rect.size.y * 1.1)))), 1, zmax)
			var t := _crop(img, rect.intersection(Rect2(Vector2.ZERO, Vector2(GAME))) if on else Rect2(Vector2(640, 324), Vector2(8, 8)), tile, zoom)
			var what := mid.get_file() if lod != "sprite" else "Arcade-Sprite"
			t = await _caption_tile(t, "%s · %d m voraus, x %.0f m · %s · %d×%s" % [what, int(d), float(sp["x"]), lod, zoom, "" if on else " · außerhalb des Bildes"])
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
			print("SZENE %s %s %d m x %.1f: %.0fx%.0f px" % [mid, lod, int(d), float(sp["x"]), rect.size.x, rect.size.y])
	return sheet


# --- outline2 -----------------------------------------------------------------------------------------------------

func _outline2(items: Array) -> Image:
	_load_sprites()
	var lods: Array = str(_args.get("lods", "lod0,lod1")).split(",", false)
	var ppm := float(str(_args.get("ppm", "20")))
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
	cam.far = 3000.0
	osv.add_child(cam)
	var holder := Node3D.new()
	osv.add_child(holder)
	var tiles: Array[Image] = []
	for it: Variant in items:
		var mid := str(it)
		var sid := _set_of_model(mid)
		var sp: Dictionary = _sprites.get(sid, {})
		if sp.is_empty():
			print("k4_scene: kein Sprite für %s" % mid)
			continue
		var th := deg_to_rad(float(sp.get("elevation_deg", 6.0)))
		var fwd := Vector3(0.0, -sin(th), -cos(th))
		var up := Vector3(0.0, cos(th), -sin(th))
		var vy := float(VIEW_YAW.get(mid.get_file(), 0.0))
		if mid.get_file().begins_with("city_"):   # KRITIK-5a1: props_cities._b() yaw (-20, outskirts houses/crane -24)
			vy = -24.0 if ["city_hanse_crane", "city_german_house"].has(mid.get_file()) else -20.0
		holder.rotation = Vector3(0.0, deg_to_rad(-vy), 0.0)
		var cellpx: Array = sp.get("cell", [64, 64])
		var w := float(sp.get("image_width_m", 1.0))
		var h := w * float(cellpx[1]) / float(cellpx[0])
		var anchor: Array = sp.get("anchor", [0.5, 1.0])
		var px := Vector2i(int(round(w * ppm)), int(round(h * ppm)))
		osv.size = px
		cam.size = w
		var c := -(float(anchor[0]) - 0.5) * w * Vector3.RIGHT - (0.5 - float(anchor[1])) * h * up - 1200.0 * fwd
		cam.look_at_from_position(c, c + fwd, up)
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
		# the sprite itself as the first tile (for the eye)
		var stile := Image.create(px.x, px.y, false, Image.FORMAT_RGB8)
		stile.fill(Color(0.92, 0.92, 0.92))
		var cell8 := cell.duplicate() as Image
		stile.convert(Image.FORMAT_RGBA8)
		stile.blend_rect(cell8, Rect2i(Vector2i.ZERO, px), Vector2i.ZERO)
		stile.convert(Image.FORMAT_RGB8)
		row_tiles.append(stile)
		for lod_v: Variant in lods:
			var lod := str(lod_v)
			for ch: Node in holder.get_children():
				ch.free()
			var node := ModelFactory.build(mid, lod, _mats)
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
			for y in px.y:
				for x in px.x:
					var col := img.get_pixel(x, y)
					var above := float(y) < float(anchor[1]) * float(px.y)
					var mm := above and not (col.r > 0.9 and col.g < 0.1 and col.b > 0.9)
					var ss := above and smask[y * px.x + x] == 1
					if mm:
						m_n += 1
						if ss:
							both += 1
						else:
							out_n += 1
					var o := Color(0.92, 0.92, 0.92)
					if mm and ss:
						o = Color(0.36, 0.58, 0.29)
					elif mm:
						o = Color(0.95, 0.55, 0.1)
					elif ss:
						o = Color(0.55, 0.7, 0.95)
					ov.set_pixel(x, y, o)
			var s_above := 0
			for y in px.y:
				for x in px.x:
					if float(y) < float(anchor[1]) * float(px.y) and smask[y * px.x + x] == 1:
						s_above += 1
			line.append("%s %.1f %% außerhalb, Sprite zu %.1f %% gedeckt (IoU %.3f)" % [lod,
				100.0 * float(out_n) / maxf(1.0, float(m_n)), 100.0 * float(both) / maxf(1.0, float(s_above)),
				float(both) / maxf(1.0, float(m_n + s_above - both))])
			row_tiles.append(ov)
			# the model render too (same camera), for the eye
			var mi := img.duplicate() as Image
			row_tiles.append(mi)
		print("UMRISS %s (Sprite %s, Blick %.0f°, Höhe %.1f°)  %s" % [mid, sid, vy, rad_to_deg(th), "  |  ".join(line)])
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


# --- close --------------------------------------------------------------------------------------------------------

func _close(items: Array, out: String) -> Image:
	var views: Array = str(_args.get("views", "front,oblique,road,roof,back")).split(",", false)
	var half := Vector2i(640, 360)
	var sheet := Image.create(half.x * views.size(), half.y * items.size(), false, Image.FORMAT_RGB8)
	var game_cam := _cam
	var cam := Camera3D.new()
	cam.fov = float(str(_args.get("fov", "40")))
	cam.near = 0.1
	cam.far = 3000.0
	_sv.add_child(cam)
	cam.make_current()
	for r in items.size():
		var sp := _spec(str(items[r]))
		var mid := str(sp["mid"])
		var lod := str(_args.get("lod", "lod0"))
		_clear()
		var pos := Vector3(float(sp["x"]), float(sp["h"]), -float(str(_args.get("at", "40"))))
		_place(mid, lod, pos, 0.0, float(sp["scale"]), bool(sp["mirror"]))
		var m := ModelDB.model(mid)
		var bb: Array = m.get("aabb", [-1, 0, -1, 1, 2, 1])
		var sc := float(sp["scale"])
		var x0 := float(bb[0]) * sc + pos.x
		var x1 := float(bb[3]) * sc + pos.x
		var y1 := float(bb[4]) * sc + pos.y
		var z0 := float(bb[2]) * sc + pos.z
		var z1 := float(bb[5]) * sc + pos.z
		var w := x1 - x0
		var hgt := y1 - pos.y
		var cx := (x0 + x1) * 0.5
		var cz := (z0 + z1) * 0.5
		for c in views.size():
			var v := str(views[c])
			var eye := Vector3.ZERO
			var at := Vector3.ZERO
			match v:
				"front":     # the approach face (+Z), head on
					var d := maxf(w, hgt) * 1.25 + 4.0
					eye = Vector3(cx, pos.y + 1.7, z1 + d)
					at = Vector3(cx, pos.y + hgt * 0.42, z1)
				"oblique":   # the approach face from the road side at a flat angle: depth of reveals, sills, frames
					eye = Vector3(x0 - 2.0, pos.y + 2.5, z1 + maxf(6.0, w * 0.45))
					at = Vector3(x0 + w * 0.55, pos.y + minf(hgt * 0.4, 6.0), z1)
				"road":      # the wall that faces the road (-X), as a driver passing at 3.4 m sees it
					eye = Vector3(x0 - 7.0, pos.y + 3.4, z1 + 8.0)
					at = Vector3(x0, pos.y + minf(hgt * 0.45, 8.0), cz)
				"roof":      # roof covering, eaves, gutters from above the road side
					eye = Vector3(x0 - maxf(8.0, w * 0.6), pos.y + hgt + maxf(6.0, hgt * 0.4), z1 + maxf(8.0, w * 0.6))
					at = Vector3(cx, pos.y + hgt * 0.75, cz)
				"back":      # the face away from the approach (-Z)
					var d2 := maxf(w, hgt) * 1.1 + 4.0
					eye = Vector3(cx - w * 0.35, pos.y + 2.0, z0 - d2)
					at = Vector3(cx, pos.y + hgt * 0.4, z0)
				"far":       # the side away from the road (+X)
					eye = Vector3(x1 + maxf(8.0, w), pos.y + 2.5, z1 + 6.0)
					at = Vector3(x1, pos.y + hgt * 0.4, cz)
				_:
					var p := v.split(":")    # custom: "ex,ey,ez:ax,ay,az" relative to the anchor
					if p.size() == 2:
						var e := p[0].split(",")
						var a := p[1].split(",")
						eye = pos + Vector3(float(e[0]), float(e[1]), float(e[2])) * sc
						at = pos + Vector3(float(a[0]), float(a[1]), float(a[2])) * sc
			cam.look_at_from_position(eye, at, Vector3.UP)
			var img := await _frame()
			img.save_png("%s_%s_%s.png" % [out.get_basename(), mid.get_file(), v.replace(":", "_").replace(",", "_")])
			var small := img.duplicate() as Image
			small.resize(half.x, half.y, Image.INTERPOLATE_LANCZOS)
			small = await _caption_tile(small, "%s · %s · %s" % [mid.get_file(), lod, v if v.length() < 24 else "eigene Ansicht"])
			sheet.blit_rect(small, Rect2i(Vector2i.ZERO, half), Vector2i(c * half.x, r * half.y))
			print("NAH %s %s %s" % [mid, lod, v])
	game_cam.make_current()
	return sheet


# --- approach -----------------------------------------------------------------------------------------------------

func _approach(items: Array, out: String) -> int:
	var sp := _spec(str(items[0]))
	var mid := str(sp["mid"])
	var d0 := float(str(_args.get("from", "400")))
	var d1 := float(str(_args.get("to", "20")))
	var kmh := float(str(_args.get("kmh", "120")))
	var fps := float(str(_args.get("fps", "30")))
	var crop := str(_args.get("crop", ""))       # "x,y,w,h" of the frame to keep (default: whole frame)
	_clear()
	var pos := Vector3(float(sp["x"]), float(sp["h"]), -d0)
	var m := ModelDB.model(mid)
	var holder := Node3D.new()
	holder.position = pos
	var sc := float(sp["scale"])
	holder.scale = Vector3(-sc if bool(sp["mirror"]) else sc, sc, sc)
	_holder.add_child(holder)
	var reps: Array[String] = []
	for l: Variant in m.get("lods", []):
		var n := str((l as Dictionary).get("name", ""))
		if n != "show":
			reps.append(n)
	for rep: String in reps:
		var node := ModelFactory.build(mid, rep, _mats)
		if node == null:
			continue
		node.set_meta(&"rep", rep)
		node.visible = false
		holder.add_child(node)
	var frames := int(ceil((d0 - d1) / (kmh / 3.6) * fps))
	var level := ""
	var t0 := float(str(_args.get("time", "1.7")))
	for f in frames:
		var cz := -kmh / 3.6 * float(f) / fps
		_cam.position = Vector3(0.0, CAM_H, cz)
		_race_update(t0 + float(f) / fps)
		var d := maxf(0.0, cz - pos.z)
		var lv := _level_for(mid, d)
		if level != "" and level != lv and _level_for(mid, maxf(0.0, d - HYST_M)) == level:
			lv = level
		if lv != level:
			level = lv
			for rep: Node in holder.get_children():
				(rep as Node3D).visible = str(rep.get_meta(&"rep", "")) == lv
			print("STUFE %s bei %.1f m: %s (Bild %d)" % [mid, d, lv, f])
		var img := await _frame()
		if crop != "":
			var c := crop.split(",")
			img = img.get_region(Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3])))
		img.save_jpg("%s_%03d.jpg" % [out.get_basename(), f], 0.92)
	return frames


# --- street -------------------------------------------------------------------------------------------------------

func _street(items: Array) -> Image:
	var every := float(str(_args.get("every", "28")))
	var reach := float(str(_args.get("reach", "500")))
	var z := float(str(_args.get("start", "15")))
	var i := 0
	_clear()
	while z < reach:
		var sp := _spec(str(items[i % items.size()]))
		i += 1
		var mid := str(sp["mid"])
		var lod := _level_for(mid, z)
		_place(mid, lod, Vector3(float(sp["x"]), float(sp["h"]), -z), 0.0, float(sp["scale"]), bool(sp["mirror"]))
		var m := ModelDB.model(mid)
		var bb: Array = m.get("aabb", [-1, 0, -1, 1, 2, 1])
		z += maxf(every, (float(bb[5]) - float(bb[2])) * float(sp["scale"]) + 2.0)
	return await _frame()
