import importlib.util, sys
Q = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5'
src = open(Q + '/tools/mutate.py').read()
src = src.replace('\nmain()\n', '\n')
ns = {}
exec(compile(src, 'mutate', 'exec'), ns)
for mid, f, old, new, filt, rule in ns['MUTS']:
    n = open(ns['MUT'] + '/' + f).read().count(old)
    print(mid, n)
