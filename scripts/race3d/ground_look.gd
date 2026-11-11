class_name GroundLook
extends RefCounted
## Mode "Modern" (v0.8.0), package terrain / props / far ground: what the ground looks like – shared by the terrain
## builder (builders/terrain.gd) and the far-ground layer (layers/far_ground.gd), so that the ribbon and the plane
## beyond it show the same colours and the same pattern. Pure static helpers; nothing here touches the simulation.
##
##  * style(scenery_id, scenery): the look of a scenery's ground beyond the verge – "accent" (colour of the patches:
##    grain fields, heather, rock, dry earth …), "amount" (how much of the ground the patches take, 0..1) and
##    "nature" (1 = vegetation with verge, ditch and field structure, 0 = the paved ground of a city centre).
##    data/scenery.json is frozen and only knows the two grass tones; the table STYLES below adds the rest and
##    graphics.modern.terrain.styles (optional, {"<scenery id>": {"accent": "#rrggbb", "amount": 0.4, "nature": 1}})
##    overrides it.
##  * grass(scenery, band): the two grass tones of data/scenery.json (Arcade's alternating bands).
##  * noise_texture(): the tiling detail texture of the ground shaders, generated when first asked for and kept while
##    a material uses it (no file):
##    r = fine grain, g = soft blotches, b = cell value of a Voronoi pattern (the "fields"), a = distance to the
##    border of that cell.
##  * far_look(track, scenery_db, z, …): the ground far away around road position z – the mean tone and style of the
##    sceneries ahead (16 samples, so it changes in small steps along the road).
## Docs: docs/renderer-modern-gelaende.md.

const NOISE_SIZE := 256
const DEFAULT_GRASS: Array[String] = ["#5d9a3e", "#56913a"]
const FAR_SAMPLES := 16
const FAR_STEP_M := 48.0
const FAR_BEHIND_M := 96.0
const GROUND_BLEND_M := 150.0      ## = RoadRenderer.GROUND_BLEND_M (pinned by tests/unit/race3d/test_terrain_builder.gd)
## Scenery id -> [accent colour, amount]. Rural sceneries; cities are derived in style().
const STYLES := {
	"north_plain": ["#b5ad4c", 0.42], "heath": ["#8b637c", 0.5], "forest_hills": ["#3e6c33", 0.36],
	"rhine_main": ["#bdb058", 0.4], "industrial": ["#8c8668", 0.36], "polder": ["#86b850", 0.4],
	"ardennes": ["#3f6e34", 0.36], "farmland_fr": ["#c9b55c", 0.55], "loire": ["#bfb260", 0.42],
	"pyrenees": ["#8f8b7a", 0.4], "meseta": ["#a38a54", 0.5], "mediterranean": ["#ad9a60", 0.45],
	"alps": ["#8e9388", 0.3], "lombardy": ["#b4b054", 0.45], "karst": ["#a7a59a", 0.5],
	"balkan_hills": ["#aca352", 0.4], "pannonian_plain": ["#c4b55e", 0.55], "bohemian": ["#afa954", 0.36],
	"east_plain": ["#b6aa58", 0.45], "baltic_forest": ["#466a36", 0.3], "coast": ["#cbc49a", 0.45],
}

static var _noise: WeakRef = null            ## the texture lives as long as a material uses it
static var _far_key: Array = []
static var _far_hit: Dictionary = {}


