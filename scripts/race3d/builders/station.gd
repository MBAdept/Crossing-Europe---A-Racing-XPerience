extends ChunkBuilder
## Fuel station builder of the mode "Modern" (v0.8.0, contract §6 R6, renderer inventory B): the structures Arcade draws
## beside a fuel lane (RoadRenderer._fuel_structures and _fuel_pylon, frozen) as real geometry, at Arcade's places and
## in Arcade's colours, with what a real station has on top. Per segment of the fuel zone (TrackSegment.fuel_zone):
##  * FUEL_ISLAND: the pump island – 0.18 m high from 0.35 to 2.3 m beyond the paved edge, its yellow kerb (face and
##    top edge) towards the fuel lane; behind it a concrete forecourt to 5.4 m (the canopy's ground) with a slab edge
##    down to the terrain;
##  * FUEL_CANOPY: the canopy over the island and half the fuel lane – soffit at 5.6 m from 0.5 m inside the paved
##    edge to 4.6 m beyond it with the dark edge strip of Arcade, fascia bands red / white on both long sides (lit
##    from inside at night: lamp channel 14), roof on top, light panels in the soffit every second segment (channel 12,
##    glowing and lighting the forecourt through renderer.add_lamps(): role "canopy" with a light pool); steel columns
##    with a plinth on the island at the front and at the end of every canopy;
##  * FUEL_CANOPY_FRONT: the front fascia – white over the red band with "TANKSTELLE" in Arcade's sign font and blue –
##    a panel of the stage's lettering atlas (PanelAtlas below, drawn once in prepare() by Arcade's SignPainter; never a
##    Label3D), backlit at night;
##  * the price pylon of the item "fuel_pylon" (Track: 60 % into the opening taper, 6.5 m beyond the paved edge): a
##    concrete footing, a steel pole and the board of Arcade's _fuel_pylon (blue, red header, the pump pictogram, the
##    prices "1,79" / "1,85") on both faces as a panel, its digits lit at night with Arcade's blue glow (flare).
## Pumps and the shop (props/fuel_pump, props/fuel_station) are models of the props builder (AS1b) at Arcade's places.
## Materials: vpbr for the structures – ModernMaterials.VPBR_STATIC (no instance uniforms: the shared shader buffer
## stays for the vehicles, M2INT); the panels in the class "baked" with the atlas as albedo and its night picture as
## emission. Shadows only with structure casters (levels.shadow_casters >= 1, „Schatten: Aus“ casts none).
## Fairness (F1/F7): the canopy keeps Arcade's lowest edge (5.6 m) and footprint, the columns stand on the island; the
## camera at 3.4 m looks under it at every car of the lane.
## Builder rules: build() runs on worker threads – ctx snapshot arrays and the plain tables of collect() only; every
## position from ctx.local() / ctx.frame().
## Shared with the other structure builders of R6 (border, city, gantry, radar): the inner classes Kit (vpbr vertex
## arrays), PanelBuf (panel quads) and PanelAtlas / PanelCanvas (pre-rendered lettering panels).
## Owner: R6 (wave 3). Docs: docs/renderer-modern-bauten.md.

const ISLAND_H := 0.18
const ISLAND_IN := 0.35            ## island from this far beyond the paved edge …
const ISLAND_OUT := 2.3            ## … to this far
const KERB_TOP_W := 0.12           ## painted top edge of the yellow kerb
const APRON_OUT := 5.4             ## concrete forecourt behind the island up to this far beyond the paved edge
const APRON_H := 0.03
const CANOPY_H := 5.6              ## underside of the canopy
const CANOPY_IN := -0.5            ## canopy from 0.5 m inside the paved edge …
const CANOPY_OUT := 4.6            ## … to 4.6 m beyond it
const BAND_RED := 0.35             ## red band above the underside …
const BAND_WHITE := 0.5            ## … and the white one above it (Arcade: 5.6–5.95, 5.95–6.45)
const EDGE_STRIP := 0.6            ## Arcade's dark strip along the road side of the underside
const PILLAR_X := 1.3              ## columns on the island, this far beyond the paved edge
const PILLAR_W := 0.3
const PLINTH_W := 0.46
const PLINTH_H := 0.32
const LAMP_X: Array[float] = [0.8, 2.8]
const LAMP_SIZE := Vector2(1.0, 0.36)   ## light panel in the soffit (along, across)
const PYLON_POLE_W := 0.36
const PYLON_BOARD := Vector3(2.2, 3.8, 0.32)   ## width, height, depth of the price board
const PYLON_BOARD_Y := 5.8         ## lower edge of the board above the road (Arcade: 5.8 – 9.6 m)
const PRICES: Array[String] = ["1,79", "1,85"]

const ISLAND_TOP := Color("c9c6bd")
const KERB := Color("e0c030")
const APRON := Color("b9b6ae")
const UNDERSIDE := Color("9a9c9b")
const EDGE := Color("6f7170")
const ROOF := Color("a9aaa8")
const RED := Color("c8102e")
const WHITE := Color("f2f2f0")
const PILLAR := Color("d0d0cc")
const PLINTH := Color("a7a49c")
const LAMP := Color(1.0, 1.0, 0.96)
const TEXT := Color("1d4f9c")
const BOARD_BLUE := Color("1d4f9c")
const POLE := Color("d9d9d6")
const ROUGH_PAINT := Vector2(0.55, 0.0)
const ROUGH_CONCRETE := Vector2(0.85, 0.0)
const ROUGH_METAL := Vector2(0.45, 0.4)
const NO_LAMP := Vector2(-1.0, 0.0)
const FASCIA_GLOW := Vector2(14.5, 0.22)   ## lamp channel 14 (flood): the fascia bands glow a little at night
## Light pool of a row of canopy lamps (one every 6 m on the lane edge): about the mean of Arcade's pools (0.8 × lights
## at the centre, radius 11 m, every 18 m; RoadRenderer._collect_static_lights) – 0.6 × 0.55 per pool, three of them
## overlap at every point of the lane
const LAMP_RANGE_M := 9.0
const LAMP_ENERGY := 0.6
## Arcade's glow round each canopy lamp (radius 1.8 m, colour (1, 0.97, 0.9), alpha 0.3): flare size × 0.9 = radius
const LAMP_GLOW := Color(1.0, 0.97, 0.9)
const LAMP_GLOW_SIZE := 2.0
const LAMP_GLOW_ENERGY := 0.6
const PYLON_GLOW := Color(0.5, 0.7, 1.0)   ## Arcade's glow round the lit price board (radius 2.6 m, alpha 0.25)
const PANEL_PPM := 96.0            ## lettering atlas: pixels per metre of the canopy front and the price board

