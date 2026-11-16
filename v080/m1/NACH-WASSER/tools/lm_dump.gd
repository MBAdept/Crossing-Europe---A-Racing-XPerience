extends SceneTree
# NACH-WASSER: the landmarks of stage directions (set, km, side, x, proc, fallback ...), and the cable-stayed pylons.
# usage: godot --headless --path <project> -s lm_dump.gd -- <stage>__<from> ...

const Fair := preload("res://tests/race3d/fairness.gd")


func _init() -> void:
	var net := Fair.load_network()
	var cfg := ConfigLoader.load_merged()
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		only.append(a)
	for dir: Dictionary in Fair.directions(net):
		if not only.has(str(dir["name"])):
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		print("== %s  (length %.1f km)" % [dir["name"], t.z_to_km(t.length) if t.get("length") != null else -1.0])
		for lm: Dictionary in t.landmarks:
			print("  LM set=%s km=%.2f side=%d x=%.1f scale=%s proc=%s fallback=%s fb_scale=%s fb_tint=%s tint=%s name=%s" % [
				lm.get("set", ""), t.z_to_km(float(lm["z"])), int(lm.get("side", 0)), float(lm.get("x", 0.0)),
				str(lm.get("scale", 1.0)), str(lm.get("proc", "-")), str(lm.get("fallback", "-")),
				str(lm.get("fallback_scale", "-")), str(lm.get("fallback_tint", "-")), str(lm.get("tint", "-")),
				str(lm.get("name", ""))])
		for plm: Dictionary in plan.landmarks:
			print("  PLAN set=%s km=%s proc=%s fallback=%s" % [plm.get("set", ""), str(plm.get("km", "")), str(plm.get("proc", "-")),
				str(plm.get("fallback", "-"))])
		for b: Dictionary in t.bridges:
			if str(b["type"]) == "cable_stayed":
				print("  BRIDGE cable_stayed km %.2f-%.2f name=%s depth=%.1f" % [float(b["km0"]), float(b["km1"]), str(b["name"]), float(b["depth"])])
	quit(0)
