import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'assets/shaders/modern/flare.gdshader'
rep(p, '''// MultiMesh (layer "flares"): instance transform''', '''// The full strength of the middle covers at least half a pixel diagonal of the 3D picture (the glow keeps its radius
// and never gets weaker anywhere): a lamp of a few pixels keeps its full strength in the pixel that holds it,
// wherever it falls between pixels - also in a 3D picture drawn below the window's resolution (3D scale of the
// presets, 75 % on "Niedrig"), where a brake light at 150 m otherwise faded to +0.07 red once the picture was scaled
// up (assembly of M1: no preset dims a lamp).
// MultiMesh (layer "flares"): instance transform''')
rep(p, '''	// Arcade's glow: 1 -> 0.55 over the first quarter of the radius, then linearly to 0 at the radius
	float t = length(v_quad) / max(v_r, 0.001);''', '''	// Arcade's glow: 1 -> 0.55 over the first quarter of the radius, then linearly to 0 at the radius - full strength
	// up to half a pixel diagonal of the 3D picture (px = logical px per pixel of the 3D picture)
	float px = logical_h / max(VIEWPORT_SIZE.y, 1.0);
	float o = min(0.7071 * px, 0.5 * v_r);
	float t = max(length(v_quad) - o, 0.0) / max(v_r - o, 0.001);''')
print('ok')
