extends SceneTree
## QA-R7c probe: the LOD bands of EVERY prop/landmark model of the shipped manifest at Details 0/1/2 (props.gd
## model_bands): the dither shares of its representations sum to 1 at every distance 0..4000 m (no hole, nothing twice);
## prints the level ends at "Mittel" and models whose last representation does not reach "endless".
const Props := preload("res://scripts/race3d/builders/props.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cfg := ConfigLoader.load_merged()
	ModelDB.available()
	var want: Array = []
	for sid: String in ModelDB.set_ids():
		if sid.begins_with("props/") or sid.begins_with("landmarks/"):
			want.append(sid)
	var pb: Object = Props.new()
	pb.call("_read_config", cfg)
	var lib := PropLibrary.new()
	pb.set("library", lib)
	lib.request(want, self)
	var guard := 0
	while lib.pending() > 0 and guard < 20000:
		await process_frame
		guard += 1
	var dets: Array = ConfigLoader.lookup(cfg, "graphics.levels.details", [])
	var bad := 0
	var checked := 0
	for di in dets.size():
		pb.call("apply_quality", dets[di])
		for mid: String in lib.models:
			var bands: Dictionary = pb.call("model_bands", mid)
			checked += 1
			var worst := 0.0
			var worst_d := 0.0
			var d := 0.0
			while d <= 4000.0:
				var s := 0.0
				for rep: String in bands:
					var b: Vector4 = bands[rep]
					if d < b.x or d > b.w:
						continue
					var fin := clampf((d - b.x) / maxf(b.y - b.x, 0.001), 0.0, 1.0)
					var fout := clampf((b.w - d) / maxf(b.w - b.z, 0.001), 0.0, 1.0)
					s += 1.0 if (fin >= 1.0 and fout >= 1.0) else fin * fout
				if absf(s - 1.0) > worst:
					worst = absf(s - 1.0)
					worst_d = d
				d += 0.25 if d < 400.0 else 2.0
			if worst > 0.02:
				bad += 1
				print("BANDS BAD details %d %s worst %.3f at %.2f m %s" % [di, mid, worst, worst_d, str(bands)])
			if di == 1:
				var ends := []
				for rep: String in bands:
					var b: Vector4 = bands[rep]
					ends.append("%s %.0f-%.0f" % [rep, b.z, b.w] if b.z < 1.0e8 else "%s ab %.0f" % [rep, b.y])
				print("BANDS MITTEL %s reps %s lod_m %s | %s" % [mid, str((lib.models[mid] as Dictionary).get("reps")), str((lib.models[mid] as Dictionary).get("lod_m")), ", ".join(ends)])
	print("BANDS ALL CHECKED %d (model x details), BAD %d, models %d" % [checked, bad, lib.models.size()])
	lib.clear(self)
	quit(0)
