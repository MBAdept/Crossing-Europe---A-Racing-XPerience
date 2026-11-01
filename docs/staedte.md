# Individuelle Städte – Vertrag zwischen Daten, Laufzeit und Sprite-Pipeline

Anlass (Playtest): Alle Städte sehen gleich aus – die letzten 20 km jeder Etappe („City Limits“) nutzen eine einzige
Landschaft `city` (fünf Gebäudetypen, allgemeine Skyline). Wunsch: Städte individueller, z. B. kleine
Einfamilienhäuser am Stadtrand in Osteuropa, Einfahrt über Brücken in Hamburg und Amsterdam, Renaissance-Gebäude in
Wien, der Eiffelturm in Paris.

Lösung: drei Bausteine, alles datengetrieben und für jede der 45 Städte einstellbar.

1. **Baustil** je Stadt (aus dem Land vorbelegt, je Stadt überschreibbar) mit eigener Landschaft für den
   **Stadtrand** (äußerer Teil der City Limits) und das **Zentrum** (innerer Teil): eigene Gebäude-Sprites, Bodenfarbe,
   Skyline-Farben und -Merkmale.
2. **Wahrzeichen**: große Sprites an festen Stellen vor dem Ziel (Vorbeifahrt) und als ferne Silhouette im
   Hintergrund, sobald die City Limits beginnen.
3. **Brücken**: Abschnitte, auf denen die Straße über Wasser führt – Wasser statt Wiese neben der Fahrbahn,
   Brückengeländer und je nach Typ ein Tragwerk (Bögen über der Fahrbahn, Pylone mit Seilen, Laternen).

## 1. Daten: `data/cities.json` (neu)

```json
{
  "_doc": "…",
  "center_km": 8.0,
  "country_style": {"DE": "german", "NL": "dutch", "BE": "belgian", "FR": "french", "ES": "spanish",
                    "IT": "italian", "AT": "austrian", "CH": "swiss", "CZ": "central", "HU": "central",
                    "SI": "central", "HR": "balkan", "RS": "balkan", "BG": "balkan", "PL": "eastern",
                    "LT": "baltic", "LV": "baltic"},
  "styles": {
    "eastern": {"name": "Osteuropa", "outskirts": "city_eastern_outskirts", "center": "city_eastern_center"},
    "…": {}
  },
  "cities": {
    "paris":     {"style": "paris",
                  "landmarks": [{"set": "landmarks/eiffel_tower", "km_to_finish": 7.0, "side": 1, "x_m": 230.0}],
                  "skyline": ["landmarks/eiffel_tower"],
                  "bridges": [{"km_to_finish": 3.0, "length_m": 220, "type": "stone_arch"}]},
    "hamburg":   {"style": "hanse",
                  "landmarks": [{"set": "landmarks/elbphilharmonie", "km_to_finish": 4.5, "side": -1, "x_m": 160.0},
                                {"set": "landmarks/michel", "km_to_finish": 2.5, "side": 1, "x_m": 120.0}],
                  "skyline": ["landmarks/michel", "landmarks/elbphilharmonie"],
                  "bridges": [{"km_to_finish": 13.0, "length_m": 700, "type": "cable_stayed"},
                              {"km_to_finish": 9.0, "length_m": 450, "type": "truss_arch"}]},
    "amsterdam": {"style": "dutch",
                  "bridges": [{"km_to_finish": 6.0, "length_m": 45, "type": "canal"}, "… mehrere Grachtenbrücken"]},
    "wien":      {"style": "vienna",
                  "landmarks": [{"set": "landmarks/riesenrad", "…": 0}, {"set": "landmarks/stephansdom", "…": 0}]}
  }
}
```

| Feld | Bedeutung |
|---|---|
| `style` | Baustil → `styles[style].outskirts` (Landschaft für `km_to_finish > center_km`) und `.center` (≤ `center_km`). Fehlt die Stadt: Stil aus `country_style` des Landes; fehlt auch der: `german`. |
| `landmarks[]` | Wahrzeichen als Requisite an `km_to_finish` vor dem Ziel, Seite `side` (1 rechts, −1 links), Abstand `x_m` vom Fahrbahnrand, optional `scale`. Wird wie andere Ereignis-Requisiten gesetzt (Track-Ereignisse), die Umgebung wird dort freigehalten. |
| `skyline[]` | Wahrzeichen, die als ferne Silhouette im Hintergrund stehen (Backdrop, dunstig getönt, mit dem Kurvenverlauf drehend), ab Beginn der City Limits; dasselbe Sprite wie die Requisite. |
| `bridges[]` | Brücke ab `km_to_finish`, Länge `length_m`, Typ: `truss_arch` (Stahlbögen über der Fahrbahn, z. B. Elbbrücken), `cable_stayed` (Pylone mit Seilfächern, z. B. Köhlbrandbrücke), `stone_arch` (Steinbrücke mit Balustrade und Laternen), `canal` (kurze Grachtenbrücke mit Geländer, Häuser am Wasser), `causeway` (langer niedriger Damm über eine Lagune, Venedig), `river` (einfache Flussbrücke mit Geländer). |

