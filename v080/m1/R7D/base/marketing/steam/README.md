# Steam-Artwork – Crossing Europe – A Racing Xperience

Bibliotheks-Artwork im Look des Titelbildschirms, damit das Spiel (Linux-Build) als Nicht-Steam-Spiel
in Steam richtig aussieht – am Linux-PC und auf dem Steam Deck. `preview.png` zeigt alles auf einen Blick.

## Dateien

| Datei | Pixel | Wofür |
|---|---|---|
| `grid_portrait_600x900.png` | 600 × 900 | Hochkant-Kachel der Bibliothek – das wichtigste Bild |
| `grid_portrait_1200x1800.png` | 1200 × 1800 | dieselbe Kachel in doppelter Auflösung (schärfer auf großen Bildschirmen und dem Steam Deck) |
| `grid_landscape_920x430.png` | 920 × 430 | Querformat-Kachel („Zuletzt gespielt“, Big Picture, breite Ansichten) |
| `grid_landscape_1840x860.png` | 1840 × 860 | dieselbe in doppelter Auflösung |
| `hero_1920x620.png` | 1920 × 620 | Hintergrundbanner der Spielseite – bewusst ohne Logo und Text, links ist Platz für das Logo |
| `hero_3840x1240.png` | 3840 × 1240 | dasselbe in doppelter Auflösung |
| `logo.png` | 2892 × 1106, transparent | Logo, das Steam über das Banner legt – **das hier in Steam verwenden** |
| `logo_1280x720.png` | 1280 × 720, transparent | dasselbe Logo auf einer festen 16:9-Fläche, nur für Werkzeuge, die genau dieses Format verlangen (in Steam würde es durch den leeren Rand kleiner) |
| `logo_wide.png` | 5358 × 602, transparent | Alternative: einzeiliges Logo |
| `icon_512.png`, `icon_256.png` | 512 × 512, 256 × 256 | quadratisches Icon |
| `icon.ico` | 16 bis 256 px | dasselbe Icon als ICO, die Kleinstgrößen 16/24/32 px sind eigens geschärft |
| `preview.png` | | Übersicht samt Steam-Vorschaugrößen (nicht für Steam gedacht) |

Pro Format reicht eine Auflösung; die doppelte sieht auf hochauflösenden Bildschirmen schärfer aus.

## In Steam einrichten (Linux / Steam Deck)

Auf dem Steam Deck dafür in den Desktop-Modus wechseln und dort in Steam genauso vorgehen; danach
erscheint das Artwork auch im Spielmodus. Je nach Steam-Version können Menüpunkte leicht anders heißen.

1. **Spiel hinzufügen:** in der Bibliothek unten links *Spiel hinzufügen* → *Ein Nicht-Steam-Spiel
   hinzufügen*, dort über *Durchsuchen* die Datei `CrossingEurope.x86_64` auswählen und hinzufügen.
2. **Hochkant-Kachel:** in der Bibliothek Rechtsklick auf die Kachel des Spiels → *Verwalten* →
   *Eigenes Artwork festlegen* → `grid_portrait_600x900.png` (oder die 1200 × 1800).
3. **Querformat-Kachel:** genauso, nur auf der breiten Kachel des Spiels, z. B. unter *Zuletzt gespielt*
   oder in den horizontalen Ansichten → `grid_landscape_920x430.png` (oder die 1840 × 860).
4. **Hintergrund:** die Spielseite in der Bibliothek öffnen, Rechtsklick auf das Banner oben →
   *Eigenen Hintergrund festlegen* → `hero_1920x620.png` (oder die 3840 × 1240).
5. **Logo:** Rechtsklick auf das Banner → *Eigenes Logo festlegen* → `logo.png`. Steam setzt es unten
   links auf das Banner; Größe und Position lassen sich danach per Rechtsklick auf das Logo anpassen.
6. **Icon:** Rechtsklick auf das Spiel → *Eigenschaften*, dann auf das (leere) Icon-Feld neben dem
   Namen klicken → `icon.ico` (oder `icon_256.png`).

## Neu erzeugen

Alle Bilder entstehen aus drei Skripten in `tools/steam/`; Zwischenstände landen standardmäßig in
`/tmp/crossing-europe-steam/`. Aufruf im Wurzelverzeichnis des Repositorys:

```sh
# 1. Logo-Schriftzüge: Godot 4.7 rendert die echten Titelbildschirm-Widgets (ca. 15 s)
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
    --audio-driver Dummy -s res://tools/steam/render_logo.gd
# 2. 3D-Szenen: ein Python mit Blender 5.2 als Modul (bpy), Cycles auf der CPU (ca. 18 min auf 4 Kernen)
CE_THREADS=4 python tools/steam/keyart_scene.py \
    --shots portrait,landscape,hero,icon_bg
# 3. Zusammensetzen (python3 mit Pillow und numpy, ca. 20 s) – schreibt nach marketing/steam/
python3 tools/steam/compose.py
```

- Szene (`keyart_scene.py`): Kamera, Sonne, Berge, Straße usw. pro Format in `SHOTS`;
  `--scale 0.25` rendert in etwa einer Minute kleine Vorschauen (`*_pv.png`).
- Layout (`compose.py`): Logo-Größe und -Position sowie das Icon stehen oben in `PORTRAIT`,
  `LANDSCAPE`, `ICON` und `SMALL`. Jeder Lauf prüft, dass das Logo Sonne, Auto, Bergkämme und Ränder
  freilässt.
- Andere Ordner: `-- --out=DIR` (Godot), `--out DIR` (Blender), `--logo-dir`, `--scene-dir`, `--out`
  (`compose.py`) oder die Umgebungsvariablen `CE_LOGO_OUT`, `STEAM_SCENE_OUT`, `STEAM_ART_OUT`.
- Die leere Datei `.gdignore` sorgt dafür, dass Godot diesen Ordner weder importiert noch ins Spiel
  exportiert.
