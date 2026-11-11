extends ChunkBuilder
## Gantry builder of the mode "Modern" (v0.8.0) – FIX1 after the QA of M1 (finding QB-04: the start and finish
## gantries were missing, the end of the test stage looked empty): Arcade's two gantries (SignPainter._gantry, frozen)
## as simple geometry until the structures package of M2 (R6) builds the real ones. They come from the sign items of
## the Track with side 0 ("start" at 14 m, "finish" at the finish line – the signs builder leaves them to this one):
##  * two steel posts 0.45 m wide just outside the road edges (incl. the shoulders), 7 m high;
##  * the banner across from 5.4 to 7 m: "finish" red with Arcade's checkered strips at its top and bottom and the
##    item's text ("ZIEL") in white, "start" dark with a light stripe, "START" and three countdown lamps – red while
##    the countdown runs (one more each second), all green at the start (view.countdown); they glow through the
##    flare layer (renderer.add_lamps(), role "on", colour and strength set every frame).
## Lettering: Label3D in Arcade's sign font (the bold fallback font of SignPainter). Material of the rest: "vpbr".
## Builder rules: build() runs on worker threads – ctx snapshot arrays only; every position from ctx.local().
## Owner: FIX1 for M1; R6 takes it over in M2. Docs: docs/renderer-modern.md §14.

const TOP := 7.0
const BANNER_H := 1.6
const POST_W := 0.45
const DEPTH := 0.3                 ## banner and posts, along the road
const STEEL := Color("c9ccd1")
const FINISH_RED := Color("c81e1e")
const START_DARK := Color("1b1f2a")
const START_STRIPE := Color("e8e8e8")
const CHECKER_H := 0.22
const LIGHT_RED := Color("ff2a1a")
const LIGHT_GREEN := Color("35ff55")
const LIGHT_OFF := Color("3a1010")
const ROUGH_METAL := Vector2(0.45, 0.5)
const ROUGH_PAINT := Vector2(0.6, 0.0)

var _font: FontVariation
var _lights: Array = []            ## [[MeshInstance3D, StandardMaterial3D, lamp dictionary, index], …] of start gantries


class Buf extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color, rm: Vector2) -> void:
		var nn := (b - a).cross(d - a)
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
			uv2.append(Vector2(-1.0, 0.0))
		if (c - a).cross(b - a).dot(nn) >= 0.0:
			idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
		else:
			idx.append_array(PackedInt32Array([o, o + 2, o + 1, o, o + 3, o + 2]))

	## Box in a road frame (x right, y up, z back towards the camera): centre c, half extents e.
	func box(f: Transform3D, c: Vector3, e: Vector3, colour: Color, rm: Vector2) -> void:
		var bx := f.basis.x
		var by := f.basis.y
		var bz := f.basis.z
		var o := f * c
		var corners: Array[Vector3] = []
		for k in 8:
			corners.append(o + bx * (e.x if (k & 1) != 0 else -e.x) + by * (e.y if (k & 2) != 0 else -e.y) + bz * (e.z if (k & 4) != 0 else -e.z))
		quad(corners[4], corners[5], corners[7], corners[6], bz, colour, rm)      # back towards the camera (+z)
		quad(corners[0], corners[1], corners[3], corners[2], -bz, colour, rm)     # far side
		quad(corners[0], corners[4], corners[6], corners[2], -bx, colour, rm)
		quad(corners[1], corners[5], corners[7], corners[3], bx, colour, rm)
		quad(corners[2], corners[3], corners[7], corners[6], by, colour, rm)
		quad(corners[0], corners[1], corners[5], corners[4], -by, colour, rm)

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
	return "gantry"


## WORKER THREAD.
func build(ctx: ChunkContext, _input: Variant) -> Dictionary:
	var buf := Buf.new()
	var gantries: Array = []
	var rows := ctx.row_count()
	for i in rows - 1:
		var seg: Dictionary = ctx.segs[i]
		for it: Dictionary in seg["sprites"]:
			if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) != 0:
				continue
			var kind := str(it.get("sign", ""))
			if kind != "start" and kind != "finish":
				continue
			var z := float(it.get("z", seg.get("z", 0.0)))
			var row := clampi(int(floor(ctx.row_of(z))), 0, rows - 1)
			var left := -ctx.shoulder_edge(row, -1)
			var right := ctx.shoulder_edge(row, 1)
			var f := ctx.frame(z, 0.0, 0.0)
			var half := (right - left) * 0.5 + POST_W
			var cx := (left + right) * 0.5
			# posts outside the road edges, a little into the ground
			buf.box(f, Vector3(left - POST_W * 0.5, (TOP - 0.3) * 0.5, 0.0), Vector3(POST_W * 0.5, (TOP + 0.3) * 0.5, DEPTH * 0.5), STEEL, ROUGH_METAL)
			buf.box(f, Vector3(right + POST_W * 0.5, (TOP - 0.3) * 0.5, 0.0), Vector3(POST_W * 0.5, (TOP + 0.3) * 0.5, DEPTH * 0.5), STEEL, ROUGH_METAL)
			# the banner
			var colour := FINISH_RED if kind == "finish" else START_DARK
			buf.box(f, Vector3(cx, TOP - BANNER_H * 0.5, 0.0), Vector3(half, BANNER_H * 0.5, DEPTH * 0.5), colour, ROUGH_PAINT)
			var front := DEPTH * 0.5 + 0.005
			if kind == "finish":
				# Arcade's checkered strips at the top and the bottom of the banner (cells of about 0.5 m)
				var w := half * 2.0
				var cells := clampi(int(w / 0.5), 4, 64)
				var cw := w / float(cells)
				for k in cells:
					var x0 := cx - half + cw * float(k)
					var top_c := Color.WHITE if k % 2 == 0 else Color.BLACK
					var bot_c := Color.BLACK if k % 2 == 0 else Color.WHITE
					_face(buf, f, x0, x0 + cw, TOP - CHECKER_H, TOP, front, top_c)
					_face(buf, f, x0, x0 + cw, TOP - BANNER_H, TOP - BANNER_H + CHECKER_H, front, bot_c)
			else:
				_face(buf, f, cx - half, cx + half, TOP - BANNER_H, TOP - BANNER_H + 0.12, front, START_STRIPE)
			gantries.append({"kind": kind, "text": str(it.get("text", "ZIEL")), "frame": f, "cx": cx, "front": front})
	if gantries.is_empty():
		return {}
	return {"arrays": buf.arrays(), "gantries": gantries, "triangles": buf.idx.size() / 3}


