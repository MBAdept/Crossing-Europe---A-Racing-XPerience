import os
S = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD'
p = os.path.join(S, 'pjobs2.txt')
cur = [l.rstrip('\n') for l in open(p) if l.strip()]
head = cur[:7]
assert head[6].startswith('head|DN|modern|high|'), head[6]
KH = '--stage=kiel_hamburg --from=kiel --vehicle=limousine --hour=12 --weather=normal --seed=7'
DN = '--stage=dev_testetappe --vehicle=limousine --hour=22 --weather=rain --seed=7'
rest = [
    'head|KH1|modern|deck|%s --timescale=1 --max-seconds=900' % KH,
    'head|DN1|modern|deck|%s --timescale=1 --max-seconds=900' % DN,
    'base|DN1|modern|deck|%s --timescale=1 --max-seconds=900' % DN,
    'base|KH1|modern|deck|%s --timescale=1 --max-seconds=900' % KH,
    'head|MEM|modern|high|--stage=bern_mailand --from=bern --start-km=100 --vehicle=limousine --hour=21 --weather=rain --seed=7 --timescale=4 --max-seconds=1200 --sample-s=20',
    'base|DN|modern|high|%s --timescale=40 --max-seconds=2700' % DN,
    'head|KH|modern|medium|%s --timescale=40 --max-seconds=2700' % KH,
    'head|KH|modern|low|%s --timescale=40 --max-seconds=2700' % KH,
    'head|KH2|modern|deck|%s --timescale=40 --max-seconds=2700' % KH,
    'base|KH|modern|medium|%s --timescale=40 --max-seconds=2700' % KH,
    'base|KH|modern|low|%s --timescale=40 --max-seconds=2700' % KH,
    'head|KH|arcade|-|%s --timescale=40 --max-seconds=2700' % KH,
    'head|DN|modern|low|%s --timescale=40 --max-seconds=2700' % DN,
    'head|DN|modern|medium|%s --timescale=40 --max-seconds=2700' % DN,
    'base|KH|modern|high|%s --timescale=40 --max-seconds=2700' % KH,
]
open(p, 'w').write('\n'.join(head + rest) + '\n')
print('ok', len(head) + len(rest))
