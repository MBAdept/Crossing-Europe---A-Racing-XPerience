extends SceneTree
func _initialize() -> void:
	var p := {}
	var base := Gfx.quality("medium", {}, p)
	for arg: String in ["scale=nan", "scale=inf", "scale=1e400", "scale=-1e400", "aa=1e30", "shadows=2.5", "shadows=2.49", "scale=92", "scale=93", "scale=58", "scale=59", "details=-0.4", "effects= 2 ,aa = 0", "scale=1e30", "scale=0x64", "shadows=1,shadows=3", "=3", "scale==75", "scale=75=1"]:
		print("QA-GFX --gfx=%-22s -> %s" % [arg, str(Gfx.with_cli(base, "", arg, p))])
	for pre: String in ["HIGH", " low", "low ", "custom", "deck"]:
		print("QA-GFX --gfx-preset='%s' -> %s" % [pre, str(Gfx.with_cli(base, pre, "", p)["preset"])])
	print("QA-GFX sanitized({scale: INF}) -> ", Gfx.sanitized({"scale": INF}), "  {scale: NAN} -> ", Gfx.sanitized({"scale": NAN}), "  {aa: 1e30} -> ", Gfx.sanitized({"aa": 1e30}), "  {aa: true} -> ", Gfx.sanitized({"aa": true}))
	print("QA-GFX levels of garbage: ", Gfx.levels({"preset": 5, "shadows": "x"}, {"levels": 7, "presets": []}).keys().size(), " keys; msaa of aa table [0, 3, 16]: ", Gfx.levels({"aa": 1}, {"levels": {"aa": [0, 3, 16]}})["msaa"], " / ", Gfx.levels({"aa": 2}, {"levels": {"aa": [0, 3, 16]}})["msaa"])
	for t: Array in [[10.0, 12.0, 16.67, false], [22.0, 25.0, 16.67, false], [34.0, 40.0, 16.67, false], [34.0, 40.0, 16.67, true], [16.0, 70.0, 16.67, false], [0.0, 0.0, 0.0, false], [5.0, 5.0, -1.0, true]]:
		print("QA-GFX watchdog median %.1f p95 %.1f target %.2f lowest %s -> %s" % [t[0], t[1], t[2], t[3], Gfx.watchdog_verdict(t[0], t[1], t[2], {}, t[3])])
	for a: Array in [["Apple M2", "Apple"], ["AMD Radeon RX 580 Series (radeonsi, polaris10, LLVM 15)", "AMD"], ["Radeon HD 7970", "ATI"], ["Intel(R) Arc(tm) A770 Graphics (DG2)", "Intel"], ["Mesa Intel(R) Iris(R) Xe Graphics (TGL GT2)", "Intel"], ["Intel(R) Iris(R) Plus Graphics 655", "Intel"], ["AMD Radeon(TM) Vega 8 Graphics", "ATI Technologies Inc."], ["NVIDIA GeForce GTX 1050 Ti/PCIe/SSE2", "NVIDIA Corporation"], ["GeForce 940MX/PCIe/SSE2", "NVIDIA Corporation"], ["NVIDIA GeForce 8600 GT", "NVIDIA"], ["virgl (AMD Radeon RX 6800)", "Mesa"], ["SVGA3D; build: RELEASE;  LLVM;", "VMware, Inc."], ["zink Vulkan 1.3(Intel(R) UHD Graphics 770 (ADL-S GT1))", "Mesa"], ["AMD Custom GPU 0405", "AMD"], ["Microsoft Basic Render Driver", "Microsoft"], ["Adreno (TM) 740", "Qualcomm"], ["AMD Radeon 780M (radeonsi, phoenix)", "AMD"]]:
		print("QA-GFX adapter %-62s -> %s (gamescope: %s)" % [a[0], Gfx.classify_adapter(a[0], a[1]), Gfx.classify_adapter(a[0], a[1], "", true)])
	quit(0)
