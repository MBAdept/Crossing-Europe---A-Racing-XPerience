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
