extends SceneTree
## R3 scratch: the sign events of a stage (km, kind, text, value, side) – to place the sign pictures.
##   godot --headless --path . -s <this> -- --stage=kiel_hamburg --from=kiel

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := "kiel_hamburg"
	var from := "kiel"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			stage = a.substr(8)
		elif a.begins_with("--from="):
			from = a.substr(7)
	var gd: Node = root.get_node("GameData")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var st: Variant = gd.call("stage_by_id", stage) if gd.has_method("stage_by_id") else null
	var plan: StagePlan = null
	for m: String in ["get_stage_plan"]:
		if gd.has_method(m):
			plan = gd.call(m, stage, from)
			break
	if plan == null:
		print("kein Plan – Methoden von GameData: ", gd.get_method_list().map(func(x: Dictionary) -> String: return str(x["name"])).filter(func(n: String) -> bool: return n.contains("stage") or n.contains("plan")))
		quit(1)
		return
	var track := Track.new()
	track.setup(plan, cfg, gd.get("scenery"))
	for i in track.segment_count:
		for e: Dictionary in track.events_for_segment(i):
			if str(e.get("kind", "")) == "sign":
				print("km %7.2f  %-12s side %2d  %s %s" % [track.z_to_km(float(e["z"])), str(e.get("sign", "")), int(e.get("side", 1)), str(e.get("text", "")), str(e.get("value", ""))])
	quit(0)
