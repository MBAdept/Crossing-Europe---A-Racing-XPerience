import sys
p = sys.argv[1] + "/bericht_gates.md"
t = open(p, encoding="utf-8").read()
for a, b in [("@@T2STAND@@", "`9b02f05`"),
             ("@@T2@@", "**803 Tests, 0 fehlgeschlagen** (einer mehr: `test_station_warm_step_prepares_what_the_halves_read`); 150 CHECK-Zeilen OK, 0 FEHLER (964 s)")]:
    assert t.count(a) == 1, a
    t = t.replace(a, b)
open(p, "w", encoding="utf-8").write(t)
print("ok")
