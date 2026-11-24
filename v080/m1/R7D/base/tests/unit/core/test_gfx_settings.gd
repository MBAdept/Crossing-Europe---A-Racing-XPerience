extends TestCase
## v0.8.0: graphics mode, sound profile and quality of the mode "Modern" (Gfx, pure) and their storage in the
## settings file version 3 (Settings): migration of older files, the fullscreen trap of the version step, unknown
## keys, the resolution order of the mode and of the sound profile, command line overrides, the crash guard and the
## verdict of the render self-test. Interfaces: docs/dev/v080_contract.md §4.1–§4.3.

const SettingsScript := preload("res://scripts/core/settings.gd")
const DIR := "user://test_gfx_settings"
const FILE := DIR + "/settings.json"
const MARKER := DIR + "/modern_start.lock"
const CLI_KEYS: Array[String] = ["graphics", "sound", "gfx-preset", "gfx"]


## A Settings node on its own test files, loaded from `file_content` (null = no file).
func _settings(file_content: Variant = null) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	JsonFile.remove_all(FILE)
	if file_content != null:
		JsonFile.save_atomic(FILE, file_content)
		JsonFile.remove(FILE + JsonFile.BAK_SUFFIX)
	var s: Node = SettingsScript.new()
	s.set("file_path", FILE)
	s.set("marker_path", MARKER)
	s.call("load_settings")
	return s


func _stored() -> Dictionary:
	var d: Variant = ConfigLoader.load_json(FILE)
	return d if d is Dictionary else {}


## Runs `body` with command line arguments set (CliArgs caches the parsed arguments in a shared dictionary).
func _with_cli(args: Dictionary, body: Callable) -> void:
	var all := CliArgs.all()
	var before := {}
	for k in CLI_KEYS:
		if all.has(k):
			before[k] = all[k]
		all.erase(k)
	for k: String in args:
		all[k] = args[k]
	body.call()
	for k in CLI_KEYS:
		all.erase(k)
	for k: String in before:
		all[k] = before[k]


func _presets() -> Dictionary:
	return ConfigLoader.lookup(cfg(), "graphics.presets", {})


# --- Gfx: adapter, mode, sound ---------------------------------------------------------------------------------

func test_adapter_tiers() -> void:
	assert_eq(Gfx.classify_adapter("llvmpipe (LLVM 20.1.2, 256 bits)", "Mesa"), "software", "llvmpipe")
	assert_eq(Gfx.classify_adapter("ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)), SwiftShader driver)", "Google"), "software", "SwiftShader")
	assert_eq(Gfx.classify_adapter("ANGLE (Microsoft, Microsoft Basic Render Driver Direct3D11 vs_5_0 ps_5_0, D3D11)", "Google Inc. (Microsoft)"), "software", "WARP")
	assert_eq(Gfx.classify_adapter("Some GPU", "Vendor", "OpenGL ES 3.0 (ANGLE, SwiftShader)"), "software", "Software-Pfad nur in der API-Zeile")
	assert_eq(Gfx.classify_adapter("AMD Custom GPU 0405 (radeonsi, vangogh, LLVM 17.0.6, DRM 3.57, 6.5.0-valve22)", "AMD"), "deck", "Deck LCD")
	assert_eq(Gfx.classify_adapter("AMD Custom GPU 0932 (radeonsi, sephiroth, LLVM 17, DRM 3.57)", "AMD"), "deck", "Deck OLED")
	assert_eq(Gfx.classify_adapter("AMD Radeon Graphics (radeonsi, rembrandt)", "AMD", "", true), "deck", "AMD-Handheld unter gamescope")
	assert_eq(Gfx.classify_adapter("AMD Radeon Graphics (radeonsi, rembrandt)", "AMD", "", false), "ok", "dieselbe Grafik auf dem Desktop")
	assert_eq(Gfx.classify_adapter("ANGLE (Intel, Intel(R) HD Graphics 4000 Direct3D11 vs_5_0 ps_5_0, D3D11)", "Google Inc. (Intel)"), "weak", "Intel HD 4000 über ANGLE")
	assert_eq(Gfx.classify_adapter("Mesa Intel(R) UHD Graphics 620 (KBL GT2)", "Intel"), "weak", "Intel UHD 620")
	assert_eq(Gfx.classify_adapter("Mesa Intel(R) UHD Graphics (ICL GT1)", "Intel"), "weak", "Intel UHD ohne Nummer")
	assert_eq(Gfx.classify_adapter("Intel(R) UHD Graphics 770", "Intel"), "ok", "Intel UHD 770")
	assert_eq(Gfx.classify_adapter("NVIDIA GeForce GT 710/PCIe/SSE2", "NVIDIA Corporation"), "weak", "GeForce GT 710")
	assert_eq(Gfx.classify_adapter("NVIDIA GeForce GTX 960/PCIe/SSE2", "NVIDIA Corporation"), "ok", "GeForce GTX 960")
	assert_eq(Gfx.classify_adapter("NVIDIA GeForce RTX 3060/PCIe/SSE2", "NVIDIA Corporation", "4.6.0 NVIDIA 550.54"), "ok", "RTX")
	assert_eq(Gfx.classify_adapter("Mesa Intel(R) Xe Graphics (TGL GT2)", "Intel", "4.6 (Core Profile) Mesa 24.0"), "ok", "Xe")
	assert_eq(Gfx.classify_adapter("", ""), "ok", "ohne Namen (headless)")


func test_recommendations_by_tier() -> void:
	assert_eq(Gfx.recommended_mode("deck"), "modern", "Deck: Modern")
	assert_eq(Gfx.recommended_mode("ok"), "modern", "normale Grafik: Modern")
	assert_eq(Gfx.recommended_mode("weak"), "arcade", "schwache Grafik: Arcade")
	assert_eq(Gfx.recommended_mode("software"), "arcade", "Software-Renderer: Arcade")
	assert_eq(Gfx.recommended_preset("deck"), "deck", "Deck")
	assert_eq(Gfx.recommended_preset("weak"), "low", "schwach")
	assert_eq(Gfx.recommended_preset("software"), "low", "Software")
	assert_eq(Gfx.recommended_preset("ok"), "medium", "normal")


