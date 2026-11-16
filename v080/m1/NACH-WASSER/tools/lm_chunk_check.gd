extends SceneTree
# NACH-WASSER: for each landmark without sprite and model (the six of QA-WASSER B1) and for EVERY stage direction that
# ends in its city: does the props builder (39849f0) draw the stand-in in the landmark's chunk, or does it drop it?
# Uses the chunk-context helper of tests/unit/race3d/test_props.gd (same setup as the unit test of FIX-WASSER-R).
# usage: godot --headless --path <project> -s lm_chunk_check.gd

const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const TestProps := preload("res://tests/unit/race3d/test_props.gd")

const SIX := {"landmarks/hram_svetog_save": "belgrad", "landmarks/neues_rathaus_hannover": "hannover",
	"landmarks/voelkerschlachtdenkmal": "leipzig", "landmarks/florianturm": "dortmund",
	"landmarks/phare_calais": "calais", "landmarks/cuatro_torres": "madrid"}


func _init() -> void:
	var net := Fair.load_network()
	var cfg := ConfigLoader.load_merged()
	var tp = TestProps.new()
	var chunk_m := 32
	for set_id: String in SIX:
		var cid := str(SIX[set_id])
		for dir: Dictionary in Fair.directions(net):
			var st: Dictionary = dir["stage"]
			var to_id := str(st["to"]) if str(dir["from"]) == str(st["from"]) else str(st["from"])
			if to_id != cid:
				continue
			var plan := StagePlan.build(st, str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
			var t := Track.new()
			t.setup(plan, cfg, net["scenery"])
			var lm: Dictionary = {}
			for l: Dictionary in t.landmarks:
				if str(l["set"]) == set_id:
					lm = l
			if lm.is_empty():
				print("%-36s %-34s landmark not on this track" % [set_id, dir["name"]])
				continue
			var k := int(floor(float(lm["z"]) / t.seg_len))
			var ctx: ChunkContext = tp._ctx(t, k / chunk_m)
			var b := Props.new()
			var part: Dictionary = b.build(ctx, b.collect(ctx))
			var found := false
			for e: Array in part["list"]:
				var it: Dictionary = t.get_segment(int(e[0])).sprites[int(e[1])]
				if bool(it.get("landmark", false)) and str(it["set"]) == set_id:
					found = true
			# why not: the drop reason of the landmark item itself
			var why := ""
			if not found:
				var seg: Dictionary = ctx.segs[clampi(k - k / chunk_m * chunk_m, 0, ctx.row_count() - 1)]
				for it: Dictionary in seg["sprites"]:
					if bool(it.get("landmark", false)) and str(it["set"]) == set_id:
						var fb := str((b.collect(ctx) as Dictionary)["lm_fallback"].get(set_id, ""))
						var e2: Dictionary = (b.library.sets as Dictionary).get(fb, {})
						var sc := float(it.get("scale", 1.0)) * float(it.get("fallback_scale", 1.0))
						var x := Props.edge_anchor_x(float(it.get("x", 0.0)), int(it.get("side", 1)), false, float(e2.get("extent_l", 0.0)),
							float(e2.get("extent_r", 0.0)), sc)
						var row := clampi(int(floor(ctx.row_of(float(it["z"])))), 0, ctx.row_count() - 1)
						var beyond := absf(x) - ctx.shoulder_edge(row, int(it.get("side", 1)))
						why = "x %.1f, beyond shoulder %.1f m, ribbon %.1f m" % [x, beyond, ctx.ribbon_width(float(it["z"]), int(it.get("side", 1)))]
			print("%-36s %-34s km %6.1f side %2d x %6.1f  chunk: %s  dropped=%s %s" % [set_id, dir["name"], t.z_to_km(float(lm["z"])),
				int(lm.get("side", 0)), float(lm.get("x", 0.0)), "DRAWN" if found else "MISSING", str(part["dropped"]), why])
	quit(0)
