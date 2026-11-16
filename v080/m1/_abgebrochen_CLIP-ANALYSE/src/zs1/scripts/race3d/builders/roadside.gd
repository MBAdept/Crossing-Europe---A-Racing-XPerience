extends ChunkBuilder
## Roadside builder of the mode "Modern" (v0.8.0, contract §6 R1): guardrails with their posts and reflectors and the
## delineator posts of a chunk as ONE mesh surface in the material class "vpbr" (ModernMaterials – the vertex format
## of everything untextured: COLOR = albedo, UV = roughness / metallic, UV2 = no lamp).
##
## Where things stand is Arcade's rule (RoadRenderer._draw_structures), so both modes show the same road furniture:
##  * guardrail: on the left outer edge of every segment with `guardrail` outside tunnels; on the right outer edge
##    as well unless a fuel lane or a border station is beside it. The beam hangs from 0.48 m to 0.80 m, its face
##    on the edge line of the shoulder (ChunkContext.shoulder_edge) – here a real W-profile of folded sheet metal,
##    with a sheet on the back so that it throws a shadow whatever the sun does. Where a rail begins or ends
##    inside the chunk the beam dives into the ground over one segment.
##  * posts every second segment (6 m) behind the beam; on the first post after every multiple of
##    road.delineator_every_m (50 m) a reflector in the valley of the beam – amber on the right, white on the left.
##  * delineator posts where there is no guardrail, outside the City Limits and tunnels, every 50 m, 0.3 m inside
##    the outer edge: white, 1.05 m high, a black band with the reflector.
##  * FIX1 (QA QB-03: the Köhlbrand bridge read as a dam): on bridge segments (water, outside tunnels) Arcade's railing
##    at the outer deck edge (RoadRenderer._bridge_structures: the shoulder edge + Track.BRIDGE_DECK_EXTRA_M outside
##    the City Limits) in the bridge's colour – a steel railing with a concrete kerb, posts every second segment; a
##    stone parapet for "stone_arch", a low wall for "causeway", an iron railing for "canal". Until the bridge
##    builder of M2 (R5) builds decks, girders and pylons.
## Nothing here depends on a quality level except the shadow (levels.shadow_casters >= 1: "structures") – what
## marks the edge of the road is never thinned out or shortened (Rule 9).
## Reflectors are small lit surfaces; what they throw back of the player's low beam at night is drawn by the lights
## layer: commit() hands it the list through layer("lights").add_reflectors(node, list) when that layer exists.
## Builder rules: build() runs on worker threads – snapshot arrays of ctx only; every position from ctx.local() /
## ctx.frame(). Without a renderer (tests) the mesh is built all the same.
## Owner: renderer core (R1). Docs: docs/renderer-modern.md.

## W-profile of the beam, top to bottom: (height above the road, depth towards the road in metres).
const BEAM: Array[Vector2] = [Vector2(0.80, 0.0), Vector2(0.775, 0.045), Vector2(0.735, 0.082), Vector2(0.69, 0.082),
	Vector2(0.64, 0.02), Vector2(0.59, 0.082), Vector2(0.545, 0.082), Vector2(0.505, 0.045), Vector2(0.48, 0.0)]
const BEAM_BACK_M := -0.006        ## the sheet on the back of the beam
const END_DIVE_M := 0.42           ## a beam that begins or ends dives this far
const POST_H := 0.74
const POST_ALONG := 0.05           ## half extent of a post along the road …
const POST_ACROSS := 0.03          ## … and across it
const POST_BACK_M := -0.036        ## its axis behind the face of the beam
const REFLECTOR_H := 0.64          ## centre of a rail reflector (the valley of the beam)
const REFLECTOR_HALF := Vector2(0.045, 0.032)
const DELIN_H := 1.05
const DELIN_HALF_W := 0.06
const DELIN_HALF_D := 0.045
const DELIN_INSET_M := 0.3         ## delineators stand this far inside the outer edge of the shoulder
const DELIN_BAND := Vector2(0.71, 0.93)
const DELIN_REFLECTOR := Vector2(0.77, 0.89)
const STEEL := Color("b8bdc3")     ## Palette.GUARDRAIL
const POST := Color("6f747a")
const WHITE := Color("f2f2ee")
const BLACK := Color("1a1a1a")
const REFLECT_WHITE := Color(1.0, 1.0, 1.0)
const REFLECT_AMBER_RAIL := Color(1.0, 0.75, 0.3)
const REFLECT_AMBER := Color(1.0, 0.65, 0.2)
const ROUGH_STEEL := Vector2(0.48, 0.25)      ## roughness, metallic
const ROUGH_POST := Vector2(0.6, 0.2)
const ROUGH_PLASTIC := Vector2(0.55, 0.0)
const ROUGH_REFLECTOR := Vector2(0.2, 0.0)
const ROUGH_RAILING := Vector2(0.5, 0.3)
const ROUGH_STONE := Vector2(0.9, 0.0)
const CONCRETE := Color("b9b5aa")             ## RoadRenderer.CONCRETE
const BRIDGE_EXTRA_M := 0.4                   ## Track.BRIDGE_DECK_EXTRA_M

