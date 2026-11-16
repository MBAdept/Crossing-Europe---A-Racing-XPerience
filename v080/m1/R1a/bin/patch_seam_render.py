#!/usr/bin/env python3
"""Scratch (package R1a): adapts tests/race3d/render/check_seam_render.gd to the renderer skeleton.
Usage: patch_seam_render.py <path of check_seam_render.gd>"""
import sys

path = sys.argv[1]
s = open(path, encoding="utf-8").read()


def rep(old, new, count=1):
    global s
    assert s.count(old) == count, (old[:80], s.count(old))
    s = s.replace(old, new)


rep("""## Render checks of the seam between the race session and the Modern renderer (v0.8.0, wave 0) – they need a real
## renderer and a fixed frame rate:""",
    """## Render checks of the seam between the race session and the Modern renderer (v0.8.0) – they need a real
## renderer and a fixed frame rate:""")
rep("""##   modern_bild   a Modern stage draws: sky colour of the palette above the horizon (through the canvas layer),
##                 the ground plane below, the horizon at 45 % of the height, the HUD on top – no black frame
""",
    """##   modern_bild   a Modern stage draws the picture of the renderer skeleton: the sky gradient of the palette above
##                 the horizon row (through the canvas layer), below it the debug road – asphalt, edge lines and
##                 shoulder at the pixels the camera model predicts – and its terrain, the HUD on top; the Camera3D
##                 maps like ChaseCamera3D; render counters; the self-test and the warm-up frames ran before the start
""")

start = s.index("# --- modern_bild ---")
end = s.index("# --- gleiche_zeit ---")
new_block = '''# --- modern_bild -----------------------------------------------------------------------------------------------

## Colour of the built-in sky (scripts/race3d/plain_sky.gd) at a row of a picture `height` rows high: Arcade's
## gradient above the horizon row (45 % of the height), the fog colour below.
func _sky_at(pal: Dictionary, row: float, height: float) -> Color:
	var hy := 0.45 * height
	var my := hy * 0.52
	if row >= hy:
		return pal["fog"]
	if row < my:
		return (pal["sky_top"] as Color).lerp(pal["sky_mid"], (row + 40.0) / (my + 40.0))
	return (pal["sky_mid"] as Color).lerp(pal["sky_bottom"], (row - my) / (hy + 3.0 - my))


func _greenish(c: Color) -> bool:
	return c.g > c.r + 0.05 and c.g > c.b + 0.05


func _check_modern_bild() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0})
	_need(p, _renderer_file(sc) == "modern_renderer.gd", "Modern-Renderer")
	var waited: int = await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 30, 2000)
	var img: Image = await _capture()
	var r: ModernRenderer = sc.get("renderer")
	var pal: Dictionary = Palette.compute(12.0, "normal", ConfigLoader.lookup(ConfigLoader.load_merged(), "daytime", {}), false)
	var w := img.get_width()
	var h := img.get_height()
	_need(p, w == 1280 and h == 720, "Bild 1280×720 (%d×%d)" % [w, h])
	# sky: the palette's gradient above the horizon row (45 % of the height = row 324), at places free of the HUD
	var sky_bad: Array[String] = []
	for at: Vector2i in [Vector2i(400, 40), Vector2i(400, 250), Vector2i(900, 250), Vector2i(400, 318), Vector2i(1000, 318)]:
		var got := img.get_pixel(at.x, at.y)
		var want := _sky_at(pal, float(at.y) + 0.5, 720.0)
		if not _near(got, want, 3.0 / 255.0):
			sky_bad.append("%s: %s statt %s" % [str(at), got.to_html(false), want.to_html(false)])
	_need(p, sky_bad.is_empty(), "Himmelsverlauf der Palette über der Horizontzeile (%s)" % "; ".join(sky_bad))
	# below it the debug road: asphalt, the two edge lines and the shoulder stand where the camera model says
	var view: Dictionary = r.view
	var cam_z := float(view["camera_z"])
	var half := 3.0 * 3.75 * 0.5
	var asphalt_a := Color(0.30, 0.31, 0.34)
	var asphalt_b := Color(0.33, 0.34, 0.37)
	var line := Color(0.92, 0.92, 0.88)
	var shoulder := Color(0.47, 0.46, 0.42)
	var paint_bad: Array[String] = []
	var probes := 0
	for d: float in [14.0, 20.0, 45.0]:
		for probe: Array in [[-(half - 0.3), line, line, "linke Randlinie"], [half - 0.3, line, line, "rechte Randlinie"],
				[0.0, asphalt_a, asphalt_b, "Asphalt"], [half - 1.5, asphalt_a, asphalt_b, "Asphalt neben der Linie"],
				[half + 1.25, shoulder, shoulder, "Bankett"]]:
			var px := r.world_to_screen(cam_z + d, float(probe[0]), 0.02)
			if px.x < 2.0 or px.x > 1277.0 or px.y > 580.0:
				continue   # outside the picture or under the HUD
			probes += 1
			var got := img.get_pixel(int(px.x), int(px.y))
			if px.z <= 0.0 or not (_near(got, probe[1], 4.0 / 255.0) or _near(got, probe[2], 4.0 / 255.0)):
				paint_bad.append("%s %d m voraus bei %d,%d: %s" % [str(probe[3]), int(d), int(px.x), int(px.y), got.to_html(false)])
	_need(p, paint_bad.is_empty() and probes >= 12, "Debug-Straße mit Markierung an den Bildpunkten der Kamera (%d Proben; %s)" % [probes, "; ".join(paint_bad)])
	var grass := img.get_pixel(400, 345)
	_need(p, _greenish(grass), "Gelände unter dem Horizont (%s)" % grass.to_html(false))
	# camera = ChaseCamera3D: the Camera3D of the picture maps as the camera model does
	var worst := 0.0
	for d: float in [10.0, 60.0, 300.0]:
		for x: float in [-9.0, 0.0, 5.0]:
			var a := r.camera.unproject_position(r.road_to_world(cam_z + d, x, 0.3))
			var b := r.world_to_screen(cam_z + d, x, 0.3)
			worst = maxf(worst, Vector2(a.x - b.x, a.y - b.y).length())
	_need(p, worst < 0.02 and r.camera.global_transform.is_equal_approx(r.chase.transform(view, r.path)), "Kamera = ChaseCamera3D (%.4f px)" % worst)
	# the HUD is drawn over the 3D picture: the speedometer's dark dial in the lower right corner
	var dial := img.get_pixel(1140, 660)
	_need(p, dial.get_luminance() < 0.2, "HUD über dem 3D-Bild (Tacho %s)" % dial.to_html(false))
	_need(p, root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Seitenverhältnis expand")
	var snap := r.debug_snapshot()
	var cam: Dictionary = snap.get("camera", {})
	_need(p, cam.has("z") and cam.has("frustum") and (snap.get("chunks", []) as Array).size() >= 8 and (snap.get("quality", {}) as Dictionary).has("msaa"),
		"debug_snapshot mit Kamera, Stücken, Qualität")
	var perf: Dictionary = sc.call("perf_stats")
	_need(p, str(perf.get("mode", "")) == "modern" and int(perf.get("sim_steps", 0)) >= 30, "perf_stats mode modern")
	_need(p, int(perf.get("draw_calls", 0)) >= 5 and int(perf.get("primitives", 0)) > 1000 and float(perf.get("tex_mem_mb", 0.0)) > 0.0,
		"Zähler des Renderers (%d Zeichenaufrufe, %d Dreiecke)" % [int(perf.get("draw_calls", 0)), int(perf.get("primitives", 0))])
	# the first Modern stage of this run: the self-test ran inside prepare(), the start view was drawn before the start
	var st: Dictionary = ModernRenderer.selftest
	_need(p, bool(st.get("ok", false)) and float(st.get("ms", 0.0)) > 0.0 and not st.has("skipped"), "Selbsttest in prepare() (%s)" % str(st))
	_need(p, float(perf.get("prewarm_ms", 0.0)) > 0.0 and float(perf.get("prepare_ms", 0.0)) >= float(perf.get("prewarm_ms", 0.0)),
		"Aufwärmbilder vor dem Start (%.0f ms von %.0f ms Vorbereitung)" % [float(perf.get("prewarm_ms", 0.0)), float(perf.get("prepare_ms", 0.0))])
	_report("modern_bild", p, "Modern (Gerüst): Himmelsverlauf, Debug-Straße an %d vorhergesagten Bildpunkten, Kamera gegen ChaseCamera3D %.4f px, HUD darüber, %d Zeichenaufrufe / %d Dreiecke; Vorbereitung %.0f ms (Selbsttest %.0f ms), %d Bilder bis Schritt 30" % [
		probes, worst, int(perf.get("draw_calls", 0)), int(perf.get("primitives", 0)), float(perf.get("prepare_ms", 0.0)), float(st.get("ms", 0.0)), waited])
	await _free(sc)


'''
s = s[:start] + new_block + s[end:]

