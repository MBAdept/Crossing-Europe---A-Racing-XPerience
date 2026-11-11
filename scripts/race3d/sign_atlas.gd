class_name SignAtlas
extends RefCounted
## Sign textures of a stage for the mode "Modern" (contract §6 R3; docs/renderer-modern.md §10): every sign the
## stage's Track can show is drawn ONCE, before the stage starts (prepare()), by Arcade's frozen SignPainter into one
## SubViewport, read back and kept as ONE mipmapped ImageTexture (the atlas). During the drive nothing is created:
## no SubViewport, no texture (counters subviewports_created / textures_created / created_while_driving).
##  * catalogue (stage_signs): the events of Track (Track.events_for_segment over the whole stage, with the country
##    and road type of the segment where each stands – exactly what Track._place_props gives the sign) plus the
##    signs Track places while it generates (curve and crest warnings, chevron boards: their look depends only on
##    the direction),
##  * key (key_of): what the look of a sign kind depends on (SignPainter.draw), so equal signs share one cell,
##  * geometry (measure): a dry run of SignPainter at 4 px per metre, collecting the vertices of its GeoBatch
##    without drawing: the bounds of the board(s) in metres above the ground point, and the posts (the rects that
##    reach the ground) – the 3D signs get real posts where Arcade draws them;
##  * headless (no renderer that draws): a placeholder atlas, every cell a plain board colour; the geometry is the same.
## The atlas is premultiplied (what a transparent SubViewport gives): the sign shader divides by alpha after sampling,
## so the mipmaps do not darken the edges of a board.
## Owner: R3.

const PPM := 64.0                    ## atlas pixels per metre of a sign
const PAD := 6                       ## free pixels around every cell
const MEASURE_PPM := 4.0             ## dry run: every text is a bar at this scale (no draw call outside _draw())
const MAX_SIZE := 4096
const DYNAMIC_SIGNS: Array = [{"sign": "curve", "value": 1}, {"sign": "curve", "value": -1}, {"sign": "crest", "value": 1},
	{"sign": "chevron", "value": 1}, {"sign": "chevron", "value": -1}]
const SCRIPT_CANVAS := "res://scripts/race3d/sign_canvas.gd"

## Diagnostics of the whole process: SubViewports and textures this class created, and how many of them were
## created after a stage had been prepared (must stay 0: everything is drawn behind the loading overlay).
static var subviewports_created := 0
static var textures_created := 0
static var created_while_driving := 0
## True while no stage is being prepared – set by the sign builder; a creation in this state counts as "driving".
static var driving := false

var texture: Texture2D               ## the atlas (placeholder headless)
var entries: Dictionary = {}         ## key -> {"uv": Rect2 (0..1), "bounds": Rect2 (m: x right, y UP from the ground
                                     ##   point; position = lower left), "posts": [Vector3(x, width, top) m], "colour"}
var size := Vector2i.ZERO
var ready := false
var placeholder := false
var missing := 0                     ## signs asked for that have no cell (drawn as a plain board)

var _holder: Node
var _vp: SubViewport
var _canvas: Node2D
var _frame0 := 0
var _jobs: Array = []                ## [key, item, cell Rect2i, bounds Rect2]


## Key of the look of a sign item: kind plus the fields SignPainter.draw() reads for that kind (style by country
## and road type only where it matters).
static func key_of(it: Dictionary) -> String:
	var kind := str(it.get("sign", ""))
	var country := str(it.get("country", ""))
	var mw := str(it.get("road", "autobahn")) == "autobahn"
	var text := str(it.get("text", ""))
	var value := int(it.get("value", 0))
	match kind:
		"limit":
			return "limit|%d" % value
		"unlimited", "crest":
			return kind
		"radar":
			return "radar|%d|%s" % [value, text]
		"fuel":
			return "fuel|%s|%s" % [text, country if mw else "-"]
		"fuel_lane":
			return "fuel_lane|%s" % (country if mw else "-")
		"town":
			return "town|%s|%s" % [text, country]
		"town_ahead":
			return "town_ahead|%s|%d|%d|%s" % [text, value, int(it.get("limit", 0)), country]
		"distance":
			return "distance|%s|%d|%s|%s" % [text, value, country, "A" if mw else "R"]
		"border":
			return "border|%s|%s" % [text, country]
		"tunnel":
			return "tunnel|%s|%d" % [text, value]
		"autobahn", "autobahn_end":
			return "%s|%s" % [kind, country]
		"curve", "chevron":
			return "%s|%d" % [kind, 1 if value >= 0 else -1]
	return "%s|%s|%d|%d|%s|%s" % [kind, text, value, int(it.get("limit", 0)), country, "A" if mw else "R"]


