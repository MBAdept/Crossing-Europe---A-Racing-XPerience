root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'docs/renderer-modern.md'
s = open(p).read()
a = '''  Tunnelwände verdecken in Kurven in beiden Modi gleich (Sichtweite etwa √(8 · R · halbe Röhrenbreite)).
'''
b = '''  Tunnelwände verdecken in Kurven in beiden Modi gleich weit (abgeleitet, nicht gemessen: die Sichtlinie an der
  Innenwand vorbei reicht in der gescherten wie in der echten Röhre etwa √(8 · R · halbe Röhrenbreite), bei
  R = 134 m und 6 m also rund 80 m).
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
