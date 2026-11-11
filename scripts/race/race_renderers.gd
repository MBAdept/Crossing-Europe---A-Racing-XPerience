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
## A Modern renderer was created in this run and its assets may still be held (leave_modern()).
static var modern_used := false
## What leaving the mode "Modern" releases: [script, static function]. Called through the scripts' paths – this file
## is loaded by every Arcade start and must not name a class of the Modern renderer or the model database.
const MODERN_RELEASE: Array = [["res://scripts/core/model_db.gd", "release_all"], ["res://scripts/race3d/modern_materials.gd", "drop_shared"]]


## A new renderer node for `mode` (Gfx.ARCADE | Gfx.MODERN; anything else counts as Arcade). null when the Modern
## renderer cannot be loaded – the session then draws the stage in Arcade (result field gfx_fallback = "renderer").
## The Modern script is loaded at runtime: Arcade never touches the 3D code.
static func create(mode: String) -> Node:
	if mode != Gfx.MODERN:
		leave_modern()
		return RoadRenderer.new()
	if not ResourceLoader.exists(modern_script):
		return null
	var script: Variant = load(modern_script)
	if not (script is GDScript) or not (script as GDScript).can_instantiate():
		return null
	var node: Variant = (script as GDScript).new()
	if node is Node:
		modern_used = true
		return node
	if node is Object and not (node is RefCounted):
		(node as Object).free()
	return null


## Leaving the mode "Modern" (contract §4.11, A-4): each mode holds only its own assets. When an Arcade renderer is
## created after a Modern one – the mode was switched, or a Modern stage fell back – the model database lets go
## of everything it still holds and the shared Modern materials (with their textures) are dropped. A run that
## never drew a Modern stage loads nothing for this; between two Modern stages nothing is released (the next
## stage would load and compile the same again).
static func leave_modern() -> void:
	if not modern_used:
		return
	modern_used = false
	for entry: Array in MODERN_RELEASE:
		var path := str(entry[0])
		if not ResourceLoader.has_cached(path):
			continue
		var script: Variant = load(path)
		if script is GDScript:
			(script as GDScript).call(StringName(str(entry[1])))
