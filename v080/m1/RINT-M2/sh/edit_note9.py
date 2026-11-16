W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:70], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)
L = "scripts/race3d/layers/lights.gd"
sub(L, """		entries.append({"pos": d.get("pos", Vector3.ZERO), "dir": dir.normalized() if dir.length_squared() > 1.0e-6 else Vector3.DOWN,
			"color": d.get("color", LAMP_COLOR), "range": reach, "energy": float(d.get("energy", 1.0)), "drop": -1.0})""",
"""		# "src": the builder's own dictionary – its "energy" is read every frame (RINT-M2, FIX-R6 note: the radar flash
		# changes it per frame and lights the road under the camera with it)
		entries.append({"pos": d.get("pos", Vector3.ZERO), "dir": dir.normalized() if dir.length_squared() > 1.0e-6 else Vector3.DOWN,
			"color": d.get("color", LAMP_COLOR), "range": reach, "energy": float(d.get("energy", 1.0)), "drop": -1.0, "src": d})""")
sub(L, """		var light := display_to_light(POOL_LEVEL * float(e["energy"]) * lamps_on * fade, e["color"], ambient)""",
"""		var light := display_to_light(POOL_LEVEL * entry_energy(e) * lamps_on * fade, e["color"], ambient)""")
sub(L, """		o.light_energy = OMNI_ENERGY * float(e2["energy"]) * lamps_on * fade2""",
"""		o.light_energy = OMNI_ENERGY * entry_energy(e2) * lamps_on * fade2""")
sub(L, """## Retro-reflectors of a chunk part: {pos, dir (unit, where the reflector looks), color, size (m)}, local to parent.""",
"""## Energy of a static lamp entry this frame: the builder's dictionary ("src") may change it per frame (the radar flash);
## without one, the energy given to add_static(). Pure (unit test).
static func entry_energy(e: Dictionary) -> float:
	var src: Variant = e.get("src")
	if src is Dictionary:
		return maxf(0.0, float((src as Dictionary).get("energy", e.get("energy", 1.0))))
	return maxf(0.0, float(e.get("energy", 1.0)))


## Retro-reflectors of a chunk part: {pos, dir (unit, where the reflector looks), color, size (m)}, local to parent.""")

F = "scripts/race3d/layers/flares.gd"
sub(F, """			var role := str(l.get("role", "lights"))
			var on := 1.0 if role == "on" else (maxf(night, 1.0 if in_tunnel else 0.0) if ROLES_NIGHT.has(role) else night)
			if on <= 0.01:
				continue""", """			var role := str(l.get("role", "lights"))
			var on := 1.0 if role == "on" else (maxf(night, 1.0 if in_tunnel else 0.0) if ROLES_NIGHT.has(role) else night)
			if on <= 0.01:
				continue
			var energy := float(l.get("energy", 1.0))
			if energy <= 0.0:
				continue      # RINT-M2 (QA-R6): a lamp switched off this frame (radar flash, countdown lamp) costs no instance""")
sub(F, """			var energy := float(l.get("energy", 1.0))
			var s := on * energy * alpha * lerpf(STATIC_HALO, 1.0, far)""", """			# optional "halo": the share of its strength near the camera instead of STATIC_HALO (1 for a pure glow without
			# lit geometry – the radar flash; R6)
			var s := on * energy * alpha * lerpf(float(l.get("halo", STATIC_HALO)), 1.0, far)""")
sub(F, """			if dirs[j].y < -0.5 and float(l.get("range", 0.0)) > 0.0:""",
"""			# optional "glow": false – no warm glow of a street lamp's head (a lamp under a canopy, R6)
			if dirs[j].y < -0.5 and float(l.get("range", 0.0)) > 0.0 and bool(l.get("glow", true)):""")

R = "scripts/race3d/builders/radar.gd"
sub(R, """## layers/flares.gd STATIC_HALO: a lamp larger than 6 px on screen gets only this share of its strength (its lit
## geometry carries the light near the camera) – the flash has no lit geometry and is always that large (6 m)
const HALO_SHARE := 0.35
## flare strength per unit of flash: the flare adds colour × 0.5 × strength, Arcade's glow colour × alpha (= flash) –
## render check v1 measured the flash without this compensation only +0.17 luminance at the head, no white pixels
const FLASH_GAIN := 2.0 / HALO_SHARE""", """## flare strength per unit of flash: the flare adds colour × 0.5 × strength, Arcade's glow colour × alpha (= flash).
## The flash has no lit geometry: its entry asks the flare layer for its full strength near the camera too ("halo": 1,
## RINT-M2 – before, FLASH_GAIN carried 1 / STATIC_HALO for it)
const FLASH_GAIN := 2.0
const FLASH_HALO := 1.0
## RINT-M2 (FIX-R6 note): the flash also lights the road under the camera at night – a light pool of this radius whose
## energy follows the flash (layers/lights.gd reads it every frame); by day the lights layer shows no pool
const FLASH_POOL_M := 9.0""")
sub(R, """		var entry := {"pos": c["pos"], "dir": c["dir"], "role": "on", "color": FLASH_COLOUR, "size": 0.0, "range": 0.0, "energy": 0.0}""",
"""		var entry := {"pos": c["pos"], "dir": c["dir"], "role": "on", "color": FLASH_COLOUR, "size": 0.0, "range": FLASH_POOL_M,
			"energy": 0.0, "halo": FLASH_HALO, "glow": false}""")
print("ok")
