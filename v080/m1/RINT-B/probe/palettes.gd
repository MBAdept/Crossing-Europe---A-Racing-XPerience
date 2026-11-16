extends SceneTree
## Dump Palette.compute for the reference conditions (ambient, fog, sky, lights) as JSON lines.

func _initialize() -> void:
	var cfg: Dictionary = ConfigLoader.load_merged()
	var daytime: Variant = ConfigLoader.lookup(cfg, "render.daytime", {})
	if not daytime is Dictionary:
		daytime = {}
	for c in [[12.0, "normal"], [19.5, "normal"], [22.0, "normal"], [22.0, "snow"], [22.0, "rain"], [16.0, "rain"], [15.0, "normal"], [11.0, "normal"]]:
		var p: Dictionary = Palette.compute(float(c[0]), str(c[1]), daytime)
		var out := {"hour": c[0], "weather": c[1]}
		for k in p:
			var v: Variant = p[k]
			if v is Color:
				out[k] = [snappedf(v.r, 0.0001), snappedf(v.g, 0.0001), snappedf(v.b, 0.0001)]
			elif v is float or v is int or v is bool:
				out[k] = v
			elif v is Vector2:
				out[k] = [v.x, v.y]
		print(JSON.stringify(out))
	quit()
