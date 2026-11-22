

# --- fans ----------------------------------------------------------------------------------------------------------

## The plan of the rows _g0 .. _g1 relative to row _g0 (RoadPath3D.rows_local()): centres, unit right vectors,
## headings, the outermost lane centres as points, shoulder edges, prefix sums of the turning.
var _g0 := 0
var _g1 := -1
var _gx := PackedFloat32Array()
var _gz := PackedFloat32Array()
var _gnx := PackedFloat32Array()
var _gnz := PackedFloat32Array()
var _gh := PackedFloat64Array()
var _glx := PackedFloat32Array()
var _glz := PackedFloat32Array()
var _grx := PackedFloat32Array()
var _grz := PackedFloat32Array()
var _gel := PackedFloat32Array()
var _ger := PackedFloat32Array()
var _gtu := PackedFloat32Array()


## Makes the plan of the rows a fan from camera row c reaches available (one block of BLOCK cameras at a time).
func _geometry(c: int) -> void:
	var end := path.end_index()
	if c >= _g0 and mini(c + _nb + 1, end) <= _g1:
		return
	var hi := mini(c + BLOCK + _nb + 1, end)
	path.ensure(hi)
	var g := path.rows_local(c, hi)
	var o: PackedVector3Array = g["o"]
	var hd: PackedFloat64Array = g["heading"]
	var count := hi - c + 1
	_gx.resize(count)
	_gz.resize(count)
	_gnx.resize(count)
	_gnz.resize(count)
	_gh.resize(count)
	_glx.resize(count)
	_glz.resize(count)
	_grx.resize(count)
	_grz.resize(count)
	_gel.resize(count)
	_ger.resize(count)
	_gtu.resize(count)
	var acc := 0.0
	for q in count:
		var s := track.get_segment(maxi(c + q, 0))
		var half := s.lanes * _lane_w * 0.5
		var paved_r := half + s.fuel_lane * _lane_w
		var a := -half + _lane_w * 0.5
		var b := paved_r - _lane_w * 0.5
		if a > b:
			a = (a + b) * 0.5
			b = a
		var th := hd[q]
		var nx := cos(th)
		var nz := sin(th)
		_gx[q] = o[q].x
		_gz[q] = o[q].z
		_gnx[q] = nx
		_gnz[q] = nz
		_gh[q] = th
		_glx[q] = o[q].x + nx * a
		_glz[q] = o[q].z + nz * a
		_grx[q] = o[q].x + nx * b
		_grz[q] = o[q].z + nz * b
		_gel[q] = half + _shoulder
		_ger[q] = paved_r + _shoulder
		if q > 0:
			acc += absf(th - hd[q - 1])
		_gtu[q] = acc
	_g0 = c
	_g1 = hi
	_grow(hi)


## The fan of the camera at row c (both outermost lanes).
func _camera(c: int) -> void:
	cameras += 1
	_geometry(c)
	var L := chord_at(c)
	var n := L / _seg
	var qc := c - _g0
	var count := _g1 - _g0 + 1
	var dn := mini(int(floor(n)), _g1 - c)
	# a straight fan never leaves the road: a curve deviates from its chord by at most length * turning / 2
	if dn < 1 or L * minf(_gtu[mini(qc + dn + 1, count - 1)] - _gtu[qc], PI * 0.5) * 0.5 < _lane_w * 0.5 + _shoulder - 0.25:
		skipped += 1
		return
	var th := _gh[qc]
	# the far end at exactly L (between two rows)
	var ft := n - float(dn)
	var q0 := qc + dn
	var has_end := ft > 1.0e-4 and q0 + 1 < count and absf(lerpf(_gh[q0], _gh[q0 + 1], ft) - th) <= MAX_TURN
	var elx := 0.0
	var elz := 0.0
	var erx := 0.0
	var erz := 0.0
	if has_end:
		elx = lerpf(_glx[q0], _glx[q0 + 1], ft)
		elz = lerpf(_glz[q0], _glz[q0 + 1], ft)
		erx = lerpf(_grx[q0], _grx[q0 + 1], ft)
		erz = lerpf(_grz[q0], _grz[q0 + 1], ft)
	var lo_row := c - _lo
	for ci in 2:
		var cx := _glx[qc] if ci == 0 else _grx[qc]
		var cz := _glz[qc] if ci == 0 else _grz[qc]
		# the outermost sight lines so far (world vectors from the camera): v lies right of u when u × v > 0
		var urx := 0.0
		var urz := 0.0
		var ulx := 0.0
		var ulz := 0.0
		var any := false
		if has_end:
			urx = elx - cx
			urz = elz - cz
			ulx = urx
			ulz = urz
			var vx := erx - cx
			var vz := erz - cz
			if urx * vz - urz * vx > 0.0:
				urx = vx
				urz = vz
			else:
				ulx = vx
				ulz = vz
			any = true
		var d := dn
		while d >= 1:
			var q := qc + d
			if absf(_gh[q] - th) <= MAX_TURN:
				var vx := _glx[q] - cx
				var vz := _glz[q] - cz
				if not any:
					urx = vx
					urz = vz
					ulx = vx
					ulz = vz
					any = true
				else:
					if urx * vz - urz * vx > 0.0:
						urx = vx
						urz = vz
					if ulx * vz - ulz * vx < 0.0:
						ulx = vx
						ulz = vz
				vx = _grx[q] - cx
				vz = _grz[q] - cz
				if urx * vz - urz * vx > 0.0:
					urx = vx
					urz = vz
				if ulx * vz - ulz * vx < 0.0:
					ulx = vx
					ulz = vz
			if any and d % row_step == 0:
				# crossings of both outermost lines with the cross-section of this row: C + s u = P + x r
				# (beyond a quarter turn of the road the order of the crossings flips, so both count on both sides)
				var njx := _gnx[q]
				var njz := _gnz[q]
				var dx := cx - _gx[q]
				var dz := cz - _gz[q]
				var sd := dx * njz - dz * njx
				var xr := -INF
				var xl := -INF
				var den := njx * urz - njz * urx
				if den * den > 0.0025 * (urx * urx + urz * urz) and sd / den > 0.0:
					var x := (dx * urz - dz * urx) / den
					xr = x
					xl = -x
				den = njx * ulz - njz * ulx
				if den * den > 0.0025 * (ulx * ulx + ulz * ulz) and sd / den > 0.0:
					var x2 := (dx * ulz - dz * ulx) / den
					xr = maxf(xr, x2)
					xl = maxf(xl, -x2)
				if xr > -INF:
					var wi := lo_row + d
					var w := xr - _ger[q]
					if w > 0.0:
						w = minf(xr, path.clearance(c + d, 1)) - _ger[q]
					if w > _wr[wi]:
						_wr[wi] = w
					var w2 := xl - _gel[q]
					if w2 > 0.0:
						w2 = minf(xl, path.clearance(c + d, -1)) - _gel[q]
					if w2 > _wl[wi]:
						_wl[wi] = w2
			d -= 1