## A flat coloured face on the front of the banner (towards the approaching camera), x0..x1, h0..h1.
static func _face(buf: Buf, f: Transform3D, x0: float, x1: float, h0: float, h1: float, front: float, colour: Color) -> void:
	buf.quad(f * Vector3(x0, h0, front), f * Vector3(x1, h0, front), f * Vector3(x1, h1, front), f * Vector3(x0, h1, front), f.basis.z, colour,
		ROUGH_PAINT)


## Main thread: the mesh in vpbr, the lettering, the countdown lamps of a start gantry.
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var arrays: Array = part.get("arrays", [])
	if arrays.is_empty():
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Gantry"
	mi.mesh = mesh
	var materials: Variant = ctx.services.get("materials")
	if not (materials is ModernMaterials):
		materials = ModernMaterials.shared()
	mi.material_override = (materials as ModernMaterials).material("vpbr")
	var casts := int(ctx.levels.get("shadow_casters", 0)) >= 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var renderer: Variant = ctx.services.get("renderer")
	for g: Dictionary in part.get("gantries", []):
		var f: Transform3D = g["frame"]
		var cx := float(g["cx"])
		var front := float(g["front"]) + 0.01
		var finish := str(g["kind"]) == "finish"
		var label := Label3D.new()
		label.name = "GantryLettering"
		label.text = str(g["text"]) if finish else tr("START")
		label.font = _sign_font()
		label.font_size = 128
		label.pixel_size = 0.0092
		label.modulate = Color.WHITE
		label.shaded = false
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.transform = Transform3D(f.basis, f * Vector3(cx if finish else cx - 2.4, TOP - BANNER_H * 0.5, front))
		parent.add_child(label)
		if finish:
			continue
		# three countdown lamps right of the text (Arcade: 1.4 + i × 1.15 m from the middle, 0.8 m under the top)
		var lamps: Array = []
		for i in 3:
			var pos := f * Vector3(cx + 1.4 + float(i) * 1.15, TOP - 0.8, front)
			var rim := MeshInstance3D.new()
			var rim_mesh := CylinderMesh.new()
			rim_mesh.top_radius = 0.45
			rim_mesh.bottom_radius = 0.45
			rim_mesh.height = 0.04
			rim_mesh.radial_segments = 20
			rim.mesh = rim_mesh
			var rim_mat := StandardMaterial3D.new()
			rim_mat.albedo_color = Color(0.05, 0.05, 0.05)
			rim.material_override = rim_mat
			rim.transform = Transform3D(f.basis * Basis(Vector3.RIGHT, PI * 0.5), pos)
			parent.add_child(rim)
			var lamp := MeshInstance3D.new()
			var lamp_mesh := CylinderMesh.new()
			lamp_mesh.top_radius = 0.36
			lamp_mesh.bottom_radius = 0.36
			lamp_mesh.height = 0.06
			lamp_mesh.radial_segments = 20
			lamp.mesh = lamp_mesh
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = LIGHT_OFF
			lamp.material_override = mat
			lamp.transform = Transform3D(f.basis * Basis(Vector3.RIGHT, PI * 0.5), pos + f.basis.z * 0.01)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(lamp)
			var entry := {"pos": lamp.position + f.basis.z * 0.05, "dir": f.basis.z, "role": "on", "color": LIGHT_RED, "size": 0.9,
				"range": 0.0, "energy": 0.0}
			lamps.append(entry)
			_lights.append([lamp, mat, entry, i])
		if renderer != null:
			(renderer as Object).call(&"add_lamps", parent, lamps)


## Every frame (main thread): Arcade's countdown lamps – red while counting (one more each second), all green at the
## start (until two seconds after it), off before and later.
func update(view: Dictionary, _dt: float) -> void:
	if _lights.is_empty():
		return
	var cd := float(view.get("countdown", -1000.0))
	var on := 0 if cd <= 0.0 else clampi(4 - int(ceil(cd)), 1, 3)
	var i := _lights.size() - 1
	while i >= 0:
		var e: Array = _lights[i]
		if not is_instance_valid(e[0]):
			_lights.remove_at(i)
			i -= 1
			continue
		var k := int(e[3])
		var col := LIGHT_OFF
		var glow := 0.0
		if cd <= 0.0 and cd > -2.0:
			col = LIGHT_GREEN
			glow = 1.0
		elif cd > 0.0 and k < on:
			col = LIGHT_RED
			glow = 1.0
		(e[1] as StandardMaterial3D).albedo_color = col
		var entry: Dictionary = e[2]
		entry["color"] = col
		entry["energy"] = glow
		i -= 1


## Arcade's sign font: the engine's fallback font, emboldened (SignPainter.setup).
func _sign_font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 0.55
	return _font


func debug(part: Dictionary) -> Dictionary:
	var kinds: Array = []
	for g: Dictionary in part.get("gantries", []):
		kinds.append(str(g["kind"]))
	return {"gantries": kinds, "triangles": int(part.get("triangles", 0))}
