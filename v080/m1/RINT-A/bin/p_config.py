import os, json
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:70])
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'config/game_config.json'
rep(p, '''			"lights": {"spots": 2, "pools_lamps": 16, "pools_traffic": 6},
			"sky_update_s": 2.0,''', '''			"lights": {"spots": 2, "pools_lamps": 16, "pools_traffic": 6},
			"props": {"bend_cover": ["props/cover_bush", "props/cover_grass"], "bend_cover_max_h_m": 0.5},
			"sky_update_s": 2.0,''')
rep(p, '''lights (Scheinwerfer-Spots, Lichtkegel im Fahrbahn-Shader), sky_update_s''', '''lights (Scheinwerfer-Spots, Lichtkegel im Fahrbahn-Shader), props (bend_cover = Bodendecker-Sets, die im Sichtkorridor einer Kurveninnenseite an die Stelle weggelassener Pflanzen treten – Nachtrag A-3 –, höchstens bend_cover_max_h_m hoch; docs/renderer-modern-gelaende.md §4.1), sky_update_s''')
json.load(open(p))
print('ok')
