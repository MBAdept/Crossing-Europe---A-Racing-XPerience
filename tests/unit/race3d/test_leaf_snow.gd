extends TestCase
## QA-mid (Q-02): snow on the crowns of the mode "Modern" (assets/shaders/modern/leaves.gdshader). Under the snow law
## of the leaves – smoothstep(0.35, 0.85, up) × 0.85 of the albedo, up = the card's crown normal – a crown whose cards
## nearly all face up turned white as a whole (the spruce: 0.68 of its area; Arcade's spruce stays dark green in snow).
## ModernMaterials.LEAF_SNOW_CARDS gives such leaf textures a share of snowy patches; every leaves mesh of the catalogue,
## measured headless over its area, keeps its mean snow at most ModernMaterials.LEAF_SNOW_MAX (a crown with a share at
## about LEAF_SNOW_MEAN) – a new model whose crown would turn white fails here until it has its entry. Ground cover may turn white (snow lies on the grass).

const GROUND_COVER: Array[String] = ["cover_grass", "heather"]
const SLACK := 0.03


## Area-weighted mean of the snow law over the leaves surfaces of a mesh.
static func _mean_snow(mesh: Mesh, classes: Array) -> float:
	var tot := 0.0
	var ks := 0.0
	for s in mesh.get_surface_count():
		var cls := str(mesh.surface_get_name(s))
		if cls == "" and s < classes.size():
			cls = str(classes[s])
		if cls != "leaves":
			continue
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in idx.size() / 3:
			var a := v[idx[t * 3]]
			var area := (v[idx[t * 3 + 1]] - a).cross(v[idx[t * 3 + 2]] - a).length() * 0.5
			var up := (n[idx[t * 3]].y + n[idx[t * 3 + 1]].y + n[idx[t * 3 + 2]].y) / 3.0
			tot += area
			ks += smoothstep(0.35, 0.85, up) * 0.85 * area
	return ks / tot if tot > 0.0 else 0.0


func test_no_crown_turns_white() -> void:
	var dir := DirAccess.open("res://assets/models/props")
	assert_true(dir != null, "Modellordner da")
	var checked := 0
	var shared := 0
	for d in dir.get_directories():
		var mp := "res://assets/models/props/%s/model.json" % d
		if not FileAccess.file_exists(mp) or GROUND_COVER.has(d):
			continue
		var model: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(mp)) as Dictionary).get("model", {})
		var tex := str((model.get("textures", {}) as Dictionary).get("leaves", ""))
		if tex == "":
			continue
		var share := float(ModernMaterials.LEAF_SNOW_CARDS.get(tex, 1.0))
		if share < 1.0:
			shared += 1
		for lod: Dictionary in model.get("lods", []):
			for part: Dictionary in lod.get("parts", []):
				var mesh: Mesh = load("res://assets/models/" + str(part["mesh"]))
				var mean := _mean_snow(mesh, part.get("classes", []))
				assert_true(mean * share <= ModernMaterials.LEAF_SNOW_MAX,
					"%s %s: Schnee im Mittel %.2f × Anteil %.2f = %.2f ≤ %.2f" % [d, lod["name"], mean, share, mean * share,
					ModernMaterials.LEAF_SNOW_MAX])
				checked += 1
	assert_true(checked >= 30, "alle Blätternetze des Katalogs gemessen (%d)" % checked)
	assert_true(shared >= 3, "Fichte (2) und Palme haben einen Anteil (%d Modelle)" % shared)


## The shares are only for crowns that need them: a crown that carries caps on its own (oak, pine …) keeps every card.
func test_shares_only_where_needed() -> void:
	for tex: String in ModernMaterials.LEAF_SNOW_CARDS:
		var d := tex.get_slice("/", 1)
		var model: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/props/%s/model.json" % d)) as Dictionary).get("model", {})
		var lod0: Dictionary = (model.get("lods", []) as Array)[0]
		var part: Dictionary = (lod0.get("parts", []) as Array)[0]
		var mean := _mean_snow(load("res://assets/models/" + str(part["mesh"])), part.get("classes", []))
		var share := float(ModernMaterials.LEAF_SNOW_CARDS[tex])
		assert_true(mean > ModernMaterials.LEAF_SNOW_MAX, "%s braucht einen Anteil (Mittel %.2f)" % [d, mean])
		assert_true(absf(mean * share - ModernMaterials.LEAF_SNOW_MEAN) <= SLACK,
			"%s: mit Anteil im Mittel %.2f ≈ %.2f" % [d, mean * share, ModernMaterials.LEAF_SNOW_MEAN])


## The material of a leaf texture carries its share (others 1), and the shader has the uniform.
func test_material_carries_the_share() -> void:
	var mats := ModernMaterials.new()
	var spruce := mats.material("leaves", {"textures": {"leaves": "props/tree_spruce/leaves.png"}}) as ShaderMaterial
	var oak := mats.material("leaves", {"textures": {"leaves": "props/tree_oak/leaves.png"}}) as ShaderMaterial
	assert_eq(float(spruce.get_shader_parameter("snow_cards")), float(ModernMaterials.LEAF_SNOW_CARDS["props/tree_spruce/leaves.png"]), "Fichte: Anteil")
	assert_eq(float(oak.get_shader_parameter("snow_cards")), 1.0, "Eiche: jede Karte")
	var names := []
	for u: Dictionary in spruce.shader.get_shader_uniform_list():
		names.append(str(u["name"]))
	assert_true(names.has("snow_cards"), "leaves.gdshader hat snow_cards")
	ModernMaterials.drop_shared()
