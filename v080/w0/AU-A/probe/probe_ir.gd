extends SceneTree
## Probe: impulse responses of stock bus effects (EQ6/10/21 flat, shelving filters) – written as float32 for an FFT.

const OUT := "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A/probe/ir/"

var _cap: AudioEffectCapture
var _p: AudioStreamPlayer


func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _impulse() -> AudioStreamWAV:
	var rate := int(AudioServer.get_mix_rate())
	var n := rate
	var b := PackedByteArray()
	b.resize(n * 2)
	b.encode_s16(2000 * 2, 16384)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = b
	return w


func _wait(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await process_frame


func _shelf(low: bool, hz: float, gain: float, res: float = 0.5, db: int = 0) -> AudioEffectFilter:
	var f: AudioEffectFilter
	if low:
		f = AudioEffectLowShelfFilter.new()
	else:
		f = AudioEffectHighShelfFilter.new()
	f.cutoff_hz = hz
	f.gain = gain
	f.resonance = res
	f.db = db
	return f


func _notch(hz: float, res: float) -> AudioEffectFilter:
	var f := AudioEffectNotchFilter.new()
	f.cutoff_hz = hz
	f.resonance = res
	return f


func _run() -> void:
	Engine.max_fps = 120
	DirAccess.make_dir_recursive_absolute(OUT)
	print("mix rate ", AudioServer.get_mix_rate())
	var eq10m := AudioEffectEQ10.new()
	for i in 10:
		eq10m.set_band_gain_db(i, -3.25)
	var eq21m := AudioEffectEQ21.new()
	var eq6 := AudioEffectEQ6.new()
	var cases := {
		"none": [],
		"eq6_flat": [eq6],
		"eq10_flat": [AudioEffectEQ10.new()],
		"eq10_all_m325": [eq10m],
		"eq21_flat": [eq21m],
		"lowshelf_1000_g0708": [_shelf(true, 1000.0, 0.708)],
		"lowshelf_1000_g0841": [_shelf(true, 1000.0, 0.841)],
		"lowshelf_200_g1259": [_shelf(true, 200.0, 1.259)],
		"lowshelf_200_g1122": [_shelf(true, 200.0, 1.122)],
		"lowshelf_1000_g0841_r0707": [_shelf(true, 1000.0, 0.841, 0.707)],
		"lowshelf_1000_g0841_r1": [_shelf(true, 1000.0, 0.841, 1.0)],
		"highshelf_1000_g0841": [_shelf(false, 1000.0, 0.841)],
		"lowshelf_1000_g0841_12db": [_shelf(true, 1000.0, 0.841, 0.5, 1)],
		"notch_500_r01": [_notch(500.0, 0.1)],
		"notch_500_r05": [_notch(500.0, 0.5)],
		"dip_shelves": [_shelf(true, 1000.0, 0.841), _shelf(true, 200.0, 1.122)],
	}
	AudioServer.add_bus()
	AudioServer.set_bus_name(1, "X")
	_p = AudioStreamPlayer.new()
	_p.bus = "X"
	root.add_child(_p)
	_p.stream = _impulse()
	for name: String in cases:
		while AudioServer.get_bus_effect_count(1) > 0:
			AudioServer.remove_bus_effect(1, 0)
		for e: AudioEffect in cases[name]:
			AudioServer.add_bus_effect(1, e)
		_cap = AudioEffectCapture.new()
		_cap.buffer_length = 2.0
		AudioServer.add_bus_effect(1, _cap)
		await _wait(200)
		_cap.clear_buffer()
		_p.play()
		await _wait(1300)
		var fr := _cap.get_buffer(_cap.get_frames_available())
		var b := PackedFloat32Array()
		b.resize(fr.size())
		for i in fr.size():
			b[i] = fr[i].x
		var f := FileAccess.open(OUT + name + ".f32", FileAccess.WRITE)
		f.store_buffer(b.to_byte_array())
		f.close()
		print(name, " frames ", fr.size())
		_p.stop()
	quit(0)
