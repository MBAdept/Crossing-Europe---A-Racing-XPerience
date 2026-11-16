import sys
p = sys.argv[1] + '/docs/renderer-modern-bauten.md'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''auf der Insel, wenn bis 120 m dahinter kein Schild steht (`SIGN_SCAN_M`; ein Schild weiter hinten könnte sie nur
verdecken, solange es mehrere hundert Meter entfernt ist). Sonst rückt die Stütze **nach außen**, ihre Innenseite
0,25 m jenseits der Außenkante jeder Schildtafel (von der Straße aus kann sie dann keine verdecken), auf den Vorplatz
oder dahinter, mit einem Träger unter der Dachkante; dort (außerhalb des Bankettstreifens) nie in einer Sichtschneise
(F7). Auswertung aller Etappen: unter 39 von 1909 Dächern steht ein Schild, hinter 134 eines in 120 m (meist
Leitpfeile einer Kurve); mit bloßem Weglassen standen 34 Dächer ohne Stütze.''',
'''auf der Insel, wenn bis 120 m dahinter kein Schild steht (`SIGN_SCAN_M`). Sonst rückt die Stütze **nach außen**, ihre
Innenseite 0,25 m jenseits der Außenkante jeder Schildtafel (auf gerader Straße kann sie dann keine verdecken), auf den
Vorplatz oder dahinter, mit einem Träger unter der Dachkante; dort (außerhalb des Bankettstreifens) nie in einer
Sichtschneise (F7). Auswertung aller Etappen: unter 39 von 1909 Dächern steht ein Schild, hinter 134 eines in 120 m
(meist Leitpfeile einer Kurve); mit bloßem Weglassen standen 34 Dächer ohne Stütze.

**Endstütze und Sichtlinien in Kurven (FIX-R6, Befund B-02 von QA-R6).** Die Regel „ein Schild mehr als 120 m dahinter
wird nur aus großer Entfernung verdeckt“ gilt nur auf gerader Straße: in Kurven verdeckte die Endstütze (nicht in
Arcade) netzweit in 1109 Stütze-Tafel-Paaren Teile ferner Tafeln, 195 davon bei 6–14 px Tafelbreite (QA-R6, gemessen).
`canopy_columns()` entscheidet die Stützen eines Dachs deshalb einmal auf dem Hauptthread (in `collect()`, je Etappe
zwischengespeichert): die Endstütze wird gegen echte Sichtlinien geprüft (`end_column_hides()`: von den Spurmitten,
dazu der offenen Tankspur, 55–600 m vor jeder Tafel beider Seiten bis 600 m hinter dem Dach, alle 10 m, Weltkoordinaten
des `RoadPath3D` mit Kurven, gegen den Querschnitt der Stütze). Sie steht auf der Insel, wenn sie so keine Tafel
verdeckt, sonst außen, wenn sie dort keine verdeckt, sonst gar nicht (Arcade hat dort keine). Ein Dach, das so ohne jede
Stütze bliebe, behält seine Endstütze auf der Insel – lieber als zu schweben (3 von 1923 Dächern im Netz, gemessen).
Die Sichtschneise (F7) der äußeren Stützen wird ebenfalls dort entschieden (`bend_corridor_at()` = der Test von
`ChunkContext.in_bend_corridor()` für eine Reihe beliebigen Stücks, Unit-Test).''')

rep('''  Auswertung aller 48 Grenzen der Etappen (gemessen, headless mit dem Builder): 43 Dächer stehen auf beiden Seiten
  (26 auf vier, 16 auf drei Pfeilern), 4 nur auf einer Seite (Grenze in einer Kurve: die Innenseite ist Sichtschneise,
  und Arcades vorderer Pfeiler musste wegen eines Schildes weichen), eines hat kein Dach (Somport: die Grenze liegt im
  Tunnel). Auf DEV (Grenze in einer Rechtskurve, Schilder unter dem Dach auf beiden Seiten) steht das Dach links auf
  einem äußeren Pfeiler vorn und einem am Ende; rechts ist alles Sichtschneise.''',
'''  - **Abspannung (FIX-R6, Befund B-01 von QA-R6).** Bleibt eine Seite so ohne Pfeiler (Schild unter dem Dach und
    Sichtschneise einer Kurve auf derselben Seite), schwebte das Dach dort. Jetzt hängt sie an **Masten**
    (`support_plan()`): die Pfeiler der getragenen Seite steigen bis 13 m, von jedem Mastkopf laufen zwei Zugstangen
    über die Platte zu 55 % und 100 % des Weges zur freien Kante, die äußere auf einen Stahl-Randträger auf der Platte
    entlang der freien Seite. Alles davon liegt über der Platte (6,8 m): nichts Neues in der Sichtschneise, keine
    Sichtlinie aus 3,4 m Augenhöhe zu einem Auto oder einem Schild kreuzt es (die Platte darunter deckt jede Linie, die
    es von unter dem Dach erreichen könnte). Die Entscheidung fällt für das ganze Dach auf dem Hauptthread in
    `collect()` (`supports_in_chunk()`), damit ein Dach über zwei Stücke eine Entscheidung bekommt.
    Verworfen (gemessen mit einer Sichtlinien-Sonde, Kamera 5–300 m vor dem Pfeiler in jeder Spur, Auto bis 270 m
    voraus): den äußeren vorderen Pfeiler in der Sichtschneise stehen zu lassen – er verdeckt an 3 der 5 Dächer 36–174
    Sichtlinien zu Autos, die Arcades eigener Pfeiler nicht verdeckt.
  Auswertung aller 48 Grenzen der Etappen (gemessen, headless mit dem Builder): 43 Dächer stehen auf beiden Seiten
  (26 auf vier, 17 auf drei Pfeilern), 5 hängen auf einer Seite an zwei Masten (Grenze in einer Kurve: die Innenseite
  ist Sichtschneise, und Arcades vorderer Pfeiler musste wegen eines Schildes weichen), keines schwebt; dazu zwei Grenzen
  ohne Dach (Somport: im Tunnel, wie Arcade). Auf DEV (Grenze in einer Rechtskurve, Schilder unter dem Dach auf beiden
  Seiten) steht das Dach links auf einem äußeren Pfeiler vorn und einem am Ende, beide als Masten; rechts hängt es.''')

rep('''- Stahlstützen 0,45 m knapp außerhalb der Bankette, 7 m hoch, auf Betonfundamenten mit Fußplatte, Gelenkbändern und
  Kappe;''',
'''- Stützen 0,45 m knapp außerhalb der Bankette, weiß lackiert wie Arcades Balken, bis 7,9 m, auf Betonfundamenten mit
  Fußplatte, Gelenkbändern und Kappe;
