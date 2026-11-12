extends ChunkBuilder
## City builder of the mode "Modern" (v0.8.0, contract §6 R6, renderer inventory B/C): what Arcade draws along the road
## inside the City Limits besides the buildings (RoadRenderer._streetlight, _fence, frozen; the buildings are props):
##  * street lights – Track's "object" items "streetlight" (every road.streetlight_every_m = 33 m, sides alternating,
##    on the sidewalk 1.9 m beyond the paved edge) as the street-light model (props/streetlight, AS1b: tapered pole,
##    arm over the road, luminaire) in a MultiMesh per chunk, mirrored on the left (D24); without the model Arcade's
##    procedural lamp (8.5 m pole, 2.2 m arm, 0.9 m head). Their lamps go to the lights and flare layers through
##    renderer.add_lamps() (role "street": lit at night, Arcade's warm glow round the head, a light pool of 9 m whose
##    centre gets Arcade's 0.55 × lights – RoadRenderer._collect_static_lights);
##  * the fence of the city's scenery (scenery "fence": picket | hedge | wall | iron, colour, x beyond the sidewalk,
##    height, a gap of gap_m every gap_every_m – the driveways) on both sides, as real geometry: pickets with rails,
##    a hedge with a rounded top, a wall with a coping and piers, iron bars on a plinth with posts. Arcade draws them
##    only up to 240 m; here they belong to the chunk. Never inside a bend's sight corridor (F7): such pieces are left out;
##  * crosswalk data: where the road shader paints a crosswalk (road.crosswalk_every_m in the City Limits, not on
##    bridges) – debug part "crosswalks" (road positions), for tests and later users.
## props.gd leaves the "object" items to this builder as soon as it exists (its _skip_objects).
## Materials: vpbr (ModernMaterials.VPBR_STATIC / the model's materials). Shadows with structure casters.
## Builder rules: build() on worker threads – ctx snapshot and the plain tables of collect() only.
## Owner: R6 (wave 3). Docs: docs/renderer-modern-bauten.md.

const Station := preload("res://scripts/race3d/builders/station.gd")

const LIGHT_SET := "props/streetlight"
const LIGHT_LOD := "lod0"
## Light pool of a street light: Arcade's (radius 9 m, 0.55 × lights at the centre = POOL_LEVEL 0.55 × energy 1.0 of
## the lights layer)
const LAMP_RANGE_M := 9.0
const LAMP_ENERGY := 1.0
const LAMP_COLOUR := Color("fff0cf")
## Arcade's procedural street light (fallback without the model)
const POLE_H := 8.5
const POLE_W := 0.18
const ARM := 2.2
const POLE_C := Color("5b6066")
const HEAD_C := Color(1.0, 0.9, 0.65)
const ROUGH_METAL := Vector2(0.45, 0.5)
const ROUGH_PAINT := Vector2(0.6, 0.0)
const ROUGH_HEDGE := Vector2(0.95, 0.0)
const ROUGH_STONE := Vector2(0.85, 0.0)
const PICKET_EVERY := 0.25
const BAR_EVERY := 0.22
const PIER_EVERY := 6.0
## Shadow casters (contract §4.10 „Schatten“): street lights are structures (from „Niedrig“ on, levels.shadow_casters
## >= 1 – like the props builder's road furniture they stay thin lines); fences, hedges and walls are small scenery
## (only „Hoch“, >= 3)
const CAST_LIGHTS := 1
const CAST_FENCES := 3

var _renderer: Node
var _mats: ModernMaterials
var _requested := false
var _parts: Array = []             ## ModelFactory.multimesh_parts of the street light (main thread)
var _model_lamps: Array = []       ## lamp anchors of the model: [{pos, dir, size, color}]
var _crosswalk_every := 330.0
var _streetlight_every := 33.0


func id() -> String:
	return "city"


func setup(renderer: Node) -> void:
	_renderer = renderer
	var m: Variant = renderer.get("materials") if renderer != null else null
	_mats = m as ModernMaterials if m is ModernMaterials else ModernMaterials.shared()
	var cfg: Variant = renderer.get("cfg") if renderer != null else null
	if cfg is Dictionary:
		_read_config(cfg)


