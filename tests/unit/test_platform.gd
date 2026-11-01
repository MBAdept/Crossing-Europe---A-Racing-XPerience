extends TestCase
## Platform details of the Windows build (docs/windows.md): fullscreen default, window size and position on
## (scaled) Windows desktops, settings file (atomic, saved when the window is closed), override files as
## Windows editors save them (UTF-8 with BOM, CRLF).

const SettingsScript := preload("res://scripts/core/settings.gd")
const DIR := "user://test_platform"
const SETTINGS_FILE := DIR + "/settings.json"


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
	assert_near(SettingsScript.fitted_window_scale(1.0, Vector2(1350, 689), base), 689.0 / 720.0, 0.0001,
		"1366×768 mit 40-px-Taskleiste: kleiner als 1280×720, Titelleiste und Bild bleiben sichtbar")
	assert_near(SettingsScript.fitted_window_scale(1.5, Vector2(1000, 600), base), 1000.0 / 1280.0, 0.0001,
		"kleiner Bildschirm: so groß, wie es passt")
	assert_near(SettingsScript.fitted_window_scale(1.0, Vector2(300, 200), base), 0.5, 0.0001, "nie kleiner als die Hälfte")
	assert_near(SettingsScript.fitted_window_scale(1.25, Vector2(0, 0), base), 1.25, 0.0001,
		"keine Arbeitsfläche gemeldet: nur die Skalierung")


## Client-area position: the frame (title bar 31 px, borders 8 px as on Windows 10/11 at 100 %) is centred
## in the usable area and never starts above it.
func test_window_centred_with_title_bar_on_screen() -> void:
	var deco := Vector2i(16, 39)
	var offset := Vector2i(8, 31)
	assert_eq(SettingsScript.centred_window_position(Rect2i(0, 0, 1366, 728), Vector2i(1225, 689), deco, offset),
		Vector2i(70, 31), "1366×768 mit Taskleiste: Rahmen genau so hoch wie die Arbeitsfläche")
	assert_eq(SettingsScript.centred_window_position(Rect2i(0, 0, 1920, 1040), Vector2i(1280, 720), deco, offset),
		Vector2i(320, 171), "1920×1080: mittig")
	assert_eq(SettingsScript.centred_window_position(Rect2i(-1366, 40, 1366, 728), Vector2i(1225, 689), deco, offset),
		Vector2i(-1296, 71), "Taskleiste oben, Bildschirm links vom Hauptbildschirm")
	assert_eq(SettingsScript.centred_window_position(Rect2i(0, 0, 1280, 720), Vector2i(1280, 720), deco, offset),
		Vector2i(8, 31), "zu groß: Rahmen beginnt oben links, die Titelleiste bleibt erreichbar")


## settings.json is written like the savegame: atomically, the previous version kept as .bak and read if
## the file is damaged; only real changes are written.
func test_settings_file_atomic_with_backup() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	JsonFile.remove_all(SETTINGS_FILE)
	var s := _settings()
	s.call("load_settings")
	assert_false(bool(s.call("has_unsaved_changes")), "frisch geladen: nichts zu speichern")
	assert_false(bool(s.call("save_if_changed")), "ohne Änderung wird nichts geschrieben")
	assert_false(FileAccess.file_exists(SETTINGS_FILE), "ohne Änderung keine Datei")
	s.set("player_name", "Jürgen")
	s.set("fullscreen", true)
	assert_true(bool(s.call("has_unsaved_changes")), "Änderung erkannt")
	assert_true(bool(s.call("save_if_changed")), "Änderung gespeichert")
	assert_false(bool(s.call("has_unsaved_changes")), "danach nichts mehr offen")
	assert_false(FileAccess.file_exists(SETTINGS_FILE + JsonFile.TMP_SUFFIX), "keine Temp-Datei übrig")
	s.set("music_volume", 0.3)
	assert_true(bool(s.call("save_settings")), "zweites Speichern")
	assert_true(FileAccess.file_exists(SETTINGS_FILE + JsonFile.BAK_SUFFIX), "vorige Fassung als .bak")
	var f := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	f.store_string("{\"player_name\": \"Jür")   # cut off while writing
	f.close()
	var t := _settings()
	JsonFile.quiet = true
	t.call("load_settings")
	JsonFile.quiet = false
	assert_eq(str(t.get("player_name")), "Jürgen", "beschädigte Datei: Name aus der vorigen Fassung")
	assert_true(bool(t.get("fullscreen")), "beschädigte Datei: Vollbild aus der vorigen Fassung")
	s.free()
	t.free()
	JsonFile.remove_all(SETTINGS_FILE)


## Closing the window (X, Alt+F4) while the options are open keeps the changes made there.
func test_close_request_saves_unsaved_settings() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	JsonFile.remove_all(SETTINGS_FILE)
	var s := _settings()
	s.call("load_settings")
	s.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_false(FileAccess.file_exists(SETTINGS_FILE), "Schließen ohne Änderung schreibt nichts")
	s.set("fullscreen", true)
	s.set("sfx_volume", 0.4)
	s.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var t := _settings()
	t.call("load_settings")
	assert_true(bool(t.get("fullscreen")), "Vollbild beim Schließen gespeichert")
	assert_near(float(t.get("sfx_volume")), 0.4, 0.0001, "Lautstärke beim Schließen gespeichert")
	s.free()
	t.free()
	JsonFile.remove_all(SETTINGS_FILE)


func _settings() -> Node:
	var s: Node = SettingsScript.new()
	s.set("file_path", SETTINGS_FILE)
	return s


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
