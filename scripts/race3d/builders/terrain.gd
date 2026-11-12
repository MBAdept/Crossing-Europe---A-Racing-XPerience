extends ChunkBuilder
## Mode "Modern" (v0.8.0): the terrain of a road chunk – the ruled ribbon of the TerrainProfile beside the road as one
## mesh per chunk (contract D16, §4.5.5; German docs: docs/renderer-modern-gelaende.md).
##
## Geometry (everything from the ChunkContext snapshot: ring distances and heights per row and side):
##  * a grid of rows x rings per side, shared vertices and smooth normals – the verge and ditch profile, the mild
##    relief outside the sight corridor and the fall to the valley floor are the kernel's numbers
##    (ChunkContext.ring_x / ring_h), so props standing on ChunkContext.ground() stand on this mesh;
##  * the valley-floor edge: below the outer ring a vertical skirt of SKIRT_M. It has no area in plan view; it closes
##    the ribbon towards the far ground where that lies lower, the walls of the 12 m gap at a medial axis and of the
##    hole at the centre of a tight bend (the far-ground plane covers both where it lies above them);
##  * nothing inside tunnels (the tunnel builder closes portal and mound); on a bridge the rings lie on the water.
## 768 + 128 = 896 triangles per chunk of 32 segments with 7 rings (budget: 1,100).
## Colours (per vertex, painted over by assets/shaders/modern/terrain.gdshader): the mean of the scenery's two grass
## tones with the outskirts -> centre blend of the City Limits (GroundLook.ground_blend), half their difference and
## how much of it shows (Arcade's alternating bands: full near the road, gone from BAND_FADE_TO_M on; the shader draws
## the bands with sharp edges from the band phase in UV.y – band_tone() repeats its arithmetic), the style of the
## scenery (patch colour and share, vegetation or paved ground: GroundLook.style) and the fade of the outer ring into
## the far ground.
## One shared ShaderMaterial for every chunk; it is registered for the light pools (ModernRenderer.add_pool_material)
## and follows the far ground and the floating origin in update() / rebased(). Like the road the mesh is on render
## layer 2 (GROUND_LAYERS): the real spot and omni lights of the lights layer leave the ground out, the shader draws
## the player's low beam and the lamp and traffic pools analytically (inc/headlight.gdshaderinc, inc/pools.gdshaderinc).
## build() runs on worker threads: it reads the ctx snapshot arrays and the plain input of collect() only.
## Owner: package terrain / props / far ground.

const SHADER := "res://assets/shaders/modern/terrain.gdshader"
const SKIRT_M := 60.0              ## depth of the skirt below the outer edge
const BAND_FADE_FROM_M := 6.0      ## the two grass tones alternate up to here beyond the shoulder …
const BAND_FADE_TO_M := 40.0       ## … and have become their mean here
const CITY_BAND_SHARE := 0.35      ## inside the City Limits the bands keep this much of their contrast
const WATER_STYLE := -1.0          ## CUSTOM0.a of a vertex on the water
const GROUND_LAYERS := 2           ## render layer of ground meshes (builders/road.gd): no positional light reaches it
## R4: snow banks – on a snow stage the ploughed snow lies in a low ridge along the outer edge of the shoulders (part
## of this mesh, same material: the ground law lights it like the snow ground). At most BANK_MAX_M high, so it can
## never hide a car from the 3.4 m eye (the ground-cover rule of A-3, 0.5 m) and the terrain profile of the fairness
## tests stays untouched. Not on bridges, in tunnels, in the City Limits or beside a fuel lane; tapered over
## BANK_TAPER rows where it ends. Profile across (m from the shoulder edge, share of the height).
const BANK_H_M := 0.3
const BANK_MAX_M := 0.45
const BANK_TAPER := 3
const BANK_PROFILE: Array[Vector2] = [Vector2(-0.3, 0.0), Vector2(0.25, 0.6), Vector2(0.75, 1.0), Vector2(1.6, -0.12)]
## UV.x of the bank's profile points: the foot on the shoulder lies on the "gravel strip" of the shader (thin, dirty
## snow: the grey plough edge that draws the bank against the white ground), the crest and the back full snow
const BANK_LAT: Array[float] = [0.15, 0.9, 2.6, 2.6]

