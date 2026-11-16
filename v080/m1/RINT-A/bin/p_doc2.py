import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'docs/renderer-modern-gelaende.md'
rep(p, '''9. **Lichtkegel** von Laternen und Scheinwerfern (`inc/pools.gdshaderinc`); das Material meldet sich mit
   `renderer.add_pool_material()` an.''', '''9. **Lichtkegel** von Laternen und Scheinwerfern (`inc/pools.gdshaderinc`) und das **Abblendlicht** des Spielers
   (`inc/headlight.gdshaderinc`) mit Arcades Rückstrahlfaktoren (Gras 0,45, Kiesstreifen 0,6, Pflaster 0,8, Wasser
   0,45); das Material meldet sich mit `renderer.add_pool_material()` an. Das Netz liegt wie die Fahrbahn auf
   Render-Ebene 2: die echten Spots und Punktlichter der Ebene `lights` lassen den Boden aus (renderer-modern.md
   §10.6, §12.3).''')
rep(p, '''- Setzt das Global `ce_far_y`. `--gfx-debug=far` zeichnet Signalfarben (Scheibe cyan, Kragen gelb) für die
  Render-Prüfung.''', '''- Setzt das Global `ce_far_y`. `--gfx-debug=far` zeichnet Signalfarben (Scheibe cyan, Kragen gelb) für die
  Render-Prüfung.
- Wie das Gelände: Render-Ebene 2, Lichtkegel und Abblendlicht (Gras 0,45), Material über `add_pool_material()`
  angemeldet – wo die Scheibe nahe dem Wagen durch eine Lücke der Bänder zu sehen ist, ist sie beleuchtet wie der
  Boden daneben.''')
rep(p, '''| `corridor` | im Sichtkorridor einer Kurveninnenseite (F7): schmückende Requisiten einer Landschaftsregel und jede Vegetation; Sets aus `graphics.modern.props.bend_cover` bleiben, auf höchstens `bend_cover_max_h_m` (0,5 m) verkleinert – die Liste ist leer, bis es solche Bodenbewuchs-Modelle gibt (A-3) |''',
    '''| `corridor` | im Sichtkorridor einer Kurveninnenseite (F7): schmückende Requisiten einer Landschaftsregel und jede Vegetation. Eine weggelassene Pflanze wird durch **Bodendecker** ersetzt (Nachtrag A-3): Stücke der Sets aus `graphics.modern.props.bend_cover` (`props/cover_bush`, `props/cover_grass`), höchstens `bend_cover_max_h_m` (0,5 m) hoch – eins für einen Busch, drei für einen Baum, über seinen Fuß verteilt (höchstens 2,5 m), nie näher als 0,8 m an der Fahrbahnkante (`cover_pieces()`; Liste `cover_list`, `debug().cover`). Ein Set der Liste, das die Strecke selbst setzt, bleibt und wird auf diese Höhe verkleinert |''')
rep(p, '''  eine stabile zufällige Drehung um die Hochachse; hat ein Set mehrere `variants`, wählt ein stabiler Hash aus
  Segment- und Requisitennummer (§4.6.6).''', '''  eine stabile zufällige Drehung um die Hochachse; hat ein Set mehrere `variants`, wählt ein stabiler Hash aus
  Stücknummer und Set **eine Variante je Stück** (`chunk_variant()`; §4.6.6 nennt Segment- und Requisitennummer –
  so kostete jede Variante eigene Knoten und Zeichenaufrufe). Nachbarstücke wechseln, im Stück verdeckt die
  zufällige Drehung jedes Baums die Wiederholung.''')