var _post_every := 2               ## segments between guardrail posts (Arcade)
var _delin_every := 50.0
var _snow := false                 ## the stage's weather is snow: a little of it lies on the rails
var _configured := false
var _renderer: Object


## Vertex arrays of one chunk while it is built.
class Buf extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	## A flat quad a-b-c-d (in order around it) that faces `toward`.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color, rm: Vector2) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length_squared() < 1.0e-12:
			nn = (c - a).cross(d - a)
		nn = nn.normalized()
		if nn.dot(toward) < 0.0:
			nn = -nn
		var o := v.size()
		v.append(a)
		v.append(b)
		v.append(c)
		v.append(d)
		for q in 4:
			n.append(nn)
			col.append(colour)
			uv.append(rm)
			uv2.append(Vector2(-1.0, 0.0))
		# front faces are clockwise
		if (c - a).cross(b - a).dot(nn) >= 0.0:
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
	return "roadside"


func setup(renderer: Node) -> void:
	_renderer = renderer
	if renderer == null:
		return
	var cfg: Variant = renderer.get("cfg")
	if cfg is Dictionary:
		configure(cfg)
	var prep: Variant = renderer.get("prep")
	_snow = prep is Dictionary and str((prep as Dictionary).get("weather", "")) == "snow"


func configure(cfg: Dictionary) -> void:
	_configured = true
	_delin_every = maxf(6.0, float(ConfigLoader.lookup(cfg, "road.delineator_every_m", 50.0)))


func collect(ctx: ChunkContext) -> Variant:
	if not _configured:
		configure(ctx.cfg)
	# the colour of every bridge in the chunk (Track.bridges is main-thread data; Arcade: RoadRenderer._bridge_color)
	var colours := {}
	if ctx.track != null:
		for seg: Dictionary in ctx.segs:
			if not bool(seg["water"]):
				continue
			var bi := int(seg["bridge_i"])
			if colours.has(bi):
				continue
			var c := ""
			if bi >= 0 and bi < ctx.track.bridges.size():
				c = str(ctx.track.bridges[bi].get("color", ""))
			colours[bi] = Color(c) if c != "" else RoadRenderer.RAIL.get(str(seg["bridge"]), RoadRenderer.RAIL["river"])
	return {"bridge_colours": colours}


## True when a guardrail stands on `side` (-1 left, +1 right) of the segment between the rows of sa and sb.
static func has_rail(sa: Dictionary, sb: Dictionary, side: int) -> bool:
	if not bool(sa["guardrail"]) or bool(sa["tunnel"]):
		return false
	if side < 0:
		return true
	return float(sa["fuel_lane"]) < 0.01 and float(sb["fuel_lane"]) < 0.01 and str(sa["cover"]) == ""


