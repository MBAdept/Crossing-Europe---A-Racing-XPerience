# R5 – Tunnel und Brücken, Wasser und Ufer (Bericht)

Paket **R5** der Welle 3 von M2 (Modus „Modern“, v0.8.0): Tunnel und Brücken – nach Entscheidung der Leitung auch
Wasser, Ufer, Kaimauern, Böschungen, Fernwasser und Fernufer. Branch `worktree-wf_fd1de4ee-28b-2`, Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2`, Basis `6e48405`
(`origin/wip/v080-m2int`, per `git merge --ff-only`); jeder Commit gepusht nach `origin/wip/v080-r5` (Sicherung, nie
force). Der Lauf wurde viermal unterbrochen (Container-Neustarts, Nutzungsgrenze); jeder Nachfolger hat nach `STAND.md` im selben
Worktree weitergemacht (keine Arbeit verloren, nichts doppelt). „gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb
bzw. headless, 4 geteilte Kerne, Last 10–27 durch die Nachbarpakete); alles über Steam Deck und echte Grafikkarten ist
**abgeleitet**. Schwere Läufe einer nach dem anderen, mit `nice -n 19`, ab dem Erscheinen von `QA_M2_FERTIG` (15.11. gegen 13 Uhr)
mit `nice -n 10`.

**Kurz:** Tunnel mit Arcades Gehwegen, Fliesenpaneelen, Nischen, Notausgängen, Lüftern, Portalrahmen und Arcades Hügel;
Brücken mit eigenem Builder (Wasser, Ufer nach Arcades Regel, Tragwerk je Typ, Pylone der Köhlbrandbrücke mit Seilen
und blinkender Flugbefeuerung, Fachwerkträger und -portale, Steinbögen, Brückenlampen); Fernwasser, Fernland und
Fernufer jenseits der Bänder. Holtenau liest sich wieder als Kanal, das Köhlbrand-Ende als Kai; die Elbbrücken haben
Arcades Fachwerkträger. Keine Datei außerhalb des R5-Eigentums geändert (auch `props.gd` nicht – sein `skip_bridge`
gab es schon) außer der Zeile `modern_s4_mittel` in `tests/golden/modern_slice.md5` (gewollte Bildänderung, angesehen). Arcade bitgleich (20/20, 17/17); die Gates sind grün bis auf Ausfälle unter Last (Waldprüfung, drei
Echtzeit-Klangprüfungen), die einzeln grün nachgeprüft sind (Abschnitt 6). Schwächen, die an fremden Dateien hängen
(Abblendlicht, Fahrbahn im Tunnel, Ausfahrt, Steinbrüstung), stehen offen in Abschnitt 3 und 8.
