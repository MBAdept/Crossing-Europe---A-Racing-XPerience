extends TestCase
## Platform details of the Windows build (docs/windows.md): fullscreen default and window size on scaled
## Windows desktops (Settings), override files as Windows editors save them (UTF-8 with BOM, CRLF).

const SettingsScript := preload("res://scripts/core/settings.gd")
const DIR := "user://test_platform"


func test_fullscreen_default_by_screen_and_scaling() -> void:
	assert_true(SettingsScript.fullscreen_by_default(800, 1.0), "Steam Deck 1280×800")
	assert_true(SettingsScript.fullscreen_by_default(768, 1.0), "1366×768")
	assert_false(SettingsScript.fullscreen_by_default(900, 1.0), "1600×900")
	assert_false(SettingsScript.fullscreen_by_default(1080, 1.0), "1920×1080 bei 100 %")
	assert_false(SettingsScript.fullscreen_by_default(1080, 1.25), "1920×1080 bei 125 % (wie 864 px)")
	assert_true(SettingsScript.fullscreen_by_default(1080, 1.5), "1920×1080 bei 150 % (wie 720 px)")
	assert_true(SettingsScript.fullscreen_by_default(1600, 2.0), "2560×1600 bei 200 % (wie 800 px)")
	assert_false(SettingsScript.fullscreen_by_default(2160, 2.0), "3840×2160 bei 200 % (wie 1080 px)")
	assert_false(SettingsScript.fullscreen_by_default(1080, 0.5), "Faktor unter 1 zählt wie 1")


func test_window_scale_follows_desktop_scaling_as_far_as_it_fits() -> void:
	var base := Vector2(1280, 720)
	assert_near(SettingsScript.fitted_window_scale(1.0, Vector2(1920, 1010), base), 1.0, 0.0001, "100 %: Fenster bleibt")
	assert_near(SettingsScript.fitted_window_scale(1.25, Vector2(1920, 990), base), 1.25, 0.0001, "1080p bei 125 %: 1600×900")
	assert_near(SettingsScript.fitted_window_scale(2.0, Vector2(3840, 2040), base), 2.0, 0.0001, "4K bei 200 %: 2560×1440")
	assert_near(SettingsScript.fitted_window_scale(2.0, Vector2(2880, 1300), base), 1300.0 / 720.0, 0.0001,
		"zu wenig Höhe: so groß, wie es passt")
	assert_near(SettingsScript.fitted_window_scale(2.0, Vector2(2000, 2000), base), 2000.0 / 1280.0, 0.0001,
		"zu wenig Breite: so groß, wie es passt")
	assert_near(SettingsScript.fitted_window_scale(1.5, Vector2(1000, 600), base), 1.0, 0.0001, "nie kleiner als 1280×720")


## game_config.json / network.json next to the .exe, edited with Notepad: UTF-8 with BOM, CRLF line ends.
func test_override_file_with_bom_and_crlf() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join("game_config_bom.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
	f.store_string("{\r\n  \"fuel\": { \"tow_penalty_s\": 120 },\r\n  \"name\": \"Prüfer – Test\"\r\n}\r\n")
	f.close()
	var d: Variant = ConfigLoader.load_json(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_true(d is Dictionary, "JSON mit BOM und CRLF lesbar")
	if d is Dictionary:
		assert_eq(int(ConfigLoader.lookup(d, "fuel.tow_penalty_s", 0)), 120, "Wert aus der Datei")
		assert_eq(str((d as Dictionary).get("name", "")), "Prüfer – Test", "Umlaut und Halbgeviertstrich")
