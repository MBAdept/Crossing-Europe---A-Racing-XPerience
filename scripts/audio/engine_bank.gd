class_name EngineBank
extends RefCounted
## Engine cycle bank of one car (format "ce-engine-bank-1", contract: docs/motorsound.md §1).
## Metadata from <car>.json, samples from the raw file named in "data" (mono float32 little endian, next to
## the JSON). load_file()/from_dict() validate the format: `errors` = the bank is unusable (the runtime falls
## back to the old engine loops), `warnings` = deviations from the contract the runtime tolerates.
##
## Flattened for the mixer (bank index b = rpm_index * 2 + load, load 0 = "off", 1 = "on"):
##   rpms[i], log_rpms[i]                rpm points, ascending
##   periods[b], overlaps[b]             cycle length in samples (float) and crossfade overlap
##   var_first[b], var_count[b]          its cycle variants in cyc_off[]/cyc_len[]
##   clips[name] = PackedInt32Array [offset0, length0, offset1, length1, …]
## `data` gets PAD zero samples appended (reads just past the last cycle stay in range).
## Optional fields beyond the contract (defaults in brackets): mix.idle_load [0.2] = share of the load bank at
## idle; gearbox.blip [true with a "shift" clip or a "crackle" layer] = throttle blip on braking downshifts;
## gearbox.rev_up_s / rev_down_s [by fuel/aspiration] = free revving idle -> limiter / limiter -> idle.

const FORMAT := "ce-engine-bank-1"
const LOAD_NAMES := ["off", "on"]
const CLIP_NAMES := ["crackle", "blowoff", "shift", "start"]
const LAYER_NAMES := ["turbo", "crackle", "blowoff", "limiter"]
const PAD := 8
const MIN_RATE := 8000
const MAX_RATE := 96000
const CONTRACT_RATE := 32000
const CONTRACT_VARIANTS := 8
const MAX_SPACING := 1.25
const LAYER_DEFAULTS := {
	"turbo": {"whistle_hz": [1800.0, 5200.0], "level": 0.1, "spool_s": 0.55, "boost_rpm": 2200.0},
	"crackle": {"min_rpm": 3200.0, "rate_hz": 7.0, "duration_s": 1.4, "level": 0.6},
	"blowoff": {"min_boost": 0.55, "level": 0.5},
	"limiter": {"cut_cycles": 2, "on_cycles": 3},
}

var path := ""
var car := ""
var sample_rate := 32000
var engine: Dictionary = {}
var gearbox: Dictionary = {}
var layers: Dictionary = {}
var clips: Dictionary = {}
var mix_gain := 1.0
var off_gain := 0.5
var idle_load := 0.2
var data := PackedFloat32Array()
var rpms := PackedFloat64Array()
var log_rpms := PackedFloat64Array()
var periods := PackedFloat64Array()
var overlaps := PackedInt32Array()
var var_first := PackedInt32Array()
var var_count := PackedInt32Array()
var cyc_off := PackedInt32Array()
var cyc_len := PackedInt32Array()
var errors: Array[String] = []
var warnings: Array[String] = []


func ok() -> bool:
	return errors.is_empty()


func bank_count() -> int:
	return rpms.size() * 2


func has_layer(layer_name: String) -> bool:
	return layers.has(layer_name)


func layer(layer_name: String) -> Dictionary:
	return layers.get(layer_name, {})


func clip_count(clip_name: String) -> int:
	return (clips.get(clip_name, PackedInt32Array()) as PackedInt32Array).size() / 2


## Length of a clip variant in seconds (0 when missing).
func clip_seconds(clip_name: String, index: int = 0) -> float:
	var c: PackedInt32Array = clips.get(clip_name, PackedInt32Array())
	if index * 2 + 1 >= c.size():
		return 0.0
	return float(c[index * 2 + 1]) / float(sample_rate)


## One line for logs: car, rate, rpm range, banks, variants, size.
func summary() -> String:
	if rpms.is_empty():
		return "%s: leer" % car
	return "%s: %d Hz, %d Drehzahlpunkte %d–%d/min, %d Zyklen, %d Clips, %.1f MB" % [car, sample_rate, rpms.size(),
		int(rpms[0]), int(rpms[rpms.size() - 1]), cyc_off.size(), _clip_total(), data.size() * 4.0 / 1048576.0]


func _clip_total() -> int:
	var n := 0
	for k in clips:
		n += (clips[k] as PackedInt32Array).size() / 2
	return n