func test_mode_resolution_order() -> void:
	# without a stored choice the game is Arcade – every tool, test and command line start behaves as before v0.8.0
	assert_eq(Gfx.resolve_mode("", "", "", false), {"mode": "arcade", "reason": "default"}, "keine Wahl")
	assert_eq(Gfx.resolve_mode("modern", "", "", false), {"mode": "modern", "reason": ""}, "gewählt Modern")
	assert_eq(Gfx.resolve_mode("arcade", "", "", false), {"mode": "arcade", "reason": ""}, "gewählt Arcade")
	# the command line beats everything (tests, screenshots, rescue switch)
	assert_eq(Gfx.resolve_mode("arcade", "modern", "arcade", true), {"mode": "modern", "reason": "cli"}, "CLI Modern")
	assert_eq(Gfx.resolve_mode("modern", "arcade", "modern", false), {"mode": "arcade", "reason": "cli"}, "CLI Arcade (Notschalter)")
	# config graphics.force_mode beats marker and choice
	assert_eq(Gfx.resolve_mode("arcade", "", "modern", true), {"mode": "modern", "reason": "config"}, "Konfiguration Modern")
	assert_eq(Gfx.resolve_mode("modern", "", "arcade", false), {"mode": "arcade", "reason": "config"}, "Konfiguration Arcade")
	# Modern did not survive its last start: this run is Arcade, the choice stays stored
	assert_eq(Gfx.resolve_mode("modern", "", "", true), {"mode": "arcade", "reason": "crash_guard"}, "Marker")
	assert_eq(Gfx.resolve_mode("", "", "", true), {"mode": "arcade", "reason": "crash_guard"}, "Marker ohne Wahl")
	assert_eq(Gfx.resolve_mode("arcade", "", "", true), {"mode": "arcade", "reason": ""}, "Marker, Arcade gewählt")
	# invalid values count as not given
	assert_eq(Gfx.resolve_mode("ultra", "fast", "retro", false), {"mode": "arcade", "reason": "default"}, "ungültige Werte")
	assert_eq(Gfx.resolve_mode("modern", "fast", "retro", false), {"mode": "modern", "reason": ""}, "ungültige CLI/Konfiguration")


func test_mode_resolution_matrix() -> void:
	# every combination against the rule written out independently: cli > force > marker > choice > arcade
	var values := ["", "arcade", "modern", "bogus"]
	var checked := 0
	for chosen: String in values:
		for cli: String in values:
			for force: String in values:
				for marker: bool in [false, true]:
					var want_mode := "arcade"
					var want_reason := "default"
					if cli == "arcade" or cli == "modern":
						want_mode = cli
						want_reason = "cli"
					elif force == "arcade" or force == "modern":
						want_mode = force
						want_reason = "config"
					elif marker and chosen != "arcade":
						want_reason = "crash_guard"
					elif chosen == "arcade" or chosen == "modern":
						want_mode = chosen
						want_reason = ""
					var got := Gfx.resolve_mode(chosen, cli, force, marker)
					assert_eq(got, {"mode": want_mode, "reason": want_reason}, "Wahl '%s' CLI '%s' Konfiguration '%s' Marker %s" % [chosen, cli, force, marker])
					checked += 1
	assert_eq(checked, 128, "alle Kombinationen")


func test_sound_matrix() -> void:
	# "auto" follows the CHOSEN graphics mode; Arcade while nothing is chosen
	assert_eq(Gfx.resolve_sound("auto", ""), "arcade", "auto, keine Grafikwahl")
	assert_eq(Gfx.resolve_sound("auto", "arcade"), "arcade", "auto, Arcade gewählt")
	assert_eq(Gfx.resolve_sound("auto", "modern"), "modern", "auto, Modern gewählt")
	# an explicit profile is independent of the graphics (weak machines may pick the Modern sound)
	assert_eq(Gfx.resolve_sound("modern", ""), "modern", "Modern-Klang ohne Grafikwahl")
	assert_eq(Gfx.resolve_sound("modern", "arcade"), "modern", "Modern-Klang zu Arcade-Grafik")
	assert_eq(Gfx.resolve_sound("arcade", "modern"), "arcade", "Arcade-Klang zu Modern-Grafik")
	# command line > configuration > setting
	assert_eq(Gfx.resolve_sound("arcade", "arcade", "modern", "arcade"), "modern", "--sound gewinnt")
	assert_eq(Gfx.resolve_sound("modern", "modern", "arcade", "modern"), "arcade", "--sound=arcade gewinnt")
	assert_eq(Gfx.resolve_sound("arcade", "arcade", "", "modern"), "modern", "Konfiguration audio.profile")
	assert_eq(Gfx.resolve_sound("modern", "modern", "", "arcade"), "arcade", "Konfiguration arcade")
	# the whole matrix against the rule written out
	var checked := 0
	for profile: String in ["auto", "arcade", "modern", "bogus"]:
		for chosen: String in ["", "arcade", "modern"]:
			for cli: String in ["", "arcade", "modern", "x"]:
				for force: String in ["", "arcade", "modern"]:
					var want := "arcade"
					if cli == "arcade" or cli == "modern":
						want = cli
					elif force != "":
						want = force
					elif profile == "arcade" or profile == "modern":
						want = profile
					elif chosen == "modern":
						want = "modern"
					assert_eq(Gfx.resolve_sound(profile, chosen, cli, force), want, "Klang '%s' Grafik '%s' CLI '%s' Konfiguration '%s'" % [profile, chosen, cli, force])
					checked += 1
	assert_eq(checked, 144, "alle Kombinationen")


# --- Gfx: quality ----------------------------------------------------------------------------------------------

func test_presets_of_the_configuration() -> void:
	var p := _presets()
	assert_eq(Gfx.quality("deck", {}, p), {"preset": "deck", "shadows": 1, "details": 1, "scale": 100, "aa": 1, "effects": 1}, "Steam Deck")
	assert_eq(Gfx.quality("low", {}, p), {"preset": "low", "shadows": 0, "details": 0, "scale": 75, "aa": 0, "effects": 0}, "Niedrig")
	assert_eq(Gfx.quality("medium", {}, p), {"preset": "medium", "shadows": 2, "details": 1, "scale": 100, "aa": 1, "effects": 1}, "Mittel")
	assert_eq(Gfx.quality("high", {}, p), {"preset": "high", "shadows": 3, "details": 2, "scale": 100, "aa": 2, "effects": 2}, "Hoch")
	for id: String in ["deck", "low", "medium", "high"]:
		assert_eq(Gfx.preset_of(Gfx.quality(id, {}, p), p), id, "Voreinstellung " + id)
		assert_eq(Gfx.quality(id, {}, {}), Gfx.quality(id, {}, p), "ohne Konfiguration dieselben Startwerte: " + id)
	assert_eq(str(Gfx.quality("nonsense", {}, p)["preset"]), "medium", "unbekannte Voreinstellung = Mittel")
	# a damaged configuration entry falls back value by value
	var broken := {"low": {"shadows": "viel", "scale": 85}, "high": 7}
	assert_eq(Gfx.quality("low", {}, broken), {"preset": "low", "shadows": 0, "details": 0, "scale": 85, "aa": 0, "effects": 0}, "kaputter Eintrag")
	assert_eq(Gfx.quality("high", {}, broken), Gfx.quality("high", {}, {}), "kein Wörterbuch")


