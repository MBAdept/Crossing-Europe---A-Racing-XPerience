extends "res://tests/race3d/render/check_landmarks_render.gd"
## scratch: heading of the backdrop per frame around the start (Kassel)

func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	CliArgs.all().erase("graphics")
	var sc: Node = await _launch("modern", {"stage_id": "hannover_kassel", "from_city": "hannover", "start_km": 148.5})
	var n := 0
	while n < 2000:
		var r: Object = sc.get("renderer")
		if r != null and r.has_method("layer") and r.call("layer", "backdrop") != null:
			var snap: Dictionary = ((r.call("layer", "backdrop") as Object).call("snapshot") as Dictionary).get("backdrop", {})
			var env: Variant = r.get("env")
			var st: Dictionary = (env as Object).get("state") if env != null else {}
			var view: Dictionary = r.get("view")
			print("F %d prepared %s live %s heading %.4f road %.4f bg %.4f sky %s" % [n, str(r.call("is_prepared")), str(sc.call("is_live")),
				float(snap.get("heading", 0.0)), float(st.get("heading", 0.0)), float(view.get("bg_offset", 0.0)), str(snap.get("skyline"))])
			if bool(sc.call("is_live")):
				n += 100
		await process_frame
		n += 1
		if n > 400:
			break
	quit(0)
