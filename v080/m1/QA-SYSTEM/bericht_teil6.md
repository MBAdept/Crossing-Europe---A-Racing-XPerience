## 6. Modell-Pipeline

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| `validate_models.py --report` (inkl. dekodierter Ecken über `inspect_models.gd`) | **OK**: 28 Modelle, 182 Sets (40 mit Modell, 142 Platzhalter); Netze 4,47 MB von 40 MB, Texturen 15,94 MB Grafikspeicher von 240 MB, Quellen 10,29 MB von 60 MB (gemessen) | `validate.log` |
| Manifest neu erzeugt (`export_models.py --manifest-only`) | **byte-gleich** mit dem eingecheckten (md5 8ab4951b…), Arbeitsbaum danach sauber | `python3 tools/blender/export_models.py --manifest-only`, `md5sum` davor und danach |
| Export-Determinismus (erzwungener Export aus den Generatoren mit Blender 5.2, neu gebacken, `git status`) | **byte-gleich** für alle sechs Stichproben (siehe 6.1); `--check-keys` OK | `exportdet/`, `export_det.out` |
| Größen im Build (`tools/pck_report.py`) | siehe Abschnitt 5.6 | `build_*.log` |

### 6.1 Export-Determinismus

`bin/export_det.sh` (gemessen, 161 s): sechs Modelle, die alle Materialwege abdecken, mit `--force --jobs=1` aus den
Generatoren neu exportiert und mit `bake_models.gd --only=…` in `assets/models` gebacken – danach ist
`git status -- assets/models` **leer**, die eingecheckten Dateien entstehen also Byte für Byte wieder:

| Modell | Weg | Export | Ergebnis |
|---|---|---|---|
| `player/kompakt` | Spielerauto, Aufkleber als Geometrie, `show`, Schatten | 15,9 s, 147 856 Dreiecke, 5 Netze | byte-gleich |
| `traffic/hatch` | Verkehr LOD0–2, Lampenkanäle | 3,4 s | byte-gleich |
| `props/tree_birch` | Kartenbaum mit Blattatlas und Ersatzbild | 6,7 s | byte-gleich |
| `props/haybale`, `props/customs_booth` | Cycles-gebackener Atlas | 30,2 s / 27,7 s | byte-gleich |
| `props/streetlight` | Lampenkanal 12 mit Lichtankern | 0,2 s | byte-gleich |

Dazu `export_models.py --check-keys`: „28 Modelle: ein geänderter Lack, Metallwert, Blickwinkel oder eine Markierung …
ergibt für genau die betroffenen Modelle einen neuen Schlüssel“ – OK. (RINT-B hatte Lkw und Limousine geprüft, AS1b alle
21 Requisiten; hier unabhängig eine Stichprobe über alle Wege.)

