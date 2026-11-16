#!/usr/bin/env python3
"""Fill the placeholders of deliver/QA-R5/bericht.md from the part files (keeps a template copy)."""
import os, shutil
Q = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5'
D = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R5/bericht.md'
T = Q + '/bericht_template.md'
if not os.path.exists(T):
    shutil.copy(D, T)
src = open(T).read()


def part(name):
    p = Q + '/part_' + name + '.md'
    return open(p).read().rstrip() + '\n' if os.path.exists(p) else '(fehlt: %s)\n' % name


gates = part('gates')
for k, v in [('__RETEST__', open(Q + '/part_retest.txt').read().strip() if os.path.exists(Q + '/part_retest.txt') else '(läuft)'),
             ('__GOLDEN__', '**„GOLDEN arcade: 20 von 20 identisch“**, **„GOLDEN arcade-ui: 17 von 17 identisch“** (gemessen, 227 s + 349 s)')]:
    gates = gates.replace(k, v)
tests = part('tests').replace('__GATES__', gates.rstrip())
befunde = part('befunde')
perf = Q + '/part_perf_finding.txt'
if os.path.exists(perf):
    sev, text, evid = open(perf).read().split('\n---\n')[:3]
    befunde = befunde.replace('__PERF_SEV__', sev.strip()).replace('__PERF_TEXT__', text.strip()).replace('__PERF_EVID__', evid.strip())
repl = {
    '__KURZ__': part('kurz'),
    '__GOLDEN__': 'Arcade bitgleich: `tools/golden.sh check` → **„GOLDEN arcade: 20 von 20 identisch“**, **„GOLDEN arcade-ui: 17 von 17 identisch“** (gemessen).',
    '__FAIR__': part('fair'),
    '__TESTS__': tests,
    '__BILDER__': part('bilder'),
    '__LEISTUNG__': part('leistung').replace('__PERFTABLE__', part('perftable_full').rstrip()),
    '__BEFUNDE__': '## 7. Befunde\n\n' + befunde + '\n' + part('vertrag'),
    '__OK__': part('ok'),
}
for k, v in repl.items():
    src = src.replace(k, v.rstrip())
open(D, 'w').write(src)
left = [k for k in ['__', ] if k in src]
print('written', D, len(src), 'chars; leftover placeholders:', src.count('__') // 2)
