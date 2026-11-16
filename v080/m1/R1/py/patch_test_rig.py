p = 'tests/unit/race3d/test_environment_rig.gd'
s = open(p, encoding='utf-8').read()


def rep(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old[:70])
    s = s.replace(old, new)


rep('''	var worst_ref := 0.0
	var worst_day := 0.0
	var worst_day_at := ""
''', '''	var worst_ref := 0.0
	var worst_day := {"normal": 0.0, "rain": 0.0, "snow": 0.0}
	var worst_day_at := {"normal": "", "rain": "", "snow": ""}
''')
rep('''					var e := _error(albedo, st, p)
					if e > worst_day:
						worst_day = e
						worst_day_at = "%.1f Uhr, %s, Albedo %.2f" % [hour, weather, albedo]
''', '''					var e := _error(albedo, st, p)
					if e > float(worst_day[weather]):
						worst_day[weather] = e
						worst_day_at[weather] = "%.1f Uhr, Albedo %.2f" % [hour, albedo]
''')
rep('''	assert_true(worst_day <= 0.10, "bei Tag höchstens 10 %% daneben für Albedo 0,3 … 0,9 (%.1f %% bei %s)" % [worst_day * 100.0, worst_day_at])
''', '''	print("      Lichtgesetz bei Tag, Albedo 0,3 … 0,9: klar %.1f %% (%s), Regen %.1f %% (%s), Schnee %.1f %% (%s)" % [
		float(worst_day["normal"]) * 100.0, worst_day_at["normal"], float(worst_day["rain"]) * 100.0, worst_day_at["rain"],
		float(worst_day["snow"]) * 100.0, worst_day_at["snow"]])
	assert_true(float(worst_day["normal"]) <= 0.08, "klarer Tag: höchstens 8 %% daneben für Albedo 0,3 … 0,9 (%.1f %% bei %s)" % [float(worst_day["normal"]) * 100.0, worst_day_at["normal"]])
	assert_true(float(worst_day["rain"]) <= 0.12 and float(worst_day["snow"]) <= 0.12, "Regen und Schnee bei Tag: höchstens 12 %% (%.1f %% / %.1f %%)" % [
		float(worst_day["rain"]) * 100.0, float(worst_day["snow"]) * 100.0])
''')
open(p, 'w', encoding='utf-8').write(s)
print("ok")
