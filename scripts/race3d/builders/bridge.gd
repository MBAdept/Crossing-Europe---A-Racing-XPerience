extends ChunkBuilder
## Bridge builder of the mode "Modern" (v0.8.0, package R5 – contract §6 wave 3 "Tunnel und Brücken", renderer
## inventory B, amendment A-16; German docs: docs/renderer-modern-tunnel-bruecken.md). Everything that is built at the
## water of a bridge (Track.bridges: its segments carry TrackSegment.water / water_level / bridge_i):
##  * the WATER beside and under the deck (assets/shaders/modern/water.gdshader, ModernMaterials class "water"):
##    WATER_LIFT above the water rows of the terrain ribbon (they stay there, covered), out to the ribbon's last ring,
##    in Arcade's colour of the bridge (bridge "water", else the scenery's, else CityData.WATER_COLOR) with ripples,
##    the mirrored sky and glitter; the river beyond the ribbons and its far banks are drawn by layers/far_ground.gd;
##  * the BANKS at both ends – Arcade (RoadRenderer._draw_water) paints the rows of the bank slope (water_level rising
##    from -depth to 0) in its QUAY colour or the bridge's "bank" colour, the terrain of Modern painted them as water
##    ("water fading into a green bank" at the end of the Köhlbrandbrücke, the Kiel Canal like a lake):
##      wall        where the slope is one segment (Track._build_bridge: low bridges without a bank colour): a vertical
##                  quay wall of cut stone (brick at canals) where the terrain reaches the water, coping stones on
##                  it and a paved top over the slope behind it;
##      embankment  elsewhere: a surface on the terrain's slope rows – grass in the bridge's bank colour with rip-rap at
##                  the waterline (Holtenauer Hochbrücke, Bern, Timișoara), cut stone in the quay colour without one
##                  (Köhlbrandbrücke);
##  * the STRUCTURE (material class vpbr, static): edge beams and the underside of the deck; piers with cutwaters under
##    girder bridges (river, truss, cable-stayed); stone, brick and causeway bridges stand on arches (spandrel walls,
##    arch barrels, piers with cutwaters); the side girders of truss bridges (Arcade's chords, verticals and
##    alternating diagonals every TRUSS_PANEL metres, RoadRenderer._truss_girder); under each pylon its foundation
##    pier and a cross beam under the deck; the stay cables;
##  * the PARTS Track places on the deck (items with a "bridge" key – builders/props.gd leaves them to this builder as
##    soon as it exists: its skip_bridge, no line of props.gd changed): the pylons of cable-stayed bridges as
##    props/bridge_pylon_bare scaled in height to the bridge's pylon_m (A-16: height_m / 88.8) with a cap and a beacon
##    mast, their stay cables per bridge as Arcade draws them (RoadRenderer._pylon: 7 to each side, span = the item's
##    "cables", from 0.95 … 0.65 of the height down to the deck edge 1.4 m inside the pylon and 1.1 m up – never over a
##    lane), the pylon dark at night like Arcade's procedural one (M2ZS1: the model's material without its night atlas,
##    night_albedo PYLON_NIGHT_ALBEDO) and its red aviation light blinking in Arcade's rhythm at pylon_m + 1.6 m
##    (PYLON_BLINK, read by the flare layer's blink_lit()); the overhead portals of truss bridges (props/bridge_truss_arch
##    scaled to the deck's fit_w) and the ornamental lamps of stone bridges and causeways (props/bridge_lamp) with their
##    light pools and glows (renderer.add_lamps(), A-7). A part whose model is missing becomes simple geometry.
## Fairness: nothing stands in a lane or in a bend's sight corridor – beside and below the deck, or overhead like
## Arcade's portals; railings stay those of builders/roadside.gd.
## Builder rules: build() runs on worker threads – ctx snapshot arrays and the plain input of collect() only; every
## position from ctx.local() (the cables: end points from the path in collect()). Without a renderer (tests) the meshes
## are built all the same.
## Owner: package R5 (tunnels, bridges, water and banks).

const WATER_CLASS := "water"                 ## ModernMaterials class: assets/shaders/modern/water.gdshader
const GROUND_LAYERS := 2                     ## render layer of ground meshes (builders/road.gd): no positional light
const WATER_LIFT := 0.15                     ## the water lies this far above the terrain's water rows
const BANK_LIFT := 0.08                      ## an embankment this far above the terrain's slope rows
const DECK_EXTRA_M := 0.4                    ## Track.BRIDGE_DECK_EXTRA_M (outside the City Limits)
const RAIL_BACK_M := 0.32                    ## the railing of roadside.gd is 0.3 m thick: the edge beam starts behind it
const K_WATER := 0.0
const K_STONE := 1.0
const K_BRICK := 2.0
const K_GRASS := 3.0
const K_PAVING := 4.0
const WALL_FOOT_M := 0.6                     ## a quay wall reaches this far below the water
const COPING_H := 0.16
const COPING_W := 0.7
## Arcade's truss girder (RoadRenderer._truss_girder: TRUSS_H, TRUSS_PANEL; 0.35 m outside the railing line)
const TRUSS_H := 4.2
const TRUSS_PANEL := 7.5
const TRUSS_OUT := 0.35
const CHORD := Vector2(0.4, 0.42)            ## chord cross-section (across, up)
const MEMBER := 0.24                         ## vertical / diagonal member
## Pylons (A-16): the bare model is 88.8 m high; Arcade's cap block is 1.6 m and its beacon on top of it
const PYLON_SET := "props/bridge_pylon_bare"
const PYLON_MODEL_H := 88.8
const PYLON_CAP_H := 1.6
const PYLON_CAP_W := 2.2
const PYLON_BASE := Vector2(4.4, 6.5)        ## foundation pier under a pylon (across, along the road)
## M2ZS1 (builders/props.gd PYLON_BLINK, PYLON_NIGHT_ALBEDO – carried over unchanged): Arcade's aviation light blinks
## while fmod(time + side × 0.4, 1.6) < 0.8 at night; the pylon model at night is concrete × ambient (night atlas off)
const PYLON_BLINK := Vector3(1.6, 0.8, 0.4)
const PYLON_NIGHT_ALBEDO := 0.45
const BEACON_COLOR := Color("ff2a1a")
const BEACON_SIZE := 0.9
const BEACON_ENERGY := 0.55                  ## PropLibrary.LAMP_ENERGY (lamps high up light no pool)
const CABLES_PER_SIDE := 7
const CABLE_W := 0.13
const CABLE_COLOR := Color("ecebe6")         ## RoadRenderer._pylon cables
const CABLE_RM := Vector2(0.6, 0.0)          ## painted steel: no metal share, the colour stays Arcade's
const PORTAL_SET := "props/bridge_truss_arch"
const LAMP_SET := "props/bridge_lamp"
const LAMP_RANGE_M := 9.0                    ## PropLibrary.LAMP_RANGE_M / LAMP_ENERGY / GROUP_ENERGY
const LAMP_ENERGY := 0.55
const GROUP_ENERGY := 1.6
## Look per bridge type: deck depth below the road (m), span of a field between two piers / arches (m), structure colour
## ("" = the bridge's railing colour), roughness / metallic
const TYPES := {
	"river": {"deck": 1.7, "span": 44.0, "struct": "#a9a69e", "rm": Vector2(0.88, 0.0)},
	"cable_stayed": {"deck": 2.3, "span": 55.0, "struct": "", "rm": Vector2(0.7, 0.15)},
	"truss_arch": {"deck": 1.1, "span": 40.0, "struct": "#8d8a83", "rm": Vector2(0.88, 0.0)},
	"stone_arch": {"deck": 0.9, "span": 21.0, "struct": "", "rm": Vector2(0.95, 0.0)},
	"canal": {"deck": 0.7, "span": 14.0, "struct": "#7a5648", "rm": Vector2(0.95, 0.0)},
	"causeway": {"deck": 0.8, "span": 9.5, "struct": "", "rm": Vector2(0.95, 0.0)},
}
const ARCHED := ["stone_arch", "canal", "causeway"]
const ROUGH_CONCRETE := Vector2(0.9, 0.0)
const ROUGH_STEEL := Vector2(0.55, 0.35)

var water_material: ShaderMaterial           ## shared with layers/far_ground.gd (ModernMaterials class "water")

