import sys
W = sys.argv[1]


def sub(path, old, new, count=1):
    p = W + '/' + path
    s = open(p, encoding='utf-8').read()
    assert old in s, (path, old[:80])
    s = s.replace(old, new, count)
    open(p, 'w', encoding='utf-8').write(s)


# --- props.gd -------------------------------------------------------------------------------------------------------
P = 'scripts/race3d/builders/props.gd'
sub(P, '''## FIX-R7c (QR7c-06): below this camera speed (m/s) the camera "stands": ce_lod_still goes to 1 over LOD_STILL_S seconds
## (the vehicles' xfade is 0.3–0.5 s, A-16) and every band narrows to a hard swap at its middle – no dithered tree or
## house in the countdown, a traffic jam or a police stop; driving off widens the bands again over the same time
const LOD_STILL_SPEED := 1.5
const LOD_STILL_S := 0.4
''', '''## A-26 (RINT-M3, NACH-R7c NR7c-01; replaces FIX-R7c's binary ce_lod_still): the cross-fade band of every level follows
## the camera's speed – at most speed × LOD_BAND_S metres wide (one global, ce_lod_band_m; inc/lod_band.gdshaderinc
## narrows each band towards its FAR end to that width). A standing camera swaps hard at the far end of a band
## (countdown, traffic jam, police stop); driving off or crawling never leaves an instance in the ordered dither for
## seconds (the band is only as wide as 0.4 s of driving); an instance crossing the far end fades over in about
## LOD_BAND_S at any speed – A-16's 0.3–0.5 s, without state per instance. The width grows with the speed at once and
## shrinks at most LOD_BAND_MAX_M per LOD_BAND_S (a stop sweeps the band's instances through the same dither).
const LOD_BAND_S := 0.4
const LOD_BAND_MAX_M := 50.0       ## no band is wider (LOD_FADE: at most 2 × 25 m); also the cap after a jump
''')
sub(P, '''var _still := 1.0
''', '''var _band_m := 0.0                  ## ce_lod_band_m of this builder (0 = standing: the start of a stage)
''')
sub(P, '''var _still_sent := -1.0             ## value of ce_lod_still last set (-1: never)
''', '''var _band_sent := -1.0              ## value of ce_lod_band_m last set (-1: never)
''')
sub(P, '''## FIX-R7c (QR7c-06): ce_lod_still from the camera's motion along the road. The clock is the view's own "time" (Rule 10)
## where the view has one – the same view drawn twice (render checks, a paused game) changes nothing, the picture stays
## the same –, else dt (dt = 0 while the stage is prepared: no change). Sets the global only when its value changes.''',
'''## A-26: ce_lod_band_m from the camera's motion along the road. The clock is the view's own "time" (Rule 10) where the
## view has one – the same view drawn twice (render checks, a paused game) changes nothing, the picture stays the same –,
## else dt (dt = 0 while the stage is prepared: no change). Sets the global only when its value changes.''')
sub(P, '''	_still = still_step(_still, speed, step)
	if _still != _still_sent:
		_still_sent = _still
		ModernMaterials.set_global("ce_lod_still", _still)


## The next value of ce_lod_still: towards 1 while the camera moves slower than LOD_STILL_SPEED (m/s), towards 0
## otherwise, LOD_STILL_S seconds for the whole way.
static func still_step(still: float, speed: float, dt: float) -> float:
	if dt <= 0.0:
		return still
	return move_toward(still, 1.0 if speed < LOD_STILL_SPEED else 0.0, dt / LOD_STILL_S)


## The current ce_lod_still of this builder (tests, debug).
func lod_still() -> float:
	return _still''', '''	_band_m = band_step(_band_m, speed, step)
	if _band_m != _band_sent:
		_band_sent = _band_m
		ModernMaterials.set_global("ce_lod_band_m", _band_m)


## The next value of ce_lod_band_m (m) at camera speed `speed` (m/s) after dt seconds: speed × LOD_BAND_S (at most
## LOD_BAND_MAX_M) – reached at once when it is wider, at most LOD_BAND_MAX_M per LOD_BAND_S narrower.
static func band_step(band: float, speed: float, dt: float) -> float:
	if dt <= 0.0:
		return band
	var target := clampf(speed * LOD_BAND_S, 0.0, LOD_BAND_MAX_M)
	if target >= band:
		return target
	return move_toward(band, target, dt * LOD_BAND_MAX_M / LOD_BAND_S)


## The current ce_lod_band_m of this builder (tests, debug).
func lod_band_m() -> float:
	return _band_m''')

