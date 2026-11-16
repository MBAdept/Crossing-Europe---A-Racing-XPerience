import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(a, b, count=1):
    global s
    if s.count(a) < 1:
        raise SystemExit('NICHT GEFUNDEN: ' + a[:100].replace('\n', ' | '))
    s = s.replace(a, b, count)


rep('''    one = turbo_tone(3000.0, 1.0, 9101)''', '''    one = turbo_tone(3000.0, LOOP_S, 9101)''')
rep('''    tl, tr = turbo_tone(2946.0, 1.0, 9111), turbo_tone(3063.0, 1.0, 9121)''', '''    tl, tr = turbo_tone(2946.0, LOOP_S, 9111), turbo_tone(3063.0, LOOP_S, 9121)''')
rep('''    hiss = _vnoise(VSR, 9131, lambda f: _bp(f, 2600.0, 9500.0, 2))''', '''    hiss = _vnoise(int(LOOP_S * VSR), 9131, lambda f: _bp(f, 2600.0, 9500.0, 2))''')
rep('''    n = VSR // 2
    t = np.arange(n) / VSR''', '''    n = int(LOOP_S * VSR)
    t = np.arange(n) / VSR''')
rep('''VSR = ml.SR
''', '''VSR = ml.SR
LOOP_S = 2.0                     # length of the loops (whole numbers of periods of their reference tones)
''')
open(p, 'w', encoding='utf-8').write(s)
print('ok')
