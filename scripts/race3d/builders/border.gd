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
##    stage's lettering atlas, drawn once in prepare() – never a Label3D), backlit at night;
##  * pillars 0.6 m outside the shoulder edges (pillar_plan()): Arcade's two at the front and two more at the end of the
##    roof – but none that could hide a sign (F1) and none inside a bend's sight corridor (F7).
## The booths are models of the props builder (props/customs_booth, AS1b) at Arcade's places on the shoulders. Arcade
## has neither a barrier nor a stop line at its border stations, so Modern has none either.
## Fairness: the soffit keeps Arcade's height (6.0 m) – the camera at 3.4 m sees every car under the roof as in Arcade.
## A sign standing under the roof is drawn by Arcade over its pillar (the same slice of its painter's order): in 3D that
## pillar would cover the sign (QA picture v2_border_day: "Tankstelle 15 km" on DEV half hidden), so it is left out.
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
const PILLAR_IN := 0.5             ## … this far inside the roof's front and end
const PLINTH_HALF := 0.425         ## half the size of a pillar's plinth (its front face: z − PLINTH_HALF)
## A pillar Arcade does not have stands only where no sign is behind it within this distance on its side: a sign d metres
## behind it can only be covered while the camera is d / (1 − r) from the sign (r = lateral offset of the pillar's
## inner face over that of the board's outer edge, both seen from the camera; ≥ 0.66 for a camera in a lane with the
## 2.5 m shoulder), i.e. a sign farther behind only while it is more than ~350 m away.
const SIGN_SCAN_M := 120.0
## Track puts the booths (props/customs_booth, 3.9 m long, model AABB z −3.2 .. 0.7) 5 m behind the border: a pillar
## in place of a front pillar stands behind them
const BOOTH_BACK_M := 9.0
const BAR := Vector2(1.8, 0.3)     ## light bar: across, along
const BAR_DROP := 0.1              ## the luminaire hangs this far below the soffit
## Arcade's glow round each light bar (RoadRenderer._border_cover: radius 2 m, alpha 0.3 × lights): flare radius = size ×
## 0.9; the flare layer gives a lamp near the camera only 35 % of its strength (the lamp itself carries the light there)
const BAR_GLOW_SIZE := 2.4
const BAR_GLOW_ENERGY := 1.2
const BAR_T: Array[float] = [0.25, 0.5, 0.75]
const POOL_EVERY := 4              ## a light pool every four segments (Arcade: k % 4)
const POOL_RANGE_M := 16.0
const POOL_ENERGY := 1.27          ## 0.7 at the centre with the lights layer's 0.55 per unit (Arcade: 0.7 × lights)
## Arcade's underside colour 8e959c is drawn flat-lit; under the real sun the soffit only gets the sky light – a lighter
## grey keeps it as light as Arcade's
const SOFFIT := Color("aab0b6")
## The soffit at night: lit by its light bars (the real lights reach it only from the pool lamps inside the slab) – a
## flood-lit surface (lamp channel 14), as bright as Arcade's lit underside
const SOFFIT_GLOW := Vector2(14.5, 0.3)
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
	return {"uv": _atlas.entries.duplicate(), "pillars": pillars_in_chunk(ctx)}


## Main thread: the pillars (pillar_plan()) of every roof that reaches into the chunk, those standing in it. The signs
## behind a roof are read from the track up to SIGN_SCAN_M beyond it – generated far enough ahead that the curve and
## crest warnings Track inserts later into segments already made are in place.
static func pillars_in_chunk(ctx: ChunkContext) -> Array:
	var out: Array = []
	var tr := ctx.track
	if tr == null:
		return out
	var len_s := ctx.seg_len
	var za := float(ctx.seg_a) * len_s
	var zb := float(ctx.seg_b) * len_s
	for zn: Dictionary in tr.zones:
		if str(zn.get("kind", "")) != "border":
			continue
		var bz := float(zn["z0"])
		var r0 := floorf(bz / len_s) * len_s
		var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
		if r0 > zb:
			break
		if r1 < za:
			continue
		tr.get_segment(tr.segment_index_at(r1 + SIGN_SCAN_M + tr.generation_lead_m()) + 2)
		var signs: Array = []
		for i in range(tr.segment_index_at(r0), tr.segment_index_at(r1 + SIGN_SCAN_M) + 1):
			var s := tr.get_segment(i)
			for sp: Variant in s.sprites:
				var it: Dictionary = sp
				if str(it.get("kind", "")) == "sign" and int(it.get("side", 1)) != 0:
					signs.append([float(it.get("z", s.z)), int(it.get("side", 1))])
		for p: Array in pillar_plan(r0, r1, bz, signs):
			if float(p[0]) >= za and float(p[0]) < zb:
				out.append(p)
	return out


