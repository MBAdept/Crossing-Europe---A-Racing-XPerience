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
##    with a plinth on the island at the front and at the end of every canopy – none in front of a sign (column_plan(),
##    F1: Arcade draws a sign under its canopy over the pillar);
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
## Arcade's warm glow of the station building at night (RoadRenderer: _glow_fixture radius 7 m, colour (1, 0.8, 0.5),
## alpha 0.25 × lights) in front of the shop model (props/fuel_station: its forecourt canopy 3–5 m in front, 4 m on the
## road side of its anchor); flare strength = 2 × alpha / 0.35 (layers/flares.gd: a glow larger than 6 px on screen
## gets 35 % of its strength)
const SHOP_SET := "props/fuel_station"
const SHOP_GLOW_AT := Vector3(-4.2, 3.0, -5.7)
const SHOP_GLOW := Color(1.0, 0.8, 0.5)
const SHOP_GLOW_R := 7.0
const SHOP_GLOW_ENERGY := 2.0 * 0.25 / 0.35
## … and the warm light of the shop's forecourt on the ground in front of it (FIX-R6, B-03 of QA-R6: at night Arcade's
## station glows warmly as a whole, Modern's shop stood dark): a lamp under its forecourt canopy with a light pool
## (layers/lights.gd: on the terrain, and one of its omni lights on the shop front when it is among the nearest)
const SHOP_POOL_AT := Vector3(-4.2, 3.4, -5.2)
const SHOP_POOL_R := 11.0
const SHOP_POOL_ENERGY := 1.1
const COLUMN_IN := 0.45            ## columns this far inside the canopy's front and end
## A column on the island Arcade does not have (at the end of a canopy) stands there only where no sign on the right
## is within this distance behind it: one farther behind could only be covered while it is several hundred metres away
## (see border.gd). Otherwise it moves out beyond the boards (OUT_GAP).
const SIGN_SCAN_M := 120.0
const OUT_GAP := 0.25              ## an outer column's inner face this far beyond the outer edge of the boards
## The rule above holds on a straight road only: in a bend the column at the end of a canopy (Arcade has none there) can
## cover part of a board several hundred metres behind it, on either side of the road (finding B-02 of QA-R6). So the
## end column is checked against the real lines of sight (end_column_hides()): from the lane centres LOS_NEAR..LOS_FAR
## before every board up to LOS_FAR behind the column, every LOS_STEP metres. If it would cover one, it stands as
## "end_out"; if that would cover one too, the canopy has no end column (Arcade has none anyway) – unless the canopy
## would then stand on no column at all (canopy_columns()).
const LOS_NEAR := 55.0
const LOS_FAR := 600.0
const LOS_STEP := 5.0
const LOS_MARGIN := 0.1            ## the column's half width plus this (cameras every LOS_STEP: a line can sweep past)
## The decision costs 2–6 ms per canopy (measured, llvmpipe VM under load): collect() gathers the jobs (CanopyJob) of the
## canopies that start up to WARM_AHEAD_M beyond its chunk, a further half only within WARM_BUDGET_MS, so that the
## canopies of a station are spread over the chunks before it and decided on a worker instead of all landing in one
## frame. The canopies of a station share their cameras and segments: the lanes and the curvature are kept for the
## next canopy (cache "_lanes", "_curve", "_signs"), so a station of six canopies is gathered in a few calls. RINT-M2,
## measured on the test stage ("Steam Deck"): further ahead than 600 m the gather makes the Track generate its segments
## early (18 ms in one frame at 2000 m); one half per call left the last three of six canopies to be decided inline.
## Before the first half, warm_step() generates the track and fills the caches in small pieces up to WARM_BUDGET_MS
## (the first canopy of a station cost 1.2–1.5 ms per half with cold caches – 2.4 ms in one collect() on the Deck).
const WARM_AHEAD_M := 600.0
const WARM_BUDGET_MS := 1.0      ## warm_step() and a further half of a job run only while the call has used less than this
const WARM_GEN_SEGS := 6         ## warm_step(): segments the track is generated ahead per piece (~0.25 ms on the Deck)
const BEAM_H := 0.4                ## the beam under the canopy edge that carries it over to an outer column
const BEAM_D := 0.3
## RINT-M2 (contract §11.3 A-18): a canopy whose columns all fell out – the outer ones in a bend's sight corridor (F7),
## the end column on the island and outside covering a gameplay board – does not stand on an emergency column Arcade
## does not draw (it covered a "curve" warning by 89 % from 210 m at prag_leipzig km 148.2, NACH-R6 N-04). It hangs like
## the border roofs: from a mast farther out (the first place MAST_STEP by MAST_STEP beyond the boards, up to MAST_MAX_OUT,
## that covers no board from the lanes and stands outside the sight corridor), with a beam under the canopy edge over to
## it and stays from the mast head to the canopy's road edge – everything new above the canopy or beyond the boards.
const MAST_TOP := 10.5
const MAST_W := 0.4
const MAST_STEP := 1.0
const MAST_MAX_OUT := 30.0
const STAY_R := 0.06
const MAST_LEFT_GAP := 1.5          ## a mast on the left side: this far beyond the left shoulder at least
const STAY_T: Array[float] = [1.0, 0.55]   ## stays to the road edge and to the middle of the canopy
const CANOPY_TOP := 6.45                   ## top of the fascia (FASCIA_BANDS)
const LAMP_X: Array[float] = [0.8, 2.8]
const LAMP_SIZE := Vector2(1.0, 0.36)   ## light panel in the soffit (along, across)
const LAMP_DROP := 0.06            ## … hanging this far below the soffit
const PYLON_POLE_W := 0.36
const PYLON_BOARD := Vector3(2.2, 3.8, 0.32)   ## width, height, depth of the price board
const PYLON_BOARD_Y := 5.8         ## lower edge of the board above the road (Arcade: 5.8 – 9.6 m)
const PRICES: Array[String] = ["1,79", "1,85"]

const JOINT := Color("2a2c30")
const COPING := Color("c4c7cb")
const JOINT_H := 0.02              ## dark joint between the red and the white band
const COPING_H := 0.06             ## metal coping on top of the fascia
## Bands of the fascia from the soffit up: [from, to, colour, lit at night] (Arcade: red 5.6–5.95, white 5.95–6.45)
const FASCIA_BANDS: Array = [[5.6, 5.95 - 0.02, Color("c8102e"), true], [5.95 - 0.02, 5.95, Color("2a2c30"), false],
	[5.95, 6.45 - 0.06, Color("f2f2f0"), true], [6.45 - 0.06, 6.45, Color("c4c7cb"), false]]
