import os
os.chdir("/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-10")
p = "assets/shaders/modern/inc/lod_band.gdshaderinc"
s = open(p, encoding="utf-8").read()
old_h = """// speed, ramped over 0.4 s) narrows every band to its middle: a standing camera sees one level per instance, hard, and
// the narrowing over time is itself a cross-fade (the threshold sweeps through the same ordered dither). 0 = the band."""
new_h = """// speed, ramped over 0.4 s) narrows every band towards its FAR end: a standing camera sees one level per instance, hard –
// the finer one through the whole band (the look of the level before the band, not a coarser one) – and the narrowing
// over time is itself a cross-fade (the threshold sweeps through the same ordered dither). 0 = the band."""
assert old_h in s
s = s.replace(old_h, new_h)
old = """	// the band narrowed towards its middle by ce_lod_still (both neighbours narrow the same shared band: still
	// complementary); the shadow pass follows the narrowed band, so a standing camera's caster is the level it shows
	// (at least ±0.5 mm wide: the two shares stay complementary – a narrower band than the 0.001 below would leave a hole)
	vec4 b = lod_band;
	float still = clamp(ce_lod_still, 0.0, 1.0);
	if (still > 0.0) {
		vec2 mid = vec2(b.x + b.y, b.z + b.w) * 0.5;
		vec2 hw = max(vec2(b.y - b.x, b.w - b.z) * 0.5 * (1.0 - still), vec2(0.0005));
		b = vec4(mid.x - hw.x, mid.x + hw.x, mid.y - hw.y, mid.y + hw.y);
	}"""
new = """	// the band narrowed towards its far end by ce_lod_still (both neighbours narrow the same shared band: still
	// complementary); the shadow pass follows the narrowed band, so a standing camera's caster is the level it shows
	// (at least 1 mm wide: the two shares stay complementary – a narrower band than the 0.001 below would leave a hole)
	vec4 b = lod_band;
	float still = clamp(ce_lod_still, 0.0, 1.0);
	if (still > 0.0) {
		vec2 w = max(vec2(b.y - b.x, b.w - b.z) * (1.0 - still), vec2(0.001));
		b = vec4(b.y - w.x, b.y, b.w - w.y, b.w);
	}"""
assert old in s
s = s.replace(old, new)
open(p, "w", encoding="utf-8").write(s)

p = "tests/unit/race3d/test_props.gd"
s = open(p, encoding="utf-8").read()
old_t = """band.contains("float still = clamp(ce_lod_still, 0.0, 1.0);") and band.contains("* 0.5 * (1.0 - still)")"""
new_t = """band.contains("float still = clamp(ce_lod_still, 0.0, 1.0);") and band.contains("b = vec4(b.y - w.x, b.y, b.w - w.y, b.w);")"""
assert old_t in s
s = s.replace(old_t, new_t)
open(p, "w", encoding="utf-8").write(s)

p = "tests/race3d/render/check_lod_band.gd"
s = open(p, encoding="utf-8").read()
old_c = """			var end_a := d - span + float(k) * STEP_M
			var w := clampf(end_a * fade.x, fade.y, fade.z)
			_set_band(model_id, a, Vector4(-2.0, -1.0, end_a - w, end_a + w))
			_set_band(model_id, b, Vector4(end_a - w, end_a + w, Props.LOD_ENDLESS, 2.0 * Props.LOD_ENDLESS))"""
new_c = """			var end_a := d - span + float(k) * STEP_M
			var w := clampf(end_a * fade.x, fade.y, fade.z)
			# a standing camera narrows the band to its far end: the band (end_a - 2w, end_a) swaps hard at end_a, as
			# the hard band of the same step does
			var mid_a := end_a - w if mode == "stand" else end_a
			_set_band(model_id, a, Vector4(-2.0, -1.0, mid_a - w, mid_a + w))
			_set_band(model_id, b, Vector4(mid_a - w, mid_a + w, Props.LOD_ENDLESS, 2.0 * Props.LOD_ENDLESS))"""
assert old_c in s
s = s.replace(old_c, new_c)
old_d = """##   lod_*_stand       FIX-R7c (QR7c-06): the same sweep with ce_lod_still = 1 (a standing camera): every step must look
##                     like the hard swap (no dither of two levels at a standstill: countdown, traffic jam, police stop)."""
new_d = """##   lod_*_stand       FIX-R7c (QR7c-06): the same sweep with ce_lod_still = 1 (a standing camera, the band narrowed to
##                     its far end): every step must look like the hard swap at that end (no dither of two levels at a
##                     standstill: countdown, traffic jam, police stop)."""
assert old_d in s
s = s.replace(old_d, new_d)
open(p, "w", encoding="utf-8").write(s)

p = "docs/renderer-modern-gelaende.md"
s = open(p, encoding="utf-8").read()
old_m = """das `xfade` der Fahrzeuge, A-16), beim Anfahren fällt es ebenso schnell auf 0. Der Shader zieht jedes Band um seine
  Mitte zusammen (bei 1 auf ±0,5 mm: harter Wechsel in der Bandmitte); das Zusammenziehen über die Zeit ist selbst ein
  Überblenden durch dasselbe Raster."""
new_m = """das `xfade` der Fahrzeuge, A-16), beim Anfahren fällt es ebenso schnell auf 0. Der Shader zieht jedes Band zu seinem
  fernen Ende zusammen (bei 1 auf 1 mm: harter Wechsel am Bandende – im ganzen Band steht die feinere Stufe, beim
  Countdown also dieselbe Krone wie vor dem Band, nicht die gröbere); das Zusammenziehen über die Zeit ist selbst ein
  Überblenden durch dasselbe Raster."""
assert old_m in s
s = s.replace(old_m, new_m)
open(p, "w", encoding="utf-8").write(s)
print("ok")
