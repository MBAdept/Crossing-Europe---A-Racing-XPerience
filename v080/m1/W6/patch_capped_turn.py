# W6: apply the turn cap to scripts/race3d/builders/landmarks.gd (run from the worktree after the gates)
p = "scripts/race3d/builders/landmarks.gd"
s = open(p).read()
old = '''	var t := face_heading(a, from, origin)
	var basis := heading_basis(t, Vector3(mx, sc, sc))'''
new = '''	var t := capped_turn(a, face_heading(a, from, origin), box, side, Vector3(mx, sc, sc))
	var basis := heading_basis(t, Vector3(mx, sc, sc))'''
assert s.count(old) == 1
s = s.replace(old, new)
old = '''## Footprint of a model in its own space: the box of its drawn parts (not the shadow caster, not a billboard).'''
new = '''## The heading `t` towards the approach, turned back towards the road's heading `a` as far as needed so that
## near_shift() stays within MAX_NODE_SHIFT_M (Welle 6, AS6): a long footprint turned to its approach swings its far
## end towards the road – the Milan cathedral (158 m) was moved 26.7 m from Arcade's anchor, the Atomium 15.9 m. Such
## a landmark then shows a little of its side in the bend instead. Bisection on the share of the turn (the move grows
## with it); a footprint that stays within the limit keeps its whole turn. s: the node's scale (x < 0 mirrors).
static func capped_turn(a: float, t: float, box: AABB, side: int, s: Vector3) -> float:
	var along := heading_basis(a, s)
	if near_shift(along, heading_basis(t, s), box, a, side) <= MAX_NODE_SHIFT_M:
		return t
	var lo := 0.0
	var hi := 1.0
	for i in 24:
		var mid := (lo + hi) * 0.5
		if near_shift(along, heading_basis(a + (t - a) * mid, s), box, a, side) <= MAX_NODE_SHIFT_M:
			lo = mid
		else:
			hi = mid
	return a + (t - a) * lo


## Footprint of a model in its own space: the box of its drawn parts (not the shadow caster, not a billboard).'''
assert s.count(old) == 1
s = s.replace(old, new)
open(p, "w").write(s)
print("capped_turn applied")
s = open(p).read()
old = '''## the turn to the approach moves it away from the road by near_shift(); measured network-wide at most 11.89 m (a church
## of Bremen – Amsterdam, turned 10.6°), checked by test_landmarks "test_anchor_and_mirror_like_arcade_network_wide"'''
new = '''## the turn to the approach moves it away from the road by near_shift(); measured network-wide at most 11.89 m (a church
## of Bremen – Amsterdam, turned 10.6°) before AS6; since the long AS6 models capped_turn() turns a footprint only as far
## as the node may move. Checked by test_landmarks "test_drawn_node_stays_near_arcades_anchor_network_wide"'''
assert s.count(old) == 1
s = s.replace(old, new)
open(p, "w").write(s)
print("comment updated")
