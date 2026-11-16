import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(a, b, count=1):
    global s
    if s.count(a) < 1:
        raise SystemExit('NICHT GEFUNDEN: ' + a[:100].replace('\n', ' | '))
    s = s.replace(a, b, count)


rep('''    jclips = {}
    for name, lst in clips.items():
        jclips[name] = []
        for c in lst:
            jclips[name].append([put(c), len(c), MODE_ST])''', '''    jclips = {}
    for name, lst in clips.items():
        jclips[name] = []
        # clips of an engine with one exhaust image are the same on both channels: stored as mono, two per stereo
        # block, and panned by the mixer (layers.<clip>.pan) - half the size, and every pop gets its own place
        mono = name != "start" and all(np.array_equal(c[:, 0], c[:, 1]) for c in lst)
        if not mono:
            for c in lst:
                jclips[name].append([put(c), len(c), MODE_ST])
            continue
        for i in range(0, len(lst), 2):
            a = lst[i][:, 0]
            b = lst[i + 1][:, 0] if i + 1 < len(lst) else np.zeros(0)
            blk = np.zeros((max(len(a), len(b)), 2))
            blk[:len(a), 0] = a
            blk[:len(b), 1] = b
            at = put(blk)
            jclips[name].append([at, len(a), MODE_L])
            if len(b):
                jclips[name].append([at, len(b), MODE_R])''')
# the sports car keeps its load curve (130 km/h is on the plan with it)
rep('''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": 1.0, "idle_db": 0.0, "low_db": 0.0,
        "mix": {"in_gain": 1.15, "idle_load": 0.2, "load_curve": 0.8},''', '''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": 1.0, "idle_db": 0.0, "low_db": 0.0,
        "mix": {"in_gain": 1.15, "idle_load": 0.2, "load_curve": 0.65},''')
open(p, 'w', encoding='utf-8').write(s)
print('ok')
