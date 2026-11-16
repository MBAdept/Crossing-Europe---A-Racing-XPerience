p = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R4/bericht.md'
s = open(p).read()
rep = [
('''Entscheidungen 1–8 der Leitung). Basis `6e48405` (= `origin/wip/v080-m2int`, M2INT + M2ZS1). Kein Vorgänger (keine
`STAND.md`, kein `wip/v080-r4`) – frisch begonnen mit `git merge --ff-only 6e48405`.''',
'''Entscheidungen 1–8 der Leitung). Basis `6e48405` (= `origin/wip/v080-m2int`, M2INT + M2ZS1). Der erste Lauf begann
frisch (Vorspulen auf `6e48405`); nach einem Ausgabenlimit (12.11. 20:20) und zwei Neustarts des Containers
(13.11. 05:30, 15.11. 08:00) haben zwei Nachfolger über `STAND.md` im selben Worktree weitergemacht – nichts ging
verloren (jeder Stand war gepusht). Der letzte Nachfolger hat zwei Look-Punkte nachgezogen (1.6, 1.9) und alle Tore
auf dem Endstand gefahren.'''),
('''### 1.6 Tunnelausfahrt bei Tag (Entscheidung 4) – `b9484fc`, nachgestellt `8ceb281`, `d1181fe`
Belichtungsrampe: ein tiefengetestetes Viereck im Ausfahrtsportal mischt das Draußen zu Weiß (60 % fern, **45 % am
Portal** – die Augen sind noch auf die Röhre eingestellt, wie bei Arcade bleibt das Draußen hell, solange die Kamera
drinnen ist), danach 60 m Nachglühen über das ganze Bild (40 % am Portal) – eine Funktion des Ortes, keine Uhr; nur
bei Tag und nur mit einem Tunnel-Builder.''',
'''### 1.6 Tunnelausfahrt bei Tag (Entscheidung 4) – `b9484fc`, nachgestellt `8ceb281`, `d1181fe`, `866a74c`
Belichtungsrampe: ein tiefengetestetes Viereck im Ausfahrtsportal überbelichtet das Draußen (Stärke 0,6 fern, **0,45
am Portal** – die Augen sind noch auf die Röhre eingestellt, wie bei Arcade bleibt das Draußen hell, solange die Kamera
drinnen ist), danach 60 m Nachglühen über das ganze Bild (0,4 am Portal) – eine Funktion des Ortes, keine Uhr; nur
bei Tag und nur mit einem Tunnel-Builder. **Gesetz** (`866a74c`): beide lesen das Bild hinter sich
(Bildschirmtextur) und zeigen es nach Arcades Gesetz für das Draußen – Anzeigewert × 1,7 + 0,25 bei voller Stärke,
die hellsten Teile brennen aus. Die erste Fassung mischte zu Weiß und las sich **milchig** (ein blasser Schleier über
graugrünem Gras); gemessen am Portal (Bereich über den Autos, „Hoch“): Leuchtdichte Arcade 0,600 / Modern vorher
0,638 / jetzt 0,717, Sättigung 0,43 / 0,20 / 0,26. Kosten: eine Bildkopie, nur solange Viereck oder Ebene zu sehen
sind; die Nachglüh-Ebene wird beim Aufwärmen mit Stärke 0 gezeichnet.'''),
('''Ehrlich: nachts wirken die Lacke blasser als Arcades Sprites (der Schimmer hat die Farbe des Nachthimmels; Kompakt
cremegelb statt bernstein) – die Helligkeit stimmt, die Sättigung ist geringer.''',
'''Danach (Nachfolger, `2577b30`) die Farbe: der neutrale Schimmer in der Farbe des Nachthimmels machte die Lacke blasser
als Arcades Sprites (Kompakt cremefarben statt bernstein, GT neutral grau statt blaugrau). Neues vpbr-Uniform
`fill_sheen_tint` (Standard 0 = unverändert, Renn-Look 0,8): der Schimmer trägt die Lackfarbe im Licht der Umgebung
(Arcades Gesetz Sprite × Umgebungsfarbe) bei gleicher Leuchtdichte. `check_night spielerauto` misst jetzt auch die
Sättigung (Median der Karosserie, Schranke ≥ 0,7 × Arcade): vorher **0,74 × / 0,70 × / 0,91 ×**, jetzt **0,95 × /
0,73 × / 0,91 ×**; Helligkeit 1,04 × / 0,93 × / 0,86 × (Schranke 0,6 … 1,1). Ein erster Versuch (Lackfarbe ohne
Umgebungsfarbe, 0,7) hob den Kompakt ebenso, nahm aber dem silbernen GT sein Nachtblau (0,56 ×) – verworfen. Der GT
bleibt knapp über der Schranke: seine Sättigung bei Arcade ist nur der blaue Nachtton des Sprites.'''),
]
for o, n in rep:
    assert s.count(o) == 1, o[:60]
    s = s.replace(o, n)
open(p, 'w').write(s)
print('ok')