var material: ShaderMaterial       ## the one terrain material (null until the first commit)
var far_look: Dictionary = {}      ## GroundLook.far_look() of the last update()

var _renderer: Node                ## untyped: packages talk to each other through the facade only
var _pattern_origin := Vector3.ZERO
var _cast := false
var _city: Dictionary = {}         ## GroundLook.city_info of the stage (first update())
var _styles: Dictionary = {}       ## graphics.modern.terrain.styles


func id() -> String:
	return "terrain"


func setup(renderer: Node) -> void:
	_renderer = renderer


## Main thread: what build() needs beyond the snapshot – the city of the stage (ground blend), the width of the grass
## bands and the style overrides of the configuration. Plain data.
func collect(ctx: ChunkContext) -> Variant:
	var styles: Variant = ConfigLoader.lookup(ctx.cfg, "graphics.modern.terrain.styles", {})
	# FIX1 (QA QB-03: dark water under the Köhlbrand bridge): Arcade's water colour of a bridge (RoadRenderer.
	# _water_base, frozen) – the bridge's own "water", else the scenery's, else the default of its type
	var waters := {}
	for seg: Dictionary in ctx.segs:
		if not bool(seg["water"]):
			continue
		var bi := int(seg["bridge_i"])
		var key := "%d|%s" % [bi, str(seg["scenery"])]
		if waters.has(key):
			continue
		var c := ""
		if ctx.track != null and bi >= 0 and bi < ctx.track.bridges.size():
			c = str(ctx.track.bridges[bi].get("water", ""))
		if c == "":
			c = str(_dict(ctx.scenery_db.get(str(seg["scenery"]))).get("water", ""))
		if c == "":
			c = str(CityData.WATER_COLOR.get(str(seg["bridge"]), "#4b6878"))
		waters[key] = Color(c)
	var snow := false
	var renderer: Variant = ctx.services.get("renderer")
	if renderer is Object:
		var prep: Variant = (renderer as Object).get("prep")
		snow = prep is Dictionary and str((prep as Dictionary).get("weather", "")) == "snow"
	return {"city": GroundLook.city_info(ctx.track),
		"band": maxi(1, int(ConfigLoader.lookup(ctx.cfg, "render.stripes.grass", 4))),
		"styles": styles if styles is Dictionary else {}, "waters": waters, "snow": snow}


