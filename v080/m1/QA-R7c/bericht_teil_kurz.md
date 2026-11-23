
## 1. Ergebnis in Kürze

- **Nichts kaputt:** Arcade 20/20 + 17/17 identisch, 808 Tests grün, 29/29 Render-Prüfungen, Sicht F1–F3/F7 und Wege
  mit `--full` grün, keine eingefrorene Datei, keine fremde Datei außer den im Brief erlaubten (gemessen).
- **Funktion im ganzen Netz:** R7c zeichnet in allen 128 Richtungen + DEV exakt dieselben 195 741 Requisiten wie der
  Stand vor ihm (43a1fcc); alle Bänder aller 77 Modelle lückenlos; Phasen gültig; `ground_sink` höchstens 0,33 m
  (gemessen).
- **Leitentscheide:** 1 (Überblenden) erfüllt – kein Stufensprung in den Clips, `check_lod_band` 0,6 % statt 7,1 %;
  2 (Fernlicht) **unabhängig nachgemessen: ±5 % erfüllt**; 3 (Flimmern) wie vom Paket gemeldet teils offen; 4 (Dämmerung)
  bei „Hoch“ gleich der Basis (warme Fensterpixel 4,7 % gegen Arcade 6,4 %); 5–8 gebaut, Instanzbudget unverändert.
- **Bild:** bei Tag in allen Städten klar besser als Arcade; bei „Hoch“ gleich der Basis (0,05–0,5 % Pixel). **Bei
  „Steam Deck“ verliert der Hamburger Speicher bei 35–60 m Details** (Türen flach, QR7c-01), **beim Countdown steht ein
  Baum im Band gerastert** (QR7c-06), ferne Fassaden sind etwas weicher (QR7c-04). Nachts und im Lyon-Vorort/Wald
  schlechter als Arcade – aber schon in der Basis bzw. in den Modellen (F-04, R7a), nicht R7c.
- **Wachen:** nur 6 von 17 Mutationen werden gefangen – Fernlicht, Flimmern, Relief, Phase, Tags und Anbau-Korridor
  sind unbewacht (QR7c-02).
- **Leistung:** Bildzeit gleich, −10–13 % Primitive, +3 (Deck) bis +27 (Hoch) Zeichenaufrufe (im Budget), Haken von
  `props.gd` 2,5–3× teurer mit Spitzen bis 4,4 ms auf dem Deck-Preset (QR7c-03).
- **Urteil:** kann in den Zusammenbau RINT-M3; vor Testbuild 2 sollten QR7c-01 (eine Konfigurationszeile) und QR7c-06
  behoben oder von der Leitung hingenommen werden; QR7c-02/03 in der nächsten Runde.