rep("""	var sky: Color = pal["sky_mid"]
	# no bars: the rows at the very top (between the HUD panels) show the sky, the very bottom the ground
	_need(p, _near(im.get_pixel(380, 2), sky, 2.5 / 255.0) and im.get_pixel(480, 717).get_luminance() > 0.15, "Modern füllt das Fenster bis an den Rand")
	# horizon at 45 % of the window height
	_need(p, _near(im.get_pixel(380, 318), sky, 2.5 / 255.0) and not _near(im.get_pixel(380, 330), sky, 8.0 / 255.0), "Horizont bei 45 % der Fensterhöhe")
""",
    """	# no bars: the rows at the very top (between the HUD panels) show the sky, the very bottom the ground
	# (row y of the 720 rows of the window shows row y * 800 / 720 of the logical picture)
	_need(p, _near(im.get_pixel(380, 2), _sky_at(pal, 2.5 * 800.0 / 720.0, 800.0), 3.0 / 255.0) and im.get_pixel(480, 717).get_luminance() > 0.15,
		"Modern füllt das Fenster bis an den Rand (%s oben, %s unten)" % [im.get_pixel(380, 2).to_html(false), im.get_pixel(480, 717).to_html(false)])
	# horizon at 45 % of the window height: the sky right above it, the terrain below
	_need(p, _near(im.get_pixel(380, 318), _sky_at(pal, 318.5 * 800.0 / 720.0, 800.0), 3.0 / 255.0) and _greenish(im.get_pixel(380, 345)),
		"Horizont bei 45 %% der Fensterhöhe (%s darüber, %s darunter)" % [im.get_pixel(380, 318).to_html(false), im.get_pixel(380, 345).to_html(false)])
""")
open(path, "w", encoding="utf-8").write(s)
print("ok")