const ISLAND_TOP := Color("c9c6bd")
const KERB := Color("e0c030")
const APRON := Color("b9b6ae")
## Arcade's underside 9a9c9b is drawn flat-lit; under the real sun the soffit gets only the sky light – a lighter grey
## keeps it about as light as Arcade's
const UNDERSIDE := Color("b4b6b5")
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
## The soffit at night: lit by its own luminaires (the real lights of the lights layer reach it only from below the pool
## lamps inside the canopy, and the ground never) – a flood-lit surface (lamp channel 14), as bright as Arcade's lit
## underside
const SOFFIT_GLOW := Vector2(14.5, 0.4)
## Light pool of a row of canopy lamps (one every 6 m on the lane edge): about the mean of Arcade's pools (0.8 × lights
## at the centre, radius 11 m, every 18 m; RoadRenderer._collect_static_lights) – 0.6 × 0.55 per pool, three of them
## overlap at every point of the lane
const LAMP_RANGE_M := 9.0
const LAMP_ENERGY := 0.6
## Arcade's glow round each canopy lamp (radius 1.8 m, colour (1, 0.97, 0.9), alpha 0.3): flare size × 0.9 = radius;
## the flare layer gives a lamp near the camera 35 % of its strength (the luminaire itself carries the light there)
const LAMP_GLOW := Color(1.0, 0.97, 0.9)
const LAMP_GLOW_SIZE := 2.0
const LAMP_GLOW_ENERGY := 1.0
const PYLON_GLOW := Color(0.5, 0.7, 1.0)   ## Arcade's glow round the lit price board (radius 2.6 m, alpha 0.25)
const PANEL_PPM := 96.0            ## lettering atlas: pixels per metre of the canopy front and the price board

var _renderer: Node                ## untyped: packages talk to each other through the facade only