func test_custom_values_and_limits() -> void:
	var p := _presets()
	var q := Gfx.quality("medium", {}, p)
	q["shadows"] = 0
	assert_eq(Gfx.preset_of(q, p), "custom", "ein Wert geändert = Eigene")
	var c := Gfx.quality("custom", {"shadows": 0, "scale": 125}, p)
	assert_eq(c, {"preset": "custom", "shadows": 0, "details": 1, "scale": 125, "aa": 1, "effects": 1}, "eigene Werte, Rest aus Mittel")
	assert_eq(Gfx.sanitized({"shadows": 9, "details": -1, "scale": 90, "aa": 7, "effects": 3}),
		{"shadows": 3, "details": 0, "scale": 85, "aa": 2, "effects": 2}, "Grenzen, Skalierung auf die nächste Stufe")
	assert_eq(Gfx.sanitized({"scale": 9999})["scale"], 150, "Skalierung oben begrenzt")
	assert_eq(Gfx.sanitized({"scale": 1})["scale"], 50, "Skalierung unten begrenzt")
	assert_eq(Gfx.sanitized({"shadows": "viele", "aa": null, "effects": 1.0}),
		{"shadows": 2, "details": 1, "scale": 100, "aa": 1, "effects": 1}, "keine Zahl = Mittel; Zahlen aus JSON sind float")
	for s in Gfx.SCALE_STEPS:
		assert_eq(Gfx.sanitized({"scale": s})["scale"], s, "Stufe %d bleibt" % s)
	# numbers beyond the integer range and NaN: the range is applied before the conversion (an overflowing
	# conversion came out at the wrong end: aa=1e30 -> 0, scale=-1e400 -> 150, NaN -> 150)
	assert_eq(Gfx.sanitized({"aa": 1e30, "shadows": 1e300, "details": INF, "effects": 4.0e18}),
		{"shadows": 3, "details": 2, "scale": 100, "aa": 2, "effects": 2}, "riesige Werte = oberes Ende")
	assert_eq(Gfx.sanitized({"aa": -1e30, "shadows": -INF, "details": -4.0e18, "effects": -1e300}),
		{"shadows": 0, "details": 0, "scale": 100, "aa": 0, "effects": 0}, "riesige negative Werte = unteres Ende")
	assert_eq(Gfx.sanitized({"scale": INF})["scale"], 150, "Skalierung unendlich = 150")
	assert_eq(Gfx.sanitized({"scale": -INF})["scale"], 50, "Skalierung minus unendlich = 50")
	assert_eq(Gfx.sanitized({"scale": 1e30})["scale"], 150, "Skalierung 1e30 = 150")
	assert_eq(Gfx.sanitized({"scale": NAN, "aa": NAN, "shadows": NAN, "details": NAN, "effects": NAN}),
		{"shadows": 2, "details": 1, "scale": 100, "aa": 1, "effects": 1}, "NaN = fehlt = Mittel")
	assert_eq(Gfx.sanitized({"shadows": 2.5, "details": 0.49, "scale": 92, "aa": -0.4, "effects": 1.5}),
		{"shadows": 3, "details": 0, "scale": 85, "aa": 0, "effects": 2}, "Runden wie bisher (92 liegt gleich weit von 85 und 100: die kleinere Stufe)")


func test_command_line_overrides_of_the_quality() -> void:
	var p := _presets()
	var base := Gfx.quality("medium", {}, p)
	assert_eq(Gfx.with_cli(base, "", "", p), base, "ohne Argumente unverändert")
	assert_eq(Gfx.with_cli(base, "low", "", p), Gfx.quality("low", {}, p), "--gfx-preset=low")
	assert_eq(Gfx.with_cli(base, "custom", "", p), base, "--gfx-preset=custom gibt es nicht")
	assert_eq(Gfx.with_cli(base, "", "shadows=0,scale=75", p),
		{"preset": "custom", "shadows": 0, "details": 1, "scale": 75, "aa": 1, "effects": 1}, "--gfx=shadows=0,scale=75")
	assert_eq(Gfx.with_cli(base, "high", "aa=0", p),
		{"preset": "custom", "shadows": 3, "details": 2, "scale": 100, "aa": 0, "effects": 2}, "Voreinstellung und Einzelwert")
	assert_eq(Gfx.with_cli(base, "", "shadows=1", p)["preset"], "deck", "Einzelwerte, die einer Voreinstellung gleichen, heißen wie sie")
	assert_eq(Gfx.with_cli(base, "", "shadows=99, nonsense=3, details, aa=x", p),
		{"preset": "custom", "shadows": 3, "details": 1, "scale": 100, "aa": 1, "effects": 1}, "begrenzt, Unbekanntes ignoriert")
	assert_eq(Gfx.with_cli(base, "", "aa=1e30,scale=-1e400", p),
		{"preset": "custom", "shadows": 2, "details": 1, "scale": 50, "aa": 2, "effects": 1}, "--gfx mit Zahlen jenseits des Ganzzahlbereichs")


