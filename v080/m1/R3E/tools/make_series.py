"""Writes the cars json files and the batch script of the R3E picture series (A/B Arcade | Modern per kind, day and
night, 20/60/150 m; before/after painted box | picture)."""
import json, os, sys
S = sys.argv[1]
shots = os.path.join(S, 'series')
os.makedirs(shots, exist_ok=True)
kinds = [
    ('sport', 'Sportwagen', ['traffic/sports_red', 'traffic/sports_yellow', 'traffic/sports_blue'], 'kombi', ''),
    ('lieferwagen', 'Lieferwagen', ['traffic/van_white', 'traffic/van_red', 'traffic/van_silver'], 'sportwagen', ''),
    ('suv', 'SUV', ['traffic/suv_grey', 'traffic/suv_brown', 'traffic/suv_white'], 'gran_turismo', ''),
    ('polizei', 'Polizei (Blaulicht bei 60 m)', ['police/de', 'police/de', 'police/de'], 'kombi', ''),
    ('bus', 'Bus', ['traffic/bus_blue', 'traffic/bus_red', 'traffic/bus_white'], 'sportwagen', ''),
    ('lkw', 'Sattelzug ohne Modell (Manifest im Lauf ohne Lkw-Modell)', ['traffic/truck_white', 'traffic/truck_blue', 'traffic/truck_red'], 'gran_turismo',
     'traffic/truck_white,traffic/truck_blue,traffic/truck_red'),
]
dists = [(20.3, -3.75), (60.3, 0.0), (150.3, -7.5)]
lines = ['#!/usr/bin/env bash', 'set -uo pipefail', 'S=' + S, 'cd $S']
for key, label, sets, veh, nomodel in kinds:
    for hour, tname in [(12, 'tag'), (22, 'nacht')]:
        cars = []
        for i, (d, lane) in enumerate(dists):
            c = {'set': sets[i], 'dist': d, 'lane': lane}
            if hour == 22:
                c['tail'] = -1
            if i == 0 and hour == 22:
                c['brake'] = 1.0
            if i == 1:
                if key == 'polizei':
                    c['beacon'] = 'a'
                else:
                    c['blink'] = -1
                    c['blink_t'] = 0.1
            cars.append(c)
        fn = os.path.join(shots, 'cars_%s_%s.json' % (key, tname))
        json.dump(cars, open(fn, 'w'))
        cap = '%s: 20 m Mitte, 60 m eigene Spur (Blinker), 150 m links – Kiel–Hamburg km 2, %d Uhr, Voreinstellung Mittel; Spieler: %s' % (
            label, hour, veh.replace('_', ' ').title())
        extra = ' --nomodel=%s' % nomodel if nomodel else ''
        lines.append('GFX_ARGS="--gfx-preset=medium" timeout 900 $S/ab_inject.sh $S/series/%s_%s %s "%s" --stage=kiel_hamburg --from=kiel --km=2 --hour=%d --weather=normal --vehicle=%s%s' % (
            key, tname, fn, cap, hour, veh, extra))
# before / after: painted box (R3) | picture (R3E)
ba = [{'set': 'traffic/sports_red', 'dist': 20.3, 'lane': -3.75}, {'set': 'traffic/van_white', 'dist': 45.3, 'lane': 0.0},
      {'set': 'police/de', 'dist': 70.3, 'lane': -3.75, 'beacon': 'a'}, {'set': 'traffic/suv_grey', 'dist': 110.3, 'lane': -7.5},
      {'set': 'traffic/bus_red', 'dist': 160.3, 'lane': 0.0}]
fn = os.path.join(shots, 'cars_vorher_nachher.json')
json.dump(ba, open(fn, 'w'))
for hour, tname in [(12, 'tag'), (22, 'nacht')]:
    if hour == 22:
        b2 = [dict(c, tail=-1) for c in ba]
        b2[0]['brake'] = 1.0
        fn2 = os.path.join(shots, 'cars_vorher_nachher_nacht.json')
        json.dump(b2, open(fn2, 'w'))
    else:
        fn2 = fn
    lines.append('GFX_ARGS="--gfx-preset=medium" timeout 900 $S/ba_inject.sh $S/series/vorher_nachher_%s %s "Sportwagen 20 m, Lieferwagen 45 m, Polizei 70 m, SUV 110 m, Bus 160 m, Spieler Kombi – %d Uhr" --stage=kiel_hamburg --from=kiel --km=2 --hour=%d --weather=normal --vehicle=kombi' % (
        tname, fn2, hour, hour))
open(os.path.join(S, 'series.sh'), 'w').write('\n'.join(lines) + '\necho FERTIG\n')
os.chmod(os.path.join(S, 'series.sh'), 0o755)
print('\n'.join(lines))
