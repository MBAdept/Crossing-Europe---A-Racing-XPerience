import os
S = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD'
lines = {l.split('|')[0]: l.rstrip('\n') for l in open(os.path.join(S, 'jobsA.txt')) if l.strip() and not l.startswith('#')}
order = ['N1', 'N2N', 'U1', 'KHH22', 'TS15N', 'GRZN', 'VAL', 'STB', 'KBN', 'C1', 'DEV', 'S5', 'T1', 'T3', 'TS15', 'GRZ',
         'S0', 'ZIEL', 'KHH195', 'KIEL22S', 'NUE12', 'NUE195S', 'NUE08R', 'STBN', 'VALN', 'GOT_EIN22', 'GOT_AUS',
         'S1_DECK', 'N2_DECK', 'S4_LOW', 'N1_MED', 'N2', 'T2', 'T4', 'KHH', 'KIEL195', 'NUE22', 'DEVR', 'N1T', 'U1N',
         'KHH22R', 'ZIEL22R', 'GOT_EIN', 'KIEL', 'KBNR', 'KHH22_DECK', 'KBT']
base_keep = {'N1', 'N2N', 'KHH22'}
out = []
for k in order:
    f = lines[k].split('|')
    f[3] = '1' if k in base_keep else '0'
    out.append('|'.join(f))
print('missing', set(lines) - set(order) - {'S1', 'S2', 'S3', 'S4'})
open(os.path.join(S, 'jobsB.txt'), 'w').write('\n'.join(out) + '\n')
print(len(out))
