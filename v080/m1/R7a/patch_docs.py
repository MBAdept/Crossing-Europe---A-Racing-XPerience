WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1"
p = WT + '/docs/renderer-modern.md'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:90]
    s = s.replace(old, new, 1)


rep('''| `scripts/race3d/terrain_profile.gd` | `TerrainProfile` | Gelände als Band neben der Straße: Ringabstände, Höhen, Sichtkorridor – reine Zahlen |
''', '''| `scripts/race3d/terrain_profile.gd` | `TerrainProfile` | Gelände als Band neben der Straße: Ringabstände, Höhen, Sichtkorridor – reine Zahlen |
| `scripts/race3d/sight_corridor.gd` | `SightCorridor` | Sichtkorridor der Kurven aus der wirklichen Geometrie: Hülle aller Sichtlinien bis zum F2-Bedarf (Nachtrag A-17, 5.3) |
''')

rep('''`corridor_width(k, seite)` (Meter jenseits des Banketts): auf der Kurveninnenseite die Pfeilhöhe einer Sehne von
`corridor_chord_m` (300 m), gemessen ab dem Fahrbahnrand mit dessen Radius – `300² / (8 · (R − halbe Fahrbahn))` –
für die stärkste Krümmung zu dieser Seite innerhalb einer halben Sehne Weg davor und dahinter; sonst
`corridor_min_m` (8 m) ab Fahrbahnrand. Engste Kurve des Netzes: 83,6 m.
''', '''`corridor_width(k, seite)` (Meter jenseits des Banketts) ist seit R7a (Nachtrag A-17) die **Hülle der wirklichen
Sichtlinien** (`SightCorridor`): von einer Kamera in jeder Spur zu einem Fahrzeug in jeder Spur, bis
L = min(`corridor_chord_m` = 300 m, F2-Bedarf / 0,6 + 9 m Kamera) Weg voraus. Der F2-Bedarf ist der Anhalteweg bei der
schnellsten fahrbaren Geschwindigkeit am Wagen, genau wie `fairness.speed_profile()` ihn rechnet (7.2), der größte von
trocken, Regen und Schnee – der Korridor hängt also nicht vom Wetter des Rennens ab. Wo eine Sichtlinie die Straße
verlässt, ist der Korridor diese Hülle, mindestens aber der schlichte Streifen + 0,55 m (`BEND_FLOOR_M`: so zählt
`ChunkContext.in_bend_corridor()` ihn als Kurvenkorridor); sonst der schlichte Streifen `corridor_min_m` (8 m ab
Fahrbahnrand). Engste Kurve des Netzes: 83,6 m.

- **Verfahren** (`scripts/race3d/sight_corridor.gd`): eine Kamera auf jeder Reihe, auf der äußersten Spurmitte links
  und rechts (die Sichtlinien der Spuren dazwischen liegen in deren konvexer Hülle; rechts gilt die Mitte der Tankspur,
  sobald sie öffnet – `Track.fuel_lane_x()`); Ziele sind die äußersten Spurmitten jeder Reihe bis L und das genaue Ende.
  Vom fernen Ende zur Kamera zurück ist die Sichtlinie mit dem größten Peilwinkel nach rechts (links) die äußerste,
  die den Querschnitt der eben erreichten Reihe noch kreuzt; ihr Schnittpunkt ist dort der Rand. Dreht die Straße bis
  L weniger als 1,2 rad, genügt je Seite ein Kamera- und ein Zielpunkt; sonst zählen beide äußersten Linien auf beiden
  Seiten (jenseits einer Vierteldrehung kehrt sich die Reihenfolge der Schnittpunkte um – in Kehren dadurch bis 2,4 m
  vorsichtiger als nötig). Nie über die Mittelachse zu einem anderen Teil der Straße hinaus (`clearance()`, beim
  Lesen angewandt); Ziele, die gegen die Kamera mehr als 2,6 rad gedreht sind, zählen nicht. Gegen eine vollständige
  Referenz (jede Kamerareihe, jede Spurmitte, jede Zielreihe, jeder Schnittpunkt jeder Sichtlinie mit jedem
  Querschnitt) **ohne Fehlbetrag** (Unit-Test `test_sight_corridor.gd`: langer und kurzer Bogen, Gerade vor der Kurve,
  S-Kurve, Kehre, drei Spuren mit Tankspur; gröbere Kameraschritte verfehlen Knicke der Hülle um bis zu 1 m und wurden
  verworfen).
- **Was das heißt**: das Band läuft an Anfang und Ende einer Kurve aus; in der Kurvenmitte ist es schmal, wo das
  Tempo klein ist (Bergkurven T3/T4: L = 118–119 m, Pfeilhöhe 11–13 m statt 83 m), am Kurvenanfang breit, solange die
  Anfahrt schnell ist – die Sichtlinien der schnellen Anfahrt schneiden in die Kurve (Autobahnbogen R = 200 m: Mitte
  10 m, die ersten 100 m bis 43 m, das alte Band überall 55 m). Eine kurze Kurve bekommt nicht die Pfeilhöhe ihres
  eigenen Bogens, sondern den Abstand der Sichtlinien von den Geraden davor und danach über ihre Ecke (60-m-Bogen
  R = 150 m: Bogen allein −1,4 m, Hülle deutlich mehr, das alte Band 38 m). Eine Gerade vor der Kurve ist frei, soweit
  keine Sichtlinie in die Kurve über sie läuft (mehr als eine Sehne L vor der Kurve immer).
- **Rechnung**: faul und schrittweise, wenn Reihen gelesen werden (`ensure()`), jede Kamera einmal je Etappe; dazu
  rechnet der Streamer in Bildern ohne Sammeln und Festschreiben höchstens 0,25 ms (und mindestens eine Kamera) voraus
  (`TerrainProfile.warm()`), bis zwei Stücke über das fernste ladbare hinaus – ein gesammeltes Stück findet seine
  Reihen fertig vor. Ein Start mitten in der Etappe kennt die Kameras vor dem ersten Pfadpunkt (150–246 m hinter der
  Kamera) nicht: an den 13 Bildstellen sind die Reihen ab der Kamera an 11 Stellen gleich, an zweien weichen 4 bzw. 8
  Reihenseiten direkt an der Kamera um höchstens 0,56 m ab (gemessen).
''')

