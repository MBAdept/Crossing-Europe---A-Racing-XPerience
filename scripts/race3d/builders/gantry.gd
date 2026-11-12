extends ChunkBuilder
## Gantry builder of the mode "Modern" (v0.8.0, contract §6 R6, renderer inventory B/C): Arcade's start and finish
## gantries (SignPainter._gantry, frozen) as steel structures at Arcade's place and size. They come from the sign items
## of the Track with side 0 ("start" 14 m after the start line, "finish" at the finish line – the signs builder leaves
## them to this one):
##  * two steel columns 0.45 m wide just outside the outer shoulder edges, 7 m high, on concrete footings with a base
##    plate, joint bands and a cap;
##  * the banner across from 5.4 to 7 m, 0.3 m deep: its face towards the approaching traffic is a panel of the stage's
##    lettering atlas, drawn once in prepare() with Arcade's own layout and sign font – "finish" red with the checkered
##    strips at its top and bottom and the item's text ("ZIEL"), "start" dark with the light stripe and "START" (never a
##    Label3D); the other faces in the banner colour;
##  * on the start gantry three countdown lamps in black housings with hoods, at Arcade's places (1.4 + i × 1.15 m right
##    of the road centre, 0.8 m under the top): red while the countdown runs (one more each second), all green at the
##    start until two seconds after it, else off (view.countdown – the same rule as RoadRenderer._start_light_glows);
##    they glow through the flare layer (renderer.add_lamps(), role "on", colour and strength set every frame).
## Materials: vpbr (ModernMaterials.VPBR_STATIC) for the steel, the class "baked" for the banner panels, unshaded
## lenses. Shadows only with structure casters (QA1-B3: nothing casts with „Schatten: Aus“).
## Builder rules: build() runs on worker threads – ctx snapshot arrays and the plain tables of collect() only.
## Owner: R6 (wave 3). Docs: docs/renderer-modern-bauten.md.

const Station := preload("res://scripts/race3d/builders/station.gd")

const TOP := 7.0
const BANNER_H := 1.6
const POST_W := 0.45
const DEPTH := 0.3                 ## banner and columns, along the road
const STEEL := Color("c9ccd1")
const STEEL_DARK := Color("8d939b")
const FOOTING := Color("a7a49c")
const FINISH_RED := Color("c81e1e")
const START_DARK := Color("1b1f2a")
const START_STRIPE := Color("e8e8e8")
const CHECKER_H := 0.22
const LAMP_R := 0.36
const RIM_R := 0.45
const LIGHT_RED := Color("ff2a1a")
const LIGHT_GREEN := Color("35ff55")
const LIGHT_OFF := Color("3a1010")
const HOUSING := Color("121418")
const ROUGH_METAL := Vector2(0.45, 0.5)
const ROUGH_PAINT := Vector2(0.6, 0.0)
const ROUGH_CONCRETE := Vector2(0.85, 0.0)
const PANEL_PPM := 64.0
## Arcade's glow round a lit countdown lamp (RoadRenderer._start_light_glows: radius 1.4 m, alpha 0.6): flare size ×
## 0.9 = radius, strength 2 × alpha (the flare adds colour × 0.5 × strength)
const LAMP_GLOW_SIZE := 1.56
const LAMP_GLOW_ENERGY := 1.2

var _renderer: Node
var _mats: ModernMaterials
var _atlas := Station.PanelAtlas.new()
var _specs: Dictionary = {}       ## key -> spec of the banners met without prepare() (tests)
var _panel_mat: ShaderMaterial
var _prepared := false
var _lights: Array = []            ## [[MeshInstance3D, StandardMaterial3D, lamp dictionary, index], …] of start gantries


func id() -> String:
	return "gantry"


func setup(renderer: Node) -> void:
	_renderer = renderer
	var m: Variant = renderer.get("materials") if renderer != null else null
	_mats = m as ModernMaterials if m is ModernMaterials else ModernMaterials.shared()


