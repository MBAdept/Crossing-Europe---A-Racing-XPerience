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
var file_path := PATH             ## file of load_settings()/save_settings() (tests use their own)
var _stored := {}                 ## values as last loaded or saved – see has_unsaved_changes()


func _ready() -> void:
	leaderboard_filter = str(ConfigLoader.lookup(ConfigLoader.load_merged(), "leaderboard.default_filter", "all"))
	fullscreen = default_fullscreen()
	load_settings()
	if not CliArgs.has("no-settings-apply"):
		apply()


## Closing the window (X button, Alt+F4 – on Windows the usual way to quit) keeps changes that are not
## saved yet: the options screen saves only when it is left. Debug screens with sample data never save.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _sample_mode():
		save_if_changed()


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


## Scale for the window in windowed mode: the desktop scale, but at most what fits into `room` (usable
## screen area minus window decorations) with a picture of `base` pixels – below 1.0 where 1280×720 does
## not fit (1366×768 with the taskbar), never below half the size. No usable area reported: desktop scale.
static func fitted_window_scale(scale: float, room: Vector2, base: Vector2) -> float:
	var wanted := maxf(scale, 1.0)
	if room.x <= 0.0 or room.y <= 0.0:
		return wanted
	return maxf(0.5, minf(wanted, minf(room.x / base.x, room.y / base.y)))


## Position of the client area that centres a window of `size` – plus its decorations `deco`, the client
## area sitting at `offset` inside the frame – in the usable screen area `area`; the frame never starts
## above or left of the area, so the title bar stays reachable.
static func centred_window_position(area: Rect2i, size: Vector2i, deco: Vector2i, offset: Vector2i) -> Vector2i:
	var frame_pos := area.position + (area.size - size - deco) / 2
	return frame_pos.max(area.position) + offset


## Reads the settings file; a damaged file falls back to the previous version (".bak", JsonFile).
func load_settings() -> void:
	var d := JsonFile.load_dict(file_path)
	master_volume = float(d.get("master_volume", master_volume))
	sfx_volume = float(d.get("sfx_volume", sfx_volume))
	music_volume = float(d.get("music_volume", music_volume))
	fullscreen = bool(d.get("fullscreen", fullscreen))
	player_name = str(d.get("player_name", player_name))
	language = str(d.get("language", language))
	leaderboard_filter = str(d.get("leaderboard_filter", leaderboard_filter))
	_stored = to_dict()


## Writes the settings atomically like the savegame (temp file, previous version kept as ".bak"), so a
## crash or power cut while saving never leaves a half-written file. Returns false if writing failed.
func save_settings() -> bool:
	var d := to_dict()
	if not JsonFile.save_atomic(file_path, d):
		return false
	_stored = d
	return true


## Saves only if something changed since the settings were last loaded or saved.
func save_if_changed() -> bool:
	return has_unsaved_changes() and save_settings()


func has_unsaved_changes() -> bool:
	return to_dict() != _stored


func to_dict() -> Dictionary:
	return {
		"master_volume": master_volume, "sfx_volume": sfx_volume, "music_volume": music_volume,
		"fullscreen": fullscreen, "player_name": player_name, "language": language,
		"leaderboard_filter": leaderboard_filter,
	}


func _sample_mode() -> bool:
	var flow: Node = get_node_or_null("/root/GameFlow") if is_inside_tree() else null
	return flow != null and flow.get("sample_mode") == true


func apply() -> void:
	TranslationServer.set_locale(language)
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(max(master_volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not fullscreen:
			_fit_window()


## Windowed on Windows: sizes the 1280×720 window by the display scaling (1600×900 at 125 %) and keeps it,
## title bar included, inside the usable screen area – smaller than 1280×720 where that does not fit
## (1366×768 with the taskbar) –, centred. The picture scales with the window (stretch mode canvas_items).
## A window that already has the right size and lies on the screen stays where it is. Other systems leave
## size and position to the window manager.
func _fit_window() -> void:
	if OS.get_name() != "Windows":
		return
	var area := DisplayServer.screen_get_usable_rect()
	var frame := Rect2i(DisplayServer.window_get_position_with_decorations(), DisplayServer.window_get_size_with_decorations())
	var deco := frame.size - DisplayServer.window_get_size()
	var offset := DisplayServer.window_get_position() - frame.position
	var base := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	var size := Vector2i((base * fitted_window_scale(desktop_scale(), Vector2(area.size - deco), base)).round())
	if size == DisplayServer.window_get_size() and area.encloses(frame):
		return
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(centred_window_position(area, size, deco, offset))
