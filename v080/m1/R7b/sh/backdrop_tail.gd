

# --- skyline (R7b) -------------------------------------------------------------------------------------------------

## The skyline silhouettes of this frame for RaceBackdrop.landmarks: Arcade's RoadRenderer._skyline_silhouettes –
## only inside the City Limits (the camera's ground point), each faded out while its landmark is within the landmark
## range (smoothstep(L, 1.15 L, its distance)), anchored to the panorama when first seen. heading = the panorama angle
## of the screen centre (the road's angle at the car plus the camera's yaw against it).
func skyline(view: Dictionary, heading: float) -> Array:
	_sky_list = []
	_sky_sig = []
	var track: Track = _renderer.get("track") if _renderer != null else null
	var proj: RoadProjection = _renderer.get("proj") if _renderer != null else null
	if track == null or track.plan == null or proj == null:
		return []
	var sky: Array[Dictionary] = track.plan.skyline
	var cam_z := float(view.get("camera_z", 0.0))
	if sky.is_empty() or not track.is_city_at(cam_z + proj.cam_distance):
		return []
	var vis := float(view.get("visibility_m", _draw_distance))
	var l := clampf(vis * _lm_law.x, minf(vis, 600.0), maxf(_lm_law.y, vis))
	var out: Array = []
	for i in sky.size():
		var e: Dictionary = sky[i]
		var a := 1.0
		var prop_km := float(e.get("prop_km", -1.0))
		var dz := 0.0
		if prop_km >= 0.0:
			dz = track.km_to_z(prop_km) - cam_z
			a = smoothstep(l, l * 1.15, dz) if dz > 0.0 else 0.0
		if a <= 0.01:
			continue
		if not _sky_anchor.has(i):
			_sky_anchor[i] = heading + skyline_offset(i, e, dz, track)
		out.append({"entry": e, "angle": float(_sky_anchor[i]), "alpha": a, "s": sky_proj.focal / _sky_dist})
		_sky_list.append({"set": str(e.get("set", "")), "angle": snappedf(float(_sky_anchor[i]), 0.0001), "alpha": snappedf(a, 0.001),
			"x": snappedf(sky_proj.screen.x * 0.5 - MARGIN + RaceBackdrop.wrap_angle(float(_sky_anchor[i]) - heading) * sky_proj.focal, 0.1)})
		_sky_sig.append(snappedf(a, 0.015))
		_sky_sig.append(i)
	return out


## Panorama offset of skyline entry i against the screen centre when it is first seen (RoadRenderer._skyline_offset):
## its azimuth_deg if given; for one that also stands on the road as a landmark the true direction of that landmark
## from the camera (its anchor on the path, against the camera's axis); else Arcade's fixed offsets.
func skyline_offset(i: int, e: Dictionary, dz: float, track: Track) -> float:
	var az := float(e.get("azimuth_deg", NAN))
	if not is_nan(az):
		return deg_to_rad(az)
	if dz > 0.0:
		var cam: Camera3D = _renderer.get("camera") if _renderer != null else null
		var path: Variant = _renderer.get("path") if _renderer != null else null
		if cam != null and path is RoadPath3D and (path as RoadPath3D).is_ready():
			for it: Dictionary in track.landmarks:
				if str(it["set"]) != str(e["set"]):
					continue
				var z := float(it["z"])
				var k := int(floor(z / track.seg_len))
				if not ((path as RoadPath3D).has(k) and (path as RoadPath3D).has(k + 1)):
					break
				var x := float(it.get("x", 0.0))
				if it.has("proc"):
					x += float(int(it.get("side", 1))) * float(it.get("width_m", 30.0)) * 0.5 * float(it.get("scale", 1.0))
				var t := cam.global_transform if cam.is_inside_tree() else cam.transform
				var local := t.affine_inverse() * (path as RoadPath3D).world(z, x, 0.0)
				return atan2(local.x, -local.z)
	return RoadRenderer.SKY_OFFSETS[i % RoadRenderer.SKY_OFFSETS.size()]


## RaceBackdrop.sprite_cb: one skyline silhouette standing on the panorama base line at pos (s = px per m) – Arcade's
## RoadRenderer._draw_skyline_landmark: the "c" cell of its sprite × the ambient light towards the fog × 1.15 by the
## haze, tinted, with its light layer at night; or Arcade's procedural silhouette.
func _draw_skyline_landmark(entry: Dictionary, pos: Vector2, s: float, alpha: float, haze: float) -> void:
	var p := _painter()
	var pc: Array = p.call(&"_prep_prop", entry)
	var amb: Color = _pal.get("ambient", Color.WHITE)
	var lights := float(_pal.get("lights", 0.0)) * alpha
	p.set(&"_amb_out", amb)
	p.set(&"_fog_outc", _fog)
	p.set(&"_lm_amb", amb)
	p.set(&"_lm_haze", haze)
	p.set(&"_lm_alpha", alpha)
	p.set(&"_time", _time)
	var info: Array = pc[1]
	var anchor := Vector3(pos.x, pos.y, s)
	if not info.is_empty():
		var tint: Color = pc[5]
		var mod := Color(amb.r, amb.g, amb.b).lerp(_fog * 1.15, haze)
		_sky_cell(info, "base", anchor, float(pc[2]), Color(mod.r * tint.r, mod.g * tint.g, mod.b * tint.b, alpha))
		if lights > 0.02 and (info[RoadRenderer.SI_ROWS] as Dictionary).has("lights"):
			_sky_cell(info, "lights", anchor, float(pc[2]), Color(1, 1, 1, lights))
	elif str(pc[4]) != "":
		p.call(&"_draw_landmark_proc", str(pc[4]), entry, anchor, lights)


## Draws the "c" cell of `layer` of a sprite (Arcade's info array) with its anchor at p (x, y, px per m) into this
## canvas – RoadRenderer._sprite_cell, but onto the backdrop's canvas item.
func _sky_cell(info: Array, layer: String, p: Vector3, scale: float, modulate: Color) -> void:
	var row := int((info[RoadRenderer.SI_ROWS] as Dictionary).get(layer, -1))
	if row < 0:
		return
	var cell: Vector2 = info[RoadRenderer.SI_CELL]
	var w := cell.x / float(info[RoadRenderer.SI_PPM]) * p.z * scale
	var h := w * cell.y / cell.x
	if w < 0.8:
		return
	var dest := RoadRenderer.sprite_dest(Vector2(p.x, p.y), w, h, info[RoadRenderer.SI_ANCHOR], false)
	if dest.position.x > sky_proj.screen.x + 4.0 or dest.end.x < -4.0:
		return
	var ai := int((info[RoadRenderer.SI_COLS] as Dictionary).get("c", 0))
	var tex: Texture2D = info[RoadRenderer.SI_TEX]
	batch.flush()
	RenderingServer.canvas_item_add_texture_rect_region(canvas.get_canvas_item(), dest, tex.get_rid(),
		RoadRenderer.cell_src(info, ai, row), modulate)
