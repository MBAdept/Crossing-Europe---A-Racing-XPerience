import os
S = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD'
cur = [l.rstrip('\n') for l in open(os.path.join(S, 'jobsB.txt')) if l.strip()]
lines = {l.split('|')[0]: l for l in cur}
head = cur[:4]
assert [l.split('|')[0] for l in head] == ['N1', 'N2N', 'U1', 'KHH22'], head
order = ['TS15N', 'GRZN', 'VALN', 'STB', 'KBN', 'DEV', 'C1', 'S5', 'T1', 'GRZ', 'S0', 'ZIEL', 'NUE12', 'KIEL22S', 'KHH195',
         'STBN', 'GOT_EIN22', 'GOT_AUS', 'S1_DECK', 'N2_DECK', 'S4_LOW', 'N1_MED', 'T3', 'NUE195S', 'NUE08R', 'VAL', 'TS15',
         'N2', 'T2', 'T4', 'KHH', 'KIEL195', 'NUE22', 'DEVR', 'N1T', 'U1N', 'KHH22R', 'ZIEL22R', 'GOT_EIN', 'KIEL', 'KBNR',
         'KHH22_DECK', 'KBT']
assert set(order) | set(['N1', 'N2N', 'U1', 'KHH22']) == set(lines), set(lines) ^ (set(order) | set(['N1', 'N2N', 'U1', 'KHH22']))
open(os.path.join(S, 'jobsB.txt'), 'w').write('\n'.join(head + [lines[k] for k in order]) + '\n')
print('ok', len(head) + len(order))