func _read_config(cfg: Dictionary) -> void:
	_crosswalk_every = float(ConfigLoader.lookup(cfg, "road.crosswalk_every_m", 330.0))
	_streetlight_every = float(ConfigLoader.lookup(cfg, "road.streetlight_every_m", 33.0))


## The street-light model is loaded with the stage (ModelDB, threaded).
func prepare(_ctx: Dictionary) -> void:
	if ModelDB.available():
		ModelDB.request([LIGHT_SET], [LIGHT_LOD], self)
		_requested = true


func prepare_pending() -> int:
	return ModelDB.pending() if _requested else 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _requested:
		ModelDB.release_all(self)


## Mesh parts and lamp anchors of the street-light model (main thread; [] without the model).
func _model() -> Array:
	if _parts.is_empty() and ModelDB.available() and ModelDB.has_model(LIGHT_SET):
		_parts = ModelFactory.multimesh_parts(LIGHT_SET, LIGHT_LOD, _mats if _mats != null else ModernMaterials.shared())
		_model_lamps.clear()
		var model: Dictionary = ModelDB.resolve(LIGHT_SET).get("model", {})
		for l: Variant in model.get("lights", []):
			var d: Dictionary = l
			var p: Array = d.get("pos", [0.0, 0.0, 0.0])
			var dv: Array = d.get("dir", [0.0, -1.0, 0.0])
			_model_lamps.append({"pos": Vector3(float(p[0]), float(p[1]), float(p[2])), "dir": Vector3(float(dv[0]), float(dv[1]), float(dv[2])),
				"size": float(d.get("size", 0.44)), "color": Color(str(d.get("color", "#fff0cf")))})
	return _parts


func warmup_nodes() -> Array:
	var out: Array = []
	var k := Station.Kit.new()
	k.box(Transform3D.IDENTITY, Vector3(0.0, 0.5, 0.0), Vector3(0.4, 0.5, 0.4), Color("5a7c44"), ROUGH_HEDGE)
	out.append(Station.vpbr_node(k.arrays(), _mats if _mats != null else ModernMaterials.shared(), true, "CityWarm"))
	var buf := PackedFloat32Array()
	_put(buf, Transform3D.IDENTITY)
	for p: Variant in _model():
		out.append(_mmi(p, buf, 1, false))
	return out


# --- chunks --------------------------------------------------------------------------------------------------------

## Main thread: the model's lamp anchors and whether it is there, the config (plain data for build()).
func collect(ctx: ChunkContext) -> Variant:
	if _renderer == null:
		_read_config(ctx.cfg)
		if not _requested and ModelDB.available():
			ModelDB.request([LIGHT_SET], [LIGHT_LOD], self)
			_requested = true
			var guard := 0
			while ModelDB.pending() > 0 and guard < 20000:
				OS.delay_msec(1)
				guard += 1
	var has := not _model().is_empty()
	return {"model": has, "lamps": _model_lamps.duplicate(true), "crosswalk_every": _crosswalk_every}


