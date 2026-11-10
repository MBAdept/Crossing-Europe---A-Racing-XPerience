extends Node
## Autoload "Settings": user preferences stored in user://settings.json.

const PATH := "user://settings.json"
## Version of the settings file ("settings_version"): 2 since only a chosen "Vollbild" is saved (fullscreen_chosen).
## Files without it (v0.5.1 and older) always had "fullscreen", chosen or not – there only a stored true counts as the
## player's choice; a false is taken as not chosen, so the start value applies (a Steam Deck that once saved false
## while docked on a large screen kept starting windowed in game mode – QA v0.5.1 review).
## 3 since v0.8.0: graphics mode, sound profile, quality of the mode "Modern" and music in races ("graphics_mode",
## "sound_profile", "gfx_preset", "gfx_custom", "race_music") – each written only once the player has chosen it;
## keys this version does not know (a newer version's) are kept when saving.
const SETTINGS_VERSION := 3
## Version from which a stored "fullscreen" is the player's choice. A fixed constant, NOT SETTINGS_VERSION: with
## ">= SETTINGS_VERSION" the step to version 3 would discard the "Vollbild: Aus" of every v0.6/v0.7 player.
const FULLSCREEN_CHOICE_SINCE := 2
## Keys this version reads and writes; every other key of the file is kept untouched (_extra).
const KNOWN_KEYS: Array[String] = ["settings_version", "master_volume", "sfx_volume", "music_volume", "fullscreen",
	"vibration", "player_name", "language", "leaderboard_filter", "graphics_mode", "sound_profile", "gfx_preset",
	"gfx_custom", "race_music"]

## The chosen graphics mode changed (options, first-start chooser): "arcade" | "modern" | "" (choice removed).
## It applies in the menus at once, in a race from the next start of a stage (effective_graphics()).
signal graphics_changed(mode: String)
## The quality preset or the custom values of Modern changed: the new quality() set.
signal quality_changed(quality: Dictionary)
## The resolved sound profile (sound()) changed: "arcade" | "modern".
signal sound_profile_changed(profile: String)

var master_volume := 0.8
var sfx_volume := 1.0
var music_volume := 0.7
## "Vollbild". Setting it (options, a settings file) counts as the player's choice (fullscreen_chosen); the start
## value of _ready() does not.
var fullscreen := false:
	set(value):
		fullscreen = value
		fullscreen_chosen = true
## The player chose "Vollbild" (options) or the settings file has it (an old file without SETTINGS_VERSION: only "An"):
## only then it is saved – otherwise the start value (default_fullscreen()) applies at every start, so a file saved
## while the Steam Deck was docked (e.g. by a leaderboard name) does not keep the handheld in a window (QA v0.5.1).
var fullscreen_chosen := false
var vibration := true             ## gamepad vibration in the race (Haptics)
## "Grafik": "arcade" | "modern"; "" = not chosen yet (the game is Arcade then, Gfx.resolve_mode). Any other value
## counts as not chosen.
var graphics_mode := "":
	set(value):
		var v: String = value if Gfx.MODES.has(value) else ""
		if v == graphics_mode:
			return
		var sound_before := sound()
		graphics_mode = v
		graphics_changed.emit(v)
		if sound() != sound_before:
			sound_profile_changed.emit(sound())
## "Klang": "auto" (as the chosen graphics mode) | "arcade" | "modern". Setting it counts as the player's choice
## (sound_profile_chosen) – only then it is saved; an invalid value counts as not chosen ("auto").
var sound_profile := "auto":
	set(value):
		var sound_before := sound()
		sound_profile_chosen = Gfx.SOUND_PROFILES.has(value)
		sound_profile = value if sound_profile_chosen else "auto"
		if sound() != sound_before:
			sound_profile_changed.emit(sound())
var sound_profile_chosen := false
## Quality preset of Modern (Gfx.PRESET_ORDER); "" = not chosen: the one recommended for the graphics adapter.
var gfx_preset := "":
	set(value):
		var v: String = value if Gfx.PRESET_ORDER.has(value) else ""
		if v == gfx_preset:
			return
		gfx_preset = v
		quality_changed.emit(quality())
## The player's own quality values (preset "custom"): {shadows, details, scale, aa, effects}; {} = none yet.
var gfx_custom: Dictionary = {}:
	set(value):
		var v: Dictionary = Gfx.sanitized(value) if not value.is_empty() else {}
		if v == gfx_custom:
			return
		gfx_custom = v
		quality_changed.emit(quality())