## WORKER THREAD.
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var buf := Buf.new()
	var bridge_colours: Dictionary = (input as Dictionary).get("bridge_colours", {}) if input is Dictionary else {}
	var railing_segments := 0
	var rows := ctx.row_count()
	var seg_len := ctx.seg_len
	var steel := STEEL.lerp(Color.WHITE, 0.3) if _snow else STEEL
	var reflectors: Array = []
	var rail_segments := [0, 0]
	var posts := 0
	var delineators := 0
	for i in rows - 1:
		var sa: Dictionary = ctx.segs[i]
		var sb: Dictionary = ctx.segs[i + 1]
		var z0 := float(ctx.seg_a + i) * seg_len
		var z1 := z0 + seg_len
		var seg_index := int(sa["index"])
		if bool(sa["water"]) and not bool(sa["tunnel"]):
			railing_segments += 1
			var rc: Color = bridge_colours.get(int(sa["bridge_i"]), RoadRenderer.RAIL["river"])
			for side: int in [-1, 1]:
				_railing(buf, ctx, i, z0, z1, side, str(sa["bridge"]), rc, bool(sa["city"]), seg_index)
		for side: int in [-1, 1]:
			if not has_rail(sa, sb, side):
				continue
			rail_segments[0 if side < 0 else 1] += 1
			var s := float(side)
			var xa := s * ctx.shoulder_edge(i, side)
			var xb := s * ctx.shoulder_edge(i + 1, side)
			var inward_a := ctx.rows_r[i] * -s
			var inward_b := ctx.rows_r[i + 1] * -s
			# a beam that begins or ends here dives into the ground (the neighbours inside the chunk are known)
			var dive_a := END_DIVE_M if i > 0 and not has_rail(ctx.segs[i - 1], sa, side) else 0.0
			var dive_b := END_DIVE_M if i + 2 < rows and not has_rail(sb, ctx.segs[i + 2], side) else 0.0
			var pa: Array[Vector3] = []
			var pb: Array[Vector3] = []
			for k in BEAM.size():
				var prof := BEAM[k]
				pa.append(ctx.local(z0, xa - s * prof.y, prof.x - dive_a))
				pb.append(ctx.local(z1, xb - s * prof.y, prof.x - dive_b))
			for k in BEAM.size() - 1:
				buf.quad(pa[k], pb[k], pb[k + 1], pa[k + 1], inward_a + inward_b, steel, ROUGH_STEEL)
			var last := BEAM.size() - 1
			buf.quad(ctx.local(z0, xa - s * BEAM_BACK_M, BEAM[0].x - dive_a), ctx.local(z1, xb - s * BEAM_BACK_M, BEAM[0].x - dive_b),
				ctx.local(z1, xb - s * BEAM_BACK_M, BEAM[last].x - dive_b), ctx.local(z0, xa - s * BEAM_BACK_M, BEAM[last].x - dive_a),
				-(inward_a + inward_b), steel.darkened(0.12), ROUGH_STEEL)
			if seg_index % _post_every != 0:
				continue
			# post behind the beam, at the near row of the segment
			posts += 1
			var fwd := ctx.rows_f[i]
			var top := POST_H - dive_a
			var c0 := ctx.local(z0, xa - s * POST_BACK_M, 0.0)
			var along := fwd * POST_ALONG
			var across := inward_a * POST_ACROSS
			var up := Vector3(0.0, maxf(top, 0.1), 0.0)
			buf.quad(c0 - along + across, c0 + along + across, c0 + along + across + up, c0 - along + across + up, inward_a, POST, ROUGH_POST)
			buf.quad(c0 - along - across, c0 + along - across, c0 + along - across + up, c0 - along - across + up, -inward_a, POST.darkened(0.1), ROUGH_POST)
			buf.quad(c0 - along - across, c0 - along + across, c0 - along + across + up, c0 - along - across + up, -fwd, POST, ROUGH_POST)
			buf.quad(c0 + along - across, c0 + along + across, c0 + along + across + up, c0 + along - across + up, fwd, POST, ROUGH_POST)
			if fposmod(z0, _delin_every) < seg_len * float(_post_every) and dive_a <= 0.0:
				# reflector in the valley of the beam, facing the traffic that comes up the road
				var colour := REFLECT_AMBER_RAIL if side > 0 else REFLECT_WHITE
				var rc := ctx.local(z0, xa - s * 0.05, REFLECTOR_H) - fwd * 0.004
				var rx := inward_a * REFLECTOR_HALF.x
				var ry := Vector3(0.0, REFLECTOR_HALF.y, 0.0)
				buf.quad(rc - rx - ry, rc + rx - ry, rc + rx + ry, rc - rx + ry, -fwd, colour, ROUGH_REFLECTOR)
				buf.quad(rc - rx - ry + fwd * 0.008, rc + rx - ry + fwd * 0.008, rc + rx + ry + fwd * 0.008, rc - rx + ry + fwd * 0.008, fwd,
					POST, ROUGH_POST)
				reflectors.append({"pos": rc, "dir": -fwd, "color": colour, "size": REFLECTOR_HALF.x * 2.0})
	# delineator posts every delin_every metres of road
	var z_from := float(ctx.seg_a) * seg_len
	var z_to := float(ctx.seg_a + rows - 1) * seg_len
	var z := ceilf(z_from / _delin_every) * _delin_every
	while z < z_to:
		var k := clampi(int(floor(z / seg_len)) - ctx.seg_a, 0, rows - 2)
		var seg: Dictionary = ctx.segs[k]
		if not bool(seg["city"]) and not bool(seg["tunnel"]) and not bool(seg["guardrail"]):
			var f := clampf(z / seg_len - float(ctx.seg_a + k), 0.0, 1.0)
			var e := ctx.rows_edge[k].lerp(ctx.rows_edge[k + 1], f)
			_delineator(buf, ctx, z, e.x - ctx.shoulder_w + DELIN_INSET_M, false, reflectors)
			delineators += 1
			if float(seg["fuel_lane"]) < 0.01 and str(seg["cover"]) == "":
				_delineator(buf, ctx, z, e.y + ctx.shoulder_w - DELIN_INSET_M, true, reflectors)
				delineators += 1
		z += _delin_every
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = buf.v
	arrays[Mesh.ARRAY_NORMAL] = buf.n
	arrays[Mesh.ARRAY_COLOR] = buf.col
	arrays[Mesh.ARRAY_TEX_UV] = buf.uv
	arrays[Mesh.ARRAY_TEX_UV2] = buf.uv2
	arrays[Mesh.ARRAY_INDEX] = buf.idx
	return {"arrays": arrays, "vertices": buf.v.size(), "triangles": buf.idx.size() / 3, "rail_left": rail_segments[0],
		"rail_right": rail_segments[1], "posts": posts, "delineators": delineators, "reflectors": reflectors,
		"railing_segments": railing_segments}


