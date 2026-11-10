class_name RaceRenderers
extends RefCounted
## Factory of the race renderers (v0.8.0, renderer seam of docs/dev/v080_contract.md §4.4.1): the race session
## draws a stage through one of two renderers with the same core interface –
##   setup(track, projection, cfg, scenery_db), render(view) every frame, perf_stats().
## "arcade" = RoadRenderer (pseudo-3D, Node2D, frozen since v0.7.0); "modern" = ModernRenderer (real 3D, Node3D,
## scripts/race3d/modern_renderer.gd), which adds apply_quality(levels), prepare(ctx), is_prepared(),
## prepare_progress(), healthy(), fail_reason(), debug_snapshot(), world_to_screen(z, x, h) and the signal
## quality_lowered(preset). The session calls the Modern-only methods through has_method("prepare").

const MODERN_SCRIPT := "res://scripts/race3d/modern_renderer.gd"

## Script of the Modern renderer. Tests of the seam point it to a probe (tests/race3d/fixtures/).
static var modern_script := MODERN_SCRIPT


## A new renderer node for `mode` (Gfx.ARCADE | Gfx.MODERN; anything else counts as Arcade). null when the Modern
## renderer cannot be loaded – the session then draws the stage in Arcade (result field gfx_fallback = "renderer").
## The Modern script is loaded at runtime: Arcade never touches the 3D code.
static func create(mode: String) -> Node:
	if mode != Gfx.MODERN:
		return RoadRenderer.new()
	if not ResourceLoader.exists(modern_script):
		return null
	var script: Variant = load(modern_script)
	if not (script is GDScript) or not (script as GDScript).can_instantiate():
		return null
	var node: Variant = (script as GDScript).new()
	if node is Node:
		return node
	if node is Object and not (node is RefCounted):
		(node as Object).free()
	return null
