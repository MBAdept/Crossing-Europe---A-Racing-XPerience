extends ChunkBuilder
## Tunnel builder of the mode "Modern" (v0.8.0, package R5 – contract §6 wave 3 "Tunnel und Brücken", renderer
## inventory B; German docs: docs/renderer-modern-tunnel-bruecken.md). FIX1 laid a minimal tube in Arcade's shapes and
## colours (RoadRenderer._tunnel_segment / _draw_portal / _tunnel_cap, frozen); R5 builds the tunnel on it:
##  * the TUBE of every tunnel segment from the outer shoulder edge on both sides (where Arcade's walls stand): raised
##    emergency WALKWAYS with a kerb, the tile band up to 2.9 m in panels with joints and road grime, the wall up to
##    render.tunnel.wall_height_m, the haunches inwards by haunch_m up to ceiling_m, the ceiling with its ring joints;
##    cable trays under the haunches; LAMP rows on both haunches every light_every_m as luminaires (housing and lens;
##    the flare layer adds Arcade's halo, role "tunnel"), the walls brighter beside every lamp;
##  * SOS NICHES every 150 m in the right wall (where Arcade paints its green sign): a lit recess with an orange SOS
##    plate above it and the green emergency sign beside it; emergency EXIT DOORS every 300 m in the left wall under a
##    lit green sign; pairs of JET FANS under the ceiling every 300 m (their underside at least 5.2 m above the road –
##    they cannot hide anything a 3.4 m eye sees under the 6.2 m ceiling);
##  * for a camera OUTSIDE the tunnel only the first peek_m (45 m) are drawn and a dark CAP closes the tube there (the
##    tube deeper inside could curve out of the hill) – the shader decides by the portal z of each vertex;
##  * at every PORTAL (the first segment of a tunnel): the opening in a protruding concrete FRAME with a dark reveal, a
##    headwall with a cornice, wing walls standing on the ground, and above it Arcade's overgrown HILL (85 m + half the
##    road wide to each side, 30 m (± a seeded variation) high, its ridge up to 38 m behind the portal, from the
##    scenery's darkened grass colour at its foot to the lighter tone on the ridge, Arcade's conifers along the ridge –
##    RoadRenderer._draw_portal's seeded sequence) as a lit mesh (vpbr, static, smooth normals) that closes the terrain
##    at the portal; the frame of the EXIT seen from inside (the last segment);
##  * the ZONE for the environment: tunnel_state (amount, exit_m, portal_m, …) every frame and – when the environment
##    rig offers it (R4, duck-typed) – EnvironmentRig.set_zone("tunnel", amount) with the same law as the rig's own
##    tunnel_blend() (0 from 12 m before a portal to 1 at 14 m inside, a function of the camera's position); without
##    set_zone the rig keeps its own tunnel path (tunnel01).
## Material of the tube: assets/shaders/modern/tunnel.gdshader – Arcade's tunnel light and tunnel fog whatever the
## environment does, so the tube looks the same from outside and inside.
## Fairness: walls and portal stand where Arcade's stand (the shoulder edge); everything added sits in the walls, on the
## walkways or under the ceiling – nothing in a lane, nothing a car or sign could hide behind.
## Builder rules: build() runs on worker threads – ctx snapshot arrays and the plain input of collect() only; every
## position from ctx.local(). Without a renderer (tests) the meshes are built all the same.
## Owner: package R5 (tunnels, bridges, water and banks); FIX1 built the first tube.

const SHADER_CLASS := "tunnel"     ## assets/shaders/modern/tunnel.gdshader through ModernMaterials
const TILE := Color("d9d3c2")      ## RoadRenderer.TILE
const WALL := Color("75716a")      ## RoadRenderer.WALL
const HAUNCH := Color("57544e")    ## RoadRenderer.HAUNCH
const CEILING := Color("3e3b35")   ## RoadRenderer.CEILING
const CONCRETE := Color("b9b5aa")  ## RoadRenderer.CONCRETE
const LAMP_COL := Color(1.0, 0.82, 0.55)   ## RoadRenderer.LAMP_COL
const WALKWAY := Color("8f8b82")   ## RoadRenderer._draw_ground: the walkway of a tunnel …
const KERB := Color("b4afa4")      ## … and its kerb face
const METAL := Color("6f7275")
const NICHE_LIGHT := Color(1.0, 0.93, 0.78)
const SOS_ORANGE := Color("f07a14")
const SIGN_GREEN := Color("1f9d4a")
const DOOR_GREEN := Color("2f7d4f")
const TILE_TOP := 2.9              ## top of the tile band (m)
const FOOT := -0.4                 ## the walls reach this far below the road (no gap at the road's edge)
const WALK_W := 0.9                ## emergency walkway on both sides (Arcade's: the outer 0.9 m of the shoulder) …
const WALK_H := 0.25               ## … raised by this much (Arcade's)
const NICHE_EVERY := 150.0
const NICHE_W := 2.2               ## SOS niche: width along the road, height, depth into the wall
const NICHE_H := 2.4
const NICHE_D := 0.9
const DOOR_EVERY := 300.0          ## emergency exits in the left wall, offset by DOOR_PHASE
const DOOR_PHASE := 75.0
const DOOR_W := 1.2
const DOOR_H := 2.25
const FAN_EVERY := 300.0           ## pairs of jet fans under the ceiling, offset by FAN_PHASE
const FAN_PHASE := 225.0
const FAN_R := 0.42
const FAN_L := 4.0
const FAN_SPREAD := 1.35           ## centre of each fan beside the tube's middle
const FAN_MIN_BOTTOM := 5.2        ## the underside of a fan at least this high above the road
const TRAY := Vector2(0.3, 0.18)   ## cable tray under the haunch: depth into the tube, height
const LAMP_LEN := 0.7              ## lamp lens along the road …
const LAMP_W := 0.22               ## … and across the haunch (Arcade's lamp rectangle)
const FRAME_W := 0.7               ## the portal frame around the opening …
const FRAME_OUT := 0.3             ## … stands this far out of the headwall
const PORTAL_SIDE := 1.4           ## headwall beside the frame
const EXIT_FRAME_W := 0.45         ## frame of the exit seen from inside
const WING_M := 9.0                ## wing walls beside the opening
const HEAD_EXTRA := 2.4            ## headwall above the ceiling (Arcade: head_h = ceiling + 2.4)
const HILL_SPAN := 85.0            ## half width of the hill beyond the middle of the road …
const HILL_PEAK := 30.0            ## … its height …
const HILL_BACK := 38.0            ## … and how far behind the portal its ridge lies at the middle
const HILL_FALL := 70.0            ## behind the ridge it falls this far (at the middle) …
const HILL_SINK := 8.0             ## … to this depth below the road
const HILL_COLS := 30               ## Arcade's columns across the hill (and the two road edges)
const ROUGH_CONCRETE := Vector2(0.9, 0.0)
const ROUGH_GRASS := Vector2(0.97, 0.0)
## Kinds of tunnel.gdshader (UV2.x)
const K_PLAIN := 0.0
const K_CAP := 1.0
const K_LAMP := 2.0
const K_SIGN := 3.0
const K_TILE := 4.0
const K_WALL := 5.0
const K_CEIL := 6.0
const K_WALK := 7.0
const K_NICHE := 8.0
const K_SOS := 9.0
const K_METAL := 10.0
const K_DOOR := 11.0
const ZONE_OUT_M := 12.0           ## the zone amount rises from 12 m before a portal …
const ZONE_IN_M := 14.0            ## … to 1 at 14 m inside (EnvironmentRig.tunnel_blend, the rig's own law)

var tunnel_state: Dictionary = {}  ## {"amount", "inside", "portal_z", "exit_m", "portal_m", "exit_in_sight"}: read by tests and the rig

var _renderer: Object
var _material: ShaderMaterial
var _wall_h := 4.2
var _ceil_h := 6.2
var _haunch := 1.8
var _lamp_every := 12.0
var _dark_m := 260.0
var _peek_m := 45.0
var _snow := false
var _configured := false
var _has_tunnels := false
var _state_key := ""
var _zone_sent := -1.0
var _zone_calls := 0


