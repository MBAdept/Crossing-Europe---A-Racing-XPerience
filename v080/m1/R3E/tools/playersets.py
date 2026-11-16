import json, sys
root = sys.argv[1]
sm = json.load(open(root + '/assets/sprites/manifest.json'))
sets = sm['sets']
for k in ['player/kombi', 'player/sportwagen', 'player/gran_turismo', 'player/kompakt', 'traffic/sports_red', 'traffic/van_white', 'traffic/suv_grey', 'police/de']:
    s = sets[k]
    print(k, json.dumps({kk: v for kk, v in s.items() if kk not in ('parts', 'lights')}))
    if s.get('projection') == 'perspective':
        cam = s['camera']
        ss = s.get('supersample', 1.0)
        focal = 711.0
        print('   W_m from camera =', s['cell'][0] * cam['distance_m'] / (ss * focal), ' image_width_m =', s['image_width_m'])
