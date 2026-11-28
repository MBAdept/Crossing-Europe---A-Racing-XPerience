extends RefCounted
## Measurements of recorded game sound for tests/race/check_audio_modern.gd (package AU-E) and its unit test
## tests/unit/audio_modern/test_audio_meter.gd. Plain static functions on PackedFloat32Array (one array per channel),
## no autoloads, no scene tree.
##
##   loudness   BS.1770 / EBU R128: K weighting (the two analog prototypes of the standard – high shelf +4 dB above
##              ~1.7 kHz and the RLB high-pass at 38 Hz – as biquads, bilinear with prewarping at the given rate),
##              block power summed over both channels, −0.691 + 10·log10. momentary = 0.4-s window, short-term =
##              3-s window, integrated = 0.4-s blocks every 0.1 s, gated at −70 LUFS and 10 LU under the ungated
##              mean – the same definitions as tools/audio/qc/qc_lib.py (which works in the frequency domain; the two
##              agree to a few hundredths of a dB on real recordings, checked in the unit test against fixed values).
##   true peak  4× oversampling with the Kaiser-windowed sinc of qc_lib.py (12 taps per side and phase, β = 8,
##              unity gain per phase); only around samples within `margin_db` of the sample peak (an inter-sample
##              peak needs a large neighbour – the bound is reported with the value).
##   spectrum   Goertzel magnitudes on a logarithmic frequency axis (Hann window) and the frequency ratio between
##              two spectra (cross-correlation in log frequency, parabolic refinement) – the Doppler of a pass-by
##              shifts every partial by the same ratio.
##   decay      Schroeder backward integration of the squared signal and the reverberation time from the slope
##              between −5 and −25 dB (T20 × 3).
##   filters    a 4th-order Butterworth high-pass (two biquads) for the small-speaker check.

const SILENCE_DB := -120.0
const TP_TAPS := 12        ## taps per side and phase (qc_lib._TP_TAPS)
const TP_OS := 4


# --- biquads ------------------------------------------------------------------------------------------------------

## Direct form I biquad over a whole channel. c = [b0, b1, b2, a1, a2] (a0 = 1).
static func biquad(x: PackedFloat32Array, c: PackedFloat64Array) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var b0 := c[0]
	var b1 := c[1]
	var b2 := c[2]
	var a1 := c[3]
	var a2 := c[4]
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var xi := float(x[i])
		var yi := b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = xi
		y2 = y1
		y1 = yi
		y[i] = yi
	return y


