import sys
p = sys.argv[1] + '/tests/unit/race3d/test_structures.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''const N := 32
''', '''const N := 32
## Arcade's own values (frozen RoadRenderer), as literals: the tests guard the builders against them, not against the
## builders' own constants (finding B-04 of QA-R6).
const ARCADE_CANOPY_H := 5.6           ## RoadRenderer._fuel_structures: h0 of the canopy
const ARCADE_ROOF_H := 6.0             ## RoadRenderer._border_cover: h0 of the roof
const ARCADE_STREET_POOL := 0.55       ## RoadRenderer: a street light's pool 0.55 × lights at its centre
const LIGHTS_POOL_PER_ENERGY := 0.55   ## layers/lights.gd POOL_LEVEL: a pool of energy 1 adds 0.55 × lights at its centre
''')

rep('''			if rc.y > ed.x and rc.y < ed.y + 0.3 and rc.z > 0.05 and rc.z < StationB.CANOPY_H - StationB.LAMP_DROP - 1.0e-3:''',
    '''			if rc.y > ed.x and rc.y < ed.y + 0.3 and rc.z > 0.05 and rc.z < ARCADE_CANOPY_H - StationB.LAMP_DROP - 1.0e-3:''')
rep('''					and rc.z < BorderB.ROOF_H - BorderB.BAR_DROP - 0.02:      # (a rigid luminaire on a sloping road: ±1–2 cm)''',
    '''					and rc.z < ARCADE_ROOF_H - BorderB.BAR_DROP - 0.02:      # (a rigid luminaire on a sloping road: ±1–2 cm)''')
rep('''		assert_near(float(l["energy"]), CityB.LAMP_ENERGY, 1.0e-6, "Stärke wie Arcade")''',
    '''		assert_near(float(l["energy"]) * LIGHTS_POOL_PER_ENERGY, ARCADE_STREET_POOL, 1.0e-6, "Kegelmitte wie Arcade (0,55 × lights)")''')
open(p, 'w').write(s)
print('ok')