func test_levels_are_flat_typed_renderer_parameters() -> void:
	var g: Dictionary = ConfigLoader.lookup(cfg(), "graphics", {})
	var want_keys := ["preset", "shadows", "details", "scale", "aa", "effects", "shadow_casters", "shadow_splits", "shadow_blend",
		"shadow_atlas", "shadow_distance_m", "shadow_filter", "blob_shadows", "vehicle_lod0_m", "vehicle_lod1_m", "prop_lod0_m",
		"prop_lod1_m", "deco_density", "terrain_outer_m", "glow", "particles", "spray", "wet_reflections", "ssao", "ssao_quality",
		"sky_reflections", "omni_pool", "msaa", "scale_3d"]
	for id: String in ["deck", "low", "medium", "high"]:
		var lv := Gfx.levels(Gfx.quality(id, {}, g.get("presets", {})), g)
		for k: String in want_keys:
			assert_true(lv.has(k), "%s: Schlüssel %s" % [id, k])
		assert_eq(str(lv["preset"]), id, "Name der Voreinstellung")
		assert_true(lv["shadow_atlas"] is int and lv["shadow_blend"] is bool and lv["shadow_distance_m"] is float
			and lv["particles"] is int and lv["glow"] is bool and lv["deco_density"] is float and lv["msaa"] is int
			and lv["scale_3d"] is float, "%s: Typen (JSON-Zahlen umgewandelt)" % id)
		assert_eq(lv, Gfx.levels(Gfx.quality(id, {}, {}), {}), "%s: Konfiguration = eingebaute Startwerte" % id)
	# the tables of the contract (§4.10)
	var low := Gfx.levels(Gfx.quality("low", {}, {}), g)
	assert_true(int(low["shadow_casters"]) == 0 and bool(low["blob_shadows"]) and int(low["shadow_atlas"]) == 1024
		and int(low["shadow_splits"]) == 1, "Schatten Aus: keine Werfer, Blob-Schatten, Atlas 1024")
	assert_true(int(low["msaa"]) == 0 and is_equal_approx(float(low["scale_3d"]), 0.75) and int(low["omni_pool"]) == 2
		and not bool(low["glow"]) and int(low["particles"]) == 300, "Niedrig: MSAA aus, 75 %, 2 Punktlichter")
	var deck := Gfx.levels(Gfx.quality("deck", {}, {}), g)
	assert_true(int(deck["shadow_splits"]) == 2 and int(deck["shadow_atlas"]) == 2048 and is_equal_approx(float(deck["shadow_distance_m"]), 80.0)
		and int(deck["msaa"]) == 2 and int(deck["omni_pool"]) == 4 and bool(deck["sky_reflections"]) and not bool(deck["ssao"]),
		"Steam Deck: 2 Stufen, 2048, 80 m, MSAA 2×, 4 Punktlichter")
	var high := Gfx.levels(Gfx.quality("high", {}, {}), g)
	assert_true(int(high["shadow_splits"]) == 4 and bool(high["shadow_blend"]) and int(high["shadow_atlas"]) == 4096
		and is_equal_approx(float(high["shadow_distance_m"]), 200.0) and int(high["msaa"]) == 4 and int(high["omni_pool"]) == 8
		and is_equal_approx(float(high["terrain_outer_m"]), 1000.0) and bool(high["wet_reflections"]) and bool(high["ssao"])
		and int(high["particles"]) == 4000, "Hoch")
	assert_true(is_equal_approx(float(high["vehicle_lod0_m"]), 60.0) and is_equal_approx(float(high["prop_lod1_m"]), 350.0)
		and is_equal_approx(float(high["deco_density"]), 1.3), "Details Hoch")
	# real lights never exceed 8 omni in any step (D8)
	for e: int in 3:
		assert_true(int(Gfx.levels({"effects": e}, g)["omni_pool"]) <= 8, "höchstens 8 Punktlichter")
	# a configuration next to the executable may tune values and add keys; damage falls back to the start values
	var tuned := {"levels": {"shadows": [{"shadow_atlas": 512.0, "new_key": "x"}], "aa": [0, 2, "viel"], "effects": "kaputt"}}
	var t := Gfx.levels({"shadows": 0, "aa": 2, "effects": 2}, tuned)
	assert_true(t["shadow_atlas"] is int and int(t["shadow_atlas"]) == 512 and str(t["new_key"]) == "x" and bool(t["blob_shadows"]),
		"überlagert, ergänzt, Rest bleibt")
	assert_eq(int(t["msaa"]), 4, "kaputte MSAA-Stufe = Startwert")
	assert_eq(int(t["particles"]), 4000, "kaputte Effekt-Tabelle = Startwerte")


func test_watchdog_verdict() -> void:
	var wd: Dictionary = ConfigLoader.lookup(cfg(), "graphics.watchdog", {})
	var hz60 := 1000.0 / 60.0
	assert_eq(Gfx.watchdog_verdict(15.0, 19.0, hz60, wd, false), "ok", "60 Bilder/s")
	assert_eq(Gfx.watchdog_verdict(24.0, 30.0, hz60, wd, false), "slow", "~40 Bilder/s an 60 Hz")
	assert_eq(Gfx.watchdog_verdict(40.0, 55.0, hz60, wd, false), "slow", "25 Bilder/s, eine Stufe ist noch frei")
	assert_eq(Gfx.watchdog_verdict(40.0, 55.0, hz60, wd, true), "too_slow", "25 Bilder/s auf der niedrigsten Stufe")
	assert_eq(Gfx.watchdog_verdict(17.0, 80.0, hz60, wd, true), "too_slow", "lange Hänger (p95)")
	assert_eq(Gfx.watchdog_verdict(24.0, 30.0, hz60, wd, true), "slow", "etwas langsam auf der niedrigsten Stufe")
	# a Steam Deck capped at 40 Hz is not slow at 25 ms
	assert_eq(Gfx.watchdog_verdict(25.0, 27.0, 25.0, wd, false), "ok", "40 Hz voll erreicht")
	assert_eq(Gfx.watchdog_verdict(36.0, 40.0, 25.0, wd, false), "slow", "28 Bilder/s an 40 Hz")
	assert_eq(Gfx.watchdog_verdict(24.0, 30.0, hz60, {}, false), "slow", "ohne Konfiguration die Startwerte")
	# no usable target (DisplayServer.screen_get_refresh_rate() = -1 for an unknown rate): judged against 60 Hz –
	# not "every frame time is too slow"
	for unknown: float in [-1.0, 0.0, NAN, -INF]:
		assert_eq(Gfx.watchdog_verdict(5.0, 5.0, unknown, wd, true), "ok", "Ziel %s unbekannt: 200 Bilder/s sind nicht langsam" % str(unknown))
		assert_eq(Gfx.watchdog_verdict(15.0, 19.0, unknown, wd, false), "ok", "Ziel %s unbekannt: 60 Bilder/s" % str(unknown))
		assert_eq(Gfx.watchdog_verdict(24.0, 30.0, unknown, wd, false), "slow", "Ziel %s unbekannt: ~40 Bilder/s gegen 60 Hz" % str(unknown))
		assert_eq(Gfx.watchdog_verdict(40.0, 55.0, unknown, wd, true), "too_slow", "Ziel %s unbekannt: 25 Bilder/s auf der niedrigsten Stufe" % str(unknown))
	assert_near(Gfx.WATCHDOG_FALLBACK_TARGET_MS, 16.667, 0.001, "Ersatzziel 60 Hz")


# --- Settings: file version 3 ----------------------------------------------------------------------------------

