import sys
p = 'tools/audio/modern/engine_synth3.py'
s = open(p, encoding='utf-8').read()


def rep(a, b, count=1):
    global s
    if a not in s:
        print('NICHT GEFUNDEN:', a[:70].replace('\n', ' | '))
        sys.exit(1)
    s = s.replace(a, b, count)


# 1. Clips: one mono model with the retuned levels, sharing the solved transfer functions of the centre model
rep('''    def __init__(self, sc: StereoCar):
        self.sc = sc

    def _run(self, fn, *args) -> list:''', '''    def __init__(self, sc: StereoCar):
        self.sc = sc
        self.mono = None
        if sc.mode != "tailpipe":
            self.mono = es.CarModel(sc.car)
            self.mono.op = dict(sc.mc.op)
            self.mono.cal = dict(sc.mc.cal, k=sc.k)
            self.mono._tf_cache = sc.mc._tf_cache      # same networks, solved once

    def _run(self, fn, *args) -> list:''')
rep('''            m = es.CarModel(self.sc.car)
            m.op = dict(self.sc.mc.op)
            m.cal = dict(self.sc.mc.cal, k=self.sc.k)
            r = fn(m, *args)
            return r if isinstance(r, list) else [r]''', '''            r = fn(self.mono, *args)
            return r if isinstance(r, list) else [r]''')

# 2. file scale folded into the gains
rep('''        file_scale = 10.0 ** ((-1.1 - tp) / 20.0)
        data = data * file_scale
''', '''        file_scale = 10.0 ** ((-1.1 - tp) / 20.0)
        data = data * file_scale
        for jb in jbanks:
            jb["gain"] = round(jb["gain"] / file_scale, 6)
''')
rep('''"mix": dict({"gain": 1.0, "off_gain": 1.0, "file_scale": round(file_scale, 6)}, **ch["mix"]),''',
    '''"mix": dict({"gain": 1.0, "off_gain": 1.0, "clip_gain": round(1.0 / file_scale, 6)}, **ch["mix"]),''')
rep('''"gain": "factor that restores the designed level of a bank (stored at full scale)",''',
    '''"gain": "factor that restores the designed level of a bank (stored at full scale); clips: mix.clip_gain",''')

# 3. manifest entry without a qc override
rep('''        e = man.add(car, f"{car}.i16", "bank", GENERATOR, bus="MEngine",
                    note="Zyklenbank Motor v3 (ce-engine-bank-2): Zyklen und Clips hintereinander, kein abspielbarer Klang")
        e["qc"] = {"dc_max": -40.0}
''', '''        man.add(car, f"{car}.i16", "bank", GENERATOR, bus="MEngine",
                note="Zyklenbank Motor v3 (ce-engine-bank-2): Zyklen und Clips hintereinander, kein abspielbarer Klang")
''')
rep('''    man = ml.Manifest("engines", out)
    for car in cars:''', '''    man = ml.Manifest("engines", out)
    man.drop_generator(GENERATOR)
    for car in cars:''')
rep("INTERNAL_LUFS = -20.0 ", "INTERNAL_LUFS = -18.0 ")

# 4. put(): designed signal in, stored at peak 0.5, gain_db restores the designed scale
a = s.index('    def put(sid: str, x: np.ndarray, kind: str, unit: float, note: str, variants: list | None = None) -> None:')
b = s.index('    # turbo: one charger (mono)')
new_put = '''    def put(sid: str, designed, kind: str, note: str) -> None:
        """designed = the sound (or the list of its variants) in the engine's own scale for a runtime level of 1."""
        many = isinstance(designed, list)
        vs = [np.asarray(v, float) for v in (designed if many else [designed])]
        unit = max(float(np.max(np.abs(v))) for v in vs)
        names = []
        loop = None
        for i, v in enumerate(vs):
            name = f"{sid}_{'abcdef'[i]}.wav" if many else f"{sid}.wav"
            ml.write_wav16(man.file(name), v * (peak / unit))
            loop = (0, len(v)) if kind == "loop" else None
            if repo:
                ml.write_wav_import(man.file(name), loop)
            names.append(name)
        man.add(sid, names if many else names[0], kind, GENERATOR, loop=loop, bus="MEngineFx",
                gain_db=round(20.0 * math.log10(unit / peak), 2), note=note)

'''
s = s[:a] + new_put + s[b:]
rep('''put("turbo_single", one, "loop", float(np.max(np.abs(one))), "Laderton, ein Lader; Bezug 3000 Hz")''',
    '''put("turbo_single", one, "loop", "Laderton, ein Lader; Bezug 3000 Hz")''')
rep('''put("turbo_twin", twin, "loop", float(np.max(np.abs(twin))), "Ladertöne, zwei Lader links/rechts (0,982 / 1,021); Bezug 3000 Hz")''',
    '''put("turbo_twin", twin, "loop", "Ladertöne, zwei Lader links/rechts (0,982 / 1,021); Bezug 3000 Hz")''')
rep('''put("turbo_hiss", hiss, "loop", float(np.max(np.abs(hiss))), "Strömungsrauschen des Verdichters (Effektivwert 1 im Entwurf)")''',
    '''put("turbo_hiss", hiss, "loop", "Strömungsrauschen des Verdichters (Effektivwert 1 im Entwurf)")''')
rep('''put("driveline_whine", wh, "loop", float(np.max(np.abs(wh))), "Zahneingriffston; Bezug 1000 Hz")''',
    '''put("driveline_whine", wh, "loop", "Zahneingriffston; Bezug 1000 Hz")''')
rep('''put("tipin", None, "oneshot", max(float(np.max(np.abs(v))) for v in vs), "Gasannahme: Ansaugschlucken und Lastwechselschlag", vs)''',
    '''put("tipin", vs, "oneshot", "Gasannahme: Ansaugschlucken und Lastwechselschlag")''')
rep('''put("shift_thump", None, "oneshot", max(float(np.max(np.abs(v))) for v in vs), "Lastwechselschlag beim Schalten", vs)''',
    '''put("shift_thump", vs, "oneshot", "Lastwechselschlag beim Schalten")''')
rep('''        pk = max(float(np.max(np.abs(v))) for v in vs)
        if len(vs) == 1:
            put(sid, vs[0], "oneshot", 2.0 * pk, notes[sid])
        else:
            put(sid, None, "oneshot", 2.0 * pk, notes[sid], vs)''', '''        pk = max(float(np.max(np.abs(v))) for v in vs)
        vs = [v * (0.5 / pk) for v in vs]
        put(sid, vs if len(vs) > 1 else vs[0], "oneshot", notes[sid])''')
open(p, 'w', encoding='utf-8').write(s)
print('ok')