## WORKER THREAD.
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var inp: Dictionary = input if input is Dictionary else {}
	var has_model := bool(inp.get("model", false))
	var model_lamps: Array = inp.get("lamps", [])
	var crosswalk_every := float(inp.get("crosswalk_every", 330.0))
	var kit := Station.Kit.new()
	var right := PackedFloat32Array()
	var left := PackedFloat32Array()
	var lamps: Array = []
	var lights_list: Array = []
	var crosswalks: Array = []
	var fence_segments := 0
	var fence_dropped := 0
	var rows := ctx.row_count()
	var seg_len := ctx.seg_len
	for i in rows - 1:
		var seg: Dictionary = ctx.segs[i]
		if not bool(seg["city"]) or bool(seg["tunnel"]):
			continue
		var z0 := float(ctx.seg_a + i) * seg_len
		if not bool(seg["water"]) and fposmod(float(seg["z"]), crosswalk_every) < seg_len:
			crosswalks.append(snappedf(float(seg["z"]), 0.001))
		for it: Dictionary in seg["sprites"]:
			if str(it.get("kind", "")) != "object" or str(it.get("obj", "")) != "streetlight":
				continue
			var side := int(it.get("side", 1))
			var z := float(it.get("z", seg["z"]))
			var x := float(it.get("x", 0.0))
			var h := ctx.ground(z, x)
			var tr := ctx.frame(z, x, h)
			lights_list.append([snappedf(z, 0.001), side, snappedf(x, 0.001)])
			if has_model:
				var flipped := side < 0
				_put(left if flipped else right, mirror_x(tr) if flipped else tr)
				for l: Dictionary in model_lamps:
					var lp: Vector3 = l["pos"]
					var ld: Vector3 = l["dir"]
					if flipped:
						lp.x = -lp.x
						ld.x = -ld.x
					lamps.append({"pos": tr * lp, "dir": (tr.basis * ld).normalized(), "role": "street", "color": l.get("color", LAMP_COLOUR),
						"size": float(l.get("size", 0.44)), "range": LAMP_RANGE_M, "energy": LAMP_ENERGY})
			else:
				_procedural_light(kit, tr, side, lamps)
		if not bool(seg["water"]):
			var fd: Variant = (ctx.scenery_db.get(str(seg["scenery"]), {}) as Dictionary).get("fence")
			if fd is Dictionary:
				var res := _fence(ctx, kit, i, z0, fd as Dictionary)
				fence_segments += int(res.x)
				fence_dropped += int(res.y)
	if lights_list.is_empty() and kit.is_empty() and crosswalks.is_empty():
		return {}
	return {"arrays": kit.arrays() if not kit.is_empty() else [], "right": right, "left": left, "lamps": lamps, "lights": lights_list,
		"crosswalks": crosswalks, "fence_segments": fence_segments, "fence_dropped": fence_dropped, "triangles": kit.triangles()}


## Arcade's street light (RoadRenderer._streetlight) when the model is missing: pole, arm towards the road, head with
## its lit strip (lamp channel 12).
static func _procedural_light(kit: Station.Kit, tr: Transform3D, side: int, lamps: Array) -> void:
	var dir := -float(side)          # the arm reaches over the road
	kit.box(tr, Vector3(0.0, POLE_H * 0.5 - 0.15, 0.0), Vector3(POLE_W, POLE_H + 0.3, POLE_W) * 0.5, POLE_C, ROUGH_METAL, 1 | 2 | 4 | 8 | 16)
	var a := tr * Vector3(0.0, POLE_H, 0.0)
	var b := tr * Vector3(dir * ARM, POLE_H + 0.25, 0.0)
	var up := tr.basis.y * 0.06
	var side_v := tr.basis.z * 0.06
	kit.quad(a - up - side_v, b - up - side_v, b + up - side_v, a + up - side_v, -tr.basis.z, POLE_C, ROUGH_METAL)
	kit.quad(a - up + side_v, b - up + side_v, b + up + side_v, a + up + side_v, tr.basis.z, POLE_C, ROUGH_METAL)
	var head := Vector3(dir * ARM, POLE_H + 0.1, 0.0)
	kit.box(tr, head, Vector3(0.45, 0.12, 0.2), POLE_C, ROUGH_METAL, 1 | 2 | 4 | 8 | 16)
	kit.quad(tr * (head + Vector3(-0.38, -0.125, -0.15)), tr * (head + Vector3(0.38, -0.125, -0.15)), tr * (head + Vector3(0.38, -0.125, 0.15)),
		tr * (head + Vector3(-0.38, -0.125, 0.15)), -tr.basis.y, HEAD_C, Vector2(0.3, 0.0), Vector2(12.5, 1.0))
	lamps.append({"pos": tr * (head + Vector3(0.0, -0.16, 0.0)), "dir": -tr.basis.y, "role": "street", "color": LAMP_COLOUR, "size": 0.44,
		"range": LAMP_RANGE_M, "energy": LAMP_ENERGY})


