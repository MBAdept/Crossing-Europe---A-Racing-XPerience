import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(a, b, count=1):
    global s
    if s.count(a) < 1:
        raise SystemExit('NICHT GEFUNDEN: ' + a[:100].replace('\n', ' | '))
    s = s.replace(a, b, count)


# --- per-car level shape: idle_db and low_db on top of the common curves -------------------------------------------
rep('''def curve(table, x: float) -> float:
    return float(np.interp(x, [a for a, _ in table], [b for _, b in table]))''',
    '''def curve(table, x: float) -> float:
    return float(np.interp(x, [a for a, _ in table], [b for _, b in table]))


def level_target(ch: dict, layer: str, x: float) -> float:
    """Target loudness of a bank in dB re the car's full load: the common curve of its layer plus the car's own
    shape - "idle_db" lifts both layers at idle (gone at x = 0.12), "low_db" the load layer in the lower third of
    the rev range (full between x = 0.12 and 0.28, gone at idle and at x = 0.5)."""
    t = curve(ch[layer], x)
    t += float(ch.get("idle_db", 0.0)) * float(np.interp(x, [0.0, 0.12], [1.0, 0.0]))
    if layer == "on":
        t += float(ch.get("low_db", 0.0)) * float(np.interp(x, [0.0, 0.12, 0.28, 0.5], [0.0, 1.0, 1.0, 0.0]))
    return t''')
rep('''            target = curve(ch[name], b["x"]) + keep * (b["lev"] - float(fv))''', '''            target = level_target(ch, name, b["x"]) + keep * (b["lev"] - float(fv))''')
rep('''#   on / off target loudness of the banks in dB re the car's full load over x = (rpm - idle) / (redline - idle)
#   loudness full-throttle loudness of the car relative to the plan's target (all five stay within +-1.5 dB)''',
    '''#   on / off target loudness of the banks in dB re the car's full load over x = (rpm - idle) / (redline - idle);
#            idle_db / low_db shape them per car (level_target) - set with the game recordings of the loudness plan
#            (tools/audio/modern/capture_mix.gd): idle about 8 dB under full throttle, 130 km/h at the plan's level
#   loudness full-throttle loudness of the car relative to INTERNAL_LUFS, set the same way (full throttle of every
#            car at the plan's -16 LUFS with all bus levels at 0 dB)''')
rep('''INTERNAL_LUFS = -18.0            # designed full-load loudness of the Gran Turismo inside the mixer (before the bus)''',
    '''INTERNAL_LUFS = -16.0            # designed full-load loudness of a car inside the mixer (before the buses), plus its "loudness"''')

# --- values of round 2 ------------------------------------------------------------------------------------------
rep('''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": -0.2,
        "mix": {"in_gain": 1.0, "idle_load": 0.2, "load_curve": 0.55},''', '''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": 0.5, "idle_db": 2.0, "low_db": 1.5,
        "mix": {"in_gain": 1.0, "idle_load": 0.2, "load_curve": 0.5},''')
rep('''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": -1.0,
        "mix": {"in_gain": 1.0, "idle_load": 0.25, "load_curve": 0.55},''', '''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": -0.5, "idle_db": 3.9, "low_db": 2.0,
        "mix": {"in_gain": 1.0, "idle_load": 0.25, "load_curve": 0.45},''')
rep('''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": -0.5,
        "mix": {"in_gain": 0.9, "idle_load": 0.2, "load_curve": 0.55},''', '''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": -0.3, "idle_db": 3.4, "low_db": 2.5,
        "mix": {"in_gain": 0.9, "idle_load": 0.2, "load_curve": 0.4},''')
rep('''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": 0.5,
        "mix": {"in_gain": 1.15, "idle_load": 0.2, "load_curve": 0.65},''', '''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": 1.0, "idle_db": 0.0, "low_db": 0.0,
        "mix": {"in_gain": 1.15, "idle_load": 0.2, "load_curve": 0.8},''')
rep('''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": 0.8,
        "mix": {"in_gain": 1.0, "idle_load": 0.2, "load_curve": 0.55},''', '''        "on": ON_CURVE, "off": OFF_CURVE, "loudness": 0.2, "idle_db": 2.6, "low_db": 1.0,
        "mix": {"in_gain": 1.0, "idle_load": 0.2, "load_curve": 0.55},''')
open(p, 'w', encoding='utf-8').write(s)
print('ok')