## Vertex arrays of one chunk while it is built (the tube: tunnel.gdshader; the portal: vpbr).
class Buf extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c0 := PackedFloat32Array()     ## CUSTOM0 (tube): sign-local u, v
	var idx := PackedInt32Array()
	var custom := false

	## A flat quad a-b-c-d (in order around it) that faces `toward`; uv / uv2 for all four corners.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color, uv_v: Vector2, uv2_v: Vector2) -> void:
		quad_full(a, b, c, d, toward, colour, [uv_v, uv_v, uv_v, uv_v], [uv2_v, uv2_v, uv2_v, uv2_v], [])

	## Like quad(), but uv per corner (the depth into the tunnel changes along the road).
	func quad_uv(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color, uvs: Array[Vector2], uv2_v: Vector2) -> void:
		quad_full(a, b, c, d, toward, colour, uvs, [uv2_v, uv2_v, uv2_v, uv2_v], [])

	## The general quad: per-corner uv, uv2 and sign-local coordinates (CUSTOM0.xy, [] = none).
	func quad_full(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color, uvs: Array, uv2s: Array, locs: Array) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length_squared() < 1.0e-12:
			nn = (c - a).cross(d - a)
		if nn.length_squared() < 1.0e-12:
			return
		nn = nn.normalized()
		if nn.dot(toward) < 0.0:
			nn = -nn
		var o := v.size()
		var pts: Array[Vector3] = [a, b, c, d]
		for q in 4:
			v.append(pts[q])
			n.append(nn)
			col.append(colour)
			uv.append(uvs[q])
			uv2.append(uv2s[q])
			if custom:
				var l: Vector2 = locs[q] if locs.size() == 4 else Vector2.ZERO
				c0.append_array(PackedFloat32Array([l.x, l.y, 0.0, 0.0]))
		# front faces are clockwise
		if (c - a).cross(b - a).dot(nn) >= 0.0:
			idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
		else:
			idx.append_array(PackedInt32Array([o, o + 2, o + 1, o, o + 3, o + 2]))

	## A quad with a normal and a colour per corner (smooth surfaces); the winding from the face normal (toward).
	func quad_vc(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, nrm: Array, cols: Array, uv_v: Vector2, uv2_v: Vector2) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length_squared() < 1.0e-12:
			nn = (c - a).cross(d - a)
		if nn.length_squared() < 1.0e-12:
			return
		nn = nn.normalized()
		if nn.dot(toward) < 0.0:
			nn = -nn
		var o := v.size()
		var pts: Array[Vector3] = [a, b, c, d]
		for q in 4:
			v.append(pts[q])
			var vn: Vector3 = nrm[q]
			n.append(vn.normalized() if vn.length_squared() > 1.0e-10 else nn)
			col.append(cols[q])
			uv.append(uv_v)
			uv2.append(uv2_v)
			if custom:
				c0.append_array(PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
		if (c - a).cross(b - a).dot(nn) >= 0.0:
			idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
		else:
			idx.append_array(PackedInt32Array([o, o + 2, o + 1, o, o + 3, o + 2]))

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		if custom:
			arr[Mesh.ARRAY_CUSTOM0] = c0
		arr[Mesh.ARRAY_INDEX] = idx
		return arr


func id() -> String:
	return "tunnel"


func setup(renderer: Node) -> void:
	_renderer = renderer
	if renderer == null:
		return
	var cfg: Variant = renderer.get("cfg")
	if cfg is Dictionary:
		configure(cfg)
	var prep: Variant = renderer.get("prep")
	_snow = prep is Dictionary and str((prep as Dictionary).get("weather", "")) == "snow"
	var trk: Variant = renderer.get("track")
	_has_tunnels = trk is Track and (trk as Track).plan != null and not (trk as Track).plan.tunnels.is_empty()


func configure(cfg: Dictionary) -> void:
	_configured = true
	var tc: Variant = ConfigLoader.lookup(cfg, "render.tunnel", {})
	var t: Dictionary = tc if tc is Dictionary else {}
	_wall_h = float(t.get("wall_height_m", _wall_h))
	_ceil_h = float(t.get("ceiling_m", _ceil_h))
	_haunch = float(t.get("haunch_m", _haunch))
	_lamp_every = maxf(3.0, float(t.get("light_every_m", _lamp_every)))
	_dark_m = maxf(20.0, float(t.get("darkness_m", _dark_m)))
	_peek_m = maxf(6.0, float(t.get("peek_m", _peek_m)))


## Main thread: the tunnels that reach into this chunk as segment ranges [first, end) – the Track holds only a window
## of segments, the stage plan the whole list.
func collect(ctx: ChunkContext) -> Variant:
	if not _configured:
		configure(ctx.cfg)
	var out: Array = []
	var trk := ctx.track
	if trk == null or trk.plan == null:
		return {"tunnels": out}
	for t: Dictionary in trk.plan.tunnels:
		var first := ceili(trk.km_to_z(float(t["start_km"])) / ctx.seg_len - 1.0e-6)
		var end := ceili(trk.km_to_z(float(t["end_km"])) / ctx.seg_len - 1.0e-6)
		if end > ctx.seg_a and first < ctx.seg_b:
			out.append([first, end])
	return {"tunnels": out}


## Portal z (road position) and end segment of the tunnel that holds segment `seg`, or [] when none does.
static func tunnel_of(tunnels: Array, seg: int) -> Array:
	for t: Array in tunnels:
		if seg >= int(t[0]) and seg < int(t[1]):
			return t
	return []


## True when a feature that repeats every `every` metres from `phase` lies in the segment starting at z0.
static func in_segment(z0: float, seg_len: float, every: float, phase: float) -> bool:
	return fposmod(z0 - phase, every) < seg_len


## WORKER THREAD.
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var inp: Dictionary = input if input is Dictionary else {}
	var tunnels: Array = inp.get("tunnels", [])
	if tunnels.is_empty():
		return {}
	var tube := Buf.new()
	tube.custom = true
	var portal := Buf.new()
	var lamps: Array = []
	var rows := ctx.row_count()
	var seg_len := ctx.seg_len
	var counts := {"segments": 0, "portals": 0, "caps": 0, "niches": 0, "doors": 0, "fans": 0, "exits": 0}
	for i in rows - 1:
		var sa: Dictionary = ctx.segs[i]
		if not bool(sa["tunnel"]):
			continue
		var seg := ctx.seg_a + i
		var t := tunnel_of(tunnels, seg)
		if t.is_empty():
			continue
		counts["segments"] += 1
		var z_portal := float(int(t[0])) * seg_len
		var z_end := float(int(t[1])) * seg_len
		var z0 := float(seg) * seg_len
		var z1 := z0 + seg_len
		var g := {"xl0": -ctx.shoulder_edge(i, -1), "xl1": -ctx.shoulder_edge(i + 1, -1), "xr0": ctx.shoulder_edge(i, 1),
			"xr1": ctx.shoulder_edge(i + 1, 1), "z0": z0, "z1": z1, "zp": z_portal, "i": i}
		var tile := TILE if (int(sa["index"]) / 2) % 2 == 0 else TILE.darkened(0.06)
		var niche := in_segment(z0, seg_len, NICHE_EVERY, 0.0)
		var door := in_segment(z0, seg_len, DOOR_EVERY, DOOR_PHASE)
		# walls of both sides – the right one with an SOS niche every 150 m, the left one with an exit door every 300 m
		for side: int in [-1, 1]:
			var gap := Vector3.ZERO           # (half width of the opening, its height, its depth) – zero: no opening
			if side > 0 and niche:
				gap = Vector3(NICHE_W * 0.5, NICHE_H, NICHE_D)
			elif side < 0 and door:
				gap = Vector3(DOOR_W * 0.5, DOOR_H, 0.22)
			_wall(tube, ctx, g, side, tile, gap)
			_walkway(tube, ctx, g, side)
			_tray(tube, ctx, g, side)
		if niche:
			counts["niches"] += 1
			_niche(tube, ctx, g, lamps)
		if door:
			counts["doors"] += 1
			_door(tube, ctx, g)
		# haunches and ceiling (facing down into the tube)
		_vault(tube, ctx, g)
		_lamps(tube, ctx, g, lamps)
		if in_segment(z0, seg_len, FAN_EVERY, FAN_PHASE):
			counts["fans"] += 1
			_fans(tube, ctx, g)
		# the cap that closes the tube for a camera outside: at peek_m behind the portal (facing the portal)
		var z_cap := z_portal + _peek_m
		if z_cap >= z0 and z_cap < z1 and z_cap < z_end - seg_len:
			counts["caps"] += 1
			_cap(tube, ctx, g, z_cap)
		# the portal: the first segment of the tunnel
		if seg == int(t[0]):
			counts["portals"] += 1
			_portal(portal, ctx, i, z0, float(g["xl0"]), float(g["xr0"]), ctx.scenery_db.get(str(sa["scenery"]), {}), z_end - z_portal)
		# the frame of the exit seen from inside: the last segment of the tunnel
		if seg == int(t[1]) - 1:
			counts["exits"] += 1
			_exit_frame(tube, ctx, g, z1)
	var out := {"tube": tube.arrays() if not tube.idx.is_empty() else [], "portal": portal.arrays() if not portal.idx.is_empty() else [],
		"lamps": lamps, "tube_triangles": tube.idx.size() / 3, "portal_triangles": portal.idx.size() / 3}
	out.merge(counts)
	return out


## Lateral position of a wall at road position z inside the segment of g (linear between its rows).
static func wall_x(g: Dictionary, side: int, z: float) -> float:
	var f := clampf((z - float(g["z0"])) / maxf(float(g["z1"]) - float(g["z0"]), 0.001), 0.0, 1.0)
	return lerpf(float(g["xl0"]), float(g["xl1"]), f) if side < 0 else lerpf(float(g["xr0"]), float(g["xr1"]), f)


## uv of a tube vertex: (depth into the tunnel, road position of its portal).
static func tube_uv(g: Dictionary, z: float) -> Vector2:
	return Vector2(z - float(g["zp"]), float(g["zp"]))


## One wall quad of side `side` from road position za to zb, height h0 to h1 (kind, colour), x on the wall.
func _wall_piece(tube: Buf, ctx: ChunkContext, g: Dictionary, side: int, za: float, zb: float, h0: float, h1: float, colour: Color, kind: float) -> void:
	if zb - za < 0.005 or h1 - h0 < 0.005:
		return
	var xa := wall_x(g, side, za)
	var xb := wall_x(g, side, zb)
	var inward := ctx.rows_r[int(g["i"])] * float(-side)
	tube.quad_full(ctx.local(za, xa, h0), ctx.local(zb, xb, h0), ctx.local(zb, xb, h1), ctx.local(za, xa, h1), inward, colour,
		[tube_uv(g, za), tube_uv(g, zb), tube_uv(g, zb), tube_uv(g, za)],
		[Vector2(kind, h0), Vector2(kind, h0), Vector2(kind, h1), Vector2(kind, h1)], [])


## The wall of one side: tile band and the wall above it, with an opening (niche / door) of gap = (half width,
## height, depth) in the middle of the segment.
func _wall(tube: Buf, ctx: ChunkContext, g: Dictionary, side: int, tile: Color, gap: Vector3) -> void:
	var z0 := float(g["z0"])
	var z1 := float(g["z1"])
	var bands := [[FOOT, TILE_TOP, tile, K_TILE], [TILE_TOP, _wall_h, WALL, K_WALL]]
	if gap.x <= 0.0:
		for b: Array in bands:
			_wall_piece(tube, ctx, g, side, z0, z1, b[0], b[1], b[2], b[3])
		return
	var zm := (z0 + z1) * 0.5
	var g0 := zm - gap.x
	var g1 := zm + gap.x
	var top := WALK_H + gap.y
	for b: Array in bands:
		_wall_piece(tube, ctx, g, side, z0, g0, b[0], b[1], b[2], b[3])
		_wall_piece(tube, ctx, g, side, g1, z1, b[0], b[1], b[2], b[3])
		# above the opening, and below its sill (hidden by the walkway)
		_wall_piece(tube, ctx, g, side, g0, g1, maxf(float(b[0]), top), b[1], b[2], b[3])
		_wall_piece(tube, ctx, g, side, g0, g1, b[0], minf(float(b[1]), WALK_H), b[2], b[3])


## The raised emergency walkway along the wall of one side: its top and the kerb towards the road.
func _walkway(tube: Buf, ctx: ChunkContext, g: Dictionary, side: int) -> void:
	var z0 := float(g["z0"])
	var z1 := float(g["z1"])
	var s := float(side)
	var w0 := wall_x(g, side, z0)
	var w1 := wall_x(g, side, z1)
	var k0 := w0 - s * WALK_W
	var k1 := w1 - s * WALK_W
	var inward := ctx.rows_r[int(g["i"])] * -s
	var uva: Array = [tube_uv(g, z0), tube_uv(g, z1), tube_uv(g, z1), tube_uv(g, z0)]
	tube.quad_full(ctx.local(z0, k0, WALK_H), ctx.local(z1, k1, WALK_H), ctx.local(z1, w1, WALK_H), ctx.local(z0, w0, WALK_H), Vector3.UP, WALKWAY,
		uva, [Vector2(K_WALK, WALK_H), Vector2(K_WALK, WALK_H), Vector2(K_WALK, WALK_H), Vector2(K_WALK, WALK_H)], [])
	tube.quad_full(ctx.local(z0, k0, -0.05), ctx.local(z1, k1, -0.05), ctx.local(z1, k1, WALK_H), ctx.local(z0, k0, WALK_H), inward, KERB,
		uva, [Vector2(K_WALK, 0.0), Vector2(K_WALK, 0.0), Vector2(K_WALK, WALK_H), Vector2(K_WALK, WALK_H)], [])


## The cable tray under the haunch of one side: its underside, front and top.
func _tray(tube: Buf, ctx: ChunkContext, g: Dictionary, side: int) -> void:
	var z0 := float(g["z0"])
	var z1 := float(g["z1"])
	var s := float(side)
	var w0 := wall_x(g, side, z0) - s * 0.01
	var w1 := wall_x(g, side, z1) - s * 0.01
	var d0 := w0 - s * TRAY.x
	var d1 := w1 - s * TRAY.x
	var hb := _wall_h - 0.42
	var ht := hb + TRAY.y
	var inward := ctx.rows_r[int(g["i"])] * -s
	var uva: Array = [tube_uv(g, z0), tube_uv(g, z1), tube_uv(g, z1), tube_uv(g, z0)]
	var m := [Vector2(K_METAL, hb), Vector2(K_METAL, hb), Vector2(K_METAL, ht), Vector2(K_METAL, ht)]
	tube.quad_full(ctx.local(z0, d0, hb), ctx.local(z1, d1, hb), ctx.local(z1, d1, ht), ctx.local(z0, d0, ht), inward, METAL, uva, m, [])
	tube.quad_full(ctx.local(z0, w0, hb), ctx.local(z1, w1, hb), ctx.local(z1, d1, hb), ctx.local(z0, d0, hb), Vector3.DOWN, METAL.darkened(0.25), uva, m, [])
	tube.quad_full(ctx.local(z0, w0, ht), ctx.local(z1, w1, ht), ctx.local(z1, d1, ht), ctx.local(z0, d0, ht), Vector3.UP, METAL.lightened(0.1), uva, m, [])


## Haunches and ceiling of the segment.
func _vault(tube: Buf, ctx: ChunkContext, g: Dictionary) -> void:
	var z0 := float(g["z0"])
	var z1 := float(g["z1"])
	var xl0 := float(g["xl0"])
	var xl1 := float(g["xl1"])
	var xr0 := float(g["xr0"])
	var xr1 := float(g["xr1"])
	var i := int(g["i"])
	var down := Vector3.DOWN
	var in_l := ctx.rows_r[i]
	var in_r := -ctx.rows_r[i]
	var uvs: Array[Vector2] = [tube_uv(g, z0), tube_uv(g, z1), tube_uv(g, z1), tube_uv(g, z0)]
	var hw := Vector2(K_CEIL, _wall_h)
	var hc := Vector2(K_CEIL, _ceil_h)
	tube.quad_full(ctx.local(z0, xl0, _wall_h), ctx.local(z1, xl1, _wall_h), ctx.local(z1, xl1 + _haunch, _ceil_h), ctx.local(z0, xl0 + _haunch, _ceil_h),
		in_l + down, HAUNCH, uvs, [hw, hw, hc, hc], [])
	tube.quad_full(ctx.local(z0, xr0, _wall_h), ctx.local(z1, xr1, _wall_h), ctx.local(z1, xr1 - _haunch, _ceil_h), ctx.local(z0, xr0 - _haunch, _ceil_h),
		in_r + down, HAUNCH, uvs, [hw, hw, hc, hc], [])
	tube.quad_full(ctx.local(z0, xl0 + _haunch, _ceil_h), ctx.local(z1, xl1 + _haunch, _ceil_h), ctx.local(z1, xr1 - _haunch, _ceil_h),
		ctx.local(z0, xr0 - _haunch, _ceil_h), down, CEILING, uvs, [hc, hc, hc, hc], [])


## Lamp rows on both haunches every lamp_every metres: the lens (its glow comes from the flare layer, role "tunnel")
## in a dark housing that stands a little out of the haunch.
func _lamps(tube: Buf, ctx: ChunkContext, g: Dictionary, lamps: Array) -> void:
	var z0 := float(g["z0"])
	var z1 := float(g["z1"])
	var zl := ceilf(z0 / _lamp_every) * _lamp_every
	while zl < z1:
		for side: int in [-1, 1]:
			var xw := wall_x(g, side, zl)
			var inward := float(-side)
			var mid_x := xw + inward * _haunch * 0.5
			var mid_h := (_wall_h + _ceil_h) * 0.5
			# the haunch's own directions: along the slope (up and inwards) and its normal (down and inwards)
			var p_lo := ctx.local(zl, xw, _wall_h)
			var p_hi := ctx.local(zl, xw + inward * _haunch, _ceil_h)
			var slope := (p_hi - p_lo).normalized()
			var fwd := (ctx.local(zl + 1.0, mid_x, mid_h) - ctx.local(zl, mid_x, mid_h)).normalized()
			var nrm := slope.cross(fwd).normalized()
			if nrm.y > 0.0:
				nrm = -nrm
			var c := ctx.local(zl, mid_x, mid_h) + nrm * 0.08
			var luv := tube_uv(g, zl)
			var hk := Vector2(K_METAL, mid_h)
			# the housing: a frame behind the lens and its sides
			var al := fwd * (LAMP_LEN * 0.5 + 0.1)
			var ac := slope * (LAMP_W * 0.5 + 0.07)
			var back := c - nrm * 0.07
			tube.quad(back - al - ac, back + al - ac, back + al + ac, back - al + ac, nrm, METAL.darkened(0.35), luv, hk)
			for e: Array in [[-al, ac], [al, ac], [-ac, al], [ac, al]]:
				var o: Vector3 = e[0]
				var w: Vector3 = e[1]
				tube.quad(back + o - w, back + o + w, c + o + w, c + o - w, o, METAL.darkened(0.15), luv, hk)
			var ll := fwd * (LAMP_LEN * 0.5)
			var lc := slope * (LAMP_W * 0.5)
			var lens := c + nrm * 0.005
			tube.quad(lens - ll - lc, lens + ll - lc, lens + ll + lc, lens - ll + lc, nrm, LAMP_COL, luv, Vector2(K_LAMP, mid_h))
			lamps.append({"pos": lens + nrm * 0.05, "dir": nrm, "role": "tunnel", "color": LAMP_COL, "size": LAMP_LEN, "range": 0.0,
				"energy": 1.0})
		zl += _lamp_every


## An SOS niche in the right wall (the middle of the segment): a lit recess, the orange SOS plate above it, Arcade's
## green emergency sign beside it.
func _niche(tube: Buf, ctx: ChunkContext, g: Dictionary, lamps: Array) -> void:
	var zm := (float(g["z0"]) + float(g["z1"])) * 0.5
	var z_a := zm - NICHE_W * 0.5
	var z_b := zm + NICHE_W * 0.5
	var i := int(g["i"])
	var r := ctx.rows_r[i]
	var f := ctx.rows_f[i]
	var xa := wall_x(g, 1, z_a)
	var xb := wall_x(g, 1, z_b)
	var top := WALK_H + NICHE_H
	var uva: Array = [tube_uv(g, z_a), tube_uv(g, z_b), tube_uv(g, z_b), tube_uv(g, z_a)]
	var lit := [Vector2(K_NICHE, WALK_H), Vector2(K_NICHE, WALK_H), Vector2(K_NICHE, top), Vector2(K_NICHE, top)]
	# back wall, sides, ceiling and floor of the recess
	tube.quad_full(ctx.local(z_a, xa + NICHE_D, WALK_H), ctx.local(z_b, xb + NICHE_D, WALK_H), ctx.local(z_b, xb + NICHE_D, top),
		ctx.local(z_a, xa + NICHE_D, top), -r, NICHE_LIGHT, uva, lit, [])
	tube.quad_full(ctx.local(z_a, xa, WALK_H), ctx.local(z_a, xa + NICHE_D, WALK_H), ctx.local(z_a, xa + NICHE_D, top), ctx.local(z_a, xa, top), f,
		NICHE_LIGHT.darkened(0.12), [uva[0], uva[0], uva[0], uva[0]], lit, [])
	tube.quad_full(ctx.local(z_b, xb, WALK_H), ctx.local(z_b, xb + NICHE_D, WALK_H), ctx.local(z_b, xb + NICHE_D, top), ctx.local(z_b, xb, top), -f,
		NICHE_LIGHT.darkened(0.12), [uva[1], uva[1], uva[1], uva[1]], lit, [])
	tube.quad_full(ctx.local(z_a, xa, top), ctx.local(z_b, xb, top), ctx.local(z_b, xb + NICHE_D, top), ctx.local(z_a, xa + NICHE_D, top), Vector3.DOWN,
		NICHE_LIGHT.darkened(0.2), uva, lit, [])
	tube.quad_full(ctx.local(z_a, xa, WALK_H), ctx.local(z_b, xb, WALK_H), ctx.local(z_b, xb + NICHE_D, WALK_H), ctx.local(z_a, xa + NICHE_D, WALK_H),
		Vector3.UP, WALKWAY, uva, [Vector2(K_WALK, WALK_H), Vector2(K_WALK, WALK_H), Vector2(K_WALK, WALK_H), Vector2(K_WALK, WALK_H)], [])
	# an emergency telephone on the back wall: a dark box face
	var pz := zm - 0.25
	var px := wall_x(g, 1, pz) + NICHE_D - 0.03
	tube.quad(ctx.local(pz - 0.25, px, 1.1), ctx.local(pz + 0.25, px, 1.1), ctx.local(pz + 0.25, px, 1.75), ctx.local(pz - 0.25, px, 1.75), -r,
		Color("e9e4d6"), tube_uv(g, pz), Vector2(K_NICHE, 1.4))
	# the orange SOS plate above the opening (sign-local u, v in CUSTOM0: u from the viewer's left – on the right wall
	# that is the far end along the road – v from the top), the green sign beside it (Arcade's)
	var xs := wall_x(g, 1, zm) - 0.03
	var ph0 := top + 0.15
	var ph1 := ph0 + 0.42
	tube.quad_full(ctx.local(zm - 0.6, xs, ph1), ctx.local(zm + 0.6, xs, ph1), ctx.local(zm + 0.6, xs, ph0), ctx.local(zm - 0.6, xs, ph0), -r, SOS_ORANGE,
		[tube_uv(g, zm), tube_uv(g, zm), tube_uv(g, zm), tube_uv(g, zm)], [Vector2(K_SOS, ph1), Vector2(K_SOS, ph1), Vector2(K_SOS, ph0), Vector2(K_SOS, ph0)],
		[Vector2(1.0, 0.0), Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)])
	var gz := z_b + 0.7
	var gx := wall_x(g, 1, gz) - 0.03
	tube.quad_full(ctx.local(gz - 0.45, gx, 2.25), ctx.local(gz + 0.45, gx, 2.25), ctx.local(gz + 0.45, gx, 1.75), ctx.local(gz - 0.45, gx, 1.75), -r,
		SIGN_GREEN, [tube_uv(g, gz), tube_uv(g, gz), tube_uv(g, gz), tube_uv(g, gz)],
		[Vector2(K_SIGN, 2.25), Vector2(K_SIGN, 2.25), Vector2(K_SIGN, 1.75), Vector2(K_SIGN, 1.75)],
		[Vector2(1.0, 0.0), Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)])
	# the niche's light: a small pool on the walkway and the road for the flare layer and the lights layer
	lamps.append({"pos": ctx.local(zm, xa + NICHE_D * 0.5, top - 0.1), "dir": Vector3.DOWN, "role": "tunnel", "color": NICHE_LIGHT, "size": 0.5,
		"range": 0.0, "energy": 0.6})


