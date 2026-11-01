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

| Stil | Städte | Gebäude (Stadtrand / Zentrum) |
|---|---|---|
| `hanse` | Hamburg, Bremen, Kiel, Rostock | Einfamilienhäuser (Klinkerton), wenige Giebelhäuser und Mietshäuser, Hafenkran / Kaufmannshäuser mit Giebeln, Speicher, Kontorhaus |
| `german` | Hannover, Kassel, Frankfurt, Berlin | Einfamilienhäuser mit Satteldach / Mietshäuser, Gründerzeit, Bürotürme (Frankfurt) |
| `german_east` | Magdeburg, Leipzig | wie `german`, am Stadtrand Plattenbauten hinter den Häusern |
| `ruhr` | Dortmund | wie `german`, am Stadtrand Backstein-Reihenhäuser (Zechensiedlung), Fabriken, Strommasten |
| `german_old` | Nürnberg, Würzburg, Erfurt | Fachwerkhäuser, barocke Bürgerhäuser |
| `bavarian` | München | Einfamilien- und Mietshäuser mit Fichten / Gründerzeit-Zinshäuser, Barockhäuser (kein Fachwerk) |
| `dutch` | Amsterdam | Grachtenhäuser (Treppen-, Glocken-, Halsgiebel), Hausboote, Windmühlen am Stadtrand |
| `belgian` | Lüttich | Backstein-Reihenhäuser, Stein |
| `paris` | Paris | Pavillons, Immeubles, HLM-Riegel / Haussmann-Blöcke (heller Stein, Mansarddächer, Balkone) |
| `french` | Tours, Pau | Loire-Häuser (Tuffstein, Schiefer) / Stadthäuser mit Fensterläden |
| `french_south` | Lyon, Bordeaux, Toulouse, Montpellier | Häuser mit Mönch-Nonne-Ziegeln, Zypressen, Ölbäume / ockerfarbene Stadthäuser |
| `spanish` / `spanish_north` / `italian` | Madrid, Barcelona, Saragossa / San Sebastián, Burgos (grün, Eichen und Pappeln statt Palmen) / Mailand, Venedig | weiße Häuser, Wohnblöcke mit Balkonen, Terrakotta-Dächer; Italien: Villette und Casette am Stadtrand, Palazzi |
| `vienna` / `austrian` | Wien | Zinshäuser am Stadtrand / Renaissance-/Gründerzeitpalais, Zinshäuser, Kuppelkirche |
| `swiss` | Bern | Chalets am Stadtrand, Laubenhäuser |
| `central` | Prag, Budapest, Ljubljana, Dresden | Würfelhäuser (Kostka, Kádár-kocka), Paneláky im Hintergrund / barocke und Jugendstil-Bürgerhäuser, Türme |
| `eastern` | Warschau, Posen, Białystok | **kleine Einfamilienhäuser mit Zaun und Garten am Stadtrand**, Plattenbauten im Zentrum |
| `balkan` | Belgrad, Sofia, Slavonski Brod | Einfamilienhäuser (oft unverputzt), Plattenbauten (im Zentrum hinter der Straßenfront), orthodoxe Kirche |
| `baltic` | Riga, Kaunas | Holzhäuser und vereinzelte Plattenbauten am Stadtrand, Jugendstil im Zentrum |

Die 16 Stile des Vertrags sind Pflicht; die regionalen Stile `german_east`, `ruhr`, `bavarian`, `french_south`
und `spanish_north` kamen nach der Sichtprüfung dazu (Städte desselben Landesstils sahen bis auf ihr Wahrzeichen
gleich aus; Dresden und München wirkten mit Fachwerk fränkisch, Toulouse und Montpellier mit Schieferdächern wie
Tours, San Sebastián und Burgos mit Palmen andalusisch). Ein Stil darf eine Landschaft mit einem anderen teilen
(`german_east` und `ruhr` nutzen das Zentrum von `german`).

## 3. Wahrzeichen

Große Requisiten `landmarks/<name>` (Winkel `c`, Ebenen `base` + `lights` für Anstrahlung nachts, Anker am Boden,
echte Maße, Tag `landmark`). Pflicht: `eiffel_tower` (Paris), `elbphilharmonie` und `michel` (Hamburg), `riesenrad`
und `stephansdom` (Wien), `fernsehturm_berlin`, `frauenkirche_dresden`, `frauenkirche_muenchen`, `sagrada_familia`
(Barcelona), `duomo_milano`, `campanile_venezia`, `parlament_budapest`, `veitsdom_prag`, `kulturpalast_warschau`,
`nevsky_kathedrale` (Sofia). Weitere nach Zeit (z. B. Frankfurter Hochhäuser, Kaiserburg Nürnberg,
Freiheitsdenkmal Riga, Kathedrale Burgos, Basílica del Pilar Saragossa).

Geliefert (Details, Maße und Zellgrößen: [docs/sprites.md „Wahrzeichen“](sprites.md)): alle 15 Pflicht-Sets und
zusätzlich `frankfurt_skyline` (Frankfurt), `kaiserburg_nuernberg` (Nürnberg), `st_petri_riga` und
`freiheitsdenkmal_riga` (Riga), `kathedrale_burgos` (Burgos), `basilica_pilar` (Saragossa). Anker = Mitte
der nahen Seite am Boden, `extent_m` wie bei allen Requisiten, kein `mirror_left` (nie spiegeln).

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

## 6. Umsetzung – Daten (`data/cities.json`, `CityData`)

Alle 45 Städte stehen in `data/cities.json` (Format wie §1, Beschreibung auch im `_doc` der Datei). Aufgelöst wird
für die **Zielstadt** einer Etappe (beide Fahrtrichtungen) von `CityData.apply()` (`scripts/data/city_data.gd`, rein,
ohne Autoloads), aufgerufen aus `StagePlan.build(…, city_db)`; `GameData` lädt die Datei (`city_db`) und reicht sie
durch. Ohne `cities.json` (oder ohne Stil-Landschaft in `scenery.json`) bleibt alles bei der Landschaft `city`.

**Einheiten und Bedeutung (verbindlich für alle Daten):**

