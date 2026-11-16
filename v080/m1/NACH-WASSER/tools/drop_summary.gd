extends SceneTree
# NACH-WASSER: per stage direction, which non-vegetation props the props builder (39849f0) leaves out ("corridor",
# "ribbon"), summed per set – quick count over whole stages (chunk context of tests/unit/race3d/test_props.gd).
# usage: godot --headless --path <project> -s drop_summary.gd -- <stage>__<from> ...

const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const TestProps := preload("res://tests/unit/race3d/test_props.gd")


func _init() -> void:
	var net := Fair.load_network()
	var cfg := ConfigLoader.load_merged()
	var tp = TestProps.new()
	var want: Array = []
	for a: String in OS.get_cmdline_user_args():
		want.append(a)
	for dir: Dictionary in Fair.directions(net):
		if not want.has(str(dir["name"])):
			continue
		var st: Dictionary = dir["stage"]
		var plan := StagePlan.build(st, str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var per_set := {}
		var veg := 0
		var b := Props.new()
		for ci in range(0, int(t.segment_count / 32)):
			var ctx: ChunkContext = tp._ctx(t, ci)
			var inp: Dictionary = b.collect(ctx)
			var part: Dictionary = b.build(ctx, inp)
			var drawn := {}
			for e: Array in part["list"]:
				drawn["%d|%d" % [int(e[0]), int(e[1])]] = true
			for i in ctx.row_count() - 1:
				var seg: Dictionary = ctx.segs[i]
				var sprites: Array = seg["sprites"]
				for j in sprites.size():
					var it: Dictionary = sprites[j]
					if str(it.get("kind", "prop")) != "prop" or drawn.has("%d|%d" % [int(seg["index"]), j]):
						continue
					var e: Dictionary = (inp["sets"] as Dictionary).get(str(it.get("set", "")), {})
					if not e.is_empty() and bool(e["veg"]):
						veg += 1
						continue
					var key := "%s (%s)" % [str(it.get("set", "")), "Stadt" if bool(seg.get("city", false)) else "Land"]
					per_set[key] = int(per_set.get(key, 0)) + 1
		print("%-34s vegetation left out: %d; other props left out: %s" % [dir["name"], veg, str(per_set)])
	quit(0)
