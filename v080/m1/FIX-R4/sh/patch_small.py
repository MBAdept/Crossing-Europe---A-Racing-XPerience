import sys, os
wt = sys.argv[1]
def patch(rel, pairs):
    p = os.path.join(wt, rel)
    s = open(p, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (rel, old[:70], s.count(old))
        s = s.replace(old, new)
    open(p, "w", encoding="utf-8").write(s)
    print("patched", rel)

# B5: weather follows the watchdog
patch("scripts/race3d/layers/weather.gd", [(
"""func prepare(ctx: Dictionary) -> void:
	kind = kind_of(str(ctx.get("weather", "normal")))
	_build()
""",
"""func prepare(ctx: Dictionary) -> void:
	kind = kind_of(str(ctx.get("weather", "normal")))
	_build()


## FIX-R4 (QA-R4 B5): the slowness watchdog stepped the preset down during the countdown – the precipitation takes the
## lower level's count and box at once (the first `_count` instances of the built MultiMesh: the shader places every
## instance by its number alone, so the rest needs no new buffer) and the spray its lower setting.
func quality_lowered(levels: Dictionary) -> void:
	var before := _count
	apply_quality(levels)
	if _particles == null or _particles.multimesh == null:
		return
	_count = mini(_count, before)
	_level = level_of(_count)
	_box = box_for(kind, _level)
	if _pmat != null:
		_pmat.set_shader_parameter(&"box_lo", Vector3(-_box.x, BOX_BELOW, _box.y))
		_pmat.set_shader_parameter(&"box_hi", Vector3(_box.x, BOX_ABOVE, _box.z))
	_particles.multimesh.visible_instance_count = mini(_count, _particles.multimesh.instance_count)
"""),
("""	return {"weather": {"kind": kind, "particles": _count, "level": _level, "shown": _shown, "fade": snappedf(_fade, 0.001),""",
"""	return {"weather": {"kind": kind, "particles": _count, "level": _level, "shown": _shown, "fade": snappedf(_fade, 0.001),
		"drawn": _particles.multimesh.visible_instance_count if _particles != null and _particles.multimesh != null else 0,""")])

# B6 + B8: after-glow limited in time, glare quad drawn first among the transparent things
patch("scripts/race3d/environment_rig.gd", [(
"""const EXIT_AFTER := 0.4
const EXIT_AFTER_M := 60.0
""",
"""const EXIT_AFTER := 0.4
const EXIT_AFTER_M := 60.0
## FIX-R4 (QA-R4 B6): … and for at most this long after the camera passed the portal (view.time; the crossing time is
## estimated from the speed, so a stage that starts behind an exit shows none): a car standing behind an exit (a jam,
## a crash, a police stop) stayed over-exposed for good. Whichever of way and time is further along decides – above
## 108 km/h the way (the look of R4), below it the time.
const EXIT_AFTER_S := 2.0
"""),
("""	var after := day * exit_after(exit_behind(_track, cam_z))
	_exit_state = Vector2(glare, after)""",
"""	var behind := exit_behind(_track, cam_z)
	var time := float(view.get("time", 0.0))
	if behind >= 0.0:
		var z1 := cam_z - behind
		if absf(z1 - _after_exit_z) > 0.5 or _after_t0 > time:
			# a new exit behind the camera: when did the camera pass it (now minus the way at the current speed)
			_after_exit_z = z1
			_after_t0 = time - behind / maxf(float(view.get("speed", 0.0)) / 3.6, 1.0)
	else:
		_after_exit_z = -1.0e9
	var after := day * exit_after_timed(behind, time - _after_t0)
	_exit_state = Vector2(glare, after)"""),
("""## Alpha of the over-exposure of the whole picture `d` metres after a tunnel exit (pure; d < 0: none).
static func exit_after(d: float) -> float:
	if d < 0.0 or d >= EXIT_AFTER_M:
		return 0.0
	return EXIT_AFTER * (1.0 - smoothstep(0.0, EXIT_AFTER_M, d))
""",
"""## Alpha of the over-exposure of the whole picture `d` metres after a tunnel exit (pure; d < 0: none).
static func exit_after(d: float) -> float:
	if d < 0.0 or d >= EXIT_AFTER_M:
		return 0.0
	return EXIT_AFTER * (1.0 - smoothstep(0.0, EXIT_AFTER_M, d))


## FIX-R4 (QA-R4 B6): the after-glow `d` metres and `dt` seconds after the camera passed the exit (pure): it fades
## with whichever of the two is further along (EXIT_AFTER_M, EXIT_AFTER_S) – never longer than EXIT_AFTER_S.
static func exit_after_timed(d: float, dt: float) -> float:
	if d < 0.0 or d >= EXIT_AFTER_M or dt >= EXIT_AFTER_S:
		return 0.0
	var u := maxf(d / EXIT_AFTER_M, maxf(dt, 0.0) / EXIT_AFTER_S)
	return EXIT_AFTER * (1.0 - smoothstep(0.0, 1.0, u))
"""),
("""	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"gain", EXIT_GAIN)
	m.set_shader_parameter(&"lift", EXIT_LIFT)
	return m""",
"""	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"gain", EXIT_GAIN)
	m.set_shader_parameter(&"lift", EXIT_LIFT)
	# FIX-R4 (QA-R4 B8): the glare quad replaces what lies behind it with the over-exposed copy of the opaque picture;
	# drawn FIRST of all transparent things, the lamp glows, rain and glass beyond the portal come after it and stay
	# (sorted by depth it could be drawn after a brake light outside the tube and wipe it out – F6)
	m.render_priority = Material.RENDER_PRIORITY_MIN
	return m""")])
