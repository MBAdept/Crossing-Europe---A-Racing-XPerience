extends SceneTree
## Arcade sound identity (v0.8.0, contract Rule 1 / §6 AU-A): fingerprints of the Arcade audio code and of the
## audio buses the Arcade AudioManager creates. Uses only classes that exist since v0.7.0, so the same script runs
## in a checkout of the tag:
##
##   godot --headless --path <tree of tag v0.7.0> -s <this file> -- --out=arcade_v070_headless.json
##   xvfb-run -a godot --path <tree of tag v0.7.0> --audio-driver Dummy -s <this file> -- --out=arcade_v070_display.json
##
## The two files next to this script were written that way (tools/audio/modern/make_arcade_golden.sh); the tests
## compare the current tree against them:
##   engine   seeded EngineAudio mixer output per car (scripted drive + manual rpm points): SHA-256 of the samples
##   sfx      every SfxSynth sound (seeded): SHA-256
##   traffic  TrafficAudio model (voice gains, pitch, cutoff of a scripted pass-by, fixture sounds): SHA-256
##   buses    the AudioServer layout after the AudioManager started: name, send, volume, mute, effects with all
##            stored parameters ("headless" = Master, SFX, Music, Room, Engine; with a display also TrafficV<n>, Siren)
##   files    SHA-256 of every frozen Arcade audio file (contract Rule 1): the six classes under scripts/audio, the
##            three synthesis tools and everything in assets/audio/{engines,traffic,music}
## Hashes are exact for one machine/engine build (libm); regenerate from the tag after an engine update.

const ENGINE_DIR := "res://assets/audio/engines"
const CARS: Array[String] = ["gran_turismo", "kombi", "kompakt", "limousine", "sportwagen"]
const FIXTURE_BANK := "res://tests/fixtures/engines/fixture_v4.json"
const TRAFFIC_FIXTURE := "res://tests/fixtures/traffic/traffic_sounds.json"
const SEED := 20260811
## Frozen Arcade audio files (contract Rule 1): single files and whole folders.
const FROZEN_FILES: Array[String] = [
	"res://scripts/audio/engine_audio.gd", "res://scripts/audio/engine_bank.gd", "res://scripts/audio/engine_gearbox.gd",
	"res://scripts/audio/room_audio.gd", "res://scripts/audio/sfx_synth.gd", "res://scripts/audio/traffic_audio.gd",
	"res://tools/audio/engine_synth.py", "res://tools/audio/traffic_synth.py", "res://tools/audio/music_synth.py",
]
const FROZEN_DIRS: Array[String] = ["res://assets/audio/engines", "res://assets/audio/traffic", "res://assets/audio/music"]
const DT := 1.0 / 60.0

var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false   # the autoloads are ready (AudioManager built its buses in frame 1)
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var data := {
		"godot": Engine.get_version_info().get("string", ""),
		"display": DisplayServer.get_name(),
		"engine": engine_hashes(),
		"sfx": sfx_hashes(),
		"traffic": traffic_hash(),
		"buses": bus_layout(),
		"files": file_hashes(),
	}
	var text := JSON.stringify(data, "\t") + "\n"
	if out == "":
		print(text)
	else:
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		print("arcade_golden: %s geschrieben (%d Busse, %d Motoren, %d Klänge)" % [out, (data["buses"] as Array).size(),
			(data["engine"] as Dictionary).size(), (data["sfx"] as Dictionary).size()])
	return true


# --- hashes ---------------------------------------------------------------------------------------