## RINT-M2 (contract §11.3 A-18, NACH-R6 N-01/N-02): the columns of one canopy decided as a job. The main thread only
## gathers what the decision reads from the Track, in two collect() calls of about 1 ms each (canopy_job_begin(): the
## signs and boards behind the canopy and the curvature of the segments the lines of sight cross; canopy_job_rest():
## the lanes at every camera place and the paved edges – measured); the lines of sight themselves (run()) need nothing
## of the running game and go to a worker thread, started when collect() looks one canopy ahead (WARM_AHEAD_M). The
## sight-corridor flags of the places (TerrainProfile) are read only when the canopy's columns are taken (finish(),
## main thread): read 600 m ahead they made the TerrainProfile compute its rows there, up to 17 ms in one frame
## (RINT-M2, measured); when the canopy's chunk is captured those rows exist anyway. The lines of sight are computed on
## a path of their own, integrated from the first segment the job needs with
## heading 0 – congruent to the streamer's path, so the decision is the same wherever the race started (the streamer's
## path begins 150 m before the start: before, canopies near a start decided on fewer cameras, NACH-R6 N-01).
class CanopyJob extends RefCounted:
	var r0 := 0.0
	var r1 := 0.0
	var plan: Array = []                ## column_plan()
	var signs: Array = []
	var boards: Array = []
	var seg_len := 3.0
	var inv_r1 := 1.0 / 120.0
	var k0 := 0                         ## first segment of the job's own path
	var curve := PackedFloat32Array()   ## curvature value of segments k0, k0 + 1, …
	var lanes: Dictionary = {}          ## camera grid index (z / LOS_STEP) -> PackedFloat32Array of lane centres x
	var edges: Dictionary = {}          ## column z (snapped) -> paved edge there
	var left_from: Dictionary = {}      ## column z (snapped) -> first place of a left mast (m left of the centre)
	var checks: Array = []              ## run(): [index into out, z, x] of the columns finish() drops in a sight corridor
	var masts: Array = []               ## run(): [[z, e, right xs free of boards, left xs free of boards]] in order
	var out: Array = []                 ## run(): the columns before the corridor test
	var fallback: Array = []
	var result: Array = []
	var gathered := false               ## canopy_job_rest() done
	var done := false                   ## run() done
	var task := -1
	var _px := PackedFloat64Array()
	var _pz := PackedFloat64Array()
	var _th := PackedFloat64Array()

	static func zkey(z: float) -> int:
		return int(round(z * 100.0))

	func has_seg(k: int) -> bool:
		return k >= k0 and k <= k0 + curve.size()

	func _integrate() -> void:
		_px.resize(curve.size() + 1)
		_pz.resize(curve.size() + 1)
		_th.resize(curve.size() + 1)
		var x := 0.0
		var z := 0.0
		var a := 0.0
		_px[0] = 0.0
		_pz[0] = 0.0
		_th[0] = 0.0
		for i in curve.size():
			var da := float(curve[i]) * inv_r1 * seg_len
			var mid := a + da * 0.5
			x += sin(mid) * seg_len
			z -= cos(mid) * seg_len
			a += da
			_px[i + 1] = x
			_pz[i + 1] = z
			_th[i + 1] = a

	## Plan position of road coordinates (z, x) on the job's path – RoadPath3D.world() without height.
	func world2(z: float, x: float) -> Vector2:
		var f := z / seg_len - float(k0)
		var n := _px.size()
		var i := clampi(int(floor(f)), 0, maxi(0, n - 2))
		var j := mini(i + 1, n - 1)
		var u := clampf(f - float(i), 0.0, 1.0)
		var rx := lerpf(cos(_th[i]), cos(_th[j]), u)
		var rz := lerpf(sin(_th[i]), sin(_th[j]), u)
		return Vector2(lerpf(_px[i], _px[j], u) + rx * x, lerpf(_pz[i], _pz[j], u) + rz * x)

	## end_column_hides() on the job's data (same lines of sight, cameras and boards).
	func hides(z: float, xs: Array[float], width: float) -> Array:
		var out: Array = []
		out.resize(xs.size())
		out.fill(false)
		if not has_seg(int(floor(z / seg_len)) + 1):
			return out
		var cols: Array[Vector2] = []
		for x: float in xs:
			cols.append(world2(z, x))
		var r := width * 0.5 + LOS_MARGIN
		var rel: Array = []
		var lo := INF
		var hi := -INF
		for bd: Array in boards:
			var zs := float(bd[0])
			if zs <= z + 0.3 or zs > z + LOS_FAR or not has_seg(int(floor(zs / seg_len)) + 1):
				continue
			rel.append(bd)
			lo = minf(lo, zs - LOS_FAR)
			hi = maxf(hi, zs - LOS_NEAR)
		if rel.is_empty():
			return out
		var cams: Array = []
		var zc := floorf((z - 1.0) / LOS_STEP) * LOS_STEP
		while zc >= z - LOS_FAR:
			if zc >= lo and zc <= hi and has_seg(int(floor(zc / seg_len))):
				var lx: Variant = lanes.get(int(round(zc / LOS_STEP)))
				if lx is PackedFloat32Array:
					for x: float in lx:
						cams.append([zc, world2(zc, x)])
			zc -= LOS_STEP
		for bd: Array in rel:
			var zs := float(bd[0])
			var b0 := world2(zs, float(bd[1]) - float(bd[2]))
			var b1 := world2(zs, float(bd[1]) + float(bd[2]))
			for cm: Array in cams:
				var d := zs - float(cm[0])
				if d < LOS_NEAR or d > LOS_FAR:
					continue
				var c: Vector2 = cm[1]
				var w0 := b0 - c
				var w1 := b1 - c
				var db := w0.length()
				var db1 := w1.length()
				for k in cols.size():
					if bool(out[k]):
						continue
					var to_col := cols[k] - c
					var dc := to_col.length()
					if dc < r or db <= dc:
						continue
					var s0 := sine(to_col, w0, dc, db)
					var s1 := sine(to_col, w1, dc, db1)
					var lim := minf(1.0, r / dc)
					if maxf(s0, s1) >= -lim and minf(s0, s1) <= lim:
						out[k] = true
		return out

	## The candidate places of a mast right of the road at zc (x from the road centre; e = the paved edge there).
	static func mast_right(zc: float, e: float, signs: Array, r0: float, r1: float) -> Array[float]:
		var xs: Array[float] = []
		var off := maxf(outer(signs, r0 - 1.0, r1 + SIGN_SCAN_M), CANOPY_OUT + MAST_W) + MAST_STEP
		while off <= CANOPY_OUT + MAST_MAX_OUT:
			xs.append(e + off)
			off += MAST_STEP
		return xs


	## … and left of it, from `left` (m left of the centre: the left shoulder + MAST_LEFT_GAP) outwards.
	static func mast_left(left: float) -> Array[float]:
		var xs: Array[float] = []
		var o := left
		while o <= left + MAST_MAX_OUT:
			xs.append(-o)
			o += MAST_STEP
		return xs

	## outer_place() of the builder (an inner class cannot call the outer script's static functions).
	static func outer(sgns: Array, z0: float, z1: float) -> float:
		var far := PILLAR_X
		for s: Array in sgns:
			if float(s[0]) >= z0 and float(s[0]) <= z1:
				far = maxf(far, float(s[1]) + OUT_GAP + PILLAR_W * 0.5)
		return far

	## _sine() of the builder.
	static func sine(v: Vector2, w: Vector2, lv: float, lw: float) -> float:
		var s := v.cross(w) / maxf(lv * lw, 1.0e-9)
		if v.dot(w) < 0.0:
			return 2.0 if s >= 0.0 else -2.0
		return s


	## The lines of sight of canopy_columns() (WORKER THREAD or inline); finish() completes the decision.
	func run() -> void:
		_integrate()
		out = []
		fallback = []
		checks = []
		masts = []
		for c0: Array in plan:
			var c: Array = c0
			var zc := float(c[0])
			var kind := str(c[1])
			var e := float(edges.get(zkey(zc), 0.0))
			if kind.begins_with("end"):
				fallback = [zc, "end", PILLAR_X]
				var cands: Array = [[zc, "end", PILLAR_X], [zc, "end_out", outer(signs, r0 - 1.0, r1 + SIGN_SCAN_M)]] \
					if kind == "end" else [c]
				var xs: Array[float] = []
				for q: Array in cands:
					xs.append(e + float(q[2]))
				var hid := hides(zc, xs, PILLAR_W)
				var chosen: Array = []
				for k in cands.size():
					if not bool(hid[k]):
						chosen = cands[k]
						break
				if chosen.is_empty():
					continue
				c = chosen
				kind = str(c[1])
			if kind != "front" and kind != "end":
				checks.append([out.size(), zc, e + float(c[2])])
			out.append(c)
		# a canopy may lose every column (finish() drops the outer ones in a sight corridor): the mast places free of
		# boards, for finish() to take the first outside the corridor – only then needed, so only then looked at
		if not fallback.is_empty() and checks.size() == out.size():
			for zm: float in [float(fallback[0]), r0 + COLUMN_IN]:
				masts.append(_mast_places(zm))
		done = true

	## The places of a mast at zc that cover no board: [zc, e, right xs (beyond the boards), left xs (beyond the left
	## shoulder)], each in the order of preference.
	func _mast_places(zc: float) -> Array:
		var e := float(edges.get(zkey(zc), 0.0))
		var xs := mast_right(zc, e, signs, r0, r1)
		var hid := hides(zc, xs, MAST_W)
		var right: Array[float] = []
		for k in xs.size():
			if not bool(hid[k]):
				right.append(xs[k])
		var xl := mast_left(float(left_from.get(zkey(zc), 9.0)))
		var hl := hides(zc, xl, MAST_W)
		var left: Array[float] = []
		for k in xl.size():
			if not bool(hl[k]):
				left.append(xl[k])
		return [zc, e, right, left]

	## MAIN THREAD, after run(): the columns of the canopy – the outer ones outside a bend's sight corridor; a canopy
	## left without any column hangs from a mast (MAST_TOP: right of the road beyond the boards, else beyond the left
	## shoulder – the first place free of boards and outside the corridor), else keeps its end column on the island.
	## tr / tp: the Track and the TerrainProfile (tp null: no corridor test).
	func finish(tr: Track, tp: TerrainProfile) -> void:
		var drop := {}
		for ck: Array in checks:
			if tp != null and bend_corridor_at(tr, tp, float(ck[1]), float(ck[2])):
				drop[int(ck[0])] = true
		var cols: Array = []
		for i in out.size():
			if not drop.has(i):
				cols.append(out[i])
		if cols.is_empty() and not fallback.is_empty():
			var mast: Array = []
			for m: Array in masts:
				var zc := float(m[0])
				for x: float in m[2]:
					if tp == null or not bend_corridor_at(tr, tp, zc, x):
						mast = [zc, "mast", x - float(m[1])]
						break
				if mast.is_empty():
					for x: float in m[3]:
						if tp == null or not bend_corridor_at(tr, tp, zc, x):
							mast = [zc, "mast_l", x]
							break
				if not mast.is_empty():
					break
			cols.append(mast if not mast.is_empty() else fallback)
		result = cols

	## bend_corridor_at() of the builder (an inner class cannot call the outer script's static functions).
	static func bend_corridor_at(tr: Track, tp: TerrainProfile, z: float, x: float) -> bool:
		var f := z / tr.seg_len
		var k := maxi(int(floor(f)), 0)
		var u := clampf(f - float(k), 0.0, 1.0)
		var side := -1 if x < 0.0 else 1
		var e := lerpf(paved_edge(tr, k, side), paved_edge(tr, k + 1, side), u)
		var m := absf(x) - e - tr.shoulder_w
		var cw := lerpf(tp.corridor_width(k, side), tp.corridor_width(k + 1, side), u)
		var cmin := maxf(0.0, tp.corridor_min_m - tr.shoulder_w)
		return cw > cmin + 0.5 and m > 0.0 and m <= cw

	## _paved_edge() of the builder.
	static func paved_edge(tr: Track, k: int, side: int) -> float:
		var s := tr.get_segment(k)
		var half := s.lanes * tr.lane_w * 0.5
		return half if side < 0 else half + s.fuel_lane * tr.lane_w


