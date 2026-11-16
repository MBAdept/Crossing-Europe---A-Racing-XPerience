"""Race EQ of the music: shelving filters in series (exact) instead of AudioEffectEQ10 (not neutral at 0 dB)."""
R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("scripts/audio/modern/modern_buses.gd", [
    ('''## the signal's own steepness = a click), AudioEffectAmplify ramps across the block (1.0–1.5×).
''', '''## the signal's own steepness = a click), AudioEffectAmplify ramps across the block (1.0–1.5×).
##
## Race EQ of the music (audio.modern.music.race_eq): shelving filters in series – not AudioEffectEQ6/10/21. Those
## sum band-passes and are not neutral: with every band at 0 dB the EQ10 raises the signal by 1.4 to 3.3 dB (ripple
## from band to band), the EQ21 by about 3.9 dB, the EQ6 by 0.5 to 2.6 dB (measured from impulse responses, Godot
## 4.7.2). A shelving filter is exact: 0 dB outside the shelf, and the square of its "gain" inside (measured: gain
## 0.841 → −3.01 dB, 1.122 → +2.00 dB; half of it at the cutoff, the transition spans about an octave to each side)
## – with the filter's default slope setting and resonance 0.5 (other slope settings change the gain of the shelf).
'''),
    ('''## Centre frequencies of AudioEffectEQ10 (band index = position).
const EQ10_HZ: Array[int] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
''', ''''''),
    ('''var _music_eq: AudioEffectEQ10 = null
var _music_eq_on := false
''', '''var _music_eq: Array[AudioEffectFilter] = []   ## shelving filters of the race EQ on MMusic
var _music_eq_db: Array[float] = []            ## the gain of each shelf in dB when fully on
var _music_eq_amount := 0.0                    ## 0 = off (filters disabled) … 1 = the full shelves
'''),
    ('''	return clampf(1.0 / maxf(1.0 - want, 0.021), 1.0, 48.0)
''', '''	return clampf(1.0 / maxf(1.0 - want, 0.021), 1.0, 48.0)


## Value of the "gain" property of Godot's shelving filters for a shelf of `db` decibels (its square is the gain).
static func shelf_gain(db: float) -> float:
	return clampf(pow(10.0, db / 40.0), 0.05, 4.0)


## A neutral shelving filter (gain 1) for an entry of audio.modern.music.race_eq – {"shelf": "low" | "high", "hz":
## cutoff, "db": gain of the shelf}; null for an entry that would do nothing.
static func shelf_filter(spec: Dictionary) -> AudioEffectFilter:
	var hz := float(spec.get("hz", 0.0))
	if hz <= 0.0 or absf(float(spec.get("db", 0.0))) < 0.01:
		return null
	var f: AudioEffectFilter
	if str(spec.get("shelf", "low")) == "high":
		f = AudioEffectHighShelfFilter.new()
	else:
		f = AudioEffectLowShelfFilter.new()
	f.cutoff_hz = clampf(hz, 20.0, 20000.0)
	f.resonance = 0.5
	f.db = AudioEffectFilter.FILTER_6DB
	f.gain = 1.0
	return f
'''),
    ('''	# MMusic: EQ of the race context (off outside races)
	_music_eq = AudioEffectEQ10.new()
	var eq: Dictionary = _dict(_dict(modern.get("music", {})).get("race_eq_db", {}))
	for i in EQ10_HZ.size():
		_music_eq.set_band_gain_db(i, float(eq.get(str(EQ10_HZ[i]), 0.0)))
	AudioServer.add_bus_effect(index("MMusic"), _music_eq)
	AudioServer.set_bus_effect_enabled(index("MMusic"), 0, false)
	_music_eq_on = false
''', '''	# MMusic: EQ of the race context (off outside races) – shelving filters in series
	var eq: Variant = _dict(modern.get("music", {})).get("race_eq", [])
	var mi := index("MMusic")
	for spec: Variant in (eq if eq is Array else []):
		var sh := shelf_filter(_dict(spec))
		if sh == null:
			continue
		AudioServer.add_bus_effect(mi, sh)
		AudioServer.set_bus_effect_enabled(mi, AudioServer.get_bus_effect_count(mi) - 1, false)
		_music_eq.append(sh)
		_music_eq_db.append(float(_dict(spec).get("db", 0.0)))
	_music_eq_amount = 0.0
'''),
    ('''	_music_eq = null
	_glue = null
''', '''	_music_eq.clear()
	_music_eq_db.clear()
	_music_eq_amount = 0.0
	_glue = null
'''),
    ('''## EQ of the music bus on (race context) or off.
func set_music_eq(on: bool) -> void:
	if _music_eq == null or on == _music_eq_on:
		return
	_music_eq_on = on
	var idx := index("MMusic")
	for j in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, j) == _music_eq:
			AudioServer.set_bus_effect_enabled(idx, j, on)


func music_eq_on() -> bool:
	return _music_eq_on
''', '''## Race EQ of the music bus: 0 = off (its filters are disabled), 1 = the full shelves, between them a share of
## their dB (ModernAudio glides the amount, so switching the context does not step the level of the music).
func set_music_eq_amount(amount: float) -> void:
	var a := clampf(amount, 0.0, 1.0)
	if not built or a == _music_eq_amount:
		return
	var was_on := _music_eq_amount > 0.0
	_music_eq_amount = a
	for i in _music_eq.size():
		_music_eq[i].gain = shelf_gain(_music_eq_db[i] * a)
	if was_on != (a > 0.0):
		var idx := index("MMusic")
		for j in AudioServer.get_bus_effect_count(idx):
			if _music_eq.has(AudioServer.get_bus_effect(idx, j)):
				AudioServer.set_bus_effect_enabled(idx, j, a > 0.0)


## Race EQ fully on or off at once.
func set_music_eq(on: bool) -> void:
	set_music_eq_amount(1.0 if on else 0.0)


func music_eq_on() -> bool:
	return _music_eq_amount > 0.0


func music_eq_amount() -> float:
	return _music_eq_amount


## The shelving filters of the race EQ, in the order of audio.modern.music.race_eq.
func music_eq() -> Array[AudioEffectFilter]:
	return _music_eq
'''),
    ('''		if fx.get_class() == cls and fx != _faders.get(bus) and fx != _lowpass.get(bus):
			return fx
''', '''		if fx.get_class() == cls and fx != _faders.get(bus) and fx != _lowpass.get(bus) and not _music_eq.has(fx):
			return fx
'''),
    ('''## The first effect of that class on a bus; created in front of the snapshot low-pass / fader when missing
## (effects a slot owns, e.g. the stereo width of a mono engine). null for a missing bus.''',
     '''## The first effect of that class on a bus; created in front of the snapshot low-pass / fader when missing
## (effects a slot owns, e.g. the stereo width of a mono engine). null for a missing bus. Never one of the effects
## this object owns (fader, snapshot low-pass, race EQ).'''),
    ('''##      ├─ MMusic               music: EQ of the race context, pause low-pass, fader (ducking, dips)''',
     '''##      ├─ MMusic               music: EQ of the race context (shelves), pause low-pass, fader (ducking, dips)'''),
])

