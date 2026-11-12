extends ChunkBuilder
## Border station builder of the mode "Modern" (v0.8.0, contract §6 R6, renderer inventory B): the control station
## Arcade draws over the road at a border (RoadRenderer._border_cover, frozen) as a real structure, at Arcade's place
## and in its colours. Per segment with TrackSegment.cover == "border" (Track: 18 m from the border on):
##  * the roof over the whole road: soffit at 6.0 m from 1.6 m beyond the left to 1.6 m beyond the right shoulder edge
##    (Arcade's underside reaches 1 m beyond them, its fascia 1.6 m), a slab up to 6.8 m with white sides and a blue
##    band, fluorescent light bars in the soffit every second segment (three across at 25 / 50 / 75 % of the road,
##    lamp channel 12, glowing white through the flare layer) and the light pools of Arcade on the road (one every four
##    segments at the road centre, radius 16 m – the pool lamp sits inside the slab, so only its light shows);
##  * at the front (TrackSegment.cover_front): Arcade's fascia from 6.0 to 7.6 m – white with the blue band at its foot,
##    the European flag at its left end and the name of the country entered in Arcade's sign font (a panel of the
##    stage's lettering atlas, drawn once in prepare() – never a Label3D), backlit at night; Arcade's two pillars
##    0.6 m outside the shoulder edges, and two more at the end of the roof (not inside a bend's sight corridor, F7);
## The booths are models of the props builder (props/customs_booth, AS1b) at Arcade's places on the shoulders. Arcade
## has neither a barrier nor a stop line at its border stations, so Modern has none either.
## Fairness: the soffit keeps Arcade's height (6.0 m) – the camera at 3.4 m sees every car under the roof as in Arcade.
## Materials: ModernMaterials.VPBR_STATIC for the structure, the class "baked" for the fascia panels. Shadows only with
## structure casters. Builder rules: build() on worker threads – ctx snapshot and the plain tables of collect() only.
## Owner: R6 (wave 3). Docs: docs/renderer-modern-bauten.md.

const Station := preload("res://scripts/race3d/builders/station.gd")

const ROOF_H := 6.0                ## soffit (Arcade: the underside at 6 m)
const SLAB_TOP := 6.8
const FASCIA_H := 1.6              ## Arcade: the fascia from 6.0 to 7.6 m
const FASCIA_OUT := 1.6            ## fascia (and roof) this far beyond the shoulder edges
const BAND := 0.3                  ## blue band at the foot of the fascia
const PILLAR_OUT := 0.6            ## pillars this far beyond the shoulder edges …
const PILLAR_W := 0.55             ## … this wide (Arcade)
const BAR := Vector2(1.8, 0.24)    ## light bar: across, along
const BAR_T: Array[float] = [0.25, 0.5, 0.75]
const POOL_EVERY := 4              ## a light pool every four segments (Arcade: k % 4)
const POOL_RANGE_M := 16.0
const POOL_ENERGY := 1.27          ## 0.7 at the centre with the lights layer's 0.55 per unit (Arcade: 0.7 × lights)
## Arcade's underside colour 8e959c is drawn flat-lit; under the real sun the soffit only gets the sky light – a lighter
## grey keeps it as light as Arcade's
const SOFFIT := Color("aab0b6")
const SLAB := Color("f0f0ec")
const PILLAR := Color("b8bcc2")
const TOP_C := Color("9a9fa5")
const BAR_C := Color(1.0, 1.0, 0.96)
const BAR_GLOW := Color(1.0, 0.97, 0.9)
const ROUGH_PAINT := Vector2(0.6, 0.0)
const ROUGH_METAL := Vector2(0.45, 0.4)
const ROUGH_CONCRETE := Vector2(0.85, 0.0)
const PANEL_PPM := 56.0

var _renderer: Node
var _mats: ModernMaterials
var _atlas := Station.PanelAtlas.new()
var _panel_mat: ShaderMaterial
var _prepared := false
var _specs: Dictionary = {}        ## key -> spec of the fascias met without prepare() (tests)
var _names: Dictionary = {}        ## country code -> name of the country (plan.borders "name_local")