## Loads <car>.json and its raw data file. Never returns null; check ok() / errors.
static func load_file(json_path: String) -> EngineBank:
	var b := EngineBank.new()
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
	var bytes := FileAccess.get_file_as_bytes(data_path)
	if bytes.size() == 0 or bytes.size() % 4 != 0:
		b.errors.append("%s: %s hat %d Bytes – erwartet ein Vielfaches von 4 (float32)" % [json_path, data_path, bytes.size()])
		return b
	b._parse(meta, bytes.to_float32_array())
	return b


## Validates metadata + samples that are already in memory (tests, tools).
static func from_dict(meta: Dictionary, samples: PackedFloat32Array, source: String = "<speicher>") -> EngineBank:
	var b := EngineBank.new()
	b.path = source
	b._parse(meta, samples)
	return b


func _err(msg: String) -> void:
	errors.append(msg)


func _warn(msg: String) -> void:
	warnings.append(msg)


static func _num(v: Variant) -> bool:
	return v is float or v is int


func _parse(meta: Dictionary, samples: PackedFloat32Array) -> void:
	var fmt := str(meta.get("format", ""))
	if fmt != FORMAT:
		_err("Format \"%s\" unbekannt (erwartet \"%s\")" % [fmt, FORMAT])
		return
	car = str(meta.get("car", ""))
	if car == "":
		_warn("Feld \"car\" fehlt")
		car = path.get_file().get_basename()
	if not _num(meta.get("sample_rate")):
		_err("sample_rate fehlt oder ist keine Zahl")
		return
	sample_rate = int(meta["sample_rate"])
	if sample_rate < MIN_RATE or sample_rate > MAX_RATE:
		_err("sample_rate %d außerhalb %d–%d Hz" % [sample_rate, MIN_RATE, MAX_RATE])
		return
	if sample_rate < CONTRACT_RATE:
		_warn("sample_rate %d Hz liegt unter den %d Hz des Vertrags" % [sample_rate, CONTRACT_RATE])
	if samples.is_empty():
		_err("Rohdaten sind leer")
		return
	_parse_engine(meta.get("engine"))
	if not ok():
		return
	_parse_gearbox(meta.get("gearbox"))
	if not ok():
		return
	data = samples
	var n_data := samples.size()
	_parse_banks(meta.get("banks"), n_data)
	if not ok():
		return
	_parse_clips(meta.get("clips", {}), n_data)
	_parse_layers(meta.get("layers", {}))
	_parse_mix(meta.get("mix", {}))
	if not ok():
		return
	data = samples.duplicate()
	data.resize(n_data + PAD)


func _parse_engine(e: Variant) -> void:
	if not (e is Dictionary):
		_err("Feld \"engine\" fehlt")
		return
	engine = (e as Dictionary).duplicate(true)
	for k in ["idle_rpm", "redline_rpm", "limiter_rpm"]:
		if not _num(engine.get(k)):
			_err("engine.%s fehlt oder ist keine Zahl" % k)
			return
	var idle := float(engine["idle_rpm"])
	var red := float(engine["redline_rpm"])
	var lim := float(engine["limiter_rpm"])
	if not (idle > 100.0 and idle < red and red <= lim and lim <= 20000.0):
		_err("engine: erwartet 100 < idle_rpm < redline_rpm <= limiter_rpm <= 20000 (ist %d / %d / %d)" % [int(idle), int(red), int(lim)])


func _parse_gearbox(g: Variant) -> void:
	if not (g is Dictionary):
		_err("Feld \"gearbox\" fehlt")
		return
	gearbox = (g as Dictionary).duplicate(true)
	var ratios: Variant = gearbox.get("kmh_per_1000rpm")
	if not (ratios is Array) or (ratios as Array).is_empty():
		_err("gearbox.kmh_per_1000rpm fehlt oder ist leer")
		return
	var last := 0.0
	for r in ratios:
		if not _num(r) or float(r) <= last:
			_err("gearbox.kmh_per_1000rpm: positive, aufsteigende Zahlen erwartet (%s)" % str(ratios))
			return
		last = float(r)
	for k in ["upshift_rpm", "downshift_rpm"]:
		var p: Variant = gearbox.get(k)
		if not (p is Array) or (p as Array).size() != 2 or not _num(p[0]) or not _num(p[1]) or float(p[0]) > float(p[1]):
			_err("gearbox.%s: erwartet [wenig Gas, Vollgas] mit wenig <= voll (ist %s)" % [k, str(p)])
			return
	var lim := float(engine["limiter_rpm"])
	var idle := float(engine["idle_rpm"])
	var up: Array = gearbox["upshift_rpm"]
	var down: Array = gearbox["downshift_rpm"]
	if float(up[1]) > lim or float(up[0]) <= idle:
		_err("gearbox.upshift_rpm %s muss zwischen idle_rpm und limiter_rpm liegen" % str(up))
	if float(down[0]) >= float(up[0]) or float(down[1]) >= float(up[1]):
		_err("gearbox.downshift_rpm %s muss unter upshift_rpm %s liegen (Hysterese)" % [str(down), str(up)])
	if not _num(gearbox.get("shift_time_s")) or float(gearbox["shift_time_s"]) <= 0.0 or float(gearbox["shift_time_s"]) > 2.0:
		_warn("gearbox.shift_time_s fehlt oder liegt nicht in (0, 2] – 0,25 s angenommen")
		gearbox["shift_time_s"] = 0.25
	if not _num(gearbox.get("launch_rpm")):
		_warn("gearbox.launch_rpm fehlt – %d angenommen" % int(idle * 2.5))
		gearbox["launch_rpm"] = idle * 2.5
	gearbox["launch_rpm"] = clampf(float(gearbox["launch_rpm"]), idle, float(engine["redline_rpm"]))


