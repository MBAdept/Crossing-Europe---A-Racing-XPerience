extends TestCase
## Quality states, slowness watchdog and warm-up plan of the mode "Modern" (scripts/race3d/quality.gd, perf_probe.gd,
## prewarm.gd – pure parts): what a level sets on the viewport and puts back, which values a running stage keeps
## when the watchdog steps down, when the watchdog judges and what it decides, the light situations of the warm-up.

const Quality := preload("res://scripts/race3d/quality.gd")
const PerfProbe := preload("res://scripts/race3d/perf_probe.gd")
const Prewarm := preload("res://scripts/race3d/prewarm.gd")


func _levels(preset: String) -> Dictionary:
	var gfx: Dictionary = ConfigLoader.lookup(cfg(), "graphics", {})
	return Gfx.levels(Gfx.quality(preset, {}, gfx.get("presets", {})), gfx)


func test_viewport_states_are_set_and_put_back() -> void:
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = 1.0
	var q: RefCounted = Quality.new()
	q.call("apply", vp, _levels("high"))
	assert_eq(vp.msaa_3d, Viewport.MSAA_4X, "Hoch: MSAA 4×")
	assert_near(vp.scaling_3d_scale, 1.0, 1.0e-6, "Hoch: 3D-Auflösung 100 %")
	assert_eq(vp.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR, "bilinear – die Anzeigen bleiben scharf")
	var applied: Dictionary = q.get("applied")
	assert_eq(int(applied["shadow_atlas"]), 4096, "Hoch: Schattenatlas 4096")
	assert_eq(int(applied["shadow_filter"]), 2, "Hoch: weicher Filter mittel")
	q.call("apply", vp, _levels("low"))
	assert_eq(vp.msaa_3d, Viewport.MSAA_DISABLED, "Niedrig: ohne MSAA")
	assert_near(vp.scaling_3d_scale, 0.75, 1.0e-6, "Niedrig: 75 %")
	assert_eq(int((q.get("applied") as Dictionary)["shadow_atlas"]), 1024, "Niedrig: Schattenatlas 1024 (Schatten Aus)")
	q.call("restore")
	assert_eq(vp.msaa_3d, Viewport.MSAA_DISABLED, "restore(): MSAA wie vorher")
	assert_near(vp.scaling_3d_scale, 1.0, 1.0e-6, "restore(): Auflösung wie vorher")
	assert_true((q.get("applied") as Dictionary).is_empty(), "nach restore() ist nichts mehr gesetzt")
	q.call("restore")
	assert_near(vp.scaling_3d_scale, 1.0, 1.0e-6, "zweimal restore() schadet nicht")
	vp.free()
	assert_eq(Quality.msaa_mode(0), Viewport.MSAA_DISABLED, "msaa 0")
	assert_eq(Quality.msaa_mode(2), Viewport.MSAA_2X, "msaa 2")
	assert_eq(Quality.msaa_mode(8), Viewport.MSAA_8X, "msaa 8")
	assert_eq(Quality.shadow_filter(0), RenderingServer.SHADOW_QUALITY_HARD, "Filter 0: hart")
	assert_eq(Quality.shadow_filter(1), RenderingServer.SHADOW_QUALITY_SOFT_LOW, "Filter 1: weich niedrig")
	assert_eq(Quality.shadow_filter(2), RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "Filter 2: weich mittel")


func test_step_down_keeps_shader_variants() -> void:
	assert_eq(Quality.lower_preset("high"), "medium", "Hoch → Mittel")
	assert_eq(Quality.lower_preset("medium"), "low", "Mittel → Niedrig")
	assert_eq(Quality.lower_preset("deck"), "low", "Steam Deck → Niedrig")
	assert_eq(Quality.lower_preset("custom"), "low", "Benutzerdefiniert → Niedrig")
	assert_eq(Quality.lower_preset("low"), "", "unter Niedrig gibt es nichts")
	var high := _levels("high")
	var medium := _levels("medium")
	var lowered: Dictionary = Quality.lowered(high, medium)
	for k: String in Quality.FIXED_KEYS:
		assert_eq(lowered[k], high[k], "%s bleibt (Shader-Variante der Etappe)" % k)
	for k: String in ["msaa", "scale_3d", "shadow_casters", "shadow_atlas", "shadow_distance_m", "glow", "ssao", "omni_pool", "prop_lod0_m", "preset"]:
		assert_eq(lowered[k], medium[k], "%s folgt der niedrigeren Voreinstellung" % k)
	var to_low: Dictionary = Quality.lowered(medium, _levels("low"))
	assert_eq(int(to_low["shadow_casters"]), 0, "Mittel → Niedrig: keine Schattenwerfer mehr")
	assert_eq(int(to_low["shadow_splits"]), int(medium["shadow_splits"]), "… der Schattenmodus der Etappe bleibt")
	# no level touches what the player has to react to: the keys of the levels name only shadows, anti-aliasing,
	# resolution, decorative density, LOD distances of scenery and vehicles, effects (Rule 9)
	for k: String in high.keys():
		assert_false(k.contains("marking") or k.contains("guardrail") or k.contains("sign") or k.contains("lamp"), "keine Stufe für „%s“" % k)


