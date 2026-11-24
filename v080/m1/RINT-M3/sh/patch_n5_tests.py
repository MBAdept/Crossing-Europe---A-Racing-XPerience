import sys, re
W = sys.argv[1]


def sub(path, old, new, count=1):
    p = W + '/' + path
    s = open(p, encoding='utf-8').read()
    assert old in s, (path, old[:90])
    s = s.replace(old, new, count)
    open(p, 'w', encoding='utf-8').write(s)


T = 'tests/unit/race3d/test_props.gd'
p = W + '/' + T
s = open(p, encoding='utf-8').read()
i0 = s.index('## QR7c-06: the standing camera')
i1 = s.index('\t# the tag override of graphics.modern.props.lod0_m still works')
new = '''## A-26 (RINT-M3, NACH-R7c NR7c-01): the band width follows the camera – ce_lod_band_m = speed × LOD_BAND_S, at once when
## wider, at most LOD_BAND_MAX_M per LOD_BAND_S narrower; 0 while the camera stands (a hard swap at the far end), no change
## while dt is 0 (the stage is prepared). NR7c-02 (a): the builder really SETS the global (ModernMaterials.global_value()),
## standing 0 and at 30 m/s 12 m. The lod0_m override still works per tag (none in the shipped configuration since QR7c-01).
func test_standing_camera_narrows_the_bands() -> void:
	assert_near(Props.band_step(0.0, 30.0, 1.0 / 60.0), 12.0, 1.0e-4, "30 m/s: 12 m (0,4 s Fahrt) sofort")
	assert_near(Props.band_step(0.0, 1.0, 1.0 / 60.0), 0.4, 1.0e-4, "Kriechgang 1 m/s: 0,4 m – kein Raster über Sekunden")
	assert_near(Props.band_step(12.0, 0.0, 0.0), 12.0, 1.0e-6, "dt 0 (Vorbereitung): unverändert")
	var w := 12.0
	for i in 6:
		w = Props.band_step(w, 0.0, 1.0 / 60.0)
	assert_near(w, 12.0 - 6.0 / 60.0 * Props.LOD_BAND_MAX_M / Props.LOD_BAND_S, 1.0e-3, "hält an: das Band zieht sich über die Zeit zusammen")
	for i in 30:
		w = Props.band_step(w, 0.0, 1.0 / 60.0)
	assert_near(w, 0.0, 1.0e-6, "steht: 0 (harter Wechsel am fernen Ende) nach höchstens LOD_BAND_S")
	assert_near(Props.band_step(0.0, 5000.0, 1.0 / 60.0), Props.LOD_BAND_MAX_M, 1.0e-6, "Sprung der Kamera: höchstens LOD_BAND_MAX_M")
	var b := Props.new()
	assert_near(b.lod_band_m(), 0.0, 1.0e-6, "Start einer Etappe: stehende Kamera")
	b.update({"camera_z": 100.0}, 1.0 / 60.0)
	for i in 30:
		b.update({"camera_z": 100.0 + float(i + 1) * 0.5}, 1.0 / 60.0)    # 30 m/s
	assert_near(b.lod_band_m(), 12.0, 1.0e-3, "fährt mit 30 m/s: 12 m")
	assert_near(float(ModernMaterials.global_value("ce_lod_band_m")), 12.0, 1.0e-3, "… und setzt das globale ce_lod_band_m (NR7c-02 a)")
	for i in 30:
		b.update({"camera_z": 115.0}, 1.0 / 60.0)
	assert_near(b.lod_band_m(), 0.0, 1.0e-6, "steht 0,5 s: hart")
	assert_near(float(ModernMaterials.global_value("ce_lod_band_m")), 0.0, 1.0e-6, "… global 0")
	# with the view's own clock (Rule 10): the same view drawn twice changes nothing (check_weather draws a view twice
	# and wants the same picture); the clock, not dt, drives the width
	var c := Props.new()
	c.update({"camera_z": 0.0, "time": 10.0}, 1.0 / 60.0)
	for i in 12:
		c.update({"camera_z": float(i + 1) * 0.05, "time": 10.0 + float(i + 1) / 60.0}, 1.0 / 60.0)    # 3 m/s
	assert_near(c.lod_band_m(), 3.0 * Props.LOD_BAND_S, 1.0e-3, "fährt an mit 3 m/s: 1,2 m nach der Uhr der Ansicht")
	var v13 := {"camera_z": 0.6 + 0.5, "time": 10.2 + 1.0 / 60.0}     # 30 m/s for one frame
	c.update(v13, 1.0 / 60.0)
	var s13 := c.lod_band_m()
	assert_near(s13, 12.0, 1.0e-3, "ein Bild mit 30 m/s: 12 m")
	c.update(v13, 1.0 / 60.0)
	c.update(v13, 1.0 / 60.0)
	assert_near(c.lod_band_m(), s13, 1.0e-6, "dieselbe Ansicht noch zweimal: unverändert (trotz dt > 0)")
'''
s = s[:i0] + new + s[i1:]
s = s.replace('''	assert_true(band.contains("global uniform float ce_lod_still;") and band.contains("float still = clamp(ce_lod_still, 0.0, 1.0);") and band.contains("b = vec4(b.y - w.x, b.y, b.w - w.y, b.w);"),
		"stehende Kamera: das Band zieht sich zusammen (ce_lod_still)")''', '''	assert_true(band.contains("global uniform float ce_lod_band_m;") and band.contains("vec2 w = max(min(vec2(b.y - b.x, b.w - b.z), vec2(max(ce_lod_band_m, 0.0))), vec2(0.001));") and band.contains("b = vec4(b.y - w.x, b.y, b.w - w.y, b.w);"),
		"das Band zieht sich zum fernen Ende auf höchstens ce_lod_band_m zusammen (A-26)")''', 1)
