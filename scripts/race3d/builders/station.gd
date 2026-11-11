extends ChunkBuilder
## Fuel station builder of the mode "Modern" (v0.8.0) – FIX1 after the QA of M1 (finding QB-02: at the tutorial's
## fuel stop of Kiel – Hamburg the pumps stood in the grass, no canopy, no island): a MINIMAL station in Arcade's
## shapes and colours (RoadRenderer._fuel_structures, frozen) until the structures package of M2 (R6) builds the real
## one (shop, price pylon, canopy details). Per segment of the fuel zone (TrackSegment.fuel_zone):
##  * FUEL_ISLAND: the pump island beside the fuel lane – 0.18 m high from 0.35 to 2.3 m beyond the paved edge, its
##    yellow kerb facing the fuel lane (the yellow line of Arcade's picture);
##  * FUEL_CANOPY: the canopy over the island and half the fuel lane – underside at 5.6 m from 0.5 m inside the
##    paved edge to 4.6 m beyond it, a red and a white band along the road side, a roof on top; two lamps under it
##    every second segment (lit at night through lamp channel 12, glowing and lighting the forecourt through
##    renderer.add_lamps(): role "canopy" with a light pool); pillars on the island at its front, every 15 m and at
##    its end;
##  * FUEL_CANOPY_FRONT: the fascia across the front of the canopy – white with a red band – with Arcade's lettering
##    "TANKSTELLE" (Label3D in Arcade's sign font, the bold fallback font of SignPainter).
## Material: the class "vpbr" (vertex colours, lit); the lettering is unshaded like Arcade's sign text.
## Builder rules: build() runs on worker threads – ctx snapshot arrays only; every position from ctx.local().
## Owner: FIX1 for M1; R6 takes it over in M2. Docs: docs/renderer-modern.md §14.

const ISLAND_H := 0.18
const ISLAND_IN := 0.35            ## island from this far beyond the paved edge …
const ISLAND_OUT := 2.3            ## … to this far
const CANOPY_H := 5.6              ## underside of the canopy
const CANOPY_IN := -0.5            ## canopy from 0.5 m inside the paved edge …
const CANOPY_OUT := 4.6            ## … to 4.6 m beyond it
const BAND_RED := 0.35             ## red band above the underside …
const BAND_WHITE := 0.5            ## … and the white one above it (Arcade: 5.6–5.95, 5.95–6.45)
const PILLAR_X := 1.3              ## pillars on the island, this far beyond the paved edge
const PILLAR_W := 0.3
const PILLAR_EVERY := 5            ## segments between pillars under a long canopy
const LAMP_X: Array[float] = [0.8, 2.8]
const ISLAND_TOP := Color("c9c6bd")
const KERB := Color("e0c030")
const UNDERSIDE := Color("9a9c9b")
const EDGE := Color("6f7170")
const RED := Color("c8102e")
const WHITE := Color("f2f2f0")
const PILLAR := Color("d0d0cc")
const LAMP := Color(1.0, 1.0, 0.96)
const TEXT := Color("1d4f9c")
const ROUGH_PAINT := Vector2(0.55, 0.0)
const ROUGH_CONCRETE := Vector2(0.85, 0.0)
const ROUGH_METAL := Vector2(0.45, 0.4)
const LAMP_RANGE_M := 7.0          ## light pool of a canopy lamp …
const LAMP_ENERGY := 0.3           ## … and its energy (Arcade's canopy glow over a lit forecourt)

var _font: FontVariation


## Vertex arrays of one chunk while it is built (vpbr format: COLOR, UV = roughness/metallic, UV2 = lamp channel).
class Buf extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color, rm: Vector2, lamp: Vector2 = Vector2(-1.0, 0.0)) -> void:
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
			uv.append(rm)
			uv2.append(lamp)
		if (c - a).cross(b - a).dot(nn) >= 0.0:
			idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
		else:
			idx.append_array(PackedInt32Array([o, o + 2, o + 1, o, o + 3, o + 2]))

	## A box between two road rows: lateral x0..x1, heights h0..h1, from z0 to z1 (all faces, normals outwards).
	func box(ctx: ChunkContext, z0: float, z1: float, x0: float, x1: float, h0: float, h1: float, colour: Color, rm: Vector2,
			faces: int = 63) -> void:
		var p000 := ctx.local(z0, x0, h0)
		var p100 := ctx.local(z0, x1, h0)
		var p010 := ctx.local(z0, x0, h1)
		var p110 := ctx.local(z0, x1, h1)
		var p001 := ctx.local(z1, x0, h0)
		var p101 := ctx.local(z1, x1, h0)
		var p011 := ctx.local(z1, x0, h1)
		var p111 := ctx.local(z1, x1, h1)
		var c := (p000 + p111) * 0.5
		if (faces & 1) != 0:    # near end (towards the approaching camera)
			quad(p000, p100, p110, p010, (p000 + p110) * 0.5 - c, colour, rm)
		if (faces & 2) != 0:    # far end
			quad(p001, p101, p111, p011, (p001 + p111) * 0.5 - c, colour, rm)
		if (faces & 4) != 0:    # left side
			quad(p000, p001, p011, p010, (p000 + p011) * 0.5 - c, colour, rm)
		if (faces & 8) != 0:    # right side
			quad(p100, p101, p111, p110, (p100 + p111) * 0.5 - c, colour, rm)
		if (faces & 16) != 0:   # top
			quad(p010, p110, p111, p011, Vector3.UP, colour, rm)
		if (faces & 32) != 0:   # bottom
			quad(p000, p100, p101, p001, Vector3.DOWN, colour, rm)

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
	return "station"