- ein **Fachwerkträger** 7,0–7,9 m über dem Banner zwischen den Stützen (vier Gurte, Pfosten und Diagonalen alle
  1,5 m) mit drei **Flutlichtern** an der Vorderseite: bei Nacht leuchten ihre Gläser, und ihr Licht fällt als Kegel
  (Ebene `lights`, Reichweite 12 m) etwa 5 m vor die Linie; Stützen und Träger sind dann leicht angestrahlt (Kanal 14).
  Alles davon liegt über Arcades Banner-Oberkante (F1). (FIX-R6, Befund B-03 von QA-R6: Start und Ziel ohne
  sichtbaren Gewinn, nachts verschwanden die grauen Stahlstützen.)''')

rep('''Banner wie Arcades (das es so hell wie bei Tag zeichnet): Nachtbild mit 0,6 der Tagesfarben (× 1,6 im Tafel-Shader),''',
    '''Banner wie Arcades (das es so hell wie bei Tag zeichnet): Nachtbild mit 0,8 der Tagesfarben (× 1,6 im Tafel-Shader),''')

rep('''| `tests/unit/race3d/test_structures.gd` | Tankstelle auf der Tankspur von Kiel – Hamburg (Kante = `Track.road_edges_at`, Spurmitte = `fuel_lane_x`, Bordstein als Ecke des Netzes, Zapfsäulen auf der Insel, nichts unter 5,6 m über Fahrbahn und Spur); Stützen nie vor einem Schild (`column_plan`, gebaute Stücke von Hamburg – Hannover); Grenze der Testetappe (Dach auf jedem Segment, eine Stirnblende „NL“, Pfeiler nie vor einem Schild und außer Arcades vorderen nie in der Sichtschneise, Kegel, nichts unter dem Dach außer Arcades Lichtbändern); `pillar_plan`;''',
    '''| `tests/unit/race3d/test_structures.gd` | Tankstelle auf der Tankspur von Kiel – Hamburg (Kante = `Track.road_edges_at`, Spurmitte = `fuel_lane_x`, Bordstein als Ecke des Netzes, Zapfsäulen auf der Insel, nichts unter Arcades 5,6 m über Fahrbahn und Spur); Stützen nie vor einem Schild (`column_plan`, gebaute Stücke von Hamburg – Hannover); Sichtlinien der Endstütze (gerade, Rechts-, Linkskurve; keine Endstütze von Kiel – Hamburg und DEV verdeckt eine Tafel, kein Dach ohne Stütze); Grenze der Testetappe (Dach auf jedem Segment, eine Stirnblende „NL“, Pfeiler nie vor einem Schild und außer Arcades vorderen nie in der Sichtschneise, in der Sichtschneise unter 6 m nur Arcades vordere Pfeiler, rechts an zwei Masten, `bend_corridor_at` = `in_bend_corridor`, Kegel, nichts unter Arcades 6,0 m außer den Lichtbändern); `pillar_plan`; `support_plan`;''')
rep('''Laternen alle 33 m im Wechsel mit Lampen und Kegeln, Zebrastreifen-Daten''',
    '''Laternen alle 33 m im Wechsel mit Lampen und Kegeln (Kegelmitte gegen Arcades 0,55 × `lights`), Zebrastreifen-Daten''')
open(p, 'w').write(s)
print('ok')
