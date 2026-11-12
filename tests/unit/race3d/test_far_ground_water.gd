extends TestCase
## layers/far_ground.gd with water in the loaded window (mode "Modern", FIX-WASSER): the far-ground plane lies below
## the lowest water surface the terrain draws in the window. Under the Köhlbrandbrücke (Kiel – Hamburg, the Elbe 9 m
## below the deck) the plane at "lowest road - far_ground_drop_m (4 m)" covered the river, and the two ferries stood
## on a meadow. Away from deep water the plane lies where it always did; when a bridge enters the window the plane
## glides down with FOLLOW_SLOPE (no jump); it still lies below every loaded road (F7).
## The layer runs its own update() with a stand-in for the renderer facade (A-7: cfg, track, path, camera,
## scenery_db, world); the water rows are counted here from the track itself (TrackSegment.water / water_level –
## exactly what TerrainProfile lays the rings of a water row on).

const Fair := preload("res://tests/race3d/fairness.gd")
const FarGround := preload("res://scripts/race3d/layers/far_ground.gd")
const VIS := 900.0
const MARGIN := 0.25               ## the plane must lie at least this far below the water (the layer keeps 0.3 m)


## The members of the renderer facade the layer reads.
class FakeRenderer extends Node:
	var cfg: Dictionary = {}
	var track: Track
	var path: RoadPath3D
	var camera: Camera3D
	var scenery_db: Dictionary = {}
	var world: Node3D


var _cfg: Dictionary = {}
var _net: Dictionary = {}


func _config() -> Dictionary:
	if _cfg.is_empty():
		_cfg = cfg()
	return _cfg


func _track(stage_id: String, from_id: String) -> Track:
	if _net.is_empty():
		_net = Fair.load_network()
	for dir: Dictionary in Fair.directions(_net, [stage_id]):
		if str(dir["from"]) == from_id:
			var plan := StagePlan.build(dir["stage"], from_id, _net["cities"], _net["countries"], _config(), _net["city_db"])
			var t := Track.new()
			t.setup(plan, _config(), _net["scenery"])
			return t
	return null


func _bridge(t: Track, bridge_name: String) -> Dictionary:
	for br: Dictionary in t.bridges:
		if str(br["name"]) == bridge_name:
			return br
	return {}


## A layer set up on a stand-in renderer for track t (the path integrated up to row last_row).
func _layer(t: Track, last_row: int) -> Array:
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(_config(), "road.curve_radius_at_1_m", 120.0)))
	p.ensure(mini(last_row, t.segment_count - 1))
	var r := FakeRenderer.new()
	r.cfg = _config()
	r.track = t
	r.path = p
	r.camera = Camera3D.new()
	r.scenery_db = _net.get("scenery", {})
	r.world = Node3D.new()
	var fg: Node3D = FarGround.new()
	fg.setup(r)
	return [fg, r, p]


func _free(parts: Array) -> void:
	var fg: Node3D = parts[0]
	var r: FakeRenderer = parts[1]
	fg.free()
	r.world.free()      # holds the plane's sectors
	r.camera.free()
	r.free()


## One frame of the layer with the camera at road position z.
func _frame(parts: Array, z: float) -> float:
	var fg: Node3D = parts[0]
	var p: RoadPath3D = parts[2]
	var r: FakeRenderer = parts[1]
	r.camera.position = p.world(z, 0.0, 3.4)
	fg.update({"camera_z": z, "visibility_m": VIS}, 1.0 / 60.0)
	return float(fg.get("far_y"))


## Rows of the window the layer loads around z (keep_behind_m and a chunk behind, visibility + two chunks ahead).
func _rows(t: Track, p: RoadPath3D, z: float) -> Vector2i:
	var m: Dictionary = ConfigLoader.lookup(_config(), "graphics.modern", {})
	var chunk := float(int(m.get("chunk_segments", 32))) * t.seg_len
	var ahead := minf(float(m.get("load_path_m", 1500.0)), VIS + 2.0 * chunk)
	var behind := float(m.get("keep_behind_m", 150.0)) + chunk
	return Vector2i(maxi(p.first, int(floor((z - behind) / t.seg_len))), mini(p.last(), int(ceil((z + ahead) / t.seg_len))))