var _renderer: Node                ## untyped: packages talk to each other through the facade only
var _mats: ModernMaterials
var _atlas := PanelAtlas.new()
var _panel_mat: ShaderMaterial
var _cast := false
var _prepared := false


# --- shared helpers of the R6 builders -----------------------------------------------------------------------------

## Vertex arrays in the vpbr format (docs/modelle.md §4.6.4): COLOR = sRGB albedo with paint code 1 (a fixed colour),
## UV = (roughness, metallic), UV2 = (lamp channel + 0.5, weight) or (-1, 0).
class Kit extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	## Quad a-b-c-d (a convex outline in order) with one normal, turned towards `toward`.
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
		var c4 := Color(colour.r, colour.g, colour.b, 1.0)
		for p: Vector3 in [a, b, c, d]:
			v.append(p)
			n.append(nn)
			col.append(c4)
			uv.append(rm)
			uv2.append(lamp)
		if (c - a).cross(b - a).dot(nn) >= 0.0:
			idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
		else:
			idx.append_array(PackedInt32Array([o, o + 2, o + 1, o, o + 3, o + 2]))

	## Box in a rigid frame f (x right, y up, z back towards the approaching camera): centre c, half extents e. Faces:
	## 1 back (+z, towards the camera), 2 front (-z), 4 left, 8 right, 16 top, 32 bottom.
	func box(f: Transform3D, c: Vector3, e: Vector3, colour: Color, rm: Vector2, faces: int = 63, lamp: Vector2 = Vector2(-1.0, 0.0)) -> void:
		var bx := f.basis.x
		var by := f.basis.y
		var bz := f.basis.z
		var o := f * c
		var k: Array[Vector3] = []
		for i in 8:
			k.append(o + bx * (e.x if (i & 1) != 0 else -e.x) + by * (e.y if (i & 2) != 0 else -e.y) + bz * (e.z if (i & 4) != 0 else -e.z))
		if (faces & 1) != 0:
			quad(k[4], k[5], k[7], k[6], bz, colour, rm, lamp)
		if (faces & 2) != 0:
			quad(k[0], k[1], k[3], k[2], -bz, colour, rm, lamp)
		if (faces & 4) != 0:
			quad(k[0], k[4], k[6], k[2], -bx, colour, rm, lamp)
		if (faces & 8) != 0:
			quad(k[1], k[5], k[7], k[3], bx, colour, rm, lamp)
		if (faces & 16) != 0:
			quad(k[2], k[3], k[7], k[6], by, colour, rm, lamp)
		if (faces & 32) != 0:
			quad(k[0], k[1], k[5], k[4], -by, colour, rm, lamp)

	## Box that follows the road between the road positions z0 and z1: lateral x0..x1, heights h0..h1 above the road
	## (faces as box(): 1 near end, 2 far end, 4 left, 8 right, 16 top, 32 bottom).
	func road_box(ctx: ChunkContext, z0: float, z1: float, x0: float, x1: float, h0: float, h1: float, colour: Color, rm: Vector2,
			faces: int = 63, lamp: Vector2 = Vector2(-1.0, 0.0)) -> void:
		var p000 := ctx.local(z0, x0, h0)
		var p100 := ctx.local(z0, x1, h0)
		var p010 := ctx.local(z0, x0, h1)
		var p110 := ctx.local(z0, x1, h1)
		var p001 := ctx.local(z1, x0, h0)
		var p101 := ctx.local(z1, x1, h0)
		var p011 := ctx.local(z1, x0, h1)
		var p111 := ctx.local(z1, x1, h1)
		var c := (p000 + p111) * 0.5
		if (faces & 1) != 0:
			quad(p000, p100, p110, p010, (p000 + p110) * 0.5 - c, colour, rm, lamp)
		if (faces & 2) != 0:
			quad(p001, p101, p111, p011, (p001 + p111) * 0.5 - c, colour, rm, lamp)
		if (faces & 4) != 0:
			quad(p000, p001, p011, p010, (p000 + p011) * 0.5 - c, colour, rm, lamp)
		if (faces & 8) != 0:
			quad(p100, p101, p111, p110, (p100 + p111) * 0.5 - c, colour, rm, lamp)
		if (faces & 16) != 0:
			quad(p010, p110, p111, p011, Vector3.UP, colour, rm, lamp)
		if (faces & 32) != 0:
			quad(p000, p100, p101, p001, Vector3.DOWN, colour, rm, lamp)

	## Triangle a-b-c with one normal, turned towards `toward`.
	func tri(a: Vector3, b: Vector3, c: Vector3, toward: Vector3, colour: Color, rm: Vector2, lamp: Vector2 = Vector2(-1.0, 0.0)) -> void:
		var nn := (b - a).cross(c - a)
		if nn.length_squared() < 1.0e-12:
			return
		nn = nn.normalized()
		if nn.dot(toward) < 0.0:
			nn = -nn
		var o := v.size()
		var c4 := Color(colour.r, colour.g, colour.b, 1.0)
		for p: Vector3 in [a, b, c]:
			v.append(p)
			n.append(nn)
			col.append(c4)
			uv.append(rm)
			uv2.append(lamp)
		if (c - a).cross(b - a).dot(nn) >= 0.0:
			idx.append_array(PackedInt32Array([o, o + 1, o + 2]))
		else:
			idx.append_array(PackedInt32Array([o, o + 2, o + 1]))

	## Upright prism (a round post with `sides` faces) in a frame: foot centre c, radius r, height h; top cap optional.
	func column(f: Transform3D, c: Vector3, r: float, h: float, sides: int, colour: Color, rm: Vector2, cap: bool = true,
			lamp: Vector2 = Vector2(-1.0, 0.0)) -> void:
		var o := f * c
		var up := f.basis.y.normalized() * h
		for i in sides:
			var a0 := TAU * float(i) / float(sides)
			var a1 := TAU * float(i + 1) / float(sides)
			var d0 := (f.basis.x * cos(a0) + f.basis.z * sin(a0)).normalized() * r
			var d1 := (f.basis.x * cos(a1) + f.basis.z * sin(a1)).normalized() * r
			quad(o + d0, o + d1, o + d1 + up, o + d0 + up, (d0 + d1) * 0.5, colour, rm, lamp)
			if cap:
				tri(o + up, o + up + d0, o + up + d1, f.basis.y, colour, rm, lamp)

	func is_empty() -> bool:
		return idx.is_empty()

	func triangles() -> int:
		return idx.size() / 3

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


