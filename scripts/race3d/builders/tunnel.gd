extends ChunkBuilder
## Tunnel builder of the mode "Modern" (v0.8.0) – FIX1 after the QA of M1 (finding QB-01: tunnels of other stages were
## open green land under a black sky): a MINIMAL tube in Arcade's shapes and colours until the tunnel package of M2
## (R5, contract §6) builds the real one (walkways, niches with doors, portal frames, wall signs on their own, the
## exposure ramp at the exit). What is here mirrors Arcade (RoadRenderer._tunnel_segment / _draw_portal / _tunnel_cap,
## frozen):
##  * the tube of every tunnel segment, from the outer shoulder edge on both sides (where Arcade's walls stand): the
##    light tile band up to 2.9 m (a little darker every second pair of segments), the wall up to render.tunnel.
##    wall_height_m, the haunches inwards by haunch_m up to ceiling_m, the ceiling; lamp strips on both haunches every
##    light_every_m (they glow through the flare layer, role "tunnel"), a green emergency sign every 150 m on the right
##    wall. Material: assets/shaders/modern/tunnel.gdshader – Arcade's tunnel light and tunnel fog whatever the
##    environment does, so the tube looks the same from outside and inside;
##  * for a camera outside the tunnel only the first peek_m (45 m) are drawn and a dark cap closes the tube there
##    (the tube deeper inside could curve out of the hill) – the shader decides by the portal z of each vertex;
##  * at every portal (the first segment of a tunnel): a concrete headwall over the opening with wing walls, and the
##    overgrown hill above it (Arcade's silhouette: 85 m + half the road wide to each side, 30 m (± a seeded
##    variation) high, its ridge up to 38 m behind the portal, in the scenery's darkened grass colour) as a lit mesh
##    in the material class "vpbr", falling off behind the ridge. The terrain builder lays nothing in tunnel rows.
## Builder rules: build() runs on worker threads – ctx snapshot arrays and the plain input of collect() only; every
## position from ctx.local(). Without a renderer (tests) the meshes are built all the same.
## Owner: FIX1 for M1; R5 takes it over in M2. Docs: docs/renderer-modern.md §14.

const SHADER_CLASS := "tunnel"     ## assets/shaders/modern/tunnel.gdshader through ModernMaterials
const TILE := Color("d9d3c2")      ## RoadRenderer.TILE
const WALL := Color("75716a")      ## RoadRenderer.WALL
const HAUNCH := Color("57544e")    ## RoadRenderer.HAUNCH
const CEILING := Color("3e3b35")   ## RoadRenderer.CEILING
const CONCRETE := Color("b9b5aa")  ## RoadRenderer.CONCRETE
const LAMP_COL := Color(1.0, 0.82, 0.55)   ## RoadRenderer.LAMP_COL
const TILE_TOP := 2.9              ## top of the tile band (m)
const FOOT := -0.4                 ## the walls reach this far below the road (no gap at the road's edge)
const NICHE_EVERY := 150.0
const LAMP_LEN := 0.7              ## lamp strip along the road …
const LAMP_W := 0.22               ## … and across the haunch (Arcade's lamp rectangle)
const WING_M := 9.0                ## wing walls beside the opening
const HEAD_EXTRA := 2.4            ## headwall above the ceiling (Arcade: head_h = ceiling + 2.4)
const HILL_SPAN := 85.0            ## half width of the hill beyond the middle of the road …
const HILL_PEAK := 30.0            ## … its height …
const HILL_BACK := 38.0            ## … and how far behind the portal its ridge lies at the middle
const HILL_FALL := 70.0            ## behind the ridge it falls this far (at the middle) …
const HILL_SINK := 8.0             ## … to this depth below the road
const HILL_COLS := 24
const ROUGH_CONCRETE := Vector2(0.9, 0.0)
const ROUGH_GRASS := Vector2(0.97, 0.0)

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


