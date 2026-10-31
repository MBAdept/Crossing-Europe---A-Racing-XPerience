extends Node
## Autoload "SpriteDB": sprite sheets rendered from Blender (see ARCHITECTURE.md §12 and the vehicle contract
## docs/fahrzeug-darstellung.md). Manifest: res://assets/sprites/manifest.json. One PNG sheet per sprite set,
## all cells of a set have the same size ("cell", px).
##
## Cell layout: cell index i = layer_row * len(angles) + angle_index; column i % grid_cols, row i / grid_cols.
## Without "grid_cols" (old manifests) grid_cols = len(angles): one row per layer, one column per angle.
## "image_width_m" = world width (metres) spanned by one cell -> pixels per metre = cell.x / image_width_m (ortho).
## "anchor" = normalized point inside a cell that touches the ground (rear centre for rear-pivot vehicles,
## projected ground point of the car centre for perspective sets, near face centre for props).
##
## Vehicle extensions (all optional, backward compatible):
##   yaw_deg     yaw per entry of "angles" (array in the same order; a dictionary angle -> degrees is
##               accepted as well). Missing: derived from the names (l2/l1/c/r1/r2 = -25/-12/0/12/25,
##               "l<n>"/"r<n>" = -n/+n degrees).
##   pivot       "rear" | "center" (default: rear for ortho, center for perspective sets)
##   projection  "ortho" (default) | "perspective" (+ "camera" {height_m, distance_m, fov_deg,
##               horizon_y_frac, screen} and "supersample")
##   render      "sprite" (default) | "box": textured boxes ("parts" with faces, "lights" overlays)
## Debug: --sprite-manifest=<path> merges another manifest over the real one (file paths relative to it;
## optional "aliases" {"set id or prefix*": "set id"} re-point existing sets, e.g. to test fixtures).

const MANIFEST_PATH := "res://assets/sprites/manifest.json"
const SPRITE_ROOT := "res://assets/sprites/"
const ANGLE_FALLBACK := {"l2": "l1", "l1": "c", "r2": "r1", "r1": "c"}
## Yaw of the angle names of the first manifest version (5 angles).
const LEGACY_YAW := {"l2": -25.0, "l1": -12.0, "c": 0.0, "r1": 12.0, "r2": 25.0}
const BOX_FACES := ["rear", "left", "right", "top"]

var sets: Dictionary = {}
var overlay_paths: Array[String] = []   ## manifests merged over the real one (debug)
var _textures: Dictionary = {}
var _meta: Dictionary = {}               ## set id -> derived data (see _meta_for)


func _init() -> void:
	reload()


func reload() -> void:
	sets.clear()
	_textures.clear()
	_meta.clear()
	overlay_paths.clear()
	var m: Variant = ConfigLoader.load_json(MANIFEST_PATH)
	if not m is Dictionary:
		push_warning("SpriteDB: kein Manifest gefunden")
	else:
		_add_sets(m, SPRITE_ROOT)
	var extra := CliArgs.get_string("sprite-manifest", "")
	if extra != "":
		merge_manifest(extra)


## Replaces all sets by the ones of the manifest at `path` (tests). File paths are relative to its folder.
func load_manifest(path: String) -> bool:
	sets.clear()
	_textures.clear()
	_meta.clear()
	return merge_manifest(path)


