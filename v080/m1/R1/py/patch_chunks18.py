def patch(p, pairs):
    s = open(p, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (p, s.count(old), old[:70])
        s = s.replace(old, new)
    open(p, 'w', encoding='utf-8').write(s)


patch('tests/unit/race3d/test_chunk_streamer.gd', [
    ('''## Acceptance: sync mode gives the same snapshot twice; at most max_chunks chunks (config graphics.modern.max_chunks,
## 16); freed behind the camera.''', '''## Acceptance: sync mode gives the same snapshot twice; at most max_chunks chunks (config graphics.modern.max_chunks,
## 18 since contract amendment A-3); freed behind the camera.'''),
    ('''		assert_eq(cap, 16, "die Grenze steht in der Konfiguration (graphics.modern.max_chunks; Vertrag §4.5.5: 16)")''',
     '''		assert_eq(cap, 18, "die Grenze steht in der Konfiguration (graphics.modern.max_chunks; Vertrag §4.5.5 mit Nachtrag A-3: 18)")'''),
    ('''			assert_true(st.chunk_count() <= 16, "höchstens 16 Stücke")''',
     '''			assert_true(st.chunk_count() <= st.max_chunks, "höchstens %d Stücke" % st.max_chunks)'''),
])
patch('scripts/race3d/chunk_streamer.gd', [
    ('''var max_chunks := 16
''', '''var max_chunks := 18
'''),
    ('''	max_chunks = maxi(2, int(m.get("max_chunks", 16)))''', '''	max_chunks = maxi(2, int(m.get("max_chunks", 18)))'''),
])
patch('tests/race3d/fairness.gd', [
    ('''	var max_chunks := int(gm.get("max_chunks", 16))''', '''	var max_chunks := int(gm.get("max_chunks", 18))'''),
])
patch('tests/sim/modern_path_check.gd', [
    ('''int(ConfigLoader.lookup(ConfigLoader.load_merged(), "graphics.modern.max_chunks", 16))''',
     '''int(ConfigLoader.lookup(ConfigLoader.load_merged(), "graphics.modern.max_chunks", 18))'''),
])
# environment rig and lights layer follow a step-down of the watchdog
patch('scripts/race3d/environment_rig.gd', [
    ('''func update(view: Dictionary, _dt: float) -> void:
	var pal: Dictionary = view.get("palette", {})
	var cam_z := float(view.get("camera_z", 0.0))''', '''## The slowness watchdog stepped the preset down while the stage runs: what selects no shader variant follows –
## shadow reach, glow, SSAO, sky reflections. Shadow mode and split blending stay as they are (D10).
func quality_lowered(levels: Dictionary) -> void:
	var reach := float(levels.get("shadow_distance_m", 0.0))
	sun.directional_shadow_max_distance = reach if reach > 0.0 else SHADOW_DISTANCE_M
	environment.glow_enabled = bool(levels.get("glow", false))
	environment.ssao_enabled = bool(levels.get("ssao", false))
	_sky_reflections = bool(levels.get("sky_reflections", true))
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if _sky_reflections else Environment.REFLECTION_SOURCE_DISABLED


func update(view: Dictionary, _dt: float) -> void:
	var pal: Dictionary = view.get("palette", {})
	var cam_z := float(view.get("camera_z", 0.0))'''),
])
patch('scripts/race3d/layers/lights.gd', [
    ('''func _build_lights() -> void:''', '''## The slowness watchdog stepped the preset down: fewer lamps of the omni pool are used (the nodes stay).
func quality_lowered(levels: Dictionary) -> void:
	var want := clampi(int(levels.get("omni_pool", 4)), 0, 8)
	while omnis.size() > want:
		var o: OmniLight3D = omnis.pop_back()
		o.queue_free()
	_rank_seg = -1


func _build_lights() -> void:'''),
])
print("ok")
