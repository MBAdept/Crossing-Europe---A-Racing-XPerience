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