## Vertex arrays of one chunk while it is built (the tube: tunnel.gdshader; the portal: vpbr).
class Buf extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	## A flat quad a-b-c-d (in order around it) that faces `toward`; uv / uv2 for all four corners.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color, uv_v: Vector2, uv2_v: Vector2) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length_squared() < 1.0e-12:
			nn = (c - a).cross(d - a)
		if nn.length_squared() < 1.0e-12:
			return
		nn = nn.normalized()
		if nn.dot(toward) < 0.0:
			nn = -nn
		var o := v.size()
		for p: Vector3 in [a, b, c, d]:
			v.append(p)
			n.append(nn)
			col.append(colour)
			uv.append(uv_v)
			uv2.append(uv2_v)
		# front faces are clockwise
		if (c - a).cross(b - a).dot(nn) >= 0.0:
			idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
		else:
			idx.append_array(PackedInt32Array([o, o + 2, o + 1, o, o + 3, o + 2]))

	## Like quad(), but uv per corner (the depth into the tunnel changes along the road).
	func quad_uv(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color, uvs: Array[Vector2], uv2_v: Vector2) -> void:
		var o := v.size()
		quad(a, b, c, d, toward, colour, uvs[0], uv2_v)
		if v.size() > o:
			for q in 4:
				uv[o + q] = uvs[q]

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
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
## of segments, the stage plan the whole list – and the scenery's grass colour for a hill.
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