func test_watchdog_target() -> void:
	assert_near(PerfProbe.target_frame_ms(60.0, 0), 1000.0 / 60.0, 1.0e-6, "60 Hz")
	assert_near(PerfProbe.target_frame_ms(144.0, 0), 1000.0 / 60.0, 1.0e-6, "144 Hz: 60 Bilder je Sekunde sind nicht langsam")
	assert_near(PerfProbe.target_frame_ms(60.0, 40), 25.0, 1.0e-6, "auf 40 Bilder begrenzt (Steam Deck): 25 ms sind das Ziel")
	assert_near(PerfProbe.target_frame_ms(-1.0, 0), 1000.0 / 60.0, 1.0e-6, "unbekannte Bildwiederholrate: 60 Hz")
	assert_near(PerfProbe.target_frame_ms(40.0, 0), 25.0, 1.0e-6, "40-Hz-Anzeige")


## Feeds a probe with frames of frame_ms during a countdown from 3 s; returns [action of the frame that judged, probe].
func _countdown(frame_ms: float, lowest: bool, on: bool = true, from_s: float = 3.0, after: int = 30) -> Array:
	var probe: RefCounted = PerfProbe.new()
	probe.call("configure", ConfigLoader.lookup(cfg(), "graphics.watchdog", {}), 60.0, 0, on)
	var t := 0
	var left := from_s
	var action := ""
	var judged_at := -1.0
	var us := int(frame_ms * 1000.0)
	for i in int(from_s * 1000.0 / frame_ms) + after:
		t += us
		var f: int = probe.call("frame", t + 1000000)
		left -= frame_ms / 1000.0
		var a: String = probe.call("watch", f, left, lowest)
		if a != "":
			action = a
			judged_at = left
	return [action, probe, judged_at]


func test_watchdog_of_the_countdown() -> void:
	var fast := _countdown(16.7, false)
	assert_eq(str(fast[0]), "", "60 Bilder je Sekunde: kein Eingriff")
	assert_eq(str((fast[1] as RefCounted).get("verdict")), "ok", "Urteil ok")
	var slow := _countdown(40.0, false)
	assert_eq(str(slow[0]), "slow", "25 Bilder je Sekunde im Countdown: eine Stufe herunter")
	assert_eq(str((slow[1] as RefCounted).get("verdict")), "slow", "Urteil langsam")
	assert_true(float(slow[2]) > 0.5, "geurteilt wird im Countdown, vor dem Start (%.2f s vorher)" % float(slow[2]))
	assert_near(float((slow[1] as RefCounted).get("judged_median_ms")), 40.0, 0.01, "Median der gemessenen Bilder")
	var lowest := _countdown(40.0, true)
	assert_eq(str(lowest[0]), "", "auf der niedrigsten Voreinstellung: kein Eingriff …")
	assert_eq(str((lowest[1] as RefCounted).get("verdict")), "too_slow", "… das Urteil „zu langsam“ bleibt für den Ergebnisbildschirm")
	var mild := _countdown(24.0, false)
	assert_eq(str(mild[0]), "slow", "42 Bilder je Sekunde bei 60 Hz: über dem 1,3-fachen der Bildzeit – langsam")
	var off := _countdown(40.0, false, false)
	assert_eq(str(off[0]), "", "abgeschaltet (--gfx-sync, --no-watchdog, headless): kein Urteil")
	assert_eq(str((off[1] as RefCounted).get("verdict")), "", "… keines")
	var none := _countdown(40.0, false, true, 0.0, 200)
	assert_eq(str(none[0]), "", "ohne Countdown: kein Urteil")
	assert_false(bool((none[1] as RefCounted).get("enabled")), "… der Wächter schaltet sich ab")
	# exactly once per stage
	var probe: RefCounted = slow[1]
	assert_eq(str(probe.call("watch", 40000, 1.0, false)), "", "nur ein Urteil je Etappe")
	# a stalled frame (window minimised) is no frame
	var p2: RefCounted = PerfProbe.new()
	p2.call("configure", {}, 60.0, 0, true)
	assert_eq(str(p2.call("watch", 5000000, 2.0, false)), "", "eine Pause von 5 s zählt nicht")
	assert_eq(float(p2.get("_count_t")), 0.0, "… sie geht nicht in die Messung ein")


