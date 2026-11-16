extends SceneTree
## KRITIK-R2-CODE: triggering of the Modern road feed over ALL visible stages in BOTH directions, on the REAL Track
## (real segments: fuel lanes, guardrails, sprites, bridges, tunnels; window moved like a race), the feed of the tree.
## Independent rules checked per metre (step 1 m in the City Limits and on bridges, 3 m elsewhere):
##   PAV  cobbles only in an old-town street (centre, no bridge, no tunnel) or on a stone deck; never on a steel or
##        concrete deck; "deck" only on steel; concrete only on concrete_roads outside the City Limits, not in tunnels,
##        not on steel/stone decks; feed.deck == deck of the track's bridge at z
##   JNT  joints per bridge from the feed's events vs the rule (ends + every N m, none within N/2 of the far end;
##        steel 100, concrete 32, stone none) and no joint event off a bridge
##   OLD  per arrival: centre metres, street metres (no bridge, no tunnel), cobbled street metres, stone-bridge and
##        tunnel metres
##   CON  per section key: the decision (both directions must agree), km; per country metres heard as concrete
##   ZON  zone "tunnel" exactly in tunnels; wet / snow off in tunnels, on outside (weather alternates rain / snow)
##   FUEL second feed with the right wheel 0.1 m inside the right edge through every fuel lane (+ taper) and 200 m
##        before it: surface_r per metre (rumble while the segment has a fuel lane = violation)
##   godot --headless --path <tree> -s <this> -- --graphics=arcade [--only=<stage id>]

const STEP_CITY := 1.0
const STEP_OPEN := 3.0


func _initialize() -> void:
	_run.call_deferred()


func _state(z: float, x: float, t: Track, weather: String) -> Dictionary:
	var e: Vector2 = t.road_edges_at(z)
	return {"z": z, "x": x, "speed": 100.0, "road_left": e.x, "road_right": e.y, "shoulder_m": t.shoulder_w,
		"off_road": 0, "rail_contact": false, "weather": weather}


func _expected_joints(z0: float, z1: float, every: float) -> Array:
	var out: Array = []
	if every < 0.0:
		return out
	out.append(z0)
	if every > 0.0:
		var j := 1
		while z0 + j * every < z1 - 0.5 * every:
			out.append(z0 + j * every)
			j += 1
	out.append(z1)
	return out


