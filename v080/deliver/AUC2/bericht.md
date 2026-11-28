# AU-C2 – Welt, Ambiente, Verkehr, Martinshorn (Bericht der Leitung)

Stand: 28.11.2026, Kopf 17bda1c. Zweig wip-v080-welle6 (origin wip/v080-welle6). Gehört hat es niemand – alles ist gemessen;
das Urteil über den Klang liegt bei dir. Hörproben liegen in diesem Ordner.

## Kurzfassung

- **Vorher** liefen im Modern-Klang für Umgebung, Verkehr, Martinshorn und Raumhall nur Platzhalter: die
  Arcade-Klänge des Verkehrs, die Arcade-Regenschleife, der Arcade-Tunnelhall. Im schlimmsten Fall (Tunnel, Lkw,
  Martinshorn, Aufprall, Musik) trieben sie den Begrenzer um gut 4 dB.
- **Jetzt** gibt es:
  - einen **Raumklang je Umgebung**: offen, Wald, Tal mit Echo von den Hängen, Felseinschnitt, Stadt, Brücke,
    Tunnel, Tankstellen- und Grenzdach; Schnee dämpft.
  - etwas mehr **Breite für das eigene Auto**.
  - **zehn Klangteppiche**: Wind, Wald, Grillen, Zikaden, Stadt bei Tag und Nacht, Wasser, Tunnellüfter,
    Dachbrummen, Regen.
  - **zufällige Einzelrufe**: Amsel, Buchfink, Meise, Krähe, Lerche, Specht, Waldkauz, Hund, Spatzen, Tauben,
    Hupe, Kirchenglocke, Roller, Möwen, Schiffshorn.
  - **eigene Verkehrsklänge** mit mehr Motorvarianten und einem Elektroauto, nassen Reifen im Regen, Luftstoß
    vorbeifahrender Lkw, seltenem Hupen und einem neuen **Martinshorn**.
- Nichts davon klingt im Arcade-Modus; die Arcade-Dateien sind unverändert.

## 1. Zum Anhören (dieser Ordner)

| Datei | Inhalt |
|---|---|
| `rundfahrt_alle_szenen.mp3` (+ `.txt` mit Zeiten) | neun Szenen am Stück im Spielmix (Auto, Verkehr, Ambiente, Raumklang; ohne Musik), Limousine |
| `01_hamburg.mp3` … `09_tankstelle.mp3` (+ Spektrogramm) | dieselben Szenen einzeln |
| `klangbausteine.mp3` (+ `.txt`) | jeder neue Klang einzeln, auf gleiche Lautheit gebracht – im Spiel sind sie viel leiser und gemischt |

Die Szenen: Hamburger Innenstadt am Hafen um 9:30 Uhr im Stand und mit 45 km/h · Elbtunnel mit Lkw · Heide-Autobahn mit
140 km/h (Lkw überholen, ein Pkw überholt uns, eine Polizeistreife mit Martinshorn fährt vorbei) · Auffahrunfall, der
andere hupt · Wald bei Kassel im Morgenchor · Bergland nachts im Stand, dann Regen · bei Montpellier mittags ·
Alpental (Echo) · Tankstelle nachts unter dem Dach.

Worauf du achten könntest: ob die **Vogelrufe** natürlich klingen (sie sind Modelle, keine Aufnahmen), ob das
**Martinshorn** passt, ob das Ambiente im Stand **zu leise oder zu aufdringlich** ist, und ob der **Tunnel** zu hallig
ist.

## 2. Was neu ist

- **Raumklang je Umgebung** (frühe Reflexionen und Hall): offen, Wald, Tal mit einem Echo von den Hängen, Felseinschnitt,
  Stadt, Brücke, Tunnel, Tankstellen- und Grenzdach; Schnee dämpft. Godot springt beim Umstellen von Echozeiten hörbar
  (im Quelltext nachgelesen) – die Zeiten wechseln darum nur, während das Echo kurz stumm ist.