## The banners of the stage's gantries, drawn behind the loading overlay.
func prepare(_ctx: Dictionary) -> void:
	var track: Variant = _renderer.get("track") if _renderer != null else null
	_atlas.prepare(panel_specs(track as Track if track is Track else null), _renderer)
	_prepared = true


func prepare_pending() -> int:
	if not _prepared:
		return 0
	var n := _atlas.pending()
	if n == 0 and _panel_mat != null:
		_panel_mat.set_shader_parameter(&"albedo_tex", _atlas.albedo)
	return n


## The lettering atlas of this stage (tests, warm-up).
func atlas() -> Station.PanelAtlas:
	return _atlas


## Key of a banner panel: kind, text and the banner's lateral extent (m from the road centre).
static func banner_key(kind: String, text: String, left: float, right: float) -> String:
	return "%s|%s|%.2f|%.2f" % [kind, text, left, right]


## Lateral extent (left, right shoulder edge, m from the road centre) of the road at road position z – the same values
## as ChunkContext.shoulder_edge() of the row whose segment holds z (TrackSegment.lanes / fuel_lane at its start).
static func edges_at(track: Track, z: float) -> Vector2:
	var zs := floorf(z / track.seg_len) * track.seg_len
	var half := track.lanes_at(zs) * track.lane_w * 0.5
	return Vector2(-half - track.shoulder_w, half + track.fuel_lane_factor(zs) * track.lane_w + track.shoulder_w)


## One spec per gantry of the stage (Track events with side 0: start and finish).
func panel_specs(track: Track) -> Array:
	var out: Array = []
	if track == null:
		return out
	for i in track.segment_count:
		for e: Variant in track.events_for_segment(i):
			var it: Dictionary = e
			if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) != 0:
				continue
			var kind := str(it.get("sign", ""))
			if kind != "start" and kind != "finish":
				continue
			var text := str(it.get("text", "ZIEL")) if kind == "finish" else "START"
			var ed := edges_at(track, float(it.get("z", 0.0)))
			out.append(spec_for(kind, text, ed.x, ed.y))
	return out


func spec_for(kind: String, text: String, left: float, right: float) -> Dictionary:
	var w := right - left + POST_W * 2.0
	# the start banner says tr("START") (SignPainter._gantry); its key keeps the plain word
	var shown := tr("START") if kind == "start" else text
	var draw := func(p: SignPainter, b: GeoBatch, r: Rect2, ppm: float, _night: bool) -> void:
		_draw_banner(p, b, r, ppm, kind, shown, left)
	return {"key": banner_key(kind, text, left, right), "w": w, "h": BANNER_H, "ppm": PANEL_PPM, "glow": false, "draw": draw}


## The banner face as SignPainter._gantry draws it (Arcade, frozen): r = the banner (left - post_w … right + post_w,
## 7 m … 5.4 m), the road centre at -left + post_w metres from its left edge.
static func _draw_banner(p: SignPainter, b: GeoBatch, r: Rect2, s: float, kind: String, text: String, left: float) -> void:
	var cx := r.position.x + (-left + POST_W) * s      # the road centre (x = 0): Arcade's p.x
	if kind == "start":
		b.rect(r, START_DARK)
		b.rect(Rect2(r.position.x, r.end.y - 0.12 * s, r.size.x, 0.12 * s), START_STRIPE)
		p.text(text, Vector2(cx - 2.4 * s, r.position.y + 1.18 * s), 0.85 * s, SignPainter.WHITE, r.size.x * 0.4)
		for i in 3:
			var c := Vector2(cx + (1.4 + float(i) * 1.15) * s, r.position.y + 0.8 * s)
			b.ellipse(c, Vector2(RIM_R, RIM_R) * s, Color(0.05, 0.05, 0.05), Color(0.05, 0.05, 0.05), 24)
			b.ellipse(c, Vector2(LAMP_R, LAMP_R) * s, LIGHT_OFF, LIGHT_OFF, 24)
		return
	b.rect(r, FINISH_RED)
	var cells := int(clampf(r.size.x / maxf(0.5 * s, 1.0), 4.0, 64.0))
	var cw := r.size.x / float(cells)
	for i in cells:
		var col := SignPainter.WHITE if i % 2 == 0 else SignPainter.BLACK
		var col2 := SignPainter.BLACK if i % 2 == 0 else SignPainter.WHITE
		b.rect(Rect2(r.position.x + cw * float(i), r.position.y, cw, CHECKER_H * s), col)
		b.rect(Rect2(r.position.x + cw * float(i), r.end.y - CHECKER_H * s, cw, CHECKER_H * s), col2)
	p.text(text, Vector2(cx, r.position.y + 1.22 * s), 0.85 * s, SignPainter.WHITE, r.size.x * 0.6)


