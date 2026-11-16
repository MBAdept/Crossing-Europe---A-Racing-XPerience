import json, sys
root = sys.argv[1]
n = json.load(open(root + '/data/network.json'))
print(list(n.keys()))
st = n.get('stages')
seq = st if isinstance(st, list) else list(st.values())
print(type(st), len(seq))
print(json.dumps(seq[0])[:400])
want = sys.argv[2:] or ['belgrad', 'budapest', 'wien', 'riga', 'venedig', 'amsterdam']
for s in seq:
    txt = json.dumps(s)
    if any(k in txt for k in want):
        print({k: s[k] for k in s if not isinstance(s[k], (list, dict))})
