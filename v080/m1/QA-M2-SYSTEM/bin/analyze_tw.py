#!/usr/bin/env python3
"""Per-phase numbers of the tyre/wind/UI captures (tyrewind/tw_*.wav + .json): RMS/LUFS-ish level, spectrum bands,
true peak; for UI sounds: peak, true peak, onset step and the level of the last 5 ms before silence (click check)."""
import json
import sys
import numpy as np

sys.path.insert(0, '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4/tools/audio/qc')
import qc_lib as q  # noqa: E402

D = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM/tyrewind'
BANDS = [(20, 160), (160, 630), (630, 2500), (2500, 10000), (10000, 20000)]


def bands_db(x, sr):
    m = x.mean(axis=1) if x.ndim == 2 else x
    if len(m) < 2048:
        return [float('nan')] * len(BANDS)
    spec = np.abs(np.fft.rfft(m * np.hanning(len(m)))) ** 2
    f = np.fft.rfftfreq(len(m), 1.0 / sr)
    out = []
    for a, b in BANDS:
        s = spec[(f >= a) & (f < b)].sum()
        out.append(10 * np.log10(s / len(m) + 1e-20))
    return out


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(x.astype(np.float64) ** 2)) + 1e-12)


for name in sys.argv[1:] or ['tw_wind', 'tw_skid', 'tw_ui']:
    try:
        x, sr = q.read_wav(f'{D}/{name}.wav')
        info = json.load(open(f'{D}/{name}.json'))
    except Exception as e:  # noqa: BLE001
        print(name, 'FEHLT', e)
        continue
    print(f'== {name}: {len(x) / sr:.2f} s, sr {sr}, json {info["seconds"]} s, TP gesamt {q.true_peak_db(x):.2f} dBTP')
    for p in info['phases']:
        a, b = int(p['t0'] * sr), int(p['t1'] * sr)
        seg = x[a:b]
        if len(seg) < 100:
            print('  ', p['name'], 'leer')
            continue
        line = f'  {p["name"]:<12} {p["t0"]:6.2f}-{p["t1"]:6.2f} s  RMS {rms_db(seg):7.2f} dBFS'
        if len(seg) > sr * 0.4:
            try:
                line += f'  LUFS {q.integrated_lufs(seg, sr):7.2f}'
            except Exception:  # noqa: BLE001
                pass
        line += f'  TP {q.true_peak_db(seg):6.2f}'
        if name != 'tw_ui':
            line += '  Bänder ' + ' '.join(f'{v:6.1f}' for v in bands_db(seg, sr))
        else:
            m = np.abs(seg).max(axis=1) if seg.ndim == 2 else np.abs(seg)
            thr = 10 ** (-60 / 20)
            idx = np.nonzero(m > thr)[0]
            if len(idx):
                on, off = idx[0], idx[-1]
                step = float(np.abs(np.diff(seg[on:on + 3], axis=0)).max()) if on + 3 < len(seg) else 0
                tail = seg[max(on, off - int(0.005 * sr)):off + 1]
                line += (f'  Dauer {(off - on) / sr * 1000:6.0f} ms  Einsatz-Sprung {20 * np.log10(step + 1e-12):6.1f} dB'
                         f'  letzte 5 ms {rms_db(tail):6.1f} dBFS  Spitze {20 * np.log10(m.max()):6.1f}')
            else:
                line += '  STILL'
        print(line)
