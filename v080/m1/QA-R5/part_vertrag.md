### 7.1 Vertragsfragen (mit Beleg)

1. **Geländer an Brücken fallen zwischen die Pakete.** Inventar B / §6 R5 nennt „railings per type“ als R5-Ausgabe,
   §5 Spalte W3 gibt `builders/roadside.gd` R4. Folge: die Steinbrüstung (QR5-04) hat in Welle 3 keinen Besitzer, der
   sie zu Arcades Docken bringen muss. Vorschlag: Geländer an Brückensegmenten in R5s Eigentum (Welle 4) oder als
   ausdrücklicher Auftrag an R4/FIX-M2.
2. **A-16 „R5 sets boats on the water surface“** ist ohne eine Zeile in R4s `props.gd` nicht erfüllbar (QR5-08).
3. **Modern-Änderungsmelder in Welle 3.** `tests/golden/**` hat in W3 keinen Besitzer („–“), aber jedes Paket, das ein
   Modern-Bild gewollt ändert, macht den Melder rot. R5 hat die Zeile selbst geändert (QR5-07). Vorschlag: der Merge
   (RINT-M2) erzeugt `modern_slice.md5` neu; Pakete melden die betroffenen Zeilen nur.
4. **F1/F7 für Bauten.** `modern_sight.gd` kennt nur Kamera und Gelände; ob Tunnelwände, Portale, Träger, Pylone und
   Kaimauern Spuren oder Sichtkorridore verdecken, prüft nur jedes Paket in seinen eigenen Unit-Tests (R5: drei Brücken,
   drei Tunnel). Vorschlag: ein gemeinsamer Netzlauf „nichts über den Spuren unter 4,5 m, nichts im Korridor“ über die
   Ausgaben aller Builder (wie `qa_scan.gd`), in `run_tests.sh` über den generischen Haken.
5. **Echtzeit-Klangprüfungen unter Last** (`test_engine3_checks` „thread“, `test_music_checks` „race“) fallen auf Prüfling
   **und** Basis abwechselnd; A-11 nennt eine nur unter Last fallende Prüfung „kaputt“ – sie sollten gegen eine im selben
   Lauf gemessene Referenz urteilen (Eigentümer Audio).