rep(p, '''Zeichenaufrufe je Set und Stück (Unit-Test): eine Fläche je Klasse des sichtbaren Netzes; von den Darstellungen
eines Modells ist immer nur eine sichtbar. Heute: Eiche 2 (Stamm `vpbr` + Laub `leaves`), Fernbild 1, Bauernhaus 1
je Seite, Laterne 1 je Seite, Vertretung 1 je Seite. Dazu ein Knoten der Kontaktschatten je Stück (alle Sets) und
im Schattendurchgang der Schattenwerfer der Kartenbäume.''', '''Zeichenaufrufe je Set, Stück **und Seite** (Unit-Test): eine Fläche je Klasse des sichtbaren Netzes; von den
Darstellungen eines Modells ist immer nur eine sichtbar. Heute: Eiche und Birke 2 (Stamm `vpbr` + Laub `leaves`),
Fernbild 1, Bauernhaus 2 je Seite (`baked` + Scheiben in `vpbr`, AS1b), Laterne 1 je Seite, Vertretung 1 je Seite.
Steht ein Set mit zwei Flächen auf beiden Straßenseiten, braucht es 2 × 2 Aufrufe (gespiegelter Knoten, D24) – die
Grenze „2 je Set und Stück“ des Bauplans hält dann nur je Seite. Dazu ein Knoten der Kontaktschatten je Stück (alle
Sets) und im Schattendurchgang der Schattenwerfer der Kartenbäume.''')
rep(p, '''Lichtanker mit Richtung (die Leuchte der Straßenlaterne) werden je Stück über `ctx.services.renderer.add_lamps(
holder, lamps)` angemeldet (A-7): Position und Richtung im Knoten `Props` des Stücks, Rolle `lights`, Farbe und
Größe aus dem Manifest, Kegel 9 m, Energie 0,55 (Arcades Laternenkegel). Die Ebenen `lights` und `flares` machen
daraus Lichtkegel am Boden und den Schein in der Ferne; ohne sie geschieht nichts. Fensterlicht gebackener Modelle
steckt im Nachtlicht-Atlas, nicht in Ankern.''', '''Lichtanker mit Richtung werden je Stück über `ctx.services.renderer.add_lamps(holder, lamps)` angemeldet (A-7):
Position und Richtung im Knoten `Props` des Stücks, Rolle `lights`, Farbe und Größe aus dem Manifest. Kegel und
Stärke gibt `PropLibrary.lamp_pools()`: nach unten (Laterne, Tankstellendach) 9 m und Arcades Laternenstärke 0,55,
eine Gruppe teilt sich 1,6 (Tankstellendach: acht Lampen je 0,2); Wandlampen (Bauernhaus, Scheune, Zollhäuschen)
5 m und 0,4, der Kegel liegt vor der Wand unter der Lampe; Lampen ab 25 m Höhe (Flugbefeuerung des Windrads) ohne
Kegel. Die Ebenen `lights` und `flares` machen daraus Lichtkegel am Boden und den Schein in der Ferne; ohne sie
geschieht nichts. Fensterlicht gebackener Modelle steckt im Nachtlicht-Atlas bzw. in Lampenkanal 12, nicht in
Ankern.

### 4.10 Ende der Sicht

Fernbilder und Laub blenden zwischen 0,85 und 1,0 des Nebelendes (`ce_fog_range.y`) mit geordnetem Dither aus:
jenseits davon wären sie reine Nebelfarbe – helle Flecken („Rauten“) vor den dunstigen Silhouetten des
Hintergrunds, gesehen an S1 (renderer-modern.md §12.6).''')
rep(p, '''| `graphics.modern.props.bend_cover` | `[]` | Sets, die im Kurvenkorridor als Bodenbewuchs bleiben dürfen |
| `graphics.modern.props.bend_cover_max_h_m` | 0,5 | ihre größte Höhe dort |''', '''| `graphics.modern.props.bend_cover` | `["props/cover_bush", "props/cover_grass"]` (Vorgabe im Code `[]`) | Bodendecker-Sets für den Kurvenkorridor (4.1) |
| `graphics.modern.props.bend_cover_max_h_m` | 0,5 | ihre größte Höhe dort |''')
rep(p, '''- **Bandspitzen in Kurven**: Der Kern kürzt jede Reihe nach ihrer *eigenen* Krümmung; wo sich die Krümmung entlang
  einer Kurve ändert, berühren sich die Spitzen des Bands auf ihrer Innenseite (bis 1,83 m, gezählt in
  `terrain_plan_tips`, dort ein Dreieck auf dem anderen – weit weg und meist im Nebel). Mit drei Zeilen im Kern
  (`TerrainProfile`: auch nach der stärksten Krümmung der Seite innerhalb des Korridorfensters kürzen) gibt es
  keine mehr, und `modern_sight.gd` bleibt grün (gemessen, nicht eingebaut: der Kern gehört dem Renderer-Kern).
  Danach `STRICT` in `check_terrain_plan.gd` einschalten.
- **Kahle Kurveninnenseiten**: F7 nimmt dort Bäume und schmückende Requisiten weg (an T2 38 von 135, an T4 der große
  Felsen, den Arcade zeigt). Bodenbewuchs ≤ 0,5 m kommt mit den Modellen dafür (`bend_cover`).''', '''- **Bandspitzen in Kurven**: erledigt mit der Zusammenführung – `TerrainProfile` kürzt jede Reihe auch nach der
  stärksten Krümmung ihrer Seite im Korridorfenster; `check_terrain_plan` ist streng (`STRICT`, 0 Paare an 40
  Kamerapositionen), `modern_sight.gd --full` grün.
- **Kurveninnenseiten**: F7 nimmt dort Bäume und schmückende Requisiten weg (an T2 38 von 135, an T4 der große
  Felsen, den Arcade zeigt); weggelassene Pflanzen werden seit der Zusammenführung Bodendecker (4.1). Felsen und
  Häuser bleiben weg, bis die Projektleitung mit den Bergbildern von Zwischenstand 2 entscheidet.''')
