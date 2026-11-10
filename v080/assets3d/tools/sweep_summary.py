import json, collections, sys
BASE="/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/assets3d"
r=json.load(open(BASE+'/out/sweep_report.json'))
ok=[k for k,v in r.items() if v['ok']]
err={k:v['error'] for k,v in r.items() if not v['ok']}
print("models:", len(r), "ok:", len(ok), "errors:", err)
cut=sorted(k for k in ok if r[k]['special']['cutout'])
lv=sorted((k,[m for m in r[k]['special']['light_volume'] if '_lens' not in m]) for k in ok if [m for m in r[k]['special']['light_volume'] if '_lens' not in m])
rnd=sorted(k for k in ok if r[k]['special']['obj_random'])
print("cutout materials in %d models:" % len(cut), cut)
print("light volumes:", lv)
print("per-object random colour:", rnd)
by=collections.defaultdict(list)
for k in ok: by[r[k]['builder']].append((k, r[k]))
tot_b=tot_e=0
for b,vs in by.items():
    bs=sum(v['build_s'] for _,v in vs); es=sum(v['export_s'] for _,v in vs)
    tot_b+=bs; tot_e+=es
    charts=sorted(v['bake']['charts'] for _,v in vs if v.get('bake'))
    ppm=sorted(v['bake']['ppm'] for _,v in vs if v.get('bake'))
    surf=sorted(v['surfaces'] for _,v in vs)
    print("%-9s n=%3d build %.0f s export %.0f s tris %d surfaces(med/max) %d/%d charts(med/max) %s glb MB %.1f" % (
        b, len(vs), bs, es, sum(v['tris'] for _,v in vs), surf[len(surf)//2], surf[-1],
        ("%d/%d" % (charts[len(charts)//2], charts[-1])) if charts else "-", sum(v['glb_bytes'] for _,v in vs)/1e6))
print("total build %.1f min, export(256^2 atlases, 1 spp) %.1f min" % (tot_b/60, tot_e/60))
many=sorted(((v['bake']['charts'], k) for k,v in ((k, r[k]) for k in ok) if v.get('bake') and v['bake']['charts']>2000), reverse=True)
print("models with > 2000 charts (atlas inefficient -> vertex-colour bake):", [(k,c) for c,k in many])
json.dump(dict(models=len(r), ok=len(ok), errors=err, cutout=cut, light_volumes=lv, many_charts=[(k,c) for c,k in many], build_min=round(tot_b/60,1), export_min=round(tot_e/60,1)), open(BASE+'/out/sweep_summary.json','w'), indent=1)
