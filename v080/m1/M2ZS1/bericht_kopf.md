# M2ZS1 – der erste Testbuild (ZS1) in der M2-Linie (Bericht)

Paket **M2ZS1** des Schubs M2: die Behebungen, die nach M2INT in den ersten Testbuild gingen (FIX-ZS1, FIX-WASSER,
FIX-WASSER-R = `39849f0`, beim Nutzer), in die M2-Linie (M2INT `49f221e`) zusammenführen und prüfen, ob jede mit dem
Inhalt von M2 noch hält. Kein Vorgänger (keine `STAND.md`, kein `wip/v080-m2zs1`) – frisch begonnen mit
`git merge --ff-only 49f221e`. Branch `worktree-wf_438996b0-243-2`, Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-2`; jeder Commit gepusht nach
`origin/wip/v080-m2zs1` (Sicherung) und `origin/wip/v080-m2int` (Fast-Forward von `49f221e`).
Commits: `25be6c7` (Merge), `efff1ed` (Pylon nachts, Flugbefeuerung), `b693d33` (`night_albedo` 0,45, Doku),
`6e48405` (Modern-Änderungsmelder, QA-Doku) – **Endkopf `6e48405`**.
„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne); alles über Steam Deck, echte
Grafikkarten, ANGLE/Direct3D und wie etwas auf einen Menschen wirkt, ist **abgeleitet**.

## Urteil

**ZS1 ist in der M2-Linie, und jede seiner Behebungen hält – eine erst nach Nacharbeit.**

- Start bei km 0: das Auto steht im Countdown und 1,5 s nach „LOS!“ an Arcades Stelle (Lackfläche ±1 %, wie FIX-ZS1),
  auch in der Steam-Deck-Stufe; die Lampenringe des Starttors werfen bei „Aus“ keinen Schatten.
- Fernboden: **eine Regel**, die von FIX-WASSER (der Nutzer hat sie); M2INTs eigene Behebung `b341df8` deckte nichts
  darüber hinaus ab und entfällt, ihr Unit-Test bleibt (umgestellt). Elbe und Nord-Ostsee-Kanal liegen unter den
  Brücken wie in ZS1.
- Wahrzeichen-Ersatz der sechs Städte: auf allen 20 Anfahrten da – seit AS4R als Kirchen- bzw. Hochhaus-**Modell**
  (ungetönt).
- **Pylone nachts: nach dem Zusammenführen wieder hellgrau** (84,4 gegen Arcade 60,1): der Pylon ist seit AS4R ein
  Modell, dessen Nachtatlas der angestrahlte Pylon des Sprites ist, und der Mond hellt den hellen Beton auf. Behoben
  (Kopie des Materials ohne Nachtatlas, `night_albedo` 0,45): entlang der ganzen Brücke höchstens Arcade und höchstens
  ZS1 (km 78,1: 55,9). Die **rote Flugbefeuerung blinkt** jetzt wie in Arcade.
- Modern-Änderungsmelder nach dem Ansehen neu: Start und S4 neu, die anderen vier MD5-gleich mit M2INT.
- **Alle Gates grün auf `6e48405`** (gemessen): Import sauber, 310 Skripte, `run_tests.sh` 749/0, Arcade 20/20 und
  17/17 identisch, Modern 6/6 + OpenGL ES, **Render-Prüfungen 19/19** (`check_light_base` jetzt grün, `check_start_km0`,
  K1), Sicht und Pfad `--full`, Builds im Größenbudget (Zip 194,5 MB), Rauchtests Linux, OpenGL ES und Windows/Wine.
- Ehrlich zum Bild: an den geprüften Stellen ist M2ZS1 **nirgends schlechter als ZS1** und an der Köhlbrandbrücke
  nachts besser (Elbphilharmonie und Michel beleuchtet, Seile dünn); gegen **Arcade gleichwertig, nicht deutlich
  besser** – in Belgrad schlechter (generische Kirche statt der Kuppelkirche, wie schon in ZS1).