## "Musik im Rennen" (sound profile "modern" only). Setting it counts as the player's choice (race_music_chosen).
var race_music := true:
	set(value):
		race_music = value
		race_music_chosen = true
var race_music_chosen := false
## Crash guard of Modern (Gfx.BOOT_MARKER): the marker of the last run was still there when this run started –
## Modern crashed or hung. The run is Arcade then (effective_graphics() reason "crash_guard") until the player
## answers the question on the title or a Modern scene has run (disarm_crash_guard()).
var crash_guard := false
var marker_path := Gfx.BOOT_MARKER   ## file of the crash guard (tests use their own)
var player_name := ""
var language := "de"
var leaderboard_filter := "all"   # "all" or a vehicle type id
var file_path := PATH             ## file of load_settings()/save_settings() (tests use their own)
var _stored := {}                 ## values as last loaded or saved – see has_unsaved_changes()
var _extra: Dictionary = {}       ## keys of the settings file this version does not know: kept when saving
var _tier := ""                   ## adapter_tier() of this run


func _ready() -> void:
	leaderboard_filter = str(ConfigLoader.lookup(ConfigLoader.load_merged(), "leaderboard.default_filter", "all"))
	fullscreen = default_fullscreen()
	fullscreen_chosen = false
	crash_guard = FileAccess.file_exists(marker_path)
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
## only fill a 16:10 screen in full screen), and always in the Steam Deck's game mode (gamescope) – docked with
## the game resolution "Nativ" the screen is 1920×1080, and gamescope would scale a 1280×720 window up softly;
## windowed on larger desktop screens. On Windows measured in units of the scaled desktop: a 1920×1080
## screen at 150 % display scaling counts as 1280×720 (docs/windows.md).
static func default_fullscreen() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return fullscreen_by_default(DisplayServer.screen_get_size().y, desktop_scale(), in_gamescope())


## Decision behind default_fullscreen(): screen height in pixels, desktop scale (1.0 = 100 %), running under
## gamescope (Steam Deck game mode).
static func fullscreen_by_default(screen_height: int, scale: float, gamescope: bool = false) -> bool:
	return gamescope or screen_height / maxf(scale, 1.0) <= 800.0


## True under gamescope, the compositor of the Steam Deck's game mode.
static func in_gamescope() -> bool:
	if OS.get_environment("XDG_CURRENT_DESKTOP").to_lower().contains("gamescope"):
		return true
	return OS.get_environment("GAMESCOPE_WAYLAND_DISPLAY") != ""


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
	if d.has("fullscreen") and fullscreen_stored_as_choice(d):
		fullscreen = bool(d["fullscreen"])   # marks it chosen
	vibration = bool(d.get("vibration", vibration))
	player_name = str(d.get("player_name", player_name))
	language = str(d.get("language", language))
	leaderboard_filter = str(d.get("leaderboard_filter", leaderboard_filter))
	# v0.8.0: only a valid value the file really holds is a choice (anything else: not chosen)
	if d.get("graphics_mode", null) is String and Gfx.MODES.has(d["graphics_mode"]):
		graphics_mode = d["graphics_mode"]
	if d.get("sound_profile", null) is String and Gfx.SOUND_PROFILES.has(d["sound_profile"]):
		sound_profile = d["sound_profile"]   # marks it chosen
	if d.get("gfx_custom", null) is Dictionary and not (d["gfx_custom"] as Dictionary).is_empty():
		gfx_custom = d["gfx_custom"]
	if d.get("gfx_preset", null) is String and Gfx.PRESET_ORDER.has(d["gfx_preset"]):
		gfx_preset = d["gfx_preset"]
	if d.get("race_music", null) is bool:
		race_music = d["race_music"]   # marks it chosen
	_extra = {}
	for k: Variant in d:
		if not KNOWN_KEYS.has(str(k)):
			_extra[k] = d[k]
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


## True if the settings file `d` holds "fullscreen" as the player's choice: always from version
## FULLSCREEN_CHOICE_SINCE (2) on; in an older file (no version, "fullscreen" always written) only a stored true – a
## false may be the start value of a docked Steam Deck or a large screen, saved along with a name or a volume.
static func fullscreen_stored_as_choice(d: Dictionary) -> bool:
	if not d.has("fullscreen"):
		return false
	return int(d.get("settings_version", 1)) >= FULLSCREEN_CHOICE_SINCE or bool(d["fullscreen"])


