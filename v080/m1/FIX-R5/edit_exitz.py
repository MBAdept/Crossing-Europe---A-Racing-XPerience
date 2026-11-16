import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6')
p = 'scripts/race3d/builders/tunnel.gd'
s = open(p, encoding='utf-8').read()
old = '''var tunnel_state: Dictionary = {}  ## {"amount", "inside", "exit_m", "portal_m", "exit_in_sight", "light"}: read by tests and the rig'''
new = '''var tunnel_state: Dictionary = {}  ## {"amount", "inside", "exit_m", "exit_z", "portal_m", "exit_in_sight", "light"}: read by tests and the rig
## "exit_z" (FIX-R5): road z where the tube really ends – at the segment boundary after the tunnel's end_km, as Arcade's
## tunnel segments end (INF outside a tunnel); the frame of the exit stands from exit_z − 0.35 m to exit_z. exit_m is
## measured to the plan's end_km (up to one segment earlier): an exposure quad at the opening belongs at exit_z, not
## there (with R4's glare quad at end_km − 0.6 m the last metres of the tube and the exit frame were over-exposed).'''
assert old in s
s = s.replace(old, new)
old = '''	var exit_m := INF
	if not t.is_empty():
		exit_m = track.km_to_z(float(t["end_km"])) - cam_z
'''
new = '''	var exit_m := INF
	var exit_z := INF
	if not t.is_empty():
		exit_m = track.km_to_z(float(t["end_km"])) - cam_z
		exit_z = float(ceili(track.km_to_z(float(t["end_km"])) / track.seg_len - 1.0e-6)) * track.seg_len
'''
assert old in s
s = s.replace(old, new)
old = '''	tunnel_state = {"amount": amount, "inside": not t.is_empty(), "exit_m": exit_m, "portal_m": portal_m,'''
new = '''	tunnel_state = {"amount": amount, "inside": not t.is_empty(), "exit_m": exit_m, "exit_z": exit_z, "portal_m": portal_m,'''
assert old in s
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)

p = 'tests/unit/race3d/test_tunnel.gd'
s = open(p, encoding='utf-8').read()
old = '''	assert_near(float(st.get("exit_m", 0.0)), t.km_to_z(float(tu["end_km"])) - z0 - 100.0, 0.01, "Weg bis zur Ausfahrt")
'''
new = '''	assert_near(float(st.get("exit_m", 0.0)), t.km_to_z(float(tu["end_km"])) - z0 - 100.0, 0.01, "Weg bis zur Ausfahrt")
	assert_near(float(st.get("exit_z", 0.0)), _exit_z(t, tu), 0.01, "exit_z: wo die Röhre endet (Segmentgrenze, Rahmen der Ausfahrt)")
'''
assert old in s
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)

p = 'docs/renderer-modern.md'
s = open(p, encoding='utf-8').read()
old = '''  `exit_in_sight` (Ausfahrt innerhalb der Sicht) – für eine Belichtungsrampe an der Ausfahrt, ohne eigene Rechnung;'''
new = '''  `exit_in_sight` (Ausfahrt innerhalb der Sicht) – für eine Belichtungsrampe an der Ausfahrt, ohne eigene Rechnung;
  `exit_z` (FIX-R5) = Straßen-z, an dem die Röhre wirklich endet (Segmentgrenze nach `end_km`, wie Arcades
  Tunnelsegmente; INF draußen) – der Rahmen der Ausfahrt steht von `exit_z` − 0,35 m bis `exit_z`; eine Belichtungsfläche
  an der Öffnung gehört dorthin, nicht an `end_km` (das bis zu ein Segment früher liegt);'''
assert old in s
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('ok')
