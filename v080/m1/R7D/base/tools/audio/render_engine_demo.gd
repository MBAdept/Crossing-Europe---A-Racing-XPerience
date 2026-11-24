extends SceneTree
## Renders a scripted drive with an engine cycle bank (docs/motorsound.md) into a 16-bit mono WAV – headless, no
## audio device. Drives EngineAudio exactly like the game does (update() + render() per 1/60 s frame).
##
## Usage:
##   godot --headless --path . -s res://tools/audio/render_engine_demo.gd -- \
##       --bank=res://assets/audio/engines/gran_turismo.json [--out=/tmp/gran_turismo_demo.wav] \
##       [--vehicle=gran_turismo] [--seed=1] [--level-db=0] [--trace=/tmp/gran_turismo_demo.csv]
## All five cars:
##   for c in kompakt kombi limousine sportwagen gran_turismo; do
##     godot --headless --path . -s res://tools/audio/render_engine_demo.gd -- \
##         --bank=res://assets/audio/engines/$c.json --out=/tmp/engine_$c.wav; done
## --bank also takes an absolute path. --vehicle (default: the bank's "car" if it is a vehicle type, else
## vehicles.default) picks vmax and the acceleration curve from config vehicles.types. --out defaults to
## /tmp/<car>_demo.wav. --level-db is added to the bank's mix.gain (the game adds audio.engine_db). --trace writes
## one CSV line per frame: t, speed, throttle, rpm, gear, load, boost. --only-cycles drops the bank's clips and
## layers (no start clip, whistle, crackles, blow-off, shift crack, limiter pattern): the cycle sound alone.
##
## Drive (≈ 45 s): engine start (start clip) and idle · three throttle blips at a standstill · rev limiter at a
## standstill · launch and full-throttle run through the gears (the car's acceleration curve, up to 96 % vmax or
## 22 s) · lift-off (blow-off, crackles) and coasting · light throttle · hard braking to a stop with downshifts
## (throttle blips on sporty cars) · idle · fade-out. Prints each phase, every gear change and the render time
## per frame (533 samples at 32 kHz).

const FPS := 60.0
const DT := 1.0 / FPS

var _e: EngineAudio
var _out := PackedFloat32Array()
var _acc := 0.0
var _t := 0.0
var _speed := 0.0
var _vmax := 250.0
var _spec: Dictionary = {}
var _trace: FileAccess
var _times: Array[int] = []


func _initialize() -> void:
	var bank_path := CliArgs.get_string("bank", "")
	if bank_path == "":
		print("Aufruf: godot --headless --path . -s res://tools/audio/render_engine_demo.gd -- --bank=<bank.json> [--out=<datei.wav>] [--vehicle=<typ>] [--seed=<n>] [--level-db=<dB>] [--trace=<datei.csv>]")
		quit(2)
		return
	var bank := EngineBank.load_file(bank_path)
	if not bank.ok():
		for e in bank.errors:
			print("FEHLER ", e)
		quit(1)
		return
	for w in bank.warnings:
		print("Hinweis: ", w)
	if CliArgs.has("only-cycles"):
		bank.clips.clear()
		bank.layers.clear()
	print(bank.summary())
	var cfg := ConfigLoader.load_merged()
	var types: Dictionary = ConfigLoader.lookup(cfg, "vehicles.types", {})
	var vehicle := CliArgs.get_string("vehicle", bank.car if types.has(bank.car) else str(ConfigLoader.lookup(cfg, "vehicles.default", "limousine")))
	_spec = VehicleModel.resolve_spec(cfg, vehicle)
	_vmax = float(_spec["vmax_kmh"])
	print("Fahrzeug %s: vmax %d km/h, 0–100 km/h in %.1f s" % [str(_spec["id"]), int(_vmax), float(_spec["t100_s"])])
	_e = EngineAudio.new(bank, int(CliArgs.get_float("seed", 1.0)))
	_e.level = db_to_linear(CliArgs.get_float("level-db", 0.0))
	var trace_path := CliArgs.get_string("trace", "")
	if trace_path != "":
		_trace = FileAccess.open(trace_path, FileAccess.WRITE)
		if _trace != null:
			_trace.store_line("t,speed_kmh,throttle,rpm,gear,load,boost")
	_e.start(true)
	_phase("Start und Leerlauf", 2.5, func(_x: float) -> float: return 0.0, "stand")
	for i in 3:
		_phase("Gasstoß im Stand" if i == 0 else "", 0.28, func(_x: float) -> float: return 1.0, "stand")
		_phase("", 0.9, func(_x: float) -> float: return 0.0, "stand")
	_phase("Begrenzer im Stand", 1.8, func(_x: float) -> float: return 1.0, "stand")
	_phase("", 1.4, func(_x: float) -> float: return 0.0, "stand")
	_phase("Vollgas durch die Gänge", 22.0, func(_x: float) -> float: return 1.0, "accel")
	_phase("Gas weg, rollen", 3.5, func(_x: float) -> float: return 0.0, "coast")
	_phase("wenig Gas", 3.0, func(_x: float) -> float: return 0.35, "accel")
	_phase("Vollbremsung mit Rückschalten", 6.0, func(_x: float) -> float: return 0.0, "brake")
	_phase("Leerlauf", 2.0, func(_x: float) -> float: return 0.0, "stand")
	_e.fade_to(0.0, 0.4)
	_phase("Ausblenden", 0.5, func(_x: float) -> float: return 0.0, "stand")
	if _trace != null:
		_trace.close()
	var out_path := CliArgs.get_string("out", "/tmp/%s_demo.wav" % bank.car)
	var err := write_wav(out_path, _out, bank.sample_rate)
	if err != OK:
		print("FEHLER: %s konnte nicht geschrieben werden (%s)" % [out_path, error_string(err)])
		quit(1)
		return
	var peak := 0.0
	for x in _out:
		peak = maxf(peak, absf(x))
	_times.sort()
	var sum := 0
	for us in _times:
		sum += us
	var n := _times.size()
	print("Renderzeit je Frame (%d Samples): Mittel %.3f ms, Median %.3f ms, 99 %% %.3f ms, max %.3f ms" % [
		int(bank.sample_rate / FPS), sum / 1000.0 / n, _times[n / 2] / 1000.0, _times[int(n * 0.99)] / 1000.0, _times[n - 1] / 1000.0])
	print("Clips: %s" % str(_e.clips_started))
	print("%s: %.1f s, %d Hz, Spitze %.2f" % [out_path, _out.size() / float(bank.sample_rate), bank.sample_rate, peak])
	quit(0)


