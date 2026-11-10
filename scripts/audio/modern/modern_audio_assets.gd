class_name ModernAudioAssets
extends RefCounted
## Sound files of the profile "Modern" (contract §4.7.3, docs/audio-modern.md "Dateien und Manifest"):
## assets/audio/modern/{engines,vehicle,traffic,sfx,ambience,ui,music}/, each folder with its own manifest.json.
##
## manifest.json (format "ce-audio-manifest-1", written by the tools under tools/audio/modern, checked by
## tools/audio/qc/audio_qc.py):
##   {"format": "ce-audio-manifest-1", "folder": "ui", "generator": "<tool that writes the folder>",
##    "sounds": {"<id>": {
##       "file": "x.wav" | "files": ["a.wav", "b.wav"],   one file or variants (one-shots: a random one each time)
##       "kind": "oneshot" | "loop" | "music" | "bank",  bank = raw engine data (<car>.i16 next to <car>.json)
##       "role": "",                                      what the runtime uses it for (music: "title", "race", …)
##       "bus": "MUI", "gain_db": 0.0,                    where and how loud it plays (optional)
##       "lufs": -18.2, "true_peak_db": -3.1,             measured: integrated loudness (BS.1770), true peak
##       "sample_rate": 44100, "channels": 2, "frames": 13230,
##       "loop": [0, 44100] | null,                       loop points in frames [begin, end) – as in the import settings
##       "bpm": 120.0, "beats": 8, "bar_beats": 4,        music: tempo, length in beats, beats per bar
##       "bytes": 52964, "sha256": "…",                   per file (lists for variants)
##       "placeholder": true                              stand-in until the real sound exists (see below)
##    }}}
## Placeholders are only visible with use_placeholders (config audio.modern.placeholders – tests and pipeline
## checks): in a normal run a role without a real sound falls back to the Arcade sound or stays silent, it never
## plays a stand-in.
## Streams are Godot imports (WAV, Ogg Vorbis) loaded on first use and cached; the loop points come from the import
## settings next to the file (the QC tool compares them with the manifest). read_i16() reads raw engine data.

const ROOT := "res://assets/audio/modern"
const FOLDERS: Array[String] = ["engines", "vehicle", "traffic", "sfx", "ambience", "ui", "music"]
const FORMAT := "ce-audio-manifest-1"
const KINDS: Array[String] = ["oneshot", "loop", "music", "bank"]


class Entry:
	var folder := ""
	var id := ""
	var kind := "oneshot"
	var role := ""
	var files: Array[String] = []      ## res:// paths (one, or the variants)
	var bus := ""
	var gain_db := 0.0
	var lufs := 0.0
	var true_peak_db := 0.0
	var sample_rate := 44100
	var channels := 2
	var frames := 0
	var loop_begin := -1               ## frames; −1 = no loop
	var loop_end := -1
	var bpm := 0.0
	var beats := 0
	var bar_beats := 4
	var bytes := 0
	var placeholder := false
	var meta: Dictionary = {}          ## the manifest entry as written (extra keys of later packages)

	func seconds() -> float:
		return float(frames) / maxf(float(sample_rate), 1.0)

	func loops() -> bool:
		return loop_end > loop_begin and loop_begin >= 0


var root := ROOT
var use_placeholders := false
var errors: Array[String] = []
var warnings: Array[String] = []
var folders_loaded: Array[String] = []
var _entries: Dictionary = {}        ## "folder/id" -> Entry
var _streams: Dictionary = {}        ## res:// path -> AudioStream (null = failed)


## Loads every folder's manifest. A missing manifest only means "no sounds there yet" (warning); a broken one is
## an error. Returns true without errors.
func load_all(p_root: String = ROOT) -> bool:
	root = p_root
	errors.clear()
	warnings.clear()
	folders_loaded.clear()
	_entries.clear()
	_streams.clear()
	for f in FOLDERS:
		load_folder(f)
	return errors.is_empty()


