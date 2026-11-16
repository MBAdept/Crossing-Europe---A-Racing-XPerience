**Kurz:** Den einzigen hohen Befund (QR5-01, Tunnelportale nachts wie bei Tag angestrahlt) habe ich bitgleich
nachgestellt und in R5s eigener Datei behoben: das Portal-Mesh liegt jetzt auf der Bodenebene (Renderlayer 2), die das
Abblendlicht und die Lampen-Omnis auslassen – wie Arcade, das sein Portal nie mit den Scheinwerfern beleuchtet. Stirnwand
U1 22 Uhr L 79 → 56 (Arcade 46), DEV 21 Uhr L 107 → 57 (Arcade 47); bei Tag und überall sonst bitgleich mit R5. Die Tests
schützen jetzt jede Regel, die QA-R5 ungeschützt fand (5 von 5 Mutationen von benannten Tests gefangen), und der Netzlauf
vergleicht genau mit Arcade (122 Brücken, 28 Tunnel, 0 Mängel; fängt 5 von 5 eingebauten Teilverlusten). Für die
Befunde in R4s Dateien liefert R5 jetzt die Daten (`tunnel_state.light`, `tunnel_state.exit_z`); eine Probe mit R4s
Stand zeigt: R4s Belichtungsrampe löst QR5-03, setzt die Fläche aber vor R5s Ausfahrtsrahmen – eine Zeile bei R4 behebt
das (in der Probe gerendert). QR5-09 ist Last, kein Code (headless Commit ≤ 0,25 ms je Tunnelstück). Offen bei R4: Fahrbahn
in der Röhre (QR5-02), Abblendkante, Steinbrüstung (QR5-04), Schiffe (QR5-08). Gates: GATES_KURZ