## Arcade's bridge railing on one side of the segment between rows i and i + 1 (RoadRenderer._bridge_structures):
## bands facing the road and their backs, posts every second segment. Heights as in Arcade.
func _railing(buf: Buf, ctx: ChunkContext, i: int, z0: float, z1: float, side: int, kind: String, col: Color, city: bool,
		seg_index: int) -> void:
	var s := float(side)
	var extra := 0.0 if city else BRIDGE_EXTRA_M
	var xa := s * (ctx.shoulder_edge(i, side) + extra)
	var xb := s * (ctx.shoulder_edge(i + 1, side) + extra)
	var inward_a := ctx.rows_r[i] * -s
	var inward_b := ctx.rows_r[i + 1] * -s
	var inward := inward_a + inward_b
	var bands: Array = []            # [h0, h1, colour, thickness (m), roughness/metallic]
	match kind:
		"stone_arch":
			bands = [[0.0, 0.24, col.darkened(0.22), 0.3, ROUGH_STONE], [0.24, 0.92, col.darkened(0.08), 0.18, ROUGH_STONE],
				[0.92, 1.14, col.lightened(0.08), 0.32, ROUGH_STONE]]
		"causeway":
			bands = [[0.0, 0.82, col, 0.3, ROUGH_STONE], [0.82, 0.92, col.lightened(0.12), 0.34, ROUGH_STONE]]
		"canal":
			bands = [[0.0, 0.1, col.darkened(0.2), 0.06, ROUGH_RAILING], [0.43, 0.48, col, 0.05, ROUGH_RAILING],
				[0.95, 1.02, col, 0.06, ROUGH_RAILING]]
		_:
			bands = [[0.0, 0.28, CONCRETE, 0.3, ROUGH_STONE], [0.5, 0.56, col.darkened(0.15), 0.06, ROUGH_RAILING],
				[0.98, 1.1, col, 0.08, ROUGH_RAILING]]
	for b: Array in bands:
		var h0 := float(b[0])
		var h1 := float(b[1])
		var c: Color = b[2]
		var t := float(b[3])
		var rm: Vector2 = b[4]
		# face towards the road, the back, the top
		buf.quad(ctx.local(z0, xa, h0), ctx.local(z1, xb, h0), ctx.local(z1, xb, h1), ctx.local(z0, xa, h1), inward, c, rm)
		buf.quad(ctx.local(z0, xa + s * t, h0), ctx.local(z1, xb + s * t, h0), ctx.local(z1, xb + s * t, h1), ctx.local(z0, xa + s * t, h1),
			-inward, c.darkened(0.1), rm)
		buf.quad(ctx.local(z0, xa, h1), ctx.local(z1, xb, h1), ctx.local(z1, xb + s * t, h1), ctx.local(z0, xa + s * t, h1), Vector3.UP,
			c.lightened(0.05), rm)
	if kind == "causeway":
		return
	# posts (balusters of a parapet, bars of an iron railing): every second segment, at the near row
	if seg_index % 2 != 0:
		return
	var top := 1.1 if kind != "stone_arch" else 1.14
	var w := 0.1 if kind != "stone_arch" else 0.2
	var fwd := ctx.rows_f[i]
	var c0 := ctx.local(z0, xa + s * 0.05, 0.0)
	var along := fwd * (w * 0.5)
	var across := inward_a * (w * 0.5)
	var up := Vector3(0.0, top, 0.0)
	var pc := col.darkened(0.2)
	buf.quad(c0 - along + across, c0 + along + across, c0 + along + across + up, c0 - along + across + up, inward_a, pc, ROUGH_RAILING)
	buf.quad(c0 - along - across, c0 + along - across, c0 + along - across + up, c0 - along - across + up, -inward_a, pc, ROUGH_RAILING)
	buf.quad(c0 - along - across, c0 - along + across, c0 - along + across + up, c0 - along - across + up, -fwd, pc, ROUGH_RAILING)
	buf.quad(c0 + along - across, c0 + along + across, c0 + along + across + up, c0 + along - across + up, fwd, pc, ROUGH_RAILING)