| Feld | Einheit / Regel |
|---|---|
| `km_to_finish` | Kilometerzähler-km vor dem Ziel (Anfang einer Brücke, Standort eines Wahrzeichens) |
| `length_m` (Brücke) | **sichtbare Meter** wie alle `*_m`-Werte (ARCHITECTURE.md §2: 1 km = 83,3 m) – eine Brücke von 200 m ist 2,4 km lang und bei 150 km/h rund 5 s zu sehen; eine Gracht von 40 m ist eine kurze Brücke |
| `height_m` (Brücke) | Wasser unter der Fahrbahn in Metern; Standard je Typ: Gracht 1,8, Damm 1,4, Fluss 3,0, Steinbrücke 3,2, Fachwerkbogen 3,6, Schrägseil 5,0. Hochbrücken nur bei langen Brücken (Kiel 16 m auf 200 m Länge): auf kurzen hohen Brücken verbirgt das Deck das Wasser, beidseits liegt nur die Böschung in Deckhöhe (Bern: 15 → 8 m) |
| `x_m` (Wahrzeichen) | Abstand der **Vorderkante** vom Fahrbahnrand (die Laufzeit rückt den Anker um die Ausdehnung zur Straße weg, `align: edge`) |
| `center_km` | Länge des Zentrums vor dem Ziel (Standard 8 km); davor der Stadtrand. Je Stadt überschreibbar (Paris, Berlin, Madrid 10, München, Wien 9, Venedig 6,6 = ab dem Damm) |

**Zusätzliche Felder** (Erweiterungen des Vertrags): Brücke `name` (HUD-Meldung beim Auffahren, wie Tunnelnamen),
`water` (Wasserfarbe), `color` (Geländer/Tragwerk), `bank` (Farbe der Böschung – macht aus der Kaimauer eine flache
grüne Böschung), `ships` (Schiffe auf dem Fluss), `boats` (Hausboote, Standard 2 bei `canal`), `pylon_m` (Höhe der
Pylone); Wahrzeichen `name`, `tint`, `clear_m` [vorher, nachher] (sichtbare Meter ohne Landschaft auf seiner Seite,
Standard [100, 40]), `plaza` (`park` = einige Bäume auf dem freien Platz, `square`, `none`); Skyline-Einträge als
Set-ID oder `{set, scale, azimuth_deg, name, tint}`; `background` (überschreibt Schlüssel des Hintergrunds der
Stadt-Landschaft, z. B. `features`, `roofs`, `height`, `behind`). Die Bergkette `behind` ist ein Stilname oder
`{style, height, color, haze}`: `color` = Farbe der Kette (Standard: die ferne Hintergrundfarbe, fast Himmelsfarbe),
`haze` = Grunddunst zur Nebelfarbe (Standard 0,55 = blass; 0,3 für eine Kette, die man lesen soll – Alpen hinter
Bern, Ljubljana, München und Mailand, Witoscha, Wienerwald, Pyrenäen). Wahrzeichen dürfen auch vorhandene Requisiten
sein (`props/church` mit `scale` und `tint` als Kathedrale) – so hat jede Stadt ein Wahrzeichen, ohne dass für alle ein
eigenes Sprite entstehen muss.

**Katalog `landmark_sets`**: je Wahrzeichen-Sprite `name`, echte `height_m` und `width_m`, `required` (Pflicht laut
§3), `proc` (prozeduraler Ersatz, den der Renderer zeichnet, solange das Sprite fehlt) und `fallback` /
`fallback_scale` / `fallback_tint` (Ersatz-Sprite, falls es keinen `proc` gibt), für `domed_church` die Farben `dome`
und `wall` und `cross` (`false`: Laterne ohne Kreuz – Rathaus, Denkmal). Siehe §8.

**Platzierung der Wahrzeichen** (Regel aus der Sichtprüfung): Ein Wahrzeichen der Höhe h ist unterhalb der
HUD-Tafeln (Uhr oben links, Zeit und Fortschritt in der Mitte bis y ≈ 150 px) erst aus etwa 4 · h sichtbaren Metern
ganz zu sehen; in der Straßenschlucht des Zentrums zeigt es sich nur über seinem freien Platz. Deshalb `clear_m[0]`
≈ 2,5–3 · h (250–320 m für 90–130 m hohe Bauten) und `x_m` so, dass es dort 10–25° neben der Fahrtrichtung steht
(nicht 40–60°: dann ist es beim Herankommen schon aus dem Bild). Gute Plätze liegen 0,4–1,0 km hinter einem
Brückenende, wo das Wasser den Blick öffnet (Bremer Dom, Magdeburger Dom, Martinskirche, Neues Rathaus,
Eiffelturm von der Pont Alexandre III). Prozedurale Wahrzeichen stehen mit ihrer Mitte bei `x_m` + halbe Breite
(`width_m`), `x_m` also klein halten. Sehr hohe Bauten (Fernsehturm 368 m, Frankfurter Hochhäuser) sind ganz nur
von den City Limits aus zu sehen und aus der Nähe oben angeschnitten – das lässt sich nicht vermeiden.

**Prüfungen** (`CityData.apply` → `StagePlan.warnings`, Datentests prüfen alle Ankünfte ohne Warnung): Brücken
außerhalb der Etappe, in oder näher als 0,3 km an einem Tunnel oder einer anderen Brücke werden verworfen;
Wahrzeichen außerhalb der City Limits, im Tunnel oder auf einer Brücke (im Wasser) ebenso. `CityData.validate()`
prüft Stile, Landschaften, Katalog (Sprite, `proc` oder Ersatz vorhanden) und Brückentypen; `CityData.missing_props()`
meldet Landschafts-Regeln ohne vorhandenes Sprite und ohne Ersatz.

**Abweichungen vom Beispiel in §1** (die Feldbedeutungen gelten unverändert): weil `length_m` sichtbare Meter sind,
wären 700 m Köhlbrandbrücke 8,4 km lang und lägen über den Elbbrücken. Außerdem liegt auf der Ankunft aus Hannover
der Elbtunnel 7,3–4,0 km vor dem Ziel. Hamburg ist deshalb: Köhlbrandbrücke 17,0 km / 260 m, Elbbrücken 11,0 km /
200 m, Elbphilharmonie 3,4 km (links, 55 m; ihr großer Auftritt ist der Blick über die Elbe von den Elbbrücken),
Michel 1,8 km (rechts, 70 m, freier Platz 320 m: der grüne Turmhelm steht ab km 89,2 ganz im Bild). Paris: Pont
Alexandre III 8,0 km (0,7 km hinter dem Tunnel du Landy 10,0–8,7 km), Eiffelturm 0,3 km (rechts, 60 m): von der Brücke
steht er ganz über der Seine, danach über den Haussmann-Dächern, am Ziel daneben; von den City Limits aus ist er
weiterhin ganz zu sehen.