func warmup_nodes() -> Array:
	var out: Array = []
	var k := Station.Kit.new()
	k.box(Transform3D.IDENTITY, Vector3(0.0, 0.5, 0.0), Vector3(0.5, 0.5, 0.5), STEEL, ROUGH_METAL)
	out.append(Station.vpbr_node(k.arrays(), _mats, true, "GantryWarm"))
	if _atlas.ready and not _atlas.entries.is_empty():
		var pb := Station.PanelBuf.new()
		var key: String = _atlas.entries.keys()[0]
		pb.framed(Transform3D.IDENTITY, -0.5, 0.5, 1.2, 2.0, 0.0, _atlas.uv(key))
		out.append(Station.panel_node(pb.arrays(), _panel_material(), true, "GantryPanelWarm"))
	var lens := _lens_node(LIGHT_OFF)
	out.append(lens[0])
	return out


func _panel_material() -> ShaderMaterial:
	if _panel_mat == null:
		_panel_mat = Station.panel_material(_mats if _mats != null else ModernMaterials.shared(), _atlas, 0.55)
	return _panel_mat


# --- chunks --------------------------------------------------------------------------------------------------------

## Main thread: the banner cells (plain data for build()); without prepare() (tests) the specs of the chunk's gantries
## go into a placeholder atlas at once.
func collect(ctx: ChunkContext) -> Variant:
	if not _prepared:
		var added := false
		for g: Dictionary in _items(ctx):
			var key := banner_key(str(g["kind"]), str(g["text"]), float(g["left"]), float(g["right"]))
			if not _specs.has(key):
				_specs[key] = spec_for(str(g["kind"]), str(g["text"]), float(g["left"]), float(g["right"]))
				added = true
		if added:
			_atlas.prepare(_specs.values(), null)
			if _panel_mat != null:
				_panel_mat.set_shader_parameter(&"albedo_tex", _atlas.albedo)
	return {"uv": _atlas.entries.duplicate()}


## The gantries of a chunk: [{kind, text, z, row, left, right}] (worker-thread safe: ctx snapshot only).
static func _items(ctx: ChunkContext) -> Array:
	var out: Array = []
	var rows := ctx.row_count()
	for i in rows - 1:
		var seg: Dictionary = ctx.segs[i]
		for it: Dictionary in seg["sprites"]:
			if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) != 0:
				continue
			var kind := str(it.get("sign", ""))
			if kind != "start" and kind != "finish":
				continue
			var z := float(it.get("z", seg.get("z", 0.0)))
			var row := clampi(int(floor(ctx.row_of(z))), 0, rows - 1)
			var text := str(it.get("text", "ZIEL")) if kind == "finish" else "START"
			out.append({"kind": kind, "text": text, "z": z, "row": row, "left": -ctx.shoulder_edge(row, -1), "right": ctx.shoulder_edge(row, 1)})
	return out


