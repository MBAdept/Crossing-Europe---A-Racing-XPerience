extends SceneTree
## AU-R3: every bridge inside the old-town centre of a destination (all visible stages, both driving directions),
## and the cobble share of every old town on its streets – the feed of AU-R2 (3600eb7, a copy without class_name,
## loaded by path: --old=<file>) against the feed of the tree (AudioFeed). Both are driven through the centre in 1-m
## steps over a proxy track: the real Track's bridges and zones (Track.setup, no segment generated), segments with
## the plan's road / city / tunnel / scenery (as Track._generate sets them). The feeds decide everything themselves.
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --old=<copy of the old audio_feed.gd>
## Output: "BRIDGE {...}" per bridge touching a centre and direction, "CENTRE {...}" per centre and direction,
## "DONE {...}".

const STEP := 1.0


class ProxyTrack:
	extends RefCounted
	var real: Track
	var plan: StagePlan
	var seg_len := 3.0
	var time_scale := 10.0
	var shoulder_w := 2.5
	var cfg: Dictionary = {}
	var scenery_db: Dictionary = {}
	var bridges: Array[Dictionary] = []
	var zones: Array[Dictionary] = []
	var _segs := {}

	func _init(t: Track) -> void:
		real = t
		plan = t.plan
		seg_len = t.seg_len
		time_scale = t.time_scale
		shoulder_w = t.shoulder_w
		cfg = t.cfg
		scenery_db = t.scenery_db
		bridges = t.bridges
		zones = t.zones

	func z_to_km(z: float) -> float:
		return real.z_to_km(z)

	func road_edges_at(_z: float) -> Vector2:
		return Vector2(-5.625, 5.625)

	func get_segment(index: int) -> TrackSegment:
		if _segs.has(index):
			return _segs[index]
		var s := TrackSegment.new()
		s.index = index
		s.z = index * seg_len
		s.km = real.z_to_km(s.z)
		var km := minf(s.km, plan.length_km)
		s.road = plan.road_at(km)
		s.city = plan.is_city(km)
		s.tunnel = plan.in_tunnel(km)
		s.scenery = plan.scenery_for(km, scenery_db)
		s.guardrail = true
		_segs[index] = s
		return s


func _initialize() -> void:
	_run.call_deferred()


func _state(z: float) -> Dictionary:
	return {"z": z, "x": 0.0, "speed": 50.0, "road_left": -5.625, "road_right": 5.625, "shoulder_m": 2.5, "off_road": 0,
		"rail_contact": false, "weather": "normal"}


## Drives the centre of the plan with one feed: per metre the paving, deck, bridge index and tunnel; joint events.
func _drive(f: Object, p: ProxyTrack) -> Dictionary:
	var plan := p.plan
	var z0 := p.real.km_to_z(plan.city_center_km)
	var z1 := p.real.km_to_z(plan.length_km)
	var rows: Array = []
	var joints: Array = []
	var z := z0 - 420.0     # a bridge reaching into the centre (≤ 380 m long) is driven from its start: all its joints
	f.call("update", _state(z - STEP))
	while z < z1:
		f.call("update", _state(z))
		for e: Dictionary in (f.get("events") as Array):
			if str(e.get("name")) == "joint":
				joints.append([float(e.get("z")), str(e.get("kind")), str(e.get("deck"))])
		if z >= z0 and plan.in_city_center(p.real.z_to_km(z)):
			var bi := -1
			for i in p.bridges.size():
				if z >= float(p.bridges[i]["z0"]) and z < float(p.bridges[i]["z1"]):
					bi = i
			rows.append([z, str(f.get("paving")), str(f.get("deck")), bi, bool(f.get("tunnel")), str(f.get("surface_l")), str(f.get("surface_r"))])
		z += STEP
	return {"rows": rows, "joints": joints, "alloc": (f.get("_cobbles") as Dictionary).duplicate()}


func _pattern(alloc: Dictionary) -> String:
	var keys := alloc.keys()
	keys.sort()
	var s := ""
	for k: int in keys:
		s += "P" if bool(alloc[k]) else "-"
	return s      # block 0 (at the finish) first


