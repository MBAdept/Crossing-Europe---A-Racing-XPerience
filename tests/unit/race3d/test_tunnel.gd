extends TestCase
## builders/tunnel.gd (mode "Modern", package R5 – docs/renderer-modern-tunnel-bruecken.md) on real tunnels, built
## headless without a renderer: the tube with walkways, SOS niches every 150 m in the right wall, exit doors and jet
## fans every 300 m, the cap at peek_m, the portal with frame, headwall and hill, the frame of the exit; nothing of
## it over the lanes below 5.2 m (the fans hang higher) and nothing over the paved road below a truck's height; the
## hill closes the terrain at the portal and ends before the exit; the cap is for a camera outside only; the zone
## for the environment follows the rig's own law and goes through set_zone only when the rig has it.

const Fair := preload("res://tests/race3d/fairness.gd")
const Tunnel := preload("res://scripts/race3d/builders/tunnel.gd")
const TRUCK_H := 4.0               ## nothing of the tube over the paved road below this (Arcade's tallest vehicle < 4 m)

var _net: Dictionary = {}
var _cfg: Dictionary = {}
var _tracks: Dictionary = {}


## The environment rig as far as the tunnel builder sees it (R4's set_zone, duck-typed).
class FakeEnv extends RefCounted:
	var calls: Array = []

	func set_zone(kind: String, amount: float) -> void:
		calls.append([kind, amount])


## Stands for the renderer: the facade members the tunnel builder reads.
class FakeRenderer extends Node:
	var track: Track
	var cfg: Dictionary = {}
	var env: Object
	var prep: Dictionary = {}


func _cleanup() -> void:
	ModernMaterials.drop_shared()


func _config() -> Dictionary:
	if _cfg.is_empty():
		_cfg = cfg()
	return _cfg


func _track(stage_id: String, from_id: String) -> Track:
	var key := stage_id + "|" + from_id
	if _tracks.has(key):
		return _tracks[key]
	if _net.is_empty():
		_net = Fair.load_network()
	for dir: Dictionary in Fair.directions(_net, [stage_id]):
		if str(dir["from"]) == from_id:
			var plan := StagePlan.build(dir["stage"], from_id, _net["cities"], _net["countries"], _config(), _net["city_db"])
			var t := Track.new()
			t.setup(plan, _config(), _net["scenery"])
			_tracks[key] = t
			return t
	return null


func _tunnel(t: Track, tunnel_name: String) -> Dictionary:
	for tu: Dictionary in t.plan.tunnels:
		if str(tu["name"]) == tunnel_name:
			return tu
	return {}


static func _portal_z(t: Track, tu: Dictionary) -> float:
	return float(ceili(t.km_to_z(float(tu["start_km"])) / t.seg_len - 1.0e-6)) * t.seg_len


static func _exit_z(t: Track, tu: Dictionary) -> float:
	return float(ceili(t.km_to_z(float(tu["end_km"])) / t.seg_len - 1.0e-6)) * t.seg_len


## Builds the chunks from the one before the portal on (at most max_chunks): [[ctx, part], …].
func _build(t: Track, tu: Dictionary, max_chunks: int = 40) -> Array:
	var b: Object = Tunnel.new()
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(_config(), "road.curve_radius_at_1_m", 120.0)))
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(_config(), "graphics.modern.terrain", {}), _net["scenery"])
	p.set_clear_reach(1842.0)
	var c0 := maxi(int(floor(_portal_z(t, tu) / t.seg_len / 32.0)) - 1, 0)
	var c1 := mini(int(floor(_exit_z(t, tu) / t.seg_len / 32.0)) + 1, c0 + max_chunks - 1)
	var out: Array = []
	for ci in range(c0, c1 + 1):
		p.ensure(mini((ci + 1) * 32 + 700, t.segment_count - 1))
		var ctx := ChunkContext.new()
		ctx.cfg = _config()
		ctx.scenery_db = _net["scenery"]
		ctx.levels = {"shadow_casters": 2}
		ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
		out.append([ctx, b.call("build", ctx, b.call("collect", ctx))])
	return out


