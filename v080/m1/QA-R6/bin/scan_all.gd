extends SceneTree
## QA-R6 network scan: every R6 element of every stage direction (and DEV) built headless with the five builders and
## compared with what Arcade draws (the Track data). Prints one line per finding and a summary JSON.
##   godot --headless --path . -s <this> [-- --only=<stage or dir name>] [--city-sample=12]

const Fair := preload("res://tests/race3d/fairness.gd")
const StationB := preload("res://scripts/race3d/builders/station.gd")
const BorderB := preload("res://scripts/race3d/builders/border.gd")
const CityB := preload("res://scripts/race3d/builders/city.gd")
const GantryB := preload("res://scripts/race3d/builders/gantry.gd")
const RadarB := preload("res://scripts/race3d/builders/radar.gd")
const N := 32

var cfg: Dictionary
var stats := {"dirs": 0, "chunks": 0, "fuel_lanes": 0, "canopies": 0, "canopies_no_column": 0, "canopies_one_column": 0,
	"canopy_columns_out": 0, "island_mismatch": 0, "canopy_mismatch": 0, "front_mismatch": 0, "lettering_mismatch": 0,
	"pylon_mismatch": 0, "borders": 0, "border_mismatch": 0, "border_front_mismatch": 0, "border_lettering_mismatch": 0,
	"roofs_no_left": 0, "roofs_no_right": 0, "roofs_no_pillar": 0, "roof_pillars_hist": {}, "gantry_mismatch": 0,
	"gantry_lettering_mismatch": 0, "radars": 0, "radar_mismatch": 0, "city_chunks": 0, "city_light_mismatch": 0,
	"city_lights": 0, "fence_dropped": 0, "fence_drawn": 0, "build_ms_max": 0.0, "build_ms_max_where": ""}


func _initialize() -> void:
	var only: Array = []
	var city_sample := 12
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
		elif a.begins_with("--city-sample="):
			city_sample = int(a.substr(14))
	cfg = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var dirs := Fair.directions(net, only)
	if only.is_empty():
		dirs.append_array(Fair.directions(net, ["dev_testetappe"]))
	for dir: Dictionary in dirs:
		_scan(net, dir, city_sample)
	print("SCAN-SUMMARY ", JSON.stringify(stats))
	quit(0)


func _ctx(t: Track, p: RoadPath3D, tp: TerrainProfile, c: int) -> ChunkContext:
	p.ensure((c + 1) * N + 700)
	var ctx := ChunkContext.new()
	ctx.cfg = cfg
	ctx.scenery_db = t.scenery_db
	ctx.capture(c, c * N, c * N + N, p, tp, t)
	return ctx