## Main thread: everything the decision of the canopy from r0 to r1 reads from the Track, as a CanopyJob (run() it
## inline or on a worker, then finish()).
static func canopy_job(ctx: ChunkContext, r0: float, r1: float) -> CanopyJob:
	var job := canopy_job_begin(ctx, r0, r1)
	canopy_job_rest(ctx, job)
	return job


## Main thread, first half of canopy_job(): the signs, the column plan and the curvature of the job's segments.
## shared: the builder's cache (Dictionary) – the curvature of the segments is kept there for the next canopy.
static func canopy_job_begin(ctx: ChunkContext, r0: float, r1: float, shared: Variant = null) -> CanopyJob:
	var tr := ctx.track
	var job := CanopyJob.new()
	job.r0 = r0
	job.r1 = r1
	var sb := signs_behind(tr, r0, r1, shared)
	job.signs = sb["signs"]
	job.boards = sb["boards"]
	job.plan = column_plan(r0, r1, job.signs)
	job.seg_len = tr.seg_len
	if ctx.path != null:
		job.inv_r1 = ctx.path.inv_r1
	var kb := tr.segment_index_at(r1 + LOS_FAR) + 3
	var ka := maxi(0, tr.segment_index_at(r0 - LOS_FAR - 3.0 * LOS_STEP))
	while ka < kb and tr.get_segment(ka).index != ka:
		ka += 1
	job.k0 = ka
	var cc: Dictionary = _shared_part(shared, "_curve", ka)
	for k in range(ka, kb + 1):
		var cv: Variant = cc.get(k)
		if cv == null:
			var s := tr.get_segment(k)
			if s.index != k:
				break
			cv = s.curve
			cc[k] = cv
		job.curve.append(float(cv))
	if job.curve.size() < 2:
		job.curve.clear()          # no path: the decision keeps every column (as without ctx.path)
	return job


## Main thread, second half of canopy_job(): the cameras (lane centres) and the paved edges at the column places.
## shared: the builder's cache – the cameras are kept there for the next canopy (its grid overlaps).
static func canopy_job_rest(ctx: ChunkContext, job: CanopyJob, shared: Variant = null) -> void:
	var tr := ctx.track
	var r0 := job.r0
	var r1 := job.r1
	# cameras: the lane centres (and the open fuel lane) on the LOS_STEP grid before the canopy
	var zc := floorf((r0 - 1.0 - LOS_FAR - LOS_STEP) / LOS_STEP) * LOS_STEP
	var lc: Dictionary = _shared_part(shared, "_lanes", int(round(zc / LOS_STEP)))
	while zc <= r1 + LOS_STEP:
		var gi := int(round(zc / LOS_STEP))
		var hit: Variant = lc.get(gi)
		if hit != null:
			job.lanes[gi] = hit
			zc += LOS_STEP
			continue
		var lx := _lane_xs(tr, zc)
		job.lanes[gi] = lx
		lc[gi] = lx
		zc += LOS_STEP
	# column places: paved edges and the first place of a left mast (the corridor flags: finish())
	for c: Array in job.plan:
		var z := float(c[0])
		job.edges[CanopyJob.zkey(z)] = paved_edge_at(tr, z)
		job.left_from[CanopyJob.zkey(z)] = tr.lanes_at(z) * tr.lane_w * 0.5 + tr.shoulder_w + MAST_LEFT_GAP
	# the mast may also stand at the front (r0 + COLUMN_IN) – the first entry of the plan is there
	job.gathered = true


## The part `name` of the builder's cache (shared) for the gather of the next canopy: a Dictionary index -> value,
## emptied when the new canopy starts beyond everything kept (index `from` past the largest key – another station).
## Without a cache a fresh one.
static func _shared_part(shared: Variant, name: String, from: int) -> Dictionary:
	if not (shared is Dictionary):
		return {}
	var d: Dictionary = (shared as Dictionary).get(name, {})
	if not d.is_empty() and from > int(d.keys().max()):
		d.clear()
	(shared as Dictionary)[name] = d
	return d


## The cameras of canopy_job_rest() at z: the lane centres and, where the fuel lane is open, its centre.
static func _lane_xs(tr: Track, z: float) -> PackedFloat32Array:
	var lanes := tr.lanes_at(z)
	var half := lanes * tr.lane_w * 0.5
	var lx := PackedFloat32Array()
	for li in int(round(lanes)):
		lx.append(-half + tr.lane_w * (float(li) + 0.5))
	if tr.fuel_lane_factor(z) > 0.5:
		lx.append(half + tr.lane_w * 0.5)
	return lx


## The entries signs_behind() keeps for segment i: [z, x, half width, right side, paved edge there, in a tunnel] of
## each sign on a side of the road.
static func _segment_signs(tr: Track, i: int) -> Array:
	var list: Array = []
	var s := tr.get_segment(i)
	for sp: Variant in s.sprites:
		var it: Dictionary = sp
		if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) == 0:
			continue
		var zs := float(it.get("z", s.z))
		var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
		var right := int(it.get("side", 1)) > 0
		list.append([zs, float(it.get("x", 0.0)), hw, right, tr.road_edges_at(zs).y if right else 0.0, s.tunnel])
	return list


## Main thread, before canopy_job_begin() of a canopy ahead (RINT-M2, A-18): generates the track as far as
## signs_behind() needs it (WARM_GEN_SEGS segments per piece), then fills the builder's caches of the job's signs and
## cameras – piece by piece until the clock passes deadline_us (at least one piece per call), so that a call of
## collect() never pays a whole cold half. True when all is in place; called again by the next collect() otherwise.
## The values are those the halves would compute (the signs only once the track is generated that far, as in
## signs_behind()).
static func warm_step(ctx: ChunkContext, r0: float, r1: float, shared: Dictionary, deadline_us: int) -> bool:
	var tr := ctx.track
	var target := tr.segment_index_at(r1 + LOS_FAR + tr.generation_lead_m()) + 2
	# how far an earlier call generated this track ("_gen": [track id, segment]) – each call goes on from there
	var gen: Array = shared.get("_gen", [0, 0])
	var k := tr.segment_index_at(r0)
	if int(gen[0]) == tr.get_instance_id():
		k = maxi(k, int(gen[1]))
	while k < target:
		k = mini(k + WARM_GEN_SEGS, target)
		tr.get_segment(k)
		shared["_gen"] = [tr.get_instance_id(), k]
		if k < target and Time.get_ticks_usec() > deadline_us:
			return false
	var ia := tr.segment_index_at(r0)
	var sc: Dictionary = _shared_part(shared, "_signs", ia)
	for i in range(ia, tr.segment_index_at(r1 + LOS_FAR) + 1):
		if sc.has(i):
			continue
		sc[i] = _segment_signs(tr, i)
		if Time.get_ticks_usec() > deadline_us:
			return false
	var zc := floorf((r0 - 1.0 - LOS_FAR - LOS_STEP) / LOS_STEP) * LOS_STEP
	var lc: Dictionary = _shared_part(shared, "_lanes", int(round(zc / LOS_STEP)))
	while zc <= r1 + LOS_STEP:
		var gi := int(round(zc / LOS_STEP))
		if not lc.has(gi):
			lc[gi] = _lane_xs(tr, zc)
			if Time.get_ticks_usec() > deadline_us:
				return false
		zc += LOS_STEP
	return true
