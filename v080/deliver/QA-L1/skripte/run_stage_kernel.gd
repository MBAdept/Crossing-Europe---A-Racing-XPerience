extends "res://tests/race/run_stage.gd"
## QA lens 1 (scratch): run_stage.gd with the Modern renderer replaced by tests/qa/kernel_renderer.gd.

func _initialize() -> void:
	var renderers: Variant = load("res://scripts/race/race_renderers.gd")
	(renderers as Object).set("modern_script", "res://tests/qa/kernel_renderer.gd")
	super._initialize()
