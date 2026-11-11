extends ChunkBuilder
## Road builder of the mode "Modern" (v0.8.0, contract §6 R1): the paved road of a chunk as ONE mesh surface with one
## shared material (assets/shaders/modern/road.gdshader) – asphalt per road type, shoulders, the median strip of
## the Autobahn, the gravel verge of a country road, sidewalks and curbs in the City Limits, the fuel lane, with
## fractional lane counts in the transitions. All paint is in the shader: the mesh only says, per segment, where
## the edges are and what the segment carries (flag bits below); two triangles per segment outside the City
## Limits, fourteen inside.
##
## Cross-section (Arcade's, RoadRenderer._draw_ground): asphalt from the left edge -lanes × lane_w / 2 to the right
## edge of the regular lanes plus the fuel lane; beside it at road level 2.5 m on each side (paved shoulder / strip
## and grass of the median / gravel verge / the paved walkway strip of a tunnel; on a bridge outside the City
## Limits 0.4 m more, up to the railing). In the City Limits the band ends at the asphalt and sidewalks stand
## 0.14 m higher behind curbs of 0.25 m. The outer edge is exactly ChunkContext.shoulder_edge(): the terrain
## builder starts there with the same numbers, so the two meshes meet without a gap.
##
## Vertex format: see the shader. Vertices are not shared between segments (flags and lane counts are per segment).
## The z coordinate of the paint is the road position modulo z_period, a multiple of every dash cycle.
## The mesh is on render layer 2 (GROUND_LAYERS): the real spot and omni lights of the lights layer leave the
## ground out, it takes their light analytically (inc/pools.gdshaderinc, inc/headlight.gdshaderinc). It casts no
## shadow and receives the sun's.
## Builder rules: build() runs on worker threads for several chunks at once – it reads only the snapshot arrays of
## its ChunkContext and the configuration values set before the first build; every position comes from
## ctx.local(). Without a renderer (unit tests) everything works; the material then comes from
## ModernMaterials.shared() and is not registered for the light pools.
## Owner: renderer core (R1). Docs: docs/renderer-modern.md.

const GROUND_LAYERS := 2           ## render layer of ground meshes (bit 1): no positional light reaches it
const CURB_H := 0.14               ## height of sidewalks and curbs (Arcade: curb_h)
const CURB_W := 0.25
const DECK_EXTRA_M := 0.4          ## Track.BRIDGE_DECK_EXTRA_M: paved up to the railing on a bridge
const START_LINE_Z := 14.0         ## road position of the start line (Arcade)
const GROUND_BLEND_M := 150.0      ## RoadRenderer.GROUND_BLEND_M: outskirts ground blends into the centre ground
const F_EDGE := 1                  ## edge lines (not in the City Limits)
const F_SEP_WIDE := 2              ## the right edge line is the wide separator of the fuel lane
const F_FUEL_EDGE := 4             ## edge line of the fuel lane
const F_WEDGE := 8                 ## hatch stripe of the opening fuel lane
const F_CHECKER := 16              ## start / finish line
const F_CROSSWALK := 32
const F_TUNNEL := 64
const F_DECK := 128                ## bridge deck outside the City Limits
const F_RAIL_L := 256              ## guardrail on the left / right outer edge (contact shadow)
const F_RAIL_R := 512
const F_CITY := 1024               ## curbs beside the asphalt
const KIND_BAND := 0.0
const KIND_SIDEWALK := 1.0
const KIND_CURB_TOP := 2.0
const KIND_CURB_FACE := 3.0
const MESH_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
const ROAD_TYPES := {"autobahn": 0.0, "landstrasse": 1.0, "city": 2.0}
const GRASS_DEFAULT: Array[String] = ["#5d9a3e", "#56913a"]

var material: ShaderMaterial       ## shared by every road chunk of the stage
var z_period := 1440.0             ## the paint's z coordinate is the road position modulo this (metres)
var detail := 1.0                  ## strength of the fine detail of the shader

var _configured := false
var _crosswalk_every := 330.0
var _edge_line := 0.3
var _lane_line := 0.15
var _dash := {"autobahn": Vector2i(2, 4), "landstrasse": Vector2i(2, 4), "city": Vector2i(1, 2)}
var _post_every := 2               ## segments between guardrail posts
var _renderer: Object