### Städte im Überblick

| Stadt | Stil | Wahrzeichen | Brücken |
|---|---|---|---|
| Kiel | `hanse` | Rathausturm | Holtenauer Hochbrücke (river, 16 m hoch, Schiff im Kanal) |
| Hamburg | `hanse` | Elbphilharmonie, Michel | Köhlbrandbrücke (cable_stayed), Elbbrücken (truss_arch), Schiffe |
| Bremen | `hanse` | Bremer Dom | Wilhelm-Kaisen-Brücke (river) |
| Rostock | `hanse` | Marienkirche (Sprite der Rigaer Petrikirche als Platzhalter: Backsteingotik, Kupferhelm) | – |
| Hannover | `german` | Neues Rathaus (prozedural: Kuppelbau mit grüner Kuppel, links über die Leine) | Leinebrücke (river) |
| Dortmund | `ruhr` | Florianturm | – (Hintergrund mit Schornsteinen und Hochhäusern) |
| Kassel | `german` | Martinskirche, Herkules (Silhouette, prozedural `octagon`) | Fuldabrücke (river) |
| Magdeburg | `german_east` | Magdeburger Dom | Strombrücke (river) |
| Leipzig | `german_east` | Völkerschlachtdenkmal (prozedural: graue Kuppel), City-Hochhaus | – |
| Frankfurt | `german` | Frankfurter Hochhäuser | Friedensbrücke (river) |
| Berlin | `german` | Fernsehturm | Oberbaumbrücke (stone_arch, Backstein) |
| Nürnberg | `german_old` | Kaiserburg | Pegnitzbrücke (river) |
| Würzburg | `german_old` | Festung Marienberg (Sprite der Kaiserburg als Platzhalter, links über dem Main) | Ludwigsbrücke (stone_arch) |
| Erfurt | `german_old` | Erfurter Dom | – |
| Dresden | `central` | Frauenkirche | Augustusbrücke (stone_arch) |
| München | `bavarian` | Frauenkirche | Maximiliansbrücke (stone_arch); Alpen am Horizont |
| Amsterdam | `dutch` | Westerkerk | fünf Grachten: Singelgracht, Prinsengracht, Keizersgracht, Herengracht, Singel (canal, Hausboote) |
| Lüttich | `belgian` | Kathedrale Saint-Paul | Pont de Fragnée (stone_arch) |
| Paris | `paris` | Eiffelturm (0,3 km vor dem Ziel), Sacré-Cœur (Silhouette, prozedural) | Pont Alexandre III (stone_arch, 8,0 km) |
| Tours | `french` | Kathedrale Saint-Gatien | Pont Wilson (stone_arch) |
| Bordeaux | `french_south` | Kathedrale Saint-André | Pont de Pierre (stone_arch) |
| Pau | `french` | Château de Pau (Sprite der Kaiserburg als Platzhalter) | Pont du XIV-Juillet (river); Pyrenäen am Horizont |
| Toulouse | `french_south` | Basilique Saint-Sernin | Pont Neuf (stone_arch, Backstein) |
| Montpellier | `french_south` | Kathedrale Saint-Pierre | Pont Juvénal (river) |
| Lyon | `french_south` | Notre-Dame de Fourvière (weiße Kuppelkirche `city_vienna_kirche`) | Pont Lafayette (river), Pont Bonaparte (stone_arch) |
| San Sebastián | `spanish_north` | Catedral del Buen Pastor | Puente María Cristina (stone_arch) |
| Burgos | `spanish_north` | Kathedrale | Puente de Santa María (stone_arch) |
| Madrid | `spanish` | Cuatro Torres | Puente de Segovia (stone_arch); Sierra am Horizont |
| Saragossa | `spanish` | Basílica del Pilar | Puente de Piedra (stone_arch) |
| Barcelona | `spanish` | Sagrada Família, Torre Glòries (Silhouette) | – |
| Bern | `swiss` | Berner Münster | Kirchenfeldbrücke (river, 8 m hoch); Alpen am Horizont |
| Mailand | `italian` | Mailänder Dom | – (Hochhäuser, Alpen am Horizont) |
| Venedig | `italian` | Campanile di San Marco | Ponte della Libertà (causeway, 380 m über die Lagune) |
| Ljubljana | `central` | Burg (Sprite der Kaiserburg als Platzhalter, auch als Silhouette) | Drachenbrücke (stone_arch); Alpen am Horizont |
| Slavonski Brod | `balkan` | Franziskanerkloster | Savebrücke (river) |
| Belgrad | `balkan` | Kirche des Heiligen Sava | Ada-Brücke (cable_stayed) |
| Sofia | `balkan` | Alexander-Newski-Kathedrale | – (Witoscha am Horizont) |
| Budapest | `central` | Parlament | Elisabethbrücke (cable_stayed) |
| Wien | `vienna` | Riesenrad, Stephansdom | Reichsbrücke (river); Wienerwald |
| Prag | `central` | Veitsdom | Most Legií (stone_arch) |
| Posen | `eastern` | Posener Dom (Sprite der Münchner Frauenkirche: Backsteingotik, Doppeltürme) | Warthebrücke (river) |
| Warschau | `eastern` | Kulturpalast | Poniatowski-Brücke (stone_arch) |
| Białystok | `eastern` | Pfarrkirche (Fara) | – |
| Kaunas | `baltic` | Christi-Auferstehungs-Kirche | Aleksotas-Brücke (river) |
| Riga | `baltic` | Freiheitsdenkmal, Petrikirche und Fernsehturm (Silhouetten) | Vanšu-Brücke (cable_stayed) |

Der Stil `austrian` wird von keiner Stadt genutzt (Wien hat `vienna`), ist aber als Landesvorgabe für AT vollständig.

## 7. Umsetzung – Laufzeit

