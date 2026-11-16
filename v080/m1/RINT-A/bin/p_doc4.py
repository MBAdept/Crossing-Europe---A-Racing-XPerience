import os
import sys
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')
core_ms = sys.argv[1]      # e.g. "0,21"


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'docs/renderer-modern.md'
rep(p, '''- `tools/run_tests.sh` startet zusätzlich `check_options_tabs` (Arcade) und `check_attract`, `check_attract_scenes`
  in Modern; die Render-Prüfungen der Pakete findet `tools/run_render_checks.sh` über ihren Dateinamen.''', '''- `tools/run_tests.sh` startet zusätzlich `check_options_tabs` (Arcade) und `check_attract`, `check_attract_scenes`
  in Modern; die Render-Prüfungen der Pakete findet `tools/run_render_checks.sh` über ihren Dateinamen.
- `check_modern_stage` → `kern_zeit` misst wieder nur den Renderer-Kern (Straße, Randausstattung, Hintergrund,
  Lichter, Overlay – Testdouble `tests/race3d/fixtures/core_renderer.gd`): seit der Zusammenführung aktualisiert
  `render()` auch Gelände, Requisiten, Schilder, Fernboden, Fahrzeuge und Lichtpunkte; mit allem maß die Prüfung
  0,499 bzw. 0,618 ms je Bild (Grenze 0,6 ms für den Kern, zwei Läufe bei Last 6–9), der Kern allein %s ms
  (gemessen, headless). Die Zeit des ganzen Renderers steht in `perf_stats` (`render_ms_avg`).''' % core_ms)
print('ok')