## Merges the sets of another manifest over the loaded ones (same id = replaced) and applies its
## "aliases". Returns false if the file is missing or invalid.
func merge_manifest(path: String) -> bool:
	var m: Variant = ConfigLoader.load_json(path)
	if not m is Dictionary:
		push_warning("SpriteDB: Zusatz-Manifest fehlt oder ist ungültig: " + path)
		return false
	_add_sets(m, path.get_base_dir() + "/")
	var aliases: Dictionary = (m as Dictionary).get("aliases", {})
	for pattern: String in aliases:
		var target := str(aliases[pattern])
		if not sets.has(target):
			push_warning("SpriteDB: Alias-Ziel fehlt: " + target)
			continue
		var ids: Array[String] = []
		if pattern.ends_with("*"):
			ids = ids_with_prefix(pattern.trim_suffix("*"))
		else:
			ids.append(pattern)
		for id in ids:
			if id == target:
				continue
			var s: Dictionary = (sets[target] as Dictionary).duplicate(true)
			s["id"] = id
			s["alias_of"] = target
			if sets.has(id):
				# the re-pointed set keeps its role (traffic, heavy, player, police …)
				s["tags"] = ((sets[id] as Dictionary).get("tags", []) as Array).duplicate()
			sets[id] = s
			_textures.erase(id)
			_meta.erase(id)
	if not overlay_paths.has(path):
		overlay_paths.append(path)
	print("SpriteDB: Zusatz-Manifest geladen: %s (%d Sets)" % [path, ((m as Dictionary).get("sets", {}) as Dictionary).size()])
	return true


func _add_sets(m: Dictionary, root: String) -> void:
	var raw: Dictionary = m.get("sets", {})
	for id: String in raw:
		var s: Dictionary = (raw[id] as Dictionary).duplicate(true)
		s["id"] = id
		s["root"] = root
		if not s.has("angles"):
			s["angles"] = ["c"]
		if not s.has("layers"):
			s["layers"] = ["base"]
		if not s.has("anchor"):
			s["anchor"] = [0.5, 1.0]
		if not s.has("tags"):
			s["tags"] = []
		if not s.has("object"):
			s["object"] = {}
		sets[id] = s
		_textures.erase(id)
		_meta.erase(id)


func has_set(id: String) -> bool:
	return sets.has(id)


func get_set(id: String) -> Dictionary:
	return sets.get(id, {})


func ids_with_tag(tag: String) -> Array[String]:
	var out: Array[String] = []
	for id in sets:
		if (sets[id]["tags"] as Array).has(tag):
			out.append(id)
	out.sort()
	return out


func ids_with_prefix(prefix: String) -> Array[String]:
	var out: Array[String] = []
	for id in sets:
		if (id as String).begins_with(prefix):
			out.append(id)
	out.sort()
	return out


## Lazily loads the sheet texture of a set. Returns null if missing. Sheets that Godot has not imported
## (test fixtures, debug manifests outside the project) are loaded directly from the PNG.
func texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var s := get_set(id)
	var tex: Texture2D = null
	if not s.is_empty():
		var path: String = str(s.get("root", SPRITE_ROOT)) + str(s.get("file", ""))
		if ResourceLoader.exists(path):
			tex = load(path)
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
		else:
			push_warning("SpriteDB: Datei fehlt: " + path)
	_textures[id] = tex
	return tex


func preload_sets(ids: Array) -> void:
	for id in ids:
		texture(id)


func cell_size(id: String) -> Vector2:
	var c: Array = get_set(id).get("cell", [0, 0])
	return Vector2(float(c[0]), float(c[1]))


func has_layer(id: String, layer: String) -> bool:
	return (get_set(id).get("layers", []) as Array).has(layer)


func resolve_angle(id: String, angle: String) -> String:
	var angles: Array = get_set(id).get("angles", ["c"])
	if angles.has(angle) or angles.is_empty():
		return angle if angles.has(angle) else "c"
	# new sets name their angles freely (only "c" is fixed): a legacy name means its yaw
	if LEGACY_YAW.has(angle):
		return str(angles[nearest_angle_index(id, float(LEGACY_YAW[angle]))])
	var a := angle
	while not angles.has(a) and ANGLE_FALLBACK.has(a):
		a = ANGLE_FALLBACK[a]
	return a if angles.has(a) else str(angles[0])


## Source rectangle (pixels) of one cell. Empty Rect2 if the layer does not exist (or for box sets).
func region(id: String, angle: String = "c", layer: String = "base") -> Rect2:
	var s := get_set(id)
	if s.is_empty():
		return Rect2()
	return cell_region(id, (s["angles"] as Array).find(resolve_angle(id, angle)), layer)


