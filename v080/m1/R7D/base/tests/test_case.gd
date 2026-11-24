class_name TestCase
extends RefCounted
## Base class for headless unit tests (tests/unit/test_*.gd). Every method starting with "test_" runs.
## Tests must not depend on autoloads: use cfg() for the configuration.

var _failures: Array[String] = []
var _current := ""


func _reset(test_name: String) -> void:
	_failures.clear()
	_current = test_name


## Merged central configuration (same as the game uses).
func cfg() -> Dictionary:
	return ConfigLoader.load_merged()


func fail(msg: String) -> void:
	_failures.append(msg)


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		fail("erwartet true: " + msg)


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		fail("erwartet false: " + msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		fail("%s: erwartet %s, ist %s" % [msg, str(expected), str(actual)])


func assert_near(actual: float, expected: float, eps: float = 0.001, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		fail("%s: erwartet %s ± %s, ist %s" % [msg, str(expected), str(eps), str(actual)])


func assert_between(actual: float, lo: float, hi: float, msg: String = "") -> void:
	if actual < lo or actual > hi:
		fail("%s: erwartet [%s, %s], ist %s" % [msg, str(lo), str(hi), str(actual)])
