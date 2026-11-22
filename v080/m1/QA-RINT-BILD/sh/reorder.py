"""reorder.py : put the sections of bericht.md in order 0,1,2,3,4,5,6,7 and move the F-xx blocks written after
section 4 into section 5 (sorted by number)."""
import re
D = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-RINT-BILD/bericht.md'
s = open(D).read()
parts = re.split(r'\n(?=## )', s)
head = parts[0]
secs = {}
for p in parts[1:]:
    m = re.match(r'## (\d+)\.', p)
    key = int(m.group(1)) if m else 99
    secs.setdefault(key, []).append(p)
# section 4 may carry F-blocks at its end (written after it): split them off
findings = []
for key in list(secs):
    new = []
    for p in secs[key]:
        sub = re.split(r'\n(?=### F-\d\d)', p)
        new.append(sub[0])
        findings.extend(sub[1:])
    secs[key] = new
order = lambda f: int(re.match(r'### F-(\d\d)', f).group(1))
findings.sort(key=order)
# rebuild section 5: its header text (first part) + all findings
sec5_head = secs[5][0].rstrip('\n')
secs[5] = [sec5_head + '\n\n' + '\n\n'.join(f.strip('\n') for f in findings) + '\n']
out = head.rstrip('\n') + '\n'
for key in sorted(secs):
    for p in secs[key]:
        out += '\n' + p.strip('\n') + '\n'
open(D, 'w').write(out)
print([k for k in sorted(secs)], len(findings), [order(f) for f in findings])