## Panel quads of the lettering atlas (class "baked": UV = atlas coordinates).
class PanelBuf extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var count := 0

	## A panel seen from its front: a lower left, b lower right, c upper right, d upper left; `r` the atlas cell (texture y
	## runs downwards: the upper edge of the panel is r.position.y).
	func panel(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, r: Rect2) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length_squared() < 1.0e-12:
			return
		nn = nn.normalized()
		if nn.dot(toward) < 0.0:
			nn = -nn
		var o := v.size()
		v.append_array(PackedVector3Array([a, b, c, d]))
		for i in 4:
			n.append(nn)
		uv.append_array(PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.position.y),
			Vector2(r.position.x, r.position.y)]))
		if (c - a).cross(b - a).dot(nn) >= 0.0:
			idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
		else:
			idx.append_array(PackedInt32Array([o, o + 2, o + 1, o, o + 3, o + 2]))
		count += 1

	## A panel on the plane of a rigid frame: x0..x1 across, y0..y1 up, at depth z (+z towards the approaching camera);
	## `back` turns it round (seen from -z: x runs the other way).
	func framed(f: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, r: Rect2, back: bool = false) -> void:
		if back:
			panel(f * Vector3(x1, y0, z), f * Vector3(x0, y0, z), f * Vector3(x0, y1, z), f * Vector3(x1, y1, z), -f.basis.z, r)
		else:
			panel(f * Vector3(x0, y0, z), f * Vector3(x1, y0, z), f * Vector3(x1, y1, z), f * Vector3(x0, y1, z), f.basis.z, r)

	func is_empty() -> bool:
		return idx.is_empty()

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		return arr


