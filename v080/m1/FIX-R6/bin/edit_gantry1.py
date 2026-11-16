import sys
p = sys.argv[1] + '/scripts/race3d/builders/gantry.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''##  * two steel columns 0.45 m wide just outside the outer shoulder edges, 7 m high, on concrete footings with a base
##    plate, joint bands and a cap;''',
'''##  * two steel columns 0.45 m wide just outside the outer shoulder edges, painted white as Arcade's beams, up to the
##    top of the truss, on concrete footings with a base plate, joint bands and a cap;
##  * a box truss from 7.0 to 7.9 m between them – the banner hangs under it (FIX-R6, finding B-03 of QA-R6: start and
##    finish showed no gain over Arcade) – with three floodlights on its front that light the banner and throw a light
##    pool onto the road just before the line at night (renderer.add_lamps(), role "lights"); nothing of it lower than
##    the banner's top over the road (F1: everything Arcade shows under the banner stays as visible);''')

rep('''const STEEL := Color("c9ccd1")
const STEEL_DARK := Color("8d939b")''',
'''## Arcade draws the columns as white beams; light paint keeps them as clear as Arcade's by day and lets them stand out
## at night (QA-R6 B-03: the grey steel vanished against the night sky)
const STEEL := Color("e9ebee")
const STEEL_DARK := Color("b4b9c0")
## The columns and the truss at night: lit by the floodlights – a flood-lit surface (lamp channel 14)
const FLOOD := Vector2(14.5, 0.3)
const TRUSS_H := 0.9               ## box truss on top of the banner: from TOP to TOP + TRUSS_H …
const TRUSS_D := 0.6               ## … this deep along the road
const TRUSS_BAY := 1.5             ## a vertical and a diagonal every this many metres
const CHORD := 0.12                ## square chords
const ROD := 0.045                 ## radius of the verticals and diagonals
## Floodlights on the truss front (three, at -0.6 / 0 / 0.6 of the banner's half width): aimed down towards the
## approaching traffic; their pool lies ~5 m before the gantry (layers/lights.gd: along the lamp's direction)
const FLOOD_T: Array[float] = [-0.6, 0.0, 0.6]
const FLOOD_DIR := Vector3(0.0, -0.85, 0.53)
const FLOOD_COLOR := Color(1.0, 0.95, 0.86)
const FLOOD_RANGE_M := 12.0
const FLOOD_ENERGY := 0.8
const FLOOD_SIZE := 0.55''')

rep('''## The banners' night picture at this share of their day colours: × 1.6 (panel shader) at full night ≈ Arcade's banner,
## which stays as bright as by day
const NIGHT_GLOW := 0.6''',
'''## The banners' night picture at this share of their day colours (× 1.6 of the panel shader at full night): Arcade's
## banner stays as bright as by day; lit by the floodlights it glows a little brighter than that (QA-R6 B-03: at 0.6 the
## red was darker than Arcade's)
const NIGHT_GLOW := 0.8''')

rep('''		for px: float in [left - POST_W * 0.5, right + POST_W * 0.5]:
			_column(ctx, kit, f, z, px)''',
'''		for px: float in [left - POST_W * 0.5, right + POST_W * 0.5]:
			_column(ctx, kit, f, z, px)
		# the truss over the banner and its floodlights
		_truss(kit, f, left - POST_W, right + POST_W)
		for t: float in FLOOD_T:
			var lx := cx + t * half
			var at := _floodlight(kit, f, lx)
			flood.append({"pos": at, "dir": (f.basis * FLOOD_DIR).normalized(), "role": "lights", "color": FLOOD_COLOR,
				"size": FLOOD_SIZE, "range": FLOOD_RANGE_M, "energy": FLOOD_ENERGY})''')

rep('''	var gantries: Array = []
	var letterings: Array = []
	for g: Dictionary in _items(ctx):''',
'''	var gantries: Array = []
	var letterings: Array = []
	var flood: Array = []
	for g: Dictionary in _items(ctx):''')

rep('''	return {"arrays": kit.arrays(), "panels": pan.arrays() if not pan.is_empty() else [],
		"gantries": gantries, "letterings": letterings, "triangles": kit.triangles()}''',
'''	return {"arrays": kit.arrays(), "panels": pan.arrays() if not pan.is_empty() else [],
		"gantries": gantries, "letterings": letterings, "flood": flood, "triangles": kit.triangles()}''')