func _run() -> void:
	await process_frame
	var args := CliArgs.all()
	var only := str(args.get("only", ""))
	var gd: Node = root.get_node("GameData")
	var cfg := ConfigLoader.load_merged()
	var modern: Dictionary = ConfigLoader.lookup(cfg, "audio.modern", {})
	var feedcfg: Dictionary = modern.get("feed", {})
	var croads: Array = feedcfg.get("concrete_roads", ["autobahn"])
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var scenery: Dictionary = (sc as Dictionary).get("scenery", {})
	var decisions := {}       # section key -> [decision, km, country, [dirs]]
	var n_plans := 0
	var t_start := Time.get_ticks_msec()
	var plan_i := 0
	for id: String in gd.call("visible_stage_ids"):
		if only != "" and id != only:
			continue
		var st: Dictionary = gd.call("get_stage", id)
		for from: String in [str(st.get("from", "")), str(st.get("to", ""))]:
			var plan: StagePlan = gd.call("get_stage_plan", id, from)
			if plan == null:
				continue
			plan_i += 1
			var weather := "rain" if plan_i % 2 == 1 else "snow"
			var t := Track.new()
			t.setup(plan, cfg, scenery)
			var f := AudioFeed.new()
			f.setup(modern)
			f.set_vehicle_width(1.85)
			f.set_track(t, plan)
			var viol := {"PAV": 0, "DECK": 0, "ZON": 0, "WX": 0, "JOFF": 0}
			var viol_ex: Array = []
			var joints: Array = []
			var centre := {"centre_m": 0.0, "street_m": 0.0, "street_cob_m": 0.0, "stone_m": 0.0, "stone_cob_m": 0.0,
				"nonstone_m": 0.0, "nonstone_cob_m": 0.0, "tunnel_m": 0.0, "tunnel_cob_m": 0.0, "cob_m": 0.0}
			var conc_country := {}   # country -> [autobahn metres outside city/tunnel, concrete metres]
			var sec_seen := {}
			var z := 0.0
			var z_end := t.length_z
			f.update(_state(z, 0.0, t, weather))
			while z < z_end:
				var km := t.z_to_km(z)
				var city := plan.is_city(km)
				var br: Dictionary = t.bridge_at(z)
				var step := STEP_CITY if (city or not br.is_empty()) else STEP_OPEN
				z += step
				if z >= z_end:
					break
				t.update_window(z, 120.0)
				f.update(_state(z, 0.0, t, weather))
				km = t.z_to_km(z)
				city = plan.is_city(km)
				br = t.bridge_at(z)
				var tun := plan.in_tunnel(km)
				var cen := plan.in_city_center(km)
				var dk := AudioFeed.deck_of(str(br.get("type", ""))) if not br.is_empty() else ""
				var pv := f.paving
				for e: Dictionary in f.events:
					if str(e.get("name")) == "joint":
						joints.append([float(e.get("z")), str(e.get("deck")), str(e.get("kind"))])
				# feed deck == track deck
				if f.deck != dk:
					viol["DECK"] = int(viol["DECK"]) + 1
					if viol_ex.size() < 40:
						viol_ex.append({"r": "DECK", "km": snappedf(km, 0.001), "feed": f.deck, "track": dk})
				# paving rules
				var bad := ""
				if pv == "cobbles" and not ((cen and dk == "" and not tun) or dk == "stone"):
					bad = "cobbles_outside"
				elif pv == "deck" and dk != "steel":
					bad = "deck_not_steel"
				elif pv == "concrete" and (city or tun or not croads.has(plan.road_at(km)) or dk == "steel" or dk == "stone"):
					bad = "concrete_where_not"
				elif dk == "steel" and pv != "deck":
					bad = "steel_not_deck"
				elif dk == "stone" and pv != "cobbles":
					bad = "stone_not_cobbles"
				elif tun and pv != "asphalt":
					bad = "tunnel_not_asphalt"
				if bad != "":
					viol["PAV"] = int(viol["PAV"]) + 1
					if viol_ex.size() < 40:
						viol_ex.append({"r": bad, "km": snappedf(km, 0.001), "paving": pv, "deck": dk, "centre": cen, "tunnel": tun})
				# zones and weather
				if (f.zone == "tunnel") != tun:
					viol["ZON"] = int(viol["ZON"]) + 1
					if viol_ex.size() < 40:
						viol_ex.append({"r": "zone", "km": snappedf(km, 0.001), "zone": f.zone, "tunnel": tun})
				var want_wet := 1.0 if (weather == "rain" and not tun) else 0.0
				var want_snow := 1.0 if (weather == "snow" and not tun) else 0.0
				if absf(f.wet - want_wet) > 1e-6 or absf(f.snow - want_snow) > 1e-6:
					viol["WX"] = int(viol["WX"]) + 1
				# old town
				if cen:
					centre["centre_m"] = float(centre["centre_m"]) + step
					var cob := step if pv == "cobbles" else 0.0
					centre["cob_m"] = float(centre["cob_m"]) + cob
					if tun:
						centre["tunnel_m"] = float(centre["tunnel_m"]) + step
						centre["tunnel_cob_m"] = float(centre["tunnel_cob_m"]) + cob
					elif dk == "stone":
						centre["stone_m"] = float(centre["stone_m"]) + step
						centre["stone_cob_m"] = float(centre["stone_cob_m"]) + cob
					elif dk != "":
						centre["nonstone_m"] = float(centre["nonstone_m"]) + step
						centre["nonstone_cob_m"] = float(centre["nonstone_cob_m"]) + cob
					else:
						centre["street_m"] = float(centre["street_m"]) + step
						centre["street_cob_m"] = float(centre["street_cob_m"]) + cob
				# concrete per section (decision once per key; metres as heard)
				if not city and croads.has(plan.road_at(km)):
					var sec: Dictionary = plan.section_at(km)
					var key := AudioFeed.section_key(plan.stage_id, sec)
					var country := str(sec.get("country", ""))
					if not sec_seen.has(key):
						sec_seen[key] = true
						var dec := bool(f.call("_concrete_section", km))
						var d0: Array = decisions.get(key, [dec, float(sec.get("length_km", 0.0)), country, [], []])
						(d0[3] as Array).append(from)
						(d0[4] as Array).append(dec)
						decisions[key] = d0
					if not tun and dk != "steel" and dk != "stone":
						var cc: Array = conc_country.get(country, [0.0, 0.0])
						cc[0] = float(cc[0]) + step
						cc[1] = float(cc[1]) + (step if pv == "concrete" else 0.0)
						conc_country[country] = cc
			# joints per bridge
			var jrows: Array = []
			var used := {}
			for bi in t.bridges.size():
				var b: Dictionary = t.bridges[bi]
				var bz0 := float(b["z0"])
				var bz1 := float(b["z1"])
				var bdk := AudioFeed.deck_of(str(b.get("type", "")))
				var every := f.joint_spacing(bdk)
				var exp := _expected_joints(bz0, bz1, every)
				var got: Array = []
				for ji in joints.size():
					var jz := float(joints[ji][0])
					if jz >= bz0 - 0.01 and jz <= bz1 + 0.01:
						got.append(snappedf(jz - bz0, 0.01))
						used[ji] = true
				var expr: Array = []
				for ez: float in exp:
					expr.append(snappedf(ez - bz0, 0.01))
				var ok := got == expr
				jrows.append({"name": str(b.get("name", "")), "type": str(b.get("type", "")), "deck": bdk,
					"len": snappedf(bz1 - bz0, 0.1), "km0": snappedf(float(b.get("km0", 0.0)), 0.001), "got": got, "exp": expr, "ok": ok,
					"in_centre": plan.in_city_center(t.z_to_km(bz0)) or plan.in_city_center(t.z_to_km(bz1 - 0.01))})
			for ji in joints.size():
				if not used.has(ji):
					viol["JOFF"] = int(viol["JOFF"]) + 1
			# fuel lanes: right wheel 0.1 m inside the right edge
			var fuel_rows: Array = []
			var taper := float(ConfigLoader.lookup(cfg, "road.fuel_lane_taper_m", 40.0))
			var t2 := Track.new()
			t2.setup(plan, cfg, scenery)
			var g := AudioFeed.new()
			g.setup(modern)
			g.set_vehicle_width(1.85)
			g.set_track(t2, plan)
			var lanes_sorted: Array = plan.fuel_lanes.duplicate()
			lanes_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start_km"]) < float(b["start_km"]))
			for l: Dictionary in lanes_sorted:
				var lz0 := t.km_to_z(float(l["start_km"]))
				var lz1 := t.km_to_z(float(l["end_km"]))
				var cnt := {"rumble_with_lane": 0, "with_lane": 0, "rumble_before": 0, "before": 0, "surf": {}}
				var zz := maxf(lz0 - 200.0, 1.0)
				while zz <= lz1 + taper + 20.0:
					t2.update_window(zz, 60.0)
					var e: Vector2 = t2.road_edges_at(zz)
					var xx := e.y - g.track_half_m - 0.1
					g.update(_state(zz, xx, t2, "normal"))
					var seg: TrackSegment = t2.get_segment(int(floor(zz / t2.seg_len)))
					if seg.fuel_lane > 0.0:
						cnt["with_lane"] = int(cnt["with_lane"]) + 1
						if g.surface_r == "rumble":
							cnt["rumble_with_lane"] = int(cnt["rumble_with_lane"]) + 1
						var sd: Dictionary = cnt["surf"]
						sd[g.surface_r] = int(sd.get(g.surface_r, 0)) + 1
					elif zz < lz0:
						cnt["before"] = int(cnt["before"]) + 1
						if g.surface_r == "rumble":
							cnt["rumble_before"] = int(cnt["rumble_before"]) + 1
					zz += 1.0
				cnt["km"] = snappedf(float(l["start_km"]), 0.01)
				cnt["road"] = plan.road_at(float(l["start_km"]))
				fuel_rows.append(cnt)
			n_plans += 1
			print("PLAN ", JSON.stringify({"stage": id, "from": from, "to": plan.to_id, "style": plan.city_style,
				"weather": weather, "length_z": snappedf(z_end, 0.1), "viol": viol, "ex": viol_ex, "centre": centre,
				"centre_m_plan": snappedf((plan.length_km - plan.city_center_km) * 1000.0 / t.time_scale, 0.1),
				"pattern": (f.get("_cobbles") as Dictionary).duplicate(), "joints": jrows, "fuel": fuel_rows,
				"conc_country": conc_country}))
	for key: String in decisions:
		var d: Array = decisions[key]
		print("SEC ", JSON.stringify({"key": key, "dec": d[0], "km": d[1], "country": d[2], "dirs": d[3], "decs": d[4]}))
	print("DONE ", JSON.stringify({"plans": n_plans, "sections": decisions.size(), "ms": Time.get_ticks_msec() - t_start}))
	quit(0)