var _mats: ModernMaterials
var _atlas := PanelAtlas.new()
var _panel_mat: ShaderMaterial
var _cast := false
var _prepared := false
var _plans: Dictionary = {}        ## main thread (collect): canopy_columns() per canopy of the stage, by its start z


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
	_plans.clear()
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
	# the joint between the bands and the coping on top, as on the long sides
	b.rect(Rect2(r.position.x, r.end.y - BAND_RED * ppm, r.size.x, JOINT_H * ppm), Color(0.0, 0.0, 0.0) if night else JOINT)
	b.rect(Rect2(r.position.x, r.position.y, r.size.x, COPING_H * ppm), Color(0.0, 0.0, 0.0) if night else COPING)
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
func collect(ctx: ChunkContext) -> Variant:
	if not _prepared and not _atlas.ready:
		_atlas.prepare(panel_specs(), null)
	# the fuel-zone flags of the segment before the chunk: an island that goes on from there gets no end face
	var prev_fz := -1
	if ctx.track != null and ctx.seg_a > 0:
		prev_fz = ctx.track.get_segment(ctx.seg_a - 1).fuel_zone
	return {"uv": _atlas.entries.duplicate(), "prev_fz": prev_fz, "columns": columns_in_chunk(ctx, _plans)}


## Main thread: the columns of every canopy that reaches into the chunk (canopy_columns()), those standing in it.
## cache: a Dictionary kept by the builder for the stage – a canopy's columns are decided once (the lines of sight cost
## a few milliseconds), whichever chunk asks first.
static func columns_in_chunk(ctx: ChunkContext, cache: Variant = null) -> Array:
	var out: Array = []
	var tr := ctx.track
	if tr == null:
		return out
	var len_s := ctx.seg_len
	var za := float(ctx.seg_a) * len_s
	var zb := float(ctx.seg_b) * len_s
	for zn: Dictionary in tr.zones:
		if str(zn.get("kind", "")) != "fuel_canopy":
			continue
		var r0 := floorf(float(zn["z0"]) / len_s) * len_s
		var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
		if r0 > zb:
			break
		if r1 < za:
			continue
		var key := "%.3f" % r0
		var plan: Array
		var got: Variant = (cache as Dictionary).get(key) if cache is Dictionary else null
		if got is CanopyJob:
			# decided on a worker since a chunk before (WARM_AHEAD_M); wait for it (normally long done) – or, when the race
			# started closer than that, gathered and decided here
			var job: CanopyJob = got
			if not job.gathered:
				canopy_job_rest(ctx, job, cache)
			if job.task >= 0:
				WorkerThreadPool.wait_for_task_completion(job.task)
				job.task = -1
			if not job.done:
				job.run()
			job.finish(tr, ctx.terrain)
			plan = job.result
			(cache as Dictionary)[key] = plan
		elif got is Array:
			plan = got
		else:
			plan = canopy_columns(ctx, r0, r1, cache)
			if cache is Dictionary:
				(cache as Dictionary)[key] = plan
		for c: Array in plan:
			if float(c[0]) >= za and float(c[0]) < zb:
				out.append(c)
	# the canopies ahead decided in advance (WARM_AHEAD_M), gathered here (main thread, WARM_BUDGET_MS per collect())
	# and decided on a worker thread – RINT-M2 (A-18)
	if cache is Dictionary and ctx.path != null:
		var t0 := Time.get_ticks_usec()
		var budget_us := int(WARM_BUDGET_MS * 1000.0)
		for zn: Dictionary in tr.zones:
			if str(zn.get("kind", "")) != "fuel_canopy":
				continue
			var r0 := floorf(float(zn["z0"]) / len_s) * len_s
			if r0 <= zb:
				continue
			if r0 > zb + WARM_AHEAD_M:
				break
			var key := "%.3f" % r0
			var ahead: Variant = (cache as Dictionary).get(key)
			if ahead == null:
				var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
				if not warm_step(ctx, r0, r1, cache, t0 + budget_us):
					break
				if Time.get_ticks_usec() - t0 > budget_us:
					break
				ahead = canopy_job_begin(ctx, r0, r1, cache)
				(cache as Dictionary)[key] = ahead
			if ahead is CanopyJob and not (ahead as CanopyJob).gathered:
				if Time.get_ticks_usec() - t0 > budget_us:
					break
				var job: CanopyJob = ahead
				canopy_job_rest(ctx, job, cache)
				job.task = WorkerThreadPool.add_task(job.run, false, "Modern canopy %.0f" % r0)
	return out


## Main thread: the columns that stand under the canopy from r0 to r1 – [[z, kind, x]] of column_plan() (the signs on
## the right read from the track up to SIGN_SCAN_M beyond it, generated far enough ahead that the curve and crest
## warnings Track inserts later are in place), then:
##  * an outer column ("front_out", "end_out") inside a bend's sight corridor stands not (F7; the island lies in the
##    shoulder band, where no corridor reaches);
##  * the end column (Arcade has none) stands where it covers no board from the road (end_column_hides(), B-02 of
##    QA-R6): on the island, else beyond the boards, else not at all;
##  * a canopy left without any column keeps its end column on the island (rather than float; in the network such an end
##    column still covers part of a 6–7 px board at 3 canopies, measured with the tools of FIX-R6).
static func canopy_columns(ctx: ChunkContext, r0: float, r1: float, _cache: Variant = null) -> Array:
	var job := canopy_job(ctx, r0, r1)
	job.run()
	job.finish(ctx.track, ctx.terrain)
	return job.result