**`StagePlan`** (Felder siehe `stage_plan.gd`): `city_style`, `city_scenery_outskirts`, `city_scenery_center`,
`city_center_km`, `city_background`, `landmarks`, `bridges`, `skyline`; Abfragen `scenery_for(km, scenery)` (Abschnitt
vor den City Limits, danach Stadtrand/Zentrum, sonst `city`), `in_city_center(km)`, `bridge_at(km)`, `on_bridge(km)`.
Die Rennsitzung nimmt `scenery_for` für den Hintergrund und meldet Brückennamen im HUD.

**`Track`**:

- Landschaft je Segment aus `plan.scenery_for` (Stadtrand → Zentrum ab `center_km`; der Hintergrund wechselt dort weich).
- **Wahrzeichen** = Ereignis-Requisite (`landmark: true`, `align: edge`, Höhe/Breite/`proc`/Ersatz aus dem Katalog) am
  km; auf seiner Seite keine Landschafts-Requisiten von `clear_m[0]` davor bis `clear_m[1]` dahinter (neue Freihalte-Bits
  für *alle* Abstände, `_mark_clear_all`), bei `plaza: park` 5–8 Parkbäume davor und zwei daneben/dahinter –
  nie auf einer Brücke oder näher als `PARK_TREE_BRIDGE_GAP_M` (8 m) an ihr (`Track.near_bridge`; liegt ein
  Wahrzeichen kurz hinter einer Brücke, standen die Bäume sonst im Fluss), links gespiegelt wie die
  Landschaftsbäume. `Track.landmarks` hält dieselben Wahrzeichen mit `z` und `x` für die Fernsicht.
- **Brücken** = Zonen (`Track.bridges`, auch in `zones`, Grenzen auf dem Segmentraster): Segmente darauf tragen
  `water`, `bridge` (Typ), `bridge_i`, `water_depth` und `water_level` (Boden unter dem Deck: an den Widerlagern 0, über
  `slope` auf `-depth` – Kaimauer = ein Segment, Böschung bei `bank`/Hochbrücken = 1,5 × Tiefe), das erste Segment
  dahinter `bank`. Auf dem Wasser keine Landschaft (24 m davor auch nicht – Gebäude reichen nach hinten), keine
  Zebrastreifen. Tragwerk als Ereignis-Requisiten: `truss_arch` Portal `props/bridge_truss_arch` alle 40 m
  (`side 0`, `overhead`, `fit_w` = Breite von Fahrbahn + Gehwegen + 0,8 m, prozedural `truss_portal`),
  `cable_stayed` Pylone `props/bridge_pylon` beidseitig bei 27/73 % (kurze Brücken: Mitte) mit `prefer_proc`: es
  zeichnet immer der prozedurale Pylon (Höhe `pylon_m`, Seile als 3D-Linien entlang des Decks) – das Sprite trägt
  einen eingebackenen Seilfächer, ist immer 88,8 m hoch und zerfiel aus der Nähe zu unscharfen, durchscheinenden
  Flächen, nachts zu leuchtenden Scheiben, `stone_arch` Laternen `props/bridge_lamp` beidseitig alle 24 m,
  `causeway` alle 36 m (statt der Straßenlaternen; `proc bridge_lamp`), `canal` Hausboote `props/houseboat` (Ersatz `props/ferry_ship` × 0,13),
  `ships` Schiffe `props/ferry_ship` × 0,32–0,45 auf dem Wasser (`h = -depth`: Requisiten können jetzt unter der
  Straße stehen).

**`RoadRenderer`**:

- **Wasser**: je Scheibe ein Band über die ganze Breite in Höhe `water_level` (Maleralgorithmus: das Deck und nähere
  Scheiben verdecken es richtig, man sieht das Wasser erst, wo der Blick über die Ufer- bzw. Deckkante reicht). Farbe:
  Brücke `water` → Landschaft `water` → Standard je Typ, vom Umgebungslicht beleuchtet und zur Ferne hin mit mehr
  Himmel gemischt (`water_tint`, flacher Blickwinkel), dann Nebel. Nahe Glitzerstreifen an festen Stellen je Segment
  (Sonne: hell, nachts warme Lichter der Stadt). Ufer: das Band steigt am Ende zur Straße – Kaimauer (Stein, Backstein
  bei Grachten) oder grüne Böschung (`bank`); die abgewandte Seite am Brückenanfang entfällt.
- **Geländer** an der äußeren Deckkante (Stadt: Gehwegkante, sonst 0,4 m hinter dem Bankett): Stahlgeländer mit
  Betonsockel (`river`, `cable_stayed`, `truss_arch`), Steinbalustrade mit Docken und Postamenten (`stone_arch`),
  schmiedeeisernes Geländer (`canal`), Betonbrüstung (`causeway`); Farbe aus `color`. `truss_arch` zusätzlich
  Seitenträger mit Ober-/Untergurt, Pfosten und Diagonalen (4,2 m, alle 7,5 m) – dünne Linien, das Wasser bleibt sichtbar.
- **Brückenteile prozedural** (bis die Sprites existieren): Portal (Beine an den Deckkanten, Stahlbogen, Zugband,
  Gitter), Pylon (Beton, Flugfeuer) mit 2 × 7 Seilen als echte 3D-Linien zur Deckkante (an der nahen Ebene
  abgeschnitten), Kandelaber (drei Kugeln auf Steinbrücken). Portale werden auf `fit_w` skaliert (Sprite:
  `fit_w / object.width_m`).
- **`prefer_proc`** an einer Requisite: ihre prozedurale Form (`proc`) schlägt das Sprite (Brückenpylone).
- **Wahrzeichen** fernsichtbar: eigenes Dunstgesetz `landmark_fade` (Reichweite = Sichtweite × 2, höchstens
  `render.landmark_far_m` = 1900 m; ausblenden über die letzten 28 %, Dunst ab dem Nebelbeginn) statt des
  Requisiten-Nebels. Jenseits der projizierten Zeilen zeichnet `_draw_far_landmarks` sie nach dem Hintergrund und vor
  der Szene, die Straße gerade aus der letzten Zeile verlängert – stetiger Übergang, kein Aufpoppen. Nachts bleibt die
  Ebene `lights` (Anstrahlung) bis 1900 m sichtbar. Prozedurale Ersatzformen (`proc`): `lattice_tower` (Eiffelturm,
  nachts golden mit stündlichem Glitzern), `tv_tower`, `ferris_wheel`, `column`, `octagon` (Oktogon mit Pyramide und
  Statue, Herkules), `campanile`, `domed_church` (Farben `dome`/`wall`, `cross`; aus der Nähe mit Fassade aus
  Fensterreihen und Portal statt einer leeren weißen Wand), `parliament`, `palace_tower`,
  `skyscrapers` (aus der Nähe mit Geschossbändern alle 4 m und Pfosten alle 3 m – Glasfassade statt glatter Fläche).
  Ihre Lichter sind weiche Punkte in der Malerreihenfolge (`_soft`), damit Häuser und Hügel davor sie verdecken – die
  additive Leuchtebene würde durchscheinen (auch für Lampen-Spiegelungen auf dem Wasser). Gewöhnliche Requisiten als
  Wahrzeichen (`props/church` als Dom …) haben nachts nur Fenster in der Lichtebene: der Renderer strahlt sie warm an
  (`LANDMARK_FLOOD`); die `landmarks/*`-Sprites tragen ihre Anstrahlung selbst.
