import os
S = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD'
p = os.path.join(S, 'jobsB.txt')
cur = [l.rstrip('\n') for l in open(p) if l.strip()]
lines = {l.split('|')[0]: l for l in cur}
head = cur[:9]
assert [l.split('|')[0] for l in head][-1] == 'KBN', head
done = set(l.split('|')[0] for l in head)
order = ['S0', 'ZIEL', 'S1_DECK', 'NUE12', 'KIEL22S', 'DEV', 'C1', 'T1', 'S5', 'N2_DECK', 'KHH195', 'GRZ', 'STBN',
         'GOT_EIN22', 'GOT_AUS', 'S4_LOW', 'N1_MED', 'T3', 'NUE195S', 'NUE08R', 'VAL', 'TS15', 'N2', 'T2', 'T4', 'KHH',
         'KIEL195', 'NUE22', 'DEVR', 'N1T', 'U1N', 'KHH22R', 'ZIEL22R', 'GOT_EIN', 'KIEL', 'KBNR', 'KHH22_DECK', 'KBT']
assert set(order) | done == set(lines), (set(order) | done) ^ set(lines)
open(p, 'w').write('\n'.join(head + [lines[k] for k in order]) + '\n')
print('ok', len(head) + len(order))