## The fence of segment i (row i, road position z0) on both sides; returns (pieces drawn, pieces left out by F7).
static func _fence(ctx: ChunkContext, kit: Station.Kit, i: int, z0: float, fd: Dictionary) -> Vector2i:
	var style := str(fd.get("style", "picket"))
	var col := Color(str(fd.get("color", "#d8d2c4")))
	var off := float(fd.get("x", 0.6))
	var h := float(fd.get("h", 1.1))
	var every := float(fd.get("gap_every_m", 24.0))
	var gap := float(fd.get("gap_m", 3.5))
	var z1 := z0 + ctx.seg_len
	var drawn := 0
	var dropped := 0
	var seg_z := float(ctx.segs[i]["z"])
	for side: int in [-1, 1]:
		# Arcade's gaps (driveways): the same phase per side
		if every > 0.0 and fposmod(seg_z + (every * 0.5 if side > 0 else 0.0), every) < gap:
			continue
		var xa := float(side) * (ctx.shoulder_edge(i, side) + off)
		var xb := float(side) * (ctx.shoulder_edge(i + 1, side) + off)
		var zm := (z0 + z1) * 0.5
		if ctx.in_bend_corridor(zm, (xa + xb) * 0.5):
			dropped += 1
			continue
		drawn += 1
		var s := float(side)
		match style:
			"hedge":
				_hedge(ctx, kit, z0, z1, xa, xb, s, h, col)
			"wall":
				_wall(ctx, kit, z0, z1, xa, xb, s, h, col)
			"iron":
				_iron(ctx, kit, z0, z1, xa, xb, s, h, col)
			_:
				_picket(ctx, kit, z0, z1, xa, xb, s, h, col)
	return Vector2i(drawn, dropped)


## Lateral position of a fence along a segment (it follows the shoulder edge from row to row).
static func _fx(xa: float, xb: float, z0: float, z1: float, z: float) -> float:
	return lerpf(xa, xb, clampf((z - z0) / maxf(z1 - z0, 0.001), 0.0, 1.0))


## A hedge 0.8 m deep (away from the road) with a rounded top: face, chamfers, top, a darker foot.
static func _hedge(ctx: ChunkContext, kit: Station.Kit, z0: float, z1: float, xa: float, xb: float, s: float, h: float, col: Color) -> void:
	var d := 0.8 * s
	var c := 0.12
	var top := col.lightened(0.1)
	var foot := col.darkened(0.25)
	var g0 := minf(ctx.ground(z0, xa), 0.0) - 0.05
	var g1 := minf(ctx.ground(z1, xb), 0.0) - 0.05
	var road := -ctx.rows_r[int(clampf(ctx.row_of(z0), 0.0, float(ctx.row_count() - 1)))] * s
	kit.quad(ctx.local(z0, xa, g0), ctx.local(z1, xb, g1), ctx.local(z1, xb, 0.25), ctx.local(z0, xa, 0.25), road, foot, ROUGH_HEDGE)
	kit.quad(ctx.local(z0, xa, 0.25), ctx.local(z1, xb, 0.25), ctx.local(z1, xb, h - c), ctx.local(z0, xa, h - c), road, col, ROUGH_HEDGE)
	kit.quad(ctx.local(z0, xa, h - c), ctx.local(z1, xb, h - c), ctx.local(z1, xb + c * s, h), ctx.local(z0, xa + c * s, h), road + Vector3.UP,
		col.lerp(top, 0.5), ROUGH_HEDGE)
	kit.quad(ctx.local(z0, xa + c * s, h), ctx.local(z1, xb + c * s, h), ctx.local(z1, xb + d - c * s, h), ctx.local(z0, xa + d - c * s, h),
		Vector3.UP, top, ROUGH_HEDGE)
	kit.quad(ctx.local(z0, xa + d - c * s, h), ctx.local(z1, xb + d - c * s, h), ctx.local(z1, xb + d, h - c), ctx.local(z0, xa + d, h - c),
		-road + Vector3.UP, col.lerp(top, 0.5), ROUGH_HEDGE)
	kit.quad(ctx.local(z0, xa + d, g0), ctx.local(z1, xb + d, g1), ctx.local(z1, xb + d, h - c), ctx.local(z0, xa + d, h - c), -road, col.darkened(0.1),
		ROUGH_HEDGE)