var _renderer: Object
var _model_info: Dictionary = {}             ## set id -> model_info() (main thread, once loaded)
var _casters := 2
var _detail := 1.0
var _has_bridges := false
var _types: Dictionary = {}                  ## bridge types of the stage
var _models_wanted: Array[String] = []
var _models_ok: Dictionary = {}              ## set id -> true when its model is loaded
var _prepared := false
var _water_key := ""
var _dark_mats: Dictionary = {}
var _pool_registered := false
var _stats := {"chunks": 0, "water_quads": 0, "bank_quads": 0, "pylons": 0, "cables": 0, "portals": 0, "lamps": 0}


## Vertex arrays of one chunk while it is built.
class Buf extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c0 := PackedFloat32Array()           ## CUSTOM0 (water mesh): world xz of the UV.x axis
	var idx := PackedInt32Array()
	var custom := false

	## Quad a-b-c-d (in order around it) facing `toward`; uvs / uv2s: 4 Vector2 each (one per corner); axis: CUSTOM0.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color, uvs: Array, uv2s: Array,
			axis: Vector2 = Vector2.ZERO) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length_squared() < 1.0e-12:
			nn = (c - a).cross(d - a)
		if nn.length_squared() < 1.0e-12:
			nn = (c - b).cross(a - b)
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
				c0.append_array(PackedFloat32Array([axis.x, axis.y, 0.0, 0.0]))
		# front faces are clockwise
		if (c - a).cross(b - a).dot(nn) >= 0.0:
			idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
		else:
			idx.append_array(PackedInt32Array([o, o + 2, o + 1, o, o + 3, o + 2]))

	## A quad of the static structure (vpbr: UV = roughness / metallic, UV2 = no lamp).
	func squad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color, rm: Vector2) -> void:
		var u: Array = [rm, rm, rm, rm]
		var nl := Vector2(-1.0, 0.0)
		quad(a, b, c, d, toward, colour, u, [nl, nl, nl, nl])

	## A box member between the centre points p0 and p1 (cross-section w × h, `up` = its height direction): four sides,
	## the ends only when caps.
	func member(p0: Vector3, p1: Vector3, w: float, h: float, up: Vector3, colour: Color, rm: Vector2, caps: bool = false) -> void:
		var along := p1 - p0
		if along.length_squared() < 1.0e-8:
			return
		along = along.normalized()
		var side := up.cross(along)
		if side.length_squared() < 1.0e-6:
			side = Vector3.RIGHT.cross(along)
		side = side.normalized() * (w * 0.5)
		var upn := along.cross(side).normalized() * (h * 0.5)
		if upn.dot(up) < 0.0:
			upn = -upn
		var c := [p0 + side + upn, p0 - side + upn, p0 - side - upn, p0 + side - upn]
		var e := [p1 + side + upn, p1 - side + upn, p1 - side - upn, p1 + side - upn]
		var dirs := [upn, -side, -upn, side]
		for q in 4:
			var q1 := (q + 1) % 4
			var mid: Vector3 = (c[q] + c[q1]) * 0.5 - p0
			squad(c[q], e[q], e[q1], c[q1], mid if mid.length_squared() > 1e-8 else dirs[q], colour, rm)
		if caps:
			squad(c[0], c[1], c[2], c[3], -along, colour.darkened(0.1), rm)
			squad(e[0], e[1], e[2], e[3], along, colour.darkened(0.1), rm)

	## A stay cable: a thin member whose faces all carry the normal UP – lit like level ground on every side, so the
	## cable reads as Arcade's light line (RoadRenderer._pylon: ecebe6 × the light) and not as a half-dark rod a
	## pixel wide.
	func cable(p0: Vector3, p1: Vector3, w: float, colour: Color, rm: Vector2) -> void:
		var first := n.size()
		member(p0, p1, w, w, Vector3.UP, colour, rm)
		for k in range(first, n.size()):
			n[k] = Vector3.UP

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
	return "bridge"


# --- hooks of the renderer (all optional) -----------------------------------------------------------------------

func setup(renderer: Node) -> void:
	_renderer = renderer
	if renderer == null:
		return
	var trk: Variant = renderer.get("track")
	if trk is Track:
		_scan_track(trk as Track)


func apply_quality(levels: Dictionary) -> void:
	_casters = int(levels.get("shadow_casters", _casters))
	_detail = 0.7 if int(levels.get("details", 1)) <= 0 else 1.0
	if water_material != null:
		water_material.set_shader_parameter("detail", _detail)


## The bridge types of the stage and the models they need.
func _scan_track(track: Track) -> void:
	_types.clear()
	for br: Dictionary in track.bridges:
		_types[str(br.get("type", "river"))] = true
	_has_bridges = not _types.is_empty()
	_models_wanted.clear()
	if _types.has("cable_stayed"):
		_models_wanted.append(PYLON_SET)
	if _types.has("truss_arch"):
		_models_wanted.append(PORTAL_SET)
	if _types.has("stone_arch") or _types.has("causeway"):
		_models_wanted.append(LAMP_SET)


func prepare(_ctx: Dictionary) -> void:
	_prepared = true
	if not _models_wanted.is_empty() and ModelDB.available():
		ModelDB.request(_models_wanted, [], self)


func prepare_pending() -> int:
	if not _prepared or _models_wanted.is_empty() or not ModelDB.available():
		return 0
	return ModelDB.pending()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not _models_wanted.is_empty():
		ModelDB.release_all(self)


## The model parts of a set when they are loaded ([] = draw the stand-in geometry).
func _parts(set_id: String) -> Array:
	if not ModelDB.available() or not ModelDB.has_model(set_id):
		return []
	if not ModelDB.missing([set_id]).is_empty():
		return []
	return ModelFactory.multimesh_parts(set_id, "", _mats())


func _mats() -> ModernMaterials:
	var m: Variant = _renderer.get("materials") if _renderer != null else null
	return m if m is ModernMaterials else ModernMaterials.shared()


## The one water material of the stage (main thread): the class "water" of ModernMaterials, registered for the light
## pools of the lights layer. layers/far_ground.gd draws its far water with the same material.
func get_water_material(materials: ModernMaterials = null) -> ShaderMaterial:
	if water_material == null:
		var m := materials if materials != null else _mats()
		water_material = m.material(WATER_CLASS) as ShaderMaterial
		water_material.set_shader_parameter("detail", _detail)
		_water_key = ""
	if not _pool_registered and _renderer != null and _renderer.has_method(&"add_pool_material"):
		_pool_registered = true
		_renderer.call(&"add_pool_material", water_material)
	return water_material


## Every frame (main thread): the sky the water mirrors, its glitter, the night.
func update(view: Dictionary, _dt: float) -> void:
	if not _has_bridges or water_material == null:
		return
	var pal: Variant = view.get("palette")
	if not (pal is Dictionary):
		return
	var p := pal as Dictionary
	var night := clampf(float(p.get("lights", 0.0)), 0.0, 1.0)
	var overcast := clampf(float(p.get("overcast", 0.0)), 0.0, 1.0)
	var glint := 0.0
	if bool(p.get("sun_visible", false)) and night < 0.3:
		glint = 1.0
	elif bool(p.get("moon_visible", false)):
		glint = 0.25
	glint *= 1.0 - overcast
	var top: Color = p.get("sky_top", Color(0.36, 0.58, 0.88))
	var bottom: Color = p.get("sky_bottom", Color(0.78, 0.86, 0.93))
	var key := "%s|%s|%.3f|%.2f" % [top.to_html(false), bottom.to_html(false), night, glint]
	if key == _water_key:
		return
	_water_key = key
	water_material.set_shader_parameter("sky_zenith", Vector3(top.r, top.g, top.b))
	water_material.set_shader_parameter("sky_horizon", Vector3(bottom.r, bottom.g, bottom.b))
	water_material.set_shader_parameter("night", night)
	water_material.set_shader_parameter("glint", glint)


# --- chunk building -----------------------------------------------------------------------------------------------

