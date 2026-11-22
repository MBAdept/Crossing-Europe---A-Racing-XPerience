import json, os, sys
root = sys.argv[1]
d = json.load(open(os.path.join(root, 'data/cities.json')))
cities = d['cities']
print(type(cities), len(cities))
first = next(iter(cities.values())) if isinstance(cities, dict) else cities[0]
print('keys of a city:', list(first.keys()))
ls = d['landmark_sets']
for cid, c in (cities.items() if isinstance(cities, dict) else enumerate(cities)):
    lms = c.get('landmarks', [])
    sky = c.get('skyline', [])
    if lms or sky:
        def f(e):
            s = e.get('set', '') if isinstance(e, dict) else str(e)
            p = ls.get(s, {}).get('proc', '')
            return s.replace('landmarks/', '') + ('(' + p + ')' if p else '') + ('' if not isinstance(e, dict) else str({k: v for k, v in e.items() if k != 'set'}))
        print(cid, 'LM:', [f(e) for e in lms], 'SKY:', [f(e) for e in sky])
