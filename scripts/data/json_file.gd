class_name JsonFile
extends RefCounted
## Robust JSON persistence for save data (leaderboards, savegame). Owner: data module.
##  * save_atomic(): writes "<path>.tmp", verifies it, keeps the previous good file as "<path>.bak" and
##    renames the temp file over the target (atomic on POSIX file systems) – a crash never leaves a
##    half-written file behind.
##  * read()/load_dict(): never raise errors for missing or corrupt files (only warnings) and fall back to
##    the ".bak" copy, so a damaged file does not cost the player all records.

const TMP_SUFFIX := ".tmp"
const BAK_SUFFIX := ".bak"
const CORRUPT_SUFFIX := ".corrupt"

## Suppresses the warnings about damaged files (tests that corrupt files on purpose).
static var quiet := false
## Description of the last parse problem of read() ("" if the last read was fine).
static var last_problem := ""


## Parsed JSON of a file, or null if it is missing or not valid JSON (warning only, no error).
static func read(path: String) -> Variant:
	last_problem = ""
	if path == "" or not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		last_problem = "JSON-Datei beschädigt: %s (Zeile %d: %s)" % [path, json.get_error_line(), json.get_error_message()]
		if not quiet:
			push_warning(last_problem)
		return null
	return json.data


## The first of [path, path.bak] that contains a JSON object; {} if none does.
static func load_dict(path: String) -> Dictionary:
	for p in [path, path + BAK_SUFFIX]:
		var d: Variant = read(p)
		if d is Dictionary:
			return d
	return {}


## Writes data as JSON atomically. Returns false if the file could not be written.
static func save_atomic(path: String, data: Variant, indent: String = "\t") -> bool:
	var text := JSON.stringify(data, indent)
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path + TMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Kann %s nicht schreiben (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.flush()
	var write_error := f.get_error()
	f.close()
	if write_error != OK or read(tmp) == null:
		push_warning("Schreiben von %s fehlgeschlagen" % tmp)
		remove(tmp)
		return false
	if FileAccess.file_exists(path) and read(path) != null:
		DirAccess.copy_absolute(_os_path(path), _os_path(path + BAK_SUFFIX))
	var err := DirAccess.rename_absolute(_os_path(tmp), _os_path(path))
	if err != OK:
		# Fallback for file systems without atomic replace: write directly.
		var direct := FileAccess.open(path, FileAccess.WRITE)
		if direct == null:
			push_warning("Kann %s nicht ersetzen (%s)" % [path, error_string(err)])
			return false
		direct.store_string(text)
		direct.close()
		remove(tmp)
	return true


## Keeps a copy of a damaged file ("<path>.corrupt") before it gets overwritten by the next save.
static func preserve_corrupt(path: String) -> void:
	if FileAccess.file_exists(path) and read(path) == null:
		DirAccess.copy_absolute(_os_path(path), _os_path(path + CORRUPT_SUFFIX))


## Removes a file if it exists (no error otherwise).
static func remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_os_path(path))


## Removes the file together with its temp/backup/corrupt companions.
static func remove_all(path: String) -> void:
	for p in [path, path + TMP_SUFFIX, path + BAK_SUFFIX, path + CORRUPT_SUFFIX]:
		remove(p)


static func _os_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path