- **Skyline-Silhouetten** (`skyline[]`, mit `proc` ohne Ersatz-Sprite wie die Requisiten – sonst stand der Rigaer
  Fernsehturm als 369 m hohes Glasbürohaus am Horizont): in den City Limits im Panorama (`RaceBackdrop.landmarks`,
  nach der fernen Ebene, vor der nahen), dunstig getönt, Größe wie in `render.skyline_distance_m` (1800 m), mit dem Panorama drehend.
  Beim ersten Erscheinen verankert: steht dasselbe Wahrzeichen als Requisite auf der Strecke, in seiner wahren Richtung;
  sonst `azimuth_deg` oder ein fester Fächer. Ist die Requisite in Reichweite (`landmark_fade`), blendet die Silhouette
  aus (kein doppelter Eiffelturm) – bei klarer Sicht übernimmt die Requisite also schon ab den City Limits, bei Nacht,
  Regen und Schnee zuerst die Silhouette.
- **Zäune** (`fence` der Landschaft): Lattenzaun, Hecke, Mauer oder Eisengitter beidseitig hinter dem Gehweg mit
  Lücken für Einfahrten (nur bis 240 m).
- **Hintergrund** je Stil (`suburb` am Stadtrand: ferne Skyline, Bäume, kleine Häuser mit Satteldach; `city` im
  Zentrum mit `roofs`) und je Stadt (`background` aus `cities.json`): neue Merkmale `cranes`, `domes`, `onion`,
  `slabs`, `towers`, Bergkette `behind` (mit `color` und `haze`, §6).
- **Boden** am Übergang Stadtrand → Zentrum: über die letzten `GROUND_BLEND_M` (150 sichtbare m) vor `center_km` geht
  der Boden des Stadtrands weich in den des Zentrums über (`RoadRenderer.ground_blend`) – vorher lief dort eine harte
  Kante quer über den Boden (grüne Gärten → Sand).

Konfiguration (optional, `render`): `landmark_far_m` (1900), `landmark_range_factor` (2,0), `skyline_distance_m` (1800).

Leistung (`bench_render.gd`, Kiel – Hamburg, Last ≈ 7 auf 4 Kernen): Minimum 4,8 ms außerhalb der Stadt, auf der
Köhlbrandbrücke 5,3 ms, auf den Elbbrücken 5,5 ms (Geländer, Seitenträger, Portale ≈ +0,3 ms), Zentrum 4,3–4,5 ms;
Mediane 5,7–8,6 ms (stark lastabhängig). Nach der Sichtprüfung (prozedurale Pylone, mehr Häuser am Hanse-Stadtrand,
Fassadenraster der Hochhäuser; gleiche Positionen, Last ≈ 1–2, verglichen mit dem Stand davor): Minima +0,1–0,4 ms –
Stadtrand vor der Köhlbrandbrücke 5,7–6,2 statt 5,6–5,8 ms, auf der Brücke 6,4–6,5 statt 6,0–6,4 ms, Cuatro Torres
aus der Nähe 5,7–5,9 statt 5,5–5,8 ms (+530 Dreiecke); Mediane 6,6–8,1 ms gegen 6,3–7,5 ms vorher.

## 8. Gebäudeliste (für die Sprite-Pipeline)

Diese IDs stehen in `data/scenery.json`; bis ein Sprite existiert, zeichnet die Laufzeit den angegebenen Ersatz
(`fallback`, getönt mit `fallback_tint`). Konventionen wie `props/building_*` (`tools/blender/cesprites/props*.py`):
Winkel `c`, Ebenen `base` + `lights` (Fenster nachts), 3/4-Ansicht für den **rechten** Straßenrand (`view_yaw` ≈ −20°),
Tags `prop`, `building`, `city`, `mirror_left`, Anker = Bodenpunkt Objektmitte vorn, `extent_m` (die Regeln stellen
die Vorderkante mit `align: edge` hinter den Gehweg). R = Stadtrand, Z = Zentrum. **Priorität 1** = vom Nutzer
genannt bzw. prägend.

