extends SceneTree
# NACH-WASSER: which props of the chunks between two km does the props builder (39849f0) leave out, and why?
# usage: godot --headless --path <project> -s drop_check.gd -- <stage>__<from> <km0> <km1>

const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const TestProps := preload("res://tests/unit/race3d/test_props.gd")


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var net := Fair.load_network()
	var cfg := ConfigLoader.load_merged()
	var tp = TestProps.new()
	for dir: Dictionary in Fair.directions(net):
		if str(dir["name"]) != a[0]:
			continue
		var st: Dictionary = dir["stage"]
		var plan := StagePlan.build(st, str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var c0 := int(floor(t.km_to_z(float(a[1])) / t.seg_len)) / 32
		var c1 := int(floor(t.km_to_z(float(a[2])) / t.seg_len)) / 32
		for ci in range(c0, c1 + 1):
			var ctx: ChunkContext = tp._ctx(t, ci)
			var b := Props.new()
			var inp: Dictionary = b.collect(ctx)
			var part: Dictionary = b.build(ctx, inp)
			var drawn := {}
			for e: Array in part["list"]:
				drawn["%d|%d" % [int(e[0]), int(e[1])]] = true
			print("chunk %d (km %.2f..%.2f): dropped %s" % [ci, t.z_to_km(ci * 32 * t.seg_len), t.z_to_km((ci + 1) * 32 * t.seg_len), str(part["dropped"])])
			for i in ctx.row_count() - 1:
				var seg: Dictionary = ctx.segs[i]
				var sprites: Array = seg["sprites"]
				for j in sprites.size():
					var it: Dictionary = sprites[j]
					if str(it.get("kind", "prop")) != "prop" or drawn.has("%d|%d" % [int(seg["index"]), j]):
						continue
					var set_id := str(it.get("set", ""))
					var e: Dictionary = (inp["sets"] as Dictionary).get(set_id, {})
					if e.is_empty():
						print("  not drawn: %s (no set entry)" % set_id)
						continue
					var side := int(it.get("side", 1))
					var x := float(it.get("x", 0.0))
					var sc := float(it.get("scale", 1.0))
					if it.has("align") and side != 0:
						x = Props.edge_anchor_x(x, side, false, float(e["extent_l"]), float(e["extent_r"]), sc)
					var z := float(it.get("z", seg["z"]))
					var why := Props.drop_reason(ctx, it, e, z, x, side, int(seg["index"]), j, 1.0, inp.get("cover", []))
					print("  not drawn: km %.2f %s side %d x %.1f offset=%s -> %s" % [t.z_to_km(z), set_id, side, x, str(it.has("offset")), why])
	quit(0)
