extends TestCase
## The Arcade sound is what it was in v0.7.0 (contract Rules 1 and 4, D25; §6 AU-A): the current tree against the
## fingerprints written from the tag by tools/audio/modern/make_arcade_golden.sh (golden/arcade_v070_headless.json):
## seeded engine mixer output per car, every SfxSynth sound, the traffic model, the frozen files themselves – also
## while the Modern profile is built in the same process. The bus layout is compared in a running game by
## check_modern_audio.gd (test_modern_checks.gd).

const GOLDEN := "res://tests/unit/audio_modern/golden/arcade_v070_headless.json"
const TOOL := "res://tests/unit/audio_modern/golden/arcade_golden.gd"


func _golden() -> Dictionary:
	var d: Variant = ConfigLoader.load_json(GOLDEN)
	assert_true(d is Dictionary, "Fingerabdrücke %s lesbar" % GOLDEN)
	return d if d is Dictionary else {}


func _tool() -> GDScript:
	return load(TOOL)


## Compares {name: {sha256, …}} maps and names what differs.
func _same_hashes(now: Dictionary, gold: Dictionary, what: String) -> void:
	assert_eq(now.size(), gold.size(), "%s: Anzahl" % what)
	for k: String in gold:
		var g: Dictionary = gold[k]
		var n: Dictionary = now.get(k, {})
		if str(n.get("sha256", "fehlt")) != str(g.get("sha256", "")):
			fail("%s %s: SHA-256 %s statt %s (Samples %s / %s, Spitze %s / %s, RMS %s / %s)" % [what, k,
				str(n.get("sha256", "fehlt")).left(12), str(g.get("sha256", "")).left(12), str(n.get("samples", "?")),
				str(g.get("samples", "?")), str(n.get("peak", "?")), str(g.get("peak", "?")), str(n.get("rms", "?")),
				str(g.get("rms", "?"))])


func test_engine_mixer_output_is_byte_identical_to_v070() -> void:
	var gold: Dictionary = _golden().get("engine", {})
	assert_eq(gold.size(), 6, "fünf Autos und die Fixture-Bank")
	_same_hashes(_tool().call("engine_hashes"), gold, "Motor")


## The same with the Modern profile alive in the process: its buses exist, its slots hold an Arcade engine of their
## own and render in between.
func test_engine_mixer_output_with_the_modern_profile_running() -> void:
	var gold: Dictionary = _golden().get("engine", {})
	var conf := cfg().duplicate(true)
	var banks := {}
	var provider := func(id: String) -> EngineBank:
		if not banks.has(id):
			banks[id] = EngineBank.load_file("res://assets/audio/engines/%s.json" % id)
		return banks[id]
	var m := ModernAudio.new()
	m.start(conf, {"live": false, "quiet": true, "bank_provider": provider})
	m.set_vehicle("limousine")
	for i in 30:
		m.set_engine(150.0, 1.0, 245.0, true)
		m.step(1.0 / 60.0, false)
	assert_true(float(m.engine_state().get("rpm", 0.0)) > 900.0, "der Modern-Platzhaltermotor läuft")
	var now: Dictionary = _tool().call("engine_hashes")
	for i in 30:
		m.set_engine(200.0, 1.0, 245.0, true)
		m.step(1.0 / 60.0, false)
	m.shutdown()
	m.free()
	_same_hashes(now, gold, "Motor (Modern aktiv)")
	assert_eq(AudioServer.bus_count, 1, "Modern-Busse wieder entfernt")


func test_sfx_synth_sounds_are_byte_identical_to_v070() -> void:
	var gold: Dictionary = _golden().get("sfx", {})
	assert_eq(gold.size(), 17, "17 synthetisierte Klänge")
	_same_hashes(_tool().call("sfx_hashes"), gold, "SfxSynth")


func test_traffic_and_room_model_are_identical_to_v070() -> void:
	var gold: Dictionary = _golden().get("traffic", {})
	var now: Dictionary = _tool().call("traffic_hash")
	assert_eq(str(now.get("sha256", "fehlt")), str(gold.get("sha256", "")), "Verkehrsmodell und Raumklang (%s Werte)" % str(now.get("values", "?")))
	assert_eq(int(now.get("values", 0)), int(gold.get("values", -1)), "Anzahl der Werte")


func test_frozen_audio_files_are_unchanged() -> void:
	var gold: Dictionary = _golden().get("files", {})
	var now: Dictionary = _tool().call("file_hashes")
	assert_true(gold.size() >= 30, "Liste der eingefrorenen Dateien (%d)" % gold.size())
	assert_eq(now.size(), gold.size(), "Anzahl der Dateien (neu oder gelöscht?)")
	for p: String in gold:
		if str(now.get(p, "fehlt")) != str(gold[p]):
			fail("%s wurde geändert (Regel 1: eingefroren)" % p)


## The table the Modern one-shots use for the Arcade streams is the AudioManager's.
func test_oneshot_levels_equal_the_audio_manager_table() -> void:
	var am: GDScript = load("res://scripts/audio/audio_manager.gd")
	var arcade: Dictionary = am.get_script_constant_map().get("ONESHOT_DB", {})
	assert_eq(arcade.size(), 11, "ONESHOT_DB des AudioManagers")
	assert_eq(SfxBank.ARCADE_DB.size(), arcade.size(), "gleiche Anzahl")
	for k: String in arcade:
		assert_near(float(SfxBank.ARCADE_DB.get(k, 999.0)), float(arcade[k]), 1.0e-6, "Pegel von %s" % k)
	for k: String in ImpactAudio.LEVEL_DB:
		assert_near(float(ImpactAudio.LEVEL_DB[k]), float(arcade[k]), 1.0e-6, "Aufprall-Pegel von %s" % k)
	for k: String in SfxBank.ROUTES:
		assert_true(arcade.has(k), "%s ist ein Arcade-Klang" % k)
	for k: String in ModernAudio.PLAY_EVENTS:
		assert_true(arcade.has(k), "%s ist ein Arcade-Klang" % k)
