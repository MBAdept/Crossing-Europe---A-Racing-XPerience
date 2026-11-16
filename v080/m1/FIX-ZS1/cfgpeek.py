import json, sys
c = json.load(open(sys.argv[1]))
r = c.get('render', {})
print({k: r[k] for k in r if 'vis' in k or 'camera' in k or 'fog' in k or 'height' in k})
m = c['graphics']['modern']
print({k: m[k] for k in m if k in ('chunk_segments', 'load_path_m', 'landmark_path_m', 'keep_behind_m', 'max_chunks', 'rebase_m', 'camera')})
t = c.get('time', {})
print({k: t[k] for k in t if 'count' in k})
