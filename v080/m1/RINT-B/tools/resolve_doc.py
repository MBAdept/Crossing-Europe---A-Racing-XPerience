import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
a = s.index("<<<<<<< HEAD\n")
m = s.index("=======\n", a)
b = s.index(">>>>>>> fbfd1b5\n", m)
head = s[a + len("<<<<<<< HEAD\n"):m]
theirs = s[m + len("=======\n"):b]
# HEAD: first bullet (Erledigt...) then "## 12."
i12 = head.index("## 12. ")
head_bullets = head[:i12]
head_rest = head[i12:]
# theirs: drop the two outdated R3 'Offen' bullets, keep from "### 10.8"
j = theirs.index("### 10.8 ")
section = theirs[j:]
section = section.replace("### 10.8 Ersatzbilder", "### 11.8 Ersatzbilder", 1)
section = section.replace("den „Kasten in Größe und Lack“ aus 10.1 und 10.7", "den „Kasten in Größe und Lack“ aus 11.1 und 11.7", 1)
assert "10.1 und 10.7" not in section
merged = head_bullets.rstrip("\n") + "\n\n" + section.rstrip("\n") + "\n\n" + head_rest
s = s[:a] + merged + s[b + len(">>>>>>> fbfd1b5\n"):]
open(p, "w", encoding="utf-8").write(s)
print("ok", s.count("<<<<<<<"), s.count(">>>>>>>"))
