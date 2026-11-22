class_name BuilderRegistry
extends RefCounted
## Kernel of the mode "Modern" (v0.8.0): the fixed list of chunk builders and dynamic layers. Written once – a
## package adds its file under the name listed here and never edits this registry; a file that does not exist (yet)
## is skipped.
##
## Chunk builders (scripts/race3d/builders/<name>.gd, class extends ChunkBuilder), in build order:
##   road       asphalt, shoulders, curbs, sidewalks, fuel lane; all paint in the road shader
##   roadside   guardrails, posts, reflectors, delineators
##   terrain    ribbon rings, valley-floor edge
##   props      scenery props as MultiMesh (+ sprite stand-ins)
##   signs      signs on posts and tunnel walls
##   tunnel     tube, walkways, lamps, niches, portal, mound
##   bridge     deck, banks, railings, girders, pylons, lamps, water plane
##   station    fuel lane islands, canopies, pumps, shop, price pylon
##   border     roof, fascia, booths
##   city       street lights, fences / hedges / walls, crosswalk data
##   gantry     start gantry with countdown lamps, finish gantry
##   radar      radar posts and camera flash
##   landmarks  landmarks anchored on the path up to landmark_path_m
## Stand-in: while builders/road.gd does not exist, create_all() puts builders/debug_road.gd in its place (a plain
## vertex-colour road with the terrain rings) so that the kernel can be seen and tested on its own.
##
## Dynamic layers (scripts/race3d/layers/<name>.gd; each has setup(renderer), update(view, dt), snapshot()):
##   backdrop, far_ground, lights, vehicles, flares, weather, overlay, post
## Owner: race3d kernel. Docs: docs/renderer-modern.md.

const BUILDER_DIR := "res://scripts/race3d/builders/"
const LAYER_DIR := "res://scripts/race3d/layers/"
const BUILDERS: Array[String] = ["road", "roadside", "terrain", "props", "signs", "tunnel", "bridge", "station", "border",
	"city", "gantry", "radar", "landmarks"]
const LAYERS: Array[String] = ["backdrop", "far_ground", "lights", "vehicles", "flares", "weather", "overlay", "post"]
const DEBUG_ROAD := "debug_road"


static func builder_path(builder_name: String) -> String:
	return BUILDER_DIR + builder_name + ".gd"


static func layer_path(layer_name: String) -> String:
	return LAYER_DIR + layer_name + ".gd"


static func has_builder(builder_name: String) -> bool:
	return ResourceLoader.exists(builder_path(builder_name))


static func has_layer(layer_name: String) -> bool:
	return ResourceLoader.exists(layer_path(layer_name))


## A new instance of builder `builder_name`, or null when its file is missing, does not load or is not a ChunkBuilder.
static func create(builder_name: String) -> ChunkBuilder:
	var obj: Variant = _instance(builder_path(builder_name))
	if obj == null:
		return null
	if not (obj is ChunkBuilder):
		push_warning("BuilderRegistry: %s ist kein ChunkBuilder" % builder_path(builder_name))
		return null
	return obj


## Every existing builder in the fixed order. With debug_fallback the debug road stands in for a missing "road".
static func create_all(debug_fallback: bool = true) -> Array[ChunkBuilder]:
	var out: Array[ChunkBuilder] = []
	for n: String in BUILDERS:
		var b := create(n)
		if b == null and n == "road" and debug_fallback:
			b = create(DEBUG_ROAD)
		if b != null:
			out.append(b)
	return out


## Names of the builders whose files exist, in the fixed order.
static func existing_builders() -> Array[String]:
	var out: Array[String] = []
	for n: String in BUILDERS:
		if has_builder(n):
			out.append(n)
	return out


## A new instance of layer `layer_name` (any Object with setup / update / snapshot), or null when its file is missing
## or does not load.
static func create_layer(layer_name: String) -> Object:
	var obj: Variant = _instance(layer_path(layer_name))
	return obj if obj is Object else null


## Names of the layers whose files exist, in the fixed order.
static func existing_layers() -> Array[String]:
	var out: Array[String] = []
	for n: String in LAYERS:
		if has_layer(n):
			out.append(n)
	return out


static func _instance(path: String) -> Variant:
	if not ResourceLoader.exists(path):
		return null
	var script: Variant = load(path)
	if not (script is GDScript) or not (script as GDScript).can_instantiate():
		push_warning("BuilderRegistry: %s lässt sich nicht laden" % path)
		return null
	return (script as GDScript).new()