open(p, 'w', encoding='utf-8').write(s)

C = 'tests/race3d/render/check_lod_band.gd'
p = W + '/' + C
s = open(p, encoding='utf-8').read()
s = s.replace('''##   lod_*_stand       FIX-R7c (QR7c-06): the same sweep with ce_lod_still = 1 (a standing camera, the band narrowed to''',
              '''##   lod_*_stand       FIX-R7c (QR7c-06), A-26: the same sweep with ce_lod_band_m = 0 (a standing camera, the band narrowed to''')
s = s.replace('''		# FIX-R7c (QR7c-06): "stand" = the band of the props builder with a standing camera (ce_lod_still = 1)
		ModernMaterials.set_global("ce_lod_still", 1.0 if mode == "stand" else 0.0)''',
              '''		# FIX-R7c (QR7c-06), A-26: "stand" = the band of the props builder with a standing camera (ce_lod_band_m = 0);
		# else wider than any band (the full band – a camera at speed, wider than 2 × 25 m)
		ModernMaterials.set_global("ce_lod_band_m", 0.0 if mode == "stand" else 1.0e4)''')
s = s.replace('''	ModernMaterials.set_global("ce_lod_still", 0.0)''', '''	ModernMaterials.set_global("ce_lod_band_m", 1.0e4)''')
s = s.replace('''ce_lod_still = 1: größte Abweichung''', '''ce_lod_band_m = 0: größte Abweichung''')
open(p, 'w', encoding='utf-8').write(s)
assert 'ce_lod_still' not in s, 'check_lod_band still names ce_lod_still'
print("ok")

# --- NR7c-02 (b) (c) (d) --------------------------------------------------------------------------------------------
P = 'scripts/race3d/builders/props.gd'
sub(P, '''	if eye is Vector3 and holder is Node3D and (holder as Node3D).is_inside_tree():
		var wb: AABB = (holder as Node3D).global_transform * box
		var p: Vector3 = eye
		var near := p.clamp(wb.position, wb.end).distance_to(p)
		# the farthest corner: per axis the end farther from the eye
		var far := (p - wb.position).abs().max((wb.end - p).abs()).length()
		return Vector2(near, far)''', '''	if eye is Vector3 and holder is Node3D and (holder as Node3D).is_inside_tree():
		return box_span(eye, (holder as Node3D).global_transform * box)''')
