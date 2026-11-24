extends "res://scripts/race3d/modern_renderer.gd"
## Test double of check_modern_stage "kern_zeit" (assembly of M1): the SHIPPED renderer with only what the renderer
## core (R1) ships – the builders road and roadside (the debug road's ribbon stands in for the terrain, as before the
## terrain existed) and the layers backdrop, lights and overlay. The builders and layers of the other packages
## (terrain, props, signs …; far ground, vehicles, flares) are left out: their GDScript time is not the core's, each
## package measures its own. Static choice, so the check script sets RaceRenderers.modern_script to this file before
## the session creates the renderer.
## Owner: assembly (tests only).

const CORE_BUILDERS: Array[String] = ["road", "roadside"]
const CORE_LAYERS: Array[String] = ["backdrop", "lights", "overlay"]


func _create_builders() -> Array[ChunkBuilder]:
	var out: Array[ChunkBuilder] = []
	for n: String in CORE_BUILDERS:
		var b := BuilderRegistry.create(n)
		if b != null:
			out.append(b)
	var ribbon := BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD)
	if ribbon != null:
		ribbon.set("road_strips", false)
		out.append(ribbon)
	return out


func _layer_script(id: String) -> String:
	return BuilderRegistry.layer_path(id) if CORE_LAYERS.has(id) else ""