## Main thread: the bridges of the chunk as plain data, the loaded model parts, the cable end points (from the path).
func collect(ctx: ChunkContext) -> Variant:
	var bridges := {}
	var trk := ctx.track
	for i in ctx.row_count():
		var seg: Dictionary = ctx.segs[i]
		if not (bool(seg["water"]) or bool(seg["bank"])):
			continue
		var bi := int(seg["bridge_i"])
		if bridges.has(bi) or trk == null or bi < 0 or bi >= trk.bridges.size():
			continue
		bridges[bi] = bridge_info(trk.bridges[bi], ctx.scenery_db.get(str(seg["scenery"]), {}), bool(seg["city"]))
	if bridges.is_empty():
		return {}
	if not _has_bridges and trk != null:
		_scan_track(trk)
	# model data for the worker: what is loaded, the lamp anchors, the pylon's centre
	var models := {}
	for set_id: String in [PYLON_SET, PORTAL_SET, LAMP_SET]:
		if not _types.is_empty() and not _models_wanted.has(set_id):
			continue
		if not _model_info.has(set_id) or (not bool((_model_info[set_id] as Dictionary)["ok"]) and ModelDB.pending() == 0):
			_model_info[set_id] = model_info(set_id)
		models[set_id] = _model_info[set_id]
	# the stay cables: both end points from the path (a cable reaches up to 64 m beyond its pylon's chunk)
	var cables: Array = []
	for i in ctx.row_count() - 1:
		for it: Dictionary in ctx.segs[i]["sprites"]:
			if str(it.get("proc", "")) != "pylon":
				continue
			cables.append_array(cable_lines(ctx, it, models.get(PYLON_SET, {})))
	return {"bridges": bridges, "models": models, "cables": cables, "casters": _casters, "detail": _detail}


## Plain data of a bridge of Track.bridges for build(): its type, depth, slope, ends, colours and bank style.
static func bridge_info(br: Dictionary, scen: Variant, city: bool) -> Dictionary:
	var typ := str(br.get("type", "river"))
	var look: Dictionary = TYPES.get(typ, TYPES["river"])
	var water := str(br.get("water", ""))
	if water == "" and scen is Dictionary:
		water = str((scen as Dictionary).get("water", ""))
	if water == "":
		water = str(CityData.WATER_COLOR.get(typ, "#4b6878"))
	var rail: Color = RoadRenderer.RAIL.get(typ, RoadRenderer.RAIL["river"])
	if str(br.get("color", "")) != "":
		rail = Color(str(br["color"]))
	var quay: Color = RoadRenderer.QUAY.get(typ, RoadRenderer.QUAY["river"])
	var bank := str(br.get("bank", ""))
	var depth := float(br.get("depth", 3.0))
	var slope := float(br.get("slope", 3.0))
	var style := "wall"
	var kind := K_BRICK if typ == "canal" else K_STONE
	var bank_col := quay
	if bank != "":
		style = "slope"
		kind = K_GRASS
		bank_col = Color(bank)
	elif slope > 3.01:
		style = "slope"
	var struct_col := rail if str(look["struct"]) == "" else Color(str(look["struct"]))
	if typ == "stone_arch" or typ == "causeway":
		struct_col = rail.darkened(0.06)
	return {"type": typ, "depth": depth, "slope": slope, "z0": float(br.get("z0", 0.0)), "z1": float(br.get("z1", 0.0)),
		"water": Color(water), "rail": rail, "bank": bank_col, "kind": kind, "style": style,
		"extra": 0.0 if city else DECK_EXTRA_M, "deck": float(look["deck"]), "span": float(look["span"]),
		"struct": struct_col, "rm": look["rm"]}


## Plain data of a part model: loaded or not, its x centre and lamp anchors.
func model_info(set_id: String) -> Dictionary:
	var ok := not _parts(set_id).is_empty()
	var out := {"ok": ok, "cx": 0.0, "width": 1.0, "height": 1.0, "lamps": []}
	if not ModelDB.available():
		return out
	var m := ModelDB.resolve(set_id).get("model", {}) as Dictionary
	if m.is_empty():
		return out
	var obj: Dictionary = m.get("object", {})
	out["width"] = float(obj.get("width_m", 1.0))
	out["height"] = float(obj.get("height_m", 1.0))
	var bb: Variant = m.get("aabb", [])
	if bb is Array and (bb as Array).size() >= 6:
		out["cx"] = float(bb[0]) + float(bb[3]) * 0.5
	var lamps: Array = []
	for l: Variant in m.get("lights", []):
		var d: Dictionary = l
		var pos: Variant = d.get("pos")
		var dir: Variant = d.get("dir")
		if not (pos is Array) or not (dir is Array):
			continue
		lamps.append({"pos": Vector3(float(pos[0]), float(pos[1]), float(pos[2])),
			"dir": Vector3(float(dir[0]), float(dir[1]), float(dir[2])).normalized(), "role": str(d.get("role", "lights")),
			"color": Color(str(d.get("color", "#fff0cf"))), "size": float(d.get("size", 0.3))})
	out["lamps"] = lamps
	return out


## The 2 × CABLES_PER_SIDE stay cables of a pylon item (Arcade, RoadRenderer._pylon): [[top, deck], …] chunk-local.
## Main thread (the path places the deck ends, which may lie beyond the chunk).
static func cable_lines(ctx: ChunkContext, it: Dictionary, pylon: Dictionary) -> Array:
	var out: Array = []
	var side := float(int(it.get("side", 1)))
	var z := float(it.get("z", 0.0))
	var x := float(it.get("x", 0.0))
	var hgt := float(it.get("height_m", 80.0))
	var span := float(it.get("cables", 50.0))
	var cx := x + side * float(pylon.get("cx", 0.0))       # the model's centre (mirrored on the left)
	var x_deck := x - side * 1.4
	var top_z := z
	for i in CABLES_PER_SIDE:
		var d := span * float(i + 1) / float(CABLES_PER_SIDE)
		var ht := hgt * (0.95 - 0.05 * float(i))
		for dir: float in [1.0, -1.0]:
			var a := ctx.local(top_z, cx, ht)
			var bz := z + dir * d
			var b: Vector3
			if ctx.path != null and ctx.path.is_ready() and bz >= float(ctx.path.first) * ctx.seg_len and bz <= float(ctx.path.last()) * ctx.seg_len:
				b = ctx.path.world(bz, x_deck, 1.1) - ctx.origin
			else:
				b = ctx.local(bz, x_deck, 1.1)
			out.append([a, b])
	return out


## WORKER THREAD.
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var inp: Dictionary = input if input is Dictionary else {}
	var bridges: Dictionary = inp.get("bridges", {})
	if bridges.is_empty():
		return {}
	var models: Dictionary = inp.get("models", {})
	var wb := Buf.new()
	wb.custom = true
	var sb := Buf.new()
	var counts := {"water_quads": 0, "bank_quads": 0, "walls": 0, "piers": 0, "arches": 0, "truss": 0, "pylons": 0, "cables": 0,
		"portals": 0, "lamps": 0}
	var rows := ctx.row_count()
	for i in rows - 1:
		var sa: Dictionary = ctx.segs[i]
		var sb_seg: Dictionary = ctx.segs[i + 1]
		if not bool(sa["water"]) or bool(sa["tunnel"]):
			continue
		var br: Dictionary = bridges.get(int(sa["bridge_i"]), {})
		if br.is_empty():
			continue
		_water_and_banks(wb, ctx, i, sa, sb_seg, br, counts)
		_structure(sb, ctx, i, sa, br, counts)
	# the parts on the deck
	var pylons: Array = []
	var portals: Array = []
	var lamp_models: Array = []
	var lamps: Array = []
	for i in rows - 1:
		var sa: Dictionary = ctx.segs[i]
		for it: Dictionary in sa["sprites"]:
			if not it.has("bridge"):
				continue
			var br: Dictionary = bridges.get(int(sa["bridge_i"]), {})
			match str(it.get("proc", "")):
				"pylon":
					_pylon(sb, ctx, it, br, models.get(PYLON_SET, {}), pylons, lamps, counts)
				"truss_portal":
					_portal(sb, ctx, it, br, models.get(PORTAL_SET, {}), portals, lamps, counts)
				"bridge_lamp":
					_lamp(sb, ctx, it, models.get(LAMP_SET, {}), lamp_models, lamps, counts)
	for c: Array in inp.get("cables", []):
		sb.cable(c[0], c[1], CABLE_W, CABLE_COLOR, CABLE_RM)
		counts["cables"] += 1
	return {"water": wb.arrays() if not wb.idx.is_empty() else [], "struct": sb.arrays() if not sb.idx.is_empty() else [],
		"pylons": pylons, "portals": portals, "lamp_models": lamp_models, "lamps": lamps, "counts": counts,
		"water_tris": wb.idx.size() / 3, "struct_tris": sb.idx.size() / 3}


## Lateral position (signed, from the centre line) of terrain ring j of row i on `side` (the ring offsets beyond the
## shoulder edge, ChunkContext.ring_offset).
static func ring_x(ctx: ChunkContext, i: int, side: int, j: int) -> float:
	return float(side) * (ctx.shoulder_edge(i, side) + ctx.ring_offset(i, side, j))


