"""Re-render list of the R3E series: the SUV by day (its first run hit a half-edited script), the buses with the middle
bus at 58.3 m (Arcade loses the rear face of a bus at 60.3 m: rounding in BoxVehicle.emit), and a bend (fold)."""
import json, os, sys
S = sys.argv[1]
shots = os.path.join(S, 'series')
lines = ['#!/usr/bin/env bash', 'set -uo pipefail', 'S=' + S, 'cd $S']
cap_suv = 'SUV: 20 m Mitte, 60 m eigene Spur (Blinker), 150 m links – Kiel–Hamburg km 2, 12 Uhr, Voreinstellung Mittel; Spieler: Gran Turismo'
lines.append('GFX_ARGS="--gfx-preset=medium" timeout 900 $S/ab_inject.sh $S/series/suv_tag %s/cars_suv_tag.json "%s" --stage=kiel_hamburg --from=kiel --km=2 --hour=12 --weather=normal --vehicle=gran_turismo' % (shots, cap_suv))
for tname, hour in [('tag', 12), ('nacht', 22)]:
    fn = os.path.join(shots, 'cars_bus_%s.json' % tname)
    cars = json.load(open(fn))
    cars[1]['dist'] = 58.3
    json.dump(cars, open(fn, 'w'))
    cap = 'Bus: 20 m Mitte, 58 m eigene Spur (Blinker), 150 m links – Kiel–Hamburg km 2, %d Uhr, Voreinstellung Mittel; Spieler: Sportwagen' % hour
    lines.append('GFX_ARGS="--gfx-preset=medium" timeout 900 $S/ab_inject.sh $S/series/bus_%s %s "%s" --stage=kiel_hamburg --from=kiel --km=2 --hour=%d --weather=normal --vehicle=sportwagen' % (tname, fn, cap, hour))
bend = [{'set': 'traffic/sports_blue', 'dist': 14.3, 'lane': -3.75}, {'set': 'traffic/van_red', 'dist': 30.3, 'lane': -3.75},
        {'set': 'police/de', 'dist': 24.3, 'lane': 0.0}, {'set': 'traffic/suv_brown', 'dist': 55.3, 'lane': 0.0},
        {'set': 'traffic/bus_white', 'dist': 75.3, 'lane': -3.75}]
fn = os.path.join(shots, 'cars_kurve.json')
json.dump(bend, open(fn, 'w'))
lines.append('GFX_ARGS="--gfx-preset=medium" timeout 900 $S/ab_inject.sh $S/series/kurve_t1 %s "Kurve T1 (Kassel–Würzburg km 46,5, 15 Uhr): nahe Autos gefaltet wie Arcades Warp; Modern mit Blick in die Kurve (D12); Spieler: Sportwagen" --stage=kassel_wuerzburg --from=kassel --km=46.5 --hour=15 --weather=normal --vehicle=sportwagen' % fn)
open(os.path.join(S, 'series2.sh'), 'w').write('\n'.join(lines) + '\necho FERTIG\n')
os.chmod(os.path.join(S, 'series2.sh'), 0o755)
print('\n'.join(lines))