## Lettering panels of a stage (contract: lettering through pre-rendered panels, never Label3D): every panel a builder
## needs is drawn ONCE in prepare() with Arcade's SignPainter (its sign font, its colours) into one SubViewport – the
## day picture in the upper half, the night picture (emission: what glows at night, black elsewhere) in the lower half –
## read back after two drawn frames and kept as two mipmapped ImageTextures with the same layout. Like SignAtlas: no
## SubViewport and no texture during the drive; headless (or without a holder in the tree) a placeholder atlas with the
## same cells. A spec: {"key", "w", "h" (m), "ppm" (pixels per metre), "draw": Callable(painter, batch, rect: Rect2,
## ppm: float, night: bool), "glow": bool (has a night picture)}.
class PanelAtlas extends RefCounted:
	const PAD := 8                 ## free pixels round every cell, filled with the cell's edge pixels (mipmaps)
	const MIN_W := 256
	const MAX_W := 2048

	var entries: Dictionary = {}       ## key -> Rect2: the cell in uv (0..1)
	var albedo: Texture2D
	var emission: Texture2D            ## null when no panel glows
	var size := Vector2i.ZERO          ## size of each of the two textures
	var ready := false
	var placeholder := false
	var textures_created := 0
	var viewports_created := 0

	var _jobs: Array = []              ## [key, spec, Rect2i cell]
	var _glows := false
	var _vp: SubViewport
	var _frame0 := 0

	## Lays the cells out and starts drawing (main thread). holder: a node in the scene tree for the SubViewport.
	func prepare(specs: Array, holder: Node) -> void:
		clear()
		var cells: Array = []
		var area := 0
		var widest := 0
		for s: Variant in specs:
			var sd: Dictionary = s
			var key := str(sd.get("key", ""))
			if key == "" or entries.has(key):
				continue
			var ppm := float(sd.get("ppm", 64.0))
			var px := Vector2i(maxi(4, int(ceil(float(sd.get("w", 1.0)) * ppm))), maxi(4, int(ceil(float(sd.get("h", 1.0)) * ppm))))
			px.x = mini(px.x, MAX_W - PAD * 2)
			entries[key] = Rect2()
			cells.append([key, sd, px])
			area += (px.x + PAD * 2) * (px.y + PAD * 2)
			widest = maxi(widest, px.x + PAD * 2)
			if bool(sd.get("glow", false)):
				_glows = true
		cells.sort_custom(func(a: Array, b: Array) -> bool: return (a[2] as Vector2i).y > (b[2] as Vector2i).y)
		var width := MIN_W
		while width < MAX_W and (width < widest or area > width * width / 2):
			width *= 2
		var x := PAD
		var y := PAD
		var shelf := 0
		for c: Array in cells:
			var px: Vector2i = c[2]
			if x + px.x + PAD > width:
				x = PAD
				y += shelf + PAD * 2
				shelf = 0
			_jobs.append([c[0], c[1], Rect2i(Vector2i(x, y), px)])
			x += px.x + PAD * 2
			shelf = maxi(shelf, px.y)
		size = Vector2i(width, maxi(16, y + shelf + PAD))
		for j: Array in _jobs:
			var cell: Rect2i = j[2]
			entries[j[0]] = Rect2(float(cell.position.x) / float(size.x), float(cell.position.y) / float(size.y),
				float(cell.size.x) / float(size.x), float(cell.size.y) / float(size.y))
		if _jobs.is_empty() or DisplayServer.get_name() == "headless" or holder == null or not holder.is_inside_tree():
			_make_placeholder()
			return
		_vp = SubViewport.new()
		_vp.name = "StructurePanels"
		_vp.size = Vector2i(size.x, size.y * (2 if _glows else 1))
		_vp.transparent_bg = true
		_vp.disable_3d = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewports_created += 1
		var canvas := PanelCanvas.new()
		canvas.jobs = _jobs
		canvas.night_offset = size.y if _glows else -1
		_vp.add_child(canvas)
		holder.add_child(_vp)
		_frame0 = Engine.get_frames_drawn()

	## Panels still to be drawn (0 = ready). Polled every frame of the preparation; reads the picture back once the
	## SubViewport has been drawn.
	func pending() -> int:
		if ready or _vp == null:
			return 0
		if not RenderingServer.render_loop_enabled:
			RenderingServer.force_draw(false)
		if Engine.get_frames_drawn() - _frame0 < 2:
			return _jobs.size()
		var img := _vp.get_texture().get_image()
		if img == null or img.is_empty():
			_make_placeholder()
		else:
			img.convert(Image.FORMAT_RGBA8)
			var day := img.get_region(Rect2i(0, 0, size.x, size.y))
			_bleed(day)
			day.generate_mipmaps()
			albedo = ImageTexture.create_from_image(day)
			textures_created += 1
			if _glows:
				var night := img.get_region(Rect2i(0, size.y, size.x, size.y))
				_bleed(night)
				night.generate_mipmaps()
				emission = ImageTexture.create_from_image(night)
				textures_created += 1
			ready = true
		_free_viewport()
		return 0

	## The cell of a panel (Rect2() when the atlas does not have it).
	func uv(key: String) -> Rect2:
		return entries.get(key, Rect2())

	func clear() -> void:
		_free_viewport()
		entries.clear()
		_jobs.clear()
		_glows = false
		albedo = null
		emission = null
		ready = false
		placeholder = false

	## Every cell's edge pixels repeated into its padding: the mipmaps of a panel do not take in its neighbours or the
	## empty background (a dark seam round a fascia far away).
	func _bleed(img: Image) -> void:
		for j: Array in _jobs:
			var c: Rect2i = j[2]
			var ext := PAD - 1
			var top := img.get_region(Rect2i(c.position.x, c.position.y, c.size.x, 1))
			var bottom := img.get_region(Rect2i(c.position.x, c.end.y - 1, c.size.x, 1))
			for k in range(1, ext + 1):
				img.blit_rect(top, Rect2i(0, 0, c.size.x, 1), Vector2i(c.position.x, c.position.y - k))
				img.blit_rect(bottom, Rect2i(0, 0, c.size.x, 1), Vector2i(c.position.x, c.end.y - 1 + k))
			var left := img.get_region(Rect2i(c.position.x, c.position.y - ext, 1, c.size.y + ext * 2))
			var right := img.get_region(Rect2i(c.end.x - 1, c.position.y - ext, 1, c.size.y + ext * 2))
			for k in range(1, ext + 1):
				img.blit_rect(left, Rect2i(0, 0, 1, c.size.y + ext * 2), Vector2i(c.position.x - k, c.position.y - ext))
				img.blit_rect(right, Rect2i(0, 0, 1, c.size.y + ext * 2), Vector2i(c.end.x - 1 + k, c.position.y - ext))

	func _make_placeholder() -> void:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.85, 0.85, 0.85, 1.0))
		img.generate_mipmaps()
		albedo = ImageTexture.create_from_image(img)
		textures_created += 1
		if _glows:
			var blk := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			blk.fill(Color(0.0, 0.0, 0.0, 1.0))
			blk.generate_mipmaps()
			emission = ImageTexture.create_from_image(blk)
			textures_created += 1
		placeholder = true
		ready = true
		_free_viewport()

	func _free_viewport() -> void:
		if _vp != null and is_instance_valid(_vp):
			_vp.queue_free()
		_vp = null


## The canvas of a PanelAtlas: every job drawn by its spec's Callable with Arcade's SignPainter (sign font) and a
## GeoBatch – the day picture at the cell, the night picture night_offset pixels lower.
class PanelCanvas extends Node2D:
	var jobs: Array = []
	var night_offset := -1
	var batch := GeoBatch.new()
	var painter := SignPainter.new()

	func _ready() -> void:
		painter.setup(self, batch)
		queue_redraw()

	func _draw() -> void:
		batch.begin(get_canvas_item())
		for j: Array in jobs:
			var spec: Dictionary = j[1]
			var cell: Rect2i = j[2]
			var draw: Callable = spec["draw"]
			var ppm := float(spec.get("ppm", 64.0))
			draw.call(painter, batch, Rect2(cell), ppm, false)
			if night_offset >= 0 and bool(spec.get("glow", false)):
				draw.call(painter, batch, Rect2(Vector2(cell.position.x, cell.position.y + night_offset), Vector2(cell.size)), ppm, true)
		batch.flush()