func test_new_player_has_no_choice_and_saves_none() -> void:
	var s := _settings()
	assert_eq(str(s.get("graphics_mode")), "", "keine Grafikwahl")
	assert_eq(str(s.get("sound_profile")), "auto", "Klang wie Grafik")
	assert_eq(str(s.get("gfx_preset")), "", "keine Voreinstellung gewählt")
	assert_true(bool(s.get("race_music")), "Musik im Rennen an")
	assert_eq(s.call("effective_graphics"), {"mode": "arcade", "reason": "default"}, "ohne Wahl Arcade")
	assert_false(bool(s.call("is_modern")), "nicht Modern")
	assert_eq(str(s.call("sound")), "arcade", "Klang Arcade")
	assert_true(bool(s.call("save_settings")), "speichern")
	var d := _stored()
	assert_eq(int(d.get("settings_version", 0)), 3, "Version 3")
	for k: String in ["graphics_mode", "sound_profile", "gfx_preset", "gfx_custom", "race_music", "fullscreen"]:
		assert_false(d.has(k), "nicht gewählt, nicht gespeichert: " + k)
	s.free()


func test_file_of_v070_keeps_everything_and_gets_no_mode() -> void:
	# v0.6/v0.7 file: version 2, "Vollbild: Aus" chosen. The trap of the version step: a comparison against
	# SETTINGS_VERSION (now 3) would drop this choice.
	assert_eq(int(SettingsScript.SETTINGS_VERSION), 3, "Dateiversion 3")
	assert_eq(int(SettingsScript.FULLSCREEN_CHOICE_SINCE), 2, "Vollbild gilt weiter ab Version 2 als Wahl")
	assert_true(SettingsScript.fullscreen_stored_as_choice({"settings_version": 2, "fullscreen": false}), "v2, Aus: gewählt")
	assert_true(SettingsScript.fullscreen_stored_as_choice({"settings_version": 3, "fullscreen": false}), "v3, Aus: gewählt")
	assert_false(SettingsScript.fullscreen_stored_as_choice({"fullscreen": false}), "ohne Version, Aus: nicht gewählt")
	var s := _settings({"settings_version": 2, "master_volume": 0.5, "sfx_volume": 0.4, "music_volume": 0.3, "fullscreen": false,
		"player_name": "Maik", "vibration": false, "language": "de", "leaderboard_filter": "kombi"})
	s.set("fullscreen", true)          # start value of a small screen …
	s.set("fullscreen_chosen", false)
	s.call("load_settings")             # … the stored choice wins
	assert_false(bool(s.get("fullscreen")), "Vollbild Aus bleibt")
	assert_true(bool(s.get("fullscreen_chosen")), "… und bleibt eine Wahl")
	assert_near(float(s.get("master_volume")), 0.5, 0.0001, "Lautstärke")
	assert_near(float(s.get("sfx_volume")), 0.4, 0.0001, "Effekte")
	assert_near(float(s.get("music_volume")), 0.3, 0.0001, "Musik")
	assert_eq(str(s.get("player_name")), "Maik", "Name")
	assert_false(bool(s.get("vibration")), "Vibration")
	assert_eq(str(s.get("leaderboard_filter")), "kombi", "Filter")
	assert_eq(str(s.get("graphics_mode")), "", "bestehender Spieler: keine Wahl (die Auswahl erscheint einmal)")
	assert_eq(s.call("effective_graphics"), {"mode": "arcade", "reason": "default"}, "bis dahin Arcade")
	assert_false(bool(s.call("has_unsaved_changes")), "nur gelesen: nichts zu speichern")
	s.set("graphics_mode", "modern")
	assert_true(bool(s.call("save_settings")), "speichern")
	var d := _stored()
	assert_eq(int(d.get("settings_version", 0)), 3, "als Version 3 gespeichert")
	assert_eq(str(d.get("graphics_mode", "")), "modern", "Wahl gespeichert")
	assert_true(d.has("fullscreen") and d["fullscreen"] == false, "Vollbild Aus weiter gespeichert")
	assert_false(d.has("sound_profile"), "Klang nicht gewählt: folgt der Grafik")
	s.free()
	# and read again as version 3
	var t: Node = SettingsScript.new()
	t.set("file_path", FILE)
	t.set("fullscreen", true)
	t.set("fullscreen_chosen", false)
	t.call("load_settings")
	assert_false(bool(t.get("fullscreen")), "Version 3: Vollbild Aus bleibt")
	assert_true(bool(t.get("fullscreen_chosen")), "Version 3: gewählt")
	assert_eq(str(t.get("graphics_mode")), "modern", "Grafik gelesen")
	assert_eq(str(t.call("sound")), "modern", "Klang folgt der gewählten Grafik")
	t.free()


func test_file_without_version_migrates() -> void:
	# v0.5.1 and older: no version, "fullscreen" always written – only a stored true is a choice
	var s := _settings({"master_volume": 0.6, "fullscreen": false, "player_name": "Deck"})
	s.set("fullscreen", true)
	s.set("fullscreen_chosen", false)
	s.call("load_settings")
	assert_true(bool(s.get("fullscreen")), "altes 'Aus' ist keine Wahl: der Startwert bleibt")
	assert_false(bool(s.get("fullscreen_chosen")), "nicht gewählt")
	assert_eq(str(s.get("player_name")), "Deck", "Name gelesen")
	assert_eq(str(s.get("graphics_mode")), "", "keine Grafikwahl")
	s.set("master_volume", 0.7)
	s.call("save_settings")
	var d := _stored()
	assert_eq(int(d.get("settings_version", 0)), 3, "Version 3 geschrieben")
	assert_false(d.has("fullscreen"), "nicht gewähltes Vollbild nicht gespeichert")
	s.free()
	var t := _settings({"fullscreen": true})
	assert_true(bool(t.get("fullscreen")) and bool(t.get("fullscreen_chosen")), "altes 'An' bleibt gewählt")
	t.free()


func test_choices_are_stored_once_chosen() -> void:
	var s := _settings({"settings_version": 3})
	s.set("graphics_mode", "modern")
	s.set("sound_profile", "auto")       # chosen on purpose: "Wie Grafik"
	s.set("gfx_custom", {"shadows": 1, "details": 2, "scale": 85, "aa": 0, "effects": 1})
	s.set("gfx_preset", "custom")
	s.set("race_music", false)
	s.call("save_settings")
	var d := _stored()
	assert_eq(str(d.get("graphics_mode", "")), "modern", "Grafik")
	assert_eq(str(d.get("sound_profile", "")), "auto", "gewähltes 'Wie Grafik' wird gespeichert")
	assert_eq(str(d.get("gfx_preset", "")), "custom", "Voreinstellung")
	assert_true(d.get("gfx_custom", null) is Dictionary and int((d["gfx_custom"] as Dictionary).get("scale", 0)) == 85, "eigene Werte")
	assert_true(d.has("race_music") and d["race_music"] == false, "Musik im Rennen aus")
	s.free()
	var t: Node = SettingsScript.new()
	t.set("file_path", FILE)
	t.call("load_settings")
	assert_eq(str(t.get("graphics_mode")), "modern", "Grafik gelesen")
	assert_true(bool(t.get("sound_profile_chosen")), "Klang gewählt")
	assert_false(bool(t.get("race_music")), "Musik aus gelesen")
	assert_true(bool(t.get("race_music_chosen")), "Musik gewählt")
	var q: Dictionary = t.call("quality")
	assert_eq(q, {"preset": "custom", "shadows": 1, "details": 2, "scale": 85, "aa": 0, "effects": 1}, "Qualität aus den eigenen Werten")
	assert_false(bool(t.call("has_unsaved_changes")), "gelesen = gespeichert")
	t.free()