func id() -> String:
	return "border"


func setup(renderer: Node) -> void:
	_renderer = renderer
	var m: Variant = renderer.get("materials") if renderer != null else null
	_mats = m as ModernMaterials if m is ModernMaterials else ModernMaterials.shared()


## The fascia of every border of the stage, drawn behind the loading overlay.
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
		_panel_mat.set_shader_parameter(&"emit_tex", _atlas.emission)
	return n


func atlas() -> Station.PanelAtlas:
	return _atlas


## Key of a fascia panel: the country entered and the road's lateral extent there (m from the road centre).
static func fascia_key(country: String, left: float, right: float) -> String:
	return "border|%s|%.2f|%.2f" % [country, left, right]


## Name on the fascia of the border into `country` (Arcade: plan.borders "name_local", upper case).
static func country_name(track: Track, country: String) -> String:
	var name := country
	if track != null and track.plan != null:
		for bd: Dictionary in track.plan.borders:
			if str(bd.get("to", "")) == country:
				name = str(bd.get("name_local", bd.get("to", country)))
	return name.to_upper()


## One spec per border of the stage.
func panel_specs(track: Track) -> Array:
	var out: Array = []
	if track == null or track.plan == null:
		return out
	for bd: Dictionary in track.plan.borders:
		var country := str(bd.get("to", ""))
		var bz := track.km_to_z(float(bd.get("km", 0.0)))
		if bz < 0.0 or bz > track.length_z:
			continue
		var ed := edges_at(track, bz)
		_names[country] = country_name(track, country)
		out.append(spec_for(country, _names[country], ed.x, ed.y))
	return out


## The road's shoulder edges at road position z (as ChunkContext.shoulder_edge() of its row): the gantry builder's rule.
static func edges_at(track: Track, z: float) -> Vector2:
	var zs := floorf(z / track.seg_len) * track.seg_len
	var half := track.lanes_at(zs) * track.lane_w * 0.5
	return Vector2(-half - track.shoulder_w, half + track.fuel_lane_factor(zs) * track.lane_w + track.shoulder_w)


func spec_for(country: String, name: String, left: float, right: float) -> Dictionary:
	var w := right - left + FASCIA_OUT * 2.0
	var draw := func(p: SignPainter, b: GeoBatch, r: Rect2, ppm: float, night: bool) -> void:
		_draw_fascia(p, b, r, ppm, name, night)
	return {"key": fascia_key(country, left, right), "w": w, "h": FASCIA_H, "ppm": PANEL_PPM, "glow": true, "draw": draw}


## Arcade's fascia (RoadRenderer._border_cover): white, the blue band at its foot, the European flag 1.2 m from its left
## end, the country's name in blue (cap height 0.55 m, baseline 0.95 m under the top, at most 70 % of the width).
## At night it is lit from inside: the white glows softly, the name and the flag's stars stronger.
static func _draw_fascia(p: SignPainter, b: GeoBatch, r: Rect2, s: float, name: String, night: bool) -> void:
	var white := Color(0.36, 0.36, 0.34) if night else SLAB
	var blue := Color(0.12, 0.26, 0.75) if night else SignPainter.EU_BLUE
	var flag := Color(0.03, 0.06, 0.2) if night else SignPainter.EU_BLUE
	var star := Color(0.9, 0.75, 0.1) if night else SignPainter.EU_YELLOW
	b.rect(r, white)
	b.rect(Rect2(r.position.x, r.end.y - BAND * s, r.size.x, BAND * s), Color(0.05, 0.1, 0.3) if night else SignPainter.EU_BLUE)
	var c := Vector2(r.position.x + 1.2 * s, r.position.y + 0.65 * s)
	b.rect(Rect2(c.x - 0.6 * s, c.y - 0.55 * s, 1.2 * s, 1.1 * s), flag)
	for i in 12:
		var a := TAU * float(i) / 12.0
		_star(b, c + Vector2(cos(a), sin(a)) * 0.36 * s, 0.07 * s, star)
	p.text(name, Vector2(r.get_center().x, r.position.y + 0.95 * s), 0.55 * s, blue, r.size.x * 0.7)


