import sys
p = sys.argv[1] + '/tests/race3d/check_landmarks.gd'
s = open(p).read()
old = '''	_need(p, props != null and bool(props.get("_skip_landmarks")), "builders/props.gd überlässt die Wahrzeichen dem Builder landmarks")
	_need(p, props != null and (props.get("_far") as Dictionary).is_empty(), "builders/props.gd stellt keine fernen Wahrzeichen auf")'''
new = '''	# the props builder draws none of them – neither in its chunks (its debug counts by set) nor beyond them (its far
	# stand-ins, if it still has that member)
	var lm_sets := {}
	for it: Dictionary in (trk.get("landmarks") as Array):
		lm_sets[str(it["set"])] = true
	var in_props := 0
	for c: Dictionary in ((r.call("debug_snapshot") as Dictionary).get("chunks", []) as Array):
		var part: Variant = (c.get("parts", {}) as Dictionary).get("props")
		if part is Dictionary:
			for k: String in ((part as Dictionary).get("counts", {}) as Dictionary):
				if lm_sets.has(k) and k.begins_with("landmarks/"):
					in_props += 1
	_need(p, in_props == 0, "builders/props.gd zeichnet kein Wahrzeichen in seinen Stücken (%d)" % in_props)
	var far: Variant = props.get("_far") if props != null else null
	_need(p, not (far is Dictionary) or (far as Dictionary).is_empty(), "builders/props.gd stellt keine fernen Wahrzeichen auf")'''
assert old in s
s = s.replace(old, new)
open(p, 'w').write(s)
print("ok")