func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var rows := ctx.row_count()
	var n := ctx.rings
	if rows < 2 or n < 2:
		return {}
	var inp: Dictionary = input if input is Dictionary else {}
	var city: Dictionary = inp.get("city", {})
	var band_w := int(inp.get("band", 4))
	var overrides: Dictionary = inp.get("styles", {})
	var waters: Dictionary = inp.get("waters", {})
	var per_side := rows * n
	var grid := per_side * 2
	var count := grid + rows * 4            # + skirt: top and bottom vertex per row and side
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var custom := PackedFloat32Array()
	var bands := PackedFloat32Array()
	verts.resize(count)
	norms.resize(count)
	cols.resize(count)
	uvs.resize(count)
	uv2s.resize(count)
	custom.resize(count * 4)
	bands.resize(count * 4)
	# band phase = segment index / band width, counted from an even number of bands before the chunk (small numbers,
	# the parity of floor() is Arcade's band of the segment)
	var phase_base := (ctx.seg_a / (2 * band_w)) * (2 * band_w)
	var tunnel_rows := PackedByteArray()
	tunnel_rows.resize(rows)
	var water_rows := 0
	var styles := {}                        # scenery id -> [g0, g1, style] (few per chunk)
	for i in rows:
		var seg: Dictionary = ctx.segs[i]
		var z := float(ctx.seg_a + i) * ctx.seg_len
		var scen_id := str(seg["scenery"])
		var is_city := bool(seg["city"])
		var water := bool(seg["water"])
		tunnel_rows[i] = 1 if bool(seg["tunnel"]) else 0
		var cached: Variant = styles.get(scen_id)
		if cached == null:
			var scen: Dictionary = _dict(ctx.scenery_db.get(scen_id))
			cached = [GroundLook.grass(scen, 0), GroundLook.grass(scen, 1), GroundLook.water(scen)]
			styles[scen_id] = cached
		var g0: Color = cached[0]
		var g1: Color = cached[1]
		var mean := g0.lerp(g1, 0.5)
		var half := Color((g0.r - g1.r) * 0.5, (g0.g - g1.g) * 0.5, (g0.b - g1.b) * 0.5)
		var st := GroundLook.style_at(scen_id, is_city, z, ctx.scenery_db, city, overrides)
		var blended := GroundLook.ground_tone(scen_id, is_city, z, ctx.scenery_db, city)
		if blended != mean:
			# City Limits: the centre's ground comes in, the bands keep a part of their contrast
			mean = blended
			half = Color(half.r * CITY_BAND_SHARE, half.g * CITY_BAND_SHARE, half.b * CITY_BAND_SHARE)
		var accent: Color = st["accent"]
		var amount := float(st["amount"])
		var nature := float(st["nature"])
		if water:
			water_rows += 1
			mean = waters.get("%d|%s" % [int(seg["bridge_i"]), scen_id], cached[2])
			half = Color(0.0, 0.0, 0.0)
			amount = WATER_STYLE
			nature = 0.0
		var phase := float(ctx.seg_a + i - phase_base) / float(band_w)
		var o := ctx.rows_o[i]
		var right := ctx.rows_r[i]
		var edge := ctx.rows_edge[i]
		for si in 2:
			var side := -1.0 if si == 0 else 1.0
			var base := (-edge.x if si == 0 else edge.y) + ctx.shoulder_w
			var ro := (i * 2 + si) * n
			var vo := si * per_side + i * n
			for r in n:
				var m := ctx.ring_x[ro + r]
				var x := side * (base + m)
				var v := vo + r
				verts[v] = o + right * x + Vector3(0.0, ctx.ring_h[ro + r], 0.0)
				cols[v] = Color(mean.r, mean.g, mean.b, nature)
				uvs[v] = Vector2(m, phase)
				uv2s[v] = Vector2(x, 1.0 if r == n - 1 else 0.0)
				custom[v * 4] = accent.r
				custom[v * 4 + 1] = accent.g
				custom[v * 4 + 2] = accent.b
				custom[v * 4 + 3] = amount
				bands[v * 4] = half.r
				bands[v * 4 + 1] = half.g
				bands[v * 4 + 2] = half.b
				bands[v * 4 + 3] = 1.0 - smoothstep(BAND_FADE_FROM_M, BAND_FADE_TO_M, m)
	# smooth normals from the neighbours in the grid (one-sided at the ends of the chunk and of the ribbon)
	for si in 2:
		for i in rows:
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, rows - 1)
			for r in n:
				var r0 := maxi(r - 1, 0)
				var r1 := mini(r + 1, n - 1)
				var across := verts[si * per_side + i * n + r1] - verts[si * per_side + i * n + r0]
				var along := verts[si * per_side + i1 * n + r] - verts[si * per_side + i0 * n + r]
				var nrm := along.cross(across) if si == 0 else across.cross(along)
				norms[si * per_side + i * n + r] = nrm.normalized() if nrm.length_squared() > 1.0e-12 else Vector3.UP
	# skirt below the outer edge: its own vertices (the normal points away from the road)
	for si in 2:
		var side := -1.0 if si == 0 else 1.0
		for i in rows:
			var src := si * per_side + i * n + n - 1
			var top := grid + (si * rows + i) * 2
			var out_n := ctx.rows_r[i] * side
			for q in 2:
				var v := top + q
				verts[v] = verts[src] - Vector3(0.0, SKIRT_M * float(q), 0.0)
				norms[v] = out_n
				cols[v] = cols[src]
				uvs[v] = uvs[src]
				uv2s[v] = Vector2(uv2s[src].x, 1.0)
				for q4 in 4:
					custom[v * 4 + q4] = custom[src * 4 + q4]
					bands[v * 4 + q4] = bands[src * 4 + q4]
	# triangles: clockwise seen from the lit side
	var idx := PackedInt32Array()
	var quads := 0
	for i in rows - 1:
		if tunnel_rows[i] == 1:
			continue
		for si in 2:
			var vo := si * per_side
			for r in n - 1:
				var a := vo + i * n + r
				var b := a + 1
				var d := vo + (i + 1) * n + r
				var c := d + 1
				if si == 1:
					idx.append_array(PackedInt32Array([a, d, c, a, c, b]))
				else:
					idx.append_array(PackedInt32Array([a, b, c, a, c, d]))
				quads += 1
			var t0 := grid + (si * rows + i) * 2
			var t1 := t0 + 2
			if si == 1:
				idx.append_array(PackedInt32Array([t0, t1, t1 + 1, t0, t1 + 1, t0 + 1]))
			else:
				idx.append_array(PackedInt32Array([t0, t1 + 1, t1, t0, t0 + 1, t1 + 1]))
	var bank_tris := 0
	if bool(inp.get("snow", false)):
		bank_tris = _snow_banks(ctx, verts, norms, cols, uvs, uv2s, custom, bands, idx, n, per_side)
	var box := AABB()
	if verts.size() > 0:
		box = AABB(verts[0], Vector3.ZERO)
		for v in verts:
			box = box.expand(v)
	return {"verts": verts, "normals": norms, "colors": cols, "uv": uvs, "uv2": uv2s, "custom": custom, "bands": bands,
		"indices": idx, "aabb": box, "rings": n, "rows": rows, "quads": quads, "water_rows": water_rows, "bank_tris": bank_tris}