sub(P, '''## Chunk LOD level 0 / 1 / 2 for a path distance''', '''## (nearest, farthest) distance of a box from point p (pure; RINT-M3, NR7c-02 d: tested against the eight corners).
static func box_span(p: Vector3, wb: AABB) -> Vector2:
	var near := p.clamp(wb.position, wb.end).distance_to(p)
	# the farthest corner: per axis the end farther from the eye
	var far := (p - wb.position).abs().max((wb.end - p).abs()).length()
	return Vector2(near, far)


## Chunk LOD level 0 / 1 / 2 for a path distance''')

sub(T, '''	b.quality_lowered({"prop_lod0_m": 40.0, "prop_lod1_m": 120.0, "shadow_casters": 0, "shadow_distance_m": 0.0, "deco_density": 0.6})
	var want: Dictionary = b.model_bands("props/tree_oak")''', '''	var holder := parent.get_child(0)
	b.update({"camera_z": 198.0 * 3.0 - 300.0}, 0.0)       # the thresholds of the first bands exist
	var old_lo: PackedFloat32Array = holder.get_meta(&"thr_lo")
	b.quality_lowered({"prop_lod0_m": 40.0, "prop_lod1_m": 120.0, "shadow_casters": 0, "shadow_distance_m": 0.0, "deco_density": 0.6})
	var want: Dictionary = b.model_bands("props/tree_oak")
	# RINT-M3 (NR7c-02 b): the thresholds follow the new bands at once – stale ones switched the level nodes at the old
	# distances (between the old and the new band start the node of the coarser level stayed off: holes)
	var new_lo: PackedFloat32Array = holder.get_meta(&"thr_lo")
	assert_true(new_lo.has((want["lod1"] as Vector4).x - Props.LOD_STEP_M) and new_lo != old_lo,
		"neue Schwellen nach quality_lowered (%s statt %s)" % [str(new_lo), str(old_lo)])''')

sub(T, '''## QR7c-03 / QR7c-05: the chunk walks its level nodes only when the span of its instances crosses a threshold (not at every''',
'''## RINT-M3 (NR7c-02 c, d): the reach of the shadow casters is a threshold of its own – a chunk just inside it casts, just
## beyond it not (without the threshold the chunk kept its old state); box_span() gives the nearest point and the
## farthest corner of a box as a loop over the eight corners does.
func test_caster_threshold_and_box_span() -> void:
	var t := _track()
	_put(t, 198, {"kind": "prop", "set": "props/tree_oak", "side": 1, "x": _x(t, 1, 12.0), "scale": 1.0})
	var ctx := _ctx(t, 6)
	var b := Props.new()
	b.apply_quality({"prop_lod0_m": 60.0, "prop_lod1_m": 200.0, "shadow_casters": 2, "shadow_distance_m": 120.0, "deco_density": 1.0})
	var parent := Node3D.new()
	b.commit(ctx, b.build(ctx, b.collect(ctx)), parent)
	var holder := parent.get_child(0)
	var reach := 120.0 + Props.SHADOW_KEEP_M
	var zi := float(holder.get_meta(&"iz0"))
	b.update({"camera_z": zi - (reach - 2.5)}, 0.0)
	assert_true(bool(holder.get_meta(&"cast")), "innerhalb der Schattenreichweite: wirft Schatten")
	assert_true((holder.get_meta(&"thr_hi") as PackedFloat32Array).has(reach), "Schwelle der Schattenwerfer %.0f m" % reach)
	b.update({"camera_z": zi - (reach + 2.5)}, 0.0)
	assert_false(bool(holder.get_meta(&"cast")), "jenseits der Schattenreichweite: keiner")
	parent.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		var box := AABB(Vector3(rng.randf_range(-50, 50), rng.randf_range(-5, 5), rng.randf_range(-50, 50)),
			Vector3(rng.randf_range(1, 40), rng.randf_range(1, 20), rng.randf_range(1, 40)))
		var p := Vector3(rng.randf_range(-80, 80), rng.randf_range(-10, 30), rng.randf_range(-80, 80))
		var far := 0.0
		for k in 8:
			far = maxf(far, box.get_endpoint(k).distance_to(p))
		var span := Props.box_span(p, box)
		assert_near(span.y, far, 1.0e-3, "fernste Ecke wie die Schleife über acht Ecken (%d)" % i)
		assert_true(span.x <= far and span.x >= 0.0, "nächster Punkt nicht ferner")
	_cleanup()


## QR7c-03 / QR7c-05: the chunk walks its level nodes only when the span of its instances crosses a threshold (not at every''')
print("ok tests b-d")