## The water of segment i and the bank geometry where the segment lies on a bank slope.
func _water_and_banks(wb: Buf, ctx: ChunkContext, i: int, sa: Dictionary, sb_seg: Dictionary, br: Dictionary, counts: Dictionary) -> void:
	var depth := float(br["depth"])
	var deep := -depth + 0.05
	var lv_a := minf(float(sa["water_level"]), 0.0)
	var b_water := bool(sb_seg["water"]) and int(sb_seg["bridge_i"]) == int(sa["bridge_i"])
	var lv_b := minf(float(sb_seg["water_level"]), 0.0) if b_water else 0.0
	var za := float(ctx.seg_a + i) * ctx.seg_len
	var zb := za + ctx.seg_len
	var z0 := float(br["z0"])
	var z1 := float(br["z1"])
	var slope := float(br["slope"])
	var wall := str(br["style"]) == "wall"
	if lv_a <= deep and b_water and lv_b <= deep:
		_water_strip(wb, ctx, i, i + 1, za, zb, lv_a, lv_b, br, z0 + slope, z1 - slope, counts)
		return
	if wall:
		if lv_a > lv_b:
			# near bank: paved top over the slope, the wall where the terrain reaches the water (facing the river)
			_quay(wb, ctx, i, i + 1, za, zb, br, 1.0, counts)
		else:
			# far bank: the wall at the water's end (facing the approaching camera), the paved top behind it
			_quay(wb, ctx, i + 1, i, zb, za, br, -1.0, counts)
		return
	# embankment: a surface on the terrain's slope rows
	_embankment(wb, ctx, i, za, zb, br, counts)


## Water between rows ra and rb (levels la, lb relative to the road), from the centre line out to the ribbon's last
## ring on both sides. zw0 / zw1: where the water meets the banks (UV2.y = distance to the nearer one).
func _water_strip(wb: Buf, ctx: ChunkContext, ra: int, rb: int, za: float, zb: float, la: float, lb: float, br: Dictionary,
		zw0: float, zw1: float, counts: Dictionary) -> void:
	var col: Color = br["water"]
	var axis_a := Vector2(ctx.rows_r[ra].x, ctx.rows_r[ra].z)
	var ha := la + WATER_LIFT
	var hb := lb + WATER_LIFT
	var da := minf(za - zw0, zw1 - za)
	var db := minf(zb - zw0, zw1 - zb)
	for side: int in [-1, 1]:
		var xa_prev := 0.0
		var xb_prev := 0.0
		for j in ctx.rings:
			var xa := ring_x(ctx, ra, side, j)
			var xb := ring_x(ctx, rb, side, j)
			if absf(xa - xa_prev) < 0.05 and absf(xb - xb_prev) < 0.05:
				continue
			wb.quad(ctx.local(za, xa_prev, ha), ctx.local(zb, xb_prev, hb), ctx.local(zb, xb, hb), ctx.local(za, xa, ha), Vector3.UP, col,
				[Vector2(xa_prev, za), Vector2(xb_prev, zb), Vector2(xb, zb), Vector2(xa, za)],
				[Vector2(K_WATER, da), Vector2(K_WATER, db), Vector2(K_WATER, db), Vector2(K_WATER, da)], axis_a)
			counts["water_quads"] += 1
			xa_prev = xa
			xb_prev = xb


## A quay wall with its paved top: the top lies over the segment from row r_top (the side of the land, at that row's
## terrain heights) to row r_wall, where the wall stands and goes down into the water. dir = +1: the wall faces
## forward (near bank: towards the river ahead), -1: it faces back (far bank: towards the approaching camera).
func _quay(wb: Buf, ctx: ChunkContext, r_top: int, r_wall: int, z_top: float, z_wall: float, br: Dictionary, dir: float, counts: Dictionary) -> void:
	var depth := float(br["depth"])
	var water_h := -depth
	var kind := float(br["kind"])
	var col: Color = br["bank"]
	var paving := col.lightened(0.18)
	var extra := float(br["extra"])
	var face := ctx.rows_f[r_wall] * dir                     # the wall's outer side
	var z_cope := z_wall - dir * COPING_W                    # the coping's back edge, on the land side
	# under the deck: the abutment, the same wall from just under the road down into the water
	var xd_l := -(ctx.shoulder_edge(r_wall, -1) + extra)
	var xd_r := ctx.shoulder_edge(r_wall, 1) + extra
	wb.quad(ctx.local(z_wall, xd_l, -0.05), ctx.local(z_wall, xd_r, -0.05), ctx.local(z_wall, xd_r, water_h - WALL_FOOT_M),
		ctx.local(z_wall, xd_l, water_h - WALL_FOOT_M), face, col.darkened(0.12),
		[Vector2(xd_l, depth), Vector2(xd_r, depth), Vector2(xd_r, -WALL_FOOT_M), Vector2(xd_l, -WALL_FOOT_M)],
		[Vector2(kind, depth), Vector2(kind, depth), Vector2(kind, -WALL_FOOT_M), Vector2(kind, -WALL_FOOT_M)])
	for side: int in [-1, 1]:
		var s := float(side)
		var x0w := s * (ctx.shoulder_edge(r_wall, side) + extra)
		var x0t := s * (ctx.shoulder_edge(r_top, side) + extra)
		var prev_w := x0w
		var prev_t := x0t
		var prev_h := maxf(ctx.ring_height(r_top, side, 0), water_h + 0.4)
		for j in range(1, ctx.rings):
			var xw := ring_x(ctx, r_wall, side, j)
			var xt := ring_x(ctx, r_top, side, j)
			var h := maxf(ctx.ring_height(r_top, side, j), water_h + 0.4)
			if absf(xw - prev_w) < 0.05:
				continue
			# the wall
			var aw := ctx.local(z_wall, prev_w, prev_h)
			var bw := ctx.local(z_wall, xw, h)
			var cw := ctx.local(z_wall, xw, water_h - WALL_FOOT_M)
			var dw := ctx.local(z_wall, prev_w, water_h - WALL_FOOT_M)
			wb.quad(aw, bw, cw, dw, face, col, [Vector2(prev_w, prev_h - water_h), Vector2(xw, h - water_h), Vector2(xw, -WALL_FOOT_M),
				Vector2(prev_w, -WALL_FOOT_M)], [Vector2(kind, prev_h - water_h), Vector2(kind, h - water_h), Vector2(kind, -WALL_FOOT_M),
				Vector2(kind, -WALL_FOOT_M)])
			# coping stones on its top: front face and top
			var ct := COPING_H
			wb.quad(ctx.local(z_wall + dir * 0.06, prev_w, prev_h + ct), ctx.local(z_wall + dir * 0.06, xw, h + ct),
				ctx.local(z_wall + dir * 0.06, xw, h - 0.05), ctx.local(z_wall + dir * 0.06, prev_w, prev_h - 0.05), face, paving,
				[Vector2(prev_w, 0.0), Vector2(xw, 0.0), Vector2(xw, 0.2), Vector2(prev_w, 0.2)],
				[Vector2(K_PAVING, prev_h - water_h), Vector2(K_PAVING, h - water_h), Vector2(K_PAVING, h - water_h), Vector2(K_PAVING, prev_h - water_h)])
			wb.quad(ctx.local(z_wall + dir * 0.06, prev_w, prev_h + ct), ctx.local(z_wall + dir * 0.06, xw, h + ct),
				ctx.local(z_cope, xw, h + ct), ctx.local(z_cope, prev_w, prev_h + ct), Vector3.UP, paving,
				[Vector2(prev_w, 0.0), Vector2(xw, 0.0), Vector2(xw, COPING_W), Vector2(prev_w, COPING_W)],
				[Vector2(K_PAVING, prev_h - water_h), Vector2(K_PAVING, h - water_h), Vector2(K_PAVING, h - water_h), Vector2(K_PAVING, prev_h - water_h)])
			# the paved top over the terrain's slope, from the coping back to the land row
			wb.quad(ctx.local(z_cope, prev_w, prev_h + 0.02), ctx.local(z_cope, xw, h + 0.02), ctx.local(z_top, xt, h + 0.02),
				ctx.local(z_top, prev_t, prev_h + 0.02), Vector3.UP, paving.darkened(0.05),
				[Vector2(prev_w, z_cope), Vector2(xw, z_cope), Vector2(xt, z_top), Vector2(prev_t, z_top)],
				[Vector2(K_PAVING, prev_h - water_h), Vector2(K_PAVING, h - water_h), Vector2(K_PAVING, h - water_h), Vector2(K_PAVING, prev_h - water_h)])
			counts["bank_quads"] += 4
			prev_w = xw
			prev_t = xt
			prev_h = h
	counts["walls"] += 1


