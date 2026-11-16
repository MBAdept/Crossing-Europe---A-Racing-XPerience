#!/usr/bin/env python3
"""Assembles deliver/RINT-B/bericht.md from the scratch parts (RINT-B helper)."""
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/"
D = S + "deliver/RINT-B/bericht.md"
M = S + "m1/RINT-B/"
head = open(D).read()
head = head[:head.index("Danach (eigene Commits)")]
body = open(M + "bericht_body.md").read()
look = open(M + "bericht_look.md").read()
tail = open(M + "bericht_tail.md").read()
tail = tail.replace("| Tests (2) | `tools/run_tests.sh` (9b6adbc) | RUN2 |",
                    "| Tests (2) | `tools/run_tests.sh` (9b6adbc, letzter Kopf) | Exit 0 in 880 s: `692 Tests, 0 fehlgeschlagen`, "
                    "`==> Tests bestanden`, 156 Zeilen `CHECK(S) … OK`, keine `FEHLER` |")
assert "RUN2" not in tail
lieferung = """
## 10. Lieferung

`/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/RINT-B/`:
`bericht.md` (dieser Bericht), `kiel_hamburg_start_ab.mp4` (20 s A/B), `look/hoch/*.jpg` (13 Bögen),
`look/maschine/*.jpg` (10 Bögen), `showroom_ab.png` (Showroom, dieselbe Kamera), `leistungstest.json` (Leistungstest
auf der Build-VM).
"""
text = head + body + "\n" + look + "\n" + tail + lieferung
open(D, "w").write(text)
print("bericht.md: %d Zeilen" % text.count("\n"))
