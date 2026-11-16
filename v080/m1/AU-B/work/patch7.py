import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(a, b, count=1):
    global s
    if s.count(a) < 1:
        raise SystemExit('NICHT GEFUNDEN: ' + a[:100].replace('\n', ' | '))
    s = s.replace(a, b, count)


rep('''    def layer(self, parts: dict, names) -> np.ndarray:
        y = np.zeros_like(parts["exh"])
        for c in names:
            if c in parts and self.k.get(c, 0.0) != 0.0:
                y += self.k[c] * parts[c]
        return np.stack([_hp(y[:, 0]), _hp(y[:, 1])], axis=1)''', '''    def layer(self, parts: dict, names) -> np.ndarray:
        y = np.zeros_like(parts["exh"])
        for c in names:
            if c in parts and self.k.get(c, 0.0) != 0.0:
                y += self.k[c] * parts[c]
        y = np.stack([_hp(y[:, 0]), _hp(y[:, 1])], axis=1)
        fc = float(self.ch.get("mono_below_hz", 0.0))
        if fc > 0.0:
            # the low end in the centre: both channels carry the mean of the two below fc (zero phase). Two exhaust
            # systems of unequal length resonate at different rpm - on overrun one side of the V8 came out up to
            # 6 dB louder, and its fundamental pulled the image to that side.
            def low(x):
                return es.spectral_filter(x, lambda f: 1.0 / (1.0 + (np.asarray(f, float) / fc) ** 4))
            mid = low(0.5 * (y[:, 0] + y[:, 1]))
            y = np.stack([mid + y[:, 0] - low(y[:, 0]), mid + y[:, 1] - low(y[:, 1])], axis=1)
        return y''')
rep('''"nl": 1.5, "pan": "tailpipe", "width": 0.62, "noise": 0.9, "clip_pan": 0.0, "voice": [[330.0, 0.8, 5.0]],''',
    '''"nl": 1.5, "pan": "tailpipe", "width": 0.62, "mono_below_hz": 150.0, "noise": 0.9, "clip_pan": 0.0, "voice": [[330.0, 0.8, 5.0]],''')
rep('''#   width    pan width of the exhaust image; noise = independent share of the flow noise per channel (0..1)''',
    '''#   width    pan width of the exhaust image; noise = independent share of the flow noise per channel (0..1);
#            pan_from_hz ("group"): the cylinder banks are panned only above it; mono_below_hz: both channels carry
#            their mean below it (the low end stays in the centre)
#   voice    formants of the exhaust path [[Hz, Q, dB], ...] (give_voice)''')
rep('''                      "retune_db": ch["retune"], "nl_scale": ch["nl"], "voice": ch.get("voice", []), "ref_rpm": round(ref_rpm),''',
    '''                      "retune_db": ch["retune"], "nl_scale": ch["nl"], "voice": ch.get("voice", []),
                      "pan_from_hz": ch.get("pan_from_hz", 0.0), "mono_below_hz": ch.get("mono_below_hz", 0.0), "ref_rpm": round(ref_rpm),''')
open(p, 'w', encoding='utf-8').write(s)
print('ok')
