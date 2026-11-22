extends Node
## Main scene: hands control to the GameFlow autoload (menus or a direct debug start).


func _ready() -> void:
	GameFlow.boot.call_deferred()
