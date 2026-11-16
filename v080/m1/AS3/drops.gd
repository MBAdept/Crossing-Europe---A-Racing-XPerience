extends SceneTree
## Scratch tool (AS3): why does the props builder leave out a set near a camera position? (read-only, like
## tests/unit/race3d/test_props.gd test_chunk_list_is_the_tracks_list_minus_the_documented_drops)
##   godot --headless --path . -s <this file> -- --stage=saragossa_pau --from=saragossa --km=149.5 --set=props/cliff

const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	var stage_id := _arg("stage", "saragossa_pau")
	var from := _arg("from", "saragossa")
	var kms: Array = []
	for v: String in _arg("km", "149.5").split(","):
		kms.append(float(v))
	var want_set := _arg("set", "props/cliff")
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var t: Track = null
	for dir: Dictionary in Fair.directions(net, [stage_id]):
		if str(dir["from"]) == from:
			var plan := StagePlan.build(dir["stage"], from, net["cities"], net["countries"], cfg, net["city_db"])
			t = Track.new()
			t.setup(plan, cfg, net["scenery"])
	if t == null:
		print("DROPS keine Etappe")
		quit(1)
		return
	var seen := {}
	var tally := {}
	for km: float in kms:
		_one(t, cfg, net, km, want_set, seen, tally)
	print("DROPS Summe %s: %s" % [want_set, str(tally)])
	quit(0)


func _one(t: Track, cfg: Dictionary, net: Dictionary, km: float, want_set: String, seen: Dictionary, tally: Dictionary) -> void:
	var cam_z := t.km_to_z(km)
	var p := RoadPath3D.new()
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
	var st := ChunkStreamer.new()
	st.setup(p, tp, t, cfg, {}, true)
	var b := Props.new()
	st.register(b)
	st.update(cam_z, 900.0)
	var snap := st.snapshot()
	for ch: Dictionary in snap["chunks"]:
		var part: Dictionary = ch["parts"]["props"]
		var a := int(ch["seg_a"])
		var bb := int(ch["seg_b"])
		var drawn := 0
		for e: Array in part.get("list", []):
			if str(e[2]).begins_with(want_set):
				drawn += 1
		var lines: Array = []
		for k in range(a, bb):
			var s := t.get_segment(k)
			for j in s.sprites.size():
				var it: Dictionary = s.sprites[j]
				if str(it.get("set", "")) != want_set:
					continue
				var side := int(it.get("side", 1))
				var x := float(it.get("x", 0.0))
				var z := float(it.get("z", s.z))
				var f := clampf(z / t.seg_len - float(k), 0.0, 1.0)
				var beyond := absf(x) - tp.edge(k, side)
				var lim := lerpf(tp.limit(k, side), tp.limit(k + 1, side), f)
				var corr := lerpf(tp.corridor_width(k, side), tp.corridor_width(k + 1, side), f)
				var m := absf(x) - lerpf(tp.edge(k, side), tp.edge(k + 1, side), f)
				var in_bend := corr > tp.corridor_min_m - t.shoulder_w + 0.5 and m > 0.0 and m <= corr
				var why := "gezeichnet"
				if beyond > lim - Props.RIBBON_MARGIN_M:
					why = "ribbon (jenseits %.1f m, Band %.1f m)" % [beyond, lim]
				elif in_bend and not it.has("offset"):
					why = "corridor (Korridor %.1f m, Abstand %.1f m)" % [corr, m]
				lines.append("    %s km %.2f x %.1f side %d scenery %s: %s" % [want_set, t.z_to_km(z), x, side, str(s.scenery), why])
				var key := "%d/%d" % [k, j]
				if not seen.has(key):
					seen[key] = true
					var w := why.split(" ")[0]
					tally[w] = int(tally.get(w, 0)) + 1
		print("DROPS Stück %d km %.2f-%.2f: %s gezeichnet %d, ausgelassen %s" % [int(ch["index"]), t.z_to_km(float(a) * t.seg_len),
			t.z_to_km(float(bb) * t.seg_len), want_set, drawn, str(part.get("dropped", {}))])
		for l: String in lines:
			print(l)
	st.clear()
	st.free()
