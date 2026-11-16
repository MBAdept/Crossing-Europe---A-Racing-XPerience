extends "res://tools/kritik/k4_scene.gd"
## AS4R scratch tool (never committed): --mode=sparkcam - like kritik_scene's sparkle (sub-pixel steps, share of the
## model's pixels that toggle per step) but the CAMERA moves sideways and the model stands still. Moving the model
## changes the rotor phase of a windmill (vpbr: angle = ce_time x speed + world x x 0.37 rad/m): the sails turn by
## 0.016 rad per quarter-pixel step at 120 m - the art review's "flicker" of the mill was mostly that turn.


func _run() -> void:
	if str(_args.get("mode", "")) != "sparkcam":
		super._run()
		return
	var out := str(_args.get("out", ""))
	if not _load_manifest_with_model_sets():
		quit(1)
		return
	_mats = ModernMaterials.new()
	_build_rig()
	var models: Array = str(_args["models"]).split(",", false)
	var img := await _sparkcam(models)
	var err := img.save_png(out)
	print("my_scene: sparkcam -> %s%s" % [out, "" if err == OK else "  FEHLER %d" % err])
	quit(0 if err == OK else 1)


func _sparkcam(models: Array) -> Image:
	var dists: Array = str(_args.get("dists", "60,120,250,400")).split(",", false)
	var x0 := float(str(_args.get("x", "20")))
	var steps := int(str(_args.get("steps", "8")))
	var thr := float(str(_args.get("thr", "0.2")))
	var sub := float(str(_args.get("sub", "0.25")))
	var tile := _tile_size()
	var rows: Array = []
	for m: Variant in models:
		rows.append([str(m), ""])
		if _args.has("sprite"):
			rows.append([str(m), "sprite"])
	var sheet := Image.create(tile.x * dists.size(), tile.y * rows.size(), false, Image.FORMAT_RGB8)
	for r in rows.size():
		var mid := str(rows[r][0])
		var res: Array[String] = []
		for c in dists.size():
			var d := float(str(dists[c]))
			var lod := str(rows[r][1]) if str(rows[r][1]) != "" else _level_for(mid, d)
			var step_m := d / FOCAL_PX * sub
			var frames: Array = []
			var bgs: Array = []
			var pos := Vector3(x0, 0.0, -d)
			var rect := Rect2()
			for k in steps:
				_cam.position = Vector3(-step_m * float(k), CAM_H, 0.0)
				_clear()
				bgs.append(await _frame())
				_place(mid, lod, pos)
				frames.append(await _frame())
				rect = _screen_rect(mid, pos) if k == 0 else rect.merge(_screen_rect(mid, pos))
			_cam.position = Vector3(0.0, CAM_H, 0.0)
			if _args.has("dump"):
				for k in mini(3, steps):
					(frames[k] as Image).save_png("%s_%s_%d_%d.png" % [str(_args["dump"]), mid.get_file(), int(d), k])
			var rr := Rect2i(rect.grow(2.0)).intersection(Rect2i(Vector2i.ZERO, GAME))
			var tog := 0.0
			var area := 0.0
			for k in steps - 1:
				var ia: Image = frames[k]
				var ib: Image = frames[k + 1]
				var ga: Image = bgs[k]
				var gb: Image = bgs[k + 1]
				var nt := 0
				var na := 0
				for y in range(rr.position.y, rr.end.y):
					for xx in range(rr.position.x, rr.end.x):
						var ca := ia.get_pixel(xx, y)
						var cb := ib.get_pixel(xx, y)
						var g1 := ga.get_pixel(xx, y)
						var g2 := gb.get_pixel(xx, y)
						var in_a := absf(ca.r - g1.r) + absf(ca.g - g1.g) + absf(ca.b - g1.b) > 0.03
						var in_b := absf(cb.r - g2.r) + absf(cb.g - g2.g) + absf(cb.b - g2.b) > 0.03
						if not (in_a or in_b):
							continue
						na += 1
						if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > thr:
							nt += 1
				tog += float(nt)
				area += float(na)
			var share := 100.0 * tog / maxf(1.0, area)
			# contrast against the background in the first frame: mean of (r + g + b) / 3 difference over the model's pixels
			var csum := 0.0
			var cn := 0
			var f0: Image = frames[0]
			var b0: Image = bgs[0]
			for y in range(rr.position.y, rr.end.y):
				for xx in range(rr.position.x, rr.end.x):
					var ca := f0.get_pixel(xx, y)
					var cg := b0.get_pixel(xx, y)
					var dd := (absf(ca.r - cg.r) + absf(ca.g - cg.g) + absf(ca.b - cg.b)) / 3.0
					if dd * 3.0 > 0.03:
						csum += dd
						cn += 1
			res.append("%d m %s: %.1f %% Pixel kippen je Schritt (%d px Fläche), Kontrast %.0f über %d px" % [int(d), lod, share,
				int(area / maxf(1.0, float(steps - 1))), 255.0 * csum / maxf(1.0, float(cn)), cn])
			var zoom := _zoom_for(rect, tile, 8)
			var t := _crop(frames[0], rect, tile, zoom)
			t = await _caption_tile(t, "%s · %s · %d m · %.1f %% kippen (Kamera)" % [mid if lod != "sprite" else "Sprite", lod, int(d), share])
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
		print("FLIMMER %s %s  %s" % [mid, str(rows[r][1]), "  |  ".join(res)])
	return sheet
