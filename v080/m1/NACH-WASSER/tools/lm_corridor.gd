extends SceneTree
# NACH-WASSER: does the stand-in of a landmark without sprite and model (B1) stand inside the sight corridor of a bend
# (ChunkContext.in_bend_corridor – where Modern drops decorative scenery for fairness F7)? Footprint sampled from the
# near edge to the far edge of the stand-in billboard (extent of its fallback set x scale), for every approach.
# usage: godot --headless --path <project> -s lm_corridor.gd

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
			for l: Dictionary in t.landmarks:
				if str(l["set"]) != set_id:
					continue
				var k := int(floor(float(l["z"]) / t.seg_len))
				var ctx: ChunkContext = tp._ctx(t, k / 32)
				var b := Props.new()
				var inp: Dictionary = b.collect(ctx)
				var fb := str((inp["lm_fallback"] as Dictionary).get(set_id, ""))
				var e: Dictionary = (inp["sets"] as Dictionary).get(fb, {})
				var sc := float(l.get("scale", 1.0)) * float(l.get("fallback_scale", 1.0))
				var side := int(l.get("side", 1))
				var x_near := float(l.get("x", 0.0))
				var x := Props.edge_anchor_x(x_near, side, false, float(e["extent_l"]), float(e["extent_r"]), sc)
				var w := float(e["width"]) * sc
				var x_far := x + float(side) * (x - x_near) * 1.0 if absf(x - x_near) > 0.01 else x + float(side) * w * 0.5
				var inside := 0
				var n := 0
				for f in [0.0, 0.25, 0.5, 0.75, 1.0]:
					var xs := lerpf(x_near, x_far, f)
					for dz in [-10.0, 0.0, 10.0]:
						n += 1
						if ctx.in_bend_corridor(float(l["z"]) + dz, xs):
							inside += 1
				print("%-36s %-34s stand-in %s x%.2f: near %.1f anchor %.1f far %.1f m, width %.1f m, height %.1f m -> in bend corridor at %d of %d sample points" % [
					set_id, dir["name"], fb, sc, x_near, x, x_far, w, float(e["height"]) * sc, inside, n])
	quit(0)