## Embankment on segment i: the terrain's slope rows (rings at the row's water level – the bank row behind a bridge at
## its own profile) BANK_LIFT higher, from the deck edge to the ribbon's last ring.
func _embankment(wb: Buf, ctx: ChunkContext, i: int, za: float, zb: float, br: Dictionary, counts: Dictionary) -> void:
	var depth := float(br["depth"])
	var water_h := -depth
	var kind := float(br["kind"])
	var col: Color = br["bank"]
	var extra := float(br["extra"])
	for side: int in [-1, 1]:
		var s := float(side)
		var pa := s * (ctx.shoulder_edge(i, side) + extra)
		var pb := s * (ctx.shoulder_edge(i + 1, side) + extra)
		var ha_prev := ctx.ring_height(i, side, 0)
		var hb_prev := ctx.ring_height(i + 1, side, 0)
		for j in range(1, ctx.rings):
			var xa := ring_x(ctx, i, side, j)
			var xb := ring_x(ctx, i + 1, side, j)
			var ha := ctx.ring_height(i, side, j)
			var hb := ctx.ring_height(i + 1, side, j)
			if absf(xa - pa) < 0.05 and absf(xb - pb) < 0.05:
				continue
			var lift := BANK_LIFT
			var c_a := _bank_tone(col, ha_prev, water_h)
			wb.quad(ctx.local(za, pa, ha_prev + lift), ctx.local(zb, pb, hb_prev + lift), ctx.local(zb, xb, hb + lift),
				ctx.local(za, xa, ha + lift), Vector3.UP, c_a,
				[Vector2(pa, za), Vector2(pb, zb), Vector2(xb, zb), Vector2(xa, za)],
				[Vector2(kind, ha_prev - water_h), Vector2(kind, hb_prev - water_h), Vector2(kind, hb - water_h), Vector2(kind, ha - water_h)])
			counts["bank_quads"] += 1
			pa = xa
			pb = xb
			ha_prev = ha
			hb_prev = hb


## Arcade darkens the quay towards the water (q.darkened(0.35 × depth share), RoadRenderer._draw_water).
static func _bank_tone(col: Color, h: float, water_h: float) -> Color:
	var share := clampf(-h / maxf(-water_h, 0.1), 0.0, 1.0)
	return col.darkened(0.18 * share)


## The structure of segment i: edge beams and underside of the deck, piers or arches, truss girders.
func _structure(sb: Buf, ctx: ChunkContext, i: int, sa: Dictionary, br: Dictionary, counts: Dictionary) -> void:
	var typ := str(br["type"])
	var depth := float(br["depth"])
	var deck := minf(float(br["deck"]), depth * 0.6)
	var col: Color = br["struct"]
	var rm: Vector2 = br["rm"]
	var extra := float(br["extra"])
	var za := float(ctx.seg_a + i) * ctx.seg_len
	var zb := za + ctx.seg_len
	var xl_a := -(ctx.shoulder_edge(i, -1) + extra + RAIL_BACK_M)
	var xl_b := -(ctx.shoulder_edge(i + 1, -1) + extra + RAIL_BACK_M)
	var xr_a := ctx.shoulder_edge(i, 1) + extra + RAIL_BACK_M
	var xr_b := ctx.shoulder_edge(i + 1, 1) + extra + RAIL_BACK_M
	var arched := ARCHED.has(typ)
	var z0 := float(br["z0"])
	var z1 := float(br["z1"])
	var slope := float(br["slope"])
	# the water stretch the substructure stands in (between the banks)
	var zw0 := z0 + slope
	var zw1 := z1 - slope
	if not arched:
		# edge beams (fascia) on both sides and the underside of the deck
		for side: int in [-1, 1]:
			var xa := xl_a if side < 0 else xr_a
			var xb := xl_b if side < 0 else xr_b
			var out := ctx.rows_r[i] * float(side)
			sb.squad(ctx.local(za, xa, 0.12), ctx.local(zb, xb, 0.12), ctx.local(zb, xb, -deck), ctx.local(za, xa, -deck), out, col, rm)
			var inner_a := xa - float(side) * RAIL_BACK_M
			var inner_b := xb - float(side) * RAIL_BACK_M
			sb.squad(ctx.local(za, inner_a, 0.12), ctx.local(zb, inner_b, 0.12), ctx.local(zb, xb, 0.12), ctx.local(za, xa, 0.12), Vector3.UP,
				col.lightened(0.06), rm)
			# a darker band at the foot of the beam (drip edge)
			sb.squad(ctx.local(za, xa + float(side) * 0.02, -deck + 0.25), ctx.local(zb, xb + float(side) * 0.02, -deck + 0.25),
				ctx.local(zb, xb + float(side) * 0.02, -deck), ctx.local(za, xa + float(side) * 0.02, -deck), out, col.darkened(0.25), rm)
		sb.squad(ctx.local(za, xl_a, -deck), ctx.local(za, xr_a, -deck), ctx.local(zb, xr_b, -deck), ctx.local(zb, xl_b, -deck), Vector3.DOWN,
			col.darkened(0.3), rm)
		# piers in the water stretch (cable-stayed bridges: only in the side spans)
		var span := float(br["span"])
		var length := zw1 - zw0
		if length > span * 1.2:
			var n := maxi(1, int(round(length / span)))
			for k in range(1, n):
				var zp := zw0 + length * float(k) / float(n)
				if typ == "cable_stayed" and zp > z0 + (z1 - z0) * 0.22 and zp < z0 + (z1 - z0) * 0.78:
					continue
				if zp >= za - 1.4 and zp < zb + 1.4 and int(floor(zp / ctx.seg_len)) == ctx.seg_a + i:
					_pier(sb, ctx, zp, xl_a, xr_a, deck, depth, col, rm)
					counts["piers"] += 1
	else:
		_arches(sb, ctx, i, za, zb, xl_a, xl_b, xr_a, xr_b, zw0, zw1, deck, depth, br, counts)
	if typ == "truss_arch":
		_truss(sb, ctx, i, za, zb, br, counts)


## A wall pier across the deck at road position zp: from the underside of the deck into the water, pointed cutwaters
## at both ends (the current runs across the road), a cap under the deck.
func _pier(sb: Buf, ctx: ChunkContext, zp: float, xl: float, xr: float, deck: float, depth: float, col: Color, rm: Vector2) -> void:
	var half := 1.1
	var top := -deck
	var bot := -depth - 1.0
	var pc := col.darkened(0.08)
	var xl_i := xl + 1.2
	var xr_i := xr - 1.2
	# long faces (towards the road's ends)
	for dz: float in [-half, half]:
		var f := ctx.rows_f[clampi(int(ctx.row_of(zp)), 0, ctx.row_count() - 1)] * signf(dz)
		sb.squad(ctx.local(zp + dz, xl_i, top), ctx.local(zp + dz, xr_i, top), ctx.local(zp + dz, xr_i, bot), ctx.local(zp + dz, xl_i, bot), f, pc, rm)
	# cutwaters: two faces each, meeting at a point beyond the deck edge
	for side: int in [-1, 1]:
		var xe := xl_i if side < 0 else xr_i
		var tip := xe + float(side) * 2.2
		var out := ctx.rows_r[clampi(int(ctx.row_of(zp)), 0, ctx.row_count() - 1)] * float(side)
		sb.squad(ctx.local(zp - half, xe, top), ctx.local(zp, tip, top), ctx.local(zp, tip, bot), ctx.local(zp - half, xe, bot), out, pc, rm)
		sb.squad(ctx.local(zp, tip, top), ctx.local(zp + half, xe, top), ctx.local(zp + half, xe, bot), ctx.local(zp, tip, bot), out, pc, rm)
		# the cap of the cutwater
		sb.squad(ctx.local(zp - half, xe, top), ctx.local(zp + half, xe, top), ctx.local(zp, tip, top), ctx.local(zp, tip, top), Vector3.UP, pc.lightened(0.05), rm)
	# the cap under the deck: a little wider than the pier
	var cap := 0.45
	for dz: float in [-half - 0.25, half + 0.25]:
		var f := ctx.rows_f[clampi(int(ctx.row_of(zp)), 0, ctx.row_count() - 1)] * signf(dz)
		sb.squad(ctx.local(zp + dz, xl_i - 0.4, top), ctx.local(zp + dz, xr_i + 0.4, top), ctx.local(zp + dz, xr_i + 0.4, top - cap),
			ctx.local(zp + dz, xl_i - 0.4, top - cap), f, col.lightened(0.04), rm)
	sb.squad(ctx.local(zp - half - 0.25, xl_i - 0.4, top - cap), ctx.local(zp - half - 0.25, xr_i + 0.4, top - cap),
		ctx.local(zp + half + 0.25, xr_i + 0.4, top - cap), ctx.local(zp + half + 0.25, xl_i - 0.4, top - cap), Vector3.DOWN, col.darkened(0.2), rm)