static func _sum(built: Array, key: String) -> int:
	var n := 0
	for e: Array in built:
		n += int((e[1] as Dictionary).get(key, 0))
	return n


## Road coordinates (z, x, h) of a chunk-local point: the boundary of the path whose cross-section holds it (also
## beyond the chunk: the hill reaches 100 m behind its portal) – lateral along its right vector, height above it.
static func _road_coords(ctx: ChunkContext, p: Vector3) -> Vector3:
	var w := p + ctx.origin
	var path := ctx.path
	var best := ctx.seg_a
	var bd := INF
	for k in range(maxi(path.first, ctx.seg_a - 40), mini(path.last(), ctx.seg_b + 40) + 1):
		var d := (w - path.point(k)).dot(RoadPath3D.fwd_of(path.heading(k)))
		if absf(d) < bd:
			bd = absf(d)
			best = k
	var rel := w - path.point(best)
	return Vector3(float(best) * ctx.seg_len + rel.dot(RoadPath3D.fwd_of(path.heading(best))), rel.dot(RoadPath3D.right_of(path.heading(best))), rel.y)


## [vertex, kind] of a part's mesh arrays.
static func _verts(arrays: Array) -> Array:
	var out: Array = []
	if arrays.is_empty():
		return out
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for k in v.size():
		out.append([v[k], uv2[k].x])
	return out


func test_tube_niches_doors_fans_cap_portal_exit() -> void:
	var t := _track("hamburg_hannover", "hamburg")
	var tu := _tunnel(t, "Elbtunnel")
	assert_false(tu.is_empty(), "Elbtunnel in den Daten")
	var built := _build(t, tu)
	var len_m := _exit_z(t, tu) - _portal_z(t, tu)
	var segs := _sum(built, "segments")
	assert_near(float(segs) * t.seg_len, len_m, 0.01, "jedes Tunnelsegment hat seine Röhre (%d)" % segs)
	assert_eq(_sum(built, "portals"), 1, "ein Portal")
	assert_eq(_sum(built, "caps"), 1, "eine Kappe bei peek_m")
	assert_eq(_sum(built, "exits"), 1, "ein Rahmen der Ausfahrt")
	assert_near(float(_sum(built, "niches")), len_m / Tunnel.NICHE_EVERY, 1.01, "SOS-Nischen alle 150 m (%d)" % _sum(built, "niches"))
	assert_near(float(_sum(built, "doors")), len_m / Tunnel.DOOR_EVERY, 1.01, "Notausgänge alle 300 m (%d)" % _sum(built, "doors"))
	assert_near(float(_sum(built, "fans")), len_m / Tunnel.FAN_EVERY, 1.01, "Strahlventilatoren alle 300 m (%d)" % _sum(built, "fans"))
	assert_true(_sum(built, "portal_triangles") > 150, "Portal mit Rahmen, Stirnwand und Hügel (%d Dreiecke)" % _sum(built, "portal_triangles"))
	var lamps := 0
	for e: Array in built:
		lamps += ((e[1] as Dictionary).get("lamps", []) as Array).size()
	assert_true(lamps >= int(len_m / 12.0) * 2, "Leuchten auf beiden Vouten alle 12 m (%d)" % lamps)
	# the niches stand in the right wall, the doors in the left one
	var niche_x := 0.0
	var door_x := 0.0
	for e: Array in built:
		var ctx: ChunkContext = e[0]
		for vt: Array in _verts((e[1] as Dictionary).get("tube", [])):
			if absf(float(vt[1]) - Tunnel.K_NICHE) < 0.01:
				niche_x = maxf(niche_x, _road_coords(ctx, vt[0]).y)
			elif absf(float(vt[1]) - Tunnel.K_DOOR) < 0.01:
				door_x = minf(door_x, _road_coords(ctx, vt[0]).y)
	assert_true(niche_x > 5.0, "SOS-Nischen rechts (%.1f m)" % niche_x)
	assert_true(door_x < -5.0, "Notausgänge links (%.1f m)" % door_x)