## Every sign item the stage can show (side 0 – the start and finish gantries – excluded): the events of the Track
## with the country and road type of their segment, plus the signs Track places while it generates. Plain copies.
static func stage_signs(track: Track, plan: StagePlan) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if track != null:
		for i in track.segment_count:
			var evs: Array = track.events_for_segment(i)
			if evs.is_empty():
				continue
			for e: Variant in evs:
				var d: Dictionary = e
				if str(d.get("kind", "")) != "sign" or int(d.get("side", 1)) == 0:
					continue
				var it := d.duplicate()
				var km := minf(track.z_to_km(float(i) * track.seg_len), track.length_km)
				if not it.has("country"):
					it["country"] = str(plan.section_at(km).get("country", "DE")) if plan != null else "DE"
				it["road"] = plan.road_at(km) if plan != null else "autobahn"
				var k := key_of(it)
				if not seen.has(k):
					seen[k] = true
					out.append(it)
	for d: Dictionary in DYNAMIC_SIGNS:
		var it := d.duplicate()
		it["kind"] = "sign"
		var k := key_of(it)
		if not seen.has(k):
			seen[k] = true
			out.append(it)
	return out


## Geometry of a sign from a dry run of SignPainter (nothing is drawn): {"bounds": Rect2 in metres with y UP from the
## ground point (position = lower left corner), "posts": [Vector3(x, width, top)] in metres (top = height of the post
## above the ground point), "colour": the colour of the largest board quad (placeholder)}. Empty bounds when the
## kind draws nothing.
static func measure(it: Dictionary, painter: SignPainter, batch: GeoBatch) -> Dictionary:
	var s := MEASURE_PPM
	# boards: the sign as mounted on a wall (no posts)
	var wall := it.duplicate()
	wall["wall"] = true
	batch.begin(RID())
	painter.draw(wall, Vector3(0.0, 0.0, s), Color.WHITE, 1.0, Vector2.ZERO)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var best_area := 0.0
	var colour := Color(0.6, 0.6, 0.6)
	var v := batch.verts
	for i in v.size():
		lo = Vector2(minf(lo.x, v[i].x), minf(lo.y, v[i].y))
		hi = Vector2(maxf(hi.x, v[i].x), maxf(hi.y, v[i].y))
	for q in range(0, v.size() - 3, 4):
		var area := absf((v[q + 2] - v[q]).cross(v[q + 1] - v[q])) + absf((v[q + 3] - v[q]).cross(v[q + 2] - v[q]))
		if area > best_area:
			best_area = area
			colour = batch.cols[q]
	batch.verts.clear()
	batch.cols.clear()
	var out := {"bounds": Rect2(), "posts": [], "colour": colour}
	if lo.x > hi.x:
		return out
	out["bounds"] = Rect2(lo.x / s, -hi.y / s, (hi.x - lo.x) / s, (hi.y - lo.y) / s)
	# posts: rects that reach down to the ground point (only drawn when the sign is not on a wall)
	if not bool(it.get("wall", false)):
		var free := it.duplicate()
		free["wall"] = false
		batch.begin(RID())
		painter.draw(free, Vector3(0.0, 0.0, s), Color.WHITE, 1.0, Vector2.ZERO)
		var w := batch.verts
		var posts: Array = []
		for q in range(0, w.size() - 3, 4):
			var a := w[q]
			var b := w[q + 1]
			var c := w[q + 2]
			var d := w[q + 3]
			if absf(c.y) < 0.001 and absf(d.y) < 0.001 and absf(a.y - b.y) < 0.001 and a.y < -0.01 \
					and absf(a.x - d.x) < 0.001 and absf(b.x - c.x) < 0.001 and b.x > a.x:
				posts.append(Vector3((a.x + b.x) * 0.5 / s, (b.x - a.x) / s, -a.y / s))
		batch.verts.clear()
		batch.cols.clear()
		out["posts"] = posts
	return out