## The class "baked" material of a lettering atlas: its two textures, a little glossier than a building.
static func panel_material(mats: ModernMaterials, atlas: PanelAtlas, roughness: float = 0.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = mats.shader("baked")
	m.set_shader_parameter(&"albedo_tex", atlas.albedo)
	if atlas.emission != null:
		m.set_shader_parameter(&"emit_tex", atlas.emission)
	m.set_shader_parameter(&"roughness", roughness)
	return m


## A MeshInstance3D of vpbr arrays with the static vpbr material (no instance uniforms).
static func vpbr_node(arrays: Array, mats: ModernMaterials, cast: bool, node_name: String) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mats.material(ModernMaterials.VPBR_STATIC)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A MeshInstance3D of panel arrays with a panel material.
static func panel_node(arrays: Array, mat: Material, cast: bool, node_name: String) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The materials of a builder: the renderer's (services) or the process' shared instance.
static func materials_of(ctx: ChunkContext) -> ModernMaterials:
	var m: Variant = ctx.services.get("materials")
	return m as ModernMaterials if m is ModernMaterials else ModernMaterials.shared()


# --- hooks ---------------------------------------------------------------------------------------------------------

func id() -> String:
	return "station"


func setup(renderer: Node) -> void:
	_renderer = renderer
	var m: Variant = renderer.get("materials") if renderer != null else null
	_mats = m as ModernMaterials if m is ModernMaterials else ModernMaterials.shared()


func apply_quality(levels: Dictionary) -> void:
	_cast = int(levels.get("shadow_casters", 0)) >= 1


## The two panels of every station (canopy front, price board), drawn behind the loading overlay.
func prepare(_ctx: Dictionary) -> void:
	_atlas.prepare(panel_specs(), _renderer)
	_prepared = true


func prepare_pending() -> int:
	if not _prepared:
		return 0
	var n := _atlas.pending()
	if n == 0 and _panel_mat != null:
		_panel_mat.set_shader_parameter(&"albedo_tex", _atlas.albedo)
		_panel_mat.set_shader_parameter(&"emit_tex", _atlas.emission)
	return n


func panel_specs() -> Array:
	return [
		{"key": "fuel_front", "w": CANOPY_OUT - CANOPY_IN, "h": BAND_RED + BAND_WHITE, "ppm": PANEL_PPM, "glow": true,
			"draw": _draw_front},
		{"key": "fuel_price", "w": PYLON_BOARD.x, "h": PYLON_BOARD.y, "ppm": PANEL_PPM * 0.75, "glow": true,
			"draw": _draw_price},
	]


## The lettering atlas of this stage (tests, warm-up).
func atlas() -> PanelAtlas:
	return _atlas


## Canopy front (RoadRenderer._fuel_structures, FUEL_CANOPY_FRONT): white over the red band, "TANKSTELLE" in blue at
## Arcade's place (cap height 0.32 m, baseline 0.45 m under the top, at most 80 % of the width). At night the fascia
## is lit from inside: the white glows softly, the letters stronger.
func _draw_front(p: SignPainter, b: GeoBatch, r: Rect2, ppm: float, night: bool) -> void:
	var white := Color(0.42, 0.42, 0.40) if night else WHITE
	var red := Color(0.30, 0.02, 0.05) if night else RED
	var blue := Color(0.30, 0.55, 1.0) if night else TEXT
	b.rect(r, white)
	b.rect(Rect2(r.position.x, r.end.y - BAND_RED * ppm, r.size.x, BAND_RED * ppm), red)
	p.text(tr("TANKSTELLE"), Vector2(r.get_center().x, r.position.y + 0.45 * ppm), 0.32 * ppm, blue, r.size.x * 0.8)


## Price board (RoadRenderer._fuel_pylon): blue with a red header of 0.7 m, the white pump pictogram, the prices.
## At night the digits and the pictogram are lit, the board glows faintly.
func _draw_price(p: SignPainter, b: GeoBatch, r: Rect2, ppm: float, night: bool) -> void:
	var blue := Color(0.04, 0.09, 0.24) if night else BOARD_BLUE
	var red := Color(0.25, 0.02, 0.04) if night else RED
	var white := Color(1.0, 1.0, 1.0) if night else Color(0.96, 0.96, 0.94)
	b.rect(r, blue)
	b.rect(Rect2(r.position.x, r.position.y, r.size.x, 0.7 * ppm), red)
	var cx := r.get_center().x
	b.rect(Rect2(cx - 0.35 * ppm, r.position.y + 1.0 * ppm, 0.5 * ppm, 0.9 * ppm), white)
	b.rect(Rect2(cx + 0.2 * ppm, r.position.y + 1.15 * ppm, 0.1 * ppm, 0.6 * ppm), white)
	p.text(PRICES[0], Vector2(cx, r.end.y - 0.95 * ppm), 0.5 * ppm, white, 1.9 * ppm)
	p.text(PRICES[1], Vector2(cx, r.end.y - 0.25 * ppm), 0.5 * ppm, white, 1.9 * ppm)


func warmup_nodes() -> Array:
	var out: Array = []
	var k := Kit.new()
	var f := Transform3D.IDENTITY
	k.box(f, Vector3(0.0, 0.5, 0.0), Vector3(0.5, 0.5, 0.5), WHITE, ROUGH_PAINT)
	k.quad(Vector3(-0.5, 1.02, -0.2), Vector3(0.5, 1.02, -0.2), Vector3(0.5, 1.02, 0.2), Vector3(-0.5, 1.02, 0.2), Vector3.UP, LAMP,
		ROUGH_PAINT, Vector2(12.5, 1.0))
	k.quad(Vector3(-0.5, 0.0, 0.52), Vector3(0.5, 0.0, 0.52), Vector3(0.5, 1.0, 0.52), Vector3(-0.5, 1.0, 0.52), Vector3.BACK, RED,
		ROUGH_PAINT, FASCIA_GLOW)
	out.append(vpbr_node(k.arrays(), _mats, true, "StationWarm"))
	if _atlas.ready:
		var pb := PanelBuf.new()
		pb.framed(f, -0.5, 0.5, 1.2, 2.0, 0.0, _atlas.uv("fuel_front"))
		out.append(panel_node(pb.arrays(), _panel_material(), true, "StationPanelWarm"))
	return out


func _panel_material() -> ShaderMaterial:
	if _panel_mat == null:
		if not _atlas.ready and not _prepared:
			_atlas.prepare(panel_specs(), null)      # tests without prepare(): the placeholder atlas, at once
		_panel_mat = panel_material(_mats if _mats != null else ModernMaterials.shared(), _atlas)
	return _panel_mat


# --- chunks --------------------------------------------------------------------------------------------------------

## Main thread: the cells of the panels (plain data for build()). Without prepare() (tests of the kernel without a
## renderer) the placeholder atlas is made here, at once.
func collect(_ctx: ChunkContext) -> Variant:
	if not _prepared and not _atlas.ready:
		_atlas.prepare(panel_specs(), null)
	return {"uv": _atlas.entries.duplicate()}


## WORKER THREAD.
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var uvs: Dictionary = (input as Dictionary).get("uv", {}) if input is Dictionary else {}
	var kit := Kit.new()
	var pan := PanelBuf.new()
	var rows := ctx.row_count()
	var seg_len := ctx.seg_len
	var lamps: Array = []
	var glows: Array = []
	var fronts: Array = []
	var islands := 0
	var canopies := 0
	var pillars := 0
	var pylons := 0
	var letterings := 0
	var edges: Array = []              ## [segment index, paved edge incl. the fuel lane] of the island segments
	var front_uv: Rect2 = uvs.get("fuel_front", Rect2())
	var price_uv: Rect2 = uvs.get("fuel_price", Rect2())
	for i in rows - 1:
		var sa: Dictionary = ctx.segs[i]
		# the price pylon of the station (an "object" item; Arcade: RoadRenderer._fuel_pylon)
		for it: Dictionary in sa["sprites"]:
			if str(it.get("kind", "")) == "object" and str(it.get("obj", "")) == "fuel_pylon" and not bool(sa["tunnel"]):
				_pylon(ctx, kit, pan, glows, it, sa, price_uv)
				pylons += 1
		var fz := int(sa["fuel_zone"])
		if fz == 0 or bool(sa["tunnel"]):
			continue
		var sb: Dictionary = ctx.segs[i + 1]
		var z0 := float(ctx.seg_a + i) * seg_len
		var z1 := z0 + seg_len
		var e := (ctx.rows_edge[i].y + ctx.rows_edge[i + 1].y) * 0.5   # paved right edge incl. the fuel lane
		var next_fz := int(sb["fuel_zone"])
		var prev_fz := int(ctx.segs[i - 1]["fuel_zone"]) if i > 0 else -1
		var road_side := -ctx.rows_r[i]
		if (fz & TrackSegment.FUEL_ISLAND) != 0:
			islands += 1
			edges.append([int(sa["index"]), e])
			var starts_i := prev_fz < 0 or (prev_fz & TrackSegment.FUEL_ISLAND) == 0
			var ends_i := (next_fz & TrackSegment.FUEL_ISLAND) == 0
			var near_end := 1 if starts_i else 0
			var far_end := 2 if ends_i else 0
			# the island: top and far side grey, the kerb towards the fuel lane yellow with a painted top edge
			kit.road_box(ctx, z0, z1, e + ISLAND_IN + KERB_TOP_W, e + ISLAND_OUT, -0.05, ISLAND_H, ISLAND_TOP, ROUGH_CONCRETE,
				16 | 8 | near_end | far_end)
			kit.road_box(ctx, z0, z1, e + ISLAND_IN, e + ISLAND_IN + KERB_TOP_W, -0.05, ISLAND_H, KERB, ROUGH_PAINT,
				16 | 4 | near_end | far_end)
			# the forecourt behind it: a concrete slab a little above the road, its outer edge down into the ground
			var g0 := minf(ctx.ground(z0, e + APRON_OUT), 0.0) - 0.25
			var g1 := minf(ctx.ground(z1, e + APRON_OUT), 0.0) - 0.25
			kit.quad(ctx.local(z0, e + ISLAND_OUT, APRON_H), ctx.local(z1, e + ISLAND_OUT, APRON_H), ctx.local(z1, e + APRON_OUT, APRON_H),
				ctx.local(z0, e + APRON_OUT, APRON_H), Vector3.UP, APRON, ROUGH_CONCRETE)
			kit.quad(ctx.local(z0, e + APRON_OUT, g0), ctx.local(z1, e + APRON_OUT, g1), ctx.local(z1, e + APRON_OUT, APRON_H),
				ctx.local(z0, e + APRON_OUT, APRON_H), ctx.rows_r[i], APRON.darkened(0.12), ROUGH_CONCRETE)
			if starts_i or ends_i:
				var ze := z0 if starts_i else z1
				var gz := minf(ctx.ground(ze, e + APRON_OUT), 0.0) - 0.25
				kit.quad(ctx.local(ze, e + ISLAND_OUT, -0.05), ctx.local(ze, e + APRON_OUT, gz), ctx.local(ze, e + APRON_OUT, APRON_H),
					ctx.local(ze, e + ISLAND_OUT, APRON_H), ctx.rows_f[i] * (-1.0 if starts_i else 1.0), APRON.darkened(0.12), ROUGH_CONCRETE)
		if (fz & TrackSegment.FUEL_CANOPY) != 0:
			canopies += 1
			var x0 := e + CANOPY_IN
			var x1 := e + CANOPY_OUT
			var hb := CANOPY_H + BAND_RED
			var h1 := hb + BAND_WHITE
			var starts := (fz & TrackSegment.FUEL_CANOPY_FRONT) != 0
			var ends := (next_fz & TrackSegment.FUEL_CANOPY) == 0
			# soffit with Arcade's dark strip along the road side, the roof on top
			kit.quad(ctx.local(z0, x0 + EDGE_STRIP, CANOPY_H), ctx.local(z1, x0 + EDGE_STRIP, CANOPY_H), ctx.local(z1, x1, CANOPY_H),
				ctx.local(z0, x1, CANOPY_H), Vector3.DOWN, UNDERSIDE, ROUGH_PAINT)
			kit.quad(ctx.local(z0, x0, CANOPY_H), ctx.local(z1, x0, CANOPY_H), ctx.local(z1, x0 + EDGE_STRIP, CANOPY_H),
				ctx.local(z0, x0 + EDGE_STRIP, CANOPY_H), Vector3.DOWN, EDGE, ROUGH_PAINT)
			kit.quad(ctx.local(z0, x0, h1), ctx.local(z1, x0, h1), ctx.local(z1, x1, h1), ctx.local(z0, x1, h1), Vector3.UP, ROOF, ROUGH_PAINT)
			# fascia bands on both long sides (lit from inside at night)
			for side_x: float in [x0, x1]:
				var outward := road_side if side_x == x0 else -road_side
				kit.quad(ctx.local(z0, side_x, CANOPY_H), ctx.local(z1, side_x, CANOPY_H), ctx.local(z1, side_x, hb), ctx.local(z0, side_x, hb),
					outward, RED, ROUGH_PAINT, FASCIA_GLOW)
				kit.quad(ctx.local(z0, side_x, hb), ctx.local(z1, side_x, hb), ctx.local(z1, side_x, h1), ctx.local(z0, side_x, h1),
					outward, WHITE, ROUGH_PAINT, FASCIA_GLOW)
			if starts:
				var fwd := ctx.rows_f[i]
				if front_uv.size.x > 0.0:
					# the front fascia: one panel of the lettering atlas
					pan.panel(ctx.local(z0, x0, CANOPY_H), ctx.local(z0, x1, CANOPY_H), ctx.local(z0, x1, h1), ctx.local(z0, x0, h1), -fwd, front_uv)
					letterings += 1
				else:
					kit.quad(ctx.local(z0, x0, CANOPY_H), ctx.local(z0, x1, CANOPY_H), ctx.local(z0, x1, hb), ctx.local(z0, x0, hb), -fwd, RED,
						ROUGH_PAINT)
					kit.quad(ctx.local(z0, x0, hb), ctx.local(z0, x1, hb), ctx.local(z0, x1, h1), ctx.local(z0, x0, h1), -fwd, WHITE, ROUGH_PAINT)
				fronts.append(snappedf(z0, 0.001))
			if ends:
				var fwd2 := ctx.rows_f[i + 1]
				kit.quad(ctx.local(z1, x0, CANOPY_H), ctx.local(z1, x1, CANOPY_H), ctx.local(z1, x1, hb), ctx.local(z1, x0, hb), fwd2, RED,
					ROUGH_PAINT, FASCIA_GLOW)
				kit.quad(ctx.local(z1, x0, hb), ctx.local(z1, x1, hb), ctx.local(z1, x1, h1), ctx.local(z1, x0, h1), fwd2, WHITE, ROUGH_PAINT,
					FASCIA_GLOW)
			# steel columns with a plinth on the island: at the front and at the end of the canopy
			if starts or ends:
				var zp := z0 + 0.45 if starts else z1 - 0.45
				var fp := ctx.frame(zp, e + PILLAR_X, ISLAND_H)
				kit.box(fp, Vector3(0.0, PLINTH_H * 0.5, 0.0), Vector3(PLINTH_W, PLINTH_H, PLINTH_W) * 0.5, PLINTH, ROUGH_CONCRETE, 1 | 2 | 4 | 8 | 16)
				kit.box(fp, Vector3(0.0, (CANOPY_H - ISLAND_H) * 0.5, 0.0), Vector3(PILLAR_W, CANOPY_H - ISLAND_H, PILLAR_W) * 0.5, PILLAR,
					ROUGH_METAL, 1 | 2 | 4 | 8)
				pillars += 1
			# light panels in the soffit every second segment (Arcade), lit at night (lamp channel 12) with Arcade's white
			# glow round each (flare layer); the light pool of the row on the lane edge (Arcade: x = edge + 0.5) comes from a
			# lamp inside the canopy box – only its light shows, not a second glow
			if int(sa["index"]) % 2 == 0:
				var zl := z0 + seg_len * 0.5
				for lx: float in LAMP_X:
					var x := e + lx
					var hl := CANOPY_H - 0.02
					var hz := LAMP_SIZE.x * 0.5
					var hx := LAMP_SIZE.y * 0.5
					kit.quad(ctx.local(zl - hz, x - hx, hl), ctx.local(zl + hz, x - hx, hl), ctx.local(zl + hz, x + hx, hl),
						ctx.local(zl - hz, x + hx, hl), Vector3.DOWN, LAMP, Vector2(0.3, 0.0), Vector2(12.5, 1.0))
					lamps.append({"pos": ctx.local(zl, x, hl - 0.03), "dir": Vector3.DOWN, "role": "canopy", "color": LAMP_GLOW,
						"size": LAMP_GLOW_SIZE, "range": 0.0, "energy": LAMP_GLOW_ENERGY})
				lamps.append({"pos": ctx.local(zl, e + 0.5, CANOPY_H + 0.4), "dir": Vector3.DOWN, "role": "canopy", "color": LAMP_GLOW,
					"size": 0.2, "range": LAMP_RANGE_M, "energy": LAMP_ENERGY})
	if kit.is_empty() and pan.is_empty():
		return {}
	return {"arrays": kit.arrays() if not kit.is_empty() else [], "panels": pan.arrays() if not pan.is_empty() else [],
		"lamps": lamps, "glows": glows, "fronts": fronts, "islands": islands, "canopies": canopies, "pillars": pillars,
		"pylons": pylons, "letterings": letterings, "edges": edges, "triangles": kit.triangles() + pan.count * 2}


## The price pylon of an item (RoadRenderer._fuel_pylon): footing, pole, the board with the panel on both faces.
static func _pylon(ctx: ChunkContext, kit: Kit, pan: PanelBuf, glows: Array, it: Dictionary, seg: Dictionary, uv: Rect2) -> void:
	var z := float(it.get("z", seg["z"]))
	var x := float(it.get("x", 0.0))
	var g := ctx.ground(z, x)
	var f := ctx.frame(z, x, 0.0)
	var foot := minf(g, 0.0) - 0.3
	# concrete footing round the foot of the pole, the pole up into the board
	kit.box(f, Vector3(0.0, (g + 0.35 + foot) * 0.5, 0.0), Vector3(0.9, g + 0.35 - foot, 0.7) * 0.5, PLINTH, ROUGH_CONCRETE, 1 | 2 | 4 | 8 | 16)
	kit.box(f, Vector3(0.0, (PYLON_BOARD_Y + 0.2 + foot) * 0.5, 0.0), Vector3(PYLON_POLE_W, PYLON_BOARD_Y + 0.2 - foot, PYLON_POLE_W) * 0.5,
		POLE, ROUGH_METAL, 1 | 2 | 4 | 8)
	# the board: a box with blue sides and a red head, both faces the panel
	var bw := PYLON_BOARD.x * 0.5
	var bd := PYLON_BOARD.z * 0.5
	var y0 := PYLON_BOARD_Y
	var y1 := PYLON_BOARD_Y + PYLON_BOARD.y
	kit.box(f, Vector3(0.0, (y0 + y1 - 0.7) * 0.5, 0.0), Vector3(bw, (y1 - 0.7 - y0) * 0.5, bd), BOARD_BLUE, ROUGH_PAINT, 4 | 8 | 32)
	kit.box(f, Vector3(0.0, y1 - 0.35, 0.0), Vector3(bw, 0.35, bd), RED, ROUGH_PAINT, 4 | 8 | 16)
	if uv.size.x > 0.0:
		pan.framed(f, -bw, bw, y0, y1, bd + 0.002, uv)
		pan.framed(f, -bw, bw, y0, y1, -bd - 0.002, uv, true)
	else:
		kit.box(f, Vector3(0.0, (y0 + y1) * 0.5, 0.0), Vector3(bw, (y1 - y0) * 0.5, bd + 0.002), BOARD_BLUE, ROUGH_PAINT, 1 | 2)
	# Arcade's blue glow round the lit board at night (flare layer, role "lights")
	glows.append({"pos": f * Vector3(0.0, (y0 + y1) * 0.5, bd + 0.05), "dir": f.basis.z, "role": "lights", "color": PYLON_GLOW,
		"size": 2.9, "range": 0.0, "energy": 0.5})


## Main thread: the structures in vpbr, the panels, the lamps to the lights and flare layers.
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var arrays: Array = part.get("arrays", [])
	var panels: Array = part.get("panels", [])
	if arrays.is_empty() and panels.is_empty():
		return
	var mats := materials_of(ctx)
	if _mats == null:
		_mats = mats
	var casts := int(ctx.levels.get("shadow_casters", 0)) >= 1
	var mi: MeshInstance3D = null
	if not arrays.is_empty():
		mi = vpbr_node(arrays, mats, casts, "Station")
		parent.add_child(mi)
	if not panels.is_empty():
		var pn := panel_node(panels, _panel_material(), casts, "StationPanels")
		var words: Array = []
		for k in int(part.get("letterings", 0)):
			words.append("TANKSTELLE")
		pn.set_meta(&"lettering", words)
		parent.add_child(pn)
		if mi == null:
			mi = pn
	var renderer: Variant = ctx.services.get("renderer")
	var lamps: Array = (part.get("lamps", []) as Array) + (part.get("glows", []) as Array)
	if renderer != null and not lamps.is_empty() and mi != null:
		(renderer as Object).call(&"add_lamps", mi, lamps)


func debug(part: Dictionary) -> Dictionary:
	return {"islands": int(part.get("islands", 0)), "canopies": int(part.get("canopies", 0)), "fronts": (part.get("fronts", []) as Array).size(),
		"front_z": part.get("fronts", []), "letterings": int(part.get("letterings", 0)), "pillars": int(part.get("pillars", 0)),
		"pylons": int(part.get("pylons", 0)), "lamps": (part.get("lamps", []) as Array).size(), "triangles": int(part.get("triangles", 0))}
