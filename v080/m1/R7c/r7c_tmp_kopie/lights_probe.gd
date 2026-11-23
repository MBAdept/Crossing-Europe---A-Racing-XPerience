extends SceneTree
## R7c scratch (never committed): palette "lights" over the hour (= ce_night of Modern, the light-layer alpha of Arcade).

func _initialize() -> void:
	var cfg: Dictionary = ConfigLoader.load_merged()
	var line := ""
	for h10 in range(160, 241, 5):
		var h := float(h10) / 10.0
		var p: Dictionary = Palette.compute(fmod(h, 24.0), "normal", ConfigLoader.lookup(cfg, "daytime", {}), false)
		line += "%.1f:%.2f  " % [h, float(p.get("lights", 0.0))]
	print("LIGHTS ", line)
	quit(0)