func test_nothing_of_the_tube_over_the_road() -> void:
	var t := _track("hamburg_hannover", "hamburg")
	var built := _build(t, _tunnel(t, "Elbtunnel"), 10)
	var bad := 0
	var example := ""
	var fan_low := INF
	var walk := 0
	for e: Array in built:
		var ctx: ChunkContext = e[0]
		for vt: Array in _verts((e[1] as Dictionary).get("tube", [])):
			var kind := float(vt[1])
			if absf(kind - Tunnel.K_CAP) < 0.01:
				continue          # the cap: only drawn for a camera outside the tunnel, 45 m in
			var rc := _road_coords(ctx, vt[0])
			var row := clampi(int(round(ctx.row_of(rc.x))), 0, ctx.row_count() - 1)
			var edge := ctx.shoulder_edge(row, 1 if rc.y > 0.0 else -1)
			var lanes := edge - ctx.shoulder_w
			if absf(kind - Tunnel.K_WALK) < 0.01:
				walk += 1
			if absf(rc.y) < lanes:
				if absf(kind - Tunnel.K_METAL) < 0.01:
					fan_low = minf(fan_low, rc.z)
				if rc.z > 0.05 and rc.z < Tunnel.FAN_MIN_BOTTOM:
					bad += 1
					example = "über den Spuren: Art %.0f, x %.2f, h %.2f" % [kind, rc.y, rc.z]
			elif absf(rc.y) < edge - Tunnel.WALK_W - 0.02 and rc.z > 0.05 and rc.z < TRUCK_H:
				bad += 1
				example = "über dem Bankett: Art %.0f, x %.2f, h %.2f, Kante %.2f" % [kind, rc.y, rc.z, edge]
	assert_eq(bad, 0, "nichts der Röhre über der Fahrbahn (%s)" % example)
	assert_true(fan_low < INF, "Lüfter über den Spuren gefunden")
	assert_true(fan_low >= Tunnel.FAN_MIN_BOTTOM - 0.01, "Unterkante der Lüfter mindestens 5,2 m hoch (%.2f m)" % fan_low)
	assert_true(walk > 100, "Gehwege (%d Eckpunkte)" % walk)


func test_hill_closes_the_terrain_at_the_portal() -> void:
	var t := _track("bern_mailand", "bern")
	var tu := _tunnel(t, "Gotthard-Strassentunnel")
	assert_false(tu.is_empty(), "Gotthard in den Daten")
	var built := _build(t, tu, 3)
	var z_portal := _portal_z(t, tu)
	var widest := 0.0
	var front := 0
	var front_ok := 0
	for e: Array in built:
		var ctx: ChunkContext = e[0]
		for vt: Array in _verts((e[1] as Dictionary).get("portal", [])):
			var rc := _road_coords(ctx, vt[0])
			widest = maxf(widest, absf(rc.y))
			# the hill's front edge beyond the wing walls lies on the ground (a little into it: no gap to the ribbon)
			var row := clampi(int(round(ctx.row_of(z_portal))), 0, ctx.row_count() - 1)
			var beyond := ctx.shoulder_edge(row, 1 if rc.y > 0.0 else -1) + Tunnel.FRAME_W + Tunnel.PORTAL_SIDE + Tunnel.WING_M + 1.0
			if absf(rc.x - (z_portal + 0.03)) < 0.05 and absf(rc.y) > beyond:
				front += 1
				if rc.z <= ctx.ground(z_portal, rc.y) + 0.01:
					front_ok += 1
	assert_true(widest >= Tunnel.HILL_SPAN, "der Hügel reicht %.0f m zur Seite" % widest)
	assert_true(front >= 10, "Vorderkante des Hügels neben den Flügelmauern gefunden (%d)" % front)
	assert_eq(front_ok, front, "die Vorderkante liegt auf dem Boden des Geländes")