func _parse_banks(list: Variant, n_data: int) -> void:
	if not (list is Array) or (list as Array).is_empty():
		_err("Feld \"banks\" fehlt oder ist leer")
		return
	var by_rpm := {}
	var idx := 0
	for e in list:
		var where := "banks[%d]" % idx
		idx += 1
		if not (e is Dictionary):
			_err("%s: kein Objekt" % where)
			return
		var d: Dictionary = e
		if not _num(d.get("rpm")) or float(d["rpm"]) <= 0.0:
			_err("%s: rpm fehlt oder ist keine positive Zahl" % where)
			return
		var rpm := float(d["rpm"])
		where = "Bank %d/min %s" % [int(rpm), str(d.get("load", "?"))]
		var load := LOAD_NAMES.find(str(d.get("load", "")))
		if load < 0:
			_err("%s: load muss \"on\" oder \"off\" sein" % where)
			return
		if not _num(d.get("period")) or not _num(d.get("overlap")):
			_err("%s: period oder overlap fehlt" % where)
			return
		var period := float(d["period"])
		var expected := 120.0 / rpm * sample_rate
		if absf(period - expected) > expected * 0.02:
			_err("%s: period %.1f passt nicht zu 120 / rpm · sample_rate = %.1f" % [where, period, expected])
			return
		if absf(period - expected) > expected * 0.005:
			_warn("%s: period %.1f weicht von %.1f ab" % [where, period, expected])
		var overlap := int(d["overlap"])
		if overlap < 8:
			_err("%s: overlap %d zu klein (mindestens 8 Samples zum Überblenden)" % [where, overlap])
			return
		if overlap > int(period):
			_err("%s: overlap %d länger als ein Arbeitsspiel" % [where, overlap])
			return
		var cyc: Variant = d.get("cycles")
		if not (cyc is Array) or (cyc as Array).size() < 2:
			_err("%s: mindestens 2 Zyklen nötig (Vertrag: %d)" % [where, CONTRACT_VARIANTS])
			return
		if (cyc as Array).size() < CONTRACT_VARIANTS:
			_warn("%s: nur %d Zyklen (Vertrag: mindestens %d)" % [where, (cyc as Array).size(), CONTRACT_VARIANTS])
		var want_len := int(round(period)) + overlap
		var offs := PackedInt32Array()
		var lens := PackedInt32Array()
		for c in cyc:
			if not (c is Array) or (c as Array).size() != 2 or not _num(c[0]) or not _num(c[1]):
				_err("%s: Zyklus %s ist kein [offset, length]" % [where, str(c)])
				return
			var off := int(c[0])
			var ln := int(c[1])
			if absi(ln - want_len) > 1:
				_err("%s: Zykluslänge %d, erwartet round(period) + overlap = %d" % [where, ln, want_len])
				return
			if off < 0 or off + ln > n_data:
				_err("%s: Zyklus [%d, %d] liegt außerhalb der Rohdaten (%d Samples)" % [where, off, ln, n_data])
				return
			offs.append(off)
			lens.append(ln)
		var key := int(round(rpm))
		if not by_rpm.has(key):
			by_rpm[key] = [null, null]
		if by_rpm[key][load] != null:
			_err("%s: doppelt" % where)
			return
		by_rpm[key][load] = {"rpm": rpm, "period": period, "overlap": overlap, "off": offs, "len": lens}
	var keys := by_rpm.keys()
	keys.sort()
	for k in keys:
		var pair: Array = by_rpm[k]
		for l in 2:
			if pair[l] == null:
				_err("Drehzahlpunkt %d/min: Bank \"%s\" fehlt (jeder Punkt braucht beide Lasten)" % [k, LOAD_NAMES[l]])
				return
	for i in keys.size():
		var pair: Array = by_rpm[keys[i]]
		var rpm := float(pair[1]["rpm"])
		rpms.append(rpm)
		log_rpms.append(log(rpm))
		for l in 2:
			var e: Dictionary = pair[l]
			periods.append(float(e["period"]))
			overlaps.append(int(e["overlap"]))
			var_first.append(cyc_off.size())
			var_count.append((e["off"] as PackedInt32Array).size())
			cyc_off.append_array(e["off"])
			cyc_len.append_array(e["len"])
		if i > 0 and rpm / rpms[i - 1] > MAX_SPACING + 0.01:
			_warn("Drehzahlpunkte %d und %d liegen weiter als Faktor %.2f auseinander" % [int(rpms[i - 1]), int(rpm), MAX_SPACING])
	var idle := float(engine["idle_rpm"])
	var lim := float(engine["limiter_rpm"])
	if rpms[0] > idle * 1.05:
		_warn("tiefster Drehzahlpunkt %d liegt über dem Leerlauf %d" % [int(rpms[0]), int(idle)])
	if rpms[rpms.size() - 1] < lim * 0.97:
		_warn("höchster Drehzahlpunkt %d liegt unter dem Begrenzer %d" % [int(rpms[rpms.size() - 1]), int(lim)])