static func sha(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()


## Speed/throttle frames of the scripted drive: idle, revs at a standstill, full throttle through the gears, lifting
## (crackles, blow-off), braking, idle.
static func drive_frames() -> Array:
	var frames: Array = []
	for i in 30:
		frames.append([0.0, 0.0])
	for i in 48:
		frames.append([0.0, 1.0 if (i / 12) % 2 == 0 else 0.0])
	for i in 300:
		frames.append([250.0 * (1.0 - exp(-float(i) * DT / 3.2)), 1.0])
	var v := 250.0 * (1.0 - exp(-300.0 * DT / 3.2))
	for i in 60:
		v -= 6.0 * DT
		frames.append([v, 0.0])
	while v > 0.0:
		v = maxf(0.0, v - 90.0 * DT)
		frames.append([v, 0.0])
	for i in 20:
		frames.append([0.0, 0.0])
	return frames


## Seeded mixer output of one bank: {samples, sha256, peak, rms} (or {error}).
static func engine_hash(bank_path: String, mixer_seed: int = SEED) -> Dictionary:
	var b := EngineBank.load_file(bank_path)
	if not b.ok():
		return {"error": str(b.errors)}
	return engine_hash_bank(b, mixer_seed)


## The same for a bank that is loaded already (e.g. the one the AudioManager caches and every profile plays from).
static func engine_hash_bank(b: EngineBank, mixer_seed: int = SEED) -> Dictionary:
	var e := EngineAudio.new(b, mixer_seed)
	e.start(true)
	var out := PackedFloat32Array()
	var per := float(b.sample_rate) * DT
	var acc := 0.0
	var pos := 0
	for f: Array in drive_frames():
		e.update(DT, float(f[0]), float(f[1]), 250.0, true)
		acc += per
		var n := int(acc)
		acc -= n
		out.resize(pos + n)
		e.render(out, pos, n)
		pos += n
	# manual rpm points (the gearbox bypassed): low load, a ramp to full load, the limiter pattern, a fade-out
	var m := EngineAudio.new(b, mixer_seed + 1)
	var lo := b.rpms[0]
	var hi := b.rpms[b.rpms.size() - 1]
	var steps: Array = [[lerpf(lo, hi, 0.25), 0.15, false, 0.0], [lerpf(lo, hi, 0.7), 1.0, false, 0.15],
		[hi * 0.98, 1.0, true, 0.1], [lerpf(lo, hi, 0.4), 0.0, false, 0.2]]
	for s: Array in steps:
		m.set_manual(float(s[0]), float(s[1]), bool(s[2]), float(s[3]))
		var n := int(0.3 * b.sample_rate)
		out.resize(pos + n)
		m.render(out, pos, n)
		pos += n
	m.fade_to(0.0, 0.1)
	var tail := int(0.15 * b.sample_rate)
	out.resize(pos + tail)
	m.render(out, pos, tail)
	var peak := 0.0
	var sq := 0.0
	for x in out:
		peak = maxf(peak, absf(x))
		sq += x * x
	return {"samples": out.size(), "sha256": sha(out.to_byte_array()), "peak": peak, "rms": sqrt(sq / maxf(out.size(), 1.0))}


static func engine_hashes() -> Dictionary:
	var out := {}
	for car in CARS:
		out[car] = engine_hash(ENGINE_DIR.path_join(car + ".json"))
	out["fixture_v4"] = engine_hash(FIXTURE_BANK)
	return out


## Every synthesised Arcade sound (the streams the AudioManager builds at start), in a fixed order.
static func sfx_sounds() -> Dictionary:
	return {
		"engine_on": SfxSynth.engine_loop(true), "engine_off": SfxSynth.engine_loop(false), "wind": SfxSynth.wind_loop(),
		"rain": SfxSynth.rain_loop(), "siren": SfxSynth.siren_loop(), "skid": SfxSynth.skid_loop(),
		"crash": SfxSynth.crash(), "rail": SfxSynth.rail_hit(), "flash": SfxSynth.radar_flash(),
		"beep": SfxSynth.beep(784.0, 0.18, 4.0), "go": SfxSynth.beep(1568.0, 0.7, 2.5), "finish": SfxSynth.finish_jingle(),
		"fuel_start": SfxSynth.fuel_start(), "fuel_done": SfxSynth.fuel_done(), "ui_move": SfxSynth.ui_tick(),
		"ui_ok": SfxSynth.ui_two_tone(880.0, 1320.0), "ui_back": SfxSynth.ui_two_tone(660.0, 440.0),
	}


static func sfx_hashes() -> Dictionary:
	var out := {}
	var s := sfx_sounds()
	for n: String in s:
		var b: PackedFloat32Array = s[n]
		out[n] = {"samples": b.size(), "sha256": sha(b.to_byte_array())}
	return out


## The traffic model over a scripted scene (no AudioServer): a truck and three cars pass a listener at 130 km/h, a
## police car closes in from behind with the siren on; hashes every voice value of every frame.
static func traffic_hash() -> Dictionary:
	var cfg := ConfigLoader.load_merged()
	var t := TrafficAudio.new()
	t.setup(cfg)
	if not t.load_sounds(TRAFFIC_FIXTURE, false):
		return {"error": str(t.errors)}
	var acc := PackedFloat32Array()
	var lz := 0.0
	var cars: Array = [
		{"id": 1, "set": "traffic/truck_red", "z": 60.0, "x": 1.9, "length": 16.5, "speed": 88.0, "heavy": true},
		{"id": 2, "set": "traffic/sedan_blue", "z": 25.0, "x": -1.9, "length": 4.7, "speed": 150.0},
		{"id": 3, "set": "traffic/van_white", "z": 110.0, "x": 1.9, "length": 5.6, "speed": 105.0},
		{"id": 4, "set": "traffic/sport_yellow", "z": -70.0, "x": -5.6, "length": 4.4, "speed": 210.0},
		{"id": -2, "set": "police/de", "z": -260.0, "x": -1.9, "length": 4.8, "speed": 185.0},
	]
	var frames := 420
	for i in frames:
		lz += 130.0 / 3.6 * DT
		for c: Dictionary in cars:
			c["z"] = float(c["z"]) + float(c["speed"]) / 3.6 * DT
		t.set_siren(i > 30 and i < 380, 0.6)
		t.update(DT, cars if i < 400 else [], {"z": lz, "x": 0.0, "speed": 130.0}, i < 400)
		for v in t.voices:
			acc.append(float(v.vehicle))
			acc.append(v.fade)
			acc.append(v.cutoff)
			acc.append(v.pan)
			acc.append(v.doppler)
			for k in 3:
				acc.append(v.gl[k])
				acc.append(v.gr[k])
				acc.append(v.pitch[k])
		acc.append(t.siren.gl[0])
		acc.append(t.siren.gr[0])
		acc.append(t.siren.pitch[0])
		acc.append(t.siren.cutoff)
	var room := RoomAudio.new()
	room.setup(cfg)
	for i in 120:
		room.update(DT, i < 70)
		var p := room.params(room.blend)
		acc.append(float(p["reflections_db"]))
		acc.append(float(p["wet"]))
	return {"values": acc.size(), "sha256": sha(acc.to_byte_array())}


## SHA-256 of every frozen Arcade audio file: {res:// path: hash}.
static func file_hashes() -> Dictionary:
	var paths: Array[String] = FROZEN_FILES.duplicate()
	for d in FROZEN_DIRS:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for f in dir.get_files():
			paths.append(d.path_join(f))
	paths.sort()
	var out := {}
	for p in paths:
		out[p] = FileAccess.get_sha256(p) if FileAccess.file_exists(p) else "fehlt"
	return out


# --- buses ----------------------------------------------------------------------------------------

## The whole AudioServer bus layout as plain data: [{name, send, volume_db, mute, solo, bypass, effects: [{class,
## enabled, params: {…}}]}] (stored parameters of every effect; no meters).
static func bus_layout() -> Array:
	var out: Array = []
	for i in AudioServer.bus_count:
		var effects: Array = []
		for j in AudioServer.get_bus_effect_count(i):
			var fx := AudioServer.get_bus_effect(i, j)
			var params := {}
			for p: Dictionary in fx.get_property_list():
				var pname := str(p["name"])
				if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or pname == "script" or pname.begins_with("resource_"):
					continue
				var v: Variant = fx.get(pname)
				if v is StringName:
					v = str(v)
				if v is float or v is int or v is bool or v is String:
					params[pname] = v
			effects.append({"class": fx.get_class(), "enabled": AudioServer.is_bus_effect_enabled(i, j), "params": params})
		out.append({"name": AudioServer.get_bus_name(i), "send": str(AudioServer.get_bus_send(i)),
			"volume_db": AudioServer.get_bus_volume_db(i), "mute": AudioServer.is_bus_mute(i),
			"solo": AudioServer.is_bus_solo(i), "bypass": AudioServer.is_bus_bypassing_effects(i), "effects": effects})
	return out


## Layout as it is stored in the golden files (through JSON: numbers as JSON writes them).
static func normalized(layout: Array) -> Array:
	var v: Variant = JSON.parse_string(JSON.stringify(layout))
	return v if v is Array else []


## Differences between two layouts as readable lines (empty = identical). `ignore` = bus names left out of `now`.
static func layout_diff(golden: Array, now: Array, ignore: PackedStringArray = PackedStringArray()) -> Array[String]:
	var out: Array[String] = []
	var cur: Array = []
	for b: Dictionary in normalized(now):
		if not ignore.has(str(b.get("name", ""))):
			cur.append(b)
	var gold := normalized(golden)
	if gold.size() != cur.size():
		var names_g: Array = []
		var names_c: Array = []
		for b: Dictionary in gold:
			names_g.append(b.get("name"))
		for b: Dictionary in cur:
			names_c.append(b.get("name"))
		out.append("Busliste: erwartet %s, ist %s" % [str(names_g), str(names_c)])
		return out
	for i in gold.size():
		var g: Dictionary = gold[i]
		var c: Dictionary = cur[i]
		for k: String in ["name", "send", "volume_db", "mute", "solo", "bypass"]:
			if g.get(k) != c.get(k):
				out.append("Bus %d %s: %s erwartet %s, ist %s" % [i, str(g.get("name")), k, str(g.get(k)), str(c.get(k))])
		var ge: Array = g.get("effects", [])
		var ce: Array = c.get("effects", [])
		if ge.size() != ce.size():
			out.append("Bus %s: %d Effekte erwartet, %d vorhanden" % [str(g.get("name")), ge.size(), ce.size()])
			continue
		for j in ge.size():
			var gf: Dictionary = ge[j]
			var cf: Dictionary = ce[j]
			if gf.get("class") != cf.get("class") or gf.get("enabled") != cf.get("enabled"):
				out.append("Bus %s Effekt %d: %s (an: %s) erwartet, ist %s (an: %s)" % [str(g.get("name")), j,
					str(gf.get("class")), str(gf.get("enabled")), str(cf.get("class")), str(cf.get("enabled"))])
				continue
			var gp: Dictionary = gf.get("params", {})
			var cp: Dictionary = cf.get("params", {})
			for k: String in gp:
				if not cp.has(k) or gp[k] != cp[k]:
					out.append("Bus %s %s.%s: erwartet %s, ist %s" % [str(g.get("name")), str(gf.get("class")), k,
						str(gp[k]), str(cp.get(k, "fehlt"))])
			for k: String in cp:
				if not gp.has(k):
					out.append("Bus %s %s.%s: neu (%s)" % [str(g.get("name")), str(gf.get("class")), k, str(cp[k])])
	return out
