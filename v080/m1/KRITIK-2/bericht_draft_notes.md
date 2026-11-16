# Notizen für bericht.md (Arbeitsstand)

- Spieler: Silhouette 9 m IoU 0,989–0,994 (gemessen) – Proportionen stimmen.
- Lack 9 m (Sprite → Modern Renn-Look; V, Anteil geclippt):
  kombi 0,30 → 0,51 (0 %), H 152 → 161°; sportwagen 0,58 → 0,94 (55 %); GT 0,64 → 0,71 (24 %);
  limousine 0,48 → 0,74 (25 %); kompakt 0,72 → 0,96 (87 %), H 43 → 54°. Neutral-Shader genauso hell → Licht, nicht Klarlack.
- Nacht 8 m rote Lampenpixel Modern/Arcade: kombi 590/1617, sportwagen 690/1061, GT 353/733, limousine 555/1369,
  kompakt 538/1193 (Rücklicht). Bremse: 1045/2034, 1052/1197, 587/957, 1000/1656, 949/1479 (ohne Flares!)
- Tag Bremse an/aus: Helligkeit der Lampenpixel ×1,3–1,5.
- Kombi-Rückfahrlicht: 47 Dreiecke unter der roten k2-Fläche (0–1 mm), Strahltest 10 % sichtbar, Render 0 px Änderung.
- Kompakt k7: hinter klarem Glas (5 mm) – Render prüfen (kompakt_night_reverse).
- SUV-Rückstrahler k0 (184 cm², Gewicht 0,3): 3 cm im Stoßfänger vergraben, 0 % sichtbar (lod0 und lod1).
- Sportwagen/GT Vorderrad: 114/71 Ecken, 84/61 mm, sichtbar seitlich und im Showroom.
- Verkehr-Sportwagen Vorderrad bei ±7°: 2 Ecken, 27–36 mm (Verkehr lenkt < 2°: unkritisch).
- Interior: über den Radläufen nichts außerhalb der Hülle.
- Zeichenaufrufe: 6 je Spielerauto (vpbr+glass+4 Räder) + Werfer je Kaskade; show-Räder mit Auto-LOD (Prims < Manifest).
- Showroom IoU 0,881–0,885 (Rest = Bodenschatten im Sprite).
- Weiße Verkehrs-Sets #ececea/#e8e8e5/#e6e6e3 ungebremst (Lkw: _tone → #d8d8d6).
- Van lod2: ganze obere Kastenhälfte (Seite und Heck) als Glas.
- SUV Front: Sägezähne Stoßfänger-Unterkante.
- Flotte: Kennzeichen Verkehr wie Strichcode.