## WORKER THREAD.
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var uvs: Dictionary = (input as Dictionary).get("uv", {}) if input is Dictionary else {}
	var kit := Station.Kit.new()
	var pan := Station.PanelBuf.new()
	var gantries: Array = []
	var letterings: Array = []
	for g: Dictionary in _items(ctx):
		var kind := str(g["kind"])
		var text := str(g["text"])
		var left := float(g["left"])
		var right := float(g["right"])
		var z := float(g["z"])
		var f := ctx.frame(z, 0.0, 0.0)
		var half := (right - left) * 0.5 + POST_W
		var cx := (left + right) * 0.5
		for px: float in [left - POST_W * 0.5, right + POST_W * 0.5]:
			_column(ctx, kit, f, z, px)
		# the banner: a box in its colour, the face towards the camera a panel
		var colour := FINISH_RED if kind == "finish" else START_DARK
		var faces := 2 | 4 | 8 | 16 | 32
		var uv: Rect2 = uvs.get(banner_key(kind, text, left, right), Rect2())
		if uv.size.x <= 0.0:
			faces |= 1
		kit.box(f, Vector3(cx, TOP - BANNER_H * 0.5, 0.0), Vector3(half, BANNER_H * 0.5, DEPTH * 0.5), colour, ROUGH_PAINT, faces)
		if uv.size.x > 0.0:
			pan.framed(f, cx - half, cx + half, TOP - BANNER_H, TOP, DEPTH * 0.5 + 0.002, uv)
			letterings.append(text)
		var lamps: Array = []
		if kind == "start":
			# three lamps in housings with hoods (Arcade: 1.4 + i × 1.15 m from the road centre, 0.8 m under the top)
			var front := DEPTH * 0.5
			for i in 3:
				var lc := Vector3(1.4 + float(i) * 1.15, TOP - 0.8, front)
				kit.column(Transform3D(f.basis * Basis(Vector3.RIGHT, PI * 0.5), f * (lc + Vector3(0.0, 0.0, -0.01))), Vector3.ZERO,
					RIM_R, 0.09, 20, HOUSING, Vector2(0.4, 0.2))
				kit.box(f, lc + Vector3(0.0, RIM_R + 0.03, 0.17), Vector3(RIM_R + 0.04, 0.025, 0.17), HOUSING, Vector2(0.4, 0.2))
				lamps.append({"pos": lc + Vector3(0.0, 0.0, 0.09), "i": i})
		gantries.append({"kind": kind, "text": text, "frame": f, "z": snappedf(z, 0.001), "lamps": lamps})
	if gantries.is_empty():
		return {}
	return {"arrays": kit.arrays(), "panels": pan.arrays() if not pan.is_empty() else [],
		"gantries": gantries, "letterings": letterings, "triangles": kit.triangles()}


## A steel column of a gantry at lateral x (m): footing from the ground, base plate, column to the top, joint bands, cap.
static func _column(ctx: ChunkContext, kit: Station.Kit, f: Transform3D, z: float, x: float) -> void:
	var g := minf(ctx.ground(z, x), 0.0)
	var foot := g - 0.3
	kit.box(f, Vector3(x, (foot + 0.25) * 0.5, 0.0), Vector3(0.95, 0.25 - foot, 0.75) * 0.5, FOOTING, ROUGH_CONCRETE, 1 | 2 | 4 | 8 | 16)
	kit.box(f, Vector3(x, 0.28, 0.0), Vector3(0.66, 0.06, 0.5) * 0.5, STEEL_DARK, ROUGH_METAL, 1 | 2 | 4 | 8 | 16)
	kit.box(f, Vector3(x, (TOP + 0.25) * 0.5, 0.0), Vector3(POST_W, TOP - 0.25, DEPTH) * 0.5, STEEL, ROUGH_METAL, 1 | 2 | 4 | 8)
	for y: float in [1.6, 3.2, 4.8]:
		kit.box(f, Vector3(x, y, 0.0), Vector3(POST_W + 0.04, 0.08, DEPTH + 0.04) * 0.5, STEEL_DARK, ROUGH_METAL, 1 | 2 | 4 | 8 | 16 | 32)
	kit.box(f, Vector3(x, TOP + 0.03, 0.0), Vector3(POST_W + 0.06, 0.06, DEPTH + 0.06) * 0.5, STEEL_DARK, ROUGH_METAL, 1 | 2 | 4 | 8 | 16)


