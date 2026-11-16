extends SceneTree
## KRITIK-R (R2): is the concrete decision of an autobahn section the same in both driving directions? For every
## visible stage and both directions: the section keys (AudioFeed.section_key where it exists, else the AU-C1 key
## text) and the feed's own decision (_concrete_section at the middle of the section).
##   godot --headless --path <tree> -s <this> -- --graphics=arcade
## Output: "DIR {...}" per stage, "DONE ..." at the end.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gd: Node = root.get_node("GameData")
	var cfg := ConfigLoader.load_merged()
	var modern: Dictionary = ConfigLoader.lookup(cfg, "audio.modern", {})
	var roads: Array = (modern.get("feed", {}) as Dictionary).get("concrete_roads", ["autobahn"])
	var stages := 0
	var bad_keys := 0
	var bad_dec := 0
	for id: String in gd.call("visible_stage_ids"):
		var st: Dictionary = gd.call("get_stage", id)
		var res := {}
		for from: String in [str(st.get("from", "")), str(st.get("to", ""))]:
			var plan: Object = gd.call("get_stage_plan", id, from)
			if plan == null:
				continue
			var f := AudioFeed.new()
			f.setup(modern)
			f.plan = plan
			var dec := {}
			var km0 := 0.0
			for s: Dictionary in plan.get("sections"):
				var length := float(s.get("length_km", 0.0))
				if roads.has(str(s.get("road", ""))):
					var key := "%s|%s|%.3f|%s|%s" % [str(plan.get("stage_id")), str(s.get("name", "")), length,
						str(s.get("country", "")), str(s.get("scenery", ""))]
					dec[key] = bool(f.call("_concrete_section", km0 + 0.5 * length))
				km0 += length
			res[from] = dec
		if res.size() != 2:
			continue
		stages += 1
		var a: Dictionary = res.values()[0]
		var b: Dictionary = res.values()[1]
		var only_a: Array = []
		var differ: Array = []
		for k: String in a:
			if not b.has(k):
				only_a.append(k)
			elif a[k] != b[k]:
				differ.append(k)
		var only_b: Array = []
		for k: String in b:
			if not a.has(k):
				only_b.append(k)
		bad_keys += 1 if (only_a.size() + only_b.size()) > 0 else 0
		bad_dec += differ.size()
		print("DIR ", JSON.stringify({"stage": id, "sections": a.size(), "keys_only_one_direction": only_a.size() + only_b.size(),
			"decision_differs": differ.size(), "ex": (only_a.slice(0, 2) + only_b.slice(0, 2) + differ.slice(0, 2))}))
	print("DONE stages=%d stages_with_direction_keys=%d decisions_differ=%d" % [stages, bad_keys, bad_dec])
	quit(0)
