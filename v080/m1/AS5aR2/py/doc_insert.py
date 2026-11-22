"""AS5aR2: final docs section 22 from the draft + budget table + measurements, appended to docs/modelle.md."""
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2/"
DOC = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-6/docs/modelle.md"
d = open(S + "doc22_draft.md").read()
table = open(S + "budget_table.md").read().strip()
i = d.index("| Set | Dreiecke lod0 / lod1")
j = d.index("Charge 2: Netze")
k = d.index("\n", j)
d = d[:i] + table + d[k + 1:] if False else d[:i] + table + "\n" + d[k + 1:]
d = d.replace("""Alle 23 unter 10 000 Dreiecken in lod0 und zwei Zeichenaufrufen je Stufe. Die Blattkarten kosten das Südhaus
460 und das Loire-Haus 340 Dreiecke in lod0 und 4–6 % des Atlas (Blattfeld 246 bzw. 248 Texel); die Wanddichte sank
dadurch um 1–2,5 %.""", """Alle 23 unter 10 000 Dreiecken in lod0 und zwei Zeichenaufrufen je Stufe; Charge 2 im Archiv 0,98 MB Netze und
5,91 MB Texturen (Grenze je Charge 3 / 7 MB). Die Blattkarten kosten das Südhaus 460 und das Loire-Haus 340 Dreiecke je
Stufe und 4–6 % des Atlas (Blattfeld 246 bzw. 248 Texel); die Wanddichte sank dadurch um 1–2,5 %.""")
mess = """### Messungen vorher / nachher (llvmpipe, gemessen)

| Messung | vorher (AS5a2) | nachher |
|---|---|---|
| Paris km 387,9, 22 Uhr, Hoch: Läden im Erdgeschoss des Eckhauses, Anteil warmer Pixel / mittlere Farbe (Arcade 28,2 %, (250,215,157)) | 10,9 %, (192,150,105) | 22,7 %, (233,193,135) |
| dasselbe +4 s, Ladenflanke rechts (Arcade 24,2 %) | 4,8 % | 9,4 % |
| Bern km 303, 22 Uhr: warmes Licht im Bild (Arcade 5,2 / 5,0 %) | 2,0 / 2,7 % | 2,9 / 3,7 % |
| Gründerzeithaus 30 m, 22 Uhr (Prüfszene, Erdgeschoss) | 16,7 %, (186,143,96) | 31,7 %, (234,190,129) |
| Stufenwechsel 60 m „Mittel“, 12 / 22 Uhr: Südhaus | 16,4 / 7,8 % der Pixel | 8,2 / 4,3 % |
| dasselbe: Loire-Haus | 11,9 / 7,8 % | 8,6 / 6,0 % |
| Flimmern 40 / 60 / 100 / 150 m: Haussmann (Sprite 0,0 / 0,2 / 0,3 / 0,4 %) | 1,0 / 1,2 / 1,0 / 0,6 % | 0,9 / 1,1 / 0,3 / 0,5 % |
| dasselbe: Eckhaus (Sprite 0,1 / 0,2 / 0,2 / 0,3 %) | 1,1 / 1,2 / 1,0 / 0,7 % | 1,1 / 1,1 / 0,2 / 0,4 % |
| dasselbe: Südhaus (Sprite 0,2 / 0,3 / 0,4 / 0,6 %) – Blattkarten | 0,4 / 0,4 / 0,6 / 0,8 % | 0,9 / 0,9 / 1,0 / 1,5 % |
| Fernbild: dunkles Zehntel lod0 60 m → lod1 250 m, Haussmann / Lauben / Maashaus | +23 / +25 / +22 | +23 / +26 / +22 (unverändert) |
| Gartenmauer Südhaus / Loire-Haus, Straßenseite (Packdichte × 0,6) | 32,5 / 30,6 px/m | 32,1 / 29,9 px/m |

Nicht erreicht: Die Fernfassaden bleiben blass (der dunklere Innenring der Fernstufe war nicht die Ursache; das Glas des
Atlas ist schon bei 60 m 11–21 Stufen heller als das gemalte Spiegelglas des Sprites); die Blattkarten flimmern bei
100–150 m mehr als die alte Kugelkrone; Haussmann und Eckhaus flimmern in lod0 (40–60 m) weiter 5–10 × so stark wie
das Sprite (Alpha-Test der Gitter, geometrische Sprossen) – Fall für TAA/Mip-Bias oder ein kürzeres lod0 (R7)."""
d = d.replace("MESSUNGEN_R2", mess)
doc = open(DOC).read()
if "## 22. Nacharbeit der Stadthäuser" in doc:
    doc = doc[:doc.index("## 22. Nacharbeit der Stadthäuser")].rstrip() + "\n"
doc = doc.rstrip() + "\n\n" + d.strip() + "\n"
open(DOC, "w").write(doc)
print("ok", len(doc.splitlines()))