- **Breite des eigenen Autos**: ein kurzer Raum nur oberhalb von etwa 600 Hz. Vollgas: Kanalkorrelation Limousine
  0,87 → 0,81, Gran Turismo 0,70 → 0,62, Kompakt 0,91 → 0,85; dabei 0,4–0,6 dB lauter (der Pegelplan hält). Im
  Leerlauf bleibt das Auto mittig – dort liegen fast nur tiefe Töne, und die sollen nicht zur Seite wandern.
- **Zehn Klangteppiche**, je nach Ort, Klima, Uhrzeit und Wetter: Wind, Wald, Grillen (nachts, im Norden weniger),
  Zikaden (am Mittelmeer), Stadt bei Tag und Nacht, Wasser (Brücken über Wasser, Küste, Hafenstädte), Tunnellüfter,
  Brummen unter Dächern, Regen. Mit dem Tempo werden sie leiser – bei Reisetempo deckt das Auto sie ohnehin zu.
- **Einzelrufe**, zufällig verteilt: Amsel, Buchfink, Meise (morgens mehr), Krähe, Lerche, Specht, Waldkauz, Hund in
  der Ferne, Spatzen und Tauben in der Stadt, eine Hupe ein paar Straßen weiter, Kirchenglocke in Altstädten,
  Motorroller, Möwen und Schiffshorn am Wasser. Weil sie einzeln gestreut werden, wiederholt sich nichts im Takt.
- **Verkehr**: das bewährte Arcade-Motormodell, aber mehr Abwechslung (zwei weitere Motorvarianten, ein Elektroauto),
  nasse Reifen im Regen, ein Luftstoß, wenn ein fahrender Lkw oder ein Auto dicht vorbeizieht, seltenes Hupen (nach
  einem Zusammenstoß oder wenn man sich sehr knapp und schnell vorbeidrängt; die Polizei hupt nie).
- **Martinshorn**: dieselbe Tonfolge wie in Arcade (a¹/d²), neuer Klang einer echten Anlage mit Trichterlautsprecher,
  räumlich mit Doppler.
- Kein **Donner** (das Spiel hat keine Blitze) und keine **Martinshörner je Land** (laut Vertrag nicht in v0.8.0).

## 3. Gemessen

| Szene | Spielmix (LUFS integriert / Kurzzeit höchstens) | nur Ambiente | nur Verkehr (momentan höchstens) |
|---|---|---|---|
| Hamburg, Hafen-Innenstadt | −20,2 / −17,6 | −33,0 | – |
| Elbtunnel mit Lkw | −16,8 / −16,3 | −36,9 | −20,4 |
| Heide, 140 km/h, Polizei fährt vorbei | −15,8 / −13,9 | −45,6 | −14,7 |
| Auffahrunfall, Hupe | −20,3 / −19,2 | −45,2 | −24,3 |
| Wald im Morgenchor | −20,9 / −20,1 | −35,9 | – |
| Bergland nachts, dann Regen | −23,4 / −22,0 | −31,5 | – |
| Mittelmeer | −21,7 / −21,1 | −33,8 | – |
| Alpental | −17,1 / −16,7 | −41,6 | – |
| Tankstelle nachts | −24,8 / −24,4 | −37,1 | – |

- **Der schlimmste Fall** (Tunnel, zwei Lkw dicht, Polizei 12 m hinten mit Martinshorn, Rennmusik, 230 km/h, schwerer
  Aufprall auf einen Lkw, Leitplanke, zweiter Aufprall): nach dem Begrenzer **−3,58 dBTP** (erlaubt höchstens
  −0,5), bei voller Gesamtlautstärke −1,50 dBTP. Vor dem Begrenzer +1,4 dBFS statt +4,1 mit den Platzhaltern.
  Ehrlich: In genau dieser Szene arbeitet der Begrenzer schon vor dem Aufprall fast durchgehend um 2–4 dB, weil der
  Tunnelhall alles um 3–5 dB anhebt. In einer normalen Tunnelfahrt mit Lkw erreicht er seine Grenze nur in einem
  einzigen Moment.
- **Platz**: alle Modern-Klänge außer Musik 22,23 von 23 MB (vorher 19,00) – Ambiente 1,85 MB, Verkehr 1,34 MB.
  Damit die Verkehrsschleifen hineinpassen, sind sie Ogg statt WAV (Vertragsnachtrag A-35).
