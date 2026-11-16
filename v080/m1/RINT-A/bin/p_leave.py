import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'scripts/race/race_renderers.gd'
rep(p, '''## Leaving the mode "Modern" (contract §4.11, A-4): each mode holds only its own assets. When an Arcade renderer is
## created after a Modern one – the mode was switched, or a Modern stage fell back – the model database lets go
## of everything it still holds and the shared Modern materials (with their textures) are dropped. A run that
## never drew a Modern stage loads nothing for this; between two Modern stages nothing is released (the next
## stage would load and compile the same again).
static func leave_modern() -> void:
	if not modern_used:
		return
	modern_used = false''', '''## Leaving the mode "Modern" (contract §4.11, A-4) – the ONE place that releases what Modern loaded: each mode holds
## only its own assets. When an Arcade renderer is created after a Modern one – the mode was switched, or a Modern
## stage fell back – the model database lets go of everything it still holds and the shared Modern materials (with
## their textures) are dropped. A run that never drew a Modern stage loads nothing for this; between two Modern
## stages nothing is released (the next stage would load and compile the same again).
## always = true: also when no Modern renderer ran in this process – the menus call it when "Grafik" leaves
## Modern (the showroom loads models and materials as well) and when the game quits (GameFlow).
static func leave_modern(always: bool = false) -> void:
	if not modern_used and not always:
		return
	modern_used = false''')

p = 'scripts/ui/game_flow.gd'
rep(p, '''## Leaving the mode "Modern": the model caches and the shared materials (they hold the textures) go. The scripts
## are reached by path and only when something has loaded them – a game that never showed Modern loads nothing here.
func _release_modern(always: bool = false) -> void:
	if not always and Settings.is_modern():
		return
	if ResourceLoader.has_cached(MODEL_DB_SCRIPT):
		(load(MODEL_DB_SCRIPT) as GDScript).call("release_all")
	if ResourceLoader.has_cached(MATERIALS_SCRIPT):
		(load(MATERIALS_SCRIPT) as GDScript).call("drop_shared")''', '''## Leaving the mode "Modern": the model caches and the shared materials (they hold the textures) go – through
## RaceRenderers.leave_modern(), the one owner of that release (A-4). It reaches the scripts by path and only when
## something has loaded them – a game that never showed Modern loads nothing here.
func _release_modern(always: bool = false) -> void:
	if not always and Settings.is_modern():
		return
	RaceRenderers.leave_modern(true)''')
rep(p, '''## Scripts of the mode "Modern" whose caches go when the mode is left (_release_modern) – reached by path.
const MODEL_DB_SCRIPT := "res://scripts/core/model_db.gd"
const MATERIALS_SCRIPT := "res://scripts/race3d/modern_materials.gd"
''', '')
print('ok')
