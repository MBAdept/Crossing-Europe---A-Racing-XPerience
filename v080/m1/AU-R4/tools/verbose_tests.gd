extends SceneTree
## AU-R4: runs chosen test methods of test_road_audio.gd and prints EVERY assertion with its message (pass or fail),
## so the measured values behind the new guards can be quoted in the report.
##   godot --headless --path <tree> -s <this> -- --tests=test_a,test_b


class Verbose:
	extends "res://tests/unit/audio_modern/test_road_audio.gd"

	func assert_true(cond: bool, msg: String = "") -> void:
		print(("  ok  " if cond else "  NO  ") + msg)
		super.assert_true(cond, msg)

	func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
		print(("  ok  " if actual == expected else "  NO  ") + "%s (ist %s)" % [msg, str(actual)])
		super.assert_eq(actual, expected, msg)

	func assert_near(actual: float, expected: float, eps: float = 0.001, msg: String = "") -> void:
		print(("  ok  " if absf(actual - expected) <= eps else "  NO  ") + "%s (ist %.4f, soll %.4f ± %.4f)" % [msg, actual, expected, eps])
		super.assert_near(actual, expected, eps, msg)

	func assert_between(actual: float, lo: float, hi: float, msg: String = "") -> void:
		print(("  ok  " if actual >= lo and actual <= hi else "  NO  ") + "%s (ist %.4f in [%.4f, %.4f])" % [msg, actual, lo, hi])
		super.assert_between(actual, lo, hi, msg)


func _initialize() -> void:
	var names := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tests="):
			names = a.substr(8)
	var t := Verbose.new()
	for n in names.split(","):
		print("== ", n)
		t.call("_reset", n)
		t.call(n)
		print("   failures: ", (t.get("_failures") as Array).size())
	quit(0)
