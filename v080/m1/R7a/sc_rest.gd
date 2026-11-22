
func _raw(k: int, side: int) -> float:
	var i := k - _lo
	if i < 0 or i >= _wl.size():
		return NONE
	return _wl[i] if side < 0 else _wr[i]


func _grow(to_row: int) -> void:
	var n := to_row - _lo + 1
	if n > _wl.size():
		var old := _wl.size()
		_wl.resize(n)
		_wr.resize(n)
		for i in range(old, n):
			_wl[i] = NONE
			_wr[i] = NONE


# --- F2 need -------------------------------------------------------------------------------------------------------

func _need_at(k: int) -> float:
	var i := clampi(k - _n_lo, 0, maxi(0, _need.size() - 1))
	return _need[i] if not _need.is_empty() else 0.0


## Makes the need final up to row k: the braking envelope runs backwards from _look rows further on, where no speed
## can be lowered any more (or from the last segment), exactly as speed_profile() does over the whole stage.
func _ensure_need(k: int) -> void:
	if k <= _n_hi:
		return
	var last := track.segment_count - 1
	var lo := _n_hi + 1
	var hi := mini(maxi(k, lo + 63), last)
	if k > last:
		hi = last
	var top := mini(hi + _look, last)
	var count := top - lo + 1
	var curv := PackedFloat32Array()
	curv.resize(count)
	for q in count:
		var r := lo + q
		curv[q] = absf(track.get_segment(r).curve) if r >= 0 else 0.0
	var best := PackedFloat32Array()
	best.resize(hi - lo + 1)
	for e: Dictionary in _env:
		var safe1 := float(e["safe1"])
		var vtop := float(e["vtop"])
		var a := float(e["brake"])
		var v := 0.0
		for q in range(count - 1, -1, -1):
			var vr := minf(vtop, CURVE_TOLERANCE * safe1 / sqrt(maxf(curv[q], 1.0e-4)))
			# at `top` nothing further on can lower the speed of a row up to `hi` any more (or it is the last segment)
			v = vr if q == count - 1 else minf(vr, sqrt(v * v + 2.0 * a * _seg))
			if q <= hi - lo:
				var nd := v * REACTION_S + v * v / (2.0 * a)
				if nd > best[q]:
					best[q] = nd
	if _need.is_empty():
		_n_lo = lo
	var off := lo - _n_lo
	if _need.size() < off + best.size():
		_need.resize(off + best.size())
	for q in best.size():
		_need[off + q] = best[q]
	_n_hi = hi
	if k > last:
		_n_hi = k     # rows beyond the track answer with the last value (_need_at clamps)


# --- fans ----------------------------------------------------------------------------------------------------------