rep(p, '''- **Zeichenaufrufe bei Varianten und Spiegelung**: ein Set mit zwei Varianten oder mit Instanzen auf beiden Seiten
  braucht je Variante bzw. Seite eigene Knoten; mit zwei Flächen je Modell (Kartenbaum, Haus mit `baked_cutout`)
  wären das mehr als zwei Zeichenaufrufe je Set und Stück (heute hat kein solches Modell Varianten oder
  `mirror_left`).''', '''- **Zeichenaufrufe bei Varianten und Spiegelung**: Varianten kosten nichts mehr (eine je Stück, 4.3); ein Set mit
  zwei Flächen auf beiden Seiten braucht 2 × 2 Aufrufe je Stück (4.4).''')

p = 'docs/modelle.md'
rep(p, '''(`props3d.ROTOR_CODE`, `ROTOR_HUB_M`; Windrad 89,6 m, Windmühle 19,8 m). Der heutige `vpbr.gdshader` zeichnet sie
als feste Farbe – ein stehender Rotor. Gedreht werden sie mit einer Erweiterung im `vertex()` des Shaders um die
Z-Achse des Modells durch (0, Nabenhöhe) mit `ce_time` (auf einem Wegwerfzweig erprobt: zehn Zeilen, Bilder bei
0 / 0,4 / 0,8 s drehen sich richtig). Der Prüfer kennt den Code.''', '''(`props3d.ROTOR_CODE`, `ROTOR_HUB_M`; Windrad 89,6 m, Windmühle 19,8 m). Seit der Zusammenführung von M1 dreht
`vpbr.gdshader` sie in `vertex()` um die Z-Achse des Modells durch (0, Nabenhöhe) mit `ce_time` (1,35 rad/s, von der
Straße aus im Uhrzeigersinn, Phase je Instanz; docs/renderer-modern.md §12.5, Render-Prüfung `rotor`). Der Prüfer
kennt den Code.''')
rep(p, '''- `vpbr.gdshader`: die Rotordrehung (siehe oben).
- Requisiten-Builder: Bodendecker-Sets in Kurven-Korridoren einsetzen; Leitungen zwischen Strommasten.''', '''- Requisiten-Builder: Leitungen zwischen Strommasten. (Rotordrehung und Bodendecker in den Kurven-Korridoren sind
  mit der Zusammenführung von M1 erledigt.)''')
print('ok')
