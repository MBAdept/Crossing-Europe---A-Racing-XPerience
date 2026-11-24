import sys
p = sys.argv[1] + '/tests/race3d/check_props_footprint.gd'
s = open(p, encoding='utf-8').read()
i0 = s.index('## Network check')
i1 = s.index('const Fair')
hdr = '''## Network check of contracts A-17 and A-24 for what the builders really draw (FIX-R7a, finding QR7a-01 of QA-R7a;
## RINT-M3): no prop taller than 0.5 m that the props builder may leave out stands with any part of its MODEL inside the
## envelope of the sight lines of a bend – not its foot, not the crown of a tree, not the near edge of an edge-aligned
## house, not a balcony beyond that edge; the props a model brings along ("attach_list") included.
## Builds the shipped ChunkStreamer in sync mode with the real props and city builders over whole stage directions
## and measures every drawn prop against the exact envelope (TerrainProfile.envelope_width(), computed on a path of
## its own over the whole stage; F7 of tests/sim/modern_sight.gd checks that envelope against an independent
## reference). The object (A-24, computed here from the model manifest, not through the builder's footprint()): the
## AABB of the union of the set's variant models, scaled, mirrored and turned by the yaw the builder placed it with
## (9th element of its list entry); an edge-aligned item reaches at least to its near edge (the set's extent); a
## stand-in without a model: half its width as crown, the extent when aligned. Along the road its whole extent, across
## the road the part nearest to the road; between two rows the larger envelope of the two (as
## ChunkContext.bend_intrusion()). Tolerance 5 cm.
##   godot --headless --path . -s res://tests/race3d/check_props_footprint.gd [-- --full] [--stage=<dir>,…] [--verbose]
## Normal run (gate of tools/run_tests.sh): six directions with the review positions T1–T4, C1, S0, S4 and the town
## bends (about 1 minute); --full: all 128 directions (about 5 minutes). Owner: the owner of builders/props.gd (A-24).
'''
s = s[:i0] + hdr + s[i1:]
s = s.replace('const QUICK :=', 'const MANIFEST := "res://assets/models/manifest.json"\nconst QUICK :=', 1)
old = '''	var t_all := Time.get_ticks_msec()
	var cfg := ConfigLoader.load_merged()'''
new = '''	var t_all := Time.get_ticks_msec()
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var aabbs := {}
	if man is Dictionary:
		for mid: String in ((man as Dictionary).get("models", {}) as Dictionary):
			var a: Array = (man["models"][mid] as Dictionary).get("aabb", [])
			if a.size() == 6:
				aabbs[mid] = a
	var cfg := ConfigLoader.load_merged()'''
assert old in s
s = s.replace(old, new, 1)
old = '''	var tot := {"props": 0, "checked": 0, "in": 0, "fixed": 0, "max_m": 0.0}'''
assert old in s
s = s.replace(old, '''	var tot := {"props": 0, "attached": 0, "checked": 0, "in": 0, "fixed": 0, "max_m": 0.0, "no_aabb": 0}''', 1)
old = '''				for e: Array in (ch["parts"] as Dictionary).get("props", {}).get("list", []):
					tot["props"] = int(tot["props"]) + 1
					var r := _judge(e, t, te, pb.library)'''
new = '''				var part: Dictionary = (ch["parts"] as Dictionary).get("props", {})
				var entries: Array = []
				for e: Array in part.get("list", []):
					entries.append([e, false])
				for e: Array in part.get("attach_list", []):
					entries.append([e, true])
					tot["attached"] = int(tot["attached"]) + 1
				for pair: Array in entries:
					var e: Array = pair[0]
					tot["props"] = int(tot["props"]) + 1
					var r := _judge(e, bool(pair[1]), t, te, pb.library, aabbs)'''
assert old in s
s = s.replace(old, new, 1)
old = '''					if r.is_empty():
						continue
					tot["checked"] = int(tot["checked"]) + 1'''
new = '''					if r.is_empty():
						continue
					tot["checked"] = int(tot["checked"]) + 1
					if bool(r.get("no_aabb", false)):
						tot["no_aabb"] = int(tot["no_aabb"]) + 1'''
assert old in s
s = s.replace(old, new, 1)
old = '''						print("FOOTPRINT %s km %.2f %s side %d: %.2f m in the envelope" % [dir["name"], t.z_to_km(float(e[4])), str(e[2]),
							int(r["side"]), float(r["depth"])])'''
new = '''						print("FOOTPRINT %s km %.2f %s%s side %d: %.2f m in the envelope (%s)" % [dir["name"], t.z_to_km(float(e[4])), str(e[2]),
							" (attached)" if bool(pair[1]) else "", int(r["side"]), float(r["depth"]), str(r["where"])])'''
assert old in s
s = s.replace(old, new, 1)
old = '''	print("FOOTPRINT %d directions, %d props drawn, %d measured (> 0.5 m beside the road): %d with their footprint in the envelope %s (deepest %.2f m); %d that the builder never leaves out (landmarks, stage events) (%.0f s)" % [
		dirs, int(tot["props"]), int(tot["checked"]), int(tot["in"]), str(by_cls), float(tot["max_m"]), int(tot["fixed"]),
		float(Time.get_ticks_msec() - t_all) / 1000.0])'''
new = '''	print("FOOTPRINT %d directions, %d props drawn (%d attached), %d measured (> 0.5 m beside the road; %d stand-ins without a model AABB): %d with their model in the envelope %s (deepest %.2f m); %d that the builder never leaves out (landmarks, stage events) (%.0f s)" % [
		dirs, int(tot["props"]), int(tot["attached"]), int(tot["checked"]), int(tot["no_aabb"]), int(tot["in"]), str(by_cls),
		float(tot["max_m"]), int(tot["fixed"]), float(Time.get_ticks_msec() - t_all) / 1000.0])'''
assert old in s
s = s.replace(old, new, 1)
j0 = s.index('## One drawn prop')
s = s[:j0] + open(sys.argv[2], encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s)
print("ok")
