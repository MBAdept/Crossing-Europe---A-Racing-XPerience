extends SceneTree

func _initialize() -> void:
	var PC: GDScript = load("res://tests/race3d/fixtures/perf_clock.gd")
	var c: RefCounted = PC.new()
	for i in 400:
		c.call("sample_reference")
	var refs: Array = c.get("refs")
	var s := refs.duplicate()
	s.sort()
	print("REF n=%d min %.0f p10 %.0f median %.0f p90 %.0f max %.0f" % [s.size(), s[0], s[s.size() / 10], s[s.size() / 2], s[s.size() * 9 / 10], s[s.size() - 1]])
	quit()