## A wall 0.25 m thick with a coping, a pier every PIER_EVERY metres of road.
static func _wall(ctx: ChunkContext, kit: Station.Kit, z0: float, z1: float, xa: float, xb: float, s: float, h: float, col: Color) -> void:
	var t := 0.25 * s
	var cap := col.lightened(0.15)
	var g0 := minf(ctx.ground(z0, xa), 0.0) - 0.1
	var g1 := minf(ctx.ground(z1, xb), 0.0) - 0.1
	var road := -ctx.rows_r[int(clampf(ctx.row_of(z0), 0.0, float(ctx.row_count() - 1)))] * s
	kit.quad(ctx.local(z0, xa, g0), ctx.local(z1, xb, g1), ctx.local(z1, xb, h), ctx.local(z0, xa, h), road, col, ROUGH_STONE)
	kit.quad(ctx.local(z0, xa + t, g0), ctx.local(z1, xb + t, g1), ctx.local(z1, xb + t, h), ctx.local(z0, xa + t, h), -road, col.darkened(0.08), ROUGH_STONE)
	# coping: a little wider and higher
	var o := 0.04 * s
	kit.quad(ctx.local(z0, xa - o, h), ctx.local(z1, xb - o, h), ctx.local(z1, xb - o, h + 0.08), ctx.local(z0, xa - o, h + 0.08), road, cap, ROUGH_STONE)
	kit.quad(ctx.local(z0, xa - o, h + 0.08), ctx.local(z1, xb - o, h + 0.08), ctx.local(z1, xb + t + o, h + 0.08), ctx.local(z0, xa + t + o, h + 0.08),
		Vector3.UP, cap, ROUGH_STONE)
	kit.quad(ctx.local(z0, xa + t + o, h), ctx.local(z1, xb + t + o, h), ctx.local(z1, xb + t + o, h + 0.08), ctx.local(z0, xa + t + o, h + 0.08), -road,
		cap.darkened(0.08), ROUGH_STONE)
	var zp := ceilf(z0 / PIER_EVERY) * PIER_EVERY
	while zp < z1:
		var x := _fx(xa, xb, z0, z1, zp)
		var f := ctx.frame(zp, x + t * 0.5, 0.0)
		kit.box(f, Vector3(0.0, (h + 0.18 + g0) * 0.5, 0.0), Vector3(0.38, h + 0.18 - g0, 0.38) * 0.5, col.darkened(0.06), ROUGH_STONE, 1 | 2 | 4 | 8 | 16)
		zp += PIER_EVERY