## R4: whether row i of a chunk may carry a snow bank (open road beside open ground).
static func bank_row(seg: Dictionary) -> bool:
	return not (bool(seg["tunnel"]) or bool(seg["water"]) or bool(seg.get("bank", false)) or bool(seg["city"])
		or int(seg.get("fuel_zone", 0)) != 0 or float(seg.get("fuel_lane", 0.0)) > 0.0 or str(seg.get("cover", "")) != "")


## R4: height of the snow bank at segment index k (m): BANK_H_M with a slow variation along the road, never above
## BANK_MAX_M. A function of the segment index alone – the bank continues across chunk borders.
static func bank_height(k: int) -> float:
	var t := float(k) * 0.11
	var v := 0.75 + 0.3 * sin(t) * sin(t * 0.37 + 1.3) + 0.12 * sin(float(k) * 0.93 + 0.4)
	return clampf(BANK_H_M * v, 0.0, BANK_MAX_M)


## R4: appends the snow banks of both sides to the arrays of the ribbon (worker thread, snapshot only); returns the
## number of triangles. The banks lie on the ground of the first two rings (linear between them) and copy the style
## of the ring at the shoulder edge.
static func _snow_banks(ctx: ChunkContext, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		uvs: PackedVector2Array, uv2s: PackedVector2Array, custom: PackedFloat32Array, bands: PackedFloat32Array,
		idx: PackedInt32Array, n: int, per_side: int) -> int:
	var rows := ctx.row_count()
	var np := BANK_PROFILE.size()
	# where a bank may stand, and how far each row is from the nearest row without one (taper)
	var ok := PackedInt32Array()
	ok.resize(rows)
	for i in rows:
		ok[i] = 1 if bank_row(ctx.segs[i]) else 0
	var reach := PackedFloat32Array()
	reach.resize(rows)
	for i in rows:
		var d := BANK_TAPER
		for j in range(maxi(0, i - BANK_TAPER), mini(rows, i + BANK_TAPER + 1)):
			if ok[j] == 0:
				d = mini(d, absi(j - i))
		reach[i] = float(d) / float(BANK_TAPER)
	var first := verts.size()
	verts.resize(first + rows * 2 * np)
	norms.resize(verts.size())
	cols.resize(verts.size())
	uvs.resize(verts.size())
	uv2s.resize(verts.size())
	custom.resize(verts.size() * 4)
	bands.resize(verts.size() * 4)
	for si in 2:
		var side := -1.0 if si == 0 else 1.0
		for i in rows:
			var o := ctx.rows_o[i]
			var right := ctx.rows_r[i]
			var edge := ctx.rows_edge[i]
			var base := (-edge.x if si == 0 else edge.y) + ctx.shoulder_w
			var ro := (i * 2 + si) * n
			var src := si * per_side + i * n          # the ring vertex at the shoulder edge: style and colour
			var h := bank_height(ctx.seg_a + i) * reach[i]
			var x1 := maxf(ctx.ring_x[ro + 1] - ctx.ring_x[ro], 0.5)
			for q in np:
				var pr: Vector2 = BANK_PROFILE[q]
				var m := pr.x
				var g := ctx.ring_h[ro] + (ctx.ring_h[ro + 1] - ctx.ring_h[ro]) * clampf(m / x1, 0.0, 1.0)
				var lift := h * pr.y if pr.y > 0.0 else pr.y * maxf(h, 0.05)
				if q == 0:
					lift = 0.025                     # on the shoulder: just above the road
				var x := side * (base + ctx.ring_x[ro] + m)
				var v := first + (si * rows + i) * np + q
				verts[v] = o + right * x + Vector3(0.0, g + lift, 0.0)
				cols[v] = cols[src]
				uvs[v] = Vector2(BANK_LAT[q], uvs[src].y)
				uv2s[v] = Vector2(x, 0.0)
				for c4 in 4:
					custom[v * 4 + c4] = custom[src * 4 + c4]
					bands[v * 4 + c4] = bands[src * 4 + c4]
	# normals from the profile and the rows
	for si in 2:
		for i in rows:
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, rows - 1)
			for q in np:
				var q0 := maxi(q - 1, 0)
				var q1 := mini(q + 1, np - 1)
				var row := first + (si * rows + i) * np
				var across := verts[row + q1] - verts[row + q0]
				var along := verts[first + (si * rows + i1) * np + q] - verts[first + (si * rows + i0) * np + q]
				var nrm := along.cross(across) if si == 0 else across.cross(along)
				norms[row + q] = nrm.normalized() if nrm.length_squared() > 1.0e-12 else Vector3.UP
	var tris := 0
	for i in rows - 1:
		if ok[i] == 0 or ok[i + 1] == 0:
			continue
		for si in 2:
			for q in np - 1:
				var a := first + (si * rows + i) * np + q
				var b := a + 1
				var d := first + (si * rows + i + 1) * np + q
				var c := d + 1
				if si == 1:
					idx.append_array(PackedInt32Array([a, d, c, a, c, b]))
				else:
					idx.append_array(PackedInt32Array([a, b, c, a, c, d]))
				tris += 2
	return tris


