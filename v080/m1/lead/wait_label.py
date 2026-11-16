# wait until the workflow journal has a result for the agent with the given label; print its commit
import json, sys, time
journal, label = sys.argv[1], sys.argv[2]
while True:
    key = None; res = None
    try:
        for line in open(journal):
            try: d = json.loads(line)
            except Exception: continue
            if d.get('type') == 'started' and d.get('label') == label: key = d.get('key')
            elif d.get('type') == 'result' and key and d.get('key') == key: res = d.get('result')
    except FileNotFoundError: pass
    if res is not None:
        print(label, 'fertig:', (res or {}).get('commit') if isinstance(res, dict) else res)
        break
    time.sleep(20)
