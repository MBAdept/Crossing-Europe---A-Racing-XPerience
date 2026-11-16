root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'docs/renderer-modern.md'
s = open(p).read()

a = '''Die Laderegel allein will in engen Bergstrecken mehr (gemessen bei 900 m Sicht, Kamera alle 96 m, 31.488 Positionen):
bis zu 18 Stücke, an 209 Positionen (0,66 %) mehr als 16. Dann warten die **nach Luftlinie fernsten** – sie liegen im
Nebel am Ende der Sichtweite. (Nach Weg sortiert wäre das nächste ausgelassene Stück nur 312 m entfernt gewesen.)

Bei 900 m Sicht sind auf gerader Strecke 13–14 Stücke geladen, im Tunnel (360 m) deutlich weniger.
'''
b = '''Die Laderegel allein will in engen Bergstrecken mehr (gemessen bei 900 m Sicht, Kamera alle 96 m, 31.488 Positionen):
an 38 Positionen 17 und an 171 Positionen 18 Stücke – zusammen 209 Positionen (0,66 %) in zwölf Etappenrichtungen.
Dann warten die **nach Luftlinie fernsten**. Das nächste ausgelassene Stück liegt an 135 dieser Positionen 800 m und
weiter entfernt (im dichten Nebel am Ende der Sichtweite), an 45 bei 700–800 m, an 18 bei 600–700 m, an 8 bei
500–600 m und an 3 unter 500 m (das nächste: 456 m, Saragossa – Pau ab Pau km 42,2). An diesen 29 Positionen kann eine
Lücke in der Ferne zu sehen sein, bis die Kamera ein Stück weiter ist. Mit `graphics.modern.max_chunks = 18` wird
nirgends im Netz etwas ausgelassen – zu entscheiden mit dem Zeichenbudget.

Bei 900 m Sicht sind auf gerader Strecke 13–14 Stücke geladen, im Tunnel (360 m) deutlich weniger.
'''
assert a in s
s = s.replace(a, b)

a = '''| Einsammeln je Stück (Hauptthread) | im Mittel 0,85–1,22 ms, höchstens 1,55 ms |
| davon `TerrainProfile.rows()` | 0,77 ms |
| `clearance` einer Stützreihe (beide Seiten, ±1.842 m Weg) | 19 µs |
| Bauen der Debug-Straße je Stück | 1,6–2,0 ms im Hauptthread, 2,6–3,0 ms auf einem Arbeiter-Thread |
| Einhängen der Debug-Straße | im Mittel 0,06–0,09 ms, höchstens 0,25 ms |
| `update()` je Bild (Threads, 120–250 km/h) | im Mittel 0,01–0,06 ms, p95 0,03–0,14 ms, höchstens 1,0–4,0 ms |
| erstes `update()` (12–16 Stücke, dazu 3,4 km Strecke erzeugen) | etwa 90–110 ms |
'''
b = '''| Einsammeln je Stück (Hauptthread) | im Mittel 0,85–1,26 ms, höchstens 2,0 ms |
| davon `TerrainProfile.rows()` | 0,77 ms |
| `clearance` einer Stützreihe (beide Seiten, ±1.842 m Weg) | 19 µs |
| Bauen der Debug-Straße je Stück | im Mittel 1,6–2,5 ms im Hauptthread, 2,2–3,3 ms auf einem Arbeiter-Thread |
| Einhängen der Debug-Straße | im Mittel 0,06–0,10 ms, höchstens 0,25 ms |
| `update()` je Bild (Threads, 120–250 km/h) | im Mittel 0,01–0,07 ms, p95 0,03–0,19 ms, p99 0,07–1,2 ms, höchstens 1,0–4,0 ms |
| `update()` je Bild (Sync-Modus) | im Mittel 0,02–0,08 ms, höchstens 3,5–8,2 ms (Einsammeln, Bauen und Einhängen in einem Bild) |
| erstes `update()` (12 Stücke, dazu 3,4 km Strecke erzeugen; Kiel – Hamburg km 2) | 77–114 ms |
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
