import json,sys
for b in ('zs1','m2'):
    m=json.load(open(b+'/assets/models/manifest.json'))
    sets=m.get('sets',{})
    try:
        sd=json.load(open(b+'/assets/models/sets_default.json'))
    except Exception as e:
        sd={}
    print('==',b,'manifest keys',list(m.keys())[:10], 'n sets',len(sets))
    out=[]
    for sid,s in sets.items():
        p=s.get('paint',{}) if isinstance(s,dict) else {}
        col=p.get('paint','') if isinstance(p,dict) else ''
        if not col: continue
        c=col.lstrip('#')
        try:
            r,g,bb=int(c[0:2],16),int(c[2:4],16),int(c[4:6],16)
        except: continue
        if min(r,g,bb)>=0xb0:
            out.append((sid,col,s.get('model',''),p.get('metal')))
    for o in out: print('  ',o)
    print('sets_default keys', list(sd.keys())[:5] if isinstance(sd,dict) else type(sd))
