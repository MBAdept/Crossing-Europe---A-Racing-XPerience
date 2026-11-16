import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'tests/race3d/check_modern_stage.gd'
rep(p, '''##   kern_zeit  GDScript time of the renderer core per frame of a drive at 150 km/h (render() with what this
##              package ships – no vehicle, prop or terrain layer – plus the backdrop's canvas drawing):
##              at most 0.6 ms on average, a chunk is committed in at most 3 ms (the best of three rounds: the
##              machine is shared)''', '''##   kern_zeit  GDScript time of the renderer core per frame of a drive at 150 km/h (render() with what this
##              package ships – no vehicle, prop or terrain layer – plus the backdrop's canvas drawing):
##              at most 0.6 ms on average, a chunk is committed in at most 3 ms (the best of three rounds: the
##              machine is shared). Since the assembly of M1 the shipped renderer also updates terrain, props,
##              signs, far ground, vehicles and flares every frame, so this check runs the core alone
##              (tests/race3d/fixtures/core_renderer.gd: road, roadside, backdrop, lights, overlay)''')
rep(p, '''const CORE_MS := 0.6
const COMMIT_MS := 3.0''', '''const CORE_MS := 0.6
const COMMIT_MS := 3.0
const CORE_FIXTURE := "res://tests/race3d/fixtures/core_renderer.gd"''')
rep(p, '''	var frames := 1500
	for round_i in 3:''', '''	var frames := 1500
	_renderers.set("modern_script", CORE_FIXTURE)
	for round_i in 3:''')
rep(p, '''		if best <= CORE_MS * 0.7 and best_commit <= COMMIT_MS * 0.7:
			break
	_need(p, best <= CORE_MS,''', '''		if best <= CORE_MS * 0.7 and best_commit <= COMMIT_MS * 0.7:
			break
	_renderers.set("modern_script", str(_renderers.get("MODERN_SCRIPT")))
	_need(p, best <= CORE_MS,''')
print('ok')