func load_folder(folder: String) -> bool:
	var path := root.path_join(folder).path_join("manifest.json")
	if not FileAccess.file_exists(path):
		warnings.append("%s fehlt" % path)
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		errors.append("%s: kein gültiges JSON-Objekt (Zeile %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return false
	var d: Dictionary = json.data
	if str(d.get("format", "")) != FORMAT:
		errors.append("%s: Format \"%s\" statt \"%s\"" % [path, str(d.get("format", "")), FORMAT])
		return false
	var sounds: Variant = d.get("sounds", {})
	if not (sounds is Dictionary):
		errors.append("%s: \"sounds\" fehlt" % path)
		return false
	var before := errors.size()
	for id: String in sounds:
		var m: Variant = sounds[id]
		if not (m is Dictionary):
			errors.append("%s: Eintrag \"%s\" ist kein Objekt" % [path, id])
			continue
		var e := _entry(folder, id, m)
		if e != null:
			_entries[folder + "/" + id] = e
	folders_loaded.append(folder)
	return errors.size() == before


func _entry(folder: String, id: String, m: Dictionary) -> Entry:
	var where := "%s/%s" % [folder, id]
	var e := Entry.new()
	e.folder = folder
	e.id = id
	e.meta = m
	e.kind = str(m.get("kind", "oneshot"))
	if not KINDS.has(e.kind):
		errors.append("%s: unbekannte Art \"%s\"" % [where, e.kind])
		return null
	var names: Array = []
	if m.get("files", null) is Array:
		names = m["files"]
	elif m.get("file", null) is String:
		names = [m["file"]]
	if names.is_empty():
		errors.append("%s: weder \"file\" noch \"files\"" % where)
		return null
	for n: Variant in names:
		var p := root.path_join(folder).path_join(str(n))
		# an imported sound exists in an exported build only as its import (ResourceLoader), raw data as a file
		if not FileAccess.file_exists(p) and not ResourceLoader.exists(p):
			errors.append("%s: Datei %s fehlt" % [where, p])
			return null
		e.files.append(p)
	e.role = str(m.get("role", ""))
	e.bus = str(m.get("bus", ""))
	e.gain_db = float(m.get("gain_db", 0.0))
	e.lufs = float(m.get("lufs", 0.0))
	e.true_peak_db = float(m.get("true_peak_db", 0.0))
	e.sample_rate = int(m.get("sample_rate", 44100))
	e.channels = int(m.get("channels", 2))
	e.frames = int(m.get("frames", 0))
	var loop: Variant = m.get("loop", null)
	if loop is Array and (loop as Array).size() == 2:
		e.loop_begin = int((loop as Array)[0])
		e.loop_end = int((loop as Array)[1])
		if e.loop_end <= e.loop_begin or e.loop_begin < 0 or (e.frames > 0 and e.loop_end > e.frames):
			errors.append("%s: Schleife %s passt nicht zu %d Frames" % [where, str(loop), e.frames])
			return null
	elif e.kind == "loop":
		errors.append("%s: Art \"loop\" ohne Schleifenpunkte" % where)
		return null
	e.bpm = float(m.get("bpm", 0.0))
	e.beats = int(m.get("beats", 0))
	e.bar_beats = int(m.get("bar_beats", 4))
	var by: Variant = m.get("bytes", 0)
	if by is Array:
		for b: Variant in by:
			e.bytes += int(b)
	else:
		e.bytes = int(by)
	e.placeholder = bool(m.get("placeholder", false))
	return e


## The entry of a sound; null when it does not exist or is a placeholder that is not to be used.
func entry(folder: String, id: String) -> Entry:
	var e: Entry = _entries.get(folder + "/" + id)
	if e == null or (e.placeholder and not use_placeholders):
		return null
	return e


func has(folder: String, id: String) -> bool:
	return entry(folder, id) != null


## Ids of a folder (sorted), optionally only of one kind and/or role.
func ids(folder: String, kind: String = "", role: String = "") -> Array[String]:
	var out: Array[String] = []
	for key: String in _entries:
		var e: Entry = _entries[key]
		if e.folder != folder or (e.placeholder and not use_placeholders):
			continue
		if (kind == "" or e.kind == kind) and (role == "" or e.role == role):
			out.append(e.id)
	out.sort()
	return out


## Every entry, also unused placeholders (tools, tests).
func all_entries() -> Array[Entry]:
	var out: Array[Entry] = []
	var keys := _entries.keys()
	keys.sort()
	for k: String in keys:
		out.append(_entries[k])
	return out


## The imported stream of a sound (variant −1 = the first file). null: no such sound, a bank, or not loadable.
func stream(folder: String, id: String, variant: int = -1) -> AudioStream:
	var e := entry(folder, id)
	if e == null or e.kind == "bank":
		return null
	return stream_at(e.files[clampi(variant, 0, e.files.size() - 1)])


func variant_count(folder: String, id: String) -> int:
	var e := entry(folder, id)
	return e.files.size() if e != null else 0


func stream_at(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		var r: Variant = load(path)
		if r is AudioStream:
			s = r
	if s == null:
		warnings.append("%s ist kein importierter Klang" % path)
	_streams[path] = s
	return s


## Bytes of the files of a folder ("" = all), placeholders included.
func bytes_total(folder: String = "") -> int:
	var n := 0
	for key: String in _entries:
		var e: Entry = _entries[key]
		if folder == "" or e.folder == folder:
			n += e.bytes
	return n


## Drops the cached streams (profile ends).
func release() -> void:
	_streams.clear()


## Raw interleaved int16 (little endian) as floats in −1..1 – engine banks (<car>.i16). Empty when the file is
## missing or its size is odd.
static func read_i16(path: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if not FileAccess.file_exists(path):
		return out
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() % 2 != 0:
		return out
	var n := bytes.size() / 2
	out.resize(n)
	var k := 1.0 / 32768.0
	for i in n:
		out[i] = bytes.decode_s16(i * 2) * k
	return out