## Vertex arrays of one chunk while it is built (one per build() call: nothing of it lives in the builder).
class Buf extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()

	## One quad between the near row (a) and the far row (b): corners a0, a1 (near) and b0, b1 (far), the UV x of
	## each, its kind, CUSTOM0 of the near and of the far row, CUSTOM1 and the ground colour of the segment.
	func quad(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, na: Vector3, nb: Vector3, xa0: float, xa1: float, xb0: float,
			xb1: float, zr: float, seg_len: float, kind: float, ca: Color, cb: Color, data: Color, ground: Color) -> void:
		var o := v.size()
		v.append(a0)
		v.append(a1)
		v.append(b1)
		v.append(b0)
		n.append(na)
		n.append(na)
		n.append(nb)
		n.append(nb)
		uv.append(Vector2(xa0, zr))
		uv.append(Vector2(xa1, zr))
		uv.append(Vector2(xb1, zr + seg_len))
		uv.append(Vector2(xb0, zr + seg_len))
		uv2.append(Vector2(0.0, kind))
		uv2.append(Vector2(0.0, kind))
		uv2.append(Vector2(seg_len, kind))
		uv2.append(Vector2(seg_len, kind))
		for q in 2:
			c0.append(ca.r)
			c0.append(ca.g)
			c0.append(ca.b)
			c0.append(ca.a)
		for q in 2:
			c0.append(cb.r)
			c0.append(cb.g)
			c0.append(cb.b)
			c0.append(cb.a)
		for q in 4:
			c1.append(data.r)
			c1.append(data.g)
			c1.append(data.b)
			c1.append(data.a)
			col.append(ground)
		# front faces are clockwise: the winding follows the normal
		if (b1 - a0).cross(a1 - a0).dot(na + nb) >= 0.0:
			idx.append(o)
			idx.append(o + 1)
			idx.append(o + 2)
			idx.append(o)
			idx.append(o + 2)
			idx.append(o + 3)
		else:
			idx.append(o)
			idx.append(o + 2)
			idx.append(o + 1)
			idx.append(o)
			idx.append(o + 3)
			idx.append(o + 2)


func id() -> String:
	return "road"


## Hook of the renderer (main thread, once per stage, before any chunk): configuration, the shared material and its
## registration for the light pools.
func setup(renderer: Node) -> void:
	_renderer = renderer
	if renderer == null:
		return
	var cfg: Variant = renderer.get("cfg")
	if cfg is Dictionary:
		configure(cfg)
	_material()
	if renderer.has_method(&"add_pool_material"):
		renderer.call(&"add_pool_material", material)


## Quality: nothing of the road depends on it – markings, edges and their geometry are never thinned out (Rule 9).
## Only the fine detail of the asphalt follows "Details" a little (0.7 / 1 / 1).
func apply_quality(levels: Dictionary) -> void:
	detail = 0.7 if int(levels.get("details", 1)) <= 0 else 1.0
	if material != null:
		material.set_shader_parameter("detail", detail)


## Reads the values the mesh and the paint depend on (config render.* and road.*). Called by setup(); without a
## renderer by the first collect().
func configure(cfg: Dictionary) -> void:
	_configured = true
	var r: Dictionary = ConfigLoader.lookup(cfg, "render", {})
	_edge_line = float(r.get("edge_line_m", 0.3))
	_lane_line = float(r.get("lane_line_m", 0.15))
	var stripes: Dictionary = r.get("stripes", {})
	var dashes: Dictionary = stripes.get("dash", {})
	for road: String in ROAD_TYPES:
		var d: Array = dashes.get(road, [int(stripes.get("dash_on", 2)), int(stripes.get("dash_off", 4))])
		_dash[road] = Vector2i(maxi(1, int(d[0])), maxi(0, int(d[1])))
	_crosswalk_every = float(ConfigLoader.lookup(cfg, "road.crosswalk_every_m", 330.0))
	var seg_len := float(r.get("segment_length_m", 3.0))
	# the paint's z coordinate wraps where every dash cycle, the post spacing and the 72 m cells of the detail end
	var cycle := 24
	for road: String in ROAD_TYPES:
		var dv: Vector2i = _dash[road]
		cycle = _lcm(cycle, dv.x + dv.y)
	cycle = _lcm(cycle, _post_every)
	z_period = float(cycle) * seg_len * ceilf(1400.0 / (float(cycle) * seg_len))


