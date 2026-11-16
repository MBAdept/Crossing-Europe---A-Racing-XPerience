## 6. Showroom: A/B und Entscheidung

Bild `04_showroom_ab.jpg`: links die Echtzeit-Stufe `show`, rechts das Cycles-Sprite, dieselbe Kamera, derselbe
Boden (`tools/models_contact_sheet.sh <bild> --only="player/*" --showroom`).

Gesehen (Bild 04, beide Autos von schräg vorn): Form, Proportionen, Fugen, Räder, Bremssättel, Spiegel und
Kennzeichen stimmen mit dem Sprite überein. Nicht gleichwertig sind:

1. **Lack** – das Echtzeit-Gelb ist zitronig und flach, das Sprite warm mit Klarlack-Spiegelung und dunkleren
   Flanken; beim Blau dasselbe. Das ist Shader und Licht (R3: Klarlack, Belichtung; UI1: Showroom-Licht), nicht das
   Netz – die Lackwerte sind die des Sprites.
2. **Glas** – in Echtzeit hell und durchsichtig (man sieht den Innenraum), im Sprite dunkel getönt mit Spiegelung.
   Die Kritik hatte das Glas nur bei den Verkehrsautos bemängelt (B4); die Spielerautos haben unverändert das
   Glas aus AS1.
3. **Rückleuchte von schräg vorn** – im Sprite reicht sie sichtbar um die Ecke (rotes Glanzlicht an der hinteren
   Flanke), im Modell nicht (A9, offen).
4. Kleinigkeiten: Chromrahmen des Limousinen-Grills im Sprite heller, Scheinwerferglas in Echtzeit weißer.

`showroom` bleibt deshalb für `showroom/limousine` und `showroom/kompakt` **`false`**. Neu entscheiden, sobald der
Lackshader (R3: Klarlack, Spiegelung, Belichtung) und das Showroom-Licht (UI1) stehen: dasselbe Kommando, bei
Gleichstand in `tools/blender/ce3d/catalog3d.py` `"showroom": True` setzen und `export_models.py --manifest-only`.