## WORKER THREAD.
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var inp: Dictionary = input if input is Dictionary else {}
	var tunnels: Array = inp.get("tunnels", [])
	if tunnels.is_empty():
		return {}
	var tube := Buf.new()
	var portal := Buf.new()
	var lamps: Array = []
	var rows := ctx.row_count()
	var seg_len := ctx.seg_len
	var segments := 0
	var portals := 0
	var caps := 0
	var niches := 0
	for i in rows - 1:
		var sa: Dictionary = ctx.segs[i]
		if not bool(sa["tunnel"]):
			continue
		var seg := ctx.seg_a + i
		var t := tunnel_of(tunnels, seg)
		if t.is_empty():
			continue
		segments += 1
		var z_portal := float(int(t[0])) * seg_len
		var z_end := float(int(t[1])) * seg_len
		var z0 := float(seg) * seg_len
		var z1 := z0 + seg_len
		var xl0 := -ctx.shoulder_edge(i, -1)
		var xl1 := -ctx.shoulder_edge(i + 1, -1)
		var xr0 := ctx.shoulder_edge(i, 1)
		var xr1 := ctx.shoulder_edge(i + 1, 1)
		var uvs: Array[Vector2] = [Vector2(z0 - z_portal, z_portal), Vector2(z1 - z_portal, z_portal), Vector2(z1 - z_portal, z_portal),
			Vector2(z0 - z_portal, z_portal)]
		var surf := Vector2(0.0, 0.0)
		var tile := TILE if (int(sa["index"]) / 2) % 2 == 0 else TILE.darkened(0.06)
		var in_l := ctx.rows_r[i]
		var in_r := -ctx.rows_r[i]
		# walls: tile band and wall above it, both sides (facing the road)
		tube.quad_uv(ctx.local(z0, xl0, FOOT), ctx.local(z1, xl1, FOOT), ctx.local(z1, xl1, TILE_TOP), ctx.local(z0, xl0, TILE_TOP), in_l, tile, uvs, surf)
		tube.quad_uv(ctx.local(z0, xl0, TILE_TOP), ctx.local(z1, xl1, TILE_TOP), ctx.local(z1, xl1, _wall_h), ctx.local(z0, xl0, _wall_h), in_l, WALL, uvs, surf)
		tube.quad_uv(ctx.local(z0, xr0, FOOT), ctx.local(z1, xr1, FOOT), ctx.local(z1, xr1, TILE_TOP), ctx.local(z0, xr0, TILE_TOP), in_r, tile, uvs, surf)
		tube.quad_uv(ctx.local(z0, xr0, TILE_TOP), ctx.local(z1, xr1, TILE_TOP), ctx.local(z1, xr1, _wall_h), ctx.local(z0, xr0, _wall_h), in_r, WALL, uvs, surf)
		# haunches and ceiling (facing down into the tube)
		var down := Vector3.DOWN
		tube.quad_uv(ctx.local(z0, xl0, _wall_h), ctx.local(z1, xl1, _wall_h), ctx.local(z1, xl1 + _haunch, _ceil_h), ctx.local(z0, xl0 + _haunch, _ceil_h),
			in_l + down, HAUNCH, uvs, surf)
		tube.quad_uv(ctx.local(z0, xr0, _wall_h), ctx.local(z1, xr1, _wall_h), ctx.local(z1, xr1 - _haunch, _ceil_h), ctx.local(z0, xr0 - _haunch, _ceil_h),
			in_r + down, HAUNCH, uvs, surf)
		tube.quad_uv(ctx.local(z0, xl0 + _haunch, _ceil_h), ctx.local(z1, xl1 + _haunch, _ceil_h), ctx.local(z1, xr1 - _haunch, _ceil_h),
			ctx.local(z0, xr0 - _haunch, _ceil_h), down, CEILING, uvs, surf)
		# lamp strips on both haunches every lamp_every metres
		var zl := ceilf(z0 / _lamp_every) * _lamp_every
		while zl < z1:
			var f := (zl - z0) / seg_len
			var depth := zl - z_portal
			for side: int in [-1, 1]:
				var xw := lerpf(xl0, xl1, f) if side < 0 else lerpf(xr0, xr1, f)
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
				var c := ctx.local(zl, mid_x, mid_h) + nrm * 0.04
				var al := fwd * (LAMP_LEN * 0.5)
				var ac := slope * (LAMP_W * 0.5)
				var luv := Vector2(depth, z_portal)
				tube.quad(c - al - ac, c + al - ac, c + al + ac, c - al + ac, nrm, LAMP_COL, luv, Vector2(2.0, 0.0))
				lamps.append({"pos": c + nrm * 0.05, "dir": nrm, "role": "tunnel", "color": LAMP_COL, "size": LAMP_LEN, "range": 0.0,
					"energy": 1.0})
			zl += _lamp_every
		# emergency sign on the right wall every 150 m (Arcade: green, 0.9 m wide, at 1.75–2.25 m)
		if fposmod(z0, NICHE_EVERY) < seg_len:
			niches += 1
			var zn := z0 + seg_len * 0.5
			var xn := lerpf(xr0, xr1, 0.5) - 0.03
			var nuv := Vector2(zn - z_portal, z_portal)
			tube.quad(ctx.local(zn - 0.45, xn, 1.75), ctx.local(zn + 0.45, xn, 1.75), ctx.local(zn + 0.45, xn, 2.25), ctx.local(zn - 0.45, xn, 2.25),
				in_r, Color("1f9d4a"), nuv, Vector2(3.0, 0.0))
		# the cap that closes the tube for a camera outside: at peek_m behind the portal (facing the portal)
		var z_cap := z_portal + _peek_m
		if z_cap >= z0 and z_cap < z1 and z_cap < z_end - seg_len:
			caps += 1
			var fc := (z_cap - z0) / seg_len
			var cl := lerpf(xl0, xl1, fc) - 0.05
			var cr := lerpf(xr0, xr1, fc) + 0.05
			var back := -ctx.rows_f[i]
			var cuv := Vector2(_peek_m, z_portal)
			tube.quad(ctx.local(z_cap, cl, FOOT), ctx.local(z_cap, cr, FOOT), ctx.local(z_cap, cr, _wall_h), ctx.local(z_cap, cl, _wall_h), back, Color.BLACK,
				cuv, Vector2(1.0, 0.0))
			tube.quad(ctx.local(z_cap, cl, _wall_h), ctx.local(z_cap, cr, _wall_h), ctx.local(z_cap, cr - _haunch, _ceil_h + 0.05),
				ctx.local(z_cap, cl + _haunch, _ceil_h + 0.05), back, Color.BLACK, cuv, Vector2(1.0, 0.0))
		# the portal: the first segment of the tunnel
		if seg == int(t[0]):
			portals += 1
			_portal(portal, ctx, i, z0, xl0, xr0, ctx.scenery_db.get(str(sa["scenery"]), {}), z_end - z_portal)
	return {"tube": tube.arrays() if not tube.idx.is_empty() else [], "portal": portal.arrays() if not portal.idx.is_empty() else [],
		"lamps": lamps, "segments": segments, "portals": portals, "caps": caps, "niches": niches,
		"tube_triangles": tube.idx.size() / 3, "portal_triangles": portal.idx.size() / 3}