## The hill never cuts through the tube (seen from inside, its slope behind the ridge showed as a green strip across
## the Somport tunnel): no point of a portal triangle – sampled over its surface – lies in the tube behind the portal.
func test_hill_never_cuts_through_the_tube() -> void:
	for want: Array in [["saragossa_pau", "saragossa", "Somport-Tunnel"], ["bern_mailand", "bern", "Gotthard-Strassentunnel"],
			["prag_nuernberg", "prag", "Tunel Valík"]]:
		var t := _track(want[0], want[1])
		var tu := _tunnel(t, want[2])
		var built := _build(t, tu, 3)
		var z_portal := _portal_z(t, tu)
		var z_exit := _exit_z(t, tu)
		var inside := 0
		var example := ""
		for e: Array in built:
			var ctx: ChunkContext = e[0]
			var arr: Array = (e[1] as Dictionary).get("portal", [])
			if arr.is_empty():
				continue
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for k in range(0, idx.size(), 3):
				var a := v[idx[k]]
				var b := v[idx[k + 1]]
				var c := v[idx[k + 2]]
				for i in 9:
					for j in 9 - i:
						var p := a + (b - a) * (float(i) + 0.33) / 9.0 + (c - a) * (float(j) + 0.33) / 9.0
						var rc := _road_coords(ctx, p)
						if rc.x < z_portal + 1.0 or rc.x > z_exit - 1.0:
							continue
						var row := clampi(int(round(ctx.row_of(rc.x))), 0, ctx.row_count() - 1)
						if absf(rc.y) < ctx.shoulder_edge(row, 1 if rc.y > 0.0 else -1) - 0.2 and rc.z > 0.1 and rc.z < 6.0:
							inside += 1
							example = "z+%.1f x %.1f h %.1f" % [rc.x - z_portal, rc.y, rc.z]
		assert_eq(inside, 0, "%s: nichts vom Hügel in der Röhre (%s)" % [want[2], example])


func test_short_tunnel_low_hill_no_cap() -> void:
	var t := _track("prag_nuernberg", "prag")
	var tu := _tunnel(t, "Tunel Valík")
	assert_false(tu.is_empty(), "Tunel Valík in den Daten")
	var built := _build(t, tu, 5)
	var z_exit := _exit_z(t, tu)
	var len_m := z_exit - _portal_z(t, tu)
	assert_true(len_m < 45.0, "kürzer als peek_m (%.0f m sichtbar)" % len_m)
	assert_eq(_sum(built, "portals"), 1, "ein Portal")
	assert_eq(_sum(built, "caps"), 0, "keine Kappe: die Ausfahrt ist durch die Röhre zu sehen")
	assert_eq(_sum(built, "exits"), 1, "Rahmen der Ausfahrt")
	var far := -INF
	var top := -INF
	for e: Array in built:
		var ctx: ChunkContext = e[0]
		for vt: Array in _verts((e[1] as Dictionary).get("portal", [])):
			var rc := _road_coords(ctx, vt[0])
			far = maxf(far, rc.x)
			top = maxf(top, rc.z)
	assert_true(far <= z_exit + 0.05, "der Hügel endet spätestens an der Ausfahrt (%.1f m davor)" % (z_exit - far))
	assert_true(top < Tunnel.HILL_PEAK * 0.7, "niedriger Hügel über einem kurzen Tunnel, Bäume eingeschlossen (%.1f m)" % top)


func test_cap_only_for_a_camera_outside() -> void:
	var t := _track("hamburg_hannover", "hamburg")
	var tu := _tunnel(t, "Elbtunnel")
	var r := FakeRenderer.new()
	r.track = t
	r.cfg = _config()
	var b: Object = Tunnel.new()
	b.call("setup", r)
	var pal := {"ambient": Color.WHITE, "lights": 0.0, "fog": Color.GRAY}
	var m: ShaderMaterial = b.call("tube_material")
	b.call("update", {"camera_z": _portal_z(t, tu) - 60.0, "palette": pal, "visibility_m": 900.0}, 0.016)
	assert_true(float(m.get_shader_parameter("cam_tunnel_z")) < -1.0e8, "draußen: Kappe aller Tunnel zu")
	b.call("update", {"camera_z": _portal_z(t, tu) + 200.0, "palette": pal, "visibility_m": 360.0, "camera_in_tunnel": true}, 0.016)
	assert_near(float(m.get_shader_parameter("cam_tunnel_z")), _portal_z(t, tu), 0.01, "drin: die Röhre des eigenen Tunnels ohne Kappe")
	r.free()


