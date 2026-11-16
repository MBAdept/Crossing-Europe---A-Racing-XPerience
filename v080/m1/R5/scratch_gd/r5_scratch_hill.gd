extends SceneTree
## R5 scratch (not committed): portal-buffer vertices of Somport that lie inside the tube's volume.

func _initialize() -> void:
	var Fair: GDScript = load("res://tests/race3d/fairness.gd")
	var Tunnel: GDScript = load("res://scripts/race3d/builders/tunnel.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.call("load_network")
	for want: Array in [["saragossa_pau", "saragossa", "Somport-Tunnel"], ["bern_mailand", "bern", "Gotthard-Strassentunnel"]]:
		for dir: Dictionary in Fair.call("directions", net, [want[0]]):
			if str(dir["from"]) != str(want[1]):
				continue
			var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
			var t := Track.new()
			t.setup(plan, cfg, net["scenery"])
			var tu: Dictionary = {}
			for x: Dictionary in plan.tunnels:
				if str(x["name"]) == want[2]:
					tu = x
			var p := RoadPath3D.new()
			p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
			var tp := TerrainProfile.new()
			tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
			p.set_clear_reach(1842.0)
			var zp := float(ceili(t.km_to_z(float(tu["start_km"])) / t.seg_len - 1.0e-6)) * t.seg_len
			var b: Object = Tunnel.new()
			var ci := int(floor(zp / t.seg_len / 32.0))
			p.ensure(mini((ci + 2) * 32 + 700, t.segment_count - 1))
			var ctx := ChunkContext.new()
			ctx.cfg = cfg
			ctx.scenery_db = net["scenery"]
			ctx.levels = {"shadow_casters": 2}
			ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
			var part: Dictionary = b.call("build", ctx, b.call("collect", ctx))
			var arr: Array = part.get("portal", [])
			if arr.is_empty():
				print("%s: no portal in chunk %d" % [want[2], ci])
				continue
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var inside := 0
			var ex := []
			for k in range(0, idx.size(), 3):
				var hit := false
				for q in 3:
					var w := v[idx[k + q]] + ctx.origin
					# road coords by nearest path row
					var best := ci * 32
					var bd := INF
					for r in range(ci * 32 - 5, ci * 32 + 60):
						var d := absf((w - p.point(r)).dot(RoadPath3D.fwd_of(p.heading(r))))
						if d < bd:
							bd = d
							best = r
					var rel := w - p.point(best)
					var zz := float(best) * t.seg_len + rel.dot(RoadPath3D.fwd_of(p.heading(best)))
					var xx := rel.dot(RoadPath3D.right_of(p.heading(best)))
					var hh := rel.y
					if zz > zp + 1.0 and absf(xx) < 7.0 and hh > 0.3 and hh < 6.0:
						hit = true
						if ex.size() < 6:
							ex.append("tri %d: z+%.1f x %.1f h %.1f" % [k / 3, zz - zp, xx, hh])
				if hit:
					inside += 1
			print("%s: %d of %d portal triangles reach into the tube; %s" % [want[2], inside, idx.size() / 3, ex])
	quit(0)