static func _lcm(a: int, b: int) -> int:
	var x := a
	var y := b
	while y != 0:
		var t := x % y
		x = y
		y = t
	return a / maxi(x, 1) * b


## Main thread: what build() needs beyond the snapshot – where the ground of the outskirts blends into the ground
## of the city centre (RoadRenderer._grass_color).
func collect(ctx: ChunkContext) -> Variant:
	if not _configured:
		configure(ctx.cfg)
	var out := {"center_z": -1.0, "outskirts": "", "center": ""}
	if ctx.track != null and ctx.track.plan != null:
		var plan: StagePlan = ctx.track.plan
		if plan.city_scenery_center != "":
			out["center_z"] = ctx.track.km_to_z(plan.city_center_km)
			out["outskirts"] = plan.city_scenery_outskirts
			out["center"] = plan.city_scenery_center
	return out


## WORKER THREAD. Returns the vertex arrays of the chunk ({"arrays": Array for ArrayMesh, …}) and plain counters.
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var buf := Buf.new()
	var rows := ctx.row_count()
	var seg_len := ctx.seg_len
	var lw := ctx.lane_w
	var sh := ctx.shoulder_w
	var blend: Dictionary = input if input is Dictionary else {}
	var center_z := float(blend.get("center_z", -1.0))
	var grass_cache := {}
	# one normal per row: up, tilted with the grade
	var normals := PackedVector3Array()
	normals.resize(rows)
	for i in rows:
		var t := ctx.rows_o[mini(i + 1, rows - 1)] - ctx.rows_o[maxi(i - 1, 0)]
		normals[i] = ctx.rows_r[i].cross(t).normalized() if t.length_squared() > 1.0e-9 else Vector3.UP
	var flags_all := 0
	var lines_max := 0
	var city_segments := 0
	for i in rows - 1:
		var sa: Dictionary = ctx.segs[i]
		var sb: Dictionary = ctx.segs[i + 1]
		var z0 := float(ctx.seg_a + i) * seg_len
		var z1 := z0 + seg_len
		var ea := ctx.rows_edge[i]
		var eb := ctx.rows_edge[i + 1]
		var la := ea.x
		var lb := eb.x
		var ma := -la
		var mb := -lb
		var ra := ea.y
		var rb := eb.y
		var lanes_a := float(sa["lanes"])
		var lanes_b := float(sb["lanes"])
		var fuel_a := float(sa["fuel_lane"])
		var fuel_b := float(sb["fuel_lane"])
		var city := bool(sa["city"])
		var tunnel := bool(sa["tunnel"])
		var water := bool(sa["water"])
		var seg_index := int(sa["index"])
		# what the segment carries (Arcade: _draw_markings, _draw_structures)
		var flags := 0
		if not city:
			flags |= F_EDGE
		if fuel_a > 0.02:
			flags |= F_SEP_WIDE
		if fuel_a > 0.02 or fuel_b > 0.02:
			flags |= F_FUEL_EDGE
		if fuel_a > 0.05 and fuel_a < 0.98 and fuel_b > fuel_a and seg_index % 2 == 0 and rb - mb > 0.9:
			flags |= F_WEDGE
		if absf(z0 + seg_len * 0.5 - ctx.length_z) <= seg_len * 0.5 or absf(z0 + seg_len * 0.5 - START_LINE_Z) <= seg_len * 0.5:
			flags |= F_CHECKER
		elif city and not water and fposmod(float(sa["z"]), _crosswalk_every) < seg_len:
			flags |= F_CROSSWALK
		if tunnel:
			flags |= F_TUNNEL
		elif bool(sa["guardrail"]):
			flags |= F_RAIL_L
			if fuel_a < 0.01 and fuel_b < 0.01 and str(sa["cover"]) == "":
				flags |= F_RAIL_R
		var curbs := city and not tunnel
		if curbs:
			flags |= F_CITY
			city_segments += 1
		elif water and not tunnel:
			flags |= F_DECK
		# lane lines: i = 1 .. n - 1, without those closer than 0.6 m to the right edge of the lanes on either row
		var lines := 0
		var n_lanes := int(ceil(maxf(lanes_a, lanes_b) - 0.01))
		for q in range(1, n_lanes):
			if la + float(q) * lw > ma - 0.6 or lb + float(q) * lw > mb - 0.6:
				break
			lines = q
		flags_all |= flags
		lines_max = maxi(lines_max, lines)
		var wear := clampf(absf(float(sa["curve"])) * 1.5 + (0.3 if city else 0.0) + (0.25 if fuel_a > 0.02 else 0.0), 0.0, 1.0)
		var data := Color(float(lines), float(ROAD_TYPES.get(str(sa["road"]), 0.0)), float(flags), wear)
		var ground := _ground(ctx, sa, blend, center_z, grass_cache)
		var ca := Color(la, ma, ra, rb - ra)
		var cb := Color(lb, mb, rb, rb - ra)
		var zr := fposmod(z0, z_period)
		var na := normals[i]
		var nb := normals[i + 1]
		# the band at road level
		var out_a := 0.0 if curbs else (sh + (DECK_EXTRA_M if (flags & F_DECK) != 0 else 0.0))
		var xa0 := la - out_a
		var xa1 := ra + out_a
		var xb0 := lb - out_a
		var xb1 := rb + out_a
		buf.quad(ctx.local(z0, xa0, 0.0), ctx.local(z0, xa1, 0.0), ctx.local(z1, xb0, 0.0), ctx.local(z1, xb1, 0.0), na, nb,
			xa0, xa1, xb0, xb1, zr, seg_len, KIND_BAND, ca, cb, data, ground)
		if not curbs:
			continue
		# City Limits: curb face, curb top and sidewalk on both sides
		for side: int in [-1, 1]:
			var s := float(side)
			var e_a := la if side < 0 else ra
			var e_b := lb if side < 0 else rb
			var right_a := ctx.rows_r[i] * -s
			var right_b := ctx.rows_r[i + 1] * -s
			# face: from the road up to the curb, looking at the road; its UV x is the height
			buf.quad(ctx.local(z0, e_a, 0.0), ctx.local(z0, e_a, CURB_H), ctx.local(z1, e_b, 0.0), ctx.local(z1, e_b, CURB_H),
				right_a, right_b, 0.0, CURB_H, 0.0, CURB_H, zr, seg_len, KIND_CURB_FACE, ca, cb, data, ground)
			buf.quad(ctx.local(z0, e_a, CURB_H), ctx.local(z0, e_a + s * CURB_W, CURB_H), ctx.local(z1, e_b, CURB_H),
				ctx.local(z1, e_b + s * CURB_W, CURB_H), na, nb, e_a, e_a + s * CURB_W, e_b, e_b + s * CURB_W, zr, seg_len,
				KIND_CURB_TOP, ca, cb, data, ground)
			buf.quad(ctx.local(z0, e_a + s * CURB_W, CURB_H), ctx.local(z0, e_a + s * sh, CURB_H), ctx.local(z1, e_b + s * CURB_W, CURB_H),
				ctx.local(z1, e_b + s * sh, CURB_H), na, nb, e_a + s * CURB_W, e_a + s * sh, e_b + s * CURB_W, e_b + s * sh, zr, seg_len,
				KIND_SIDEWALK, ca, cb, data, ground)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = buf.v
	arrays[Mesh.ARRAY_NORMAL] = buf.n
	arrays[Mesh.ARRAY_TEX_UV] = buf.uv
	arrays[Mesh.ARRAY_TEX_UV2] = buf.uv2
	arrays[Mesh.ARRAY_CUSTOM0] = buf.c0
	arrays[Mesh.ARRAY_CUSTOM1] = buf.c1
	arrays[Mesh.ARRAY_COLOR] = buf.col
	arrays[Mesh.ARRAY_INDEX] = buf.idx
	return {"arrays": arrays, "vertices": buf.v.size(), "triangles": buf.idx.size() / 3, "segments": rows - 1, "flags": flags_all,
		"lines_max": lines_max, "city_segments": city_segments}


