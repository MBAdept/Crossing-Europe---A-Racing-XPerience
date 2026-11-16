## 5. Modern-Änderungsmelder (`6e48405`)

`KEEP=<scratch> tools/golden.sh modern-make` (472 s, gemessen), dann die sechs Bilder angesehen, dann die Liste
committet. Im Merge-Commit stand vorläufig M2INTs Liste (dort im Commit-Text gesagt).

| Bild | M2INT `49f221e` | M2ZS1 | angesehen |
|---|---|---|---|
| `modern_start_mittel_00` (km 0, Countdown 2,2 s) | `e7714a12…` | **`1fa6d0b4…`** | gewollt: Spielerauto im Countdown an Arcades Stelle (FIX-ZS1), Starttor mit drei Lampen, Schild „Tankstelle 15 km“, Bäume von AS3R – bei M2INT fehlte das Auto |
| `modern_s4_mittel_00` (km 80,6, Ende der Köhlbrandbrücke) | `649a97ff…` | **`711d3901…`** | gewollt: Fernboden unter dem Wasser im Fenster (FIX-WASSER); gegen das S4-Bild von ZS1 1,0 % der Bildpunkte anders (Verkehr, Bäume von M2), sonst dasselbe Bild |
| `modern_s2_mittel_00`, `modern_s3_hoch_00`, `modern_s5_niedrig_00`, `modern_s1_nacht_00` | – | MD5-gleich | auch S1 bei Nacht gleich: `night_albedo` lässt mit der Vorgabe 1 jedes andere Material bitgleich |
