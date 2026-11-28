extends Node
var n := 0
func _ready() -> void:
	var p := AudioStreamPlayer.new()
	var g := AudioStreamGenerator.new()
	add_child(p)
	print("display ", DisplayServer.get_name())
func _process(_d: float) -> void:
	n += 1
	if n == 30:
		print("frames ", n, " time ", Time.get_ticks_msec())
		get_tree().quit()