func test_zone_follows_the_rigs_law() -> void:
	var t := _track("hamburg_hannover", "hamburg")
	var tu := _tunnel(t, "Elbtunnel")
	var z0 := t.km_to_z(float(tu["start_km"]))
	var z1 := t.km_to_z(float(tu["end_km"]))
	assert_near(Tunnel.zone_amount(t, z0 - 13.0), 0.0, 1.0e-6, "13 m vor dem Portal: draußen")
	assert_near(Tunnel.zone_amount(t, z0 + 15.0), 1.0, 1.0e-6, "15 m drin: im Tunnel")
	assert_near(Tunnel.zone_amount(t, z1 + 13.0), 0.0, 1.0e-6, "13 m nach der Ausfahrt: draußen")
	var rig: GDScript = load("res://scripts/race3d/environment_rig.gd")
	var names: Array = []
	if rig != null:
		for d: Dictionary in rig.get_script_method_list():
			names.append(str(d["name"]))
	if not names.has("tunnel_blend"):
		return      # the rig of R4 may have replaced its own law by set_zone
	for k in 60:
		var z := z0 - 30.0 + float(k) * 1.5
		assert_near(Tunnel.zone_amount(t, z), float(rig.call("tunnel_blend", t, z)), 1.0e-5, "dasselbe Gesetz wie EnvironmentRig.tunnel_blend bei %.1f m" % (z - z0))


func test_set_zone_only_when_the_rig_has_it() -> void:
	var t := _track("hamburg_hannover", "hamburg")
	var tu := _tunnel(t, "Elbtunnel")
	var z0 := t.km_to_z(float(tu["start_km"]))
	var r := FakeRenderer.new()
	r.track = t
	r.cfg = _config()
	var b: Object = Tunnel.new()
	b.call("setup", r)
	var pal := {"ambient": Color.WHITE, "lights": 0.0, "fog": Color.GRAY}
	# without set_zone: the state is kept, nothing is called
	b.call("update", {"camera_z": z0 + 100.0, "palette": pal, "visibility_m": 360.0, "camera_in_tunnel": true}, 0.016)
	var st: Dictionary = b.get("tunnel_state")
	assert_near(float(st.get("amount", -1.0)), 1.0, 1.0e-6, "tunnel_state: drin")
	assert_true(bool(st.get("inside", false)), "tunnel_state: inside")
	assert_near(float(st.get("exit_m", 0.0)), t.km_to_z(float(tu["end_km"])) - z0 - 100.0, 0.01, "Weg bis zur Ausfahrt")
	# with set_zone: called with the amount, once per change
	var env := FakeEnv.new()
	r.env = env
	b.call("update", {"camera_z": z0 - 5.0, "palette": pal, "visibility_m": 900.0}, 0.016)
	b.call("update", {"camera_z": z0 - 5.0, "palette": pal, "visibility_m": 900.0}, 0.016)
	assert_eq(env.calls.size(), 1, "einmal je Änderung gerufen")
	if not env.calls.is_empty():
		assert_eq(str(env.calls[0][0]), "tunnel", "Art tunnel")
		assert_near(float(env.calls[0][1]), Tunnel.zone_amount(t, z0 - 4.0), 1.0e-6, "Anteil nach dem Gesetz")
	b.call("update", {"camera_z": z0 + 3.0, "palette": pal, "visibility_m": 900.0}, 0.016)
	assert_eq(env.calls.size(), 2, "neuer Anteil: neuer Aufruf")
	r.free()
