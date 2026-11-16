import json,sys
for b in sys.argv[1:]:
    c=json.load(open(b+'/config/game_config.json'))
    g=c['graphics']
    print('==',b)
    print('presets', json.dumps(g.get('presets'),ensure_ascii=False)[:1500])
    lv=g['levels']
    for k in ('details','shadows'):
        print(k, json.dumps(lv.get(k),ensure_ascii=False)[:2000])
