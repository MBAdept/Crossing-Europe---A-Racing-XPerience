
## 8. Hinweise für die nächste Runde

- **Kurveninnenseiten (A-17 → R7):** T1–T4 zeigen innen keine Bäume und Felsen, wo Arcade welche hat – der größte
  sichtbare Unterschied zu Arcade in dieser Montage.
- **Lack:** Gran Turismo (Modell silbern, Arcade dunkel blaugrau, N2 0,77×) und Kompakt nachts (1,23×) sind
  Asset-Fragen; die Limousine in der Dämmerung (19:30) grau-lila statt Blau (Farbton 271° statt 242°) – vermutlich der
  Abendhimmel im Lack, nicht untersucht.
- **`collect()` auf dem Deck:** in einem Lauf auf der VM alle Bausteine ≤ 1,36 ms; Höchstwerte streuen auf der
  belasteten VM bis 4,19 ms (Requisiten) – auf dem Gerät oder mit mehreren Läufen bestätigen.
- **Wald 216 von 230** Instanzen mit 48 gleichzeitig gezeigten Autos: wenig Luft; harte Obergrenze gezeigter
  Modellautos oder größerer globaler Puffer (Vertragsfrage §6).
- **Grenzstation Amsterdam – Lüttich km 210,175:** Endstütze gegen „town_ahead“ (22 %) – keine Spieltafel, gelistet.
- **Offen aus den Vorpaketen:** Geländewasser unter Brücken (FIX-R5 8.6), Mondlichtstreifen am Portalhügel
  (NACH-R5 N-01), Abblendlicht ohne Hell-Dunkel-Grenze, die Limousine im Tunnel dunkler als Arcade.
- **Tests:** `test_chunk_services` „services_reach_collect_and_commit_on_the_main_thread“ fiel in einem Einzellauf
  dieser Montage (06:13 Uhr, neben anderer Last) einmal aus – „commit() je gebautem Stück: erwartet 25, ist 23“ –,
  in der Wiederholung und in den vollen Läufen grün; vermutlich zeitabhängig (gefolgert) – beobachten.
- **Werkzeug:** ein Hilfsskript ohne `XDG_DATA_HOME` traf den echten Benutzerordner (§6); `tools/ab_shot.sh` und
  `tools/ab_clip.sh` legen ihren Ordner unter `TMPDIR` an – in Paketen mit der XDG-Regel `TMPDIR` in den Arbeitsordner
  setzen.
- Lackflackern des weißen Autos: weiter pausiert (A-21), hier nichts geändert.
