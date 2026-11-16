# AS1R – Nacharbeit der Fahrzeugmodelle nach der Kunstkritik: Bericht

- Paket: AS1R (v0.8.0, M1) · Zweig `worktree-wf_9693abb2-cee-3` · Sicherheitskopie `origin wip/v080-as1r`
- Arbeitsbaum: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-3`
- Basis: `d025d1d` (R1a + AS1). Alle Zahlen **gemessen** auf dieser VM (Software-OpenGL llvmpipe unter Xvfb,
  Licht des Kontaktbogens), wo nichts anderes steht. Alles über Steam Deck, echte Grafikkarten und die Wirkung auf
  einen Menschen ist **abgeleitet**.

## 1. Ergebnis in Kürze

Jeder Befund der Kritik wurde zuerst am Netz oder im Bild nachgeprüft. Bestätigt und am Modell behoben: bei den
Spielerautos A2–A6 und die günstigen niedrigen A7, A10, A11; bei den Verkehrsautos B3–B7 und die Modellseite von B1;
beim Sattelzug C1–C3. Zwei Befunde hatten eine andere Ursache als vermutet (A3: die Hutablage, nicht die Heckblende;
A4 Limousine: der Boden der Innenraumwanne, nicht Radlaufschale und Schweller). Nicht erreicht: der Stufenwechsel
bei 120 m (22–34 % statt ≤ 10 %), und die Leuchten der Verkehrsautos sind weiter flache, eingeschnittene Felder (B2).
Nicht am Modell lösbar und deshalb offen für den Renderer: Lackbelichtung (A1, B8, zum größten Teil C2),
unbeleuchtete Lampen bei Tag (B1: `lamp_off`), Klarlack und Spiegelung, Kontaktschatten, Schein an den Ankern.

Prüfungen: Prüfer grün; Sprite-Geometrie 187 von 187 identisch; erzwungener Neuexport und zweiter Bake aller sechs
Fahrzeuge byte-gleich; `--check-keys` OK; `run_tests.sh` bestanden (576 Unit-Tests und 89 Prüfungen, 0 fehlgeschlagen);
`golden.sh check` 20 von 20 identisch; Render-Prüfung der Modelle 6 von 6 OK.

`showroom` bleibt für beide Spielerautos `false` (Abschnitt 6).