| ID (`props/…`) | Landschaft | Beschreibung | Maße B × H × T (m) | Ersatz heute |
|---|---|---|---|---|
| `city_eastern_family_house` | eastern R | **P1** kleines Einfamilienhaus (1–2 Geschosse, Zeltdach, Putz in Pastell), Garten; der Zaun wird prozedural gezeichnet | 9 × 7 × 9 | `house_med` × 0,8 |
| `city_eastern_kostka` | eastern R | **P1** polnischer „Würfel“ (Kostka): quadratisch, flaches Zeltdach, zwei Geschosse | 10 × 8 × 10 | `house_med` × 0,78 |
| `city_eastern_plattenbau` | eastern R/Z, baltic Z | **P1** Plattenbau, 11 Geschosse, Betonplatten, Balkonreihen | 30 × 32 × 12 | `building_block_a` × 1,4 grau |
| `city_eastern_tenement` | eastern Z | Kamienica (Mietshaus um 1900, 5 Geschosse, Putz, Gesimse) | 15 × 18 × 12 | `building_block_a` × 0,85 |
| `city_dutch_canal_house_step` | dutch Z | **P1** Grachtenhaus mit Treppengiebel, 4–5 Geschosse, dunkler Backstein, weiße Fenster, Lastbalken | 7 × 18 × 14 | `building_oldtown` |
| `city_dutch_canal_house_bell` | dutch Z | **P1** Grachtenhaus mit Glockengiebel (Sandstein-Schmuck) | 7 × 18 × 14 | `building_oldtown` |
| `city_dutch_canal_house_neck` | dutch Z | **P1** Grachtenhaus mit Halsgiebel | 6 × 17 × 14 | `building_oldtown` |
| `city_dutch_rowhouse` | dutch R | Backstein-Reihenhäuser (Zeile von 3–4 Häusern) | 18 × 9 × 9 | `house_med` |
| `city_vienna_palais` | vienna Z | **P1** Ringstraßenpalais: Renaissance-/Gründerzeitfassade, Rustika-EG, Säulen, Attika mit Figuren, 5 Geschosse | 22 × 24 × 16 | `building_block_a` |
| `city_vienna_dome_church` | vienna Z | **P1** barocke Kuppelkirche (Art Karlskirche) | 40 × 70 × 60 | `church` × 1,3 |
| `city_vienna_gemeindebau` | vienna R/Z | Gemeindebau (Wohnhof, 6 Geschosse, Rundbogen-Durchfahrt) | 30 × 21 × 14 | `building_block_a` × 1,1 |
| `city_paris_haussmann` | paris Z | **P1** Haussmann-Block: heller Kalkstein, 6 Geschosse, Balkone im 2./5. OG, Mansarddach mit Gauben | 20 × 24 × 14 | `building_block_a` |
| `city_paris_haussmann_corner` | paris Z | Haussmann-Eckhaus mit runder Ecke und kleiner Kuppel | 22 × 27 × 16 | `building_block_a` × 1,1 |
| `city_paris_pavillon` | paris R | Pavillon de banlieue (Mühlstein/Putz, Ziegeldach) | 10 × 8 × 9 | `house_med` |
| `city_paris_hlm` | paris R | Wohnriegel der Banlieue (HLM, 10 Geschosse) | 40 × 30 × 12 | `building_block_a` × 1,3 |
| `city_hanse_speicher` | hanse Z | **P1** Speicherstadt-Speicher: Backstein-Neugotik, 7 Geschosse, Türmchen, Windenerker | 24 × 26 × 16 | `building_block_b` |
| `city_hanse_gable_house` | hanse R/Z | Backstein-Giebelhaus (Treppengiebel, 3–4 Geschosse) | 9 × 15 × 12 | `house_med` / `building_oldtown` |
| `city_hanse_kontorhaus` | hanse R/Z | Kontorhaus (dunkler Klinker, expressionistisch, 8 Geschosse) | 28 × 30 × 18 | `building_block_b` |
| `city_hanse_brick_block` | hanse Z | Rotklinker-Wohnblock, 5 Geschosse | 20 × 18 × 12 | `building_block_a` |
| `city_hanse_harbour_crane` | hanse R | Hafenkran (Stahlgitter, rot/grau, Ausleger) | 20 × 40 × 10 | `power_pylon` rot |
| `city_german_family_house` | german R, german_old R | Einfamilienhaus mit Satteldach und Garten | 10 × 9 × 10 | `house_med` |
| `city_german_apartment` | german R | Mehrfamilienhaus der 60er/70er, 4 Geschosse | 18 × 13 × 12 | `building_block_a` × 0,85 |
| `city_german_gruenderzeit` | german Z | Gründerzeit-Mietshaus (Stuck, Erker, 5 Geschosse) | 16 × 19 × 13 | `building_block_a` × 0,9 |
| `city_german_postwar_block` | german Z | Nachkriegs-Wohnblock | 20 × 18 × 12 | `building_block_a` |
| `city_german_office_tower` | german Z | Bürohochhaus Glas (80–120 m; Frankfurt) | 30 × 100 × 30 | `building_tall` |
| `city_german_old_timber_house` | german_old R/Z | Fachwerkhaus (3–4 Geschosse, vorkragend, Giebel zur Straße) | 9 × 15 × 12 | `farmhouse` / `building_oldtown` |
| `city_german_old_baroque_house` | german_old Z | barockes Bürgerhaus (Sandstein, Volutengiebel) | 14 × 18 × 14 | `building_block_a` |
| `city_belgian_rowhouse` | belgian R/Z | schmales Backstein-Reihenhaus (3 Geschosse) | 7 × 12 × 12 | `house_med` / `building_oldtown` |
| `city_belgian_stone_house` | belgian R/Z | Bürgerhaus aus Blaustein/Sandstein (4 Geschosse) | 14 × 16 × 12 | `farmhouse` / `building_block_a` |
| `city_french_house` | french R | Einfamilienhaus (Putz, Fensterläden, Ziegeldach) | 11 × 8 × 10 | `house_med` |
| `city_french_townhouse` | french Z | Stadthaus aus hellem Kalkstein mit Fensterläden (4 Geschosse) | 14 × 15 × 12 | `building_block_a` × 0,8 |
| `city_french_south_house` | french Z | südfranzösisches Haus (ocker, flaches Ziegeldach, 3 Geschosse) | 12 × 11 × 10 | `house_med` × 1,1 |
| `city_spanish_house` | spanish R | weißes Haus mit Terrakottadach und Mauer | 11 × 7 × 10 | `house_med` |
| `city_spanish_block` | spanish R/Z | Wohnblock 8–10 Geschosse, Balkone, ocker | 22 × 28 × 14 | `building_block_a` |
| `city_spanish_balcony_house` | spanish Z | Stadthaus mit Balkonen und verglasten Erkern (5 Geschosse) | 14 × 17 × 12 | `building_block_a` × 0,85 |
| `city_italian_palazzo` | italian Z | Palazzo (Rustika-EG, Fensterläden, Kranzgesims, 4 Geschosse) | 22 × 19 × 16 | `building_block_a` |
| `city_italian_house` | italian R/Z | verputztes Haus ocker/rosa, Ziegeldach, Fensterläden | 11 × 10 × 10 | `house_med` / `building_block_a` × 0,8 |
| `city_italian_block` | italian R/Z | Wohnblock 7 Geschosse mit Balkonen | 20 × 22 × 13 | `building_block_a` |
| `city_austrian_house` | austrian R, vienna R | Haus mit Walmdach und Balkon | 11 × 9 × 10 | `house_med` |
| `city_austrian_townhouse` | austrian Z | Bürgerhaus mit Erker, Pastell (4 Geschosse) | 14 × 16 × 12 | `building_block_a` × 0,85 |
| `city_swiss_chalet` | swiss R | Chalet: Holz, weit überstehendes Dach, Balkone mit Blumen | 12 × 10 × 12 | `farmhouse` |
| `city_swiss_arcade_house` | swiss Z | Berner Laubenhaus: grüngrauer Sandstein, Arkaden im EG, steiles Dach | 13 × 17 × 14 | `building_block_a` × 0,85 |
| `city_central_family_house` | central R | Einfamilienhaus mit Walmdach | 10 × 8 × 10 | `house_med` |
| `city_central_block` | central R | Wohnblock (Paneláky) | 28 × 26 × 12 | `building_block_a` × 1,3 |
| `city_central_baroque_house` | central Z | barockes Bürgerhaus in Pastell, Volutengiebel | 13 × 17 × 13 | `building_block_a` × 0,85 |
| `city_central_art_nouveau` | central Z | Jugendstilhaus (5 Geschosse, Erker, Mosaik) | 18 × 20 × 14 | `building_block_a` |
| `city_central_tower` | central Z | gotischer Torturm (Pulverturm), 50 m | 14 × 50 × 14 | `church` × 0,9 |
| `city_balkan_house` | balkan R | Einfamilienhaus, oft unverputzt (roter Hohlziegel), Balkon, Bewehrungseisen auf dem Dach | 11 × 9 × 10 | `house_med` |
| `city_balkan_church` | balkan R/Z | kleine orthodoxe Kirche mit Kuppel | 14 × 22 × 20 | `church` × 0,8 |
| `city_balkan_plattenbau` | balkan Z | sozialistischer Wohnblock, 10–14 Geschosse | 30 × 36 × 12 | `building_block_a` × 1,4 |
| `city_balkan_townhouse` | balkan Z | Bürgerhaus 19. Jh. (3–4 Geschosse, Putz) | 14 × 14 × 12 | `building_block_a` × 0,8 |
| `city_baltic_wooden_house` | baltic R | Holzhaus, farbig gestrichen (grün/gelb), Satteldach, Schnitzwerk | 10 × 8 × 10 | `house_med` / `farmhouse` |
| `city_baltic_art_nouveau` | baltic Z | Rigaer Jugendstilhaus (Masken, Figuren, 6 Geschosse) | 18 × 22 × 14 | `building_block_a` |

