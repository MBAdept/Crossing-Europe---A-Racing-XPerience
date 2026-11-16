root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'docs/renderer-modern.md'
s = open(p).read()
a = '''  in Kurven nicht mehr (120.852 von 199 Mio. Stichproben). Ab 30 m gibt es bis 260 m keinen Fall.
'''
b = '''  in Kurven nicht mehr (120.852 von 199 Mio. Stichproben). Ab 30 m gibt es bis 260 m keinen Fall.
  Ebenso die Tankspur (+ 7,5 m; gerechnet, als gäbe es sie überall): ein Ziel dort mit der Kamera in einer Spur 866
  Fälle bei 15 m, Ziele in den Spuren mit der Kamera auf der Tankspur 1.031 Fälle bei 15 m – jeweils bis drei Spuren
  quer, 6 m vor dem Wagen; von 30 bis 260 m kein Fall, bei 270 m einer bzw. zwei (je 99 Mio. Stichproben).
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
