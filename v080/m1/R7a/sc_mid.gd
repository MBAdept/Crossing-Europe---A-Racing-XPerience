func trim(before_index: int) -> void:
	if before_index >= (1 << 39):
		reset()
		return
	if not _started:
		return
	var cut := mini(before_index - 8 - _lo, _wl.size())
	if cut > 0:
		_wl = _wl.slice(cut)
		_wr = _wr.slice(cut)
		_lo += cut
	var cn := mini(before_index - 8 - _n_lo, _need.size())
	if cn > 0:
		_need = _need.slice(cn)
		_n_lo += cn


## Makes the rows up to k final: every camera at or before k computed.
func ensure(k: int) -> void:
	warm(k, -1)


## Computes the cameras up to row k, until the clock (Time.get_ticks_usec()) passes deadline_us (< 0: no limit).
## Returns true when the rows up to k are final. The streamer calls it every frame for the rows ahead of the chunks it
## will collect, so that a chunk finds its rows ready.
func warm(k: int, deadline_us: int) -> bool:
	if path == null or not path.is_ready():
		return false
	if not _started:
		_start()
	var end := path.end_index()
	if _cam_next > k or _cam_next > end:
		return true
	var t0 := Time.get_ticks_usec()
	while _cam_next <= k and _cam_next <= end:
		_camera(_cam_next)
		_cam_next += cam_step
		if deadline_us >= 0 and Time.get_ticks_usec() >= deadline_us:
			break
	usec += Time.get_ticks_usec() - t0
	return _cam_next > k or _cam_next > end


## The next row whose cameras are not computed yet.
func front() -> int:
	return _cam_next if _started else -(1 << 40)


func _start() -> void:
	_started = true
	row_step = maxi(1, row_step)
	cam_step = maxi(row_step, (cam_step / row_step) * row_step)   # cameras on sampled rows
	var first := path.first
	if path.has_lead_in():
		first = -(_nb + 32)          # cameras on the straight lead-in before the start line see the first bend too
	_cam_next = int(ceil(float(first) / float(cam_step))) * cam_step
	_lo = _cam_next
	_wl.clear()
	_wr.clear()
	_n_lo = _cam_next
	_n_hi = _cam_next - 1
	_need.clear()
	_g0 = 0
	_g1 = -1


func _interp(q: int, side: int) -> float:
	var k0 := int(floor(float(q) / float(row_step))) * row_step
	var u := float(q - k0) / float(row_step)
	var a := _raw(k0, side)
	if u <= 0.0:
		return a
	return lerpf(a, _raw(k0 + row_step, side), u)


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