**Brückenteile** (§4; Laufzeit zeichnet bis dahin prozedural):

| ID | Beschreibung, Vorgaben der Laufzeit |
|---|---|
| `props/bridge_truss_arch` | Stahlbogen-Portal über der ganzen Fahrbahn, Ansicht genau von vorn, Anker unten Mitte, `object.width_m` = Außenbreite an den Beinen (die Laufzeit skaliert auf die Deckbreite), lichte Höhe ≥ 6 m, Scheitel ≈ 14 m, Tag `overhead`, ohne `mirror_left`; dunkelgrüner Stahl (Hamburg) |
| `props/bridge_pylon` | ein Pylon (Beton, ≈ 80–100 m) mit Seilfächer zur Fahrbahn hin, für den rechten Rand, `mirror_left`; steht 1,3 m außerhalb des Geländers. **Zur Zeit nicht gezeichnet** (`prefer_proc`, §7). Ein neues Sprite bräuchte: Zelle ≥ 1024 px hoch, **ohne** Seilfächer (die Laufzeit zeichnet die Seile in 3D), schwächere Lichtebene, Skalierung über `pylon_m` / `object.height_m` |
| `props/bridge_lamp` | Kandelaber (≈ 4,5 m, drei Kugeln), `lights`, `mirror_left` |
| `props/houseboat` | Hausboot in Breitseitenansicht (20–25 m), Anker = **Wasserlinie Mitte** (wie `props/ferry_ship`), `lights` |

**Wahrzeichen** (Katalog `landmark_sets`; Winkel `c`, Ebenen `base` + `lights` = Anstrahlung, Anker Bodenpunkt
Mitte vorn, echte Maße, Tag `landmark`, **kein** `mirror_left` – Wahrzeichen werden nie gespiegelt):

| ID (`landmarks/…`) | Name | Höhe × Breite (m) | Pflicht | Ersatz heute |
|---|---|---|---|---|
| `eiffel_tower` | Eiffelturm | 330 × 125 | ja | prozedural `lattice_tower` |
| `elbphilharmonie` | Elbphilharmonie | 110 × 110 | ja | `building_tall` × 1,65 |
| `michel` | Michel | 132 × 45 | ja | `church` × 3,7 |
| `riesenrad` | Riesenrad | 65 × 62 | ja | prozedural `ferris_wheel` |
| `stephansdom` | Stephansdom | 136 × 70 | ja | `church` × 3,85 |
| `fernsehturm_berlin` | Fernsehturm | 368 × 32 | ja | prozedural `tv_tower` |
| `frauenkirche_dresden` | Frauenkirche Dresden | 91 × 50 | ja | prozedural `domed_church` |
| `frauenkirche_muenchen` | Frauenkirche München | 99 × 40 | ja | `church` × 2,8 |
| `sagrada_familia` | Sagrada Família | 172 × 90 | ja | `church` × 4,9 |
| `duomo_milano` | Mailänder Dom | 108 × 93 | ja | `church` × 3,0 |
| `campanile_venezia` | Campanile di San Marco | 99 × 13 | ja | prozedural `campanile` |
| `parlament_budapest` | Parlament | 96 × 268 | ja | prozedural `parliament` |
| `veitsdom_prag` | Veitsdom | 97 × 60 | ja | `church` × 2,75 |
| `kulturpalast_warschau` | Kulturpalast | 237 × 90 | ja | prozedural `palace_tower` |
| `nevsky_kathedrale` | Alexander-Newski-Kathedrale | 53 × 70 | ja | prozedural `domed_church` |
| `frankfurter_hochhaeuser` | Frankfurter Hochhäuser | 259 × 150 | nach Zeit | prozedural `skyscrapers` |
| `kaiserburg_nuernberg` | Kaiserburg | 50 × 80 | nach Zeit | `church` × 1,6 |
| `freiheitsdenkmal_riga` | Freiheitsdenkmal | 42 × 22 | nach Zeit | prozedural `column` |
| `kathedrale_burgos` | Kathedrale von Burgos | 88 × 60 | nach Zeit | `church` × 2,5 |
| `basilica_pilar` | Basílica del Pilar | 80 × 130 | nach Zeit | prozedural `domed_church` |
| `florianturm`, `fernsehturm_riga`, `cuatro_torres`, `sacre_coeur`, `hram_svetog_save`, `herkules_kassel` | optional | siehe `cities.json` | nein | prozedural bzw. `church` |