## Headwall, wing walls and the hill above a portal at road position z (row i of the chunk); xl / xr = the walls.
func _portal(buf: Buf, ctx: ChunkContext, i: int, z: float, xl: float, xr: float, scen: Variant, length: float) -> void:
	var rm := ROUGH_CONCRETE
	var nolamp := Vector2(-1.0, 0.0)
	var face := -ctx.rows_f[i]                      # towards the approaching camera
	var head_h := _ceil_h + HEAD_EXTRA
	var conc := CONCRETE
	var conc_dark := CONCRETE.darkened(0.18)
	var zf := z - 0.02                              # the face a little in front of the tube's first row
	# headwall above the opening, the corners above the haunches, the cornice
	buf.quad(ctx.local(zf, xl, _ceil_h), ctx.local(zf, xr, _ceil_h), ctx.local(zf, xr, head_h), ctx.local(zf, xl, head_h), face, conc, rm, nolamp)
	# (triangles: the fourth corner repeats the third)
	buf.quad(ctx.local(zf, xl, _wall_h), ctx.local(zf, xl + _haunch, _ceil_h), ctx.local(zf, xl, _ceil_h), ctx.local(zf, xl, _ceil_h), face, conc, rm, nolamp)
	buf.quad(ctx.local(zf, xr, _wall_h), ctx.local(zf, xr - _haunch, _ceil_h), ctx.local(zf, xr, _ceil_h), ctx.local(zf, xr, _ceil_h), face, conc, rm, nolamp)
	buf.quad(ctx.local(zf - 0.3, xl - 0.6, head_h), ctx.local(zf - 0.3, xr + 0.6, head_h), ctx.local(zf - 0.3, xr + 0.6, head_h + 0.35),
		ctx.local(zf - 0.3, xl - 0.6, head_h + 0.35), face, conc_dark, rm, nolamp)
	buf.quad(ctx.local(zf - 0.3, xl - 0.6, head_h + 0.35), ctx.local(zf - 0.3, xr + 0.6, head_h + 0.35), ctx.local(zf + 0.3, xr + 0.6, head_h + 0.35),
		ctx.local(zf + 0.3, xl - 0.6, head_h + 0.35), Vector3.UP, conc_dark, rm, nolamp)
	# frame of the opening: dark strips on the wall ends
	for side: int in [-1, 1]:
		var xw := xl if side < 0 else xr
		var inward := float(-side)
		buf.quad(ctx.local(zf - 0.01, xw - inward * 0.15, FOOT), ctx.local(zf - 0.01, xw + inward * 0.5, FOOT), ctx.local(zf - 0.01, xw + inward * 0.5, _wall_h),
			ctx.local(zf - 0.01, xw - inward * 0.15, _wall_h), face, conc_dark, rm, nolamp)
	# wing walls: from the opening (head height) down to 0.6 m at their outer end, standing on the ground
	for side: int in [-1, 1]:
		var xw := xl if side < 0 else xr
		var xo := xw + float(side) * WING_M
		var g_o := ctx.ground(z, xo)
		buf.quad(ctx.local(zf, xw, FOOT), ctx.local(zf, xo, g_o - 1.0), ctx.local(zf, xo, g_o + 0.6), ctx.local(zf, xw, head_h), face, conc_dark.lerp(conc, 0.5),
			rm, nolamp)
	# the hill (Arcade's silhouette, seeded per tunnel): rows = front edge on the portal, ridge, foot behind it
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ctx.segs[i]["index"]) * 31 + 7
	var cx := (xl + xr) * 0.5
	var span := HILL_SPAN + (xr - xl) * 0.5
	var scale := clampf(length / 120.0, 0.35, 1.0)    # a short tunnel gets a lower hill that ends before its exit
	var peak := (HILL_PEAK + rng.randf_range(-5.0, 9.0)) * scale
	var max_back := maxf(4.0, length * 0.45)
	var veg := _veg_colour(scen)
	var veg_top := veg.lightened(0.08)
	var veg_bot := veg.darkened(0.2)
	var cols := HILL_COLS
	var front: Array[Vector3] = []
	var ridge: Array[Vector3] = []
	var foot: Array[Vector3] = []
	var front_h: Array[float] = []
	var ridge_h: Array[float] = []
	for c in cols + 1:
		var tt := float(c) / float(cols) * 2.0 - 1.0
		var x := cx + tt * span
		# the front edge sits on the portal: on the headwall over the opening, on the wing walls beside it, on the
		# ground beyond them
		var hb: float
		if x >= xl and x <= xr:
			hb = head_h
		elif x < xl and x > xl - WING_M:
			hb = lerpf(head_h, 0.6 + ctx.ground(z, xl - WING_M), (xl - x) / WING_M)
		elif x > xr and x < xr + WING_M:
			hb = lerpf(head_h, 0.6 + ctx.ground(z, xr + WING_M), (x - xr) / WING_M)
		else:
			hb = ctx.ground(z, x) - 0.5
		var hgt := peak * pow(maxf(0.0, 1.0 - tt * tt), 1.15) + rng.randf_range(-0.7, 0.9) * (1.0 - absf(tt)) * 2.0 * scale
		hgt = maxf(hgt, hb + 0.5)
		var back := minf(HILL_BACK * pow(maxf(0.0, 1.0 - absf(tt)), 0.8), max_back) + 1.0
		var fall := minf(HILL_FALL * (0.4 + 0.6 * (1.0 - absf(tt))), maxf(2.0, length - back))
		front.append(ctx.local(zf + 0.05, x, hb))
		ridge.append(ctx.local(z + back, x, hgt))
		foot.append(ctx.local(z + back + fall, x, -HILL_SINK * scale))
		front_h.append(hb)
		ridge_h.append(hgt)
	for c in cols:
		var fa := clampf(front_h[c] / maxf(peak, 1.0), 0.0, 1.0)
		var fb := clampf(front_h[c + 1] / maxf(peak, 1.0), 0.0, 1.0)
		var col_front := veg_bot.lerp(veg_top, (fa + fb) * 0.5)
		buf.quad(front[c], front[c + 1], ridge[c + 1], ridge[c], face + Vector3.UP, col_front.lerp(veg_top, 0.5), ROUGH_GRASS, nolamp)
		buf.quad(ridge[c], ridge[c + 1], foot[c + 1], foot[c], Vector3.UP - face, veg_top.darkened(0.05), ROUGH_GRASS, nolamp)


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


