# RINT-M2 – Zweite Montage des Schubs M2

Zweig `wip/v080-rint-m2` (nur dorthin gepusht, nach jedem Commit), Basis `515dd51`. Alle Zahlen gemessen auf dieser
Maschine (Xvfb, llvmpipe, Godot 4.7.2 Compatibility), sonst steht **(gefolgert)** dabei. Jeder Spiellauf mit
absolutem `XDG_DATA_HOME` im Arbeitsordner und `--graphics` ausdrücklich; schwere Läufe einzeln über eine
Warteschlange, `nice -n 10`, `LP_NUM_THREADS=2`.

## 1. Kurzfassung

- Vier Merges `--no-ff` in der verlangten Reihenfolge, Vertrag §11.3 wörtlich angehängt.
- Leitungsnotizen 3–11 umgesetzt und gemessen; Notiz 10 (Lack) gemessen, nicht mit einer Konstante lösbar → gelistet;
  Notiz 12 befolgt (nichts gegen das Flackern).
- **Selbst gefunden und behoben:** die erste Fassung der Tönung (Notiz 5, `b04d28a`) färbte Fensterrahmen,
  Garagentore, Bäume und Windräder leuchtend grün. Ursache ist ein Verhalten von Godots Compatibility-Renderer bei
  `INSTANCE_CUSTOM` (mit Sonden eingegrenzt, §3 Notiz 5); behoben in `a3120e4`, Bilder vorher/nachher.
- Notiz 8 brauchte nach dem ersten Einfrieren (`1cd689d`) noch drei Code-Schritte am Tankstellendach (`c72d484`,
  `b673df5`, `02051f7`): `collect()` der Tankstelle höchstens 2,40 ms, Mittel 0,14 ms auf „Deck“ (vorher 3,41 / 0,20;
  Ziel 2 ms im Höchstwert um 0,4 ms verfehlt, §3 Notiz 8); Entscheide netzweit unverändert (1909 Dächer, 0 verschieden).
  Dazu eine angepasste Render-Prüfung (`ab2a400`) und Doku (`ae1fd76`). Endstand `@@HEAD@@`.
- A/B: an den Bezugsstellen 2 besser, 8 gleich, 4 schlechter (Kurveninnenseiten in Bergetappen, A-17 → R7); an den
  weiteren Stellen @@ABX@@ (§5, §7).

## 2. Zusammenbau

| Schritt | Commit | Konflikte / Auflösung |
|---|---|---|
| R4 `origin/wip/v080-fix-r4` (`b156763`) | `04de79f` | nur `tests/golden/modern_slice.{md5,env}` – R4s Seite, Liste wird am Ende neu erzeugt |
| R5 `origin/wip/v080-fix-r5` (`80b8141`) | `9fec3a7` | `modern_slice.md5`; `docs/renderer-modern.md`: R4 und R5 hatten beide §15 – R4 bleibt §15, R5 wird §16 |
| R6 `origin/wip/v080-fix-r6` (`2b7dcc0`) | `5c451f2` | nur `modern_slice.*` |
| AS5a `origin/wip/v080-as5ar1` (`7153381`) | `cee4590` | nur `modern_slice.*`; `manifest.json` seit der Basis nur von AS5a geändert |
| Vertrag §11.3 (Leitung) wörtlich | `8999769` | „Vertrag §11.3 (Leitung): Sichtkorridor, Bauten, Instanz-Uniforms, Nachtlicht, Plan, Stadtgebäude“ |

Auf dem Merge-Stand `8999769` liefen die Render-Prüfungen `night_nass`, `night`, `weather`, `tunnel_bridge`,
`structures`, `structures_licht`, `vehicle_lights` grün (Ausgangspunkt der Nacharbeit).

Commits der Nacharbeit: `2322092` (Notiz 3), `1c61036`/`71ed4b7` (4), `b04d28a`/`a3120e4` (5), `967ad21` (6),
`6347e41`/`618561f` (8), `747fa30` (9), `4fc3d35` (7), `eb417a7` (11 a–d), `58eba9e`/`5294d00` (11 e: N1/N2),
`aa44247`/`1cd689d` (Doku), `c72d484`/`b673df5`/`02051f7` (8, Tankstellendach), `ab2a400` (Render-Prüfung
`props_spiegel`), `ae1fd76` (Doku §17.10), dazu die Goldens `6b17293` (§4).
