"""Appends a code block to a file (scratch helper): append_code.py <target> <block file>; adds "import math"
after "import time" if missing."""
import sys

target, block = sys.argv[1], sys.argv[2]
s = open(target).read()
add = open(block).read()
if add.strip() in s:
    print("schon drin")
    sys.exit(0)
if "import math\n" not in s and "import time\n" in s:
    s = s.replace("import time\n", "import math\nimport time\n", 1)
s = s.rstrip("\n") + "\n" + add
open(target, "w").write(s)
print("angehängt", len(add.splitlines()), "Zeilen")