## WORKER THREAD. The mast of a canopy without column (CanopyJob._mast()): at (zp, cx) from the ground to MAST_TOP with a head
## plate, a beam under the canopy edge over to it, and its stays from the mast head to the road edge and the middle of
## the canopy's top (e = the paved edge there).
static func _mast(ctx: ChunkContext, kit: Kit, zp: float, e: float, cx: float) -> void:
	var g := ctx.ground(zp, cx)
	var f := ctx.frame(zp, cx, g)
	kit.box(f, Vector3(0.0, PLINTH_H * 0.5, 0.0), Vector3(PLINTH_W + 0.1, PLINTH_H, PLINTH_W + 0.1) * 0.5, PLINTH, ROUGH_CONCRETE, 1 | 2 | 4 | 8 | 16)
	kit.box(f, Vector3(0.0, (MAST_TOP - g) * 0.5, 0.0), Vector3(MAST_W, MAST_TOP - g, MAST_W) * 0.5, PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8)
	kit.box(f, Vector3(0.0, MAST_TOP - g + 0.08, 0.0), Vector3(MAST_W + 0.2, 0.16, MAST_W + 0.2) * 0.5, PILLAR.darkened(0.15),
		ROUGH_METAL, 1 | 2 | 4 | 8 | 16 | 32)
	if cx < 0.0:
		# on the left side: two stays in a V from the mast head high over the road to the canopy's road edge (lowest at
		# CANOPY_TOP over the fuel lane, 7–9 m over the driving lanes – above every vehicle and every line of sight to a
		# board) and a steel edge beam along that edge on the canopy top
		for dz: float in [-3.0, -0.3]:
			_stay(kit, ctx.local(zp, cx + MAST_W * 0.5, MAST_TOP - 0.4), ctx.local(zp + dz, e + CANOPY_IN + 0.3, CANOPY_TOP + 0.2))
		var fe := ctx.frame(zp - 1.65, e + CANOPY_IN + 0.3, CANOPY_TOP + 0.1)
		kit.box(fe, Vector3.ZERO, Vector3(0.2, 0.1, 1.85), PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8 | 16 | 32)
		return
	# the beam under the canopy edge over to the mast (the canopy's outer edge is e + CANOPY_OUT)
	var bx0 := e + CANOPY_OUT - 0.3
	var bx1 := cx + MAST_W * 0.5
	var fb := ctx.frame(zp, (bx0 + bx1) * 0.5, CANOPY_H - BEAM_H * 0.5)
	kit.box(fb, Vector3.ZERO, Vector3((bx1 - bx0) * 0.5, BEAM_H * 0.5, BEAM_D * 0.5), PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8 | 16 | 32)
	for j in STAY_T.size():
		var xt := lerpf(e + CANOPY_OUT, e + CANOPY_IN + 0.3, STAY_T[j])
		var a := ctx.local(zp, cx - MAST_W * 0.5, MAST_TOP - 0.4 - 0.6 * float(j))
		var b := ctx.local(zp, xt, CANOPY_TOP)
		_stay(kit, a, b)


