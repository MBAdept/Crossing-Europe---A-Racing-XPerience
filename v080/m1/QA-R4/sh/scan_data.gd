extends SceneTree
## QA-R4 data scan (not part of the repo): tunnels network-wide (exit detection, gaps shorter than the after-glow),
## snow banks built by the terrain builder with snow on every stage (sampled windows).

const Fair := preload("res://tests/race3d/fairness.gd")
const TerrainBuilder := preload("res://scripts/race3d/builders/terrain.gd")
const Rig := preload("res://scripts/race3d/environment_rig.gd")

class FakeRenderer:
	var prep := {"weather": "snow"}

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var dirs := Fair.directions(net, [])
	var windows_per := 3
	var tunnels_only := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--windows="):
			windows_per = int(a.substr(10))
		if a == "--tunnels-only":
			tunnels_only = true
	var n_tun := 0
	var short_gaps: Array = []
	var exit_fail: Array = []
	var stage_seen := {}
	var bank_max := 0.0
	var chunks := 0
	var bank_chunks := 0
	var bank_tris := 0
	var errors := 0
	var dirs_scanned := 0
	var bank_bad_rows := 0
	for dir: Dictionary in dirs:
		var sid := str(dir["stage"]["id"])
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net.get("city_db", {}))
		var track := Track.new()
		track.setup(plan, cfg, net["scenery"])
		# tunnels: exit detection and gaps (both directions)
		var tl: Array = plan.tunnels.duplicate()
		tl.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["start_km"]) < float(y["start_km"]))
		for i in tl.size():
			var t: Dictionary = tl[i]
			n_tun += 1
			var z1 := minf(track.km_to_z(float(t["end_km"])), track.length_z)
			var ex := Rig.exit_ahead(track, z1 - 5.0, 900.0)
			if ex.is_empty() or absf(float(ex["z"]) - z1) > 0.01:
				exit_fail.append("%s %s km %.2f" % [dir["name"], str(t.get("name", "")), float(t["end_km"])])
			if i + 1 < tl.size():
				var nz0 := track.km_to_z(float(tl[i + 1]["start_km"]))
				var gap := nz0 - z1
				if gap < Rig.EXIT_AFTER_M:
					var after_at_entry := Rig.exit_after(gap)
					short_gaps.append("%s: %s (bis km %.3f) -> %s (ab km %.3f): Luecke %.0f m, Nachgluehen beim Einfahren %.2f (volle Staerke %.2f)" % [dir["name"],
						str(t.get("name", "?")), float(t["end_km"]), str(tl[i + 1].get("name", "?")), float(tl[i + 1]["start_km"]), gap, after_at_entry, Rig.EXIT_AFTER])
		if tunnels_only or stage_seen.has(sid):
			continue
		stage_seen[sid] = true
		dirs_scanned += 1
		# snow banks: windows along the stage
		for w in windows_per:
			var cam_z := track.length_z * (float(w) + 0.5) / float(windows_per)
			var p := RoadPath3D.new()
			var tp := TerrainProfile.new()
			tp.setup(p, track, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
			var st := ChunkStreamer.new()
			st.setup(p, tp, track, cfg, {}, true)
			st.update(cam_z, 900.0)
			var builder := TerrainBuilder.new()
			var snap := st.snapshot()
			for ch: Dictionary in snap["chunks"]:
				var ctx := ChunkContext.new()
				ctx.cfg = cfg
				ctx.scenery_db = net["scenery"]
				ctx.services = {"renderer": FakeRenderer.new()}
				ctx.capture(int(ch["index"]), int(ch["seg_a"]), int(ch["seg_b"]), p, tp, track)
				var inp: Variant = builder.collect(ctx)
				if not (inp is Dictionary) or not bool((inp as Dictionary).get("snow", false)):
					errors += 1
					continue
				var part: Dictionary = builder.build(ctx, inp)
				chunks += 1
				var bt := int(part.get("bank_tris", 0))
				bank_tris += bt
				if bt > 0:
					bank_chunks += 1
				var rows := ctx.row_count()
				for i in rows:
					bank_max = maxf(bank_max, TerrainBuilder.bank_height(ctx.seg_a + i))
					var sg: Dictionary = ctx.segs[i]
					if TerrainBuilder.bank_row(sg) and (bool(sg["tunnel"]) or bool(sg["water"]) or bool(sg["city"])):
						bank_bad_rows += 1
				var verts: PackedVector3Array = part["verts"]
				var nrm: PackedVector3Array = part["normals"]
				if verts.size() != nrm.size():
					errors += 1
		if dirs_scanned % 10 == 0:
			print("  ... %d Etappen, %d Stuecke, %.0f s" % [dirs_scanned, chunks, (Time.get_ticks_msec() - t0) / 1000.0])
	print("SCAN tunnel: %d Tunnel (beide Richtungen), Ausfahrt nicht erkannt: %d %s" % [n_tun, exit_fail.size(), str(exit_fail.slice(0, 10))])
	print("SCAN tunnel_luecken < %.0f m (Nachgluehen in den naechsten Tunnel): %d" % [Rig.EXIT_AFTER_M, short_gaps.size()])
	for s: String in short_gaps:
		print("    " + s)
	print("SCAN schneewall: %d Etappen, %d Stuecke mit Schnee gebaut, %d mit Wall, %d Walldreiecke, hoechster Wall %.3f m, falsche Reihen %d, Fehler %d" % [dirs_scanned, chunks, bank_chunks, bank_tris, bank_max, bank_bad_rows, errors])
	print("SCAN fertig %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)