## Iron railing: a light plinth, bars every BAR_EVERY metres, a top rail, a post every PIER_EVERY metres.
static func _iron(ctx: ChunkContext, kit: Station.Kit, z0: float, z1: float, xa: float, xb: float, s: float, h: float, col: Color) -> void:
	var base := col.lightened(0.35)
	var t := 0.3 * s
	var g0 := minf(ctx.ground(z0, xa), 0.0) - 0.1
	var g1 := minf(ctx.ground(z1, xb), 0.0) - 0.1
	var road := -ctx.rows_r[int(clampf(ctx.row_of(z0), 0.0, float(ctx.row_count() - 1)))] * s
	kit.quad(ctx.local(z0, xa, g0), ctx.local(z1, xb, g1), ctx.local(z1, xb, 0.3), ctx.local(z0, xa, 0.3), road, base, ROUGH_STONE)
	kit.quad(ctx.local(z0, xa, 0.3), ctx.local(z1, xb, 0.3), ctx.local(z1, xb + t, 0.3), ctx.local(z0, xa + t, 0.3), Vector3.UP, base, ROUGH_STONE)
	var mid := t * 0.5
	# rails at the top and just above the plinth (thin boxes along the segment)
	for y: float in [0.42, h - 0.06]:
		kit.quad(ctx.local(z0, xa + mid - 0.02 * s, y), ctx.local(z1, xb + mid - 0.02 * s, y), ctx.local(z1, xb + mid - 0.02 * s, y + 0.05),
			ctx.local(z0, xa + mid - 0.02 * s, y + 0.05), road, col, ROUGH_METAL)
		kit.quad(ctx.local(z0, xa + mid - 0.02 * s, y + 0.05), ctx.local(z1, xb + mid - 0.02 * s, y + 0.05), ctx.local(z1, xb + mid + 0.02 * s, y + 0.05),
			ctx.local(z0, xa + mid + 0.02 * s, y + 0.05), Vector3.UP, col, ROUGH_METAL)
	var zb := ceilf(z0 / BAR_EVERY) * BAR_EVERY
	while zb < z1:
		var x := _fx(xa, xb, z0, z1, zb) + mid
		var f := ctx.frame(zb, x, 0.0)
		var post := fposmod(zb, PIER_EVERY) < BAR_EVERY
		if post:
			kit.box(f, Vector3(0.0, (0.3 + h + 0.12) * 0.5, 0.0), Vector3(0.07, h + 0.12 - 0.3, 0.07) * 0.5, col, ROUGH_METAL, 1 | 2 | 4 | 8 | 16)
		else:
			# a bar: its face to the road and its back (two quads, the ends are too thin to show), a spear tip
			var w := 0.012
			for sgn: float in [-1.0, 1.0]:
				var o := Vector3(sgn * 0.011 * s, 0.0, 0.0)
				kit.quad(f * (Vector3(0.0, 0.3, -w) + o), f * (Vector3(0.0, 0.3, w) + o), f * (Vector3(0.0, h, w) + o), f * (Vector3(0.0, h, -w) + o),
					road * -sgn, col, ROUGH_METAL)
			kit.tri(f * Vector3(0.0, h, -w * 2.0), f * Vector3(0.0, h, w * 2.0), f * Vector3(0.0, h + 0.07, 0.0), road, col, ROUGH_METAL)
		zb += BAR_EVERY


## Picket fence: two rails, pickets every PICKET_EVERY metres with pointed tops, a post every PIER_EVERY metres.
static func _picket(ctx: ChunkContext, kit: Station.Kit, z0: float, z1: float, xa: float, xb: float, s: float, h: float, col: Color) -> void:
	var rail := col.darkened(0.12)
	var road := -ctx.rows_r[int(clampf(ctx.row_of(z0), 0.0, float(ctx.row_count() - 1)))] * s
	var back := 0.04 * s
	for y: float in [h * 0.22, h * 0.68]:
		kit.quad(ctx.local(z0, xa + back, y), ctx.local(z1, xb + back, y), ctx.local(z1, xb + back, y + h * 0.08), ctx.local(z0, xa + back, y + h * 0.08),
			road, rail, ROUGH_PAINT)
		kit.quad(ctx.local(z0, xa + back, y + h * 0.08), ctx.local(z1, xb + back, y + h * 0.08), ctx.local(z1, xb + back * 2.0, y + h * 0.08),
			ctx.local(z0, xa + back * 2.0, y + h * 0.08), Vector3.UP, rail, ROUGH_PAINT)
	var zq := ceilf(z0 / PICKET_EVERY) * PICKET_EVERY
	while zq < z1:
		var x := _fx(xa, xb, z0, z1, zq)
		var f := ctx.frame(zq, x, 0.0)
		var post := fposmod(zq, PIER_EVERY) < PICKET_EVERY
		var w := 0.045 if not post else 0.06
		var top := h - 0.12 if not post else h + 0.05
		var g := minf(ctx.ground(zq, x), 0.0)
		var out := Vector3(s, 0.0, 0.0)
		# the picket: its face to the road, its back, the pointed top (both sides)
		kit.quad(f * Vector3(-0.0, g, -w), f * Vector3(0.0, g, w), f * Vector3(0.0, top, w), f * Vector3(0.0, top, -w), road, col, ROUGH_PAINT)
		kit.quad(f * (Vector3(0.0, g, -w) + out * 0.02), f * (Vector3(0.0, g, w) + out * 0.02), f * (Vector3(0.0, top, w) + out * 0.02),
			f * (Vector3(0.0, top, -w) + out * 0.02), -road, col.darkened(0.1), ROUGH_PAINT)
		if not post:
			kit.tri(f * Vector3(0.0, top, -w), f * Vector3(0.0, top, w), f * Vector3(0.0, top + 0.12, 0.0), road, col, ROUGH_PAINT)
			kit.tri(f * (Vector3(0.0, top, -w) + out * 0.02), f * (Vector3(0.0, top, w) + out * 0.02), f * (Vector3(0.0, top + 0.12, 0.0) + out * 0.02),
				-road, col.darkened(0.1), ROUGH_PAINT)
		zq += PICKET_EVERY


