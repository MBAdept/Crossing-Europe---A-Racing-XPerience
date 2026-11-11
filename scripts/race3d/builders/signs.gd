extends ChunkBuilder
## Builder "signs" of the mode "Modern" (contract §6 R3; docs/renderer-modern.md §10): every road sign of a chunk
## (TrackSegment.sprites with kind "sign"; side 0 – the start and finish gantries – is the gantry builder's) as real
## geometry in the cross-section plane of the road, facing the traffic:
##  * the board(s) are a quad textured from the stage's sign atlas (SignAtlas: Arcade's SignPainter drew every sign
##    of the stage once in prepare(), so a sign looks exactly like its Arcade counterpart, lettering included);
##    their outline comes from the atlas' alpha, the back is bare metal;
##  * the posts stand where SignPainter draws them (measured from its own geometry), a little behind the board,
##    down into the ground beside the road (ChunkContext.ground); wall-mounted signs (tunnels, "wall") have none;
##  * the board sits at Arcade's height above the road level of its cross-section, scaled like Arcade ("scale");
##  * one mesh per chunk for all its signs (assets/shaders/modern/sign.gdshader, one draw call): path-distance fade
##    of Arcade (F5) in the shader, retro-reflection in the headlight cone, shadows when the quality levels have
##    structure casters.
## prepare() starts the atlas (prepare_pending() > 0 until it is drawn and read back); nothing is created during the
## drive. A sign that is not in the atlas (it cannot happen for the kinds Track knows) is drawn as a plain board in
## its main colour and counted (SignAtlas.missing).
## Owner: R3.

const POST_GAP_M := 0.05            ## posts stand this far behind the board
const POST_SINK_M := 0.3            ## … and reach this far into the ground

var _renderer: Node
var _mats: ModernMaterials
var _atlas := SignAtlas.new()
var _mat: ShaderMaterial
var _cast := false
var _fog_frac := 0.45
var _tunnel_fog_m := 260.0
var _hl_range := 80.0
var _prepared := false
var _committed: Dictionary = {}     ## parent instance id -> [parent, [{kind, z, x}]] (main thread, snapshots)


func id() -> String:
	return "signs"


func setup(renderer: Node) -> void:
	_renderer = renderer
	_mats = renderer.get("materials") as ModernMaterials if renderer != null else null
	if _mats == null:
		_mats = ModernMaterials.shared()
	var cfg: Variant = renderer.get("cfg") if renderer != null else {}
	if cfg is Dictionary:
		_fog_frac = float(ConfigLoader.lookup(cfg, "render.fog_start_frac", 0.45))
		_tunnel_fog_m = float(ConfigLoader.lookup(cfg, "render.tunnel.darkness_m", 260.0))
		_hl_range = float(ConfigLoader.lookup(cfg, "render.headlight_range_m", 80.0))


func apply_quality(levels: Dictionary) -> void:
	_cast = int(levels.get("shadow_casters", 0)) >= 1


## Draws the atlas of every sign the stage can show (behind the loading overlay).
func prepare(ctx: Dictionary) -> void:
	SignAtlas.driving = false
	var track: Track = _renderer.get("track") if _renderer != null else null
	var plan: Variant = ctx.get("plan", null)
	var items := SignAtlas.stage_signs(track, plan as StagePlan if plan is StagePlan else null)
	_atlas.prepare(items, _renderer, _countries())
	_mat = ShaderMaterial.new()
	_mat.shader = _mats.shader("sign")
	_mat.set_shader_parameter(&"fog_frac", _fog_frac)
	_mat.set_shader_parameter(&"tunnel_fog_m", _tunnel_fog_m)
	_mat.set_shader_parameter(&"hl_range", _hl_range)
	if _atlas.ready:
		_mat.set_shader_parameter(&"atlas", _atlas.texture)


func prepare_pending() -> int:
	var n := _atlas.pending()
	if n == 0 and not _prepared and _atlas.ready:
		_prepared = true
		_mat.set_shader_parameter(&"atlas", _atlas.texture)
	return n


## The atlas of this stage (tests and the warm-up).
func atlas() -> SignAtlas:
	return _atlas