## WORKER THREAD.
func build(ctx: ChunkContext, _input: Variant) -> Dictionary:
	var buf := Buf.new()
	var rows := ctx.row_count()
	var seg_len := ctx.seg_len
	var lamps: Array = []
	var fronts: Array = []
	var islands := 0
	var canopies := 0
	for i in rows - 1:
		var sa: Dictionary = ctx.segs[i]
		var fz := int(sa["fuel_zone"])
		if fz == 0 or bool(sa["tunnel"]):
			continue
		var sb: Dictionary = ctx.segs[i + 1]
		var z0 := float(ctx.seg_a + i) * seg_len
		var z1 := z0 + seg_len
		var ea := ctx.rows_edge[i].y          # paved right edge incl. the fuel lane
		var eb := ctx.rows_edge[i + 1].y
		var e := (ea + eb) * 0.5
		var next_fz := int(sb["fuel_zone"])
		var prev_fz := int(ctx.segs[i - 1]["fuel_zone"]) if i > 0 else -1
		if (fz & TrackSegment.FUEL_ISLAND) != 0:
			islands += 1
			var near_end := 1 if prev_fz < 0 or (prev_fz & TrackSegment.FUEL_ISLAND) == 0 else 0
			var far_end := 2 if (next_fz & TrackSegment.FUEL_ISLAND) == 0 else 0
			# the island: top and far side grey, the kerb towards the fuel lane yellow
			buf.box(ctx, z0, z1, e + ISLAND_IN, e + ISLAND_OUT, -0.05, ISLAND_H, ISLAND_TOP, ROUGH_CONCRETE, 16 | 8 | near_end | far_end)
			buf.quad(ctx.local(z0, e + ISLAND_IN, -0.05), ctx.local(z1, e + ISLAND_IN, -0.05), ctx.local(z1, e + ISLAND_IN, ISLAND_H),
				ctx.local(z0, e + ISLAND_IN, ISLAND_H), -ctx.rows_r[i], KERB, ROUGH_PAINT)
		if (fz & TrackSegment.FUEL_CANOPY) != 0:
			canopies += 1
			var x0 := e + CANOPY_IN
			var x1 := e + CANOPY_OUT
			var h1 := CANOPY_H + BAND_RED + BAND_WHITE
			var starts := (fz & TrackSegment.FUEL_CANOPY_FRONT) != 0
			var ends := (next_fz & TrackSegment.FUEL_CANOPY) == 0
			# underside, roof, the far side white; the road side red under white
			buf.quad(ctx.local(z0, x0, CANOPY_H), ctx.local(z1, x0, CANOPY_H), ctx.local(z1, x1, CANOPY_H), ctx.local(z0, x1, CANOPY_H),
				Vector3.DOWN, UNDERSIDE, ROUGH_PAINT)
			buf.quad(ctx.local(z0, x0, CANOPY_H - 0.01), ctx.local(z1, x0, CANOPY_H - 0.01), ctx.local(z1, x0 + 0.6, CANOPY_H - 0.01),
				ctx.local(z0, x0 + 0.6, CANOPY_H - 0.01), Vector3.DOWN, EDGE, ROUGH_PAINT)
			buf.quad(ctx.local(z0, x0, h1), ctx.local(z1, x0, h1), ctx.local(z1, x1, h1), ctx.local(z0, x1, h1), Vector3.UP, UNDERSIDE.lightened(0.15),
				ROUGH_PAINT)
			var road_side := -ctx.rows_r[i]
			buf.quad(ctx.local(z0, x0, CANOPY_H), ctx.local(z1, x0, CANOPY_H), ctx.local(z1, x0, CANOPY_H + BAND_RED),
				ctx.local(z0, x0, CANOPY_H + BAND_RED), road_side, RED, ROUGH_PAINT)
			buf.quad(ctx.local(z0, x0, CANOPY_H + BAND_RED), ctx.local(z1, x0, CANOPY_H + BAND_RED), ctx.local(z1, x0, h1), ctx.local(z0, x0, h1),
				road_side, WHITE, ROUGH_PAINT)
			buf.quad(ctx.local(z0, x1, CANOPY_H), ctx.local(z1, x1, CANOPY_H), ctx.local(z1, x1, h1), ctx.local(z0, x1, h1), -road_side, WHITE,
				ROUGH_PAINT)
			if starts:
				# the fascia across the front: white with the red band at its foot (the lettering is a Label3D, commit())
				var fwd := ctx.rows_f[i]
				buf.quad(ctx.local(z0, x0, CANOPY_H), ctx.local(z0, x1, CANOPY_H), ctx.local(z0, x1, CANOPY_H + BAND_RED),
					ctx.local(z0, x0, CANOPY_H + BAND_RED), -fwd, RED, ROUGH_PAINT)
				buf.quad(ctx.local(z0, x0, CANOPY_H + BAND_RED), ctx.local(z0, x1, CANOPY_H + BAND_RED), ctx.local(z0, x1, h1), ctx.local(z0, x0, h1),
					-fwd, WHITE, ROUGH_PAINT)
				fronts.append({"frame": ctx.frame(z0, (x0 + x1) * 0.5, CANOPY_H + BAND_RED + BAND_WHITE * 0.5), "width": x1 - x0})
			if ends:
				var fwd2 := ctx.rows_f[i + 1]
				buf.quad(ctx.local(z1, x0, CANOPY_H), ctx.local(z1, x1, CANOPY_H), ctx.local(z1, x1, h1), ctx.local(z1, x0, h1), fwd2, WHITE,
					ROUGH_PAINT)
			# pillars on the island: at the front, every PILLAR_EVERY segments, at the end
			if starts or ends or int(sa["index"]) % PILLAR_EVERY == 0:
				var zp := z0 + 0.4 if starts else (z1 - 0.4 if ends else z0)
				buf.box(ctx, zp - PILLAR_W * 0.5, zp + PILLAR_W * 0.5, e + PILLAR_X - PILLAR_W * 0.5, e + PILLAR_X + PILLAR_W * 0.5, 0.0,
					CANOPY_H, PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8)
			# two lamps under the canopy every second segment (Arcade), lit at night (lamp channel 12)
			if int(sa["index"]) % 2 == 0:
				var zl := z0 + seg_len * 0.5
				for lx: float in LAMP_X:
					var x := e + lx
					var hl := CANOPY_H - 0.02
					buf.quad(ctx.local(zl - 0.5, x - 0.18, hl), ctx.local(zl + 0.5, x - 0.18, hl), ctx.local(zl + 0.5, x + 0.18, hl),
						ctx.local(zl - 0.5, x + 0.18, hl), Vector3.DOWN, LAMP, Vector2(0.3, 0.0), Vector2(12.5, 1.0))
					lamps.append({"pos": ctx.local(zl, x, hl - 0.03), "dir": Vector3.DOWN, "role": "canopy", "color": Color(1.0, 0.97, 0.9),
						"size": 1.0, "range": LAMP_RANGE_M, "energy": LAMP_ENERGY})
	if buf.idx.is_empty():
		return {}
	return {"arrays": buf.arrays(), "lamps": lamps, "fronts": fronts, "islands": islands, "canopies": canopies,
		"triangles": buf.idx.size() / 3}


