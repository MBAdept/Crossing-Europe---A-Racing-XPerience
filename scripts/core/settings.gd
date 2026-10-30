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
	load_settings()
	if not CliArgs.has("no-settings-apply"):
		apply()


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