## The pillars of a roof from r0 (start of its front segment) to r1 (end of its last segment) at the border bz:
## [[z, side, kind]] per side –
##  * "front": Arcade's, PILLAR_IN behind r0 – unless a sign of its side stands under the roof behind its front face
##    (Arcade draws such a sign over the pillar; in 3D the pillar would cover it). Then "moved": one behind that sign
##    and behind the booth (BOOTH_BACK_M behind bz), at least 2 m before the end pillar's place, where no sign of its
##    side stands within SIGN_SCAN_M behind it;
##  * "end": PILLAR_IN before r1 where no sign of its side stands within SIGN_SCAN_M behind it (Arcade has none there).
## A side may end up without a pillar (the roof is then carried by the other side's). build() leaves out the pillars
## other than Arcade's that stand in a bend's sight corridor (F7). signs: [[z, side]] of the signs from r0 to
## r1 + SIGN_SCAN_M. Pure.
static func pillar_plan(r0: float, r1: float, bz: float, signs: Array) -> Array:
	var out: Array = []
	for side: int in [-1, 1]:
		var zf := r0 + PILLAR_IN
		var last := -INF
		for s: Array in signs:
			if int(s[1]) == side and float(s[0]) >= zf - PLINTH_HALF and float(s[0]) <= r1:
				last = maxf(last, float(s[0]))
		if last == -INF:
			out.append([zf, side, "front"])
		else:
			var zm := maxf(bz + BOOTH_BACK_M, last + PLINTH_HALF + 0.3)
			if zm <= r1 - PILLAR_IN - 2.0 and not _sign_behind(signs, side, zm, zm + SIGN_SCAN_M):
				out.append([zm, side, "moved"])
		var ze := r1 - PILLAR_IN
		if not _sign_behind(signs, side, ze, ze + SIGN_SCAN_M):
			out.append([ze, side, "end"])
	return out


## True when a sign of `side` stands behind the front face of a pillar at z, up to z_to.
static func _sign_behind(signs: Array, side: int, z: float, z_to: float) -> bool:
	for s: Array in signs:
		if int(s[1]) == side and float(s[0]) >= z - PLINTH_HALF and float(s[0]) <= z_to:
			return true
	return false


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
			ROUGH_PAINT, SOFFIT_GLOW)
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
		# light bars every second segment (Arcade), lit at night; the flare layer gives each its white glow
		var zm := z0 + seg_len * 0.5
		if int(sa["index"]) % 2 == 0:
			for t: float in BAR_T:
				var x := lerpf(xl, xr, t)
				# a surface-mounted luminaire: its diffuser glows on the bottom and the sides (seen from the road at a
				# grazing angle a flat panel would be a hairline, Arcade draws a bright bar)
				var fb := ctx.frame(zm, x, ROOF_H - BAR_DROP * 0.5)
				kit.box(fb, Vector3.ZERO, Vector3(BAR.x, BAR_DROP, BAR.y) * 0.5, BAR_C, Vector2(0.3, 0.0), 1 | 2 | 4 | 8 | 32,
					Vector2(12.5, 1.0))
				lamps.append({"pos": ctx.local(zm, x, ROOF_H - BAR_DROP - 0.02), "dir": Vector3.DOWN, "role": "lamp", "color": BAR_GLOW,
					"size": BAR_GLOW_SIZE, "range": 0.0, "energy": BAR_GLOW_ENERGY})
		# Arcade's light pool on the road (every fourth segment, at the road centre): its lamp sits inside the slab
		if int(sa["index"]) % POOL_EVERY == 0:
			lamps.append({"pos": ctx.local(zm, (xl + xr) * 0.5, (ROOF_H + SLAB_TOP) * 0.5 + 0.12), "dir": Vector3.DOWN, "role": "lamp",
				"color": BAR_GLOW, "size": 0.2, "range": POOL_RANGE_M, "energy": POOL_ENERGY})
			pools += 1
	if covers == 0:
		return {}
	# pillars (pillar_plan(): none that could hide a sign, F1), those Arcade does not have never inside a bend's sight
	# corridor (F7)
	var pillar_at: Array = []
	var plan: Array = (input as Dictionary).get("pillars", []) if input is Dictionary else []
	for p: Array in plan:
		var zp := float(p[0])
		var row := clampi(int(floor(zp / seg_len)) - ctx.seg_a, 0, rows - 2)
		var sr: Dictionary = ctx.segs[row]
		if str(sr["cover"]) == "" or bool(sr["tunnel"]):
			continue
		var px := ctx.shoulder_edge(row, 1) + PILLAR_OUT if int(p[1]) > 0 else -ctx.shoulder_edge(row, -1) - PILLAR_OUT
		if str(p[2]) != "front" and ctx.in_bend_corridor(zp, px):
			continue
		var g := minf(ctx.ground(zp, px), 0.0) - 0.3
		var f := ctx.frame(zp, px, 0.0)
		kit.box(f, Vector3(0.0, (g + ROOF_H) * 0.5, 0.0), Vector3(PILLAR_W, ROOF_H - g, PILLAR_W) * 0.5, PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8)
		kit.box(f, Vector3(0.0, (g + 0.35) * 0.5, 0.0), Vector3(PLINTH_HALF, (0.35 - g) * 0.5, PLINTH_HALF), PILLAR.darkened(0.2),
			ROUGH_CONCRETE, 1 | 2 | 4 | 8 | 16)
		pillars += 1
		pillar_at.append([zp, px, str(p[2])])
	return {"arrays": kit.arrays(), "panels": pan.arrays() if not pan.is_empty() else [], "lamps": lamps, "covers": covers,
		"fronts": fronts, "pillars": pillars, "pillar_at": pillar_at, "pools": pools, "letterings": letterings,
		"triangles": kit.triangles() + pan.count * 2}


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
		"pillar_at": part.get("pillar_at", []), "pools": int(part.get("pools", 0)), "lamps": (part.get("lamps", []) as Array).size(), "letterings": part.get("letterings", []),
		"triangles": int(part.get("triangles", 0))}