## Source rectangle of the cell of angle index `angle_index` (order of "angles") on `layer`.
func cell_region(id: String, angle_index: int, layer: String = "base") -> Rect2:
	var s := get_set(id)
	if s.is_empty() or is_box(id):
		return Rect2()
	var row := (s["layers"] as Array).find(layer)
	var n := (s["angles"] as Array).size()
	if row < 0 or angle_index < 0 or angle_index >= n:
		return Rect2()
	var cs := cell_size(id)
	var gp := cell_grid_pos(row * n + angle_index, grid_cols(id))
	return Rect2(float(gp.x) * cs.x, float(gp.y) * cs.y, cs.x, cs.y)


## Column/row of cell index i in a sheet with `cols` cells per row (contract §1).
static func cell_grid_pos(i: int, cols: int) -> Vector2i:
	var c := maxi(1, cols)
	return Vector2i(i % c, i / c)


func grid_cols(id: String) -> int:
	return int(_meta_for(id).get("grid_cols", 1))


func pixels_per_meter(id: String) -> float:
	var s := get_set(id)
	var w := float(s.get("image_width_m", 1.0))
	return cell_size(id).x / max(w, 0.001)


func anchor(id: String) -> Vector2:
	var a: Array = get_set(id).get("anchor", [0.5, 1.0])
	return Vector2(float(a[0]), float(a[1]))


## Physical object size in metres: {"width_m", "length_m", "height_m"} (may be partial).
func object_size(id: String) -> Dictionary:
	return get_set(id).get("object", {})


# --- vehicle extensions (docs/fahrzeug-darstellung.md) ----------------------------------------

## Yaw (degrees, + = turned right) of every entry of "angles", in that order.
func yaw_list(id: String) -> PackedFloat32Array:
	return _meta_for(id).get("yaws", PackedFloat32Array())


func angle_count(id: String) -> int:
	return (get_set(id).get("angles", []) as Array).size()


## Index (order of "angles") of the cell whose yaw is closest to yaw_deg.
func nearest_angle_index(id: String, yaw_deg: float) -> int:
	return nearest_yaw_index(yaw_list(id), yaw_deg)


## "ortho" or "perspective".
func projection(id: String) -> String:
	return str(_meta_for(id).get("projection", "ortho"))


## "rear" (rotation about the rear centre = anchor) or "center" (rotation about the vehicle centre).
func pivot(id: String) -> String:
	return str(_meta_for(id).get("pivot", "rear"))


## "sprite" or "box".
func render_mode(id: String) -> String:
	return str(_meta_for(id).get("render", "sprite"))


func is_box(id: String) -> bool:
	return render_mode(id) == "box"


## Perspective sets: the camera the cells were rendered with ({height_m, distance_m, fov_deg, horizon_y_frac,
## screen}); {} for ortho sets.
func camera(id: String) -> Dictionary:
	var c: Variant = get_set(id).get("camera", {})
	return c if c is Dictionary else {}


## Perspective sets: factor by which the cells are rendered larger than they appear in the game.
func supersample(id: String) -> float:
	return float(_meta_for(id).get("supersample", 1.0))


## Box sets: parts with float extents relative to the vehicle centre (z along, + = front; x across,
## + = right; y height) and their face rectangles: [{name, z0, z1, x0, x1, y0, y1, faces: {face: Rect2}}].
func box_parts(id: String) -> Array:
	return _meta_for(id).get("parts", [])


## Box sets: light overlays {"tail": [{part (index), face, rect: Rect2}], "brake": [...]}.
func box_lights(id: String) -> Dictionary:
	return _meta_for(id).get("lights", {})


## Derived per-set data, computed once.
func _meta_for(id: String) -> Dictionary:
	var c: Variant = _meta.get(id)
	if c != null:
		return c
	var s := get_set(id)
	var meta := derive_meta(s)
	_meta[id] = meta
	return meta


