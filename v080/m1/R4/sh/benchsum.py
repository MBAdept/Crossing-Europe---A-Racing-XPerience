import json, os, sys
B = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4/bench/'
rows = []
for tag, preset in [('base', 'medium'), ('head', 'medium'), ('head', 'deck'), ('head', 'low'), ('head', 'high')]:
    f = B + '%s_%s.json' % (tag, preset)
    if not os.path.exists(f):
        rows.append('| %s | %s | – | (fehlt) | | | | |' % (tag, preset))
        continue
    d = json.load(open(f))
    for sc in d.get('scenes', []):
        rows.append('| %s | %s | %s | %.1f | %.0f | %.2f / %.1f | %d | %d |' % (
            tag, preset, sc.get('id'), sc.get('avg_fps', 0), sc.get('frame_ms_median', 0), sc.get('script_ms', 0),
            sc.get('script_ms_max', 0), sc.get('draw_calls', 0), sc.get('primitives', 0)))
print('| Stand | Stufe | Szene | Bilder/s | Median ms | Skript ms (Mittel / max) | Zeichenaufrufe | Dreiecke |')
print('|---|---|---|---|---|---|---|---|')
print('\n'.join(rows))