func test_keys_of_a_newer_version_survive() -> void:
	var s := _settings({"settings_version": 4, "graphics_mode": "modern", "hdr": true, "gfx_ray": {"a": 1}, "liste": [1, 2]})
	assert_eq(str(s.get("graphics_mode")), "modern", "bekannte Werte gelesen")
	assert_false(bool(s.call("has_unsaved_changes")), "nur gelesen: nichts zu speichern")
	s.set("master_volume", 0.3)
	s.call("save_settings")
	var d := _stored()
	assert_true(d.get("hdr", false) == true, "unbekannter Schlüssel bleibt")
	assert_true(d.get("gfx_ray", null) is Dictionary and int((d["gfx_ray"] as Dictionary).get("a", 0)) == 1, "unbekanntes Wörterbuch bleibt")
	assert_true(d.get("liste", null) is Array and (d["liste"] as Array).size() == 2, "unbekannte Liste bleibt")
	assert_eq(str(d.get("graphics_mode", "")), "modern", "bekannte Werte bleiben")
	s.free()


func test_damaged_values_count_as_not_chosen() -> void:
	var s := _settings({"settings_version": 3, "graphics_mode": "ultra", "sound_profile": 7, "gfx_preset": "mega",
		"gfx_custom": {"scale": 9999, "shadows": -3}, "race_music": "ja"})
	assert_eq(str(s.get("graphics_mode")), "", "unbekannter Modus = keine Wahl")
	assert_eq(s.call("effective_graphics"), {"mode": "arcade", "reason": "default"}, "also Arcade")
	assert_eq(str(s.get("sound_profile")), "auto", "ungültiger Klang = Wie Grafik")
	assert_false(bool(s.get("sound_profile_chosen")), "… und nicht gewählt")
	assert_eq(str(s.get("gfx_preset")), "", "unbekannte Voreinstellung = Empfehlung")
	assert_eq(s.get("gfx_custom"), {"shadows": 0, "details": 1, "scale": 150, "aa": 1, "effects": 1}, "eigene Werte begrenzt")
	assert_true(bool(s.get("race_music")) and not bool(s.get("race_music_chosen")), "kein Wahrheitswert = nicht gewählt")
	s.call("save_settings")
	var d := _stored()
	assert_false(d.has("graphics_mode") or d.has("sound_profile") or d.has("gfx_preset") or d.has("race_music"), "Ungültiges wird nicht wieder gespeichert")
	s.free()
	# setting invalid values in the running game is ignored the same way
	var t := _settings()
	t.set("graphics_mode", "modern")
	t.set("graphics_mode", "retro")
	assert_eq(str(t.get("graphics_mode")), "", "ungültig gesetzt = keine Wahl")
	t.set("sound_profile", "laut")
	assert_eq(str(t.get("sound_profile")), "auto", "ungültiger Klang gesetzt")
	t.set("gfx_preset", "ultra")
	assert_eq(str(t.get("gfx_preset")), "", "ungültige Voreinstellung gesetzt")
	t.free()


func test_wrongly_typed_old_keys_do_not_stop_the_reading() -> void:
	# one value of the wrong type in a key of v0.7.0 (a hand-edited file, a later version that changes a type) was a
	# script error that ended load_settings(): everything read after it – the graphics mode, the sound profile, the
	# name – and the unknown keys were lost, and the next save removed them from the file
	var files: Array[Dictionary] = [
		{"settings_version": 3, "vibration": "x", "player_name": "Maik", "graphics_mode": "modern", "sound_profile": "modern", "hdr": true},
		{"settings_version": 3, "fullscreen": null, "player_name": "Maik", "graphics_mode": "modern", "sound_profile": "modern", "hdr": true},
		{"settings_version": 3, "master_volume": null, "player_name": "Maik", "graphics_mode": "modern", "sound_profile": "modern", "hdr": true},
		{"settings_version": "drei", "sfx_volume": "laut", "music_volume": [1], "fullscreen": {"an": 1}, "vibration": [], "language": 5,
			"leaderboard_filter": null, "player_name": "Maik", "graphics_mode": "modern", "sound_profile": "modern", "hdr": true},
	]
	for i in files.size():
		var s := _settings(files[i])
		var tag := "Datei %d: " % i
		assert_eq(str(s.get("player_name")), "Maik", tag + "Name gelesen")
		assert_eq(str(s.get("graphics_mode")), "modern", tag + "Grafikmodus gelesen")
		assert_eq(str(s.get("sound_profile")), "modern", tag + "Klangprofil gelesen")
		assert_eq(s.call("effective_graphics"), {"mode": "modern", "reason": ""}, tag + "also Modern")
		assert_near(float(s.get("master_volume")), 0.8, 0.0001, tag + "Lautstärke: Startwert")
		assert_near(float(s.get("sfx_volume")), 1.0, 0.0001, tag + "Effekte: Startwert")
		assert_near(float(s.get("music_volume")), 0.7, 0.0001, tag + "Musik: Startwert")
		assert_true(bool(s.get("vibration")), tag + "Vibration: Startwert")
		assert_false(bool(s.get("fullscreen_chosen")), tag + "Vollbild nicht gewählt")
		assert_eq(str(s.get("language")), "de", tag + "Sprache: Startwert")
		assert_eq(str(s.get("leaderboard_filter")), "all", tag + "Filter: Startwert")
		s.set("master_volume", 0.33)
		assert_true(bool(s.call("save_settings")), tag + "speichern")
		var d := _stored()
		assert_true(d.get("hdr", false) == true, tag + "unbekannter Schlüssel bleibt in der Datei")
		assert_eq(str(d.get("graphics_mode", "")), "modern", tag + "Grafikmodus bleibt in der Datei")
		assert_eq(str(d.get("sound_profile", "")), "modern", tag + "Klangprofil bleibt in der Datei")
		assert_eq(str(d.get("player_name", "")), "Maik", tag + "Name bleibt in der Datei")
		assert_false(d.has("fullscreen"), tag + "kein Vollbild erfunden")
		s.free()
	# what v0.7.0 read without an error keeps its meaning: numbers as flags, whole numbers as volumes
	var t := _settings({"settings_version": 2, "fullscreen": 0, "vibration": 0.0, "master_volume": 1, "music_volume": 0.25})
	assert_true(bool(t.get("fullscreen_chosen")) and not bool(t.get("fullscreen")), "Vollbild 0 = Aus, gewählt")
	assert_false(bool(t.get("vibration")), "Vibration 0.0 = Aus")
	assert_near(float(t.get("master_volume")), 1.0, 0.0001, "ganze Zahl als Lautstärke")
	assert_near(float(t.get("music_volume")), 0.25, 0.0001, "Musik")
	t.free()
	# the fullscreen trap with damaged values: no bool, no number = not stored; a version that is no number = old file
	assert_false(SettingsScript.fullscreen_stored_as_choice({"settings_version": 3, "fullscreen": "an"}), "Text ist keine Wahl")
	assert_false(SettingsScript.fullscreen_stored_as_choice({"settings_version": 3, "fullscreen": null}), "null ist keine Wahl")
	assert_false(SettingsScript.fullscreen_stored_as_choice({"settings_version": "3", "fullscreen": false}), "Version als Text = alte Datei: Aus zählt nicht")
	assert_true(SettingsScript.fullscreen_stored_as_choice({"settings_version": null, "fullscreen": true}), "Version null = alte Datei: An zählt")