## The ground tone the shader starts from at vertex v of a built part (before its patterns): Arcade's band tone near
## the road (tone 0 on an even band phase, tone 1 on an odd one), fading into the mean – terrain.gdshader's arithmetic
## at the vertex (tests, top views).
static func band_tone(part: Dictionary, v: int) -> Color:
	var c: Color = (part["colors"] as PackedColorArray)[v]
	var b: PackedFloat32Array = part["bands"]
	var phase := float((part["uv"] as PackedVector2Array)[v].y)
	var s := 1.0 if posmod(int(floor(phase + 1.0e-4)), 2) == 0 else -1.0
	var k := b[v * 4 + 3] * s
	return Color(c.r + b[v * 4] * k, c.g + b[v * 4 + 1] * k, c.b + b[v * 4 + 2] * k, c.a)


func commit(_ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var idx: PackedInt32Array = part.get("indices", PackedInt32Array())
	if idx.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh_of(part)
	mi.material_override = ground_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = GROUND_LAYERS
	parent.add_child(mi)


## The mesh of a built part (also for tests and top views).
static func mesh_of(part: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = part["verts"]
	arrays[Mesh.ARRAY_NORMAL] = part["normals"]
	arrays[Mesh.ARRAY_COLOR] = part["colors"]
	arrays[Mesh.ARRAY_TEX_UV] = part["uv"]
	arrays[Mesh.ARRAY_TEX_UV2] = part["uv2"]
	arrays[Mesh.ARRAY_CUSTOM0] = part["custom"]
	arrays[Mesh.ARRAY_CUSTOM1] = part["bands"]
	arrays[Mesh.ARRAY_INDEX] = part["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
	return mesh


## The one terrain material (created on first use, main thread). Registered for the light pools when a renderer is
## there.
func ground_material() -> ShaderMaterial:
	if material != null:
		return material
	ModernMaterials.ensure_globals()
	material = ShaderMaterial.new()
	material.shader = load(SHADER) as Shader
	material.set_shader_parameter("ground_noise", GroundLook.noise_texture())
	material.set_shader_parameter("pattern_origin", _pattern_origin)
	if not far_look.is_empty():
		_apply_far()
	if _renderer != null and _renderer.has_method(&"add_pool_material"):
		_renderer.call(&"add_pool_material", material)
	return material


## Hook of the renderer, once per stage: the terrain casts no shadow of its own (the relief is mild; it would cost a
## draw call per chunk and split). Kept as a switch for the mountain stages.
func apply_quality(levels: Dictionary) -> void:
	_cast = bool(levels.get("terrain_shadows", false))


## Hook of the renderer (every frame): the outer ring fades into the far ground of this frame.
func update(view: Dictionary, _dt: float) -> void:
	if _renderer == null:
		return
	var track: Track = _renderer.get("track")
	if track == null:
		return
	if _city.is_empty():
		_city = GroundLook.city_info(track)
		var cfg: Variant = _renderer.get("cfg")
		var styles: Variant = ConfigLoader.lookup(cfg, "graphics.modern.terrain.styles", {}) if cfg is Dictionary else {}
		_styles = styles if styles is Dictionary else {}
	var look := GroundLook.far_look(track, _renderer.get("scenery_db"), float(view.get("camera_z", 0.0)), _city, _styles)
	if look != far_look:
		far_look = look
		if material != null:
			_apply_far()


func _apply_far() -> void:
	var c: Color = far_look.get("color", Color(0.36, 0.58, 0.25))
	var a: Color = far_look.get("accent", Color(0.71, 0.68, 0.3))
	material.set_shader_parameter("far_color", Vector3(c.r, c.g, c.b))
	material.set_shader_parameter("far_accent", Vector3(a.r, a.g, a.b))
	material.set_shader_parameter("far_amount", float(far_look.get("amount", 0.4)))
	material.set_shader_parameter("far_nature", float(far_look.get("nature", 1.0)))


## Hook of the renderer: the floating origin moved – the pattern stays where it is on the ground.
func rebased(shift: Vector3) -> void:
	_pattern_origin -= shift
	if material != null:
		material.set_shader_parameter("pattern_origin", _pattern_origin)


## Offset of the ground pattern against origin-relative world positions (the far-ground layer shows the same).
func pattern_origin() -> Vector3:
	return _pattern_origin


## Hook of the renderer: one small patch with the terrain material, so its shader is compiled behind the loading cover.
func warmup_nodes() -> Array:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.0, 4.0)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = ground_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = GROUND_LAYERS
	return [mi]


func debug(part: Dictionary) -> Dictionary:
	var verts: PackedVector3Array = part.get("verts", PackedVector3Array())
	var idx: PackedInt32Array = part.get("indices", PackedInt32Array())
	var box: AABB = part.get("aabb", AABB())
	var q := PackedInt32Array()
	q.resize(verts.size() * 3)
	for i in verts.size():
		var v := verts[i]
		q[i * 3] = int(round(v.x * 1000.0))
		q[i * 3 + 1] = int(round(v.y * 1000.0))
		q[i * 3 + 2] = int(round(v.z * 1000.0))
	return {"vertices": verts.size(), "triangles": idx.size() / 3, "quads": int(part.get("quads", 0)), "bank_tris": int(part.get("bank_tris", 0)),
		"rings": int(part.get("rings", 0)), "water_rows": int(part.get("water_rows", 0)), "checksum": hash(q),
		"aabb": [snappedf(box.position.x, 0.001), snappedf(box.position.y, 0.001), snappedf(box.position.z, 0.001),
			snappedf(box.size.x, 0.001), snappedf(box.size.y, 0.001), snappedf(box.size.z, 0.001)]}


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
