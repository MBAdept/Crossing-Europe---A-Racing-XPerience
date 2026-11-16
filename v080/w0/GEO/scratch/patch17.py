root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'

# --- path check: the true spacing of 32-bit floats at that coordinate ------------------------------------------
p = root + 'tests/sim/modern_path_check.gd'
s = open(p).read()
a = '''		far_m / 1000.0, far_name, far_m * pow(2.0, -23.0) * 1000.0])
'''
b = '''		far_m / 1000.0, far_name, pow(2.0, floorf(log(maxf(far_m, 1.0)) / log(2.0)) - 23.0) * 1000.0])
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)

# --- docs ----------------------------------------------------------------------------------------------------
p = root + 'docs/renderer-modern.md'
s = open(p).read()
a = '''| größte Koordinate eines echten Pfads (Bukarest – Sibiu ab Sibiu) | 20,2 km → 2,4 mm Raster ohne Verlegen (abgeleitet) |
'''
b = '''| größte Koordinate eines echten Pfads ab seinem Start (Belgrad – Budapest ab Budapest; `modern_path_check.gd -- --full`) | 37,8 km → 3,9 mm Raster der 32-Bit-Zahlen ohne Verlegen (abgeleitet) |
'''
assert a in s
s = s.replace(a, b)
a = '''bestätigt die Schranke (53 s gemessen).
'''
b = '''bestätigt die Schranke (53–56 s gemessen).
'''
assert a in s
s = s.replace(a, b)
a = '''| `modern_path_check.gd -- --full` | ganzes Netz gerechnet, dazu freie Breite und Stückzahl | 53 s |
'''
b = '''| `modern_path_check.gd -- --full` | ganzes Netz gerechnet, dazu freie Breite, Stückzahl und größte Koordinate | 53–56 s |
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