func _scan(net: Dictionary, dir: Dictionary, city_sample: int) -> void:
	var name := str(dir["name"])
	var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
	var t := Track.new()
	t.setup(plan, cfg, net["scenery"])
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
	stats["dirs"] += 1
	var cl := float(N) * t.seg_len
	var chunks := {}
	var tags := {}
	for zn: Dictionary in t.zones:
		var k := str(zn["kind"])
		if k == "fuel" or k == "border":
			for c in range(int(floor((float(zn["z0"]) - 140.0) / cl)), int(floor((float(zn["z1"]) + 30.0) / cl)) + 1):
				if c >= 0:
					chunks[c] = true
					tags[c] = str(tags.get(c, "")) + k[0]
	for r: Dictionary in plan.radars:
		var rk := float(r["km"])
		var mid := (rk + float(r["end_km"])) * 0.5
		for k: float in [rk + 0.25, mid + 0.25]:
			var c := int(floor(t.km_to_z(k) / cl))
			chunks[c] = true
			tags[c] = str(tags.get(c, "")) + "r"
	chunks[0] = true
	var cf := int(floor(t.length_z / cl))
	for c in [cf - 1, cf, cf + 1]:
		chunks[c] = true
	# city chunks: a sample spread over the stage
	var city_chunks: Array = []
	var last := -1
	for i in t.segment_index_at(t.length_z) + 1:
		var s := t.get_segment(i)
		if s.city and int(i / N) != last:
			last = int(i / N)
			city_chunks.append(last)
	if not city_chunks.is_empty():
		var step := maxf(1.0, float(city_chunks.size()) / float(city_sample))
		var f := 0.0
		while int(f) < city_chunks.size():
			chunks[city_chunks[int(f)]] = true
			tags[city_chunks[int(f)]] = str(tags.get(city_chunks[int(f)], "")) + "c"
			f += step
	var sb: ChunkBuilder = StationB.new()
	var bb: ChunkBuilder = BorderB.new()
	var cb: ChunkBuilder = CityB.new()
	var gb: ChunkBuilder = GantryB.new()
	var rb: ChunkBuilder = RadarB.new()
	var keys := chunks.keys()
	keys.sort()
	var columns: Array = []
	var pillars: Array = []
	var gantries: Array = []
	var gletters: Array = []
	for c: int in keys:
		if c < 0 or c * N >= t.segment_count - 2:
			continue
		var ctx := _ctx(t, p, tp, c)
		stats["chunks"] += 1
		var want := {"islands": 0, "canopies": 0, "fronts": 0, "pylons": 0, "covers": 0, "cover_fronts": 0, "lights": 0, "gantries": 0, "cams": 0}
		for i in ctx.row_count() - 1:
			var sa: Dictionary = ctx.segs[i]
			var tun := bool(sa["tunnel"])
			for it: Dictionary in sa["sprites"]:
				if str(it.get("kind", "")) == "object" and str(it.get("obj", "")) == "fuel_pylon" and not tun:
					want["pylons"] += 1
				if str(it.get("kind", "")) == "object" and str(it.get("obj", "")) == "streetlight" and bool(sa["city"]) and not tun:
					want["lights"] += 1
				if str(it.get("kind", "")) == "sign" and int(it.get("side", 1)) == 0 and ["start", "finish"].has(str(it.get("sign", ""))):
					want["gantries"] += 1
				if RadarB.is_camera(it):
					want["cams"] += 1
			if tun:
				continue
			var fz := int(sa["fuel_zone"])
			if (fz & TrackSegment.FUEL_ISLAND) != 0:
				want["islands"] += 1
			if (fz & TrackSegment.FUEL_CANOPY) != 0:
				want["canopies"] += 1
			if (fz & TrackSegment.FUEL_CANOPY_FRONT) != 0 and (fz & TrackSegment.FUEL_CANOPY) != 0:
				want["fronts"] += 1
			if str(sa["cover"]) != "":
				want["covers"] += 1
				if bool(sa["cover_front"]):
					want["cover_fronts"] += 1
		var t0 := Time.get_ticks_usec()
		var sp: Dictionary = sb.debug(sb.build(ctx, sb.collect(ctx)))
		var bp_raw: Dictionary = bb.build(ctx, bb.collect(ctx))
		var bp: Dictionary = bb.debug(bp_raw)
		var cp: Dictionary = {}
		if str(tags.get(c, "")).contains("c") or want["lights"] > 0:
			cp = cb.debug(cb.build(ctx, cb.collect(ctx)))
		var gp: Dictionary = gb.debug(gb.build(ctx, gb.collect(ctx)))
		var rp: Dictionary = rb.debug(rb.build(ctx, rb.collect(ctx)))
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		if ms > float(stats["build_ms_max"]):
			stats["build_ms_max"] = ms
			stats["build_ms_max_where"] = "%s chunk %d (%s)" % [name, c, str(tags.get(c, ""))]
		var km := t.z_to_km(float(c) * cl)
		if int(sp["islands"]) != want["islands"]:
			stats["island_mismatch"] += 1
			print("FIND %s km %.2f station islands %d want %d" % [name, km, sp["islands"], want["islands"]])
		if int(sp["canopies"]) != want["canopies"]:
			stats["canopy_mismatch"] += 1
			print("FIND %s km %.2f station canopies %d want %d" % [name, km, sp["canopies"], want["canopies"]])
		if int(sp["fronts"]) != want["fronts"]:
			stats["front_mismatch"] += 1
			print("FIND %s km %.2f station fronts %d want %d" % [name, km, sp["fronts"], want["fronts"]])
		if int(sp["letterings"]) != int(sp["fronts"]):
			stats["lettering_mismatch"] += 1
			print("FIND %s km %.2f station letterings %d fronts %d" % [name, km, sp["letterings"], sp["fronts"]])
		if int(sp["pylons"]) != want["pylons"]:
			stats["pylon_mismatch"] += 1
			print("FIND %s km %.2f station pylons %d want %d" % [name, km, sp["pylons"], want["pylons"]])
		for q: Array in sp.get("column_at", []):
			columns.append(q)
		if int(bp.get("covers", 0)) != want["covers"]:
			stats["border_mismatch"] += 1
			print("FIND %s km %.2f border covers %d want %d" % [name, km, bp.get("covers", 0), want["covers"]])
		if int(bp.get("fronts", 0)) != want["cover_fronts"]:
			stats["border_front_mismatch"] += 1
			print("FIND %s km %.2f border fronts %d want %d" % [name, km, bp.get("fronts", 0), want["cover_fronts"]])
		if (bp.get("letterings", []) as Array).size() != int(bp.get("fronts", 0)):
			stats["border_lettering_mismatch"] += 1
			print("FIND %s km %.2f border letterings %s fronts %d" % [name, km, str(bp.get("letterings", [])), bp.get("fronts", 0)])
		for q: Array in bp.get("pillar_at", []):
			pillars.append(q)
		if not cp.is_empty() or want["lights"] > 0:
			stats["city_chunks"] += 1
			var got := (cp.get("lights", []) as Array).size()
			stats["city_lights"] += got
			stats["fence_dropped"] += int(cp.get("fence_dropped", 0))
			stats["fence_drawn"] += int(cp.get("fence_segments", 0))
			if got != want["lights"] or int(cp.get("lamps", 0)) < got:
				stats["city_light_mismatch"] += 1
				print("FIND %s km %.2f city lights %d lamps %d want %d" % [name, km, got, cp.get("lamps", 0), want["lights"]])
		gantries.append_array(gp.get("gantries", []))
		gletters.append_array(gp.get("letterings", []))
		if (gp.get("gantries", []) as Array).size() != want["gantries"]:
			stats["gantry_mismatch"] += 1
			print("FIND %s km %.2f gantries %s want %d" % [name, km, str(gp.get("gantries", [])), want["gantries"]])
		var cams := (rp.get("cameras", []) as Array).size()
		stats["radars"] += cams
		if cams != want["cams"]:
			stats["radar_mismatch"] += 1
			print("FIND %s km %.2f radar cams %d want %d" % [name, km, cams, want["cams"]])
	if gletters.size() != gantries.size():
		stats["gantry_lettering_mismatch"] += 1
		print("FIND %s gantry letterings %s gantries %s" % [name, str(gletters), str(gantries)])
	# columns per canopy, pillars per roof
	for zn: Dictionary in t.zones:
		var k := str(zn["kind"])
		var r0 := floorf(float(zn["z0"]) / t.seg_len) * t.seg_len
		var r1 := ceilf(float(zn["z1"]) / t.seg_len) * t.seg_len
		if k == "fuel":
			stats["fuel_lanes"] += 1
		if k == "fuel_canopy":
			if t.get_segment(t.segment_index_at(r0 + 0.1)).tunnel:
				continue
			stats["canopies"] += 1
			var n := 0
			var outs := 0
			for q: Array in columns:
				if float(q[0]) >= r0 and float(q[0]) <= r1:
					n += 1
					if str(q[2]).ends_with("_out"):
						outs += 1
			stats["canopy_columns_out"] += outs
			if n == 0:
				stats["canopies_no_column"] += 1
				print("FIND %s km %.3f canopy without any column" % [name, t.z_to_km(r0)])
			elif n == 1:
				stats["canopies_one_column"] += 1
				print("NOTE %s km %.3f canopy on one column" % [name, t.z_to_km(r0)])
		elif k == "border":
			if t.get_segment(t.segment_index_at(r0 + 0.1)).tunnel:
				print("NOTE %s km %.3f border in a tunnel (no roof, as Arcade)" % [name, t.z_to_km(r0)])
				continue
			stats["borders"] += 1
			var l := 0
			var rr := 0
			var kinds: Array = []
			for q: Array in pillars:
				if float(q[0]) >= r0 - 1.0 and float(q[0]) <= r1 + 1.0:
					if float(q[1]) < 0.0:
						l += 1
					else:
						rr += 1
					kinds.append(("L" if float(q[1]) < 0.0 else "R") + str(q[2]))
			var hk := str(l + rr)
			stats["roof_pillars_hist"][hk] = int(stats["roof_pillars_hist"].get(hk, 0)) + 1
			if l == 0:
				stats["roofs_no_left"] += 1
			if rr == 0:
				stats["roofs_no_right"] += 1
			if l + rr == 0:
				stats["roofs_no_pillar"] += 1
			if l == 0 or rr == 0:
				print("NOTE %s km %.3f border roof one-sided: %s" % [name, t.z_to_km(r0), str(kinds)])
	if not gantries.has("start") or not gantries.has("finish"):
		print("FIND %s gantries %s" % [name, str(gantries)])
		stats["gantry_mismatch"] += 1