## Height (relative to the road) of the arch intrados at road position z: segmental arches over the water stretch
## zw0 … zw1 in fields of the bridge's span, piers of `pier` metres between them, springing `spring` above the water,
## crown just under the deck. Returns INF on a pier (no opening there).
static func arch_height(z: float, zw0: float, zw1: float, span: float, pier: float, spring_h: float, crown_h: float) -> float:
	var length := zw1 - zw0
	if length <= 1.0 or z <= zw0 or z >= zw1:
		return INF
	var n := maxi(1, int(round(length / span)))
	var field := length / float(n)
	var k := clampi(int(floor((z - zw0) / field)), 0, n - 1)
	var a := zw0 + float(k) * field + (pier * 0.5 if k > 0 else 0.0)
	var b := zw0 + float(k + 1) * field - (pier * 0.5 if k < n - 1 else 0.0)
	if z <= a or z >= b:
		return INF
	var t := (z - a) / (b - a) * 2.0 - 1.0            # -1 … 1 across the opening
	return spring_h + (crown_h - spring_h) * sqrt(maxf(0.0, 1.0 - t * t))


## Spandrel walls, arch barrels and piers of segment i (stone, brick and causeway bridges).
func _arches(sb: Buf, ctx: ChunkContext, i: int, za: float, zb: float, xl_a: float, xl_b: float, xr_a: float, xr_b: float,
		zw0: float, zw1: float, deck: float, depth: float, br: Dictionary, counts: Dictionary) -> void:
	var col: Color = br["struct"]
	var rm: Vector2 = br["rm"]
	var span := float(br["span"])
	var pier := clampf(span * 0.16, 1.0, 3.6)
	var spring_h := -depth + 0.55
	var crown_h := -deck
	var steps := 4
	var top := 0.12
	var barrel := col.darkened(0.32)
	for q in steps:
		var z_a := lerpf(za, zb, float(q) / float(steps))
		var z_b := lerpf(za, zb, float(q + 1) / float(steps))
		var ha := arch_height(z_a, zw0, zw1, span, pier, spring_h, crown_h)
		var hb := arch_height(z_b, zw0, zw1, span, pier, spring_h, crown_h)
		var bot_a := ha if ha < INF else -depth - 0.6
		var bot_b := hb if hb < INF else -depth - 0.6
		var f0 := float(q) / float(steps)
		var f1 := float(q + 1) / float(steps)
		var xla := lerpf(xl_a, xl_b, f0)
		var xlb := lerpf(xl_a, xl_b, f1)
		var xra := lerpf(xr_a, xr_b, f0)
		var xrb := lerpf(xr_a, xr_b, f1)
		for side: int in [-1, 1]:
			var xa := xla if side < 0 else xra
			var xb := xlb if side < 0 else xrb
			var out := ctx.rows_r[i] * float(side)
			# the spandrel wall (and the pier's face where there is no opening)
			sb.squad(ctx.local(z_a, xa, top), ctx.local(z_b, xb, top), ctx.local(z_b, xb, bot_b), ctx.local(z_a, xa, bot_a), out, col, rm)
			# a string course under the parapet
			sb.squad(ctx.local(z_a, xa + float(side) * 0.08, top), ctx.local(z_b, xb + float(side) * 0.08, top),
				ctx.local(z_b, xb + float(side) * 0.08, top - 0.3), ctx.local(z_a, xa + float(side) * 0.08, top - 0.3), out, col.lightened(0.08), rm)
			sb.squad(ctx.local(z_a, xa, top), ctx.local(z_b, xb, top), ctx.local(z_b, xb + float(side) * 0.08, top), ctx.local(z_a, xa + float(side) * 0.08, top),
				Vector3.UP, col.lightened(0.1), rm)
		if ha < INF and hb < INF:
			# the barrel of the arch: the intrados between the two spandrels
			sb.squad(ctx.local(z_a, xla, ha), ctx.local(z_a, xra, ha), ctx.local(z_b, xrb, hb), ctx.local(z_b, xlb, hb), Vector3.DOWN, barrel, rm)
		elif (ha < INF) != (hb < INF):
			# the face of a pier towards the opening
			var zf := z_b if ha < INF else z_a
			var hf := ha if ha < INF else hb
			var toward := -ctx.rows_f[i] if ha >= INF else ctx.rows_f[i]
			sb.squad(ctx.local(zf, xla, hf), ctx.local(zf, xra, hf), ctx.local(zf, xra, -depth - 0.6), ctx.local(zf, xla, -depth - 0.6), toward,
				barrel.lightened(0.1), rm)
	# cutwaters of the piers that stand in this segment
	var length := zw1 - zw0
	var n := maxi(1, int(round(length / span)))
	var field := length / maxf(1.0, float(n))
	for k in range(1, n):
		var zp := zw0 + field * float(k)
		if int(floor(zp / ctx.seg_len)) != ctx.seg_a + i:
			continue
		counts["piers"] += 1
		var half := pier * 0.5
		for side: int in [-1, 1]:
			var xe := xl_a if side < 0 else xr_a
			var tip := xe + float(side) * minf(2.0, pier * 0.8)
			var up_h := spring_h + 0.6
			var out := ctx.rows_r[i] * float(side)
			sb.squad(ctx.local(zp - half, xe, up_h), ctx.local(zp, tip, up_h), ctx.local(zp, tip, -depth - 0.6), ctx.local(zp - half, xe, -depth - 0.6), out, col, rm)
			sb.squad(ctx.local(zp, tip, up_h), ctx.local(zp + half, xe, up_h), ctx.local(zp + half, xe, -depth - 0.6), ctx.local(zp, tip, -depth - 0.6), out, col, rm)
			# a pointed stone cap on the cutwater
			sb.squad(ctx.local(zp - half, xe, up_h), ctx.local(zp + half, xe, up_h), ctx.local(zp, xe, up_h + 0.9), ctx.local(zp, tip, up_h), Vector3.UP + out,
				col.lightened(0.06), rm)
	counts["arches"] += 1


## Arcade's side girders of a truss bridge on segment i: bottom and top chord, verticals and alternating diagonals at
## the panel points (world road positions, multiples of TRUSS_PANEL) – each member clipped to the segment, so the
## girder is continuous over chunk boundaries.
func _truss(sb: Buf, ctx: ChunkContext, i: int, za: float, zb: float, br: Dictionary, counts: Dictionary) -> void:
	var col: Color = br["rail"]
	var dark := col.darkened(0.15)
	var extra := float(br["extra"])
	var rm := ROUGH_STEEL
	for side: int in [-1, 1]:
		var s := float(side)
		var xa := s * (ctx.shoulder_edge(i, side) + extra + TRUSS_OUT)
		var xb := s * (ctx.shoulder_edge(i + 1, side) + extra + TRUSS_OUT)
		var up := Vector3.UP
		# chords along the segment
		sb.member(ctx.local(za, xa, CHORD.y * 0.5), ctx.local(zb, xb, CHORD.y * 0.5), CHORD.x, CHORD.y, up, dark, rm)
		sb.member(ctx.local(za, xa, TRUSS_H - CHORD.y * 0.5), ctx.local(zb, xb, TRUSS_H - CHORD.y * 0.5), CHORD.x, CHORD.y, up, col, rm)
		# members of the panels that touch the segment
		var k0 := int(floor(za / TRUSS_PANEL)) - 1
		var k1 := int(ceil(zb / TRUSS_PANEL))
		for k in range(k0, k1 + 1):
			var zp := float(k) * TRUSS_PANEL
			if zp >= za and zp < zb:
				var xv := lerpf(xa, xb, (zp - za) / (zb - za))
				sb.member(ctx.local(zp, xv, CHORD.y), ctx.local(zp, xv, TRUSS_H - CHORD.y), MEMBER, MEMBER, ctx.rows_f[i], col, rm)
			# the diagonal of this panel: from the bottom at zp to the top at zp + panel, or from the top to the bottom
			var rising := posmod(k, 2) == 0
			var z_s := zp
			var z_e := zp + TRUSS_PANEL
			var h_s := CHORD.y if rising else TRUSS_H - CHORD.y
			var h_e := TRUSS_H - CHORD.y if rising else CHORD.y
			var c0 := maxf(z_s, za)
			var c1 := minf(z_e, zb)
			if c1 <= c0 + 0.01:
				continue
			var t0 := (c0 - z_s) / TRUSS_PANEL
			var t1 := (c1 - z_s) / TRUSS_PANEL
			var x0 := lerpf(xa, xb, (c0 - za) / (zb - za))
			var x1 := lerpf(xa, xb, (c1 - za) / (zb - za))
			sb.member(ctx.local(c0, x0, lerpf(h_s, h_e, t0)), ctx.local(c1, x1, lerpf(h_s, h_e, t1)), MEMBER * 0.85, MEMBER * 0.85,
				ctx.rows_r[i], col, rm)
	counts["truss"] += 1


