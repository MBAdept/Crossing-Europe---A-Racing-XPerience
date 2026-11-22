p = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2/doc22_draft.md"
s = open(p).read()
a = """  lod1 bekommt weniger, größere Karten (`n1`, `half1`) und behält dafür die Ausschneide-Klasse – ohne sie zeigte lod1
  nur den Kern, und der Stufenwechsel bei 60 m tauschte beim Südhaus 34,8 statt 16,4 % der Pixel (gemessen). Weil die"""
b = """  lod1 zeigt dieselben Karten (`n1` = `n`, `half1` = `half`) und behält dafür die Ausschneide-Klasse – mit dem Kern
  allein tauschte der Stufenwechsel bei 60 m beim Südhaus 34,8 % der Pixel, mit weniger, größeren Karten 27,5 %
  (gemessen; vorher 16,4 %). Weil die"""
assert s.count(a) == 1
s = s.replace(a, b)
open(p, "w").write(s)
print("ok")