## Starts drawing the signs (main thread; `holder` = a node in the scene tree the SubViewport may hang under).
## countries = GameData.countries (sign styles). Headless: the placeholder atlas, ready at once.
func prepare(items: Array, holder: Node, countries: Dictionary) -> void:
	ready = false
	entries.clear()
	_jobs.clear()
	var batch := GeoBatch.new()
	var painter := SignPainter.new()
	painter.setup(null, batch)
	painter.countries = countries
	# geometry and packing: shelves, tallest first
	var cells: Array = []
	for it: Dictionary in items:
		var k := key_of(it)
		if entries.has(k):
			continue
		var m := measure(it, painter, batch)
		var b: Rect2 = m["bounds"]
		if b.size.x <= 0.0 or b.size.y <= 0.0:
			continue
		entries[k] = {"uv": Rect2(), "bounds": b, "posts": m["posts"], "colour": m["colour"]}
		cells.append([k, it, Vector2i(int(ceil(b.size.x * PPM)), int(ceil(b.size.y * PPM)))])
	cells.sort_custom(func(a: Array, c: Array) -> bool: return (a[2] as Vector2i).y > (c[2] as Vector2i).y)
	var width := 1024
	var total := 0
	for c: Array in cells:
		total += ((c[2] as Vector2i).x + PAD * 2) * ((c[2] as Vector2i).y + PAD * 2)
	while width < MAX_SIZE and total > width * width / 2:
		width *= 2
	var x := PAD
	var y := PAD
	var shelf := 0
	for c: Array in cells:
		var sz: Vector2i = c[2]
		if x + sz.x + PAD > width:
			x = PAD
			y += shelf + PAD * 2
			shelf = 0
		_jobs.append([c[0], c[1], Rect2i(Vector2i(x, y), sz)])
		x += sz.x + PAD * 2
		shelf = maxi(shelf, sz.y)
	var height := mini(MAX_SIZE, maxi(64, y + shelf + PAD))
	size = Vector2i(width, height)
	for j: Array in _jobs:
		var cell: Rect2i = j[2]
		var e: Dictionary = entries[j[0]]
		e["uv"] = Rect2(float(cell.position.x) / float(width), float(cell.position.y) / float(height),
			float(cell.size.x) / float(width), float(cell.size.y) / float(height))
	if DisplayServer.get_name() == "headless" or holder == null or not holder.is_inside_tree() or _jobs.is_empty():
		_make_placeholder()
		return
	# one SubViewport draws every sign once
	_holder = holder
	_vp = SubViewport.new()
	_vp.name = "SignAtlas"
	_vp.size = size
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_count_viewport()
	var canvas_script: Variant = load(SCRIPT_CANVAS)
	_canvas = (canvas_script as GDScript).new()
	var jobs: Array = []
	for j: Array in _jobs:
		var cell: Rect2i = j[2]
		var b: Rect2 = (entries[j[0]] as Dictionary)["bounds"]
		# ground point such that the board's bounds fill the cell (y down in the canvas, bounds y up)
		var at := Vector2(float(cell.position.x) - b.position.x * PPM, float(cell.position.y) + b.end.y * PPM)
		var it: Dictionary = (j[1] as Dictionary).duplicate()
		it["wall"] = true
		jobs.append({"item": it, "at": at, "ppm": PPM})
	_canvas.set("jobs", jobs)
	_vp.add_child(_canvas)
	_canvas.call("setup_painter", countries)
	_holder.add_child(_vp)
	_frame0 = Engine.get_frames_drawn()


## Signs still to be drawn (0 = the atlas is ready). Polled every frame of the preparation; reads the picture back
## once the SubViewport has been drawn.
func pending() -> int:
	if ready:
		return 0
	if _vp == null:
		return 0
	if not RenderingServer.render_loop_enabled:
		RenderingServer.force_draw(false)
	if Engine.get_frames_drawn() - _frame0 < 2:
		return _jobs.size()
	var img := _vp.get_texture().get_image()
	if img == null or img.is_empty():
		_make_placeholder()
	else:
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		texture = ImageTexture.create_from_image(img)
		_count_texture()
		ready = true
	_free_viewport()
	return 0


## The cell of a sign item ({} when it was not in the catalogue – then the caller draws a plain board and `missing`
## counts it).
func entry(it: Dictionary) -> Dictionary:
	var e: Variant = entries.get(key_of(it))
	if e == null:
		missing += 1
		return {}
	return e


func _make_placeholder() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.85, 0.85, 1.0))
	img.generate_mipmaps()
	texture = ImageTexture.create_from_image(img)
	_count_texture()
	placeholder = true
	ready = true
	_free_viewport()


func _free_viewport() -> void:
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null
	_canvas = null


func _count_viewport() -> void:
	subviewports_created += 1
	if driving:
		created_while_driving += 1


func _count_texture() -> void:
	textures_created += 1
	if driving:
		created_while_driving += 1


## Frees what is left (the stage ends).
func clear() -> void:
	_free_viewport()
	texture = null
	entries.clear()
	ready = false
