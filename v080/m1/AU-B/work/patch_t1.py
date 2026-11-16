import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(a, b, count=1):
    global s
    if s.count(a) < 1:
        raise SystemExit('NICHT GEFUNDEN: ' + a[:100].replace('\n', ' | '))
    s = s.replace(a, b, count)


rep('''	assert_true(b.ok(), "Fixture lädt: %s" % str(b.errors))
	assert_true(b.warnings.is_empty(), "Fixture ohne Hinweise: %s" % str(b.warnings))
	return b''', '''	assert_true(b.ok(), "Fixture lädt: %s" % str(b.errors))
	# the fixture is a 16-kHz bank on purpose (half the samples): that is its only deviation
	assert_true(b.warnings.size() == 1 and b.warnings[0].contains("16000"), "Fixture: nur der Hinweis auf die Abtastrate (%s)" % str(b.warnings))
	return b''')
rep('''	# a stereo clip keeps its channels (left louder in the fixture), a mono clip is panned
	var m3 := _plain(b, 18)
	m3.reset()
	m3.fade_to(1.0, 0.0001)
	m3.play_clip("crackle", 0, 1.0, 1.0)
	var o3 := _power(_render(m3, 0.05))
	assert_true(o3.x > 3.0 * o3.y and o3.y > 0.0, "Stereo-Clip: Kanäle wie gespeichert (L %.5f, R %.5f)" % [o3.x, o3.y])
	for pan: float in [-1.0, 0.0, 1.0]:
		var m4 := _plain(b, 19)
		m4.reset()
		m4.fade_to(1.0, 0.0001)
		m4.play_clip("shift", 0, 1.0, pan)
		var o4 := _power(_render(m4, 0.06))
		if pan < 0.0:
			assert_true(o4.x > 100.0 * o4.y, "Mono-Clip ganz links")
		elif pan > 0.0:
			assert_true(o4.y > 100.0 * o4.x, "Mono-Clip ganz rechts")
		else:
			assert_near(_db(o4.y / o4.x), 0.0, 0.05, "Mono-Clip mittig")''', '''	# a stereo clip keeps its channels (left twice the right in the fixture), a mono clip is panned
	var o3 := _clip_alone(b, "crackle", 0, 1.0)
	assert_near(_db(o3.x / o3.y), 6.02, 0.1, "Stereo-Clip: Kanäle wie gespeichert, sein Pan zählt nicht (L/R %.2f dB)" % _db(o3.x / o3.y))
	for pan: float in [-1.0, 0.0, 1.0]:
		for index in 2:
			var o4 := _clip_alone(b, "shift", index, pan)
			if pan < 0.0:
				assert_true(o4.x > 1.0e-5 and o4.y < 1.0e-10, "Mono-Clip %d ganz links" % index)
			elif pan > 0.0:
				assert_true(o4.y > 1.0e-5 and o4.x < 1.0e-10, "Mono-Clip %d ganz rechts" % index)
			else:
				assert_near(_db(o4.y / o4.x), 0.0, 0.01, "Mono-Clip %d mittig" % index)''')
rep('''func test_clips_start_crackles_and_panning() -> void:''', '''## Power of a clip alone: the same mixer run with and without it, subtracted (clips are added after the saturation).
func _clip_alone(b: EngineBank2, clip_name: String, index: int, pan: float) -> Vector3:
	var outs: Array[PackedVector2Array] = []
	for with_clip: bool in [false, true]:
		var m := _plain(b, 19)
		m.set_manual(2500.0, 0.0, 0.0)
		if with_clip:
			m.play_clip(clip_name, index, 1.0, pan)
		outs.append(_render(m, 0.06))
	var diff := PackedVector2Array()
	diff.resize(outs[0].size())
	for i in diff.size():
		diff[i] = outs[1][i] - outs[0][i]
	return _power(diff)


func test_clips_start_crackles_and_panning() -> void:''')
open(p, 'w', encoding='utf-8').write(s)
print('ok')
