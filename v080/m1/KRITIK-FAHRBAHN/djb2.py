import json
def djb2(s):
    h=5381
    for ch in s:
        h=((h<<5)+h+ord(ch)) & 0xFFFFFFFF
    return h
def unit(s): return (djb2(s) & 0xFFFFFF)/float(0x1000000)
cities=['hamburg','hannover','paris','venedig','mailand','wuerzburg','bremen','amsterdam','luettich','tours','madrid','wien','prag','berlin']
for c in cities:
    us=[unit(f"{c}|{k}") for k in range(0,40)]
    cob=sum(u<0.6 for u in us)
    print(f"{c:10s} unit_hash blocks 0..39: min {min(us):.6f} max {max(us):.6f} -> cobbled {cob}/40")
