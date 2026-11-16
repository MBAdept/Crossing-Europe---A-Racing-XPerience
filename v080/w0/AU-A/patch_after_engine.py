"""arcade_after: the cycle bank both profiles played from still gives the v0.7.0 mixer output (SHA-256)."""
R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("tests/unit/audio_modern/golden/arcade_golden.gd", [
    ('''## Seeded mixer output of one bank: {samples, sha256, peak, rms} (or {error}).
static func engine_hash(bank_path: String, mixer_seed: int = SEED) -> Dictionary:
	var b := EngineBank.load_file(bank_path)
	if not b.ok():
		return {"error": str(b.errors)}
	var e := EngineAudio.new(b, mixer_seed)
''', '''## Seeded mixer output of one bank: {samples, sha256, peak, rms} (or {error}).
static func engine_hash(bank_path: String, mixer_seed: int = SEED) -> Dictionary:
	var b := EngineBank.load_file(bank_path)
	if not b.ok():
		return {"error": str(b.errors)}
	return engine_hash_bank(b, mixer_seed)


## The same for a bank that is loaded already (e.g. the one the AudioManager caches and every profile plays from).
static func engine_hash_bank(b: EngineBank, mixer_seed: int = SEED) -> Dictionary:
	var e := EngineAudio.new(b, mixer_seed)
'''),
])

patch("tests/unit/audio_modern/check_modern_audio.gd", [
    ('''var _golden: Array = []
''', '''var _golden: Array = []
var _golden_engine: Dictionary = {}   ## car -> {samples, sha256, …} of the seeded Arcade mixer output in v0.7.0
'''),
    ('''	_golden = (g as Dictionary).get("buses", []) if g is Dictionary else []
''', '''	_golden = (g as Dictionary).get("buses", []) if g is Dictionary else []
	_golden_engine = (g as Dictionary).get("engine", {}) if g is Dictionary else {}
'''),
    ('''	var ok := str(_am.call("profile")) == "arcade" and _modern() == null and names_ok and close
	_check("arcade_after", ok, "nach allem: Profil Arcade, %d Busse mit Sends, Pegeln und Effekten wie in v0.7.0 (%s)%s%s" % [now.size(), golden_file,
		"" if notes.is_empty() else " – abweichend: " + ", ".join(notes),
		"" if strict.is_empty() else "; nach dem Arcade-Rennen ruhen %d Raumklang-/Filterwerte neben dem Startwert (wie in v0.7.0)" % strict.size()])''',
     '''	# the cycle bank both profiles played from (the AudioManager's cached object) still gives the seeded mixer
	# output of v0.7.0, sample for sample
	var bank: Variant = _am.call("bank_for", "limousine")
	var eh: Dictionary = _tool.call("engine_hash_bank", bank) if bank != null else {}
	var want_engine: Dictionary = _golden_engine.get("limousine", {})
	var engine_ok := eh.has("sha256") and str(eh["sha256"]) == str(want_engine.get("sha256", "?"))
	var ok := str(_am.call("profile")) == "arcade" and _modern() == null and names_ok and close and engine_ok
	_check("arcade_after", ok, "nach allem: Profil Arcade, %d Busse mit Sends, Pegeln und Effekten wie in v0.7.0 (%s)%s%s; Motor-Mischer mit der von beiden Profilen benutzten Bank der Limousine: %d Abtastwerte, SHA-256 %s" % [now.size(), golden_file,
		"" if notes.is_empty() else " – abweichend: " + ", ".join(notes),
		"" if strict.is_empty() else "; nach dem Arcade-Rennen ruhen %d Raumklang-/Filterwerte neben dem Startwert (wie in v0.7.0)" % strict.size(),
		int(eh.get("samples", 0)), "wie in v0.7.0" if engine_ok else "ANDERS als in v0.7.0"])'''),
    ('''##   arcade_after   after all that: Arcade profile, the Arcade bus list as in v0.7.0''',
     '''##   arcade_after   after all that: Arcade profile, the Arcade bus list as in v0.7.0, and the cycle bank both
##                  profiles played from still gives the seeded mixer output of v0.7.0 (SHA-256)'''),
])
print("ok")
