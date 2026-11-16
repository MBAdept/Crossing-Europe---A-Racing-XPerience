import sys
W = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work'
sys.path.insert(0, W)
import e3an
d = sys.argv[1] if len(sys.argv) > 1 else 'r1'
prof = sys.argv[2] if len(sys.argv) > 2 else 'modern'
print('Auto          idle   revs   pull  cruise_hi  lift  brake cruise130 kickdn | idle-pull  c130-pull  chi-pull | min Korr  min Mono  max|R-L|  Knack')
for car in ('kompakt', 'kombi', 'limousine', 'sportwagen', 'gran_turismo'):
    p = W + '/%s/%s_%s_drive.wav' % (d, car, prof)
    r = {x['name']: x for x in e3an.phase_table(p)}
    x, sr, tr = e3an.read(p)
    w, hits = e3an.clicks(x, sr)
    print('%-12s %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f   | %6.1f    %6.1f    %6.1f   |  %5.2f    %5.2f    %5.2f   %4.1f %s' % (
        car, r['idle']['lufs'], r['revs']['lufs'], r['pull']['lufs'], r['cruise_hi']['lufs'], r['lift']['lufs'], r['brake']['lufs'],
        r['cruise_130']['lufs'], r['kickdown']['lufs'], r['idle']['lufs'] - r['pull']['lufs'], r['cruise_130']['lufs'] - r['pull']['lufs'],
        r['cruise_hi']['lufs'] - r['pull']['lufs'], min(v['corr'] for v in r.values()), min(v['mono'] for v in r.values()),
        max(abs(v['bal']) for v in r.values()), w, [float(h[0]) for h in hits][:3]))
