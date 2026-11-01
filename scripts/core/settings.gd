extends Node
## Autoload "Settings": user preferences stored in user://settings.json.

const PATH := "user://settings.json"

var master_volume := 0.8
var sfx_volume := 1.0
var music_volume := 0.7
var fullscreen := false
var player_name := ""
var language := "de"
var leaderboard_filter := "all"   # "all" or a vehicle type id


func _ready() -> void:
	leaderboard_filter = str(ConfigLoader.lookup(ConfigLoader.load_merged(), "leaderboard.default_filter", "all"))
	fullscreen = default_fullscreen()
	load_settings()
	if not CliArgs.has("no-settings-apply"):
		apply()


## Start value of "Vollbild" (until the player sets it in the options): full screen on small screens
## like the Steam Deck's 1280×800, where a 1280×720 window with its title bar does not fit (and the menus
## only fill a 16:10 screen in full screen); windowed on larger screens. On Windows measured in units of
## the scaled desktop: a 1920×1080 screen at 150 % display scaling counts as 1280×720 (docs/windows.md).
static func default_fullscreen() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return fullscreen_by_default(DisplayServer.screen_get_size().y, desktop_scale())


## Decision behind default_fullscreen(): screen height in pixels, desktop scale (1.0 = 100 %).
static func fullscreen_by_default(screen_height: int, scale: float) -> bool:
	return screen_height / maxf(scale, 1.0) <= 800.0


## Display scaling of the Windows desktop (screen DPI / 96, e.g. 1.5 at 150 %), 1.0 on other systems.
## Godot's window does not follow it: at 200 % a 1280×720 window would appear half as big as intended.
static func desktop_scale() -> float:
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return 1.0
	return clampf(DisplayServer.screen_get_dpi() / 96.0, 1.0, 4.0)


## Scale for the window in windowed mode: the desktop scale, at most what fits into `room` (usable screen
## area minus window decorations) with a picture of `base` pixels; 1.0 = leave the window as it is.
static func fitted_window_scale(scale: float, room: Vector2, base: Vector2) -> float:
	return maxf(1.0, minf(scale, minf(room.x / base.x, room.y / base.y)))


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d: Variant = ConfigLoader.load_json(PATH)
	if not d is Dictionary:
		return
	master_volume = float(d.get("master_volume", master_volume))
	sfx_volume = float(d.get("sfx_volume", sfx_volume))
	music_volume = float(d.get("music_volume", music_volume))
	fullscreen = bool(d.get("fullscreen", fullscreen))
	player_name = str(d.get("player_name", player_name))
	language = str(d.get("language", language))
	leaderboard_filter = str(d.get("leaderboard_filter", leaderboard_filter))


func save_settings() -> void:
	var d := {
		"master_volume": master_volume, "sfx_volume": sfx_volume, "music_volume": music_volume,
		"fullscreen": fullscreen, "player_name": player_name, "language": language,
		"leaderboard_filter": leaderboard_filter,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))


func apply() -> void:
	TranslationServer.set_locale(language)
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(max(master_volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not fullscreen:
			_scale_window()


## Windowed on a scaled Windows desktop: enlarges the 1280×720 window by the display scaling (as far as it
## fits on the screen) and centres it. Nothing happens at 100 % and on other systems.
func _scale_window() -> void:
	var scale := desktop_scale()
	if scale <= 1.0:
		return
	var area := DisplayServer.screen_get_usable_rect()
	var deco := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var base := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	var s := fitted_window_scale(scale, Vector2(area.size - deco), base)
	if s <= 1.0:
		return
	var size := Vector2i((base * s).round())
	DisplayServer.window_set_size(size)
	var pos := area.position + Vector2i(Vector2(area.size - size) * 0.5)
	# keep the title bar on the screen (decoration height minus the bottom border)
	pos.y = maxi(pos.y, area.position.y + deco.y - int(deco.x * 0.5))
	DisplayServer.window_set_position(pos)
