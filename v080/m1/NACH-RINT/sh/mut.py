"""mut.py <file> <old> <new> : replace exactly one occurrence (fails otherwise)."""
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding="utf-8").read()
n = s.count(old)
if n != 1:
    sys.exit("count=%d" % n)
open(p, "w", encoding="utf-8").write(s.replace(old, new))
print("mutated", p)
