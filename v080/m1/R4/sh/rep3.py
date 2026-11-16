p = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R4/bericht.md'
s = open(p).read()
rep = [
('''| `TEXIT_*` (Testetappe km 52,8, 12 Uhr; 1,0 / 2,4 / 3,8 s) | dritte Fassung: drinnen blaue Limousine, Ausfahrt in 40 m hell überstrahlt, am Portal das Draußen milchig hell, das Auto davor klar | gleichwertig: Arcade überstrahlt satter (hellgrün), Modern milchiger; dafür das Nachglühen nach dem Portal, das Arcade nicht hat |''',
 '''| `12_…`, `13_…`, `20_…` TEXIT (Testetappe km 52,8, 12 Uhr; 1,0 / 2,4 / 3,8 s; Endstand `866a74c`) | drinnen blaue Limousine mit Rücklichtern, Ausfahrt in 40 m hell, am Portal das Draußen überbelichtet: helles Gras, heller Himmel, Bäume mit Farbe, das Auto davor klar; `20_…` zeigt Arcade / vorherige Fassung (Weißmischung) / Endstand am Portal | **besser als vorher, gleichwertig zu Arcade**: die Weißmischung war ein milchiger Schleier (Sättigung 0,20), jetzt hell und farbig (0,26, Leuchtdichte 0,717 gegen Arcade 0,600); Arcades Gras bleibt greller (Palette), dafür hat Modern Licht und Schatten der Röhre und das Nachglühen nach dem Portal |'''),
('''| `N1_deck`, `N2N_deck` (1280×800, „Steam Deck“) | dasselbe mit der Stufe „Einfach“ der Effekte | Niederschlag und Gischt sichtbar, Bild füllt 16:10 |''',
 '''| `N1_deck`, `N2N_deck` (1280×800, „Steam Deck“) | dasselbe mit der Stufe „Einfach“ der Effekte (Stand vor `2577b30`: nur der Nacht-Schimmer des Spielerautos ist seither farbiger) | Niederschlag und Gischt sichtbar, Bild füllt 16:10 |
| `21_spielerauto_nacht_…` (22 Uhr, „Mittel“; Spalten Arcade / neutraler Schimmer / Endstand) | Kompakt im Schnee, GT im Regen, Limousine klar | Kompakt jetzt bernstein wie das Sprite (vorher cremefarben), Limousine satt blau (Arcade dunkler marineblau); **schwächer**: der silberne GT liest sich heller und neutraler als Arcades blaugraues Sprite – die nach oben weisenden Flächen (Kofferraumdeckel, Dach) liegen bei rund 1,6 × Arcades Wert (Raster: 81–106 gegen 51–66 von 255), Stoßfänger und Seiten gleich; das 75. Perzentil der ganzen Karosserie 0,93 × verdeckt das |'''),
('''7. Dritte Nachtetappe der Deckel-Prüfung ist C1 (21:30, Regen) statt der Testetappe: deren Tunnellampen haben keine
   Pool-Reichweite (R5), dort gäbe es keine Lampe im Pool zu prüfen.''',
 '''7. Dritte Nachtetappe der Deckel-Prüfung ist C1 (21:30, Regen) statt der Testetappe: deren Tunnellampen haben keine
   Pool-Reichweite (R5), dort gäbe es keine Lampe im Pool zu prüfen.
8. **Tunnelausfahrt mit Bildschirmtextur** (`866a74c`): Viereck und Nachglüh-Ebene lesen das Bild hinter sich (eine
   Bildkopie, nur solange sie zu sehen sind – nur an Tunnelausfahrten bei Tag). Eine Weißmischung ohne Kopie las sich
   milchig; Arcades Gesetz (× 1,7 + 0,25) geht nur mit dem Bild dahinter.
9. **Neue Schranke in `check_night spielerauto`**: Sättigung der Karosserie ≥ 0,7 × Arcade (vorher nur Helligkeit).'''),
('''4. Tunnel-Lampen ohne Pool-Reichweite (R5): sie zählen nicht zum Punktlicht-Pool.''',
 '''4. Tunnel-Lampen ohne Pool-Reichweite (R5): sie zählen nicht zum Punktlicht-Pool.
5. `assets/shaders/modern/flare.gdshader` steht in der W3-Spalte von §5 bei niemandem (W1: R3); R4 besitzt
   `layers/flares.gd` und hat den Shader um die Variante `CE_STREAK` (Spiegelungen auf nasser Fahrbahn) erweitert –
   Vorschlag: der Shader gehört zum Besitzer von `flares.gd`.'''),
]
for o, n in rep:
    assert s.count(o) == 1, o[:60]
    s = s.replace(o, n)
open(p, 'w').write(s)
print('ok')