- **Rechenzeit** je Bild: Raumklang 0,017 ms, Ambiente 0,036 ms, Verkehr 0,014 ms (ohne das Setzen der Player).

## 4. Unabhängige Prüfung

Ein zweiter Prüfer hat den Code ohne meine Schlussfolgerungen gelesen: 11 Befunde, alle behoben und mit Tests gesichert.
Die drei wichtigsten:
1. **Das Ambiente verstummte in jeder Pause** – das Spiel meldet in der Pause weder Fahrt noch Zustand, und mein Test
   hatte einen Zustand gebaut, den es nie gibt. Jetzt läuft es in der Pause 6 dB leiser weiter, geprüft über die
   echte Pause.
2. **Eine Hupe aus nächster Nähe** hätte −6 LUFS erreichen und alles um 5 dB wegdrücken können. Jetzt höchstens
   −15 LUFS, innerhalb von 6 m gleich laut.
3. **Die Tunnellüfter klangen nach der Ausfahrt 2–3 s nach** – jetzt nach einer Sekunde fast weg.

Außerdem: Zone in Pause und Hängern gehalten, Echozeiten erst nach dem Leerlaufen umgestellt, keine Hupe in der Pause,
kein Unbeteiligter hupt, wenn man die Polizei anrempelt, lange Klänge (Glocke) werden nicht mehr abgeschnitten,
Rückfall auf Arcade-Klänge mit Arcade-Pegel, die Verkehrspegel-Tests rechnen jetzt unabhängig nach.

## 5. Prüfungen

Alle Prüfläufe auf dem Kopf 17bda1c (28.11., 07:09–10:28 Uhr):

| Prüfung | Ergebnis |
|---|---|
| Arcade-Bilder (`golden.sh check`) | 20 von 20 und Menüs 17 von 17 identisch – Arcade unverändert |
| Modern-Bilder (`golden.sh modern-check`) | 6 von 6 identisch; OpenGL ES gegen OpenGL höchstens 2/255 (PSNR 73,2 dB) |
| ganze Testsuite (`run_tests.sh`) | 876 Tests, 0 fehlgeschlagen; alle Prüfungen in Ordnung (darunter die Arcade-Fingerabdrücke des Klangs) |
| Klangprüfung (`audio_qc.py --determinism`) | 143 Klänge, 0 Fehler; jeder der 12 Generatoren zweimal gleich; Klänge 22,23 von 23 MB, Musik 18,54 von 25 MB |
| Render-Prüfungen (`run_render_checks.sh all`) | 33 von 33 Dateien in Ordnung |

Ehrlich angemerkt: Nach der 33. Datei brach das Prüfskript selbst mit einem Syntaxfehler ab – ich hatte es für das
nächste Paket (AU-E) geändert, während es noch lief, und Bash liest Skripte stückweise. Alle 33 Einzelurteile waren
da schon „in Ordnung“; die Datei selbst ist fehlerfrei. Die Prüfungen von AU-E laufen ohnehin noch einmal über alles.

## 6. Offen

- **Hören** – alles oben ist gemessen, nicht gehört.
- Tunnel insgesamt eher laut (siehe schlimmster Fall) – **in AU-E schon nachgestellt**: frühe Reflexionen −10 statt
  −7 dB, Hallanteil 0,22 statt 0,30; bei 120 km/h macht der Tunnel die Mischung jetzt 3,7 statt 5,3 dB lauter. Die
  Hörproben in diesem Ordner sind noch mit den Werten von AU-C2; Ambiente-Pegel und Rufraten sind Startwerte (in der
  Konfiguration `audio.modern.ambience`, `traffic`, `env`) und gehören in die Gesamtabstimmung AU-E.
- Platz: noch 0,77 MB für weitere Klänge.
- Donner und Martinshörner je Land: später, wenn gewünscht.

Doku: `docs/audio-modern.md` Abschnitt 16; Vertrag A-35. Werkzeuge der Messungen: `scratchpad/v080/m1/AUC2/tools/`.