## Computes the fans of the cameras c0 .. c1 (multiples of CAM_STEP).
func _compute_block(c0: int, c1: int) -> void:
	var end := path.end_index()
	var hi := mini(c1 + _nb + 1, end)
	path.ensure(hi)
	_ensure_need(c1 + _cam_rows)
	var g := path.rows_local(c0, hi)
	var o: PackedVector3Array = g["o"]
	var hd: PackedFloat64Array = g["heading"]
	var count := hi - c0 + 1
	# lane extremes (signed lateral offsets of the outermost lane centres) and shoulder edges per row
	var xl := PackedFloat32Array()
	var xr := PackedFloat32Array()
	var el := PackedFloat32Array()
	var er := PackedFloat32Array()
	var turn := PackedFloat32Array()        # prefix sums of the absolute heading change
	xl.resize(count)
	xr.resize(count)
	el.resize(count)
	er.resize(count)
	turn.resize(count)
	var acc := 0.0
	for q in count:
		var s := track.get_segment(maxi(c0 + q, 0))
		var half := s.lanes * _lane_w * 0.5
		var paved_r := half + s.fuel_lane * _lane_w
		var a := -half + _lane_w * 0.5
		var b := paved_r - _lane_w * 0.5
		if a > b:
			a = (a + b) * 0.5
			b = a
		xl[q] = a
		xr[q] = b
		el[q] = half + _shoulder
		er[q] = paved_r + _shoulder
		if q > 0:
			acc += absf(hd[q] - hd[q - 1])
		turn[q] = acc
	_grow(hi)
	var c := c0
	while c <= c1:
		var qc := c - c0
		var L := chord_at(c)
		var n := L / _seg
		var dn := mini(int(floor(n)), hi - c)
		cameras += 1
		# a straight fan never leaves the road: deviation from the chord <= length * turning / 2
		if dn < 1 or L * minf(turn[mini(qc + dn + 1, count - 1)] - turn[qc], PI * 0.5) * 0.5 < _lane_w * 0.5 + _shoulder - 0.25:
			skipped += 1
			c += cam_step
			continue
		var th := hd[qc]
		var fx := sin(th)
		var fz := -cos(th)
		var rx := cos(th)
		var rz := sin(th)
		for ci in 2:
			var cl := xl[qc] if ci == 0 else xr[qc]
			var cx := o[qc].x + rx * cl
			var cz := o[qc].z + rz * cl
			# the outermost sight lines so far, as (forward, right) components in the camera's frame
			var ra := 0.0
			var rb := 0.0
			var la := 0.0
			var lb := 0.0
			var any := false
			# the far end at exactly L (between two rows), then every row back towards the camera
			var d := dn + 1
			while d >= 1:
				var q := qc + d
				var tx := 0.0
				var tz := 0.0
				var hq := 0.0
				var t0 := 0.0
				var t1 := 0.0
				if d == dn + 1:
					var ft := n - float(dn)
					if ft <= 1.0e-4 or qc + dn + 1 >= count:
						d -= 1
						continue
					var q0 := qc + dn
					hq = lerpf(hd[q0], hd[q0 + 1], ft)
					tx = lerpf(o[q0].x, o[q0 + 1].x, ft)
					tz = lerpf(o[q0].z, o[q0 + 1].z, ft)
					t0 = lerpf(xl[q0], xl[q0 + 1], ft)
					t1 = lerpf(xr[q0], xr[q0 + 1], ft)
					q = -1
				else:
					hq = hd[q]
					tx = o[q].x
					tz = o[q].z
					t0 = xl[q]
					t1 = xr[q]
				var njx := cos(hq)
				var njz := sin(hq)
				if absf(hq - th) <= MAX_TURN:
					for ti in 2:
						var tl := t0 if ti == 0 else t1
						var vx := tx + njx * tl - cx
						var vz := tz + njz * tl - cz
						var va := vx * fx + vz * fz
						var vb := vx * rx + vz * rz
						if not any:
							ra = va
							rb = vb
							la = va
							lb = vb
							any = true
						else:
							if vb * ra - va * rb > 0.0:
								ra = va
								rb = vb
							if vb * la - va * lb < 0.0:
								la = va
								lb = vb
				if q >= 0 and any and posmod(c + d, row_step) == 0:
					var wi := c + d - _lo
					var dx := cx - tx
					var dz := cz - tz
					var best_r := -INF
					var best_l := -INF
					# both outermost lines: beyond a quarter turn the order of the crossings flips
					for ui in 2:
						var ua := ra if ui == 0 else la
						var ub := rb if ui == 0 else lb
						var ux := fx * ua + rx * ub
						var uz := fz * ua + rz * ub
						var den := njx * uz - njz * ux
						if absf(den) <= 0.05 * sqrt(ux * ux + uz * uz):
							continue
						# C + s u = P + x r_j  (x: lateral offset at this row, s > 0: ahead of the camera)
						var x := (dx * uz - dz * ux) / den
						var s := (dx * njz - dz * njx) / den
						if s <= 0.0:
							continue
						best_r = maxf(best_r, x)
						best_l = maxf(best_l, -x)
					if best_r > -INF:
						var w := best_r - er[q]
						if w > 0.0:
							w = minf(best_r, path.clearance(c + d, 1)) - er[q]
						if w > _wr[wi]:
							_wr[wi] = w
						var w2 := best_l - el[q]
						if w2 > 0.0:
							w2 = minf(best_l, path.clearance(c + d, -1)) - el[q]
						if w2 > _wl[wi]:
							_wl[wi] = w2
				d -= 1
		c += cam_step
