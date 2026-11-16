"""deliver.py: section labels alternate between two rows (the one-bar count-in and A1 overlapped)."""
import os

p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "deliver.py")
s = open(p, encoding="utf-8").read()
old = """    for t, lab in zip(marks, labels):
        xx = int(t / total * width)
        dr.line([(xx, 40), (xx, rows * 2 + 40)], fill=(255, 255, 255), width=1)
        dr.text((xx + 3, 44), lab, fill=(255, 255, 255), font=FONT)"""
new = """    for k, (t, lab) in enumerate(zip(marks, labels)):
        xx = int(t / total * width)
        dr.line([(xx, 40), (xx, rows * 2 + 40)], fill=(255, 255, 255), width=1)
        dr.text((xx + 3, 44 + 16 * (k % 2)), lab, fill=(255, 255, 255), font=FONT)"""
assert old in s
s = s.replace(old, new)
open(p, "w", encoding="utf-8").write(s)
print("ok")
