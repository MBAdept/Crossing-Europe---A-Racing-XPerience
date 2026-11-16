p = 'scripts/race/race_session.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old[:80])
    s = s.replace(old, new)


rep('''## - only the HUD icons are loaded as sprite sheets – the vehicle, prop and landmark sheets stay unloaded.
''', '''## - only the HUD icons are loaded as sprite sheets – the vehicle, prop and landmark sheets stay unloaded;
## - the renderer's slowness watchdog may step the quality preset down one step during the countdown (signal
##   quality_lowered): the HUD says so, gfx_lowered and the result field of that name carry the preset.
''')
rep('''## start_towed; v0.8.0 gfx and, after a fallback from Modern to Arcade, gfx_fallback).
''', '''## start_towed; v0.8.0 gfx, after a fallback from Modern to Arcade gfx_fallback, after a step-down of the quality
## preset by the slowness watchdog gfx_lowered).
''')
rep('''var gfx_fallback := ""
''', '''var gfx_fallback := ""
## Quality preset the Modern renderer's slowness watchdog stepped down to during the countdown ("" = it did not):
## "medium" | "low". For this stage only – nothing is stored; result field (the result screens may offer to keep it).
var gfx_lowered := ""
''')
rep('''	renderer = r
	add_child(r)
	move_child(r, 0)
	renderer.setup(track, proj, cfg, GameData.scenery)
''', '''	renderer = r
	add_child(r)
	move_child(r, 0)
	renderer.setup(track, proj, cfg, GameData.scenery)
	if mode == Gfx.MODERN and r.has_signal(&"quality_lowered"):
		r.connect(&"quality_lowered", _on_quality_lowered)
''')
rep('''func _show_fallback_message() -> void:
''', '''## Modern: the slowness watchdog of the renderer stepped the quality preset down (once, during the countdown).
func _on_quality_lowered(preset: String) -> void:
	gfx_lowered = preset
	var names := {"low": tr("Niedrig"), "medium": tr("Mittel"), "high": tr("Hoch"), "deck": tr("Steam Deck")}
	if hud != null:
		hud.show_message(tr("Das Bild läuft zu langsam – die Grafikqualität ist für diese Etappe auf „%s“ gesenkt.") % str(names.get(preset, preset)),
			"warn", 6.0)


func _show_fallback_message() -> void:
''')
rep('''	if gfx_fallback != "":
		r["gfx_fallback"] = gfx_fallback   # Modern was wanted, Arcade drew the stage: why
''', '''	if gfx_fallback != "":
		r["gfx_fallback"] = gfx_fallback   # Modern was wanted, Arcade drew the stage: why
	if gfx_lowered != "":
		r["gfx_lowered"] = gfx_lowered     # the slowness watchdog stepped the quality preset down to this one
''')
open(p, 'w').write(s)

p = 'scripts/race/race_renderers.gd'
s = open(p).read()
rep('''## Script of the Modern renderer. Tests of the seam point it to a probe (tests/race3d/fixtures/).
static var modern_script := MODERN_SCRIPT
''', '''## Script of the Modern renderer. Tests of the seam point it to a probe (tests/race3d/fixtures/).
static var modern_script := MODERN_SCRIPT
## A Modern renderer was created in this run and its assets may still be held (leave_modern()).
static var modern_used := false
## What leaving the mode "Modern" releases: [script, static function]. Called through the scripts' paths – this file
## is loaded by every Arcade start and must not name a class of the Modern renderer or the model database.
const MODERN_RELEASE: Array = [["res://scripts/core/model_db.gd", "release_all"], ["res://scripts/race3d/modern_materials.gd", "drop_shared"]]
''')
rep('''static func create(mode: String) -> Node:
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
''', '''static func create(mode: String) -> Node:
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
''')
s += '''

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
'''
open(p, 'w').write(s)
print("ok")
