P = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/tests/unit/audio_modern/check_modern_audio.gd"
s = open(P, encoding="utf-8").read()


def rep(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old)
    s = s.replace(old, new)


rep('''	var before := _counts()
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var max_children := 0
''', '''	var before := _counts()
	# generator streams are held for two seconds after their player went (ModernAudioContext.keep_alive): not leaks
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - ModernAudioContext.kept_count()
	var max_children := 0
''')
rep('''	var objects_after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var diff := _arcade_diff()
	var ok := after == before and diff.is_empty() and objects_after <= objects + 8 and (max_children > 0) == _live
	_check("switch_20", ok, "20 × arcade ↔ modern (%s): Knoten %d → %d, Busse %d → %d, Kinder des AudioManagers %d → %d, verwaiste Knoten %d → %d, Objekte %d → %d; Arcade-Busse wie in v0.7.0%s" % [
		"mit bis zu %d Playern" % max_children if _live else "ohne Wiedergabe", before["nodes"], after["nodes"], before["buses"],
		after["buses"], before["children"], after["children"], before["orphans"], after["orphans"], objects, objects_after,
		"" if diff.is_empty() else " NICHT: " + "; ".join(diff.slice(0, 3))])''', '''	var kept := ModernAudioContext.kept_count()
	var objects_after := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - kept
	var diff := _arcade_diff()
	var ok := after == before and diff.is_empty() and objects_after <= objects + 8 and (max_children > 0) == _live
	_check("switch_20", ok, "20 × arcade ↔ modern (%s): Knoten %d → %d, Busse %d → %d, Kinder des AudioManagers %d → %d, verwaiste Knoten %d → %d, Objekte %d → %d%s; Arcade-Busse wie in v0.7.0%s" % [
		"mit bis zu %d Playern" % max_children if _live else "ohne Wiedergabe", before["nodes"], after["nodes"], before["buses"],
		after["buses"], before["children"], after["children"], before["orphans"], after["orphans"], objects, objects_after,
		" (ohne %d noch gehaltene Generator-Streams)" % kept if kept > 0 else "",
		"" if diff.is_empty() else " NICHT: " + "; ".join(diff.slice(0, 3))])''')
open(P, "w", encoding="utf-8").write(s)
print("ok")