## A lens: [MeshInstance3D, its unshaded material].
static func _lens_node(colour: Color) -> Array:
	var lamp := MeshInstance3D.new()
	var lamp_mesh := CylinderMesh.new()
	lamp_mesh.top_radius = LAMP_R
	lamp_mesh.bottom_radius = LAMP_R
	lamp_mesh.height = 0.04
	lamp_mesh.radial_segments = 24
	lamp.mesh = lamp_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	lamp.material_override = mat
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return [lamp, mat]


## Main thread: the steel in vpbr, the banner panels, the countdown lenses of a start gantry.
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var arrays: Array = part.get("arrays", [])
	if arrays.is_empty():
		return
	var mats := Station.materials_of(ctx)
	if _mats == null:
		_mats = mats
	var casts := int(ctx.levels.get("shadow_casters", 0)) >= 1
	var mi := Station.vpbr_node(arrays, mats, casts, "Gantry")
	parent.add_child(mi)
	var panels: Array = part.get("panels", [])
	if not panels.is_empty():
		var pn := Station.panel_node(panels, _panel_material(), casts, "GantryPanels")
		pn.set_meta(&"lettering", part.get("letterings", []))
		parent.add_child(pn)
	var renderer: Variant = ctx.services.get("renderer")
	for g: Dictionary in part.get("gantries", []):
		var f: Transform3D = g["frame"]
		var lamps: Array = []
		for l: Dictionary in g.get("lamps", []):
			var lens := _lens_node(LIGHT_OFF)
			var node: MeshInstance3D = lens[0]
			var pos: Vector3 = f * (l["pos"] as Vector3)
			node.transform = Transform3D(f.basis * Basis(Vector3.RIGHT, PI * 0.5), pos)
			parent.add_child(node)
			var entry := {"pos": pos + f.basis.z * 0.05, "dir": f.basis.z, "role": "on", "color": LIGHT_RED, "size": LAMP_GLOW_SIZE,
				"range": 0.0, "energy": 0.0}
			lamps.append(entry)
			_lights.append([node, lens[1], entry, int(l["i"])])
		if renderer != null and not lamps.is_empty():
			(renderer as Object).call(&"add_lamps", parent, lamps)


## Every frame (main thread): Arcade's countdown lamps – red while counting (one more each second), all green at the
## start (until two seconds after it), off before and later.
func update(view: Dictionary, _dt: float) -> void:
	if _lights.is_empty():
		return
	var cd := float(view.get("countdown", -1000.0))
	var i := _lights.size() - 1
	while i >= 0:
		var e: Array = _lights[i]
		if not is_instance_valid(e[0]):
			_lights.remove_at(i)
			i -= 1
			continue
		var st := lamp_state(cd, int(e[3]))
		(e[1] as StandardMaterial3D).albedo_color = st[0]
		var entry: Dictionary = e[2]
		entry["color"] = st[0]
		entry["energy"] = float(st[1]) * LAMP_GLOW_ENERGY
		i -= 1


## Colour and glow of countdown lamp k (0..2) at view.countdown cd – the rule of RoadRenderer._start_light_glows.
static func lamp_state(cd: float, k: int) -> Array:
	var on := 0 if cd <= 0.0 else clampi(4 - int(ceil(cd)), 1, 3)
	if cd <= 0.0 and cd > -2.0:
		return [LIGHT_GREEN, 1.0]
	if cd > 0.0 and k < on:
		return [LIGHT_RED, 1.0]
	return [LIGHT_OFF, 0.0]


func debug(part: Dictionary) -> Dictionary:
	var kinds: Array = []
	var lamps := 0
	for g: Dictionary in part.get("gantries", []):
		kinds.append(str(g["kind"]))
		lamps += (g.get("lamps", []) as Array).size()
	return {"gantries": kinds, "letterings": part.get("letterings", []), "lamps": lamps, "triangles": int(part.get("triangles", 0))}