## Main thread: the tube with the tunnel material, the portal in vpbr; the lamps go to the flare layer.
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var materials: Variant = ctx.services.get("materials")
	if not (materials is ModernMaterials):
		materials = ModernMaterials.shared()
	var casts := int(ctx.levels.get("shadow_casters", 0)) >= 1
	var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tube: Array = part.get("tube", [])
	if not tube.is_empty():
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tube)
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
		pi.material_override = (materials as ModernMaterials).material("vpbr")
		pi.cast_shadow = shadow
		parent.add_child(pi)


## The one tube material (main thread).
func tube_material(materials: ModernMaterials = null) -> ShaderMaterial:
	if _material == null:
		var m := materials if materials != null else ModernMaterials.shared()
		_material = m.material(SHADER_CLASS) as ShaderMaterial
		_material.set_shader_parameter("darkness_m", _dark_m)
		_material.set_shader_parameter("peek_m", _peek_m)
		var fog := Palette.TUNNEL_FOG
		_material.set_shader_parameter("fog_colour", Vector3(fog.r, fog.g, fog.b))
		var lamp := LAMP_COL.lerp(Color.WHITE, 0.4)
		_material.set_shader_parameter("lamp_colour", Vector3(lamp.r, lamp.g, lamp.b))
		_state_key = ""
	return _material


## Every frame (main thread): the tunnel light of the palette and the tunnel the camera is in.
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
	if bool(view.get("camera_in_tunnel", false)) or track.is_tunnel_at(cam_z):
		var t: Dictionary = track.plan.tunnel_at(track.z_to_km(cam_z))
		if not t.is_empty():
			cam_tunnel = float(ceili(track.km_to_z(float(t["start_km"])) / track.seg_len - 1.0e-6)) * track.seg_len
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


## One node for the tube's shader behind the loading picture (only on stages with tunnels).
func warmup_nodes() -> Array:
	if not _has_tunnels:
		return []
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	mi.mesh = q
	mi.material_override = tube_material()
	return [mi]


func debug(part: Dictionary) -> Dictionary:
	return {"segments": int(part.get("segments", 0)), "portals": int(part.get("portals", 0)), "caps": int(part.get("caps", 0)),
		"niches": int(part.get("niches", 0)), "lamps": (part.get("lamps", []) as Array).size(),
		"tube_triangles": int(part.get("tube_triangles", 0)), "portal_triangles": int(part.get("portal_triangles", 0))}
