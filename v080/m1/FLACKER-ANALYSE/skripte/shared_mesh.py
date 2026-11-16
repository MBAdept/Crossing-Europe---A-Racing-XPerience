import json,collections
for b in ('zs1','m2'):
    m=json.load(open(b+'/assets/models/manifest.json'))
    use=collections.defaultdict(set)
    kinds=collections.Counter()
    for mid,e in m['models'].items():
        k=str(e.get('kind',''))
        kinds[k]+=1
        veh = k in ('vehicle','heavy')
        for l in e.get('lods',[]):
            for p in l.get('parts',[]):
                use[p.get('mesh','')].add((mid,veh))
        if 'shadow' in e:
            use[e['shadow'].get('mesh','')].add((mid,veh))
    mixed=[(path,sorted(v)) for path,v in use.items() if len({x[1] for x in v})>1]
    shared_veh=[(path,len(v)) for path,v in use.items() if len(v)>1 and all(x[1] for x in v)]
    print('==',b,'kinds',dict(kinds),'meshes',len(use),'mixed vehicle/non-vehicle',len(mixed),'shared among vehicles',len(shared_veh))
    for x in mixed[:10]: print('  MIXED',x)
    for x in shared_veh[:5]: print('  shared',x)