func test_sound_follows_the_chosen_graphics_and_signals() -> void:
	var s := _settings()
	var log: Array[String] = []
	s.connect("graphics_changed", func(m: String) -> void: log.append("gfx:" + m))
	s.connect("sound_profile_changed", func(p: String) -> void: log.append("sound:" + p))
	s.connect("quality_changed", func(q: Dictionary) -> void: log.append("q:" + str(q["preset"])))
	s.set("graphics_mode", "modern")      # the chooser: picture and sound together
	assert_eq(" ".join(log), "gfx:modern sound:modern", "Modern gewählt: Grafik und Klang")
	assert_eq(str(s.call("sound")), "modern", "Klang Modern")
	log.clear()
	s.set("graphics_mode", "modern")
	assert_eq(" ".join(log), "", "derselbe Wert: kein Signal")
	s.set("sound_profile", "arcade")      # options: Modern picture, Arcade sound
	assert_eq(" ".join(log), "sound:arcade", "Klang Arcade gewählt")
	log.clear()
	s.set("graphics_mode", "arcade")
	assert_eq(" ".join(log), "gfx:arcade", "Grafik Arcade: der gewählte Klang bleibt, kein Klang-Signal")
	log.clear()
	s.set("sound_profile", "modern")      # a weak machine: Arcade picture, Modern sound
	assert_eq(str(s.call("sound")), "modern", "Modern-Klang zu Arcade-Grafik")
	assert_eq(str(s.call("effective_graphics")["mode"]), "arcade", "Grafik bleibt Arcade")
	s.set("sound_profile", "auto")
	assert_eq(" ".join(log), "sound:modern sound:arcade", "zurück auf 'Wie Grafik' (Arcade)")
	log.clear()
	s.set("gfx_preset", "high")
	s.set("gfx_custom", {"shadows": 0})
	assert_eq(" ".join(log), "q:high q:high", "Qualität geändert: Voreinstellung, dann eigene Werte (Voreinstellung bleibt)")
	s.free()


func test_quality_of_a_run() -> void:
	var s := _settings()
	# no preset chosen: the one recommended for the adapter tier of this machine
	var tier := str(s.call("adapter_tier"))
	assert_true(["software", "weak", "deck", "ok"].has(tier), "Stufe der Grafikkarte: " + tier)
	var q: Dictionary = s.call("quality")
	assert_eq(str(q["preset"]), Gfx.recommended_preset(tier), "ohne Wahl die empfohlene Voreinstellung")
	s.set("gfx_preset", "high")
	assert_eq(s.call("quality"), Gfx.quality("high", {}, _presets()), "gewählte Voreinstellung")
	var lv: Dictionary = s.call("quality_levels")
	assert_true(str(lv["preset"]) == "high" and int(lv["msaa"]) == 4 and int(lv["shadow_atlas"]) == 4096, "Renderer-Parameter der Voreinstellung")
	s.free()


func test_command_line_beats_the_settings() -> void:
	var s := _settings({"settings_version": 3, "graphics_mode": "arcade", "sound_profile": "arcade", "gfx_preset": "high"})
	_with_cli({"graphics": "modern"}, func() -> void:
		assert_eq(s.call("effective_graphics"), {"mode": "modern", "reason": "cli"}, "--graphics=modern")
		assert_true(bool(s.call("is_modern")), "Modern")
		assert_eq(str(s.call("sound")), "arcade", "--graphics ändert den Klang nicht")
		assert_eq(str(s.get("graphics_mode")), "arcade", "die gespeicherte Wahl bleibt"))
	_with_cli({"graphics": "arcade"}, func() -> void:
		s.set("graphics_mode", "modern")
		s.set("crash_guard", true)
		assert_eq(s.call("effective_graphics"), {"mode": "arcade", "reason": "cli"}, "--graphics=arcade (Notschalter)")
		s.set("crash_guard", false)
		s.set("graphics_mode", "arcade"))
	_with_cli({"graphics": true}, func() -> void:
		assert_eq(s.call("effective_graphics"), {"mode": "arcade", "reason": ""}, "--graphics ohne Wert zählt nicht"))
	_with_cli({"sound": "modern"}, func() -> void:
		assert_eq(str(s.call("sound")), "modern", "--sound=modern")
		assert_eq(str(s.call("effective_graphics")["mode"]), "arcade", "--sound ändert die Grafik nicht"))
	_with_cli({"gfx-preset": "low"}, func() -> void:
		assert_eq(s.call("quality"), Gfx.quality("low", {}, _presets()), "--gfx-preset=low"))
	_with_cli({"gfx": "shadows=0,scale=67"}, func() -> void:
		var q: Dictionary = s.call("quality")
		assert_eq(q, {"preset": "custom", "shadows": 0, "details": 2, "scale": 67, "aa": 2, "effects": 2}, "--gfx=… über 'Hoch'")
		var lv: Dictionary = s.call("quality_levels")
		assert_true(int(lv["shadow_casters"]) == 0 and is_equal_approx(float(lv["scale_3d"]), 0.67), "Renderer-Parameter folgen"))
	assert_eq(s.call("effective_graphics"), {"mode": "arcade", "reason": ""}, "ohne Argumente wieder die Wahl")
	assert_eq(s.call("quality"), Gfx.quality("high", {}, _presets()), "ohne Argumente wieder die Voreinstellung")
	s.free()


