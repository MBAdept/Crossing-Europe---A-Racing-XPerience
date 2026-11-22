class_name EngineBank2
extends RefCounted
## Stereo engine cycle bank of the sound profile "Modern" (engine v3, format "ce-engine-bank-2";
## docs/motorsound.md "Modern"). Metadata from assets/audio/modern/engines/<car>.json, samples from the raw file named
## in "data" next to it (interleaved int16, 32 kHz stereo, read with ModernAudioAssets.read_i16()). Written by
## tools/audio/modern/engine_synth3.py. load_file() / from_dict() validate: `errors` = unusable (the engine slot then
## only runs its gearbox), `warnings` = tolerated deviations.
##
## Per rpm point three layers, all cut at the same cycle start (arrival of cylinder 1's exhaust pulse):
##   "off"  closed throttle: overrun and idle (stereo)
##   "on"   full load without induction: exhaust, valve rasp, tailpipe jet, mechanics (stereo)
##   "in"   full-throttle induction alone: intake pulses, compressor whoosh (mono)
## Flattened for the mixer (bank index b = rpm index × 3 + layer; LAYER_OFF / LAYER_ON / LAYER_IN):
##   rpms[i], log_rpms[i]            rpm points, ascending
##   periods[b], overlaps[b]         cycle length in frames (float) and crossfade overlap
##   gains[b]                        every bank is stored at full 16-bit scale; × gain = its designed level
##   power[b]                        its designed power (from the measured K-weighted loudness "lufs")
##   xrpm[b]                         coherence with the next lower rpm point of the same layer (−1..1)
##   xload[i]                        coherence between "off" and "on" of rpm point i
##   var_first[b], var_count[b]      its cycle variants in cyc_base[] / cyc_len[] / cyc_mono[]
##   cyc_base[v]                     index of the variant's first sample in `data` (frame × 2, + 1 for a mono
##                                   variant that lives in the right samples); a stereo variant reads data[base + 2k]
##                                   and data[base + 2k + 1], a mono one data[base + 2k]
##   clips[name] = PackedInt32Array [base0, frames0, mono0, base1, frames1, mono1, …]
## `data` = interleaved float samples with PAD silent frames appended (reads just past the last frame stay in range).
## "mix": gain (level of the car, applied after the saturation), off_gain, in_gain (induction), idle_load (share of
## the load layer at idle), clip_gain {name: factor}, load_curve (exponent of the load blend).
## "layers": free-form parameter blocks for the mixer and the vehicle layers (limiter, crackle, shift, saturation,
## turbo, blowoff, driveline, tipin, thump) – read with layer() and defaults at the user.

const FORMAT := "ce-engine-bank-2"
const LAYER_NAMES: Array[String] = ["off", "on", "in"]
const LAYER_OFF := 0
const LAYER_ON := 1
const LAYER_IN := 2
const LAYER_COUNT := 3
const CLIP_NAMES: Array[String] = ["crackle", "shift", "start"]
const PAD := 8
const MIN_RATE := 8000
const MAX_RATE := 96000
const CONTRACT_RATE := 32000
const MAX_SPACING := 1.25
const DIR := "res://assets/audio/modern/engines"

var path := ""
var car := ""
var sample_rate := 32000
var engine: Dictionary = {}
var gearbox: Dictionary = {}
var layers: Dictionary = {}
var clips: Dictionary = {}
var clip_gain: Dictionary = {}
var mix_gain := 1.0
var off_gain := 1.0
var in_gain := 1.0
var idle_load := 0.2
var load_curve := 1.0
var data := PackedFloat32Array()
var frames := 0                           ## frames in `data` without the padding
var rpms := PackedFloat64Array()
var log_rpms := PackedFloat64Array()
var periods := PackedFloat64Array()
var overlaps := PackedInt32Array()
var gains := PackedFloat64Array()
var power := PackedFloat64Array()
var xrpm := PackedFloat64Array()
var xload := PackedFloat64Array()
var var_first := PackedInt32Array()
var var_count := PackedInt32Array()
var cyc_base := PackedInt32Array()
var cyc_len := PackedInt32Array()
var cyc_mono := PackedByteArray()
var errors: Array[String] = []
var warnings: Array[String] = []


func ok() -> bool:
	return errors.is_empty()


func bank_count() -> int:
	return rpms.size() * LAYER_COUNT


func has_layer(layer_name: String) -> bool:
	return layers.has(layer_name)


## Parameter block of a runtime layer ({} when the car has none).
func layer(layer_name: String) -> Dictionary:
	var l: Variant = layers.get(layer_name, {})
	return l if l is Dictionary else {}


func clip_count(clip_name: String) -> int:
	return (clips.get(clip_name, PackedInt32Array()) as PackedInt32Array).size() / 3