func test_frame_statistics() -> void:
	var probe: RefCounted = PerfProbe.new()
	var t := 5000000
	assert_eq(int(probe.call("frame", t)), 0, "das erste Bild hat keine Bildzeit")
	for i in 300:
		t += 16000 if i % 20 != 0 else 50000
		probe.call("frame", t)
	assert_near(float(probe.call("median_ms")), 16.0, 0.01, "Median der letzten 240 Bilder")
	assert_near(float(probe.call("p95_ms")), 50.0, 0.01, "95-Prozent-Wert: die langen Bilder")
	var st: Dictionary = probe.call("stats")
	for k: String in ["frame_ms_median", "frame_ms_p95", "start_frame_ms_max", "start_frame_ms_median", "start_frames", "watchdog",
			"watchdog_median_ms", "watchdog_p95_ms", "watchdog_target_ms"]:
		assert_true(st.has(k), "stats(): %s" % k)
	assert_near(float(st["start_frame_ms_max"]), 50.0, 0.01, "längstes Bild der ersten 30 s")
	assert_eq(int(st["start_frames"]), 300, "Bilder der ersten 30 s")
	assert_eq((probe.call("start_frames_ms") as PackedFloat32Array).size(), 300, "… einzeln abrufbar (Aufwärm-Prüfung)")
	# frames later than 30 s after the start are not recorded as start frames
	t += 40000000
	probe.call("frame", t)
	assert_eq(int((probe.call("stats") as Dictionary)["start_frames"]), 300, "nach 30 s wird nichts mehr als Startbild gezählt")


func test_warm_up_phases() -> void:
	assert_eq(Prewarm.PHASES, ["plain", "spot", "omni", "spot_omni"] as Array[String], "vier Lichtsituationen")
	assert_eq(Prewarm.frames_total(), ModernRenderer.WARMUP_FRAMES, "ModernRenderer.WARMUP_FRAMES = Bilder des Aufwärmplans")
	var parent := Node3D.new()
	var plan: RefCounted = Prewarm.new()
	assert_true(bool(plan.call("step", 0, Transform3D.IDENTITY)), "ohne begin() ist nichts zu tun")
	plan.call("begin", parent, 100)
	assert_eq(parent.get_child_count(), 2, "ein Spot und ein Punktlicht")
	var spot: SpotLight3D = null
	var omni: OmniLight3D = null
	for c: Node in parent.get_children():
		if c is SpotLight3D:
			spot = c
		elif c is OmniLight3D:
			omni = c
	assert_true(spot != null and omni != null and not spot.shadow_enabled and not omni.shadow_enabled, "beide ohne Schatten (D5, D8)")
	if spot == null or omni == null:
		parent.free()
		return
	assert_eq(spot.light_cull_mask & 2, 0, "sie lassen den Boden aus wie jedes echte Licht")
	var seen: Array[String] = []
	var frame := 100
	var done := false
	var steps := 0
	while not done and steps < 100:
		seen.append("%s%s" % ["S" if spot.visible else "-", "O" if omni.visible else "-"])
		frame += 1
		done = plan.call("step", frame, Transform3D(Basis.IDENTITY, Vector3(0.0, 3.0, 0.0)))
		steps += 1
	assert_eq(steps, Prewarm.frames_total(), "acht gezeichnete Bilder")
	assert_eq(seen, ["--", "--", "S-", "S-", "-O", "-O", "SO", "SO"] as Array[String], "jede Lichtsituation zwei Bilder lang")
	assert_near(float(plan.call("progress", frame)), 1.0, 1.0e-6, "Fortschritt 1 am Ende")
	assert_true(bool(plan.call("step", frame + 5, Transform3D.IDENTITY)), "fertig bleibt fertig")
	parent.free()