patch("scripts/audio/modern/modern_audio.gd", [
    ('''var _music_context := "off"
''', '''var _music_context := "off"
var _eq_amount := 0.0            ## race EQ of the music: 0 off … 1 full (glides with the context)
var _eq_fade_s := 0.4
'''),
    ('''	mix = ModernMix.new()
	mix.setup(ctx.modern)
	ctx.mix = mix
''', '''	mix = ModernMix.new()
	mix.setup(ctx.modern)
	ctx.mix = mix
	_eq_amount = 0.0
	_eq_fade_s = maxf(ctx.number("music.race_eq_fade_s", 0.4), 0.01)
'''),
    ('''	mix.step(delta, car, mute_request, buses.peak_db("MEnv") if ctx.live else ModernMix.KEY_FLOOR_DB)
	f.effects_muted = mix.effects_muted
	_apply_mix()
''', '''	mix.step(delta, car, mute_request, buses.peak_db("MEnv") if ctx.live else ModernMix.KEY_FLOOR_DB)
	f.effects_muted = mix.effects_muted
	_eq_amount = move_toward(_eq_amount, 1.0 if _music_context == "race" else 0.0, delta / _eq_fade_s)
	_apply_mix()
'''),
    ('''	buses.set_music_eq(_music_context == "race")
''', '''	buses.set_music_eq_amount(_eq_amount)
'''),
])

# --- configuration
P = R + "config/game_config.json"
s = open(P, encoding="utf-8").read()
old = '"race_eq_db": {"62": -1.0, "500": -3.0}, "fade_in_s": 0.4, "fade_out_s": 0.6},'
new = ('"race_eq": [{"shelf": "low", "hz": 1100.0, "db": -3.2}, {"shelf": "low", "hz": 180.0, "db": 2.2}], '
       '"race_eq_fade_s": 0.4, "fade_in_s": 0.4, "fade_out_s": 0.6},')
