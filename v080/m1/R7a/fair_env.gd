## F7 reference of the sight corridor (contract A-17), independent of SightCorridor: every cam_every-th camera row
## (from cam_offset), the camera at every lane centre, the targets at every lane centre of every row up to
## L = min(chord_max_m, need / 0.6 + camera offset) – need: the largest of `profiles` (speed_profile() per weather) at
## the car's row camera_offset_m ahead –, in doubles on the whole-stage arrays of geo. Per camera point: the outermost
## bearings (to the right and to the left) of the targets from the far end back, crossed with the cross-section of
## every row they reach (both lines on both sides, as beyond a quarter turn the order of the crossings flips); targets
## whose heading differs more than max_turn from the camera's are left out, as in the kernel. Returns {"l", "r":
## PackedFloat64Array – metres beyond the shoulder edge per row, -INF where no sampled sight line passes –, "cameras",
## "skipped" (fans that turn too little to leave the road: length × turning / 2 below half a lane + shoulder)}.
static func sight_envelope(geo: Dictionary, profiles: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var n: int = geo["n"]
	var seg: float = geo["seg"]
	var xs: PackedFloat64Array = geo["x"]
	var zs: PackedFloat64Array = geo["z"]
	var th: PackedFloat64Array = geo["th"]
	var rx: PackedFloat64Array = geo["rx"]
	var rz: PackedFloat64Array = geo["rz"]
	var track: Track = geo["track"]
	var lw := track.lane_w
	var sh := track.shoulder_w
	var every := maxi(1, int(opts.get("cam_every", 7)))
	var offset := int(opts.get("cam_offset", 3))
	var chord_max := float(opts.get("chord_max_m", 300.0))
	var cam_back := float(opts.get("camera_offset_m", 9.0))
	var max_turn := float(opts.get("max_turn", 2.6))
	var cam_rows := int(round(cam_back / seg))
	var need := PackedFloat64Array()
	need.resize(n)
	for w: Variant in profiles:
		var nd: PackedFloat64Array = (profiles[w] as Dictionary)["need"]
		for i in n:
			need[i] = maxf(need[i], nd[i])
	var lanes: Array[PackedFloat64Array] = []
	var el := PackedFloat64Array()
	var er := PackedFloat64Array()
	var turn := PackedFloat64Array()
	el.resize(n)
	er.resize(n)
	turn.resize(n)
	for k in n:
		var s := track.get_segment(k)
		var half := s.lanes * lw * 0.5
		var c := PackedFloat64Array()
		for i in int(ceil(s.lanes - 1.0e-4)):
			c.append(minf(-half + lw * (float(i) + 0.5), half - lw * 0.5))
		if s.fuel_lane > 0.0:
			c.append(half + lw * 0.5)       # Track.fuel_lane_x()
		lanes.append(c)
		el[k] = half + sh
		er[k] = half + s.fuel_lane * lw + sh
		turn[k] = (turn[k - 1] + absf(th[k] - th[k - 1])) if k > 0 else 0.0
	var wl := PackedFloat64Array()
	var wr := PackedFloat64Array()
	wl.resize(n)
	wr.resize(n)
	wl.fill(-INF)
	wr.fill(-INF)
	var cams := 0
	var skipped := 0
	var a := offset
	while a < n - 1:
		var L := minf(chord_max, need[mini(a + cam_rows, n - 1)] / 0.6 + cam_back)
		var nf := L / seg
		var dn := mini(int(floor(nf)), n - 1 - a)
		cams += 1
		if dn < 1 or L * minf(turn[mini(a + dn + 1, n - 1)] - turn[a], PI * 0.5) * 0.5 < lw * 0.5 + sh - 0.25:
			skipped += 1
			a += every
			continue
		var fx := sin(th[a])
		var fz := -cos(th[a])
		# targets from the far end back: [row, fraction]
		var ft := nf - float(dn)
		for cl: float in lanes[a]:
			var cx := xs[a] + rx[a] * cl
			var cz := zs[a] + rz[a] * cl
			var b_r := -INF
			var b_l := INF
			var ur := Vector2.ZERO
			var ul := Vector2.ZERO
			if ft > 1.0e-4 and a + dn + 1 < n:
				var q := a + dn
				var hq := lerpf(th[q], th[q + 1], ft)
				if absf(hq - th[a]) <= max_turn:
					var px := lerpf(xs[q], xs[q + 1], ft)
					var pz := lerpf(zs[q], zs[q + 1], ft)
					for tl: float in lanes[q]:
						var vx := px + cos(hq) * tl - cx
						var vz := pz + sin(hq) * tl - cz
						var bb := atan2(vx * rx[a] + vz * rz[a], vx * fx + vz * fz)
						if bb > b_r:
							b_r = bb
							ur = Vector2(vx, vz)
						if bb < b_l:
							b_l = bb
							ul = Vector2(vx, vz)
			for d in range(dn, 0, -1):
				var b := a + d
				if absf(th[b] - th[a]) <= max_turn:
					for tl: float in lanes[b]:
						var vx := xs[b] + rx[b] * tl - cx
						var vz := zs[b] + rz[b] * tl - cz
						var bb := atan2(vx * rx[a] + vz * rz[a], vx * fx + vz * fz)
						if bb > b_r:
							b_r = bb
							ur = Vector2(vx, vz)
						if bb < b_l:
							b_l = bb
							ul = Vector2(vx, vz)
				if b_r == -INF:
					continue
				for u: Vector2 in [ur, ul]:
					# C + s u = P_b + x r_b
					var den := rx[b] * u.y - rz[b] * u.x
					if absf(den) <= 0.05 * u.length():
						continue
					var dx := cx - xs[b]
					var dz := cz - zs[b]
					if (dx * rz[b] - dz * rx[b]) / den <= 0.0:
						continue
					var x := (dx * u.y - dz * u.x) / den
					wr[b] = maxf(wr[b], x - er[b])
					wl[b] = maxf(wl[b], -x - el[b])
		a += every
	return {"l": wl, "r": wr, "cameras": cams, "skipped": skipped}


