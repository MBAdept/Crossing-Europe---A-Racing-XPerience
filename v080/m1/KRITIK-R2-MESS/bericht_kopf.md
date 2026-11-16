# KRITIK-R2-MESS – Abnahmemessung des Modern-Klangs, Endstand AU-R3 (`b6339ad`)

**Prüfgegenstand:** `b6339ad4fe5d26c14e5ad4912848f32f8eb7cd5e` (`origin/wip/v080-au-r3` = AU-C1 + AU-R + AU-R2 + AU-R3),
verglichen mit AU-C1 `4209268` (der Klang, den der Nutzer auf Kopfhörern gehört hat) und, wo es hilft, mit AU-R
`3d2e6e1`. **Rolle:** unabhängige Abnahmemessung, nur lesend – keine Commits, kein Zweig, kein Arbeitsbaum eines
anderen Pakets berührt. Gemessen in drei Kopien (`git archive` + `.godot` des Hauptbaums, je einmal importiert);
jeder Lauf mit absolutem `XDG_DATA_HOME`, `nice -n 19`, ein schwerer Lauf nach dem anderen (die Maschine war mit
dem Testbuild und einem Modellpaket belastet, Last 5–8).

**Gehört hat hier niemand.** *gemessen* = Zahl aus einer Aufnahme des laufenden Spiels (Godot 4.7.2 ohne Bildschirm,
Dummy-Audiotreiber, Limousine, Kiel – Hamburg) oder aus den Dateien. *abgeleitet* = aus Code, Konfiguration oder einem
Modell geschlossen – dazu gehört jede Aussage darüber, wie etwas klingt, ob man es hört und wie es sich auf dem Steam
Deck verhält. Keine Zahl ist aus einem Bericht übernommen; wo ich eine fremde Zahl nenne, steht „(laut …)“ dabei.
Neue Zufallsfolgen: Fahrten `--seed` 7101–7801 (setzt die beiden Zufallsgeneratoren des Fahrbahn-Slots je Abschnitt neu),
Unfälle 9311 (Pkw) und 9312 (Lkw) – nicht 777/778.
Messpunkt selbst geprüft (`vol_probe.gd`): Ein `AudioEffectRecord` am Ende von `Master` nimmt **vor** dessen Lautstärke
auf (Sinus −15,05 dBFS RMS bei 0 dB und bei −20 dB Master-Lautstärke) – jede Aufnahme am Master ist der Klang bei
Gesamtlautstärke 1,0; bei der Voreinstellung 0,8 ist alles 1,94 dB leiser (in den Tabellen „@0,8“). Die Aufnahmen laufen
in Echtzeit; unter der Last lieferte der Mischer 3–5 % weniger Ton als Wanduhrzeit (20 s → 19,0–19,7 s).
Nicht Teil dieser Messung (zweiter Prüfer): Code, Auslösung, Regressionen außerhalb des Klangs, V2 (Betonanteil je Land).
