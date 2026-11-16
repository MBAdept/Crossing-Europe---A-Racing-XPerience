import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:70])
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'scripts/race3d/prop_library.gd'
rep(p, '''## Light pool of a street light on the ground: Arcade's lamp pools (RoadRenderer._collect_static_lights).
const LAMP_RANGE_M := 9.0
const LAMP_ENERGY := 0.55
''', '''## Light pool of a street light on the ground: Arcade's lamp pools (RoadRenderer._collect_static_lights).
const LAMP_RANGE_M := 9.0
const LAMP_ENERGY := 0.55
## Lamps of a model that look down (street lights, the canopy of a fuel station) light a pool of LAMP_RANGE_M; a
## group of them shares about the light of Arcade's station pool (0.8 at its centre: RoadRenderer._add_light):
## each gets min(LAMP_ENERGY, GROUP_ENERGY / count). Wall lamps (looking sideways, low) light a small pool in front of
## the wall; lamps high up (aviation lights of a wind turbine) light nothing on the ground – they only glow.
const GROUP_ENERGY := 1.6
const WALL_RANGE_M := 5.0
const WALL_ENERGY := 0.4
const BEACON_MIN_H_M := 25.0
''')
rep(p, '''	var lamps: Array = []
	for l: Variant in m.get("lights", []):
		var d: Dictionary = l
		var dir: Variant = d.get("dir")
		var pos: Variant = d.get("pos")
		if not (dir is Array) or (dir as Array).size() < 3 or not (pos is Array) or (pos as Array).size() < 3:
			continue      # baked lights (window panes of a house) live in the emission atlas
		lamps.append({"pos": Vector3(float(pos[0]), float(pos[1]), float(pos[2])),
			"dir": Vector3(float(dir[0]), float(dir[1]), float(dir[2])).normalized(), "role": str(d.get("role", "lights")),
			"color": Color(str(d.get("color", "#fff0cf"))), "size": float(d.get("size", 0.3)), "range": LAMP_RANGE_M,
			"energy": LAMP_ENERGY})
''', '''	var lamps: Array = []
	for l: Variant in m.get("lights", []):
		var d: Dictionary = l
		var dir: Variant = d.get("dir")
		var pos: Variant = d.get("pos")
		if not (dir is Array) or (dir as Array).size() < 3 or not (pos is Array) or (pos as Array).size() < 3:
			continue      # baked lights (window panes of a house) live in the emission atlas
		lamps.append({"pos": Vector3(float(pos[0]), float(pos[1]), float(pos[2])),
			"dir": Vector3(float(dir[0]), float(dir[1]), float(dir[2])).normalized(), "role": str(d.get("role", "lights")),
			"color": Color(str(d.get("color", "#fff0cf"))), "size": float(d.get("size", 0.3)), "range": LAMP_RANGE_M,
			"energy": LAMP_ENERGY})
	lamp_pools(lamps)
''')
rep(p, '''# --- sprite sheets --------------------------------------------------------------------------------------------------
''', '''## Range and energy of the light pool of every lamp of one model (see GROUP_ENERGY): lamps that look down share
## the light of a group, wall lamps get a small pool, lamps high up none (they still glow in the flare layer).
static func lamp_pools(lamps: Array) -> void:
	var down := 0
	for l: Dictionary in lamps:
		if (l["dir"] as Vector3).y < -0.5:
			down += 1
	for l: Dictionary in lamps:
		var dir: Vector3 = l["dir"]
		var pos: Vector3 = l["pos"]
		if pos.y >= BEACON_MIN_H_M:
			l["range"] = 0.0
			l["energy"] = LAMP_ENERGY
		elif dir.y < -0.5:
			l["range"] = LAMP_RANGE_M
			l["energy"] = minf(LAMP_ENERGY, GROUP_ENERGY / float(maxi(down, 1)))
		else:
			l["range"] = WALL_RANGE_M
			l["energy"] = WALL_ENERGY


# --- sprite sheets --------------------------------------------------------------------------------------------------
''')

# lights layer: the pool of a lamp that does not look down lies just in front of it on the ground
p = 'scripts/race3d/layers/lights.gd'
rep(p, '''		var e: Dictionary = _ranked[i][1]
		var centre := pos[i] + dirs[i] * (float(e["drop"]) / maxf(-dirs[i].y, 0.3))''', '''		var e: Dictionary = _ranked[i][1]
		var centre := pool_centre(pos[i], dirs[i], float(e["drop"]))''')
rep(p, '''## Height of a lamp above the road beside it: the nearest row of its chunk''', '''## Centre of a lamp's pool on the ground: where its axis meets the ground for a lamp that looks down; for a wall lamp
## (it looks sideways) the ground just in front of the wall below it – its axis would meet the ground far away.
static func pool_centre(lamp_pos: Vector3, lamp_dir: Vector3, drop: float) -> Vector3:
	if -lamp_dir.y >= 0.5:
		return lamp_pos + lamp_dir * (drop / -lamp_dir.y)
	var flat := Vector3(lamp_dir.x, 0.0, lamp_dir.z)
	if flat.length_squared() > 1.0e-6:
		flat = flat.normalized()
	return lamp_pos + flat * minf(drop, WALL_POOL_M) - Vector3(0.0, drop, 0.0)


## Height of a lamp above the road beside it: the nearest row of its chunk''')
rep(p, '''const LAMP_DROP_M := 8.0            ## height of a lamp above the road when it cannot be measured
''', '''const LAMP_DROP_M := 8.0            ## height of a lamp above the road when it cannot be measured
const WALL_POOL_M := 1.5            ## a wall lamp's pool lies at most this far in front of the wall
''')
print('ok')