## Ground colour beside the road of a segment: the mean of the scenery's two grass bands (Modern has no stripes),
## blended into the ground of the city centre before its start (RoadRenderer._grass_color; snow is the shader's).
func _ground(ctx: ChunkContext, seg: Dictionary, blend: Dictionary, center_z: float, cache: Dictionary) -> Color:
	var scen_id := str(seg["scenery"])
	var c := _grass_of(ctx, scen_id, cache)
	if bool(seg["city"]) and center_z > 0.0 and scen_id == str(blend.get("outskirts", "")):
		var f := ground_blend(float(seg["z"]), center_z)
		if f > 0.0:
			c = c.lerp(_grass_of(ctx, str(blend.get("center", "")), cache), f)
	return c


## Share of the centre ground in the outskirts ground at z – RoadRenderer.ground_blend (GROUND_BLEND_M = 150),
## repeated here so that a worker thread does not need the Arcade renderer's script.
static func ground_blend(z: float, center_z: float) -> float:
	if center_z <= 0.0 or z >= center_z:
		return 0.0
	return smoothstep(center_z - GROUND_BLEND_M, center_z, z)


func _grass_of(ctx: ChunkContext, scen_id: String, cache: Dictionary) -> Color:
	if cache.has(scen_id):
		return cache[scen_id]
	var scen: Dictionary = ctx.scenery_db.get(scen_id, {})
	var gcols: Array = scen.get("grass", GRASS_DEFAULT)
	var g0 := Color(str(gcols[0])) if gcols.size() > 0 else Color(GRASS_DEFAULT[0])
	var g1 := Color(str(gcols[mini(1, gcols.size() - 1)])) if gcols.size() > 0 else Color(GRASS_DEFAULT[1])
	var c := g0.lerp(g1, 0.5)
	cache[scen_id] = c
	return c