Landschaften `city_<stil>_outskirts` / `city_<stil>_center` stehen in `data/scenery.json` im bekannten Format
(`grass`, `background` mit `style: "city"`, Farben, `features`, `props` mit Regeln und `fallback`). Neue Gebäude, die
es noch nicht gibt, bekommen per `fallback` ein vorhandenes Sprite, damit nichts fehlt.

## 2. Baustile und Gebäude (Sprite-Pipeline)

Neue Requisiten wie die vorhandenen Gebäude (`tools/blender/cesprites/props*.py`, Manifest-Format wie
`props/building_oldtown`: Winkel `c`, Ebenen `base` + `lights` (Fenster nachts), Anker am Boden, `extent_m`,
Tags `prop`, `building`, `city`, `mirror_left`). Namen `props/city_<stil>_<name>`:

| Stil | Städte (Vorschlag) | Gebäude (Stadtrand / Zentrum) |
|---|---|---|
| `hanse` | Hamburg, Bremen, Kiel, Rostock | Backstein-Giebelhäuser, Kontorhaus, Hafenkran / Speicher, Backsteinblock |
| `german` | Hannover, Dortmund, Kassel, Magdeburg, Leipzig, Frankfurt, Berlin | Einfamilienhäuser mit Satteldach / Mietshäuser, Gründerzeit, Bürotürme (Frankfurt) |
| `german_old` | Nürnberg, Würzburg, Erfurt, Dresden, München | Fachwerkhäuser, barocke Bürgerhäuser |
| `dutch` | Amsterdam | Grachtenhäuser (Treppen-, Glocken-, Halsgiebel), Hausboote, Windmühle am Stadtrand |
| `belgian` | Lüttich | Backstein-Reihenhäuser, Stein |
| `paris` | Paris | Haussmann-Blöcke (heller Stein, Mansarddächer, Balkone) |
| `french` | Lyon, Bordeaux, Tours, Toulouse, Montpellier, Pau | Steinhäuser mit Fensterläden, Ziegeldächer im Süden |
| `spanish` / `italian` | Madrid, Barcelona, Burgos, Saragossa, San Sebastián / Mailand, Venedig | verputzte Wohnblöcke mit Balkonen, Terrakotta-Dächer, Palazzi |
| `vienna` / `austrian` | Wien | Renaissance-/Gründerzeitpalais mit reicher Fassade, Kuppelkirche |
| `swiss` | Bern | Chalets am Stadtrand, Laubenhäuser |
| `central` | Prag, Budapest, Ljubljana | barocke/Jugendstil-Bürgerhäuser, Türme |
| `eastern` | Warschau, Posen, Białystok | **kleine Einfamilienhäuser mit Zaun und Garten am Stadtrand**, Plattenbauten im Zentrum |
| `balkan` | Belgrad, Sofia, Slavonski Brod | Einfamilienhäuser (oft unverputzt), Plattenbauten, orthodoxe Kirche |
| `baltic` | Riga, Kaunas | Holzhäuser am Stadtrand, Jugendstil im Zentrum |

## 3. Wahrzeichen

Große Requisiten `landmarks/<name>` (Winkel `c`, Ebenen `base` + `lights` für Anstrahlung nachts, Anker am Boden,
echte Maße, Tag `landmark`). Pflicht: `eiffel_tower` (Paris), `elbphilharmonie` und `michel` (Hamburg), `riesenrad`
und `stephansdom` (Wien), `fernsehturm_berlin`, `frauenkirche_dresden`, `frauenkirche_muenchen`, `sagrada_familia`
(Barcelona), `duomo_milano`, `campanile_venezia`, `parlament_budapest`, `veitsdom_prag`, `kulturpalast_warschau`,
`nevsky_kathedrale` (Sofia). Weitere nach Zeit (z. B. Frankfurter Hochhäuser, Kaiserburg Nürnberg,
Freiheitsdenkmal Riga, Kathedrale Burgos, Basílica del Pilar Saragossa).

## 4. Brückenbauteile

`props/bridge_truss_arch` (Stahlbogen-Portal über der ganzen Fahrbahn, mittig verankert, Tag `overhead`, wird alle
~40 m wiederholt), `props/bridge_pylon` (Pylon mit Seilfächer zur Fahrbahn hin, `mirror_left`), `props/bridge_lamp`
(Laterne für Steinbrücken, `mirror_left`), `props/houseboat` (Grachten). Geländer und Wasser zeichnet der Renderer
selbst.

## 5. Laufzeit

- `StagePlan`/`Track`: Stil der Zielstadt, Landschaft je Abschnitt (Stadtrand/Zentrum), Wahrzeichen als
  Ereignis-Requisiten, Brücken als Zonen (Segmente mit `bridge`, `water`), Hintergrund-Silhouetten.
- Renderer: Wasser neben der Fahrbahn auf Brücken (mit Ufer an den Enden, nachts dunkel mit Lichtreflexen),
  Brückengeländer, Tragwerk-Requisiten (über der Fahrbahn gezeichnete Requisiten in der normalen
  Malerreihenfolge), Wahrzeichen weit sichtbar (frühes Einblenden statt Aufpoppen am Rand der Sichtweite).
- Alles fällt sauber zurück: fehlt ein Sprite, greift `fallback`; fehlt `data/cities.json`, bleibt `city`.
