import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
pairs = [
('''##   bremslicht     brake light by day at 50, 150 and 300 m: braking lights the rear (more red than the tail lamp
##                  alone, Arcade's glow strength 0.35) at every distance''',
 '''##   bremslicht     brake light by day at 50, 150 and 300 m: braking lights the rear (more red than the tail lamp
##                  alone, Arcade's glow strength 0.35) at every distance
##   sichtgrenze    F4/F5 and Arcade's fog of sprites (FIX1, QA QB-07/QB-11): a dark car at the end of the sight
##                  (0.995 × visibility) changes its footprint by less than 3 % contrast; at 0.839 × visibility (where
##                  the simulation counts it as seen) the pixels it still covers keep at least half the contrast they
##                  have at the fog begin (0.45 × visibility) – Arcade tints a sprite by 0.7 × the fog amount towards
##                  its own colour × the fog colour, the engine's depth fog had left about 30 %'''),
('''const CHECKS := ["blinker", "ruecklicht_n1", "bremslicht"]''',
 '''const CHECKS := ["blinker", "ruecklicht_n1", "bremslicht", "sichtgrenze"]'''),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:60]
    s = s.replace(old, new)
s += open(sys.argv[2], encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s)
print('ok')