# --- lod_band.gdshaderinc -------------------------------------------------------------------------------------------
I = 'assets/shaders/modern/inc/lod_band.gdshaderinc'
sub(I, '''// FIX-R7c (QR7c-06): the band hangs on the distance, so an instance inside it would stay in the dither of two levels
// while the camera stands (countdown, traffic jam, police stop). ce_lod_still (0..1, builders/props.gd from the camera's
// speed, ramped over 0.4 s) narrows every band towards its FAR end: a standing camera sees one level per instance, hard –
// the finer one through the whole band (the look of the level before the band, not a coarser one) – and the narrowing
// over time is itself a cross-fade (the threshold sweeps through the same ordered dither). 0 = the band.''',
'''// A-26 (RINT-M3, NACH-R7c NR7c-01; replaces FIX-R7c's binary ce_lod_still): the band hangs on the distance, so an
// instance inside it would stay in the dither of two levels while the camera stands or crawls. ce_lod_band_m (metres,
// builders/props.gd: camera speed × 0.4 s) narrows every band towards its FAR end to at most that width: a standing
// camera (0) sees one level per instance, hard – the finer one through the whole band (the look of the level before the
// band, not a coarser one); an instance crossing the far end fades over in about 0.4 s at any speed; a narrowing over
// time is itself a cross-fade (the threshold sweeps through the same ordered dither). Wider than the band: the band.''')
sub(I, '''global uniform float ce_lod_still;
''', '''global uniform float ce_lod_band_m;
''')
sub(I, '''	// the band narrowed towards its far end by ce_lod_still (both neighbours narrow the same shared band: still
	// complementary); the shadow pass follows the narrowed band, so a standing camera's caster is the level it shows
	// (at least 1 mm wide: the two shares stay complementary – a narrower band than the 0.001 below would leave a hole)
	vec4 b = lod_band;
	float still = clamp(ce_lod_still, 0.0, 1.0);
	if (still > 0.0) {
		vec2 w = max(vec2(b.y - b.x, b.w - b.z) * (1.0 - still), vec2(0.001));
		b = vec4(b.y - w.x, b.y, b.w - w.y, b.w);
	}''', '''	// the band narrowed towards its far end to at most ce_lod_band_m (both neighbours narrow the same shared band:
	// still complementary); the shadow pass follows the narrowed band, so a standing camera's caster is the level it
	// shows (at least 1 mm wide: the two shares stay complementary – a narrower band than the 0.001 below would leave a
	// hole)
	vec4 b = lod_band;
	vec2 w = max(min(vec2(b.y - b.x, b.w - b.z), vec2(max(ce_lod_band_m, 0.0))), vec2(0.001));
	b = vec4(b.y - w.x, b.y, b.w - w.y, b.w);''')

# --- modern_materials.gd --------------------------------------------------------------------------------------------
M = 'scripts/race3d/modern_materials.gd'
sub(M, '''	# FIX-R7c (QR7c-06): 1 = the camera stands – the level bands of the props narrow to a hard swap (inc/lod_band.gdshaderinc);
	# set by builders/props.gd from the camera's speed; 0 = the dither band (every scene without that builder)
	["ce_lod_still", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],''', '''	# A-26 (RINT-M3): the width (m) the level bands of the props narrow to towards their far end
	# (inc/lod_band.gdshaderinc) – camera speed × 0.4 s, set by builders/props.gd; 0 = a hard swap (a standing camera);
	# the default is wider than any band: the full band (every scene without that builder)
	["ce_lod_band_m", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0e4],''')
sub(M, '''static func set_global(name: String, value: Variant) -> void:
	ensure_globals()
	RenderingServer.global_shader_parameter_set(StringName(name), value)''', '''static func set_global(name: String, value: Variant) -> void:
	ensure_globals()
	_globals_set[name] = value
	RenderingServer.global_shader_parameter_set(StringName(name), value)


## The value set_global() last gave `name` in this process (null: never) – tests (NACH-R7c NR7c-02 a: a test can see that
## a builder really sets its global, not only computes it).
static func global_value(name: String) -> Variant:
	return _globals_set.get(name)''')
print("ok")
sub(M, '''static var _globals_added := false
''', '''static var _globals_added := false
static var _globals_set := {}          ## name -> value set_global() last gave it (global_value(), tests)
''')
print("ok2")
