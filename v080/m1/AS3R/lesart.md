Lesart (gemessen, Endstand):

- **Mittags** liegt jedes Fernbild außer der Palme bei lod1: Kontrast −22 … +14 % (die Kritik maß −30 … −80 %),
  Sättigung −7 … +9 % (vorher −5 … −19 %), Helligkeit −9 … +6 %. Das Arcade-Sprite ist nicht mehr deutlich
  kontrastreicher als das Fernbild (−29 … +22 % statt +14 … +290 %). Die Palme bleibt bei −59 … −62 % Kontrast: ihre
  dünnen Wedel lösen sich im Fernbild kaum auf.
- **lod0 → lod1** springt die Helligkeit mittags um −3,6 … +5,0 % (alle 21 Modelle), abends um −2,7 … +6,5 %, nachts
  um −3,6 … +8,3 %. Ausreißer ist `olive_b`: +5,0 / +6,5 / +8,3 % (vorher −1,8 / −0,7 / −1,1 %), seit ihr lod1 den
  vollen Kuppelrand trägt; `spruce_b` hat nachts +8,1 % wie vorher. Alle anderen bleiben innerhalb ±6 %.
- **Abends (19:30)** zeigt das Fernbild weiter das Relief aus dem Licht des Sprite-Rigs, lod1 dagegen das flache
  Abendlicht. Deshalb liegt der Kontrast der Laubbäume und Kiefern +10 … +48 % über lod1 und der der Zypresse +114 … +121 %
  (vorher −5 … −36 % bzw. +9,5 … +11,5 %). Das Arcade-Sprite hat dann bis zu 40 % weniger Kontrast als das Fernbild
  (Fichte gleich viel; vorher bis zu 124 % mehr). Die Fichte verliert abends wie vorher rund ein Drittel der Sättigung (−36 %).
- **Nachts** sind die Fernbilder von Fichte (+30 / +32 %), Palme (+14 / +20 %) und Zypresse (+17 / +18 %) heller
  als lod1. Bei einer Krone um 10–30 von 255 Grauwerten (Messung von AS3) sind das 2–6 Grauwerte; das Gesetz von
  `billboard.gdshader` ist unverändert.
- Abhilfe für Abend und Nacht wäre ein Tageszeit-Faktor auf dem eingebackenen Relief im Shader (R2/R7, Abschnitt 9).