## Main thread: the mesh of the chunk under its node.
func commit(_ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	if int(part.get("vertices", 0)) <= 0:
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part["arrays"], [], {}, MESH_FORMAT)
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = mesh
	mi.material_override = _material()
	mi.layers = GROUND_LAYERS
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func debug(part: Dictionary) -> Dictionary:
	return {"vertices": int(part.get("vertices", 0)), "triangles": int(part.get("triangles", 0)), "segments": int(part.get("segments", 0)),
		"flags": int(part.get("flags", 0)), "lines_max": int(part.get("lines_max", 0)), "city_segments": int(part.get("city_segments", 0))}


## The shared material (created on first use, on the main thread).
func _material() -> ShaderMaterial:
	if material != null:
		return material
	material = ShaderMaterial.new()
	material.shader = ModernMaterials.shared().shader("road")
	_set_colour("col_road_a", Palette.ROAD)
	_set_colour("col_road_l", Palette.ROAD_LANDSTRASSE)
	_set_colour("col_road_c", Palette.ROAD_CITY)
	_set_colour("col_paved", Palette.SHOULDER_PAVED)
	_set_colour("col_gravel", Palette.SHOULDER)
	_set_colour("col_sidewalk", Palette.SIDEWALK.lerp(Palette.SIDEWALK_ALT, 0.5))
	_set_colour("col_curb", Palette.CURB)
	_set_colour("col_line", Palette.LINE)
	_set_colour("col_snow", Palette.SNOW_GROUND)
	_set_colour("col_road_snow", Color("9fa4ab"))
	_set_colour("col_line_snow", Color("c9cdd3"))
	material.set_shader_parameter("lane_w", 3.75)
	material.set_shader_parameter("edge_line_w", _edge_line)
	material.set_shader_parameter("lane_line_w", _lane_line)
	var seg_len := 3.0
	var cfg: Variant = _renderer.get("cfg") if _renderer != null else null
	var lane_w := 3.75
	var shoulder_w := 2.5
	if cfg is Dictionary:
		seg_len = float(ConfigLoader.lookup(cfg, "render.segment_length_m", seg_len))
		lane_w = float(ConfigLoader.lookup(cfg, "road.lane_width_m", lane_w))
		shoulder_w = float(ConfigLoader.lookup(cfg, "road.shoulder_width_m", shoulder_w))
	var on := Vector3.ZERO
	var cyc := Vector3.ZERO
	var k := 0
	for road: String in ["autobahn", "landstrasse", "city"]:
		var d: Vector2i = _dash[road]
		on[k] = float(d.x) * seg_len
		cyc[k] = float(d.x + d.y) * seg_len
		k += 1
	material.set_shader_parameter("lane_w", lane_w)
	material.set_shader_parameter("shoulder_w", shoulder_w)
	material.set_shader_parameter("dash_on", on)
	material.set_shader_parameter("dash_cycle", cyc)
	material.set_shader_parameter("seg_len", seg_len)
	material.set_shader_parameter("post_every", float(_post_every) * seg_len)
	material.set_shader_parameter("detail", detail)
	return material


func _set_colour(param: String, c: Color) -> void:
	material.set_shader_parameter(param, Vector3(c.r, c.g, c.b))
