# AS5a2 – Stadthäuser Teil 1, Charge 2: dutch, belgian, french, paris, swiss

Zweig `worktree-wf_db8ba6cd-508-4` (gesichert als `origin/wip/v080-as5a2`), Basis 7153381 (AS5aR1), Endstand
**HEADCOMMIT**. Messgrundlage: **gemessen** = auf dieser VM (Mesa llvmpipe unter Xvfb, Godot 4.7.2, Spiel-Shader,
Renn-Licht); **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht messbar (echte Grafikkarte, Steam Deck,
Wirkung auf einen Menschen) oder abgeleitet.

## 1. Ergebnis in Kürze

ZUSAMMENFASSUNG

## 2. Was gebaut wurde

Zwölf Sets, Reihenfolge nach Häufigkeit im ganzen Netz (Zählung `census_all.gd` von AS5a1/AS4R: alle Requisiten aller
Etappen, mit Wiederholungen):

| Set | Platzierungen | Städte (Ankünfte) | Zone |
|---|---|---|---|
| `city_french_sud` | 588 | Toulouse, Montpellier, Lyon, Bordeaux, Pau, Bern-Abfahrt … (Mischstil french_south) | Vorort |
| `city_belgian_terrace` | 315 | Brüssel, Lüttich, Calais, Amsterdam-Abfahrt | Innenstadt |
| `city_french_maison` | 209 | Paris, Tours, Pau, Lüttich-Abfahrt | Vorort |
| `city_french_immeuble` | 202 | Toulouse, Lyon, Montpellier, Bordeaux, Paris … | Innenstadt |
| `city_dutch_terrace` | 130 (50 getönt `#ead6cc`) | Amsterdam, Dortmund (ruhr) | Vorort |
| `city_belgian_stone` | 96 | Brüssel, Lüttich, Calais | Innenstadt |
| `city_paris_haussmann` | 55 | Paris | Innenstadt |
| `city_swiss_chalet` | 54 | Bern | Vorort |
| `city_dutch_canal` | 51 | Amsterdam | Innenstadt |
| `city_swiss_laube` | 46 | Bern | Innenstadt |
| `city_dutch_canal_b` | 22 | Amsterdam | Innenstadt |
| `city_paris_corner` | 8 | Paris | Innenstadt |

(Die Etiketten der Zählung nennen die Etappe und die Startstadt; die Häuser stehen an der Ankunft der Gegenstadt.)