## A pylon of a cable-stayed bridge: the bare model (placed and mirrored like the props builder placed the pylon model,
## scaled in height to pylon_m – A-16), its cap and beacon mast, the foundation pier, the aviation light.
func _pylon(sb: Buf, ctx: ChunkContext, it: Dictionary, br: Dictionary, model: Dictionary, out: Array, lamps: Array, counts: Dictionary) -> void:
	var side := int(it.get("side", 1))
	var s := float(side)
	var z := float(it.get("z", 0.0))
	var x := float(it.get("x", 0.0))
	var hgt := maxf(10.0, float(it.get("height_m", 80.0)))
	var cx := x + s * float(model.get("cx", 0.0))
	var concrete := Color("c4c2bb")
	var depth := float(br.get("depth", 5.0))
	var deck := minf(float(br.get("deck", 2.0)), depth * 0.6)
	if bool(model.get("ok", false)):
		var tr := ctx.frame(z, x, 0.0).scaled_local(Vector3(1.0, hgt / PYLON_MODEL_H, 1.0))
		out.append({"t": tr, "mirror": side < 0})
	else:
		# without the model: Arcade's procedural pylon (RoadRenderer._pylon) – a tapered column 3.6 → 2.2 m
		_column(sb, ctx, z, cx, 0.0, hgt, 3.6, 2.2, concrete)
	# cap and beacon mast on the top (Arcade: a block from hgt to hgt + 1.6, the light on it)
	_box(sb, ctx, z, cx, hgt - 0.6, hgt + PYLON_CAP_H, PYLON_CAP_W, PYLON_CAP_W, concrete.darkened(0.2))
	# the foundation in the water and a cross beam under the deck towards the road
	_box(sb, ctx, z, cx, -depth - 1.0, -0.05, PYLON_BASE.x, PYLON_BASE.y, concrete.darkened(0.12))
	_box_span(sb, ctx, z, 0.0, cx, -deck - 1.4, -deck + 0.05, 2.4, concrete.darkened(0.18))
	var top := ctx.local(z, cx, hgt + PYLON_CAP_H + 0.12)
	lamps.append({"pos": top, "dir": ctx.rows_r[clampi(int(ctx.row_of(z)), 0, ctx.row_count() - 1)] * -s, "role": "lights",
		"color": BEACON_COLOR, "size": BEACON_SIZE, "range": 0.0, "energy": BEACON_ENERGY,
		"blink": Vector3(PYLON_BLINK.x, PYLON_BLINK.y, s * PYLON_BLINK.z)})
	counts["pylons"] += 1


## The overhead portal of a truss bridge: props/bridge_truss_arch scaled to the deck (fit_w), its lamps.
func _portal(sb: Buf, ctx: ChunkContext, it: Dictionary, br: Dictionary, model: Dictionary, out: Array, lamps: Array, counts: Dictionary) -> void:
	var z := float(it.get("z", 0.0))
	var fit := float(it.get("fit_w", 16.0))
	var sc := fit / maxf(0.5, float(model.get("width", 32.4)))
	if bool(model.get("ok", false)):
		var tr := ctx.frame(z, 0.0, 0.0).scaled_local(Vector3(sc, sc, sc))
		out.append({"t": tr, "mirror": false})
		_model_lamps(model, tr, false, lamps)
	else:
		# Arcade's procedural portal: legs at the deck edges, an arch over the deck (RoadRenderer._truss_portal)
		var hw := fit * 0.5 - 0.4
		var col: Color = br.get("rail", Color("4f6b55"))
		for sd: float in [-1.0, 1.0]:
			sb.member(ctx.local(z, sd * hw, 0.0), ctx.local(z, sd * hw, 6.4), 0.75, 0.75, Vector3.FORWARD, col, ROUGH_STEEL)
		var n := 12
		for q in n:
			var t0 := float(q) / float(n)
			var t1 := float(q + 1) / float(n)
			sb.member(ctx.local(z, lerpf(-hw, hw, t0), 6.4 + 7.6 * sin(t0 * PI)), ctx.local(z, lerpf(-hw, hw, t1), 6.4 + 7.6 * sin(t1 * PI)),
				0.85, 0.85, Vector3.FORWARD, col, ROUGH_STEEL)
	counts["portals"] += 1


## An ornamental bridge lamp (stone bridges, causeways): props/bridge_lamp, mirrored on the left like the props builder
## did; its lamps light pools and glow (A-7).
func _lamp(sb: Buf, ctx: ChunkContext, it: Dictionary, model: Dictionary, out: Array, lamps: Array, counts: Dictionary) -> void:
	var side := int(it.get("side", 1))
	var z := float(it.get("z", 0.0))
	var x := float(it.get("x", 0.0))
	var tr := ctx.frame(z, x, 0.0)
	if bool(model.get("ok", false)):
		out.append({"t": tr, "mirror": side < 0})
		_model_lamps(model, tr, side < 0, lamps)
	else:
		var post := Color("2e3833")
		sb.member(ctx.local(z, x, 0.0), ctx.local(z, x, 4.4), 0.2, 0.2, Vector3.FORWARD, post, ROUGH_STEEL, true)
		lamps.append({"pos": ctx.local(z, x, 4.75), "dir": Vector3.DOWN, "role": "lights", "color": Color(1.0, 0.93, 0.72), "size": 0.3,
			"range": LAMP_RANGE_M, "energy": LAMP_ENERGY})
	counts["lamps"] += 1


## The lamps of a placed model as A-7 lamp entries (chunk-local): pools for lamps that look down (a group shares
## GROUP_ENERGY, PropLibrary.lamp_pools), none for the rest.
static func _model_lamps(model: Dictionary, tr: Transform3D, mirrored: bool, lamps: Array) -> void:
	var list: Array = model.get("lamps", [])
	var down := 0
	for l: Dictionary in list:
		if (l["dir"] as Vector3).y < -0.5:
			down += 1
	for l: Dictionary in list:
		var lp: Vector3 = l["pos"]
		var ld: Vector3 = l["dir"]
		if mirrored:
			lp.x = -lp.x
			ld.x = -ld.x
		var e := {"pos": tr * lp, "dir": (tr.basis * ld).normalized(), "role": str(l["role"]), "color": l["color"],
			"size": float(l["size"]) * tr.basis.get_scale().x, "range": 0.0, "energy": LAMP_ENERGY}
		if ld.y < -0.5:
			e["range"] = LAMP_RANGE_M
			e["energy"] = minf(LAMP_ENERGY, GROUP_ENERGY / float(maxi(down, 1)))
		lamps.append(e)