## A five-pointed star (the flag's stars; SignPainter draws them the same way on its border sign).
static func _star(b: GeoBatch, c: Vector2, r: float, col: Color) -> void:
	var pts: Array[Vector2] = []
	for i in 10:
		var a := -PI * 0.5 + PI * float(i) / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	for i in 10:
		b.tri(c, pts[i], pts[(i + 1) % 10], col)


func warmup_nodes() -> Array:
	var out: Array = []
	var k := Station.Kit.new()
	k.box(Transform3D.IDENTITY, Vector3(0.0, 0.5, 0.0), Vector3(0.5, 0.5, 0.5), SLAB, ROUGH_PAINT)
	k.quad(Vector3(-0.5, 1.02, -0.2), Vector3(0.5, 1.02, -0.2), Vector3(0.5, 1.02, 0.2), Vector3(-0.5, 1.02, 0.2), Vector3.UP, BAR_C,
		ROUGH_PAINT, Vector2(12.5, 1.0))
	out.append(Station.vpbr_node(k.arrays(), _mats, true, "BorderWarm"))
	if _atlas.ready and not _atlas.entries.is_empty():
		var pb := Station.PanelBuf.new()
		pb.framed(Transform3D.IDENTITY, -0.5, 0.5, 1.2, 2.0, 0.0, _atlas.uv(str(_atlas.entries.keys()[0])))
		out.append(Station.panel_node(pb.arrays(), _panel_material(), true, "BorderPanelWarm"))
	return out


func _panel_material() -> ShaderMaterial:
	if _panel_mat == null:
		_panel_mat = Station.panel_material(_mats if _mats != null else ModernMaterials.shared(), _atlas, 0.6)
	return _panel_mat


# --- chunks --------------------------------------------------------------------------------------------------------

## Main thread: the fascia cells (plain data for build()); without prepare() (tests) the fascias of the chunk go into a
## placeholder atlas at once.
func collect(ctx: ChunkContext) -> Variant:
	if not _prepared:
		var added := false
		for i in ctx.row_count() - 1:
			var sa: Dictionary = ctx.segs[i]
			if str(sa["cover"]) == "" or not bool(sa["cover_front"]):
				continue
			var country := str(sa["country_to"])
			var key := fascia_key(country, -ctx.shoulder_edge(i, -1), ctx.shoulder_edge(i, 1))
			if not _specs.has(key):
				var name := country_name(ctx.track, country)
				_specs[key] = spec_for(country, name, -ctx.shoulder_edge(i, -1), ctx.shoulder_edge(i, 1))
				added = true
		if added:
			_atlas.prepare(_specs.values(), null)
			if _panel_mat != null:
				_panel_mat.set_shader_parameter(&"albedo_tex", _atlas.albedo)
				_panel_mat.set_shader_parameter(&"emit_tex", _atlas.emission)
	return {"uv": _atlas.entries.duplicate()}