## A round stay (six faces) from a to b.
static func _stay(kit: Kit, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var h := d.length()
	if h < 1.0e-3:
		return
	var y := d / h
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	kit.column(Transform3D(Basis(x, y, z), a), Vector3.ZERO, STAY_R, h, 6, PILLAR, ROUGH_METAL, false)


## Main thread: the signs behind a canopy from r0 to r1 – {"signs": [[z, outer edge of the board beyond the paved edge]]
## of the signs on the right up to SIGN_SCAN_M beyond it (column_plan()), "boards": [[z, x of the centre, half width]]
## of every board on either side up to LOS_FAR beyond it, outside tunnels (end_column_hides())}. Generates the track far
## enough ahead that the curve and crest warnings Track inserts later are in place. shared: the builder's cache – the
## signs of a segment (final once the track is generated that far) are kept there for the next canopy (RINT-M2).
static func signs_behind(tr: Track, r0: float, r1: float, shared: Variant = null) -> Dictionary:
	tr.get_segment(tr.segment_index_at(r1 + LOS_FAR + tr.generation_lead_m()) + 2)
	var signs: Array = []
	var boards: Array = []
	var ia := tr.segment_index_at(r0)
	var sc: Dictionary = _shared_part(shared, "_signs", ia)
	for i in range(ia, tr.segment_index_at(r1 + LOS_FAR) + 1):
		var got: Variant = sc.get(i)
		if got == null:
			got = _segment_signs(tr, i)
			sc[i] = got
		for e: Array in got:
			var zs := float(e[0])
			if bool(e[3]) and zs <= r1 + SIGN_SCAN_M:
				signs.append([zs, float(e[1]) + float(e[2]) - float(e[4])])
			if not bool(e[5]):
				boards.append([zs, float(e[1]), float(e[2])])
	return {"signs": signs, "boards": boards}


## Main thread: true when the road point (z, x) lies inside the sight corridor of a bend on its inside – the test of
## ChunkContext.in_bend_corridor(), for a row of any chunk (Track segments and the TerrainProfile instead of a snapshot;
## used by the station and the border builder).
static func bend_corridor_at(tr: Track, tp: TerrainProfile, z: float, x: float) -> bool:
	var f := z / tr.seg_len
	var k := maxi(int(floor(f)), 0)
	var t := clampf(f - float(k), 0.0, 1.0)
	var side := -1 if x < 0.0 else 1
	var e := lerpf(_paved_edge(tr, k, side), _paved_edge(tr, k + 1, side), t)
	var m := absf(x) - e - tr.shoulder_w
	var cw := lerpf(tp.corridor_width(k, side), tp.corridor_width(k + 1, side), t)
	var cmin := maxf(0.0, tp.corridor_min_m - tr.shoulder_w)
	return cw > cmin + 0.5 and m > 0.0 and m <= cw


## Paved edge of segment k on `side` (m from the centre, positive): ChunkContext.rows_edge of that row.
static func _paved_edge(tr: Track, k: int, side: int) -> float:
	var s := tr.get_segment(k)
	var half := s.lanes * tr.lane_w * 0.5
	return half if side < 0 else half + s.fuel_lane * tr.lane_w


## The paved right edge incl. the fuel lane where build() puts a column at z: the mean of the two rows of its segment
## (ChunkContext.rows_edge).
static func paved_edge_at(tr: Track, z: float) -> float:
	var k := maxi(int(floor(z / tr.seg_len)), 0)
	var a := tr.get_segment(k)
	var b := tr.get_segment(k + 1)
	return (a.lanes * tr.lane_w * 0.5 + a.fuel_lane * tr.lane_w + b.lanes * tr.lane_w * 0.5 + b.fuel_lane * tr.lane_w) * 0.5


## Main thread: for each candidate place x of `xs` (m from the road centre) at road position z, true when a column
## there would cover part of one of `boards` ([z, x, half width]) from a lane centre (and the fuel lane where it is
## open) LOS_NEAR..LOS_FAR before the board – world-space lines of sight on the RoadPath3D, bends included, against the
## column's footprint (it spans every board height). Cameras every LOS_STEP metres on a fixed grid; positions the path
## does not hold are skipped. cache (a Dictionary, optional): keeps the camera positions of the grid for the next
## canopies (valid while the floating origin of the path stays where it is).
static func end_column_hides(tr: Track, p: RoadPath3D, z: float, xs: Array[float], boards: Array, cache: Variant = null,
		width: float = PILLAR_W) -> Array:
	var out: Array = []
	out.resize(xs.size())
	out.fill(false)
	if not p.has(tr.segment_index_at(z) + 1):
		return out
	var cols: Array[Vector2] = []
	for x: float in xs:
		var cw := p.world(z, x, 0.0)
		cols.append(Vector2(cw.x, cw.z))
	var r := width * 0.5 + LOS_MARGIN
	# only the boards behind the column, and only the cameras some of them need
	var rel: Array = []
	var lo := INF
	var hi := -INF
	for bd: Array in boards:
		var zs := float(bd[0])
		if zs <= z + 0.3 or zs > z + LOS_FAR or not p.has(tr.segment_index_at(zs) + 1):
			continue
		rel.append(bd)
		lo = minf(lo, zs - LOS_FAR)
		hi = maxf(hi, zs - LOS_NEAR)
	if rel.is_empty():
		return out
	var cams: Array = []               ## [z, Vector2] on a fixed grid before the column
	var grid: Dictionary = {}
	if cache is Dictionary:
		var cd: Dictionary = cache
		if int(cd.get("cam_origin", -1)) != p.origin_index or not cd.has("cams"):
			cd["cam_origin"] = p.origin_index
			cd["cams"] = {}
		grid = cd["cams"]
	var zc := floorf((z - 1.0) / LOS_STEP) * LOS_STEP
	while zc >= z - LOS_FAR:
		if zc >= lo and zc <= hi and p.has(tr.segment_index_at(zc)):
			var at: Variant = grid.get(zc)
			if at == null:
				var half := tr.lanes_at(zc) * tr.lane_w * 0.5
				var nl := int(round(tr.lanes_at(zc)))
				var lxs: Array[float] = []
				for li in nl:
					lxs.append(-half + tr.lane_w * (float(li) + 0.5))
				if tr.fuel_lane_factor(zc) > 0.5:
					lxs.append(half + tr.lane_w * 0.5)
				var pts: Array[Vector2] = []
				for lx: float in lxs:
					var w := p.world(zc, lx, 0.0)
					pts.append(Vector2(w.x, w.z))
				at = pts
				grid[zc] = pts
			for v2: Vector2 in at:
				cams.append([zc, v2])
		zc -= LOS_STEP
	for bd: Array in rel:
		var zs := float(bd[0])
		var e0 := p.world(zs, float(bd[1]) - float(bd[2]), 0.0)
		var e1 := p.world(zs, float(bd[1]) + float(bd[2]), 0.0)
		var b0 := Vector2(e0.x, e0.z)
		var b1 := Vector2(e1.x, e1.z)
		for cm: Array in cams:
			var d := zs - float(cm[0])
			if d < LOS_NEAR or d > LOS_FAR:
				continue
			var c: Vector2 = cm[1]
			var w0 := b0 - c
			var w1 := b1 - c
			var db := w0.length()
			var db1 := w1.length()
			for k in cols.size():
				if bool(out[k]):
					continue
				var to_col := cols[k] - c
				var dc := to_col.length()
				if dc < r or db <= dc:
					continue
				# the column covers the angles within asin(r / dc) of its direction; the board spans its two ends' angles.
				# Compared as sines (monotonic up to 90°; beyond it ±2): the same test as with the angles, without atan2
				var s0 := _sine(to_col, w0, dc, db)
				var s1 := _sine(to_col, w1, dc, db1)
				var lim := minf(1.0, r / dc)
				if maxf(s0, s1) >= -lim and minf(s0, s1) <= lim:
					out[k] = true
	return out


## Sine of the signed angle from v to w (lengths lv, lw), mapped to ±2 beyond 90° – a monotonic stand-in for the angle.
static func _sine(v: Vector2, w: Vector2, lv: float, lw: float) -> float:
	var s := v.cross(w) / maxf(lv * lw, 1.0e-9)
	if v.dot(w) < 0.0:
		return 2.0 if s >= 0.0 else -2.0
	return s


## The columns of a canopy from r0 (start of its front segment) to r1 (end of its last segment): [[z, kind, x]], x =
## the column's centre beyond the paved edge –
##  * "front": Arcade's (on the island at PILLAR_X, COLUMN_IN behind r0) – unless a sign on the right stands under the
##    canopy behind its plinth: Arcade draws such a sign over its pillar (the same slice of its painter's order), in 3D
##    the column would cover it. Then "front_out": the column moves out beyond the boards (outer_place());
##  * "end": on the island COLUMN_IN before r1 where no sign on the right stands within SIGN_SCAN_M behind it, otherwise
##    "end_out" beyond the boards. Arcade has no column there.
## signs: [[z, outer edge of the board beyond the paved edge]] of the signs on the right from r0 to r1 + SIGN_SCAN_M.
## canopy_columns() decides which of them stand (sight corridor F7, lines of sight of the end column). Pure.
static func column_plan(r0: float, r1: float, signs: Array) -> Array:
	var out: Array = []
	var zf := r0 + COLUMN_IN
	var ze := r1 - COLUMN_IN
	var far := outer_place(signs, r0 - 1.0, r1 + SIGN_SCAN_M)
	var front_ok := true
	var end_ok := true
	for s: Array in signs:
		var z := float(s[0])
		# under the canopy: in one of its segments (a sign at r1 stands in the next one – another slice in Arcade)
		if z >= zf - PLINTH_W * 0.5 and z < r1:
			front_ok = false
		if z >= ze - PLINTH_W * 0.5 and z <= ze + SIGN_SCAN_M:
			end_ok = false
	out.append([zf, "front", PILLAR_X] if front_ok else [zf, "front_out", far])
	out.append([ze, "end", PILLAR_X] if end_ok else [ze, "end_out", far])
	return out


## The place of an outer column (m beyond the paved edge): its inner face OUT_GAP beyond the outer edge of every board
## on the right from z0 to z1 – seen from the road it covers none of them; never nearer the road than the island's.
static func outer_place(signs: Array, z0: float, z1: float) -> float:
	var far := PILLAR_X
	for s: Array in signs:
		if float(s[0]) >= z0 and float(s[0]) <= z1:
			far = maxf(far, float(s[1]) + OUT_GAP + PILLAR_W * 0.5)
	return far


## WORKER THREAD.
func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var uvs: Dictionary = (input as Dictionary).get("uv", {}) if input is Dictionary else {}
	var first_prev := int((input as Dictionary).get("prev_fz", -1)) if input is Dictionary else -1
	var columns: Array = (input as Dictionary).get("columns", []) if input is Dictionary else []
	var column_at: Array = []
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
			elif str(it.get("set", "")) == SHOP_SET and not bool(sa["tunnel"]):
				# Arcade's warm glow at the shop's forecourt (RoadRenderer: radius 7 m, colour (1, 0.8, 0.5), alpha 0.25 ×
				# lights); the shop itself is the AS1b model of the props builder
				var zs := float(it.get("z", sa["z"]))
				var fs := ctx.frame(zs, float(it.get("x", 0.0)), ctx.ground(zs, float(it.get("x", 0.0))))
				glows.append({"pos": fs * SHOP_GLOW_AT, "dir": fs.basis.z, "role": "lights", "color": SHOP_GLOW, "size": SHOP_GLOW_R / 0.9,
					"range": 0.0, "energy": SHOP_GLOW_ENERGY})
				glows.append({"pos": fs * SHOP_POOL_AT, "dir": -fs.basis.y, "role": "lights", "color": SHOP_GLOW, "size": 0.3,
					"range": SHOP_POOL_R, "energy": SHOP_POOL_ENERGY})
		var fz := int(sa["fuel_zone"])
		if fz == 0 or bool(sa["tunnel"]):
			continue
		var sb: Dictionary = ctx.segs[i + 1]
		var z0 := float(ctx.seg_a + i) * seg_len
		var z1 := z0 + seg_len
		var e := (ctx.rows_edge[i].y + ctx.rows_edge[i + 1].y) * 0.5   # paved right edge incl. the fuel lane
		var next_fz := int(sb["fuel_zone"])
		var prev_fz := int(ctx.segs[i - 1]["fuel_zone"]) if i > 0 else first_prev
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
				ctx.local(z0, x1, CANOPY_H), Vector3.DOWN, UNDERSIDE, ROUGH_PAINT, SOFFIT_GLOW)
			kit.quad(ctx.local(z0, x0, CANOPY_H), ctx.local(z1, x0, CANOPY_H), ctx.local(z1, x0 + EDGE_STRIP, CANOPY_H),
				ctx.local(z0, x0 + EDGE_STRIP, CANOPY_H), Vector3.DOWN, EDGE, ROUGH_PAINT)
			kit.quad(ctx.local(z0, x0, h1), ctx.local(z1, x0, h1), ctx.local(z1, x1, h1), ctx.local(z0, x1, h1), Vector3.UP, ROOF, ROUGH_PAINT)
			# fascia bands on both long sides (lit from inside at night)
			for side_x: float in [x0, x1]:
				var outward := road_side if side_x == x0 else -road_side
				_bands(kit, ctx.local(z0, side_x, 0.0), ctx.local(z1, side_x, 0.0), outward)
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
				_bands(kit, ctx.local(z1, x0, 0.0), ctx.local(z1, x1, 0.0), ctx.rows_f[i + 1])
			# steel columns with a plinth: on the island at the front and at the end of the canopy – moved out beyond the
			# sign boards where they could cover a sign (column_plan(), F1; then a beam under the canopy edge carries it
			# over and a column outside the shoulder band never stands in a bend's sight corridor, F7)
			for c: Array in columns:
				var zp := float(c[0])
				if zp < z0 or zp >= z1:
					continue
				var kind := str(c[1])
				var off := float(c[2])
				var cx := e + off
				if kind == "mast" or kind == "mast_l":
					if kind == "mast_l":
						cx = off            # the left mast's place is given from the road centre
					_mast(ctx, kit, zp, e, cx)
					pillars += 1
					column_at.append([zp, cx, kind])
					continue
				var base := ISLAND_H
				if off > ISLAND_OUT:
					base = APRON_H if off < APRON_OUT - PLINTH_W * 0.5 else minf(ctx.ground(zp, cx), APRON_H)
				var fp := ctx.frame(zp, cx, base)
				var top := CANOPY_H - base
				if off + PILLAR_W * 0.5 > CANOPY_OUT:
					var bx0 := e + CANOPY_OUT - 0.3
					var bx1 := cx + PILLAR_W * 0.5
					var fb := ctx.frame(zp, (bx0 + bx1) * 0.5, CANOPY_H - BEAM_H * 0.5)
					kit.box(fb, Vector3.ZERO, Vector3((bx1 - bx0) * 0.5, BEAM_H * 0.5, BEAM_D * 0.5), PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8 | 16 | 32)
				kit.box(fp, Vector3(0.0, PLINTH_H * 0.5, 0.0), Vector3(PLINTH_W, PLINTH_H, PLINTH_W) * 0.5, PLINTH, ROUGH_CONCRETE, 1 | 2 | 4 | 8 | 16)
				kit.box(fp, Vector3(0.0, top * 0.5, 0.0), Vector3(PILLAR_W, top, PILLAR_W) * 0.5, PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8)
				pillars += 1
				column_at.append([zp, cx, kind])
			# light panels in the soffit every second segment (Arcade), lit at night (lamp channel 12) with Arcade's white
			# glow round each (flare layer); the light pool of the row on the lane edge (Arcade: x = edge + 0.5) comes from a
			# lamp inside the canopy box – only its light shows, not a second glow
			if int(sa["index"]) % 2 == 0:
				var zl := z0 + seg_len * 0.5
				for lx: float in LAMP_X:
					var x := e + lx
					# a flat luminaire under the soffit: diffuser on the bottom and the sides (a panel flush with the soffit
					# would be a hairline from the road)
					var fl := ctx.frame(zl, x, CANOPY_H - LAMP_DROP * 0.5)
					kit.box(fl, Vector3.ZERO, Vector3(LAMP_SIZE.y, LAMP_DROP, LAMP_SIZE.x) * 0.5, LAMP, Vector2(0.3, 0.0), 1 | 2 | 4 | 8 | 32,
						Vector2(12.5, 1.0))
					lamps.append({"pos": ctx.local(zl, x, CANOPY_H - LAMP_DROP - 0.02), "dir": Vector3.DOWN, "role": "canopy", "color": LAMP_GLOW,
						"size": LAMP_GLOW_SIZE, "range": 0.0, "energy": LAMP_GLOW_ENERGY})
				lamps.append({"pos": ctx.local(zl, e + 0.5, CANOPY_H + 0.4), "dir": Vector3.DOWN, "role": "canopy", "color": LAMP_GLOW,
					"size": 0.2, "range": LAMP_RANGE_M, "energy": LAMP_ENERGY})
	if kit.is_empty() and pan.is_empty():
		return {}
	return {"arrays": kit.arrays() if not kit.is_empty() else [], "panels": pan.arrays() if not pan.is_empty() else [],
		"lamps": lamps, "glows": glows, "fronts": fronts, "islands": islands, "canopies": canopies, "pillars": pillars,
		"column_at": column_at, "pylons": pylons, "letterings": letterings, "edges": edges, "triangles": kit.triangles() + pan.count * 2}


## The fascia on a vertical face from pa to pb (points at road level): Arcade's red band and white band (both lit a
## little from inside at night), with a dark joint between them and a metal coping on top.
static func _bands(kit: Kit, pa: Vector3, pb: Vector3, outward: Vector3) -> void:
	for b: Array in FASCIA_BANDS:
		var u0 := Vector3(0.0, float(b[0]), 0.0)
		var u1 := Vector3(0.0, float(b[1]), 0.0)
		kit.quad(pa + u0, pb + u0, pb + u1, pa + u1, outward, b[2], ROUGH_PAINT if bool(b[3]) else ROUGH_METAL,
			FASCIA_GLOW if bool(b[3]) else NO_LAMP)


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
		"column_at": part.get("column_at", []), "pylons": int(part.get("pylons", 0)), "lamps": (part.get("lamps", []) as Array).size(), "triangles": int(part.get("triangles", 0))}
