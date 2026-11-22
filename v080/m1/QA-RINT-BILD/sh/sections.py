import json, sys
n = json.load(open(sys.argv[1]))
want = sys.argv[2].split(',')
for s in n['stages']:
    if s['id'] in want:
        km = 0
        print(s['id'], s['length_km'])
        for sec in s['sections']:
            extra = {k: v for k, v in sec.items() if k not in ('length_km', 'road', 'name', 'curviness', 'hills', 'scenery', 'country', 'speed_limit', 'traffic')}
            print('  %6.1f %5.1f %-10s %-12s %s %s' % (km, sec['length_km'], sec.get('road'), sec.get('scenery'), sec.get('name'), extra))
            km += sec['length_km']
