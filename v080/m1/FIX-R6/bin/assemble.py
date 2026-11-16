import sys
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6/"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX-R6/bericht.md"
parts = [open(S + f).read() for f in ["bericht_teil_kopf.md", "bericht_teil_befunde.md", "bericht_teil_gates.md",
                                       "bericht_teil_bilder.md", "bericht_teil_ende.md"]]
s = "\n".join(parts)
perf = """| `perf_stats` | Kopf `2c75af0` Lauf 1 | Basis `c8b18d1` Lauf 1 | Kopf Lauf 2 | Basis Lauf 2 |
|---|---|---|---|---|
| Last der Maschine | 15–17 | 12–17 | 14–16 | 16 |
| `render()` ms Mittel / max | 7,10 / 138,7 | 5,93 / 66,1 | 6,23 / 258,1 | 5,76 / 78,8 |
| davon Hook `streamer` ms Mittel / max | 4,23 / 119,3 | 3,62 / 64,0 | 3,95 / 256,1 | 3,34 / 77,3 |
| Hooks `flares` / `lights` / `gantry` / `radar` ms Mittel | 0,59 / 0,27 / 0,007 / 0,017 | 0,16 / 0,28 / 0,009 / 0,010 | 0,17 / 0,25 / 0,008 / 0,008 | 0,14 / 0,26 / 0,009 / 0,004 |
| Chunk-Einhängen max (Hauptthread) | 6,61 ms | 6,67 ms | 8,96 ms | 44,28 ms |
| Chunk-Bau ms Mittel / max (Worker-Thread) | 9,0 / 197,6 | 6,1 / 50,1 | 10,5 / 211,5 | 10,4 / 260,9 |
| Draw Calls / Primitive / Schatten-Primitive (letztes Bild, Ziel) | 83 / 75 885 / 8 316 | 83 / 75 885 / 8 316 | 83 / 75 885 / 8 316 | 83 / 75 885 / 8 316 |
| Instanzen mit Instanz-Uniforms | 63 | 63 | 63 | 63 |
| Bildzeit Median / p95 ms (llvmpipe, Zeitraffer) | 991 / 1547 | 834 / 1447 | 923 / 1503 | 915 / 1525 |
| Ergebnis | 130 km, 0 Kollisionen, 0 Skriptfehler, `time_s` 376,85 | gleich | gleich | gleich |

Lesart (gemessen, ehrlich): Draw Calls, Primitive, Schatten-Primitive und Instanzen sind im letzten Bild gleich (am
Zieltor: das Fachwerk liegt dort hinter der Kamera bzw. außerhalb des Schattenbereichs). `render()` im Mittel +0,5 bzw.
+1,2 ms, fast ganz im Streamer (Zeitraffer 40: viele Stücke je Bild); das längste Bild war in beiden Paaren auf dem Kopf
länger (139 / 258 ms gegen 66 / 79 ms) – einzelne Spitzen unter Last 15–17 streuen stark (QA-R6 maß für `c8b18d1`
selbst 134 ms, R6 347 ms), eine Ursache in meinem Code habe ich nicht gefunden: die teuerste neue Arbeit auf dem
Hauptthread ist die Sichtlinienprüfung der Tankstelle mit höchstens 1–7 ms je Stück (3.2). Der `flares`-Hook war im
ersten Paar höher (0,59 ms), im zweiten gleich (0,17 gegen 0,14 ms) – Rauschen. Gefolgert: auf dem Deck und echten
GPUs mit dem Leistungstest nachmessen (Hinweis 5.3); das Starttor hat jetzt 1 162 statt 374 Dreiecke (gemessen, Kiel – Hamburg); sein Bau
und der Masten liegt im Worker-Thread."""
s = s.replace("PERFTABLE", perf)
s = s.replace("HEADCOMMIT", "`2b7dcc0`")
s = s.replace("MUSICALONE", "`tools/run_tests.sh test_music_checks` (Last 16) **2 von 2 OK**, „Tests bestanden“")
s = s.replace("MODERNMAKE", "Exit 0, 6 Hashes neu; nur `modern_start_mittel` geändert (derselbe Hash wie das behaltene Bild der Prüfung), Commit `2b7dcc0`")
s = s.replace("Render-Prüfungen RENDERSUMMARY", "Render-Prüfungen 21 von 21 OK")
s = s.replace("`run_tests.sh`\n  TESTSUMMARY.", "`run_tests.sh`\n  761 Tests grün bis auf die bekannte lastabhängige Echtzeit-Musikprüfung im zweiten Lauf (startet in Arcade; allein 2/2 grün).")
s = s.replace("| (Abschnitt 2) | Modern-Änderungsmelder neu |", "| `2b7dcc0` | Modern-Änderungsmelder neu (nur `modern_start_mittel`, gewollt), Doku-Zahlen der Hauptthread-Kosten |")
open(D, "w").write(s)
for tok in ["PERFTABLE", "HEADCOMMIT", "MUSICALONE", "MODERNMAKE", "RENDERSUMMARY", "TESTSUMMARY", "TODO"]:
    if tok in s:
        print("left:", tok)
print("written", len(s))