func _parse_clips(c: Variant, n_data: int) -> void:
	if c == null:
		return
	if not (c is Dictionary):
		_err("Feld \"clips\" ist kein Objekt")
		return
	for k in c:
		var name := str(k)
		if not CLIP_NAMES.has(name):
			_warn("Clip \"%s\" unbekannt – wird nicht verwendet" % name)
		var list: Variant = c[k]
		if not (list is Array):
			_err("clips.%s ist keine Liste" % name)
			return
		var flat := PackedInt32Array()
		for e in list:
			if not (e is Array) or (e as Array).size() != 2 or not _num(e[0]) or not _num(e[1]):
				_err("clips.%s: Eintrag %s ist kein [offset, length]" % [name, str(e)])
				return
			var off := int(e[0])
			var ln := int(e[1])
			if off < 0 or ln <= 0 or off + ln > n_data:
				_err("clips.%s: [%d, %d] liegt außerhalb der Rohdaten (%d Samples)" % [name, off, ln, n_data])
				return
			flat.append(off)
			flat.append(ln)
		if not flat.is_empty():
			clips[name] = flat


func _parse_layers(l: Variant) -> void:
	if l == null:
		return
	if not (l is Dictionary):
		_err("Feld \"layers\" ist kein Objekt")
		return
	for k in l:
		var name := str(k)
		if not LAYER_NAMES.has(name):
			_warn("Ebene \"%s\" unbekannt – wird nicht verwendet" % name)
			continue
		if not (l[k] is Dictionary):
			_err("layers.%s ist kein Objekt" % name)
			return
		var src: Dictionary = l[k]
		var out: Dictionary = (LAYER_DEFAULTS[name] as Dictionary).duplicate(true)
		for f in out:
			if not src.has(f):
				_warn("layers.%s.%s fehlt – Standardwert %s" % [name, f, str(out[f])])
				continue
			var v: Variant = src[f]
			if out[f] is Array:
				if not (v is Array) or (v as Array).size() != 2 or not _num(v[0]) or not _num(v[1]):
					_err("layers.%s.%s: erwartet [von, bis]" % [name, f])
					return
				out[f] = [float(v[0]), float(v[1])]
			elif not _num(v) or float(v) < 0.0:
				_err("layers.%s.%s: nichtnegative Zahl erwartet" % [name, f])
				return
			else:
				out[f] = int(v) if out[f] is int else float(v)
		layers[name] = out
	if layers.has("limiter"):
		var lim: Dictionary = layers["limiter"]
		lim["cut_cycles"] = maxi(int(lim["cut_cycles"]), 1)
		lim["on_cycles"] = maxi(int(lim["on_cycles"]), 1)


func _parse_mix(m: Variant) -> void:
	if m == null:
		return
	if not (m is Dictionary):
		_err("Feld \"mix\" ist kein Objekt")
		return
	var d: Dictionary = m
	if d.has("gain"):
		if not _num(d["gain"]) or float(d["gain"]) <= 0.0 or float(d["gain"]) > 8.0:
			_err("mix.gain muss in (0, 8] liegen")
			return
		mix_gain = float(d["gain"])
	if d.has("off_gain"):
		if not _num(d["off_gain"]) or float(d["off_gain"]) < 0.0 or float(d["off_gain"]) > 4.0:
			_err("mix.off_gain muss in [0, 4] liegen")
			return
		off_gain = float(d["off_gain"])
	if d.has("idle_load"):
		if not _num(d["idle_load"]):
			_err("mix.idle_load muss eine Zahl sein")
			return
		idle_load = clampf(float(d["idle_load"]), 0.0, 1.0)