func test_crash_guard_marker() -> void:
	var s := _settings({"settings_version": 3, "graphics_mode": "modern"})
	s.call("disarm_crash_guard")
	assert_false(FileAccess.file_exists(MARKER), "kein Marker")
	assert_eq(s.call("effective_graphics"), {"mode": "modern", "reason": ""}, "Modern gewählt")
	s.call("arm_crash_guard")
	assert_true(FileAccess.file_exists(MARKER), "Marker geschrieben")
	assert_true(FileAccess.get_file_as_string(MARKER).begins_with("modern "), "Inhalt des Markers")
	# the marker written by THIS run does not change this run (only the one found at the start does)
	assert_eq(s.call("effective_graphics"), {"mode": "modern", "reason": ""}, "eigener Marker ändert den Lauf nicht")
	# the next start finds it: Arcade, the choice stays
	s.set("crash_guard", FileAccess.file_exists(MARKER))
	assert_eq(s.call("effective_graphics"), {"mode": "arcade", "reason": "crash_guard"}, "Marker des letzten Laufs: Arcade")
	assert_eq(str(s.get("graphics_mode")), "modern", "die Wahl bleibt gespeichert")
	assert_eq(str(s.call("sound")), "modern", "der Klang bleibt Modern (Grafik-Rückfall ändert ihn nicht)")
	# an orderly failure removes the file but keeps this run in Arcade
	s.call("disarm_crash_guard", false)
	assert_false(FileAccess.file_exists(MARKER), "Marker entfernt")
	assert_eq(str(s.call("effective_graphics")["reason"]), "crash_guard", "dieser Lauf bleibt Arcade")
	# Modern has run / the player answered: Modern again
	s.call("arm_crash_guard")
	s.call("disarm_crash_guard")
	assert_false(FileAccess.file_exists(MARKER), "Marker entfernt")
	assert_eq(s.call("effective_graphics"), {"mode": "modern", "reason": ""}, "wieder Modern")
	s.free()
	JsonFile.remove_all(FILE)


## FIX1 (QA QS-04): a SIGTERM while a Modern stage loads leaves the marker like a crash. The first strike keeps the
## stored choice (the title's „Bei Arcade bleiben“ settles only this start), the second in a row stores Arcade; a
## Modern stage that ran properly forgets the strikes.
func test_crash_guard_strikes() -> void:
	var s := _settings({"settings_version": 3, "graphics_mode": "modern"})
	s.call("disarm_crash_guard")
	assert_eq(int(s.call("crash_strikes")), 0, "keine Fehlstarts")
	s.call("arm_crash_guard")                       # the run is killed while Modern loads …
	s.set("crash_guard", FileAccess.file_exists(MARKER))   # … the next start finds the marker
	assert_eq(int(s.call("crash_strikes")), 1, "erster Fehlstart")
	s.call("note_crash_strike")                     # „Bei Arcade bleiben“ the first time
	s.call("disarm_crash_guard", false)
	assert_false(FileAccess.file_exists(MARKER), "Marker entfernt")
	assert_eq(str(s.get("graphics_mode")), "modern", "die Wahl bleibt beim ersten Mal")
	assert_eq(str(s.call("effective_graphics")["reason"]), "crash_guard", "dieser Start bleibt Arcade")
	s.set("crash_guard", false)                     # the next start: Modern again, killed again
	assert_eq(int(s.call("crash_strikes")), 1, "der Fehlstart ist gemerkt")
	s.call("arm_crash_guard")
	s.set("crash_guard", FileAccess.file_exists(MARKER))
	assert_eq(int(s.call("crash_strikes")), 2, "zweiter Fehlstart in Folge")
	# a Modern stage that ran properly settles everything
	s.call("arm_crash_guard")
	s.call("disarm_crash_guard")
	assert_eq(int(s.call("crash_strikes")), 0, "Modern lief: keine Fehlstarts mehr")
	assert_false(FileAccess.file_exists(str(s.call("strikes_path"))), "Datei der Fehlstarts entfernt")
	s.free()
	JsonFile.remove_all(FILE)


# --- render self-test ------------------------------------------------------------------------------------------

func _picture(lit: Color, quad: Color, background: Color) -> Image:
	var img := Image.create(GfxSelfTest.SIZE, GfxSelfTest.SIZE, false, Image.FORMAT_RGBA8)
	img.fill(background)
	var n := float(GfxSelfTest.SIZE)
	img.fill_rect(Rect2i(int(n * GfxSelfTest.LIT_AT.x) - 6, int(n * GfxSelfTest.LIT_AT.y) - 6, 12, 12), lit)
	img.fill_rect(Rect2i(int(n * GfxSelfTest.QUAD_AT.x) - 6, int(n * GfxSelfTest.QUAD_AT.y) - 6, 12, 12), quad)
	return img


func test_self_test_verdict() -> void:
	var good := GfxSelfTest.judge(_picture(Color(0.8, 0.8, 0.8), GfxSelfTest.QUAD_COLOR, Color.BLACK))
	assert_true(bool(good["ok"]) and str(good["reason"]) == "", "gutes Bild: " + str(good))
	assert_eq(str(GfxSelfTest.judge(_picture(Color.BLACK, Color.BLACK, Color.BLACK))["reason"]), "black", "schwarzes Bild")
	assert_eq(str(GfxSelfTest.judge(_picture(Color(0.2, 0.2, 0.2), GfxSelfTest.QUAD_COLOR, Color.BLACK))["reason"]), "black", "Kugel ohne Licht")
	assert_eq(str(GfxSelfTest.judge(_picture(Color(0.8, 0.8, 0.8), Color.BLACK, Color.BLACK))["reason"]), "shader", "Shader-Fläche schwarz")
	assert_eq(str(GfxSelfTest.judge(_picture(Color.WHITE, Color.WHITE, Color.WHITE))["reason"]), "shader", "alles weiß")
	assert_eq(str(GfxSelfTest.judge(_picture(Color(0.8, 0.8, 0.8), Color.MAGENTA, Color.BLACK))["reason"]), "shader", "falsche Shader-Farbe")
	assert_eq(str(GfxSelfTest.judge(_picture(Color(0.8, 0.8, 0.8), GfxSelfTest.QUAD_COLOR, Color(0.5, 0.5, 0.5)))["reason"]), "readback", "Hintergrund nicht schwarz")
	assert_eq(str(GfxSelfTest.judge(null)["reason"]), "readback", "kein Bild")
	assert_false(bool(GfxSelfTest.judge(Image.new())["ok"]), "leeres Bild")
