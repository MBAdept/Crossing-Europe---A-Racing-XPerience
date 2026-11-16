# Bericht RINT-A – erste Hälfte der Zusammenführung des Schubs M1 (v0.8.0)

Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1`, Zweig
`worktree-wf_c23ec0b9-e7b-1`, Sicherung `origin wip/v080-rint-a` (nach jedem Commit gepusht, nie erzwungen).
Basis: `v0.8.0` = 2b41e16 (vorgespult). Kein Vorgänger (keine STAND.md, kein Zweig `wip/v080-rint-a`).

„gemessen“ = auf dieser VM (llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne, während der Läufe Last 1–13 durch
andere Aufträge); „abgeleitet“ = gefolgert, nicht gemessen. Über eine echte Grafikkarte, das Steam Deck oder wie
etwas klingt, sagt dieser Bericht nichts Gemessenes.

__GATES__

## 1. Zusammenführung

| Schritt | Commit | Ergebnis |
|---|---|---|
| R1 (21bca09) `--no-ff` | 286e64d | ohne Konflikt |
| R2 (b947e73) `--no-ff` | 7c1a82f | ohne Konflikt |
| R3 (4d02ada) `--no-ff` | f1a2ea2 | Konflikte `contact_shadow.gdshader` (+ .uid, add/add) und `docs/renderer-modern.md` (R1 und R3 je ein §10) |
| AS1b (adff0b3) `--no-ff` | 720fa3a | ohne Konflikt |
| UI1 (3b89a33, enthält AS1 und AU-B) `--no-ff` | 4547818 | ohne Konflikt |

- **contact_shadow**: R2s Datei (Schattenfleck der Requisiten, `PropLibrary.CONTACT_SHADER`) bleibt
  `contact_shadow.gdshader` mit ihrer uid; R3s Fahrzeug-Schattenfleck heißt `vehicle_shadow.gdshader`, Klasse
  `vehicle_shadow` in `layers/vehicles.gd` (die einzige Zeile, die ich in einer Datei von R3E geändert habe), uid neu
  aus dem Import (a27d3ed). Keine Aufwärm- oder Prüfliste nannte die Klasse; `perf().contact_shadows` bleibt der
  Zählername der Fahrzeug-Ebene.
- **docs/renderer-modern.md**: R1s Abschnitt bleibt §10, R3s wird §11 (Unterabschnitte umnummeriert).
- **Manifest**: `export_models.py --manifest-only` erzeugt genau das gemergte `manifest.json` (28 Modelle, 182 Sets).
- **Import**: der erste `godot --headless --import` hing (Hauptthread drehte 15 min, Arbeiter schliefen, drei
  Texturen als 0-Byte-Reste); abgebrochen, Reste gelöscht, zweiter Lauf 8 s. Der Import auf dem Endstand ist sauber.
- `tests/check_scripts.gd` nach dem Zusammenführen: 287 Skripte, 0 fehlerhaft.

## 2. Was die Zusammenführung erst zusammen brauchte (Punkte des Auftrags)

__ITEMS__

## 3. Bilder und ehrliches Urteil

__LOOK__

## 4. Abweichungen

__DEV__

## 5. Probleme im Bauplan

__CI__

## 6. Für RINT-B und die nächsten

__NEXT__

## 7. Geänderte Dateien (seit 2b41e16 ohne die Merges)

__FILES__