## An emergency exit in the left wall: a green steel door in a shallow reveal, a lit green sign above it.
func _door(tube: Buf, ctx: ChunkContext, g: Dictionary) -> void:
	var zm := (float(g["z0"]) + float(g["z1"])) * 0.5
	var z_a := zm - DOOR_W * 0.5
	var z_b := zm + DOOR_W * 0.5
	var i := int(g["i"])
	var r := ctx.rows_r[i]
	var f := ctx.rows_f[i]
	var depth := 0.22
	var xa := wall_x(g, -1, z_a)
	var xb := wall_x(g, -1, z_b)
	var top := WALK_H + DOOR_H
	var uva: Array = [tube_uv(g, z_a), tube_uv(g, z_b), tube_uv(g, z_b), tube_uv(g, z_a)]
	tube.quad_full(ctx.local(z_a, xa - depth, WALK_H), ctx.local(z_b, xb - depth, WALK_H), ctx.local(z_b, xb - depth, top), ctx.local(z_a, xa - depth, top),
		r, DOOR_GREEN, uva, [Vector2(K_DOOR, WALK_H), Vector2(K_DOOR, WALK_H), Vector2(K_DOOR, top), Vector2(K_DOOR, top)],
		[Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	var rv := [Vector2(K_WALL, WALK_H), Vector2(K_WALL, WALK_H), Vector2(K_WALL, top), Vector2(K_WALL, top)]
	tube.quad_full(ctx.local(z_a, xa, WALK_H), ctx.local(z_a, xa - depth, WALK_H), ctx.local(z_a, xa - depth, top), ctx.local(z_a, xa, top), f, CONCRETE,
		[uva[0], uva[0], uva[0], uva[0]], rv, [])
	tube.quad_full(ctx.local(z_b, xb, WALK_H), ctx.local(z_b, xb - depth, WALK_H), ctx.local(z_b, xb - depth, top), ctx.local(z_b, xb, top), -f, CONCRETE,
		[uva[1], uva[1], uva[1], uva[1]], rv, [])
	tube.quad_full(ctx.local(z_a, xa, top), ctx.local(z_b, xb, top), ctx.local(z_b, xb - depth, top), ctx.local(z_a, xa - depth, top), Vector3.DOWN,
		CONCRETE.darkened(0.2), uva, rv, [])
	var xs := wall_x(g, -1, zm) + 0.03
	var s0 := top + 0.2
	var s1 := s0 + 0.4
	tube.quad_full(ctx.local(zm - 0.55, xs, s1), ctx.local(zm + 0.55, xs, s1), ctx.local(zm + 0.55, xs, s0), ctx.local(zm - 0.55, xs, s0), r, SIGN_GREEN,
		[tube_uv(g, zm), tube_uv(g, zm), tube_uv(g, zm), tube_uv(g, zm)], [Vector2(K_SIGN, s1), Vector2(K_SIGN, s1), Vector2(K_SIGN, s0), Vector2(K_SIGN, s0)],
		[Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])


## A pair of jet fans under the ceiling in the middle of the segment: 8-sided drums with dark ends on two hangers.
func _fans(tube: Buf, ctx: ChunkContext, g: Dictionary) -> void:
	var zm := (float(g["z0"]) + float(g["z1"])) * 0.5
	var cx := (wall_x(g, -1, zm) + wall_x(g, 1, zm)) * 0.5
	var hc := maxf(_ceil_h - FAN_R - 0.16, FAN_MIN_BOTTOM + FAN_R)
	if hc + FAN_R > _ceil_h - 0.05:
		return             # no room under this ceiling
	var i := int(g["i"])
	var f := ctx.rows_f[i]
	var r := ctx.rows_r[i]
	var uvm := tube_uv(g, zm)
	for sx: float in [-FAN_SPREAD, FAN_SPREAD]:
		var c0 := ctx.local(zm - FAN_L * 0.5, cx + sx, hc)
		var c1 := ctx.local(zm + FAN_L * 0.5, cx + sx, hc)
		var ring0: Array[Vector3] = []
		var ring1: Array[Vector3] = []
		for q in 8:
			var a := TAU * (float(q) + 0.5) / 8.0
			var off := r * (cos(a) * FAN_R) + Vector3.UP * (sin(a) * FAN_R)
			ring0.append(c0 + off)
			ring1.append(c1 + off)
		for q in 8:
			var q1 := (q + 1) % 8
			var mid := (ring0[q] + ring0[q1]) * 0.5 - c0
			var shade := METAL.darkened(0.1 + 0.2 * clampf(-mid.normalized().y, 0.0, 1.0))
			tube.quad(ring0[q], ring1[q], ring1[q1], ring0[q1], mid, shade, uvm, Vector2(K_METAL, hc))
		# the ends: dark grilles (two quads each, an octagon split into a fan of four)
		for e: Array in [[c0, ring0, -f], [c1, ring1, f]]:
			var cc: Vector3 = e[0]
			var ring: Array[Vector3] = e[1]
			for q in range(0, 8, 2):
				tube.quad(cc, ring[q], ring[(q + 1) % 8], ring[(q + 2) % 8], e[2], METAL.darkened(0.55), uvm, Vector2(K_METAL, hc))
		# two hangers up to the ceiling
		for hz: float in [-FAN_L * 0.3, FAN_L * 0.3]:
			var b := ctx.local(zm + hz, cx + sx, hc + FAN_R)
			var t := ctx.local(zm + hz, cx + sx, _ceil_h + 0.02)
			var w := r * 0.06
			tube.quad(b - w, b + w, t + w, t - w, -f, METAL.darkened(0.3), uvm, Vector2(K_METAL, hc))
			tube.quad(b - w, b + w, t + w, t - w, f, METAL.darkened(0.3), uvm, Vector2(K_METAL, hc))


## The dark cap at peek_m (only drawn for a camera outside this tunnel).
func _cap(tube: Buf, ctx: ChunkContext, g: Dictionary, z_cap: float) -> void:
	var cl := wall_x(g, -1, z_cap) - 0.05
	var cr := wall_x(g, 1, z_cap) + 0.05
	var back := -ctx.rows_f[int(g["i"])]
	var cuv := Vector2(_peek_m, float(g["zp"]))
	tube.quad(ctx.local(z_cap, cl, FOOT), ctx.local(z_cap, cr, FOOT), ctx.local(z_cap, cr, _wall_h), ctx.local(z_cap, cl, _wall_h), back, Color.BLACK,
		cuv, Vector2(K_CAP, 0.0))
	tube.quad(ctx.local(z_cap, cl, _wall_h), ctx.local(z_cap, cr, _wall_h), ctx.local(z_cap, cr - _haunch, _ceil_h + 0.05),
		ctx.local(z_cap, cl + _haunch, _ceil_h + 0.05), back, Color.BLACK, cuv, Vector2(K_CAP, 0.0))


## The opening's outline at a portal (x, h), from the foot of the left wall round to the foot of the right one.
func opening(xl: float, xr: float) -> Array[Vector2]:
	return [Vector2(xl, FOOT), Vector2(xl, _wall_h), Vector2(xl + _haunch, _ceil_h), Vector2(xr - _haunch, _ceil_h), Vector2(xr, _wall_h),
		Vector2(xr, FOOT)]


## The outline offset by w (outwards > 0, inwards < 0): mitred corners; the feet move sideways only.
static func offset_outline(p: Array[Vector2], w: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := p.size()
	for k in n:
		var nrm := Vector2.ZERO
		var cnt := 0
		for e: int in [k - 1, k]:
			if e < 0 or e >= n - 1:
				continue
			var d := (p[e + 1] - p[e]).normalized()
			nrm += Vector2(-d.y, d.x)          # left of the direction of travel = outwards for this outline
			cnt += 1
		if cnt == 2:
			var m := nrm.normalized()
			var c := maxf(0.3, m.dot(Vector2(-(p[k + 1] - p[k]).normalized().y, (p[k + 1] - p[k]).normalized().x)))
			out.append(p[k] + m * (w / c))
		else:
			out.append(p[k] + nrm.normalized() * w)
	return out


## The frame of the exit seen from inside: a concrete ring that stands into the tube at the end of the last segment.
func _exit_frame(tube: Buf, ctx: ChunkContext, g: Dictionary, z_exit: float) -> void:
	var xl := wall_x(g, -1, z_exit)
	var xr := wall_x(g, 1, z_exit)
	var outer := opening(xl, xr)
	var inner := offset_outline(outer, -EXIT_FRAME_W)
	var back := -ctx.rows_f[int(g["i"])]
	var zf := z_exit - 0.35
	var uv := tube_uv(g, zf)
	for k in outer.size() - 1:
		var a := outer[k]
		var b := outer[k + 1]
		var c := inner[k + 1]
		var d := inner[k]
		tube.quad(ctx.local(zf, a.x, a.y), ctx.local(zf, b.x, b.y), ctx.local(zf, c.x, c.y), ctx.local(zf, d.x, d.y), back, CONCRETE, uv,
			Vector2(K_WALL, (a.y + c.y) * 0.5))
		# the reveal from the ring's inner edge to the end of the tube
		var inward := Vector3(0.0, 0.0, 0.0)
		var e := Vector2(-(c - d).y, (c - d).x)
		inward = ctx.rows_r[int(g["i"])] * e.x + Vector3.UP * e.y
		tube.quad(ctx.local(zf, d.x, d.y), ctx.local(zf, c.x, c.y), ctx.local(z_exit + 0.02, c.x, c.y), ctx.local(z_exit + 0.02, d.x, d.y), -inward,
			CONCRETE.darkened(0.12), uv, Vector2(K_WALL, (c.y + d.y) * 0.5))


## Portal at road position z (row i of the chunk); xl / xr = the walls: the frame round the opening, the headwall with
## its cornice, the wing walls and the hill above.
func _portal(buf: Buf, ctx: ChunkContext, i: int, z: float, xl: float, xr: float, scen: Variant, length: float) -> void:
	var rm := ROUGH_CONCRETE
	var nolamp := Vector2(-1.0, 0.0)
	var face := -ctx.rows_f[i]                      # towards the approaching camera
	var head_h := _ceil_h + HEAD_EXTRA
	var conc := CONCRETE
	var conc_light := CONCRETE.lightened(0.08)
	var conc_dark := CONCRETE.darkened(0.18)
	var zf := z - 0.02                              # the headwall a little in front of the tube's first row
	var zo := zf - FRAME_OUT                        # the front of the frame
	var hole := opening(xl, xr)
	var ring := offset_outline(hole, FRAME_W)
	var r := ctx.rows_r[i]
	# the frame: front face, its outer side towards the headwall, the dark reveal towards the tube
	for k in hole.size() - 1:
		var a := hole[k]
		var b := hole[k + 1]
		var c := ring[k + 1]
		var d := ring[k]
		buf.quad(ctx.local(zo, a.x, a.y), ctx.local(zo, b.x, b.y), ctx.local(zo, c.x, c.y), ctx.local(zo, d.x, d.y), face, conc_light, rm, nolamp)
		var e := (b - a).normalized()
		var out := r * (-e.y) + Vector3.UP * e.x        # left of the travel along the outline: outwards
		buf.quad(ctx.local(zo, d.x, d.y), ctx.local(zo, c.x, c.y), ctx.local(zf, c.x, c.y), ctx.local(zf, d.x, d.y), out, conc, rm, nolamp)
		buf.quad(ctx.local(zo, a.x, a.y), ctx.local(zo, b.x, b.y), ctx.local(z, b.x, b.y), ctx.local(z, a.x, a.y), -out, conc_dark.darkened(0.3), rm, nolamp)
	# the headwall round the frame, out to PORTAL_SIDE beyond it
	var left := ring[0].x - PORTAL_SIDE
	var right := ring[ring.size() - 1].x + PORTAL_SIDE
	var q1 := ring[1]
	var q2 := ring[2]
	var q3 := ring[3]
	var q4 := ring[4]
	buf.quad(ctx.local(zf, left, FOOT), ctx.local(zf, ring[0].x, FOOT), ctx.local(zf, q1.x, q1.y), ctx.local(zf, left, q1.y), face, conc, rm, nolamp)
	buf.quad(ctx.local(zf, q4.x, FOOT), ctx.local(zf, right, FOOT), ctx.local(zf, right, q4.y), ctx.local(zf, q4.x, q4.y), face, conc, rm, nolamp)
	buf.quad(ctx.local(zf, left, q1.y), ctx.local(zf, q1.x, q1.y), ctx.local(zf, q2.x, q2.y), ctx.local(zf, left, head_h), face, conc, rm, nolamp)
	buf.quad(ctx.local(zf, left, head_h), ctx.local(zf, q2.x, q2.y), ctx.local(zf, q2.x, head_h), ctx.local(zf, q2.x, head_h), face, conc, rm, nolamp)
	buf.quad(ctx.local(zf, q2.x, q2.y), ctx.local(zf, q3.x, q3.y), ctx.local(zf, q3.x, head_h), ctx.local(zf, q2.x, head_h), face, conc, rm, nolamp)
	buf.quad(ctx.local(zf, q3.x, q3.y), ctx.local(zf, q4.x, q4.y), ctx.local(zf, right, q4.y), ctx.local(zf, right, head_h), face, conc, rm, nolamp)
	buf.quad(ctx.local(zf, q3.x, q3.y), ctx.local(zf, right, head_h), ctx.local(zf, q3.x, head_h), ctx.local(zf, q3.x, head_h), face, conc, rm, nolamp)
	# the cornice on top
	buf.quad(ctx.local(zf - 0.4, left - 0.4, head_h), ctx.local(zf - 0.4, right + 0.4, head_h), ctx.local(zf - 0.4, right + 0.4, head_h + 0.45),
		ctx.local(zf - 0.4, left - 0.4, head_h + 0.45), face, conc_dark, rm, nolamp)
	buf.quad(ctx.local(zf - 0.4, left - 0.4, head_h + 0.45), ctx.local(zf - 0.4, right + 0.4, head_h + 0.45), ctx.local(zf + 0.4, right + 0.4, head_h + 0.45),
		ctx.local(zf + 0.4, left - 0.4, head_h + 0.45), Vector3.UP, conc_dark, rm, nolamp)
	buf.quad(ctx.local(zf - 0.4, left - 0.4, head_h), ctx.local(zf - 0.4, right + 0.4, head_h), ctx.local(zf + 0.02, right + 0.4, head_h),
		ctx.local(zf + 0.02, left - 0.4, head_h), Vector3.DOWN, conc_dark.darkened(0.2), rm, nolamp)
	# wing walls: from the headwall's edge (head height) down to 0.6 m at their outer end, standing on the ground
	for side: int in [-1, 1]:
		var xw := left if side < 0 else right
		var xo := xw + float(side) * WING_M
		var g_o := ctx.ground(z, xo)
		buf.quad(ctx.local(zf, xw, FOOT), ctx.local(zf, xo, g_o - 1.0), ctx.local(zf, xo, g_o + 0.6), ctx.local(zf, xw, head_h), face, conc_dark.lerp(conc, 0.5),
			rm, nolamp)
		# its coping
		buf.quad(ctx.local(zf - 0.25, xw, head_h + 0.02), ctx.local(zf - 0.25, xo, g_o + 0.62), ctx.local(zf + 0.25, xo, g_o + 0.62),
			ctx.local(zf + 0.25, xw, head_h + 0.02), Vector3.UP, conc_dark, rm, nolamp)
	_hill(buf, ctx, i, z, xl, xr, left, right, scen, length)


## Arcade's hill above a portal (RoadRenderer._draw_portal, the same seeded sequence per tunnel): its front edge on the
## headwall, the wing walls and the ground, its ridge `back` metres behind the portal (Arcade's silhouette), behind it
## a slope down below the road; colours like Arcade's – from the scenery's darkened grass tone at the bottom of the face
## to its lighter tone on the ridge – with smooth normals, and Arcade's conifers along the ridge. xl / xr = the walls
## (Arcade's road edges), left / right = the headwall's ends.
func _hill(buf: Buf, ctx: ChunkContext, i: int, z: float, xl: float, xr: float, left: float, right: float, scen: Variant,
		length: float) -> void:
	var nolamp := Vector2(-1.0, 0.0)
	var face := -ctx.rows_f[i]
	var head_h := _ceil_h + HEAD_EXTRA
	var zf := z - 0.02
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ctx.segs[i]["index"]) * 31 + 7
	var cx := (xl + xr) * 0.5
	var span := HILL_SPAN + (xr - xl) * 0.5
	var scale := clampf(length / 120.0, 0.35, 1.0)    # a short tunnel gets a lower hill that ends at its exit
	var peak := (HILL_PEAK + rng.randf_range(-5.0, 9.0)) * scale
	var max_back := maxf(4.0, length * 0.45)
	var veg := _veg_colour(scen)
	var veg_top := veg.lightened(0.08)
	var veg_bot := veg.darkened(0.2)
	# Arcade's columns: 31 across the span and the two road edges
	var xs: Array[float] = []
	for c in HILL_COLS + 1:
		xs.append(cx + (float(c) / float(HILL_COLS) * 2.0 - 1.0) * span)
	xs.append(xl)
	xs.append(xr)
	xs.sort()
	var front: Array[Vector3] = []
	var ridge: Array[Vector3] = []
	var foot: Array[Vector3] = []
	var front_h: Array[float] = []
	var ridge_h: Array[float] = []
	for x: float in xs:
		var tt := (x - cx) / span
		var hgt := peak * pow(maxf(0.0, 1.0 - tt * tt), 1.15) + rng.randf_range(-0.7, 0.9) * (1.0 - absf(tt)) * 2.0 * scale
		# the front edge sits on the portal: on the headwall, on the wing walls beside it, on the ground beyond them
		var hb: float
		if x >= left and x <= right:
			hb = head_h + 0.45
		elif x < left and x > left - WING_M:
			hb = lerpf(head_h, 0.6 + ctx.ground(z, left - WING_M), (left - x) / WING_M)
		elif x > right and x < right + WING_M:
			hb = lerpf(head_h, 0.6 + ctx.ground(z, right + WING_M), (x - right) / WING_M)
		else:
			hb = ctx.ground(z, x) - 0.5
		hgt = maxf(hgt, hb + 0.5)
		var back := minf(HILL_BACK * pow(maxf(0.0, 1.0 - absf(tt)), 0.8), max_back) + 1.0
		var fall := minf(HILL_FALL * (0.4 + 0.6 * (1.0 - absf(tt))), maxf(2.0, length - back))
		front.append(ctx.local(zf + 0.05, x, hb))
		ridge.append(ctx.local(z + back, x, hgt))
		foot.append(ctx.local(z + back + fall, x, -HILL_SINK * scale))
		front_h.append(hb)
		ridge_h.append(hgt)
	var n := xs.size()
	# smooth normals: every corner the mean of the faces around it
	var n_front: Array[Vector3] = []
	var n_ridge: Array[Vector3] = []
	var n_foot: Array[Vector3] = []
	n_front.resize(n)
	n_ridge.resize(n)
	n_foot.resize(n)
	for c in n:
		n_front[c] = Vector3.ZERO
		n_ridge[c] = Vector3.ZERO
		n_foot[c] = Vector3.ZERO
	for c in n - 1:
		var nf := _face_normal(front[c], front[c + 1], ridge[c + 1], ridge[c], face + Vector3.UP)
		var nb := _face_normal(ridge[c], ridge[c + 1], foot[c + 1], foot[c], Vector3.UP - face)
		for q: int in [c, c + 1]:
			n_front[q] += nf
			n_ridge[q] += nf + nb
			n_foot[q] += nb
	for c in n - 1:
		if xs[c + 1] - xs[c] < 0.01:
			continue
		var ca := veg_bot.lerp(veg_top, clampf(front_h[c] / maxf(peak, 1.0), 0.0, 1.0))
		var cb := veg_bot.lerp(veg_top, clampf(front_h[c + 1] / maxf(peak, 1.0), 0.0, 1.0))
		buf.quad_vc(front[c], front[c + 1], ridge[c + 1], ridge[c], face + Vector3.UP,
			[n_front[c], n_front[c + 1], n_ridge[c + 1], n_ridge[c]], [ca, cb, veg_top, veg_top], ROUGH_GRASS, nolamp)
		var back_c := veg_top.darkened(0.06)
		buf.quad_vc(ridge[c], ridge[c + 1], foot[c + 1], foot[c], Vector3.UP - face,
			[n_ridge[c], n_ridge[c + 1], n_foot[c + 1], n_foot[c]], [veg_top, veg_top, back_c, back_c], ROUGH_GRASS, nolamp)
	# Arcade's conifers along the ridge (veg_top darkened by 0.25, 5–9 m, three of four columns)
	var tree_c := veg_top.darkened(0.25)
	for c in range(1, n - 1):
		if ridge_h[c] < 2.0 or rng.randf() < 0.25:
			continue
		var th := rng.randf_range(5.0, 9.0) * maxf(scale, 0.6)
		var base := ridge[c] - Vector3.UP * 0.4
		var tip := base + Vector3.UP * (th + 0.4)
		var r := th * 0.2
		var right_v := ctx.rows_r[i] * r
		var fwd_v := ctx.rows_f[i] * r
		var ring: Array[Vector3] = [base - right_v, base - fwd_v, base + right_v, base + fwd_v]
		for q in 4:
			var a := ring[q]
			var b := ring[(q + 1) % 4]
			var out := ((a + b) * 0.5 - base).normalized() + Vector3.UP * 0.35
			buf.quad(a, b, tip, tip, out, tree_c, ROUGH_GRASS, nolamp)


## Unit normal of the quad a-b-c-d that faces `toward`.
static func _face_normal(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3) -> Vector3:
	var nn := (b - a).cross(d - a)
	if nn.length_squared() < 1.0e-12:
		nn = (c - a).cross(d - a)
	if nn.length_squared() < 1.0e-12:
		return Vector3.UP
	nn = nn.normalized()
	return -nn if nn.dot(toward) < 0.0 else nn


## The hill's colour: the scenery's first grass tone darkened (Arcade), under snow mostly snow.
func _veg_colour(scen: Variant) -> Color:
	var gcols: Variant = (scen as Dictionary).get("grass", ["#5d9a3e"]) if scen is Dictionary else ["#5d9a3e"]
	var first := "#5d9a3e"
	if gcols is Array and not (gcols as Array).is_empty():
		first = str((gcols as Array)[0])
	var veg := Color(first).darkened(0.22)
	if _snow:
		veg = veg.lerp(Palette.SNOW_GROUND, 0.8)
	return veg


## Main thread: the tube with the tunnel material, the portal in vpbr (static); the lamps go to the renderer.
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var materials: Variant = ctx.services.get("materials")
	if not (materials is ModernMaterials):
		materials = ModernMaterials.shared()
	var casts := int(ctx.levels.get("shadow_casters", 0)) >= 1
	var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tube: Array = part.get("tube", [])
	if not tube.is_empty():
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tube, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		var mi := MeshInstance3D.new()
		mi.name = "TunnelTube"
		mi.mesh = mesh
		mi.material_override = tube_material(materials as ModernMaterials)
		mi.cast_shadow = shadow
		parent.add_child(mi)
		var renderer: Variant = ctx.services.get("renderer")
		var lamps: Array = part.get("lamps", [])
		if renderer != null and not lamps.is_empty():
			(renderer as Object).call(&"add_lamps", mi, lamps)
	var portal: Array = part.get("portal", [])
	if not portal.is_empty():
		var pmesh := ArrayMesh.new()
		pmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, portal)
		var pi := MeshInstance3D.new()
		pi.name = "TunnelPortal"
		pi.mesh = pmesh
		pi.material_override = (materials as ModernMaterials).material(ModernMaterials.VPBR_STATIC)
		pi.cast_shadow = shadow
		parent.add_child(pi)


## The one tube material (main thread).
func tube_material(materials: ModernMaterials = null) -> ShaderMaterial:
	if _material == null:
		var m := materials if materials != null else ModernMaterials.shared()
		_material = m.material(SHADER_CLASS) as ShaderMaterial
		_material.set_shader_parameter("darkness_m", _dark_m)
		_material.set_shader_parameter("peek_m", _peek_m)
		_material.set_shader_parameter("lamp_every", _lamp_every)
		_material.set_shader_parameter("lamp_h", (_wall_h + _ceil_h) * 0.5)
		_material.set_shader_parameter("halo_colour", Vector3(LAMP_COL.r, LAMP_COL.g, LAMP_COL.b))
		var fog := Palette.TUNNEL_FOG
		_material.set_shader_parameter("fog_colour", Vector3(fog.r, fog.g, fog.b))
		var lamp := LAMP_COL.lerp(Color.WHITE, 0.4)
		_material.set_shader_parameter("lamp_colour", Vector3(lamp.r, lamp.g, lamp.b))
		_state_key = ""
	return _material


## The zone amount at road position z (0 in the open, rising from ZONE_OUT_M before a portal to 1 at ZONE_IN_M
## inside) – EnvironmentRig.tunnel_blend's law, a function of the position alone.
static func zone_amount(track: Track, z: float) -> float:
	if track == null or track.plan == null or track.plan.tunnels.is_empty() or z > track.length_z + ZONE_OUT_M:
		return 0.0
	var signed := -1.0e9
	for t: Dictionary in track.plan.tunnels:
		var z0 := track.km_to_z(float(t["start_km"]))
		var z1 := minf(track.km_to_z(float(t["end_km"])), track.length_z)
		signed = maxf(signed, minf(z - z0, z1 - z))
	return smoothstep(-ZONE_OUT_M, ZONE_IN_M, signed)


## Every frame (main thread): the tunnel light of the palette and the tunnel the camera is in; the zone for the
## environment (tunnel_state, EnvironmentRig.set_zone when it exists).
func update(view: Dictionary, _dt: float) -> void:
	if not _has_tunnels or _renderer == null:
		return
	var pal: Variant = view.get("palette")
	if not (pal is Dictionary):
		return
	var trk: Variant = _renderer.get("track")
	if not (trk is Track):
		return
	var track := trk as Track
	var cam_z := float(view.get("camera_z", 0.0))
	var cam_tunnel := -1.0e9
	var t: Dictionary = {}
	if bool(view.get("camera_in_tunnel", false)) or track.is_tunnel_at(cam_z):
		t = track.plan.tunnel_at(track.z_to_km(cam_z))
		if not t.is_empty():
			cam_tunnel = float(ceili(track.km_to_z(float(t["start_km"])) / track.seg_len - 1.0e-6)) * track.seg_len
	_update_zone(view, track, cam_z, t)
	var tun: Dictionary = Palette.tunnel(pal as Dictionary)
	var amb: Color = tun.get("ambient", Palette.TUNNEL_AMBIENT)
	var lights := float((pal as Dictionary).get("lights", 0.0))
	var key := "%s|%.3f|%.1f" % [amb.to_html(), lights, cam_tunnel]
	if key == _state_key:
		return
	_state_key = key
	var m := tube_material()
	m.set_shader_parameter("ambient_in", Vector3(amb.r, amb.g, amb.b))
	var k := 0.5 + 0.5 * lights            # Arcade: the tube seen from outside, eyes adapted to the daylight
	m.set_shader_parameter("ambient_out", Vector3(amb.r * k, amb.g * k, amb.b * k))
	m.set_shader_parameter("cam_tunnel_z", cam_tunnel)
	m.set_shader_parameter("lights", clampf(lights, 0.0, 1.0))


## tunnel_state for this frame and the call EnvironmentRig.set_zone("tunnel", amount) when the rig has it.
func _update_zone(view: Dictionary, track: Track, cam_z: float, t: Dictionary) -> void:
	var amount := zone_amount(track, cam_z + 1.0)
	var vis := float(view.get("visibility_m", 900.0))
	var exit_m := INF
	if not t.is_empty():
		exit_m = track.km_to_z(float(t["end_km"])) - cam_z
	var portal_m := INF
	for tt: Dictionary in track.plan.tunnels:
		var zp := track.km_to_z(float(tt["start_km"]))
		if zp > cam_z:
			portal_m = minf(portal_m, zp - cam_z)
	tunnel_state = {"amount": amount, "inside": not t.is_empty(), "exit_m": exit_m, "portal_m": portal_m,
		"exit_in_sight": not t.is_empty() and exit_m <= vis}
	var env: Variant = _renderer.get("env")
	if env is Object and is_instance_valid(env) and (env as Object).has_method(&"set_zone"):
		if absf(amount - _zone_sent) > 1.0e-4 or _zone_sent < 0.0:
			_zone_sent = amount
			_zone_calls += 1
			(env as Object).call(&"set_zone", "tunnel", amount)


## One node for the tube's shader behind the loading picture (only on stages with tunnels).
func warmup_nodes() -> Array:
	if not _has_tunnels:
		return []
	var b := Buf.new()
	b.custom = true
	b.quad(Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0), Vector3.BACK, TILE, Vector2.ZERO, Vector2(K_TILE, 1.0))
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.arrays(), [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = tube_material()
	return [mi]


func snapshot() -> Dictionary:
	return {"tunnel": {"zone": snappedf(float(tunnel_state.get("amount", 0.0)), 0.0001), "zone_calls": _zone_calls,
		"inside": bool(tunnel_state.get("inside", false))}}


func debug(part: Dictionary) -> Dictionary:
	return {"segments": int(part.get("segments", 0)), "portals": int(part.get("portals", 0)), "caps": int(part.get("caps", 0)),
		"niches": int(part.get("niches", 0)), "doors": int(part.get("doors", 0)), "fans": int(part.get("fans", 0)),
		"exits": int(part.get("exits", 0)), "lamps": (part.get("lamps", []) as Array).size(),
		"tube_triangles": int(part.get("tube_triangles", 0)), "portal_triangles": int(part.get("portal_triangles", 0))}
