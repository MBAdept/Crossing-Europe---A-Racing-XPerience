extends Node3D
## Example layer of docs/renderer-modern.md §9.5 (file name = layer id, here "overlay"): a marker box that
## stands on the road 30 m in front of the player's car.

var _renderer: Node               # untyped: packages talk to each other through the facade only
var _marker: MeshInstance3D
var _material: StandardMaterial3D
var _pending := 0


func setup(renderer: Node) -> void:
	# every layer and builder exists by now; the path is not integrated yet (no positions before update())
	_renderer = renderer
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.9, 0.2, 0.1)
	_marker = MeshInstance3D.new()
	_marker.mesh = BoxMesh.new()
	_marker.material_override = _material
	(renderer.get("world") as Node3D).add_child(_marker)   # origin-relative world, identity transform


func apply_quality(levels: Dictionary) -> void:
	var casts := int(levels.get("shadow_casters", 0)) > 0
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func prepare(_ctx: Dictionary) -> void:
	_pending = 1      # e.g. ModelDB.request(...) – the stage does not start while prepare_pending() > 0


func prepare_pending() -> int:
	_pending = 0      # here: ready at the first poll
	return _pending


func warmup_nodes() -> Array:
	# a fresh node per shader variant: the renderer shows it for two frames behind the loading cover and frees it
	var probe := MeshInstance3D.new()
	probe.mesh = BoxMesh.new()
	probe.material_override = _material
	return [probe]


func update(view: Dictionary, _dt: float) -> void:
	# every frame, after the streamer and the camera; _dt is 0 while the stage is prepared
	var player: Dictionary = view["player"]
	_marker.position = _renderer.call("road_to_world", float(player["z"]) + 30.0, float(player["x"]), 0.5)


func perf() -> Dictionary:
	return {"instances": 1}


func snapshot() -> Dictionary:
	return {"props": {"overlay_marker": 1}}


func _exit_tree() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()      # it hangs under renderer.world, not under this layer