rep('''	kit.box(f, Vector3(x, (TOP + 0.25) * 0.5, 0.0), Vector3(POST_W, TOP - 0.25, DEPTH) * 0.5, STEEL, ROUGH_METAL, 1 | 2 | 4 | 8)
	for y: float in [1.6, 3.2, 4.8]:
		kit.box(f, Vector3(x, y, 0.0), Vector3(POST_W + 0.04, 0.08, DEPTH + 0.04) * 0.5, STEEL_DARK, ROUGH_METAL, 1 | 2 | 4 | 8 | 16 | 32)
	kit.box(f, Vector3(x, TOP + 0.03, 0.0), Vector3(POST_W + 0.06, 0.06, DEPTH + 0.06) * 0.5, STEEL_DARK, ROUGH_METAL, 1 | 2 | 4 | 8 | 16)''',
'''	var top := TOP + TRUSS_H
	kit.box(f, Vector3(x, (top + 0.25) * 0.5, 0.0), Vector3(POST_W, top - 0.25, TRUSS_D) * 0.5, STEEL, ROUGH_PAINT, 1 | 2 | 4 | 8, FLOOD)
	for y: float in [1.6, 3.2, 4.8]:
		kit.box(f, Vector3(x, y, 0.0), Vector3(POST_W + 0.04, 0.08, TRUSS_D + 0.04) * 0.5, STEEL_DARK, ROUGH_METAL, 1 | 2 | 4 | 8 | 16 | 32)
	kit.box(f, Vector3(x, top + 0.03, 0.0), Vector3(POST_W + 0.06, 0.06, TRUSS_D + 0.06) * 0.5, STEEL_DARK, ROUGH_METAL, 1 | 2 | 4 | 8 | 16)


## The box truss over the banner from x0 to x1 (between the columns): four square chords, verticals and diagonals on
## the front, the back and the top, every TRUSS_BAY metres. All of it at TOP or higher (F1).
static func _truss(kit: Station.Kit, f: Transform3D, x0: float, x1: float) -> void:
	var zf := TRUSS_D * 0.5 - CHORD * 0.5
	var y0 := TOP + CHORD * 0.5
	var y1 := TOP + TRUSS_H - CHORD * 0.5
	for y: float in [y0, y1]:
		for zz: float in [-zf, zf]:
			kit.box(f, Vector3((x0 + x1) * 0.5, y, zz), Vector3((x1 - x0) * 0.5, CHORD * 0.5, CHORD * 0.5), STEEL, ROUGH_PAINT,
				1 | 2 | 16 | 32, FLOOD)
	var n := maxi(2, int(round((x1 - x0) / TRUSS_BAY)))
	var bay := (x1 - x0) / float(n)
	for i in n + 1:
		var x := x0 + bay * float(i)
		for zz: float in [-zf, zf]:
			_rod(kit, f * Vector3(x, y0, zz), f * Vector3(x, y1, zz), ROD, STEEL)
		if i < n:
			var xb := x + bay
			# diagonals alternate their direction from bay to bay; front and back mirror each other, the top zigzags
			var up := i % 2 == 0
			for zz: float in [-zf, zf]:
				_rod(kit, f * Vector3(x, y0 if up else y1, zz), f * Vector3(xb, y1 if up else y0, zz), ROD, STEEL)
			_rod(kit, f * Vector3(x, y1, -zf if up else zf), f * Vector3(xb, y1, zf if up else -zf), ROD, STEEL)


## A floodlight on the front of the truss at lateral x: bracket, housing tilted down towards the traffic, a lens that
## glows at night (lamp channel 12). Returns the position of its lamp (frame-local → chunk-local).
static func _floodlight(kit: Station.Kit, f: Transform3D, x: float) -> Vector3:
	var zf := TRUSS_D * 0.5
	var y := TOP + TRUSS_H - 0.1
	kit.box(f, Vector3(x, y, zf + 0.12), Vector3(0.1, 0.1, 0.24) * 0.5, STEEL_DARK, ROUGH_METAL, 1 | 4 | 8 | 16 | 32)
	# the housing: its face looks along FLOOD_DIR
	var d := FLOOD_DIR.normalized()
	var hb := Basis(Vector3.RIGHT, d.cross(Vector3.RIGHT).normalized(), d)
	var hc := Vector3(x, y - 0.05, zf + 0.32)
	var hf := Transform3D(f.basis * hb, f * hc)
	kit.box(hf, Vector3.ZERO, Vector3(0.62, 0.36, 0.26) * 0.5, HOUSING, Vector2(0.4, 0.3))
	kit.box(hf, Vector3(0.0, 0.0, 0.132), Vector3(0.54, 0.28, 0.002) * 0.5, FLOOD_COLOR, Vector2(0.2, 0.0), 1, Vector2(12.5, 1.0))
	return hf * Vector3(0.0, 0.0, 0.2)


## A round rod (six faces) from a to b (chunk-local).
static func _rod(kit: Station.Kit, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var dv := b - a
	var h := dv.length()
	if h < 1.0e-3:
		return
	var yy := dv / h
	var xx := yy.cross(Vector3.UP if absf(yy.y) < 0.9 else Vector3.RIGHT).normalized()
	var zz := xx.cross(yy).normalized()
	kit.column(Transform3D(Basis(xx, yy, zz), a), Vector3.ZERO, r, h, 6, col, ROUGH_PAINT, false, FLOOD)''')

rep('''		var renderer: Variant = ctx.services.get("renderer")
	for g: Dictionary in part.get("gantries", []):''',
'''		var renderer: Variant = ctx.services.get("renderer")
	var flood: Array = part.get("flood", [])
	if renderer != null and not flood.is_empty():
		(renderer as Object).call(&"add_lamps", mi, flood)
	for g: Dictionary in part.get("gantries", []):''') if False else None

rep('''	var renderer: Variant = ctx.services.get("renderer")
	for g: Dictionary in part.get("gantries", []):''',
'''	var renderer: Variant = ctx.services.get("renderer")
	var flood: Array = part.get("flood", [])
	if renderer != null and not flood.is_empty():
		(renderer as Object).call(&"add_lamps", mi, flood)
	for g: Dictionary in part.get("gantries", []):''')

rep('''	return {"gantries": kinds, "letterings": part.get("letterings", []), "lamps": lamps, "triangles": int(part.get("triangles", 0))}''',
'''	return {"gantries": kinds, "letterings": part.get("letterings", []), "lamps": lamps, "flood": (part.get("flood", []) as Array).size(),
		"triangles": int(part.get("triangles", 0))}''')
open(p, 'w').write(s)
print('ok')