func to_dict() -> Dictionary:
	var d := {
		"settings_version": SETTINGS_VERSION,
		"master_volume": master_volume, "sfx_volume": sfx_volume, "music_volume": music_volume,
		"vibration": vibration, "player_name": player_name, "language": language,
		"leaderboard_filter": leaderboard_filter,
	}
	if fullscreen_chosen:
		d["fullscreen"] = fullscreen
	if graphics_mode != "":
		d["graphics_mode"] = graphics_mode
	if sound_profile_chosen:
		d["sound_profile"] = sound_profile
	if gfx_preset != "":
		d["gfx_preset"] = gfx_preset
	if not gfx_custom.is_empty():
		d["gfx_custom"] = gfx_custom.duplicate()
	if race_music_chosen:
		d["race_music"] = race_music
	for k: Variant in _extra:
		if not d.has(k):
			d[k] = _extra[k]
	return d


# --- graphics mode, quality and sound profile (v0.8.0, ARCHITECTURE.md §15) ---------------------------------

## The graphics mode a stage started now is drawn in – {"mode": "arcade"|"modern", "reason": ""|"cli"|"config"|
## "crash_guard"|"default"} (Gfx.resolve_mode): command line --graphics= > config graphics.force_mode > crash guard
## > the stored choice > Arcade. The race session asks once per stage (the renderer is never swapped in a stage).
func effective_graphics() -> Dictionary:
	return Gfx.resolve_mode(graphics_mode, CliArgs.get_string("graphics", ""),
		str(ConfigLoader.lookup(ConfigLoader.load_merged(), "graphics.force_mode", "")), crash_guard)


func is_modern() -> bool:
	return str(effective_graphics()["mode"]) == Gfx.MODERN


## Quality of Modern for this run: {"preset", "shadows", "details", "scale", "aa", "effects"} – the stored preset
## (or the one recommended for the graphics adapter), "custom" with the player's own values, overridden by the
## command line (--gfx-preset=, --gfx=key=value,…).
func quality() -> Dictionary:
	var p: Variant = ConfigLoader.lookup(ConfigLoader.load_merged(), "graphics.presets", {})
	var presets: Dictionary = p if p is Dictionary else {}
	var preset := gfx_preset if gfx_preset != "" else Gfx.recommended_preset(adapter_tier())
	return Gfx.with_cli(Gfx.quality(preset, gfx_custom, presets), CliArgs.get_string("gfx-preset", ""),
		CliArgs.get_string("gfx", ""), presets)


## Numeric renderer parameters of quality() (Gfx.levels with config "graphics"): what ModernRenderer.apply_quality()
## gets.
func quality_levels() -> Dictionary:
	var g: Variant = ConfigLoader.lookup(ConfigLoader.load_merged(), "graphics", {})
	var gfx_cfg: Dictionary = g if g is Dictionary else {}
	return Gfx.levels(quality(), gfx_cfg)


## The sound profile – "arcade" | "modern" (Gfx.resolve_sound): command line --sound= > config audio.profile > the
## setting "sound_profile"; "auto" follows the chosen graphics mode, Arcade while none is chosen.
func sound() -> String:
	return Gfx.resolve_sound(sound_profile, graphics_mode, CliArgs.get_string("sound", ""),
		str(ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.profile", "")))


## Tier of the running graphics adapter: "software" | "weak" | "deck" | "ok" (Gfx.classify_adapter).
func adapter_tier() -> String:
	if _tier == "":
		_tier = Gfx.classify_adapter(RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
			RenderingServer.get_video_adapter_api_version(), in_gamescope())
	return _tier


## Crash guard: writes the marker – the race session calls this before it builds the Modern renderer of a stage.
func arm_crash_guard() -> void:
	var f := FileAccess.open(marker_path, FileAccess.WRITE)
	if f != null:
		f.store_line("modern %s %d" % [str(ProjectSettings.get_setting("application/config/version", "")),
			int(Time.get_unix_time_from_system())])
		f.close()


## Crash guard: removes the marker – Modern has drawn for a while (race session), the stage fell back to Arcade or
## left in an orderly way, or the player answered the question on the title. lift = also forget the marker of the
## last run (Modern may be used again in this run); false leaves effective_graphics() as it is.
func disarm_crash_guard(lift: bool = true) -> void:
	if FileAccess.file_exists(marker_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path))
	if lift:
		crash_guard = false


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