## Lowest water surface the terrain draws in the window around z (INF without water) – counted row by row.
func _water(t: Track, p: RoadPath3D, z: float) -> float:
	var w := _rows(t, p, z)
	var lo := INF
	for k in range(w.x, w.y + 1):
		var s := t.get_segment(k)
		if s.index == k and s.water:
			lo = minf(lo, p.height(k) + minf(s.water_level, 0.0))
	return lo


func _lowest_road(t: Track, p: RoadPath3D, z: float) -> float:
	var w := _rows(t, p, z)
	var lo := INF
	for k in range(w.x, w.y + 1):
		lo = minf(lo, p.height(k))
	return lo


func _drop() -> float:
	return float(ConfigLoader.lookup(_config(), "graphics.modern.terrain.far_ground_drop_m", 4.0))


func test_plane_lies_below_the_elbe_under_the_koehlbrand_bridge() -> void:
	var t := _track("kiel_hamburg", "kiel")
	assert_true(t != null, "Kiel – Hamburg ab Kiel")
	if t == null:
		return
	var br := _bridge(t, "Köhlbrandbrücke")
	assert_false(br.is_empty(), "Köhlbrandbrücke in den Daten")
	if br.is_empty():
		return
	var z0 := float(br["z0"])
	var z1 := float(br["z1"])
	assert_true(float(br["depth"]) > _drop() + 1.0, "das Wasser liegt tiefer als der alte Abstand der Scheibe (%.1f m)" % float(br["depth"]))
	var parts := _layer(t, int((z1 + 1600.0) / t.seg_len))
	var p: RoadPath3D = parts[2]
	# the brief's stretch km 77.5 – 80 (approach ramp, deck, ferries at km 78.95 / 79.14), each one a camera jump
	for z: float in [z0 - 500.0, z0 - 250.0, z0, z0 + 95.0, z0 + 114.0, (z0 + z1) * 0.5, z1 - 30.0]:
		var far_y := _frame(parts, z)
		var water := _water(t, p, z)
		assert_true(water < INF, "km %.2f: Wasser im Fenster" % t.z_to_km(z))
		assert_true(far_y <= water - MARGIN,
			"km %.2f: Fernboden %.2f m, tiefstes Wasser %.2f m – die Scheibe muss darunter liegen (liegt %.2f m darüber)" % [
			t.z_to_km(z), far_y, water, far_y - water])
		assert_true(far_y <= _lowest_road(t, p, z) - _drop() + 0.6, "km %.2f: und unter jeder geladenen Straße (F7)" % t.z_to_km(z))
	# the ferries (h = -depth) stand on the water the terrain draws, above the plane
	var ferries := 0
	var far_y := _frame(parts, z0 + 100.0)
	for k in range(int(z0 / t.seg_len), int(z1 / t.seg_len)):
		var s := t.get_segment(k)
		for it: Dictionary in s.sprites:
			if str(it.get("set", "")) != "props/ferry_ship":
				continue
			ferries += 1
			var fz := float(it.get("z", s.z))
			var base := p.height_at(fz) + float(it.get("h", 0.0))
			assert_near(float(it.get("h", 0.0)), minf(s.water_level, 0.0), 0.01, "Fähre bei km %.2f liegt auf der Wasserhöhe" % t.z_to_km(fz))
			assert_true(base >= far_y + MARGIN, "Fähre bei km %.2f: Rumpf %.2f m über der Scheibe (%.2f m)" % [t.z_to_km(fz), base - far_y, far_y])
	assert_eq(ferries, 2, "zwei Fähren unter der Köhlbrandbrücke")
	_free(parts)


func test_plane_unchanged_away_from_deep_water() -> void:
	var t := _track("kiel_hamburg", "kiel")
	if t == null:
		fail("Kiel – Hamburg fehlt")
		return
	var elb := _bridge(t, "Elbbrücken")
	assert_false(elb.is_empty(), "Elbbrücken in den Daten")
	var parts := _layer(t, t.segment_count - 1)
	var fg: Node3D = parts[0]
	var p: RoadPath3D = parts[2]
	var mid := (float(elb["z0"]) + float(elb["z1"])) * 0.5
	# km 2, 30, 60, before the Köhlbrand bridge enters the window, the Elbbrücken (water 3.6 m under the deck: above
	# the old plane) and the finish – far from deep water the plane is the old rule exactly
	for z: float in [200.0, 3000.0, 6000.0, 6500.0, mid, 9300.0]:
		var far_y := _frame(parts, z)
		var old: float = fg.call("lowest_road", p, z, VIS) - _drop()
		assert_near(far_y, old, 1.0e-5, "km %.2f: Fernboden wie bisher (tiefste Straße - %.1f m)" % [t.z_to_km(z), _drop()])
		var water := _water(t, p, z)
		if water < INF:
			assert_true(far_y <= water - MARGIN, "km %.2f: Wasser der Elbbrücken über der Scheibe (%.2f / %.2f)" % [t.z_to_km(z), water, far_y])
	_free(parts)