## One delineator post at road position (z, x): white, a black band near the top, the reflector on the face that
## looks at the traffic coming up the road.
func _delineator(buf: Buf, ctx: ChunkContext, z: float, x: float, right: bool, reflectors: Array) -> void:
	var tr := ctx.frame(z, x, 0.0)
	var o := tr.origin
	var bx := tr.basis.x * DELIN_HALF_W
	var bz := tr.basis.z * DELIN_HALF_D          # +Z of the frame looks back down the road, at the player
	var levels: Array[float] = [0.0, DELIN_BAND.x, DELIN_BAND.y, DELIN_H]
	var colours: Array[Color] = [WHITE, BLACK, WHITE]
	for q in 3:
		var y0 := Vector3(0.0, levels[q], 0.0)
		var y1 := Vector3(0.0, levels[q + 1], 0.0)
		var c := colours[q]
		buf.quad(o - bx + bz + y0, o + bx + bz + y0, o + bx + bz + y1, o - bx + bz + y1, tr.basis.z, c, ROUGH_PLASTIC)
		buf.quad(o - bx - bz + y0, o + bx - bz + y0, o + bx - bz + y1, o - bx - bz + y1, -tr.basis.z, c, ROUGH_PLASTIC)
		buf.quad(o - bx - bz + y0, o - bx + bz + y0, o - bx + bz + y1, o - bx - bz + y1, -tr.basis.x, c, ROUGH_PLASTIC)
		buf.quad(o + bx - bz + y0, o + bx + bz + y0, o + bx + bz + y1, o + bx - bz + y1, tr.basis.x, c, ROUGH_PLASTIC)
	var top := Vector3(0.0, DELIN_H, 0.0)
	buf.quad(o - bx - bz + top, o + bx - bz + top, o + bx + bz + top, o - bx + bz + top, Vector3.UP, WHITE, ROUGH_PLASTIC)
	var colour := REFLECT_AMBER if right else REFLECT_WHITE
	var rx := tr.basis.x * (DELIN_HALF_W * 0.6)
	var front := o + bz + tr.basis.z * 0.003
	var r0 := Vector3(0.0, DELIN_REFLECTOR.x, 0.0)
	var r1 := Vector3(0.0, DELIN_REFLECTOR.y, 0.0)
	buf.quad(front - rx + r0, front + rx + r0, front + rx + r1, front - rx + r1, tr.basis.z, colour, ROUGH_REFLECTOR)
	reflectors.append({"pos": front + (r0 + r1) * 0.5, "dir": tr.basis.z, "color": colour, "size": DELIN_HALF_W * 1.2})


## Main thread: the mesh under the chunk node; the reflectors go to the lights layer.
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	if int(part.get("vertices", 0)) <= 0:
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part["arrays"])
	var mi := MeshInstance3D.new()
	mi.name = "Roadside"
	mi.mesh = mesh
	var materials: Variant = ctx.services.get("materials")
	if not (materials is ModernMaterials):
		materials = ModernMaterials.shared()
	mi.material_override = (materials as ModernMaterials).material("vpbr")
	var casts := int(ctx.levels.get("shadow_casters", 0)) >= 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var renderer: Variant = ctx.services.get("renderer")
	var list: Array = part.get("reflectors", [])
	if renderer != null and not list.is_empty():
		var lights: Variant = (renderer as Object).call(&"layer", "lights")
		if lights != null and (lights as Object).has_method(&"add_reflectors"):
			(lights as Object).call(&"add_reflectors", mi, list)


func debug(part: Dictionary) -> Dictionary:
	return {"vertices": int(part.get("vertices", 0)), "triangles": int(part.get("triangles", 0)), "rail_left": int(part.get("rail_left", 0)),
		"rail_right": int(part.get("rail_right", 0)), "posts": int(part.get("posts", 0)), "delineators": int(part.get("delineators", 0)),
		"reflectors": (part.get("reflectors", []) as Array).size(), "railing_segments": int(part.get("railing_segments", 0))}
