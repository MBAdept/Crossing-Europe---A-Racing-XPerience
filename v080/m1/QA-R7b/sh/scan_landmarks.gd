extends SceneTree
## QA-R7b: data scan of every stage direction of the network – for every landmark of Track.landmarks:
## Arcade's representation (RoadRenderer._prep_prop of the same item: set / proc / anchor x / scale / tint) against
## builders/landmarks.gd resolve_item (rep / set / kind / x / scale / tint), then a headless build of every landmark
## node (_make with a stub renderer): node created, parts, materials, triangles. Skyline entries of every
## destination: drawable by the backdrop (sprite or one of Arcade's procedural kinds).
## Run: godot --headless --path <tree> -s <this file>

const Fair := preload("res://tests/race3d/fairness.gd")
const Landmarks := preload("res://scripts/race3d/builders/landmarks.gd")


class StubRenderer:
	extends Node
	var terrain = null
	var path = null
	func road_to_world(z: float, x: float, h: float) -> Vector3:
		return Vector3(x, h, -z)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.call("disarm_crash_guard")
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var proj := Fair.make_projection(cfg)
	var dirs := Fair.directions(net)
	var per_dir: Array = []
	var want: Array = []
	var t0 := Time.get_ticks_msec()
	for dir: Dictionary in dirs:
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var lms: Array = []
		for it: Dictionary in t.landmarks:
			lms.append(it.duplicate(true))
		var sky: Array = []
		for e: Dictionary in t.plan.skyline:
			sky.append(e.duplicate(true))
		per_dir.append({"name": str(dir["name"]), "lms": lms, "pfb": Landmarks.plan_fallbacks(t), "sky": sky,
			"seg": t.seg_len, "km": t.z_to_km(t.landmarks[0]["z"]) if not t.landmarks.is_empty() else -1.0})
		for s: String in Landmarks.wanted_sets(t):
			if not want.has(s):
				want.append(s)
	print("SCAN dirs=%d sets=%d (%.1f s)" % [dirs.size(), want.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	var lib := PropLibrary.new()
	lib.request(want, self)
	var guard := 0
	while lib.pending() > 0 and guard < 60000:
		OS.delay_msec(2)
		guard += 1
	print("SCAN library ready=%s fail=%s" % [str(lib.ready()), lib.fail_reason()])
	var stub := StubRenderer.new()
	var world := Node3D.new()
	var b = Landmarks.new()
	b.library = lib
	b._renderer = stub
	b._prepared = true
	var n_total := 0
	var n_bad := 0
	var reps := {}
	var max_dx := 0.0
	var max_dx_what := ""
	var seen := {}
	for d: Dictionary in per_dir:
		var lms: Array = d["lms"]
		for li in lms.size():
			var it: Dictionary = lms[li]
			n_total += 1
			var rr: Node = (load("res://scripts/race/road_renderer.gd") as GDScript).new()
			rr.set("proj", proj)
			var pc: Array = rr.call("_prep_prop", it.duplicate())
			rr.free()
			var p: Dictionary = Landmarks.resolve_item(it, lib.sets, d["pfb"])
			var rep := int(p["rep"])
			var probs: Array[String] = []
			var a_set := str(pc[0])
			var a_proc := str(pc[4])
			if a_set != "":
				if not (rep == Landmarks.MODEL or rep == Landmarks.PICTURE):
					probs.append("Arcade Bild %s, Modern rep %s" % [a_set, Landmarks.REP_NAMES[rep]])
				if str(p["set"]) != a_set:
					probs.append("Set Arcade %s, Modern %s" % [a_set, str(p["set"])])
				if absf(float(p["scale"]) - float(pc[2])) > 1.0e-4:
					probs.append("Maßstab Arcade %.3f, Modern %.3f" % [float(pc[2]), float(p["scale"])])
				var ta: Color = pc[5]
				var tm: Color = p["tint"]
				if not ta.is_equal_approx(tm):
					probs.append("Tönung Arcade %s, Modern %s" % [ta.to_html(false), tm.to_html(false)])
			elif a_proc != "":
				if rep != Landmarks.PROC or str(p["kind"]) != a_proc:
					probs.append("Arcade prozedural %s, Modern %s %s (set %s)" % [a_proc, Landmarks.REP_NAMES[rep], str(p["kind"]), str(p["set"])])
			else:
				probs.append("Arcade zeichnet nichts")
				if rep != Landmarks.NONE:
					probs.append("Modern zeichnet %s" % Landmarks.REP_NAMES[rep])
			var dx := absf(float(p["x"]) - float(pc[3]))
			var px600 := dx * float(proj.focal) / 600.0
			if dx > max_dx:
				max_dx = dx
				max_dx_what = "%s %s (Arcade x %.2f, Modern x %.2f)" % [str(d["name"]), str(it["set"]), float(pc[3]), float(p["x"])]
			if px600 > 0.05 * float(proj.screen.x):
				probs.append("Anker %.1f m neben Arcade (%.0f px bei 600 m)" % [dx, px600])
			var key := "%s|%s" % [Landmarks.REP_NAMES[rep], str(p["set"]) if rep != Landmarks.PROC else str(p["kind"])]
			reps[key] = int(reps.get(key, 0)) + 1
			# headless build of the node
			var bkey := str(it["set"]) + "|" + str(p["set"]) + "|" + str(p.get("proc_key", ""))
			if rep != Landmarks.NONE and not seen.has(bkey):
				seen[bkey] = true
				b._plans = [p]
				var e: Variant = b._make(0, p, world)
				if e == null:
					probs.append("Knoten nicht gebaut")
				else:
					var ed: Dictionary = e
					var node: Node3D = ed["node"]
					var meshes := 0
					var tris := 0
					for c: Node in node.get_children():
						if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
							meshes += 1
							var m: Mesh = (c as MeshInstance3D).mesh
							for si in m.get_surface_count():
								var arr := m.surface_get_arrays(si)
								var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
								tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
					var slots: Array = ed["slots"]
					var nullmat := 0
					for s: Array in slots:
						if s[1] == null or s[2] == null:
							nullmat += 1
					if meshes == 0 or slots.is_empty() or nullmat > 0:
						probs.append("Knoten leer (Netze %d, Plätze %d, ohne Material %d)" % [meshes, slots.size(), nullmat])
					print("BUILD %-42s rep=%-7s set=%-34s netze=%d plaetze=%d dreiecke=%d licht=%s" % [str(it["set"]), Landmarks.REP_NAMES[rep],
						str(p["set"]) if rep != Landmarks.PROC else str(p["kind"]), meshes, slots.size(), tris, str(ed.get("has_lights"))])
					b._live.erase(0)
					node.free()
			if not probs.is_empty():
				n_bad += 1
				print("SCAN-ABW %s %s: %s" % [str(d["name"]), str(it["set"]), "; ".join(probs)])
		# skyline entries: something the backdrop can draw
		for e: Dictionary in (d["sky"] as Array):
			var rr2: Node = (load("res://scripts/race/road_renderer.gd") as GDScript).new()
			rr2.set("proj", proj)
			var pc2: Array = rr2.call("_prep_prop", e.duplicate())
			rr2.free()
			if (pc2[1] as Array).is_empty() and str(pc2[4]) == "":
				print("SCAN-ABW %s Skyline %s: weder Bild noch prozedurale Art" % [str(d["name"]), str(e.get("set"))])
				n_bad += 1
	print("SCAN reps: %s" % str(reps))
	print("SCAN groesster Ankerversatz %.2f m: %s" % [max_dx, max_dx_what])
	print("SCAN %s  %d Wahrzeichen in %d Richtungen, %d mit Abweichung" % ["OK" if n_bad == 0 else "ABW", n_total, per_dir.size(), n_bad])
	world.free()
	stub.free()
	lib.clear(self)
	ModelDB.release_all()
	quit(0)