D = 'docs/renderer-modern-gelaende.md'
sub(D, '''- **Stehende Kamera** (FIX-R7c, QR7c-06). Das Band hängt am Abstand; steht die Kamera (Countdown, Stau, Polizei),
  bliebe eine Instanz im Band im Raster zweier Stufen stehen (eine Baumkrone wirkt körnig). Das globale
  `ce_lod_still` (0..1) setzt `props.gd` aus der Kamerageschwindigkeit: unter 1,5 m/s wächst es in 0,4 s auf 1 (wie
  das `xfade` der Fahrzeuge, A-16), beim Anfahren fällt es ebenso schnell auf 0. Der Shader zieht jedes Band zu seinem
  fernen Ende zusammen (bei 1 auf 1 mm: harter Wechsel am Bandende – im ganzen Band steht die feinere Stufe, beim
  Countdown also dieselbe Krone wie vor dem Band, nicht die gröbere); das Zusammenziehen über die Zeit ist selbst ein
  Überblenden durch dasselbe Raster. Ohne `props.gd` (Ausstellungsraum, Prüfszenen) bleibt es 0 (Band wie bisher).
  Render-Prüfung `check_lod_band` „…_stand“: mit `ce_lod_still` = 1 sieht jeder Schritt aus wie der harte Wechsel.''',
'''- **Bandbreite nach der Geschwindigkeit** (A-26, RINT-M3; ersetzt FIX-R7cs `ce_lod_still`). Das Band hängt am
  Abstand; steht oder kriecht die Kamera (Countdown, Stau, Polizei), bliebe eine Instanz im Band sekundenlang im Raster
  zweier Stufen (NACH-R7c NR7c-01: Körnung 4,15 % beim Anfahren gegen 0,67 % im Stand). Das globale `ce_lod_band_m`
  (Meter) setzt `props.gd` aus der Kamerageschwindigkeit: Geschwindigkeit × 0,4 s (`LOD_BAND_S`), sofort, wenn es
  breiter wird, beim Anhalten höchstens 50 m je 0,4 s schmaler (`band_step()`). Der Shader zieht jedes Band zu seinem
  fernen Ende auf höchstens diese Breite zusammen (`w' = min(w, ce_lod_band_m)`, mindestens 1 mm): im Stand ein harter
  Wechsel am Bandende – im ganzen Band steht die feinere Stufe, beim Countdown also dieselbe Krone wie vor dem Band –,
  beim Anfahren und im Kriechgang nur 0,4 s Fahrt breit (kein Raster über Sekunden, kein Hin und Her der Stufen), und
  eine Instanz, die das ferne Ende kreuzt, blendet bei jeder Geschwindigkeit in etwa 0,4 s über (das `xfade` der
  Fahrzeuge, A-16) – ohne Zustand je Instanz. Ohne `props.gd` (Ausstellungsraum, Prüfszenen) gilt der Vorgabewert
  1e4 m (das volle Band). Render-Prüfung `check_lod_band` „…_stand“: mit `ce_lod_band_m` = 0 sieht jeder Schritt aus
  wie der harte Wechsel; `test_props` „standing_camera…“ prüft die Breite und dass `props.gd` das Globale wirklich setzt
  (`ModernMaterials.global_value()`).''')
sub(D, '''`…_stand` – mit `ce_lod_still` = 1 jeder Schritt wie der harte Wechsel am Bandende;''', '''`…_stand` – mit `ce_lod_band_m` = 0 (stehende Kamera) jeder Schritt wie der harte Wechsel am Bandende;''')
print("ok docs")