## WORKER THREAD.
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var uvs: Dictionary = (input as Dictionary).get("uv", {}) if input is Dictionary else {}
	var kit := Station.Kit.new()
	var pan := Station.PanelBuf.new()
	var lamps: Array = []
	var covers := 0
	var fronts := 0
	var pillars := 0
	var pools := 0
	var letterings: Array = []
	var rows := ctx.row_count()
	var seg_len := ctx.seg_len
	for i in rows - 1:
		var sa: Dictionary = ctx.segs[i]
		if str(sa["cover"]) == "" or bool(sa["tunnel"]):
			continue
		covers += 1
		var sb: Dictionary = ctx.segs[i + 1]
		var z0 := float(ctx.seg_a + i) * seg_len
		var z1 := z0 + seg_len
		var xl := -ctx.shoulder_edge(i, -1)
		var xr := ctx.shoulder_edge(i, 1)
		var a := xl - FASCIA_OUT
		var b := xr + FASCIA_OUT
		var starts := bool(sa["cover_front"])
		var ends := str(sb["cover"]) == ""
		var left_out := -ctx.rows_r[i]
		# soffit, slab top, the long sides (white over the blue band)
		kit.quad(ctx.local(z0, a, ROOF_H), ctx.local(z1, a, ROOF_H), ctx.local(z1, b, ROOF_H), ctx.local(z0, b, ROOF_H), Vector3.DOWN, SOFFIT,
			ROUGH_PAINT)
		kit.quad(ctx.local(z0, a, SLAB_TOP), ctx.local(z1, a, SLAB_TOP), ctx.local(z1, b, SLAB_TOP), ctx.local(z0, b, SLAB_TOP), Vector3.UP, TOP_C,
			ROUGH_CONCRETE)
		for side_x: float in [a, b]:
			var out := left_out if side_x == a else -left_out
			kit.quad(ctx.local(z0, side_x, ROOF_H), ctx.local(z1, side_x, ROOF_H), ctx.local(z1, side_x, ROOF_H + BAND),
				ctx.local(z0, side_x, ROOF_H + BAND), out, SignPainter.EU_BLUE, ROUGH_PAINT)
			kit.quad(ctx.local(z0, side_x, ROOF_H + BAND), ctx.local(z1, side_x, ROOF_H + BAND), ctx.local(z1, side_x, SLAB_TOP),
				ctx.local(z0, side_x, SLAB_TOP), out, SLAB, ROUGH_PAINT)
		if starts:
			fronts += 1
			var fwd := ctx.rows_f[i]
			var key := fascia_key(str(sa["country_to"]), xl, xr)
			var uv: Rect2 = uvs.get(key, Rect2())
			if uv.size.x > 0.0:
				pan.panel(ctx.local(z0, a, ROOF_H), ctx.local(z0, b, ROOF_H), ctx.local(z0, b, ROOF_H + FASCIA_H), ctx.local(z0, a, ROOF_H + FASCIA_H),
					-fwd, uv)
				letterings.append(str(sa["country_to"]))
			else:
				kit.quad(ctx.local(z0, a, ROOF_H), ctx.local(z0, b, ROOF_H), ctx.local(z0, b, ROOF_H + FASCIA_H), ctx.local(z0, a, ROOF_H + FASCIA_H),
					-fwd, SLAB, ROUGH_PAINT)
			# the raised part of the fascia above the slab: its back and its ends
			var zb := z0 + 0.25
			kit.quad(ctx.local(zb, a, SLAB_TOP), ctx.local(zb, b, SLAB_TOP), ctx.local(zb, b, ROOF_H + FASCIA_H), ctx.local(zb, a, ROOF_H + FASCIA_H),
				fwd, SLAB.darkened(0.1), ROUGH_PAINT)
			kit.quad(ctx.local(z0, a, ROOF_H + FASCIA_H), ctx.local(z0, b, ROOF_H + FASCIA_H), ctx.local(zb, b, ROOF_H + FASCIA_H),
				ctx.local(zb, a, ROOF_H + FASCIA_H), Vector3.UP, TOP_C, ROUGH_PAINT)
			for side_x: float in [a, b]:
				var out2 := left_out if side_x == a else -left_out
				kit.quad(ctx.local(z0, side_x, SLAB_TOP), ctx.local(zb, side_x, SLAB_TOP), ctx.local(zb, side_x, ROOF_H + FASCIA_H),
					ctx.local(z0, side_x, ROOF_H + FASCIA_H), out2, SLAB, ROUGH_PAINT)
		if ends:
			var fwd2 := ctx.rows_f[i + 1]
			kit.quad(ctx.local(z1, a, ROOF_H), ctx.local(z1, b, ROOF_H), ctx.local(z1, b, ROOF_H + BAND), ctx.local(z1, a, ROOF_H + BAND), fwd2,
				SignPainter.EU_BLUE, ROUGH_PAINT)
			kit.quad(ctx.local(z1, a, ROOF_H + BAND), ctx.local(z1, b, ROOF_H + BAND), ctx.local(z1, b, SLAB_TOP), ctx.local(z1, a, SLAB_TOP), fwd2,
				SLAB, ROUGH_PAINT)
		# pillars: Arcade's at the front, two more at the end of the roof (never inside a bend's sight corridor)
		if starts or ends:
			var zp := z0 + 0.5 if starts else z1 - 0.5
			for px: float in [xl - PILLAR_OUT, xr + PILLAR_OUT]:
				if ends and not starts and ctx.in_bend_corridor(zp, px):
					continue
				var g := minf(ctx.ground(zp, px), 0.0) - 0.3
				var f := ctx.frame(zp, px, 0.0)
				kit.box(f, Vector3(0.0, (g + ROOF_H) * 0.5, 0.0), Vector3(PILLAR_W, ROOF_H - g, PILLAR_W) * 0.5, PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8)
				kit.box(f, Vector3(0.0, (g + 0.35) * 0.5, 0.0), Vector3(PILLAR_W + 0.3, 0.35 - g, PILLAR_W + 0.3) * 0.5, PILLAR.darkened(0.2),
					ROUGH_CONCRETE, 1 | 2 | 4 | 8 | 16)
				pillars += 1
		# light bars every second segment (Arcade), lit at night; the flare layer gives each its white glow
		var zm := z0 + seg_len * 0.5
		if int(sa["index"]) % 2 == 0:
			for t: float in BAR_T:
				var x := lerpf(xl, xr, t)
				var h := ROOF_H - 0.03
				kit.quad(ctx.local(zm - BAR.y * 0.5, x - BAR.x * 0.5, h), ctx.local(zm + BAR.y * 0.5, x - BAR.x * 0.5, h),
					ctx.local(zm + BAR.y * 0.5, x + BAR.x * 0.5, h), ctx.local(zm - BAR.y * 0.5, x + BAR.x * 0.5, h), Vector3.DOWN, BAR_C,
					Vector2(0.3, 0.0), Vector2(12.5, 1.0))
				lamps.append({"pos": ctx.local(zm, x, h - 0.03), "dir": Vector3.DOWN, "role": "lamp", "color": BAR_GLOW, "size": 2.0,
					"range": 0.0, "energy": 0.6})
		# Arcade's light pool on the road (every fourth segment, at the road centre): its lamp sits inside the slab
		if int(sa["index"]) % POOL_EVERY == 0:
			lamps.append({"pos": ctx.local(zm, (xl + xr) * 0.5, (ROOF_H + SLAB_TOP) * 0.5 + 0.12), "dir": Vector3.DOWN, "role": "lamp",
				"color": BAR_GLOW, "size": 0.2, "range": POOL_RANGE_M, "energy": POOL_ENERGY})
			pools += 1
	if covers == 0:
		return {}
	return {"arrays": kit.arrays(), "panels": pan.arrays() if not pan.is_empty() else [], "lamps": lamps, "covers": covers,
		"fronts": fronts, "pillars": pillars, "pools": pools, "letterings": letterings, "triangles": kit.triangles() + pan.count * 2}