rep('''`ChunkContext.in_bend_corridor()` sagt dem Requisiten-Builder, wo keine schmückende Vegetation stehen darf. Gemessen
in den zwölf härtesten Etappenrichtungen: 5.230 von 18.518 Landschafts-Requisiten (28,2 %) stehen in einem
Kurvenkorridor, davon 4.033 von 13.628 Bäumen und Büschen (29,6 %).''', '''`ChunkContext.in_bend_corridor()` sagt dem Requisiten-Builder, wo nichts über 0,5 m stehen darf (Bodendecker füllen
den Korridor), der Stadt-Builder lässt dort Zaun-, Hecken- und Mauerstücke weg (ein Stück, sobald seine Mitte oder eines
seiner Enden darin liegt), der Grenz-Builder prüft seine Pfeiler gegen die genaue Hülle (`pillar_in_sight()`).
Gemessen im ganzen Netz (128 Etappenrichtungen, gleiche Strecken, Sonde des Pakets R7a): von 203.367 Requisiten im
Band ließ das alte Band 37.368 im Kurvenkorridor weg (18,4 %), die Hülle 14.342 (7,1 %) – 23.026 kommen zurück
(16.947 Bäume, 2.947 Pflanzen, 952 Felsen, 1.944 Häuser, davon 1.878 in Städten), keines fällt neu weg. Stadtzäune:
Arcade zeichnet 79.662 Stücke, das alte Band ließ 64,3 % stehen, die Hülle 75,3 %. Grenzdächer: von 48 hängen 3 an
Masten (vorher 4; Belgrad – Sofia km 340 steht wieder auf vier Pfeilern).''')