## Length of a clip variant in seconds (0 when missing).
func clip_seconds(clip_name: String, index: int = 0) -> float:
	var c: PackedInt32Array = clips.get(clip_name, PackedInt32Array())
	if index * 3 + 2 >= c.size():
		return 0.0
	return float(c[index * 3 + 1]) / float(sample_rate)


func summary() -> String:
	if rpms.is_empty():
		return "%s: leer" % car
	var n := 0
	for k: String in clips:
		n += clip_count(k)
	return "%s: %d Hz Stereo, %d Drehzahlpunkte %d–%d/min, %d Zyklen, %d Clips, %.1f MB" % [car, sample_rate, rpms.size(),
		int(rpms[0]), int(rpms[rpms.size() - 1]), cyc_base.size(), n, frames * 4.0 / 1048576.0]


## Path of a car's bank description.
static func path_for(id: String, dir: String = DIR) -> String:
	return dir.path_join(id + ".json")


## The description alone (no samples) – engine, gearbox and layer parameters for whoever needs only those.
## {} when the file is missing or not a bank of this format.
static func read_meta(json_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(json_path)) != OK or not (json.data is Dictionary):
		return {}
	var meta: Dictionary = json.data
	return meta if str(meta.get("format", "")) == FORMAT else {}


## Loads <car>.json and its raw data. Never returns null; check ok() / errors. Safe to call from a worker thread.
static func load_file(json_path: String) -> EngineBank2:
	var b := EngineBank2.new()
	b.path = json_path
	if not FileAccess.file_exists(json_path):
		b.errors.append("Motorbank fehlt: %s" % json_path)
		return b
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(json_path)) != OK:
		b.errors.append("%s: JSON-Fehler in Zeile %d: %s" % [json_path, json.get_error_line(), json.get_error_message()])
		return b
	if not (json.data is Dictionary):
		b.errors.append("%s: kein JSON-Objekt" % json_path)
		return b
	var meta: Dictionary = json.data
	var data_name := str(meta.get("data", ""))
	if data_name == "" or data_name.contains("..") or data_name.is_absolute_path():
		b.errors.append("%s: Feld \"data\" fehlt oder ist kein Dateiname im selben Ordner (\"%s\")" % [json_path, data_name])
		return b
	var data_path := json_path.get_base_dir().path_join(data_name)
	if not FileAccess.file_exists(data_path):
		b.errors.append("%s: Rohdaten fehlen: %s" % [json_path, data_path])
		return b
	var samples := ModernAudioAssets.read_i16(data_path)
	if samples.is_empty() or samples.size() % 2 != 0:
		b.errors.append("%s: %s ist leer oder kein Stereo-int16 (%d Werte)" % [json_path, data_path, samples.size()])
		return b
	b._parse(meta, samples)
	return b


## Validates metadata + interleaved stereo samples that are already in memory (tests, tools). The array is taken
## over (padded in place).
static func from_dict(meta: Dictionary, samples: PackedFloat32Array, source: String = "<speicher>") -> EngineBank2:
	var b := EngineBank2.new()
	b.path = source
	b._parse(meta, samples)
	return b


static func _num(v: Variant) -> bool:
	return v is float or v is int


func _parse(meta: Dictionary, samples: PackedFloat32Array) -> void:
	var fmt := str(meta.get("format", ""))
	if fmt != FORMAT:
		errors.append("Format \"%s\" unbekannt (erwartet \"%s\")" % [fmt, FORMAT])
		return
	car = str(meta.get("car", ""))
	if car == "":
		warnings.append("Feld \"car\" fehlt")
		car = path.get_file().get_basename()
	if not _num(meta.get("sample_rate")):
		errors.append("sample_rate fehlt oder ist keine Zahl")
		return
	sample_rate = int(meta["sample_rate"])
	if sample_rate < MIN_RATE or sample_rate > MAX_RATE:
		errors.append("sample_rate %d außerhalb %d–%d Hz" % [sample_rate, MIN_RATE, MAX_RATE])
		return
	if sample_rate != CONTRACT_RATE:
		warnings.append("sample_rate %d Hz statt der %d Hz des Vertrags" % [sample_rate, CONTRACT_RATE])
	if int(meta.get("channels", 0)) != 2:
		errors.append("channels muss 2 sein (ist %s)" % str(meta.get("channels", "–")))
		return
	if samples.is_empty() or samples.size() % 2 != 0:
		errors.append("Rohdaten sind leer oder haben eine ungerade Zahl von Werten")
		return
	# engine and gearbox blocks are those of the Arcade bank: its checks apply (EngineBank is only used to validate)
	var probe := EngineBank.new()
	probe._parse_engine(meta.get("engine"))
	if probe.ok():
		probe._parse_gearbox(meta.get("gearbox"))
	errors.append_array(probe.errors)
	warnings.append_array(probe.warnings)
	if not ok():
		return
	engine = probe.engine
	gearbox = probe.gearbox
	frames = samples.size() / 2
	_parse_banks(meta.get("banks"))
	if not ok():
		return
	_parse_clips(meta.get("clips", {}))
	_parse_layers(meta.get("layers", {}))
	_parse_mix(meta.get("mix", {}))
	if not ok():
		return
	data = samples
	data.resize((frames + PAD) * 2)