## The mirror image of a transform in the plane x = 0 as a proper transform (props.gd, D24): what an instance needs
## inside a MultiMesh node that is itself mirrored in x.
static func mirror_x(t: Transform3D) -> Transform3D:
	var b := t.basis
	return Transform3D(Basis(Vector3(b.x.x, -b.x.y, -b.x.z), Vector3(-b.y.x, b.y.y, b.y.z), Vector3(-b.z.x, b.z.y, b.z.z)),
		Vector3(-t.origin.x, t.origin.y, t.origin.z))


## Appends a transform in the layout of MultiMesh.buffer.
static func _put(buf: PackedFloat32Array, t: Transform3D) -> void:
	var b := t.basis
	var o := t.origin
	buf.append_array(PackedFloat32Array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z]))


## A MultiMeshInstance3D of one model part with n transforms (mirrored: the node is mirrored in x, D24).
static func _mmi(part: Variant, buf: PackedFloat32Array, n: int, mirrored: bool) -> MultiMeshInstance3D:
	var p: Dictionary = part
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = p["mesh"]
	mm.instance_count = n
	var own: Transform3D = p.get("transform", Transform3D.IDENTITY)
	if own == Transform3D.IDENTITY:
		mm.buffer = buf
	else:
		for i in n:
			var o := i * 12
			var t := Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
				Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
			mm.set_instance_transform(i, t * own)
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	if mirrored:
		node.basis = Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
	return node


## Main thread: the street lights (MultiMesh per part and side), fences and procedural lights in vpbr, the lamps.
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var right: PackedFloat32Array = part.get("right", PackedFloat32Array())
	var left: PackedFloat32Array = part.get("left", PackedFloat32Array())
	var arrays: Array = part.get("arrays", [])
	if right.is_empty() and left.is_empty() and arrays.is_empty():
		return
	var casters := int(ctx.levels.get("shadow_casters", 0))
	var cast_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casters >= CAST_LIGHTS else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.name = "City"
	parent.add_child(holder)
	if not arrays.is_empty():
		holder.add_child(Station.vpbr_node(arrays, Station.materials_of(ctx), casters >= CAST_FENCES, "Fences"))
	var parts := _model()
	for side_buf: Array in [[right, false], [left, true]]:
		var buf: PackedFloat32Array = side_buf[0]
		if buf.is_empty():
			continue
		for p: Variant in parts:
			var node := _mmi(p, buf, buf.size() / 12, bool(side_buf[1]))
			node.name = "StreetLights"
			node.cast_shadow = cast_mode
			holder.add_child(node)
	holder.set_meta(&"lights", (part.get("lights", []) as Array).size())
	var renderer: Variant = ctx.services.get("renderer")
	var lamps: Array = part.get("lamps", [])
	if renderer != null and not lamps.is_empty():
		(renderer as Object).call(&"add_lamps", holder, lamps)


func debug(part: Dictionary) -> Dictionary:
	return {"lights": part.get("lights", []), "lamps": (part.get("lamps", []) as Array).size(), "crosswalks": part.get("crosswalks", []),
		"fence_segments": int(part.get("fence_segments", 0)), "fence_dropped": int(part.get("fence_dropped", 0)),
		"triangles": int(part.get("triangles", 0))}
