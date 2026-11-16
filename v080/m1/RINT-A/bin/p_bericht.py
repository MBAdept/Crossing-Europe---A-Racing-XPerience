"""Assembles deliver/RINT-A/bericht.md from the template (kept as bericht_template.md) and the drafts."""
import os
import re
import shutil

S = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A'
D = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/RINT-A'

tpl_path = S + '/bericht_template.md'
if not os.path.exists(tpl_path):
    shutil.copy(D + '/bericht.md', tpl_path)
tpl = open(tpl_path).read()


def rd(name):
    return open(S + '/' + name).read().strip('\n')


rest = rd('bericht_rest.md')
parts = re.split(r'^## [456]\. [^\n]*\n', rest, flags=re.M)
# parts[0] = '' (before "## 4."), [1] = deviations, [2] = plan problems, [3] = next
dev, ci, nxt = (p.strip('\n') for p in parts[1:4])

files = rd('files_bericht.md')

out = tpl
out = out.replace('__GATES__', rd('bericht_gates.md'))
out = out.replace('__ITEMS__', rd('bericht_items.md'))
out = out.replace('__LOOK__', rd('bericht_look.md'))
out = out.replace('__DEV__', dev)
out = out.replace('__CI__', ci)
out = out.replace('__NEXT__', nxt)
out = out.replace('__FILES__', files)
left = re.findall(r'__[A-Z]+__', out)
open(D + '/bericht.md', 'w').write(out)
print('bericht.md', len(out.splitlines()), 'Zeilen; offene Platzhalter:', left)