func _run() -> void:
	await process_frame
	var args := CliArgs.all()
	var old_path := str(args.get("old", ""))
	var OldFeed: GDScript = load(old_path)
	if OldFeed == null:
		print("FEHLER: alter Feed nicht ladbar: ", old_path)
		quit(1)
		return
	var gd: Node = root.get_node("GameData")
	var cfg := ConfigLoader.load_merged()
	var modern: Dictionary = ConfigLoader.lookup(cfg, "audio.modern", {})
	var styles: Array = (modern.get("feed", {}) as Dictionary).get("cobble_styles", [])
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var scenery: Dictionary = (sc as Dictionary).get("scenery", {})
	var n_bridges := 0
	var n_centres := 0
	var n_changed := 0
	for id: String in gd.call("visible_stage_ids"):
		var st: Dictionary = gd.call("get_stage", id)
		for from: String in [str(st.get("from", "")), str(st.get("to", ""))]:
			var plan: StagePlan = gd.call("get_stage_plan", id, from)
			if plan == null:
				continue
			var t := Track.new()
			t.setup(plan, cfg, scenery)
			var res := {}
			for which: String in ["old", "new"]:
				var p := ProxyTrack.new(t)
				var f: Object = OldFeed.new() if which == "old" else AudioFeed.new()
				f.call("setup", modern)
				f.call("set_track", p, plan)
				res[which] = _drive(f, p)
			var ro: Array = res["old"]["rows"]
			var rn: Array = res["new"]["rows"]
			var cobble_style := styles.has(plan.city_style)
			# per bridge touching the centre
			var per := {}
			for i in ro.size():
				var bi := int(ro[i][3])
				if bi < 0:
					continue
				var d: Dictionary = per.get(bi, {"m": 0.0, "old": {}, "new": {}, "deck_old": {}, "deck_new": {}})
				d["m"] = float(d["m"]) + STEP
				for which: String in ["old", "new"]:
					var row: Array = (ro if which == "old" else rn)[i]
					var pv: Dictionary = d[which]
					pv[str(row[1])] = float(pv.get(str(row[1]), 0.0)) + STEP
					var dk: Dictionary = d["deck_" + which]
					dk[str(row[2])] = float(dk.get(str(row[2]), 0.0)) + STEP
				per[bi] = d
			for bi: int in per:
				var b: Dictionary = t.bridges[bi]
				var d: Dictionary = per[bi]
				var jo := 0
				var jn := 0
				for j: Array in res["old"]["joints"]:
					jo += 1 if (float(j[0]) >= float(b["z0"]) - 0.01 and float(j[0]) <= float(b["z1"]) + 0.01) else 0
				for j: Array in res["new"]["joints"]:
					jn += 1 if (float(j[0]) >= float(b["z0"]) - 0.01 and float(j[0]) <= float(b["z1"]) + 0.01) else 0
				n_bridges += 1
				print("BRIDGE ", JSON.stringify({"stage": id, "from": from, "to": plan.to_id, "style": plan.city_style,
					"cobble_style": cobble_style, "name": str(b.get("name", "")), "type": str(b.get("type", "")),
					"deck": AudioFeed.deck_of(str(b.get("type", ""))), "km0": snappedf(float(b["km0"]), 0.001),
					"km1": snappedf(float(b["km1"]), 0.001), "to_finish_m": [snappedf(t.length_z - float(b["z1"]), 0.1), snappedf(t.length_z - float(b["z0"]), 0.1)],
					"length_m": float(b["z1"]) - float(b["z0"]), "in_centre_m": d["m"], "paving_old": d["old"], "paving_new": d["new"],
					"deck_old": d["deck_old"], "deck_new": d["deck_new"], "joints_old": jo, "joints_new": jn}))
			# the centre: streets (off bridges without a stone deck, outside tunnels), stone bridges, tunnels
			var c := {"centre_m": 0.0, "nonstone_m": 0.0, "stone_m": 0.0, "tunnel_m": 0.0, "street_m": 0.0, "street_cob_old": 0.0,
				"street_cob_new": 0.0, "bridge_cob_old": 0.0, "bridge_cob_new": 0.0, "stone_cob_new": 0.0, "diff_m": 0.0,
				"surface_diff_m": 0.0}
			for i in ro.size():
				var a: Array = ro[i]
				var n: Array = rn[i]
				c["centre_m"] = float(c["centre_m"]) + STEP
				if str(a[1]) != str(n[1]):
					c["diff_m"] = float(c["diff_m"]) + STEP
				if str(a[5]) != str(n[5]) or str(a[6]) != str(n[6]):
					c["surface_diff_m"] = float(c["surface_diff_m"]) + STEP
				var dk := str(n[2])
				if bool(n[4]):
					c["tunnel_m"] = float(c["tunnel_m"]) + STEP
				elif dk == "stone":
					c["stone_m"] = float(c["stone_m"]) + STEP
					c["stone_cob_new"] = float(c["stone_cob_new"]) + (STEP if str(n[1]) == "cobbles" else 0.0)
				elif dk != "":
					c["nonstone_m"] = float(c["nonstone_m"]) + STEP
					c["bridge_cob_old"] = float(c["bridge_cob_old"]) + (STEP if str(a[1]) == "cobbles" else 0.0)
					c["bridge_cob_new"] = float(c["bridge_cob_new"]) + (STEP if str(n[1]) == "cobbles" else 0.0)
				else:
					c["street_m"] = float(c["street_m"]) + STEP
					c["street_cob_old"] = float(c["street_cob_old"]) + (STEP if str(a[1]) == "cobbles" else 0.0)
					c["street_cob_new"] = float(c["street_cob_new"]) + (STEP if str(n[1]) == "cobbles" else 0.0)
			var sm := maxf(float(c["street_m"]), 1.0)
			c["share_old"] = snappedf(float(c["street_cob_old"]) / sm, 0.001)
			c["share_new"] = snappedf(float(c["street_cob_new"]) / sm, 0.001)
			c["changed"] = float(c["diff_m"]) > 0.0
			n_changed += 1 if bool(c["changed"]) else 0
			c.merge({"stage": id, "from": from, "to": plan.to_id, "style": plan.city_style, "cobble_style": cobble_style,
				"centre_km": snappedf(plan.length_km - plan.city_center_km, 0.001), "pattern_old": _pattern(res["old"]["alloc"]),
				"pattern_new": _pattern(res["new"]["alloc"]), "bridges_in_centre": per.size()})
			n_centres += 1
			print("CENTRE ", JSON.stringify(c))
	print("DONE ", JSON.stringify({"bridges": n_bridges, "centres": n_centres, "centres_changed": n_changed}))
	quit(0)
