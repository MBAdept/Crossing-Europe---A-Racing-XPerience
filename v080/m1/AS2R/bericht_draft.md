# AS2R – Nacharbeit der Fahrzeugmodelle nach der Kunstkritik: Bericht

- Paket: AS2R (v0.8.0, Vorstart M2) · Zweig `worktree-wf_72970c4d-66e-4` · Sicherheitskopie `origin wip/v080-as2r`
- Arbeitsbaum: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-4`
- Basis: `19624cd` (AS2a + AS2b, ff). Commits: {COMMITS}
- **gemessen** = auf dieser VM gemessen (Software-OpenGL llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader `vpbr`/`glass`
  über `ModelFactory`, das Licht-Rig des Kontaktbogens mit dem **Renn-Look** der Fahrzeug-Ebene). **abgeleitet** =
  hier nicht messbar (echte Grafikkarte, Steam Deck, das Licht von R1/R4, die Wirkung auf einen Menschen).
- Werkzeug der Vergleiche: der Renderer und die Auswertungen der Kritik KRITIK-2 (`kritik_render.gd`, `sheet_*.py`,
  `mesh_analysis.py`, `lamp_vis.py`), unverändert kopiert und auf diesen Arbeitsbaum gerichtet, dazu eigene kleine
  Auswertungen (Abschnitt 11). Die Zahlen „vorher“ sind die der Kritik (gleiche Werkzeuge, Stand vor AS2R) oder
  eigene Messungen vor der jeweiligen Änderung.

## 1. Ergebnis in Kürze

{SUMMARY}

## 2. Befunde der Kritik: geprüft, Ursache, Änderung, Messung

{TABLE}

## 3. Nicht umgesetzt oder anders als vorgeschlagen

{REJECTED}

## 4. Selbstprüfung Lkw, Bus, Polizei (Modelle von AS2b)

{HEAVY}

## 5. Messungen

{NUMBERS}

## 6. Showroom-Schalter

{SHOWROOM}

## 7. Gates

{GATES}

## 8. Was die Modelle vom Renderer brauchen (R1, R3, R4, UI1)

{RENDERER}

## 9. Vertragsfragen

{CONTRACT}

## 10. Bilder in diesem Ordner

{IMAGES}

## 11. Geänderte Dateien und Werkzeuge

{FILES}