rep('''| `corridor_chord_m`, `corridor_min_m` | 300, 8 | Sichtkorridor – nicht ohne die Projektleitung ändern |''',
    '''| `corridor_chord_m`, `corridor_min_m` | 300, 8 | Sichtkorridor: längste Sichtlinie L (darunter der F2-Bedarf) und schlichter Streifen ab Fahrbahnrand – nicht ohne die Projektleitung ändern |''')

rep('''| F7 Gelände im Sichtkorridor nie über der Fahrbahn | `modern_sight_f7`: jede Reihe, beide Seiten | 0 Verstöße |''',
    '''| F7 Gelände im Sichtkorridor nie über der Fahrbahn | `modern_sight_f7`: jede Reihe, beide Seiten | 0 Verstöße |
| F7 der Korridor ist die Hülle der Sichtlinien (A-17) | `modern_sight_f7`: unabhängige Referenz `Fairness.sight_envelope()` (jede 7. Kamerareihe, jede Spurmitte, Bedarf aus `speed_profile()`, doppelte Genauigkeit): jede ihrer Sichtlinien jenseits des Banketts liegt im Korridor, und er zählt dort als Kurvenkorridor | 0 nicht abgedeckt, 0 nicht gezählt |''')

rep('''- **Sichtkorridor und Vegetation**: die Regel nimmt in Bergstrecken knapp 30 % der Bäume weg (5.3). Wirkt das kahl,
  ließe sich der Korridor aus der wirklichen Sehne statt aus der stärksten Krümmung rechnen – eine Änderung im
  Kern mit neuem Lauf von `modern_sight.gd`, zu entscheiden von der Projektleitung.
''', '''- **Sichtkorridor und Vegetation**: seit R7a aus der wirklichen Geometrie (A-17, 5.3); in Städten bleibt L meist 300 m
  (die schnellste fahrbare Geschwindigkeit kennt keine Tempolimits), Häuser in Stadtkurven kommen daher nur zum Teil
  zurück.
''')

rep('''  City Limits (Grasbüschel auf dem Pflaster eines Stadtzentrums, gesehen an C1). Felsen und
  Häuser einer Landschaftsregel bleiben im Korridor weggelassen (strengere Lesart von R2, bis die Projektleitung mit
  den Bergbildern von Zwischenstand 2 entscheidet). Bilder T2/T4 vorher/nachher im Abgabeordner.''',
    '''  City Limits (Grasbüschel auf dem Pflaster eines Stadtzentrums, gesehen an C1). Felsen und
  Häuser einer Landschaftsregel bleiben im Korridor weggelassen (strenge Lesart, A-17: nichts über 0,5 m in der Hülle
  der Sichtlinien); der Korridor selbst ist seit R7a die Hülle der wirklichen Sichtlinien (5.3).''')

rep('''- Kurveninnenseiten in Bergetappen kahler als Arcade (Sichtkorridor F7: Bäume werden durch Bodendecker ersetzt –
  Entscheidung der Leitung nach A-3).''', '''- Kurveninnenseiten in Bergetappen kahler als Arcade (Sichtkorridor F7: Bäume werden durch Bodendecker ersetzt –
  Entscheidung der Leitung nach A-3). *Seit R7a nur noch, wo die Sichtlinien laufen (A-17, 5.3).*''')

rep('''- Kurveninnenseiten in Bergetappen: Sichtkorridor nach A-17 kommt mit R7 (A/B T1–T4: Bäume und Felsen innen fehlen).''',
    '''- Kurveninnenseiten in Bergetappen: Sichtkorridor nach A-17 mit R7a (5.3); was in Stadtkurven fehlt, bleibt (L = 300 m).''')
open(p, 'w').write(s)
print('ok')