func warmup_nodes() -> Array:
	if _mat == null:
		return []
	# one board and one post: the shader's variant (with the atlas) is compiled behind the loading cover
	var data := _sign_arrays([{"z": 0.0, "x": 0.0, "scale": 1.0, "wall": false, "tunnel": false,
		"bounds": Rect2(-0.5, 1.8, 1.0, 1.0), "uv": Rect2(0.0, 0.0, 0.1, 0.1), "posts": [Vector3(0.0, 0.1, 2.3)], "colour": Color.GRAY}],
		null)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(data)
	mi.material_override = _mat
	return [mi]


## Every frame: the camera's road position and the sight for the path-distance fade of the shader.
func update(view: Dictionary, _dt: float) -> void:
	SignAtlas.driving = true
	if _mat == null:
		return
	_mat.set_shader_parameter(&"cam_z", float(view.get("camera_z", 0.0)))
	_mat.set_shader_parameter(&"visibility", float(view.get("visibility_m", 900.0)))


## Main thread: the signs of the chunk with their atlas cells (plain data for build()).
func collect(ctx: ChunkContext) -> Variant:
	var out: Array = []
	for q in range(0, ctx.segs.size() - 1):
		var seg: Dictionary = ctx.segs[q]
		for sp: Variant in seg.get("sprites", []):
			var it: Dictionary = sp
			if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) == 0:
				continue
			var e := _atlas.entry(it)
			var wall := bool(it.get("wall", false))
			var rec := {"kind": str(it.get("sign", "")), "z": float(it.get("z", seg.get("z", 0.0))), "x": float(it.get("x", 0.0)),
				"scale": float(it.get("scale", 1.0)), "wall": wall, "tunnel": bool(seg.get("tunnel", false))}
			if e.is_empty():
				# not in the atlas: a plain board of Arcade's width
				var hw := SignPainter.board_half_width(str(it.get("sign", "")))
				rec["bounds"] = Rect2(-hw, 2.0, hw * 2.0, 1.4)
				rec["uv"] = Rect2()
				rec["posts"] = [] if wall else [Vector3(0.0, 0.11, 2.6)]
				rec["colour"] = Color(0.85, 0.85, 0.85)
			else:
				rec["bounds"] = e["bounds"]
				rec["uv"] = e["uv"]
				rec["posts"] = [] if wall else e["posts"]
				rec["colour"] = e["colour"]
			out.append(rec)
	return out


## WORKER THREAD: the arrays of the chunk's sign mesh (boards and posts, chunk-local).
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var signs: Array = input if input is Array else []
	if signs.is_empty():
		return {"signs": []}
	var data := _sign_arrays(signs, ctx)
	data["signs"] = signs
	return data


## Arrays of the mesh: for every sign its board quad (atlas UVs) and a box per post. ctx = null: positions in the
## sign's own frame (warm-up).
static func _sign_arrays(signs: Array, ctx: ChunkContext) -> Dictionary:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for s: Dictionary in signs:
		var z := float(s["z"])
		var x := float(s["x"])
		var sc := float(s["scale"])
		var fr := ctx.frame(z, x, 0.0) if ctx != null else Transform3D.IDENTITY
		var b: Rect2 = s["bounds"]
		var u: Rect2 = s["uv"]
		var tag := Vector2(z, 1.0 if bool(s["tunnel"]) else 0.0)
		var board_col := Color(1.0, 1.0, 1.0, 1.0)
		if u.size.x <= 0.0:
			board_col = Color(s["colour"], 0.0)          # no atlas cell: a plain board in its colour
		var x0 := b.position.x * sc
		var x1 := b.end.x * sc
		var y0 := b.position.y * sc
		var y1 := b.end.y * sc
		var nrm := fr.basis.z.normalized()                  # +Z of the frame looks back along the road, at the traffic
		var base := v.size()
		for p: Vector3 in [Vector3(x0, y0, 0.0), Vector3(x0, y1, 0.0), Vector3(x1, y1, 0.0), Vector3(x1, y0, 0.0)]:
			v.append(fr * p)
			n.append(nrm)
			c.append(board_col)
			uv2.append(tag)
		uv.append(Vector2(u.position.x, u.end.y))
		uv.append(Vector2(u.position.x, u.position.y))
		uv.append(Vector2(u.end.x, u.position.y))
		uv.append(Vector2(u.end.x, u.end.y))
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		# posts: boxes behind the board, from the ground (or a little below the road) up to their top
		for pv: Variant in s["posts"]:
			var post: Vector3 = pv
			var px := post.x * sc
			var hw := maxf(post.y * sc, 0.06) * 0.5
			var top := post.z * sc
			var g := ctx.ground(z, x + px) if ctx != null else 0.0
			var bottom := minf(g, 0.0) - POST_SINK_M
			_post_box(fr, px, hw, bottom, top, -POST_GAP_M - hw, v, n, c, uv, uv2, idx, tag)
	return {"v": v, "n": n, "c": c, "uv": uv, "uv2": uv2, "idx": idx}


