import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'docs/renderer-modern.md'
rep(p, '''  2 von 3 Läufen als „ObjectDB instances leaked at exit“ (gemessen; danach 0 von 6 Läufen in Arcade, 0 von 3 in
  Modern).''', '''  2 von 3 Läufen als „ObjectDB instances leaked at exit“ (gemessen; danach 0 von 6 Läufen in Arcade, 0 von 3 in
  Modern).

### 12.9 Erst zusammen sichtbar: 3D-Auflösung und Lichtpunkte, Aufwärmen je Modell

- **Lichtpunkte bei verkleinerter 3D-Auflösung**: „Niedrig“ (die Voreinstellung für Software-Grafik) zeichnet das
  3D-Bild mit 75 % und zieht es bilinear auf (R1, `quality.gd`). Eine Heckleuchte in 150 m ist dann kleiner als ein
  Bildpunkt und fällt zwischen die Bildpunkte; ihr Lichtpunkt (R3) hatte die volle Stärke nur genau im Mittelpunkt.
  Gemessen (`check_vehicle_lights` → `bremslicht`, Tag): 150 m Rot +0,07 statt +0,57 bei 100 % – unter der Schwelle
  0,08; das widerspricht „keine Qualitätsstufe dunkelt Fahrzeuglichter ab“. `flare.gdshader` hält die volle Stärke
  jetzt bis zu einer halben Bildpunkt-Diagonale des 3D-Bilds und fällt von dort bis zum unveränderten Radius ab (der
  Schein wird nirgends schwächer oder kleiner): „Niedrig“ 150 m +0,16, 300 m +0,33; bei 100 % und „Hoch“ wie vorher
  oder heller (+0,57 / +0,55 in 150 m).
- **Aufwärmen der Requisiten je Modell**: `props.gd warmup_nodes()` gab einen Knoten je Materialklasse (das erste
  Modell der Klasse, als MeshInstance3D). Die Prüfung mit kaltem Cache (`warmup_cold.gd`, Kiel – Hamburg km 2,
  „Mittel“, 12 Uhr) zählte mit allen Inhalten **2 Varianten mitten in der Fahrt** (nach 3–6 s, auch ohne Verkehr und
  ohne HUD; Mesa bekam dabei keinen neuen GLSL-Quelltext – es waren Varianten des Treibers für ein Modell mit anderen
  Texturen oder Vertex-Daten als das erste seiner Klasse). Jetzt steht jede Darstellung jedes geladenen Modells so
  vor der Kamera, wie `commit()` sie zeichnet (MultiMesh mit einer Instanz, Schattenteile als Werfer): **0 Varianten
  während der Fahrt**, 48 statt 17 Aufwärm-Knoten, das Aufwärmen dauerte unter llvmpipe bei Last 7 rund 10 s länger
  (Übersetzungen, die sonst unterwegs gekommen wären).''')
print('ok')