assert s.count(old) == 1
s = s.replace(old, new)
old = ("race_eq_db = Equalizer der Musik im Rennen (Band in Hz → dB; Bänder 31, 62, 125, 250, 500, 1000, 2000, 4000, "
       "8000, 16000), fade_in_s / fade_out_s = Überblenden zwischen Stücken. ")
new = ("race_eq = Klangregelung der Musik im Rennen, die dem Motor Platz macht: Kuhschwanzfilter in Reihe, je Eintrag "
       "shelf (\\\"low\\\" = unterhalb von hz, \\\"high\\\" = oberhalb), hz (dort ist die Hälfte erreicht, der Übergang "
       "reicht etwa eine Oktave nach beiden Seiten) und db; die beiden Einträge ergeben zusammen eine breite Mulde um "
       "500 Hz (gemessen: 62 Hz −1,0 dB, 250 Hz −2,7 dB, 500 Hz −3,0 dB, 1 kHz −1,9 dB, 2 kHz −0,3 dB, ab 4 kHz 0 dB); "
       "race_eq_fade_s = so lange blendet sie beim Wechsel des Kontexts ein und aus; fade_in_s / fade_out_s = "
       "Überblenden zwischen Stücken. ")
assert s.count(old) == 1, s.count(old)
s = s.replace(old, new)
open(P, "w", encoding="utf-8").write(s)