## Main thread: the mesh in vpbr, the lettering of each canopy front, the lamps to the lights and flare layers.
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var arrays: Array = part.get("arrays", [])
	if arrays.is_empty():
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Station"
	mi.mesh = mesh
	var materials: Variant = ctx.services.get("materials")
	if not (materials is ModernMaterials):
		materials = ModernMaterials.shared()
	mi.material_override = (materials as ModernMaterials).material("vpbr")
	var casts := int(ctx.levels.get("shadow_casters", 0)) >= 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	for f: Dictionary in part.get("fronts", []):
		var label := Label3D.new()
		label.name = "StationLettering"
		label.text = tr("TANKSTELLE")
		label.font = _sign_font()
		label.font_size = 96
		label.outline_size = 0
		label.pixel_size = 0.0045
		label.modulate = TEXT
		label.shaded = false
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.width = float(f["width"]) / label.pixel_size
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		# the frame looks along the road (-Z forward): the text faces +Z, the approaching camera, a little in front
		var tr3: Transform3D = f["frame"]
		label.transform = tr3.translated_local(Vector3(0.0, 0.0, 0.03))
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(label)
	var renderer: Variant = ctx.services.get("renderer")
	var lamps: Array = part.get("lamps", [])
	if renderer != null and not lamps.is_empty():
		(renderer as Object).call(&"add_lamps", mi, lamps)


## Arcade's sign font: the engine's fallback font, emboldened (SignPainter.setup).
func _sign_font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 0.55
	return _font


func debug(part: Dictionary) -> Dictionary:
	return {"islands": int(part.get("islands", 0)), "canopies": int(part.get("canopies", 0)), "fronts": (part.get("fronts", []) as Array).size(),
		"lamps": (part.get("lamps", []) as Array).size(), "triangles": int(part.get("triangles", 0))}