func _cycle(c: Variant, where: String) -> PackedInt32Array:
	if not (c is Array) or (c as Array).size() != 3 or not _num(c[0]) or not _num(c[1]) or not _num(c[2]):
		errors.append("%s: Eintrag %s ist kein [offset, length, mode]" % [where, str(c)])
		return PackedInt32Array()
	var off := int(c[0])
	var ln := int(c[1])
	var mode := int(c[2])
	if mode < 0 or mode > 2:
		errors.append("%s: mode %d unbekannt (0 Stereo, 1 Mono links, 2 Mono rechts)" % [where, mode])
		return PackedInt32Array()
	if off < 0 or ln <= 0 or off + ln > frames:
		errors.append("%s: [%d, %d] liegt außerhalb der Rohdaten (%d Frames)" % [where, off, ln, frames])
		return PackedInt32Array()
	return PackedInt32Array([off * 2 + (1 if mode == 2 else 0), ln, 0 if mode == 0 else 1])


func _parse_banks(list: Variant) -> void:
	if not (list is Array) or (list as Array).is_empty():
		errors.append("Feld \"banks\" fehlt oder ist leer")
		return
	var by_rpm := {}
	var idx := 0
	for e: Variant in list:
		var where := "banks[%d]" % idx
		idx += 1
		if not (e is Dictionary):
			errors.append("%s: kein Objekt" % where)
			return
		var d: Dictionary = e
		if not _num(d.get("rpm")) or float(d["rpm"]) <= 0.0:
			errors.append("%s: rpm fehlt oder ist keine positive Zahl" % where)
			return
		var rpm := float(d["rpm"])
		var layer_i := LAYER_NAMES.find(str(d.get("layer", "")))
		where = "Bank %d/min %s" % [int(rpm), str(d.get("layer", "?"))]
		if layer_i < 0:
			errors.append("%s: layer muss \"off\", \"on\" oder \"in\" sein" % where)
			return
		if not _num(d.get("period")) or not _num(d.get("overlap")):
			errors.append("%s: period oder overlap fehlt" % where)
			return
		var period := float(d["period"])
		var expected := 120.0 / rpm * sample_rate
		if absf(period - expected) > expected * 0.02:
			errors.append("%s: period %.1f passt nicht zu 120 / rpm · sample_rate = %.1f" % [where, period, expected])
			return
		var overlap := int(d["overlap"])
		if overlap < 8 or overlap > int(period):
			errors.append("%s: overlap %d außerhalb 8 … ein Arbeitsspiel" % [where, overlap])
			return
		var gain := float(d.get("gain", 1.0)) if _num(d.get("gain", 1.0)) else -1.0
		if gain <= 0.0 or gain > 64.0:
			errors.append("%s: gain muss in (0, 64] liegen" % where)
			return
		var cyc: Variant = d.get("cycles")
		if not (cyc is Array) or (cyc as Array).size() < 2:
			errors.append("%s: mindestens 2 Zyklen nötig" % where)
			return
		var want_len := int(round(period)) + overlap
		var bases := PackedInt32Array()
		var lens := PackedInt32Array()
		var monos := PackedByteArray()
		for c: Variant in cyc:
			var t := _cycle(c, where)
			if t.is_empty():
				return
			if absi(t[1] - want_len) > 1:
				errors.append("%s: Zykluslänge %d, erwartet round(period) + overlap = %d" % [where, t[1], want_len])
				return
			bases.append(t[0])
			lens.append(t[1])
			monos.append(t[2])
		var key := int(round(rpm))
		if not by_rpm.has(key):
			by_rpm[key] = [null, null, null]
		if by_rpm[key][layer_i] != null:
			errors.append("%s: doppelt" % where)
			return
		by_rpm[key][layer_i] = {"rpm": rpm, "period": period, "overlap": overlap, "gain": gain, "base": bases, "len": lens,
			"mono": monos, "lufs": float(d.get("lufs", 0.0)) if _num(d.get("lufs", 0.0)) else 0.0,
			"xrpm": clampf(float(d.get("xrpm", 1.0)) if _num(d.get("xrpm", 1.0)) else 1.0, -1.0, 1.0),
			"xload": clampf(float(d.get("xload", 0.0)) if _num(d.get("xload", 0.0)) else 0.0, -1.0, 1.0)}
	var keys := by_rpm.keys()
	keys.sort()
	for k: int in keys:
		var triple: Array = by_rpm[k]
		for l in LAYER_COUNT:
			if triple[l] == null:
				errors.append("Drehzahlpunkt %d/min: Bank \"%s\" fehlt (jeder Punkt braucht alle drei Ebenen)" % [k, LAYER_NAMES[l]])
				return
	for i in keys.size():
		var triple: Array = by_rpm[keys[i]]
		var rpm := float(triple[LAYER_ON]["rpm"])
		rpms.append(rpm)
		log_rpms.append(log(rpm))
		xload.append(float(triple[LAYER_ON]["xload"]))
		for l in LAYER_COUNT:
			var e: Dictionary = triple[l]
			periods.append(float(e["period"]))
			overlaps.append(int(e["overlap"]))
			gains.append(float(e["gain"]))
			power.append(pow(10.0, float(e["lufs"]) / 10.0))
			xrpm.append(float(e["xrpm"]) if i > 0 else 1.0)
			var_first.append(cyc_base.size())
			var_count.append((e["base"] as PackedInt32Array).size())
			cyc_base.append_array(e["base"])
			cyc_len.append_array(e["len"])
			cyc_mono.append_array(e["mono"])
		if i > 0 and rpm / rpms[i - 1] > MAX_SPACING + 0.01:
			warnings.append("Drehzahlpunkte %d und %d liegen weiter als Faktor %.2f auseinander" % [int(rpms[i - 1]), int(rpm), MAX_SPACING])
	var idle := float(engine["idle_rpm"])
	var lim := float(engine["limiter_rpm"])
	if rpms[0] > idle * 1.05:
		warnings.append("tiefster Drehzahlpunkt %d liegt über dem Leerlauf %d" % [int(rpms[0]), int(idle)])
	if rpms[rpms.size() - 1] < lim * 0.97:
		warnings.append("höchster Drehzahlpunkt %d liegt unter dem Begrenzer %d" % [int(rpms[rpms.size() - 1]), int(lim)])


