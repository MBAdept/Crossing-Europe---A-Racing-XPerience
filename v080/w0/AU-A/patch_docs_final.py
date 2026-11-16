"""Final touches of docs/audio-modern.md: test count, the engine check after everything, the number of hang-free runs."""
import sys

R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"
RUNS = sys.argv[1] if len(sys.argv) > 1 else "54"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("docs/audio-modern.md", [
    ('''`tests/unit/audio_modern/` (laufen mit `tools/run_tests.sh`, allein mit `tools/run_tests.sh audio_modern`,
54 Tests, etwa 45 s):''', '''`tests/unit/audio_modern/` (laufen mit `tools/run_tests.sh`, allein mit `tools/run_tests.sh audio_modern`,
56 Tests, etwa 45 s):'''),
    ('''mit Arcade bei gleicher Simulation in jeder Sekunde (Regel 3) · danach wieder Arcade wie in v0.7.0.''',
     '''mit Arcade bei gleicher Simulation in jeder Sekunde (Regel 3) · danach wieder Arcade wie in v0.7.0 – die
Busliste und der Motor-Mischer mit der Bank, aus der beide Profile gespielt haben, Abtastwert für Abtastwert.'''),
    ('''Die Mulde nimmt Musik 1,4 dB (Titelmelodie) bis 1,7 dB (Platzhalter-Stück) ihrer Lautheit (gemessen);
`context_db.race` = +1,0 dB gleicht das mit aus.''', '''Die Mulde nimmt Musik einen Teil ihrer Lautheit: 1,7 dB beim Platzhalter-Stück (im Spiel gemessen), 1,4 dB bei der
Titelmelodie (mit der gemessenen Impulsantwort berechnet). `context_db.race` = +1,0 dB gleicht das mit aus.'''),
    ('''   `ModernAudioContext.keep_alive(stream)` hält solche Streams zwei Sekunden über ihren Player hinaus: 0 von
   54 Läufen.''', '''   `ModernAudioContext.keep_alive(stream)` hält solche Streams zwei Sekunden über ihren Player hinaus: 0 von
   %s Läufen.''' % RUNS),
])
print("ok")