static func _post_box(fr: Transform3D, px: float, hw: float, y0: float, y1: float, zc: float, v: PackedVector3Array,
		n: PackedVector3Array, c: PackedColorArray, uv: PackedVector2Array, uv2: PackedVector2Array, idx: PackedInt32Array,
		tag: Vector2) -> void:
	var col := Color(SignPainter.POST, 0.0)
	var xa := px - hw
	var xb := px + hw
	var za := zc - hw
	var zb := zc + hw
	# four sides and the top; corners counter-clockwise seen from outside
	var faces := [
		[Vector3(xa, y0, zb), Vector3(xb, y0, zb), Vector3(xb, y1, zb), Vector3(xa, y1, zb), Vector3(0, 0, 1)],
		[Vector3(xb, y0, za), Vector3(xa, y0, za), Vector3(xa, y1, za), Vector3(xb, y1, za), Vector3(0, 0, -1)],
		[Vector3(xb, y0, zb), Vector3(xb, y0, za), Vector3(xb, y1, za), Vector3(xb, y1, zb), Vector3(1, 0, 0)],
		[Vector3(xa, y0, za), Vector3(xa, y0, zb), Vector3(xa, y1, zb), Vector3(xa, y1, za), Vector3(-1, 0, 0)],
		[Vector3(xa, y1, zb), Vector3(xb, y1, zb), Vector3(xb, y1, za), Vector3(xa, y1, za), Vector3(0, 1, 0)]]
	for f: Array in faces:
		var base := v.size()
		var nn := (fr.basis * (f[4] as Vector3)).normalized()
		for i in 4:
			v.append(fr * (f[i] as Vector3))
			n.append(nn)
			c.append(col)
			uv.append(Vector2.ZERO)
			uv2.append(tag)
		idx.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func commit(_ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var signs: Array = part.get("signs", [])
	if signs.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.name = "Signs"
	mi.mesh = _mesh(part)
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var list: Array = []
	for s: Dictionary in signs:
		list.append({"kind": str(s["kind"]), "z": float(s["z"]), "x": float(s["x"]), "wall": bool(s["wall"])})
	_committed[parent.get_instance_id()] = [parent, list]


static func _mesh(d: Dictionary) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = d["v"]
	arr[Mesh.ARRAY_NORMAL] = d["n"]
	arr[Mesh.ARRAY_COLOR] = d["c"]
	arr[Mesh.ARRAY_TEX_UV] = d["uv"]
	arr[Mesh.ARRAY_TEX_UV2] = d["uv2"]
	arr[Mesh.ARRAY_INDEX] = d["idx"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func debug(part: Dictionary) -> Dictionary:
	var kinds: Array = []
	for s: Dictionary in part.get("signs", []):
		kinds.append(str(s["kind"]))
	return {"signs": kinds.size(), "kinds": kinds}


## Contract §4.4.5: signs [{kind, z, x}] of the chunks that are in the scene now.
func snapshot() -> Dictionary:
	var out: Array = []
	for k: Variant in _committed.keys():
		var e: Array = _committed[k]
		var p: Variant = e[0]
		if not is_instance_valid(p) or not (p as Node).is_inside_tree():
			_committed.erase(k)
			continue
		out.append_array(e[1])
	return {"signs": out, "sign_atlas": {"cells": _atlas.entries.size(), "size": [_atlas.size.x, _atlas.size.y],
		"placeholder": _atlas.placeholder, "missing": _atlas.missing}}


func perf() -> Dictionary:
	return {"sign_cells": _atlas.entries.size(), "signs_missing": _atlas.missing}


func _countries() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var gd: Node = tree.root.get_node_or_null("GameData") if tree != null and tree.root != null else null
	if gd == null:
		return {}
	var c: Variant = gd.get("countries")
	return c if c is Dictionary else {}