func _parse_clips(c: Variant) -> void:
	if c == null:
		return
	if not (c is Dictionary):
		errors.append("Feld \"clips\" ist kein Objekt")
		return
	for k: Variant in c:
		var clip_name := str(k)
		if not CLIP_NAMES.has(clip_name):
			warnings.append("Clip \"%s\" unbekannt – wird nicht verwendet" % clip_name)
		var list: Variant = c[k]
		if not (list is Array):
			errors.append("clips.%s ist keine Liste" % clip_name)
			return
		var flat := PackedInt32Array()
		for e: Variant in list:
			var t := _cycle(e, "clips.%s" % clip_name)
			if t.is_empty():
				return
			flat.append_array(t)
		if not flat.is_empty():
			clips[clip_name] = flat


func _parse_layers(l: Variant) -> void:
	if l == null:
		return
	if not (l is Dictionary):
		errors.append("Feld \"layers\" ist kein Objekt")
		return
	for k: Variant in l:
		if not (l[k] is Dictionary):
			errors.append("layers.%s ist kein Objekt" % str(k))
			return
		layers[str(k)] = (l[k] as Dictionary).duplicate(true)


func _parse_mix(m: Variant) -> void:
	if m == null:
		return
	if not (m is Dictionary):
		errors.append("Feld \"mix\" ist kein Objekt")
		return
	var d: Dictionary = m
	for key: String in ["gain", "off_gain", "in_gain", "idle_load", "load_curve"]:
		if d.has(key) and not _num(d[key]):
			errors.append("mix.%s muss eine Zahl sein" % key)
			return
	mix_gain = float(d.get("gain", 1.0))
	off_gain = float(d.get("off_gain", 1.0))
	in_gain = float(d.get("in_gain", 1.0))
	if mix_gain <= 0.0 or mix_gain > 8.0 or off_gain < 0.0 or off_gain > 4.0 or in_gain < 0.0 or in_gain > 8.0:
		errors.append("mix: gain in (0, 8], off_gain in [0, 4], in_gain in [0, 8] erwartet")
		return
	idle_load = clampf(float(d.get("idle_load", 0.2)), 0.0, 1.0)
	load_curve = clampf(float(d.get("load_curve", 1.0)), 0.25, 4.0)
	var cg: Variant = d.get("clip_gain", {})
	if cg is Dictionary:
		for k: Variant in cg:
			if _num(cg[k]) and float(cg[k]) > 0.0:
				clip_gain[str(k)] = float(cg[k])