## K weighting stage 1: the high shelf of BS.1770 (f0 1681.97 Hz, +4.0 dB, Q 0.7072).
static func shelf_coeffs(rate: float) -> PackedFloat64Array:
	var f0 := 1681.974450955533
	var g := 3.999843853973347
	var q := 0.7071752369554196
	var k := tan(PI * f0 / rate)
	var vh := pow(10.0, g / 20.0)
	var vb := pow(vh, 0.4996667741545416)
	var a0 := 1.0 + k / q + k * k
	return PackedFloat64Array([(vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0,
		2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0])


## K weighting stage 2: the RLB high-pass of BS.1770 (f0 38.135 Hz, Q 0.5003).
static func rlb_coeffs(rate: float) -> PackedFloat64Array:
	return highpass_coeffs(rate, 38.13547087602444, 0.5003270373238773)


## 2nd-order high-pass (bilinear with prewarping): H(s) = s² / (s² + s/Q + 1) at f0.
static func highpass_coeffs(rate: float, f0: float, q: float) -> PackedFloat64Array:
	var k := tan(PI * f0 / rate)
	var a0 := 1.0 + k / q + k * k
	return PackedFloat64Array([1.0 / a0, -2.0 / a0, 1.0 / a0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0])


static func k_weight(x: PackedFloat32Array, rate: float) -> PackedFloat32Array:
	return biquad(biquad(x, shelf_coeffs(rate)), rlb_coeffs(rate))


## 4th-order Butterworth high-pass at f0 (two biquads, Q 0.5412 and 1.3066): a small speaker that gives nothing
## below f0 (24 dB per octave).
static func highpass4(x: PackedFloat32Array, rate: float, f0: float) -> PackedFloat32Array:
	return biquad(biquad(x, highpass_coeffs(rate, f0, 0.5411961001461969)), highpass_coeffs(rate, f0, 1.3065629648763766))


# --- loudness -----------------------------------------------------------------------------------------------------

## Running sum of the K-weighted power of both channels (index i = sum of samples < i), for block powers.
static func power_sum(lk: PackedFloat32Array, rk: PackedFloat32Array) -> PackedFloat64Array:
	var c := PackedFloat64Array()
	c.resize(lk.size() + 1)
	var s := 0.0
	c[0] = 0.0
	for i in lk.size():
		var a := float(lk[i])
		var b := float(rk[i])
		s += a * a + b * b
		c[i + 1] = s
	return c


static func lufs_of(power: float) -> float:
	return -0.691 + 10.0 * log(maxf(power, 1.0e-14)) / log(10.0)


## Loudness of the window [i0, i0 + w) from a power sum (power_sum).
static func window_lufs(c: PackedFloat64Array, i0: int, w: int) -> float:
	var a := clampi(i0, 0, c.size() - 1)
	var b := clampi(i0 + w, 0, c.size() - 1)
	if b <= a:
		return SILENCE_DB
	return lufs_of((c[b] - c[a]) / float(b - a))


## Loudness series of windows win_s long every hop_s inside [from_s, to_s) (window start times from_s, from_s + hop,
## … while the window fits). Momentary: win 0.4 s; short-term: win 3 s.
static func series(c: PackedFloat64Array, rate: float, from_s: float, to_s: float, win_s: float, hop_s: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var w := int(round(win_s * rate))
	var h := maxi(int(round(hop_s * rate)), 1)
	var i := int(round(from_s * rate))
	var end := mini(int(round(to_s * rate)), c.size() - 1)
	if end - i < w:   # shorter than one window: the whole stretch
		out.append(window_lufs(c, i, end - i))
		return out
	while i + w <= end:
		out.append(window_lufs(c, i, w))
		i += h
	return out


## Integrated loudness of [from_s, to_s) with the two gates of BS.1770.
static func integrated(c: PackedFloat64Array, rate: float, from_s: float, to_s: float) -> float:
	var w := int(round(0.4 * rate))
	var h := int(round(0.1 * rate))
	var i := int(round(from_s * rate))
	var end := mini(int(round(to_s * rate)), c.size() - 1)
	var powers := PackedFloat64Array()
	while i + w <= end:
		powers.append((c[i + w] - c[i]) / float(w))
		i += h
	if powers.is_empty():
		return window_lufs(c, int(round(from_s * rate)), end - int(round(from_s * rate)))
	var sum := 0.0
	var n := 0
	for p in powers:
		if lufs_of(p) > -70.0:
			sum += p
			n += 1
	if n == 0:
		return -70.0
	var rel := lufs_of(sum / n) - 10.0
	var sum2 := 0.0
	var n2 := 0
	for p in powers:
		var l := lufs_of(p)
		if l > -70.0 and l > rel:
			sum2 += p
			n2 += 1
	return lufs_of(sum2 / n2) if n2 > 0 else -70.0


static func max_of(a: PackedFloat32Array) -> float:
	var m := -INF
	for v in a:
		m = maxf(m, v)
	return m


static func min_of(a: PackedFloat32Array) -> float:
	var m := INF
	for v in a:
		m = minf(m, v)
	return m


static func median_of(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return SILENCE_DB
	var s := a.duplicate()
	s.sort()
	var n := s.size()
	return s[n / 2] if n % 2 == 1 else 0.5 * (s[n / 2 - 1] + s[n / 2])


# --- peaks --------------------------------------------------------------------------------------------------------

static func db(x: float) -> float:
	return 20.0 * log(maxf(x, 1.0e-6)) / log(10.0) if x > 0.0 else SILENCE_DB


## Largest |sample| of both channels in [i0, i1).
static func sample_peak(l: PackedFloat32Array, r: PackedFloat32Array, i0: int, i1: int) -> float:
	var m := 0.0
	for i in range(maxi(i0, 0), mini(i1, l.size())):
		m = maxf(m, maxf(absf(l[i]), absf(r[i])))
	return m


## Number of samples in [i0, i1) with |x| ≥ level (both channels).
static func count_at_least(l: PackedFloat32Array, r: PackedFloat32Array, i0: int, i1: int, level: float) -> int:
	var n := 0
	for i in range(maxi(i0, 0), mini(i1, l.size())):
		if absf(l[i]) >= level:
			n += 1
		if absf(r[i]) >= level:
			n += 1
	return n


static func _bessel_i0(x: float) -> float:
	var s := 1.0
	var t := 1.0
	var k := 1.0
	while k < 60.0:
		t *= (x / (2.0 * k)) * (x / (2.0 * k))
		s += t
		if t < 1.0e-12 * s:
			break
		k += 1.0
	return s


## The oversampling filter of qc_lib._tp_filter(4), split into its phases: phases[p] = taps for the output between
## sample n and n+1 at p/4 (taps run over x[n − TP_TAPS + 1 … n + TP_TAPS] for p > 0; phase 0 is the sample itself).
static func tp_phases() -> Array[PackedFloat64Array]:
	var m := TP_TAPS * TP_OS
	var h := PackedFloat64Array()
	h.resize(2 * m + 1)
	var beta := 8.0
	var i0b := _bessel_i0(beta)
	for j in 2 * m + 1:
		var n := float(j - m)
		var u := n / TP_OS
		var sinc := 1.0 if is_zero_approx(u) else sin(PI * u) / (PI * u)
		var r := 2.0 * j / (2 * m) - 1.0
		h[j] = sinc * _bessel_i0(beta * sqrt(maxf(1.0 - r * r, 0.0))) / i0b
	var out: Array[PackedFloat64Array] = []
	for p in TP_OS:
		var taps := PackedFloat64Array()
		var s := 0.0
		var j := p
		while j < h.size():
			taps.append(h[j])
			s += h[j]
			j += TP_OS
		for t in taps.size():
			taps[t] /= s
		out.append(taps)
	return out


## True peak (linear) of both channels in [i0, i1): the largest value of the 4× oversampled signal, computed around
## every sample within margin_db of the sample peak of the stretch. Returns {"true_peak", "sample_peak", "checked"}.
static func true_peak(l: PackedFloat32Array, r: PackedFloat32Array, i0: int, i1: int, margin_db: float = 6.0) -> Dictionary:
	var a := maxi(i0, 0)
	var b := mini(i1, l.size())
	var sp := sample_peak(l, r, a, b)
	var thr := sp * pow(10.0, -margin_db / 20.0)
	var phases := tp_phases()
	var best := sp
	var checked := 0
	var m := TP_TAPS * TP_OS
	for ch in 2:
		var x: PackedFloat32Array = l if ch == 0 else r
		var last := -1000000
		for n in range(a, b):
			if absf(x[n]) < thr:
				continue
			# outputs between n−1 … n+1 (the inter-sample peaks next to this sample)
			for k in range(maxi(n - 1, last + 1), mini(n + 1, b - 1) + 1):
				last = k
				for p in range(1, TP_OS):
					var taps: PackedFloat64Array = phases[p]
					# np.convolve(x, h[p::4]): output index o = k + offset; tap t multiplies x[o − t]
					# Phase p of the full filter centred at m: the value between k and k+1 at fraction p/4 is
					# Σ_t taps[t] · x[k + TP_TAPS − t] with the taps of h[p::4] (length 2·TP_TAPS for p > 0).
					var s := 0.0
					for t in taps.size():
						var idx := k + TP_TAPS - t
						if idx >= 0 and idx < x.size():
							s += taps[t] * x[idx]
					best = maxf(best, absf(s))
				checked += 1
	return {"true_peak": best, "sample_peak": sp, "checked": checked, "margin_db": margin_db, "m": m}


# --- channels and spectra -----------------------------------------------------------------------------------------

## Energy of one channel in [i0, i1) (sum of squares).
static func energy(x: PackedFloat32Array, i0: int, i1: int) -> float:
	var s := 0.0
	for i in range(maxi(i0, 0), mini(i1, x.size())):
		s += x[i] * x[i]
	return s


## Level of the left channel over the right one in dB in [i0, i1).
static func balance_db(l: PackedFloat32Array, r: PackedFloat32Array, i0: int, i1: int) -> float:
	return 10.0 * log(maxf(energy(l, i0, i1), 1.0e-20) / maxf(energy(r, i0, i1), 1.0e-20)) / log(10.0)


## RMS of [i0, i1) of one channel in dBFS.
static func rms_db(x: PackedFloat32Array, i0: int, i1: int) -> float:
	var n := mini(i1, x.size()) - maxi(i0, 0)
	if n <= 0:
		return SILENCE_DB
	return 10.0 * log(maxf(energy(x, i0, i1) / n, 1.0e-20)) / log(10.0)


## Goertzel magnitudes (dB) of the mono sum of [i0, i0 + n) at f_lo · 2^(k / steps_per_octave) up to f_hi, Hann
## window.
static func log_spectrum(l: PackedFloat32Array, r: PackedFloat32Array, i0: int, n: int, rate: float, f_lo: float,
		f_hi: float, steps_per_octave: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var j := i0 + i
		var v := 0.0
		if j >= 0 and j < l.size():
			v = 0.5 * (l[j] + r[j])
		x[i] = v * (0.5 - 0.5 * cos(TAU * i / (n - 1)))
	var out := PackedFloat32Array()
	var f := f_lo
	var k := 0
	while f <= f_hi:
		var w := TAU * f / rate
		var coeff := 2.0 * cos(w)
		var s1 := 0.0
		var s2 := 0.0
		for i in n:
			var s0 := x[i] + coeff * s1 - s2
			s2 = s1
			s1 = s0
		var p := s1 * s1 + s2 * s2 - coeff * s1 * s2
		out.append(10.0 * log(maxf(p, 1.0e-20)) / log(10.0))
		k += 1
		f = f_lo * pow(2.0, float(k) / steps_per_octave)
	return out


## Frequency ratio b / a of two log spectra (same axis): the lag in steps that maximises their correlation (mean
## removed, lags within ±max_steps), refined by a parabola. ratio > 1: b lies higher. Returns {"ratio", "steps",
## "corr"}.
static func spectrum_ratio(a: PackedFloat32Array, b: PackedFloat32Array, steps_per_octave: int, max_steps: int) -> Dictionary:
	var n := mini(a.size(), b.size())
	var ma := 0.0
	var mb := 0.0
	for i in n:
		ma += a[i]
		mb += b[i]
	ma /= n
	mb /= n
	var corr := PackedFloat64Array()
	for lag in range(-max_steps, max_steps + 1):
		var s := 0.0
		var sa := 0.0
		var sb := 0.0
		for i in n:
			var j := i + lag
			if j < 0 or j >= n:
				continue
			var da := a[i] - ma
			var dbv := b[j] - mb
			s += da * dbv
			sa += da * da
			sb += dbv * dbv
		corr.append(s / sqrt(maxf(sa * sb, 1.0e-20)))
	var best := 0
	for i in corr.size():
		if corr[i] > corr[best]:
			best = i
	var frac := 0.0
	if best > 0 and best < corr.size() - 1:
		var y0 := corr[best - 1]
		var y1 := corr[best]
		var y2 := corr[best + 1]
		var den := y0 - 2.0 * y1 + y2
		if absf(den) > 1.0e-12:
			frac = clampf(0.5 * (y0 - y2) / den, -0.5, 0.5)
	var steps := float(best - max_steps) + frac
	return {"ratio": pow(2.0, steps / steps_per_octave), "steps": steps, "corr": corr[best]}


# --- decay --------------------------------------------------------------------------------------------------------

## Schroeder decay of the mono sum from i0 on (n samples): the energy that is still to come at every 1-ms step, in dB
## relative to the start. Returns the curve (one value per ms).
static func schroeder_db(l: PackedFloat32Array, r: PackedFloat32Array, i0: int, n: int, rate: float) -> PackedFloat32Array:
	var step := maxi(int(round(rate / 1000.0)), 1)
	var e := PackedFloat64Array()
	var i := i0
	while i < i0 + n and i < l.size():
		var s := 0.0
		for j in range(i, mini(i + step, l.size())):
			var v := 0.5 * (l[j] + r[j])
			s += v * v
		e.append(s)
		i += step
	var out := PackedFloat32Array()
	out.resize(e.size())
	var acc := 0.0
	for k in range(e.size() - 1, -1, -1):
		acc += e[k]
		out[k] = acc
	var total := maxf(out[0] if out.size() > 0 else 0.0, 1.0e-30)
	for k in out.size():
		out[k] = 10.0 * log(maxf(out[k] / total, 1.0e-30)) / log(10.0)
	return out


## Reverberation time (s) from a Schroeder curve (1 value per ms): the line through the −5 dB and −25 dB points,
## extended to −60 dB. −1 when the curve does not reach −25 dB.
static func rt60(curve: PackedFloat32Array) -> float:
	var t5 := -1
	var t25 := -1
	for k in curve.size():
		if t5 < 0 and curve[k] <= -5.0:
			t5 = k
		if t25 < 0 and curve[k] <= -25.0:
			t25 = k
			break
	if t5 < 0 or t25 <= t5:
		return -1.0
	return 3.0 * float(t25 - t5) / 1000.0
