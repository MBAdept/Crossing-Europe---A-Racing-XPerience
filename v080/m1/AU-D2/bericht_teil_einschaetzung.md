## 5. Ehrliche Einschätzung: was der Spieler hören wird

**Was gemessen gut ist**

- Die Technik der neuen Stücke ist so sauber wie bei „Linke Spur“: −14,2 LUFS, True Peak nach Vorbis −1,5 bis
  −1,8 dBTP, Schleifen ohne messbaren Sprung, der Schluss auf dem Taktstrich ohne Lücke und ohne doppelten Schlag –
  auch die Varianten Rekord und Finale (Abschnitt 3).
- Die Noten stimmen mit der Partitur überein (89–93 % der Takte, der Rest sind Farbakkorde), die Tonarten werden
  erkannt, alle 15 Zusatzclips stehen in der Tonart ihres Stücks.
- Die Klangbalance der neuen Rennstücke liegt in jedem Band höchstens 1 dB neben „Linke Spur“, deren Stil der Nutzer
  bestätigt hat – dieselben Instrumente, dieselbe Misch- und Master-Kette. Der Markenklang ist also messbar derselbe;
  ob die Stücke auch so *wirken*, ist eine andere Frage (unten).
- Das Profil Arcade spielt nichts Neues (geprüft: kein Modern-Klang geladen, auch nach Stinger-Ereignissen und
  UI-Klängen).

**Was niemand weiß, weil niemand es gehört hat**

- Ob die Melodien tragen, ob „Nachtfahrt“ mit ihrem Halbtakt-Groove dunkel-spannend oder eher träge wirkt (105 bpm
  ist das langsamste der drei Tempi) und ob „Rückenwind“ mit 150 bpm treibt oder hetzt. Das lässt sich nicht messen.
- Wie Ziel-Schlag und Stinger im Rennen gegen Motor, Wind und Sirene wirken: Ihre Dateipegel sind gemessen (−15 bis
  −19 LUFS, also etwa 4–8 dB über dem um 9 dB abgesenkten Stück – abgeleitet), die ganze Kette mit dem Auto nicht
  (gehört AU-E). Die Szene in `stinger_im_rennen_….mp3` ist ohne Auto gemischt. „Tank leer“ ist der leiseste Clip
  (ein seufzender Abstieg, −18 bis −19 LUFS) – vielleicht zu leise.
- Ob der Hook der Titelmelodie im Zwischenspiel nach vielen Etappen nervt (die Schleife ist 76,8 s lang).
- Wie die UI-Klänge neben der Menümusik wirken (Pegel abgeleitet, nicht in der Kette gemessen) und ob sie zu
  „musikalisch“ sind – sie sind aus dem gezupften Synth und der Glocke der Musik gebaut.

**Was bekannt nicht gut ist**

- „Linke Spur“ behält das leise Knacken am Ende der weichen Lead-Phrasen (Breakdown, Kehre; der Ausklang endet
  34 dB unter der Spitze der Phrase abrupt), weil ihre Hauptdatei bitgleich zu den Hörproben bleiben sollte, die der
  Nutzer heute Abend hört. In den neuen Stücken und allen Zusatzclips ist es behoben; für Stück 1 ist es eine Zeile
  beim nächsten Rendering.
- Mit dem Regler „Musik“ auf 0 ist das Ziel im Profil Modern still – der Zielklang ist jetzt Musik.
- `ui_tab`, `ui_toggle`, `ui_error` klingen erst, wenn die UI sie aufruft (UI2).
- Ein Rennen hört drei Stücke reihum: Ab der vierten Etappe wiederholt sich die Musik (Stücke 4–5 nicht gebaut).
