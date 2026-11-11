extends RefCounted
## Quality levels of the mode "Modern" that are states of the viewport and of the RenderingServer (v0.8.0, contract
## D1, D35, §4.10): MSAA 3D, 3D resolution scale (bilinear – the HUD stays sharp), size of the directional shadow
## atlas and the quality of the soft shadow filter. ModernRenderer sets them when a stage is prepared (apply) and
## puts back what was there when it leaves the tree (restore) – no project-wide render state survives a Modern
## stage, so Arcade draws the same picture before and after (render check "arcade_gleich").
## Everything else a level means belongs to whoever draws it: the environment rig (shadow splits and reach, glow,
## SSAO, sky reflections), builders and layers (shadow casters, LOD distances, densities, particle counts) – they
## get the same dictionary through their apply_quality() hook. No level thins out, shortens or dims anything the
## player has to react to (Rule 9).
## Also here: which values may still change once a stage is prepared – the step the slowness watchdog takes during
## the countdown (lowered). Shader variants are fixed for a stage (D10): shadow mode, split blending and filter
## quality stay as they were.
## Loaded by modern_renderer.gd only (no class name). Owner: renderer core (R1).

## Presets from the most to the least expensive; "deck" and "custom" step down to "low".
const STEPS := {"high": "medium", "medium": "low", "deck": "low", "custom": "low"}
## Keys of the levels a running stage keeps when the watchdog lowers the quality: they select shader variants.
const FIXED_KEYS: Array[String] = ["shadow_splits", "shadow_blend", "shadow_filter"]

var _viewport: Viewport
var _saved: Dictionary = {}
var applied: Dictionary = {}       ## what apply() set: {msaa, scale_3d, shadow_atlas, shadow_filter}


## Sets the viewport and RenderingServer states of `levels` (Gfx.levels). Headless nothing is drawn, the calls are
## harmless there.
func apply(viewport: Viewport, levels: Dictionary) -> void:
	if viewport == null:
		return
	if _saved.is_empty():
		_viewport = viewport
		_saved = {"msaa": viewport.msaa_3d, "scale": viewport.scaling_3d_scale, "mode": viewport.scaling_3d_mode,
			"atlas": int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)),
			"atlas_16": bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true)),
			"filter": int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2))}
	var msaa := msaa_mode(int(levels.get("msaa", 0)))
	var scale := clampf(float(levels.get("scale_3d", 1.0)), 0.25, 2.0)
	var atlas := clampi(int(levels.get("shadow_atlas", 2048)), 256, 16384)
	var filter := shadow_filter(int(levels.get("shadow_filter", 1)))
	viewport.msaa_3d = msaa
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = scale
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(filter)
	applied = {"msaa": int(levels.get("msaa", 0)), "scale_3d": scale, "shadow_atlas": atlas, "shadow_filter": int(levels.get("shadow_filter", 1))}


## Puts back what apply() found (leaving the mode "Modern").
func restore() -> void:
	if _saved.is_empty():
		return
	if is_instance_valid(_viewport):
		_viewport.msaa_3d = _saved["msaa"]
		_viewport.scaling_3d_mode = _saved["mode"]
		_viewport.scaling_3d_scale = _saved["scale"]
	RenderingServer.directional_shadow_atlas_set_size(int(_saved["atlas"]), bool(_saved["atlas_16"]))
	RenderingServer.directional_soft_shadow_filter_set_quality(int(_saved["filter"]) as RenderingServer.ShadowQuality)
	_saved = {}
	_viewport = null
	applied = {}


static func msaa_mode(samples: int) -> Viewport.MSAA:
	if samples >= 8:
		return Viewport.MSAA_8X
	if samples >= 4:
		return Viewport.MSAA_4X
	if samples >= 2:
		return Viewport.MSAA_2X
	return Viewport.MSAA_DISABLED


## levels.shadow_filter 0 hard, 1 soft low, 2 soft medium.
static func shadow_filter(level: int) -> RenderingServer.ShadowQuality:
	if level <= 0:
		return RenderingServer.SHADOW_QUALITY_HARD
	if level == 1:
		return RenderingServer.SHADOW_QUALITY_SOFT_LOW
	return RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM


## The preset one step below `preset` ("" when nothing lower is left).
static func lower_preset(preset: String) -> String:
	return str(STEPS.get(preset, ""))


## The levels of a running stage after the watchdog stepped down to the levels `target` of a lower preset: every
## value of the lower preset except those that select shader variants (FIXED_KEYS keep the stage's values).
static func lowered(current: Dictionary, target: Dictionary) -> Dictionary:
	var out := target.duplicate(true)
	for k: String in FIXED_KEYS:
		if current.has(k):
			out[k] = current[k]
	return out