## Main thread: the structure in vpbr, the fascia panels, the lamps to the lights and flare layers.
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var arrays: Array = part.get("arrays", [])
	if arrays.is_empty():
		return
	var mats := Station.materials_of(ctx)
	if _mats == null:
		_mats = mats
	var casts := int(ctx.levels.get("shadow_casters", 0)) >= 1
	var mi := Station.vpbr_node(arrays, mats, casts, "Border")
	parent.add_child(mi)
	var panels: Array = part.get("panels", [])
	if not panels.is_empty():
		var pn := Station.panel_node(panels, _panel_material(), casts, "BorderPanels")
		pn.set_meta(&"lettering", part.get("letterings", []))
		parent.add_child(pn)
	var renderer: Variant = ctx.services.get("renderer")
	var lamps: Array = part.get("lamps", [])
	if renderer != null and not lamps.is_empty():
		(renderer as Object).call(&"add_lamps", mi, lamps)


func debug(part: Dictionary) -> Dictionary:
	return {"covers": int(part.get("covers", 0)), "fronts": int(part.get("fronts", 0)), "pillars": int(part.get("pillars", 0)),
		"pools": int(part.get("pools", 0)), "lamps": (part.get("lamps", []) as Array).size(), "letterings": part.get("letterings", []),
		"triangles": int(part.get("triangles", 0))}