## Runs a phase of the drive: `seconds` long (accel stops near vmax, brake at standstill), throttle from
## thr(t), speed by mode: stand (0), accel (acceleration curve × throttle), coast (−5 km/h/s), brake (−70 km/h/s).
func _phase(title: String, seconds: float, thr: Callable, mode: String) -> void:
	var t := 0.0
	var lo := 1.0e9
	var hi := 0.0
	var gears := {}
	while t < seconds:
		var throttle := float(thr.call(t))
		match mode:
			"stand":
				_speed = 0.0
			"accel":
				if _speed >= _vmax * 0.96 and throttle >= 1.0:
					break
				_speed = _accelerate(_speed, throttle)
			"coast":
				_speed = maxf(0.0, _speed - 5.0 * DT)
			"brake":
				if _speed <= 0.0 and t > 0.5:
					break
				_speed = maxf(0.0, _speed - 70.0 * DT)
		_frame(_speed, throttle)
		var st := _e.state()
		lo = minf(lo, float(st["rpm"]))
		hi = maxf(hi, float(st["rpm"]))
		gears[int(st["gear"])] = true
		t += DT
	if title != "":
		var g := gears.keys()
		g.sort()
		print("%6.1f s  %-30s %4.0f km/h  %5d–%d/min  Gänge %s" % [_t, title, _speed, int(lo), int(hi), str(g)])


func _accelerate(v: float, throttle: float) -> float:
	var a0 := float(_spec["accel_a0"])
	var q := float(_spec["accel_q"])
	if v >= _vmax:
		return v
	return VehicleModel.curve_speed(VehicleModel.curve_time(v, _vmax, a0, q) + DT * throttle, _vmax, a0, q)


func _frame(speed: float, throttle: float) -> void:
	var t0 := Time.get_ticks_usec()
	var before := _e.gearbox.gear
	_e.update(DT, speed, throttle, _vmax, true)
	_acc += _e.bank.sample_rate * DT
	var n := int(_acc)
	_acc -= n
	var at := _out.size()
	_out.resize(at + n)
	_e.render(_out, at, n)
	_times.append(Time.get_ticks_usec() - t0)
	var gb := _e.gearbox
	if gb.ev_upshift or gb.ev_downshift:
		print("         %5.1f s  %3.0f km/h  Gang %d -> %d%s" % [_t, speed, before, gb.gear, "  Zwischengas" if gb.ev_blip else ""])
	if _trace != null:
		var st := _e.state()
		_trace.store_line("%.3f,%.2f,%.2f,%.0f,%d,%.3f,%.3f" % [_t, speed, throttle, float(st["rpm"]), int(st["gear"]), float(st["load"]), float(st["boost"])])
	_t += DT


## 16-bit PCM mono WAV.
static func write_wav(path: String, samples: PackedFloat32Array, rate: int) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var n := samples.size()
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + n * 2)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(rate)
	f.store_32(rate * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(n * 2)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	f.store_buffer(bytes)
	f.close()
	return OK
