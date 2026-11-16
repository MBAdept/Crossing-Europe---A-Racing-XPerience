extends SceneTree
## Scratch: prints what the plain light law shows on level ground against Arcade's colour.

const PE := preload("res://scripts/race3d/plain_environment.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var daytime: Dictionary = ConfigLoader.lookup(cfg, "daytime", {})
	for hour: float in [6.0, 7.0, 8.5, 12.0, 13.0, 15.0, 17.5, 19.0, 19.5, 20.0, 21.0, 23.0]:
		for weather: String in ["normal", "rain", "snow"]:
			var pal := Palette.compute(hour, weather, daytime, false)
			var st := PE.light_state(pal, false, 0.0, 0.0)
			var p: Color = pal["ambient"]
			var line := "%5.1f %-6s share %.3f elev %4.1f night %.2f |" % [hour, weather, float(st["share"]), rad_to_deg(asin((st["to_sun"] as Vector3).y)), float(pal["night"])]
			for albedo: float in [0.2, 0.3, 0.45, 0.6, 0.75, 0.9]:
				var worst := 0.0
				for ch in 3:
					var a := PE.engine_to_linear(albedo)
					var amb: Color = st["ambient"]
					var sun: Color = st["sun"]
					var ndl := maxf((st["to_sun"] as Vector3).y, 0.0)
					var got: float = PE.engine_show(a * amb[ch]) + PE.engine_show(a * sun[ch] * ndl)
					var want: float = albedo * p[ch]
					var e := (got - want) / want
					if absf(e) > absf(worst):
						worst = e
				line += " %.2f:%+5.1f%%" % [albedo, worst * 100.0]
			print(line)
	quit(0)