## Look of a scenery's ground: {"accent": Color, "amount": float, "nature": float}. `overrides` =
## graphics.modern.terrain.styles (may be empty).
static func style(scenery_id: String, scenery: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var g0 := grass(scenery, 0)
	var accent := g0.lightened(0.12)
	var amount := 0.3
	var nature := 1.0
	if STYLES.has(scenery_id):
		var e: Array = STYLES[scenery_id]
		accent = Color(str(e[0]))
		amount = float(e[1])
	elif scenery_id == "city" or scenery_id.ends_with("_center"):
		# paved ground between the houses: slabs in a second tone of the same grey
		accent = g0.darkened(0.14)
		amount = 0.35
		nature = 0.0
	elif scenery_id.begins_with("city"):
		# gardens of the outskirts: lawns, a little lighter and yellower than the grass
		accent = g0.lerp(Color("a9b86a"), 0.45)
		amount = 0.3
	var o: Variant = overrides.get(scenery_id)
	if o is Dictionary:
		var od: Dictionary = o
		if od.has("accent"):
			accent = Color(str(od["accent"]))
		amount = float(od.get("amount", amount))
		nature = float(od.get("nature", nature))
	return {"accent": accent, "amount": clampf(amount, 0.0, 1.0), "nature": clampf(nature, 0.0, 1.0)}


## Grass tone `band` (0 | 1) of a scenery entry of data/scenery.json.
static func grass(scenery: Dictionary, band: int) -> Color:
	var g: Variant = scenery.get("grass", DEFAULT_GRASS)
	if not (g is Array) or (g as Array).is_empty():
		g = DEFAULT_GRASS
	var list: Array = g
	return Color(str(list[mini(band, list.size() - 1)]))


## Mean of the two grass tones.
static func grass_mean(scenery: Dictionary) -> Color:
	return grass(scenery, 0).lerp(grass(scenery, 1), 0.5)


## Colour of the water under a bridge (city sceneries name it, the others take a default).
static func water(scenery: Dictionary) -> Color:
	return Color(str(scenery.get("water", "#4b6878")))


## Ground tone of one segment (plain data of ChunkContext.segs or the fields of a TrackSegment) as the terrain shows
## it away from the verge: the mean grass tone of its scenery, inside the City Limits blended from the outskirts into
## the centre like Arcade's ground (ground_blend()). city = {"center_z", "center", "outskirts"}.
static func ground_tone(scenery_id: String, is_city: bool, z: float, scenery_db: Dictionary, city: Dictionary) -> Color:
	var c := grass_mean(_dict(scenery_db.get(scenery_id)))
	var center := str(city.get("center", ""))
	if is_city and center != "" and scenery_id == str(city.get("outskirts", "")):
		var f := ground_blend(z, float(city.get("center_z", 0.0)))
		if f > 0.0:
			c = c.lerp(grass_mean(_dict(scenery_db.get(center))), f)
	return c


## Share of the centre ground in the outskirts ground at z – Arcade's law (RoadRenderer.ground_blend, repeated here
## so that the builders do not pull the Arcade renderer onto their worker threads).
static func ground_blend(z: float, center_z: float) -> float:
	if center_z <= 0.0 or z >= center_z:
		return 0.0
	return smoothstep(center_z - GROUND_BLEND_M, center_z, z)


## What ground_tone() needs to know about the city of a stage (main thread: reads the plan).
static func city_info(track: Track) -> Dictionary:
	if track == null or track.plan == null:
		return {"center_z": 0.0, "center": "", "outskirts": ""}
	var plan := track.plan
	return {"center_z": track.km_to_z(plan.city_center_km), "center": plan.city_scenery_center,
		"outskirts": plan.city_scenery_outskirts}


## The ground far away around road position z (main thread: reads the track): {"color", "accent": Color, "amount",
## "nature": float} – the mean of ground_tone() and of the styles over FAR_SAMPLES points from FAR_BEHIND_M behind z to
## about 670 m ahead, so it changes in small steps along the road. Water does not count (a bridge is short).
## The last answer is kept (the terrain builder and the far-ground layer ask for the same row in the same frame).
static func far_look(track: Track, scenery_db: Dictionary, z: float, city: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var row := int(floor(z / track.seg_len))
	if _far_key == [track.get_instance_id(), row]:
		return _far_hit
	var col := Vector3.ZERO
	var acc := Vector3.ZERO
	var amount := 0.0
	var nature := 0.0
	var n := 0
	var last := track.segment_count - 1
	for i in FAR_SAMPLES:
		var zi := z - FAR_BEHIND_M + float(i) * FAR_STEP_M
		var k := clampi(int(floor(zi / track.seg_len)), 0, last)
		var s := track.get_segment(k)
		if s == null or s.index != k:
			continue
		var c := ground_tone(s.scenery, s.city, s.z, scenery_db, city)
		var st := style_at(s.scenery, s.city, s.z, scenery_db, city, overrides)
		var a: Color = st["accent"]
		col += Vector3(c.r, c.g, c.b)
		acc += Vector3(a.r, a.g, a.b)
		amount += float(st["amount"])
		nature += float(st["nature"])
		n += 1
	var out := {"color": Color(DEFAULT_GRASS[0]), "accent": Color("b5ad4c"), "amount": 0.4, "nature": 1.0}
	if n > 0:
		var f := 1.0 / float(n)
		out = {"color": Color(col.x * f, col.y * f, col.z * f), "accent": Color(acc.x * f, acc.y * f, acc.z * f),
			"amount": amount * f, "nature": nature * f}
	_far_key = [track.get_instance_id(), row]
	_far_hit = out
	return out


## Style of the ground of one segment: style() of its scenery, inside the City Limits blended from the outskirts into
## the centre with the same law as the ground tone.
static func style_at(scenery_id: String, is_city: bool, z: float, scenery_db: Dictionary, city: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var st := style(scenery_id, _dict(scenery_db.get(scenery_id)), overrides)
	var center := str(city.get("center", ""))
	if is_city and center != "" and scenery_id == str(city.get("outskirts", "")):
		var f := ground_blend(z, float(city.get("center_z", 0.0)))
		if f > 0.0:
			var sc := style(center, _dict(scenery_db.get(center)), overrides)
			st = {"accent": (st["accent"] as Color).lerp(sc["accent"], f), "amount": lerpf(float(st["amount"]), float(sc["amount"]), f),
				"nature": lerpf(float(st["nature"]), float(sc["nature"]), f)}
	return st


## The detail texture of the ground shaders (see the header). Deterministic; generated in about 20 ms and shared for
## as long as somebody holds it (a weak reference here: nothing is left behind when the last material goes).
static func noise_texture() -> ImageTexture:
	var alive: Variant = _noise.get_ref() if _noise != null else null
	if alive is ImageTexture:
		return alive
	var n := NOISE_SIZE
	var grain := FastNoiseLite.new()
	grain.seed = 1107
	grain.noise_type = FastNoiseLite.TYPE_VALUE
	grain.frequency = 0.42
	grain.fractal_type = FastNoiseLite.FRACTAL_FBM
	grain.fractal_octaves = 2
	var blot := FastNoiseLite.new()
	blot.seed = 2311
	blot.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	blot.frequency = 0.028
	blot.fractal_type = FastNoiseLite.FRACTAL_FBM
	blot.fractal_octaves = 3
	var cells := FastNoiseLite.new()
	cells.seed = 4073
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.frequency = 0.024
	cells.cellular_jitter = 0.85
	cells.fractal_type = FastNoiseLite.FRACTAL_NONE
	cells.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	cells.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var edges: FastNoiseLite = cells.duplicate()
	edges.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var layers: Array[Image] = []
	for src: FastNoiseLite in [grain, blot, cells, edges]:
		var img := src.get_seamless_image(n, n, false, false, 0.12, true)
		img.convert(Image.FORMAT_L8)
		layers.append(img)
	var bytes := PackedByteArray()
	bytes.resize(n * n * 4)
	var d0 := layers[0].get_data()
	var d1 := layers[1].get_data()
	var d2 := layers[2].get_data()
	var d3 := layers[3].get_data()
	for i in n * n:
		bytes[i * 4] = d0[i]
		bytes[i * 4 + 1] = d1[i]
		bytes[i * 4 + 2] = d2[i]
		bytes[i * 4 + 3] = d3[i]
	var out := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, bytes)
	out.generate_mipmaps()
	var tex := ImageTexture.create_from_image(out)
	_noise = weakref(tex)
	return tex


## Forgets what is kept between calls (tests).
static func drop() -> void:
	_noise = null
	_far_key = []
	_far_hit = {}


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