func test_plane_glides_down_when_the_bridge_enters_the_window() -> void:
	var t := _track("kiel_hamburg", "kiel")
	if t == null:
		fail("Kiel – Hamburg fehlt")
		return
	var br := _bridge(t, "Köhlbrandbrücke")
	var z0 := float(br["z0"])
	var parts := _layer(t, int((float(br["z1"]) + 1600.0) / t.seg_len))
	var fg: Node3D = parts[0]
	var p: RoadPath3D = parts[2]
	var slope := float(FarGround.FOLLOW_SLOPE)
	var step := 1.5                     # 90 km/h at 60 frames per second
	var z := z0 - 1400.0
	var prev := _frame(parts, z)
	var entered := INF
	var steepest := 0.0
	var off_rule := 0.0                 # without water in the window: largest difference to the old rule
	var above := -INF                   # bridge inside the sight: highest plane over the water
	var above_z := 0.0
	while z < z0 - 700.0:
		z += step
		var y := _frame(parts, z)
		steepest = maxf(steepest, absf(y - prev))
		prev = y
		var water := _water(t, p, z)
		if water == INF:
			off_rule = maxf(off_rule, absf(y - (float(fg.call("lowest_road", p, z, VIS)) - _drop())))
		elif entered == INF:
			entered = z
		# once the bridge is inside the sight (+ a margin of 50 m) the plane lies below its water
		if water < INF and z >= z0 - VIS - 50.0 and y - water > above:
			above = y - water
			above_z = z
	assert_near(off_rule, 0.0, 1.0e-5, "ohne Wasser im Fenster liegt die Scheibe wie bisher")
	assert_true(above <= -MARGIN, "Brücke in Sichtweite: die Scheibe muss mindestens %.2f m unter dem Wasser liegen, gemessen %.2f m darüber (km %.3f, %.0f m vor der Brücke)" % [
		MARGIN, above, t.z_to_km(above_z), z0 - above_z])
	assert_true(entered < INF, "die Brücke kommt ins Fenster")
	assert_true(entered <= z0 - VIS - 100.0, "… früher als in Sichtweite (%.0f m vor der Brücke)" % (z0 - entered))
	assert_true(steepest <= slope * step + 1.0e-4, "kein Sprung: höchstens %.2f m je Bild, gemessen %.3f m" % [slope * step, steepest])
	_free(parts)


func test_deep_bridges_of_other_stages_stay_visible() -> void:
	# Kiel canal (Holtenauer Hochbrücke, 16 m), the Rhine in Köln (Severinsbrücke, cable-stayed: 5 m) and the Danube
	# in Budapest (Elisabethbrücke, 5 m) – with the camera on the deck the plane lies below the water
	for case: Array in [["rostock_kiel", "rostock", "Holtenauer Hochbrücke"], ["frankfurt_koeln", "frankfurt", "Severinsbrücke"],
			["budapest_wien", "wien", "Elisabethbrücke"]]:
		var t := _track(str(case[0]), str(case[1]))
		if t == null:
			fail("%s ab %s fehlt" % [case[0], case[1]])
			continue
		var br := _bridge(t, str(case[2]))
		if br.is_empty():
			fail("%s fehlt" % case[2])
			continue
		var parts := _layer(t, int((float(br["z1"]) + 1600.0) / t.seg_len))
		var p: RoadPath3D = parts[2]
		var z := (float(br["z0"]) + float(br["z1"])) * 0.5
		var far_y := _frame(parts, z)
		var water := _water(t, p, z)
		assert_true(far_y <= water - MARGIN, "%s (%.1f m tief): Fernboden %.2f m über dem Wasser" % [case[2], float(br["depth"]), far_y - water])
		assert_true(far_y <= _lowest_road(t, p, z) - _drop() + 0.6, "%s: unter jeder geladenen Straße" % case[2])
		_free(parts)
