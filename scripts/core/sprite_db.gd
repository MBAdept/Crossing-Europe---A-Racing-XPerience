extends Node
## Autoload "SpriteDB": sprite sheets rendered from Blender (see ARCHITECTURE.md §Sprites).
## Manifest: res://assets/sprites/manifest.json. One PNG sheet per sprite set:
## columns = angles, rows = layers; every cell has the same size ("cell", px).
## "image_width_m" = world width (metres) spanned by one cell -> pixels per metre = cell.x / image_width_m.
## "anchor" = normalized point inside a cell that touches the ground (object centre, near face).

const MANIFEST_PATH := "res://assets/sprites/manifest.json"
const SPRITE_ROOT := "res://assets/sprites/"
const ANGLE_FALLBACK := {"l2": "l1", "l1": "c", "r2": "r1", "r1": "c"}

var sets: Dictionary = {}
var _textures: Dictionary = {}


func _init() -> void:
	reload()


func reload() -> void:
	sets.clear()
	_textures.clear()
	var m: Variant = ConfigLoader.load_json(MANIFEST_PATH)
	if not m is Dictionary:
		push_warning("SpriteDB: kein Manifest gefunden")
		return
	var raw: Dictionary = m.get("sets", {})
	for id in raw:
		var s: Dictionary = raw[id].duplicate(true)
		s["id"] = id
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


## Lazily loads the sheet texture of a set. Returns null if missing.
func texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var s := get_set(id)
	var tex: Texture2D = null
	if not s.is_empty():
		var path: String = SPRITE_ROOT + str(s.get("file", ""))
		if ResourceLoader.exists(path):
			tex = load(path)
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
	var a := angle
	while not angles.has(a) and ANGLE_FALLBACK.has(a):
		a = ANGLE_FALLBACK[a]
	return a if angles.has(a) else str(angles[0])


## Source rectangle (pixels) of one cell. Empty Rect2 if the layer does not exist.
func region(id: String, angle: String = "c", layer: String = "base") -> Rect2:
	var s := get_set(id)
	if s.is_empty():
		return Rect2()
	var layers: Array = s["layers"]
	var row := layers.find(layer)
	if row < 0:
		return Rect2()
	var col := (s["angles"] as Array).find(resolve_angle(id, angle))
	var cs := cell_size(id)
	return Rect2(col * cs.x, row * cs.y, cs.x, cs.y)


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
