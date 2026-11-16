import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(a, b, count=1):
    global s
    if s.count(a) < 1:
        raise SystemExit('NICHT GEFUNDEN: ' + a[:100].replace('\n', ' | '))
    s = s.replace(a, b, count)


rep('''ON_CURVE = [(0.0, -7.5), (0.12, -5.5), (0.28, -3.2), (0.5, -1.2), (0.7, -0.3), (0.85, 0.0), (1.0, 0.3), (1.2, 0.3)]
OFF_CURVE = [(0.0, -8.6), (0.12, -9.6), (0.28, -9.0), (0.5, -8.4), (0.75, -7.4), (1.0, -6.4), (1.2, -6.4)]''',
'''ON_CURVE = [(0.0, -6.0), (0.12, -4.0), (0.28, -2.0), (0.5, -0.8), (0.7, -0.2), (0.85, 0.0), (1.0, 0.3), (1.2, 0.3)]
OFF_CURVE = [(0.0, -9.0), (0.12, -9.4), (0.28, -8.8), (0.5, -8.4), (0.75, -7.4), (1.0, -6.4), (1.2, -6.4)]''')
rep('''        "retune": {"rasp": 4.0, "jet": 5.0, "intake": 6.0, "whoosh": 3.0, "mech": 3.0, "hiss": 3.0},''', '''        "retune": {"rasp": 1.5, "jet": 2.5, "intake": 6.0, "whoosh": 2.0, "mech": 3.0, "hiss": 2.0},''')
rep('''        "retune": {"rasp": 4.0, "jet": 6.0, "intake": 5.0, "whoosh": 5.0, "mech": 2.0, "hiss": 3.0},''', '''        "retune": {"rasp": 3.0, "jet": 4.0, "intake": 5.0, "whoosh": 5.0, "mech": 2.0, "hiss": 3.0},''')
rep('''        "mix": {"in_gain": 1.0, "idle_load": 0.2, "load_curve": 0.65},
        "saturation": 1.0, "turbo_depth": 0.25,''', '''        "mix": {"in_gain": 1.0, "idle_load": 0.2, "load_curve": 0.55},
        "saturation": 1.0, "turbo_depth": 0.25,''')
rep('''        "mix": {"in_gain": 1.0, "idle_load": 0.25, "load_curve": 0.65},''', '''        "mix": {"in_gain": 1.0, "idle_load": 0.25, "load_curve": 0.55},''')
rep('''        "mix": {"in_gain": 0.9, "idle_load": 0.2, "load_curve": 0.65},''', '''        "mix": {"in_gain": 0.9, "idle_load": 0.2, "load_curve": 0.55},''')
rep('''        "mix": {"in_gain": 1.0, "idle_load": 0.2, "load_curve": 0.65},
        "saturation": 1.25, "turbo_depth": 0.25,''', '''        "mix": {"in_gain": 1.0, "idle_load": 0.2, "load_curve": 0.55},
        "saturation": 1.25, "turbo_depth": 0.25,''')
open(p, 'w', encoding='utf-8').write(s)
print('ok')
