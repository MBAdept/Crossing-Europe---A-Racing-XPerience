import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'assets/shaders/modern/glass.gdshader'
rep(p, '''// default) = only the engine's reflection, as before; the vehicle layer sets the race value.
uniform vec4 env_zenith''', '''// default) = only the engine's reflection, as before; the vehicle layer sets the race value. ONE source (assembly
// of M1, as in vpbr.gdshader): with env_energy > 0 the engine's reflection of the Sky is kept out (SPECULAR 0).
uniform vec4 env_zenith''')
rep(p, '''	SPECULAR = mirror * mix(0.25, 1.0, smoothstep(0.08, 0.3, COLOR.a));''', '''	SPECULAR = env_energy > 0.0 ? 0.0 : mirror * mix(0.25, 1.0, smoothstep(0.08, 0.3, COLOR.a));''')
print('ok')