# --- tests
patch("tests/unit/audio_modern/test_modern_buses.gd", [
    ('''	assert_eq(_classes("MMusic"), ["AudioEffectEQ10", "AudioEffectLowPassFilter", "AudioEffectAmplify"] as Array[String], "MMusic")''',
     '''	assert_eq(_classes("MMusic"), ["AudioEffectLowShelfFilter", "AudioEffectLowShelfFilter", "AudioEffectLowPassFilter", "AudioEffectAmplify"] as Array[String], "MMusic: Renn-EQ (zwei Kuhschwanzfilter), Tiefpass, Fader")'''),
    ('''	assert_false(_enabled("MMusic", "AudioEffectEQ10"), "Renn-EQ aus")
	for n in ModernBuses.FADER_BUSES:''', '''	assert_false(b.music_eq_on(), "Renn-EQ aus")
	for fx in b.music_eq():
		assert_false(_enabled_fx("MMusic", fx), "Filter des Renn-EQ aus")
		assert_near(fx.gain, 1.0, 1.0e-6, "und neutral")
	for n in ModernBuses.FADER_BUSES:'''),
    ('''func _effect(bus: String, cls: String) -> AudioEffect:''', '''func _enabled_fx(bus: String, fx: AudioEffect) -> bool:
	var idx := AudioServer.get_bus_index(bus)
	for j in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, j) == fx:
			return AudioServer.is_bus_effect_enabled(idx, j)
	return false


func _shelf_db(fx: AudioEffectFilter) -> float:
	return 40.0 * log(fx.gain) / log(10.0)   # the gain of the shelf is the square of the filter's "gain"


func _effect(bus: String, cls: String) -> AudioEffect:'''),
    ('''	b.set_music_eq(true)
	assert_true(_enabled("MMusic", "AudioEffectEQ10"), "Renn-EQ an")
	var eq := _effect("MMusic", "AudioEffectEQ10") as AudioEffectEQ10
	var want: Dictionary = ConfigLoader.lookup(cfg(), "audio.modern.music.race_eq_db", {})
	for i in ModernBuses.EQ10_HZ.size():
		assert_near(eq.get_band_gain_db(i), float(want.get(str(ModernBuses.EQ10_HZ[i]), 0.0)), 1.0e-5, "Band %d Hz" % ModernBuses.EQ10_HZ[i])
	assert_near(eq.get_band_gain_db(4), -3.0, 1.0e-5, "500 Hz um 3 dB abgesenkt (Platz für den Motor)")
	b.set_music_eq(false)
	assert_false(_enabled("MMusic", "AudioEffectEQ10"), "Renn-EQ aus")
''', '''	# race EQ: shelving filters in series (a broad dip around 500 Hz that makes room for the engine); its response
	# is measured by check_modern_audio.gd --live
	var eq := b.music_eq()
	var want: Array = ConfigLoader.lookup(cfg(), "audio.modern.music.race_eq", [])
	assert_eq(eq.size(), want.size(), "ein Filter je Eintrag")
	assert_true(eq.size() >= 1, "es gibt eine Klangregelung fürs Rennen")
	b.set_music_eq(true)
	assert_true(b.music_eq_on(), "Renn-EQ an")
	var bass_db := 0.0
	for i in eq.size():
		var spec: Dictionary = want[i]
		assert_true(_enabled_fx("MMusic", eq[i]), "Filter %d an" % i)
		assert_true(eq[i] is AudioEffectLowShelfFilter or eq[i] is AudioEffectHighShelfFilter, "Kuhschwanzfilter")
		assert_near(eq[i].cutoff_hz, float(spec["hz"]), 0.01, "Eckfrequenz %d" % i)
		assert_near(_shelf_db(eq[i]), float(spec["db"]), 1.0e-3, "Gewinn der Stufe %d" % i)
		assert_near(eq[i].resonance, 0.5, 1.0e-6, "ohne Überhöhung")
		assert_eq(int(eq[i].db), int(AudioEffectFilter.FILTER_6DB), "Flankeneinstellung, für die der Gewinn gemessen ist")
		if eq[i] is AudioEffectLowShelfFilter:
			bass_db += _shelf_db(eq[i])
	assert_between(bass_db, -2.0, 0.0, "der Bass bleibt fast, wie er ist (%.1f dB)" % bass_db)
	b.set_music_eq_amount(0.5)
	assert_near(b.music_eq_amount(), 0.5, 1.0e-6, "halb eingeblendet")
	for i in eq.size():
		assert_near(_shelf_db(eq[i]), 0.5 * float((want[i] as Dictionary)["db"]), 1.0e-3, "halber Gewinn der Stufe %d" % i)
		assert_true(_enabled_fx("MMusic", eq[i]), "Filter %d bleibt an" % i)
	b.set_music_eq(false)
	assert_false(b.music_eq_on(), "Renn-EQ aus")
	for i in eq.size():
		assert_false(_enabled_fx("MMusic", eq[i]), "Filter %d aus" % i)
		assert_near(eq[i].gain, 1.0, 1.0e-6, "neutral")
	assert_near(ModernBuses.shelf_gain(-6.0), 0.70795, 1.0e-4, "−6 dB: Gewinn 0,708 (gemessen −6,00 dB)")
	assert_true(ModernBuses.shelf_filter({"shelf": "low", "hz": 200.0, "db": 0.0}) == null, "0 dB: kein Filter")
	assert_true(ModernBuses.shelf_filter({"shelf": "high", "hz": 4000.0, "db": 2.0}) is AudioEffectHighShelfFilter, "Höhen")
'''),
    ('''	assert_eq(_classes("MMusic"), ["AudioEffectEQ10", "AudioEffectChorus", "AudioEffectLowPassFilter", "AudioEffectAmplify"] as Array[String], "vor Tiefpass und Fader")''',
     '''	assert_eq(_classes("MMusic"), ["AudioEffectLowShelfFilter", "AudioEffectLowShelfFilter", "AudioEffectChorus", "AudioEffectLowPassFilter", "AudioEffectAmplify"] as Array[String], "vor Tiefpass und Fader")
	assert_true(b.effect("MMusic", "AudioEffectLowShelfFilter", false) == null, "die Filter des Renn-EQ werden nicht herausgegeben")'''),
])

patch("tests/unit/audio_modern/test_modern_audio.gd", [
    ('''	# the race EQ of the music follows the context
	assert_true(m.buses.music_eq_on(), "im Rennen ist der Musik-EQ an")
	m.set_music_context("menu")
	_steps(m, 1)
	assert_false(m.buses.music_eq_on(), "im Menü aus")
''', '''	# the race EQ of the music follows the context – gliding, so the level of the music never steps
	assert_near(m.buses.music_eq_amount(), 1.0, 1.0e-6, "im Rennen ist der Musik-EQ ganz an")
	m.set_music_context("menu")
	_steps(m, 1)
	assert_between(m.buses.music_eq_amount(), 0.5, 0.999, "er blendet aus")
	_steps(m, 60)
	assert_false(m.buses.music_eq_on(), "im Menü aus")
	m.set_music_context("race")
	_steps(m, 1)
	assert_between(m.buses.music_eq_amount(), 0.001, 0.5, "und wieder ein")
	_steps(m, 60)
	assert_near(m.buses.music_eq_amount(), 1.0, 1.0e-6, "ganz an")
'''),
])
print("ok")