## A tapered column (stand-in pylon) at road position z, lateral x, from h0 to h1, width w0 at the foot, w1 at the top.
func _column(sb: Buf, ctx: ChunkContext, z: float, x: float, h0: float, h1: float, w0: float, w1: float, col: Color) -> void:
	var f := ctx.rows_f[clampi(int(ctx.row_of(z)), 0, ctx.row_count() - 1)]
	var r := ctx.rows_r[clampi(int(ctx.row_of(z)), 0, ctx.row_count() - 1)]
	var c0 := ctx.local(z, x, h0)
	var c1 := ctx.local(z, x, h1)
	var a := [r * w0 * 0.5 + f * w0 * 0.5, -r * w0 * 0.5 + f * w0 * 0.5, -r * w0 * 0.5 - f * w0 * 0.5, r * w0 * 0.5 - f * w0 * 0.5]
	var b := [r * w1 * 0.5 + f * w1 * 0.5, -r * w1 * 0.5 + f * w1 * 0.5, -r * w1 * 0.5 - f * w1 * 0.5, r * w1 * 0.5 - f * w1 * 0.5]
	for q in 4:
		var q1 := (q + 1) % 4
		var mid: Vector3 = (a[q] + a[q1]) * 0.5
		sb.squad(c0 + a[q], c1 + b[q], c1 + b[q1], c0 + a[q1], mid, col, ROUGH_CONCRETE)


## An upright box at road position z, lateral x (centre), from h0 to h1, w across, l along the road.
func _box(sb: Buf, ctx: ChunkContext, z: float, x: float, h0: float, h1: float, w: float, l: float, col: Color) -> void:
	sb.member(ctx.local(z - l * 0.5, x, (h0 + h1) * 0.5), ctx.local(z + l * 0.5, x, (h0 + h1) * 0.5), w, h1 - h0, Vector3.UP, col, ROUGH_CONCRETE, true)


## A beam across the road at z from lateral x0 to x1, from h0 to h1, l thick along the road.
func _box_span(sb: Buf, ctx: ChunkContext, z: float, x0: float, x1: float, h0: float, h1: float, l: float, col: Color) -> void:
	sb.member(ctx.local(z, x0, (h0 + h1) * 0.5), ctx.local(z, x1, (h0 + h1) * 0.5), l, h1 - h0, Vector3.UP, col, ROUGH_CONCRETE, true)


## Main thread: water and banks with the water material (render layer 2), the structure in vpbr (static), the part
## models as MultiMesh nodes (mirrored nodes for the left side, D24), the lamps to the renderer.
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	if part.is_empty():
		return
	var materials: Variant = ctx.services.get("materials")
	if not (materials is ModernMaterials):
		materials = ModernMaterials.shared()
	var mats := materials as ModernMaterials
	var casts := _casters >= 1
	var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.name = "Bridge"
	parent.add_child(holder)
	var water: Array = part.get("water", [])
	if not water.is_empty():
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, water, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		var mi := MeshInstance3D.new()
		mi.name = "Water"
		mi.mesh = mesh
		mi.material_override = get_water_material(mats)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = GROUND_LAYERS
		holder.add_child(mi)
	var st: Array = part.get("struct", [])
	if not st.is_empty():
		var smesh := ArrayMesh.new()
		smesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st)
		var si := MeshInstance3D.new()
		si.name = "Structure"
		si.mesh = smesh
		si.material_override = mats.material(ModernMaterials.VPBR_STATIC)
		si.cast_shadow = shadow
		holder.add_child(si)
	_add_models(holder, part.get("pylons", []), PYLON_SET, true, shadow)
	_add_models(holder, part.get("portals", []), PORTAL_SET, false, shadow)
	_add_models(holder, part.get("lamp_models", []), LAMP_SET, false,
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _casters >= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var lamps: Array = part.get("lamps", [])
	var renderer: Variant = ctx.services.get("renderer")
	if renderer != null and not lamps.is_empty() and (renderer as Object).has_method(&"add_lamps"):
		(renderer as Object).call(&"add_lamps", holder, lamps)
	var c: Dictionary = part.get("counts", {})
	_stats["chunks"] += 1
	for k: String in ["water_quads", "bank_quads", "pylons", "cables", "portals", "lamps"]:
		_stats[k] += int(c.get(k, 0))


## MultiMesh nodes of a part model: one for the right side, one mirrored node for the left (D24).
func _add_models(holder: Node3D, list: Array, set_id: String, dark: bool, shadow: GeometryInstance3D.ShadowCastingSetting) -> void:
	if list.is_empty():
		return
	var parts := _parts(set_id)
	if parts.is_empty():
		return
	for mirrored: bool in [false, true]:
		var ts: Array[Transform3D] = []
		for e: Dictionary in list:
			if bool(e["mirror"]) == mirrored:
				ts.append(mirror_x(e["t"]) if mirrored else (e["t"] as Transform3D))
		if ts.is_empty():
			continue
		for p: Variant in parts:
			var mp: Dictionary = p
			if bool(mp.get("shadow", false)):
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mp["mesh"]
			mm.instance_count = ts.size()
			var own: Transform3D = mp.get("transform", Transform3D.IDENTITY)
			for q in ts.size():
				mm.set_instance_transform(q, ts[q] * own)
			var node := MultiMeshInstance3D.new()
			node.name = set_id.get_file() + ("_l" if mirrored else "_r")
			node.multimesh = mm
			node.cast_shadow = shadow
			if mirrored:
				node.basis = Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
			if dark:
				_dark_override(node, mp)
			holder.add_child(node)


## The mirror image of a transform in the plane x = 0 (inside a node mirrored in x, D24; builders/props.gd mirror_x).
static func mirror_x(t: Transform3D) -> Transform3D:
	var b := t.basis
	return Transform3D(Basis(Vector3(b.x.x, -b.x.y, -b.x.z), Vector3(-b.y.x, b.y.y, b.y.z), Vector3(-b.z.x, b.z.y, b.z.z)),
		Vector3(-t.origin.x, t.origin.y, t.origin.z))


## M2ZS1, carried over unchanged (builders/props.gd _dark_model_override): the pylon model's one surface material
## (baked.gdshader) duplicated without the night atlas (emit_energy 0) and with night_albedo PYLON_NIGHT_ALBEDO –
## Arcade's procedural pylon is concrete × ambient light at night. Same shader, no new variant.
func _dark_override(node: GeometryInstance3D, part: Dictionary) -> void:
	var mesh: Variant = part.get("mesh")
	if not (mesh is Mesh) or (mesh as Mesh).get_surface_count() != 1:
		return
	var src := (mesh as Mesh).surface_get_material(0)
	if not (src is ShaderMaterial):
		return
	var key := "model%d" % src.get_instance_id()
	var m: Variant = _dark_mats.get(key)
	if m == null:
		var dup := (src as ShaderMaterial).duplicate() as ShaderMaterial
		dup.set_shader_parameter("emit_energy", 0.0)
		dup.set_shader_parameter("night_albedo", PYLON_NIGHT_ALBEDO)
		_dark_mats[key] = dup
		m = dup
	node.material_override = m


## Shader variants behind the loading picture: the water material, the structure, every part model as committed.
func warmup_nodes() -> Array:
	if not _has_bridges:
		return []
	var out: Array = []
	var w := MeshInstance3D.new()
	var b := Buf.new()
	b.custom = true
	b.quad(Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3.UP, Color("4b6878"),
		[Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [Vector2(0, 5), Vector2(0, 5), Vector2(0, 5), Vector2(0, 5)], Vector2(1, 0))
	var wm := ArrayMesh.new()
	wm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.arrays(), [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	w.mesh = wm
	w.material_override = get_water_material()
	w.layers = GROUND_LAYERS
	out.append(w)
	var sbuf := Buf.new()
	sbuf.squad(Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0), Vector3.BACK, Color.GRAY, ROUGH_CONCRETE)
	var sm := ArrayMesh.new()
	sm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sbuf.arrays())
	var s := MeshInstance3D.new()
	s.mesh = sm
	s.material_override = _mats().material(ModernMaterials.VPBR_STATIC)
	out.append(s)
	for set_id: String in _models_wanted:
		var holder := Node3D.new()
		_add_models(holder, [{"t": Transform3D.IDENTITY.scaled(Vector3(0.05, 0.05, 0.05)), "mirror": false}], set_id, set_id == PYLON_SET,
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		if holder.get_child_count() > 0:
			out.append(holder)
		else:
			holder.free()
	return out


func snapshot() -> Dictionary:
	return {"bridges": _stats.duplicate()}


func debug(part: Dictionary) -> Dictionary:
	var c: Dictionary = part.get("counts", {})
	var out := c.duplicate()
	out["water_tris"] = int(part.get("water_tris", 0))
	out["struct_tris"] = int(part.get("struct_tris", 0))
	out["pylon_models"] = (part.get("pylons", []) as Array).size()
	out["portal_models"] = (part.get("portals", []) as Array).size()
	out["lamp_models"] = (part.get("lamp_models", []) as Array).size()
	out["lamp_entries"] = (part.get("lamps", []) as Array).size()
	return out
