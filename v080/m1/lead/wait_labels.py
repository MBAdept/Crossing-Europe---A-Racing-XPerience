# wait until the workflow journal has a result line (any value, also null) for EVERY given label;
# the last "started" line of a label counts (stale starts of a stopped run are ignored).
# usage: python3 -u wait_labels.py <journal> <label> [<label> ...]
import json, sys, time
journal, labels = sys.argv[1], sys.argv[2:]
reported = set()
while True:
    key = {}; res = {}
    try:
        for line in open(journal):
            try: d = json.loads(line)
            except Exception: continue
            if d.get('type') == 'started' and d.get('label') in labels:
                key[d['label']] = d.get('key'); res.pop(d['label'], None)
            elif d.get('type') == 'result':
                for lb, k in key.items():
                    if k == d.get('key'): res[lb] = d.get('result')
    except FileNotFoundError: pass
    for lb in labels:
        if lb in res and lb not in reported:
            r = res[lb]
            if isinstance(r, dict):
                info = r.get('commit') or ('%d Befunde' % len(r.get('findings', [])) if 'findings' in r else 'ok')
            else:
                info = 'kein Ergebnis (null)' if r is None else str(r)[:80]
            print(lb, 'fertig:', info, flush=True)
            reported.add(lb)
    if all(lb in res for lb in labels):
        break
    time.sleep(20)
