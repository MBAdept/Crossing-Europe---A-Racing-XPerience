import sys
p = sys.argv[1] + '/scripts/race3d/builders/station.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''const SHOP_GLOW_ENERGY := 2.0 * 0.25 / 0.35''',
'''const SHOP_GLOW_ENERGY := 2.0 * 0.25 / 0.35
## … and the warm light of the shop's forecourt on the ground in front of it (FIX-R6, B-03 of QA-R6: at night Arcade's
## station glows warmly as a whole, Modern's shop stood dark): a lamp under its forecourt canopy with a light pool
## (layers/lights.gd: on the terrain, and one of its omni lights on the shop front when it is among the nearest)
const SHOP_POOL_AT := Vector3(-4.2, 3.4, -5.2)
const SHOP_POOL_R := 11.0
const SHOP_POOL_ENERGY := 1.1''')

rep('''				glows.append({"pos": fs * SHOP_GLOW_AT, "dir": fs.basis.z, "role": "lights", "color": SHOP_GLOW, "size": SHOP_GLOW_R / 0.9,
					"range": 0.0, "energy": SHOP_GLOW_ENERGY})''',
'''				glows.append({"pos": fs * SHOP_GLOW_AT, "dir": fs.basis.z, "role": "lights", "color": SHOP_GLOW, "size": SHOP_GLOW_R / 0.9,
					"range": 0.0, "energy": SHOP_GLOW_ENERGY})
				glows.append({"pos": fs * SHOP_POOL_AT, "dir": -fs.basis.y, "role": "lights", "color": SHOP_GLOW, "size": 0.3,
					"range": SHOP_POOL_R, "energy": SHOP_POOL_ENERGY})''')
open(p, 'w').write(s)
print('ok')
