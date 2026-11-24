extends SceneTree
## Writes LIZENZEN.txt, the licence notices that every release archive carries next to the executable:
##   1. the Godot Engine licence (MIT) and 2. the notices of the engine's third-party parts – both taken
##      from the engine itself (Engine.get_license_text(), get_copyright_info(), get_license_info()), so
##      they always match the Godot version the game is exported with,
##   3. the SIL Open Font License of the bundled fonts (assets/fonts/OFL-*.txt),
##   4. the notice for the map data (Natural Earth, world-atlas: data/map/LICENSE-world-atlas.txt).
## The output only depends on the Godot version and these files (same input, same bytes).
## Usage: godot --headless --path . -s res://tools/write_licenses.gd -- /absolute/path/LIZENZEN.txt
## Called by tools/build_windows.sh and tools/build_release.sh (docs/windows.md).

const FONT_DIR := "res://assets/fonts"
const MAP_LICENSE := "res://data/map/LICENSE-world-atlas.txt"
const RULE := "--------------------------------------------------------------------------------"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path():
		printerr("Aufruf: godot --headless --path . -s res://tools/write_licenses.gd -- /absoluter/Pfad/LIZENZEN.txt")
		quit(2)
		return
	var text := build_text()
	if text == "":
		quit(1)
		return
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	if f == null:
		printerr("Kann %s nicht schreiben (%s)" % [args[0], error_string(FileAccess.get_open_error())])
		quit(1)
		return
	f.store_string(text)
	f.close()
	print("Lizenzhinweise geschrieben: %s (%d Zeichen)" % [args[0], text.length()])
	quit(0)


func build_text() -> String:
	var v := Engine.get_version_info()
	var godot := "%d.%d.%d" % [v["major"], v["minor"], v["patch"]]
	var game := str(ProjectSettings.get_setting("application/config/name", "Crossing Europe"))
	var fonts := font_files()
	var map_text := FileAccess.get_file_as_string(MAP_LICENSE)
	if fonts.is_empty() or map_text == "":
		printerr("Lizenztexte fehlen (%s/OFL-*.txt, %s)" % [FONT_DIR, MAP_LICENSE])
		return ""
	var out := PackedStringArray()
	out.append_array([
		"%s – Lizenzen" % game,
		"=".repeat(("%s – Lizenzen" % game).length()),
		"",
		"Das Spiel ist mit der Godot Engine gebaut und enthält Schriften und Kartendaten Dritter. Deren",
		"Lizenzen verlangen, dass die folgenden Hinweise jeder Kopie des Spiels beiliegen. Die Lizenztexte",
		"stehen im englischen Original.",
		"",
		"  1. Godot Engine %s (MIT-Lizenz), https://godotengine.org/license" % godot,
		"  2. Bestandteile der Godot Engine von Dritten (u. a. FreeType, HarfBuzz, Mbed TLS, SDL, ANGLE)",
		"  3. Schriften Orbitron, Exo 2, Barlow Condensed und Share Tech Mono (SIL Open Font License 1.1)",
		"  4. Kartendaten: Natural Earth (gemeinfrei) über das npm-Paket world-atlas (ISC-Lizenz)",
		"",
	])
	section(out, "1. Godot Engine %s" % godot)
	out.append(Engine.get_license_text().strip_edges())
	out.append("")
	section(out, "2. Bestandteile der Godot Engine von Dritten")
	out.append_array([
		"Angaben der Godot Engine %s selbst (Engine.get_copyright_info(), wie COPYRIGHT.txt im" % godot,
		"Quelltext der Engine); die Lizenztexte folgen nach der Liste.",
		"",
	])
	for component: Dictionary in Engine.get_copyright_info():
		out.append(str(component["name"]))
		var seen := {}
		for part: Dictionary in component["parts"]:
			var key := str(part["copyright"]) + "|" + str(part["license"])
			if seen.has(key):
				continue
			seen[key] = true
			for c in part["copyright"]:
				out.append("  Copyright: %s" % c)
			out.append("  License: %s" % part["license"])
		out.append("")
	var licenses := Engine.get_license_info()
	var names: Array = licenses.keys()
	names.sort()
	for n in names:
		out.append("License: %s" % n)
		out.append(RULE)
		out.append(str(licenses[n]).strip_edges())
		out.append("")
	section(out, "3. Schriften")
	for path in fonts:
		out.append("%s (%s)" % [path.get_file().get_basename().trim_prefix("OFL-"), path.get_file()])
		out.append(RULE)
		out.append(FileAccess.get_file_as_string(path).strip_edges())
		out.append("")
	section(out, "4. Kartendaten")
	out.append_array([
		"Ländergrenzen der Karte: Natural Earth 1:50m Admin 0 – Countries, gemeinfrei (public domain).",
		"Made with Natural Earth. Free vector and raster map data @ naturalearthdata.com.",
		"",
		"Aufbereitet über das npm-Paket world-atlas 2.0.2 (https://github.com/topojson/world-atlas):",
		RULE,
		map_text.strip_edges(),
		"",
	])
	return "\n".join(out)


func section(out: PackedStringArray, title: String) -> void:
	out.append_array(["", title, "=".repeat(title.length()), ""])


func font_files() -> Array[String]:
	var files: Array[String] = []
	for f in DirAccess.get_files_at(FONT_DIR):
		if f.begins_with("OFL-") and f.ends_with(".txt"):
			files.append(FONT_DIR.path_join(f))
	files.sort()
	return files