## 9. Tests, Screenshots, offene Assets

- `tests/unit/data/test_cities.gd`: jede Stadt hat einen Stil mit beiden Landschaften, Rückfall-Regeln,
  `CityData.validate()` und `missing_props()` leer, alle Stile (die 16 des Vertrags und die regionalen) mit eigenem
  Boden, Gebäuden mit Ersatz, links gespiegelten Bäumen und gültigem Zaun, Skyline-Einträge mit `proc` ohne
  Ersatz-Sprite (Rigaer Fernsehturm, Herkules), **jede Ankunft in jeder Stadt (beide Richtungen aller Etappen) ohne
  Warnung** (Brücken in der Etappe und nicht im Tunnel, Wahrzeichen in den City Limits, nicht im Tunnel, nicht im
  Wasser), Pflicht-Wahrzeichen und -Brücken,
  Auflösung der Hamburger Ankunft (km, Länge in sichtbaren Metern, Sortierung, Skyline ↔ Requisite), ungültige Brücken
  werden mit Warnung verworfen.
- `tests/unit/race/test_city_track.gd`: Stadtrand/Zentrum je Segment, Brücken als Wasser-Zonen mit Ufer, Boden unter
  dem Deck (Kaimauer/Böschung), keine Landschaft auf dem Wasser, Portale alle 40 m über der ganzen Fahrbahn, Pylone
  (prozedural, `prefer_proc`), Laternen, Hausboote und Schiff auf Wasserhöhe, Wahrzeichen als Ereignis mit freiem
  Platz und gleicher Lage in der Fernliste, Parkbäume von Wahrzeichen direkt hinter einer Gracht und einer
  Hochbrücke und in allen echten Ankünften nicht auf oder an einer Brücke, Pylone aller Schrägseilbrücken
  prozedural, Determinismus.
- `tests/unit/race/test_city_render.gd`: `landmark_fade` stetig und monoton (kein Aufpoppen, am Rand der Sichtweite
  noch sichtbar, bei klarer Sicht ab den City Limits), `water_tint`, Eiffelturm-Profil, Boden unter Brücken,
  Hintergrundstil `suburb`, Bergkette `behind` mit Farbe und Dunst (`RaceBackdrop.behind_params`/`behind_haze`),
  weicher Bodenübergang zum Zentrum (`ground_blend`).
- Screenshots (je 1280 × 720): `tools/screenshot.sh <präfix> --stage=kiel_hamburg --start-km=83.6 --start-speed=60
  --hour=12 --autopilot --no-countdown --shot-times=1.5` (Elbbrücken; 78.7 = Köhlbrandbrücke, 77.0 = Anfahrt),
  `--stage=luettich_paris --start-km=378` (Eiffelturm von fern; 387.0 = Pont Alexandre III mit dem Turm über der Seine,
  386.4 mit `--hour=22` nachts, 394 = Turm am Ziel),
  `--stage=bremen_amsterdam --start-km=357.6` (Grachten), `--stage=budapest_wien --start-km=237.3` (Reichsbrücke,
  Riesenrad, Stephansdom), `--stage=warschau_bialystok --start-km=182` bzw. `--stage=posen_warschau --start-km=287`
  (Einfamilienhäuser mit Zäunen, Kulturpalast in der Ferne), `--stage=mailand_venedig --start-km=269` (Damm, Campanile).
- **Geliefert** (Manifest, [sprites.md](sprites.md)): 46 Stadtgebäude in 15 Stilen (`props/city_*`, Namen wie in
  sprites.md „Städte“, nicht wie in der Wunschliste §8), `bridge_truss_arch`, `bridge_pylon`, `bridge_lamp`,
  `houseboat` und 21 Wahrzeichen (die 15 Pflicht-Sets und 6 weitere).
- **Noch ohne Asset** (läuft prozedural oder mit Ersatz):
  - Wahrzeichen nur prozedural: `florianturm`, `fernsehturm_riga` (`tv_tower`), `cuatro_torres` (`skyscrapers`),
    `sacre_coeur`, `hram_svetog_save`, `voelkerschlachtdenkmal`, `neues_rathaus_hannover` (`domed_church`),
    `herkules_kassel` (`octagon`).
  - Wahrzeichen mit dem Sprite eines anderen: Festung Marienberg, Burg Ljubljana, Château de Pau (Kaiserburg),
    Marienkirche Rostock (Petrikirche Riga), Posener Dom (Frauenkirche München), Notre-Dame de Fourvière
    (`city_vienna_kirche`).
  - Wahrzeichen als allgemeine Kirche `props/church` (getönt): Rathausturm Kiel, Bremer Dom, Martinskirche Kassel,
    Magdeburger und Erfurter Dom, Westerkerk, Saint-Paul Lüttich, Saint-Gatien Tours, Saint-André Bordeaux,
    Saint-Sernin Toulouse, Saint-Pierre Montpellier, Buen Pastor San Sebastián, Berner Münster,
    Franziskanerkloster Slavonski Brod, Fara Białystok, Christi-Auferstehungs-Kirche Kaunas; Leipziger
    City-Hochhaus und Torre Glòries als `props/building_tall`.
  - Gebäude mit Ersatz aus anderen Stilen: HLM der Banlieue (`city_eastern_plattenbau`), italienische Villette
    (`city_spanish_casa`, `city_french_sud`), bayerische/österreichische Häuser (`city_german_house`),
    mitteleuropäische Würfelhäuser und Paneláky (`city_eastern_house_a/_c`, `city_eastern_plattenbau`),
    Zechenhäuser im Ruhrgebiet (`city_dutch_terrace`), Wiener Gemeindebau.
  - `props/bridge_pylon` neu (siehe §8), dann ohne `prefer_proc`. Reihenfolge und Vorgaben: sprites.md „Wunschliste“.