## Normalised vehicle metadata of one manifest set (static: unit tests, tools).
static func derive_meta(s: Dictionary) -> Dictionary:
	var angles: Array = s.get("angles", ["c"])
	var proj := str(s.get("projection", "ortho"))
	if proj != "perspective":
		proj = "ortho"
	var piv := str(s.get("pivot", "center" if proj == "perspective" else "rear"))
	if piv != "center":
		piv = "rear"
	var mode := str(s.get("render", "sprite"))
	if mode != "box":
		mode = "sprite"
	var meta := {
		"yaws": parse_yaws(s),
		"grid_cols": maxi(1, int(s.get("grid_cols", maxi(1, angles.size())))),
		"projection": proj,
		"pivot": piv,
		"render": mode,
		"supersample": maxf(0.01, float(s.get("supersample", 1.0))) if proj == "perspective" else 1.0,
	}
	if mode == "box":
		meta["parts"] = parse_parts(s)
		meta["lights"] = parse_lights(s, meta["parts"])
	return meta


## Yaw per angle (degrees) from "yaw_deg" (array in "angles" order or dictionary name -> degrees) or the names.
static func parse_yaws(s: Dictionary) -> PackedFloat32Array:
	var angles: Array = s.get("angles", ["c"])
	var out := PackedFloat32Array()
	out.resize(angles.size())
	var y: Variant = s.get("yaw_deg", null)
	for i in angles.size():
		var name := str(angles[i])
		var v := name_yaw(name)
		if y is Array and i < (y as Array).size():
			v = float((y as Array)[i])
		elif y is Dictionary and (y as Dictionary).has(name):
			v = float((y as Dictionary)[name])
		out[i] = v
	return out


## Yaw implied by an angle name: legacy l2/l1/c/r1/r2, else "l<n>" / "r<n>" = -n / +n degrees, else 0.
static func name_yaw(name: String) -> float:
	if LEGACY_YAW.has(name):
		return float(LEGACY_YAW[name])
	if name.length() > 1 and (name[0] == "l" or name[0] == "r") and name.substr(1).is_valid_float():
		return (-1.0 if name[0] == "l" else 1.0) * name.substr(1).to_float()
	return 0.0


## Index of the yaw closest to yaw_deg (first one on ties); -1 for an empty list.
static func nearest_yaw_index(yaws: PackedFloat32Array, yaw_deg: float) -> int:
	var best := -1
	var best_d := INF
	for i in yaws.size():
		var d := absf(yaws[i] - yaw_deg)
		if d < best_d:
			best_d = d
			best = i
	return best


static func parse_parts(s: Dictionary) -> Array:
	var out: Array = []
	for p: Variant in s.get("parts", []):
		if not p is Dictionary:
			continue
		var d: Dictionary = p
		var z: Array = d.get("z", [0.0, 0.0])
		var x: Array = d.get("x", [0.0, 0.0])
		var y: Array = d.get("y", [0.0, 0.0])
		var faces := {}
		var fr: Dictionary = d.get("faces", {})
		for f: String in BOX_FACES:
			if fr.get(f, null) is Array and (fr[f] as Array).size() >= 4:
				var r: Array = fr[f]
				faces[f] = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		out.append({"name": str(d.get("name", "part%d" % out.size())),
			"z0": minf(float(z[0]), float(z[1])), "z1": maxf(float(z[0]), float(z[1])),
			"x0": minf(float(x[0]), float(x[1])), "x1": maxf(float(x[0]), float(x[1])),
			"y0": minf(float(y[0]), float(y[1])), "y1": maxf(float(y[0]), float(y[1])),
			"faces": faces})
	return out


static func parse_lights(s: Dictionary, parts: Array) -> Dictionary:
	var out := {}
	var raw: Dictionary = s.get("lights", {})
	for kind: String in raw:
		var arr: Array = []
		for l: Variant in raw[kind]:
			if not l is Dictionary:
				continue
			var d: Dictionary = l
			var r: Array = d.get("rect", [])
			var pi := -1
			for i in parts.size():
				if str((parts[i] as Dictionary)["name"]) == str(d.get("part", "")):
					pi = i
			if pi < 0 or r.size() < 4:
				continue
			arr.append({"part": pi, "face": str(d.get("face", "rear")), "rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))})
		out[kind] = arr
	return out
