# AS1 – Fahrzeugmodelle für den Schnitt: Bericht

- Paket: AS1 (v0.8.0, Bauabschnitt 1) · Zweig `worktree-wf_bade9e46-06a-1` · Stand `@@COMMIT@@` ·
  Sicherheitskopie `origin wip/v080-as1`
- Arbeitsbaum: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1`
- Alle Zahlen sind **gemessen** (Prüfer, Inspektor, Render-Prüfung auf Software-OpenGL), wo nichts anderes
  dabeisteht. Aussagen über das Steam Deck oder eine echte Grafikkarte sind **geschlossen**, nie gemessen.

## 1. Ergebnis in Kürze

Alle sechs Modelle des Pakets existieren, der Prüfer ist grün, die Budgets sind eingehalten:
zwei Spielerautos (`player/limousine`, `player/kompakt`: Rennstufe, Showroom-Stufe, Schattenwerfer), drei
Verkehrsautos (`traffic/sedan`, `traffic/hatch`, `traffic/wagon`: `lod0`–`lod2`, alle Farbsets als Lack) und der
Sattelzug (`traffic/truck`: Zugmaschine + Auflieger, vier Lackierungen).

Die Spielerautos haben jetzt Lampen mit Tiefe, durchsichtiges Glas mit Innenraum, ein ausgearbeitetes Heck und
eine Front mit Grilltiefe, Wischern und Antenne. Die Verkehrsautos sind auf glatten Lofts neu aufgebaut: straffe
Form, dieselben Konturen in allen Stufen, nichts knittert mehr. Das Heck des Lkw liest sich auf 20–150 m sofort.

Nicht erreicht: Im Showroom-Vergleich ist das Echtzeit-Bild dem Cycles-Sprite **noch nicht ebenbürtig** – das
Netz ist reicher, Lack und Licht sind flacher. `showroom` bleibt für beide Spielerautos `false` (Abschnitt 7).

## 2. Abnahmepunkte

| Punkt | Ergebnis | Beleg |
|---|---|---|
| Prüfer grün | erfüllt | `validate_models.py`: `CHECK models OK` – 10 Modelle, 180 Sets, 25 mit Modell (`pruefer_bericht.txt`) |
| Kontaktbögen Tag und Nacht mit jedem Lampenkanal | erfüllt | `01`–`04` (Nachtbögen: je Fahrzeug eine Kachel pro Lampenzustand), `05_lampenkanaele.jpg` (alle 15 Kanäle), `10_verfolger_nacht.jpg` |
| A/B Showroom-Sprite gegen Echtzeit `show`, dieselbe Kamera, beide Spielerautos | erfüllt, Entscheidung: `showroom = false` | `06_showroom_ab.jpg`; was fehlt, steht in Abschnitt 7 |
| ≤ 6 Zeichenaufrufe je Verkehrsauto in `lod0` | erfüllt | 6 (Karosserie: `vpbr` + `glass`, 4 Räder) bei Limousine, Schrägheck, Kombi; `lod1`/`lod2` je 1 |
| Geometrie-Fixture identisch | erfüllt | `check_sprite_geometry.py`: 187 von 187 Sets identisch (1 davon „REIHENFOLGE“), 0 „ANDERS“, 346 s |
| Byte-Bericht | erfüllt | Abschnitt 3, `pruefer_bericht.txt` |
| alle Tests | @@TESTS_RESULT@@ | @@TESTS@@ |
| Arcade unverändert | @@GOLDEN_RESULT@@ | @@GOLDEN@@ |
| Render-Prüfung Modelle | @@RENDER_RESULT@@ | @@RENDER@@ |

## 3. Zahlen (gemessen)

| Modell | Dreiecke je Stufe (Budget) | Aufrufe | Netze |
|---|---|---|---|
| `player/limousine` | lod0 45 764 (55 000) · show 99 670 (120 000) · Schatten 1 872 (3 000) | 6 / 6 | 1 573 290 B |
| `player/kompakt` | lod0 50 080 · show 107 042 · Schatten 1 872 | 6 / 6 | 1 742 534 B |
| `traffic/sedan` (4 Farben) | lod0 17 695 (18 000) · lod1 5 805 (6 000) · lod2 1 123 (1 200) · Schatten 636 | 6 / 1 / 1 | 260 279 B |
| `traffic/hatch` (5 Farben) | lod0 17 317 · lod1 5 753 · lod2 1 136 · Schatten 652 | 6 / 1 / 1 | 256 895 B |
| `traffic/wagon` (4 Farben) | lod0 17 888 · lod1 5 937 · lod2 1 103 · Schatten 604 | 6 / 1 / 1 | 269 062 B |
| `traffic/truck` (4 Lackierungen) | lod0 18 084 (25 000) · lod1 4 672 (7 000) · lod2 1 490 (1 500) · Schatten 356 | 13 / 1 / 1 | 160 568 B |

Zusammen 4 262 628 B (4,07 MB) für die sechs Fahrzeuge; alle Netze des Spiels 4,18 MB von 40 MB. Keine Texturen.
Export aller sechs Fahrzeuge: 31 s, Bake 0,3 s. Ein erzwungener zweiter Export ergab Byte für Byte dieselben
Karosserie-Netze (`git status` zeigte nach dem Neuexport nur die absichtlich geänderten Schattenwerfer).

Lampenflächen (projiziert, nach Wicklung, cm²; Blinker je Seite; Regel: hinten ≥ 60, vorn ≥ 40, Spielerauto vorn
≥ 15, Rücklicht ≥ 200, Bremslicht ≥ 100, Scheinwerfer ≥ 80):

| Modell, Stufe | Rücklicht | Bremslicht | Blinker hinten | Scheinwerfer | Blinker vorn |
|---|---|---|---|---|---|
| Limousine (Spieler) lod0 / show | 874 / 869 | 830 / 827 | 84 / 81 | 89 / 89 | 20 / 20 |
| Kompakt (Spieler) lod0 / show | 914 / 899 | 900 / 890 | 102 / 100 | 101 / 102 | 28 / 27 |
| Limousine (Verkehr) lod0 / lod1 / lod2 | 639 / 847 / 887 | 759 / 967 / 1 007 | 99 / 99 / 99 | 161 / 242 / 327 | 95 / 95 / 86 |
| Schrägheck lod0 / lod1 / lod2 | 727 / 902 / 965 | 846 / 1 021 / 1 084 | 95 / 95 / 95 | 195 / 273 / 360 | 112 / 100 / 95 |
| Kombi lod0 / lod1 / lod2 | 973 / 1 188 / 1 031 | 1 093 / 1 308 / 1 081 | 102 / 102 / 102 | 171 / 250 / 316 | 95 / 90 / 50 |
| Sattelzug, jede Stufe | 860 | 860 | 450 | 1 000 | 320 |

Die Blinker der Pkw sind in allen drei Stufen gleich groß: dieselbe Kontur, in jede Stufe eingeschnitten.
Im Bild der Render-Prüfung (Limousine silber von hinten, Blinker an): 390 / 390 / 390 Bildpunkte bernsteinfarben in
`lod0` / `lod1` / `lod2`; Bremslicht 2,63-mal so hell wie das Rücklicht in jeder Stufe.
Lichtanker: Verkehrsautos ≤ 3,5 mm von ihrer Lampe; Spielerautos bis 33 mm (der Anker liegt in der Öffnung der
Mulde, der Leuchtkörper bis 28 mm dahinter; „unter der Lampe“ höchstens 2,9 mm bei erlaubten 3 mm).

