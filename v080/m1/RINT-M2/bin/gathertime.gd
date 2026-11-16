extends SceneTree
## RINT-M2 probe (note 8): where the main-thread gather of a canopy job spends its time (copy of canopy_job()'s steps).

const Fair := preload("res://tests/race3d/fairness.gd")
const StationB := preload("res://scripts/race3d/builders/station.gd")
const N := 32


func _initialize() -> void:
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var dirs := Fair.directions(net, ["dev_testetappe", "kiel_hamburg"])
	var acc := {"signs_plan": 0.0, "curve": 0.0, "lanes": 0.0, "col_places": 0.0, "mast_places": 0.0}
	var mx := acc.duplicate()
	var n := 0
	var calls := 0
	for dir: Dictionary in dirs:
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var tr := Track.new()
		tr.setup(plan, cfg, net["scenery"])
		var r1c := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
		var full := RoadPath3D.new()
		full.setup(tr, 0, r1c)
		var tpf := TerrainProfile.new()
		tpf.setup(full, tr, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), tr.scenery_db)
		for zn: Dictionary in tr.zones:
			if str(zn["kind"]) != "fuel_canopy":
				continue
			var r0 := floorf(float(zn["z0"]) / tr.seg_len) * tr.seg_len
			var r1 := ceilf(float(zn["z1"]) / tr.seg_len) * tr.seg_len
			full.ensure(tr.segment_index_at(r1 + 1300.0))
			var t: Dictionary = {}
			var a := Time.get_ticks_usec()
			var sb: Dictionary = StationB.signs_behind(tr, r0, r1)
			var cplan: Array = StationB.column_plan(r0, r1, sb["signs"])
			var b := Time.get_ticks_usec()
			t["signs_plan"] = b - a
			var kb: int = tr.segment_index_at(r1 + StationB.LOS_FAR) + 3
			var ka: int = maxi(0, tr.segment_index_at(r0 - StationB.LOS_FAR - 3.0 * StationB.LOS_STEP))
			var curve := PackedFloat32Array()
			for k in range(ka, kb + 1):
				var s := tr.get_segment(k)
				if s.index != k:
					break
				curve.append(s.curve)
			var c := Time.get_ticks_usec()
			t["curve"] = c - b
			var zc := floorf((r0 - 1.0 - StationB.LOS_FAR - StationB.LOS_STEP) / StationB.LOS_STEP) * StationB.LOS_STEP
			while zc <= r1 + StationB.LOS_STEP:
				var half := tr.lanes_at(zc) * tr.lane_w * 0.5
				var nl := int(round(tr.lanes_at(zc)))
				var lx := PackedFloat32Array()
				for li in nl:
					lx.append(-half + tr.lane_w * (float(li) + 0.5))
				if tr.fuel_lane_factor(zc) > 0.5:
					lx.append(half + tr.lane_w * 0.5)
				zc += StationB.LOS_STEP
			var d := Time.get_ticks_usec()
			t["lanes"] = d - c
			var far: float = StationB.outer_place(sb["signs"], r0 - 1.0, r1 + StationB.SIGN_SCAN_M)
			var tc := 0
			var tm := 0
			for col: Array in cplan:
				var z := float(col[0])
				var e: float = StationB.paved_edge_at(tr, z)
				var left: float = tr.lanes_at(z) * tr.lane_w * 0.5 + tr.shoulder_w + StationB.MAST_LEFT_GAP
				var t0 := Time.get_ticks_usec()
				for x: float in [e + far, e + float(col[2])]:
					StationB.bend_corridor_at(tr, tpf, z, x)
					calls += 1
				var t1 := Time.get_ticks_usec()
				var places: Array[float] = []
				places.append_array(StationB.CanopyJob.mast_right(z, e, sb["signs"], r0, r1))
				places.append_array(StationB.CanopyJob.mast_left(left))
				for x: float in places:
					StationB.bend_corridor_at(tr, tpf, z, x)
					calls += 1
				var t2 := Time.get_ticks_usec()
				tc += t1 - t0
				tm += t2 - t1
			t["col_places"] = tc
			t["mast_places"] = tm
			n += 1
			var line := "GATHER %s km %.2f plan %d:" % [str(dir["name"]), tr.z_to_km(r0), cplan.size()]
			for k: String in t:
				acc[k] = float(acc[k]) + float(t[k]) / 1000.0
				mx[k] = maxf(float(mx[k]), float(t[k]) / 1000.0)
				line += " %s %.3f" % [k, float(t[k]) / 1000.0]
			print(line)
	var s := "GATHER-SUMMARY n=%d corridor calls %d:" % [n, calls]
	for k: String in acc:
		s += " %s avg %.3f max %.3f;" % [k, float(acc[k]) / maxf(n, 1), float(mx[k])]
	print(s)
	quit(0)
