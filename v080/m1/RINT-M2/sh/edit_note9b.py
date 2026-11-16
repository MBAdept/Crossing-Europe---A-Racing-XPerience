W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:70], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)
sub("tests/unit/race3d/test_light_pool.gd", """func test_light_cap_per_effects_level() -> void:""",
"""## RINT-M2 (FIX-R6 note): a static lamp's energy is read from the builder's own dictionary every frame – the radar
## flash changes it per frame and lights the road under the camera with it; without that dictionary the energy given.
func test_static_lamp_energy_is_read_every_frame() -> void:
	var src := {"pos": Vector3.ZERO, "dir": Vector3.DOWN, "range": 9.0, "energy": 0.0}
	var e := {"energy": 0.0, "src": src}
	assert_near(Lights.entry_energy(e), 0.0, 1.0e-6, "aus")
	src["energy"] = 1.6
	assert_near(Lights.entry_energy(e), 1.6, 1.0e-6, "die Änderung im Eintrag des Bausteins gilt im selben Bild")
	src["energy"] = -1.0
	assert_near(Lights.entry_energy(e), 0.0, 1.0e-6, "nie negativ")
	assert_near(Lights.entry_energy({"energy": 0.7}), 0.7, 1.0e-6, "ohne Quelle: die gegebene Stärke")
	assert_near(Lights.entry_energy({}), 1.0, 1.0e-6, "ohne Angabe: 1")


func test_light_cap_per_effects_level() -> void:""")
sub("tests/unit/race3d/test_structures.gd", """	assert_near(float(e["energy"]), RadarB.FLASH_GAIN * 0.5, 1.0e-6, "Stärke mit dem Blitz")
""", """	assert_near(float(e["energy"]), RadarB.FLASH_GAIN * 0.5, 1.0e-6, "Stärke mit dem Blitz")
	# RINT-M2: the flash is a pure glow (its full strength near the camera, no warm street-lamp glow) and lights a pool
	# on the road at night through the lights layer (which reads its energy every frame)
	var b2: ChunkBuilder = RadarB.new()
	assert_near(RadarB.FLASH_HALO, 1.0, 1.0e-6, "Blitz: voller Nahanteil (halo 1)")
	assert_true(RadarB.FLASH_POOL_M > 0.0, "Blitz: Lichtkegel auf der Fahrbahn (%.0f m)" % RadarB.FLASH_POOL_M)
	b2.free() if b2 is Object and not (b2 is RefCounted) else null
""")
print("ok")
